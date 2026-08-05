-- ============================================================================
-- F0.6 — the grant matrix. This is the artifact that stops the F-1..F-4 class
-- of bug recurring.
--
-- Every SECURITY DEFINER function in `public` runs with the table owner's
-- rights, so its EXECUTE ACL *is* the security perimeter. Supabase blanket-grants
-- EXECUTE on new public functions and `GRANT ... TO service_role` does NOT
-- remove anon/authenticated — only a REVOKE does. Four separate live holes
-- (F-1 minting, F-2 draining, F-3 free compute, F-4 rate-limit DoS + an
-- unauthenticated profile write) all had exactly one root cause: nobody
-- asserted the ACL.
--
-- The rule this file enforces:
--
--   Every SECURITY DEFINER function in public must be either
--     (a) service_role-only, or
--     (b) on the explicit AUTHENTICATED_ALLOWLIST below.
--   NOTHING may be callable by anon or by PUBLIC. No exceptions.
--
-- Adding a function to the allow-list is a deliberate act: it means "a signed-in
-- user may call this directly, and it checks auth.uid() internally". If you add
-- one, add a test for its ownership check too — an allow-list entry without an
-- internal check is what F-4's apply_referral was.
--
-- ============================================================================
-- HOW TO RUN — as ONE execute_sql call. MCP makes each call its own
-- transaction, so a split file never pairs BEGIN with ROLLBACK.
-- ============================================================================
-- Last run 2026-08-05 (after I8). FAILED T1 on the first run and found a real
-- one: i7's admin_upsert_carrier_rule(uuid,jsonb) had shipped with PUBLIC +
-- anon EXECUTE. Latent, not live — its assert_admin() answered anon with KS460
-- — but revoked in migration 20260818020000_i8c and re-probed to 42501.
-- 6/6 PASSED, 0 violations.
-- ============================================================================

BEGIN;

CREATE TEMP TABLE f0_results(t text, outcome text) ON COMMIT DROP;

DO $$
DECLARE
  -- (b) — signed-in users may call these directly. Each is self-scoped and
  -- gates on auth.uid() (or on ownership of the row it touches) internally.
  allowlist text[] := ARRAY[
    -- --------------------------------------------------------------------
    -- Phase H, the admin control plane. Every one of these opens with
    -- `PERFORM public.assert_admin()`, which is the single gate: it returns
    -- the acting power user, returns NULL for service_role, and raises KS460
    -- otherwise. Critically it raises on a MISSING identity — the two entries
    -- this block replaces
    --   admin_complete_manual_refill(uuid) / admin_switch_gateway_to_manual(uuid)
    -- opened `IF auth.uid() IS NOT NULL AND NOT (is_power_user AND ...)`, which
    -- is false when auth.uid() is NULL, i.e. it fell OPEN for an unauthenticated
    -- caller. Fifth occurrence of that shape after D5c, F-4's apply_referral and
    -- protect_is_power_user. They are dropped and replaced by (uuid,text) forms
    -- with the guard inverted; there is deliberately no 1-arg overload, because
    -- PostgREST resolves overloads from body keys on signature alone and would
    -- answer HTTP 300 PGRST203 (the F2b failure).
    --
    -- assert_admin() itself is absent from this list on purpose: it is SECURITY
    -- INVOKER, like is_power_user, so it is outside this perimeter entirely.
    -- Its own checks are asserted in supabase/tests/h_admin_control_plane_tests.sql.
    'admin_adjust_wallet(uuid,numeric,text)',
    'admin_complete_manual_refill(uuid,text)',
    'admin_delete_offline_endpoint(uuid,text)',
    'admin_fail_refill(uuid,text,boolean)',
    'admin_get_ticket(uuid)',
    'admin_get_user(uuid)',
    'admin_list_audit(integer,text,text)',
    'admin_list_carriers()',
    'admin_list_channels()',
    'admin_list_configs()',
    'admin_list_esim_suppliers()',
    'admin_list_offline_endpoints()',
    'admin_list_tickets(text,integer)',
    'admin_list_users(text,integer)',
    'admin_notification_health(integer)',
    'admin_overview()',
    'admin_reply_ticket(uuid,text,text)',
    'admin_set_config(text,text,text)',
    'admin_set_ticket_status(uuid,text,text)',
    'admin_set_user_flags(uuid,jsonb,text)',
    'admin_switch_gateway_to_manual(uuid,text)',
    'admin_update_carrier(uuid,jsonb,text)',
    'admin_update_carrier_rule(uuid,jsonb,text)',
    -- i7's wider carrier-rule write (it also patches activity_requirement and
    -- the qualifying denomination). It is NOT an overload of the entry above —
    -- different name, so no PGRST203. It shipped with PUBLIC + anon EXECUTE and
    -- this file is what caught it; I8c revoked both. Same assert_admin() gate,
    -- which is why anon got KS460 rather than a written row while it was open.
    'admin_upsert_carrier_rule(uuid,jsonb)',
    'admin_update_channel(text,jsonb,text)',
    'admin_upsert_esim_supplier(text,jsonb,text)',
    'admin_upsert_offline_endpoint(uuid,jsonb,text)',
    -- I8, same assert_admin() gate. The emitter that reads every user's lines
    -- and writes to every user's notifications
    -- (emit_carrier_self_service_advice) is deliberately NOT here: it is
    -- service_role-only, asserted directly in i8_carrier_advice_tests.sql T9.
    'admin_list_carrier_self_service()',
    'admin_upsert_carrier_self_service(uuid,jsonb,text)',
    -- I3/I4, same assert_admin() gate as every entry above. The audience query
    -- (campaign_audience) and the runner protocol (script_claim_next_execution,
    -- script_complete_execution) are deliberately NOT here: they are
    -- service_role-only, because one enumerates every targeted user and the
    -- other moves money.
    'admin_list_campaigns()',
    'admin_list_refill_scripts()',
    'admin_list_supplier_policy()',
    'admin_send_campaign(uuid,text)',
    'admin_update_supplier_policy(text,jsonb,text)',
    'admin_upsert_campaign(uuid,jsonb,text)',
    'admin_upsert_refill_script(uuid,jsonb,text)',
    -- I5's engine itself is service_role-only and must NEVER appear here:
    -- supplier_candidates / choose_supplier_for_offer expose wholesale supplier
    -- pricing, which is the markup isolation the G5b view lockdown exists to
    -- protect. config_numeric and supplier_effective_cost likewise.
    -- admin_log, validate_config_value and sync_offline_endpoint_configs are
    -- service_role-only by design: the admin_* functions reach them as their own
    -- definer, never the client. They must NOT appear here.
    -- --------------------------------------------------------------------
    -- --------------------------------------------------------------------
    -- G6/G7/G10 additions. These were live for days before anyone re-ran this
    -- file: at Phase H it failed T4 with twelve unlisted functions, four of
    -- them because G10 added a trailing p_device_id and CHANGED the signature
    -- of an entry that was already here. A grant-matrix test nobody runs is not
    -- a guard, it is a document. Run this file after every phase.
    'household_spend_summary()',
    'label_my_device(text,text)',
    'my_devices()',
    'my_household_allowances()',
    'report_device_block(text,numeric,text)',
    'revoke_my_device(text)',
    'set_line_rescue_policy(uuid,numeric,integer,integer)',
    'touch_user_device(text,text,text)',
    -- --------------------------------------------------------------------
    -- H8, the household member-side write path. These exist BECAUSE the member
    -- has no write policy on household_members any more: the old policy scoped
    -- rows but not columns, so a viewer could set their own role='manager' and
    -- then spend the owner's wallet. Each of these gates on auth.uid() and
    -- writes only the columns its name implies — invite_household_member takes
    -- owner_id from auth.uid(), respond_to_household_invite touches only
    -- invite_status/member_id/accepted_at, leave_household deletes only a row
    -- whose member_id is the caller.
    'invite_household_member(text,text)',
    'leave_household(uuid)',
    'respond_to_household_invite(uuid,boolean)',
    -- --------------------------------------------------------------------
    'apply_referral(uuid,text)',
    'calculate_health_score(uuid,text,timestamp with time zone)',
    'cancel_account_deletion()',
    'cancel_topup_execution(uuid)',
    -- I3, the in-app advert. Both are auth.uid()-scoped: get_active_promos
    -- returns only campaigns matching a line the caller owns, and dismiss_promo
    -- writes only the caller's own row. dismiss_promo deliberately does not
    -- check that the campaign exists — answering differently for a real id
    -- would make it a campaign-id oracle.
    'dismiss_promo(uuid)',
    'export_user_data()',
    'get_active_promos()',
    'get_wallet_forecast(uuid)',
    -- is_power_user(uuid) is deliberately absent: migration 20260801100000 made
    -- it SECURITY INVOKER, so it is out of this perimeter entirely. It must stay
    -- anon-EXECUTEable for the sim_lines "Allow power users full access" policy.
    -- The trailing text on these four is G10's p_device_id, added LAST so an
    -- old APK still resolves the call. The signatures listed here before Phase H
    -- were the pre-G10 ones and had silently stopped matching anything.
    -- I1. Read-only offer discovery, scoped to a line the caller owns or
    -- manages in a household — the same visibility test request_instant_refill
    -- applies, deliberately, so the list and the purchase cannot disagree.
    -- Neither of these moves money or writes a row.
    'list_refill_offers(uuid)',
    'pick_best_refill_offer(uuid,numeric)',
    'pay_plan_fee_from_wallet(text,uuid,text)',
    'queue_premium_refill_executions(uuid,uuid,timestamp with time zone,timestamp with time zone)',
    'quote_plan_price(uuid,text,text)',
    'redeem_referral_points()',
    'request_account_deletion(text,boolean)',
    'request_esim_purchase(text,integer,text)',
    'request_instant_refill(uuid,text,text,numeric,text)',
    'reschedule_mini_refill(uuid,timestamp with time zone)',
    'reset_mini_refill_to_default(uuid)',
    'retry_topup_execution(uuid)',
    -- G3. The only allow-list entry that moves money BETWEEN users, so it is
    -- the one to re-read hardest. Sender is auth.uid() and there is no sender
    -- parameter; the recipient is resolved by email behind a rate limit; only
    -- ledger-derived deposits and received gifts are transferable. Its own
    -- checks are asserted in supabase/tests/g3_gift_credit_tests.sql (T5, T15,
    -- T16, T17) — an allow-list entry without a tested internal check is
    -- exactly what F-4's apply_referral was.
    'transfer_wallet_credit(text,numeric,text,text,text)',
    'update_mini_refill_dates(uuid,jsonb)'
  ];
  v_bad text;
  v_n int;
  v_passed int := 0;
  v_expected int := 6;
BEGIN
  -- T1: nothing SECURITY DEFINER may be callable by anon. This is F-3/F-4.
  SELECT string_agg(p.oid::regprocedure::text, ', ' ORDER BY p.oid::regprocedure::text), count(*)
    INTO v_bad, v_n
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.prokind = 'f' AND p.prosecdef
    AND has_function_privilege('anon', p.oid, 'EXECUTE');
  IF v_n > 0 THEN
    RAISE EXCEPTION 'T1 FAIL: % SECURITY DEFINER function(s) callable by anon: %', v_n, v_bad;
  END IF;
  INSERT INTO f0_results VALUES ('T1 no SECURITY DEFINER fn is anon-callable', 'PASS');
  v_passed := v_passed + 1;

  -- T2: nothing may carry a PUBLIC EXECUTE grant. This is the F-2 shape — the
  -- ACL entry with an empty grantee, which has_function_privilege alone can miss
  -- if the role also holds a direct grant.
  SELECT string_agg(p.oid::regprocedure::text, ', ' ORDER BY p.oid::regprocedure::text), count(*)
    INTO v_bad, v_n
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.prokind = 'f' AND p.prosecdef
    AND EXISTS (
      SELECT 1 FROM aclexplode(p.proacl) a
      WHERE a.grantee = 0 AND a.privilege_type = 'EXECUTE'
    );
  IF v_n > 0 THEN
    RAISE EXCEPTION 'T2 FAIL: % SECURITY DEFINER function(s) hold PUBLIC EXECUTE: %', v_n, v_bad;
  END IF;
  INSERT INTO f0_results VALUES ('T2 no SECURITY DEFINER fn holds PUBLIC EXECUTE', 'PASS');
  v_passed := v_passed + 1;

  -- T3: a NULL proacl means "default privileges" — which for a function is
  -- EXECUTE TO PUBLIC. Catches a brand-new function nobody locked down.
  SELECT string_agg(p.oid::regprocedure::text, ', ' ORDER BY p.oid::regprocedure::text), count(*)
    INTO v_bad, v_n
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.prokind = 'f' AND p.prosecdef AND p.proacl IS NULL;
  IF v_n > 0 THEN
    RAISE EXCEPTION 'T3 FAIL: % SECURITY DEFINER function(s) have a default (PUBLIC) ACL: %', v_n, v_bad;
  END IF;
  INSERT INTO f0_results VALUES ('T3 no SECURITY DEFINER fn has a default ACL', 'PASS');
  v_passed := v_passed + 1;

  -- T4: anything callable by `authenticated` must be on the allow-list.
  SELECT string_agg(sig, ', ' ORDER BY sig), count(*) INTO v_bad, v_n
  FROM (
    SELECT replace(p.oid::regprocedure::text, 'public.', '') AS sig
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.prokind = 'f' AND p.prosecdef
      AND has_function_privilege('authenticated', p.oid, 'EXECUTE')
  ) s
  WHERE sig <> ALL (allowlist);
  IF v_n > 0 THEN
    RAISE EXCEPTION 'T4 FAIL: % authenticated-callable SECURITY DEFINER function(s) are NOT on the allow-list: %. Either revoke, or add to the allow-list AND test its auth.uid() check.', v_n, v_bad;
  END IF;
  INSERT INTO f0_results VALUES ('T4 every authenticated-callable fn is allow-listed', 'PASS');
  v_passed := v_passed + 1;

  -- T5: the reverse — an allow-listed function that LOST its grant means the
  -- app is broken. This is the D5c failure mode (a lockdown that went too far).
  SELECT string_agg(a, ', ' ORDER BY a), count(*) INTO v_bad, v_n
  FROM unnest(allowlist) a
  WHERE NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.prosecdef
      AND replace(p.oid::regprocedure::text, 'public.', '') = a
      AND has_function_privilege('authenticated', p.oid, 'EXECUTE')
  );
  IF v_n > 0 THEN
    RAISE EXCEPTION 'T5 FAIL: % allow-listed function(s) are missing or no longer callable by authenticated — the app is broken: %', v_n, v_bad;
  END IF;
  INSERT INTO f0_results VALUES ('T5 every allow-listed fn is still authenticated-callable', 'PASS');
  v_passed := v_passed + 1;

  -- T6: service_role must be able to execute everything, or the workers and cron
  -- jobs silently stop.
  SELECT string_agg(p.oid::regprocedure::text, ', ' ORDER BY p.oid::regprocedure::text), count(*)
    INTO v_bad, v_n
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.prokind = 'f' AND p.prosecdef
    AND NOT has_function_privilege('service_role', p.oid, 'EXECUTE');
  IF v_n > 0 THEN
    RAISE EXCEPTION 'T6 FAIL: service_role cannot execute % function(s) — workers/cron are broken: %', v_n, v_bad;
  END IF;
  INSERT INTO f0_results VALUES ('T6 service_role can execute every SECURITY DEFINER fn', 'PASS');
  v_passed := v_passed + 1;

  IF v_passed <> v_expected THEN
    RAISE EXCEPTION 'F0 FAIL: only % of % assertions passed', v_passed, v_expected;
  END IF;
  INSERT INTO f0_results VALUES ('TOTAL', format('%s / %s PASSED', v_passed, v_expected));
END;
$$;

-- Informational: the full matrix, so a reviewer can eyeball it.
SELECT * FROM f0_results;

SELECT
  replace(p.oid::regprocedure::text, 'public.', '') AS function,
  CASE
    WHEN has_function_privilege('anon', p.oid, 'EXECUTE')          THEN 'anon (VIOLATION)'
    WHEN has_function_privilege('authenticated', p.oid, 'EXECUTE') THEN 'authenticated (allow-listed)'
    ELSE 'service_role only'
  END AS bucket
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.prokind = 'f' AND p.prosecdef
ORDER BY 2, 1;

ROLLBACK;
