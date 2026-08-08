-- =============================================================================
-- J8 · One server-side price for a plan, and a wallet rail that can buy Premium
-- =============================================================================
-- REPORTED SYMPTOM (2026-08-08, live): saving a Premium line on "Protect New
-- Line" ends with
--
--   Failed to save SIM line: Exception: Exception: Failed to schedule premium
--   refills: This line has no paid, unexpired premium plan, so pre-paid refills
--   cannot be queued.
--
-- That sentence is I2b's KS403 in `queue_premium_refill_executions`, and it was
-- telling the truth. Forensics on the failed attempt (line
-- a716e5fb… / +966555554444555, Zain KSA):
--
--   02:06:31  sim_lines row inserted, plan_type = 'premium'
--   02:06:32  queue_premium_refill_executions → KS403, whole save reported failed
--   02:06:48  wallet_transactions: deposit $9.52 (PayPal order 4YL62738T835…)
--
-- No `plan_fee_debit`, no `plan_payments` row — ever. `sim_line_form_screen`
-- pushed PayPal with `paymentKind: 'deposit'`, so the money landed in the
-- WALLET, and the premium branch of its `onSuccess` went straight to
-- `commitSave()` with no debit of any kind. The Standard branch beside it does
-- `waitForWalletCredit` → `tryStandardFromWallet` → commit. Premium had no such
-- branch, so **no Premium line bought on that screen has ever been paid for**;
-- the entitlement guard is simply the first thing downstream that noticed.
--
-- WHY THE FIX IS PARTLY IN THE DATABASE
-- The obvious client fix — debit the wallet like Standard does — could not be
-- written, because `pay_plan_fee_from_wallet` can only charge one number:
-- `BASE_SERVICE_FEE_USD`. There was no server-side way to charge for a year of
-- Premium at all. The other two purchase surfaces avoid that by billing PayPal
-- with `kind='plan'`, which prices from `quote_plan_price` — and that function
-- has been wrong since i7:
--
--   * it still derives the refill count from `topup_validity_days`, the bundle
--     cycle that i7 established is NOT the cadence, and that i7c removed from
--     `queue_premium_refill_executions` in favour of `refill_interval_days()`.
--     Zain KSA: validity 30 ⇒ 13 refills quoted and charged, against the 5 the
--     queue actually lays down. The subscriber is shown $10.36 by the Dart
--     quote and billed $21.99 by the server — 2.3×.
--   * it can only find a carrier through an existing `sim_lines` row, so
--     onboarding (where the line does not exist yet) prices EVERY carrier at
--     the `COALESCE(min_topup, 10.0)` / `COALESCE(validity, 30)` fiction.
--
-- So there are two rails and they must quote the same plan from one formula.
-- This migration makes `plan_price_net()` that formula, mirroring
-- `RefillPricing.premiumYearlyTotal` in Dart line for line, and rebuilds both
-- rails on top of it:
--
--   quote_plan_price          = gross_up(plan_price_net, gateway)   [PayPal]
--   pay_plan_fee_from_wallet  = round(plan_price_net, 2)            [wallet]
--
-- The wallet charges the net because the wallet gateway is 0% + $0.00 — the
-- same reason Standard bills wallet-first (C3c).
--
-- THE REFUSALS MOVE TO THE MONEY BOUNDARY. i7 gated `usage_required` and
-- under-qualifying `min_denomination` carriers in three Flutter screens, with a
-- note that a fourth purchase surface would need its own copy. Pricing is the
-- one thing every surface must go through, so the same two refusals now live
-- here, in the same dialect (KS422) and with the same wording the queue uses.
-- A screen that forgets its gate now fails to get a price instead of taking a
-- year's payment for a plan `queue_premium_refill_executions` will refuse.
--
-- SIGNATURES: both public functions are DROP + CREATE, never CREATE OR REPLACE
-- with an extra defaulted parameter — that leaves two overloads and PostgREST
-- answers PGRST203 for every call (the D5b→F2b failure, twice). The new
-- parameters are last and defaulted, so an APK that still sends the old three
-- arguments resolves to the new function unchanged.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. The one formula.
-- -----------------------------------------------------------------------------
-- Returns the price of a plan BEFORE any gateway's cut, UNROUNDED. Rounding is
-- the caller's job and happens exactly once: rounding ~13 refills individually
-- and summing drifts from the total the subscriber is charged, and rounding the
-- net before grossing up can move the gross by a cent away from what the Dart
-- quote showed on the button.
CREATE OR REPLACE FUNCTION public.plan_price_net(
  p_plan            text,
  p_sim_line_id     uuid DEFAULT NULL::uuid,
  p_carrier_rule_id uuid DEFAULT NULL::uuid
)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_base_fee    numeric;
  v_app_fee_pct numeric;
  v_margin_pct  numeric;
  v_margin_flat numeric;
  v_rule        RECORD;
  v_step        integer;
  v_refills     integer;
  v_per_refill  numeric;
BEGIN
  SELECT config_value::numeric INTO v_base_fee
  FROM public.system_configs WHERE config_key = 'BASE_SERVICE_FEE_USD';
  IF v_base_fee IS NULL OR v_base_fee <= 0 THEN v_base_fee := 2.50; END IF;

  IF lower(coalesce(p_plan, '')) = 'standard' THEN
    RETURN v_base_fee;
  END IF;

  IF lower(coalesce(p_plan, '')) <> 'premium' THEN
    RAISE EXCEPTION 'Invalid plan: %', p_plan USING ERRCODE = '22023';
  END IF;

  -- Resolution order is deliberately the same as the queue's, so the row that
  -- sets the price is the row that lays down the executions. A rule id given
  -- by the caller wins because on a NEW line that is the only handle there is:
  -- the line does not exist yet, and the client has already used this same id
  -- to decide what to show and will store it on the row it is about to insert.
  SELECT cr.minimum_topup_amount, cr.inactivity_limit_days,
         cr.refill_interval_days_override, cr.inapp_pricing,
         cr.activity_requirement, cr.validity_qualifying_topup_amount
  INTO v_rule
  FROM public.carrier_rules cr
  WHERE cr.id = COALESCE(
          p_carrier_rule_id,
          (SELECT sl.carrier_rule_id FROM public.sim_lines sl WHERE sl.id = p_sim_line_id),
          (SELECT cr2.id
             FROM public.carrier_rules cr2
             JOIN public.sim_lines sl2 ON sl2.carrier_id = cr2.carrier_id
            WHERE sl2.id = p_sim_line_id
            ORDER BY cr2.created_at DESC
            LIMIT 1));

  -- No silent default. The old `COALESCE(min_topup, 10.0)` produced a
  -- plausible-looking price for a carrier nobody had configured, and a
  -- plausible wrong price is charged without anyone noticing.
  IF NOT FOUND OR v_rule.minimum_topup_amount IS NULL OR v_rule.minimum_topup_amount <= 0 THEN
    RAISE EXCEPTION 'No carrier rule with a top-up price exists for this plan'
      USING ERRCODE = '22023';
  END IF;

  -- i7's two refusals, at the money boundary this time. Same SQLSTATE and same
  -- sentences as queue_premium_refill_executions: a plan the queue will not
  -- honour must not have a price.
  IF v_rule.activity_requirement = 'usage_required' THEN
    RAISE EXCEPTION
      'This carrier only resets its inactivity clock on an outgoing call, SMS or data session, so automated refills cannot keep the line active.'
      USING ERRCODE = 'KS422';
  END IF;

  IF v_rule.activity_requirement = 'min_denomination'
     AND v_rule.validity_qualifying_topup_amount IS NOT NULL
     AND v_rule.minimum_topup_amount < v_rule.validity_qualifying_topup_amount THEN
    RAISE EXCEPTION
      'Carrier rule refills % but this carrier only grants line validity from %',
      v_rule.minimum_topup_amount, v_rule.validity_qualifying_topup_amount
      USING ERRCODE = 'KS422';
  END IF;

  v_step := public.refill_interval_days(
              v_rule.inactivity_limit_days, v_rule.refill_interval_days_override);

  IF v_step IS NULL OR v_step < 1 THEN
    RAISE EXCEPTION 'Carrier rule has no usable deactivation window'
      USING ERRCODE = '22023';
  END IF;

  v_refills := ceil(365.0 / v_step);

  SELECT COALESCE(config_value::numeric, 3.0) INTO v_app_fee_pct
  FROM public.system_configs WHERE config_key = 'APP_FEE_PERCENT';
  SELECT COALESCE(config_value::numeric, 5.0) INTO v_margin_pct
  FROM public.system_configs WHERE config_key = 'PREMIUM_MARGIN_PERCENT';
  SELECT COALESCE(config_value::numeric, 0.324) INTO v_margin_flat
  FROM public.system_configs WHERE config_key = 'PREMIUM_MARGIN_PER_REFILL_USD';
  v_app_fee_pct := COALESCE(v_app_fee_pct, 3.0);
  v_margin_pct  := COALESCE(v_margin_pct, 5.0);
  v_margin_flat := COALESCE(v_margin_flat, 0.324);

  -- `inapp_pricing` is an override, not a default: the column is NULL for most
  -- carriers and only a positive value means "this carrier has a hand-set
  -- price". Matches PlanPayment.overrideFor.
  IF v_rule.inapp_pricing IS NOT NULL AND v_rule.inapp_pricing > 0 THEN
    v_per_refill := v_rule.inapp_pricing;
  ELSE
    v_per_refill := v_rule.minimum_topup_amount
                    * (1.0 + ((v_app_fee_pct + v_margin_pct) / 100.0))
                    + v_margin_flat;
  END IF;

  RETURN v_base_fee + (v_per_refill * v_refills);
END;
$function$;

COMMENT ON FUNCTION public.plan_price_net(text, uuid, uuid) IS
  'J8: the single server-side plan price, before any gateway fee and unrounded. '
  'Mirrors RefillPricing.premiumYearlyTotal in Dart; both must change together. '
  'Refuses (KS422) any carrier queue_premium_refill_executions would refuse.';

-- A guard helper, not an API: it would otherwise be a way to enumerate carrier
-- economics (margin percentages back out of two quotes). The two callers below
-- are SECURITY DEFINER and reach it as the owner.
REVOKE ALL ON FUNCTION public.plan_price_net(text, uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.plan_price_net(text, uuid, uuid) TO service_role;

-- -----------------------------------------------------------------------------
-- 2. The PayPal rail.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.quote_plan_price(uuid, text, text);

CREATE OR REPLACE FUNCTION public.quote_plan_price(
  p_sim_line_id     uuid DEFAULT NULL::uuid,
  p_plan            text DEFAULT 'standard'::text,
  p_gateway         text DEFAULT 'paypal'::text,
  p_carrier_rule_id uuid DEFAULT NULL::uuid
)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_gw_pct   numeric;
  v_gw_fixed numeric;
  v_net      numeric;
BEGIN
  IF p_sim_line_id IS NOT NULL AND auth.uid() IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.sim_lines
      WHERE id = p_sim_line_id AND user_id = auth.uid()
    ) THEN
      RAISE EXCEPTION 'FORBIDDEN: SIM line does not belong to caller' USING ERRCODE = '42501';
    END IF;
  END IF;

  -- Doctrine: payment_gateways is the source of truth for what a gateway costs.
  SELECT fee_percentage, fee_fixed
  INTO v_gw_pct, v_gw_fixed
  FROM public.payment_gateways
  WHERE code = p_gateway AND is_active = true;

  IF NOT FOUND OR v_gw_pct IS NULL OR v_gw_fixed IS NULL THEN
    RAISE EXCEPTION 'Gateway % is not active or missing rates in payment_gateways', p_gateway
      USING ERRCODE = '22023';
  END IF;

  v_net := public.plan_price_net(p_plan, p_sim_line_id, p_carrier_rule_id);

  -- Grossed up, not marked up: solving `charged - (charged*pct + fixed) = net`
  -- leaves exactly the net behind after the gateway takes its cut.
  -- A gateway at 100% can never be covered; such a row is a data error, not a
  -- price, so charge the raw net rather than divide by zero.
  IF v_gw_pct >= 100 THEN
    RETURN round(v_net, 2);
  END IF;

  RETURN round((v_net + v_gw_fixed) / (1.0 - (v_gw_pct / 100.0)), 2);
END;
$function$;

COMMENT ON FUNCTION public.quote_plan_price(uuid, text, text, uuid) IS
  'J8: PayPal-rail plan price = plan_price_net grossed up by the gateway. '
  'p_carrier_rule_id prices a line that does not exist yet (onboarding).';

REVOKE ALL ON FUNCTION public.quote_plan_price(uuid, text, text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quote_plan_price(uuid, text, text, uuid) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 3. The wallet rail — now able to buy Premium.
-- -----------------------------------------------------------------------------
-- Everything that was here is carried over verbatim: the suspension check, the
-- line-ownership check, the plan_fee rate limit, idempotency on reference_id,
-- G10's device guard AFTER the idempotency check (so a retry never logs a
-- second attempt), the debit, and the plan_expires_at stamp.
--
-- Two things change beyond the price:
--   * the idempotency check now runs BEFORE the price is computed and reports
--     the amount that was ACTUALLY debited. Recomputing a price to answer
--     "you already paid" is how a replay starts disagreeing with the ledger,
--     and for a Premium carrier that has since been flagged `usage_required`
--     the recompute would raise instead of answering at all.
--   * an `amount` is stamped into the description, because `wallet_transactions`
--     has no metadata column and "Annual Plan Fee Debit" for both a $2.50
--     Standard fee and a $9.52 Premium year is unreadable in support.
DROP FUNCTION IF EXISTS public.pay_plan_fee_from_wallet(text, uuid, text);

CREATE OR REPLACE FUNCTION public.pay_plan_fee_from_wallet(
  p_reference_id    text,
  p_sim_line_id     uuid DEFAULT NULL::uuid,
  p_device_id       text DEFAULT NULL::text,
  p_plan            text DEFAULT 'standard'::text,
  p_carrier_rule_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id     uuid := auth.uid();
  v_plan        text := lower(coalesce(p_plan, 'standard'));
  v_fee         numeric(10,2);
  v_balance     numeric(10,2);
  v_existing    RECORD;
  v_guard       jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = v_user_id AND is_suspended = true) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Account is suspended.');
  END IF;

  IF p_sim_line_id IS NOT NULL AND NOT EXISTS (
       SELECT 1 FROM public.sim_lines WHERE id = p_sim_line_id AND user_id = v_user_id) THEN
    RAISE EXCEPTION 'SIM line % does not belong to user %', p_sim_line_id, v_user_id;
  END IF;

  PERFORM public.enforce_rate_limit('plan_fee', v_user_id::text);

  -- Idempotency first: a replay is answered from the ledger, never re-priced.
  SELECT id, amount INTO v_existing
  FROM public.wallet_transactions
  WHERE reference_id = p_reference_id AND type = 'plan_fee_debit';

  IF FOUND THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_paid', true,
      'transaction_id', v_existing.id,
      'amount', v_existing.amount,
      'plan', v_plan,
      'reference_id', p_reference_id
    );
  END IF;

  -- Priced server-side. A client cannot name its own price, and cannot buy a
  -- Premium year for a carrier the refill queue will refuse to serve — that
  -- raises KS422 here, before any money moves.
  v_fee := round(public.plan_price_net(v_plan, p_sim_line_id, p_carrier_rule_id), 2);

  IF v_fee IS NULL OR v_fee <= 0 THEN
    RAISE EXCEPTION 'Plan % has no usable price', v_plan USING ERRCODE = '22023';
  END IF;

  SELECT COALESCE(balance, 0.00) INTO v_balance
  FROM public.wallets WHERE user_id = v_user_id;

  IF v_balance < v_fee THEN
    RAISE EXCEPTION 'Insufficient wallet balance ($%) for annual plan fee ($%).', v_balance, v_fee;
  END IF;

  -- G10: after the idempotency check, so a retry never logs twice.
  v_guard := public.guard_money_action('plan_fee', v_fee, p_device_id, p_reference_id, v_user_id);
  IF (v_guard ->> 'blocked')::boolean THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'DEVICE_BLOCKED',
      'reason', v_guard ->> 'reason',
      'error', 'This payment was stopped by a security check on this device. Contact support if this is a mistake.'
    );
  END IF;

  PERFORM public.debit_wallet_for_topup(
    v_user_id, p_sim_line_id, v_fee,
    'Annual Plan Fee Debit (' || v_plan || ')',
    p_reference_id, 'plan_fee_debit'
  );

  IF p_sim_line_id IS NOT NULL THEN
    UPDATE public.sim_lines
    SET plan_expires_at = clock_timestamp() + INTERVAL '365 days',
        updated_at = clock_timestamp()
    WHERE id = p_sim_line_id AND user_id = v_user_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'amount', v_fee,
    'plan', v_plan,
    'reference_id', p_reference_id
  );
END;
$function$;

COMMENT ON FUNCTION public.pay_plan_fee_from_wallet(text, uuid, text, text, uuid) IS
  'J8: charges a plan to the wallet at plan_price_net (the wallet gateway takes '
  'no cut). p_plan/p_carrier_rule_id let it buy Premium for a line that does not '
  'exist yet; the resulting plan_fee_debit is what has_paid_premium_entitlement '
  'reads, so the refill queue no longer refuses a line the subscriber paid for.';

REVOKE ALL     ON FUNCTION public.pay_plan_fee_from_wallet(text, uuid, text, text, uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.pay_plan_fee_from_wallet(text, uuid, text, text, uuid) TO authenticated, service_role;

COMMIT;
