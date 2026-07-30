-- ============================================================================
-- G7 — Auto-rescue top-up ("SIM insurance")
--
-- Feature suggestion #7 in doc/PRODUCTION_PLAN_REVIEW.md § 6. `rescue_topup_
-- triggered` has been in the C6 activity-log canon since 2026-07-22 and
-- nothing has ever emitted it. This emits it.
--
-- The promise the product is named after — "SIM Shield" — is that a line the
-- user cares about does not die while they are not looking. Today that is
-- entirely manual: the user must open the app, notice, and pay. G7 makes it
-- automatic for lines the user has explicitly insured.
--
-- ── Seven decisions worth not re-deriving ──────────────────────────────────
--
-- 1. THE CAP IS THE PERMISSION, again. `max_usd NOT NULL DEFAULT 0`, and
--    **0 means not insured**. No `is_enabled` boolean beside it to drift out of
--    sync — the same idiom as G6's household cap, for the same reason. A line
--    is insured when, and only when, its owner has typed a number.
--
-- 2. THIS WARNS FIRST, AND THE WARNING IS ITS OWN. The review says "if a line
--    is n days from expiry AND the user is unreachable". Keying off "we tried
--    to warn them and it did not land" cannot work here: `line_critical` has
--    fired **zero** times in this database's history and `line_entering_grace`
--    exactly once (2026-07-09, with no `sim_line_id`), and F1 is still open —
--    18 of the last 31 push dispatches reached nobody. Depending on that
--    pipeline would make this feature permanently inert, or fire it for
--    everybody. So the rescue runs its own two-phase clock: it writes the
--    warning itself at `lead_days + warn_lead_days`, then rescues at
--    `lead_days` if `RESCUE_GRACE_HOURS` have passed and the user still has not
--    acted. The user is always warned before money moves, whether or not push
--    works — the in-app row is written regardless, which is the part F1 cannot
--    break.
--
-- 3. IT SPENDS THROUGH THE EXISTING PIPELINE, NOT AROUND IT. The rescue inserts
--    a `topup_executions` row with `execution_type = 'refill_instant'`; the
--    BEFORE INSERT `route_topup_execution()` trigger flips it to `routing`, and
--    `worker_instant_refill.js` claims it via `claim_instant_executions()`. No
--    worker change — the same wall G1, G2 and G6 hit. It therefore inherits the
--    offer-tampering check, the wallet debit, the refund-on-failure reaper and
--    the `topup_success` notification for free.
--
-- 4. THE CAP IS CHECKED ON THE POST-TRIGGER AMOUNT. `tr_calculate_topup_fees`
--    adds the app fee in a BEFORE INSERT trigger and the worker debits
--    `amount`, not `base_cost_usd` — a $2.50 offer is charged $2.58. This is
--    the trap G6 hit two days' work ago; here the row is inserted, `RETURNING
--    amount` is compared against the cap, and a violation raises inside a
--    per-line subtransaction that unwinds the insert **and** the activity-log
--    row its AFTER INSERT trigger already wrote.
--
-- 5. ONE LINE'S FAILURE MUST NOT STOP THE RUN, BUT MUST NOT VANISH EITHER.
--    Each line is attempted inside its own `BEGIN … EXCEPTION` block. The
--    `WHEN OTHERS` there is deliberate isolation, not the fail-open catch-all
--    F0 warned about: the SQLSTATE and message are returned in the result row
--    for that line, so a swallowed error is still a visible one. Compare
--    `enforce_rate_limit`, whose `WHEN OTHERS THEN RAISE NOTICE` genuinely does
--    hide things.
--
-- 6. EVERY RUN RETURNS ITS REASONING. `run_auto_rescue()` returns one row per
--    line it considered, with the action and the reason it took it — including
--    every refusal. An automation that spends money silently is not
--    debuggable, and this project has been burned by exactly that shape before.
--    `p_dry_run => true` does the whole decision and spends nothing.
--
-- 7. THERE IS A GLOBAL BRAKE. `system_configs.RESCUE_ENABLED` defaults to
--    `true` because the per-line opt-in is the real gate and defaults to off —
--    but one UPDATE stops every rescue in the product, which is what you want
--    at 3am when a supplier starts returning garbage.
--
-- ⚠️ THIS IS THE FIRST THING IN THE PRODUCT THAT SPENDS A USER'S MONEY WITH NO
-- HUMAN IN THE LOOP. The guard list in `run_auto_rescue()` is not defensive
-- programming, it is the feature. Read it before changing anything here.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- 1. The per-line policy.
--
-- A separate table rather than columns on `sim_lines`, deliberately: D5c's
-- column-level UPDATE lockdown on `sim_lines` broke SIM line editing outright
-- (`updateSimLine` sends the whole model; only the granted columns survive),
-- and offline sync broke again in D5e for the same reason. Adding money-bearing
-- columns to that table means touching that grant list. This does not.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sim_line_rescue_policy (
  sim_line_id uuid PRIMARY KEY REFERENCES public.sim_lines(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL     REFERENCES public.profiles(id)  ON DELETE CASCADE,

  -- 0.00 = this line is NOT insured. The cap is the permission.
  max_usd numeric(10,2) NOT NULL DEFAULT 0.00
    CHECK (max_usd >= 0 AND max_usd <= 500),

  -- Rescue when the forecast says this many days of life are left.
  lead_days integer NOT NULL DEFAULT 2
    CHECK (lead_days >= 1 AND lead_days <= 14),

  -- Warn this many days before that, so the user gets a chance to act first.
  warn_lead_days integer NOT NULL DEFAULT 3
    CHECK (warn_lead_days >= 1 AND warn_lead_days <= 30),

  last_warned_at           timestamptz,
  last_rescue_at           timestamptz,
  last_rescue_execution_id uuid REFERENCES public.topup_executions(id) ON DELETE SET NULL,
  rescue_count             integer NOT NULL DEFAULT 0,

  created_at timestamptz NOT NULL DEFAULT NOW(),
  updated_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS sim_line_rescue_policy_armed_idx
  ON public.sim_line_rescue_policy (user_id) WHERE max_usd > 0;

COMMENT ON TABLE public.sim_line_rescue_policy IS
  'G7: per-line "SIM insurance". max_usd = 0 means NOT insured, which is the default and the fail-closed state. Held apart from sim_lines on purpose — that table''s column-level UPDATE grant has broken client writes twice (D5c, D5e).';
COMMENT ON COLUMN public.sim_line_rescue_policy.max_usd IS
  'G7: the most run_auto_rescue() may spend on one rescue of this line, checked against the POST-FEE charged amount. 0.00 = the line is not insured.';

DROP TRIGGER IF EXISTS trg_sim_line_rescue_policy_updated_at ON public.sim_line_rescue_policy;
CREATE TRIGGER trg_sim_line_rescue_policy_updated_at
  BEFORE UPDATE ON public.sim_line_rescue_policy
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

ALTER TABLE public.sim_line_rescue_policy ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.sim_line_rescue_policy FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.sim_line_rescue_policy TO authenticated;
GRANT ALL    ON TABLE public.sim_line_rescue_policy TO service_role;

DROP POLICY IF EXISTS "Users can read their own rescue policy" ON public.sim_line_rescue_policy;
CREATE POLICY "Users can read their own rescue policy"
  ON public.sim_line_rescue_policy FOR SELECT TO authenticated
  USING (user_id = auth.uid());
-- No client INSERT/UPDATE policy: writes go through set_line_rescue_policy(),
-- which validates the numbers and cannot be talked into insuring a line the
-- caller does not own.


-- ---------------------------------------------------------------------------
-- 2. Knobs.
-- ---------------------------------------------------------------------------
INSERT INTO public.system_configs (config_key, config_value) VALUES
  ('RESCUE_ENABLED',       'true'),   -- global brake; per-line opt-in is the real gate
  ('RESCUE_GRACE_HOURS',   '24'),     -- how long the user gets after the warning
  ('RESCUE_COOLDOWN_DAYS', '20'),     -- never rescue the same line twice inside this
  ('RESCUE_MAX_PER_RUN',   '25')      -- blast radius of a single run
ON CONFLICT (config_key) DO NOTHING;


-- ---------------------------------------------------------------------------
-- 3. The owner-facing switch.
--
-- SECURITY DEFINER because it must confirm the caller owns the line and then
-- write a row they have no INSERT policy for. Guarded on `auth.uid()`, never on
-- `current_user` — inside SECURITY DEFINER that is the function owner, which is
-- how this project shipped dead guards four times (D5c, D5d, F4b, F1).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_line_rescue_policy(
  p_sim_line_id    uuid,
  p_max_usd        numeric,
  p_lead_days      integer DEFAULT 2,
  p_warn_lead_days integer DEFAULT 3
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_actor uuid := auth.uid();
  v_owner uuid;
BEGIN
  IF v_actor IS NULL THEN
    RETURN jsonb_build_object('success', false, 'code', 'UNAUTHORIZED');
  END IF;

  IF p_max_usd IS NULL OR p_max_usd < 0 OR p_max_usd > 500 THEN
    RETURN jsonb_build_object('success', false, 'code', 'INVALID_CAP',
      'error', 'The rescue limit must be between $0.00 and $500.00. Use 0 to switch SIM insurance off.');
  END IF;

  IF p_lead_days IS NULL OR p_lead_days < 1 OR p_lead_days > 14
     OR p_warn_lead_days IS NULL OR p_warn_lead_days < 1 OR p_warn_lead_days > 30 THEN
    RETURN jsonb_build_object('success', false, 'code', 'INVALID_WINDOW',
      'error', 'Rescue must trigger 1–14 days out, with a warning 1–30 days before that.');
  END IF;

  -- Ownership only. A household manager can spend the owner's wallet under G6,
  -- but arming an unattended automation on someone else's line is a different
  -- and much larger promise, and it is not one this makes.
  SELECT sl.user_id INTO v_owner
  FROM public.sim_lines sl WHERE sl.id = p_sim_line_id;

  IF v_owner IS NULL OR v_owner <> v_actor THEN
    RETURN jsonb_build_object('success', false, 'code', 'NOT_FOUND',
      'error', 'That SIM line does not exist, or is not yours.');
  END IF;

  INSERT INTO public.sim_line_rescue_policy AS p
    (sim_line_id, user_id, max_usd, lead_days, warn_lead_days)
  VALUES
    (p_sim_line_id, v_actor, round(p_max_usd, 2), p_lead_days, p_warn_lead_days)
  ON CONFLICT (sim_line_id) DO UPDATE
    SET max_usd        = EXCLUDED.max_usd,
        lead_days      = EXCLUDED.lead_days,
        warn_lead_days = EXCLUDED.warn_lead_days,
        -- Re-arming clears the clock, so raising a cap cannot instantly rescue
        -- on the strength of a warning the user already responded to.
        last_warned_at = CASE WHEN EXCLUDED.max_usd <> p.max_usd
                              THEN NULL ELSE p.last_warned_at END;

  RETURN jsonb_build_object(
    'success', true,
    'sim_line_id', p_sim_line_id,
    'max_usd', round(p_max_usd, 2),
    'insured', p_max_usd > 0,
    'lead_days', p_lead_days,
    'warn_lead_days', p_warn_lead_days
  );
END $fn$;

COMMENT ON FUNCTION public.set_line_rescue_policy(uuid, numeric, integer, integer) IS
  'G7: arm or disarm SIM insurance on one of the caller''s own lines. 0 switches it off. Changing the cap clears last_warned_at so the warn-then-rescue clock restarts.';

REVOKE ALL     ON FUNCTION public.set_line_rescue_policy(uuid, numeric, integer, integer) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.set_line_rescue_policy(uuid, numeric, integer, integer) TO authenticated, service_role;
