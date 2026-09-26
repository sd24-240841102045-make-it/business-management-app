-- ============================================================
-- CONTROLLED BUSINESS COMMUNICATION SYSTEM
-- Multi-Tenant SaaS: Relationship-Based Access & Privacy
-- ============================================================

-- 1. Communication Settings Table per Organization
CREATE TABLE IF NOT EXISTS public.communication_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE UNIQUE,
    enable_employee_client_messaging BOOLEAN NOT NULL DEFAULT true,
    restrict_client_to_projects BOOLEAN NOT NULL DEFAULT true,
    allow_employee_employee_chat BOOLEAN NOT NULL DEFAULT true,
    show_business_contact_info BOOLEAN NOT NULL DEFAULT true,
    allow_file_sharing BOOLEAN NOT NULL DEFAULT true,
    allow_message_editing BOOLEAN NOT NULL DEFAULT true,
    allow_message_deletion BOOLEAN NOT NULL DEFAULT false, -- Protect business records by default
    max_message_length INT NOT NULL DEFAULT 4000,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Seed default communication settings for all existing organizations
INSERT INTO public.communication_settings (organization_id)
SELECT id FROM public.organizations
ON CONFLICT (organization_id) DO NOTHING;

-- Trigger to automatically create communication settings for new organizations
CREATE OR REPLACE FUNCTION public.create_default_org_comm_settings()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.communication_settings (organization_id)
    VALUES (NEW.id)
    ON CONFLICT (organization_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_create_default_comm_settings ON public.organizations;
CREATE TRIGGER trg_create_default_comm_settings
    AFTER INSERT ON public.organizations
    FOR EACH ROW EXECUTE FUNCTION public.create_default_org_comm_settings();

-- 2. Ensure Project Conversations Columns
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='conversations' AND column_name='project_id') THEN
        ALTER TABLE public.conversations ADD COLUMN project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_conversations_project_id ON public.conversations(project_id);

-- ============================================================
-- 3. SECURITY DEFINER RELATIONSHIP HELPER FUNCTIONS
-- ============================================================

-- Helper: Check if user has admin privileges
CREATE OR REPLACE FUNCTION public.is_admin(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
    IF p_user_id IS NULL THEN
        RETURN false;
    END IF;

    -- 1. Check organization_memberships for admin or owner
    IF EXISTS (
        SELECT 1 FROM public.organization_memberships
        WHERE user_id = p_user_id 
          AND role IN ('admin', 'owner')
          AND status = 'active'
    ) THEN
        RETURN true;
    END IF;

    -- 2. Check if user is the creator of any organization
    IF EXISTS (
        SELECT 1 FROM public.organizations
        WHERE created_by = p_user_id
    ) THEN
        RETURN true;
    END IF;

    -- 3. Check auth.users user metadata for role
    IF EXISTS (
        SELECT 1 FROM auth.users
        WHERE id = p_user_id 
          AND (
            raw_user_meta_data->>'role' IN ('admin', 'owner')
            OR raw_app_meta_data->>'role' IN ('admin', 'owner')
          )
    ) THEN
        RETURN true;
    END IF;

    RETURN false;
END;
$$;

-- Helper: Get user's role in an organization
CREATE OR REPLACE FUNCTION public.get_user_org_role(p_user_id UUID, p_org_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    v_role TEXT;
BEGIN
    IF p_user_id IS NULL OR p_org_id IS NULL THEN
        RETURN 'guest';
    END IF;

    -- 1. Check organization_memberships
    SELECT role INTO v_role 
    FROM public.organization_memberships
    WHERE user_id = p_user_id AND organization_id = p_org_id AND status = 'active'
    LIMIT 1;

    IF v_role IS NOT NULL THEN
        RETURN v_role;
    END IF;

    -- 2. Check if organization owner
    IF EXISTS (SELECT 1 FROM public.organizations WHERE id = p_org_id AND created_by = p_user_id) THEN
        RETURN 'owner';
    END IF;

    -- 3. Check auth.users metadata
    IF EXISTS (
        SELECT 1 FROM auth.users
        WHERE id = p_user_id 
          AND (
            raw_user_meta_data->>'role' IN ('admin', 'owner')
            OR raw_app_meta_data->>'role' IN ('admin', 'owner')
          )
    ) THEN
        RETURN 'admin';
    END IF;

    -- 4. Check employees table
    IF EXISTS (SELECT 1 FROM public.employees WHERE (user_id = p_user_id OR id = p_user_id) AND organization_id = p_org_id) THEN
        RETURN 'employee';
    END IF;

    -- 5. Check clients table
    IF EXISTS (SELECT 1 FROM public.clients WHERE (user_id = p_user_id OR id = p_user_id) AND organization_id = p_org_id) THEN
        RETURN 'client';
    END IF;

    RETURN 'guest';
END;
$$;

-- Helper: Check if a user is an active member or client of a specific project
CREATE OR REPLACE FUNCTION public.can_access_project_conversation(p_user_id UUID, p_project_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    v_org_id UUID;
    v_client_id UUID;
    v_client_user_id UUID;
    v_role TEXT;
BEGIN
    IF p_user_id IS NULL THEN
        RETURN false;
    END IF;

    -- Global / Org Admin always has access
    IF public.is_admin(p_user_id) THEN
        RETURN true;
    END IF;

    -- If no specific project ID attached, allow authenticated org members
    IF p_project_id IS NULL THEN
        RETURN true;
    END IF;

    -- Look up project info
    SELECT organization_id, client_id INTO v_org_id, v_client_id
    FROM public.projects WHERE id = p_project_id;

    IF v_org_id IS NULL THEN
        RETURN EXISTS (SELECT 1 FROM public.projects WHERE id = p_project_id AND created_by = p_user_id);
    END IF;

    -- Check if user is an Admin of the project's organization
    v_role := public.get_user_org_role(p_user_id, v_org_id);
    IF v_role IN ('admin', 'owner') THEN
        RETURN true;
    END IF;

    -- Check if user is the Client who owns this project
    IF v_client_id IS NOT NULL THEN
        SELECT user_id INTO v_client_user_id FROM public.clients WHERE id = v_client_id;
        IF v_client_user_id = p_user_id OR v_client_id = p_user_id THEN
            RETURN true;
        END IF;
    END IF;

    -- Check if user is an Employee assigned to this project (project_members)
    IF EXISTS (
        SELECT 1 FROM public.project_members
        WHERE project_id = p_project_id AND user_id = p_user_id
    ) THEN
        RETURN true;
    END IF;

    -- Check if user is an Employee assigned to any task within this project
    IF EXISTS (
        SELECT 1 FROM public.tasks
        WHERE project_id = p_project_id AND assigned_to = p_user_id
    ) THEN
        RETURN true;
    END IF;

    -- Check if user created the project
    IF EXISTS (
        SELECT 1 FROM public.projects
        WHERE id = p_project_id AND created_by = p_user_id
    ) THEN
        RETURN true;
    END IF;

    RETURN false;
END;
$$;

-- Helper: Validate whether two users have an authorized business communication relationship
CREATE OR REPLACE FUNCTION public.can_users_direct_chat(p_user_a UUID, p_user_b UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    v_org_id UUID;
    v_role_a TEXT;
    v_role_b TEXT;
    v_settings RECORD;
    v_client_user UUID;
    v_emp_user UUID;
    v_client_id UUID;
BEGIN
    -- Allow chatting with oneself (personal notes / testing)
    IF p_user_a = p_user_b THEN
        RETURN true;
    END IF;

    -- If either user is an Admin or Owner, direct chat is ALWAYS permitted!
    IF public.is_admin(p_user_a) OR public.is_admin(p_user_b) THEN
        RETURN true;
    END IF;

    -- 1. Find shared active organization across memberships, clients, employees, and projects
    SELECT org_id INTO v_org_id FROM (
        SELECT om1.organization_id AS org_id
        FROM public.organization_memberships om1
        JOIN public.organization_memberships om2 ON om1.organization_id = om2.organization_id
        WHERE om1.user_id = p_user_a AND om1.status = 'active'
          AND om2.user_id = p_user_b AND om2.status = 'active'
        UNION
        SELECT c.organization_id AS org_id
        FROM public.clients c
        JOIN public.organization_memberships om ON om.organization_id = c.organization_id
        WHERE (c.user_id = p_user_b OR c.id = p_user_b) AND om.user_id = p_user_a AND om.status = 'active'
        UNION
        SELECT c.organization_id AS org_id
        FROM public.clients c
        JOIN public.organization_memberships om ON om.organization_id = c.organization_id
        WHERE (c.user_id = p_user_a OR c.id = p_user_a) AND om.user_id = p_user_b AND om.status = 'active'
        UNION
        SELECT c.organization_id AS org_id
        FROM public.clients c
        JOIN public.employees e ON e.organization_id = c.organization_id
        WHERE (c.user_id = p_user_b OR c.id = p_user_b) AND (e.user_id = p_user_a OR e.id = p_user_a)
        UNION
        SELECT c.organization_id AS org_id
        FROM public.clients c
        JOIN public.employees e ON e.organization_id = c.organization_id
        WHERE (c.user_id = p_user_a OR c.id = p_user_a) AND (e.user_id = p_user_b OR e.id = p_user_b)
        UNION
        SELECT e1.organization_id AS org_id
        FROM public.employees e1
        JOIN public.employees e2 ON e1.organization_id = e2.organization_id
        WHERE (e1.user_id = p_user_a OR e1.id = p_user_a) AND (e2.user_id = p_user_b OR e2.id = p_user_b)
    ) shared_orgs
    LIMIT 1;

    -- If no shared organization could be determined
    IF v_org_id IS NULL THEN
        IF EXISTS (
            SELECT 1 FROM public.projects p
            LEFT JOIN public.project_members pm ON pm.project_id = p.id
            LEFT JOIN public.clients c ON c.id = p.client_id
            WHERE (pm.user_id = p_user_a AND (c.user_id = p_user_b OR c.id = p_user_b))
               OR (pm.user_id = p_user_b AND (c.user_id = p_user_a OR c.id = p_user_a))
        ) THEN
            RETURN true;
        END IF;
        RETURN false;
    END IF;

    -- Get roles in the shared organization
    v_role_a := public.get_user_org_role(p_user_a, v_org_id);
    v_role_b := public.get_user_org_role(p_user_b, v_org_id);

    -- Load organization communication settings
    SELECT * INTO v_settings FROM public.communication_settings WHERE organization_id = v_org_id;

    -- 2. Admin <-> Anyone in organization is always allowed
    IF v_role_a IN ('admin', 'owner') OR v_role_b IN ('admin', 'owner') THEN
        RETURN true;
    END IF;

    -- 3. Client <-> Client is NEVER allowed
    IF v_role_a = 'client' AND v_role_b = 'client' THEN
        RETURN false;
    END IF;

    -- 4. Employee <-> Employee
    IF v_role_a = 'employee' AND v_role_b = 'employee' THEN
        IF v_settings.allow_employee_employee_chat IS FALSE THEN
            RETURN false;
        END IF;
        RETURN true;
    END IF;

    -- 5. Employee <-> Client (Legitimate business relationship required)
    IF (v_role_a = 'employee' AND v_role_b = 'client') OR (v_role_a = 'client' AND v_role_b = 'employee') THEN
        IF v_settings.enable_employee_client_messaging IS FALSE THEN
            RETURN false;
        END IF;

        IF v_role_a = 'client' THEN
            v_client_user := p_user_a;
            v_emp_user := p_user_b;
        ELSE
            v_client_user := p_user_b;
            v_emp_user := p_user_a;
        END IF;

        -- Find client record ID
        SELECT id INTO v_client_id FROM public.clients 
        WHERE (user_id = v_client_user OR id = v_client_user) AND organization_id = v_org_id 
        LIMIT 1;

        -- Check A: Is employee assigned to this client's account directly?
        IF EXISTS (
            SELECT 1 FROM public.clients
            WHERE id = v_client_id
              AND (
                assigned_employee_id = v_emp_user::text
                OR assigned_employee_id IN (SELECT id::text FROM public.employees WHERE user_id = v_emp_user OR id = v_emp_user)
              )
        ) THEN
            RETURN true;
        END IF;

        -- Check B: Is employee assigned to any project belonging to this client?
        IF EXISTS (
            SELECT 1 FROM public.projects p
            JOIN public.project_members pm ON pm.project_id = p.id
            WHERE p.client_id = v_client_id
              AND pm.user_id = v_emp_user
              AND p.organization_id = v_org_id
        ) THEN
            RETURN true;
        END IF;

        -- Check C: Is employee assigned to any task within this client's projects?
        IF EXISTS (
            SELECT 1 FROM public.tasks t
            JOIN public.projects p ON p.id = t.project_id
            WHERE p.client_id = v_client_id
              AND t.assigned_to = v_emp_user
              AND p.organization_id = v_org_id
        ) THEN
            RETURN true;
        END IF;

        -- If restricted to projects and no shared project/account relationship exists, REJECT
        IF v_settings.restrict_client_to_projects IS TRUE THEN
            RETURN false;
        END IF;

        RETURN true;
    END IF;

    RETURN false;
END;
$$;

-- Helper: Check whether authenticated user can access/participate in a given conversation
CREATE OR REPLACE FUNCTION public.can_user_access_conversation(p_user_id UUID, p_conv_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    v_conv RECORD;
    v_other_user UUID;
BEGIN
    IF p_user_id IS NULL OR p_conv_id IS NULL THEN
        RETURN false;
    END IF;

    -- Global / Org Admin always has unrestricted access
    IF public.is_admin(p_user_id) THEN
        RETURN true;
    END IF;

    -- Retrieve conversation
    SELECT * INTO v_conv FROM public.conversations WHERE id = p_conv_id;
    IF v_conv.id IS NULL THEN
        RETURN true;
    END IF;

    -- Creator always has access
    IF v_conv.created_by = p_user_id THEN
        RETURN true;
    END IF;

    -- Check if user is an admin of this specific conversation's organization
    IF v_conv.organization_id IS NOT NULL THEN
        IF public.get_user_org_role(p_user_id, v_conv.organization_id) IN ('admin', 'owner') THEN
            RETURN true;
        END IF;
    END IF;

    -- 1. Project Conversations: Must have valid project membership or admin rights
    IF v_conv.conversation_type = 'project' OR v_conv.project_id IS NOT NULL THEN
        RETURN public.can_access_project_conversation(p_user_id, v_conv.project_id);
    END IF;

    -- 2. Direct Conversations: Must have legitimate business relationship
    IF v_conv.conversation_type = 'direct' THEN
        IF EXISTS (SELECT 1 FROM public.conversation_members WHERE conversation_id = p_conv_id AND user_id = p_user_id) THEN
            SELECT user_id INTO v_other_user
            FROM public.conversation_members
            WHERE conversation_id = p_conv_id AND user_id <> p_user_id
            LIMIT 1;

            IF v_other_user IS NOT NULL THEN
                RETURN public.can_users_direct_chat(p_user_id, v_other_user);
            END IF;
            RETURN true;
        END IF;

        RETURN v_conv.created_by = p_user_id;
    END IF;

    -- 3. Group Conversations: User must be an explicit member
    RETURN EXISTS (
        SELECT 1 FROM public.conversation_members
        WHERE conversation_id = p_conv_id AND user_id = p_user_id
    );
END;
$$;

-- ============================================================
-- 4. UPDATE ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================

-- Communication Settings RLS
ALTER TABLE public.communication_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "comm_settings_select" ON public.communication_settings;
CREATE POLICY "comm_settings_select"
    ON public.communication_settings FOR SELECT TO authenticated
    USING (organization_id IN (SELECT public.current_user_org_ids()) OR public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "comm_settings_update" ON public.communication_settings;
CREATE POLICY "comm_settings_update"
    ON public.communication_settings FOR UPDATE TO authenticated
    USING (public.has_org_role(organization_id, 'admin') OR public.is_admin(auth.uid()));

-- Conversations RLS
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "conversations_select_policy" ON public.conversations;
CREATE POLICY "conversations_select_policy"
    ON public.conversations FOR SELECT TO authenticated
    USING (
        public.is_admin(auth.uid())
        OR created_by = auth.uid()
        OR public.can_user_access_conversation(auth.uid(), id)
    );

DROP POLICY IF EXISTS "conversations_insert_policy" ON public.conversations;
CREATE POLICY "conversations_insert_policy"
    ON public.conversations FOR INSERT TO authenticated
    WITH CHECK (
        auth.uid() IS NOT NULL
        AND (
            public.is_admin(auth.uid())
            OR created_by = auth.uid()
            OR (conversation_type = 'project' AND public.can_access_project_conversation(auth.uid(), project_id))
        )
    );

DROP POLICY IF EXISTS "conversations_update_policy" ON public.conversations;
CREATE POLICY "conversations_update_policy"
    ON public.conversations FOR UPDATE TO authenticated
    USING (
        public.is_admin(auth.uid())
        OR created_by = auth.uid()
        OR public.can_user_access_conversation(auth.uid(), id)
    );

-- Conversation Members RLS
ALTER TABLE public.conversation_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "members_select_policy" ON public.conversation_members;
CREATE POLICY "members_select_policy"
    ON public.conversation_members FOR SELECT TO authenticated
    USING (
        user_id = auth.uid()
        OR public.is_admin(auth.uid())
        OR public.can_user_access_conversation(auth.uid(), conversation_id)
    );

DROP POLICY IF EXISTS "members_insert_policy" ON public.conversation_members;
CREATE POLICY "members_insert_policy"
    ON public.conversation_members FOR INSERT TO authenticated
    WITH CHECK (
        auth.uid() IS NOT NULL
        AND (
            user_id = auth.uid()
            OR public.is_admin(auth.uid())
            OR public.can_user_access_conversation(auth.uid(), conversation_id)
            OR EXISTS (SELECT 1 FROM public.conversations c WHERE c.id = conversation_id AND c.created_by = auth.uid())
        )
    );

DROP POLICY IF EXISTS "members_update_policy" ON public.conversation_members;
CREATE POLICY "members_update_policy"
    ON public.conversation_members FOR UPDATE TO authenticated
    USING (user_id = auth.uid() OR public.is_admin(auth.uid()))
    WITH CHECK (user_id = auth.uid() OR public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "members_delete_policy" ON public.conversation_members;
CREATE POLICY "members_delete_policy"
    ON public.conversation_members FOR DELETE TO authenticated
    USING (
        user_id = auth.uid()
        OR public.is_admin(auth.uid())
        OR EXISTS (
            SELECT 1 FROM public.conversations c
            WHERE c.id = conversation_id AND c.created_by = auth.uid()
        )
    );

-- Messages RLS
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "messages_select_policy" ON public.messages;
CREATE POLICY "messages_select_policy"
    ON public.messages FOR SELECT TO authenticated
    USING (
        public.is_admin(auth.uid())
        OR public.can_user_access_conversation(auth.uid(), conversation_id)
        OR EXISTS (SELECT 1 FROM public.conversation_members cm WHERE cm.conversation_id = messages.conversation_id AND cm.user_id = auth.uid())
    );

DROP POLICY IF EXISTS "messages_insert_policy" ON public.messages;
CREATE POLICY "messages_insert_policy"
    ON public.messages FOR INSERT TO authenticated
    WITH CHECK (
        sender_id = auth.uid()
        AND (
            public.is_admin(auth.uid())
            OR public.can_user_access_conversation(auth.uid(), conversation_id)
            OR EXISTS (SELECT 1 FROM public.conversations c WHERE c.id = conversation_id AND c.created_by = auth.uid())
            OR EXISTS (SELECT 1 FROM public.conversation_members cm WHERE cm.conversation_id = messages.conversation_id AND cm.user_id = auth.uid())
        )
        AND (message IS NULL OR length(message) <= 10000)
    );

DROP POLICY IF EXISTS "messages_update_policy" ON public.messages;
CREATE POLICY "messages_update_policy"
    ON public.messages FOR UPDATE TO authenticated
    USING (
        sender_id = auth.uid()
        OR public.is_admin(auth.uid())
    )
    WITH CHECK (sender_id = auth.uid() OR public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "messages_delete_policy" ON public.messages;
CREATE POLICY "messages_delete_policy"
    ON public.messages FOR DELETE TO authenticated
    USING (
        sender_id = auth.uid()
        OR public.is_admin(auth.uid())
    );

-- Realtime publication for communication_settings
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'communication_settings'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.communication_settings;
    END IF;
END $$;
