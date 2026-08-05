-- i7: what actually keeps a prepaid line alive
--
-- The premium plan pre-pays a year of refills. How many it buys came from
-- `ceil(365 / topup_validity_days)`, and `topup_validity_days` was seeded at a
-- flat 30 (or 28) for almost every carrier in the table. 30 days is a *bundle
-- renewal cycle*. It is not, for any carrier we serve, the window after which a
-- line is deactivated.
--
-- Concretely: STC Saudi Arabia extends SIM validity 180 days from the last paid
-- activity, so a dormant line needs ~3 recharges a year. The app was selling 13
-- of them — $98.29 against a real need of about $25. Every carrier in the table
-- had the same shape of error, in both directions.
--
-- This migration separates the four things that were collapsed into one column:
--
--   inactivity_limit_days  days from the last qualifying activity until the LINE
--                          IS GONE (terminated / number recyclable). The only
--                          field that may drive refill cadence.
--   grace_period_days      window after that in which the same number can still
--                          be recovered. Head-room, never planned against.
--   balance_validity_days  when unused CREDIT is swept. Costs money, does not
--                          cost the number. Informational.
--   topup_validity_days    line validity a top-up of minimum_topup_amount buys.
--                          Redefined here, and demoted: it no longer sets cadence.
--
-- and adds the case the old model could not express at all — carriers where
-- sending a refill is *not sufficient* to hold the line:
--
--   activity_requirement   'recharge_ok'      a top-up alone resets the clock
--                          'min_denomination' only a top-up >= a threshold does
--                                             (Gulf voucher tiers: a BD 3 or
--                                             1 KD voucher is credit with no
--                                             validity attached)
--                          'usage_required'   the clock only resets on a real
--                                             call / SMS / data session, which
--                                             KeepSIMs cannot perform remotely
--
-- A line whose carrier is not 'recharge_ok' can be silently lost while the
-- subscriber is paying us to protect it. Those carriers must say so at the point
-- of sale, which is what activity_requirement + the note exist to drive.

BEGIN;

-- ── 1. Columns ──────────────────────────────────────────────────────────────
ALTER TABLE public.carrier_rules
  ADD COLUMN IF NOT EXISTS activity_requirement text NOT NULL DEFAULT 'recharge_ok',
  ADD COLUMN IF NOT EXISTS validity_qualifying_topup_amount numeric,
  ADD COLUMN IF NOT EXISTS activity_requirement_note text,
  ADD COLUMN IF NOT EXISTS balance_validity_days integer,
  ADD COLUMN IF NOT EXISTS refill_interval_days_override integer,
  ADD COLUMN IF NOT EXISTS rule_source_url text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'carrier_rules_activity_requirement_chk'
  ) THEN
    ALTER TABLE public.carrier_rules
      ADD CONSTRAINT carrier_rules_activity_requirement_chk
      CHECK (activity_requirement IN ('recharge_ok', 'min_denomination', 'usage_required'));
  END IF;

  -- A 'min_denomination' carrier without the denomination is undisplayable: the
  -- UI would have to warn "top up more" without saying how much. Reject it.
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'carrier_rules_min_denomination_chk'
  ) THEN
    ALTER TABLE public.carrier_rules
      ADD CONSTRAINT carrier_rules_min_denomination_chk
      CHECK (
        activity_requirement <> 'min_denomination'
        OR (validity_qualifying_topup_amount IS NOT NULL
            AND validity_qualifying_topup_amount > 0)
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'carrier_rules_refill_override_chk'
  ) THEN
    ALTER TABLE public.carrier_rules
      ADD CONSTRAINT carrier_rules_refill_override_chk
      CHECK (refill_interval_days_override IS NULL
             OR refill_interval_days_override BETWEEN 1 AND 365);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'carrier_rules_balance_validity_chk'
  ) THEN
    ALTER TABLE public.carrier_rules
      ADD CONSTRAINT carrier_rules_balance_validity_chk
      CHECK (balance_validity_days IS NULL OR balance_validity_days >= 1);
  END IF;
END $$;

COMMENT ON COLUMN public.carrier_rules.inactivity_limit_days IS
  'Days from the last qualifying activity until the line is terminated and the '
  'number becomes recyclable. Drives refill cadence — see refill_interval_days().';
COMMENT ON COLUMN public.carrier_rules.topup_validity_days IS
  'Line validity that a top-up of minimum_topup_amount buys. Informational since '
  'i7: it is a bundle/validity cycle, NOT the deactivation window, and must never '
  'be used to derive how often we refill.';
COMMENT ON COLUMN public.carrier_rules.balance_validity_days IS
  'Days until unused credit is swept. Losing credit is not losing the number, so '
  'this never shortens the refill cadence; it only warns the subscriber.';
COMMENT ON COLUMN public.carrier_rules.activity_requirement IS
  'Whether an automated refill is by itself enough to hold the line: recharge_ok '
  '| min_denomination (needs >= validity_qualifying_topup_amount) | usage_required '
  '(needs a human-made call/SMS/data session that KeepSIMs cannot perform).';
COMMENT ON COLUMN public.carrier_rules.refill_interval_days_override IS
  'Set only when the derived cadence is wrong for a specific carrier. Null means '
  'derive from inactivity_limit_days.';

-- ── 2. The cadence, in one place ────────────────────────────────────────────
-- Dart mirrors this exactly (RefillPricing.refillIntervalDays). If the two ever
-- disagree, the subscriber is quoted a different number of refills than the
-- scheduler queues, and the plan year ends early or overspends.
CREATE OR REPLACE FUNCTION public.refill_interval_days(
  p_inactivity_limit_days integer,
  p_override integer DEFAULT NULL
)
RETURNS integer
LANGUAGE sql
IMMUTABLE
SET search_path TO ''
AS $$
  SELECT CASE
    WHEN p_override IS NOT NULL AND p_override > 0
      THEN LEAST(365, p_override)
    WHEN p_inactivity_limit_days IS NULL OR p_inactivity_limit_days < 1
      THEN NULL
    ELSE GREATEST(1, LEAST(365,
      -- Land one safety margin short of the cliff, so a failed refill still has
      -- room for the retry sweep before the carrier reclaims the number.
      p_inactivity_limit_days
        - GREATEST(7, ceil(p_inactivity_limit_days * 0.15)::integer)))
  END;
$$;

COMMENT ON FUNCTION public.refill_interval_days(integer, integer) IS
  'Days between automated refills: the carrier deactivation window less a 15%% '
  '(min 7-day) safety margin. Mirrored by RefillPricing.refillIntervalDays.';

CREATE OR REPLACE FUNCTION public.refills_per_year(
  p_inactivity_limit_days integer,
  p_override integer DEFAULT NULL
)
RETURNS integer
LANGUAGE sql
IMMUTABLE
SET search_path TO ''
AS $$
  SELECT CASE
    WHEN public.refill_interval_days(p_inactivity_limit_days, p_override) IS NULL
      THEN 0
    ELSE ceil(
      365.0 / public.refill_interval_days(p_inactivity_limit_days, p_override)
    )::integer
  END;
$$;

-- ── 3. Let the admin app read and write the new fields ──────────────────────
CREATE OR REPLACE FUNCTION public.admin_upsert_carrier_rule(
  p_carrier_id uuid,
  p_patch      jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_allowed text[] := ARRAY['minimum_topup_amount','recommended_topup_amount','topup_validity_days',
                            'inactivity_limit_days','grace_period_days','notes','inapp_pricing',
                            'offer_id','offer_value',
                            -- i7
                            'activity_requirement','validity_qualifying_topup_amount',
                            'activity_requirement_note','balance_validity_days',
                            'refill_interval_days_override','rule_source_url'];
  v_bad     text;
  v_before  jsonb;
  v_after   jsonb;
  v_min     numeric;
  v_rec     numeric;
  v_val     integer;
BEGIN
  PERFORM public.assert_admin();

  IF p_patch IS NULL OR jsonb_typeof(p_patch) <> 'object' OR p_patch = '{}'::jsonb THEN
    RAISE EXCEPTION 'Nothing to change' USING ERRCODE = 'KS467';
  END IF;

  SELECT string_agg(k, ', ') INTO v_bad
  FROM jsonb_object_keys(p_patch) k WHERE k <> ALL (v_allowed);
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'Unknown field(s): %', v_bad USING ERRCODE = 'KS467';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.carriers WHERE id = p_carrier_id) THEN
    RAISE EXCEPTION 'Carrier % not found', p_carrier_id USING ERRCODE = 'KS461';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.carrier_rules WHERE carrier_id = p_carrier_id) THEN
    INSERT INTO public.carrier_rules
      (carrier_id, rule_type, inactivity_limit_days, minimum_topup_amount, topup_validity_days)
    VALUES
      (p_carrier_id, 'prepaid', 90, 1.00, 90);
  END IF;

  SELECT to_jsonb(cr) INTO v_before FROM public.carrier_rules cr WHERE cr.carrier_id = p_carrier_id;

  UPDATE public.carrier_rules SET
    minimum_topup_amount     = COALESCE(CASE WHEN p_patch ? 'minimum_topup_amount'
                                    THEN (p_patch ->> 'minimum_topup_amount')::numeric
                                    ELSE minimum_topup_amount END, minimum_topup_amount),
    recommended_topup_amount = CASE WHEN p_patch ? 'recommended_topup_amount'
                                    THEN (p_patch ->> 'recommended_topup_amount')::numeric
                                    ELSE recommended_topup_amount END,
    topup_validity_days      = COALESCE(CASE WHEN p_patch ? 'topup_validity_days'
                                    THEN (p_patch ->> 'topup_validity_days')::integer
                                    ELSE topup_validity_days END, topup_validity_days),
    inactivity_limit_days    = COALESCE(CASE WHEN p_patch ? 'inactivity_limit_days'
                                    THEN (p_patch ->> 'inactivity_limit_days')::integer
                                    ELSE inactivity_limit_days END, inactivity_limit_days),
    grace_period_days        = CASE WHEN p_patch ? 'grace_period_days'
                                    THEN (p_patch ->> 'grace_period_days')::integer
                                    ELSE grace_period_days END,
    inapp_pricing            = CASE WHEN p_patch ? 'inapp_pricing'
                                    THEN (p_patch ->> 'inapp_pricing')::numeric
                                    ELSE inapp_pricing END,
    offer_id                 = CASE WHEN p_patch ? 'offer_id'
                                    THEN (p_patch ->> 'offer_id')
                                    ELSE offer_id END,
    offer_value              = CASE WHEN p_patch ? 'offer_value'
                                    THEN (p_patch ->> 'offer_value')::bigint
                                    ELSE offer_value END,
    activity_requirement     = COALESCE(CASE WHEN p_patch ? 'activity_requirement'
                                    THEN (p_patch ->> 'activity_requirement')
                                    ELSE activity_requirement END, activity_requirement),
    validity_qualifying_topup_amount = CASE WHEN p_patch ? 'validity_qualifying_topup_amount'
                                    THEN (p_patch ->> 'validity_qualifying_topup_amount')::numeric
                                    ELSE validity_qualifying_topup_amount END,
    activity_requirement_note = CASE WHEN p_patch ? 'activity_requirement_note'
                                    THEN (p_patch ->> 'activity_requirement_note')
                                    ELSE activity_requirement_note END,
    balance_validity_days    = CASE WHEN p_patch ? 'balance_validity_days'
                                    THEN (p_patch ->> 'balance_validity_days')::integer
                                    ELSE balance_validity_days END,
    refill_interval_days_override = CASE WHEN p_patch ? 'refill_interval_days_override'
                                    THEN (p_patch ->> 'refill_interval_days_override')::integer
                                    ELSE refill_interval_days_override END,
    rule_source_url          = CASE WHEN p_patch ? 'rule_source_url'
                                    THEN (p_patch ->> 'rule_source_url')
                                    ELSE rule_source_url END,
    last_verified_at         = now(),
    updated_at               = now()
  WHERE carrier_id = p_carrier_id;

  SELECT to_jsonb(cr) INTO v_after FROM public.carrier_rules cr WHERE cr.carrier_id = p_carrier_id;

  v_min := (v_after ->> 'minimum_topup_amount')::numeric;
  v_rec := (v_after ->> 'recommended_topup_amount')::numeric;
  v_val := (v_after ->> 'topup_validity_days')::integer;

  IF v_min IS NULL OR v_min <= 0 THEN
    RAISE EXCEPTION 'minimum_topup_amount must be positive' USING ERRCODE = 'KS467';
  END IF;
  IF v_rec IS NOT NULL AND v_rec < v_min THEN
    RAISE EXCEPTION 'recommended_topup_amount cannot be below minimum_topup_amount'
      USING ERRCODE = 'KS467';
  END IF;
  IF v_val IS NULL OR v_val < 1 THEN
    RAISE EXCEPTION 'topup_validity_days must be at least 1' USING ERRCODE = 'KS467';
  END IF;
  IF (v_after ->> 'inactivity_limit_days')::integer < 1 THEN
    RAISE EXCEPTION 'inactivity_limit_days must be at least 1' USING ERRCODE = 'KS467';
  END IF;

  RETURN jsonb_build_object('before', v_before, 'after', v_after);
END $$;

COMMIT;
