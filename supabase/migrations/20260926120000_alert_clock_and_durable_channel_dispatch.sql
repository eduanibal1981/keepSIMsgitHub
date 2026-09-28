-- KeepSIMs Alert Clock & Durable Channel Dispatch
-- Migration: 20260926120000_alert_clock_and_durable_channel_dispatch.sql
-- Description:
-- 1. Updates notification_deliveries check constraint to support honest delivery states:
--    queued, attempting, accepted_by_provider, delivered, unknown, skipped, retrying, failed.
-- 2. Adds telegram_bind_tokens table and secure nonce-based binding RPCs.
-- 3. Creates public.sim_line_alert_clock_states table with auditable carrier semantics.
-- 4. Creates calculate_sim_line_alert_clock() and sync_all_sim_line_alert_clocks().
-- 5. Implements emit_urgent_deactivation_alerts() for 48-hour crossing detection with dry-run support.
-- 6. Integrates alert clock emit into process_due_notifications().
-- 7. Adds admin diagnostics RPCs for Alert Clock oversight and carrier rule quality.

-- ============================================================================
-- 1. NOTIFICATION DELIVERIES STATUS EXPANSION
-- ============================================================================

ALTER TABLE public.notification_deliveries 
  DROP CONSTRAINT IF EXISTS notification_deliveries_status_check;

ALTER TABLE public.notification_deliveries
  ADD CONSTRAINT notification_deliveries_status_check 
  CHECK (status IN (
    'queued',
    'attempting',
    'accepted_by_provider',
    'delivered',
    'unknown',
    'skipped',
    'retrying',
    'failed'
  ));

-- ============================================================================
-- 2. SECURE TELEGRAM BIND TOKENS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.telegram_bind_tokens (
  token TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ NOT NULL,
  used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tg_bind_tokens_user ON public.telegram_bind_tokens(user_id, expires_at);

ALTER TABLE public.telegram_bind_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can create and view their own bind tokens"
  ON public.telegram_bind_tokens
  FOR ALL
  USING (
    (current_setting('request.jwt.claims', true)::jsonb ->> 'role' = 'service_role')
    OR (auth.uid() = user_id)
  )
  WITH CHECK (
    (current_setting('request.jwt.claims', true)::jsonb ->> 'role' = 'service_role')
    OR (auth.uid() = user_id)
  );

-- RPC: Create short-lived Telegram Bind Token (15-minute TTL)
CREATE OR REPLACE FUNCTION public.create_telegram_bind_token()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_uid uuid;
  v_token text;
  v_expires timestamptz;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = 'KS401';
  END IF;

  v_token := encode(gen_random_bytes(16), 'hex');
  v_expires := now() + interval '15 minutes';

  INSERT INTO public.telegram_bind_tokens (token, user_id, expires_at)
  VALUES (v_token, v_uid, v_expires);

  RETURN jsonb_build_object(
    'success', true,
    'token', v_token,
    'expires_at', v_expires,
    'bot_url', 'https://t.me/KeepSIMsBot?start=bind_' || v_token
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_telegram_bind_token() TO authenticated;

-- RPC: Securely bind Telegram chat by Token or Legacy UUID (with validation)
CREATE OR REPLACE FUNCTION public.bind_telegram_bot_token(
  p_token_or_uid text,
  p_chat_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_target_user_id uuid;
  v_token_record RECORD;
BEGIN
  IF p_token_or_uid IS NULL OR btrim(p_token_or_uid) = '' THEN
    RAISE EXCEPTION 'Token is required' USING ERRCODE = 'KS400';
  END IF;

  IF p_chat_id IS NULL OR btrim(p_chat_id) = '' THEN
    RAISE EXCEPTION 'Chat ID is required' USING ERRCODE = 'KS400';
  END IF;

  -- 1. Check if it's a valid unexpired bind token
  SELECT * INTO v_token_record
  FROM public.telegram_bind_tokens
  WHERE token = p_token_or_uid
    AND used_at IS NULL
    AND expires_at > now();

  IF v_token_record.token IS NOT NULL THEN
    v_target_user_id := v_token_record.user_id;

    UPDATE public.telegram_bind_tokens
    SET used_at = now()
    WHERE token = v_token_record.token;
  ELSE
    -- 2. Legacy fallback: check if it's a valid UUID
    IF p_token_or_uid ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
      SELECT id INTO v_target_user_id
      FROM auth.users
      WHERE id = p_token_or_uid::uuid;
    END IF;
  END IF;

  IF v_target_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid or expired bind token. Please click the link from the KeepSIMs app again.'
    );
  END IF;

  -- Upsert into notification_channels
  INSERT INTO public.notification_channels (user_id, channel_type, is_enabled, config)
  VALUES (
    v_target_user_id,
    'telegram',
    true,
    jsonb_build_object('chat_id', btrim(p_chat_id))
  )
  ON CONFLICT (user_id, channel_type) DO UPDATE SET
    is_enabled = true,
    config = jsonb_set(COALESCE(public.notification_channels.config, '{}'::jsonb), '{chat_id}', to_jsonb(btrim(p_chat_id)));

  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_target_user_id,
    'chat_id', btrim(p_chat_id)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.bind_telegram_bot_token(text, text) TO anon, authenticated, service_role;

-- ============================================================================
-- 3. SIM LINE ALERT CLOCK STATES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.sim_line_alert_clock_states (
  sim_line_id UUID PRIMARY KEY REFERENCES public.sim_lines(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  carrier_id UUID REFERENCES public.carriers(id) ON DELETE SET NULL,
  carrier_rule_id UUID REFERENCES public.carrier_rules(id) ON DELETE SET NULL,
  carrier_name TEXT,
  activity_requirement TEXT,
  inactivity_limit_days INTEGER,
  qualifying_activity_type TEXT,
  qualifying_activity_at TIMESTAMPTZ,
  qualifying_activity_amount NUMERIC,
  deactivation_cutoff_at TIMESTAMPTZ,
  precision TEXT NOT NULL DEFAULT 'date' CHECK (precision IN ('date', 'timestamp')),
  state TEXT NOT NULL DEFAULT 'needs_activity_date' CHECK (state IN (
    'eligible',
    'needs_activity_date',
    'needs_qualifying_usage',
    'needs_amount',
    'missing_rule',
    'stale_rule',
    'inactive_line',
    'carrier_deactivated'
  )),
  ineligibility_reason TEXT,
  hours_remaining NUMERIC,
  is_within_48h BOOLEAN NOT NULL DEFAULT false,
  rule_source_url TEXT,
  rule_last_verified_at TIMESTAMPTZ,
  alert_cycle_token TEXT,
  alert_emitted_at TIMESTAMPTZ,
  evaluated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_clock_states_lookup 
  ON public.sim_line_alert_clock_states(state, is_within_48h, alert_emitted_at);

CREATE INDEX IF NOT EXISTS idx_clock_states_user 
  ON public.sim_line_alert_clock_states(user_id);

ALTER TABLE public.sim_line_alert_clock_states ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own sim line alert clock states"
  ON public.sim_line_alert_clock_states
  FOR SELECT
  USING (
    (current_setting('request.jwt.claims', true)::jsonb ->> 'role' = 'service_role')
    OR public.is_power_user(auth.uid())
    OR (auth.uid() = user_id)
    OR EXISTS (
      SELECT 1 FROM public.household_members hm
      WHERE hm.owner_id = sim_line_alert_clock_states.user_id
        AND hm.member_id = auth.uid()
        AND hm.invite_status = 'accepted'
    )
  );

CREATE POLICY "Service role and power users can manage sim line alert clock states"
  ON public.sim_line_alert_clock_states
  FOR ALL
  USING (
    (current_setting('request.jwt.claims', true)::jsonb ->> 'role' = 'service_role')
    OR public.is_power_user(auth.uid())
  )
  WITH CHECK (
    (current_setting('request.jwt.claims', true)::jsonb ->> 'role' = 'service_role')
    OR public.is_power_user(auth.uid())
  );

-- ============================================================================
-- 4. SYSTEM CONFIG SEEDS
-- ============================================================================

INSERT INTO public.system_configs (config_key, config_value)
VALUES 
  ('ALERT_CLOCK_SCHEDULER_ENABLED', 'true'),
  ('ALERT_CLOCK_STALE_RULE_DAYS', '180')
ON CONFLICT (config_key) DO NOTHING;

-- ============================================================================
-- 5. SERVER SOURCE OF TRUTH: calculate_sim_line_alert_clock()
-- ============================================================================

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
      -- Top-up alone does NOT reset the inactivity cliff!
      -- Must have a confirmed network usage event (call, SMS, data, or active liveness verification)
      SELECT * INTO v_usage
      FROM public.line_activity_log
      WHERE sim_line_id = p_sim_line_id
        AND event_type IN ('outgoing_call', 'sms_sent', 'data_session', 'carrier_liveness_check', 'sim_ping_success')
        AND created_at <= p_now
      ORDER BY created_at DESC
      LIMIT 1;

      IF v_usage.id IS NOT NULL THEN
        v_activity_type := 'network_usage';
        v_activity_at := v_usage.created_at;
        v_precision := 'timestamp';
      ELSIF v_line.is_carrier_verified = true AND v_line.carrier_verified_at IS NOT NULL THEN
        v_activity_type := 'carrier_verified_activity';
        v_activity_at := v_line.carrier_verified_at;
        v_precision := 'timestamp';
      ELSE
        v_state := 'needs_qualifying_usage';
        v_reason := 'Carrier requires outgoing calls, SMS, or data usage. Recharges alone do not reset the deactivation timer.';
      END IF;

    ELSIF v_rule.activity_requirement = 'min_denomination' THEN
      -- Must meet threshold
      DECLARE
        v_min_threshold NUMERIC := COALESCE(v_rule.validity_qualifying_topup_amount, v_rule.minimum_topup_amount, 0);
      BEGIN
        IF v_exec.id IS NOT NULL AND v_exec.amount >= v_min_threshold THEN
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
    v_cutoff_at := v_activity_at + (v_rule.inactivity_limit_days || ' days')::interval;
    v_hours_remaining := round((extract(epoch from (v_cutoff_at - p_now)) / 3600.0)::numeric, 1);
    
    -- Within 48h boundary
    v_is_within_48h := (v_hours_remaining <= 48.0 AND v_hours_remaining > 0.0);
    
    -- Unique token for this activity cycle
    v_cycle_token := md5(
      p_sim_line_id::text || ':' || 
      v_activity_at::text || ':' || 
      COALESCE(v_rule.id::text, '') || ':' || 
      COALESCE(v_rule.inactivity_limit_days::text, '')
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

GRANT EXECUTE ON FUNCTION public.calculate_sim_line_alert_clock(uuid, timestamptz) TO authenticated, service_role;

-- ============================================================================
-- 6. BATCH EVALUATION FUNCTION: sync_all_sim_line_alert_clocks()
-- ============================================================================

CREATE OR REPLACE FUNCTION public.sync_all_sim_line_alert_clocks(
  p_now TIMESTAMPTZ DEFAULT now()
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_line RECORD;
  v_total INT := 0;
  v_eligible INT := 0;
  v_within_48h INT := 0;
  v_needs_date INT := 0;
  v_needs_usage INT := 0;
  v_needs_amount INT := 0;
  v_stale_rule INT := 0;
  v_res jsonb;
BEGIN
  FOR v_line IN SELECT id FROM public.sim_lines WHERE status = 'active' LOOP
    v_res := public.calculate_sim_line_alert_clock(v_line.id, p_now);
    v_total := v_total + 1;

    IF (v_res->>'state') = 'eligible' THEN
      v_eligible := v_eligible + 1;
      IF (v_res->>'is_within_48h')::boolean THEN
        v_within_48h := v_within_48h + 1;
      END IF;
    ELSIF (v_res->>'state') = 'needs_activity_date' THEN
      v_needs_date := v_needs_date + 1;
    ELSIF (v_res->>'state') = 'needs_qualifying_usage' THEN
      v_needs_usage := v_needs_usage + 1;
    ELSIF (v_res->>'state') = 'needs_amount' THEN
      v_needs_amount := v_needs_amount + 1;
    ELSIF (v_res->>'state') = 'stale_rule' THEN
      v_stale_rule := v_stale_rule + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'total_active_lines', v_total,
    'eligible_count', v_eligible,
    'within_48h_count', v_within_48h,
    'needs_activity_date_count', v_needs_date,
    'needs_qualifying_usage_count', v_needs_usage,
    'needs_amount_count', v_needs_amount,
    'stale_rule_count', v_stale_rule,
    'evaluated_at', p_now
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sync_all_sim_line_alert_clocks(timestamptz) TO service_role;

-- ============================================================================
-- 7. URGENT 48-HOUR ALERT SCHEDULER: emit_urgent_deactivation_alerts()
-- ============================================================================

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
      AND (cs.alert_emitted_at IS NULL OR cs.alert_cycle_token IS DISTINCT FROM cs.alert_cycle_token)
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
        );

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

GRANT EXECUTE ON FUNCTION public.emit_urgent_deactivation_alerts(boolean, timestamptz) TO service_role;

-- ============================================================================
-- 8. INTEGRATE INTO HOURLY NOTIFICATIONS PROCESSOR
-- ============================================================================

CREATE OR REPLACE FUNCTION public.process_due_notifications()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  r RECORD;
  v_phone_number TEXT;
  v_next_due TIMESTAMPTZ;
BEGIN
  -- A. Process standard notification schedules
  FOR r IN
    SELECT s.id, s.sim_line_id, s.user_id, s.amount, s.currency, s.frequency_days
    FROM public.scheduled_topups s
    WHERE s.is_active = true
      AND s.status = 'active'
      AND s.schedule_type = 'notify'
      AND s.next_execution_at <= NOW()
  LOOP
    SELECT phone_number INTO v_phone_number
    FROM public.sim_lines
    WHERE id = r.sim_line_id;

    INSERT INTO public.notifications (
      user_id, category, title, body, action_url, sim_line_id, delivered_via, is_read, created_at
    ) VALUES (
      r.user_id, 'line_critical', 'Notify Renewal',
      'Your Phone Number (' || COALESCE(v_phone_number, '') || ') is due for recharge. Please top up at least $' || to_char(r.amount, 'FM99999990.00') || ' to keep it active.',
      '/sim_lines/' || r.sim_line_id, r.sim_line_id, ARRAY[]::text[], false, NOW()
    );

    INSERT INTO public.line_activity_log (
      sim_line_id, user_id, event_type, description, metadata, created_at
    ) VALUES (
      r.sim_line_id, r.user_id, 'reminder_sent',
      NULL,
      jsonb_build_object('amount', r.amount, 'schedule_type', 'notify'),
      clock_timestamp()
    );

    v_next_due := NOW() + (
      CASE
        WHEN r.frequency_days = 0 THEN INTERVAL '1 hour'
        ELSE r.frequency_days * INTERVAL '1 day'
      END
    );

    UPDATE public.scheduled_topups
    SET last_execution_at = NOW(),
        next_execution_at = v_next_due,
        retry_count = 0,
        whatsapp_sent_this_cycle = false,
        status = 'active',
        updated_at = NOW()
    WHERE id = r.id;
  END LOOP;

  -- B. Emit advance low-balance reminders for upcoming auto-refills
  PERFORM public.emit_upcoming_refill_low_balance_reminders();

  -- C. Emit missing recharge date reminders (guarded by rolling cadence)
  BEGIN
    PERFORM public.emit_missing_recharge_date_reminders();
  EXCEPTION WHEN OTHERS THEN
    -- Best effort, do not crash main cron
  END;

  -- D. Emit urgent 48-hour deactivation alerts
  BEGIN
    PERFORM public.emit_urgent_deactivation_alerts(false);
  EXCEPTION WHEN OTHERS THEN
    -- Best effort, do not crash main cron
  END;
END;
$function$;

REVOKE ALL ON FUNCTION public.process_due_notifications() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_due_notifications() TO service_role;

-- ============================================================================
-- 9. ADMIN DIAGNOSTIC RPCs FOR ALERT CLOCK & CARRIER RULE QUALITY
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_get_alert_clock_overview()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_counts RECORD;
  v_dry_run jsonb;
BEGIN
  PERFORM public.assert_admin();

  SELECT 
    count(*) AS total,
    count(*) FILTER (WHERE state = 'eligible') AS eligible,
    count(*) FILTER (WHERE state = 'eligible' AND is_within_48h = true) AS within_48h,
    count(*) FILTER (WHERE alert_emitted_at IS NOT NULL) AS alerted,
    count(*) FILTER (WHERE state = 'needs_activity_date') AS needs_date,
    count(*) FILTER (WHERE state = 'needs_qualifying_usage') AS needs_usage,
    count(*) FILTER (WHERE state = 'needs_amount') AS needs_amount,
    count(*) FILTER (WHERE state = 'stale_rule') AS stale_rule,
    count(*) FILTER (WHERE state = 'missing_rule') AS missing_rule
  INTO v_counts
  FROM public.sim_line_alert_clock_states;

  v_dry_run := public.emit_urgent_deactivation_alerts(true);

  RETURN jsonb_build_object(
    'success', true,
    'total_lines', v_counts.total,
    'eligible_count', v_counts.eligible,
    'within_48h_count', v_counts.within_48h,
    'alerted_count', v_counts.alerted,
    'needs_date_count', v_counts.needs_date,
    'needs_usage_count', v_counts.needs_usage,
    'needs_amount_count', v_counts.needs_amount,
    'stale_rule_count', v_counts.stale_rule,
    'missing_rule_count', v_counts.missing_rule,
    'dry_run_preview', v_dry_run
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_alert_clock_overview() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_list_alert_clocks(
  p_state TEXT DEFAULT NULL,
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_res jsonb;
  v_total INT;
BEGIN
  PERFORM public.assert_admin();

  SELECT count(*) INTO v_total
  FROM public.sim_line_alert_clock_states
  WHERE (p_state IS NULL OR state = p_state);

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'sim_line_id', cs.sim_line_id,
      'phone_number', sl.phone_number,
      'nickname', sl.nickname,
      'carrier_name', cs.carrier_name,
      'activity_requirement', cs.activity_requirement,
      'inactivity_limit_days', cs.inactivity_limit_days,
      'qualifying_activity_type', cs.qualifying_activity_type,
      'qualifying_activity_at', cs.qualifying_activity_at,
      'deactivation_cutoff_at', cs.deactivation_cutoff_at,
      'hours_remaining', cs.hours_remaining,
      'is_within_48h', cs.is_within_48h,
      'state', cs.state,
      'ineligibility_reason', cs.ineligibility_reason,
      'precision', cs.precision,
      'rule_source_url', cs.rule_source_url,
      'rule_last_verified_at', cs.rule_last_verified_at,
      'alert_emitted_at', cs.alert_emitted_at,
      'evaluated_at', cs.evaluated_at
    ) ORDER BY cs.hours_remaining ASC NULLS LAST
  ), '[]'::jsonb) INTO v_res
  FROM (
    SELECT * FROM public.sim_line_alert_clock_states
    WHERE (p_state IS NULL OR state = p_state)
    ORDER BY hours_remaining ASC NULLS LAST
    LIMIT LEAST(GREATEST(p_limit, 1), 200)
    OFFSET GREATEST(p_offset, 0)
  ) cs
  JOIN public.sim_lines sl ON sl.id = cs.sim_line_id;

  RETURN jsonb_build_object(
    'success', true,
    'total', v_total,
    'items', v_res
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_list_alert_clocks(text, int, int) TO authenticated, service_role;

-- 10. Triggers to maintain Alert Clock in real-time
CREATE OR REPLACE FUNCTION public.trg_fn_sync_alert_clock_on_sim_line()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  PERFORM public.calculate_sim_line_alert_clock(NEW.id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_alert_clock_on_sim_line ON public.sim_lines;
CREATE TRIGGER trg_sync_alert_clock_on_sim_line
  AFTER INSERT OR UPDATE OF last_topup_at, status, carrier_id, carrier_rule_id, carrier_status, is_carrier_verified
  ON public.sim_lines
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_sync_alert_clock_on_sim_line();

CREATE OR REPLACE FUNCTION public.trg_fn_sync_alert_clock_on_activity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF NEW.sim_line_id IS NOT NULL THEN
    PERFORM public.calculate_sim_line_alert_clock(NEW.sim_line_id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_alert_clock_on_activity ON public.line_activity_log;
CREATE TRIGGER trg_sync_alert_clock_on_activity
  AFTER INSERT
  ON public.line_activity_log
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_sync_alert_clock_on_activity();

-- 11. Automatically calculate Alert Clock on initial migration run
SELECT public.sync_all_sim_line_alert_clocks();

