-- ============================================================================
-- F3 + F4: lock down the remaining anon-callable SECURITY DEFINER RPCs
--
-- Findings F-3 and F-4 (doc/PRODUCTION_PLAN_REVIEW.md § 1), all re-verified live
-- on 2026-07-29 with nothing but the anon key that ships inside the APK:
--
--   POST /rest/v1/rpc/purge_deleted_accounts   -> HTTP 200
--   POST /rest/v1/rpc/consume_rate_limit       -> [{"allowed":true,...}]
--   POST /rest/v1/rpc/enforce_rate_limit       -> KS429 (i.e. it ran and drained a bucket)
--   POST /rest/v1/rpc/prune_rate_limit_data    -> HTTP 204
--   POST /rest/v1/rpc/check_rate_limit_health  -> HTTP 204
--   POST /rest/v1/rpc/apply_referral           -> {"success": true}   <-- see below
--
-- Every one of these had the Postgres default ACL
--   {=X/postgres, anon=X/postgres, authenticated=X/postgres, service_role=X/postgres}
-- because Supabase blanket-grants EXECUTE on new public functions and
-- `GRANT ... TO service_role` does not remove that. Only a REVOKE does.
--
-- Worst of the set is the rate limiter: consume_rate_limit takes the bucket AND
-- the key from the caller, so an unauthenticated attacker could spend another
-- user's tokens and lock them out of instant_refill, esim_purchase, plan_fee and
-- wallet_deduct — D2's own limiter turned into a denial-of-service weapon.
--
-- ---------------------------------------------------------------------------
-- Two guard shapes, because the callers differ. Get this wrong and you either
-- ship dead code or break production.
-- ---------------------------------------------------------------------------
--
-- (a) CRON-ONLY functions — purge_deleted_accounts, prune_rate_limit_data,
--     check_rate_limit_health. Their only callers are cron.job 10, 12 and 11,
--     which run with no JWT at all. Nothing in lib/, servers/ or
--     supabase/functions/ calls them. So the F-1 shape applies: if a JWT is
--     present at all and its role is not service_role, refuse.
--
-- (b) NESTED-CALLER functions — consume_rate_limit, enforce_rate_limit. These
--     are the F-2 situation and a naive role check WOULD break every money path:
--
--       enforce_rate_limit is called from inside export_user_data,
--       pay_plan_fee_from_wallet, redeem_referral_points,
--       request_account_deletion, request_esim_purchase and
--       request_instant_refill — all user-facing RPCs, so request.jwt.claims
--       still reads role=authenticated in those nested calls.
--
--       consume_rate_limit is called nested from apply_referral and
--       enforce_rate_limit, AND top-level over REST as service_role by five
--       Edge Functions: create-paypal-order:63, capture-paypal-order:61,
--       detect-country:102, paypal-webhook:346, sms-webhook:81 (all verified to
--       use SUPABASE_SERVICE_ROLE_KEY).
--
--     So the discriminator is plpgsql call depth (GET DIAGNOSTICS PG_CONTEXT),
--     exactly as in 20260801050000: a PostgREST RPC is always the top frame, an
--     internal call never is. service_role is allowed at any depth (the Edge
--     Functions), anyone is allowed when nested (the money RPCs), and only a
--     non-service_role JWT at the top frame is refused.
--
-- ---------------------------------------------------------------------------
-- 🔴 A separate live hole found while verifying F-4: apply_referral
-- ---------------------------------------------------------------------------
-- Its ownership check read:
--
--     IF auth.uid() IS NOT NULL AND auth.uid() <> p_referred_id THEN ... UNAUTHORIZED
--
-- As anon, auth.uid() is NULL, so the check was skipped entirely and
-- p_referred_id — the account being modified — was caller-chosen. Proven in a
-- rolled-back transaction against a real user who had no referrer:
--
--     victim referred_by BEFORE  <null>
--     anon apply_referral        {"success": true}
--     victim referred_by AFTER   SS2A150D18      referrals rows 0 -> 1
--
-- That is an unauthenticated write to another user's profile, and it is a money
-- path: trg_fn_award_referral_points awards the referrer a point per plan-fee
-- payment and redeem_referral_points converts 10 points into $2.00 of real
-- wallet credit via credit_wallet_for_deposit. Fixed here by requiring a
-- session: auth.uid() IS NULL OR auth.uid() <> p_referred_id.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- (a) CRON-ONLY — F-1 guard shape
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.purge_deleted_accounts()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_raw_claims text;
  v_jwt_role text;
  rec RECORD;
  v_wallet RECORD;
  v_in_flight_count int;
  v_secret text;
  v_purged_count int := 0;
  v_ref_code text;
BEGIN
  -- Layer 2. Callers are cron only (no JWT). Any JWT-bearing caller that is not
  -- service_role is a client reaching in over PostgREST — refuse. A malformed
  -- claims blob fails closed at the cast, before any row is touched.
  v_raw_claims := current_setting('request.jwt.claims', true);
  IF v_raw_claims IS NOT NULL AND v_raw_claims <> '' THEN
    v_jwt_role := (v_raw_claims::jsonb) ->> 'role';
    IF v_jwt_role IS DISTINCT FROM 'service_role' THEN
      RAISE EXCEPTION 'purge_deleted_accounts is not callable by role %', COALESCE(v_jwt_role, '<none>')
        USING ERRCODE = 'KS403';
    END IF;
  END IF;

  UPDATE public.account_deletions
  SET status = 'frozen', frozen_at = clock_timestamp(), updated_at = clock_timestamp()
  WHERE status = 'requested' AND scheduled_purge_at <= clock_timestamp();

  FOR rec IN SELECT * FROM public.account_deletions WHERE status IN ('frozen', 'draining') LOOP
    SELECT COUNT(*) INTO v_in_flight_count
    FROM public.topup_executions
    WHERE user_id = rec.user_id AND status = 'routing';

    IF v_in_flight_count = 0 THEN
      SELECT COUNT(*) INTO v_in_flight_count
      FROM public.esim_orders
      WHERE user_id = rec.user_id AND status IN ('pending', 'processing');
    END IF;

    IF v_in_flight_count > 0 THEN
      IF rec.scheduled_purge_at < (clock_timestamp() - INTERVAL '72 hours') THEN
        INSERT INTO public.system_alerts (kind, message, details)
        VALUES (
          'account_purge_stuck',
          'Account deletion stuck in draining state >72h for user ' || rec.user_id::text,
          jsonb_build_object('user_id', rec.user_id, 'in_flight_count', v_in_flight_count)
        );
      END IF;
      CONTINUE;
    END IF;

    UPDATE public.account_deletions
    SET status = 'draining', drained_at = COALESCE(drained_at, clock_timestamp()), updated_at = clock_timestamp()
    WHERE id = rec.id;

    SELECT referral_code INTO v_ref_code FROM public.profiles WHERE id = rec.user_id;
    IF v_ref_code IS NOT NULL AND length(trim(v_ref_code)) > 0 THEN
      INSERT INTO public.retired_referral_codes (code) VALUES (upper(trim(v_ref_code)))
      ON CONFLICT DO NOTHING;
    END IF;

    FOR v_wallet IN SELECT * FROM public.wallets WHERE user_id = rec.user_id LOOP
      IF v_wallet.balance <> 0 THEN
        INSERT INTO public.wallet_transactions (
          wallet_id, user_id, amount, balance_before, balance_after, type, description, reference_id
        ) VALUES (
          v_wallet.id, rec.user_id, v_wallet.balance, v_wallet.balance, 0.00,
          CASE WHEN rec.dust_forfeited THEN 'wallet_forfeit' ELSE 'wallet_settlement' END,
          'Account purge wallet balance zeroing',
          'purge_' || rec.id
        );
      END IF;
      UPDATE public.wallets SET balance = 0.00, user_id = NULL WHERE id = v_wallet.id;
    END LOOP;

    UPDATE public.referral_points
    SET sim_line_id = NULL
    WHERE sim_line_id IN (SELECT id FROM public.sim_lines WHERE user_id = rec.user_id);

    UPDATE public.wallet_transactions SET user_id = NULL WHERE user_id = rec.user_id;
    UPDATE public.plan_payments SET user_id = NULL WHERE user_id = rec.user_id;
    UPDATE public.esim_orders SET user_id = NULL WHERE user_id = rec.user_id;
    UPDATE public.user_esims SET user_id = NULL WHERE user_id = rec.user_id;
    UPDATE public.topup_executions SET user_id = NULL WHERE user_id = rec.user_id;

    DELETE FROM public.line_activity_log WHERE sim_line_id IN (SELECT id FROM public.sim_lines WHERE user_id = rec.user_id);
    DELETE FROM public.scheduled_topups WHERE sim_line_id IN (SELECT id FROM public.sim_lines WHERE user_id = rec.user_id);
    DELETE FROM public.offline_refill_settings WHERE user_id = rec.user_id;
    DELETE FROM public.sim_lines WHERE user_id = rec.user_id;
    DELETE FROM public.ticket_messages WHERE user_id = rec.user_id OR ticket_id IN (SELECT id FROM public.support_tickets WHERE user_id = rec.user_id);
    DELETE FROM public.support_tickets WHERE user_id = rec.user_id;
    DELETE FROM public.alert_settings WHERE user_id = rec.user_id;
    DELETE FROM public.notification_channels WHERE user_id = rec.user_id;
    DELETE FROM public.notifications WHERE user_id = rec.user_id;
    DELETE FROM public.device_push_tokens WHERE user_id = rec.user_id;
    DELETE FROM public.user_consents WHERE user_id = rec.user_id;

    UPDATE public.account_deletions
    SET status = 'purged', purged_at = clock_timestamp(), updated_at = clock_timestamp()
    WHERE id = rec.id;

    v_purged_count := v_purged_count + 1;

    SELECT decrypted_secret INTO v_secret
    FROM vault.decrypted_secrets WHERE name = 'dispatch_shared_secret' LIMIT 1;

    PERFORM net.http_post(
      url := 'https://zwxswagokhgbuzrrbnhr.supabase.co/functions/v1/purge-accounts',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-keep-sims-secret', COALESCE(v_secret, '')
      ),
      body := jsonb_build_object('user_id', rec.user_id)
    );
  END LOOP;

  RETURN jsonb_build_object('success', true, 'purged_count', v_purged_count);
END;
$function$;


CREATE OR REPLACE FUNCTION public.prune_rate_limit_data()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_raw_claims text;
  v_jwt_role text;
BEGIN
  v_raw_claims := current_setting('request.jwt.claims', true);
  IF v_raw_claims IS NOT NULL AND v_raw_claims <> '' THEN
    v_jwt_role := (v_raw_claims::jsonb) ->> 'role';
    IF v_jwt_role IS DISTINCT FROM 'service_role' THEN
      RAISE EXCEPTION 'prune_rate_limit_data is not callable by role %', COALESCE(v_jwt_role, '<none>')
        USING ERRCODE = 'KS403';
    END IF;
  END IF;

  DELETE FROM public.security_logs
  WHERE created_at < NOW() - INTERVAL '90 days';

  DELETE FROM public.rate_limit_buckets
  WHERE updated_at < NOW() - INTERVAL '7 days';
END;
$function$;


CREATE OR REPLACE FUNCTION public.check_rate_limit_health()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_raw_claims text;
  v_jwt_role text;
  v_count int;
BEGIN
  v_raw_claims := current_setting('request.jwt.claims', true);
  IF v_raw_claims IS NOT NULL AND v_raw_claims <> '' THEN
    v_jwt_role := (v_raw_claims::jsonb) ->> 'role';
    IF v_jwt_role IS DISTINCT FROM 'service_role' THEN
      RAISE EXCEPTION 'check_rate_limit_health is not callable by role %', COALESCE(v_jwt_role, '<none>')
        USING ERRCODE = 'KS403';
    END IF;
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM public.security_logs
  WHERE event_type = 'rate_limited'
    AND created_at > (NOW() - INTERVAL '1 hour');

  IF v_count >= 20 THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.system_alerts
      WHERE kind = 'sustained_rate_limits'
        AND created_at > (NOW() - INTERVAL '6 hours')
    ) THEN
      INSERT INTO public.system_alerts (kind, severity, title, details)
      VALUES (
        'sustained_rate_limits',
        'warning',
        'Sustained Rate Limit Rejections',
        jsonb_build_object('rejections_past_hour', v_count)
      );
    END IF;
  END IF;
END;
$function$;


-- ---------------------------------------------------------------------------
-- (b) NESTED-CALLER — F-2 call-depth guard shape
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.consume_rate_limit(
  p_bucket text,
  p_key text,
  p_capacity integer,
  p_refill_per_minute numeric,
  p_now timestamp with time zone DEFAULT clock_timestamp()
)
RETURNS TABLE(allowed boolean, retry_after_seconds integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_raw_claims text;
  v_jwt_role text;
  v_ctx text;
  v_tokens numeric;
  v_updated_at timestamptz;
  v_elapsed numeric;
  v_refill numeric;
  v_new_tokens numeric;
  v_needed numeric;
  v_retry_sec int;
BEGIN
  -- Layer 2. service_role is allowed at any depth (the five Edge Functions call
  -- this top-level over REST). Anyone is allowed when nested, because the caller
  -- above chose the bucket and key server-side. Only a non-service_role JWT at
  -- the top frame — i.e. a client hand-picking someone else's bucket — is
  -- refused. Depth is the discriminator: a PostgREST RPC is always frame 1.
  v_raw_claims := current_setting('request.jwt.claims', true);
  IF v_raw_claims IS NOT NULL AND v_raw_claims <> '' THEN
    v_jwt_role := (v_raw_claims::jsonb) ->> 'role';
    IF v_jwt_role IS DISTINCT FROM 'service_role' THEN
      GET DIAGNOSTICS v_ctx = PG_CONTEXT;
      IF coalesce(array_length(string_to_array(v_ctx, E'\n'), 1), 1) < 2 THEN
        RAISE EXCEPTION 'consume_rate_limit is not directly callable by role %', COALESCE(v_jwt_role, '<none>')
          USING ERRCODE = 'KS403';
      END IF;
    END IF;
  END IF;

  IF p_key IS NULL OR p_key = '' THEN
    RETURN QUERY SELECT true, 0;
    RETURN;
  END IF;

  p_bucket := LOWER(p_bucket);

  SELECT tokens, updated_at INTO v_tokens, v_updated_at
  FROM public.rate_limit_buckets
  WHERE bucket = p_bucket AND key = p_key
  FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.rate_limit_buckets (bucket, key, tokens, updated_at)
    VALUES (p_bucket, p_key, GREATEST(0, p_capacity - 1), p_now)
    ON CONFLICT (bucket, key) DO UPDATE
      SET tokens = EXCLUDED.tokens, updated_at = EXCLUDED.updated_at;

    RETURN QUERY SELECT true, 0;
    RETURN;
  END IF;

  v_elapsed := GREATEST(0, EXTRACT(EPOCH FROM (p_now - v_updated_at)));
  v_refill := v_elapsed * (p_refill_per_minute / 60.0);
  v_new_tokens := LEAST(p_capacity::numeric, v_tokens + v_refill);

  IF v_new_tokens >= 1.0 THEN
    UPDATE public.rate_limit_buckets
    SET tokens = v_new_tokens - 1.0, updated_at = p_now
    WHERE bucket = p_bucket AND key = p_key;

    RETURN QUERY SELECT true, 0;
  ELSE
    v_needed := 1.0 - v_new_tokens;
    IF p_refill_per_minute > 0 THEN
      v_retry_sec := GREATEST(1, CEIL(v_needed / (p_refill_per_minute / 60.0))::int);
    ELSE
      v_retry_sec := 60;
    END IF;

    UPDATE public.rate_limit_buckets
    SET tokens = v_new_tokens, updated_at = p_now
    WHERE bucket = p_bucket AND key = p_key;

    INSERT INTO public.security_logs (user_id, event_type, description, metadata)
    VALUES (
      CASE WHEN auth.uid() IS NOT NULL THEN auth.uid() ELSE NULL END,
      'rate_limited',
      'Rate limit exceeded for ' || p_bucket,
      jsonb_build_object('bucket', p_bucket, 'key', p_key, 'retry_after', v_retry_sec)
    );

    RETURN QUERY SELECT false, v_retry_sec;
  END IF;
END;
$function$;


CREATE OR REPLACE FUNCTION public.enforce_rate_limit(p_bucket text, p_key text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_raw_claims text;
  v_jwt_role text;
  v_ctx text;
  v_config text;
  v_cap int := 10;
  v_minutes numeric := 60;
  v_refill_rate numeric;
  v_allowed boolean;
  v_retry_sec int;
  v_slash_pos int;
BEGIN
  -- Layer 2, same shape as consume_rate_limit. This function has no legitimate
  -- top-level caller at all: every caller is another SECURITY DEFINER RPC
  -- (export_user_data, pay_plan_fee_from_wallet, redeem_referral_points,
  -- request_account_deletion, request_esim_purchase, request_instant_refill).
  v_raw_claims := current_setting('request.jwt.claims', true);
  IF v_raw_claims IS NOT NULL AND v_raw_claims <> '' THEN
    v_jwt_role := (v_raw_claims::jsonb) ->> 'role';
    IF v_jwt_role IS DISTINCT FROM 'service_role' THEN
      GET DIAGNOSTICS v_ctx = PG_CONTEXT;
      IF coalesce(array_length(string_to_array(v_ctx, E'\n'), 1), 1) < 2 THEN
        RAISE EXCEPTION 'enforce_rate_limit is not directly callable by role %', COALESCE(v_jwt_role, '<none>')
          USING ERRCODE = 'KS403';
      END IF;
    END IF;
  END IF;

  IF p_key IS NULL OR p_key = '' THEN
    RETURN;
  END IF;

  p_bucket := LOWER(p_bucket);

  SELECT config_value INTO v_config
  FROM public.system_configs
  WHERE config_key = 'RATE_LIMIT_' || UPPER(p_bucket);

  IF v_config IS NOT NULL AND v_config LIKE '%/%' THEN
    BEGIN
      v_slash_pos := POSITION('/' IN v_config);
      v_cap := SUBSTRING(v_config FROM 1 FOR v_slash_pos - 1)::int;
      v_minutes := SUBSTRING(v_config FROM v_slash_pos + 1)::numeric;
    EXCEPTION WHEN OTHERS THEN
      v_cap := 10;
      v_minutes := 60;
    END;
  END IF;

  IF v_minutes <= 0 THEN v_minutes := 60; END IF;
  v_refill_rate := v_cap::numeric / v_minutes;

  SELECT allowed, retry_after_seconds INTO v_allowed, v_retry_sec
  FROM public.consume_rate_limit(p_bucket, p_key, v_cap, v_refill_rate, clock_timestamp());

  IF NOT v_allowed THEN
    RAISE EXCEPTION USING ERRCODE = 'KS429', MESSAGE = 'RATE_LIMITED:' || p_bucket || ':' || v_retry_sec;
  END IF;
EXCEPTION
  WHEN SQLSTATE 'KS429' THEN
    RAISE;
  -- ⚠️ KS403 MUST be re-raised here. This function ends in a
  -- `WHEN OTHERS THEN RAISE NOTICE` catch-all that deliberately makes limiter
  -- faults non-fatal to the money path. Without this branch that catch-all
  -- swallows the guard above — and also any KS403 bubbling up out of
  -- consume_rate_limit — leaving the guard as dead code AND silently disabling
  -- rate limiting. This is the same class of bug as D5c's tamper trigger.
  WHEN SQLSTATE 'KS403' THEN
    RAISE;
  WHEN OTHERS THEN
    RAISE NOTICE 'Limiter error for bucket %: %', p_bucket, SQLERRM;
END;
$function$;


-- ---------------------------------------------------------------------------
-- apply_referral — repair the ownership check (see the header note)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.apply_referral(p_referred_id uuid, p_referral_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_referrer_id uuid;
  v_already_referred_by text;
  v_allowed boolean;
  v_retry_sec int;
  v_email text;
  v_email_hash text;
BEGIN
  -- WAS: IF auth.uid() IS NOT NULL AND auth.uid() <> p_referred_id
  -- which no-oped for an unauthenticated caller (auth.uid() IS NULL), leaving
  -- p_referred_id — the account being written — entirely caller-chosen.
  -- A session is now required, and it must own the row it is modifying.
  IF auth.uid() IS NULL OR auth.uid() <> p_referred_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  SELECT allowed, retry_after_seconds INTO v_allowed, v_retry_sec
  FROM public.consume_rate_limit('apply_referral', p_referred_id::text, 5, 5.0/60.0, clock_timestamp());

  IF NOT v_allowed THEN
    RETURN jsonb_build_object('success', false, 'code', 'KS429', 'error', 'RATE_LIMITED:apply_referral:' || v_retry_sec, 'retry_after', v_retry_sec);
  END IF;

  p_referral_code := UPPER(TRIM(COALESCE(p_referral_code, '')));

  -- Check if code is retired
  IF EXISTS (SELECT 1 FROM public.retired_referral_codes WHERE code = p_referral_code) THEN
    RETURN jsonb_build_object('success', false, 'error', 'This referral code has been retired');
  END IF;

  SELECT id INTO v_referrer_id
  FROM public.profiles
  WHERE UPPER(referral_code) = p_referral_code;

  IF v_referrer_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid referral code');
  END IF;

  IF v_referrer_id = p_referred_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'You cannot refer yourself');
  END IF;

  SELECT referred_by INTO v_already_referred_by
  FROM public.profiles
  WHERE id = p_referred_id;

  IF v_already_referred_by IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'You have already applied a referral code');
  END IF;

  -- Anti-abuse: check if user's email hash was in account_deletions within last 90 days
  SELECT email INTO v_email FROM auth.users WHERE id = p_referred_id;
  IF v_email IS NOT NULL THEN
    v_email_hash := encode(sha256(lower(trim(v_email))::bytea), 'hex');
    IF EXISTS (
      SELECT 1 FROM public.account_deletions
      WHERE email_hash = v_email_hash
        AND requested_at > (clock_timestamp() - INTERVAL '90 days')
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', 'Re-registered accounts are ineligible for referral bonuses');
    END IF;
  END IF;

  UPDATE public.profiles
  SET referred_by = p_referral_code
  WHERE id = p_referred_id;

  INSERT INTO public.referrals (referrer_id, referred_user_id, code)
  VALUES (v_referrer_id, p_referred_id, p_referral_code);

  RETURN jsonb_build_object('success', true);
END;
$function$;


-- ============================================================================
-- Layer 1 — the grants. Signature-qualified throughout: an unqualified REVOKE on
-- an overloaded name errors out, and getting exactly that wrong on one overload
-- is what F-2 was.
-- ============================================================================

-- service_role only ---------------------------------------------------------
REVOKE ALL ON FUNCTION public.purge_deleted_accounts()  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.purge_deleted_accounts()  TO service_role;

REVOKE ALL ON FUNCTION public.prune_rate_limit_data()   FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.prune_rate_limit_data()   TO service_role;

REVOKE ALL ON FUNCTION public.check_rate_limit_health() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_rate_limit_health() TO service_role;

REVOKE ALL ON FUNCTION public.consume_rate_limit(text, text, integer, numeric, timestamptz)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_rate_limit(text, text, integer, numeric, timestamptz)
  TO service_role;

REVOKE ALL ON FUNCTION public.enforce_rate_limit(text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.enforce_rate_limit(text, text) TO service_role;

-- Trigger function: never called directly (Postgres raises 0A000 for that), but
-- it had no business carrying an anon EXECUTE grant.
REVOKE ALL ON FUNCTION public.trg_fn_award_referral_points() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.trg_fn_award_referral_points() TO service_role;

-- Self-scoped RPCs: these MUST stay callable by a signed-in user, they just have
-- no reason to be callable without one. Each already refuses when auth.uid() is
-- NULL; dropping anon removes the free unauthenticated compute and the
-- referral-code oracle. request_account_deletion in particular is invoked
-- top-level with a real user JWT by the delete_account Edge Function.
REVOKE ALL ON FUNCTION public.export_user_data()          FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.export_user_data()          TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.apply_referral(uuid, text)  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.apply_referral(uuid, text)  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.request_account_deletion(text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_account_deletion(text, boolean) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.cancel_account_deletion()   FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_account_deletion()   TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.redeem_referral_points()    FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.redeem_referral_points()    TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.is_power_user(uuid)         FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_power_user(uuid)         TO authenticated, service_role;


COMMENT ON FUNCTION public.purge_deleted_accounts() IS
  'Advances the account-deletion state machine. service_role/cron ONLY — was HTTP-200 '
  'callable by anon until 2026-07-29 (F-3). Regression test supabase/tests/f3_f4_rpc_grant_tests.sql.';

COMMENT ON FUNCTION public.consume_rate_limit(text, text, integer, numeric, timestamptz) IS
  'Token-bucket consume. service_role at any depth, or nested inside another server-side '
  'function. Never grant to anon/authenticated: the bucket AND key are caller-supplied, so a '
  'direct grant lets anyone drain another user''s money-path limits (F-4).';

COMMENT ON FUNCTION public.enforce_rate_limit(text, text) IS
  'Config-driven rate limit gate. Has no legitimate top-level caller. NOTE the KS403 branch in '
  'its EXCEPTION block — the WHEN OTHERS catch-all below it will silently swallow the guard '
  'without it, disabling rate limiting entirely (F-4).';

COMMENT ON FUNCTION public.apply_referral(uuid, text) IS
  'Applies a referral code to the CALLING user. Requires a session and self-ownership: until '
  '2026-07-29 the check was skipped for anon, making p_referred_id caller-chosen and allowing '
  'an unauthenticated write to any profile (F-4, found during verification).';
