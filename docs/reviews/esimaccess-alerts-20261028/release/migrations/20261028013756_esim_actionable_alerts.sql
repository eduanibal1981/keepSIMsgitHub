BEGIN;
SET LOCAL lock_timeout='5s';

-- ESIM-05 uses stored, authenticated observations, never callback payloads.
CREATE TABLE esim_private.alert_policy (
 id boolean PRIMARY KEY DEFAULT true CHECK(id), enabled boolean NOT NULL DEFAULT true,
 low_percent integer NOT NULL DEFAULT 20 CHECK(low_percent BETWEEN 2 AND 99),
 critical_percent integer NOT NULL DEFAULT 10 CHECK(critical_percent BETWEEN 1 AND 98),
 near_expiry_hours integer NOT NULL DEFAULT 48 CHECK(near_expiry_hours BETWEEN 1 AND 168),
 last_sweep_at timestamptz, last_sweep_created integer,
 freshness_minutes integer NOT NULL DEFAULT 360 CHECK(freshness_minutes BETWEEN 5 AND 1440),
 CHECK(critical_percent<low_percent)
);
INSERT INTO esim_private.alert_policy(id) VALUES(true);
CREATE TABLE esim_private.alert_cycles (
 profile_id uuid NOT NULL REFERENCES public.user_esims(id) ON DELETE CASCADE,
 entitlement_key text NOT NULL CHECK(length(entitlement_key) BETWEEN 1 AND 160),
 cycle_id uuid NOT NULL DEFAULT gen_random_uuid(), created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(profile_id,entitlement_key), UNIQUE(cycle_id)
);
CREATE TABLE esim_private.alert_profile_state (
 profile_id uuid PRIMARY KEY REFERENCES public.user_esims(id) ON DELETE CASCADE,
 cycle_id uuid NOT NULL REFERENCES esim_private.alert_cycles(cycle_id),
 evaluated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE esim_private.alert_events (
 event_key text PRIMARY KEY, profile_id uuid REFERENCES public.user_esims(id) ON DELETE CASCADE,
 order_id uuid REFERENCES public.esim_orders(id) ON DELETE CASCADE,
 cycle_id uuid REFERENCES esim_private.alert_cycles(cycle_id),
 event_type text NOT NULL, threshold integer NOT NULL DEFAULT 0,
 notification_id uuid REFERENCES public.notifications(id) ON DELETE SET NULL,
 decision text NOT NULL CHECK(decision IN('queued','opted_out','covered_by_lower_threshold')),
 created_at timestamptz NOT NULL DEFAULT now()
);
DO $$DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['alert_policy','alert_cycles','alert_profile_state','alert_events'] LOOP
  EXECUTE format('ALTER TABLE esim_private.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('REVOKE ALL ON esim_private.%I FROM PUBLIC,anon,authenticated',t);
  EXECUTE format('GRANT ALL ON esim_private.%I TO service_role',t);
 END LOOP;
END $$;

-- Preserve every existing category, including independently deployed additions.
DO $$DECLARE t text; c text; expression text; BEGIN
 FOREACH t IN ARRAY ARRAY['notifications','alert_settings'] LOOP
  c:=t||'_category_check';
  SELECT pg_get_expr(conbin,conrelid) INTO STRICT expression FROM pg_constraint
    WHERE conrelid=('public.'||t)::regclass AND conname=c;
  EXECUTE format('ALTER TABLE public.%I DROP CONSTRAINT %I',t,c);
  EXECUTE format('ALTER TABLE public.%I ADD CONSTRAINT %I CHECK ((%s) OR category=''esim_updates'')',t,c,expression);
 END LOOP;
END $$;

-- Only a trusted, proven entitlement settlement may open a later recharge cycle.
-- ESIM-05 calls this for original issuance only; byte/expiry changes never reset it.
-- ESIM-08 must call it atomically with a verified recharge settlement.
CREATE FUNCTION esim_private.open_alert_cycle(p_profile_id uuid,p_entitlement_key text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result uuid; previous uuid;
BEGIN
 PERFORM esim_private.require_service();
 PERFORM 1 FROM public.user_esims WHERE id=p_profile_id AND provider='esimaccess'
  AND supplier_profile_ref IS NOT NULL FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Verified eSIM profile required'; END IF;
 SELECT cycle_id INTO result FROM esim_private.alert_cycles WHERE profile_id=p_profile_id AND entitlement_key=p_entitlement_key;
 -- Replaying an older settlement cannot move the current cycle backwards.
 IF FOUND THEN RETURN result; END IF;
 INSERT INTO esim_private.alert_cycles(profile_id,entitlement_key) VALUES(p_profile_id,p_entitlement_key) RETURNING cycle_id INTO result;
 INSERT INTO esim_private.alert_profile_state(profile_id,cycle_id) VALUES(p_profile_id,result)
 ON CONFLICT(profile_id) DO UPDATE SET cycle_id=excluded.cycle_id;
 RETURN result;
END $$;

CREATE FUNCTION esim_private.alert_is_relevant(p_profile_id uuid,p_event_type text,p_threshold integer DEFAULT 0)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.user_esims; cfg esim_private.alert_policy; fresh boolean;
BEGIN
 SELECT * INTO cfg FROM esim_private.alert_policy WHERE id AND enabled;
 IF NOT FOUND THEN RETURN false; END IF;
 SELECT * INTO p FROM public.user_esims WHERE id=p_profile_id AND provider='esimaccess'
  AND supplier_profile_ref IS NOT NULL AND supplier_account_id IS NOT NULL;
 IF NOT FOUND THEN RETURN false; END IF;
 fresh:=p.last_observation_at BETWEEN now()-make_interval(mins=>cfg.freshness_minutes) AND now()+interval '5 minutes';
 IF NOT coalesce(fresh,false) THEN RETURN false; END IF;
 RETURN coalesce(CASE p_event_type
 WHEN 'esim_ready' THEN p.profile_state='issued' AND p.installation_state='released'
  AND p.lpa_string LIKE 'LPA:1$%$%' AND p.smdp_address<>'' AND p.matching_id<>''
 WHEN 'esim_activated' THEN p.profile_state='active' AND p.bundle_state IN('active','depleted')
 WHEN 'esim_low_data' THEN p.profile_state IN('active','suspended') AND p.bundle_state IN('active','depleted')
  AND p.usage_error_code IS NULL AND p.last_usage_check>=now()-make_interval(mins=>cfg.freshness_minutes)
  AND p.last_usage_check<=now()+interval '5 minutes'
  AND (p.usage_observed_at IS NULL OR p.usage_observed_at BETWEEN now()-make_interval(mins=>cfg.freshness_minutes) AND now()+interval '5 minutes')
  AND p.data_total_bytes>0 AND p.data_remaining_bytes BETWEEN 0 AND p.data_total_bytes
  AND p.data_remaining_bytes::numeric*100<=p.data_total_bytes::numeric*p_threshold
  AND (p.confirmed_expires_at IS NULL OR p.confirmed_expires_at>now())
 WHEN 'esim_near_expiry' THEN p.bundle_state IN('active','depleted') AND p.profile_state IN('active','suspended')
  AND p.confirmed_expires_at>now() AND p.confirmed_expires_at<=now()+make_interval(hours=>cfg.near_expiry_hours)
 WHEN 'esim_expired' THEN p.bundle_state='expired' AND p.profile_state='expired'
 ELSE false END,false);
END $$;

CREATE FUNCTION esim_private.emit_alert(p_profile_id uuid,p_order_id uuid,p_cycle_id uuid,p_event_type text,p_threshold integer DEFAULT 0)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE uid uuid; key text; cat text; title text; body text; target jsonb; n uuid; allowed boolean; decision text;
BEGIN
 PERFORM esim_private.require_service();
 IF p_profile_id IS NOT NULL THEN
  SELECT user_id INTO STRICT uid FROM public.user_esims WHERE id=p_profile_id;
  key:='esim:'||p_profile_id||':'||CASE WHEN p_event_type IN('esim_ready','esim_activated') THEN 'profile' ELSE p_cycle_id::text END||':'||p_event_type||':'||p_threshold;
  target:=jsonb_build_object('route','/esim/profiles/:id','id',p_profile_id);
 ELSE
  SELECT user_id INTO STRICT uid FROM public.esim_orders WHERE id=p_order_id AND provider='esimaccess';
  key:='esim:order:'||p_order_id||':'||p_event_type;
  target:=jsonb_build_object('route','/esim/orders/:id','id',p_order_id);
 END IF;
 cat:=CASE WHEN p_event_type='esim_low_data' THEN 'esim_low_data' ELSE 'esim_updates' END;
 SELECT coalesce((SELECT is_enabled FROM public.alert_settings WHERE user_id=uid AND category=cat),true) INTO allowed;
 decision:=CASE WHEN allowed THEN 'queued' ELSE 'opted_out' END;
 INSERT INTO esim_private.alert_events(event_key,profile_id,order_id,cycle_id,event_type,threshold,decision)
 VALUES(key,p_profile_id,p_order_id,p_cycle_id,p_event_type,p_threshold,decision) ON CONFLICT DO NOTHING;
 IF NOT FOUND OR NOT allowed THEN RETURN false; END IF;
 title:=CASE p_event_type WHEN 'esim_ready' THEN 'Your eSIM is ready to install'
 WHEN 'esim_activated' THEN 'Your eSIM is active' WHEN 'esim_low_data' THEN 'Your eSIM data is running low'
 WHEN 'esim_near_expiry' THEN 'Your eSIM validity is ending soon' WHEN 'esim_expired' THEN 'Your eSIM has expired'
 WHEN 'esim_order_completed' THEN 'Your eSIM order is ready' ELSE 'Your eSIM order needs support' END;
 body:=CASE p_event_type WHEN 'esim_ready' THEN 'Open your eSIM securely in KeepSIMs to view installation details.'
 WHEN 'esim_activated' THEN 'Open your eSIM to review its latest usage and confirmed validity.'
 WHEN 'esim_low_data' THEN 'Your latest reported allowance is at or below '||p_threshold||'%. Open your eSIM to review usage. Recharge is not available yet.'
 WHEN 'esim_near_expiry' THEN 'Open your eSIM to check its confirmed expiry in your local time. Recharge is not available yet.'
 WHEN 'esim_expired' THEN 'The latest provider check confirms expiry. Open your eSIM to review its status.'
 WHEN 'esim_order_completed' THEN 'Open My eSIMs in KeepSIMs to view your profiles and installation details.'
 ELSE 'Your order needs a support review. Open My eSIMs to review the order; this alert does not confirm a refund.' END;
 INSERT INTO public.notifications(user_id,category,title,body,event_type,schema_version,source_event_key,action_url,target,
  occurred_at,expires_at,template_version,template_data,delivered_via)
 VALUES(uid,cat,title,body,p_event_type,2,key,CASE WHEN p_profile_id IS NULL THEN '/esim/orders/'||p_order_id ELSE '/esim/profiles/'||p_profile_id END,target,
  now(),now()+interval '24 hours',1,jsonb_build_object('profile_id',p_profile_id,'cycle_id',p_cycle_id,'threshold',p_threshold),ARRAY[]::text[])
 RETURNING id INTO n;
 UPDATE esim_private.alert_events SET notification_id=n WHERE event_key=key;
 RETURN true;
END $$;

CREATE FUNCTION public.service_esim_emit_alerts(p_limit integer DEFAULT 250)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p record; o record; cfg esim_private.alert_policy; cycle uuid; event text; threshold integer; produced integer:=0; checked integer:=0;
BEGIN
 PERFORM esim_private.require_service();
 SELECT * INTO cfg FROM esim_private.alert_policy WHERE id AND enabled;
 IF NOT FOUND THEN RETURN jsonb_build_object('enabled',false,'created',0); END IF;
 -- One transaction serializes sweeps; unique event keys also protect restarts.
 IF NOT pg_try_advisory_xact_lock(hashtextextended('esim-alert-sweep',0)) THEN RETURN jsonb_build_object('busy',true); END IF;
 FOR p IN SELECT e.id,e.order_id,s.cycle_id FROM public.user_esims e
 LEFT JOIN esim_private.alert_profile_state s ON s.profile_id=e.id
 WHERE e.provider='esimaccess' AND e.supplier_profile_ref IS NOT NULL AND e.supplier_account_id IS NOT NULL
 ORDER BY s.evaluated_at NULLS FIRST,e.id LIMIT least(greatest(coalesce(p_limit,250),1),1000) LOOP
  cycle:=p.cycle_id;
  IF cycle IS NULL THEN cycle:=esim_private.open_alert_cycle(p.id,'issuance:'||p.order_id); END IF;
  FOREACH event IN ARRAY ARRAY['esim_ready','esim_activated','esim_low_data','esim_near_expiry','esim_expired'] LOOP
   threshold:=CASE WHEN event='esim_low_data' THEN CASE WHEN esim_private.alert_is_relevant(p.id,event,cfg.critical_percent)
     THEN cfg.critical_percent ELSE cfg.low_percent END ELSE 0 END;
   IF esim_private.alert_is_relevant(p.id,event,threshold) THEN
    IF esim_private.emit_alert(p.id,NULL,cycle,event,threshold) THEN produced:=produced+1; END IF;
    IF event='esim_low_data' AND threshold=cfg.critical_percent THEN
     INSERT INTO esim_private.alert_events(event_key,profile_id,cycle_id,event_type,threshold,decision)
      VALUES('esim:'||p.id||':'||cycle||':'||event||':'||cfg.low_percent,p.id,cycle,event,cfg.low_percent,'covered_by_lower_threshold') ON CONFLICT DO NOTHING;
    END IF;
   END IF;
  END LOOP;
  UPDATE esim_private.alert_profile_state SET evaluated_at=clock_timestamp() WHERE profile_id=p.id;
  checked:=checked+1;
 END LOOP;
 FOR o IN SELECT e.id,r.state FROM public.esim_orders e JOIN esim_private.order_runs r ON r.order_id=e.id
 WHERE e.provider='esimaccess' AND r.state IN('completed','support_required')
  AND r.updated_at>now()-interval '24 hours'
  AND NOT EXISTS(SELECT 1 FROM esim_private.alert_events a WHERE a.order_id=e.id AND a.event_type='esim_order_'||r.state)
 ORDER BY r.updated_at,e.id LIMIT least(greatest(coalesce(p_limit,250),1),1000) LOOP
  IF esim_private.emit_alert(NULL,o.id,NULL,'esim_order_'||o.state) THEN produced:=produced+1; END IF;
 END LOOP;
 UPDATE esim_private.alert_policy SET last_sweep_at=clock_timestamp(),last_sweep_created=produced WHERE id;
 RETURN jsonb_build_object('enabled',true,'checked',checked,'created',produced);
END $$;

CREATE FUNCTION public.service_esim_alert_is_current(p_notification_id uuid)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE a esim_private.alert_events; n public.notifications;
BEGIN
 PERFORM esim_private.require_service();
 SELECT * INTO n FROM public.notifications WHERE id=p_notification_id;
 IF NOT FOUND OR n.expires_at<=now() THEN RETURN false; END IF;
 SELECT * INTO a FROM esim_private.alert_events WHERE notification_id=n.id AND decision='queued';
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM esim_private.alert_policy WHERE id AND enabled) THEN RETURN false; END IF;
 IF a.profile_id IS NOT NULL THEN
  RETURN EXISTS(SELECT 1 FROM public.user_esims p JOIN esim_private.alert_profile_state s ON s.profile_id=p.id
   WHERE p.id=a.profile_id AND p.user_id=n.user_id AND s.cycle_id=a.cycle_id)
   AND esim_private.alert_is_relevant(a.profile_id,a.event_type,a.threshold);
 END IF;
 RETURN EXISTS(SELECT 1 FROM public.esim_orders o JOIN esim_private.order_runs r ON r.order_id=o.id
  WHERE o.id=a.order_id AND o.user_id=n.user_id AND a.event_type='esim_order_'||r.state);
END $$;

CREATE FUNCTION public.seed_esim_alert_settings() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 INSERT INTO public.alert_settings(user_id,category,channels) VALUES(NEW.id,'esim_updates',ARRAY['push']),
  (NEW.id,'esim_low_data',ARRAY['push']) ON CONFLICT(user_id,category) DO NOTHING;
 RETURN NEW;
END $$;
CREATE TRIGGER seed_esim_alert_settings AFTER INSERT ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.seed_esim_alert_settings();
INSERT INTO public.alert_settings(user_id,category,channels)
 SELECT p.id,c.category,ARRAY['push'] FROM public.profiles p CROSS JOIN (VALUES('esim_updates'),('esim_low_data')) c(category)
 ON CONFLICT(user_id,category) DO NOTHING;

-- Patch only channel narrowing in the current trigger; fail closed on drift.
DO $$DECLARE body text; needle text:='WHERE public.notification_channel_eligible(NEW.user_id,NEW.sim_line_id,c.channel_key,NEW.event_type)'; BEGIN
 SELECT pg_get_functiondef('public.trg_fn_dispatch_notification()'::regprocedure) INTO body;
 IF position(needle in body)=0 THEN RAISE EXCEPTION 'Notification trigger contract changed; review required'; END IF;
 body:=replace(body,needle,needle||E'\n    AND (left(coalesce(NEW.event_type,''''),5)<>''esim_'' OR c.channel_key=''push'')');
 EXECUTE body;
END $$;
DO $$DECLARE r record; BEGIN
 FOR r IN SELECT p.oid::regprocedure signature FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE (n.nspname='esim_private' AND p.proname IN('open_alert_cycle','alert_is_relevant','emit_alert'))
 OR (n.nspname='public' AND p.proname IN('service_esim_emit_alerts','service_esim_alert_is_current','seed_esim_alert_settings')) LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',r.signature);
  EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',r.signature);
 END LOOP;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
