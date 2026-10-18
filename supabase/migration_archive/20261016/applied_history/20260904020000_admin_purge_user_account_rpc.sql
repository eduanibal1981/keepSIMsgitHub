-- Admin Purge User Account with strict typed User ID challenge and Vault internal secret
CREATE OR REPLACE FUNCTION public.admin_purge_user_account(
  p_user_id        uuid,
  p_confirm_user_id text,
  p_reason         text DEFAULT 'Manual admin purge with user_id verification challenge'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_admin_id uuid;
  v_secret   text;
  v_req_id   bigint;
BEGIN
  -- 1. Assert admin authorization
  v_admin_id := public.assert_admin();

  -- 2. Strict Confirmation Challenge: confirm_user_id must match p_user_id
  IF p_confirm_user_id IS NULL OR lower(trim(p_confirm_user_id)) <> lower(p_user_id::text) THEN
    RAISE EXCEPTION 'Confirmation failed: Typed user ID does not match target user ID'
      USING ERRCODE = 'KS400',
            HINT = 'You must type the exact UUID of the user to confirm this destructive purge.';
  END IF;

  -- 3. Read internal secret from Vault
  SELECT decrypted_secret INTO v_secret
    FROM vault.decrypted_secrets WHERE name = 'dispatch_shared_secret';
  IF COALESCE(v_secret, '') = '' THEN
    RAISE EXCEPTION 'Internal dispatch_shared_secret missing from Vault'
      USING ERRCODE = 'KS500';
  END IF;

  -- 4. Mark or insert account_deletions row with status 'purged'
  INSERT INTO public.account_deletions (
    user_id, status, requested_at, purged_at, de_identified_at, note
  )
  VALUES (
    p_user_id, 'purged', pg_catalog.now(), pg_catalog.now(), pg_catalog.now(),
    'Manual admin purge: ' || COALESCE(p_reason, 'No reason specified')
  )
  ON CONFLICT (user_id) DO UPDATE SET
    status = 'purged',
    purged_at = pg_catalog.now(),
    note = 'Manual admin purge: ' || COALESCE(p_reason, 'No reason specified');

  -- 5. Trigger purge-accounts Edge Function via pg_net
  SELECT net.http_post(
    url := 'https://zwxswagokhgbuzrrbnhr.supabase.co/functions/v1/purge-accounts',
    headers := pg_catalog.jsonb_build_object(
      'Content-Type', 'application/json',
      'x-keep-sims-secret', v_secret
    ),
    body := pg_catalog.jsonb_build_object(
      'user_id', p_user_id,
      'admin_purge', true,
      'confirm_user_id', p_user_id::text,
      'reason', p_reason
    ),
    timeout_milliseconds := 15000
  ) INTO v_req_id;

  -- 6. Audit in admin_audit_log
  PERFORM public.admin_log(
    'user.admin_purge',
    'user',
    p_user_id::text,
    pg_catalog.jsonb_build_object('admin_id', v_admin_id),
    pg_catalog.jsonb_build_object('net_request_id', v_req_id, 'status', 'purged'),
    p_reason
  );

  RETURN pg_catalog.jsonb_build_object(
    'status', 'ok',
    'user_id', p_user_id,
    'net_request_id', v_req_id,
    'message', 'Purge initiated successfully with confirmation challenge'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_purge_user_account(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_purge_user_account(uuid, text, text) TO authenticated, service_role;
