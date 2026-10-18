BEGIN;

-- Owner invoker core supports the checked admin facade and trusted cron facade.
CREATE OR REPLACE FUNCTION public.prune_database_logs_internal(p_cron_retention_days integer,p_alerts_retention_days integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE c integer; a integer;
BEGIN
  IF current_user<>'postgres' THEN RAISE EXCEPTION 'Maintenance owner required' USING ERRCODE='42501'; END IF;
  IF p_cron_retention_days IS NULL OR p_cron_retention_days<3 OR p_cron_retention_days>36500
    OR p_alerts_retention_days IS NULL OR p_alerts_retention_days<7 OR p_alerts_retention_days>36500 THEN
    RAISE EXCEPTION 'Invalid retention bounds' USING ERRCODE='22023';
  END IF;
  DELETE FROM cron.job_run_details WHERE start_time<now()-p_cron_retention_days*interval '1 day';
  GET DIAGNOSTICS c=ROW_COUNT;
  DELETE FROM public.system_alerts WHERE created_at<now()-p_alerts_retention_days*interval '1 day';
  GET DIAGNOSTICS a=ROW_COUNT;
  RETURN jsonb_build_object('status','success','cron_runs_pruned',c,'alerts_pruned',a,
    'cron_retention_days',p_cron_retention_days,'alerts_retention_days',p_alerts_retention_days,
    'cron_cutoff',now()-p_cron_retention_days*interval '1 day',
    'alerts_cutoff',now()-p_alerts_retention_days*interval '1 day','executed_at',now());
END;
$$;

CREATE OR REPLACE FUNCTION public.prune_database_logs(p_cron_retention_days integer DEFAULT 14,p_alerts_retention_days integer DEFAULT 90)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF NOT coalesce((current_setting('role',true)='service_role' AND auth.role()='service_role')
    OR (session_user='postgres' AND current_setting('role',true) IN ('none','postgres')),false) THEN
    RAISE EXCEPTION 'Trusted maintenance role required' USING ERRCODE='42501';
  END IF;
  RETURN public.prune_database_logs_internal(p_cron_retention_days,p_alerts_retention_days);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_prune_database_logs(p_cron_retention_days integer DEFAULT 14,p_alerts_retention_days integer DEFAULT 90)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
  PERFORM public.assert_admin();
  IF auth.role()='service_role' AND current_setting('role',true)<>'service_role' THEN
    RAISE EXCEPTION 'Service identity mismatch' USING ERRCODE='42501'; END IF;
  result:=public.prune_database_logs_internal(p_cron_retention_days,p_alerts_retention_days);
  PERFORM public.admin_log(p_action=>'prune_database_logs',p_target_type=>'maintenance',
    p_target_id=>'database_logs',p_after=>result,p_note=>'Retention maintenance');
  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.check_rate_limit_health()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE n bigint;
BEGIN
  IF NOT coalesce((current_setting('role',true)='service_role' AND auth.role()='service_role')
    OR (session_user='postgres' AND current_setting('role',true) IN ('none','postgres')),false) THEN
    RAISE EXCEPTION 'Trusted maintenance role required' USING ERRCODE='42501';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('keepsims:rate-limit-health',0));
  SELECT count(*) INTO n FROM public.security_logs
    WHERE event_type='rate_limited' AND created_at>now()-interval '1 hour';
  IF n>=20 AND NOT EXISTS(SELECT 1 FROM public.system_alerts
    WHERE kind='sustained_rate_limits' AND created_at>now()-interval '6 hours') THEN
    INSERT INTO public.system_alerts(kind,message,details)
    VALUES('sustained_rate_limits','Sustained rate limit rejections',
      jsonb_build_object('severity','warning','rejections_past_hour',n));
  END IF;
END;
$$;

-- Targets and actor snapshots deliberately survive Auth deletion. Client access
-- is through existing checked RPCs; this table is not an API write surface.
CREATE TABLE public.account_purge_jobs(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deletion_id uuid NOT NULL UNIQUE REFERENCES public.account_deletions(id),
  target_user_id uuid NOT NULL,
  actor_id uuid,
  actor_email text NOT NULL,
  reason text,
  state text NOT NULL DEFAULT 'queued' CHECK(state IN ('queued','processing','failed','completed')),
  claim_token uuid,
  lease_until timestamptz,
  attempt_count integer NOT NULL DEFAULT 0,
  error_code text,
  dispatched_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.account_purge_jobs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.account_purge_jobs FROM PUBLIC,anon,authenticated,service_role;
-- The existing user-facing read-own policy remains; clients cannot forge state.
REVOKE INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER ON public.account_deletions FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.log_account_purge_job(p_job_id uuid,p_action text,p_note text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE j public.account_purge_jobs;
BEGIN
  IF current_user<>'postgres' THEN RAISE EXCEPTION 'Purge owner required' USING ERRCODE='42501'; END IF;
  SELECT * INTO STRICT j FROM public.account_purge_jobs WHERE id=p_job_id;
  INSERT INTO public.admin_audit_log(actor_id,actor_email,action,target_type,target_id,after_value,note)
  VALUES(CASE WHEN EXISTS(SELECT 1 FROM auth.users WHERE id=j.actor_id) THEN j.actor_id END,
    j.actor_email,p_action,'user',j.target_user_id::text,
    jsonb_build_object('job_id',j.id,'state',j.state,'error_code',j.error_code,
      'authorized_actor_id',j.actor_id,'attempt_count',j.attempt_count),p_note);
END;
$$;

CREATE FUNCTION public.dispatch_account_purge_job(p_job_id uuid)
RETURNS bigint LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE secret text; request_id bigint;
BEGIN
  IF current_user<>'postgres' THEN RAISE EXCEPTION 'Purge owner required' USING ERRCODE='42501'; END IF;
  SELECT decrypted_secret INTO secret FROM vault.decrypted_secrets WHERE name='dispatch_shared_secret';
  IF coalesce(secret,'')='' THEN RAISE EXCEPTION 'Purge dispatch is not configured' USING ERRCODE='55000'; END IF;
  SELECT net.http_post(url:='https://zwxswagokhgbuzrrbnhr.supabase.co/functions/v1/purge-accounts',
    headers:=jsonb_build_object('Content-Type','application/json','x-keep-sims-secret',secret),
    body:=jsonb_build_object('job_id',p_job_id),timeout_milliseconds:=15000) INTO request_id;
  UPDATE public.account_purge_jobs SET dispatched_at=now() WHERE id=p_job_id;
  RETURN request_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_purge_user_account(p_user_id uuid,p_confirm_user_id text,
  p_reason text DEFAULT 'Manual admin purge with user_id verification challenge')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid; email text; target_email text; d uuid; j public.account_purge_jobs; req bigint;
BEGIN
  actor:=public.assert_admin();
  IF actor IS NULL THEN RAISE EXCEPTION 'Named admin session required' USING ERRCODE='KS460'; END IF;
  IF p_user_id IS NULL OR p_confirm_user_id IS NULL OR lower(btrim(p_confirm_user_id))<>p_user_id::text THEN
    RAISE EXCEPTION 'User ID confirmation mismatch' USING ERRCODE='KS400'; END IF;
  IF actor=p_user_id THEN RAISE EXCEPTION 'Self purge is not an admin operation' USING ERRCODE='KS400'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('keepsims:account-purge:'||p_user_id,0));
  SELECT * INTO j FROM public.account_purge_jobs WHERE target_user_id=p_user_id AND state IN ('processing','completed');
  IF FOUND THEN RETURN jsonb_build_object('success',true,'status',j.state,'job_id',j.id,'user_id',p_user_id); END IF;
  SELECT u.email INTO target_email FROM auth.users u WHERE id=p_user_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Target user not found' USING ERRCODE='KS404'; END IF;
  SELECT p.email INTO email FROM public.profiles p WHERE p.id=actor;
  INSERT INTO public.account_deletions(user_id,email_hash,status,scheduled_purge_at,reason,actor_id,frozen_at)
  VALUES(p_user_id,encode(sha256(convert_to(lower(coalesce(target_email,p_user_id::text)),'UTF8')),'hex'),
    'frozen',now(),p_reason,actor,now())
  ON CONFLICT(user_id) DO UPDATE SET status=CASE WHEN public.account_deletions.status IN ('drained','draining')
      THEN public.account_deletions.status ELSE 'frozen' END,
    scheduled_purge_at=now(),reason=excluded.reason,actor_id=excluded.actor_id,updated_at=now()
  RETURNING id INTO d;
  UPDATE public.profiles SET is_suspended=true WHERE id=p_user_id;
  UPDATE public.scheduled_topups SET is_active=false WHERE user_id=p_user_id;
  INSERT INTO public.account_purge_jobs(deletion_id,target_user_id,actor_id,actor_email,reason)
  VALUES(d,p_user_id,actor,coalesce(email,'admin'),p_reason) ON CONFLICT(deletion_id) DO NOTHING;
  SELECT * INTO STRICT j FROM public.account_purge_jobs WHERE deletion_id=d FOR UPDATE;
  IF j.state='processing' OR j.state='completed' THEN
    RETURN jsonb_build_object('success',true,'status',j.state,'job_id',j.id,'user_id',p_user_id);
  END IF;
  UPDATE public.account_purge_jobs SET state='queued',error_code=NULL,actor_id=actor,actor_email=coalesce(email,'admin'),reason=p_reason,
    attempt_count=CASE WHEN j.state='failed' THEN 0 ELSE attempt_count END,updated_at=now() WHERE id=j.id;
  PERFORM public.admin_log(p_action=>'user.admin_purge_requested',p_target_type=>'user',p_target_id=>p_user_id::text,
    p_after=>jsonb_build_object('job_id',j.id,'state','queued'),p_note=>p_reason);
  BEGIN
    req:=public.dispatch_account_purge_job(j.id);
  EXCEPTION WHEN OTHERS THEN
    UPDATE public.account_purge_jobs SET state='failed',error_code='dispatch_failed',updated_at=now() WHERE id=j.id;
    PERFORM public.log_account_purge_job(j.id,'user.purge_failed','Dispatch failed');
    RETURN jsonb_build_object('success',false,'status','failed','job_id',j.id,'error','dispatch_failed');
  END;
  RETURN jsonb_build_object('success',true,'status','queued','job_id',j.id,'user_id',p_user_id,'net_request_id',req,
    'message','Purge requested; completion follows Storage and Auth deletion');
END;
$$;

CREATE OR REPLACE FUNCTION public.purge_deleted_accounts()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE d record; jid uuid; n integer:=0;
BEGIN
  IF NOT coalesce((current_setting('role',true)='service_role' AND auth.role()='service_role')
    OR (session_user='postgres' AND current_setting('role',true) IN ('none','postgres')),false) THEN
    RAISE EXCEPTION 'Trusted purge role required' USING ERRCODE='42501'; END IF;
  FOR d IN SELECT a.* FROM public.account_deletions a WHERE a.status IN ('requested','frozen','draining','drained')
    AND a.scheduled_purge_at<=now() AND a.user_id IS NOT NULL ORDER BY a.scheduled_purge_at LIMIT 50 FOR UPDATE SKIP LOCKED
  LOOP
    UPDATE public.account_deletions SET status='draining',frozen_at=coalesce(frozen_at,now()),updated_at=now() WHERE id=d.id;
    INSERT INTO public.account_purge_jobs(deletion_id,target_user_id,actor_id,actor_email,reason)
    VALUES(d.id,d.user_id,d.actor_id,coalesce((SELECT email FROM public.profiles WHERE id=d.actor_id),'scheduled_service'),d.reason)
    ON CONFLICT(deletion_id) DO NOTHING RETURNING id INTO jid;
    IF jid IS NOT NULL THEN PERFORM public.log_account_purge_job(jid,'user.purge_requested','Scheduled deletion'); END IF;
  END LOOP;
  FOR d IN SELECT * FROM public.account_purge_jobs WHERE (state IN ('queued','failed') OR (state='processing' AND lease_until<=now()))
    AND (dispatched_at IS NULL OR dispatched_at<now()-interval '1 hour') AND attempt_count<5
    ORDER BY created_at LIMIT 50 FOR UPDATE SKIP LOCKED
  LOOP
    BEGIN
      PERFORM public.dispatch_account_purge_job(d.id); n:=n+1;
    EXCEPTION WHEN OTHERS THEN
      UPDATE public.account_purge_jobs SET state='failed',error_code='dispatch_failed',dispatched_at=now(),updated_at=now() WHERE id=d.id;
      PERFORM public.log_account_purge_job(d.id,'user.purge_failed','Dispatch failed');
    END;
  END LOOP;
  RETURN jsonb_build_object('success',true,'queued_count',n,'purged_count',0);
END;
$$;

CREATE FUNCTION public.claim_account_purge_job(p_job_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE j public.account_purge_jobs; blocker text;
BEGIN
  IF NOT coalesce(current_setting('role',true)='service_role' AND auth.role()='service_role',false)
    AND NOT(session_user='postgres' AND current_setting('role',true) IN ('none','postgres')) THEN
    RAISE EXCEPTION 'Trusted purge role required' USING ERRCODE='42501'; END IF;
  SELECT * INTO j FROM public.account_purge_jobs WHERE id=p_job_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('claimed',false,'state','missing'); END IF;
  IF j.state='completed' THEN RETURN jsonb_build_object('claimed',false,'state','completed'); END IF;
  IF j.state='processing' AND j.lease_until>now() THEN RETURN jsonb_build_object('claimed',false,'state','busy'); END IF;
  IF j.attempt_count>=5 THEN RETURN jsonb_build_object('claimed',false,'state','review_required'); END IF;
  IF NOT EXISTS(SELECT 1 FROM public.account_deletions WHERE id=j.deletion_id AND user_id=j.target_user_id
    AND status IN ('frozen','draining','drained') AND scheduled_purge_at<=now()) THEN
    RETURN jsonb_build_object('claimed',false,'state','not_eligible'); END IF;
  -- Do not invent settlement/forfeiture or erase retained financial/provider
  -- evidence. These accounts need explicit reconciliation before final deletion.
  IF EXISTS(SELECT 1 FROM public.wallets WHERE user_id=j.target_user_id AND balance<>0)
    OR EXISTS(SELECT 1 FROM public.wallet_holds WHERE user_id=j.target_user_id AND status='active')
    OR EXISTS(SELECT 1 FROM public.wallet_refund_requests WHERE user_id=j.target_user_id)
    OR EXISTS(SELECT 1 FROM public.wallet_funding_lots WHERE user_id=j.target_user_id)
    OR EXISTS(SELECT 1 FROM public.wallet_transactions WHERE user_id=j.target_user_id)
    OR EXISTS(SELECT 1 FROM public.topup_executions WHERE user_id=j.target_user_id)
    OR EXISTS(SELECT 1 FROM public.user_esims WHERE user_id=j.target_user_id)
    OR EXISTS(SELECT 1 FROM public.virtual_did_numbers WHERE user_id=j.target_user_id)
    OR EXISTS(SELECT 1 FROM public.call_records WHERE user_id=j.target_user_id) THEN
    blocker:='retention_or_funding_review_required';
  END IF;
  IF blocker IS NOT NULL THEN
    UPDATE public.account_purge_jobs SET state='failed',error_code=blocker,attempt_count=attempt_count+1,updated_at=now() WHERE id=j.id;
    PERFORM public.log_account_purge_job(j.id,'user.purge_failed',blocker);
    RETURN jsonb_build_object('claimed',false,'state','review_required','error',blocker);
  END IF;
  UPDATE public.account_deletions SET status='drained',drained_at=coalesce(drained_at,now()),updated_at=now() WHERE id=j.deletion_id;
  UPDATE public.account_purge_jobs SET state='processing',claim_token=gen_random_uuid(),lease_until=now()+interval '10 minutes',
    attempt_count=attempt_count+1,error_code=NULL,updated_at=now() WHERE id=j.id RETURNING * INTO j;
  PERFORM public.log_account_purge_job(j.id,'user.purge_started','Storage and Auth deletion started');
  RETURN jsonb_build_object('claimed',true,'claim_token',j.claim_token,'user_id',j.target_user_id,'job_id',j.id);
END;
$$;

CREATE FUNCTION public.finish_account_purge_job(p_job_id uuid,p_claim_token uuid,p_success boolean,p_note text DEFAULT NULL)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE j public.account_purge_jobs;
BEGIN
  IF NOT coalesce(current_setting('role',true)='service_role' AND auth.role()='service_role',false)
    AND NOT(session_user='postgres' AND current_setting('role',true) IN ('none','postgres')) THEN
    RAISE EXCEPTION 'Trusted purge role required' USING ERRCODE='42501'; END IF;
  SELECT * INTO j FROM public.account_purge_jobs WHERE id=p_job_id FOR UPDATE;
  IF p_success IS NULL THEN RAISE EXCEPTION 'Purge outcome required' USING ERRCODE='22023'; END IF;
  IF j.state='completed' AND j.claim_token=p_claim_token THEN RETURN true; END IF;
  IF j.state IS DISTINCT FROM 'processing' OR j.claim_token IS DISTINCT FROM p_claim_token THEN RETURN false; END IF;
  IF p_success AND EXISTS(SELECT 1 FROM auth.users WHERE id=j.target_user_id) THEN
    RAISE EXCEPTION 'Auth deletion has not completed' USING ERRCODE='55000'; END IF;
  IF NOT p_success AND (p_note IS NULL OR p_note NOT IN ('storage_failed','auth_failed','completion_failed')) THEN
    RAISE EXCEPTION 'Invalid purge failure code' USING ERRCODE='22023'; END IF;
  UPDATE public.account_purge_jobs SET state=CASE WHEN p_success THEN 'completed' ELSE 'failed' END,
    error_code=CASE WHEN p_success THEN NULL ELSE p_note END,lease_until=NULL,
    completed_at=CASE WHEN p_success THEN now() END,updated_at=now() WHERE id=j.id;
  IF p_success THEN
    UPDATE public.account_deletions SET status='auth_deleted',purged_at=now(),auth_deleted_at=now(),updated_at=now()
      WHERE id=j.deletion_id;
  END IF;
  PERFORM public.log_account_purge_job(j.id,CASE WHEN p_success THEN 'user.purge_completed' ELSE 'user.purge_failed' END,
    CASE WHEN p_success THEN 'Storage and Auth deletion completed' ELSE p_note END);
  RETURN true;
END;
$$;

-- Retire the old raw-SQL Auth fallback; it bypasses Auth's supported lifecycle.
CREATE OR REPLACE FUNCTION public.delete_auth_user_by_id(p_user_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN RAISE EXCEPTION 'Use the claimed purge job and Auth Admin API' USING ERRCODE='42501'; END;
$$;

REVOKE ALL ON FUNCTION public.prune_database_logs_internal(integer,integer),public.log_account_purge_job(uuid,text,text),
  public.dispatch_account_purge_job(uuid),public.delete_auth_user_by_id(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.prune_database_logs_internal(integer,integer),public.log_account_purge_job(uuid,text,text),
  public.dispatch_account_purge_job(uuid) TO postgres;
REVOKE ALL ON FUNCTION public.prune_database_logs(integer,integer),public.check_rate_limit_health(),public.purge_deleted_accounts(),
  public.claim_account_purge_job(uuid),public.finish_account_purge_job(uuid,uuid,boolean,text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.prune_database_logs(integer,integer),public.check_rate_limit_health(),public.purge_deleted_accounts(),
  public.claim_account_purge_job(uuid),public.finish_account_purge_job(uuid,uuid,boolean,text) TO postgres,service_role;
REVOKE ALL ON FUNCTION public.admin_prune_database_logs(integer,integer),public.admin_purge_user_account(uuid,text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.admin_prune_database_logs(integer,integer),public.admin_purge_user_account(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_prune_database_logs(integer,integer) TO service_role;

-- Intentional source-controlled replacement of the deployed email v2 contract.
-- A sending/failed row is never automatically resent after an ambiguous call.
ALTER TABLE public.admin_emails ADD COLUMN claim_token uuid;
REVOKE INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER ON public.admin_emails FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.claim_admin_email(p_email_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE e public.admin_emails;
BEGIN
  IF NOT coalesce(current_setting('role',true)='service_role' AND auth.role()='service_role',false) THEN
    RAISE EXCEPTION 'Service role required' USING ERRCODE='42501'; END IF;
  UPDATE public.admin_emails SET status='sending',claim_token=gen_random_uuid(),error=NULL
    WHERE id=p_email_id AND status='queued' RETURNING * INTO e;
  IF NOT FOUND THEN RETURN jsonb_build_object('claimed',false); END IF;
  RETURN jsonb_build_object('claimed',true,'claim_token',e.claim_token,'email',to_jsonb(e));
END;
$$;

CREATE FUNCTION public.finish_admin_email(p_email_id uuid,p_claim_token uuid,p_sent boolean,
  p_provider_message_id text DEFAULT NULL,p_error_code text DEFAULT NULL)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF NOT coalesce(current_setting('role',true)='service_role' AND auth.role()='service_role',false) THEN
    RAISE EXCEPTION 'Service role required' USING ERRCODE='42501'; END IF;
  IF p_sent IS NULL OR (p_sent AND nullif(p_provider_message_id,'') IS NULL)
    OR (NOT p_sent AND (p_error_code IS NULL OR p_error_code NOT IN ('provider_rejected','provider_outcome_unknown'))) THEN
    RAISE EXCEPTION 'Invalid email outcome' USING ERRCODE='22023'; END IF;
  UPDATE public.admin_emails SET status=CASE WHEN p_sent THEN 'sent' ELSE 'failed' END,
    provider_message_id=p_provider_message_id,error=p_error_code,sent_at=CASE WHEN p_sent THEN now() END
    WHERE id=p_email_id AND claim_token=p_claim_token AND status='sending';
  RETURN FOUND;
END;
$$;

CREATE OR REPLACE FUNCTION public.kick_admin_email(p_email_id uuid)
RETURNS bigint LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE secret text; req bigint;
BEGIN
  IF current_user<>'postgres' AND NOT coalesce(current_user='service_role' AND auth.role()='service_role',false) THEN
    RAISE EXCEPTION 'Trusted email dispatcher required' USING ERRCODE='42501'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.admin_emails WHERE id=p_email_id AND status='queued') THEN
    RAISE EXCEPTION 'Email is not queued' USING ERRCODE='55000'; END IF;
  secret:=public.get_internal_secret('admin_email_secret');
  IF coalesce(secret,'')='' THEN RAISE EXCEPTION 'Admin email dispatch unavailable' USING ERRCODE='55000'; END IF;
  SELECT net.http_post(url:='https://zwxswagokhgbuzrrbnhr.supabase.co/functions/v1/send-admin-email',
    headers:=jsonb_build_object('Content-Type','application/json','x-sync-secret',secret),
    body:=jsonb_build_object('email_id',p_email_id),timeout_milliseconds:=30000) INTO req;
  RETURN req;
END;
$$;
REVOKE ALL ON FUNCTION public.claim_admin_email(uuid),public.finish_admin_email(uuid,uuid,boolean,text,text),
  public.kick_admin_email(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.claim_admin_email(uuid),public.finish_admin_email(uuid,uuid,boolean,text,text),
  public.kick_admin_email(uuid) TO service_role;

-- Serialize customer cancellation with the due-job eligibility check.
CREATE OR REPLACE FUNCTION "public"."cancel_account_deletion"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_existing RECORD;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  SELECT * INTO v_existing
  FROM public.account_deletions
  WHERE user_id = v_user_id AND status IN ('requested', 'frozen') FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'No active pending account deletion found.');
  END IF;

  IF v_existing.scheduled_purge_at <= clock_timestamp() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Grace period has expired. Deletion is already in progress.');
  END IF;

  UPDATE public.account_deletions
  SET status = 'cancelled', updated_at = clock_timestamp()
  WHERE id = v_existing.id;

  UPDATE public.profiles SET is_suspended = false WHERE id = v_user_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

COMMIT;
