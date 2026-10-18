BEGIN;

-- Preserve the physical fit and allowed method labels. A missing recharge
-- anchor stays unknown; grace never extends the carrier inactivity deadline.
CREATE OR REPLACE FUNCTION public.compute_usage_forecasts_internal()
RETURNS integer LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE
  v_default_validity integer;
  v_lead_days        integer;
  v_min_cycle        integer;
  v_rows             integer := 0;
  v_n                integer;
BEGIN
  -- Owner-only invoker core also serves the existing owner/manager-checked
  -- manual recharge definer. API clients cannot execute it or elevate here.
  IF current_user<>'postgres' THEN
    RAISE EXCEPTION 'Forecast owner execution required' USING ERRCODE='42501';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('keepsims:usage-forecasts',0));
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
               THEN c.inactivity_limit_days
             WHEN c.carrier_cycle_days IS NOT NULL
               THEN c.carrier_cycle_days
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

  -- eSIM metadata is optional evidence, never a fabricated 30-day bundle.
  -- Isolate unexpected eSIM errors so valid physical forecasts survive.
  BEGIN
    WITH readings AS (
      SELECT s.*,lag(s.data_remaining_mb) OVER w AS previous_mb,
        lag(s.data_total_mb) OVER w AS previous_total
      FROM public.esim_usage_samples s JOIN public.user_esims e ON e.id=s.esim_id
      WHERE s.sampled_on BETWEEN (now() AT TIME ZONE 'UTC')::date-30 AND (now() AT TIME ZONE 'UTC')::date
        AND s.sampled_on >= (e.purchased_at AT TIME ZONE 'UTC')::date
        AND s.sampled_on <= (e.last_usage_check AT TIME ZONE 'UTC')::date
        AND s.data_total_mb>0 AND s.data_remaining_mb BETWEEN 0 AND s.data_total_mb
      WINDOW w AS (PARTITION BY s.esim_id ORDER BY s.sampled_on)
    ), resets AS (
      SELECT r.*,max(sampled_on) FILTER (WHERE data_remaining_mb>previous_mb OR data_total_mb<>previous_total)
        OVER (PARTITION BY esim_id) AS reset_on
      FROM readings r
    ), fitted AS (
      SELECT r.esim_id,count(*)::integer AS n,min(sampled_on) AS first_on,max(sampled_on) AS last_on,
        (array_agg(r.data_remaining_mb ORDER BY sampled_on))[1]::numeric AS first_mb,
        (array_agg(r.data_remaining_mb ORDER BY sampled_on DESC))[1]::numeric AS last_mb
      FROM resets r JOIN public.user_esims e ON e.id=r.esim_id
      WHERE (r.reset_on IS NULL OR r.sampled_on>=r.reset_on) AND r.data_total_mb=e.data_total_mb
      GROUP BY r.esim_id
    ), current_esim AS (
      SELECT e.*,f.n,
        -- Fit only a bounded, decreasing segment with a real current reading.
        CASE WHEN e.data_total_mb>0 AND e.data_remaining_mb BETWEEN 0 AND e.data_total_mb
          AND NOT coalesce(c.is_unlimited,false) AND e.last_usage_check<=now()
          AND e.last_usage_check>=now()-interval '30 days'
          AND f.last_on>f.first_on AND f.first_mb>f.last_mb
          AND e.data_remaining_mb<=f.last_mb
          AND round((f.first_mb-f.last_mb)/(f.last_on-f.first_on),2) BETWEEN 0.01 AND 9999999999.99
          THEN round((f.first_mb-f.last_mb)/(f.last_on-f.first_on),2) END AS rate,
        -- Catalogue duration is advisory. It never creates an expiry instant.
        CASE WHEN c.duration_days>0 THEN c.duration_days END AS duration_days,
        CASE WHEN o.retail_price_usd>=0 AND o.retail_price_usd::text NOT IN ('NaN','Infinity','-Infinity')
          THEN o.retail_price_usd END AS retail_unit_price,
        CASE WHEN length(nullif(btrim(o.offer_id),''))<=120 THEN o.offer_id END AS offer_id
      FROM public.user_esims e
      LEFT JOIN fitted f ON f.esim_id=e.id
      LEFT JOIN public.esim_orders o ON o.id=e.order_id AND o.user_id=e.user_id
        AND o.provider=e.provider AND o.bundle_name=e.bundle_name AND o.status='completed'
      LEFT JOIN public.esim_offers_cache c ON c.provider=e.provider AND c.bundle_name=e.bundle_name
      WHERE e.status IN ('active','installed') AND e.user_id IS NOT NULL
        AND EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=e.user_id)
        AND (e.expires_at IS NULL OR (isfinite(e.expires_at) AND e.expires_at>now()))
    ), projected AS (
      SELECT c.*,
        -- Reject absurd horizons instead of overflowing dates or integer fields.
        CASE WHEN rate>0 AND data_remaining_mb/rate BETWEEN 0 AND 36500
          THEN last_usage_check + (data_remaining_mb/rate)*interval '1 day' END AS usage_depletion
      FROM current_esim c
    ), dated AS (
      SELECT p.*,least(usage_depletion,expires_at) AS depletion_at FROM projected p
    )
    INSERT INTO public.sim_line_usage_forecast AS t(user_id,esim_id,subject_kind,method,confidence,samples_count,
      mb_per_day,effective_validity_days,predicted_depletion_at,days_remaining,
      suggested_frequency_days,suggested_amount_usd,suggested_offer_id,alert_lead_days,computed_at)
    SELECT user_id,id,'esim',CASE WHEN usage_depletion IS NOT NULL THEN 'esim_usage' ELSE 'default' END,
      CASE WHEN usage_depletion IS NULL THEN 'low' WHEN n>=7 THEN 'high' WHEN n>=3 THEN 'medium' ELSE 'low' END,
      coalesce(n,0),rate,duration_days,depletion_at,
      CASE WHEN depletion_at IS NOT NULL THEN greatest(0,ceil(extract(epoch FROM (depletion_at-now()))/86400))::integer END,
      duration_days,retail_unit_price,offer_id,v_lead_days,now()
    FROM dated
    ON CONFLICT (esim_id) WHERE esim_id IS NOT NULL DO UPDATE SET
      user_id=excluded.user_id,method=excluded.method,confidence=excluded.confidence,samples_count=excluded.samples_count,
      mb_per_day=excluded.mb_per_day,effective_validity_days=excluded.effective_validity_days,
      predicted_depletion_at=excluded.predicted_depletion_at,days_remaining=excluded.days_remaining,
      suggested_frequency_days=excluded.suggested_frequency_days,suggested_amount_usd=excluded.suggested_amount_usd,
      suggested_offer_id=excluded.suggested_offer_id,alert_lead_days=excluded.alert_lead_days,computed_at=excluded.computed_at;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_rows := v_rows + v_n;

    DELETE FROM public.sim_line_usage_forecast f WHERE f.subject_kind='esim' AND NOT EXISTS (
      SELECT 1 FROM public.user_esims e WHERE e.id=f.esim_id AND e.user_id=f.user_id
        AND EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=e.user_id)
        AND e.status IN ('active','installed')
        AND (e.expires_at IS NULL OR (isfinite(e.expires_at) AND e.expires_at>now()))
    );
  EXCEPTION WHEN OTHERS THEN
    -- Invalidate old eSIM predictions when recomputation failed. Preserve the
    -- physical rows, and make the failure visible without raw data in logs.
    UPDATE public.sim_line_usage_forecast SET predicted_depletion_at=NULL,days_remaining=NULL,
      mb_per_day=NULL,method='default',samples_count=0,confidence='low',computed_at=now(),
      effective_validity_days=NULL,suggested_frequency_days=NULL,suggested_amount_usd=NULL,suggested_offer_id=NULL
      WHERE subject_kind='esim';
    RAISE WARNING 'Usage forecast eSIM stage failed (SQLSTATE %)',SQLSTATE;
    BEGIN
      INSERT INTO public.system_alerts(kind,message,details)
      VALUES('usage_forecast_failed','eSIM forecasts could not be computed',jsonb_build_object('stage','esim_compute','sqlstate',SQLSTATE));
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Usage forecast diagnostic could not be persisted (SQLSTATE %)',SQLSTATE;
    END;
  END;
  DELETE FROM public.sim_line_usage_forecast f USING public.sim_lines l
    WHERE f.sim_line_id=l.id AND l.status IS DISTINCT FROM 'active';
  RETURN v_rows;
END;
$$;

CREATE OR REPLACE FUNCTION public.compute_usage_forecasts()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF NOT coalesce((current_setting('role',true)='service_role' AND auth.role()='service_role')
    OR (current_setting('role',true) IN ('none','postgres') AND session_user='postgres'),false) THEN
    RAISE EXCEPTION 'Trusted forecast role required' USING ERRCODE='42501';
  END IF;
  RETURN public.compute_usage_forecasts_internal();
END;
$$;

CREATE OR REPLACE FUNCTION public.snapshot_esim_usage()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_rows integer;
BEGIN
  IF NOT coalesce((current_setting('role',true)='service_role' AND auth.role()='service_role')
    OR (current_setting('role',true) IN ('none','postgres') AND session_user='postgres'),false) THEN
    RAISE EXCEPTION 'Trusted forecast role required' USING ERRCODE='42501';
  END IF;
  -- A repeated old provider reading is not a new observation each night.
  INSERT INTO public.esim_usage_samples(esim_id,sampled_on,data_remaining_mb,data_total_mb)
  SELECT e.id,(e.last_usage_check AT TIME ZONE 'UTC')::date,e.data_remaining_mb,e.data_total_mb
  FROM public.user_esims e
  WHERE e.status IN ('active','installed') AND e.data_total_mb>0
    AND e.data_remaining_mb BETWEEN 0 AND e.data_total_mb
    AND e.last_usage_check BETWEEN greatest(e.purchased_at,now()-interval '30 days') AND now()
    AND (e.expires_at IS NULL OR (isfinite(e.expires_at) AND e.expires_at>now()))
    AND NOT EXISTS(SELECT 1 FROM public.esim_offers_cache c
      WHERE c.provider=e.provider AND c.bundle_name=e.bundle_name AND c.is_unlimited)
  ON CONFLICT (esim_id,sampled_on) DO UPDATE SET data_remaining_mb=excluded.data_remaining_mb,data_total_mb=excluded.data_total_mb;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  RETURN v_rows;
END;
$$;

CREATE OR REPLACE FUNCTION public.refresh_usage_forecasts()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_samples integer:=0; v_forecasts integer; v_alerts integer:=0;
BEGIN
  IF NOT coalesce((current_setting('role',true)='service_role' AND auth.role()='service_role')
    OR (current_setting('role',true) IN ('none','postgres') AND session_user='postgres'),false) THEN
    RAISE EXCEPTION 'Trusted forecast role required' USING ERRCODE='42501';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('keepsims:usage-forecasts',0));
  BEGIN
    v_samples:=public.snapshot_esim_usage();
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Usage forecast snapshot failed (SQLSTATE %)',SQLSTATE;
    BEGIN
      INSERT INTO public.system_alerts(kind,message,details)
      VALUES('usage_forecast_failed','eSIM usage snapshot could not be recorded',jsonb_build_object('stage','snapshot','sqlstate',SQLSTATE));
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Usage forecast diagnostic could not be persisted (SQLSTATE %)',SQLSTATE;
    END;
  END;
  -- Physical computation failures propagate; eSIM failures are isolated inside.
  v_forecasts:=public.compute_usage_forecasts();
  BEGIN
    v_alerts:=public.emit_forecast_depletion_alerts();
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Usage forecast alerts failed (SQLSTATE %)',SQLSTATE;
    BEGIN
      INSERT INTO public.system_alerts(kind,message,details)
      VALUES('usage_forecast_failed','Forecast alerts could not be queued',jsonb_build_object('stage','alerts','sqlstate',SQLSTATE));
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Usage forecast diagnostic could not be persisted (SQLSTATE %)',SQLSTATE;
    END;
  END;
  RETURN jsonb_build_object('esim_samples',v_samples,'forecasts',v_forecasts,'alerts',v_alerts,'ran_at',now());
END;
$$;

CREATE OR REPLACE FUNCTION public.emit_forecast_depletion_alerts()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r record; v_count integer:=0; v_id uuid;
BEGIN
  IF NOT coalesce((current_setting('role',true)='service_role' AND auth.role()='service_role')
    OR (current_setting('role',true) IN ('none','postgres') AND session_user='postgres'),false) THEN
    RAISE EXCEPTION 'Trusted forecast role required' USING ERRCODE='42501';
  END IF;
  FOR r IN
    SELECT f.*,l.phone_number FROM public.sim_line_usage_forecast f
    JOIN public.sim_lines l ON l.id=f.sim_line_id AND l.user_id=f.user_id
    WHERE f.subject_kind='sim_line' AND l.status='active' AND NOT coalesce(l.protection_paused,false)
      AND f.computed_at>=now()-interval '1 day' AND f.predicted_depletion_at IS NOT NULL
      AND f.predicted_depletion_at<=now()+f.alert_lead_days*interval '1 day'
      AND (f.last_alert_at IS NULL OR f.last_alert_at<now()-f.alert_lead_days*interval '1 day')
      AND NOT EXISTS(SELECT 1 FROM public.scheduled_topups st WHERE st.sim_line_id=f.sim_line_id
        AND st.is_active AND st.status='active' AND st.schedule_type IN ('refill_custom','refill_mini')
        AND st.next_execution_at<=f.predicted_depletion_at)
    FOR UPDATE OF f SKIP LOCKED
  LOOP
    INSERT INTO public.notifications(user_id,sim_line_id,category,title,body,action_url,delivered_via,
      schema_version,event_type,source_event_key,occurred_at,expires_at,template_version,template_data,target)
    VALUES(r.user_id,r.sim_line_id,'line_critical','Recharge forecast needs attention',
      'SIM line ending '||right(regexp_replace(r.phone_number,'[^0-9]','','g'),4)||
      ' may need a recharge soon. Open KeepSIMs to review the forecast.',
      '/sim-lines/detail/'||r.sim_line_id,ARRAY[]::text[],2,'line_critical',
      'forecast-depletion:'||r.id||':'||extract(epoch FROM now()),now(),now()+interval '24 hours',1,
      jsonb_build_object('method',r.method,'confidence',r.confidence,'predicted_depletion_at',r.predicted_depletion_at),
      jsonb_build_object('route','/sim-lines/detail/'||r.sim_line_id,'id',r.sim_line_id)) RETURNING id INTO v_id;
    INSERT INTO public.line_activity_log(sim_line_id,user_id,event_type,description,metadata)
    VALUES(r.sim_line_id,r.user_id,'reminder_sent','Forecast reminder queued',
      jsonb_build_object('notification_id',v_id,'source','forecast','state','queued'));
    UPDATE public.sim_line_usage_forecast SET last_alert_at=now() WHERE id=r.id;
    v_count:=v_count+1;
  END LOOP;
  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.compute_usage_forecasts(),public.refresh_usage_forecasts(),
  public.snapshot_esim_usage(),public.emit_forecast_depletion_alerts() FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.compute_usage_forecasts(),public.refresh_usage_forecasts(),
  public.snapshot_esim_usage(),public.emit_forecast_depletion_alerts() TO postgres,service_role;
REVOKE ALL ON FUNCTION public.compute_usage_forecasts_internal() FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.compute_usage_forecasts_internal() TO postgres;

-- Preserve the checked customer/manual-recharge path without exposing the core.
CREATE OR REPLACE FUNCTION "public"."record_manual_external_recharge"("p_sim_line_id" "uuid", "p_recharge_date" timestamp with time zone DEFAULT "now"(), "p_amount" numeric DEFAULT NULL::numeric, "p_note" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
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
    PERFORM public.compute_usage_forecasts_internal();
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Manual recharge forecast failed (SQLSTATE %)',SQLSTATE;
  END;

  RETURN jsonb_build_object(
    'success', true,
    'activity_id', v_log_id,
    'sim_line_id', p_sim_line_id,
    'last_topup_at', p_recharge_date
  );
END;
$$;
REVOKE ALL ON FUNCTION public.record_manual_external_recharge(uuid,timestamptz,numeric,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.record_manual_external_recharge(uuid,timestamptz,numeric,text) TO authenticated,service_role;

COMMIT;

