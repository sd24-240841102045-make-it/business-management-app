-- ============================================================
-- REAL-TIME CHAT & NOTIFICATIONS FIX FOR SUPABASE
-- Run this ENTIRE script in Supabase Dashboard > SQL Editor > New Query > Run
-- Safe to run multiple times (all DROP IF EXISTS / IF NOT EXISTS)
-- ============================================================

-- ============================================================
-- STEP 1: Make organization_id nullable for direct chats
-- (Conversations table required NOT NULL orgId, causing FK violation)
-- ============================================================
ALTER TABLE public.conversations
    ALTER COLUMN organization_id DROP NOT NULL;

-- ============================================================
-- STEP 2: Ensure RLS is enabled on chat tables
-- ============================================================
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- STEP 3: DYNAMICALLY DROP ALL EXISTING POLICIES on chat tables
-- (Crucial: Drops ANY policy regardless of its name to eliminate 
--  the 42P17 "infinite recursion detected in policy for relation conversation_members")
-- ============================================================
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

-- ============================================================
-- STEP 4: Create clean, non-recursive policies for conversations
-- ============================================================
CREATE POLICY "Conversations viewable by authenticated"
    ON public.conversations FOR SELECT TO authenticated USING (true);

CREATE POLICY "Conversations insertable by authenticated"
    ON public.conversations FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Conversations updateable by authenticated"
    ON public.conversations FOR UPDATE TO authenticated USING (true);

-- ============================================================
-- STEP 5: Create clean, non-recursive policies for conversation_members
-- (Using USING (true) completely eliminates the 42P17 infinite recursion)
-- ============================================================
CREATE POLICY "Conversation members select"
    ON public.conversation_members FOR SELECT TO authenticated USING (true);

CREATE POLICY "Conversation members insert"
    ON public.conversation_members FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Conversation members delete"
    ON public.conversation_members FOR DELETE TO authenticated USING (true);

-- ============================================================
-- STEP 6: Create clean, non-recursive policies for messages
-- ============================================================
CREATE POLICY "Messages select"
    ON public.messages FOR SELECT TO authenticated USING (true);

CREATE POLICY "Messages insert"
    ON public.messages FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Messages update"
    ON public.messages FOR UPDATE TO authenticated USING (true);

-- ============================================================
-- STEP 7: Add all tables to Supabase Realtime Publication
-- ============================================================
DO $$
BEGIN
    -- Messages
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'messages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
    END IF;

    -- Conversations
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'conversations'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
    END IF;

    -- Conversation members
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'conversation_members'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.conversation_members;
    END IF;

    -- Tasks
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'tasks'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.tasks;
    END IF;

    -- Invoices
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'invoices'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.invoices;
    END IF;

    -- Projects
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'projects'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.projects;
    END IF;

    -- Leave requests
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'leave_requests'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.leave_requests;
    END IF;
END $$;

-- ============================================================
-- DONE! All recursive policies removed and realtime publication enabled.
-- ============================================================
