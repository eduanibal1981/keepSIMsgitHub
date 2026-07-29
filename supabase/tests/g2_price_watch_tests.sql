-- G2 regression suite — price-drop / best-offer watch
-- (doc/PRODUCTION_PLAN_REVIEW.md § 6, feature #2).
--
-- Three things are asserted, and the third matters as much as the first two:
--   1. offer_price_history is genuinely deny-all. It holds eSIM WHOLESALE
--      prices; a read grant here would undo the markup isolation that the
--      `esim_offers` view exists to provide (doc/RLS_MATRIX.md).
--   2. The four new functions are service_role-only, so the F0 perimeter is
--      unchanged.
--   3. THE APP STILL WORKS. offer_price_watches has column-scoped INSERT and
--      UPDATE grants, and a column lockdown has already broken a real write
--      path twice here (D5c SIM lines, F6 profiles). Every payload the Flutter
--      client actually sends is exercised as a signed-in user.
--
-- Probed as a REAL `authenticated` role with a JWT, never as postgres — a
-- SECURITY DEFINER function sees current_user = its owner, which is how four
-- separate guards in this project shipped as dead code.
--
-- Uses the existing a1 fixture only — creates no auth.users rows.
--
-- ============================================================================
-- HOW TO RUN — as ONE execute_sql call. MCP makes each call its own
-- transaction, so a split file never pairs BEGIN with ROLLBACK and the INSERTs
-- COMMIT. That is how test residue leaked into production three times here.
-- ============================================================================
-- Last run 2026-07-29: 14/14 PASSED.
-- ============================================================================

BEGIN;

CREATE TEMP TABLE g2(t text, outcome text) ON COMMIT DROP;
GRANT INSERT, SELECT ON g2 TO authenticated;

-- --------------------------------------------------------------------------
-- Part 1 — the grant matrix, read from the catalog.
-- --------------------------------------------------------------------------
DO $$
DECLARE
  v_n int; v_bad text; v_passed int := 0;
  fns text[] := ARRAY[
    'offer_watch_metrics(integer)',
    'sync_auto_price_watches()',
    'detect_offer_price_drops()',
    'prune_offer_price_history()',
    'refresh_offer_price_watch()',
    'trg_fn_record_topup_price_history()',
    'trg_fn_record_esim_price_history()'
  ];
BEGIN
  -- T1: offer_price_history is deny-all for both client roles. This is the
  --     wholesale-price leak test.
  SELECT count(*) INTO v_n
  FROM information_schema.role_table_grants
  WHERE table_schema='public' AND table_name='offer_price_history'
    AND grantee IN ('anon','authenticated','PUBLIC');
  IF v_n > 0 THEN
    RAISE EXCEPTION 'T1 FAIL: offer_price_history holds % client grant(s)', v_n;
  END IF;
  INSERT INTO g2 VALUES ('T1 offer_price_history holds no client grant','PASS');
  v_passed := v_passed + 1;

  -- T2: ...and it has RLS on with zero policies, so even a future accidental
  --     grant reads nothing.
  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid='public.offer_price_history'::regclass) THEN
    RAISE EXCEPTION 'T2 FAIL: offer_price_history does not have RLS enabled';
  END IF;
  SELECT count(*) INTO v_n FROM pg_policies
  WHERE schemaname='public' AND tablename='offer_price_history';
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'T2 FAIL: offer_price_history has % policy(ies); it must have none', v_n;
  END IF;
  INSERT INTO g2 VALUES ('T2 offer_price_history is RLS-on with zero policies','PASS');
  v_passed := v_passed + 1;

  -- T3: every G2 function is service_role-only.
  SELECT string_agg(f, ', '), count(*) INTO v_bad, v_n
  FROM unnest(fns) f
  WHERE has_function_privilege('anon', 'public.' || f, 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.' || f, 'EXECUTE');
  IF v_n > 0 THEN
    RAISE EXCEPTION 'T3 FAIL: % G2 function(s) are client-callable: %', v_n, v_bad;
  END IF;
  INSERT INTO g2 VALUES ('T3 no G2 function is anon/authenticated-callable','PASS');
  v_passed := v_passed + 1;

  -- T4: ...and service_role can still run all of them, or the cron job dies.
  SELECT string_agg(f, ', '), count(*) INTO v_bad, v_n
  FROM unnest(fns) f
  WHERE NOT has_function_privilege('service_role', 'public.' || f, 'EXECUTE');
  IF v_n > 0 THEN
    RAISE EXCEPTION 'T4 FAIL: service_role cannot execute: %', v_bad;
  END IF;
  INSERT INTO g2 VALUES ('T4 service_role can execute every G2 function','PASS');
  v_passed := v_passed + 1;

  -- T5: anon holds nothing at all on offer_price_watches.
  SELECT count(*) INTO v_n
  FROM information_schema.role_table_grants
  WHERE table_schema='public' AND table_name='offer_price_watches' AND grantee='anon';
  IF v_n > 0 THEN
    RAISE EXCEPTION 'T5 FAIL: anon holds % grant(s) on offer_price_watches', v_n;
  END IF;
  INSERT INTO g2 VALUES ('T5 anon holds no grant on offer_price_watches','PASS');
  v_passed := v_passed + 1;

  -- T6: authenticated's UPDATE is column-scoped to exactly the two the user
  --     owns. A table-level UPDATE would let a client write last_alert_at and
  --     silence its own alerts, or invent a last_best_usd the UI then shows.
  SELECT string_agg(column_name, ',' ORDER BY column_name) INTO v_bad
  FROM information_schema.column_privileges
  WHERE table_schema='public' AND table_name='offer_price_watches'
    AND grantee='authenticated' AND privilege_type='UPDATE';
  IF v_bad IS DISTINCT FROM 'is_active,threshold_percent' THEN
    RAISE EXCEPTION 'T6 FAIL: authenticated UPDATE columns are [%], expected [is_active,threshold_percent]', v_bad;
  END IF;
  SELECT count(*) INTO v_n
  FROM information_schema.role_table_grants
  WHERE table_schema='public' AND table_name='offer_price_watches'
    AND grantee='authenticated' AND privilege_type IN ('TRUNCATE','REFERENCES','TRIGGER');
  IF v_n > 0 THEN
    RAISE EXCEPTION 'T6 FAIL: authenticated holds % of TRUNCATE/REFERENCES/TRIGGER', v_n;
  END IF;
  INSERT INTO g2 VALUES ('T6 authenticated UPDATE is column-scoped, no TRUNCATE/REFERENCES/TRIGGER','PASS');
  v_passed := v_passed + 1;

  -- T7: `origin` is withheld from the INSERT grant, so a client cannot forge an
  --     'auto' row that sync_auto_price_watches() would then manage or delete.
  IF EXISTS (
    SELECT 1 FROM information_schema.column_privileges
    WHERE table_schema='public' AND table_name='offer_price_watches'
      AND grantee='authenticated' AND privilege_type='INSERT' AND column_name='origin'
  ) THEN
    RAISE EXCEPTION 'T7 FAIL: authenticated can INSERT offer_price_watches.origin';
  END IF;
  INSERT INTO g2 VALUES ('T7 origin is not client-insertable','PASS');
  v_passed := v_passed + 1;

  IF v_passed <> 7 THEN
    RAISE EXCEPTION 'Part 1 FAIL: only % of 7 assertions passed', v_passed;
  END IF;
END;
$$;


-- --------------------------------------------------------------------------
-- Part 2 — as a signed-in user. a1 = e5a56433-…, who owns SIM line a918abf3
-- (Zain KSA), so sync_auto_price_watches() has already given them an SA/Zain
-- auto watch.
-- --------------------------------------------------------------------------
SELECT set_config('request.jwt.claims',
  json_build_object('role','authenticated','sub','e5a56433-6f75-41a3-96b9-19c62b9d1280')::text, true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  v_uid   uuid := 'e5a56433-6f75-41a3-96b9-19c62b9d1280';
  v_other uuid;
  v_id    uuid;
  v_n     int;
  v_all   int;
  v_passed int := 0;
BEGIN
  -- T8: read-own. The user sees their own watches and nobody else's.
  SELECT count(*) INTO v_n FROM public.offer_price_watches;
  SELECT count(*) INTO v_all FROM public.offer_price_watches WHERE user_id = v_uid;
  IF v_n <> v_all OR v_n = 0 THEN
    RAISE EXCEPTION 'T8 FAIL: sees % rows, % of them own (expected equal and non-zero)', v_n, v_all;
  END IF;
  INSERT INTO g2 VALUES (format('T8 read-own: sees %s rows, all own', v_n),'PASS');
  v_passed := v_passed + 1;

  -- T9: the app's exact create payload — price_watch_repository.dart addWatch().
  INSERT INTO public.offer_price_watches (user_id, source, country_code, carrier_code, threshold_percent, is_active)
  VALUES (v_uid, 'esim', 'JP', NULL, NULL, true)
  RETURNING id INTO v_id;
  IF (SELECT origin FROM public.offer_price_watches WHERE id = v_id) <> 'user' THEN
    RAISE EXCEPTION 'T9 FAIL: origin did not default to user';
  END IF;
  INSERT INTO g2 VALUES ('T9 client can create an eSIM watch (origin defaults to user)','PASS');
  v_passed := v_passed + 1;

  -- T10: the app's exact toggle payload — setActive().
  UPDATE public.offer_price_watches SET is_active = false WHERE id = v_id;
  IF (SELECT is_active FROM public.offer_price_watches WHERE id = v_id) THEN
    RAISE EXCEPTION 'T10 FAIL: is_active toggle did not take';
  END IF;
  UPDATE public.offer_price_watches SET threshold_percent = 25 WHERE id = v_id;
  INSERT INTO g2 VALUES ('T10 client can toggle is_active and set threshold_percent','PASS');
  v_passed := v_passed + 1;

  -- T11: bookkeeping columns are not writable — the whole point of T6.
  BEGIN
    UPDATE public.offer_price_watches SET last_alert_at = NULL, last_best_usd = 0.01 WHERE id = v_id;
    RAISE EXCEPTION 'T11 FAIL: client wrote last_alert_at/last_best_usd';
  EXCEPTION WHEN insufficient_privilege THEN
    INSERT INTO g2 VALUES ('T11 writing last_alert_at/last_best_usd -> 42501','PASS');
    v_passed := v_passed + 1;
  END;

  -- T12: cannot create a watch for somebody else.
  SELECT id INTO v_other FROM public.profiles WHERE id <> v_uid LIMIT 1;
  IF v_other IS NULL THEN
    -- profiles is itself read-own+household; fall back to a literal non-self id.
    v_other := '00000000-0000-0000-0000-0000000000ff';
  END IF;
  BEGIN
    INSERT INTO public.offer_price_watches (user_id, source, country_code, carrier_code)
    VALUES (v_other, 'esim', 'TH', NULL);
    RAISE EXCEPTION 'T12 FAIL: client created a watch for another user';
  EXCEPTION
    WHEN insufficient_privilege OR check_violation THEN
      INSERT INTO g2 VALUES ('T12 watch for another user -> blocked','PASS');
      v_passed := v_passed + 1;
  END;

  -- T13: the wholesale price log is unreadable.
  BEGIN
    PERFORM 1 FROM public.offer_price_history LIMIT 1;
    RAISE EXCEPTION 'T13 FAIL: client read offer_price_history';
  EXCEPTION WHEN insufficient_privilege THEN
    INSERT INTO g2 VALUES ('T13 SELECT offer_price_history -> 42501','PASS');
    v_passed := v_passed + 1;
  END;

  -- T14: the job cannot be driven from a client.
  BEGIN
    PERFORM public.detect_offer_price_drops();
    RAISE EXCEPTION 'T14 FAIL: client executed detect_offer_price_drops()';
  EXCEPTION WHEN insufficient_privilege THEN
    INSERT INTO g2 VALUES ('T14 detect_offer_price_drops() -> 42501','PASS');
    v_passed := v_passed + 1;
  END;

  -- ...and DELETE of an own row works, which the UI needs for user watches.
  DELETE FROM public.offer_price_watches WHERE id = v_id;

  IF v_passed <> 7 THEN
    RAISE EXCEPTION 'Part 2 FAIL: only % of 7 assertions passed', v_passed;
  END IF;
END;
$$;

RESET ROLE;
SELECT set_config('request.jwt.claims','',true);

INSERT INTO g2 VALUES ('TOTAL', (SELECT format('%s / 14 PASSED', count(*)) FROM g2));
SELECT * FROM g2;

ROLLBACK;
