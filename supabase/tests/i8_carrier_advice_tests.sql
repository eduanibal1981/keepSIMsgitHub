-- ============================================================================
-- I8 — carrier rule transparency + the self-service advice notification.
--
-- The two things worth asserting here are the two that would be invisible if
-- they broke:
--
--   * the ADVICE IS SHIPPED OFF. `CARRIER_ADVICE_ENABLED` defaults false per
--     the owner's pre-production instruction, and a master switch that does not
--     actually stop the send is the "installed and doing nothing" failure in
--     reverse — a nightly job quietly messaging every user.
--   * the ADVICE GOES TO THE RIGHT LINES. It exists to tell people to spend
--     money somewhere other than here. Sending it to a subscriber who already
--     paid us to automate their refills would be both noise and untrue.
--
-- ============================================================================
-- HOW TO RUN — as ONE execute_sql call. MCP makes each call its own
-- transaction, so a split file never pairs BEGIN with ROLLBACK.
-- ============================================================================
-- Last run 2026-08-05 (I8/I8b applied): 9/9 PASSED.
-- ============================================================================

BEGIN;

CREATE TEMP TABLE i8_results(t text, outcome text) ON COMMIT DROP;
GRANT INSERT ON i8_results TO authenticated;

DO $$
DECLARE
  v_user      uuid;
  v_line      uuid;
  v_carrier   uuid;
  v_country   uuid;
  v_res       jsonb;
  v_n         int;
  v_txt       text;
  v_passed    int := 0;
  v_expected  int := 9;
BEGIN
  SELECT id INTO v_user FROM public.profiles ORDER BY created_at LIMIT 1;

  -- A carrier of our own, so the fixtures cannot disturb a live line's rules.
  SELECT id INTO v_country FROM public.countries WHERE iso_code = 'EG';
  INSERT INTO public.carriers (country_id, name, is_supported)
  VALUES (v_country, 'I8 Test Carrier', true) RETURNING id INTO v_carrier;

  INSERT INTO public.carrier_rules
    (carrier_id, rule_type, inactivity_limit_days, grace_period_days,
     minimum_topup_amount, topup_validity_days, inapp_pricing,
     inapp_pricing_currency, activity_requirement)
  VALUES (v_carrier, 'prepaid', 90, 30, 5.00, 30, 0, 'usd', 'recharge_ok');

  INSERT INTO public.sim_lines
    (user_id, phone_number, country_id, carrier_id, status, plan_type,
     protection_tier, next_topup_due)
  VALUES (v_user, '+2010000000001', v_country, v_carrier, 'active', 'standard',
          'standard', now() + interval '5 days')
  RETURNING id INTO v_line;

  -- ------------------------------------------------------------------ T1
  -- The master switch actually stops the send. With ENABLED=false a live run
  -- must write nothing at all, not merely "nothing today".
  UPDATE public.system_configs SET config_value = 'false'
   WHERE config_key = 'CARRIER_ADVICE_ENABLED';

  v_res := public.emit_carrier_self_service_advice(false);
  SELECT count(*) INTO v_n FROM public.notifications
   WHERE category = 'carrier_action' AND sim_line_id = v_line;

  IF (v_res ->> 'enabled')::boolean = false AND (v_res ->> 'sent')::int = 0
     AND v_n = 0 THEN
    INSERT INTO i8_results VALUES ('T1 disabled switch sends nothing', 'PASS');
    v_passed := v_passed + 1;
  ELSE
    INSERT INTO i8_results VALUES ('T1 disabled switch sends nothing',
      'FAIL: ' || v_res::text || ' rows=' || v_n);
  END IF;

  -- ------------------------------------------------------------------ T2
  -- A dry run ignores the switch — that is how the owner sees who would be
  -- told what before flipping it — and still writes nothing.
  v_res := public.emit_carrier_self_service_advice(true);
  SELECT count(*) INTO v_n FROM public.notifications
   WHERE category = 'carrier_action' AND sim_line_id = v_line;

  IF v_n = 0 AND EXISTS (
       SELECT 1 FROM jsonb_array_elements(v_res -> 'preview') e
        WHERE (e ->> 'sim_line_id')::uuid = v_line
          AND e ->> 'reason' = 'no_automation') THEN
    INSERT INTO i8_results VALUES ('T2 dry run previews without writing', 'PASS');
    v_passed := v_passed + 1;
  ELSE
    INSERT INTO i8_results VALUES ('T2 dry run previews without writing',
      'FAIL: ' || v_res::text || ' rows=' || v_n);
  END IF;

  -- ------------------------------------------------------------------ T3
  -- Enabled, it sends — and the body names the operator's own app, which is
  -- the entire point of the notification.
  UPDATE public.system_configs SET config_value = 'true'
   WHERE config_key = 'CARRIER_ADVICE_ENABLED';

  v_res := public.emit_carrier_self_service_advice(false);
  SELECT body INTO v_txt FROM public.notifications
   WHERE category = 'carrier_action' AND sim_line_id = v_line;

  IF v_txt IS NOT NULL AND v_txt LIKE '%official app%' THEN
    INSERT INTO i8_results VALUES ('T3 enabled run sends self-service advice', 'PASS');
    v_passed := v_passed + 1;
  ELSE
    INSERT INTO i8_results VALUES ('T3 enabled run sends self-service advice',
      'FAIL: ' || COALESCE(v_txt, '<none>'));
  END IF;

  -- ------------------------------------------------------------------ T4
  -- The cooldown holds. Running again immediately must not re-send: this is
  -- the difference between advice and nagging, and the lines that most need
  -- this notification are exactly the ones that stay in the window for weeks.
  v_res := public.emit_carrier_self_service_advice(false);
  SELECT count(*) INTO v_n FROM public.notifications
   WHERE category = 'carrier_action' AND sim_line_id = v_line;

  IF v_n = 1 THEN
    INSERT INTO i8_results VALUES ('T4 cooldown blocks a second send', 'PASS');
    v_passed := v_passed + 1;
  ELSE
    INSERT INTO i8_results VALUES ('T4 cooldown blocks a second send',
      'FAIL: ' || v_n || ' notifications');
  END IF;

  -- ------------------------------------------------------------------ T5
  -- A premium line on an ordinary carrier is never advised to shop elsewhere.
  -- It is already being refilled by us; the advice would be untrue.
  DELETE FROM public.notifications WHERE sim_line_id = v_line;
  UPDATE public.sim_lines
     SET plan_type = 'premium', plan_expires_at = now() + interval '300 days'
   WHERE id = v_line;
  INSERT INTO public.premium_entitlement_grandfather (sim_line_id, reason)
  VALUES (v_line, 'i8 test fixture');

  v_res := public.emit_carrier_self_service_advice(false);
  SELECT count(*) INTO v_n FROM public.notifications
   WHERE category = 'carrier_action' AND sim_line_id = v_line;

  IF v_n = 0 THEN
    INSERT INTO i8_results VALUES ('T5 a paid premium line is left alone', 'PASS');
    v_passed := v_passed + 1;
  ELSE
    INSERT INTO i8_results VALUES ('T5 a paid premium line is left alone',
      'FAIL: ' || v_n || ' notifications');
  END IF;

  -- ------------------------------------------------------------------ T6
  -- ...unless the carrier only counts real usage, where the paid premium is
  -- irrelevant: nothing we send can hold that line, so the owner must be told
  -- regardless of what they bought.
  UPDATE public.carrier_rules SET activity_requirement = 'usage_required'
   WHERE carrier_id = v_carrier;

  v_res := public.emit_carrier_self_service_advice(false);
  SELECT body INTO v_txt FROM public.notifications
   WHERE category = 'carrier_action' AND sim_line_id = v_line;

  IF v_txt IS NOT NULL AND v_txt LIKE '%call, sends an SMS or uses data%' THEN
    INSERT INTO i8_results VALUES ('T6 usage_required overrides a paid plan', 'PASS');
    v_passed := v_passed + 1;
  ELSE
    INSERT INTO i8_results VALUES ('T6 usage_required overrides a paid plan',
      'FAIL: ' || COALESCE(v_txt, '<none>'));
  END IF;

  -- ------------------------------------------------------------------ T7
  -- Every existing account can mute it. A category present in the CHECK but
  -- absent from alert_settings is a category with no switch in the UI, which
  -- is how a notification becomes un-turn-off-able.
  SELECT count(*) INTO v_n FROM public.profiles p
   WHERE NOT EXISTS (SELECT 1 FROM public.alert_settings a
                      WHERE a.user_id = p.id AND a.category = 'carrier_action');

  IF v_n = 0 THEN
    INSERT INTO i8_results VALUES ('T7 every profile can mute carrier_action', 'PASS');
    v_passed := v_passed + 1;
  ELSE
    INSERT INTO i8_results VALUES ('T7 every profile can mute carrier_action',
      'FAIL: ' || v_n || ' profiles without a row');
  END IF;

  -- ------------------------------------------------------------------ T8
  -- carrier_self_service is catalogue data: read for anyone signed in, and no
  -- write verb for anon or authenticated. A new public table arrives carrying
  -- the default GRANT ALL, and TRUNCATE is not RLS-filtered (G5b).
  SELECT count(*) INTO v_n
    FROM information_schema.role_table_grants
   WHERE table_schema = 'public' AND table_name = 'carrier_self_service'
     AND grantee IN ('anon', 'authenticated', 'PUBLIC')
     AND privilege_type <> 'SELECT';

  IF v_n = 0 AND EXISTS (
       SELECT 1 FROM information_schema.role_table_grants
        WHERE table_schema = 'public' AND table_name = 'carrier_self_service'
          AND grantee = 'authenticated' AND privilege_type = 'SELECT') THEN
    INSERT INTO i8_results VALUES ('T8 self-service registry is read-only to clients', 'PASS');
    v_passed := v_passed + 1;
  ELSE
    INSERT INTO i8_results VALUES ('T8 self-service registry is read-only to clients',
      'FAIL: ' || v_n || ' non-SELECT client grants');
  END IF;

  -- ------------------------------------------------------------------ T9
  -- The emitter reads every user's lines and writes to every user's
  -- notifications. It must be service_role-only and must never reach the F0
  -- authenticated allow-list.
  SELECT count(*) INTO v_n
    FROM pg_proc p
    JOIN pg_namespace nsp ON nsp.oid = p.pronamespace
   WHERE nsp.nspname = 'public'
     AND p.proname = 'emit_carrier_self_service_advice'
     AND (has_function_privilege('anon', p.oid, 'EXECUTE')
       OR has_function_privilege('authenticated', p.oid, 'EXECUTE'));

  IF v_n = 0 THEN
    INSERT INTO i8_results VALUES ('T9 emitter is service_role-only', 'PASS');
    v_passed := v_passed + 1;
  ELSE
    INSERT INTO i8_results VALUES ('T9 emitter is service_role-only',
      'FAIL: reachable by a client role');
  END IF;

  RAISE NOTICE 'I8: % of % passed', v_passed, v_expected;
END $$;

SELECT * FROM i8_results ORDER BY t;

ROLLBACK;
