-- Migration: 20260916080000_fix_forecast_anchor_null_recharge.sql
-- Description: Ensure compute_usage_forecasts() does NOT manufacture a depletion forecast
-- for SIM lines that have never had a last_topup_at recorded.
-- If sl.last_topup_at IS NULL, anchor is NULL, resulting in depletion_at = NULL and days_remaining = NULL.

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
    SELECT DISTINCT ON (sl.id)
           sl.id AS sim_line_id,
           cr.inactivity_limit_days,
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
    SELECT sl.id AS sim_line_id,
           sl.user_id,
           -- Do NOT fall back to created_at or NOW() when last_topup_at is NULL.
           -- If the user never recorded a recharge, there is no recharge baseline.
           sl.last_topup_at AS anchor,
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
           COALESCE(s.observed_days, s.carrier_cycle_days, s.carrier_deadline_days, v_default_validity) AS cycle_days,
           CASE
             WHEN s.anchor IS NULL THEN 'none'
             WHEN COALESCE(s.gap_count, 0) >= 1 THEN 'topup_history'
             WHEN s.carrier_cycle_days IS NOT NULL OR s.carrier_deadline_days IS NOT NULL THEN 'carrier_rule'
             ELSE 'default'
           END AS method,
           CASE
             WHEN s.anchor IS NULL THEN 'low'
             WHEN COALESCE(s.gap_count, 0) >= 3 THEN 'high'
             WHEN COALESCE(s.gap_count, 0) >= 1 THEN 'medium'
             WHEN s.carrier_cycle_days IS NOT NULL OR s.carrier_deadline_days IS NOT NULL THEN 'medium'
             ELSE 'low'
           END AS confidence
    FROM shaped s
  ),
  dated AS (
    SELECT f.*,
           CASE
             WHEN f.anchor IS NOT NULL THEN
               LEAST(
                 f.anchor + (f.cycle_days || ' days')::interval,
                 f.anchor + (f.carrier_deadline_days || ' days')::interval
               )
             ELSE NULL
           END AS depletion_at
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
    CASE
      WHEN d.depletion_at IS NOT NULL THEN
        GREATEST(0, CEIL(EXTRACT(EPOCH FROM (d.depletion_at - NOW())) / 86400.0))::integer
      ELSE NULL
    END,
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
             ELSE NULL
           END AS mb_per_day
    FROM agg a
  ),
  current_esim AS (
    SELECT e.id                                        AS esim_id,
           e.user_id,
           e.data_remaining_mb,
           e.validity_days,
           e.expires_at,
           (e.metadata->>'offer_id')                   AS offer_id,
           (e.metadata->>'initial_cost_usd')::numeric  AS cost_usd
    FROM public.esims e
    WHERE e.status = 'active'
  ),
  matched AS (
    SELECT c.*,
           r.mb_per_day,
           r.n AS samples_count,
           CASE
             WHEN r.mb_per_day IS NOT NULL AND r.mb_per_day > 0
               THEN CEIL(c.data_remaining_mb / r.mb_per_day)::integer
             ELSE NULL
           END AS days_to_zero
    FROM current_esim c
    LEFT JOIN rate r ON r.esim_id = c.esim_id
  ),
  dated AS (
    SELECT m.*,
           CASE
             WHEN m.days_to_zero IS NOT NULL AND m.expires_at IS NOT NULL
               THEN LEAST(NOW() + (m.days_to_zero || ' days')::interval, m.expires_at)
             WHEN m.days_to_zero IS NOT NULL
               THEN NOW() + (m.days_to_zero || ' days')::interval
             WHEN m.expires_at IS NOT NULL
               THEN m.expires_at
             ELSE NULL
           END AS depletion_at
    FROM matched m
  )
  INSERT INTO public.sim_line_usage_forecast AS t (
    user_id, esim_id, subject_kind, method, confidence, samples_count,
    mb_per_day, effective_validity_days, predicted_depletion_at, days_remaining,
    suggested_frequency_days, suggested_amount_usd, suggested_offer_id,
    alert_lead_days, computed_at
  )
  SELECT
    d.user_id,
    d.esim_id,
    'esim',
    CASE WHEN d.mb_per_day IS NOT NULL THEN 'esim_usage' ELSE 'default' END,
    CASE
      WHEN d.samples_count >= 7 THEN 'high'
      WHEN d.samples_count >= 3 THEN 'medium'
      ELSE 'low'
    END,
    COALESCE(d.samples_count, 0),
    d.mb_per_day,
    d.validity_days,
    d.depletion_at,
    CASE
      WHEN d.depletion_at IS NOT NULL
        THEN GREATEST(0, CEIL(EXTRACT(EPOCH FROM (d.depletion_at - NOW())) / 86400.0))::integer
      ELSE NULL
    END,
    COALESCE(d.validity_days, 30),
    d.cost_usd,
    d.offer_id,
    v_lead_days,
    NOW()
  FROM dated d
  ON CONFLICT (esim_id) WHERE esim_id IS NOT NULL DO UPDATE SET
    user_id                  = EXCLUDED.user_id,
    method                   = EXCLUDED.method,
    confidence               = EXCLUDED.confidence,
    samples_count            = EXCLUDED.samples_count,
    mb_per_day               = EXCLUDED.mb_per_day,
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

  -- Clear forecasts that had fabricated predictions when last_topup_at is NULL
  UPDATE public.sim_line_usage_forecast f
  SET predicted_depletion_at = NULL,
      days_remaining = NULL,
      confidence = 'low'
  FROM public.sim_lines sl
  WHERE f.sim_line_id = sl.id
    AND sl.last_topup_at IS NULL;

  RETURN v_rows;
END;
$function$;

-- Update current forecast rows for any lines with no last_topup_at
UPDATE public.sim_line_usage_forecast f
SET predicted_depletion_at = NULL,
    days_remaining = NULL,
    confidence = 'low'
FROM public.sim_lines sl
WHERE f.sim_line_id = sl.id
  AND sl.last_topup_at IS NULL;

COMMIT;
