-- ============================================================================
-- H8 — Household & Family: security hardening + invite lifecycle repair.
--
-- The feature was re-enabled in the UI on 2026-08-04 after a period behind a
-- comment block. Turning it back on surfaced three defects that made it unsafe
-- and, for the most common case, non-functional:
--
--   1. PRIVILEGE ESCALATION. `authenticated` holds a column-level UPDATE grant
--      on every column of `household_members`, and the policy
--      "Members can update their invite status" scoped rows only by
--      `auth.uid() = member_id` — it did not scope COLUMNS. A member therefore
--      owned their own row outright. Proven against this database on
--      2026-08-04: an accepted VIEWER ran
--          UPDATE household_members SET role='manager' WHERE id=<own row>;
--          UPDATE household_members SET monthly_cap_usd=9999 WHERE id=<own row>;
--      and both succeeded. `role='manager'` is the gate on `request_instant_refill`,
--      on the sim_lines UPDATE policy, and on G6 wallet spending — so any invited
--      person could promote themselves and then spend the OWNER's wallet up to
--      the $100,000 CHECK ceiling. The cap trigger did not stop it: it only
--      refuses `cap > 0 AND role <> 'manager'`, and escalating role first
--      satisfies it.
--
--   2. DEAD INVITES. `handle_new_household_member` resolves `member_id` from
--      `profiles` at INSERT time. Invite someone who has not signed up yet —
--      the entire point of a family invite — and `member_id` stays NULL. The
--      member-side SELECT policy keys on `member_id`, so the invite is
--      invisible; nothing back-fills it at signup, so it stays invisible
--      forever. The invitee installs the app, registers, and sees nothing.
--
--   3. SILENT NO-OP ON LEAVE. Members have SELECT and UPDATE policies but no
--      DELETE policy, and the client called `.delete()` directly. PostgREST
--      reports zero deleted rows as success, so "Leave Household" showed a
--      success toast and changed nothing.
--
-- The shape of the fix: members get NO direct write path to this table at all.
-- Every member-side mutation goes through a SECURITY DEFINER RPC that decides
-- what may change. Owners keep their existing policy — it is correctly scoped —
-- and gain an invite RPC so the duplicate check stops being a client-side race.
--
-- Safe to apply: `household_members` is empty (0 rows) as of 2026-08-04.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- 1. Close the escalation hole.
--
-- Dropping the policy is the fix, not narrowing it. A column-level GRANT is
-- role-wide, so it cannot separate "owner may change role" from "member may
-- not" — both are `authenticated`. The only way to let owners keep direct
-- writes while members get none is to remove the member's write policy and
-- give members RPCs instead.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Members can update their invite status" ON public.household_members;

-- `anon` was carrying INSERT/UPDATE/SELECT on this table. Nothing unauthenticated
-- has any business here; RLS happened to block it (every policy compares against
-- a NULL `auth.uid()`), but the grant should never have been there.
REVOKE ALL ON TABLE public.household_members FROM anon;


-- ---------------------------------------------------------------------------
-- 2. Make a pending invite visible before the invitee has an account linked.
--
-- Matching on the JWT email as well as on `member_id` is what lets somebody who
-- signed up AFTER being invited actually see the invitation. The back-fill in
-- section 6 handles the same case for sessions that never re-read the JWT.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Members can view their invites" ON public.household_members;
CREATE POLICY "Members can view their invites"
  ON public.household_members
  FOR SELECT
  TO authenticated
  USING (
    (
      auth.uid() = member_id
      OR lower(member_email) = lower(auth.jwt() ->> 'email')
    )
    AND NOT is_user_suspended()
  );


-- ---------------------------------------------------------------------------
-- 3. `member_id` must always be the account that owns `member_email`.
--
-- Without this an owner could point `member_id` at any uuid and hand a stranger
-- read access to their own lines (and, with a cap, their wallet). Stating it as
-- a table invariant avoids a `current_user`-inside-DEFINER check, which this
-- codebase has got wrong before.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_fn_household_member_id_matches_email()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $fn$
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.owner_id IS DISTINCT FROM OLD.owner_id THEN
    RAISE EXCEPTION 'A household membership cannot change owner'
      USING ERRCODE = 'KS403';
  END IF;

  IF NEW.member_id IS NOT NULL
     AND (TG_OP = 'INSERT' OR NEW.member_id IS DISTINCT FROM OLD.member_id)
     AND NOT EXISTS (
       SELECT 1 FROM public.profiles p
        WHERE p.id = NEW.member_id
          AND lower(p.email) = lower(NEW.member_email)
     )
  THEN
    RAISE EXCEPTION 'member_id must be the account registered to %', NEW.member_email
      USING ERRCODE = 'KS403';
  END IF;

  RETURN NEW;
END $fn$;

DROP TRIGGER IF EXISTS trg_household_member_id_matches_email ON public.household_members;
CREATE TRIGGER trg_household_member_id_matches_email
  BEFORE INSERT OR UPDATE ON public.household_members
  FOR EACH ROW EXECUTE FUNCTION public.trg_fn_household_member_id_matches_email();


-- ---------------------------------------------------------------------------
-- 4. Owner sends an invite.
--
-- SECURITY DEFINER, because it writes a `notifications` row for the invitee and
-- the owner cannot insert into another user's notifications. `owner_id` is
-- taken from `auth.uid()` and never from the caller, so DEFINER buys no
-- authority the caller did not already have.
--
-- The duplicate check moves server-side: the old client-side SELECT-then-INSERT
-- raced, and the UNIQUE (owner_id, member_email) violation surfaced as a raw
-- Postgres error string.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.invite_household_member(
  p_email text,
  p_role  text DEFAULT 'viewer'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_actor    uuid := auth.uid();
  v_email    text := lower(trim(coalesce(p_email, '')));
  v_role     text := lower(trim(coalesce(p_role, 'viewer')));
  v_owner_nm text;
  v_invitee  uuid;
  v_row      RECORD;
BEGIN
  IF v_actor IS NULL THEN
    RETURN jsonb_build_object('success', false, 'code', 'UNAUTHORIZED',
      'error', 'Please sign in again.');
  END IF;

  IF is_user_suspended() THEN
    RETURN jsonb_build_object('success', false, 'code', 'SUSPENDED',
      'error', 'Your account is suspended. Invitations are disabled.');
  END IF;

  IF v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' THEN
    RETURN jsonb_build_object('success', false, 'code', 'INVALID_EMAIL',
      'error', 'That does not look like an email address.');
  END IF;

  IF v_role NOT IN ('viewer', 'manager') THEN
    RETURN jsonb_build_object('success', false, 'code', 'INVALID_ROLE',
      'error', 'Choose either the viewer or the manager role.');
  END IF;

  IF v_email = lower(auth.jwt() ->> 'email') THEN
    RETURN jsonb_build_object('success', false, 'code', 'SELF_INVITE',
      'error', 'You are already the owner of this household.');
  END IF;

  SELECT id INTO v_invitee FROM public.profiles WHERE lower(email) = v_email;

  INSERT INTO public.household_members (owner_id, member_email, role, invite_status)
  VALUES (v_actor, v_email, v_role, 'pending')
  ON CONFLICT (owner_id, member_email) DO NOTHING
  RETURNING id, member_email, role INTO v_row;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'code', 'ALREADY_INVITED',
      'error', 'You have already invited this person. Remove them first to send a new invitation.');
  END IF;

  -- Tell the invitee, if they already have an account. If they do not, the
  -- back-fill in section 6 surfaces the invite the moment they register.
  IF v_invitee IS NOT NULL THEN
    SELECT nullif(trim(full_name), '') INTO v_owner_nm
      FROM public.profiles WHERE id = v_actor;

    INSERT INTO public.notifications (user_id, category, title, body, action_url)
    VALUES (
      v_invitee,
      'system',
      'Family invitation',
      coalesce(v_owner_nm, 'Someone') || ' invited you to join their household on KeepSIMs.',
      '/settings/household'
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'id', v_row.id,
    'member_email', v_row.member_email,
    'role', v_row.role,
    'invitee_has_account', v_invitee IS NOT NULL
  );
END $fn$;

COMMENT ON FUNCTION public.invite_household_member(text, text) IS
  'H8: owner invites a family member by email. owner_id is taken from auth.uid(); DEFINER only so the invitee gets a notification row.';

REVOKE ALL     ON FUNCTION public.invite_household_member(text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.invite_household_member(text, text) TO authenticated, service_role;


-- ---------------------------------------------------------------------------
-- 5. Member accepts or declines.
--
-- This is the call that replaces the dropped member UPDATE policy. It changes
-- exactly three columns and nothing else — in particular it cannot touch `role`
-- or `monthly_cap_usd`, which is the whole point.
--
-- The invite is matched by JWT email as well as by `member_id`, so an invite
-- issued before the invitee registered is claimable.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.respond_to_household_invite(
  p_invite_id uuid,
  p_accept    boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_actor uuid := auth.uid();
  v_email text := lower(auth.jwt() ->> 'email');
  v_name  text;
  v_row   RECORD;
BEGIN
  IF v_actor IS NULL THEN
    RETURN jsonb_build_object('success', false, 'code', 'UNAUTHORIZED',
      'error', 'Please sign in again.');
  END IF;

  IF is_user_suspended() THEN
    RETURN jsonb_build_object('success', false, 'code', 'SUSPENDED',
      'error', 'Your account is suspended.');
  END IF;

  SELECT * INTO v_row
    FROM public.household_members
   WHERE id = p_invite_id
     AND invite_status = 'pending'
     AND (member_id = v_actor OR lower(member_email) = v_email)
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'code', 'NOT_FOUND',
      'error', 'That invitation is no longer available. It may have been withdrawn.');
  END IF;

  IF v_row.owner_id = v_actor THEN
    RETURN jsonb_build_object('success', false, 'code', 'SELF_INVITE',
      'error', 'You cannot join your own household.');
  END IF;

  UPDATE public.household_members
     SET invite_status = CASE WHEN p_accept THEN 'accepted' ELSE 'declined' END,
         member_id     = v_actor,
         accepted_at   = CASE WHEN p_accept THEN now() ELSE NULL END
   WHERE id = p_invite_id;

  SELECT nullif(trim(full_name), '') INTO v_name FROM public.profiles WHERE id = v_actor;

  INSERT INTO public.notifications (user_id, category, title, body, action_url)
  VALUES (
    v_row.owner_id,
    'system',
    CASE WHEN p_accept THEN 'Family invitation accepted' ELSE 'Family invitation declined' END,
    coalesce(v_name, v_row.member_email)
      || CASE WHEN p_accept
              THEN ' joined your household.'
              ELSE ' declined your household invitation.' END,
    '/settings/household'
  );

  RETURN jsonb_build_object('success', true, 'accepted', p_accept, 'role', v_row.role);
END $fn$;

COMMENT ON FUNCTION public.respond_to_household_invite(uuid, boolean) IS
  'H8: member accepts/declines an invitation. Replaces the dropped member UPDATE policy — touches only invite_status, member_id, accepted_at.';

REVOKE ALL     ON FUNCTION public.respond_to_household_invite(uuid, boolean) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.respond_to_household_invite(uuid, boolean) TO authenticated, service_role;


-- ---------------------------------------------------------------------------
-- 6. Member leaves a household.
--
-- Members have no DELETE policy, which is why the old client-side `.delete()`
-- was a silent no-op reported to the user as success.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.leave_household(p_membership_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_actor uuid := auth.uid();
  v_row   RECORD;
  v_name  text;
BEGIN
  IF v_actor IS NULL THEN
    RETURN jsonb_build_object('success', false, 'code', 'UNAUTHORIZED',
      'error', 'Please sign in again.');
  END IF;

  DELETE FROM public.household_members
   WHERE id = p_membership_id
     AND member_id = v_actor
  RETURNING owner_id, member_email INTO v_row;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'code', 'NOT_FOUND',
      'error', 'You are not a member of that household.');
  END IF;

  SELECT nullif(trim(full_name), '') INTO v_name FROM public.profiles WHERE id = v_actor;

  INSERT INTO public.notifications (user_id, category, title, body, action_url)
  VALUES (
    v_row.owner_id,
    'system',
    'Family member left',
    coalesce(v_name, v_row.member_email) || ' left your household.',
    '/settings/household'
  );

  RETURN jsonb_build_object('success', true);
END $fn$;

COMMENT ON FUNCTION public.leave_household(uuid) IS
  'H8: member removes their own membership. Members have no DELETE policy, so this RPC is the only way out.';

REVOKE ALL     ON FUNCTION public.leave_household(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.leave_household(uuid) TO authenticated, service_role;


-- ---------------------------------------------------------------------------
-- 7. Back-fill `member_id` at signup — the fix for dead invites.
--
-- `handle_new_household_member` resolves the invitee at INSERT time only. This
-- closes the other direction: register with an email that was already invited
-- and the invitation binds to the new account immediately.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.claim_pending_household_invites()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF NEW.email IS NULL OR trim(NEW.email) = '' THEN
    RETURN NEW;
  END IF;

  UPDATE public.household_members
     SET member_id = NEW.id
   WHERE member_id IS NULL
     AND lower(member_email) = lower(NEW.email)
     AND owner_id <> NEW.id;

  RETURN NEW;
END $fn$;

DROP TRIGGER IF EXISTS trg_profiles_claim_household_invites ON public.profiles;
CREATE TRIGGER trg_profiles_claim_household_invites
  AFTER INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.claim_pending_household_invites();

-- A function's default ACL is EXECUTE TO PUBLIC, so a SECURITY DEFINER trigger
-- function is callable by anon unless revoked — the exact hole F6's migration
-- 20260717000200 and H5c both closed. Revoking does not stop the trigger:
-- privilege is checked at CREATE TRIGGER, not at fire time.
REVOKE ALL ON FUNCTION public.claim_pending_household_invites()          FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_pending_household_invites()       TO service_role;
REVOKE ALL ON FUNCTION public.trg_fn_household_member_id_matches_email() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.trg_fn_household_member_id_matches_email() TO service_role;

-- Same back-fill for any invite already sitting unclaimed.
UPDATE public.household_members hm
   SET member_id = p.id
  FROM public.profiles p
 WHERE hm.member_id IS NULL
   AND lower(p.email) = lower(hm.member_email)
   AND hm.owner_id <> p.id;
