-- i7d: stop the forecast suggesting refills off the bundle cycle
--
-- This closes a regression that i7b opened, and an older one it exposed.
--
-- THE REGRESSION. `compute_usage_forecasts` derived a line's cycle from
-- `carrier_rules.topup_validity_days`, which used to be a flat 30 for nearly
-- every carrier. i7 redefined that column as "line validity a minimum top-up
-- buys" and i7b filled in the real values — 7 days for the Kuwaiti operators,
-- 13 for Alfa Lebanon, because that is genuinely all a small voucher buys
-- there. The forecast kept reading it as a refill cycle, so a Kuwaiti line with
-- no top-up history would have been handed a 7-day suggested frequency against
-- a minimum qualifying refill of USD 32.70. That is roughly USD 1,700 a year to
-- protect a line the carrier only terminates after 90 days of inactivity.
--
-- THE OLDER ONE. `suggested_frequency_days` preferred `observed_days`, the mean
-- gap between the line's own past top-ups. Those gaps were produced by the
-- 30-day cadence this phase is removing, so feeding them back in launders the
-- old bug into a permanent "measured" fact about the user. Refill cadence now
-- comes from the carrier rule whenever there is one, and observed history is
-- used only where no rule exists.
--
-- Observed history still drives `predicted_depletion_at` and
-- `effective_validity_days`. That is the right use for it: how fast someone
-- burns credit is a real behavioural signal about their BALANCE. It just says
-- nothing about when the carrier reclaims their NUMBER.
--
-- THE SNAP IS GONE for rule-backed lines. It mapped a cycle onto the sheet's
-- {7,14,30,90} chips using execution-day thresholds (90→85, 30→28, 14→13).
-- With real per-carrier windows the cadences are continuous — 76, 80, 102, 127,
-- 153, 280, 310 — and the nearest chip is wrong in both directions: an interval
-- of 76 falls into the 30 bucket (12 refills a year against a real need of 5),
-- and 280 collapses to 90 (4 against 2). The suggestion is now the carrier's
-- actual cadence, and the schedule sheet offers it as its own chip. The legacy
-- ladder survives only for lines with no carrier rule at all.

BEGIN;

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
           -- i7d: the cadence, not the bundle cycle. Same function the premium
           -- queue steps by and the Dart quote prices from.
           public.refill_interval_days(
             cr.inactivity_limit_days, cr.refill_interval_days_override
           ) AS carrier_cycle_days,
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
           r.carrier_cycle_days,
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
             WHEN c.carrier_cycle_days IS NOT NULL
               THEN c.carrier_cycle_days + COALESCE(c.grace_period_days, 0)
           END AS carrier_deadline_days,
           CASE WHEN COALESCE(c.gap_count, 0) >= 1
                THEN GREATEST(ROUND(c.mean_gap)::integer, 1) END AS observed_days
    FROM calc c
  ),
  final AS (
    SELECT s.*,
           -- Depletion: how fast this person actually burns credit, which is a
           -- genuine behavioural signal, falling back to the carrier's cadence.
           COALESCE(s.observed_days, s.carrier_cycle_days, s.carrier_deadline_days, v_default_validity) AS cycle_days,
           CASE
             WHEN COALESCE(s.gap_count, 0) >= 1 THEN 'topup_history'
             WHEN s.carrier_cycle_days IS NOT NULL OR s.carrier_deadline_days IS NOT NULL THEN 'carrier_rule'
             ELSE 'default'
           END AS method,
           CASE
             WHEN COALESCE(s.gap_count, 0) >= 3 THEN 'high'
             WHEN COALESCE(s.gap_count, 0) >= 1 THEN 'medium'
             WHEN s.carrier_cycle_days IS NOT NULL OR s.carrier_deadline_days IS NOT NULL THEN 'medium'
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
    -- i7d: the carrier's own cadence wins outright where we have a rule. It is
    -- already safety-adjusted by refill_interval_days(), so it is an EXECUTION
    -- day and must not be re-adjusted by the sheet's chip mapping. Observed
    -- gaps are deliberately not consulted here — they were manufactured by the
    -- cadence bug this phase removes, and reusing them would make it permanent.
    -- The legacy chip ladder survives only for lines with no carrier rule,
    -- where its execution-day thresholds (90→85, 30→28, 14→13) still hold.
    CASE
      WHEN d.carrier_cycle_days IS NOT NULL THEN d.carrier_cycle_days
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

  -- ---------------- eSIMs ---------------- (unchanged by i7d)
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

COMMIT;
