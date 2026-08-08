-- ============================================================
-- RESET SCRIPT - Run this FIRST, then run supabase_schema.sql
-- WARNING: This drops ALL data. Only use in development.
-- ============================================================

-- 1. Drop trigger first (depends on function)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 2. Drop all tables (CASCADE handles foreign keys and policies automatically)
DROP TABLE IF EXISTS public.invoice_items CASCADE;
DROP TABLE IF EXISTS public.payments CASCADE;
DROP TABLE IF EXISTS public.invoices CASCADE;
DROP TABLE IF EXISTS public.task_comments CASCADE;
DROP TABLE IF EXISTS public.client_requests CASCADE;
DROP TABLE IF EXISTS public.approvals CASCADE;
DROP TABLE IF EXISTS public.timesheets CASCADE;
DROP TABLE IF EXISTS public.attendance CASCADE;
DROP TABLE IF EXISTS public.leave_requests CASCADE;
DROP TABLE IF EXISTS public.messages CASCADE;
DROP TABLE IF EXISTS public.conversation_members CASCADE;
DROP TABLE IF EXISTS public.conversations CASCADE;
DROP TABLE IF EXISTS public.activity_logs CASCADE;
DROP TABLE IF EXISTS public.notifications CASCADE;
DROP TABLE IF EXISTS public.invitations CASCADE;
DROP TABLE IF EXISTS public.tasks CASCADE;
DROP TABLE IF EXISTS public.project_members CASCADE;
DROP TABLE IF EXISTS public.projects CASCADE;
DROP TABLE IF EXISTS public.employees CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.organization_memberships CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;
DROP TABLE IF EXISTS public.organizations CASCADE;
DROP TABLE IF EXISTS public.subscription_plans CASCADE;

-- 3. Drop all functions
DROP FUNCTION IF EXISTS public.current_user_org_ids();
DROP FUNCTION IF EXISTS public.has_org_role(UUID, TEXT);
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS public.get_my_memberships();
DROP FUNCTION IF EXISTS public.verify_invite_code(TEXT);
DROP FUNCTION IF EXISTS public.redeem_invite_code(TEXT);
