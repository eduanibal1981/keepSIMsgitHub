-- Keep customer-created paid setup drafts, but only server-confirmed plans may
-- authorize paid delivery. The marker cannot be supplied or changed by clients.
ALTER TABLE public.sim_lines ADD COLUMN notification_entitlement_verified boolean NOT NULL DEFAULT false;
COMMENT ON COLUMN public.sim_lines.notification_entitlement_verified IS
  'Server-confirmed paid notification entitlement; customer plan labels are setup drafts until finalized.';

UPDATE public.sim_lines l SET notification_entitlement_verified=true
WHERE lower(l.plan_type) IN ('standard','premium') AND EXISTS (
  SELECT 1 FROM public.plan_payments p WHERE p.sim_line_id=l.id AND p.user_id=l.user_id
    AND p.kind='plan' AND lower(p.metadata->>'plan')=lower(l.plan_type)
    AND p.created_at+interval '1 year'>now()
);

CREATE OR REPLACE FUNCTION public.guard_notification_paid_entitlement()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
BEGIN
  IF current_user IN ('service_role','postgres','supabase_admin') THEN
    NEW.notification_entitlement_verified:=lower(coalesce(NEW.plan_type,'')) IN ('standard','premium');
  ELSIF TG_OP='INSERT' THEN
    NEW.notification_entitlement_verified:=false;
  ELSIF NEW.notification_entitlement_verified IS DISTINCT FROM OLD.notification_entitlement_verified THEN
    RAISE EXCEPTION 'Only the server can confirm paid notification entitlement' USING ERRCODE='42501';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.guard_notification_paid_entitlement() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER trg_guard_notification_paid_entitlement
  BEFORE INSERT OR UPDATE OF plan_type,plan_expires_at,notification_entitlement_verified ON public.sim_lines
  FOR EACH ROW EXECUTE FUNCTION public.guard_notification_paid_entitlement();

CREATE OR REPLACE FUNCTION public.notification_channel_eligible(
  p_user_id uuid,p_sim_line_id uuid,p_channel text,p_event_type text DEFAULT NULL
) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.notification_channel_catalog c
    WHERE c.channel_key=p_channel AND c.is_globally_enabled
      AND CASE WHEN p_channel IN ('push','telegram') THEN true
      WHEN p_sim_line_id IS NULL THEN p_event_type='weekly_digest' AND p_channel='email' AND EXISTS (
        SELECT 1 FROM public.sim_lines l WHERE l.user_id=p_user_id
          AND l.notification_entitlement_verified
          AND l.status NOT IN ('deleted','canceled','archived')
          AND lower(coalesce(nullif(l.plan_type,''),nullif(l.protection_tier,''),'basic')) IN ('standard','premium')
          AND (l.plan_expires_at IS NULL OR l.plan_expires_at>now())
          AND (c.min_tier<>'premium' OR lower(coalesce(nullif(l.plan_type,''),l.protection_tier))='premium')
      ) ELSE EXISTS (
        SELECT 1 FROM public.sim_lines l WHERE l.id=p_sim_line_id AND l.user_id=p_user_id
          AND l.notification_entitlement_verified
          AND l.status NOT IN ('deleted','canceled','archived')
          AND lower(coalesce(nullif(l.plan_type,''),nullif(l.protection_tier,''),'basic')) IN ('standard','premium')
          AND (l.plan_expires_at IS NULL OR l.plan_expires_at>now())
          AND (c.min_tier<>'premium' OR lower(coalesce(nullif(l.plan_type,''),l.protection_tier))='premium')
      ) END
  );
$$;
REVOKE ALL ON FUNCTION public.notification_channel_eligible(uuid,uuid,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.notification_channel_eligible(uuid,uuid,text,text) TO service_role;

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
  v_key:='setup:'||l.id||':'||v_type||':'||coalesce(s.id::text,'initial')||
    CASE WHEN l.notification_entitlement_verified THEN ':paid_confirmed' ELSE '' END;
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

-- Standard setup saves its schedule before payment finalization; Premium may
-- activate the schedule afterward. Both orders get one paid confirmation event.
CREATE OR REPLACE FUNCTION public.emit_setup_after_paid_confirmation()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE s public.scheduled_topups;
BEGIN
  SELECT * INTO s FROM public.scheduled_topups WHERE sim_line_id=NEW.id AND user_id=NEW.user_id
    AND is_active AND status='active' ORDER BY created_at DESC LIMIT 1;
  IF s.id IS NOT NULL THEN
    BEGIN
      PERFORM public.emit_line_setup_event(NEW.user_id,NEW.id,
        CASE WHEN s.schedule_type IN ('refill','refill_mini','refill_custom') THEN 'auto_recharge_scheduled' ELSE 'line_added' END);
    EXCEPTION WHEN OTHERS THEN
      -- Notification failures must not undo a captured plan payment.
      BEGIN
        INSERT INTO public.system_alerts(kind,message,details,created_at) VALUES(
          'notification_setup_event_failed','Paid setup confirmation could not be queued',
          jsonb_build_object('sim_line_id',NEW.id,'sqlstate',SQLSTATE),now());
      EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Paid setup notification and its diagnostic could not be queued';
      END;
    END;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.emit_setup_after_paid_confirmation() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER trg_emit_setup_after_paid_confirmation
  AFTER UPDATE OF notification_entitlement_verified,plan_type,plan_expires_at ON public.sim_lines
  FOR EACH ROW WHEN (NOT OLD.notification_entitlement_verified AND NEW.notification_entitlement_verified)
  EXECUTE FUNCTION public.emit_setup_after_paid_confirmation();

-- Prefer a confirmed paid line for channel tests when no line is specified.
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
    SELECT id INTO v_line FROM public.sim_lines WHERE user_id=v_uid AND notification_entitlement_verified
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
