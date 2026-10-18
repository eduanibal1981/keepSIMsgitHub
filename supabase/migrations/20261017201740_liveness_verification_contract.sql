-- Task 12, undeployed. Requires coordinated wallet/funding migrations (Task 7).
-- Legacy attempts/log prose are not upgraded into authenticated provider evidence.
BEGIN;
ALTER TABLE public.line_verification_attempts
  ADD COLUMN evidence_version smallint NOT NULL DEFAULT 0 CHECK (evidence_version IN (0,1)),
  ADD COLUMN allowance_id uuid REFERENCES public.line_verification_allowances(id),
  ADD COLUMN evidence_event_type text;
CREATE UNIQUE INDEX uq_verification_trusted_resource ON public.line_verification_attempts(provider,provider_resource_id)
  WHERE evidence_version=1 AND provider_resource_id IS NOT NULL;

REVOKE ALL ON public.line_verification_attempts,public.line_verification_allowances FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.line_verification_attempts,public.line_verification_allowances TO authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.line_verification_attempts,public.line_verification_allowances TO service_role;
-- Drop separately granted column writes as well as relation privileges.
DO $$ DECLARE t text; c record; BEGIN
  FOREACH t IN ARRAY ARRAY['line_verification_attempts','line_verification_allowances'] LOOP
    FOR c IN SELECT attname FROM pg_attribute WHERE attrelid=('public.'||t)::regclass AND attnum>0 AND NOT attisdropped LOOP
      EXECUTE format('REVOKE INSERT (%I), UPDATE (%I), REFERENCES (%I) ON public.%I FROM PUBLIC,anon,authenticated',c.attname,c.attname,c.attname,t);
    END LOOP;
  END LOOP;
END $$;

-- Keep a rejecting tombstone for old apps; even a service caller cannot use prose
-- or caller-selected channels to manufacture evidence through this old API.
CREATE OR REPLACE FUNCTION public.confirm_line_verification(p_sim_line_id uuid,p_channel text DEFAULT 'telnyx_sms_dlr',p_carrier_name text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN RAISE EXCEPTION 'Provider evidence required' USING ERRCODE='42501'; END $$;
REVOKE ALL ON FUNCTION public.confirm_line_verification(uuid,text,text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.calculate_health_score(
  p_sim_line_id uuid,
  p_status text,
  p_last_topup_at timestamp with time zone
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_is_verified BOOLEAN := false;
  v_has_notify_schedule BOOLEAN := false;
  v_expiration_days INTEGER := 90;
  v_rule_days INTEGER;
  v_score INTEGER := 0;
BEGIN
  -- Pillar 1: Real Live Verification (25 pts)
  -- ONLY awarded if real live verification has succeeded (SMS DLR or missed call).
  -- Format checking or active status during line onboarding does NOT grant points.
  SELECT EXISTS(
    SELECT 1 FROM public.line_verification_attempts a
    JOIN public.sim_lines sl ON sl.id=a.sim_line_id
    WHERE a.sim_line_id=p_sim_line_id AND a.user_id=sl.user_id
      AND a.destination_phone=sl.phone_number AND a.country_id IS NOT DISTINCT FROM sl.country_id
      AND a.evidence_version=1 AND a.status='terminal' AND a.outcome='succeeded'
      AND a.provider_resource_id IS NOT NULL AND a.evidence_event_type IS NOT NULL
      AND a.settlement_status IN ('captured','consumed','no_charge')
  ) INTO v_is_verified;

  IF v_is_verified THEN
    v_score := v_score + 25;
  END IF;

  -- Pillar 2: Auto-Notify alerts configured & active (25 pts)
  SELECT EXISTS(
    SELECT 1 FROM public.scheduled_topups
    WHERE sim_line_id = p_sim_line_id
      AND status = 'active'
      AND is_active = true
      AND schedule_type = 'notify'
  ) INTO v_has_notify_schedule;

  IF v_has_notify_schedule THEN
    v_score := v_score + 25;
  END IF;

  -- Pillar 3: Last refill date within carrier rule window (50 pts)
  -- The ground truth: recorded either in-app or from outside recharge.
  -- Awarded 50 points IF AND ONLY IF recorded AND within carrier rule limit days.
  -- - No recharge recorded: 0 pts
  -- - Last recharge older than carrier limit days: 0 pts
  SELECT cr.inactivity_limit_days INTO v_rule_days
  FROM public.sim_lines sl
  LEFT JOIN public.carrier_rules cr ON (cr.id = sl.carrier_rule_id OR cr.carrier_id = sl.carrier_id)
  WHERE sl.id = p_sim_line_id
  LIMIT 1;

  IF v_rule_days IS NOT NULL AND v_rule_days > 0 THEN
    v_expiration_days := v_rule_days;
  END IF;

  IF p_last_topup_at IS NOT NULL AND p_last_topup_at >= NOW() - (v_expiration_days || ' days')::INTERVAL THEN
    v_score := v_score + 50;
  END IF;

  RETURN LEAST(100, GREATEST(0, v_score));
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.calculate_health_score(uuid, text, timestamp with time zone) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.calculate_health_score(uuid, text, timestamp with time zone) TO authenticated, service_role;


-- Invoker trigger: direct client writes cannot inherit SECURITY DEFINER privilege.
-- Server mutations still derive their result from evidence in the settlement RPC.
CREATE OR REPLACE FUNCTION public.guard_line_verification_fields()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
DECLARE v_client boolean := current_user IN ('anon','authenticated');
BEGIN
  IF TG_OP='INSERT' AND v_client THEN
    NEW.verification_status:='unverified'; NEW.is_carrier_verified:=false;
    NEW.carrier_status:='pending'; NEW.carrier_verified_at:=NULL;
    NEW.detected_operator_name:=NULL;
    NEW.health_score:=public.calculate_health_score(NEW.id,NEW.status,NEW.last_topup_at);
  ELSIF TG_OP='UPDATE' THEN
    IF v_client AND (NEW.verification_status,NEW.health_score,NEW.is_carrier_verified,NEW.carrier_status,NEW.carrier_verified_at,NEW.detected_operator_name)
       IS DISTINCT FROM (OLD.verification_status,OLD.health_score,OLD.is_carrier_verified,OLD.carrier_status,OLD.carrier_verified_at,OLD.detected_operator_name) THEN
      RAISE EXCEPTION 'Provider verification fields are server owned' USING ERRCODE='42501';
    END IF;
    IF (NEW.phone_number,NEW.country_id,NEW.user_id) IS DISTINCT FROM (OLD.phone_number,OLD.country_id,OLD.user_id) THEN
      IF EXISTS(SELECT 1 FROM public.line_verification_attempts WHERE sim_line_id=OLD.id AND status<>'terminal') THEN
        RAISE EXCEPTION 'Unresolved verification must be reconciled before changing line identity';
      END IF;
      NEW.verification_status:='unverified'; NEW.is_carrier_verified:=false;
      NEW.carrier_status:='pending'; NEW.carrier_verified_at:=NULL; NEW.detected_operator_name:=NULL;
      -- Exclude the old destination's verification points while preserving other pillars.
      NEW.health_score:=public.calculate_health_score(OLD.id,NEW.status,NEW.last_topup_at);
      IF EXISTS(SELECT 1 FROM public.line_verification_attempts a WHERE a.sim_line_id=OLD.id
        AND a.user_id=OLD.user_id AND a.destination_phone=OLD.phone_number
        AND a.country_id IS NOT DISTINCT FROM OLD.country_id AND a.evidence_version=1
        AND a.status='terminal' AND a.outcome='succeeded' AND a.evidence_event_type IS NOT NULL
        AND a.provider_resource_id IS NOT NULL AND a.settlement_status IN ('captured','consumed','no_charge')) THEN
        NEW.health_score:=greatest(0,NEW.health_score-25);
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.guard_line_verification_fields() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER z_guard_line_verification_fields BEFORE INSERT OR UPDATE ON public.sim_lines
  FOR EACH ROW EXECUTE FUNCTION public.guard_line_verification_fields();
REVOKE UPDATE (verification_status,health_score,is_carrier_verified,carrier_status,carrier_verified_at,detected_operator_name)
  ON public.sim_lines FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.quote_line_verification(
  p_sim_line_id UUID,
  p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id UUID;
  v_line RECORD;
  v_country RECORD;
  v_is_paid BOOLEAN := false;
  v_has_allowance BOOLEAN := false;
  v_period_start TIMESTAMPTZ;
  v_period_end TIMESTAMPTZ;
  v_allowance RECORD;
  v_wallet_balance NUMERIC(12,2) := 0.00;
  v_wallet_available NUMERIC(12,2) := 0.00;
  v_held_amount NUMERIC(12,2) := 0.00;
  v_in_flight_id UUID := NULL;
  v_effective_sms_cost NUMERIC(12,2) := 0.00;
  v_effective_call_cost NUMERIC(12,2) := 0.00;
BEGIN
  IF coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb->>'role' = 'service_role' THEN
    v_user_id:=p_user_id;
  ELSE
    v_user_id:=auth.uid();
    IF p_user_id IS NOT NULL AND p_user_id IS DISTINCT FROM v_user_id THEN RAISE EXCEPTION 'Unauthorized' USING ERRCODE='42501'; END IF;
  END IF;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = 'KS401';
  END IF;

  -- 1. Fetch SIM Line
  SELECT sl.id, sl.user_id, sl.phone_number, sl.country_id, sl.plan_type, 
         sl.protection_tier, sl.plan_expires_at, sl.verification_status, sl.carrier_status
  INTO v_line
  FROM public.sim_lines sl
  WHERE sl.id = p_sim_line_id;

  IF v_line.id IS NULL THEN
    RAISE EXCEPTION 'SIM line not found' USING ERRCODE = 'KS404';
  END IF;

  IF v_line.user_id IS DISTINCT FROM v_user_id THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = 'KS403';
  END IF;

  -- Check existing in-flight attempt
  SELECT id INTO v_in_flight_id
  FROM public.line_verification_attempts
  WHERE sim_line_id = p_sim_line_id
    AND status <> 'terminal'
  LIMIT 1;

  -- 2. Fetch Country Pricing
  SELECT id, name, iso_code, COALESCE(sms_verify_cost, 0.00) AS sms_cost,
         COALESCE(call_verify_cost, 0.00) AS call_cost, verification_price_version
  INTO v_country
  FROM public.countries
  WHERE id = v_line.country_id;
  IF v_country.id IS NULL THEN RAISE EXCEPTION 'Country verification pricing unavailable'; END IF;

  v_effective_sms_cost := v_country.sms_cost;
  v_effective_call_cost := v_country.call_cost;

  -- 3. Determine Paid Plan Entitlement & Allowance
  IF LOWER(COALESCE(v_line.plan_type, 'free')) IN ('standard', 'premium') 
      THEN
    IF v_line.plan_expires_at > now() THEN
      v_is_paid := true;
      v_period_end := v_line.plan_expires_at;
      v_period_start := v_period_end - interval '365 days';

      -- Ensure allowance row exists for current period
      INSERT INTO public.line_verification_allowances (
        sim_line_id, period_start, period_end
      ) VALUES (
        p_sim_line_id, v_period_start, v_period_end
      )
      ON CONFLICT (sim_line_id, period_start, period_end) DO NOTHING;

      -- Check if available
      SELECT * INTO v_allowance
      FROM public.line_verification_allowances
      WHERE sim_line_id = p_sim_line_id
        AND period_start = v_period_start
        AND period_end = v_period_end;

      IF v_allowance.id IS NOT NULL 
         AND v_allowance.consumed_attempt_id IS NULL 
         AND (v_allowance.reserved_attempt_id IS NULL OR v_allowance.reserved_attempt_id = v_in_flight_id) THEN
        v_has_allowance := true;
      END IF;
    END IF;
  END IF;

  -- 4. Check Wallet Available Funds
  SELECT COALESCE(balance, 0.00) INTO v_wallet_balance
  FROM public.wallets
  WHERE user_id = v_user_id;

  SELECT COALESCE(SUM(amount), 0.00) INTO v_held_amount
  FROM public.wallet_holds
  WHERE user_id = v_user_id AND status = 'active';

  v_wallet_available := GREATEST(0.00, v_wallet_balance - v_held_amount);

  RETURN jsonb_build_object(
    'sim_line_id', v_line.id,
    'phone_number', v_line.phone_number,
    'country_id', v_country.id,
    'country_name', v_country.name,
    'sms_verify_cost_usd', v_effective_sms_cost,
    'call_verify_cost_usd', v_effective_call_cost,
    'is_paid_plan', v_is_paid,
    'has_annual_allowance', v_has_allowance,
    'allowance_period_end', v_period_end,
    'wallet_balance_usd', v_wallet_balance,
    'wallet_available_usd', v_wallet_available,
    'price_version', COALESCE(v_country.verification_price_version, 1),
    'in_flight_attempt_id', v_in_flight_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.quote_line_verification(UUID, UUID) TO authenticated, service_role;



CREATE OR REPLACE FUNCTION public.begin_line_verification(p_user_id uuid,p_sim_line_id uuid,p_method text,p_idempotency_key text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE l public.sim_lines%ROWTYPE; a public.line_verification_attempts%ROWTYPE;
  q jsonb; v_id uuid:=gen_random_uuid(); v_hold uuid; v_allowance uuid; v_cost numeric; v_kind text;
BEGIN
  IF p_method IS NULL OR p_method NOT IN ('sms','voice') OR nullif(btrim(p_idempotency_key),'') IS NULL OR length(p_idempotency_key)>200 THEN
    RAISE EXCEPTION 'Invalid verification request';
  END IF;
  -- Serialize same customer/key across lines, then same line across different keys.
  PERFORM pg_advisory_xact_lock(hashtextextended(p_user_id::text||':'||p_idempotency_key,0));
  SELECT * INTO l FROM public.sim_lines WHERE id=p_sim_line_id AND user_id=p_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Owned SIM line required' USING ERRCODE='42501'; END IF;
  SELECT * INTO a FROM public.line_verification_attempts WHERE user_id=p_user_id AND idempotency_key=p_idempotency_key;
  IF FOUND THEN
    IF a.sim_line_id<>p_sim_line_id OR a.method<>p_method THEN RAISE EXCEPTION 'Idempotency terms mismatch'; END IF;
    RETURN jsonb_build_object('attempt',to_jsonb(a),'dispatch',false);
  END IF;
  SELECT * INTO a FROM public.line_verification_attempts WHERE sim_line_id=l.id AND status<>'terminal' LIMIT 1;
  IF FOUND THEN RETURN jsonb_build_object('attempt',to_jsonb(a),'dispatch',false); END IF;
  q:=public.quote_line_verification(l.id,p_user_id);
  v_cost:=(q->>CASE WHEN p_method='sms' THEN 'sms_verify_cost_usd' ELSE 'call_verify_cost_usd' END)::numeric;
  IF v_cost IS NULL OR v_cost<0 THEN RAISE EXCEPTION 'Verification pricing unavailable'; END IF;
  IF (q->>'has_annual_allowance')::boolean THEN
    SELECT id INTO v_allowance FROM public.line_verification_allowances WHERE sim_line_id=l.id
      AND period_end=(q->>'allowance_period_end')::timestamptz AND consumed_attempt_id IS NULL
      AND reserved_attempt_id IS NULL FOR UPDATE;
    IF v_allowance IS NULL THEN RAISE EXCEPTION 'Allowance unavailable'; END IF;
    v_kind:='annual_allowance'; v_cost:=0;
    UPDATE public.line_verification_allowances SET reserved_attempt_id=v_id,updated_at=now() WHERE id=v_allowance;
  ELSIF v_cost=0 THEN v_kind:='country_zero';
  ELSE
    v_kind:='wallet';
    v_hold:=public.reserve_wallet_funds(p_user_id,v_cost,'line_verification',v_id::text,'Line verification',60);
  END IF;
  INSERT INTO public.line_verification_attempts(id,user_id,sim_line_id,method,destination_phone,country_id,
    retail_price,funding_kind,wallet_hold_id,allowance_id,status,idempotency_key,price_version,evidence_version)
  VALUES(v_id,p_user_id,l.id,p_method,l.phone_number,l.country_id,v_cost,v_kind,v_hold,v_allowance,'dispatching',p_idempotency_key,(q->>'price_version')::int,1)
  RETURNING * INTO a;
  RETURN jsonb_build_object('attempt',to_jsonb(a),'dispatch',true);
END $$;

CREATE OR REPLACE FUNCTION public.bind_line_verification_resource(p_attempt_id uuid,p_resource_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE a public.line_verification_attempts%ROWTYPE;
BEGIN
  SELECT * INTO a FROM public.line_verification_attempts WHERE id=p_attempt_id FOR UPDATE;
  IF a.id IS NULL OR a.evidence_version<>1 OR a.status NOT IN ('dispatching','reconciliation_required','pending')
    OR nullif(btrim(p_resource_id),'') IS NULL THEN RAISE EXCEPTION 'Invalid verification binding'; END IF;
  IF a.provider_resource_id IS NOT NULL AND (a.provider<>'telnyx' OR a.provider_resource_id<>p_resource_id) THEN
    RAISE EXCEPTION 'Provider identity mismatch';
  END IF;
  UPDATE public.line_verification_attempts SET provider='telnyx',provider_resource_id=p_resource_id,status='pending',dispatched_at=coalesce(dispatched_at,now()),updated_at=now() WHERE id=a.id;
  RETURN jsonb_build_object('success',true);
END $$;

-- Retain rejecting old settlement signature, so stale servers fail closed.
CREATE OR REPLACE FUNCTION public.settle_line_verification_attempt(p_attempt_id uuid,p_outcome text,p_carrier_name text DEFAULT NULL,p_error_message text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN RAISE EXCEPTION 'Use authenticated verification event settlement' USING ERRCODE='42501'; END $$;
REVOKE ALL ON FUNCTION public.settle_line_verification_attempt(uuid,text,text,text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.settle_line_verification_event(p_attempt_id uuid,p_provider text,p_resource_id text,p_event_type text,p_outcome text,p_carrier_name text DEFAULT NULL,p_error_message text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE a public.line_verification_attempts%ROWTYPE; l public.sim_lines%ROWTYPE;
  h public.wallet_holds%ROWTYPE; v_settlement text; v_success boolean;
BEGIN
  IF p_event_type IS NULL OR nullif(btrim(p_event_type),'') IS NULL THEN RAISE EXCEPTION 'Provider event type required'; END IF;
  IF p_outcome IS NULL OR p_outcome NOT IN ('succeeded','failed','inconclusive') THEN RAISE EXCEPTION 'Invalid verification outcome'; END IF;
  -- Global operation lock order: line -> attempt -> wallet -> hold/allowance.
  SELECT sl.* INTO l FROM public.sim_lines sl JOIN public.line_verification_attempts x ON x.sim_line_id=sl.id WHERE x.id=p_attempt_id FOR UPDATE OF sl;
  SELECT * INTO a FROM public.line_verification_attempts WHERE id=p_attempt_id FOR UPDATE;
  IF a.id IS NULL THEN RAISE EXCEPTION 'Attempt not found'; END IF;
  IF a.status='terminal' THEN RETURN jsonb_build_object('success',true,'outcome',a.outcome,'settlement_status',a.settlement_status); END IF;
  IF a.evidence_version<>1 OR (a.user_id,a.destination_phone,a.country_id) IS DISTINCT FROM (l.user_id,l.phone_number,l.country_id) THEN
    RAISE EXCEPTION 'Verification identity mismatch or legacy evidence';
  END IF;
  IF p_event_type='dispatch.rejected' AND p_outcome='failed' THEN
    IF a.provider_resource_id IS NOT NULL OR a.status<>'dispatching' THEN RAISE EXCEPTION 'Not an undispatched attempt'; END IF;
  ELSE
    IF p_provider IS NULL OR p_provider NOT IN ('telnyx','twilio') OR nullif(p_resource_id,'') IS NULL
      OR (p_provider,p_resource_id) IS DISTINCT FROM (a.provider,a.provider_resource_id) THEN RAISE EXCEPTION 'Provider identity mismatch'; END IF;
    IF p_outcome='succeeded' THEN
      IF NOT ((a.method='voice' AND p_event_type IN ('call.ringing','call.answered','call.in-progress'))
        OR (a.method='sms' AND p_event_type='message.delivered')) THEN RAISE EXCEPTION 'Positive provider evidence required'; END IF;
    ELSIF NOT ((a.method='voice' AND p_event_type IN ('call.hangup','call.completed','call.failed','call.busy','call.no-answer','call.canceled'))
      OR (a.method='sms' AND p_event_type IN ('message.failed','message.undelivered'))) THEN RAISE EXCEPTION 'Terminal provider evidence required'; END IF;
  END IF;
  v_success:=p_outcome='succeeded';
  IF a.funding_kind='wallet' THEN
    SELECT * INTO h FROM public.wallet_holds WHERE id=a.wallet_hold_id;
    IF h.id IS NULL OR (h.user_id,h.order_type,h.order_reference_id,h.amount,h.currency)
      IS DISTINCT FROM (a.user_id,'line_verification'::text,a.id::text,a.retail_price,'USD'::text) OR h.status<>'active' THEN
      RAISE EXCEPTION 'Verification reservation mismatch';
    END IF;
    IF v_success THEN
      PERFORM public.capture_wallet_hold(h.id,'verification_debit','Line verification',jsonb_build_object('attempt_id',a.id,'sim_line_id',a.sim_line_id));
      v_settlement:='captured';
    ELSE
      IF NOT public.release_wallet_hold(h.id,'Verification unsuccessful') THEN RAISE EXCEPTION 'Reservation release failed'; END IF;
      v_settlement:='released';
    END IF;
  ELSIF a.funding_kind='annual_allowance' THEN
    UPDATE public.line_verification_allowances SET reserved_attempt_id=NULL,
      consumed_attempt_id=CASE WHEN v_success THEN a.id ELSE NULL END,updated_at=now()
      WHERE id=a.allowance_id AND sim_line_id=a.sim_line_id AND reserved_attempt_id=a.id AND consumed_attempt_id IS NULL;
    IF NOT FOUND THEN RAISE EXCEPTION 'Verification allowance mismatch'; END IF;
    v_settlement:=CASE WHEN v_success THEN 'consumed' ELSE 'released' END;
  ELSIF a.funding_kind='country_zero' AND a.retail_price=0 AND a.wallet_hold_id IS NULL AND a.allowance_id IS NULL THEN
    v_settlement:='no_charge';
  ELSE RAISE EXCEPTION 'Invalid verification funding';
  END IF;
  UPDATE public.line_verification_attempts SET status='terminal',outcome=p_outcome,settlement_status=v_settlement,
    evidence_event_type=p_event_type,carrier_name=CASE WHEN v_success THEN left(p_carrier_name,200) ELSE NULL END,
    error_message=left(p_error_message,300),completed_at=now(),updated_at=now() WHERE id=a.id;
  IF v_success THEN
    UPDATE public.sim_lines SET verification_status='verified',is_carrier_verified=true,carrier_status='active',
      carrier_verified_at=now(),detected_operator_name=coalesce(left(p_carrier_name,200),detected_operator_name),
      health_score=public.calculate_health_score(id,status,last_topup_at),updated_at=now() WHERE id=a.sim_line_id;
    INSERT INTO public.line_activity_log(sim_line_id,user_id,event_type,description,metadata)
      VALUES(a.sim_line_id,a.user_id,'health_update','Provider confirmed line activity',jsonb_build_object('attempt_id',a.id,'provider',p_provider));
  END IF;
  RETURN jsonb_build_object('success',true,'outcome',p_outcome,'settlement_status',v_settlement);
END $$;
REVOKE ALL ON FUNCTION public.begin_line_verification(uuid,uuid,text,text),public.bind_line_verification_resource(uuid,text),public.settle_line_verification_event(uuid,text,text,text,text,text,text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.begin_line_verification(uuid,uuid,text,text),public.bind_line_verification_resource(uuid,text),public.settle_line_verification_event(uuid,text,text,text,text,text,text) TO service_role;
REVOKE ALL ON FUNCTION public.quote_line_verification(uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.quote_line_verification(uuid,uuid) TO authenticated,service_role;

-- No legacy prose or unsupported historical success is promoted into proof.
UPDATE public.sim_lines SET verification_status='unverified',is_carrier_verified=false,carrier_verified_at=NULL,
  health_score=public.calculate_health_score(id,status,last_topup_at),updated_at=now();
NOTIFY pgrst,'reload schema';
COMMIT;
