-- Source-event indexes are non-unique for setup/missing-date events.
-- Serialize generation and check the logical key before inserting.
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
  -- Serialize the same logical setup event, including concurrent RPC requests.
  PERFORM pg_advisory_xact_lock(hashtextextended('notification-setup:'||v_key,0));
  IF EXISTS(SELECT 1 FROM public.notifications WHERE user_id=p_user_id AND source_event_key=v_key) THEN
    RETURN NULL;
  END IF;
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


CREATE OR REPLACE FUNCTION public.emit_missing_recharge_date_reminders(p_now timestamptz DEFAULT now())
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_count integer;
BEGIN
  -- A manual sweep and the hourly sweep share one transaction lock.
  PERFORM pg_advisory_xact_lock(hashtextextended('keepsims:missing-recharge-emitter',0));
  WITH candidates AS (
    SELECT l.id,l.user_id,l.phone_number,l.created_at,
      CASE WHEN public.notification_channel_eligible(l.user_id,l.id,'email',NULL) THEN 1 ELSE 7 END days,
      coalesce(up.language,'en') language
    FROM public.sim_lines l LEFT JOIN public.user_preferences up ON up.user_id=l.user_id
    WHERE l.status='active' AND l.last_topup_at IS NULL AND NOT l.protection_paused
  ), inserted AS (
    INSERT INTO public.notifications(user_id,sim_line_id,category,title,body,event_type,schema_version,
      source_event_key,action_url,occurred_at,created_at,expires_at,template_data)
    SELECT user_id,id,'system',CASE WHEN language LIKE 'ar%' THEN 'أضف تاريخ آخر شحن' ELSE 'Add your last recharge date' END,
      CASE WHEN language LIKE 'ar%' THEN 'أضف تاريخ آخر شحن للخط المنتهي بـ ' ELSE 'Add the last recharge date for SIM line ending ' END
        ||right(regexp_replace(phone_number,'[^0-9]','','g'),4),
      'recharge_date_missing',2,'missing-recharge:'||id||':'||floor(extract(epoch FROM p_now)/(days*86400)),
      '/sim-lines/detail/'||id,p_now,p_now,p_now+interval '24 hours',jsonb_build_object('cadence_days',days)
    FROM candidates c WHERE created_at<=p_now-make_interval(days=>c.days)
      AND NOT EXISTS(SELECT 1 FROM public.notifications n WHERE n.sim_line_id=c.id AND n.event_type='recharge_date_missing'
        AND n.created_at>p_now-make_interval(days=>c.days))
    ON CONFLICT DO NOTHING RETURNING id
  ) SELECT count(*) INTO v_count FROM inserted;
  RETURN v_count;
END;
$$;
REVOKE ALL ON FUNCTION public.emit_missing_recharge_date_reminders(timestamptz) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.emit_missing_recharge_date_reminders(timestamptz) TO service_role;
