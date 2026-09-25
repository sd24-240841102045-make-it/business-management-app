-- ============================================================
-- PRODUCTION-READY REAL-TIME MESSAGING SCHEMA & RLS
-- Multi-Tenant SaaS: Admin, Employee, Client
-- ============================================================

-- 1. Ensure extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 2. CONVERSATIONS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    project_id UUID REFERENCES public.projects(id) ON DELETE SET NULL,
    conversation_type TEXT NOT NULL DEFAULT 'direct' CHECK (conversation_type IN ('direct', 'group', 'project')),
    title TEXT,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Backwards-compatibility column checks
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='conversations' AND column_name='conversation_type') THEN
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='conversations' AND column_name='type') THEN
            ALTER TABLE public.conversations ADD COLUMN conversation_type TEXT DEFAULT 'direct';
            UPDATE public.conversations SET conversation_type = type WHERE conversation_type IS NULL;
        ELSE
            ALTER TABLE public.conversations ADD COLUMN conversation_type TEXT DEFAULT 'direct';
        END IF;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='conversations' AND column_name='created_by') THEN
        ALTER TABLE public.conversations ADD COLUMN created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='conversations' AND column_name='updated_at') THEN
        ALTER TABLE public.conversations ADD COLUMN updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL;
    END IF;
END $$;

-- Allow organization_id to be nullable for cross-org direct messages if needed,
-- but enforce organization isolation when present.
ALTER TABLE public.conversations ALTER COLUMN organization_id DROP NOT NULL;

-- ============================================================
-- 3. CONVERSATION MEMBERS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.conversation_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    joined_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    last_read_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(conversation_id, user_id)
);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='conversation_members' AND column_name='last_read_at') THEN
        ALTER TABLE public.conversation_members ADD COLUMN last_read_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL;
    END IF;
END $$;

-- ============================================================
-- 4. MESSAGES TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    message TEXT NOT NULL DEFAULT '',
    message_type TEXT NOT NULL DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'file', 'system')),
    attachment_url TEXT,
    reply_to_id UUID REFERENCES public.messages(id) ON DELETE SET NULL,
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

DO $$
BEGIN
    -- Ensure 'message' column exists and sync with legacy 'content' column if present
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='messages' AND column_name='message') THEN
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='messages' AND column_name='content') THEN
            ALTER TABLE public.messages ADD COLUMN message TEXT DEFAULT '';
            UPDATE public.messages SET message = content WHERE message IS NULL OR message = '';
        ELSE
            ALTER TABLE public.messages ADD COLUMN message TEXT DEFAULT '';
        END IF;
    END IF;

    -- Ensure 'content' column exists for backwards compatibility with any existing query
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='messages' AND column_name='content') THEN
        ALTER TABLE public.messages ADD COLUMN content TEXT DEFAULT '';
        UPDATE public.messages SET content = message WHERE content IS NULL OR content = '';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='messages' AND column_name='message_type') THEN
        ALTER TABLE public.messages ADD COLUMN message_type TEXT NOT NULL DEFAULT 'text';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='messages' AND column_name='is_deleted') THEN
        ALTER TABLE public.messages ADD COLUMN is_deleted BOOLEAN NOT NULL DEFAULT false;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='messages' AND column_name='updated_at') THEN
        ALTER TABLE public.messages ADD COLUMN updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL;
    END IF;
END $$;

-- Keep 'content' and 'message' in sync automatically via trigger
CREATE OR REPLACE FUNCTION public.sync_message_content()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.message IS NOT NULL AND (NEW.content IS NULL OR NEW.content = '') THEN
        NEW.content := NEW.message;
    ELSIF NEW.content IS NOT NULL AND (NEW.message IS NULL OR NEW.message = '') THEN
        NEW.message := NEW.content;
    END IF;
    NEW.updated_at := timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_message_content ON public.messages;
CREATE TRIGGER trg_sync_message_content
    BEFORE INSERT OR UPDATE ON public.messages
    FOR EACH ROW EXECUTE FUNCTION public.sync_message_content();

-- Automatically update conversation updated_at when a new message is inserted
CREATE OR REPLACE FUNCTION public.on_message_inserted_update_conversation()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.conversations
    SET updated_at = NEW.created_at
    WHERE id = NEW.conversation_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_message_inserted_update_conv ON public.messages;
CREATE TRIGGER trg_message_inserted_update_conv
    AFTER INSERT ON public.messages
    FOR EACH ROW EXECUTE FUNCTION public.on_message_inserted_update_conversation();

-- ============================================================
-- 5. PERFORMANCE INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_conversations_org_id ON public.conversations(organization_id);
CREATE INDEX IF NOT EXISTS idx_conversations_updated_at ON public.conversations(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_conversation_members_conv_id ON public.conversation_members(conversation_id);
CREATE INDEX IF NOT EXISTS idx_conversation_members_user_id ON public.conversation_members(user_id);
CREATE INDEX IF NOT EXISTS idx_messages_conv_created ON public.messages(conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON public.messages(sender_id);

-- ============================================================
-- 6. SECURITY DEFINER HELPER FUNCTIONS (PREVENTS 42P17 RECURSION)
-- ============================================================
-- Verifies membership without triggering RLS evaluation cycle
CREATE OR REPLACE FUNCTION public.is_conversation_member(p_conv_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.conversation_members
        WHERE conversation_id = p_conv_id AND user_id = p_user_id
    );
$$;

-- Returns all conversation IDs for the calling authenticated user
CREATE OR REPLACE FUNCTION public.get_my_conversation_ids()
RETURNS SETOF UUID
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT conversation_id 
    FROM public.conversation_members 
    WHERE user_id = auth.uid();
$$;

-- Check if user has access to conversation's organization
CREATE OR REPLACE FUNCTION public.user_can_access_conv_org(p_conv_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    v_org_id UUID;
BEGIN
    SELECT organization_id INTO v_org_id FROM public.conversations WHERE id = p_conv_id;
    -- If no org attached (e.g. direct cross-membership chat), allow if user is a member
    IF v_org_id IS NULL THEN
        RETURN true;
    END IF;
    RETURN EXISTS (
        SELECT 1 FROM public.organization_memberships
        WHERE organization_id = v_org_id
          AND user_id = auth.uid()
          AND status = 'active'
    );
END;
$$;

-- ============================================================
-- 7. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Clean existing policies safely
DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN
        SELECT policyname, tablename
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename IN ('conversations', 'conversation_members', 'messages')
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I;', pol.policyname, pol.tablename);
    END LOOP;
END $$;

-- 7.1 CONVERSATIONS POLICIES
-- Users can only select conversations they belong to, or conversations within their organization that they created
CREATE POLICY "conversations_select_policy"
    ON public.conversations FOR SELECT TO authenticated
    USING (
        id IN (SELECT public.get_my_conversation_ids())
        OR created_by = auth.uid()
    );

-- Any authenticated user can initiate a conversation
CREATE POLICY "conversations_insert_policy"
    ON public.conversations FOR INSERT TO authenticated
    WITH CHECK (
        auth.uid() IS NOT NULL
        AND (organization_id IS NULL OR organization_id IN (SELECT public.current_user_org_ids()))
    );

-- Members can update conversation metadata (e.g. title)
CREATE POLICY "conversations_update_policy"
    ON public.conversations FOR UPDATE TO authenticated
    USING (
        id IN (SELECT public.get_my_conversation_ids())
        OR created_by = auth.uid()
    );

-- 7.2 CONVERSATION MEMBERS POLICIES
-- Users can view membership of conversations they belong to
CREATE POLICY "members_select_policy"
    ON public.conversation_members FOR SELECT TO authenticated
    USING (
        user_id = auth.uid()
        OR public.is_conversation_member(conversation_id, auth.uid())
    );

-- Users can join a conversation or add other members if they are creating/member
CREATE POLICY "members_insert_policy"
    ON public.conversation_members FOR INSERT TO authenticated
    WITH CHECK (
        user_id = auth.uid()
        OR public.is_conversation_member(conversation_id, auth.uid())
        OR EXISTS (
            SELECT 1 FROM public.conversations c
            WHERE c.id = conversation_id AND c.created_by = auth.uid()
        )
    );

-- Members can update their own last_read_at timestamp
CREATE POLICY "members_update_policy"
    ON public.conversation_members FOR UPDATE TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Members can leave a conversation
CREATE POLICY "members_delete_policy"
    ON public.conversation_members FOR DELETE TO authenticated
    USING (user_id = auth.uid());

-- 7.3 MESSAGES POLICIES
-- Users can view messages only if they are a member of that conversation
CREATE POLICY "messages_select_policy"
    ON public.messages FOR SELECT TO authenticated
    USING (
        public.is_conversation_member(conversation_id, auth.uid())
    );

-- Users can insert messages only into conversations they are a member of
CREATE POLICY "messages_insert_policy"
    ON public.messages FOR INSERT TO authenticated
    WITH CHECK (
        sender_id = auth.uid()
        AND public.is_conversation_member(conversation_id, auth.uid())
    );

-- Senders can edit their own messages
CREATE POLICY "messages_update_policy"
    ON public.messages FOR UPDATE TO authenticated
    USING (sender_id = auth.uid())
    WITH CHECK (sender_id = auth.uid());

-- Senders can delete (or soft-delete) their own messages
CREATE POLICY "messages_delete_policy"
    ON public.messages FOR DELETE TO authenticated
    USING (sender_id = auth.uid());

-- ============================================================
-- 8. REALTIME REPLICATION CONFIGURATION
-- ============================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'messages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'conversations'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'conversation_members'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.conversation_members;
    END IF;
END $$;

-- Enable REPLICA IDENTITY FULL on messages so Realtime delivers complete records on UPDATE and DELETE
ALTER TABLE public.messages REPLICA IDENTITY FULL;
ALTER TABLE public.conversations REPLICA IDENTITY FULL;
ALTER TABLE public.conversation_members REPLICA IDENTITY FULL;
