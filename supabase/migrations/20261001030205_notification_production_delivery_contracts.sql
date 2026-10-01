-- Durable per-target outcomes; Admin retains exclusive country routing control.
UPDATE public.notification_channel_catalog SET min_tier='standard' WHERE channel_key IN ('email','whatsapp');
ALTER TABLE public.notification_channel_catalog ADD CONSTRAINT paid_alert_channels_support_standard
  CHECK (channel_key NOT IN ('email','whatsapp') OR min_tier='standard');
ALTER TABLE public.whatsapp_message_attempts ADD COLUMN IF NOT EXISTS sent_at timestamptz;
ALTER TABLE public.whatsapp_message_attempts ADD COLUMN IF NOT EXISTS claim_token uuid;
ALTER TABLE public.whatsapp_message_attempts ADD COLUMN IF NOT EXISTS lease_until timestamptz;
ALTER TABLE public.whatsapp_message_attempts ADD COLUMN IF NOT EXISTS retryable boolean NOT NULL DEFAULT false;
ALTER TABLE public.whatsapp_message_attempts ADD COLUMN IF NOT EXISTS request_snapshot jsonb;
ALTER TABLE public.whatsapp_message_attempts ADD COLUMN IF NOT EXISTS cycle_key text;

CREATE TABLE public.notification_channel_targets (
  notification_id uuid NOT NULL REFERENCES public.notifications(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  channel text NOT NULL CHECK (channel IN ('push','email','telegram','whatsapp','webhook')),
  target_key text NOT NULL,
  snapshot jsonb NOT NULL DEFAULT '{}',
  state text NOT NULL DEFAULT 'pending' CHECK (state IN ('pending','attempting','accepted_by_provider','delivered','skipped','failed','unknown')),
  attempt_count integer NOT NULL DEFAULT 0,
  retryable boolean NOT NULL DEFAULT false,
  claim_token uuid,
  lease_until timestamptz,
  detail text,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (notification_id,channel,target_key)
);
ALTER TABLE public.notification_channel_targets ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.notification_channel_targets FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.notification_channel_targets TO service_role;

CREATE TABLE public.whatsapp_cycle_reservations (
  sim_line_id uuid NOT NULL REFERENCES public.sim_lines(id) ON DELETE CASCADE,
  cycle_key text NOT NULL,
  attempt_id uuid REFERENCES public.whatsapp_message_attempts(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (sim_line_id,cycle_key)
);
ALTER TABLE public.whatsapp_cycle_reservations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.whatsapp_cycle_reservations FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.whatsapp_cycle_reservations TO service_role;

-- Canonical paid eligibility never borrows another line or an account plan.
-- A paid digest is an explicit exception: it contains only eligible line content.
CREATE OR REPLACE FUNCTION public.notification_channel_eligible(
  p_user_id uuid,p_sim_line_id uuid,p_channel text,p_event_type text DEFAULT NULL
) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.notification_channel_catalog c
    WHERE c.channel_key=p_channel AND c.is_globally_enabled
      AND CASE WHEN p_channel IN ('push','telegram') THEN true
      WHEN p_sim_line_id IS NULL THEN p_event_type='weekly_digest' AND p_channel='email' AND EXISTS (
        SELECT 1 FROM public.sim_lines l WHERE l.user_id=p_user_id
          AND l.status NOT IN ('deleted','canceled','archived')
          AND lower(coalesce(nullif(l.plan_type,''),nullif(l.protection_tier,''),'basic')) IN ('standard','premium')
          AND (l.plan_expires_at IS NULL OR l.plan_expires_at>now())
          AND (c.min_tier<>'premium' OR lower(coalesce(nullif(l.plan_type,''),l.protection_tier))='premium')
      ) ELSE EXISTS (
        SELECT 1 FROM public.sim_lines l WHERE l.id=p_sim_line_id AND l.user_id=p_user_id
          AND l.status NOT IN ('deleted','canceled','archived')
          AND lower(coalesce(nullif(l.plan_type,''),nullif(l.protection_tier,''),'basic')) IN ('standard','premium')
          AND (l.plan_expires_at IS NULL OR l.plan_expires_at>now())
          AND (c.min_tier<>'premium' OR lower(coalesce(nullif(l.plan_type,''),l.protection_tier))='premium')
      ) END
  );
$$;
REVOKE ALL ON FUNCTION public.notification_channel_eligible(uuid,uuid,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.notification_channel_eligible(uuid,uuid,text,text) TO service_role;

CREATE OR REPLACE FUNCTION public.whatsapp_refill_healthy(p_sim_line_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (SELECT 1 FROM public.scheduled_topups s
    WHERE s.sim_line_id=p_sim_line_id AND s.is_active AND s.status='active'
      AND s.schedule_type IN ('refill','refill_mini','refill_custom') AND coalesce(s.retry_count,0)=0
      AND coalesce((SELECT e.status NOT IN ('failed','blocked','canceled')
        FROM public.topup_executions e WHERE e.sim_line_id=s.sim_line_id AND e.created_at>=s.created_at
        ORDER BY e.created_at DESC LIMIT 1),true));
$$;
REVOKE ALL ON FUNCTION public.whatsapp_refill_healthy(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.whatsapp_refill_healthy(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.claim_notification_channel_target(
  p_notification_id uuid,p_channel text,p_target_key text,p_snapshot jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE r public.notification_channel_targets; v_uid uuid; v_token uuid;
BEGIN
  SELECT user_id INTO STRICT v_uid FROM public.notifications WHERE id=p_notification_id;
  INSERT INTO public.notification_channel_targets(notification_id,user_id,channel,target_key,snapshot)
    VALUES(p_notification_id,v_uid,p_channel,p_target_key,coalesce(p_snapshot,'{}')) ON CONFLICT DO NOTHING;
  SELECT * INTO STRICT r FROM public.notification_channel_targets
    WHERE notification_id=p_notification_id AND channel=p_channel AND target_key=p_target_key FOR UPDATE;
  IF r.state='attempting' AND r.lease_until<now() THEN
    UPDATE public.notification_channel_targets SET state='unknown',retryable=false,lease_until=NULL,
      detail='Send lease expired; reconcile provider outcome',updated_at=now()
      WHERE notification_id=p_notification_id AND channel=p_channel AND target_key=p_target_key RETURNING * INTO r;
  END IF;
  IF r.state='pending' OR (r.state='failed' AND r.retryable AND r.attempt_count<3) THEN
    v_token:=gen_random_uuid();
    UPDATE public.notification_channel_targets SET state='attempting',attempt_count=attempt_count+1,
      claim_token=v_token,lease_until=now()+interval '3 minutes',updated_at=now()
      WHERE notification_id=p_notification_id AND channel=p_channel AND target_key=p_target_key RETURNING * INTO r;
    RETURN jsonb_build_object('claimed',true,'claim_token',v_token,'target',to_jsonb(r));
  END IF;
  RETURN jsonb_build_object('claimed',false,'target',to_jsonb(r));
END;
$$;
CREATE OR REPLACE FUNCTION public.finish_notification_channel_target(
  p_notification_id uuid,p_channel text,p_target_key text,p_claim_token uuid,
  p_state text,p_retryable boolean,p_detail text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE r public.notification_channel_targets;
BEGIN
  IF p_state NOT IN ('accepted_by_provider','delivered','skipped','failed','unknown') THEN RAISE EXCEPTION 'Invalid target state'; END IF;
  SELECT * INTO r FROM public.notification_channel_targets WHERE notification_id=p_notification_id
    AND channel=p_channel AND target_key=p_target_key AND claim_token=p_claim_token FOR UPDATE;
  IF r.notification_id IS NULL THEN RETURN jsonb_build_object('persisted',false); END IF;
  UPDATE public.notification_channel_targets SET state=p_state,retryable=p_retryable AND p_state='failed',
    detail=left(p_detail,1000),lease_until=NULL,updated_at=now()
    WHERE notification_id=p_notification_id AND channel=p_channel AND target_key=p_target_key
      AND claim_token=p_claim_token AND state='attempting' RETURNING * INTO r;
  IF NOT FOUND THEN
    SELECT * INTO r FROM public.notification_channel_targets WHERE notification_id=p_notification_id
      AND channel=p_channel AND target_key=p_target_key AND claim_token=p_claim_token;
  END IF;
  RETURN jsonb_build_object('persisted',true,'target',to_jsonb(r));
END;
$$;
REVOKE ALL ON FUNCTION public.claim_notification_channel_target(uuid,text,text,jsonb) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.finish_notification_channel_target(uuid,text,text,uuid,text,boolean,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.claim_notification_channel_target(uuid,text,text,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.finish_notification_channel_target(uuid,text,text,uuid,text,boolean,text) TO service_role;

CREATE OR REPLACE FUNCTION public.claim_whatsapp_message_attempt(p_key text,p_snapshot jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE r public.whatsapp_message_attempts; l public.sim_lines; v_cycle text; v_reserved uuid; v_token uuid;
BEGIN
  -- Serialize both first sends and retries of the same provider idempotency key.
  PERFORM pg_advisory_xact_lock(hashtextextended(p_key,0));
  SELECT * INTO r FROM public.whatsapp_message_attempts WHERE idempotency_key=p_key FOR UPDATE;
  IF r.id IS NOT NULL THEN
    IF r.state='pending' AND r.lease_until<now() THEN
      UPDATE public.whatsapp_message_attempts SET state='unknown',retryable=false,lease_until=NULL,
        error_category='send_lease_expired',updated_at=now() WHERE id=r.id RETURNING * INTO r;
    END IF;
    IF r.state NOT IN ('failed','skipped') OR NOT r.retryable OR r.attempt_count>=3 THEN
      RETURN jsonb_build_object('claimed',false,'state',r.state,'attempt',to_jsonb(r));
    END IF;
    IF r.route_mode IS DISTINCT FROM p_snapshot->>'route_mode' OR
       r.profile_id IS DISTINCT FROM (p_snapshot->>'profile_id')::uuid OR
       r.profile_version IS DISTINCT FROM (p_snapshot->>'profile_version')::integer OR
       r.sender_number IS DISTINCT FROM p_snapshot->>'sender_number' THEN
      RETURN jsonb_build_object('claimed',false,'state','skipped','reason','route_changed',
        'detail','Admin route/profile changed; original attempt retained for review','attempt',to_jsonb(r));
    END IF;
  END IF;
  IF p_snapshot->>'purpose'='subscription_alert' THEN
    SELECT * INTO STRICT l FROM public.sim_lines WHERE id=(p_snapshot->>'sim_line_id')::uuid FOR UPDATE;
    IF NOT public.notification_channel_eligible(l.user_id,l.id,'whatsapp',NULL) OR
       NOT EXISTS(SELECT 1 FROM public.notifications n WHERE n.id=(p_snapshot->>'notification_id')::uuid
         AND n.user_id=l.user_id AND n.sim_line_id=l.id) THEN RAISE EXCEPTION 'Line/event not eligible'; END IF;
    -- Routine confirmations cannot consume the sole deactivation warning.
    IF EXISTS(SELECT 1 FROM public.notifications WHERE id=(p_snapshot->>'notification_id')::uuid AND event_type='line_deactivation_imminent') THEN
      PERFORM public.calculate_sim_line_alert_clock(l.id);
      SELECT coalesce(a.alert_cycle_token,md5(coalesce(l.last_topup_at,l.created_at)::text)) INTO v_cycle
        FROM public.sim_line_alert_clock_states a WHERE a.sim_line_id=l.id;
      v_cycle:=coalesce(v_cycle,md5(coalesce(l.last_topup_at,l.created_at)::text));
      SELECT attempt_id INTO v_reserved FROM public.whatsapp_cycle_reservations WHERE sim_line_id=l.id AND cycle_key=v_cycle;
      IF FOUND AND (v_reserved IS NULL OR v_reserved IS DISTINCT FROM r.id) THEN
        RETURN jsonb_build_object('claimed',false,'state','skipped','reason','cycle_quota_consumed',
          'detail','A WhatsApp send is already reserved or accepted for this recharge cycle','attempt',to_jsonb(r));
      END IF;
    END IF;
  END IF;
  v_token:=gen_random_uuid();
  IF r.id IS NULL THEN
    INSERT INTO public.whatsapp_message_attempts(purpose,notification_id,command_id,recipient_phone,recipient_country_id,
      sim_line_id,route_mode,profile_id,profile_version,sender_number,idempotency_key,template_name,template_language,
      state,claim_token,lease_until,request_snapshot,cycle_key)
    VALUES(p_snapshot->>'purpose',(p_snapshot->>'notification_id')::uuid,p_snapshot->>'command_id',
      p_snapshot->>'recipient_phone',(p_snapshot->>'recipient_country_id')::uuid,(p_snapshot->>'sim_line_id')::uuid,
      p_snapshot->>'route_mode',(p_snapshot->>'profile_id')::uuid,(p_snapshot->>'profile_version')::integer,
      p_snapshot->>'sender_number',p_key,p_snapshot->>'template_name',p_snapshot->>'template_language',
      'pending',v_token,now()+interval '3 minutes',p_snapshot->'request',v_cycle) RETURNING * INTO r;
  ELSE
    UPDATE public.whatsapp_message_attempts SET state='pending',claim_token=v_token,lease_until=now()+interval '3 minutes',
      attempt_count=attempt_count+1,updated_at=now() WHERE id=r.id RETURNING * INTO r;
  END IF;
  IF v_cycle IS NOT NULL THEN
    INSERT INTO public.whatsapp_cycle_reservations(sim_line_id,cycle_key,attempt_id) VALUES(l.id,v_cycle,r.id)
      ON CONFLICT DO NOTHING;
  END IF;
  RETURN jsonb_build_object('claimed',true,'claim_token',v_token,'attempt',to_jsonb(r));
END;
$$;
CREATE OR REPLACE FUNCTION public.finish_whatsapp_message_attempt(
  p_id uuid,p_claim_token uuid,p_state text,p_retryable boolean,p_error_category text,p_detail text,p_provider_message_id text
) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE r public.whatsapp_message_attempts;
BEGIN
  IF p_state NOT IN ('accepted','sent','delivered','failed','skipped','unknown') THEN RAISE EXCEPTION 'Invalid WhatsApp state'; END IF;
  SELECT * INTO r FROM public.whatsapp_message_attempts WHERE id=p_id AND claim_token=p_claim_token FOR UPDATE;
  IF r.id IS NULL THEN RETURN false; END IF;
  -- A fast worker receipt may already have advanced the state; never regress it.
  IF r.state IN ('sent','delivered') THEN RETURN true; END IF;
  IF r.state<>'pending' THEN RETURN false; END IF;
  UPDATE public.whatsapp_message_attempts SET state=p_state,retryable=p_retryable AND p_state='failed',lease_until=NULL,
    error_category=p_error_category,error_detail=left(p_detail,1000),
    provider_message_id=coalesce(p_provider_message_id,provider_message_id),updated_at=now()
    WHERE id=p_id;
  IF p_state IN ('failed','skipped') THEN
    DELETE FROM public.whatsapp_cycle_reservations WHERE attempt_id=p_id;
  END IF;
  RETURN true;
END;
$$;
REVOKE ALL ON FUNCTION public.claim_whatsapp_message_attempt(text,jsonb) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.finish_whatsapp_message_attempt(uuid,uuid,text,boolean,text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.claim_whatsapp_message_attempt(text,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.finish_whatsapp_message_attempt(uuid,uuid,text,boolean,text,text,text) TO service_role;

-- Preserve existing environment-backed profiles explicitly; new profiles must
-- configure their own credentials. No route, profile assignment or sender changes.
UPDATE public.whatsapp_provider_profiles SET connection_metadata=connection_metadata||'{"use_legacy_env":true}'::jsonb
  WHERE provider_kind='baileys' AND NOT(connection_metadata ? 'auth_secret_vault_id');
UPDATE public.whatsapp_provider_profiles SET connection_metadata=connection_metadata||'{"legacy_webhook_env":true}'::jsonb
  WHERE provider_kind='meta_cloud' AND NOT(connection_metadata ? 'app_secret_vault_id');

-- Preserve explicitly migrated credentials when Admin edits another field.
CREATE OR REPLACE FUNCTION public.preserve_whatsapp_legacy_flags()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE k text;
BEGIN
  FOREACH k IN ARRAY ARRAY['use_legacy_env','legacy_webhook_env'] LOOP
    IF OLD.connection_metadata ? k AND NOT(NEW.connection_metadata ? k) THEN
      NEW.connection_metadata:=NEW.connection_metadata||jsonb_build_object(k,OLD.connection_metadata->k);
    END IF;
  END LOOP;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_preserve_whatsapp_legacy_flags BEFORE UPDATE OF connection_metadata ON public.whatsapp_provider_profiles
  FOR EACH ROW EXECUTE FUNCTION public.preserve_whatsapp_legacy_flags();
REVOKE ALL ON FUNCTION public.preserve_whatsapp_legacy_flags() FROM PUBLIC,anon,authenticated;

-- Clients may change preferences, never bot bindings or owner-verified endpoints.
CREATE OR REPLACE FUNCTION public.protect_notification_channel_config()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF current_user IN ('postgres','service_role','supabase_admin') OR public.is_power_user(auth.uid()) THEN RETURN NEW; END IF;
  IF TG_OP='UPDATE' AND (NEW.user_id IS DISTINCT FROM OLD.user_id OR NEW.channel_type IS DISTINCT FROM OLD.channel_type) THEN
    RAISE EXCEPTION 'Channel identity is server-owned' USING ERRCODE='42501';
  END IF;
  IF NEW.channel_type IN ('telegram','webhook') AND
      ((TG_OP='INSERT' AND coalesce(NEW.config,'{}')<>'{}') OR
       (TG_OP='UPDATE' AND NEW.config IS DISTINCT FROM OLD.config)) THEN
    RAISE EXCEPTION 'Use verified channel setup' USING ERRCODE='42501';
  END IF;
  IF coalesce(NEW.config,'{}') ?| ARRAY['owner_verified','binding_verified_at','is_verified','chat_id'] AND
     (TG_OP='INSERT' OR NEW.config IS DISTINCT FROM OLD.config) THEN
    RAISE EXCEPTION 'Binding evidence is server-owned' USING ERRCODE='42501';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.protect_notification_channel_config() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER trg_protect_notification_channel_config BEFORE INSERT OR UPDATE ON public.notification_channels
  FOR EACH ROW EXECUTE FUNCTION public.protect_notification_channel_config();
REVOKE INSERT,UPDATE ON public.notifications FROM authenticated,anon;
GRANT UPDATE(is_read) ON public.notifications TO authenticated;
REVOKE ALL ON public.telegram_bind_tokens FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.bind_telegram_bot_token(p_token_or_uid text,p_chat_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_uid uuid;
BEGIN
  IF p_token_or_uid !~ '^[0-9a-f]{32}$' OR p_chat_id !~ '^-?[0-9]+$' THEN
    RETURN jsonb_build_object('success',false,'error','Invalid bind token or chat');
  END IF;
  UPDATE public.telegram_bind_tokens SET used_at=now()
    WHERE token=p_token_or_uid AND used_at IS NULL AND expires_at>now() RETURNING user_id INTO v_uid;
  IF v_uid IS NULL THEN RETURN jsonb_build_object('success',false,'error','Expired or used bind token'); END IF;
  INSERT INTO public.notification_channels(user_id,channel_type,is_enabled,config)
    VALUES(v_uid,'telegram',true,jsonb_build_object('chat_id',p_chat_id,'binding_verified_at',now()))
    ON CONFLICT(user_id,channel_type) DO UPDATE SET is_enabled=true,
      config=public.notification_channels.config||excluded.config;
  RETURN jsonb_build_object('success',true);
END;
$$;
REVOKE ALL ON FUNCTION public.bind_telegram_bot_token(text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.bind_telegram_bot_token(text,text) TO service_role;

-- Caller submits a state transition, never arbitrary external-send content.
CREATE OR REPLACE FUNCTION public.emit_line_setup_event(p_user_id uuid,p_sim_line_id uuid,p_event_type text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE l public.sim_lines; s public.scheduled_topups; v_key text; v_id uuid; v_title text; v_body text; v_type text; v_identity text;
BEGIN
  SELECT * INTO l FROM public.sim_lines WHERE id=p_sim_line_id AND user_id=p_user_id;
  IF l.id IS NULL THEN RAISE EXCEPTION 'SIM ownership required' USING ERRCODE='42501'; END IF;
  IF p_event_type NOT IN ('line_added','auto_recharge_scheduled','line_setup_incomplete') THEN
    RAISE EXCEPTION 'Unsupported client event' USING ERRCODE='42501';
  END IF;
  SELECT * INTO s FROM public.scheduled_topups WHERE sim_line_id=l.id AND user_id=p_user_id
    AND is_active AND status='active' ORDER BY created_at DESC LIMIT 1;
  v_type:=CASE WHEN s.id IS NULL THEN 'line_setup_incomplete'
    WHEN s.schedule_type IN ('refill','refill_mini','refill_custom') THEN 'auto_recharge_scheduled' ELSE 'line_added' END;
  IF p_event_type<>v_type THEN RETURN NULL; END IF;
  v_identity:='SIM line ending '||right(regexp_replace(l.phone_number,'[^0-9]','','g'),4);
  v_title:=CASE v_type WHEN 'line_added' THEN 'SIM protection is ready'
    WHEN 'auto_recharge_scheduled' THEN 'Automatic recharge scheduled' ELSE 'Finish your SIM setup' END;
  v_body:=v_identity||CASE v_type WHEN 'line_added' THEN ' has a saved recharge reminder.'
    WHEN 'auto_recharge_scheduled' THEN ' has an active automatic recharge schedule.' ELSE ' needs a saved reminder or recharge schedule.' END;
  v_key:='setup:'||l.id||':'||v_type||':'||coalesce(s.id::text,'initial');
  INSERT INTO public.notifications(user_id,sim_line_id,category,title,body,event_type,schema_version,source_event_key,
    action_url,target,template_data,template_version,occurred_at)
  VALUES(p_user_id,l.id,v_type,v_title,v_body,v_type,2,v_key,'/sim-lines/detail/'||l.id,
    jsonb_build_object('route','/sim-lines/detail/'||l.id,'id',l.id),jsonb_build_object('schedule_id',s.id),1,now())
    ON CONFLICT DO NOTHING RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.emit_line_setup_event(uuid,uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.emit_line_setup_event(uuid,uuid,text) TO service_role;

CREATE OR REPLACE FUNCTION public.request_notification_event(p_event_type text,p_sim_line_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_uid uuid:=auth.uid();
BEGIN
  IF v_uid IS NULL OR public.is_user_suspended() THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.sim_lines WHERE id=p_sim_line_id AND user_id=v_uid) THEN
    RAISE EXCEPTION 'SIM ownership required' USING ERRCODE='42501';
  END IF;
  IF EXISTS(SELECT 1 FROM public.consume_rate_limit('notification_setup',v_uid::text,10,1.0) WHERE allowed=false) THEN
    RAISE EXCEPTION 'Too many notification requests' USING ERRCODE='KS429';
  END IF;
  RETURN public.emit_line_setup_event(v_uid,p_sim_line_id,p_event_type);
END;
$$;
REVOKE ALL ON FUNCTION public.request_notification_event(text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.request_notification_event(text,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.request_notification_test(p_channel text DEFAULT NULL,p_sim_line_id uuid DEFAULT NULL,p_delay_minutes integer DEFAULT 0)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_uid uuid:=auth.uid(); v_line uuid:=p_sim_line_id; v_id uuid;
BEGIN
  IF v_uid IS NULL OR public.is_user_suspended() THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  IF p_channel IS NOT NULL AND p_channel NOT IN ('push','email','telegram','whatsapp') THEN RAISE EXCEPTION 'Unsupported test channel'; END IF;
  IF p_delay_minutes NOT BETWEEN 0 AND 30 THEN RAISE EXCEPTION 'Invalid test delay'; END IF;
  IF v_line IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.sim_lines WHERE id=v_line AND user_id=v_uid) THEN
    RAISE EXCEPTION 'SIM ownership required' USING ERRCODE='42501';
  END IF;
  IF v_line IS NULL THEN
    SELECT id INTO v_line FROM public.sim_lines WHERE user_id=v_uid
      AND lower(coalesce(nullif(plan_type,''),protection_tier)) IN ('standard','premium')
      AND (plan_expires_at IS NULL OR plan_expires_at>now()) ORDER BY created_at LIMIT 1;
  END IF;
  IF EXISTS(SELECT 1 FROM public.consume_rate_limit('notification_test',v_uid::text,3,0.05) WHERE allowed=false) THEN
    RAISE EXCEPTION 'Test alert limit reached; try again later' USING ERRCODE='KS429';
  END IF;
  INSERT INTO public.notifications(user_id,sim_line_id,category,title,body,event_type,schema_version,template_data,scheduled_at,occurred_at)
    VALUES(v_uid,v_line,'system','KeepSIMs test alert','Your saved alert channel received this test request.',
      'notification_test',2,jsonb_build_object('test_channel',p_channel),now()+make_interval(mins=>p_delay_minutes),now()) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.request_notification_test(text,uuid,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.request_notification_test(text,uuid,integer) TO authenticated;
-- Remove the legacy arbitrary-content schedule entrypoint from customer roles.
REVOKE EXECUTE ON FUNCTION public.schedule_delayed_notification(uuid,text,text,text,integer) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.trg_fn_dispatch_notification()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_channels text[]; v_enabled boolean; v_category_channels text[]; v_language text;
BEGIN
  SELECT is_enabled,channels INTO v_enabled,v_category_channels FROM public.alert_settings
    WHERE user_id=NEW.user_id AND category=NEW.category;
  IF NOT coalesce(v_enabled,NEW.category<>'promo') THEN RETURN NEW; END IF;
  IF NEW.sim_line_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.sim_lines WHERE id=NEW.sim_line_id AND user_id=NEW.user_id) THEN RETURN NEW; END IF;
  SELECT language INTO v_language FROM public.user_preferences WHERE user_id=NEW.user_id;
  SELECT array_agg(c.channel_key ORDER BY c.sort_order) INTO v_channels
  FROM public.notification_channel_catalog c LEFT JOIN public.notification_channels nc
    ON nc.user_id=NEW.user_id AND nc.channel_type=c.channel_key
  WHERE public.notification_channel_eligible(NEW.user_id,NEW.sim_line_id,c.channel_key,NEW.event_type)
    AND coalesce(nc.is_enabled,c.channel_key='push')
    AND (v_category_channels IS NULL OR c.channel_key=ANY(v_category_channels))
    AND (NEW.event_type IS DISTINCT FROM 'weekly_digest' OR c.channel_key<>'email' OR NEW.template_data->>'digest_paid_eligible'='true')
    AND (NEW.event_type<>'notification_test' OR NEW.template_data->>'test_channel' IS NULL OR c.channel_key=NEW.template_data->>'test_channel');
  IF coalesce(cardinality(v_channels),0)=0 THEN RETURN NEW; END IF;
  INSERT INTO public.notification_dispatch_jobs(notification_id,user_id,payload,next_attempt_at)
    VALUES(NEW.id,NEW.user_id,jsonb_build_object('notification_id',NEW.id,'user_id',NEW.user_id,
      'category',NEW.category,'title',NEW.title,'body',NEW.body,'action_url',NEW.action_url,'sim_line_id',NEW.sim_line_id,
      'channels',v_channels,'event_type',NEW.event_type,'source_event_key',NEW.source_event_key,
      'target',NEW.target,'template_data',coalesce(NEW.template_data,'{}'),'language',coalesce(v_language,'en'),
      'schema_version',NEW.schema_version,'occurred_at',NEW.occurred_at,'template_version',NEW.template_version),
      greatest(now(),coalesce(NEW.scheduled_at,now()))) ON CONFLICT(notification_id) DO NOTHING;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.trg_fn_dispatch_notification() FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.project_whatsapp_delivery()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_state text; v_uid uuid;
BEGIN
  IF NEW.state IS NOT DISTINCT FROM OLD.state OR NEW.notification_id IS NULL THEN RETURN NEW; END IF;
  v_state:=CASE NEW.state WHEN 'accepted' THEN 'accepted_by_provider' WHEN 'sent' THEN 'accepted_by_provider'
    WHEN 'delivered' THEN 'delivered' WHEN 'failed' THEN 'failed' WHEN 'unknown' THEN 'unknown' WHEN 'skipped' THEN 'skipped' ELSE NULL END;
  IF v_state IS NULL THEN RETURN NEW; END IF;
  SELECT user_id INTO v_uid FROM public.notifications WHERE id=NEW.notification_id;
  UPDATE public.notification_channel_targets SET state=v_state,detail=left(coalesce(NEW.error_detail,'Verified WhatsApp state: '||NEW.state),1000),
    retryable=NEW.retryable AND v_state='failed',updated_at=now()
    WHERE notification_id=NEW.notification_id AND channel='whatsapp' AND target_key='primary' AND state<>'delivered';
  INSERT INTO public.notification_deliveries(notification_id,user_id,channel,status,detail)
    VALUES(NEW.notification_id,v_uid,'whatsapp',v_state,'WhatsApp attempt receipt: '||NEW.state);
  IF NEW.state='delivered' THEN
    UPDATE public.notifications SET delivered_via=ARRAY(SELECT DISTINCT x FROM unnest(coalesce(delivered_via,ARRAY[]::text[])||ARRAY['whatsapp']) x)
      WHERE id=NEW.notification_id;
  END IF;
  IF NEW.state IN ('failed','skipped') THEN
    DELETE FROM public.whatsapp_cycle_reservations WHERE attempt_id=NEW.id;
  END IF;
  IF NEW.state IN ('failed','skipped','unknown') THEN
    UPDATE public.notification_dispatch_jobs SET state=CASE WHEN NEW.state='failed' AND NEW.retryable AND attempt_count<3 THEN 'pending'
        WHEN NEW.state='skipped' THEN 'canceled' ELSE NEW.state END,
      next_attempt_at=CASE WHEN NEW.state='failed' AND NEW.retryable AND attempt_count<3 THEN now()+interval '2 minutes' ELSE next_attempt_at END,
      last_error='WhatsApp worker/provider outcome: '||NEW.state,updated_at=now()
      WHERE notification_id=NEW.notification_id AND state='complete';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_project_whatsapp_delivery AFTER UPDATE OF state ON public.whatsapp_message_attempts
  FOR EACH ROW EXECUTE FUNCTION public.project_whatsapp_delivery();
REVOKE ALL ON FUNCTION public.project_whatsapp_delivery() FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.whatsapp_state_monotonic()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF OLD.state='delivered' OR (OLD.state='sent' AND NEW.state IN ('pending','accepted')) THEN
    NEW.state:=OLD.state;
    NEW.delivered_at:=OLD.delivered_at;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_whatsapp_state_monotonic BEFORE UPDATE ON public.whatsapp_message_attempts
  FOR EACH ROW EXECUTE FUNCTION public.whatsapp_state_monotonic();
REVOKE ALL ON FUNCTION public.whatsapp_state_monotonic() FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.emit_setup_after_schedule()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NEW.is_active AND NEW.status='active' AND (TG_OP='INSERT' OR OLD.is_active IS DISTINCT FROM NEW.is_active OR OLD.status IS DISTINCT FROM NEW.status) THEN
    PERFORM public.emit_line_setup_event(NEW.user_id,NEW.sim_line_id,
      CASE WHEN NEW.schedule_type IN ('refill','refill_mini','refill_custom') THEN 'auto_recharge_scheduled' ELSE 'line_added' END);
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_emit_setup_after_schedule AFTER INSERT OR UPDATE OF is_active,status ON public.scheduled_topups
  FOR EACH ROW EXECUTE FUNCTION public.emit_setup_after_schedule();
REVOKE ALL ON FUNCTION public.emit_setup_after_schedule() FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.process_due_notifications()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE r record; v_period interval; v_next timestamptz; v_key text;
BEGIN
  FOR r IN SELECT s.*,l.phone_number FROM public.scheduled_topups s
    JOIN public.sim_lines l ON l.id=s.sim_line_id AND l.user_id=s.user_id
    WHERE s.is_active AND s.status='active' AND s.schedule_type='notify' AND s.next_execution_at<=now()
    ORDER BY s.next_execution_at LIMIT 1000 FOR UPDATE OF s SKIP LOCKED
  LOOP
    v_key:='notify_due:'||r.id||':'||r.next_execution_at;
    v_period:=CASE WHEN coalesce(r.frequency_days,0)<=0 THEN interval '1 hour' ELSE r.frequency_days*interval '1 day' END;
    -- One catch-up event, then advance from the intended due time, not now().
    v_next:=r.next_execution_at+v_period*(floor(extract(epoch FROM (now()-r.next_execution_at))/extract(epoch FROM v_period))+1);
    INSERT INTO public.notifications(user_id,sim_line_id,category,title,body,event_type,schema_version,source_event_key,
      action_url,occurred_at,expires_at,template_data)
    VALUES(r.user_id,r.sim_line_id,'line_critical','Recharge reminder',
      'SIM line ending '||right(regexp_replace(r.phone_number,'[^0-9]','','g'),4)||' is due for recharge. Open KeepSIMs to review your line.',
      'recharge_due_today',2,v_key,'/sim-lines/detail/'||r.sim_line_id,r.next_execution_at,now()+interval '24 hours',
      jsonb_build_object('scheduled_topup_id',r.id,'amount',r.amount,'currency',r.currency)) ON CONFLICT DO NOTHING;
    INSERT INTO public.line_activity_log(sim_line_id,user_id,event_type,metadata)
      VALUES(r.sim_line_id,r.user_id,'reminder_sent',jsonb_build_object('source_event_key',v_key,'schedule_type','notify'));
    UPDATE public.scheduled_topups SET last_execution_at=now(),next_execution_at=v_next,retry_count=0,
      whatsapp_sent_this_cycle=false,updated_at=now() WHERE id=r.id;
  END LOOP;
  PERFORM public.emit_upcoming_refill_low_balance_reminders();
  PERFORM public.emit_missing_recharge_date_reminders();
  PERFORM public.emit_urgent_deactivation_alerts(false);
END;
$$;
REVOKE ALL ON FUNCTION public.process_due_notifications() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.process_due_notifications() TO service_role;

CREATE OR REPLACE FUNCTION public.emit_weekly_notification_digests(p_now timestamptz DEFAULT now())
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE r record; v_lines uuid[]; v_count integer; v_created integer:=0; v_id uuid; v_paid boolean;
BEGIN
  FOR r IN SELECT u.user_id,u.notification_timezone,
      p_now AT TIME ZONE u.notification_timezone local_now
    FROM public.user_preferences u JOIN pg_timezone_names z ON z.name=u.notification_timezone
    WHERE u.weekly_digest_enabled AND u.weekly_digest_consent_at IS NOT NULL
      AND extract(isodow FROM p_now AT TIME ZONE u.notification_timezone)=7
      AND extract(hour FROM p_now AT TIME ZONE u.notification_timezone) BETWEEN 9 AND 11
      AND NOT EXISTS(SELECT 1 FROM public.notifications n WHERE n.user_id=u.user_id
        AND n.source_event_key='weekly_digest:'||u.user_id||':'||to_char((p_now AT TIME ZONE u.notification_timezone)::date,'YYYY-MM-DD'))
    ORDER BY u.user_id LIMIT 1000
  LOOP
    SELECT array_agg(l.id) INTO v_lines FROM public.sim_lines l WHERE l.user_id=r.user_id
      AND public.notification_channel_eligible(r.user_id,l.id,'email',NULL);
    v_paid:=coalesce(cardinality(v_lines),0)>0;
    IF NOT v_paid THEN
      SELECT array_agg(id) INTO v_lines FROM public.sim_lines WHERE user_id=r.user_id AND status='active';
    END IF;
    IF coalesce(cardinality(v_lines),0)=0 THEN CONTINUE; END IF;
    SELECT count(*) INTO v_count FROM public.notifications n WHERE n.user_id=r.user_id AND n.sim_line_id=ANY(v_lines)
      AND n.created_at>=p_now-interval '7 days' AND n.created_at<p_now
      AND n.event_type IS DISTINCT FROM 'weekly_digest' AND n.category NOT IN ('promo','line_critical');
    INSERT INTO public.notifications(user_id,category,title,body,event_type,schema_version,source_event_key,
      action_url,occurred_at,expires_at,template_data,template_version)
    VALUES(r.user_id,'system','Your KeepSIMs weekly summary',
      'You have '||cardinality(v_lines)||CASE WHEN v_paid THEN ' eligible' ELSE ' saved' END||' SIM line(s) and '||v_count||' routine update(s) this week. Open KeepSIMs to review them.',
      'weekly_digest',2,'weekly_digest:'||r.user_id||':'||to_char(r.local_now::date,'YYYY-MM-DD'),
      '/notifications',p_now,p_now+interval '24 hours',
      jsonb_build_object('included_line_ids',to_jsonb(v_lines),'digest_paid_eligible',v_paid,'routine_count',v_count,'active_line_count',cardinality(v_lines)),1)
      ON CONFLICT DO NOTHING RETURNING id INTO v_id;
    IF v_id IS NOT NULL THEN v_created:=v_created+1; END IF;
    v_id:=NULL;
  END LOOP;
  RETURN jsonb_build_object('created',v_created);
END;
$$;
REVOKE ALL ON FUNCTION public.emit_weekly_notification_digests(timestamptz) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.emit_weekly_notification_digests(timestamptz) TO service_role;

-- The worker asks again immediately before sending a queued Baileys job.
CREATE OR REPLACE FUNCTION public.whatsapp_attempt_send_allowed(p_attempt_id uuid,p_observed_sender text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS(SELECT 1 FROM public.whatsapp_message_attempts a
    JOIN public.whatsapp_provider_profiles p ON p.id=a.profile_id
    JOIN public.whatsapp_country_routes r ON r.country_id=a.recipient_country_id
    WHERE a.id=p_attempt_id AND a.route_mode='baileys' AND a.state IN ('pending','accepted')
      AND p.is_enabled AND p.ready_state='ready' AND p.version=a.profile_version
      AND r.route_mode='baileys' AND r.profile_id=a.profile_id
      AND regexp_replace(a.sender_number,'[^0-9]','','g')=regexp_replace(p_observed_sender,'[^0-9]','','g')
      AND (a.purpose='admin_test' OR public.notification_channel_eligible(
        (SELECT user_id FROM public.notifications WHERE id=a.notification_id),a.sim_line_id,'whatsapp',NULL))
      AND (a.purpose='admin_test' OR EXISTS(SELECT 1 FROM public.notification_channels c
        JOIN public.notifications n ON n.user_id=c.user_id WHERE n.id=a.notification_id AND c.channel_type='whatsapp' AND c.is_enabled
          AND regexp_replace(coalesce(c.config->>'phone_number',c.config->>'phone'),'[^0-9]','','g')=regexp_replace(a.recipient_phone,'[^0-9]','','g')
          AND (n.expires_at IS NULL OR n.expires_at>now())
          AND NOT EXISTS(SELECT 1 FROM public.alert_settings s WHERE s.user_id=n.user_id AND s.category=n.category
            AND (NOT s.is_enabled OR (s.channels IS NOT NULL AND NOT('whatsapp'=ANY(s.channels)))))
          AND (n.category='top_up_failed' OR n.event_type IN ('notification_test','line_added','auto_recharge_scheduled','line_setup_incomplete') OR NOT public.whatsapp_refill_healthy(a.sim_line_id)) )));
$$;
REVOKE ALL ON FUNCTION public.whatsapp_attempt_send_allowed(uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.whatsapp_attempt_send_allowed(uuid,text) TO service_role;
