-- ============================================================================
-- G1 — Depletion forecasting → smarter auto-custom refills
--
-- Feature suggestion #1 in doc/PRODUCTION_PLAN_REVIEW.md § 6. Three outcomes:
--   (a) predict when a line/eSIM actually runs out,
--   (b) *propose* the auto-custom schedule instead of asking the user to
--       invent a frequency and an amount out of thin air,
--   (c) let `line_critical` fire off the prediction, i.e. earlier than the
--       user's own notify cadence, and only when nothing already covers it.
--
-- ── Two deviations from the sketch in the review, both deliberate ───────────
--
-- 1. A TABLE, not a MATERIALIZED VIEW. Postgres does not support RLS on a
--    matview, so `sim_line_usage_forecast` as a matview would either be
--    world-readable through PostgREST or need a SECURITY DEFINER view in front
--    of it — i.e. exactly the shape F0 spent three sessions removing. A plain
--    table takes an ordinary read-own policy and no new function in the
--    perimeter. Refresh cost is identical (one nightly recompute).
--
-- 2. eSIM burn rate is sampled BY THIS JOB, not by the worker. The fulfilment
--    worker already refreshes `user_esims.data_remaining_mb` on every poll, but
--    it keeps no history, so there is nothing to fit a rate to. Rather than
--    change a worker that can only be deployed from the VM (owner-gated, see
--    doc/PROJECT_TOPOLOGY.md § 5), the nightly job records the reading it finds.
--    Zero deploy dependency; the rate simply needs two nights to exist.
--
-- Nothing here is callable by anon or authenticated: every function is
-- cron-driven and service_role-only, so the F0 grant matrix is untouched.
-- The app reads the forecast as a plain RLS-guarded table.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. esim_usage_samples — one reading per eSIM per UTC day.
--    Internal telemetry: deny-all, like offline_refill_events. The user never
--    reads this; they read the fitted rate on the forecast row.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.esim_usage_samples (
  esim_id           uuid        NOT NULL REFERENCES public.user_esims(id) ON DELETE CASCADE,
  sampled_on        date        NOT NULL,
  data_remaining_mb bigint,
  data_total_mb     bigint,
  created_at        timestamptz NOT NULL DEFAULT NOW(),
  PRIMARY KEY (esim_id, sampled_on)
);

ALTER TABLE public.esim_usage_samples ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.esim_usage_samples FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.esim_usage_samples TO service_role;

COMMENT ON TABLE public.esim_usage_samples IS
  'G1: daily snapshot of user_esims.data_remaining_mb, written by refresh_usage_forecasts(). Deny-all by design (RLS on, zero policies).';

-- ---------------------------------------------------------------------------
-- 2. sim_line_usage_forecast — one row per protected subject.
--    A subject is EITHER a sim_line OR an eSIM, never both.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sim_line_usage_forecast (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  sim_line_id            uuid REFERENCES public.sim_lines(id) ON DELETE CASCADE,
  esim_id                uuid REFERENCES public.user_esims(id) ON DELETE CASCADE,
  subject_kind           text NOT NULL CHECK (subject_kind IN ('sim_line','esim')),

  -- how we got here, so the UI can be honest about a guess
  method                 text NOT NULL CHECK (method IN ('topup_history','esim_usage','carrier_rule','default')),
  confidence             text NOT NULL CHECK (confidence IN ('high','medium','low')),
  samples_count          integer NOT NULL DEFAULT 0,

  -- (a) the prediction
  observed_interval_days  numeric(7,2),   -- physical: mean days between successful refills
  mb_per_day              numeric(12,2),  -- eSIM: fitted burn rate
  effective_validity_days integer,
  predicted_depletion_at  timestamptz,
  days_remaining          integer,

  -- (b) the proposal
  suggested_frequency_days integer,
  suggested_amount_usd     numeric(10,2),
  suggested_offer_id       varchar(120),

  -- (c) alert bookkeeping
  alert_lead_days        integer NOT NULL DEFAULT 7,
  last_alert_at          timestamptz,

  computed_at            timestamptz NOT NULL DEFAULT NOW(),

  CONSTRAINT sim_line_usage_forecast_one_subject CHECK (num_nonnulls(sim_line_id, esim_id) = 1),
  CONSTRAINT sim_line_usage_forecast_kind_matches CHECK (
    (subject_kind = 'sim_line' AND sim_line_id IS NOT NULL) OR
    (subject_kind = 'esim'     AND esim_id     IS NOT NULL)
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS sim_line_usage_forecast_line_uq
  ON public.sim_line_usage_forecast (sim_line_id) WHERE sim_line_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS sim_line_usage_forecast_esim_uq
  ON public.sim_line_usage_forecast (esim_id) WHERE esim_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS sim_line_usage_forecast_user_idx
  ON public.sim_line_usage_forecast (user_id);
CREATE INDEX IF NOT EXISTS sim_line_usage_forecast_due_idx
  ON public.sim_line_usage_forecast (predicted_depletion_at)
  WHERE predicted_depletion_at IS NOT NULL;

ALTER TABLE public.sim_line_usage_forecast ENABLE ROW LEVEL SECURITY;

-- Read-own, plus the household counterpart, mirroring the sim_lines /
-- line_activity_log read model — otherwise the card silently disappears for a
-- household member who can see the line itself.
DROP POLICY IF EXISTS "Users can view own or household usage forecast" ON public.sim_line_usage_forecast;
CREATE POLICY "Users can view own or household usage forecast"
  ON public.sim_line_usage_forecast
  FOR SELECT TO authenticated
  USING (
    (
      auth.uid() = user_id
      OR EXISTS (
        SELECT 1 FROM public.household_members hm
        WHERE hm.owner_id = sim_line_usage_forecast.user_id
          AND hm.member_id = auth.uid()
          AND hm.invite_status = 'accepted'
      )
    )
    AND NOT public.is_user_suspended()
  );

-- No client writes at all: this is derived data, written only by the job.
REVOKE ALL ON TABLE public.sim_line_usage_forecast FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.sim_line_usage_forecast TO authenticated;
GRANT ALL    ON TABLE public.sim_line_usage_forecast TO service_role;

COMMENT ON TABLE public.sim_line_usage_forecast IS
  'G1: nightly depletion forecast + suggested refill schedule, one row per sim_line or user_esim. Read-own; written only by refresh_usage_forecasts().';

-- ---------------------------------------------------------------------------
-- 3. Tunables. Kept in system_configs so the lead time can change without a
--    release, same as every other business number in this project.
-- ---------------------------------------------------------------------------
INSERT INTO public.system_configs (config_key, config_value)
VALUES ('FORECAST_ALERT_LEAD_DAYS', '7')
ON CONFLICT (config_key) DO NOTHING;

INSERT INTO public.system_configs (config_key, config_value)
VALUES ('FORECAST_DEFAULT_VALIDITY_DAYS', '90')
ON CONFLICT (config_key) DO NOTHING;

-- The shortest gap between two successful top-ups that can be a real refill
-- *cycle*. Anything below it is a retry, a duplicate, or test traffic — and it
-- poisons the fit badly: on the live data a line with five test executions
-- minutes apart fitted a 0.40-day cycle, which predicted the line was already
-- dead and proposed a 7-day refill for a 30-day carrier window.
INSERT INTO public.system_configs (config_key, config_value)
VALUES ('FORECAST_MIN_CYCLE_DAYS', '3')
ON CONFLICT (config_key) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. snapshot_esim_usage() — record today's reading for every live eSIM.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.snapshot_esim_usage()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_rows integer;
BEGIN
  INSERT INTO public.esim_usage_samples (esim_id, sampled_on, data_remaining_mb, data_total_mb)
  SELECT e.id, (NOW() AT TIME ZONE 'utc')::date, e.data_remaining_mb, e.data_total_mb
  FROM public.user_esims e
  WHERE e.status = 'active'
    AND e.data_remaining_mb IS NOT NULL
  ON CONFLICT (esim_id, sampled_on) DO UPDATE
    SET data_remaining_mb = EXCLUDED.data_remaining_mb,
        data_total_mb     = EXCLUDED.data_total_mb;

  GET DIAGNOSTICS v_rows = ROW_COUNT;
  RETURN v_rows;
END;
$function$;

REVOKE ALL ON FUNCTION public.snapshot_esim_usage() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.snapshot_esim_usage() TO service_role;

-- ---------------------------------------------------------------------------
-- 5. compute_usage_forecasts() — the fit.
--
-- Physical lines: the gap between successful top-ups is the observed cycle.
-- The carrier's inactivity limit (+ grace) is the hard deadline. A line dies at
-- whichever comes first, so the prediction is LEAST(cycle, carrier deadline).
-- With no history we still have the carrier rule; with neither, a configured
-- default. `method`/`confidence` record which of those happened — the UI must
-- never present a default-90-days guess as if it were a measurement.
--
-- eSIMs: MB remaining ÷ fitted MB/day, capped by the bundle's own expires_at.
--
-- NOTE on LEAST/GREATEST: unlike MIN/MAX they ignore NULL arguments, which is
-- exactly the "whichever signal we happen to have" semantics wanted here.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.compute_usage_forecasts()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_default_validity integer;
  v_lead_days        integer;
  v_min_cycle        integer;
  v_rows             integer := 0;
  v_n                integer;
BEGIN
  SELECT COALESCE(NULLIF(config_value, '')::integer, 90) INTO v_default_validity
  FROM public.system_configs WHERE config_key = 'FORECAST_DEFAULT_VALIDITY_DAYS';
  v_default_validity := COALESCE(v_default_validity, 90);

  SELECT COALESCE(NULLIF(config_value, '')::integer, 7) INTO v_lead_days
  FROM public.system_configs WHERE config_key = 'FORECAST_ALERT_LEAD_DAYS';
  v_lead_days := COALESCE(v_lead_days, 7);

  SELECT COALESCE(NULLIF(config_value, '')::integer, 3) INTO v_min_cycle
  FROM public.system_configs WHERE config_key = 'FORECAST_MIN_CYCLE_DAYS';
  v_min_cycle := COALESCE(v_min_cycle, 3);

  -- ---------------- physical SIM lines ----------------
  WITH ok_exec AS (
    SELECT te.sim_line_id,
           te.amount,
           te.offer_id,
           COALESCE(te.completed_at, te.execution_time, te.executed_at, te.created_at) AS at
    FROM public.topup_executions te
    WHERE te.status IN ('success', 'completed')
      AND COALESCE(te.completed_at, te.execution_time, te.executed_at, te.created_at)
          >= NOW() - INTERVAL '365 days'
  ),
  gaps AS (
    SELECT sim_line_id,
           EXTRACT(EPOCH FROM (at - LAG(at) OVER (PARTITION BY sim_line_id ORDER BY at))) / 86400.0 AS gap_days
    FROM ok_exec
  ),
  hist AS (
    -- v_min_cycle floor: a sub-3-day gap is a retry or a duplicate, not a
    -- refill cycle. Without it, one retry storm collapses the whole fit.
    SELECT g.sim_line_id,
           COUNT(*)::integer                  AS gap_count,
           ROUND(AVG(g.gap_days)::numeric, 2) AS mean_gap
    FROM gaps g
    WHERE g.gap_days IS NOT NULL AND g.gap_days >= v_min_cycle
    GROUP BY g.sim_line_id
  ),
  money AS (
    SELECT e.sim_line_id,
           COUNT(*)::integer AS exec_count,
           ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY e.amount)::numeric, 2) AS median_amount,
           (ARRAY_AGG(e.offer_id ORDER BY e.at DESC) FILTER (WHERE e.offer_id IS NOT NULL))[1] AS last_offer_id
    FROM ok_exec e
    GROUP BY e.sim_line_id
  ),
  rule AS (
    -- carrier_rule_id is NULL on every line today, so resolve through the
    -- carrier as well. One rule per carrier in practice; DISTINCT ON makes the
    -- pick deterministic if that ever stops being true.
    SELECT DISTINCT ON (sl.id)
           sl.id AS sim_line_id,
           cr.inactivity_limit_days,
           cr.topup_validity_days,
           cr.grace_period_days,
           cr.recommended_topup_amount,
           cr.minimum_topup_amount,
           cr.offer_id AS rule_offer_id
    FROM public.sim_lines sl
    LEFT JOIN public.carrier_rules cr
           ON cr.id = sl.carrier_rule_id
           OR (sl.carrier_rule_id IS NULL AND cr.carrier_id = sl.carrier_id)
    ORDER BY sl.id, (cr.id = sl.carrier_rule_id) DESC NULLS LAST, cr.updated_at DESC NULLS LAST
  ),
  calc AS (
    SELECT sl.id                                            AS sim_line_id,
           sl.user_id,
           COALESCE(sl.last_topup_at, sl.created_at, NOW()) AS anchor,
           h.gap_count,
           h.mean_gap,
           m.exec_count,
           m.median_amount,
           m.last_offer_id,
           r.inactivity_limit_days,
           r.topup_validity_days,
           r.grace_period_days,
           r.recommended_topup_amount,
           r.minimum_topup_amount,
           r.rule_offer_id
    FROM public.sim_lines sl
    LEFT JOIN hist  h ON h.sim_line_id = sl.id
    LEFT JOIN money m ON m.sim_line_id = sl.id
    LEFT JOIN rule  r ON r.sim_line_id = sl.id
    WHERE sl.status = 'active'
  ),
  shaped AS (
    SELECT c.*,
           -- when the SIM is actually lost, not merely empty
           CASE
             WHEN c.inactivity_limit_days IS NOT NULL
               THEN c.inactivity_limit_days + COALESCE(c.grace_period_days, 0)
             WHEN c.topup_validity_days IS NOT NULL
               THEN c.topup_validity_days + COALESCE(c.grace_period_days, 0)
           END AS carrier_deadline_days,
           CASE WHEN COALESCE(c.gap_count, 0) >= 1
                THEN GREATEST(ROUND(c.mean_gap)::integer, 1) END AS observed_days
    FROM calc c
  ),
  final AS (
    SELECT s.*,
           COALESCE(s.observed_days, s.topup_validity_days, s.carrier_deadline_days, v_default_validity) AS cycle_days,
           CASE
             WHEN COALESCE(s.gap_count, 0) >= 1 THEN 'topup_history'
             WHEN s.topup_validity_days IS NOT NULL OR s.carrier_deadline_days IS NOT NULL THEN 'carrier_rule'
             ELSE 'default'
           END AS method,
           CASE
             WHEN COALESCE(s.gap_count, 0) >= 3 THEN 'high'
             WHEN COALESCE(s.gap_count, 0) >= 1 THEN 'medium'
             WHEN s.topup_validity_days IS NOT NULL OR s.carrier_deadline_days IS NOT NULL THEN 'medium'
             ELSE 'low'
           END AS confidence
    FROM shaped s
  ),
  dated AS (
    SELECT f.*,
           LEAST(
             f.anchor + (f.cycle_days || ' days')::interval,
             f.anchor + (f.carrier_deadline_days || ' days')::interval
           ) AS depletion_at
    FROM final f
  )
  INSERT INTO public.sim_line_usage_forecast AS t (
    user_id, sim_line_id, subject_kind, method, confidence, samples_count,
    observed_interval_days, effective_validity_days, predicted_depletion_at, days_remaining,
    suggested_frequency_days, suggested_amount_usd, suggested_offer_id,
    alert_lead_days, computed_at
  )
  SELECT
    d.user_id,
    d.sim_line_id,
    'sim_line',
    d.method,
    d.confidence,
    COALESCE(d.exec_count, 0),
    d.mean_gap,
    d.cycle_days,
    d.depletion_at,
    GREATEST(0, CEIL(EXTRACT(EPOCH FROM (d.depletion_at - NOW())) / 86400.0))::integer,
    -- Snap to a frequency the schedule sheet actually offers, choosing the
    -- largest one that still *executes* inside the window. The thresholds are
    -- the EXECUTION days, not the chip labels: RefillScheduleMath
    -- .safetyAdjustedDelayDays maps 90→85, 30→28, 14→13. Keying on the labels
    -- instead sends a measured 28-day cycle to the 14-day chip and doubles the
    -- user's refill spend for no protection gain. Change one of those constants
    -- and this must change with it.
    CASE
      WHEN d.cycle_days >= 85 THEN 90
      WHEN d.cycle_days >= 28 THEN 30
      WHEN d.cycle_days >= 13 THEN 14
      ELSE 7
    END,
    COALESCE(d.median_amount, d.recommended_topup_amount, d.minimum_topup_amount),
    COALESCE(d.last_offer_id, d.rule_offer_id),
    v_lead_days,
    NOW()
  FROM dated d
  ON CONFLICT (sim_line_id) WHERE sim_line_id IS NOT NULL DO UPDATE SET
    user_id                  = EXCLUDED.user_id,
    method                   = EXCLUDED.method,
    confidence               = EXCLUDED.confidence,
    samples_count            = EXCLUDED.samples_count,
    observed_interval_days   = EXCLUDED.observed_interval_days,
    effective_validity_days  = EXCLUDED.effective_validity_days,
    predicted_depletion_at   = EXCLUDED.predicted_depletion_at,
    days_remaining           = EXCLUDED.days_remaining,
    suggested_frequency_days = EXCLUDED.suggested_frequency_days,
    suggested_amount_usd     = EXCLUDED.suggested_amount_usd,
    suggested_offer_id       = EXCLUDED.suggested_offer_id,
    alert_lead_days          = EXCLUDED.alert_lead_days,
    computed_at              = EXCLUDED.computed_at;

  GET DIAGNOSTICS v_n = ROW_COUNT;
  v_rows := v_rows + v_n;

  -- ---------------- eSIMs ----------------
  WITH s AS (
    SELECT esim_id,
           FIRST_VALUE(data_remaining_mb) OVER w              AS first_mb,
           LAST_VALUE(data_remaining_mb)  OVER w              AS last_mb,
           MIN(sampled_on) OVER (PARTITION BY esim_id)        AS first_on,
           MAX(sampled_on) OVER (PARTITION BY esim_id)        AS last_on,
           COUNT(*)        OVER (PARTITION BY esim_id)        AS n
    FROM public.esim_usage_samples
    WHERE sampled_on >= ((NOW() AT TIME ZONE 'utc')::date - 30)
    WINDOW w AS (PARTITION BY esim_id ORDER BY sampled_on
                 ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
  ),
  agg AS (
    SELECT DISTINCT esim_id, n::integer AS n, first_mb, last_mb, (last_on - first_on) AS span_days
    FROM s
  ),
  rate AS (
    SELECT a.esim_id,
           a.n,
           CASE
             WHEN a.span_days >= 1 AND a.first_mb > a.last_mb
               THEN ROUND(((a.first_mb - a.last_mb)::numeric / a.span_days), 2)
           END AS mb_per_day
    FROM agg a
  ),
  ecalc AS (
    SELECT e.id AS esim_id,
           e.user_id,
           e.expires_at,
           r.n,
           r.mb_per_day,
           CASE
             WHEN r.mb_per_day IS NOT NULL AND r.mb_per_day > 0 AND e.data_remaining_mb IS NOT NULL
               THEN NOW() + ((e.data_remaining_mb::numeric / r.mb_per_day) || ' days')::interval
           END AS data_out_at
    FROM public.user_esims e
    LEFT JOIN rate r ON r.esim_id = e.id
    WHERE e.status = 'active'
  )
  INSERT INTO public.sim_line_usage_forecast AS t (
    user_id, esim_id, subject_kind, method, confidence, samples_count,
    mb_per_day, predicted_depletion_at, days_remaining,
    alert_lead_days, computed_at
  )
  SELECT
    c.user_id,
    c.esim_id,
    'esim',
    CASE WHEN c.data_out_at IS NOT NULL THEN 'esim_usage' ELSE 'default' END,
    CASE
      WHEN c.data_out_at IS NOT NULL AND COALESCE(c.n, 0) >= 7 THEN 'high'
      WHEN c.data_out_at IS NOT NULL                           THEN 'medium'
      ELSE 'low'
    END,
    COALESCE(c.n, 0),
    c.mb_per_day,
    LEAST(c.data_out_at, c.expires_at),
    GREATEST(0, CEIL(EXTRACT(EPOCH FROM (LEAST(c.data_out_at, c.expires_at) - NOW())) / 86400.0))::integer,
    v_lead_days,
    NOW()
  FROM ecalc c
  WHERE LEAST(c.data_out_at, c.expires_at) IS NOT NULL
  ON CONFLICT (esim_id) WHERE esim_id IS NOT NULL DO UPDATE SET
    user_id                = EXCLUDED.user_id,
    method                 = EXCLUDED.method,
    confidence             = EXCLUDED.confidence,
    samples_count          = EXCLUDED.samples_count,
    mb_per_day             = EXCLUDED.mb_per_day,
    predicted_depletion_at = EXCLUDED.predicted_depletion_at,
    days_remaining         = EXCLUDED.days_remaining,
    alert_lead_days        = EXCLUDED.alert_lead_days,
    computed_at            = EXCLUDED.computed_at;

  GET DIAGNOSTICS v_n = ROW_COUNT;
  v_rows := v_rows + v_n;

  RETURN v_rows;
END;
$function$;

REVOKE ALL ON FUNCTION public.compute_usage_forecasts() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.compute_usage_forecasts() TO service_role;

-- ---------------------------------------------------------------------------
-- 6. emit_forecast_depletion_alerts() — outcome (c).
--
-- `line_critical` today only fires on the user's own notify cadence
-- (process_due_notifications), which is a calendar, not a prediction. This
-- fires off the forecast instead, so a line that is genuinely about to lapse
-- is flagged `alert_lead_days` before it happens.
--
-- Two suppressions, both deliberate:
--   * a paused line is a user decision, not a problem;
--   * an active auto-refill scheduled to execute BEFORE the predicted
--     depletion is the protection working. Alerting there would be nagging a
--     user about something the product is already handling for them.
-- A `notify` schedule does NOT suppress it — firing earlier than that calendar
-- is the entire point.
--
-- Dedup is one alert per line per lead window (`last_alert_at`). The nightly
-- job is therefore idempotent: re-running it the same day emits nothing.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.emit_forecast_depletion_alerts()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  r       RECORD;
  v_count integer := 0;
  v_label text;
  v_when  text;
BEGIN
  FOR r IN
    SELECT f.id                     AS forecast_id,
           f.user_id,
           f.sim_line_id,
           f.days_remaining,
           f.predicted_depletion_at,
           f.confidence,
           f.method,
           f.suggested_amount_usd,
           sl.phone_number,
           sl.nickname
    FROM public.sim_line_usage_forecast f
    JOIN public.sim_lines sl ON sl.id = f.sim_line_id
    WHERE f.subject_kind = 'sim_line'
      AND sl.status = 'active'
      AND COALESCE(sl.protection_paused, false) = false
      AND f.predicted_depletion_at IS NOT NULL
      AND f.predicted_depletion_at <= NOW() + (f.alert_lead_days || ' days')::interval
      AND (
        f.last_alert_at IS NULL
        OR f.last_alert_at < NOW() - (f.alert_lead_days || ' days')::interval
      )
      AND NOT EXISTS (
        SELECT 1
        FROM public.scheduled_topups st
        WHERE st.sim_line_id = f.sim_line_id
          AND st.is_active = true
          AND st.status = 'active'
          AND st.schedule_type IN ('refill_custom', 'refill_mini')
          AND st.next_execution_at <= f.predicted_depletion_at
      )
  LOOP
    v_label := COALESCE(NULLIF(r.nickname, ''), r.phone_number, 'Your SIM line');
    v_when  := CASE
                 WHEN r.days_remaining <= 0 THEN 'is out of validity now'
                 WHEN r.days_remaining = 1  THEN 'runs out tomorrow'
                 ELSE 'runs out in ' || r.days_remaining || ' days'
               END;

    INSERT INTO public.notifications (
      user_id, category, title, body, action_url, sim_line_id, delivered_via, is_read, created_at
    ) VALUES (
      r.user_id,
      'line_critical',
      'Refill predicted for ' || v_label,
      v_label || ' ' || v_when || ' (around ' || to_char(r.predicted_depletion_at, 'Mon DD') || ')'
        || CASE
             WHEN r.suggested_amount_usd IS NOT NULL
               THEN '. A top-up of about $' || to_char(r.suggested_amount_usd, 'FM99999990.00') || ' keeps it active.'
             ELSE '. Top it up to keep it active.'
           END,
      '/sim_lines/' || r.sim_line_id,
      r.sim_line_id,
      ARRAY['push'::text],
      false,
      NOW()
    );

    INSERT INTO public.line_activity_log (
      sim_line_id, user_id, event_type, description, metadata, created_at
    ) VALUES (
      r.sim_line_id,
      r.user_id,
      'reminder_sent',
      NULL,
      jsonb_build_object(
        'source',                 'forecast',
        'method',                 r.method,
        'confidence',             r.confidence,
        'days_remaining',         r.days_remaining,
        'predicted_depletion_at', r.predicted_depletion_at
      ),
      clock_timestamp()
    );

    UPDATE public.sim_line_usage_forecast
       SET last_alert_at = NOW()
     WHERE id = r.forecast_id;

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$function$;

REVOKE ALL ON FUNCTION public.emit_forecast_depletion_alerts() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.emit_forecast_depletion_alerts() TO service_role;

-- ---------------------------------------------------------------------------
-- 7. refresh_usage_forecasts() — the single cron entry point.
--
-- No `WHEN OTHERS` handler on purpose. `enforce_rate_limit` ends in one and it
-- silently swallowed a new guard during F0; a nightly job that fails must show
-- up in cron.job_run_details, not return a cheerful zero.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.refresh_usage_forecasts()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_samples   integer;
  v_forecasts integer;
  v_alerts    integer;
BEGIN
  v_samples   := public.snapshot_esim_usage();
  v_forecasts := public.compute_usage_forecasts();
  v_alerts    := public.emit_forecast_depletion_alerts();

  RETURN jsonb_build_object(
    'esim_samples', v_samples,
    'forecasts',    v_forecasts,
    'alerts',       v_alerts,
    'ran_at',       NOW()
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.refresh_usage_forecasts() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_usage_forecasts() TO service_role;

-- ---------------------------------------------------------------------------
-- 8. Nightly at 02:20 UTC — after the eSIM worker's usage poll has had the
--    night to run, and clear of the 03:00 rate-limit prune.
-- ---------------------------------------------------------------------------
DO $cron$
BEGIN
  PERFORM cron.unschedule('refresh-usage-forecasts')
  WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'refresh-usage-forecasts');

  PERFORM cron.schedule(
    'refresh-usage-forecasts',
    '20 2 * * *',
    'SELECT public.refresh_usage_forecasts();'
  );
END;
$cron$;
