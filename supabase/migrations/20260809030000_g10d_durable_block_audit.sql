-- ============================================================================
-- G10d — Making a *raised* refusal legible.
--
-- ── The problem this exists for ────────────────────────────────────────────
--
-- Three of the four guarded RPCs refuse by RETURNING `{success:false}`, so
-- their transaction commits and the `device_money_events` row and the
-- `security_logs` row survive. `request_instant_refill` refuses by RAISING
-- (SQLSTATE KS451), because it returns a bare `uuid` and has always raised —
-- and **a raise aborts the transaction, which takes the audit rows with it.**
--
-- Proven, not assumed: the g10c enforcement proof blocked all four paths and
-- landed **3** `device_money_events` rows and **3** `security_logs` rows, not
-- four. The missing one is the refill.
--
-- There is no autonomous-transaction escape in this database. `dblink` and
-- `pg_background` are not installed; `pg_net` is, but its outbound queue is an
-- ordinary table and rolls back with everything else; `cron.schedule` writes
-- `cron.job`, likewise. Nothing written inside an aborting transaction can be
-- made to survive it.
--
-- ── What this does instead ─────────────────────────────────────────────────
--
-- `report_device_block()` re-runs the assessment in a *fresh* transaction. The
-- Flutter repository calls it from the `catch` that already handles KS451, so
-- the block a real user hit is recorded a few milliseconds later, in a
-- transaction that commits.
--
-- ── What it does and does not guarantee, precisely ─────────────────────────
--
--   ✔ Enforcement never depended on the client and still does not: the refusal
--     happens server-side in `request_instant_refill` whether or not this is
--     ever called.
--   ✔ The reason and score cannot be forged. This takes no reason argument —
--     it recomputes the decision from `guard_money_action`, server-side, from
--     the same tables.
--   ✔ A legitimate user who hits a false positive leaves a record, which is
--     the case § 4 of the brief actually cares about ("a support person can
--     answer 'why was I blocked?' from the database alone").
--   ✘ An attacker running a script can simply not call it, and then their
--     blocked refill leaves no row. They are still blocked. What is lost is
--     one line of telemetry about someone who was already refused — and their
--     approach to the threshold was logged the whole way up, because
--     `device_risk_flag` and `device_risk_challenge` fire on paths that commit.
--   ✘ It is not a second enforcement point and must never become one.
--
-- Events written this way carry `reference_id = 'device_block_replay'` so no
-- velocity analysis mistakes a replay for a fresh attempt.
--
-- The honest alternative was to change `request_instant_refill` to return
-- jsonb like its three siblings. That is a breaking change to a shipped money
-- RPC — every installed APK does `return executionId as String` — and it would
-- have to be sequenced behind a forced app update. Worth doing one day; not
-- worth doing inside a feature whose whole regression story is "the ordinary
-- path is byte-for-byte unchanged".
-- ============================================================================

CREATE OR REPLACE FUNCTION public.report_device_block(
  p_action     text,
  p_amount_usd numeric DEFAULT NULL,
  p_device_id  text    DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_res  jsonb;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('recorded', false, 'error', 'UNAUTHORIZED');
  END IF;

  -- Only the five real actions, so this cannot be used to write arbitrary
  -- labels into the audit trail.
  IF p_action IS NULL OR p_action NOT IN
       ('deposit_order', 'instant_refill', 'esim_purchase', 'gift_send', 'plan_fee') THEN
    RETURN jsonb_build_object('recorded', false, 'error', 'BAD_ACTION');
  END IF;

  -- Cheap and bounded: one bucket, shared with the refill limiter's spirit but
  -- its own key space, so a loop here cannot become a way to fill the table.
  -- consume_rate_limit, not enforce_rate_limit — this must never raise.
  IF NOT COALESCE((SELECT allowed FROM public.consume_rate_limit(
                     'device_block_report', v_user::text, 20, 0.34, clock_timestamp())), true) THEN
    RETURN jsonb_build_object('recorded', false, 'error', 'RATE_LIMITED');
  END IF;

  v_res := public.guard_money_action(p_action, p_amount_usd, p_device_id,
                                     'device_block_replay', v_user);

  RETURN jsonb_build_object(
    'recorded', true,
    'decision', v_res ->> 'decision',
    'reason',   v_res ->> 'reason',
    'score',    v_res ->> 'score');
END;
$function$;

REVOKE ALL     ON FUNCTION public.report_device_block(text, numeric, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.report_device_block(text, numeric, text) TO authenticated, service_role;

COMMENT ON FUNCTION public.report_device_block(text, numeric, text) IS
  'G10d: re-runs the device risk assessment in a fresh transaction so a refusal '
  'that was raised (and therefore rolled its own audit row back) still leaves a '
  'record. Records only — never an enforcement point. Recomputes the reason '
  'server-side; takes no reason argument.';

INSERT INTO public.system_configs (config_key, config_value)
VALUES ('RATE_LIMIT_DEVICE_BLOCK_REPORT', '20/60')
ON CONFLICT (config_key) DO NOTHING;
