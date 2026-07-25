-- D3b Purge Pipeline & RPC Security Regression Test
-- Run against Supabase DB to verify RPC security, internal guards, and purge transition.

DO $$
DECLARE
  v_user_id uuid := gen_random_uuid();
  v_anon_can_delete boolean;
  v_auth_can_delete boolean;
  v_service_can_delete boolean;
  v_guard_caught boolean := false;
  v_status text;
BEGIN
  -- 1. VERIFY PERMISSIONS: anon and authenticated MUST NOT have EXECUTE on delete_auth_user_by_id
  SELECT has_function_privilege('anon', 'public.delete_auth_user_by_id(uuid)', 'EXECUTE') INTO v_anon_can_delete;
  SELECT has_function_privilege('authenticated', 'public.delete_auth_user_by_id(uuid)', 'EXECUTE') INTO v_auth_can_delete;
  SELECT has_function_privilege('service_role', 'public.delete_auth_user_by_id(uuid)', 'EXECUTE') INTO v_service_can_delete;

  IF v_anon_can_delete THEN
    RAISE EXCEPTION 'SECURITY FAILURE: anon role has EXECUTE on delete_auth_user_by_id';
  END IF;

  IF v_auth_can_delete THEN
    RAISE EXCEPTION 'SECURITY FAILURE: authenticated role has EXECUTE on delete_auth_user_by_id';
  END IF;

  IF NOT v_service_can_delete THEN
    RAISE EXCEPTION 'CONFIG FAILURE: service_role lacks EXECUTE on delete_auth_user_by_id';
  END IF;

  -- 2. VERIFY INTERNAL GUARD: calling delete_auth_user_by_id on non-purged user MUST FAIL
  BEGIN
    PERFORM public.delete_auth_user_by_id(v_user_id);
  EXCEPTION WHEN OTHERS THEN
    v_guard_caught := true;
  END;

  IF NOT v_guard_caught THEN
    RAISE EXCEPTION 'SECURITY FAILURE: delete_auth_user_by_id allowed execution for non-purged user';
  END IF;

  -- 3. TEST PURGE TRANSITION: Create throwaway user, request deletion, fast-forward, run purge
  INSERT INTO auth.users (
    id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, recovery_sent_at,
    last_sign_in_at, raw_app_meta_data, raw_user_meta_data, is_super_admin, created_at, updated_at
  ) VALUES (
    v_user_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
    'test-d3b-regression-check@keepsims.test', '$2a$10$abcdefghijklmnopqrstuu', now(), now(),
    now(), '{"provider":"email","providers":["email"]}', '{}', false, now(), now()
  );

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_user_id::text, 'role', 'authenticated')::text, true);

  PERFORM public.request_account_deletion('D3b Regression Test');

  UPDATE public.account_deletions
  SET scheduled_purge_at = now() - interval '1 minute'
  WHERE user_id = v_user_id;

  PERFORM public.purge_deleted_accounts();

  SELECT status INTO v_status FROM public.account_deletions WHERE user_id = v_user_id;

  IF v_status <> 'purged' THEN
    RAISE EXCEPTION 'PURGE FAILURE: account_deletions status is %, expected purged', v_status;
  END IF;

  -- Execute guarded delete_auth_user_by_id directly (valid since status = 'purged')
  PERFORM public.delete_auth_user_by_id(v_user_id);

  UPDATE public.account_deletions
  SET status = 'auth_deleted', auth_deleted_at = now()
  WHERE user_id = v_user_id;

  -- Clean up test residue
  DELETE FROM public.account_deletions WHERE user_id = v_user_id;
  DELETE FROM public.wallets WHERE user_id IS NULL AND balance = 0.00;

  RAISE NOTICE 'SUCCESS: All D3b purge pipeline & security checks passed!';
END $$;
