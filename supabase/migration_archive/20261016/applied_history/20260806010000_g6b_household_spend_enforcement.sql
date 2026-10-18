-- ============================================================================
-- G6b — Household spend limits: the enforcement wiring.
--
-- G6 (20260806000000) added the cap, the derived month-to-date accounting and
-- the read surfaces. This file is the half that touches money: it redirects the
-- payer at request time and enforces the cap again at debit time.
--
-- Split out deliberately. Everything here is a `CREATE OR REPLACE` over a live
-- money path, and it should be reviewable — and revertible — without dragging
-- the schema along with it.
--
-- Both functions are restated in full rather than patched, because that is the
-- only way to be sure what the deployed body is. The diff against the live
-- definitions captured on 2026-07-30 is exactly the lines marked `G6`.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 9. Enforcement point 1 of 2 — request time.
--
-- Verbatim re-statement of the live `request_instant_refill` with the additions
-- marked G6 below. Everything else — the suspension check, the rate limit, the
-- 24-hour staleness guard, the FIXED/RANGE pricing arithmetic — is unchanged.
-- ---------------------------------------------------------------------------
-- NOTE the parameter defaults below. They are not decoration: PostgREST
-- resolves an RPC by the set of parameter NAMES supplied, and dropping a
-- default is a hard `42P13` on CREATE OR REPLACE. `p_amount_usd` defaults to
-- NULL because FIXED-price offers are called without an amount.
CREATE OR REPLACE FUNCTION public.request_instant_refill(
  p_sim_line_id          uuid,
  p_offer_id             text,
  p_payment_gateway_code text,
  p_amount_usd           numeric DEFAULT NULL::numeric
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_iso          text;
  v_zen_carrier  text;
  v_offer        RECORD;
  v_base         numeric;
  v_value        numeric;
  v_execution_id uuid;
  v_line_owner   uuid;    -- G6
  v_payer        uuid;    -- G6
  v_acting       uuid;    -- G6
  v_charged      numeric; -- G6
  v_chk          RECORD;  -- G6
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_suspended = true) THEN
    RAISE EXCEPTION 'Account is suspended. Refills are disabled.';
  END IF;

  PERFORM public.enforce_rate_limit('instant_refill', auth.uid()::text);

  -- G6: sl.user_id is now selected too, because the payer is derived from who
  -- owns the line rather than from who is calling.
  SELECT co.iso_code, ca.zen_carrier, sl.user_id
  INTO v_iso, v_zen_carrier, v_line_owner
  FROM public.sim_lines sl
  JOIN public.countries co ON co.id = sl.country_id
  JOIN public.carriers ca ON ca.id = sl.carrier_id
  WHERE sl.id = p_sim_line_id
    AND (sl.user_id = auth.uid()
         OR EXISTS (SELECT 1 FROM public.household_members hm
                    WHERE hm.owner_id = sl.user_id
                      AND hm.member_id = auth.uid()
                      AND hm.invite_status = 'accepted'
                      AND hm.role = 'manager'));

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Not authorized to refill this SIM line';
  END IF;

  IF v_zen_carrier IS NULL THEN
    RAISE EXCEPTION 'This carrier has no online top-up catalog';
  END IF;

  SELECT * INTO v_offer
  FROM public.zendit_offers_cache z
  WHERE z.offer_id = p_offer_id
    AND z.country_code = v_iso
    AND z.zen_carrier = v_zen_carrier;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Offer % is not available for this SIM line', p_offer_id;
  END IF;

  IF v_offer.refreshed_at < now() - interval '24 hours' THEN
    RAISE EXCEPTION 'Offer pricing is temporarily unavailable. Please try again later.';
  END IF;

  IF v_offer.price_type = 'FIXED' THEN
    v_base := v_offer.price_fixed_usd;
    v_value := NULL;
  ELSE
    IF p_amount_usd IS NULL THEN
      RAISE EXCEPTION 'This offer requires an amount';
    END IF;
    v_base := round(p_amount_usd, 2);
    IF v_base < v_offer.price_min_usd - 0.01 OR v_base > v_offer.price_max_usd + 0.01 THEN
      RAISE EXCEPTION 'Amount % is outside this offer''s %-% USD range',
        v_base, v_offer.price_min_usd, v_offer.price_max_usd;
    END IF;
    v_value := least(v_offer.send_max, greatest(v_offer.send_min, round(
      v_offer.send_min
      + CASE WHEN v_offer.price_max_usd - v_offer.price_min_usd > 0
             THEN (v_base - v_offer.price_min_usd)
                  * (v_offer.send_max - v_offer.send_min)
                  / (v_offer.price_max_usd - v_offer.price_min_usd)
             ELSE 0 END)));
  END IF;

  IF v_base IS NULL OR v_base <= 0 THEN
    RAISE EXCEPTION 'Offer % has no usable price', p_offer_id;
  END IF;

  -- ── G6: who pays? ────────────────────────────────────────────────────────
  -- The price has to be settled first, because the cap is checked against it.
  -- A manager the owner has never funded resolves to themselves and keeps
  -- paying their own wallet — exactly the pre-G6 behaviour, and the reason
  -- `acting_user_id` stays NULL for them.
  v_payer  := public.resolve_household_payer(auth.uid(), v_line_owner);
  v_acting := CASE WHEN v_payer <> auth.uid() THEN auth.uid() END;

  INSERT INTO public.topup_executions (
    sim_line_id, user_id, acting_user_id, amount, base_cost_usd, payment_gateway_code,
    currency, status, execution_type, execution_time, offer_id, offer_value
  ) VALUES (
    p_sim_line_id, v_payer, v_acting, v_base, v_base, p_payment_gateway_code,
    'USD', 'pending', 'refill_instant', now(), p_offer_id, v_value
  )
  RETURNING id, amount INTO v_execution_id, v_charged;

  -- ── G6: the cap is checked AFTER the insert, on purpose ──────────────────
  -- `tr_calculate_topup_fees` is a BEFORE INSERT trigger that adds the app fee
  -- to `amount`, and `amount` — not `base_cost_usd` — is what
  -- worker_instant_refill.js debits. A $2.50 offer is charged $2.58. Checking
  -- the offer price would let every single refill overrun the cap by its fee,
  -- so the check has to see the post-trigger number, which means the row must
  -- exist first. Raising here unwinds the INSERT with it: same statement, same
  -- transaction, nothing left behind. The row is excluded from its own
  -- in-flight total or it would be counted twice.
  IF v_acting IS NOT NULL THEN
    SELECT * INTO v_chk
    FROM public.household_spend_check(v_payer, v_acting, v_charged, v_execution_id);

    IF NOT v_chk.allowed THEN
      RAISE EXCEPTION 'HOUSEHOLD_CAP:%:%:%:%',
        v_chk.reason, v_chk.monthly_cap, v_chk.spent_mtd, v_chk.remaining_usd
        USING ERRCODE = 'KS402';
    END IF;
  END IF;

  RETURN v_execution_id;
END;
$fn$;

REVOKE ALL     ON FUNCTION public.request_instant_refill(uuid, text, text, numeric) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.request_instant_refill(uuid, text, text, numeric) TO authenticated;


-- ---------------------------------------------------------------------------
-- 10. Enforcement point 2 of 2 — the moment money moves.
--
-- WARNING. This is the most sensitive function in the product. F-2 shut a live
-- drain here, and the guard below is F-2's, reproduced exactly: a call-DEPTH
-- test, not a JWT-role test, because `request_esim_purchase` and
-- `pay_plan_fee_from_wallet` call this nested and a role-only guard breaks
-- both. Do not "simplify" it.
--
-- The G6 addition is inert for every caller that exists today. It fires only
-- when the reference names a `topup_executions` row whose `acting_user_id` is
-- set and differs from the payer — which nothing but G6's own request path
-- produces.
-- ---------------------------------------------------------------------------
-- The three defaults are load-bearing: `worker_instant_refill.js` calls this
-- with five named arguments and never passes `p_txn_type`. Dropping any of them
-- is a hard `42P13`, which is how this was caught rather than shipped.
CREATE OR REPLACE FUNCTION public.debit_wallet_for_topup(
  p_user_id      uuid,
  p_sim_line_id  uuid,
  p_amount       numeric,
  p_description  text DEFAULT 'SIM top-up'::text,
  p_reference_id text DEFAULT NULL::text,
  p_txn_type     text DEFAULT 'topup_debit'::text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_raw_claims     TEXT;
  v_jwt_role       TEXT;
  v_ctx            TEXT;
  v_wallet_id      UUID;
  v_balance_before NUMERIC;
  v_balance_after  NUMERIC;
  v_txn_id         UUID;
  v_exec_id        UUID;                   -- G6
  v_acting         UUID;                   -- G6
  v_chk            RECORD;                 -- G6
  v_metadata       JSONB := '{}'::jsonb;   -- G6
BEGIN
  -- ── F-2 guard, unchanged ────────────────────────────────────────────────
  v_raw_claims := current_setting('request.jwt.claims', true);
  IF v_raw_claims IS NOT NULL AND v_raw_claims <> '' THEN
    v_jwt_role := (v_raw_claims::jsonb) ->> 'role';
    IF v_jwt_role IS DISTINCT FROM 'service_role' THEN
      GET DIAGNOSTICS v_ctx = PG_CONTEXT;
      IF coalesce(array_length(string_to_array(v_ctx, E'\n'), 1), 1) < 2 THEN
        RAISE EXCEPTION 'debit_wallet_for_topup is not directly callable by role %', COALESCE(v_jwt_role, '<none>')
          USING ERRCODE = 'KS403';
      END IF;
    END IF;
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Debit amount must be positive, got %', p_amount;
  END IF;

  -- ── G6: is a household member spending the payer's wallet here? ─────────
  -- `exec_<uuid>` is the reference format worker_instant_refill.js builds and
  -- the D5b reaper already relies on. The regex means a malformed or unrelated
  -- reference simply skips this block instead of erroring.
  IF p_reference_id ~ '^exec_[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
    v_exec_id := substring(p_reference_id FROM 6)::uuid;

    SELECT te.acting_user_id INTO v_acting
    FROM public.topup_executions te
    WHERE te.id = v_exec_id;
  END IF;

  IF v_acting IS NOT NULL AND v_acting <> p_user_id THEN
    -- Exclude this execution from its own in-flight total, or it would count
    -- twice and the last refill under a cap would always be refused.
    SELECT * INTO v_chk
    FROM public.household_spend_check(p_user_id, v_acting, p_amount, v_exec_id);

    IF NOT v_chk.allowed THEN
      RAISE EXCEPTION 'HOUSEHOLD_CAP:%:%:%:%',
        v_chk.reason, v_chk.monthly_cap, v_chk.spent_mtd, v_chk.remaining_usd
        USING ERRCODE = 'KS402';
    END IF;

    -- The stamp household_spend_mtd() reads. Without it the spend is invisible
    -- to the cap and every later refill this month would be free.
    v_metadata := jsonb_build_object(
      'spent_by',        v_acting::text,
      'spent_for_owner', p_user_id::text,
      'household',       true
    );
  END IF;

  SELECT id, balance INTO v_wallet_id, v_balance_before
  FROM public.wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RAISE EXCEPTION 'Wallet not found for user %', p_user_id;
  END IF;

  IF v_balance_before < p_amount THEN
    RAISE EXCEPTION 'Insufficient wallet balance. Have: %, Need: %', v_balance_before, p_amount;
  END IF;

  v_balance_after := v_balance_before - p_amount;

  UPDATE public.wallets
  SET balance = v_balance_after,
      total_spent = total_spent + p_amount
  WHERE id = v_wallet_id;

  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, amount, balance_before, balance_after,
    description, reference_id, sim_line_id, status, metadata
  ) VALUES (
    v_wallet_id, p_user_id, COALESCE(p_txn_type, 'topup_debit'), p_amount, v_balance_before, v_balance_after,
    p_description, p_reference_id, p_sim_line_id, 'completed', v_metadata
  ) RETURNING id INTO v_txn_id;

  RETURN v_txn_id;
END;
$fn$;

-- F-2's grant posture, restated so a CREATE OR REPLACE cannot quietly widen it.
REVOKE ALL ON FUNCTION public.debit_wallet_for_topup(uuid, uuid, numeric, text, text, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.debit_wallet_for_topup(uuid, uuid, numeric, text, text, text)
  TO service_role;
