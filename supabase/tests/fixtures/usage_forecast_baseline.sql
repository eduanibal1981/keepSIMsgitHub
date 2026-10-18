-- ISOLATED ONLY: forecast extension; load notification_scheduler_baseline.sql first.

SET check_function_bodies=false;

CREATE TABLE IF NOT EXISTS "public"."user_esims" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "order_id" "uuid" NOT NULL,
    "iccid" "text" NOT NULL,
    "smdp_address" "text" NOT NULL,
    "matching_id" "text" NOT NULL,
    "lpa_string" "text" NOT NULL,
    "bundle_name" "text" NOT NULL,
    "provider" "text" DEFAULT 'esim_go'::"text" NOT NULL,
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    "purchased_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "expires_at" timestamp with time zone,
    "data_total_mb" bigint NOT NULL,
    "data_remaining_mb" bigint NOT NULL,
    "last_usage_check" timestamp with time zone,
    "low_data_notified" boolean DEFAULT false NOT NULL,
    CONSTRAINT "user_esims_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'expired'::"text", 'depleted'::"text", 'installed'::"text"])))
);

CREATE TABLE IF NOT EXISTS "public"."esim_orders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "provider" "text" DEFAULT 'esim_go'::"text" NOT NULL,
    "bundle_name" "text" NOT NULL,
    "quantity" integer DEFAULT 1 NOT NULL,
    "wholesale_price_usd" numeric(10,4) NOT NULL,
    "retail_price_usd" numeric(10,2) NOT NULL,
    "markup_percent" numeric(5,2) NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "provider_order_ref" "text",
    "error_message" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "offer_id" "text",
    "total_amount_usd" numeric(10,2),
    CONSTRAINT "esim_orders_quantity_check" CHECK ((("quantity" >= 1) AND ("quantity" <= 3))),
    CONSTRAINT "esim_orders_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'processing'::"text", 'completed'::"text", 'failed'::"text", 'refunded'::"text"])))
);

CREATE TABLE IF NOT EXISTS "public"."esim_offers_cache" (
    "provider" "text" DEFAULT 'esim_go'::"text" NOT NULL,
    "bundle_name" "text" NOT NULL,
    "description" "text",
    "countries" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "roaming_enabled" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "data_amount_mb" bigint DEFAULT 0 NOT NULL,
    "duration_days" integer DEFAULT 0 NOT NULL,
    "wholesale_price_usd" numeric(10,4) DEFAULT 0.0000 NOT NULL,
    "image_url" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "clock_timestamp"() NOT NULL,
    "is_unlimited" boolean DEFAULT false NOT NULL,
    "bundle_group" "text",
    "speed_tier" "text",
    "region" "text",
    "country_count" integer DEFAULT 0 NOT NULL
);

CREATE TABLE IF NOT EXISTS "public"."esim_usage_samples" (
    "esim_id" "uuid" NOT NULL,
    "sampled_on" "date" NOT NULL,
    "data_remaining_mb" bigint,
    "data_total_mb" bigint,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);

CREATE TABLE IF NOT EXISTS "public"."sim_line_usage_forecast" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "sim_line_id" "uuid",
    "esim_id" "uuid",
    "subject_kind" "text" NOT NULL,
    "method" "text" NOT NULL,
    "confidence" "text" NOT NULL,
    "samples_count" integer DEFAULT 0 NOT NULL,
    "observed_interval_days" numeric(7,2),
    "mb_per_day" numeric(12,2),
    "effective_validity_days" integer,
    "predicted_depletion_at" timestamp with time zone,
    "days_remaining" integer,
    "suggested_frequency_days" integer,
    "suggested_amount_usd" numeric(10,2),
    "suggested_offer_id" character varying(120),
    "alert_lead_days" integer DEFAULT 7 NOT NULL,
    "last_alert_at" timestamp with time zone,
    "computed_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "sim_line_usage_forecast_confidence_check" CHECK (("confidence" = ANY (ARRAY['high'::"text", 'medium'::"text", 'low'::"text"]))),
    CONSTRAINT "sim_line_usage_forecast_kind_matches" CHECK (((("subject_kind" = 'sim_line'::"text") AND ("sim_line_id" IS NOT NULL)) OR (("subject_kind" = 'esim'::"text") AND ("esim_id" IS NOT NULL)))),
    CONSTRAINT "sim_line_usage_forecast_method_check" CHECK (("method" = ANY (ARRAY['topup_history'::"text", 'esim_usage'::"text", 'carrier_rule'::"text", 'default'::"text"]))),
    CONSTRAINT "sim_line_usage_forecast_one_subject" CHECK (("num_nonnulls"("sim_line_id", "esim_id") = 1)),
    CONSTRAINT "sim_line_usage_forecast_subject_kind_check" CHECK (("subject_kind" = ANY (ARRAY['sim_line'::"text", 'esim'::"text"])))
);

CREATE TABLE IF NOT EXISTS "public"."household_members" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "owner_id" "uuid" NOT NULL,
    "member_email" "text" NOT NULL,
    "member_id" "uuid",
    "role" "text" DEFAULT 'viewer'::"text",
    "invite_status" "text" DEFAULT 'pending'::"text",
    "invited_at" timestamp with time zone DEFAULT "now"(),
    "accepted_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "monthly_cap_usd" numeric(10,2) DEFAULT 0.00 NOT NULL,
    "per_txn_cap_usd" numeric(10,2),
    "cap_updated_at" timestamp with time zone,
    "cap_updated_by" "uuid",
    CONSTRAINT "household_members_invite_status_check" CHECK (("invite_status" = ANY (ARRAY['pending'::"text", 'accepted'::"text", 'declined'::"text"]))),
    CONSTRAINT "household_members_monthly_cap_nonneg" CHECK ((("monthly_cap_usd" >= (0)::numeric) AND ("monthly_cap_usd" <= (100000)::numeric))),
    CONSTRAINT "household_members_per_txn_cap_positive" CHECK ((("per_txn_cap_usd" IS NULL) OR (("per_txn_cap_usd" > (0)::numeric) AND ("per_txn_cap_usd" <= "monthly_cap_usd")))),
    CONSTRAINT "household_members_role_check" CHECK (("role" = ANY (ARRAY['viewer'::"text", 'manager'::"text"])))
);

CREATE TABLE IF NOT EXISTS "public"."sim_line_rescue_policy" (
    "sim_line_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "max_usd" numeric(10,2) DEFAULT 0.00 NOT NULL,
    "lead_days" integer DEFAULT 2 NOT NULL,
    "warn_lead_days" integer DEFAULT 3 NOT NULL,
    "last_warned_at" timestamp with time zone,
    "last_rescue_at" timestamp with time zone,
    "last_rescue_execution_id" "uuid",
    "rescue_count" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "sim_line_rescue_policy_lead_days_check" CHECK ((("lead_days" >= 1) AND ("lead_days" <= 14))),
    CONSTRAINT "sim_line_rescue_policy_max_usd_check" CHECK ((("max_usd" >= (0)::numeric) AND ("max_usd" <= (500)::numeric))),
    CONSTRAINT "sim_line_rescue_policy_warn_lead_days_check" CHECK ((("warn_lead_days" >= 1) AND ("warn_lead_days" <= 30)))
);

ALTER TABLE public."sim_line_usage_forecast" ADD CONSTRAINT "sim_line_usage_forecast_pkey" PRIMARY KEY (id);

ALTER TABLE public."sim_line_rescue_policy" ADD CONSTRAINT "sim_line_rescue_policy_pkey" PRIMARY KEY (sim_line_id);

ALTER TABLE public."household_members" ADD CONSTRAINT "household_members_pkey" PRIMARY KEY (id);

ALTER TABLE public."esim_orders" ADD CONSTRAINT "esim_orders_pkey" PRIMARY KEY (id);

ALTER TABLE public."user_esims" ADD CONSTRAINT "user_esims_pkey" PRIMARY KEY (id);

ALTER TABLE public."esim_offers_cache" ADD CONSTRAINT "esim_offers_cache_pkey" PRIMARY KEY (provider, bundle_name);

ALTER TABLE public."esim_usage_samples" ADD CONSTRAINT "esim_usage_samples_pkey" PRIMARY KEY (esim_id, sampled_on);

ALTER TABLE public."household_members" ADD CONSTRAINT "household_members_owner_id_member_email_key" UNIQUE (owner_id, member_email);

ALTER TABLE public."user_esims" ADD CONSTRAINT "user_esims_iccid_key" UNIQUE (iccid);

ALTER TABLE public."sim_line_usage_forecast" ADD CONSTRAINT "sim_line_usage_forecast_esim_id_fkey" FOREIGN KEY (esim_id) REFERENCES user_esims(id) ON DELETE CASCADE;

ALTER TABLE public."sim_line_usage_forecast" ADD CONSTRAINT "sim_line_usage_forecast_sim_line_id_fkey" FOREIGN KEY (sim_line_id) REFERENCES sim_lines(id) ON DELETE CASCADE;

ALTER TABLE public."sim_line_usage_forecast" ADD CONSTRAINT "sim_line_usage_forecast_user_id_fkey" FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE public."sim_line_rescue_policy" ADD CONSTRAINT "sim_line_rescue_policy_last_rescue_execution_id_fkey" FOREIGN KEY (last_rescue_execution_id) REFERENCES topup_executions(id) ON DELETE SET NULL;

ALTER TABLE public."sim_line_rescue_policy" ADD CONSTRAINT "sim_line_rescue_policy_sim_line_id_fkey" FOREIGN KEY (sim_line_id) REFERENCES sim_lines(id) ON DELETE CASCADE;

ALTER TABLE public."sim_line_rescue_policy" ADD CONSTRAINT "sim_line_rescue_policy_user_id_fkey" FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE public."household_members" ADD CONSTRAINT "household_members_cap_updated_by_fkey" FOREIGN KEY (cap_updated_by) REFERENCES profiles(id) ON DELETE SET NULL;

ALTER TABLE public."household_members" ADD CONSTRAINT "household_members_member_id_fkey" FOREIGN KEY (member_id) REFERENCES profiles(id) ON DELETE SET NULL;

ALTER TABLE public."household_members" ADD CONSTRAINT "household_members_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE public."esim_orders" ADD CONSTRAINT "esim_orders_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public."user_esims" ADD CONSTRAINT "user_esims_order_id_fkey" FOREIGN KEY (order_id) REFERENCES esim_orders(id) ON DELETE CASCADE;

ALTER TABLE public."user_esims" ADD CONSTRAINT "user_esims_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public."esim_usage_samples" ADD CONSTRAINT "esim_usage_samples_esim_id_fkey" FOREIGN KEY (esim_id) REFERENCES user_esims(id) ON DELETE CASCADE;

CREATE UNIQUE INDEX sim_line_usage_forecast_line_uq ON public.sim_line_usage_forecast USING btree (sim_line_id) WHERE (sim_line_id IS NOT NULL);

CREATE UNIQUE INDEX sim_line_usage_forecast_esim_uq ON public.sim_line_usage_forecast USING btree (esim_id) WHERE (esim_id IS NOT NULL);

CREATE INDEX sim_line_usage_forecast_user_idx ON public.sim_line_usage_forecast USING btree (user_id);

CREATE INDEX sim_line_usage_forecast_due_idx ON public.sim_line_usage_forecast USING btree (predicted_depletion_at) WHERE (predicted_depletion_at IS NOT NULL);

CREATE INDEX sim_line_rescue_policy_armed_idx ON public.sim_line_rescue_policy USING btree (user_id) WHERE (max_usd > (0)::numeric);

CREATE INDEX idx_household_members_owner_id ON public.household_members USING btree (owner_id);

CREATE INDEX idx_household_members_member_id ON public.household_members USING btree (member_id);

CREATE INDEX idx_user_esims_user_id ON public.user_esims USING btree (user_id);

CREATE INDEX idx_esim_offers_cache_provider ON public.esim_offers_cache USING btree (provider);

CREATE INDEX idx_esim_offers_cache_active ON public.esim_offers_cache USING btree (is_active);

CREATE INDEX idx_esim_offers_cache_countries ON public.esim_offers_cache USING gin (countries);

CREATE INDEX idx_esim_offers_cache_roaming ON public.esim_offers_cache USING gin (roaming_enabled);

CREATE INDEX idx_esim_offers_cache_active_price ON public.esim_offers_cache USING btree (is_active, wholesale_price_usd);

CREATE OR REPLACE FUNCTION "public"."compute_usage_forecasts"() RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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
$$;

REVOKE ALL ON FUNCTION public."compute_usage_forecasts"() FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public."compute_usage_forecasts"() TO service_role;

CREATE OR REPLACE FUNCTION "public"."refresh_usage_forecasts"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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
$$;

REVOKE ALL ON FUNCTION public."refresh_usage_forecasts"() FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public."refresh_usage_forecasts"() TO service_role;

CREATE OR REPLACE FUNCTION "public"."snapshot_esim_usage"() RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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
$$;

REVOKE ALL ON FUNCTION public."snapshot_esim_usage"() FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public."snapshot_esim_usage"() TO service_role;

CREATE OR REPLACE FUNCTION "public"."emit_forecast_depletion_alerts"() RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
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
$_$;

REVOKE ALL ON FUNCTION public."emit_forecast_depletion_alerts"() FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public."emit_forecast_depletion_alerts"() TO service_role;

CREATE OR REPLACE FUNCTION "public"."refill_interval_days"("p_inactivity_limit_days" integer, "p_override" integer DEFAULT NULL::integer) RETURNS integer
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO ''
    AS $$
  SELECT CASE
    WHEN p_override IS NOT NULL AND p_override > 0 THEN LEAST(365, p_override)
    WHEN p_inactivity_limit_days IS NULL OR p_inactivity_limit_days < 1 THEN NULL
    ELSE GREATEST(1, LEAST(365,
      p_inactivity_limit_days - GREATEST(7, ceil(p_inactivity_limit_days * 0.15)::integer)))
  END;
$$;

REVOKE ALL ON FUNCTION public."refill_interval_days"(integer, integer) FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public."refill_interval_days"(integer, integer) TO anon;

GRANT EXECUTE ON FUNCTION public."refill_interval_days"(integer, integer) TO authenticated;

GRANT EXECUTE ON FUNCTION public."refill_interval_days"(integer, integer) TO service_role;

CREATE OR REPLACE FUNCTION "public"."record_manual_external_recharge"("p_sim_line_id" "uuid", "p_recharge_date" timestamp with time zone DEFAULT "now"(), "p_amount" numeric DEFAULT NULL::numeric, "p_note" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_line RECORD;
  v_user_id uuid;
  v_log_id uuid;
  v_description text;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = 'KS401';
  END IF;

  SELECT * INTO v_line
  FROM public.sim_lines
  WHERE id = p_sim_line_id
    AND (user_id = v_user_id
         OR EXISTS (
           SELECT 1 FROM public.household_members hm
           WHERE hm.owner_id = sim_lines.user_id
             AND hm.member_id = v_user_id
             AND hm.invite_status = 'accepted'
             AND hm.role = 'manager'
         ));

  IF NOT FOUND THEN
    RAISE EXCEPTION 'SIM line not found or unauthorized' USING ERRCODE = 'KS404';
  END IF;

  v_description := COALESCE(NULLIF(btrim(p_note), ''), 'Manual external recharge logged');

  -- 1. Insert activity log entry for audit and UI trail
  INSERT INTO public.line_activity_log (
    sim_line_id,
    user_id,
    event_type,
    description,
    metadata,
    created_at
  ) VALUES (
    p_sim_line_id,
    v_user_id,
    'validity_extended',
    v_description,
    jsonb_build_object(
      'recharge_date', p_recharge_date,
      'amount', p_amount,
      'note', p_note,
      'source', 'external'
    ),
    now()
  )
  RETURNING id INTO v_log_id;

  -- 2. Explicitly update sim_lines last_topup_at (triggers trg_update_line_health)
  UPDATE public.sim_lines
  SET last_topup_at = p_recharge_date,
      updated_at = now()
  WHERE id = p_sim_line_id;

  -- 3. Clear any pending auto-rescue warning clock
  UPDATE public.sim_line_rescue_policy
  SET last_warned_at = NULL
  WHERE sim_line_id = p_sim_line_id;

  -- 4. Recompute usage forecast asynchronously / best-effort
  BEGIN
    PERFORM public.compute_usage_forecasts();
  EXCEPTION WHEN OTHERS THEN
    -- Best effort, do not block
  END;

  RETURN jsonb_build_object(
    'success', true,
    'activity_id', v_log_id,
    'sim_line_id', p_sim_line_id,
    'last_topup_at', p_recharge_date
  );
END;
$$;

REVOKE ALL ON FUNCTION public."record_manual_external_recharge"(uuid, timestamp with time zone, numeric, text) FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public."record_manual_external_recharge"(uuid, timestamp with time zone, numeric, text) TO authenticated;

GRANT EXECUTE ON FUNCTION public."record_manual_external_recharge"(uuid, timestamp with time zone, numeric, text) TO service_role;

SET check_function_bodies=true;
