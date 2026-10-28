-- ESIM-04: callbacks are authenticated refresh hints, never financial evidence.
BEGIN;
SET LOCAL lock_timeout='5s';
ALTER TABLE esim_private.accounts ADD COLUMN event_window_at timestamptz DEFAULT now(),ADD COLUMN event_window_count integer NOT NULL DEFAULT 0;
CREATE TABLE esim_private.events(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),account_id uuid NOT NULL REFERENCES esim_private.accounts(id),
 event_key text NOT NULL CHECK(event_key~'^[a-f0-9]{64}$'),kind text NOT NULL,
 order_ref text,submission_ref text,profile_ref text,iccid text,event_observed_at timestamptz,
 state_hint text,received_at timestamptz NOT NULL DEFAULT now(),
 status text NOT NULL DEFAULT 'pending' CHECK(status IN('pending','leased','retry','done','dead_letter')),
 attempts integer NOT NULL DEFAULT 0, next_attempt_at timestamptz NOT NULL DEFAULT now(),
 lease uuid,lease_until timestamptz,error_code text,UNIQUE(account_id,event_key)
);
CREATE INDEX esim_events_due ON esim_private.events(next_attempt_at) WHERE status IN('pending','leased','retry');
ALTER TABLE esim_private.events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON esim_private.events FROM PUBLIC,anon,authenticated;
GRANT SELECT ON esim_private.events TO service_role;
CREATE FUNCTION public.service_esim_accept_event(p_account_key text,p_event_key text,p_event jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE a esim_private.accounts%ROWTYPE; eid uuid;
BEGIN
 PERFORM esim_private.require_service();
 SELECT * INTO STRICT a FROM esim_private.accounts WHERE account_key=p_account_key FOR UPDATE;
 IF p_event_key!~'^[a-f0-9]{64}$' OR coalesce(p_event->>'kind','') NOT IN('ORDER_STATUS','ESIM_STATUS','DATA_USAGE','VALIDITY_USAGE','SMDP_EVENT')
  OR octet_length(p_event::text)>2048 OR coalesce(p_event->>'order_ref',p_event->>'submission_ref',p_event->>'profile_ref',p_event->>'iccid') IS NULL
 THEN RAISE EXCEPTION 'Invalid eSIM event'; END IF;
 SELECT id INTO eid FROM esim_private.events WHERE account_id=a.id AND event_key=p_event_key;
 IF FOUND THEN RETURN jsonb_build_object('accepted',true,'duplicate',true); END IF;
 IF a.event_window_at<now()-interval '1 minute' THEN
  UPDATE esim_private.accounts SET event_window_at=now(),event_window_count=1 WHERE id=a.id;
 ELSIF a.event_window_count>=120 THEN RETURN '{"accepted":false,"rate_limited":true}'::jsonb;
 ELSE UPDATE esim_private.accounts SET event_window_count=event_window_count+1 WHERE id=a.id;
 END IF;
 IF (SELECT count(*) FROM esim_private.events WHERE account_id=a.id AND status IN('pending','retry','leased'))>=10000 THEN
  RETURN '{"accepted":false,"rate_limited":true}'::jsonb; END IF;
 INSERT INTO esim_private.events(account_id,event_key,kind,order_ref,submission_ref,profile_ref,iccid,event_observed_at,state_hint)
 VALUES(a.id,p_event_key,p_event->>'kind',left(p_event->>'order_ref',100),left(p_event->>'submission_ref',100),
  left(p_event->>'profile_ref',100),left(p_event->>'iccid',32),(p_event->>'observed_at')::timestamptz,left(p_event->>'state_hint',64));
 RETURN '{"accepted":true,"duplicate":false}'::jsonb;
END $$;
CREATE FUNCTION public.service_esim_claim_event(p_account_key text DEFAULT 'primary')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE e esim_private.events%ROWTYPE;
BEGIN
 PERFORM esim_private.require_service();
 SELECT event.* INTO e FROM esim_private.events event JOIN esim_private.accounts a ON a.id=event.account_id
 WHERE a.account_key=p_account_key AND event.status IN('pending','retry','leased') AND event.next_attempt_at<=now()
  AND (event.lease_until IS NULL OR event.lease_until<now())
 ORDER BY event.next_attempt_at FOR UPDATE OF event SKIP LOCKED LIMIT 1;
 IF NOT FOUND THEN RETURN NULL; END IF;
 UPDATE esim_private.events SET status='leased',lease=gen_random_uuid(),lease_until=now()+interval '2 minutes',attempts=attempts+1
 WHERE id=e.id RETURNING * INTO e;
 RETURN jsonb_build_object('id',e.id,'lease',e.lease);
END $$;
CREATE FUNCTION public.service_esim_process_event(p_event_id uuid,p_lease uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE e esim_private.events%ROWTYPE; r esim_private.order_runs%ROWTYPE; n integer:=0; m integer:=0;
BEGIN
 PERFORM esim_private.require_service();
 SELECT * INTO STRICT e FROM esim_private.events WHERE id=p_event_id FOR UPDATE;
 IF p_lease IS NULL OR e.lease IS NULL OR e.lease_until IS NULL OR e.lease IS DISTINCT FROM p_lease OR e.lease_until<now() OR e.status<>'leased' THEN RETURN '{"processed":false}'::jsonb; END IF;
 SELECT * INTO r FROM esim_private.order_runs WHERE account_id=e.account_id AND
  ((e.submission_ref IS NOT NULL AND submission_ref=e.submission_ref) OR
   (e.submission_ref IS NULL AND e.order_ref IS NOT NULL AND provider_order_ref=e.order_ref)) FOR UPDATE;
 IF FOUND AND (r.provider_order_ref IS NULL OR e.order_ref IS NULL OR r.provider_order_ref=e.order_ref) THEN
  -- The hint never binds an unproven provider order or completes delivery.
  UPDATE esim_private.order_runs SET hinted_order_ref=coalesce(hinted_order_ref,e.order_ref),next_check_at=now()
  WHERE order_id=r.order_id AND state<>'completed';
  UPDATE esim_private.profile_work w SET next_check_at=least(coalesce(next_check_at,now()),now())
  FROM public.user_esims p WHERE p.id=w.profile_id AND p.order_id=r.order_id AND p.supplier_account_id=e.account_id AND w.terminal_checks<3;
  n:=1;
 END IF;
 UPDATE esim_private.profile_work w SET next_check_at=least(coalesce(next_check_at,now()),now())
 FROM public.user_esims p WHERE w.profile_id=p.id AND p.supplier_account_id=e.account_id AND p.supplier_profile_ref IS NOT NULL AND w.terminal_checks<3
 AND (e.profile_ref IS NOT NULL OR e.iccid IS NOT NULL)
 AND (e.profile_ref IS NULL OR p.supplier_profile_ref=e.profile_ref) AND (e.iccid IS NULL OR p.iccid=e.iccid);
 GET DIAGNOSTICS m=ROW_COUNT;
 UPDATE esim_private.events SET status=CASE WHEN n+m>0 THEN 'done' WHEN attempts>=8 THEN 'dead_letter' ELSE 'retry' END,
  lease=NULL,lease_until=NULL,error_code=CASE WHEN n+m=0 THEN 'UNMATCHED_REFERENCE' END,
  next_attempt_at=now()+make_interval(secs=>least(21600,60*power(2,least(attempts,8)))::integer)
 WHERE id=e.id;
 RETURN jsonb_build_object('processed',true,'matched',n+m>0);
END $$;
CREATE FUNCTION public.prune_esim_event_inbox() RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 DELETE FROM esim_private.events WHERE status IN('done','dead_letter') AND received_at<now()-interval '30 days';
$$;
CREATE FUNCTION public.admin_esim_runtime_status() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.assert_admin();
 RETURN jsonb_build_object('new_sales_enabled',(SELECT new_sales_enabled FROM esim_private.accounts WHERE account_key='primary'),
  'last_worker_seen_at',(SELECT last_worker_seen_at FROM esim_private.accounts WHERE account_key='primary'),
  'last_cycle',(SELECT last_cycle FROM esim_private.accounts WHERE account_key='primary'),
  'orders',(SELECT coalesce(jsonb_object_agg(state,n),'{}') FROM(SELECT state,count(*) n FROM esim_private.order_runs GROUP BY state)q),
  'events',(SELECT coalesce(jsonb_object_agg(status,n),'{}') FROM(SELECT status,count(*) n FROM esim_private.events GROUP BY status)q),
  'profiles_due',(SELECT count(*) FROM esim_private.profile_work WHERE next_check_at<=now() AND terminal_checks<3));
END $$;
CREATE FUNCTION public.admin_request_esim_reconciliation(p_order_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE queued boolean;
BEGIN
 PERFORM public.assert_admin();
 UPDATE esim_private.order_runs SET next_check_at=now() WHERE order_id=p_order_id AND state<>'completed';
 queued:=FOUND;
 PERFORM public.admin_log('esim.reconciliation.request','esim_order',p_order_id::text,NULL,
  jsonb_build_object('queued',queued,'read_only',true),'Read-only provider reconciliation requested');
 RETURN jsonb_build_object('queued',queued,'read_only',true);
END $$;

-- A separate high-entropy callback capability; never reuse supplier or sync secrets.
DO $$ BEGIN
 IF to_regclass('vault.secrets') IS NOT NULL THEN
  IF NOT EXISTS(SELECT 1 FROM vault.secrets WHERE name='esimaccess_event_secret') THEN
   PERFORM vault.create_secret(replace(gen_random_uuid()::text||gen_random_uuid()::text,'-',''),
     'esimaccess_event_secret','eSIM Access event ingress refresh-hint capability');
  END IF;
 END IF;
 IF EXISTS(SELECT 1 FROM pg_extension WHERE extname='pg_cron') THEN
  PERFORM cron.schedule('esim-event-inbox-retention','27 3 * * *','select public.prune_esim_event_inbox()');
 END IF;
END $$;
DO $$ DECLARE r record; BEGIN
 FOR r IN SELECT p.oid::regprocedure signature FROM pg_proc p WHERE p.pronamespace='public'::regnamespace
 AND p.proname IN('service_esim_accept_event','service_esim_claim_event','service_esim_process_event','prune_esim_event_inbox') LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',r.signature);
  EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',r.signature);
 END LOOP;
END $$;
REVOKE ALL ON FUNCTION public.admin_esim_runtime_status(),public.admin_request_esim_reconciliation(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_esim_runtime_status(),public.admin_request_esim_reconciliation(uuid) TO authenticated,service_role;
NOTIFY pgrst,'reload schema';
COMMIT;
