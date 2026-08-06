
CREATE TABLE IF NOT EXISTS public.employees (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    role TEXT NOT NULL,
    department TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT NOT NULL,
    avatar_url TEXT DEFAULT '',
    status TEXT NOT NULL DEFAULT 'Active',
    joining_date TEXT NOT NULL,
    assigned_client_ids JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.clients (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    company TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'Active',
    assigned_employee_id TEXT,
    assigned_employee_name TEXT,
    project_type TEXT DEFAULT 'General Consulting',
    budget NUMERIC DEFAULT 0.0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.leave_requests (
    id TEXT PRIMARY KEY,
    employee_id TEXT NOT NULL,
    employee_name TEXT NOT NULL,
    type TEXT NOT NULL,
    start_date TEXT NOT NULL,
    end_date TEXT NOT NULL,
    reason TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'Pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leave_requests ENABLE ROW LEVEL SECURITY;


CREATE POLICY "Allow public select on employees" ON public.employees FOR SELECT USING (true);
CREATE POLICY "Allow public insert on employees" ON public.employees FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update on employees" ON public.employees FOR UPDATE USING (true);
CREATE POLICY "Allow public delete on employees" ON public.employees FOR DELETE USING (true);

CREATE POLICY "Allow public select on clients" ON public.clients FOR SELECT USING (true);
CREATE POLICY "Allow public insert on clients" ON public.clients FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update on clients" ON public.clients FOR UPDATE USING (true);
CREATE POLICY "Allow public delete on clients" ON public.clients FOR DELETE USING (true);

CREATE POLICY "Allow public select on leave_requests" ON public.leave_requests FOR SELECT USING (true);
CREATE POLICY "Allow public insert on leave_requests" ON public.leave_requests FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update on leave_requests" ON public.leave_requests FOR UPDATE USING (true);
CREATE POLICY "Allow public delete on leave_requests" ON public.leave_requests FOR DELETE USING (true);

-- ============================================================
-- SUPABASE AUTHENTICATION & ROLE MANAGEMENT NOTES
-- ============================================================
-- Users registering via the app have their role stored in Supabase Auth user_metadata:
--   - Admin / Staff Users: raw_user_meta_data = '{"role": "admin", "full_name": "..."}'
--   - Client Users: raw_user_meta_data = '{"role": "client", "full_name": "...", "company": "..."}'
--
-- Upon signup, user profiles are automatically synced into:
--   - public.employees (for admin role)
--   - public.clients (for client role)

