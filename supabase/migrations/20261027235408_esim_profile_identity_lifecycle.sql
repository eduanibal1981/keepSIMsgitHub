-- ESIM-03: stable identity and evidence-only delivery. No wallet mutations.
BEGIN;
SET LOCAL lock_timeout='5s';
CREATE SCHEMA IF NOT EXISTS esim_private;
REVOKE ALL ON SCHEMA esim_private FROM PUBLIC,anon,authenticated;
GRANT USAGE ON SCHEMA esim_private TO service_role;

CREATE TABLE esim_private.accounts(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), account_key text NOT NULL UNIQUE,
  provider text NOT NULL CHECK(provider='esimaccess'), new_sales_enabled boolean NOT NULL DEFAULT false,
  next_request_at timestamptz NOT NULL DEFAULT now(),last_worker_seen_at timestamptz,last_cycle jsonb
);
INSERT INTO esim_private.accounts(account_key,provider) VALUES('primary','esimaccess');

ALTER TABLE public.user_esims
  ADD COLUMN supplier_account_id uuid REFERENCES esim_private.accounts(id),
  ADD COLUMN supplier_profile_ref text,
  ADD COLUMN profile_state text NOT NULL DEFAULT 'unknown',
  ADD COLUMN installation_state text NOT NULL DEFAULT 'unknown',
  ADD COLUMN bundle_state text NOT NULL DEFAULT 'unknown',
  ADD COLUMN provider_state jsonb NOT NULL DEFAULT '{}',
  ADD COLUMN plan_details jsonb,
  ADD COLUMN activation_trigger text NOT NULL DEFAULT 'unknown',
  ADD COLUMN first_activated_at timestamptz,
  ADD COLUMN confirmed_expires_at timestamptz,
  ADD COLUMN activation_deadline_at timestamptz,
  ADD COLUMN data_total_bytes bigint CHECK(data_total_bytes>=0),
  ADD COLUMN data_used_bytes bigint CHECK(data_used_bytes>=0),
  ADD COLUMN data_remaining_bytes bigint CHECK(data_remaining_bytes>=0),
  ADD COLUMN usage_observed_at timestamptz,
  ADD COLUMN last_observation_at timestamptz,
  ADD COLUMN last_usage_attempt_at timestamptz,
  ADD COLUMN usage_error_code text,
  ADD COLUMN qr_code_url text;
CREATE UNIQUE INDEX user_esims_supplier_identity ON public.user_esims(provider,supplier_account_id,supplier_profile_ref)
WHERE supplier_profile_ref IS NOT NULL;
CREATE INDEX IF NOT EXISTS user_esims_owner_idx ON public.user_esims(user_id);
-- Retain global ICCID uniqueness conservatively: a reuse collision needs support,
-- never an upsert that overwrites another owner's profile. Historical rows stay intact.

CREATE TABLE esim_private.profile_work(
  profile_id uuid PRIMARY KEY REFERENCES public.user_esims(id) ON DELETE CASCADE,
  next_check_at timestamptz DEFAULT now(), requested_at timestamptz,
  lease uuid, lease_until timestamptz, observation_started_at timestamptz,
  attempts integer NOT NULL DEFAULT 0, terminal_checks integer NOT NULL DEFAULT 0
);
ALTER TABLE public.esim_orders ADD COLUMN delivery_state text NOT NULL DEFAULT 'unverified';
CREATE TABLE esim_private.order_runs(
  order_id uuid PRIMARY KEY REFERENCES public.esim_orders(id) ON DELETE CASCADE,
  account_id uuid NOT NULL REFERENCES esim_private.accounts(id),
  submission_ref text NOT NULL UNIQUE,
  state text NOT NULL CHECK(state IN('prepared','submitted','reconciling','support_required','completed')),
  provider_order_ref text, hinted_order_ref text,
  submitted_at timestamptz, next_check_at timestamptz DEFAULT now(),
  lease uuid, lease_until timestamptz, attempts integer NOT NULL DEFAULT 0,
  error_code text, updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX esim_order_provider_ref ON esim_private.order_runs(account_id,provider_order_ref)
WHERE provider_order_ref IS NOT NULL;
CREATE INDEX esim_order_due ON esim_private.order_runs(next_check_at) WHERE state<>'completed';
CREATE INDEX esim_profile_due ON esim_private.profile_work(next_check_at);

DO $$ DECLARE n text; BEGIN
 FOREACH n IN ARRAY ARRAY['accounts','profile_work','order_runs'] LOOP
  EXECUTE format('ALTER TABLE esim_private.%I ENABLE ROW LEVEL SECURITY',n);
  EXECUTE format('REVOKE ALL ON esim_private.%I FROM PUBLIC,anon,authenticated',n);
  EXECUTE format('GRANT SELECT ON esim_private.%I TO service_role',n);
 END LOOP;
END $$;
CREATE FUNCTION esim_private.require_service() RETURNS void LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
 IF coalesce(auth.role(),current_setting('role',true),'')<>'service_role' THEN
  RAISE EXCEPTION 'Service role required' USING ERRCODE='42501';
 END IF;
END $$;

CREATE FUNCTION public.service_esim_acquire_slot(p_account_key text DEFAULT 'primary')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE a esim_private.accounts%ROWTYPE; t timestamptz:=clock_timestamp();
BEGIN
 PERFORM esim_private.require_service();
 SELECT * INTO STRICT a FROM esim_private.accounts WHERE account_key=p_account_key FOR UPDATE;
 IF a.next_request_at>t THEN RETURN jsonb_build_object('granted',false,'retry_after_ms',ceil(extract(epoch FROM(a.next_request_at-t))*1000)); END IF;
 UPDATE esim_private.accounts SET next_request_at=t+interval '500 milliseconds' WHERE id=a.id;
 RETURN '{"granted":true}'::jsonb;
END $$;

CREATE FUNCTION public.gate_esim_order_submission() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE a esim_private.accounts%ROWTYPE;
BEGIN
 SELECT * INTO STRICT a FROM esim_private.accounts WHERE account_key='primary';
 IF NEW.provider<>'esimaccess' OR NOT a.new_sales_enabled THEN
  RAISE EXCEPTION 'eSIM purchases are temporarily unavailable while delivery safeguards are verified' USING ERRCODE='P0001';
 END IF;
 NEW.delivery_state:='queued'; RETURN NEW;
END $$;
CREATE FUNCTION public.service_esim_heartbeat(p_account_key text,p_counts jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM esim_private.require_service();
 UPDATE esim_private.accounts SET last_worker_seen_at=now(),last_cycle=jsonb_build_object(
  'orders',(p_counts->>'orders')::integer,'profiles',(p_counts->>'profiles')::integer,
  'events',(p_counts->>'events')::integer,'errors',(p_counts->>'errors')::integer) WHERE account_key=p_account_key;
 INSERT INTO public.system_configs(config_key,config_value,updated_at)
 VALUES('WORKER_ESIM_FULFILLMENT_HEARTBEAT',to_jsonb(now()::text)::text,now())
 ON CONFLICT(config_key) DO UPDATE SET config_value=excluded.config_value,updated_at=excluded.updated_at;
END $$;
CREATE TRIGGER gate_esim_order_submission BEFORE INSERT ON public.esim_orders
FOR EACH ROW EXECUTE FUNCTION public.gate_esim_order_submission();
CREATE FUNCTION public.queue_esim_order_delivery() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 INSERT INTO esim_private.order_runs(order_id,account_id,submission_ref,state)
 SELECT NEW.id,a.id,'esim_'||NEW.id::text,'prepared' FROM esim_private.accounts a WHERE a.account_key='primary';
 RETURN NEW;
END $$;
CREATE TRIGGER queue_esim_order_delivery AFTER INSERT ON public.esim_orders
FOR EACH ROW EXECUTE FUNCTION public.queue_esim_order_delivery();
-- Never replay pre-cutover work: a crash may already have submitted it.
INSERT INTO esim_private.order_runs(order_id,account_id,submission_ref,state,provider_order_ref,error_code,next_check_at)
SELECT o.id,a.id,'esim_'||o.id::text,CASE WHEN nullif(o.provider_order_ref,'') IS NULL THEN 'support_required' ELSE 'reconciling' END,
 nullif(o.provider_order_ref,''),'LEGACY_REVIEW_REQUIRED',CASE WHEN nullif(o.provider_order_ref,'') IS NULL THEN NULL ELSE now() END
FROM public.esim_orders o CROSS JOIN esim_private.accounts a
WHERE a.account_key='primary' AND o.provider='esimaccess' AND o.status IN('pending','processing');
UPDATE public.esim_orders o SET delivery_state=r.state FROM esim_private.order_runs r WHERE o.id=r.order_id;

CREATE FUNCTION public.service_esim_claim_order(p_account_key text DEFAULT 'primary')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE a esim_private.accounts%ROWTYPE; r esim_private.order_runs%ROWTYPE; result jsonb;
BEGIN
 PERFORM esim_private.require_service();
 SELECT * INTO STRICT a FROM esim_private.accounts WHERE account_key=p_account_key;
 SELECT run.* INTO r FROM esim_private.order_runs run JOIN public.esim_orders o ON o.id=run.order_id
 WHERE run.account_id=a.id AND run.state<>'completed' AND o.user_id IS NOT NULL
   AND o.status IN('pending','processing') AND run.next_check_at<=now()
   AND (run.lease_until IS NULL OR run.lease_until<now())
   AND (run.state<>'prepared' OR a.new_sales_enabled)
 ORDER BY run.next_check_at FOR UPDATE OF run SKIP LOCKED LIMIT 1;
 IF NOT FOUND THEN RETURN NULL; END IF;
 UPDATE esim_private.order_runs SET lease=gen_random_uuid(),lease_until=now()+interval '2 minutes',attempts=attempts+1
 WHERE order_id=r.order_id RETURNING * INTO r;
 UPDATE public.esim_orders SET status='processing',delivery_state=r.state,updated_at=now() WHERE id=r.order_id;
 SELECT jsonb_build_object('order_id',o.id,'user_id',o.user_id,'bundle_name',o.bundle_name,'quantity',o.quantity,
  'wholesale_price_usd',o.wholesale_price_usd,'catalogue_snapshot',o.catalogue_snapshot,'lease',r.lease,
  'state',r.state,'submission_ref',r.submission_ref,'provider_order_ref',r.provider_order_ref,'hinted_order_ref',r.hinted_order_ref)
 INTO result FROM public.esim_orders o WHERE o.id=r.order_id;
 RETURN result;
END $$;
CREATE FUNCTION public.service_esim_mark_submitted(p_order_id uuid,p_lease uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r esim_private.order_runs%ROWTYPE;
BEGIN
 PERFORM esim_private.require_service();
 SELECT * INTO STRICT r FROM esim_private.order_runs WHERE order_id=p_order_id FOR UPDATE;
 IF p_lease IS NULL OR r.lease IS NULL OR r.lease_until IS NULL OR r.lease IS DISTINCT FROM p_lease OR r.lease_until<now() OR r.state<>'prepared' THEN RETURN false; END IF;
 IF NOT EXISTS(SELECT 1 FROM esim_private.accounts WHERE id=r.account_id AND new_sales_enabled) THEN RETURN false; END IF;
 UPDATE esim_private.order_runs SET state='submitted',submitted_at=now(),updated_at=now() WHERE order_id=p_order_id;
 UPDATE public.esim_orders SET delivery_state='submitted' WHERE id=p_order_id;
 RETURN true;
END $$;
CREATE FUNCTION public.service_esim_order_checkpoint(p_order_id uuid,p_lease uuid,p_provider_order_ref text DEFAULT NULL,p_error_code text DEFAULT NULL)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r esim_private.order_runs%ROWTYPE; state_value text;
BEGIN
 PERFORM esim_private.require_service();
 SELECT * INTO STRICT r FROM esim_private.order_runs WHERE order_id=p_order_id FOR UPDATE;
 IF p_lease IS NULL OR r.lease IS NULL OR r.lease_until IS NULL OR r.lease IS DISTINCT FROM p_lease OR r.lease_until<now() OR r.state='completed' THEN RETURN false; END IF;
 IF p_error_code IS NOT NULL AND p_error_code!~'^[A-Z0-9_]{1,64}$' THEN RAISE EXCEPTION 'Invalid error code'; END IF;
 IF r.provider_order_ref IS NOT NULL AND p_provider_order_ref IS NOT NULL AND r.provider_order_ref<>p_provider_order_ref THEN RAISE EXCEPTION 'Provider order reference conflict'; END IF;
 state_value:=CASE WHEN coalesce(r.provider_order_ref,p_provider_order_ref) IS NULL THEN 'support_required' ELSE 'reconciling' END;
 UPDATE esim_private.order_runs SET state=state_value,provider_order_ref=coalesce(provider_order_ref,p_provider_order_ref),
  error_code=p_error_code,lease=NULL,lease_until=NULL,updated_at=now(),
  next_check_at=CASE WHEN state_value='support_required' AND hinted_order_ref IS NULL THEN NULL
    WHEN p_error_code IS NULL THEN now()+interval '10 seconds'
    ELSE now()+make_interval(secs=>least(21600,60*power(2,least(attempts,8)))::integer) END WHERE order_id=p_order_id;
 UPDATE public.esim_orders SET delivery_state=state_value,updated_at=now() WHERE id=p_order_id;
 RETURN true;
END $$;

CREATE FUNCTION public.service_esim_save_issuance(p_order_id uuid,p_lease uuid,p_provider_order_ref text,p_profiles jsonb,p_transaction_id text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r esim_private.order_runs%ROWTYPE; o public.esim_orders%ROWTYPE; item jsonb;
 existing public.user_esims%ROWTYPE; new_id uuid; count_profiles integer; conflict boolean:=false;
BEGIN
 PERFORM esim_private.require_service();
 SELECT * INTO STRICT r FROM esim_private.order_runs WHERE order_id=p_order_id FOR UPDATE;
 IF r.state='completed' THEN RETURN jsonb_build_object('completed',true); END IF;
 IF p_lease IS NULL OR r.lease IS NULL OR r.lease_until IS NULL OR r.lease IS DISTINCT FROM p_lease OR r.lease_until<now() THEN RAISE EXCEPTION 'Expired order lease'; END IF;
 SELECT * INTO STRICT o FROM public.esim_orders WHERE id=p_order_id FOR UPDATE;
 IF o.user_id IS NULL OR o.provider<>'esimaccess' OR o.status NOT IN('pending','processing') THEN RAISE EXCEPTION 'Order is not eligible'; END IF;
 IF nullif(p_provider_order_ref,'') IS NULL OR
  (r.provider_order_ref IS NOT NULL AND r.provider_order_ref<>p_provider_order_ref) OR
  (r.provider_order_ref IS NULL AND p_transaction_id IS DISTINCT FROM r.submission_ref) THEN RAISE EXCEPTION 'Unproven order binding'; END IF;
 IF p_profiles IS NULL OR jsonb_typeof(p_profiles)<>'array' OR jsonb_array_length(p_profiles)>o.quantity OR octet_length(p_profiles::text)>65536 THEN RAISE EXCEPTION 'Invalid allocation batch'; END IF;
 FOR item IN SELECT value FROM jsonb_array_elements(p_profiles) LOOP
  IF item->>'provider_order_ref' IS DISTINCT FROM p_provider_order_ref OR item->>'issuance_proven' IS DISTINCT FROM 'true'
   OR coalesce(item->>'supplier_profile_ref','')='' OR coalesce(item->>'iccid','')!~'^[0-9]{15,22}$'
   OR coalesce(item->>'lpa_string','')!~'^LPA:1\$[^$[:space:]]+\$[^$[:space:]]+'
  OR coalesce(item->>'smdp_address','')='' OR coalesce(item->>'matching_id','')=''
  OR split_part(item->>'lpa_string','$',2) IS DISTINCT FROM item->>'smdp_address'
  OR split_part(item->>'lpa_string','$',3) IS DISTINCT FROM item->>'matching_id'
  OR item->>'profile_state' IN('cancelled','revoked','expired') THEN CONTINUE; END IF;
  SELECT * INTO existing FROM public.user_esims WHERE provider='esimaccess' AND supplier_account_id=r.account_id
   AND supplier_profile_ref=item->>'supplier_profile_ref' FOR UPDATE;
  IF FOUND THEN
   IF existing.user_id IS DISTINCT FROM o.user_id OR existing.order_id<>o.id OR existing.iccid<>item->>'iccid'
    OR existing.lpa_string<>item->>'lpa_string' THEN conflict:=true; END IF;
   CONTINUE;
  END IF;
  BEGIN
   INSERT INTO public.user_esims(user_id,order_id,provider,bundle_name,iccid,smdp_address,matching_id,lpa_string,
     status,purchased_at,data_total_mb,data_remaining_mb,supplier_account_id,supplier_profile_ref,profile_state,
     installation_state,bundle_state,provider_state,activation_trigger,confirmed_expires_at,plan_details,
     data_total_bytes,data_used_bytes,data_remaining_bytes,last_usage_check,last_observation_at)
   VALUES(o.user_id,o.id,o.provider,o.bundle_name,item->>'iccid',item->>'smdp_address',item->>'matching_id',item->>'lpa_string',
    'active',o.created_at,coalesce(floor((item->>'data_total_bytes')::numeric/1048576)::bigint,0),
    coalesce(floor((item->>'data_remaining_bytes')::numeric/1048576)::bigint,0),r.account_id,item->>'supplier_profile_ref',coalesce(item->>'profile_state','unknown'),
    coalesce(item->>'installation_state','unknown'),coalesce(item->>'bundle_state','unknown'),coalesce(item->'provider_state','{}'),
    coalesce(item->>'activation_trigger','unknown'),(item->>'confirmed_expires_at')::timestamptz,o.catalogue_snapshot->'catalogue_details',
    (item->>'data_total_bytes')::bigint,(item->>'data_used_bytes')::bigint,(item->>'data_remaining_bytes')::bigint,
    CASE WHEN item->>'data_remaining_bytes' IS NOT NULL THEN now() END,clock_timestamp()) RETURNING id INTO new_id;
   INSERT INTO esim_private.profile_work(profile_id) VALUES(new_id);
  EXCEPTION WHEN unique_violation THEN conflict:=true;
  END;
 END LOOP;
 SELECT count(*) INTO count_profiles FROM public.user_esims WHERE order_id=o.id AND user_id=o.user_id
  AND provider=o.provider AND supplier_account_id=r.account_id AND supplier_profile_ref IS NOT NULL;
 UPDATE esim_private.order_runs SET provider_order_ref=p_provider_order_ref,state=CASE WHEN conflict THEN 'support_required'
  WHEN count_profiles=o.quantity THEN 'completed' ELSE 'reconciling' END,
  next_check_at=CASE WHEN count_profiles=o.quantity OR conflict THEN NULL ELSE now()+interval '1 minute' END,
  lease=NULL,lease_until=NULL,error_code=CASE WHEN conflict THEN 'IDENTITY_CONFLICT' WHEN count_profiles<o.quantity THEN 'PARTIAL_ISSUANCE' END,updated_at=now()
 WHERE order_id=o.id;
 UPDATE public.esim_orders SET status=CASE WHEN count_profiles=o.quantity AND NOT conflict THEN 'completed' ELSE 'processing' END,
  delivery_state=CASE WHEN conflict THEN 'support_required' WHEN count_profiles=o.quantity THEN 'completed' ELSE 'reconciling' END,
  provider_order_ref=p_provider_order_ref,updated_at=now() WHERE id=o.id;
 RETURN jsonb_build_object('completed',count_profiles=o.quantity AND NOT conflict,'profiles',count_profiles,'conflict',conflict);
END $$;

CREATE FUNCTION public.service_esim_claim_profile(p_account_key text DEFAULT 'primary')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE w esim_private.profile_work%ROWTYPE; result jsonb;
BEGIN
 PERFORM esim_private.require_service();
 SELECT work.* INTO w FROM esim_private.profile_work work JOIN public.user_esims p ON p.id=work.profile_id
  JOIN esim_private.accounts a ON a.id=p.supplier_account_id
 WHERE a.account_key=p_account_key AND p.user_id IS NOT NULL AND p.supplier_profile_ref IS NOT NULL
  AND work.next_check_at<=now() AND (work.lease_until IS NULL OR work.lease_until<now()) AND work.terminal_checks<3
 ORDER BY work.next_check_at FOR UPDATE OF work SKIP LOCKED LIMIT 1;
 IF NOT FOUND THEN RETURN NULL; END IF;
 UPDATE esim_private.profile_work SET lease=gen_random_uuid(),lease_until=now()+interval '2 minutes',observation_started_at=clock_timestamp(),attempts=attempts+1
  WHERE profile_id=w.profile_id RETURNING * INTO w;
 SELECT jsonb_build_object('id',p.id,'supplier_profile_ref',p.supplier_profile_ref,'lease',w.lease,'observation_started_at',w.observation_started_at)
 INTO result FROM public.user_esims p WHERE p.id=w.profile_id;
 RETURN result;
END $$;
CREATE FUNCTION public.service_esim_apply_observation(p_profile_id uuid,p_lease uuid,p_observation jsonb DEFAULT NULL,p_error_code text DEFAULT NULL)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE w esim_private.profile_work%ROWTYPE; p public.user_esims%ROWTYPE; t timestamptz; good boolean; terminal boolean;
BEGIN
 PERFORM esim_private.require_service();
 SELECT * INTO STRICT w FROM esim_private.profile_work WHERE profile_id=p_profile_id FOR UPDATE;
 IF p_lease IS NULL OR w.lease IS NULL OR w.lease_until IS NULL OR w.lease IS DISTINCT FROM p_lease OR w.lease_until<now() THEN RETURN false; END IF;
 SELECT * INTO STRICT p FROM public.user_esims WHERE id=p_profile_id FOR UPDATE;
 IF p_error_code IS NOT NULL AND p_error_code!~'^[A-Z0-9_]{1,64}$' THEN RAISE EXCEPTION 'Invalid error code'; END IF;
 IF p_observation IS NOT NULL AND p_observation->>'supplier_profile_ref' IS DISTINCT FROM p.supplier_profile_ref THEN RAISE EXCEPTION 'Profile reference mismatch'; END IF;
 IF p_observation IS NOT NULL AND (p_observation->>'iccid' IS DISTINCT FROM p.iccid OR
  p_observation->>'provider_order_ref' IS DISTINCT FROM (SELECT provider_order_ref FROM esim_private.order_runs WHERE order_id=p.order_id))
 THEN RAISE EXCEPTION 'Profile order binding mismatch'; END IF;
 t:=(p_observation->>'usage_observed_at')::timestamptz;
 good:=p_observation IS NOT NULL AND p_error_code IS NULL
  AND (p.usage_observed_at IS NULL OR (t IS NOT NULL AND t>=p.usage_observed_at)) AND (t IS NULL OR t<=clock_timestamp()+interval '5 minutes')
  AND (p.last_observation_at IS NULL OR w.observation_started_at>=p.last_observation_at);
 IF good THEN
  UPDATE public.user_esims SET profile_state=coalesce(p_observation->>'profile_state',profile_state),
   installation_state=coalesce(p_observation->>'installation_state',installation_state),bundle_state=coalesce(p_observation->>'bundle_state',bundle_state),
   provider_state=coalesce(p_observation->'provider_state',provider_state),
   activation_trigger=coalesce(p_observation->>'activation_trigger',activation_trigger),
   confirmed_expires_at=coalesce((p_observation->>'confirmed_expires_at')::timestamptz,confirmed_expires_at),
   data_total_bytes=coalesce((p_observation->>'data_total_bytes')::bigint,data_total_bytes),
   data_used_bytes=coalesce((p_observation->>'data_used_bytes')::bigint,data_used_bytes),
   data_remaining_bytes=coalesce((p_observation->>'data_remaining_bytes')::bigint,data_remaining_bytes),
   usage_observed_at=coalesce(t,usage_observed_at),last_observation_at=w.observation_started_at,
   last_usage_check=CASE WHEN p_observation->>'data_remaining_bytes' IS NOT NULL THEN now() ELSE last_usage_check END,
   last_usage_attempt_at=now(),usage_error_code=CASE WHEN p_observation->>'data_remaining_bytes' IS NULL THEN 'USAGE_NOT_PROVIDED' END,
   data_total_mb=coalesce(floor((p_observation->>'data_total_bytes')::numeric/1048576)::bigint,data_total_mb),
   data_remaining_mb=coalesce(floor((p_observation->>'data_remaining_bytes')::numeric/1048576)::bigint,data_remaining_mb)
  WHERE id=p.id;
 ELSE UPDATE public.user_esims SET last_usage_attempt_at=now(),usage_error_code=coalesce(p_error_code,'STALE_OBSERVATION') WHERE id=p.id;
 END IF;
 terminal:=CASE WHEN good THEN coalesce(p_observation->>'profile_state',p.profile_state) ELSE p.profile_state END IN('expired','cancelled','revoked');
 UPDATE esim_private.profile_work SET lease=NULL,lease_until=NULL,terminal_checks=CASE WHEN terminal AND good THEN terminal_checks+1 WHEN terminal THEN terminal_checks ELSE 0 END,
  next_check_at=now()+CASE WHEN terminal THEN interval '1 day'
    WHEN coalesce(p_observation->>'bundle_state',p.bundle_state)='depleted' OR coalesce(p_observation->>'profile_state',p.profile_state)='suspended' THEN interval '6 hours'
    ELSE interval '1 hour' END WHERE profile_id=p.id;
 RETURN good;
END $$;

CREATE FUNCTION public.request_esim_profile_refresh() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE n integer;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required' USING ERRCODE='42501'; END IF;
 UPDATE esim_private.profile_work w SET next_check_at=least(coalesce(next_check_at,now()),now()),requested_at=now()
 FROM public.user_esims p WHERE p.id=w.profile_id AND p.user_id=auth.uid() AND w.terminal_checks<3
 AND (w.requested_at IS NULL OR w.requested_at<now()-interval '5 minutes');
 GET DIAGNOSTICS n=ROW_COUNT; RETURN jsonb_build_object('queued',n);
END $$;

REVOKE ALL ON public.user_esims FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.user_esims TO authenticated;
ALTER TABLE public.user_esims ENABLE ROW LEVEL SECURITY;
CREATE VIEW public.customer_esim_profiles WITH(security_invoker=true,security_barrier=true) AS
 SELECT id,user_id,order_id,iccid,CASE WHEN supplier_profile_ref IS NOT NULL THEN lpa_string END AS lpa_string,
  qr_code_url,bundle_name,provider,status,purchased_at,
  data_total_mb,data_remaining_mb,last_usage_check,profile_state,installation_state,bundle_state,
  activation_trigger,first_activated_at,confirmed_expires_at AS expires_at,activation_deadline_at,
  data_total_bytes,data_used_bytes,data_remaining_bytes,usage_observed_at,last_observation_at,
  last_usage_attempt_at,usage_error_code,plan_details AS catalogue_details,(supplier_profile_ref IS NOT NULL) AS issuance_verified
 FROM public.user_esims WHERE user_id=(SELECT auth.uid());
REVOKE ALL ON public.customer_esim_profiles FROM PUBLIC,anon;
GRANT SELECT ON public.customer_esim_profiles TO authenticated,service_role;
REVOKE ALL ON public.esim_orders FROM PUBLIC,anon,authenticated;
GRANT SELECT(id,user_id,provider,bundle_name,quantity,retail_price_usd,status,created_at,updated_at,total_amount_usd,delivery_state)
 ON public.esim_orders TO authenticated;
CREATE OR REPLACE VIEW public.customer_esim_orders WITH(security_invoker=true,security_barrier=true) AS
 SELECT id,user_id,provider,bundle_name,quantity,retail_price_usd,status,created_at,updated_at,total_amount_usd,
 CASE WHEN status='failed' THEN 'eSIM order could not be completed.'::text ELSE NULL::text END AS error_message,delivery_state
 FROM public.esim_orders;

DO $$ DECLARE r record; BEGIN
 FOR r IN SELECT p.oid::regprocedure AS signature FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE (n.nspname='esim_private') OR (n.nspname='public' AND p.proname IN(
 'service_esim_acquire_slot','service_esim_heartbeat','gate_esim_order_submission','queue_esim_order_delivery','service_esim_claim_order',
 'service_esim_mark_submitted','service_esim_order_checkpoint','service_esim_save_issuance','service_esim_claim_profile','service_esim_apply_observation')) LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',r.signature);
  EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',r.signature);
 END LOOP;
END $$;
REVOKE ALL ON FUNCTION public.request_esim_profile_refresh() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.request_esim_profile_refresh() TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
