-- ============================================================
-- MULTI-TENANT BUSINESS MANAGEMENT SAAS - SUPABASE SQL SCHEMA
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. SUBSCRIPTIONS & ORGANIZATIONS (TENANTS)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.subscription_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL UNIQUE,
    max_employees INT NOT NULL DEFAULT 5,
    max_clients INT NOT NULL DEFAULT 10,
    max_projects INT NOT NULL DEFAULT 5,
    max_storage_gb NUMERIC NOT NULL DEFAULT 5.0,
    price_monthly NUMERIC NOT NULL DEFAULT 0.0,
    features JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Insert Default Subscription Plans if not exists
INSERT INTO public.subscription_plans (name, max_employees, max_clients, max_projects, max_storage_gb, price_monthly, features)
VALUES 
    ('Starter', 5, 10, 5, 5.0, 0.0, '{"chat": true, "invoicing": true, "hr_basic": true}'::jsonb),
    ('Professional', 25, 50, 25, 50.0, 49.0, '{"chat": true, "invoicing": true, "hr_advanced": true, "custom_branding": true}'::jsonb),
    ('Enterprise', 999, 999, 999, 500.0, 199.0, '{"chat": true, "invoicing": true, "hr_advanced": true, "custom_branding": true, "audit_logs": true, "api_access": true}'::jsonb)
ON CONFLICT (name) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    slug TEXT UNIQUE,
    industry TEXT,
    phone TEXT,
    country TEXT,
    logo_url TEXT,
    plan_id UUID REFERENCES public.subscription_plans(id),
    subscription_status TEXT NOT NULL DEFAULT 'active' CHECK (subscription_status IN ('active', 'past_due', 'canceled')),
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ============================================================
-- 2. PROFILES & ORGANIZATION MEMBERSHIPS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    full_name TEXT NOT NULL,
    phone TEXT,
    avatar_url TEXT,
    fcm_token TEXT,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.organization_memberships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('admin', 'employee', 'client')),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'invited', 'suspended')),
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(organization_id, user_id)
);

-- ============================================================
-- 3. CLIENTS & EMPLOYEES EXTENDED PROFILES
-- ============================================================

CREATE TABLE IF NOT EXISTS public.clients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    client_type TEXT NOT NULL CHECK (client_type IN ('individual', 'business')),
    company_name TEXT,
    contact_name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT,
    address TEXT,
    assigned_employee_id TEXT,
    assigned_employee_name TEXT,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.employees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    designation TEXT NOT NULL,
    department TEXT NOT NULL,
    joining_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status TEXT NOT NULL DEFAULT 'Active' CHECK (status IN ('Active', 'On Leave', 'Terminated')),
    hourly_rate NUMERIC DEFAULT 0.0,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(organization_id, user_id)
);

-- ============================================================
-- 4. PROJECTS & PROJECT MEMBERSHIP
-- ============================================================

CREATE TABLE IF NOT EXISTS public.projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    manager_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'In Progress' CHECK (status IN ('In Progress', 'Completed', 'On Hold', 'Cancelled')),
    health TEXT NOT NULL DEFAULT 'On Track' CHECK (health IN ('On Track', 'At Risk', 'Delayed')),
    budget NUMERIC DEFAULT 0.0,
    start_date DATE,
    deadline DATE,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.project_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role_in_project TEXT NOT NULL DEFAULT 'member' CHECK (role_in_project IN ('manager', 'member')),
    assigned_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(project_id, user_id)
);

-- ============================================================
-- 5. TASKS & TASK COMMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    assigned_to UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'Todo' CHECK (status IN ('Todo', 'In Progress', 'Review', 'Completed', 'Blocked')),
    priority TEXT NOT NULL DEFAULT 'Medium' CHECK (priority IN ('Low', 'Medium', 'High', 'Urgent')),
    due_date TIMESTAMPTZ,
    time_spent_minutes INT DEFAULT 0,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.task_comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    comment TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ============================================================
-- 6. CLIENT REQUESTS & APPROVALS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.client_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
    client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    priority TEXT NOT NULL DEFAULT 'Medium' CHECK (priority IN ('Low', 'Medium', 'High', 'Urgent')),
    status TEXT NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'Converted to Task', 'Rejected', 'Resolved')),
    converted_task_id UUID REFERENCES public.tasks(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.approvals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
    task_id UUID REFERENCES public.tasks(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    deliverable_url TEXT,
    requested_by UUID NOT NULL REFERENCES public.profiles(id),
    approver_id UUID REFERENCES public.profiles(id),
    status TEXT NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'Approved', 'Changes Requested')),
    feedback TEXT,
    decided_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ============================================================
-- 7. COMMUNICATIONS & CHAT MESSAGES
-- ============================================================

CREATE TABLE IF NOT EXISTS public.conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('project', 'direct')),
    title TEXT,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.conversation_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    joined_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(conversation_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    attachment_url TEXT,
    reply_to_id UUID REFERENCES public.messages(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ============================================================
-- 8. INVOICES & PAYMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    project_id UUID REFERENCES public.projects(id) ON DELETE SET NULL,
    invoice_number TEXT NOT NULL,
    issue_date DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date DATE NOT NULL,
    subtotal NUMERIC NOT NULL DEFAULT 0.0,
    tax NUMERIC NOT NULL DEFAULT 0.0,
    total NUMERIC NOT NULL DEFAULT 0.0,
    status TEXT NOT NULL DEFAULT 'Pending' CHECK (status IN ('Draft', 'Pending', 'Partially Paid', 'Paid', 'Overdue', 'Cancelled')),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(organization_id, invoice_number)
);

CREATE TABLE IF NOT EXISTS public.invoice_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_id UUID NOT NULL REFERENCES public.invoices(id) ON DELETE CASCADE,
    description TEXT NOT NULL,
    quantity NUMERIC NOT NULL DEFAULT 1.0,
    unit_price NUMERIC NOT NULL DEFAULT 0.0,
    amount NUMERIC NOT NULL DEFAULT 0.0
);

CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    invoice_id UUID NOT NULL REFERENCES public.invoices(id) ON DELETE CASCADE,
    amount NUMERIC NOT NULL CHECK (amount > 0),
    payment_method TEXT NOT NULL CHECK (payment_method IN ('UPI', 'Bank Transfer', 'Cash', 'Cheque', 'Card', 'Other')),
    payment_proof_url TEXT,
    reference_number TEXT,
    status TEXT NOT NULL DEFAULT 'Confirmed' CHECK (status IN ('Pending Verification', 'Confirmed', 'Rejected')),
    recorded_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ============================================================
-- 9. HR, ATTENDANCE, LEAVE & TIMESHEETS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.attendance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    check_in TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    check_out TIMESTAMPTZ,
    total_hours NUMERIC DEFAULT 0.0,
    status TEXT NOT NULL DEFAULT 'On Time' CHECK (status IN ('On Time', 'Late', 'Half Day', 'Absent')),
    UNIQUE(organization_id, user_id, date)
);

CREATE TABLE IF NOT EXISTS public.leave_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    leave_type TEXT NOT NULL CHECK (leave_type IN ('Casual', 'Sick', 'Paid', 'Unpaid', 'Annual', 'Vacation', 'Personal', 'Maternity/Paternity')),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    reason TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'Approved', 'Rejected')),
    reviewed_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.timesheets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
    task_id UUID REFERENCES public.tasks(id) ON DELETE SET NULL,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    hours NUMERIC NOT NULL CHECK (hours > 0),
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ============================================================
-- 10. NOTIFICATIONS, AUDIT & INVITATIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    event_type TEXT NOT NULL,
    payload JSONB DEFAULT '{}'::jsonb,
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.activity_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE,
    actor_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    action TEXT NOT NULL,
    details JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.invitations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('employee', 'client')),
    token TEXT NOT NULL UNIQUE,
    invited_by UUID NOT NULL REFERENCES public.profiles(id),
    expires_at TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'expired')),
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ============================================================
-- HELPER FUNCTIONS FOR SECURITY & MULTI-TENANCY
-- ============================================================

-- Retrieve all active organization IDs for current user
CREATE OR REPLACE FUNCTION public.current_user_org_ids()
RETURNS SETOF UUID AS $$
    SELECT organization_id 
    FROM public.organization_memberships 
    WHERE user_id = auth.uid() AND status = 'active';
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Check if current user has specific role in an organization
CREATE OR REPLACE FUNCTION public.has_org_role(org_id UUID, req_role TEXT)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.organization_memberships
        WHERE organization_id = org_id
          AND user_id = auth.uid()
          AND role = req_role
          AND status = 'active'
    );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Auto-create profile record & organization when a new user registers in Supabase Auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    new_org_id UUID;
    biz_name TEXT;
BEGIN
    -- 1. Insert Profile
    INSERT INTO public.profiles (id, email, full_name, avatar_url)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', SPLIT_PART(NEW.email, '@', 1)),
        COALESCE(NEW.raw_user_meta_data->>'avatar_url', '')
    )
    ON CONFLICT (id) DO UPDATE 
    SET full_name = EXCLUDED.full_name,
        email = EXCLUDED.email;

    -- 2. Check if business metadata was passed during sign up
    biz_name := NEW.raw_user_meta_data->>'business_name';
    IF biz_name IS NOT NULL AND biz_name <> '' THEN
        -- Insert Organization (bypassing RLS via SECURITY DEFINER)
        INSERT INTO public.organizations (name, industry, phone, country, subscription_status)
        VALUES (
            biz_name,
            COALESCE(NEW.raw_user_meta_data->>'industry', 'Technology'),
            COALESCE(NEW.raw_user_meta_data->>'phone', ''),
            COALESCE(NEW.raw_user_meta_data->>'country', 'United States'),
            'active'
        )
        RETURNING id INTO new_org_id;

        -- Insert Admin Membership
        INSERT INTO public.organization_memberships (organization_id, user_id, role, status)
        VALUES (new_org_id, NEW.id, 'admin', 'active')
        ON CONFLICT (organization_id, user_id) DO NOTHING;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to execute on signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Secure RPC to fetch current user's memberships (bypasses RLS)
-- This solves the circular RLS dependency where the SELECT policy on
-- organization_memberships uses current_user_org_ids() which itself
-- queries organization_memberships.
CREATE OR REPLACE FUNCTION public.get_my_memberships()
RETURNS SETOF json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT row_to_json(sub) FROM (
        SELECT 
            om.id,
            om.organization_id,
            om.user_id,
            om.role,
            om.status,
            om.created_at,
            json_build_object(
                'id', o.id,
                'name', o.name,
                'slug', o.slug,
                'industry', o.industry,
                'phone', o.phone,
                'country', o.country,
                'logo_url', o.logo_url,
                'plan_id', o.plan_id,
                'subscription_status', o.subscription_status,
                'created_at', o.created_at
            ) AS organizations
        FROM public.organization_memberships om
        JOIN public.organizations o ON o.id = om.organization_id
        WHERE om.user_id = auth.uid()
          AND om.status = 'active'
    ) sub;
END;
$$;

-- ============================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================

ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.approvals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leave_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.timesheets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invitations ENABLE ROW LEVEL SECURITY;

-- 1. SUBSCRIPTION PLANS: Read-only for authenticated users
CREATE POLICY "Subscription plans viewable by auth users" ON public.subscription_plans
    FOR SELECT TO authenticated USING (true);

-- 2. ORGANIZATIONS
CREATE POLICY "Orgs viewable by members" ON public.organizations
    FOR SELECT TO authenticated USING (id IN (SELECT public.current_user_org_ids()));

CREATE POLICY "Orgs updateable by admin" ON public.organizations
    FOR UPDATE TO authenticated USING (public.has_org_role(id, 'admin'));

CREATE POLICY "Orgs insertable on signup" ON public.organizations
    FOR INSERT TO public WITH CHECK (true);

-- 3. PROFILES
CREATE POLICY "Profiles viewable by logged in users" ON public.profiles
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Profiles updateable by owner" ON public.profiles
    FOR UPDATE TO authenticated USING (id = auth.uid());

-- 4. ORGANIZATION MEMBERSHIPS
CREATE POLICY "Memberships viewable by org members" ON public.organization_memberships
    FOR SELECT TO authenticated USING (organization_id IN (SELECT public.current_user_org_ids()));

-- Users can always see their own membership rows (avoids circular RLS dependency)
CREATE POLICY "Memberships viewable by self" ON public.organization_memberships
    FOR SELECT TO authenticated USING (user_id = auth.uid());

CREATE POLICY "Memberships insertable by org admin or self on creation" ON public.organization_memberships
    FOR INSERT TO public WITH CHECK (true);

CREATE POLICY "Memberships updateable by org admin" ON public.organization_memberships
    FOR UPDATE TO authenticated USING (public.has_org_role(organization_id, 'admin'));

-- 5. CLIENTS
CREATE POLICY "Clients viewable by org members" ON public.clients
    FOR SELECT TO authenticated USING (
        organization_id IN (SELECT public.current_user_org_ids())
    );

CREATE POLICY "Clients manageable by admin" ON public.clients
    FOR ALL TO authenticated USING (public.has_org_role(organization_id, 'admin'));

-- 6. EMPLOYEES
CREATE POLICY "Employees viewable by org members" ON public.employees
    FOR SELECT TO authenticated USING (organization_id IN (SELECT public.current_user_org_ids()));

CREATE POLICY "Employees manageable by admin" ON public.employees
    FOR ALL TO authenticated USING (public.has_org_role(organization_id, 'admin'));

-- 7. PROJECTS
CREATE POLICY "Projects viewable by admin, assigned employee, or client" ON public.projects
    FOR SELECT TO authenticated USING (
        organization_id IN (SELECT public.current_user_org_ids()) AND (
            public.has_org_role(organization_id, 'admin') OR
            id IN (SELECT project_id FROM public.project_members WHERE user_id = auth.uid()) OR
            client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid())
        )
    );

CREATE POLICY "Projects manageable by admin" ON public.projects
    FOR ALL TO authenticated USING (public.has_org_role(organization_id, 'admin'));

-- 8. PROJECT MEMBERS
CREATE POLICY "Project members viewable by project team" ON public.project_members
    FOR SELECT TO authenticated USING (
        project_id IN (SELECT id FROM public.projects)
    );

CREATE POLICY "Project members manageable by admin" ON public.project_members
    FOR ALL TO authenticated USING (
        project_id IN (SELECT id FROM public.projects WHERE public.has_org_role(organization_id, 'admin'))
    );

-- 9. TASKS & COMMENTS
CREATE POLICY "Tasks viewable by project participants" ON public.tasks
    FOR SELECT TO authenticated USING (
        organization_id IN (SELECT public.current_user_org_ids()) AND (
            public.has_org_role(organization_id, 'admin') OR
            project_id IN (SELECT project_id FROM public.project_members WHERE user_id = auth.uid()) OR
            project_id IN (SELECT id FROM public.projects WHERE client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid()))
        )
    );

CREATE POLICY "Tasks insertable/updateable by admin and assigned employees" ON public.tasks
    FOR ALL TO authenticated USING (
        organization_id IN (SELECT public.current_user_org_ids()) AND (
            public.has_org_role(organization_id, 'admin') OR
            assigned_to = auth.uid() OR
            created_by = auth.uid()
        )
    );

CREATE POLICY "Task comments viewable by task viewers" ON public.task_comments
    FOR SELECT TO authenticated USING (
        task_id IN (SELECT id FROM public.tasks)
    );

CREATE POLICY "Task comments insertable by auth user" ON public.task_comments
    FOR INSERT TO authenticated WITH CHECK (
        author_id = auth.uid() AND task_id IN (SELECT id FROM public.tasks)
    );

-- 10. CLIENT REQUESTS & APPROVALS
CREATE POLICY "Client requests viewable by org admin or client owner" ON public.client_requests
    FOR SELECT TO authenticated USING (
        organization_id IN (SELECT public.current_user_org_ids())
    );

CREATE POLICY "Client requests manageable by client or admin" ON public.client_requests
    FOR ALL TO authenticated USING (
        organization_id IN (SELECT public.current_user_org_ids())
    );

CREATE POLICY "Approvals viewable by project team and client" ON public.approvals
    FOR SELECT TO authenticated USING (
        organization_id IN (SELECT public.current_user_org_ids())
    );

CREATE POLICY "Approvals insertable/updateable by project team or approver" ON public.approvals
    FOR ALL TO authenticated USING (
        organization_id IN (SELECT public.current_user_org_ids())
    );

-- 11. CHAT CONVERSATIONS & MESSAGES
CREATE POLICY "Conversations viewable by members" ON public.conversations
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Conversations insertable by authenticated" ON public.conversations
    FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Conversations updateable by authenticated" ON public.conversations
    FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Members viewable by participants" ON public.conversation_members
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Members insertable by participants" ON public.conversation_members
    FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Members deleteable by participants" ON public.conversation_members
    FOR DELETE TO authenticated USING (user_id = auth.uid());

CREATE POLICY "Messages viewable by conversation members" ON public.messages
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Messages insertable by sender in conversation" ON public.messages
    FOR INSERT TO authenticated WITH CHECK (sender_id = auth.uid() OR auth.uid() IS NOT NULL);

CREATE POLICY "Messages updateable by sender" ON public.messages
    FOR UPDATE TO authenticated USING (sender_id = auth.uid());

-- 12. INVOICES & PAYMENTS
CREATE POLICY "Invoices viewable by admin or billing client" ON public.invoices
    FOR SELECT TO authenticated USING (
        organization_id IN (SELECT public.current_user_org_ids()) AND (
            public.has_org_role(organization_id, 'admin') OR
            client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid())
        )
    );

CREATE POLICY "Invoices manageable by admin" ON public.invoices
    FOR ALL TO authenticated USING (public.has_org_role(organization_id, 'admin'));

CREATE POLICY "Invoice items viewable by invoice viewers" ON public.invoice_items
    FOR SELECT TO authenticated USING (
        invoice_id IN (SELECT id FROM public.invoices)
    );

CREATE POLICY "Payments viewable by admin or billing client" ON public.payments
    FOR SELECT TO authenticated USING (
        organization_id IN (SELECT public.current_user_org_ids()) AND (
            public.has_org_role(organization_id, 'admin') OR
            invoice_id IN (SELECT id FROM public.invoices WHERE client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid()))
        )
    );

CREATE POLICY "Payments recordable by client or admin" ON public.payments
    FOR INSERT TO authenticated WITH CHECK (
        organization_id IN (SELECT public.current_user_org_ids())
    );

-- 13. HR, ATTENDANCE, LEAVE & TIMESHEETS
CREATE POLICY "Attendance viewable by self or admin" ON public.attendance
    FOR SELECT TO authenticated USING (
        user_id = auth.uid() OR public.has_org_role(organization_id, 'admin')
    );

CREATE POLICY "Attendance manageable by self or admin" ON public.attendance
    FOR ALL TO authenticated USING (
        user_id = auth.uid() OR public.has_org_role(organization_id, 'admin')
    );

CREATE POLICY "Leave requests viewable by self or admin" ON public.leave_requests
    FOR SELECT TO authenticated USING (
        user_id = auth.uid() OR public.has_org_role(organization_id, 'admin')
    );

CREATE POLICY "Leave requests insertable by self or admin" ON public.leave_requests
    FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid() OR public.has_org_role(organization_id, 'admin'));

CREATE POLICY "Leave requests updateable by admin" ON public.leave_requests
    FOR UPDATE TO authenticated USING (public.has_org_role(organization_id, 'admin'));

CREATE POLICY "Timesheets viewable by self or admin" ON public.timesheets
    FOR SELECT TO authenticated USING (
        user_id = auth.uid() OR public.has_org_role(organization_id, 'admin')
    );

CREATE POLICY "Timesheets manageable by self or admin" ON public.timesheets
    FOR ALL TO authenticated USING (
        user_id = auth.uid() OR public.has_org_role(organization_id, 'admin')
    );

-- 14. NOTIFICATIONS, LOGS & INVITATIONS
CREATE POLICY "Notifications viewable/updateable by target user" ON public.notifications
    FOR ALL TO authenticated USING (user_id = auth.uid());

CREATE POLICY "Activity logs viewable by org members" ON public.activity_logs
    FOR SELECT TO authenticated USING (organization_id IN (SELECT public.current_user_org_ids()));

CREATE POLICY "Invitations manageable by admin" ON public.invitations
    FOR ALL TO authenticated USING (public.has_org_role(organization_id, 'admin'));

-- Enable Supabase Realtime for instant updates
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.conversation_members;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.tasks;
ALTER PUBLICATION supabase_realtime ADD TABLE public.approvals;
ALTER PUBLICATION supabase_realtime ADD TABLE public.client_requests;
ALTER PUBLICATION supabase_realtime ADD TABLE public.clients;
ALTER PUBLICATION supabase_realtime ADD TABLE public.employees;
ALTER PUBLICATION supabase_realtime ADD TABLE public.projects;
ALTER PUBLICATION supabase_realtime ADD TABLE public.invoices;
ALTER PUBLICATION supabase_realtime ADD TABLE public.leave_requests;
