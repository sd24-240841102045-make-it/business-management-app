-- ============================================================
-- SUPABASE ENTERPRISE SCALABILITY & PERFORMANCE OPTIMIZATION
-- Run this in Supabase SQL Editor to index tables and optimize queries
-- ============================================================

-- 1. NOTIFICATIONS & INVITATIONS (High frequency real-time & lookups)
CREATE INDEX IF NOT EXISTS idx_notifications_user_read_created 
    ON public.notifications(user_id, is_read, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_org_created 
    ON public.notifications(organization_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_invitations_token_status 
    ON public.invitations(upper(trim(token)), status, expires_at);

CREATE INDEX IF NOT EXISTS idx_invitations_org_email 
    ON public.invitations(organization_id, lower(trim(email)));

-- 2. TASKS & WORKFLOW (Heavy filtering by org, assignee, status)
CREATE INDEX IF NOT EXISTS idx_tasks_org_status_due 
    ON public.tasks(organization_id, status, due_date);

CREATE INDEX IF NOT EXISTS idx_tasks_assigned_org 
    ON public.tasks(assigned_to, organization_id, status);

CREATE INDEX IF NOT EXISTS idx_tasks_project_id 
    ON public.tasks(project_id);

-- 3. CLIENTS & CRM (Frequent searching by name, email, status)
ALTER TABLE public.clients ADD COLUMN IF NOT EXISTS assigned_employee_id TEXT;
ALTER TABLE public.clients ADD COLUMN IF NOT EXISTS assigned_employee_name TEXT;

CREATE INDEX IF NOT EXISTS idx_clients_org_status 
    ON public.clients(organization_id, status);

CREATE INDEX IF NOT EXISTS idx_clients_org_assigned_emp 
    ON public.clients(organization_id, assigned_employee_id);

CREATE INDEX IF NOT EXISTS idx_clients_email_lower 
    ON public.clients(lower(trim(email)));

-- 4. EMPLOYEES & ORGANIZATION MEMBERSHIPS
CREATE INDEX IF NOT EXISTS idx_employees_org_status 
    ON public.employees(organization_id, status);

CREATE INDEX IF NOT EXISTS idx_employees_user_id 
    ON public.employees(user_id);

CREATE INDEX IF NOT EXISTS idx_org_memberships_user_org 
    ON public.organization_memberships(user_id, organization_id, status);

CREATE INDEX IF NOT EXISTS idx_org_memberships_org_role 
    ON public.organization_memberships(organization_id, role);

-- 5. MESSAGING & REAL-TIME CHAT (Speed up thread loading & pagination)
CREATE INDEX IF NOT EXISTS idx_messages_conv_created 
    ON public.messages(conversation_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_conversation_members_user 
    ON public.conversation_members(user_id, conversation_id);

CREATE INDEX IF NOT EXISTS idx_conversations_org_updated 
    ON public.conversations(organization_id, updated_at DESC);

-- 6. INVOICES & BILLING
CREATE INDEX IF NOT EXISTS idx_invoices_org_status 
    ON public.invoices(organization_id, status);

CREATE INDEX IF NOT EXISTS idx_invoices_client_id 
    ON public.invoices(client_id);

-- 7. PROJECTS & LEAVES
CREATE INDEX IF NOT EXISTS idx_projects_org_status 
    ON public.projects(organization_id, status);

CREATE INDEX IF NOT EXISTS idx_leave_requests_org_status 
    ON public.leave_requests(organization_id, status);

CREATE INDEX IF NOT EXISTS idx_leave_requests_user 
    ON public.leave_requests(user_id, created_at DESC);

-- 8. QUERY PERFORMANCE: ANALYZE TABLES
ANALYZE public.notifications;
ANALYZE public.invitations;
ANALYZE public.tasks;
ANALYZE public.clients;
ANALYZE public.employees;
ANALYZE public.organization_memberships;
ANALYZE public.messages;
ANALYZE public.conversations;
ANALYZE public.invoices;
ANALYZE public.projects;
ANALYZE public.leave_requests;
