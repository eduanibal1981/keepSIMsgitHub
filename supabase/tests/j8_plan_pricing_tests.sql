-- ============================================================================
-- J8 — one plan price, two rails.
--
-- The bug this file exists to keep fixed: on 2026-08-08 a Premium line was
-- created for +966555554444555 (Zain KSA), the PayPal money went to the WALLET
-- as a deposit, no plan charge of any kind was ever made, and
-- `queue_premium_refill_executions` correctly refused the line with KS403 —
-- reported to the subscriber as "Failed to save SIM line" over a row that
-- already existed. Nothing downstream was broken; the plan had simply never
-- been paid for, because the add-line screen had no code path that charged for
-- Premium at all.
--
-- What is asserted here:
--   1. the price is computed once, server-side, from the deactivation window
--      (i7/i7c cadence) — not from `topup_validity_days`, which quoted 13
--      refills against a carrier that needs 5;
--   2. the wallet rail can buy Premium, and the debit it writes is exactly what
--      `has_paid_premium_entitlement` reads, so the queue succeeds;
--   3. a plan the refill queue would refuse has no price on either rail, so no
--      screen can take the money first and discover it afterwards.
--
-- ============================================================================
-- HOW TO RUN — as ONE execute_sql call. MCP makes each call its own
-- transaction, so a split file never pairs BEGIN with ROLLBACK. Everything
-- below is rolled back; run it and then re-check that
-- `wallet_transactions.reference_id LIKE 'j8_test%'` returns 0 rows.
-- ============================================================================
-- Last run 2026-08-08 (J8): 11/11 PASSED.
-- ============================================================================

BEGIN;

CREATE TEMP TABLE j8_results(t text, outcome text, detail text) ON COMMIT DROP;
GRANT ALL ON j8_results TO authenticated;

DO $$
DECLARE
  v_rule        RECORD;
  v_line        RECORD;
  v_expected    numeric;
  v_net         numeric;
  v_gross       numeric;
  v_gw_pct      numeric;
  v_gw_fixed    numeric;
  v_base        numeric;
  v_app         numeric;
  v_margin      numeric;
  v_flat        numeric;
  v_step        int;
  v_refills     int;
  v_r           jsonb;
  v_ent         boolean;
  v_count       int;
  v_state       text;
  v_msg         text;
  v_bal_before  numeric;
  v_bal_after   numeric;
  v_txns        int;
BEGIN
  SELECT COALESCE(config_value::numeric, 2.50) INTO v_base
  FROM public.system_configs WHERE config_key = 'BASE_SERVICE_FEE_USD';
  SELECT COALESCE(config_value::numeric, 3.0) INTO v_app
  FROM public.system_configs WHERE config_key = 'APP_FEE_PERCENT';
  SELECT COALESCE(config_value::numeric, 5.0) INTO v_margin
  FROM public.system_configs WHERE config_key = 'PREMIUM_MARGIN_PERCENT';
  SELECT COALESCE(config_value::numeric, 0.324) INTO v_flat
  FROM public.system_configs WHERE config_key = 'PREMIUM_MARGIN_PER_REFILL_USD';
  SELECT fee_percentage, fee_fixed INTO v_gw_pct, v_gw_fixed
  FROM public.payment_gateways WHERE code = 'paypal' AND is_active;

  -- ── T1: Standard is the flat service fee on the wallet rail ──────────────
  INSERT INTO j8_results
  SELECT 'T1 standard net = BASE_SERVICE_FEE_USD',
         CASE WHEN public.plan_price_net('standard') = v_base THEN 'PASS' ELSE 'FAIL' END,
         '$' || public.plan_price_net('standard');

  -- ── T2: Premium is priced off the DEACTIVATION WINDOW, not the bundle ────
  -- Recomputed here from the rule's own columns rather than hardcoded, so the
  -- test still means something after a config or carrier-rule change.
  SELECT cr.* INTO v_rule
  FROM public.carrier_rules cr
  WHERE cr.activity_requirement = 'recharge_ok'
    AND cr.minimum_topup_amount > 0
    AND (cr.inapp_pricing IS NULL OR cr.inapp_pricing <= 0)
    AND cr.inactivity_limit_days > 0
  ORDER BY cr.created_at
  LIMIT 1;

  v_step    := public.refill_interval_days(v_rule.inactivity_limit_days,
                                           v_rule.refill_interval_days_override);
  v_refills := ceil(365.0 / v_step);
  v_expected := v_base
              + ((v_rule.minimum_topup_amount * (1 + (v_app + v_margin) / 100.0)) + v_flat)
                * v_refills;
  v_net := public.plan_price_net('premium', NULL, v_rule.id);

  INSERT INTO j8_results VALUES ('T2 premium net follows refill_interval_days',
    CASE WHEN round(v_net, 6) = round(v_expected, 6) THEN 'PASS' ELSE 'FAIL' END,
    format('%s: window %s ⇒ step %s ⇒ %s refills ⇒ $%s',
           v_rule.id, v_rule.inactivity_limit_days, v_step, v_refills, round(v_net, 2)));

  -- ── T3: and NOT off topup_validity_days, the pre-J8 formula ──────────────
  INSERT INTO j8_results VALUES ('T3 the bundle cycle no longer sets the price',
    CASE WHEN v_rule.topup_validity_days IS NULL
              OR ceil(365.0 / v_rule.topup_validity_days) = v_refills
              OR round(v_net, 2) <> round(v_base + ((v_rule.minimum_topup_amount
                   * (1 + (v_app + v_margin) / 100.0)) + v_flat)
                   * ceil(365.0 / v_rule.topup_validity_days), 2)
         THEN 'PASS' ELSE 'FAIL' END,
    format('validity %s ⇒ would have been %s refills',
           v_rule.topup_validity_days,
           ceil(365.0 / NULLIF(v_rule.topup_validity_days, 0))));

  -- ── T4: the PayPal rail is the same net, grossed up once ─────────────────
  v_gross := public.quote_plan_price(NULL, 'premium', 'paypal', v_rule.id);
  INSERT INTO j8_results VALUES ('T4 paypal quote = gross_up(net)',
    CASE WHEN v_gross = round((v_net + v_gw_fixed) / (1 - v_gw_pct / 100.0), 2)
         THEN 'PASS' ELSE 'FAIL' END,
    format('net $%s ⇒ paypal $%s', round(v_net, 2), v_gross));

  -- ── T5: the wallet rail is strictly cheaper — the reason to bill it first ─
  INSERT INTO j8_results VALUES ('T5 wallet rail is cheaper than paypal',
    CASE WHEN public.quote_plan_price(NULL, 'premium', 'wallet', v_rule.id) < v_gross
         THEN 'PASS' ELSE 'FAIL' END,
    format('wallet $%s vs paypal $%s',
           public.quote_plan_price(NULL, 'premium', 'wallet', v_rule.id), v_gross));

  -- ── T6: a plan the queue would refuse has no price on either rail ────────
  -- i7 gated this in three Flutter screens with a note that a fourth would need
  -- its own copy. Pricing is the one thing every screen must pass through.
  BEGIN
    PERFORM public.quote_plan_price(NULL, 'premium', 'paypal',
      (SELECT id FROM public.carrier_rules WHERE activity_requirement = 'usage_required' LIMIT 1));
    INSERT INTO j8_results VALUES ('T6 usage_required has no price', 'FAIL', 'it was priced');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    INSERT INTO j8_results VALUES ('T6 usage_required has no price',
      CASE WHEN v_state = 'KS422' THEN 'PASS' ELSE 'FAIL' END, v_state || ' ' || left(v_msg, 60));
  END;

  -- ── T7: premium with no resolvable carrier refuses, never invents one ────
  -- The old function fell back to COALESCE(min_topup, 10.0) / 30 days, which
  -- produced a plausible price for a carrier nobody had configured. A
  -- plausible wrong price is charged without anyone noticing.
  BEGIN
    PERFORM public.quote_plan_price(NULL, 'premium', 'paypal', NULL);
    INSERT INTO j8_results VALUES ('T7 no carrier ⇒ no price', 'FAIL', 'it was priced');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE;
    INSERT INTO j8_results VALUES ('T7 no carrier ⇒ no price',
      CASE WHEN v_state = '22023' THEN 'PASS' ELSE 'FAIL' END, v_state);
  END;

  -- ── T8..T11: the wallet rail end to end, as a real signed-in subscriber ──
  SELECT sl.id AS line_id, sl.user_id, sl.carrier_rule_id, st.id AS schedule_id
  INTO v_line
  FROM public.sim_lines sl
  JOIN public.scheduled_topups st
    ON st.sim_line_id = sl.id AND st.schedule_type = 'refill_mini'
  WHERE lower(coalesce(sl.plan_type, '')) = 'premium'
    AND sl.carrier_rule_id IS NOT NULL
    AND sl.plan_expires_at > now()
    -- A grandfathered line is entitled whatever happens, so it cannot show
    -- that the debit is what makes the difference.
    AND NOT EXISTS (SELECT 1 FROM public.premium_entitlement_grandfather g
                    WHERE g.sim_line_id = sl.id)
  ORDER BY sl.created_at DESC NULLS LAST
  LIMIT 1;

  IF NOT FOUND THEN
    INSERT INTO j8_results VALUES ('T8-T11 wallet rail end to end', 'SKIP',
      'no non-grandfathered premium line with a refill_mini schedule exists');
  ELSE
    v_net := round(public.plan_price_net('premium', v_line.line_id), 2);

    -- Fund the wallet inside the transaction so the test is self-contained.
    SELECT balance INTO v_bal_before FROM public.wallets WHERE user_id = v_line.user_id;
    UPDATE public.wallets SET balance = v_net WHERE user_id = v_line.user_id;

    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_line.user_id, 'role', 'authenticated')::text, true);

    SELECT public.has_paid_premium_entitlement(v_line.line_id) INTO v_ent;
    INSERT INTO j8_results VALUES ('T8 entitlement absent before payment',
      CASE WHEN v_ent THEN 'FAIL' ELSE 'PASS' END, 'entitled = ' || v_ent);

    PERFORM set_config('role', 'authenticated', true);
    v_r := public.pay_plan_fee_from_wallet('j8_test_premium', v_line.line_id,
             'j8-test-device', 'premium', v_line.carrier_rule_id);

    -- A replay of the same reference must answer from the ledger, not debit
    -- again: this is the guarantee the client leans on when a save fails after
    -- the charge.
    PERFORM public.pay_plan_fee_from_wallet('j8_test_premium', v_line.line_id,
             'j8-test-device', 'premium', v_line.carrier_rule_id);
    PERFORM set_config('role', 'postgres', true);

    SELECT count(*) INTO v_txns FROM public.wallet_transactions
    WHERE reference_id = 'j8_test_premium' AND type = 'plan_fee_debit';
    SELECT balance INTO v_bal_after FROM public.wallets WHERE user_id = v_line.user_id;

    INSERT INTO j8_results VALUES ('T9 premium debited once at the server price',
      CASE WHEN (v_r ->> 'success')::boolean
            AND (v_r ->> 'amount')::numeric = v_net
            AND v_txns = 1
            AND v_bal_after = 0.00
           THEN 'PASS' ELSE 'FAIL' END,
      format('$%s debited, %s ledger row(s), balance $%s', v_net, v_txns, v_bal_after));

    SELECT public.has_paid_premium_entitlement(v_line.line_id) INTO v_ent;
    INSERT INTO j8_results VALUES ('T10 the debit IS the entitlement',
      CASE WHEN v_ent THEN 'PASS' ELSE 'FAIL' END, 'entitled = ' || v_ent);

    -- The call that produced the reported error message.
    PERFORM set_config('role', 'authenticated', true);
    BEGIN
      v_count := public.queue_premium_refill_executions(v_line.line_id, v_line.schedule_id);
      INSERT INTO j8_results VALUES ('T11 the refill queue no longer refuses',
        CASE WHEN v_count > 0 THEN 'PASS' ELSE 'FAIL' END, v_count || ' executions queued');
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
      INSERT INTO j8_results VALUES ('T11 the refill queue no longer refuses', 'FAIL',
        v_state || ' ' || left(v_msg, 90));
    END;
    PERFORM set_config('role', 'postgres', true);
  END IF;
END $$;

SELECT * FROM j8_results ORDER BY t;
SELECT count(*) FILTER (WHERE outcome = 'PASS') AS passed,
       count(*) FILTER (WHERE outcome = 'FAIL') AS failed,
       count(*) FILTER (WHERE outcome = 'SKIP') AS skipped
FROM j8_results;

ROLLBACK;
