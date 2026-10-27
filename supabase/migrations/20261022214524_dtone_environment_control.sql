-- DT One versioned Vault control plane. No credentials or activation are seeded.
BEGIN;
CREATE SCHEMA dtone_private;
REVOKE ALL ON SCHEMA dtone_private FROM PUBLIC,anon,authenticated,service_role;
CREATE TABLE dtone_private.configs(environment text PRIMARY KEY CHECK(environment IN ('preproduction','production')), version integer NOT NULL DEFAULT 0 CHECK(version>=0));
CREATE TABLE dtone_private.versions(environment text REFERENCES dtone_private.configs,version integer NOT NULL CHECK(version>0),secret_id uuid NOT NULL,validated_at timestamptz NOT NULL,account jsonb NOT NULL,callback_configured boolean NOT NULL DEFAULT false,PRIMARY KEY(environment,version));
CREATE TABLE dtone_private.runtime(id boolean PRIMARY KEY DEFAULT true CHECK(id),environment text,version integer,revision integer NOT NULL DEFAULT 0,release_verified boolean NOT NULL DEFAULT false,updated_at timestamptz NOT NULL DEFAULT now(),FOREIGN KEY(environment,version) REFERENCES dtone_private.versions);
CREATE TABLE dtone_private.jobs(id uuid PRIMARY KEY,actor uuid NOT NULL,action text NOT NULL CHECK(action IN ('save','check','activate')),environment text NOT NULL REFERENCES dtone_private.configs,expected_version integer NOT NULL,expected_revision integer NOT NULL,request_fingerprint bytea NOT NULL,secret_id uuid,state text NOT NULL DEFAULT 'queued' CHECK(state IN ('queued','running','ok','failed')),code text,lease uuid,lease_until timestamptz,created_at timestamptz NOT NULL DEFAULT now(),completed_at timestamptz);
CREATE INDEX dtone_jobs_queue ON dtone_private.jobs(created_at) WHERE state IN ('queued','running');
CREATE TABLE dtone_private.adoption(consumer text PRIMARY KEY,environment text,version integer NOT NULL,revision integer NOT NULL,source text NOT NULL CHECK(source IN ('legacy','vault','unavailable')),build text NOT NULL,last_seen timestamptz NOT NULL DEFAULT now());
CREATE TABLE dtone_private.operations(execution_id uuid PRIMARY KEY REFERENCES public.topup_executions(id),environment text NOT NULL,version integer NOT NULL,revision integer NOT NULL,external_reference text NOT NULL UNIQUE,account_identity jsonb NOT NULL,created_at timestamptz NOT NULL DEFAULT now(),FOREIGN KEY(environment,version) REFERENCES dtone_private.versions);
CREATE TABLE dtone_private.callback_signals(execution_id uuid PRIMARY KEY REFERENCES dtone_private.operations,received_at timestamptz NOT NULL DEFAULT now(),status_code integer NOT NULL CHECK(status_code IN (70000,80000,90000)));
INSERT INTO dtone_private.configs(environment) VALUES('preproduction'),('production');
INSERT INTO dtone_private.runtime(id) VALUES(true);
ALTER TABLE public.topup_executions ADD COLUMN dtone_provenance jsonb;
ALTER TABLE public.provider_offers_cache ADD COLUMN dtone_provenance jsonb;
ALTER TABLE public.provider_offers ADD COLUMN dtone_provenance jsonb;
UPDATE public.provider_offers SET source_is_active=false WHERE provider_code='dtone' AND source_is_active;
-- Old cache rows have no trustworthy account/environment provenance.
DELETE FROM public.provider_offers_cache WHERE api_provider='dtone';
DO $$DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['configs','versions','runtime','jobs','adoption','operations','callback_signals'] LOOP
 EXECUTE format('ALTER TABLE dtone_private.%I ENABLE ROW LEVEL SECURITY',t);
 END LOOP;
END$$;
REVOKE ALL ON ALL TABLES IN SCHEMA dtone_private FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION dtone_private.actor(p_actor uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$BEGIN
 IF p_actor IS NULL OR NOT EXISTS(SELECT 1 FROM auth.users WHERE id=p_actor AND deleted_at IS NULL AND (banned_until IS NULL OR banned_until<=now()) AND raw_app_meta_data->>'is_power_user'='true' AND coalesce(raw_app_meta_data->>'is_suspended','false')<>'true') THEN RAISE EXCEPTION 'Administrator required' USING ERRCODE='DT403'; END IF;
END$$;
CREATE FUNCTION dtone_private.audit(p_actor uuid,p_action text,p_env text,p_value jsonb) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$BEGIN
 INSERT INTO public.admin_audit_log(actor_id,actor_email,action,target_type,target_id,after_value,note)
 SELECT p_actor,email,'dtone.'||p_action,'provider_credentials',p_env,p_value,'Metadata only; provider-side settings are managed in DT Shop' FROM public.profiles WHERE id=p_actor;
 IF NOT FOUND THEN RAISE EXCEPTION 'Administrator profile required' USING ERRCODE='DT403'; END IF;
END$$;
CREATE FUNCTION dtone_private.ready() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT r.release_verified AND NOT EXISTS(SELECT 1 FROM unnest(ARRAY['worker_instant_refill','worker_auto_mini_refill','worker_auto_custom_refill','worker_offers_cache','worker_dtone_control']) n WHERE NOT EXISTS(SELECT 1 FROM dtone_private.adoption a WHERE a.consumer=n AND a.build='dtone-v1' AND a.last_seen>now()-interval '90 seconds' AND a.source<>'unavailable')) FROM dtone_private.runtime r WHERE r.id=true
$$;
CREATE FUNCTION dtone_private.blockers() RETURNS bigint LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path='' AS $$
 SELECT (SELECT count(*) FROM public.topup_executions e WHERE (lower(coalesce(e.api_provider,''))='dtone' OR (e.api_provider IS NULL AND e.execution_type IN ('refill_instant','refill_mini','refill_custom'))) AND (e.status IN ('pending','pending_payment','awaiting_funds','awaiting_approval','processing','routing') OR coalesce(e.carrier_in_flight,false)))
 + (SELECT count(*) FROM public.sim_setup_orders o WHERE o.plan='premium' AND lower(coalesce(o.provider,'dtone'))='dtone' AND o.status NOT IN ('active','failed','cancelled'))
$$;
CREATE FUNCTION public.admin_dtone_status() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb; BEGIN
 PERFORM public.assert_admin(); PERFORM dtone_private.actor(auth.uid());
 SELECT jsonb_build_object('active_environment',r.environment,'active_version',r.version,'activation_revision',r.revision,'runtime_ready',dtone_private.ready(),'legacy_fallback',r.environment IS NULL,'pending_blockers',dtone_private.blockers(),
 'environments',(SELECT jsonb_agg(jsonb_build_object('environment',c.environment,'version',c.version,'configured',v.secret_id IS NOT NULL AND EXISTS(SELECT 1 FROM vault.secrets s WHERE s.id=v.secret_id),'validated_at',v.validated_at,'account',coalesce(v.account,'[]'::jsonb),'callback_configured',coalesce(v.callback_configured,false),'last_callback_at',(SELECT max(cs.received_at) FROM dtone_private.callback_signals cs JOIN dtone_private.operations op ON op.execution_id=cs.execution_id WHERE op.environment=c.environment)) ORDER BY c.environment) FROM dtone_private.configs c LEFT JOIN dtone_private.versions v ON v.environment=c.environment AND v.version=c.version),
 'workers',coalesce((SELECT jsonb_agg(jsonb_build_object('consumer',a.consumer,'environment',a.environment,'version',a.version,'revision',a.revision,'source',a.source,'last_seen',a.last_seen,'fresh',a.last_seen>now()-interval '90 seconds','adopted',a.last_seen>now()-interval '90 seconds' AND a.source='vault' AND a.environment=r.environment AND a.version=r.version AND a.revision=r.revision) ORDER BY a.consumer) FROM dtone_private.adoption a),'[]'::jsonb)) INTO result FROM dtone_private.runtime r WHERE r.id=true;
 RETURN result;
END$$;
CREATE FUNCTION public.admin_dtone_request(p_id uuid,p_action text,p_environment text,p_expected_version integer,p_expected_revision integer,p_pair jsonb DEFAULT NULL) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c dtone_private.configs%ROWTYPE; j dtone_private.jobs%ROWTYPE; sid uuid; k text; BEGIN
 PERFORM public.assert_admin(); PERFORM dtone_private.actor(auth.uid());
 IF p_id IS NULL OR p_action IS NULL OR p_action NOT IN ('save','check','activate') OR p_environment IS NULL OR p_expected_version IS NULL OR p_expected_revision IS NULL OR p_expected_version<0 OR p_expected_revision<0 THEN RAISE EXCEPTION 'Invalid request' USING ERRCODE='DT400'; END IF;
 SELECT * INTO c FROM dtone_private.configs WHERE environment=p_environment FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Invalid environment' USING ERRCODE='DT400'; END IF;
 SELECT * INTO j FROM dtone_private.jobs WHERE id=p_id;
 IF FOUND THEN
 IF j.actor<>auth.uid() OR j.action<>p_action OR j.environment<>p_environment OR j.expected_version<>p_expected_version OR j.expected_revision<>p_expected_revision OR j.request_fingerprint IS DISTINCT FROM sha256(convert_to(coalesce(p_pair,'null'::jsonb)::text,'UTF8')) THEN RAISE EXCEPTION 'Request conflict' USING ERRCODE='DT409'; END IF;
 RETURN j.id; END IF;
 IF c.version<>p_expected_version THEN RAISE EXCEPTION 'Version changed; refresh' USING ERRCODE='DT409'; END IF;
 IF p_action='save' THEN
 IF p_pair IS NULL OR jsonb_typeof(p_pair)<>'object' OR NOT p_pair ?& ARRAY['api_key','api_secret'] OR EXISTS(SELECT 1 FROM jsonb_object_keys(p_pair) x WHERE x NOT IN ('api_key','api_secret','callback_username','callback_password')) THEN RAISE EXCEPTION 'Invalid credential pair' USING ERRCODE='DT400'; END IF;
 FOREACH k IN ARRAY ARRAY['api_key','api_secret'] LOOP
 IF jsonb_typeof(p_pair->k)<>'string' OR length(p_pair->>k)=0 OR octet_length(p_pair->>k)>4096 OR (p_pair->>k) ~ '[[:space:]]' OR (k='api_key' AND (p_pair->>k) LIKE '%:%') THEN RAISE EXCEPTION 'Invalid credential pair' USING ERRCODE='DT400'; END IF;
 END LOOP;
 IF (p_pair ? 'callback_username') IS DISTINCT FROM (p_pair ? 'callback_password') THEN RAISE EXCEPTION 'Callback pair required' USING ERRCODE='DT400'; END IF;
 FOREACH k IN ARRAY ARRAY['callback_username','callback_password'] LOOP
 IF p_pair ? k AND (jsonb_typeof(p_pair->k)<>'string' OR length(p_pair->>k)=0 OR octet_length(p_pair->>k)>1024 OR (p_pair->>k) ~ '[[:cntrl:]]' OR (k='callback_username' AND (p_pair->>k) LIKE '%:%')) THEN RAISE EXCEPTION 'Invalid callback pair' USING ERRCODE='DT400'; END IF;
 END LOOP;
 IF NOT p_pair ? 'callback_username' AND c.version>0 THEN
 p_pair:=p_pair || coalesce((SELECT jsonb_build_object('callback_username',s.decrypted_secret::jsonb->>'callback_username','callback_password',s.decrypted_secret::jsonb->>'callback_password') FROM dtone_private.versions v JOIN vault.decrypted_secrets s ON s.id=v.secret_id WHERE v.environment=c.environment AND v.version=c.version AND v.callback_configured),'{}'::jsonb);
 END IF;
 SELECT vault.create_secret(p_pair::text,NULL,'DT One candidate pair') INTO sid;
 ELSE
 IF c.version<1 OR p_pair IS NOT NULL THEN RAISE EXCEPTION 'Saved credentials required' USING ERRCODE='DT400'; END IF;
 SELECT secret_id INTO sid FROM dtone_private.versions WHERE environment=p_environment AND version=c.version;
 END IF;
 -- Bounded queue; duplicate HTTP requests reuse their id rather than reissue actions.
 IF (SELECT count(*) FROM dtone_private.jobs WHERE actor=auth.uid() AND state IN ('queued','running') AND created_at>now()-interval '2 minutes')>=3 THEN RAISE EXCEPTION 'Request already pending' USING ERRCODE='DT429'; END IF;
 INSERT INTO dtone_private.jobs(id,actor,action,environment,expected_version,expected_revision,request_fingerprint,secret_id) VALUES(p_id,auth.uid(),p_action,p_environment,p_expected_version,p_expected_revision,sha256(convert_to(coalesce(p_pair,'null'::jsonb)::text,'UTF8')),sid);
 PERFORM dtone_private.audit(auth.uid(),'requested',p_environment,jsonb_build_object('request_id',p_id,'action',p_action,'version',p_expected_version));
 RETURN p_id;
EXCEPTION WHEN SQLSTATE 'DT400' OR SQLSTATE 'DT403' OR SQLSTATE 'DT409' OR SQLSTATE 'DT429' OR SQLSTATE 'KS460' THEN RAISE;
 WHEN OTHERS THEN RAISE EXCEPTION 'DT One request could not be stored' USING ERRCODE='DT503';
END$$;
CREATE FUNCTION public.admin_dtone_request_status(p_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$BEGIN
 PERFORM public.assert_admin(); PERFORM dtone_private.actor(auth.uid());
 RETURN (SELECT jsonb_build_object('id',id,'action',action,'environment',environment,'expected_version',expected_version,'state',CASE WHEN state IN ('queued','running') AND created_at<now()-interval '2 minutes' THEN 'failed' ELSE state END,'code',CASE WHEN state IN ('queued','running') AND created_at<now()-interval '2 minutes' THEN 'expired' ELSE code END) FROM dtone_private.jobs WHERE id=p_id AND actor=auth.uid());
END$$;
CREATE FUNCTION public.service_claim_dtone_request() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE j dtone_private.jobs%ROWTYPE; pair jsonb; BEGIN
 -- Expired validation can be retried without a purchase; leases fence delayed results.
 UPDATE dtone_private.jobs SET state='failed',code='expired',completed_at=now() WHERE state IN ('queued','running') AND created_at<now()-interval '2 minutes';
 DELETE FROM vault.secrets s WHERE EXISTS(SELECT 1 FROM dtone_private.jobs candidate WHERE candidate.secret_id=s.id AND candidate.action='save' AND candidate.state='failed') AND NOT EXISTS(SELECT 1 FROM dtone_private.versions v WHERE v.secret_id=s.id);
 SELECT * INTO j FROM dtone_private.jobs WHERE state='queued' OR (state='running' AND lease_until<now()) ORDER BY created_at FOR UPDATE SKIP LOCKED LIMIT 1;
 IF NOT FOUND THEN RETURN NULL; END IF;
 UPDATE dtone_private.jobs SET state='running',lease=gen_random_uuid(),lease_until=now()+interval '45 seconds' WHERE id=j.id RETURNING * INTO j;
 SELECT decrypted_secret::jsonb INTO pair FROM vault.decrypted_secrets WHERE id=j.secret_id;
 RETURN jsonb_build_object('id',j.id,'lease',j.lease,'environment',j.environment,'action',j.action,'pair',pair);
END$$;
CREATE FUNCTION public.service_complete_dtone_request(p_id uuid,p_lease uuid,p_code text,p_account jsonb DEFAULT '[]') RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE j dtone_private.jobs%ROWTYPE; r dtone_private.runtime%ROWTYPE; c dtone_private.configs%ROWTYPE; outcome text:=p_code; pair jsonb; BEGIN
 PERFORM pg_advisory_xact_lock(7381202601);
 SELECT * INTO j FROM dtone_private.jobs WHERE id=p_id FOR UPDATE;
 IF NOT FOUND OR j.state<>'running' OR j.lease IS DISTINCT FROM p_lease OR j.lease_until<clock_timestamp() OR j.created_at<clock_timestamp()-interval '2 minutes' THEN RETURN 'expired'; END IF;
 BEGIN
 PERFORM dtone_private.actor(j.actor);
 SELECT * INTO STRICT r FROM dtone_private.runtime WHERE id=true FOR UPDATE;
 SELECT * INTO STRICT c FROM dtone_private.configs WHERE environment=j.environment FOR UPDATE;
 IF p_code IS NULL OR p_code NOT IN ('ok','invalid_credentials','ip_restricted','access_restricted','provider_unavailable','insufficient_balance','invalid_response','unavailable') THEN outcome:='unavailable'; END IF;
 IF outcome='ok' AND c.version<>j.expected_version THEN outcome:='conflict'; END IF;
 IF outcome='ok' THEN
 -- Store only schema-checked account balance metadata, never an arbitrary provider body.
 IF p_account IS NULL OR jsonb_typeof(p_account)<>'array' OR jsonb_array_length(p_account)=0 OR jsonb_array_length(p_account)>100 OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_account) x WHERE jsonb_typeof(x)<>'object' OR NOT x ?& ARRAY['id','currency','available'] OR EXISTS(SELECT 1 FROM jsonb_object_keys(x) k WHERE k NOT IN ('id','currency','available','holding','credit_limit')) OR coalesce(x->>'id','')!~'^[0-9]{1,20}$' OR coalesce(x->>'currency','')!~'^[A-Z]{3}$' OR coalesce(x->>'available','')!~'^-?[0-9]+([.][0-9]+)?$') THEN outcome:='invalid_response'; END IF;
 END IF;
 IF outcome='ok' AND j.action='activate' THEN
 IF r.revision<>j.expected_revision THEN outcome:='conflict';
 ELSIF NOT dtone_private.ready() THEN outcome:='runtime_not_ready';
 ELSIF dtone_private.blockers()>0 THEN outcome:='busy';
 ELSE
 UPDATE dtone_private.runtime SET environment=j.environment,version=c.version,revision=r.revision+1,updated_at=now() WHERE id=r.id;
 DELETE FROM public.provider_offers_cache WHERE api_provider='dtone';
 UPDATE public.provider_offers SET source_is_active=false WHERE provider_code='dtone' AND source_is_active;
 PERFORM dtone_private.audit(j.actor,'activated',j.environment,jsonb_build_object('version',c.version,'revision',r.revision+1));
 END IF;
 END IF;
 IF outcome='ok' AND j.action='save' THEN
 SELECT decrypted_secret::jsonb INTO pair FROM vault.decrypted_secrets WHERE id=j.secret_id;
 IF pair IS NULL THEN RAISE EXCEPTION 'Vault unavailable' USING ERRCODE='DT503'; END IF;
 INSERT INTO dtone_private.versions(environment,version,secret_id,validated_at,account,callback_configured) VALUES(j.environment,c.version+1,j.secret_id,now(),p_account,pair ?& ARRAY['callback_username','callback_password']);
 UPDATE dtone_private.configs SET version=c.version+1 WHERE environment=c.environment;
 PERFORM dtone_private.audit(j.actor,'saved',j.environment,jsonb_build_object('version',c.version+1,'activation_unchanged',true));
 ELSIF outcome='ok' THEN
 UPDATE dtone_private.versions SET validated_at=now(),account=p_account WHERE environment=j.environment AND version=c.version;
 PERFORM dtone_private.audit(j.actor,'checked',j.environment,jsonb_build_object('version',c.version));
 END IF;
 EXCEPTION WHEN SQLSTATE 'DT403' THEN outcome:='forbidden';
 END;
 UPDATE dtone_private.jobs SET state=CASE WHEN outcome='ok' THEN 'ok' ELSE 'failed' END,code=outcome,completed_at=now(),lease=NULL,lease_until=NULL WHERE id=j.id;
 -- Failed candidate secrets were never committed; old immutable versions are retained for reconciliation.
 IF j.action='save' AND outcome<>'ok' THEN DELETE FROM vault.secrets WHERE id=j.secret_id AND NOT EXISTS(SELECT 1 FROM dtone_private.versions v WHERE v.secret_id=j.secret_id); END IF;
 RETURN outcome;
END$$;
CREATE FUNCTION public.get_dtone_runtime_credentials(p_execution_id uuid DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r dtone_private.runtime%ROWTYPE; o dtone_private.operations%ROWTYPE; v dtone_private.versions%ROWTYPE; pair jsonb; env text; ver integer; rev integer; BEGIN
 SELECT * INTO STRICT r FROM dtone_private.runtime WHERE id=true;
 IF p_execution_id IS NOT NULL THEN
 SELECT * INTO o FROM dtone_private.operations WHERE execution_id=p_execution_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Original DT One configuration unavailable; operator reconciliation required' USING ERRCODE='DT503'; END IF;
 env:=o.environment;ver:=o.version;rev:=o.revision;
 ELSE env:=r.environment;ver:=r.version;rev:=r.revision; END IF;
 IF env IS NULL THEN RETURN NULL; END IF;
 SELECT * INTO v FROM dtone_private.versions WHERE environment=env AND version=ver;
 SELECT decrypted_secret::jsonb INTO pair FROM vault.decrypted_secrets WHERE id=v.secret_id;
 IF pair->>'api_key' IS NULL OR pair->>'api_secret' IS NULL THEN RAISE EXCEPTION 'Vault unavailable' USING ERRCODE='DT503'; END IF;
 RETURN jsonb_build_object('environment',env,'version',ver,'activation_revision',rev,'api_key',pair->>'api_key','api_secret',pair->>'api_secret','callback_configured',v.callback_configured,'account',v.account);
END$$;
CREATE FUNCTION public.service_dtone_adoption(p_consumer text,p_environment text,p_version integer,p_revision integer,p_source text,p_build text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$BEGIN
 IF p_consumer NOT IN ('worker_instant_refill','worker_auto_mini_refill','worker_auto_custom_refill','worker_offers_cache','worker_dtone_control','worker_supplier_reconciliation') OR p_source NOT IN ('legacy','vault','unavailable') OR p_build<>'dtone-v1' OR p_version<0 OR p_revision<0 THEN RAISE EXCEPTION 'Invalid adoption' USING ERRCODE='DT400'; END IF;
 INSERT INTO dtone_private.adoption(consumer,environment,version,revision,source,build) VALUES(p_consumer,p_environment,p_version,p_revision,p_source,p_build) ON CONFLICT(consumer) DO UPDATE SET environment=excluded.environment,version=excluded.version,revision=excluded.revision,source=excluded.source,build=excluded.build,last_seen=now() WHERE dtone_private.adoption.consumer=p_consumer;
END$$;
-- Initial rollout gate. Run only after comparing deployed hashes and observing all five heartbeats.
CREATE FUNCTION public.service_verify_dtone_release() RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$BEGIN
 IF EXISTS(SELECT 1 FROM unnest(ARRAY['worker_instant_refill','worker_auto_mini_refill','worker_auto_custom_refill','worker_offers_cache','worker_dtone_control']) n WHERE NOT EXISTS(SELECT 1 FROM dtone_private.adoption a WHERE a.consumer=n AND a.build='dtone-v1' AND a.last_seen>now()-interval '90 seconds' AND a.source<>'unavailable')) THEN RETURN false; END IF;
 UPDATE dtone_private.runtime SET release_verified=true WHERE id=true; RETURN true;
END$$;
CREATE FUNCTION public.service_pin_dtone_operation(p_execution_id uuid,p_environment text,p_version integer,p_revision integer) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r dtone_private.runtime%ROWTYPE; e public.topup_executions%ROWTYPE; o dtone_private.operations%ROWTYPE; parent public.topup_executions%ROWTYPE; original dtone_private.operations%ROWTYPE; meta jsonb; BEGIN
 PERFORM pg_advisory_xact_lock(7381202601);
 SELECT * INTO STRICT r FROM dtone_private.runtime WHERE id=true FOR SHARE;
 SELECT * INTO STRICT e FROM public.topup_executions WHERE id=p_execution_id FOR UPDATE;
 SELECT * INTO o FROM dtone_private.operations WHERE execution_id=e.id;
 IF FOUND THEN
 IF o.environment IS DISTINCT FROM p_environment OR o.version IS DISTINCT FROM p_version OR o.revision IS DISTINCT FROM p_revision THEN RAISE EXCEPTION 'Original configuration required' USING ERRCODE='DT409'; END IF;
 RETURN e.dtone_provenance;
 END IF;
 IF e.carrier_in_flight OR e.reloadly_transaction_id IS NOT NULL THEN RAISE EXCEPTION 'Existing submission requires original configuration reconciliation' USING ERRCODE='DT423'; END IF;
 IF e.retry_of IS NOT NULL THEN
 IF r.environment IS DISTINCT FROM 'production' OR p_environment IS DISTINCT FROM r.environment OR p_version IS DISTINCT FROM r.version OR p_revision IS DISTINCT FROM r.revision OR NOT r.release_verified THEN RAISE EXCEPTION 'Original retry configuration is not active; operator reconciliation required' USING ERRCODE='DT409'; END IF;
 SELECT * INTO parent FROM public.topup_executions WHERE id=e.retry_of;
 SELECT * INTO original FROM dtone_private.operations WHERE execution_id=e.retry_of;
 IF original.execution_id IS NULL OR parent.status NOT IN ('failed','cancelled') OR coalesce(parent.carrier_in_flight,false) OR original.environment IS DISTINCT FROM p_environment OR original.version IS DISTINCT FROM p_version OR original.revision IS DISTINCT FROM p_revision THEN RAISE EXCEPTION 'Unresolved or unpinned original retry requires reconciliation' USING ERRCODE='DT423'; END IF;
 ELSIF p_environment IS DISTINCT FROM 'production' OR r.environment IS DISTINCT FROM p_environment OR r.version IS DISTINCT FROM p_version OR r.revision IS DISTINCT FROM p_revision OR NOT r.release_verified THEN RAISE EXCEPTION 'DT One simulation or changed configuration cannot deliver paid airtime' USING ERRCODE='DT409'; END IF;
 IF e.status NOT IN ('processing','routing','pending') THEN RAISE EXCEPTION 'Invalid execution state' USING ERRCODE='DT423'; END IF;
 meta:=jsonb_build_object('environment',p_environment,'version',p_version,'activation_revision',p_revision,'simulation',false,'source','vault');
 INSERT INTO dtone_private.operations(execution_id,environment,version,revision,external_reference,account_identity) SELECT e.id,p_environment,p_version,p_revision,'dt_'||e.id::text,(SELECT jsonb_agg(jsonb_build_object('balance_id',x->>'id','currency',x->>'currency')) FROM jsonb_array_elements(v.account) x) FROM dtone_private.versions v WHERE v.environment=p_environment AND v.version=p_version;
 UPDATE public.topup_executions SET dtone_provenance=meta WHERE id=e.id;
 RETURN meta;
END$$;
-- Serialize queue creation and supplier state changes with activation. A transaction
-- cannot enter the queue between the blocker check and the runtime commit.
CREATE FUNCTION dtone_private.execution_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$BEGIN
 IF lower(coalesce(NEW.api_provider,'dtone'))='dtone' OR (TG_OP='UPDATE' AND lower(coalesce(OLD.api_provider,'dtone'))='dtone') THEN
 PERFORM pg_advisory_xact_lock(7381202601);
 IF TG_OP='UPDATE' AND EXISTS(SELECT 1 FROM dtone_private.operations op WHERE op.execution_id=NEW.id AND op.submitted_at IS NOT NULL AND coalesce(op.proof_status,0) NOT IN (30000,40000,70000,90000)) AND (NEW.status IN ('failed','refunded','cancelled') OR NOT coalesce(NEW.carrier_in_flight,false)) THEN RAISE EXCEPTION 'DT One submission requires original-reference reconciliation' USING ERRCODE='DT423'; END IF;
 IF NEW.dtone_provenance IS DISTINCT FROM (CASE WHEN TG_OP='INSERT' THEN NULL::jsonb ELSE OLD.dtone_provenance END) AND NOT EXISTS(SELECT 1 FROM dtone_private.operations o WHERE o.execution_id=NEW.id AND o.environment=NEW.dtone_provenance->>'environment' AND o.version=(NEW.dtone_provenance->>'version')::integer AND o.revision=(NEW.dtone_provenance->>'activation_revision')::integer) THEN RAISE EXCEPTION 'Untrusted provider provenance' USING ERRCODE='DT403'; END IF;
 IF lower(coalesce(NEW.api_provider,''))='dtone' AND NEW.status='success' AND (TG_OP='INSERT' OR OLD.status IS DISTINCT FROM 'success') AND (NEW.dtone_provenance->>'environment' IS DISTINCT FROM 'production' OR NEW.dtone_provenance->>'simulation' IS DISTINCT FROM 'false') THEN RAISE EXCEPTION 'Simulation is not airtime delivery' USING ERRCODE='DT423'; END IF;
 END IF; RETURN NEW;
END$$;
CREATE TRIGGER dtone_execution_guard BEFORE INSERT OR UPDATE ON public.topup_executions FOR EACH ROW EXECUTE FUNCTION dtone_private.execution_guard();
-- A premium setup can precede its initial execution. Serialize that queue too,
-- and require proven Production delivery before it can activate paid service.
CREATE FUNCTION dtone_private.setup_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$BEGIN
 IF (NEW.plan='premium' AND lower(coalesce(NEW.provider,'dtone'))='dtone') OR (TG_OP='UPDATE' AND OLD.plan='premium' AND lower(coalesce(OLD.provider,'dtone'))='dtone') THEN
 PERFORM pg_advisory_xact_lock(7381202601);
 IF NEW.plan='premium' AND (lower(coalesce(NEW.provider,''))='dtone' OR EXISTS(SELECT 1 FROM public.topup_executions original WHERE original.wallet_hold_id=NEW.first_refill_hold_id AND lower(original.api_provider)='dtone')) AND NEW.status='active' AND (TG_OP='INSERT' OR OLD.status IS DISTINCT FROM 'active') AND NOT EXISTS(SELECT 1 FROM public.topup_executions e JOIN dtone_private.operations op ON op.execution_id=e.id WHERE e.wallet_hold_id=NEW.first_refill_hold_id AND e.status='success' AND op.environment='production' AND op.proof_status=70000 AND e.dtone_provenance->>'simulation'='false') THEN RAISE EXCEPTION 'Premium activation requires proven Production delivery' USING ERRCODE='DT423'; END IF;
 END IF;RETURN NEW;
END$$;
CREATE TRIGGER dtone_setup_guard BEFORE INSERT OR UPDATE ON public.sim_setup_orders FOR EACH ROW EXECUTE FUNCTION dtone_private.setup_guard();
-- Same guarded sync contract as Reloadly, but DT One never exposes a simulation catalogue to paying customers.
CREATE FUNCTION public.service_sync_dtone_catalog(
  p_environment text,p_version integer,p_activation_revision integer,
  p_country_code text,p_carrier_code text,p_rows jsonb
) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE r dtone_private.runtime%ROWTYPE;
BEGIN
  PERFORM pg_advisory_xact_lock(7381202601);
  SELECT * INTO STRICT r FROM dtone_private.runtime WHERE id=true FOR SHARE;
  IF r.environment IS DISTINCT FROM 'production' OR p_environment IS DISTINCT FROM r.environment OR p_version IS DISTINCT FROM r.version OR p_activation_revision IS DISTINCT FROM r.revision THEN RETURN false; END IF;
  IF p_environment IS NULL OR p_environment <> 'production'
    OR p_country_code IS NULL OR p_carrier_code IS NULL OR p_rows IS NULL
    OR jsonb_typeof(p_rows)<>'array' THEN RAISE EXCEPTION 'Invalid catalogue' USING ERRCODE='DT400'; END IF;
  IF jsonb_array_length(p_rows)>5000 OR EXISTS(
    SELECT 1 FROM jsonb_array_elements(p_rows) x WHERE
      x->>'api_provider' IS DISTINCT FROM 'dtone' OR
      x->>'country_code' IS DISTINCT FROM p_country_code OR
      x->>'carrier_code' IS DISTINCT FROM p_carrier_code OR
      coalesce(x->>'offer_id','')=''
  ) THEN RAISE EXCEPTION 'Invalid catalogue' USING ERRCODE='DT400'; END IF;
  INSERT INTO public.provider_offers_cache(api_provider,offer_id,country_code,carrier_code,offer_name,price_type,price_fixed_usd,price_min_usd,price_max_usd,send_min,send_max,send_currency,send_currency_divisor,source_currency,source_amount_native,fx_usd_to_local,fx_rate_as_of,delivery_type,redeem_instructions,service_type,benefit_summary,data_mb,duration_days,refreshed_at,dtone_provenance)
    SELECT x.api_provider,x.offer_id,x.country_code,x.carrier_code,x.offer_name,x.price_type,x.price_fixed_usd,x.price_min_usd,x.price_max_usd,x.send_min,x.send_max,x.send_currency,x.send_currency_divisor,x.source_currency,x.source_amount_native,x.fx_usd_to_local,x.fx_rate_as_of,x.delivery_type,x.redeem_instructions,x.service_type,x.benefit_summary,x.data_mb,x.duration_days,x.refreshed_at,jsonb_build_object('environment',p_environment,'version',p_version,'activation_revision',p_activation_revision,'simulation',false)
    FROM jsonb_populate_recordset(NULL::public.provider_offers_cache,p_rows) x
    ON CONFLICT(api_provider,offer_id) DO UPDATE SET country_code=excluded.country_code,
      carrier_code=excluded.carrier_code,
      offer_name=excluded.offer_name,
      price_type=excluded.price_type,
      price_fixed_usd=excluded.price_fixed_usd,
      price_min_usd=excluded.price_min_usd,
      price_max_usd=excluded.price_max_usd,
      send_min=excluded.send_min,
      send_max=excluded.send_max,
      send_currency=excluded.send_currency,
      send_currency_divisor=excluded.send_currency_divisor,
      source_currency=excluded.source_currency,
      source_amount_native=excluded.source_amount_native,
      fx_usd_to_local=excluded.fx_usd_to_local,
      fx_rate_as_of=excluded.fx_rate_as_of,
      delivery_type=excluded.delivery_type,
      redeem_instructions=excluded.redeem_instructions,
      service_type=excluded.service_type,
      benefit_summary=excluded.benefit_summary,
      data_mb=excluded.data_mb,
      duration_days=excluded.duration_days,
      refreshed_at=excluded.refreshed_at,dtone_provenance=excluded.dtone_provenance WHERE provider_offers_cache.api_provider='dtone';
  DELETE FROM public.provider_offers_cache p WHERE p.api_provider='dtone'
    AND p.country_code=p_country_code AND p.carrier_code=p_carrier_code
    AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_rows) x WHERE x->>'offer_id'=p.offer_id);
  RETURN true;
END;
$$;
CREATE FUNCTION dtone_private.catalog_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$DECLARE r dtone_private.runtime%ROWTYPE; BEGIN
 IF NEW.api_provider='dtone' THEN
 PERFORM pg_advisory_xact_lock(7381202601);
 SELECT * INTO STRICT r FROM dtone_private.runtime WHERE id=true;
 IF r.environment IS DISTINCT FROM 'production' OR NEW.dtone_provenance->>'environment' IS DISTINCT FROM r.environment OR NEW.dtone_provenance->>'version' IS DISTINCT FROM r.version::text OR NEW.dtone_provenance->>'activation_revision' IS DISTINCT FROM r.revision::text THEN RAISE EXCEPTION 'Stale or simulated DT One catalogue' USING ERRCODE='DT409'; END IF;
 END IF; RETURN NEW;
END$$;
CREATE TRIGGER dtone_catalog_guard BEFORE INSERT OR UPDATE ON public.provider_offers_cache FOR EACH ROW EXECUTE FUNCTION dtone_private.catalog_guard();
CREATE FUNCTION dtone_private.published_offer_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$DECLARE c public.provider_offers_cache%ROWTYPE; r dtone_private.runtime%ROWTYPE; BEGIN
 IF NEW.provider_code='dtone' AND NEW.source_is_active THEN
 PERFORM pg_advisory_xact_lock(7381202601);
 SELECT * INTO STRICT r FROM dtone_private.runtime WHERE id=true;
 SELECT * INTO c FROM public.provider_offers_cache WHERE api_provider='dtone' AND offer_id=NEW.offer_code;
 IF c.offer_id IS NULL OR r.environment IS DISTINCT FROM 'production' OR c.dtone_provenance->>'version' IS DISTINCT FROM r.version::text OR c.dtone_provenance->>'activation_revision' IS DISTINCT FROM r.revision::text OR NEW.source_price_usd IS DISTINCT FROM coalesce(c.price_fixed_usd,c.price_min_usd) OR NEW.source_price_min_usd IS DISTINCT FROM c.price_min_usd OR NEW.source_price_max_usd IS DISTINCT FROM c.price_max_usd OR NEW.source_currency IS DISTINCT FROM c.source_currency OR NEW.source_amount_native IS DISTINCT FROM c.source_amount_native OR NEW.fx_usd_to_local IS DISTINCT FROM c.fx_usd_to_local THEN RAISE EXCEPTION 'Stale DT One published offer' USING ERRCODE='DT409'; END IF;
 NEW.dtone_provenance:=c.dtone_provenance;
 END IF; RETURN NEW;
END$$;
CREATE TRIGGER dtone_published_offer_guard BEFORE INSERT OR UPDATE ON public.provider_offers FOR EACH ROW EXECUTE FUNCTION dtone_private.published_offer_guard();
CREATE FUNCTION public.service_dtone_callback_context(p_environment text,p_external_id text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE o dtone_private.operations%ROWTYPE; pair jsonb; BEGIN
 SELECT * INTO o FROM dtone_private.operations WHERE external_reference=p_external_id AND environment=p_environment;
 IF NOT FOUND THEN RETURN NULL; END IF;
 -- DT Shop callback authentication is an environment setting. Use its latest
 -- validated callback pair; the transaction API still uses the original version.
 SELECT s.decrypted_secret::jsonb INTO pair FROM dtone_private.configs c JOIN dtone_private.versions v ON v.environment=c.environment AND v.version=c.version JOIN vault.decrypted_secrets s ON s.id=v.secret_id WHERE c.environment=o.environment;
 IF NOT pair ?& ARRAY['callback_username','callback_password'] THEN RETURN NULL; END IF;
 RETURN jsonb_build_object('execution_id',o.execution_id,'callback_username',pair->>'callback_username','callback_password',pair->>'callback_password');
END$$;
CREATE FUNCTION public.service_record_dtone_callback(p_execution_id uuid,p_status_code integer) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$BEGIN
 IF p_status_code NOT IN (70000,80000,90000) OR p_status_code IS NULL THEN RAISE EXCEPTION 'Invalid callback status' USING ERRCODE='DT400'; END IF;
 INSERT INTO dtone_private.callback_signals(execution_id,status_code) VALUES(p_execution_id,p_status_code) ON CONFLICT(execution_id) DO UPDATE SET status_code=excluded.status_code,received_at=now() WHERE dtone_private.callback_signals.execution_id=p_execution_id;
 -- This is a wake-up hint only. No raw callback ever settles a wallet or entitlement.
END$$;
-- Operator lookup uses the VM egress, and is never evidence of subscriber liveness.
CREATE TABLE dtone_private.lookups(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),secret_id uuid NOT NULL,environment text NOT NULL,version integer NOT NULL,revision integer NOT NULL,created_at timestamptz NOT NULL DEFAULT now(),state text NOT NULL DEFAULT 'queued',lease uuid,result jsonb);
ALTER TABLE dtone_private.lookups ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON dtone_private.lookups FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION public.service_enqueue_dtone_lookup(p_phone text) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$DECLARE r dtone_private.runtime%ROWTYPE; sid uuid; jid uuid; BEGIN
 IF p_phone IS NULL OR p_phone!~'^\+[1-9][0-9]{6,14}$' THEN RAISE EXCEPTION 'Invalid phone' USING ERRCODE='DT400'; END IF;
 SELECT * INTO STRICT r FROM dtone_private.runtime WHERE id=true;
 IF r.environment IS NULL OR NOT r.release_verified THEN RETURN NULL; END IF;
 IF (SELECT count(*) FROM dtone_private.lookups WHERE created_at>now()-interval '30 seconds')>100 THEN RETURN NULL; END IF;
 SELECT vault.create_secret(p_phone,NULL,'DT One short-lived lookup') INTO sid;
 INSERT INTO dtone_private.lookups(secret_id,environment,version,revision) VALUES(sid,r.environment,r.version,r.revision) RETURNING id INTO jid; RETURN jid;
END$$;
CREATE FUNCTION public.service_claim_dtone_lookup() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$DECLARE j dtone_private.lookups%ROWTYPE; pair jsonb; phone text; BEGIN
 DELETE FROM vault.secrets s WHERE EXISTS(SELECT 1 FROM dtone_private.lookups l WHERE l.secret_id=s.id AND l.created_at<now()-interval '1 minute');
 DELETE FROM dtone_private.lookups WHERE created_at<now()-interval '1 minute';
 SELECT * INTO j FROM dtone_private.lookups WHERE state='queued' AND created_at>now()-interval '25 seconds' ORDER BY created_at FOR UPDATE SKIP LOCKED LIMIT 1;
 IF NOT FOUND THEN RETURN NULL; END IF;
 UPDATE dtone_private.lookups SET state='running',lease=gen_random_uuid() WHERE id=j.id RETURNING * INTO j;
 SELECT decrypted_secret INTO phone FROM vault.decrypted_secrets WHERE id=j.secret_id;
 SELECT s.decrypted_secret::jsonb INTO pair FROM dtone_private.versions v JOIN vault.decrypted_secrets s ON s.id=v.secret_id WHERE v.environment=j.environment AND v.version=j.version;
 RETURN jsonb_build_object('id',j.id,'lease',j.lease,'environment',j.environment,'pair',pair,'phone',phone);
END$$;
CREATE FUNCTION public.service_complete_dtone_lookup(p_id uuid,p_lease uuid,p_result jsonb) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$BEGIN
 IF p_result IS NULL OR jsonb_typeof(p_result)<>'object' OR EXISTS(SELECT 1 FROM jsonb_object_keys(p_result) k WHERE k NOT IN ('operator_id','operator_name','country','code')) OR octet_length(p_result::text)>512 THEN RAISE EXCEPTION 'Invalid lookup result' USING ERRCODE='DT400'; END IF;
 UPDATE dtone_private.lookups SET state='done',result=p_result WHERE id=p_id AND lease=p_lease AND state='running' AND created_at>now()-interval '30 seconds';
 DELETE FROM vault.secrets s WHERE EXISTS(SELECT 1 FROM dtone_private.lookups l WHERE l.id=p_id AND l.secret_id=s.id AND l.state='done');
END$$;
CREATE FUNCTION public.service_dtone_lookup_result(p_id uuid) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$SELECT jsonb_build_object('state',state,'environment',environment,'simulation',environment='preproduction','result',result) FROM dtone_private.lookups WHERE id=p_id AND created_at>now()-interval '30 seconds'$$;
-- DT One submissions have an independent, persisted one-shot boundary. This
-- delegates successful settlement to the existing financial RPC, rather than
-- deploying any unrelated pending financial migration or changing other providers.
ALTER TABLE dtone_private.operations ADD COLUMN submitted_at timestamptz, ADD COLUMN provider_transaction_id text, ADD COLUMN proof_status integer, ADD COLUMN proof_at timestamptz, ADD COLUMN next_lookup timestamptz DEFAULT now(), ADD COLUMN lookup_lease uuid, ADD COLUMN lookup_lease_until timestamptz;
CREATE FUNCTION dtone_private.funding_bound(p_execution_id uuid,p_hold_id uuid) RETURNS boolean LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM public.topup_executions e JOIN public.wallet_holds h ON h.id=e.wallet_hold_id JOIN public.wallets w ON w.id=h.wallet_id JOIN public.sim_lines line ON line.id=e.sim_line_id
 WHERE e.id=p_execution_id AND h.id=p_hold_id AND h.user_id=e.user_id AND w.user_id=e.user_id AND line.user_id=e.user_id AND e.currency='USD' AND h.currency=e.currency AND w.currency=e.currency AND h.amount=e.amount AND e.amount>0 AND coalesce(e.payment_gateway_code,'wallet')='wallet'
 AND NOT EXISTS(SELECT 1 FROM public.topup_executions other WHERE other.wallet_hold_id=h.id AND other.id<>e.id)
 AND ((h.order_type IN ('refill_instant','refill_scheduled','refill_mini','refill_custom') AND h.order_reference_id IN (e.id::text,'exec_'||e.id::text))
 OR (h.order_type='setup_refill' AND EXISTS(SELECT 1 FROM public.sim_setup_orders setup WHERE setup.first_refill_hold_id=h.id AND setup.user_id=e.user_id AND setup.sim_line_id=e.sim_line_id AND setup.plan='premium' AND setup.status IN ('reserved','dispatching','active') AND setup.first_refill_cost_usd=e.amount AND h.order_reference_id='setup_refill_'||setup.id::text))))
$$;
CREATE FUNCTION public.service_begin_dtone_submission(p_execution_id uuid) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE e public.topup_executions%ROWTYPE; o dtone_private.operations%ROWTYPE; h public.wallet_holds%ROWTYPE; r dtone_private.runtime%ROWTYPE; BEGIN
 PERFORM pg_advisory_xact_lock(7381202601);
 SELECT * INTO STRICT r FROM dtone_private.runtime WHERE id=true FOR SHARE;
 SELECT * INTO STRICT e FROM public.topup_executions WHERE id=p_execution_id FOR UPDATE;
 SELECT * INTO o FROM dtone_private.operations WHERE execution_id=e.id FOR UPDATE;
 IF NOT r.release_verified OR r.environment IS DISTINCT FROM 'production' OR o.environment IS DISTINCT FROM r.environment OR o.version IS DISTINCT FROM r.version OR o.revision IS DISTINCT FROM r.revision THEN RETURN false; END IF;
 IF o.execution_id IS NULL OR o.environment<>'production' OR e.dtone_provenance->>'simulation' IS DISTINCT FROM 'false' OR o.submitted_at IS NOT NULL OR e.status NOT IN ('processing','routing','pending') OR e.reloadly_transaction_id IS NOT NULL OR coalesce(e.carrier_in_flight,false) THEN RETURN false; END IF;
 IF e.wallet_hold_id IS NULL THEN RAISE EXCEPTION 'Bound wallet reservation required' USING ERRCODE='DT423'; END IF;
 SELECT * INTO h FROM public.wallet_holds WHERE id=e.wallet_hold_id FOR UPDATE;
 IF h.id IS NULL OR h.user_id IS DISTINCT FROM e.user_id OR h.currency IS DISTINCT FROM 'USD' OR h.amount IS DISTINCT FROM e.amount OR h.amount<=0 OR h.status<>'active' OR h.expires_at IS NULL OR h.expires_at<=clock_timestamp() OR NOT dtone_private.funding_bound(e.id,h.id) THEN RAISE EXCEPTION 'DT One funding binding invalid' USING ERRCODE='DT423'; END IF;
 UPDATE dtone_private.operations SET submitted_at=now(),next_lookup=now()+interval '40 seconds' WHERE execution_id=e.id;
 UPDATE public.topup_executions SET api_provider='dtone',carrier_in_flight=true WHERE id=e.id;
 UPDATE public.wallet_holds SET carrier_in_flight=true WHERE id=h.id;
 RETURN true;
END$$;
CREATE FUNCTION public.service_fail_dtone_before_submission(p_execution_id uuid,p_code text) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE e public.topup_executions%ROWTYPE; h public.wallet_holds%ROWTYPE; BEGIN
 PERFORM pg_advisory_xact_lock(7381202601);
 SELECT * INTO STRICT e FROM public.topup_executions WHERE id=p_execution_id FOR UPDATE;
 IF e.status='success' OR coalesce(e.carrier_in_flight,false) OR e.reloadly_transaction_id IS NOT NULL OR EXISTS(SELECT 1 FROM dtone_private.operations WHERE execution_id=e.id AND submitted_at IS NOT NULL) THEN RETURN false; END IF;
 IF lower(coalesce(e.api_provider,'dtone'))<>'dtone' AND NOT EXISTS(SELECT 1 FROM dtone_private.operations WHERE execution_id=e.id) THEN RETURN false; END IF;
 IF e.wallet_hold_id IS NOT NULL THEN
 SELECT * INTO h FROM public.wallet_holds WHERE id=e.wallet_hold_id FOR UPDATE;
 IF h.user_id IS DISTINCT FROM e.user_id OR h.currency IS DISTINCT FROM 'USD' OR h.amount IS DISTINCT FROM e.amount OR h.status NOT IN ('active','released') OR NOT dtone_private.funding_bound(e.id,h.id) THEN RETURN false; END IF;
 PERFORM public.release_wallet_hold(h.id,'DT One stopped before provider submission');
 END IF;
 UPDATE public.topup_executions SET status='failed',failure_reason=CASE WHEN p_code='simulation_only' THEN 'DT One Pre-production is simulation only; no real airtime delivered or paid entitlement granted' ELSE 'DT One could not submit this recharge; check provider configuration and refresh the offer' END WHERE id=e.id;
 RETURN true;
END$$;
CREATE FUNCTION public.service_resolve_dtone_operation(p_execution_id uuid,p_provider_tx_id text,p_status_id integer,p_pin_code text DEFAULT NULL,p_pin_serial text DEFAULT NULL,p_instructions text DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE e public.topup_executions%ROWTYPE; o dtone_private.operations%ROWTYPE; h public.wallet_holds%ROWTYPE; result jsonb; BEGIN
 PERFORM pg_advisory_xact_lock(7381202601);
 SELECT * INTO STRICT e FROM public.topup_executions WHERE id=p_execution_id FOR UPDATE;
 SELECT * INTO o FROM dtone_private.operations WHERE execution_id=e.id FOR UPDATE;
 IF o.execution_id IS NULL OR o.submitted_at IS NULL OR o.environment<>'production' OR p_provider_tx_id IS NULL OR p_provider_tx_id!~'^[0-9]{1,20}$' OR p_status_id IS NULL OR p_status_id NOT IN (10000,20000,30000,40000,50000,70000,80000,90000) OR (o.provider_transaction_id IS NOT NULL AND o.provider_transaction_id<>p_provider_tx_id) THEN RAISE EXCEPTION 'Original provider proof required' USING ERRCODE='DT423'; END IF;
 IF o.proof_status=70000 AND p_status_id<>80000 THEN
 UPDATE dtone_private.operations SET proof_at=now(),lookup_lease=NULL,lookup_lease_until=NULL,next_lookup=now()+interval '30 seconds' WHERE execution_id=e.id;
 RETURN jsonb_build_object('outcome','success','idempotent',true); END IF;
 IF o.proof_status IN (30000,40000,90000) THEN RETURN jsonb_build_object('outcome','failed','idempotent',true); END IF;
 UPDATE dtone_private.operations SET provider_transaction_id=p_provider_tx_id,proof_status=p_status_id,proof_at=now(),next_lookup=now()+interval '30 seconds',lookup_lease=NULL,lookup_lease_until=NULL WHERE execution_id=e.id;
 IF p_status_id=80000 THEN
 UPDATE public.topup_executions SET carrier_in_flight=true,failure_reason='DT One reports a reversal; operator reconciliation is required',dtone_provenance=dtone_provenance||jsonb_build_object('provider_status','reversed','reconciliation_required',true) WHERE id=e.id;
 RETURN jsonb_build_object('outcome','operator_review'); END IF;
 IF p_status_id NOT IN (30000,40000,70000,90000) THEN RETURN jsonb_build_object('outcome','pending'); END IF;
 SELECT * INTO h FROM public.wallet_holds WHERE id=e.wallet_hold_id FOR UPDATE;
 IF h.id IS NULL OR h.user_id IS DISTINCT FROM e.user_id OR h.currency IS DISTINCT FROM 'USD' OR h.amount IS DISTINCT FROM e.amount OR h.amount<=0 OR h.status NOT IN ('active','captured') OR NOT dtone_private.funding_bound(e.id,h.id) THEN RAISE EXCEPTION 'DT One funding binding invalid' USING ERRCODE='DT423'; END IF;
 IF p_status_id=70000 THEN
 result:=public.settle_successful_execution(e.id,p_provider_tx_id,h.id,p_pin_code,p_pin_serial,p_instructions,jsonb_build_object('provider','dtone','environment',o.environment,'credential_version',o.version,'activation_revision',o.revision,'external_id',o.external_reference,'simulation',false));
 IF result->>'success' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Settlement not confirmed' USING ERRCODE='DT503'; END IF;
 IF nullif(p_pin_code,'') IS NOT NULL THEN
 INSERT INTO public.notifications(user_id,category,title,body,sim_line_id) VALUES(e.user_id,'system','Your recharge PIN is ready','Your PIN code is '||p_pin_code||CASE WHEN nullif(p_instructions,'') IS NULL THEN '' ELSE '. '||p_instructions END,e.sim_line_id);
 END IF;
 ELSE
 IF h.status<>'active' THEN RAISE EXCEPTION 'Captured delivery requires operator review' USING ERRCODE='DT423'; END IF;
 PERFORM public.release_wallet_hold(h.id,'DT One confirmed terminal rejection');
 UPDATE public.topup_executions SET status='failed',failure_reason='DT One confirmed the transaction was declined or cancelled',reloadly_transaction_id=p_provider_tx_id WHERE id=e.id;
 END IF;
 UPDATE public.topup_executions SET carrier_in_flight=false WHERE id=e.id;
 UPDATE public.wallet_holds SET carrier_in_flight=false WHERE id=h.id;
 RETURN jsonb_build_object('outcome',CASE WHEN p_status_id=70000 THEN 'success' ELSE 'failed' END);
END$$;
CREATE FUNCTION public.service_claim_dtone_reconciliation() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$DECLARE o dtone_private.operations%ROWTYPE; BEGIN
 SELECT op.* INTO o FROM dtone_private.operations op JOIN public.topup_executions e ON e.id=op.execution_id
 WHERE op.submitted_at IS NOT NULL AND (coalesce(op.proof_status,0) NOT IN (30000,40000,70000,80000,90000) OR (op.proof_status=70000 AND EXISTS(SELECT 1 FROM dtone_private.callback_signals signal WHERE signal.execution_id=op.execution_id AND signal.status_code=80000 AND signal.received_at>op.proof_at)))
 AND (op.lookup_lease_until IS NULL OR op.lookup_lease_until<now())
 AND (op.next_lookup<=now() OR EXISTS(SELECT 1 FROM dtone_private.callback_signals cs WHERE cs.execution_id=op.execution_id AND cs.received_at>coalesce(op.proof_at,op.submitted_at)))
 ORDER BY op.next_lookup FOR UPDATE OF op SKIP LOCKED LIMIT 1;
 IF NOT FOUND THEN RETURN NULL; END IF;
 UPDATE dtone_private.operations SET lookup_lease=gen_random_uuid(),lookup_lease_until=now()+interval '45 seconds',next_lookup=now()+interval '30 seconds' WHERE execution_id=o.execution_id RETURNING * INTO o;
 RETURN jsonb_build_object('execution_id',o.execution_id,'external_reference',o.external_reference,'lease',o.lookup_lease);
END$$;
-- A delayed reconciliation response can only resolve the exact leased operation.
CREATE FUNCTION public.service_complete_dtone_reconciliation(p_execution_id uuid,p_lease uuid,p_provider_tx_id text,p_status_id integer,p_pin_code text DEFAULT NULL,p_pin_serial text DEFAULT NULL,p_instructions text DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$DECLARE o dtone_private.operations%ROWTYPE; BEGIN
 PERFORM pg_advisory_xact_lock(7381202601);
 SELECT * INTO o FROM dtone_private.operations WHERE execution_id=p_execution_id FOR UPDATE;
 IF o.lookup_lease IS DISTINCT FROM p_lease OR p_lease IS NULL OR o.lookup_lease_until<clock_timestamp() THEN RETURN jsonb_build_object('outcome','expired'); END IF;
 IF p_provider_tx_id IS NULL OR p_status_id IS NULL THEN
 UPDATE dtone_private.operations SET lookup_lease=NULL,lookup_lease_until=NULL,next_lookup=now()+interval '1 minute' WHERE execution_id=o.execution_id;
 RETURN jsonb_build_object('outcome','unresolved'); END IF;
 RETURN public.service_resolve_dtone_operation(p_execution_id,p_provider_tx_id,p_status_id,p_pin_code,p_pin_serial,p_instructions);
END$$;

-- Default privileges can grant exposed RPCs automatically; revoke before explicit role grants.
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA dtone_private FROM PUBLIC,anon,authenticated,service_role;
DO $$DECLARE f record; BEGIN
 FOR f IN SELECT p.oid::regprocedure AS signature,p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND (p.proname LIKE 'admin_dtone_%' OR p.proname LIKE 'service_%dtone%' OR p.proname='get_dtone_runtime_credentials') LOOP
 EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated,service_role',f.signature);
 EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO %I',f.signature,CASE WHEN f.proname LIKE 'admin_dtone_%' THEN 'authenticated' ELSE 'service_role' END);
 END LOOP;
END$$;
COMMIT;
