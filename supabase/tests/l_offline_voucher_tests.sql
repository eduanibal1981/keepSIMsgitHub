-- ============================================================================
-- L — the offline recharge voucher rail.
--
-- What this file exists to keep true:
--
--   1. A PIN is a bearer instrument. It is stored encrypted, it is unreadable
--      by `authenticated` through any path, and it leaves the database in
--      exactly ONE function.
--   2. The cap is structural. "One live voucher per premium SIM line" is a
--      partial unique index, not an IF in application code — five separate
--      guards in this project have shipped as code that never ran, and this
--      one hands out money. T10 proves it with a direct INSERT, because that
--      is the only way to show the DATABASE refuses rather than the RPC
--      choosing not to ask.
--   3. The commercial loop closes. Reveal creates a debt at a frozen price; an
--      unsettled debt blocks the next voucher; settling unblocks it and debits
--      the wallet exactly once however many times the call is repeated.
--   4. Nothing silently succeeds. Every refusal has its own code, because "you
--      owe us for the last one" and "we have not stocked your carrier" are
--      opposite problems with opposite remedies.
--
-- ── A NOTE ON ROLE SWITCHING, which the first draft got wrong ───────────────
-- Every RPC is CALLED as `authenticated`, then the role goes back to postgres
-- before any ASSERTION reads a table. The first version asserted while still
-- impersonating, and T6 died on `permission denied for
-- offline_voucher_requests` — the deny-all working exactly as intended, on the
-- test rather than on an attacker. Keep the two phases separate.
--
-- ============================================================================
-- HOW TO RUN — as ONE execute_sql call. MCP wraps each call in its own
-- transaction, so a file split across two calls never pairs its BEGIN with its
-- ROLLBACK and the INSERTs COMMIT. That is how test residue reached production
-- three times in this project.
--
-- After running, re-check that these all return 0:
--   select count(*) from offline_voucher_stock;
--   select count(*) from sim_lines where phone_number like '+99999%';
--   select count(*) from wallet_transactions where reference_id like 'voucher_%';
-- and that OFFLINE_VOUCHER_ENABLED is back to 'false'.
-- ============================================================================
-- Last run 2026-08-11 (L): 20/20 PASSED, zero residue.
-- ============================================================================

BEGIN;

CREATE TEMP TABLE l_results(t text, outcome text, detail text) ON COMMIT DROP;
GRANT ALL ON l_results TO authenticated;

DO $$
DECLARE
  v_user uuid; v_carrier uuid; v_country uuid;
  v_line uuid; v_line2 uuid; v_stock1 uuid; v_stock2 uuid; v_grant uuid;
  v_r jsonb; v_r2 jsonb;
  v_pin text := 'LTEST-1111-2222';
  v_pin2 text := 'LTEST-3333-4444';
  v_fee numeric; v_due numeric; v_n int; v_bal numeric; v_sla int;
  v_state text; v_msg text; v_ts timestamptz; v_ok boolean;
BEGIN
  -- ── Fixtures ────────────────────────────────────────────────────────────
  SELECT w.user_id INTO v_user FROM public.wallets w ORDER BY w.created_at LIMIT 1;
  SELECT c.id, c.country_id INTO v_carrier, v_country
    FROM public.carriers c JOIN public.carrier_rules r ON r.carrier_id = c.id
   ORDER BY c.name LIMIT 1;

  -- A generous bucket so the suite's own calls cannot trip the rate limit and
  -- report a false failure. Rolled back with everything else.
  UPDATE public.system_configs SET config_value = '500/60'
   WHERE config_key = 'RATE_LIMIT_VOUCHER_PROVISION';

  -- `status` is supplied explicitly: the column DEFAULT ('unverified')
  -- violates its own CHECK, so an INSERT that omits it raises 23514.
  INSERT INTO public.sim_lines
    (user_id, phone_number, country_id, carrier_id, status, plan_type, plan_expires_at)
  VALUES (v_user, '+999990000001', v_country, v_carrier, 'active', 'premium', now() + interval '300 days')
  RETURNING id INTO v_line;

  INSERT INTO public.sim_lines
    (user_id, phone_number, country_id, carrier_id, status, plan_type)
  VALUES (v_user, '+999990000002', v_country, v_carrier, 'active', 'free')
  RETURNING id INTO v_line2;

  -- Entitlement without faking a payment: the grandfather table is the
  -- service_role-only exemption I2 added for exactly this.
  INSERT INTO public.premium_entitlement_grandfather (sim_line_id, reason)
  VALUES (v_line, 'l_test fixture');

  SELECT COALESCE(NULLIF(config_value,'')::int, 7) INTO v_sla
    FROM public.system_configs WHERE config_key = 'OFFLINE_VOUCHER_MANUAL_SLA_DAYS';
  SELECT COALESCE(NULLIF(config_value,'')::numeric, 0) INTO v_fee
    FROM public.system_configs WHERE config_key = 'OFFLINE_VOUCHER_SERVICE_FEE_PERCENT';

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_user, 'role', 'authenticated')::text, true);

  ----------------------------------------------------------------- T01 ------
  -- The master switch really switches it off.
  PERFORM set_config('role', 'authenticated', true);
  v_r := public.provision_offline_voucher(v_line, 'l_test_device');
  PERFORM set_config('role', 'postgres', true);
  INSERT INTO l_results VALUES ('T01 off means off',
    CASE WHEN v_r ->> 'code' = 'FEATURE_OFF' THEN 'PASS' ELSE 'FAIL' END, v_r::text);

  ----------------------------------------------------------------- T02 ------
  -- Deny-all: no client reads a PIN, encrypted or otherwise.
  PERFORM set_config('role', 'authenticated', true);
  BEGIN
    PERFORM 1 FROM public.offline_voucher_stock LIMIT 1;
    v_msg := 'SELECT succeeded'; v_ok := false;
  EXCEPTION WHEN insufficient_privilege THEN v_msg := '42501'; v_ok := true;
  END;
  PERFORM set_config('role', 'postgres', true);
  INSERT INTO l_results VALUES ('T02 stock table unreadable by clients',
    CASE WHEN v_ok THEN 'PASS' ELSE 'FAIL' END, v_msg);

  ----------------------------------------------------------------- T03 ------
  -- The crypto helpers are not a back door.
  PERFORM set_config('role', 'authenticated', true);
  BEGIN
    PERFORM public.voucher_decrypt_pin('\x00'::bytea);
    v_msg := 'call succeeded'; v_ok := false;
  EXCEPTION WHEN insufficient_privilege THEN v_msg := '42501'; v_ok := true;
  WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE;
    v_msg := v_state; v_ok := false;
  END;
  PERFORM set_config('role', 'postgres', true);
  INSERT INTO l_results VALUES ('T03 decrypt not callable by a client',
    CASE WHEN v_ok THEN 'PASS' ELSE 'FAIL' END, v_msg);

  ----------------------------------------------------------------- T04 ------
  PERFORM set_config('role', 'authenticated', true);
  BEGIN
    PERFORM public.admin_list_voucher_stock(NULL, NULL, 10);
    v_state := 'none';
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE;
  END;
  PERFORM set_config('role', 'postgres', true);
  INSERT INTO l_results VALUES ('T04 admin RPC refuses a normal user',
    CASE WHEN v_state IN ('KS460','42501') THEN 'PASS' ELSE 'FAIL' END, v_state);

  UPDATE public.system_configs SET config_value = 'true'
   WHERE config_key = 'OFFLINE_VOUCHER_ENABLED';

  ----------------------------------------------------------------- T05 ------
  PERFORM set_config('role', 'authenticated', true);
  v_r := public.provision_offline_voucher(v_line2, 'l_test_device');
  PERFORM set_config('role', 'postgres', true);
  INSERT INTO l_results VALUES ('T05 a free line gets no PIN',
    CASE WHEN v_r ->> 'code' = 'NOT_PREMIUM' THEN 'PASS' ELSE 'FAIL' END, v_r::text);

  ----------------------------------------------------------------- T06 ------
  -- No stock is an operations task with a deadline, not a shrug.
  PERFORM set_config('role', 'authenticated', true);
  v_r := public.provision_offline_voucher(v_line, 'l_test_device');
  PERFORM set_config('role', 'postgres', true);
  SELECT count(*) INTO v_n FROM public.offline_voucher_requests
   WHERE sim_line_id = v_line AND status = 'open'
     AND due_at BETWEEN now() + make_interval(days => v_sla) - interval '1 minute'
                    AND now() + make_interval(days => v_sla) + interval '1 minute';
  INSERT INTO l_results VALUES ('T06 no stock opens an SLA request',
    CASE WHEN v_r ->> 'code' = 'NO_STOCK' AND v_n = 1 THEN 'PASS' ELSE 'FAIL' END,
    format('%s rows=%s', v_r::text, v_n));

  -- ── Load two PINs at different face values ──────────────────────────────
  INSERT INTO public.offline_voucher_stock
    (carrier_id, source, pin_encrypted, pin_fingerprint, face_value_usd, expires_at, load_note)
  VALUES (v_carrier, 'manual', public.voucher_encrypt_pin(v_pin),
          public.voucher_pin_fingerprint(v_carrier, v_pin), 2.50,
          now() + interval '200 days', 'l_test stock 1')
  RETURNING id INTO v_stock1;

  INSERT INTO public.offline_voucher_stock
    (carrier_id, source, pin_encrypted, pin_fingerprint, face_value_usd, expires_at, load_note)
  VALUES (v_carrier, 'manual', public.voucher_encrypt_pin(v_pin2),
          public.voucher_pin_fingerprint(v_carrier, v_pin2), 9.00,
          now() + interval '200 days', 'l_test stock 2')
  RETURNING id INTO v_stock2;

  ----------------------------------------------------------- T07 T08 T09 ----
  PERFORM set_config('role', 'authenticated', true);
  v_r := public.provision_offline_voucher(v_line, 'l_test_device');
  v_grant := (v_r ->> 'grant_id')::uuid;
  -- A different device id: a reinstall wipes the keystore, and someone about
  -- to lose signal must not be stranded holding a PIN they cannot read — nor
  -- be handed a second one.
  v_r2 := public.provision_offline_voucher(v_line, 'l_test_device_2');
  PERFORM set_config('role', 'postgres', true);

  INSERT INTO l_results VALUES ('T07 the PIN survives the round trip',
    CASE WHEN v_r ->> 'pin' = v_pin AND (v_r ->> 'face_value_usd')::numeric = 2.50
          AND (v_r ->> 'reissued')::boolean = false THEN 'PASS' ELSE 'FAIL' END,
    format('pin=%s face=%s cheapest_first=%s', v_r ->> 'pin', v_r ->> 'face_value_usd',
           v_r ->> 'pin' = v_pin));

  SELECT count(*) INTO v_n FROM public.offline_voucher_stock
   WHERE carrier_id = v_carrier AND status = 'issued';
  INSERT INTO l_results VALUES ('T08 re-provision is idempotent',
    CASE WHEN (v_r2 ->> 'grant_id')::uuid = v_grant AND v_r2 ->> 'pin' = v_pin
          AND (v_r2 ->> 'reissued')::boolean = true AND v_n = 1
         THEN 'PASS' ELSE 'FAIL' END,
    format('same_grant=%s issued_rows=%s', (v_r2 ->> 'grant_id')::uuid = v_grant, v_n));

  SELECT count(*) INTO v_n FROM public.offline_voucher_requests
   WHERE sim_line_id = v_line AND status = 'open';
  INSERT INTO l_results VALUES ('T09 issuing closes the fulfilment request',
    CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL' END, format('open_requests=%s', v_n));

  ----------------------------------------------------------------- T10 ------
  -- 🔒 THE CAP IS AN INDEX.
  BEGIN
    INSERT INTO public.offline_voucher_grants (user_id, sim_line_id, stock_id)
    VALUES (v_user, v_line, v_stock2);
    v_ok := false; v_msg := 'the index allowed it';
  EXCEPTION WHEN unique_violation THEN
    v_ok := true; v_msg := '23505 from offline_voucher_grants_one_live_per_line';
  END;
  INSERT INTO l_results VALUES ('T10 a second live voucher is impossible',
    CASE WHEN v_ok THEN 'PASS' ELSE 'FAIL' END, v_msg);

  ------------------------------------------------------------- T11 T12 ------
  -- A device clock a year fast must not park the debt in the future where no
  -- reminder ever fires. The timestamp is client-supplied; it gets clamped.
  PERFORM set_config('role', 'authenticated', true);
  v_r := public.report_offline_voucher_reveal(v_grant, now() + interval '365 days');
  v_r2 := public.report_offline_voucher_reveal(v_grant, now());
  PERFORM set_config('role', 'postgres', true);

  v_due := (v_r ->> 'amount_due_usd')::numeric;
  v_ts  := (v_r ->> 'revealed_at')::timestamptz;
  INSERT INTO l_results VALUES ('T11 reveal prices the debt and clamps the clock',
    CASE WHEN v_due = round(2.50 * (1 + v_fee/100.0), 2)
          AND v_ts <= now() + interval '1 second' THEN 'PASS' ELSE 'FAIL' END,
    format('due=%s revealed_at=%s fee_pct=%s', v_due, v_ts, v_fee));

  SELECT amount_due_usd INTO v_due FROM public.offline_voucher_grants WHERE id = v_grant;
  INSERT INTO l_results VALUES ('T12 reveal is idempotent',
    CASE WHEN (v_r2 ->> 'already_reported')::boolean = true
          AND v_due = round(2.50 * (1 + v_fee/100.0), 2) THEN 'PASS' ELSE 'FAIL' END,
    v_r2::text);

  ----------------------------------------------------------------- T13 ------
  -- The debt is the gate. This is the whole commercial loop.
  PERFORM set_config('role', 'authenticated', true);
  v_r := public.provision_offline_voucher(v_line, 'l_test_device');
  PERFORM set_config('role', 'postgres', true);
  INSERT INTO l_results VALUES ('T13 an unsettled voucher blocks the next one',
    CASE WHEN v_r ->> 'code' = 'SETTLEMENT_DUE' AND (v_r ->> 'grant_id')::uuid = v_grant
          AND NOT (v_r ? 'pin') THEN 'PASS' ELSE 'FAIL' END, v_r::text);

  ----------------------------------------------------------------- T14 ------
  UPDATE public.wallets SET balance = 0.00 WHERE user_id = v_user;
  PERFORM set_config('role', 'authenticated', true);
  v_r := public.settle_offline_voucher(v_grant);
  PERFORM set_config('role', 'postgres', true);
  SELECT count(*) INTO v_n FROM public.wallet_transactions
   WHERE reference_id = 'voucher_' || v_grant::text;
  INSERT INTO l_results VALUES ('T14 no funds refuses without moving money',
    CASE WHEN v_r ->> 'code' = 'INSUFFICIENT_FUNDS' AND v_n = 0 THEN 'PASS' ELSE 'FAIL' END,
    format('%s ledger_rows=%s', v_r::text, v_n));

  ------------------------------------------------------------- T15 T16 ------
  -- A double tap, or a retry after a dropped response, must not charge twice.
  -- The LEDGER is the authority, not the grant's status.
  UPDATE public.wallets SET balance = 50.00 WHERE user_id = v_user;
  PERFORM set_config('role', 'authenticated', true);
  v_r  := public.settle_offline_voucher(v_grant);
  v_r2 := public.settle_offline_voucher(v_grant);
  PERFORM set_config('role', 'postgres', true);

  SELECT balance INTO v_bal FROM public.wallets WHERE user_id = v_user;
  SELECT count(*) INTO v_n FROM public.wallet_transactions
   WHERE reference_id = 'voucher_' || v_grant::text AND type = 'offline_voucher_debit';

  INSERT INTO l_results VALUES ('T15 settling debits the wallet once',
    CASE WHEN (v_r ->> 'success')::boolean AND v_n = 1
          AND v_bal = 50.00 - round(2.50 * (1 + v_fee/100.0), 2)
         THEN 'PASS' ELSE 'FAIL' END,
    format('balance=%s rows=%s resp=%s', v_bal, v_n, left(v_r::text, 80)));

  INSERT INTO l_results VALUES ('T16 settling twice charges once',
    CASE WHEN (v_r2 ->> 'already_settled')::boolean = true AND v_n = 1
          AND v_bal = 50.00 - round(2.50 * (1 + v_fee/100.0), 2)
         THEN 'PASS' ELSE 'FAIL' END, format('rows=%s balance=%s', v_n, v_bal));

  ------------------------------------------------------------- T17 T18 ------
  -- If T17 fails the feature is a one-shot and "pay so you can have another"
  -- is a lie.
  PERFORM set_config('role', 'authenticated', true);
  v_r  := public.provision_offline_voucher(v_line, 'l_test_device');
  v_r2 := public.offline_voucher_state();
  PERFORM set_config('role', 'postgres', true);

  INSERT INTO l_results VALUES ('T17 settling unblocks the next voucher',
    CASE WHEN (v_r ->> 'success')::boolean AND v_r ->> 'pin' = v_pin2
         THEN 'PASS' ELSE 'FAIL' END,
    format('code=%s second_stock=%s', v_r ->> 'code', v_r ->> 'pin' = v_pin2));

  INSERT INTO l_results VALUES ('T18 the status poll leaks no PIN',
    CASE WHEN v_r2::text NOT LIKE '%' || v_pin2 || '%'
          AND v_r2::text NOT LIKE '%' || v_pin || '%'
          AND (v_r2 ->> 'enabled')::boolean THEN 'PASS' ELSE 'FAIL' END,
    left(v_r2::text, 90));

  ------------------------------------------------------------- T19 T20 ------
  -- Under a forged power-user claim. `is_power_user()` reads app_metadata from
  -- the JWT, NOT profiles.is_power_user — setting the column does not grant
  -- admin and never has (F4b).
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_user, 'role', 'authenticated',
                      'app_metadata', json_build_object('is_power_user', true))::text, true);
  PERFORM set_config('role', 'authenticated', true);

  v_r := public.admin_add_voucher_stock(
    v_carrier,
    jsonb_build_array(v_pin, 'LTEST-NEW-0001', jsonb_build_object('pin', 'LTEST-NEW-0002')),
    jsonb_build_object('face_value_usd', 2.50), 'l_test bulk');

  -- An unverified dial code is worse than none: it is dialled by someone with
  -- no signal and no credit and cannot be taken back.
  BEGIN
    PERFORM public.admin_upsert_carrier_voucher_redemption(
      v_carrier, jsonb_build_object('instructions', 'x', 'redeem_ussd_template', '*102#'), NULL);
    v_state := 'none';
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE;
  END;
  PERFORM set_config('role', 'postgres', true);

  INSERT INTO l_results VALUES ('T19 bulk load skips duplicates, loads the rest',
    CASE WHEN (v_r ->> 'added')::int = 2 AND (v_r ->> 'skipped_duplicates')::int = 1
         THEN 'PASS' ELSE 'FAIL' END, v_r::text);

  INSERT INTO l_results VALUES ('T20 a redeem template without the PIN token is refused',
    CASE WHEN v_state = 'KS466' THEN 'PASS' ELSE 'FAIL' END, v_state);
END $$;

-- Only the LAST select comes back through MCP, and RAISE NOTICE output is
-- discarded entirely — so the verdict and the detail have to travel together.
SELECT count(*) FILTER (WHERE outcome = 'PASS') AS passed,
       count(*) FILTER (WHERE outcome = 'FAIL') AS failed,
       string_agg(t || ' :: ' || outcome || ' :: ' || COALESCE(detail,''), E'\n' ORDER BY t) AS report
FROM l_results;

ROLLBACK;
