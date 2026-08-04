-- =============================================================================
-- I2b · Premium entitlement guard on the pre-paid refill queue
-- =============================================================================
-- PROVEN LIVE 2026-08-04, as `authenticated` under a real user's JWT:
--
--   INSERT INTO sim_lines (..., plan_type, plan_expires_at)
--   VALUES (..., 'premium', now() + interval '365 days');   -- ACCEPTED
--
-- `trg_prevent_sim_line_plan_tampering` is `BEFORE UPDATE` only, and
-- `authenticated` holds column-level INSERT on both `plan_type` and
-- `plan_expires_at`. So any signed-up user can create a line that *claims* the
-- premium plan without paying for it.
--
-- That label was not merely cosmetic. The chain it unlocked:
--   1. insert a line marked premium (above);
--   2. insert a `scheduled_topups` row with `schedule_type = 'refill_mini'`
--      (the client already does this);
--   3. call `queue_premium_refill_executions` — `EXECUTE` is granted to
--      `authenticated` and it verified **ownership only, never payment**;
--   4. it queues up to 400 `refill_mini` executions with
--      `payment_gateway_code = NULL`, so `calculate_topup_fees()` adds nothing;
--   5. `worker_auto_mini_refill.js` executes them and **contains no wallet
--      debit at all** — grep it: the only mention of a wallet is the comment
--      "Premium users pay upfront; no wallet refund needed".
--
-- Net effect: a free year of airtime, bought from Zendit at KeepSIMs' expense,
-- reachable with nothing but the anon key that ships in the APK and a signup.
--
-- A SECOND HOLE IN THE SAME FUNCTION, independent of the first:
--   `v_expires := COALESCE(p_plan_expires_at, v_line.plan_expires_at, …)`
--   trusted a **caller-supplied** horizon. Even a genuinely paid premium user
--   could pass `p_plan_expires_at => now() + 10 years` and queue the full 400
--   executions instead of the ~12 a year of their plan buys. At a $2.50 carrier
--   minimum that is ~$1,000 of airtime per line. The parameter is now a
--   NARROWING hint only: it can pull the horizon in, never push it out.
--
-- WHY THE FIX IS HERE AND NOT ON THE INSERT
--   The legitimate client flow is **pay first, then insert the line carrying the
--   tier** (`sim_line_form_screen.dart`: `tryStandardFromWallet` / the PayPal
--   checkout both complete before `commitSave()`), and on a *new* line the
--   payment carries no `sim_line_id` because the line does not exist yet. So
--   forcing `plan_type` to 'free' on INSERT would take the money and withhold
--   the plan. Closing the label properly needs a claim protocol — written up as
--   I2c in doc/PRODUCTION_PLAN_REVIEW.md.
--   Guarding the *spend* instead is sufficient, because `topup_executions` is
--   `SELECT`-only for `anon` and `authenticated` (verified against
--   `information_schema.role_table_grants`), so this RPC is the ONLY
--   client-reachable way to queue a pre-paid refill.
--
-- GRANDFATHERING (required, not a convenience): the four premium lines in
--   production were seeded by the owner and have **zero** `plan_fee_debit`
--   transactions — three of them do not even carry a `plan_expires_at`. A
--   strict "must have paid" test would refuse the owner's own lines.
--
--   ⚠️ The obvious grandfather — "created before <date>" — would be a DEAD
--   GUARD, the fifth occurrence of that pattern in this project. `authenticated`
--   holds column-level INSERT on `sim_lines.created_at` (verified against
--   `information_schema.column_privileges`), so an attacker simply backdates the
--   row and walks through. The exemption is therefore an explicit, service_role
--   -only ALLOW-LIST of line ids, seeded from what exists today. Nothing a
--   client can write decides it.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.premium_entitlement_grandfather (
  sim_line_id uuid PRIMARY KEY REFERENCES public.sim_lines(id) ON DELETE CASCADE,
  reason      text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.premium_entitlement_grandfather ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.premium_entitlement_grandfather FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.premium_entitlement_grandfather TO service_role;

COMMENT ON TABLE public.premium_entitlement_grandfather IS
  'I2b: SIM lines allowed to queue pre-paid premium refills without a payment '
  'record. Seeded with the owner-created premium lines that predate the guard. '
  'Adding a row is a deliberate act by service_role; there is no client path.';

-- Seed: exactly the premium lines that exist at migration time.
INSERT INTO public.premium_entitlement_grandfather (sim_line_id, reason)
SELECT sl.id, 'I2b seed: owner-created premium line predating the entitlement guard'
FROM public.sim_lines sl
WHERE lower(coalesce(sl.plan_type, '')) = 'premium'
ON CONFLICT (sim_line_id) DO NOTHING;

-- -----------------------------------------------------------------------------
-- Does this line hold a premium plan somebody actually paid for?
-- -----------------------------------------------------------------------------
-- Payments are recorded against the USER, not the line, because on a new line
-- the purchase completes before the line exists. So the match is
-- (owner, kind, inside the plan's own year) rather than (line).
CREATE OR REPLACE FUNCTION public.has_paid_premium_entitlement(p_sim_line_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_line   RECORD;
  v_window timestamptz;
BEGIN
  SELECT sl.user_id, sl.plan_type, sl.plan_expires_at
  INTO v_line
  FROM public.sim_lines sl
  WHERE sl.id = p_sim_line_id;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF lower(coalesce(v_line.plan_type, '')) <> 'premium' THEN
    RETURN false;
  END IF;

  -- Checked BEFORE the expiry test: three of the four seeded premium lines
  -- carry no `plan_expires_at` at all, and the horizon clamp in the caller
  -- bounds their spend regardless.
  IF EXISTS (SELECT 1 FROM public.premium_entitlement_grandfather g
             WHERE g.sim_line_id = p_sim_line_id) THEN
    RETURN true;
  END IF;

  IF v_line.plan_expires_at IS NULL OR v_line.plan_expires_at <= now() THEN
    RETURN false;
  END IF;

  -- The plan's own year, widened by a day so a purchase that lands a few
  -- seconds before the line is created still counts.
  v_window := v_line.plan_expires_at - interval '366 days';

  IF EXISTS (
    SELECT 1 FROM public.plan_payments pp
    WHERE pp.kind = 'plan'
      AND (pp.sim_line_id = p_sim_line_id
           OR (pp.sim_line_id IS NULL AND pp.user_id = v_line.user_id))
      AND pp.created_at >= v_window
  ) THEN
    RETURN true;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.wallet_transactions wt
    WHERE wt.user_id = v_line.user_id
      AND wt.type = 'plan_fee_debit'
      AND (wt.sim_line_id = p_sim_line_id OR wt.sim_line_id IS NULL)
      AND wt.created_at >= v_window
  ) THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$function$;

-- Not client-callable: it is a guard helper, and exposing it would hand out a
-- probe for other users' payment history.
REVOKE ALL ON FUNCTION public.has_paid_premium_entitlement(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.has_paid_premium_entitlement(uuid) TO service_role;

-- -----------------------------------------------------------------------------
-- The guarded queue
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.queue_premium_refill_executions(
  p_sim_line_id       uuid,
  p_scheduled_topup_id uuid,
  p_plan_expires_at   timestamptz DEFAULT NULL::timestamptz,
  p_start_at          timestamptz DEFAULT now()
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_line RECORD;
  v_rule RECORD;
  v_expires timestamptz;
  v_t timestamptz;
  v_count integer := 0;
  v_role text;
BEGIN
  SELECT sl.user_id, sl.carrier_id, sl.carrier_rule_id, sl.plan_expires_at
  INTO v_line
  FROM public.sim_lines sl
  WHERE sl.id = p_sim_line_id
    AND (auth.uid() IS NULL
         OR sl.user_id = auth.uid()
         OR EXISTS (SELECT 1 FROM public.household_members hm
                    WHERE hm.owner_id = sl.user_id
                      AND hm.member_id = auth.uid()
                      AND hm.invite_status = 'accepted'
                      AND hm.role = 'manager'));

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Not authorized to schedule refills for this SIM line';
  END IF;

  -- I2b GUARD. `current_user` is useless here (SECURITY DEFINER makes it the
  -- owner — D5c/F-6a/F4b, four occurrences), so the discriminator is the JWT
  -- role, read fail-closed: a malformed claims blob yields NULL, which is not
  -- 'service_role', so the guard still runs.
  BEGIN
    v_role := current_setting('request.jwt.claims', true)::json ->> 'role';
  EXCEPTION WHEN OTHERS THEN
    v_role := NULL;
  END;

  IF v_role IS DISTINCT FROM 'service_role' THEN
    IF NOT public.has_paid_premium_entitlement(p_sim_line_id) THEN
      RAISE EXCEPTION
        'This line has no paid, unexpired premium plan, so pre-paid refills cannot be queued.'
        USING ERRCODE = 'KS403';
    END IF;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.scheduled_topups st
    WHERE st.id = p_scheduled_topup_id
      AND st.sim_line_id = p_sim_line_id
      AND st.schedule_type = 'refill_mini'
  ) THEN
    RAISE EXCEPTION 'Schedule does not belong to this SIM line';
  END IF;

  SELECT cr.topup_validity_days, cr.minimum_topup_amount, cr.offer_id, cr.offer_value
  INTO v_rule
  FROM public.carrier_rules cr
  WHERE cr.id = COALESCE(v_line.carrier_rule_id,
                         (SELECT cr2.id FROM public.carrier_rules cr2
                          WHERE cr2.carrier_id = v_line.carrier_id
                          ORDER BY cr2.created_at DESC LIMIT 1));

  IF NOT FOUND OR v_rule.minimum_topup_amount IS NULL OR v_rule.minimum_topup_amount <= 0 THEN
    RAISE EXCEPTION 'No carrier rule with a top-up price exists for this SIM line';
  END IF;

  IF v_rule.topup_validity_days IS NULL OR v_rule.topup_validity_days < 1 THEN
    RAISE EXCEPTION 'Carrier rule has no usable validity period';
  END IF;

  -- I2b: the horizon is the LINE's paid-for expiry. `p_plan_expires_at` may
  -- only pull it in (a shorter queue is always safe), never push it out — it
  -- used to be trusted outright, which was worth ~$1,000 of airtime per line.
  v_expires := COALESCE(v_line.plan_expires_at, p_start_at + interval '365 days');
  IF p_plan_expires_at IS NOT NULL AND p_plan_expires_at < v_expires THEN
    v_expires := p_plan_expires_at;
  END IF;
  -- Belt and braces: never queue past a year from the start, whatever the row
  -- says, so a bad `plan_expires_at` cannot become an unbounded spend.
  IF v_expires > p_start_at + interval '370 days' THEN
    v_expires := p_start_at + interval '370 days';
  END IF;

  UPDATE public.topup_executions
  SET status = 'cancelled', completed_at = now()
  WHERE scheduled_topup_id = p_scheduled_topup_id
    AND status IN ('pending', 'pending_payment');

  v_t := p_start_at;
  WHILE v_t < v_expires AND v_count < 400 LOOP
    INSERT INTO public.topup_executions (
      sim_line_id, user_id, amount, base_cost_usd, currency, status,
      execution_type, execution_time, offer_id, offer_value,
      payment_gateway_code, scheduled_topup_id
    ) VALUES (
      p_sim_line_id, v_line.user_id, v_rule.minimum_topup_amount,
      v_rule.minimum_topup_amount, 'USD', 'pending',
      'refill_mini', v_t, v_rule.offer_id, v_rule.offer_value,
      NULL,
      p_scheduled_topup_id
    );
    v_count := v_count + 1;
    v_t := v_t + (v_rule.topup_validity_days || ' days')::interval;
  END LOOP;

  RETURN v_count;
END;
$function$;
