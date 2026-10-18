-- Task 23. Observation only: no jobs/processes/providers are started here.
-- Required source/version manifest: ../backend-sync-wt/worker-fleet.json v1.
BEGIN;
CREATE TABLE public.worker_fleet_requirements(
 worker text PRIMARY KEY, manifest_version integer NOT NULL CHECK(manifest_version=1),
 stale_seconds integer NOT NULL CHECK(stale_seconds BETWEEN 60 AND 3600),
 lanes jsonb NOT NULL CHECK(jsonb_typeof(lanes)='object')
);
CREATE TABLE public.worker_fleet_runtime(
 worker text PRIMARY KEY REFERENCES public.worker_fleet_requirements(worker),
 instance uuid NOT NULL, started_at timestamptz NOT NULL, sequence bigint NOT NULL,
 version text NOT NULL CHECK(version ~ '^[0-9a-f]{64}$'),
 last_seen_at timestamptz NOT NULL, lanes jsonb NOT NULL
);
CREATE TABLE public.worker_fleet_probes(
 key text PRIMARY KEY, max_age_seconds integer NOT NULL CHECK(max_age_seconds>0),
 max_backlog integer NOT NULL CHECK(max_backlog>0), query_sql text NOT NULL
);
CREATE TABLE public.worker_fleet_cron(
 name text PRIMARY KEY, max_age_seconds integer NOT NULL CHECK(max_age_seconds>0)
);
CREATE TABLE public.worker_fleet_observation(
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton), payload jsonb NOT NULL,
 observed_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.worker_fleet_observation ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.worker_fleet_observation FROM PUBLIC,anon,authenticated,service_role;
CREATE TABLE public.worker_fleet_incidents(
 key text PRIMARY KEY, state text NOT NULL, last_checked_at timestamptz NOT NULL,
 last_alert_at timestamptz, resolved_at timestamptz
);

INSERT INTO public.worker_fleet_requirements VALUES('server_baileys',1,180,'{"connection": {"max_success_age_seconds": 180, "max_run_seconds": 180}, "receipts": {"max_success_age_seconds": 180, "max_run_seconds": 180}}'::jsonb);
INSERT INTO public.worker_fleet_requirements VALUES('worker_instant_refill',1,180,'{"queue": {"max_success_age_seconds": 300, "max_run_seconds": 900}}'::jsonb);
INSERT INTO public.worker_fleet_requirements VALUES('worker_auto_mini_refill',1,180,'{"queue": {"max_success_age_seconds": 300, "max_run_seconds": 900}, "approval": {"max_success_age_seconds": 300, "max_run_seconds": 300}}'::jsonb);
INSERT INTO public.worker_fleet_requirements VALUES('worker_auto_custom_refill',1,180,'{"queue": {"max_success_age_seconds": 300, "max_run_seconds": 900}, "approval": {"max_success_age_seconds": 300, "max_run_seconds": 300}}'::jsonb);
INSERT INTO public.worker_fleet_requirements VALUES('worker_offers_cache',1,180,'{"catalog": {"max_success_age_seconds": 10800, "max_run_seconds": 7200}}'::jsonb);
INSERT INTO public.worker_fleet_requirements VALUES('worker-esim-catalog',1,180,'{"catalog": {"max_success_age_seconds": 25200, "max_run_seconds": 7200}}'::jsonb);
INSERT INTO public.worker_fleet_requirements VALUES('worker-esim-fulfillment',1,180,'{"fulfillment": {"max_success_age_seconds": 300, "max_run_seconds": 900}, "usage": {"max_success_age_seconds": 18000, "max_run_seconds": 3600}}'::jsonb);
INSERT INTO public.worker_fleet_requirements VALUES('server_tg',1,180,'{"poll": {"max_success_age_seconds": 180, "max_run_seconds": 180}}'::jsonb);
INSERT INTO public.worker_fleet_requirements VALUES('supplier-reconciliation',1,180,'{"reconcile": {"max_success_age_seconds": 900, "max_run_seconds": 600}}'::jsonb);
INSERT INTO public.worker_fleet_probes VALUES('refill_instant',300,1000,'SELECT count(*) FILTER(WHERE status=''pending'' AND execution_time<=now()) AS backlog,
 min(execution_time) FILTER(WHERE status=''pending'' AND execution_time<=now()) AS oldest_at,
 count(*) FILTER(WHERE status IN (''processing'',''routing'') AND coalesce(processing_since,updated_at,created_at)<now()-interval ''15 minutes'') AS issues
 FROM public.topup_executions WHERE execution_type=''refill_instant''');
INSERT INTO public.worker_fleet_probes VALUES('refill_mini',300,1000,'SELECT count(*) FILTER(WHERE status=''pending'' AND execution_time<=now()) AS backlog,
 min(execution_time) FILTER(WHERE status=''pending'' AND execution_time<=now()) AS oldest_at,
 count(*) FILTER(WHERE status IN (''processing'',''routing'') AND coalesce(processing_since,updated_at,created_at)<now()-interval ''15 minutes'') AS issues
 FROM public.topup_executions WHERE execution_type=''refill_mini''');
INSERT INTO public.worker_fleet_probes VALUES('refill_custom',300,1000,'SELECT count(*) FILTER(WHERE status=''pending'' AND execution_time<=now()) AS backlog,
 min(execution_time) FILTER(WHERE status=''pending'' AND execution_time<=now()) AS oldest_at,
 count(*) FILTER(WHERE status IN (''processing'',''routing'') AND coalesce(processing_since,updated_at,created_at)<now()-interval ''15 minutes'') AS issues
 FROM public.topup_executions WHERE execution_type=''refill_custom''');
INSERT INTO public.worker_fleet_probes VALUES('supplier_reconciliation',600,100,'SELECT count(*) FILTER(WHERE outcome IN (''unknown'',''pending'')) AS backlog,
 min(next_check_at) FILTER(WHERE outcome IN (''unknown'',''pending'') AND next_check_at<=now()) AS oldest_at,
 count(*) FILTER(WHERE outcome=''operator'' OR (lease_until IS NOT NULL AND lease_until<now() AND outcome IN (''unknown'',''pending''))) AS issues
 FROM public.refill_supplier_submissions');
INSERT INTO public.worker_fleet_probes VALUES('unresolved_holds',600,100,'SELECT count(*) AS backlog,min(expires_at) AS oldest_at,count(*) FILTER(WHERE carrier_in_flight) AS issues
 FROM public.wallet_holds WHERE status=''active'' AND expires_at<now()');
INSERT INTO public.worker_fleet_probes VALUES('payout_reconciliation',3600,100,'SELECT count(*) FILTER(WHERE status IN (''pending'',''processing'',''reconciliation_required'')) AS backlog,
 min(created_at) FILTER(WHERE status IN (''pending'',''processing'')) AS oldest_at,
 count(*) FILTER(WHERE status=''reconciliation_required'' OR (status=''processing'' AND claimed_at<now()-interval ''30 minutes'') OR (status=''failed'' AND updated_at>now()-interval ''24 hours'')) AS issues
 FROM public.wallet_refund_items');
INSERT INTO public.worker_fleet_probes VALUES('esim_orders',600,100,'SELECT count(*) FILTER(WHERE status IN (''pending'',''processing'')) AS backlog,
 min(created_at) FILTER(WHERE status IN (''pending'',''processing'')) AS oldest_at,
 count(*) FILTER(WHERE status=''processing'' AND updated_at<now()-interval ''15 minutes'') AS issues FROM public.esim_orders');
INSERT INTO public.worker_fleet_probes VALUES('voucher_requests',60,1000,'SELECT count(*) AS backlog,min(due_at) FILTER(WHERE due_at<=now()) AS oldest_at,0::bigint AS issues
 FROM public.offline_voucher_requests WHERE status=''open''');
INSERT INTO public.worker_fleet_probes VALUES('voucher_purchase_jobs',600,100,'SELECT count(*) FILTER(WHERE status IN (''queued'',''claimed'')) AS backlog,
 min(requested_at) FILTER(WHERE status IN (''queued'',''claimed'')) AS oldest_at,
 count(*) FILTER(WHERE status=''failed'' OR (status=''claimed'' AND claimed_at<now()-interval ''15 minutes'')) AS issues FROM public.offline_voucher_purchase_jobs');
INSERT INTO public.worker_fleet_probes VALUES('notification_dispatch',300,1000,'SELECT count(*) FILTER(WHERE state IN (''pending'',''leased'')) AS backlog,
 min(next_attempt_at) FILTER(WHERE state=''pending'' AND next_attempt_at<=now()) AS oldest_at,
 count(*) FILTER(WHERE state IN (''unknown'',''failed'') OR (state=''leased'' AND lease_until<now())) AS issues FROM public.notification_dispatch_jobs');
INSERT INTO public.worker_fleet_probes VALUES('admin_email',600,100,'SELECT count(*) FILTER(WHERE status IN (''queued'',''sending'')) AS backlog,
 min(created_at) FILTER(WHERE status IN (''queued'',''sending'')) AS oldest_at,
 count(*) FILTER(WHERE status=''failed'' AND created_at>now()-interval ''24 hours'') AS issues FROM public.admin_emails');
INSERT INTO public.worker_fleet_probes VALUES('second_number_purchases',900,100,'SELECT count(*) FILTER(WHERE state IN (''submitting'',''provisioning'',''reconciliation'')) AS backlog,
 min(updated_at) FILTER(WHERE state IN (''submitting'',''provisioning'',''reconciliation'')) AS oldest_at,
 count(*) FILTER(WHERE state=''reconciliation'') AS issues FROM public.second_number_orders');
INSERT INTO public.worker_fleet_probes VALUES('second_number_renewals',3600,100,'SELECT count(*) AS backlog,min(renews_at) AS oldest_at,0::bigint AS issues
 FROM public.virtual_did_numbers WHERE lifecycle_managed AND auto_renew AND status IN (''active'',''suspended'') AND renews_at<now()');
INSERT INTO public.worker_fleet_probes VALUES('account_purge',3600,100,'SELECT count(*) FILTER(WHERE state IN (''queued'',''processing'',''failed'')) AS backlog,
 min(created_at) FILTER(WHERE state IN (''queued'',''processing'')) AS oldest_at,
 count(*) FILTER(WHERE state=''failed'' OR (state=''processing'' AND lease_until<now())) AS issues FROM public.account_purge_jobs');
INSERT INTO public.worker_fleet_cron VALUES('check-rate-limit-health',9000);
INSERT INTO public.worker_fleet_cron VALUES('check-scheduled-jobs-health',9000);
INSERT INTO public.worker_fleet_cron VALUES('check-worker-heartbeat',1200);
INSERT INTO public.worker_fleet_cron VALUES('emit-carrier-self-service-advice',180000);
INSERT INTO public.worker_fleet_cron VALUES('emit-urgent-deactivation-alerts',9000);
INSERT INTO public.worker_fleet_cron VALUES('emit-weekly-notification-digests-hourly',9000);
INSERT INTO public.worker_fleet_cron VALUES('process-alert-outbox-every-minute',300);
INSERT INTO public.worker_fleet_cron VALUES('process-hourly-notifications',9000);
INSERT INTO public.worker_fleet_cron VALUES('prune-database-logs-daily',180000);
INSERT INTO public.worker_fleet_cron VALUES('prune-rate-limit-data',180000);
INSERT INTO public.worker_fleet_cron VALUES('purge-deleted-accounts-hourly',9000);
INSERT INTO public.worker_fleet_cron VALUES('reap-stale-esim-orders-hourly',9000);
INSERT INTO public.worker_fleet_cron VALUES('reap-stuck-executions',900);
INSERT INTO public.worker_fleet_cron VALUES('refill-pipeline-health',9000);
INSERT INTO public.worker_fleet_cron VALUES('refresh-fx-rates',180000);
INSERT INTO public.worker_fleet_cron VALUES('refresh-offer-price-watch',180000);
INSERT INTO public.worker_fleet_cron VALUES('refresh-provider-offers',180000);
INSERT INTO public.worker_fleet_cron VALUES('refresh-usage-forecasts',180000);
INSERT INTO public.worker_fleet_cron VALUES('run-auto-rescue',9000);
INSERT INTO public.worker_fleet_cron VALUES('sweep-offline-vouchers',180000);
INSERT INTO public.worker_fleet_cron VALUES('sync-affiliate-network',180000);
INSERT INTO public.worker_fleet_cron VALUES('sync-esim-catalogue',180000);

INSERT INTO public.worker_fleet_probes VALUES('wallet_reconciliation',3600,100,'SELECT 0::bigint AS backlog,NULL::timestamptz AS oldest_at,count(*) AS issues FROM public.wallet_reconciliation WHERE drift<>0');
INSERT INTO public.worker_fleet_probes VALUES('call_billing',3600,100,'SELECT count(*) FILTER(WHERE billing_state IN (''reserved'',''submitting'',''active'',''termination_pending'',''reconciliation_required'')) AS backlog,min(created_at) FILTER(WHERE billing_state IN (''reserved'',''submitting'',''active'',''termination_pending'',''reconciliation_required'')) AS oldest_at,count(*) FILTER(WHERE billing_state=''reconciliation_required'') AS issues FROM public.call_records');
INSERT INTO public.worker_fleet_probes VALUES('notification_scheduler_failures',3600,100,'SELECT 0::bigint AS backlog,NULL::timestamptz AS oldest_at,count(*) AS issues FROM public.system_alerts WHERE kind=''notification_scheduler_failed'' AND created_at>now()-interval ''2 hours''');
INSERT INTO public.worker_fleet_probes VALUES('whatsapp_attempts',600,1000,'SELECT count(*) FILTER(WHERE state IN (''pending'',''accepted'')) AS backlog,min(created_at) FILTER(WHERE state IN (''pending'',''accepted'')) AS oldest_at,count(*) FILTER(WHERE state=''unknown'' OR (state=''failed'' AND created_at>now()-interval ''24 hours'')) AS issues FROM public.whatsapp_message_attempts');
INSERT INTO public.worker_fleet_probes VALUES('notification_targets',900,1000,'SELECT count(*) FILTER(WHERE state IN (''pending'',''attempting'')) AS backlog,min(updated_at) FILTER(WHERE state IN (''pending'',''attempting'')) AS oldest_at,count(*) FILTER(WHERE state IN (''unknown'',''failed'') OR (state=''attempting'' AND lease_until<now())) AS issues FROM public.notification_channel_targets');
INSERT INTO public.worker_fleet_probes VALUES('liveness_reconciliation',900,1000,'SELECT count(*) FILTER(WHERE status IN (''reserved'',''dispatching'',''pending'',''reconciliation_required'')) AS backlog,min(created_at) FILTER(WHERE status IN (''reserved'',''dispatching'',''pending'',''reconciliation_required'')) AS oldest_at,count(*) FILTER(WHERE status=''reconciliation_required'' OR settlement_status=''reconciliation_required'') AS issues FROM public.line_verification_attempts');
INSERT INTO public.worker_fleet_probes VALUES('second_number_release',900,1000,'SELECT count(*) AS backlog,min(updated_at) AS oldest_at,0::bigint AS issues FROM public.virtual_did_numbers WHERE lifecycle_managed AND status=''release_pending''');
INSERT INTO public.worker_fleet_cron VALUES('recover-expired-wallet-holds',900);
INSERT INTO public.worker_fleet_probes VALUES('approval_quotes',300,1000,'SELECT count(*) FILTER(WHERE status IN (''queued'',''processing'')) AS backlog,min(created_at) FILTER(WHERE status IN (''queued'',''processing'')) AS oldest_at,count(*) FILTER(WHERE status=''failed'' AND created_at>now()-interval ''24 hours'') AS issues FROM public.refill_approval_quotes');
INSERT INTO public.worker_fleet_probes VALUES('active_esim_catalogue',300,1000,'SELECT 0::bigint AS backlog,NULL::timestamptz AS oldest_at,count(*) AS issues FROM public.esim_suppliers WHERE is_active AND (last_sync_at IS NULL OR last_sync_at<now()-interval ''8 hours'' OR last_sync_status IS DISTINCT FROM ''ok'')');
INSERT INTO public.worker_fleet_probes VALUES('active_offer_catalogue',300,1000,'SELECT 0::bigint AS backlog,NULL::timestamptz AS oldest_at,count(*) AS issues FROM public.carrier_provider_map m JOIN public.supplier_policy p ON p.provider=m.provider JOIN public.carriers c ON c.id=m.carrier_id WHERE m.is_enabled AND p.is_globally_enabled AND c.is_supported AND NOT EXISTS(SELECT 1 FROM public.provider_offers_cache o WHERE o.api_provider=m.provider AND o.country_code=m.provider_country_code AND o.carrier_code=m.provider_carrier_code AND o.refreshed_at>now()-interval ''3 hours'')');
ALTER TABLE public.worker_fleet_requirements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.worker_fleet_runtime ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.worker_fleet_probes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.worker_fleet_cron ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.worker_fleet_incidents ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.worker_fleet_requirements,public.worker_fleet_runtime,public.worker_fleet_probes,
 public.worker_fleet_cron,public.worker_fleet_incidents FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.report_worker_health(p_worker text,p_instance uuid,p_started_at timestamptz,
 p_sequence bigint,p_version text,p_lanes jsonb) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE req public.worker_fleet_requirements; prev public.worker_fleet_runtime; item record; prior jsonb;
 normalized jsonb:='{}'; info jsonb; completed bigint; failed bigint; elapsed bigint;
BEGIN
 -- session_user/current role is not the definer identity; service claims are mandatory.
 IF coalesce(auth.role(),'')<>'service_role' THEN RAISE EXCEPTION 'Service access required' USING ERRCODE='42501'; END IF;
 SELECT * INTO req FROM public.worker_fleet_requirements WHERE worker=p_worker;
 IF req.worker IS NULL OR p_instance IS NULL OR p_started_at IS NULL OR p_started_at>clock_timestamp()+interval '1 minute'
  OR p_sequence IS NULL OR p_sequence<1 OR p_version IS NULL OR p_version !~ '^[0-9a-f]{64}$'
  OR jsonb_typeof(p_lanes) IS DISTINCT FROM 'object' OR pg_column_size(p_lanes)>8192
  OR (SELECT array_agg(key ORDER BY key) FROM jsonb_object_keys(p_lanes) key)
     IS DISTINCT FROM (SELECT array_agg(key ORDER BY key) FROM jsonb_object_keys(req.lanes) key) THEN
   RAISE EXCEPTION 'Invalid telemetry' USING ERRCODE='22023';
 END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('fleet:'||p_worker,0));
 SELECT * INTO prev FROM public.worker_fleet_runtime WHERE worker=p_worker;
 IF prev.worker IS NOT NULL AND ((prev.instance=p_instance AND p_sequence<=prev.sequence)
   OR (prev.instance<>p_instance AND p_started_at<=prev.started_at)) THEN RETURN false; END IF;
 FOR item IN SELECT * FROM jsonb_each(p_lanes) LOOP
  info:=item.value;
  IF jsonb_typeof(info) IS DISTINCT FROM 'object' OR (SELECT count(*) FROM jsonb_object_keys(info))<>4
   OR NOT info ?& ARRAY['phase','completed','failed','running_seconds']
   OR info->>'phase' NOT IN ('starting','running','idle','error') OR info->>'phase' IS NULL
   OR coalesce(info->>'completed','') !~ '^[0-9]{1,12}$'
   OR coalesce(info->>'failed','') !~ '^[0-9]{1,12}$'
   OR coalesce(info->>'running_seconds','') !~ '^[0-9]{1,9}$' THEN
   RAISE EXCEPTION 'Invalid lane telemetry' USING ERRCODE='22023';
  END IF;
  completed:=(info->>'completed')::bigint; failed:=(info->>'failed')::bigint; elapsed:=(info->>'running_seconds')::bigint;
  prior:=CASE WHEN prev.instance=p_instance THEN prev.lanes->item.key END;
  IF completed<coalesce((prior->>'completed')::bigint,0) OR failed<coalesce((prior->>'failed')::bigint,0) THEN
   RAISE EXCEPTION 'Regressing telemetry' USING ERRCODE='22023'; END IF;
  normalized:=normalized||jsonb_build_object(item.key,info||jsonb_build_object('last_success_at',
   CASE WHEN completed>coalesce((prior->>'completed')::bigint,0) THEN to_jsonb(clock_timestamp()) ELSE prior->'last_success_at' END));
 END LOOP;
 INSERT INTO public.worker_fleet_runtime VALUES(p_worker,p_instance,p_started_at,p_sequence,p_version,clock_timestamp(),normalized)
 ON CONFLICT(worker) DO UPDATE SET instance=excluded.instance,started_at=excluded.started_at,sequence=excluded.sequence,
 version=excluded.version,last_seen_at=excluded.last_seen_at,lanes=excluded.lanes;
 RETURN true;
END $$;

CREATE FUNCTION public.worker_fleet_runtime_snapshot() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE req record; runtime public.worker_fleet_runtime; lane record; info jsonb; state text;
 output jsonb:='[]'; lanes jsonb; backlog bigint; oldest timestamptz; issues bigint; age numeric;
 job record; run record; bad integer; good integer;
BEGIN
 FOR req IN SELECT * FROM public.worker_fleet_requirements ORDER BY worker LOOP
  SELECT * INTO runtime FROM public.worker_fleet_runtime WHERE worker=req.worker;
  lanes:='{}'; state:='healthy';
  IF runtime.worker IS NULL THEN state:='missing';
  ELSIF runtime.last_seen_at<now()-make_interval(secs=>req.stale_seconds) THEN state:='stale'; END IF;
  FOR lane IN SELECT * FROM jsonb_each(req.lanes) LOOP
   info:=runtime.lanes->lane.key;
   IF info IS NULL OR info->>'phase' IN ('starting','error') OR info->>'phase' IS NULL
    OR (info->>'running_seconds')::bigint>(lane.value->>'max_run_seconds')::integer
    OR (info->>'last_success_at') IS NULL
    OR ((info->>'last_success_at') IS NULL AND runtime.started_at<now()-make_interval(secs=>(lane.value->>'max_run_seconds')::integer))
    OR (info->>'last_success_at')::timestamptz<now()-make_interval(secs=>(lane.value->>'max_success_age_seconds')::integer)
   THEN IF state='healthy' THEN state:='stalled'; END IF;
    lanes:=lanes||jsonb_build_object(lane.key,'degraded');
   ELSE lanes:=lanes||jsonb_build_object(lane.key,'healthy'); END IF;
  END LOOP;
  output:=output||jsonb_build_array(jsonb_build_object('key','worker:'||req.worker,'kind','worker','state',state,
   'version',runtime.version,'last_seen_at',runtime.last_seen_at,'lanes',lanes));
 END LOOP;
 FOR req IN SELECT * FROM public.worker_fleet_cron ORDER BY name LOOP
  BEGIN
   EXECUTE 'SELECT jobid,active FROM cron.job WHERE jobname=$1' INTO job USING req.name;
   IF job.jobid IS NULL OR job.active IS DISTINCT FROM true THEN state:='missing';
   ELSE
    EXECUTE 'SELECT status,start_time,end_time FROM cron.job_run_details WHERE jobid=$1 ORDER BY runid DESC LIMIT 1' INTO run USING job.jobid;
    IF run.start_time IS NULL THEN state:='unknown';
    ELSIF run.status NOT IN ('succeeded','running','starting','connecting','sending') THEN state:='failed';
    ELSIF coalesce(run.end_time,run.start_time)<now()-make_interval(secs=>req.max_age_seconds) THEN state:='stale';
    ELSIF run.status<>'succeeded' AND run.start_time<now()-interval '15 minutes' THEN state:='stalled';
    ELSE state:='healthy'; END IF;
   END IF;
   output:=output||jsonb_build_array(jsonb_build_object('key','cron:'||req.name,'kind','cron','state',state));
  EXCEPTION WHEN OTHERS THEN
   output:=output||jsonb_build_array(jsonb_build_object('key','cron:'||req.name,'kind','cron','state','unknown','code','cron_unavailable'));
  END;
 END LOOP;
 RETURN output;
END $$;

CREATE FUNCTION public.worker_fleet_snapshot() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE req record; runtime public.worker_fleet_runtime; lane record; info jsonb; state text;
 output jsonb:='[]'; lanes jsonb; backlog bigint; oldest timestamptz; issues bigint; age numeric;
 job record; run record; bad integer; good integer;
BEGIN
 output:=public.worker_fleet_runtime_snapshot();
 FOR req IN SELECT * FROM public.worker_fleet_probes ORDER BY key LOOP
  BEGIN
   EXECUTE req.query_sql INTO backlog,oldest,issues;
   age:=greatest(0,extract(epoch FROM now()-oldest));
   state:=CASE WHEN backlog IS NULL OR issues IS NULL THEN 'unknown'
     WHEN backlog>=req.max_backlog OR issues>0 OR (oldest IS NOT NULL AND age>req.max_age_seconds) THEN 'backlog' ELSE 'healthy' END;
   output:=output||jsonb_build_array(jsonb_build_object('key','probe:'||req.key,'kind','probe','state',state,
     'backlog',backlog,'oldest_age_seconds',CASE WHEN oldest IS NOT NULL THEN age END,'issues',issues));
  EXCEPTION WHEN OTHERS THEN
   output:=output||jsonb_build_array(jsonb_build_object('key','probe:'||req.key,'kind','probe','state','unknown','code','probe_unavailable'));
  END;
 END LOOP;
 SELECT count(*) FILTER(WHERE e->>'state'<>'healthy'),count(*) FILTER(WHERE e->>'state'='healthy') INTO bad,good FROM jsonb_array_elements(output) e;
 RETURN jsonb_build_object('manifest_version',1,'status',CASE WHEN bad=0 THEN 'healthy' ELSE 'degraded' END,
  'healthy',good,'unhealthy',bad,'components',output,'checked_at',now());
END $$;

CREATE FUNCTION public.worker_fleet_cached_snapshot() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE cached public.worker_fleet_observation; output jsonb; bad integer; good integer;
BEGIN
 output:=public.worker_fleet_runtime_snapshot();
 SELECT * INTO cached FROM public.worker_fleet_observation WHERE singleton;
 IF cached.observed_at IS NULL OR cached.observed_at<now()-interval '15 minutes' THEN
  output:=output||jsonb_build_array(jsonb_build_object('key','probe:observation','kind','probe','state','unknown','code','observation_stale'));
 ELSE
  output:=output||coalesce((SELECT jsonb_agg(e) FROM jsonb_array_elements(cached.payload->'components') e WHERE e->>'kind'='probe'),'[]'::jsonb);
 END IF;
 SELECT count(*) FILTER(WHERE e->>'state'<>'healthy'),count(*) FILTER(WHERE e->>'state'='healthy') INTO bad,good FROM jsonb_array_elements(output) e;
 RETURN jsonb_build_object('manifest_version',1,'status',CASE WHEN bad=0 THEN 'healthy' ELSE 'degraded' END,
  'healthy',good,'unhealthy',bad,'components',output,'checked_at',now(),'queues_observed_at',cached.observed_at);
END $$;

CREATE FUNCTION public.get_worker_fleet_health() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF coalesce(auth.role(),'')<>'service_role' THEN RAISE EXCEPTION 'Service access required' USING ERRCODE='42501'; END IF;
 RETURN public.worker_fleet_cached_snapshot();
END $$;
CREATE FUNCTION public.admin_worker_fleet_health() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN PERFORM public.assert_admin(); RETURN public.worker_fleet_cached_snapshot(); END $$;

CREATE FUNCTION public.check_worker_fleet_health() RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE snapshot jsonb; item jsonb; prev public.worker_fleet_incidents;
BEGIN
 -- current_user is the definer; use session_user plus claims for the cron/service boundary.
 IF session_user<>'postgres' AND coalesce(auth.role(),'')<>'service_role' THEN
  RAISE EXCEPTION 'Service access required' USING ERRCODE='42501'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('worker-fleet-alert-sweep',0));
 snapshot:=public.worker_fleet_snapshot();
 INSERT INTO public.worker_fleet_observation(singleton,payload,observed_at) VALUES(true,snapshot,now())
 ON CONFLICT(singleton) DO UPDATE SET payload=excluded.payload,observed_at=excluded.observed_at;
 FOR item IN SELECT * FROM jsonb_array_elements(snapshot->'components') LOOP
  BEGIN
   SELECT * INTO prev FROM public.worker_fleet_incidents WHERE key=item->>'key';
   IF item->>'state'<>'healthy' AND (prev.last_alert_at IS NULL OR prev.last_alert_at<now()-interval '6 hours') THEN
    INSERT INTO public.system_alerts(kind,message,details) VALUES('worker_fleet_degraded','Required background processing needs attention',
      jsonb_build_object('manifest_version',1,'component',item->>'key','state',item->>'state',
        'backlog',item->'backlog','issues',item->'issues','oldest_age_seconds',item->'oldest_age_seconds'));
    INSERT INTO public.worker_fleet_incidents(key,state,last_checked_at,last_alert_at)
      VALUES(item->>'key',item->>'state',now(),now())
    ON CONFLICT(key) DO UPDATE SET state=excluded.state,last_checked_at=excluded.last_checked_at,last_alert_at=excluded.last_alert_at,resolved_at=NULL;
   ELSE
    INSERT INTO public.worker_fleet_incidents(key,state,last_checked_at,resolved_at)
      VALUES(item->>'key',item->>'state',now(),CASE WHEN item->>'state'='healthy' THEN now() END)
    ON CONFLICT(key) DO UPDATE SET state=excluded.state,last_checked_at=excluded.last_checked_at,
      resolved_at=CASE WHEN excluded.state='healthy' THEN coalesce(worker_fleet_incidents.resolved_at,now()) END;
   END IF;
  EXCEPTION WHEN OTHERS THEN RAISE WARNING 'Fleet incident persistence failed for component % [code %]',item->>'key',SQLSTATE;
  END;
 END LOOP;
END $$;

-- Existing ten-minute pg_cron entry point now checks the entire fleet.
CREATE OR REPLACE FUNCTION public.check_worker_heartbeat_health() RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF session_user<>'postgres' AND coalesce(auth.role(),'')<>'service_role' THEN
  RAISE EXCEPTION 'Service access required' USING ERRCODE='42501'; END IF;
 PERFORM public.check_worker_fleet_health();
END $$;
REVOKE ALL ON FUNCTION public.worker_fleet_snapshot(),public.worker_fleet_runtime_snapshot(),public.worker_fleet_cached_snapshot(),
 public.report_worker_health(text,uuid,timestamptz,bigint,text,jsonb),public.get_worker_fleet_health(),
 public.admin_worker_fleet_health(),public.check_worker_fleet_health(),public.check_worker_heartbeat_health()
 FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.report_worker_health(text,uuid,timestamptz,bigint,text,jsonb),
 public.get_worker_fleet_health(),public.check_worker_fleet_health(),public.check_worker_heartbeat_health() TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_worker_fleet_health() TO authenticated;
COMMIT;
