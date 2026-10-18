-- Correct carrier activity semantics and make the 48-hour event atomic.
-- The scheduler remains paused until dispatch and UI verification completes.

CREATE OR REPLACE FUNCTION public.calculate_sim_line_alert_clock(
  p_sim_line_id UUID,
  p_now TIMESTAMPTZ DEFAULT now()
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_line RECORD;
  v_carrier RECORD;
  v_rule RECORD;
  v_exec RECORD;
  v_usage RECORD;
  v_stale_limit_days INT := 180;
  
  v_state TEXT;
  v_reason TEXT := NULL;
  v_activity_type TEXT := NULL;
  v_activity_at TIMESTAMPTZ := NULL;
  v_activity_amount NUMERIC := NULL;
  v_cutoff_at TIMESTAMPTZ := NULL;
  v_hours_remaining NUMERIC := NULL;
  v_is_within_48h BOOLEAN := false;
  v_precision TEXT := 'date';
  v_cycle_token TEXT := NULL;
  v_prev_alert_emitted_at TIMESTAMPTZ := NULL;
  v_prev_cycle_token TEXT := NULL;
BEGIN
  -- Read stale limit config
  SELECT COALESCE(NULLIF(config_value, '')::integer, 180) INTO v_stale_limit_days
  FROM public.system_configs WHERE config_key = 'ALERT_CLOCK_STALE_RULE_DAYS';

  -- 1. Fetch SIM Line
  SELECT * INTO v_line FROM public.sim_lines WHERE id = p_sim_line_id;
  IF v_line.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'SIM line not found');
  END IF;

  -- Check existing clock state to preserve emission history if in same cycle
  SELECT alert_cycle_token, alert_emitted_at 
  INTO v_prev_cycle_token, v_prev_alert_emitted_at
  FROM public.sim_line_alert_clock_states
  WHERE sim_line_id = p_sim_line_id;

  -- 2. State checks on line status
  IF v_line.status <> 'active' THEN
    v_state := 'inactive_line';
    v_reason := 'SIM line is currently ' || COALESCE(v_line.status, 'inactive');
  ELSIF v_line.carrier_status IN ('deactivated', 'terminated', 'blocked') THEN
    v_state := 'carrier_deactivated';
    v_reason := 'Carrier reported this line as ' || v_line.carrier_status;
  END IF;

  -- 3. Fetch Carrier and Carrier Rule
  SELECT * INTO v_carrier FROM public.carriers WHERE id = v_line.carrier_id;

  SELECT * INTO v_rule 
  FROM public.carrier_rules 
  WHERE id = v_line.carrier_rule_id
     OR (v_line.carrier_rule_id IS NULL AND carrier_id = v_line.carrier_id)
  ORDER BY (id = v_line.carrier_rule_id) DESC NULLS LAST, updated_at DESC NULLS LAST
  LIMIT 1;

  IF v_state IS NULL THEN
    IF v_rule.id IS NULL OR v_rule.inactivity_limit_days IS NULL OR v_rule.inactivity_limit_days <= 0 THEN
      v_state := 'missing_rule';
      v_reason := 'No verified carrier deactivation rule found for this network';
    ELSIF v_rule.last_verified_at IS NULL OR v_rule.last_verified_at < (p_now - make_interval(days => v_stale_limit_days)) THEN
      v_state := 'stale_rule';
      v_reason := 'Carrier deactivation policy requires re-verification by KeepSIMs operators';
    END IF;
  END IF;

  -- 4. Evaluate Qualifying Activity based on rule semantics
  IF v_state IS NULL THEN
    -- Check for latest confirmed automated topup execution
    SELECT * INTO v_exec
    FROM public.topup_executions
    WHERE sim_line_id = p_sim_line_id
      AND status IN ('success', 'completed')
      AND COALESCE(completed_at, executed_at, created_at) <= p_now
    ORDER BY COALESCE(completed_at, executed_at, created_at) DESC
    LIMIT 1;

    IF v_rule.activity_requirement = 'usage_required' THEN
      -- The current activity log has no carrier-confirmed call/SMS/data events.
      -- A liveness ping proves only that the SIM responds, not qualifying usage.
      v_state := 'needs_qualifying_usage';
      v_reason := 'Carrier requires confirmed outgoing call, SMS, or cellular data activity; no verified usage event is available.';
    ELSIF v_rule.activity_requirement = 'min_denomination' THEN
      -- Must meet threshold
      DECLARE
        v_min_threshold NUMERIC := COALESCE(v_rule.validity_qualifying_topup_amount, v_rule.minimum_topup_amount, 0);
      BEGIN
        SELECT * INTO v_exec
        FROM public.topup_executions
        WHERE sim_line_id = p_sim_line_id
          AND status = 'success'
          AND currency = 'USD'
          AND amount >= v_min_threshold
          AND COALESCE(completed_at, executed_at, created_at) <= p_now
        ORDER BY COALESCE(completed_at, executed_at, created_at) DESC
        LIMIT 1;

        IF v_exec.id IS NOT NULL THEN
          v_activity_type := 'confirmed_topup';
          v_activity_at := COALESCE(v_exec.completed_at, v_exec.executed_at, v_exec.created_at);
          v_activity_amount := v_exec.amount;
          v_precision := 'timestamp';
        ELSIF v_line.last_topup_at IS NOT NULL THEN
          -- Check if manual recharge has logged amount in activity log
          SELECT (metadata->>'amount')::numeric INTO v_activity_amount
          FROM public.line_activity_log
          WHERE sim_line_id = p_sim_line_id
            AND event_type = 'validity_extended'
            AND (metadata->>'recharge_date')::timestamptz = v_line.last_topup_at
          ORDER BY created_at DESC
          LIMIT 1;

          IF v_activity_amount IS NOT NULL AND v_activity_amount >= v_min_threshold THEN
            v_activity_type := 'manual_topup';
            v_activity_at := v_line.last_topup_at;
            v_precision := 'date';
          ELSIF v_activity_amount IS NULL THEN
            v_state := 'needs_amount';
            v_reason := 'Carrier requires top-up of at least $' || v_min_threshold || '. Please confirm the amount of your recharge.';
          ELSE
            v_state := 'needs_amount';
            v_reason := 'Last top-up of $' || v_activity_amount || ' is below the carrier threshold of $' || v_min_threshold || '.';
          END IF;
        ELSE
          v_state := 'needs_activity_date';
          v_reason := 'No qualifying recharge recorded for this line';
        END IF;
      END;

    ELSE
      -- recharge_ok (default)
      IF v_exec.id IS NOT NULL AND (v_line.last_topup_at IS NULL OR COALESCE(v_exec.completed_at, v_exec.executed_at) >= v_line.last_topup_at) THEN
        v_activity_type := 'confirmed_topup';
        v_activity_at := COALESCE(v_exec.completed_at, v_exec.executed_at, v_exec.created_at);
        v_activity_amount := v_exec.amount;
        v_precision := 'timestamp';
      ELSIF v_line.last_topup_at IS NOT NULL THEN
        -- Timestamp sanity check
        IF v_line.last_topup_at > (p_now + interval '1 day') THEN
          v_state := 'needs_activity_date';
          v_reason := 'Recorded recharge date is in the future. Please update to a valid date.';
        ELSIF v_line.last_topup_at < (p_now - interval '730 days') THEN
          v_state := 'needs_activity_date';
          v_reason := 'Recorded recharge date is over 2 years old. Please record your latest recharge.';
        ELSE
          v_activity_type := 'manual_topup';
          v_activity_at := v_line.last_topup_at;
          v_precision := 'date';
        END IF;
      ELSE
        v_state := 'needs_activity_date';
        v_reason := 'No recharge date recorded. Self-report your last recharge date to activate the Alert Clock.';
      END IF;
    END IF;
  END IF;

  -- 5. Final Calculation for Eligible State
  IF v_state IS NULL AND v_activity_at IS NOT NULL THEN
    v_state := 'eligible';
    -- NEVER add grace_period_days to deactivation cutoff!
    IF v_precision = 'date' THEN
      -- Keep a day-resolution UTC comparison instant only for scheduling.
      -- The app must display a date estimate, never this invented hour.
      v_cutoff_at := ((v_activity_at AT TIME ZONE 'UTC')::date
        + v_rule.inactivity_limit_days)::timestamp AT TIME ZONE 'UTC';
    ELSE
      v_cutoff_at := v_activity_at + (v_rule.inactivity_limit_days || ' days')::interval;
    END IF;
    v_hours_remaining := round((extract(epoch from (v_cutoff_at - p_now)) / 3600.0)::numeric, 1);
    
    -- Within 48h boundary
    v_is_within_48h := (v_hours_remaining <= 48.0 AND v_hours_remaining > 0.0);
    
    -- Unique token for this activity cycle
    v_cycle_token := md5(
      p_sim_line_id::text || ':' || 
      v_activity_at::text || ':' || 
      COALESCE(v_rule.id::text, '') || ':' || 
      COALESCE(v_rule.inactivity_limit_days::text, '') || ':' ||
      COALESCE(v_rule.activity_requirement, '') || ':' ||
      COALESCE(v_rule.validity_qualifying_topup_amount::text, '')
    );

    -- If cycle token changed from previous cycle, reset alert emission
    IF v_prev_cycle_token IS DISTINCT FROM v_cycle_token THEN
      v_prev_alert_emitted_at := NULL;
    END IF;
  ELSE
    v_cutoff_at := NULL;
    v_hours_remaining := NULL;
    v_is_within_48h := false;
    v_cycle_token := NULL;
    v_prev_alert_emitted_at := NULL;
  END IF;

  -- 6. Upsert into public.sim_line_alert_clock_states
  INSERT INTO public.sim_line_alert_clock_states (
    sim_line_id,
    user_id,
    carrier_id,
    carrier_rule_id,
    carrier_name,
    activity_requirement,
    inactivity_limit_days,
    qualifying_activity_type,
    qualifying_activity_at,
    qualifying_activity_amount,
    deactivation_cutoff_at,
    precision,
    state,
    ineligibility_reason,
    hours_remaining,
    is_within_48h,
    rule_source_url,
    rule_last_verified_at,
    alert_cycle_token,
    alert_emitted_at,
    evaluated_at,
    updated_at
  ) VALUES (
    v_line.id,
    v_line.user_id,
    v_line.carrier_id,
    v_rule.id,
    v_carrier.name,
    COALESCE(v_rule.activity_requirement, 'recharge_ok'),
    v_rule.inactivity_limit_days,
    v_activity_type,
    v_activity_at,
    v_activity_amount,
    v_cutoff_at,
    v_precision,
    v_state,
    v_reason,
    v_hours_remaining,
    v_is_within_48h,
    v_rule.rule_source_url,
    v_rule.last_verified_at,
    v_cycle_token,
    v_prev_alert_emitted_at,
    p_now,
    now()
  )
  ON CONFLICT (sim_line_id) DO UPDATE SET
    user_id = EXCLUDED.user_id,
    carrier_id = EXCLUDED.carrier_id,
    carrier_rule_id = EXCLUDED.carrier_rule_id,
    carrier_name = EXCLUDED.carrier_name,
    activity_requirement = EXCLUDED.activity_requirement,
    inactivity_limit_days = EXCLUDED.inactivity_limit_days,
    qualifying_activity_type = EXCLUDED.qualifying_activity_type,
    qualifying_activity_at = EXCLUDED.qualifying_activity_at,
    qualifying_activity_amount = EXCLUDED.qualifying_activity_amount,
    deactivation_cutoff_at = EXCLUDED.deactivation_cutoff_at,
    precision = EXCLUDED.precision,
    state = EXCLUDED.state,
    ineligibility_reason = EXCLUDED.ineligibility_reason,
    hours_remaining = EXCLUDED.hours_remaining,
    is_within_48h = EXCLUDED.is_within_48h,
    rule_source_url = EXCLUDED.rule_source_url,
    rule_last_verified_at = EXCLUDED.rule_last_verified_at,
    alert_cycle_token = EXCLUDED.alert_cycle_token,
    alert_emitted_at = EXCLUDED.alert_emitted_at,
    evaluated_at = EXCLUDED.evaluated_at,
    updated_at = now();

  RETURN jsonb_build_object(
    'sim_line_id', v_line.id,
    'carrier_name', v_carrier.name,
    'state', v_state,
    'is_eligible', (v_state = 'eligible'),
    'ineligibility_reason', v_reason,
    'activity_requirement', COALESCE(v_rule.activity_requirement, 'recharge_ok'),
    'inactivity_limit_days', v_rule.inactivity_limit_days,
    'qualifying_activity_type', v_activity_type,
    'qualifying_activity_at', v_activity_at,
    'deactivation_cutoff_at', v_cutoff_at,
    'hours_remaining', v_hours_remaining,
    'is_within_48h', v_is_within_48h,
    'precision', v_precision,
    'rule_source_url', v_rule.rule_source_url,
    'rule_last_verified_at', v_rule.last_verified_at,
    'evaluated_at', p_now
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.emit_urgent_deactivation_alerts(
  p_dry_run BOOLEAN DEFAULT false,
  p_now TIMESTAMPTZ DEFAULT now()
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_is_enabled BOOLEAN := false;
  v_candidate RECORD;
  v_emitted_count INT := 0;
  v_candidates_list jsonb := '[]'::jsonb;
  v_event_key TEXT;
  v_line_label TEXT;
  v_user_lang TEXT;
  v_title TEXT;
  v_body TEXT;
  v_inserted_id uuid;
BEGIN
  -- 1. Check global feature switch
  SELECT (config_value = 'true') INTO v_is_enabled
  FROM public.system_configs
  WHERE config_key = 'ALERT_CLOCK_SCHEDULER_ENABLED';

  IF NOT COALESCE(v_is_enabled, false) AND NOT p_dry_run THEN
    RETURN jsonb_build_object(
      'success', true,
      'scheduler_enabled', false,
      'emitted_count', 0,
      'message', 'ALERT_CLOCK_SCHEDULER_ENABLED is false; emission withheld'
    );
  END IF;

  -- 2. First refresh all active line clock states to ensure real-time evaluation
  PERFORM public.sync_all_sim_line_alert_clocks(p_now);

  -- 3. Loop over candidates currently in 48-hour window
  FOR v_candidate IN
    SELECT 
      cs.*,
      sl.phone_number,
      sl.nickname,
      up.language AS user_language
    FROM public.sim_line_alert_clock_states cs
    JOIN public.sim_lines sl ON sl.id = cs.sim_line_id
    LEFT JOIN public.user_preferences up ON up.user_id = cs.user_id
    WHERE cs.state = 'eligible'
      AND cs.is_within_48h = true
      AND cs.alert_cycle_token IS NOT NULL
      AND cs.alert_emitted_at IS NULL
      AND sl.status = 'active'
      AND COALESCE(sl.protection_paused, false) = false
  LOOP
    v_event_key := 'deactivation_48h:' || v_candidate.sim_line_id || ':' || v_candidate.alert_cycle_token;

    -- Idempotency check: has this specific event key already been inserted into notifications?
    IF NOT EXISTS (
      SELECT 1 FROM public.notifications 
      WHERE source_event_key = v_event_key
    ) THEN
      -- Prepare label & language
      v_user_lang := COALESCE(v_candidate.user_language, 'en');
      v_line_label := CASE 
        WHEN NULLIF(btrim(COALESCE(v_candidate.nickname, '')), '') IS NOT NULL 
          THEN btrim(v_candidate.nickname) || ' · ' || right(regexp_replace(v_candidate.phone_number, '\D', '', 'g'), 4)
        ELSE 'Line ending ' || right(regexp_replace(v_candidate.phone_number, '\D', '', 'g'), 4)
      END;

      IF v_user_lang LIKE 'ar%' THEN
        v_title := '⚠️ تحذير: الخط معرض للإلغاء خلال 48 ساعة';
        v_body := 'الرقم ' || v_line_label || ' قارب على مهلة الإلغاء المقدرة بحوالي يومين (' || 
                  to_char(v_candidate.deactivation_cutoff_at, 'YYYY-MM-DD') || 
                  '). يرجى اتخاذ الإجراء اللازم فوراً للحفاظ على صلاحية الرقم.';
      ELSE
        v_title := '⚠️ Deactivation Imminent: About 48h Remaining';
        v_body := v_line_label || ' is within approximately 2 days of carrier deactivation cutoff (' || 
                  to_char(v_candidate.deactivation_cutoff_at, 'YYYY-MM-DD') || 
                  '). Take action now to keep your line active.';
      END IF;

      v_candidates_list := v_candidates_list || jsonb_build_object(
        'sim_line_id', v_candidate.sim_line_id,
        'phone_number', v_candidate.phone_number,
        'carrier_name', v_candidate.carrier_name,
        'hours_remaining', v_candidate.hours_remaining,
        'deactivation_cutoff_at', v_candidate.deactivation_cutoff_at,
        'event_key', v_event_key
      );

      IF NOT p_dry_run THEN
        -- Insert logical alert event
        INSERT INTO public.notifications (
          user_id,
          category,
          title,
          body,
          action_url,
          sim_line_id,
          delivered_via,
          is_read,
          schema_version,
          event_type,
          source_event_key,
          occurred_at,
          template_version,
          template_data,
          target,
          created_at
        ) VALUES (
          v_candidate.user_id,
          'line_critical',
          v_title,
          v_body,
          '/sim-lines/detail/' || v_candidate.sim_line_id,
          v_candidate.sim_line_id,
          ARRAY[]::text[], -- Will be populated truthfully by dispatcher upon attempt outcomes!
          false,
          2,
          'line_deactivation_imminent',
          v_event_key,
          p_now,
          1,
          jsonb_build_object(
            'line', v_line_label,
            'carrier_name', v_candidate.carrier_name,
            'hours_remaining', v_candidate.hours_remaining,
            'cutoff_at', v_candidate.deactivation_cutoff_at,
            'activity_requirement', v_candidate.activity_requirement
          ),
          jsonb_build_object('route', '/sim-lines/detail/:id', 'id', v_candidate.sim_line_id),
          p_now
        )
        ON CONFLICT DO NOTHING
        RETURNING id INTO v_inserted_id;

        IF v_inserted_id IS NULL THEN
          -- Another scheduler run already inserted this logical event.
          UPDATE public.sim_line_alert_clock_states
          SET alert_emitted_at = p_now, updated_at = now()
          WHERE sim_line_id = v_candidate.sim_line_id;
          CONTINUE;
        END IF;

        -- Mark alert emitted for this cycle token on state table
        UPDATE public.sim_line_alert_clock_states
        SET alert_emitted_at = p_now,
            updated_at = now()
        WHERE sim_line_id = v_candidate.sim_line_id;

        v_emitted_count := v_emitted_count + 1;
      END IF;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'dry_run', p_dry_run,
    'candidates_count', jsonb_array_length(v_candidates_list),
    'emitted_count', v_emitted_count,
    'candidates', v_candidates_list,
    'evaluated_at', p_now
  );
END;
$$;
