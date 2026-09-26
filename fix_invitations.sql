-- 1. Create a secure function to VERIFY an invitation code BEFORE sign up
-- This is public, but only returns true/false so it doesn't leak data.
CREATE OR REPLACE FUNCTION public.verify_invite_code(invite_code_param text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.invitations 
        WHERE upper(trim(token)) = upper(trim(invite_code_param)) 
          AND status = 'pending' 
          AND expires_at > now()
    );
END;
$$;

-- 1b. Create a secure function to fetch invitation details for login pre-fill
CREATE OR REPLACE FUNCTION public.get_invite_details(invite_code_param text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    invitation_record record;
    org_record record;
BEGIN
    SELECT * INTO invitation_record 
    FROM public.invitations 
    WHERE upper(trim(token)) = upper(trim(invite_code_param))
      AND status = 'pending'
      AND expires_at > now();

    IF NOT FOUND THEN
        RETURN json_build_object('valid', false);
    END IF;

    SELECT name INTO org_record FROM public.organizations WHERE id = invitation_record.organization_id;

    RETURN json_build_object(
        'valid', true,
        'email', invitation_record.email,
        'role', invitation_record.role,
        'organization_id', invitation_record.organization_id,
        'organization_name', COALESCE(org_record.name, 'Enterprise Workspace')
    );
END;
$$;

-- 2. Create a secure function to REDEEM an invitation code AFTER sign up
-- This runs as security definer to bypass RLS and securely add the member.
CREATE OR REPLACE FUNCTION public.redeem_invite_code(invite_code_param text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    invitation_record record;
    new_org_id uuid;
    assigned_role text;
    user_email text;
BEGIN
    -- 1. Ensure Caller is Authenticated
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    -- Get caller email
    SELECT email INTO user_email FROM auth.users WHERE id = auth.uid();

    -- Find and Lock the invitation
    SELECT * INTO invitation_record 
    FROM public.invitations 
    WHERE token = invite_code_param AND status = 'pending'
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid or already used invitation code.';
    END IF;

    -- Expiration Check
    IF invitation_record.expires_at < now() THEN
        RAISE EXCEPTION 'Invitation code has expired.';
    END IF;

    -- Email Matching Check
    IF lower(trim(invitation_record.email)) != lower(trim(user_email)) THEN
        RAISE EXCEPTION 'This invitation is registered to a different email address.';
    END IF;

    new_org_id := invitation_record.organization_id;
    assigned_role := invitation_record.role;

    -- Role Validation
    IF assigned_role NOT IN ('employee', 'client') THEN
        RAISE EXCEPTION 'Invalid role in invitation.';
    END IF;

    -- Duplicate Protection Check
    IF EXISTS (
        SELECT 1 FROM public.organization_memberships 
        WHERE organization_id = new_org_id AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'You are already a member of this organization.';
    END IF;

    -- Mark as used
    UPDATE public.invitations 
    SET status = 'accepted' 
    WHERE id = invitation_record.id;

    -- Insert into organization_memberships
    INSERT INTO public.organization_memberships (organization_id, user_id, role, status)
    VALUES (new_org_id, auth.uid(), assigned_role, 'active');

    -- Insert into employees if role is employee
    IF assigned_role = 'employee' THEN
        INSERT INTO public.employees (organization_id, user_id, designation, department, status)
        VALUES (new_org_id, auth.uid(), 'Staff', 'General', 'Active');
    END IF;

    -- Notify the inviter admin
    BEGIN
        INSERT INTO public.notifications (organization_id, user_id, title, body, event_type, payload)
        VALUES (
            new_org_id,
            invitation_record.invited_by,
            '🎉 Invitation Accepted!',
            COALESCE(user_email, 'A member') || ' has accepted the invite and joined as ' || assigned_role || '.',
            'invitation_accepted',
            json_build_object(
                'email', user_email,
                'role', assigned_role,
                'token', invite_code_param
            )
        );
    EXCEPTION WHEN OTHERS THEN
        NULL; -- Non-blocking
    END;

    RETURN json_build_object('success', true, 'organization_id', new_org_id, 'role', assigned_role);
END;
$$;

