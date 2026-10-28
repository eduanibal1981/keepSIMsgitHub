-- ESIM-07: private compatible TOPUP discovery and immutable, non-spending quotes.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $preflight$ BEGIN
 IF md5(pg_get_functiondef('public.resolve_esim_offer_price(numeric,uuid)'::regprocedure))<>'db0fc0960113fb3cac910c0f63cbb3cb'
  OR md5(pg_get_functiondef('public.get_wallet_summary(uuid)'::regprocedure))<>'003fc42f897def9e424e83651dd9e53a' THEN
  RAISE EXCEPTION 'ESIM-07 pricing/wallet source drift: inspect before applying';
 END IF;
END $preflight$;
CREATE TABLE esim_private.recharge_policy (
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
 discovery_enabled boolean NOT NULL DEFAULT false,
 catalogue_revision bigint NOT NULL DEFAULT 1,
 last_worker_seen_at timestamptz, last_discovery_at timestamptz
);
INSERT INTO esim_private.recharge_policy DEFAULT VALUES;
CREATE TABLE esim_private.topup_cache (
 profile_id uuid PRIMARY KEY REFERENCES public.user_esims(id) ON DELETE CASCADE,
 owner_id uuid NOT NULL, account_id uuid NOT NULL REFERENCES esim_private.accounts(id),
 context text NOT NULL, status text NOT NULL CHECK(status IN('pending','leased','ready','error')),
 requested_at timestamptz NOT NULL DEFAULT now(), lease uuid, lease_until timestamptz,
 fetched_at timestamptz, expires_at timestamptz, version uuid NOT NULL DEFAULT gen_random_uuid(),
 offers jsonb, error_code text
);
CREATE INDEX topup_cache_due ON esim_private.topup_cache(requested_at) WHERE status IN('pending','leased');
CREATE TABLE esim_private.recharge_quotes (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), acceptance_key uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
 owner_id uuid NOT NULL, payer_id uuid NOT NULL CHECK(payer_id=owner_id),
 profile_id uuid NOT NULL REFERENCES public.user_esims(id) ON DELETE CASCADE,
 account_id uuid NOT NULL REFERENCES esim_private.accounts(id), provider text NOT NULL CHECK(provider='esimaccess'),
 action text NOT NULL CHECK(action='fixed_bundle_recharge'), package_id text NOT NULL,
 cache_version uuid NOT NULL, context text NOT NULL, wholesale_usd numeric NOT NULL CHECK(wholesale_usd>0),
 retail_total numeric(12,2) NOT NULL CHECK(retail_total>0), currency text NOT NULL CHECK(currency='USD'),
 duration_value integer NOT NULL, duration_unit text NOT NULL, period_count integer NOT NULL DEFAULT 1 CHECK(period_count=1),
 retail_snapshot jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), expires_at timestamptz NOT NULL
);
CREATE INDEX recharge_quotes_owner_profile ON esim_private.recharge_quotes(owner_id,profile_id,created_at);
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['recharge_policy','topup_cache','recharge_quotes'] LOOP
  EXECUTE format('ALTER TABLE esim_private.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('REVOKE ALL ON esim_private.%I FROM PUBLIC,anon,authenticated',t);
  EXECUTE format('GRANT SELECT ON esim_private.%I TO service_role',t);
 END LOOP;
END $$;

CREATE FUNCTION esim_private.topup_context(p public.user_esims) RETURNS text
LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT md5(jsonb_build_array(p.user_id,p.provider,p.supplier_account_id,p.supplier_profile_ref,p.iccid,
 p.profile_state,p.bundle_state,p.installation_state,p.confirmed_expires_at,p.activation_deadline_at,
 p.last_observation_at,p.usage_error_code,p.plan_details,
 (SELECT catalogue_revision FROM esim_private.recharge_policy WHERE singleton))::text);
$$;
CREATE FUNCTION esim_private.topup_refusal(p public.user_esims) RETURNS text
LANGUAGE plpgsql STABLE SET search_path='' AS $$
BEGIN
 IF p.provider<>'esimaccess' OR p.supplier_account_id IS NULL OR nullif(p.supplier_profile_ref,'') IS NULL
  OR coalesce(p.iccid,'')!~'^[0-9]{15,22}$' THEN RETURN 'UNSUPPORTED_PROFILE'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.esim_suppliers WHERE code=p.provider AND is_active)
  OR NOT EXISTS(SELECT 1 FROM esim_private.accounts WHERE id=p.supplier_account_id AND provider=p.provider AND account_key='primary') THEN RETURN 'SUPPLIER_DISABLED'; END IF;
 IF p.profile_state IN('expired','cancelled','revoked') OR p.bundle_state IN('expired','cancelled')
  OR p.confirmed_expires_at<=now() OR (p.bundle_state='not_started' AND p.activation_deadline_at<=now()) THEN RETURN 'PROFILE_EXPIRED'; END IF;
 IF p.profile_state NOT IN('issued','active') OR p.bundle_state NOT IN('not_started','active','depleted')
  OR p.installation_state NOT IN('released','downloaded','installed','enabled') THEN RETURN 'PROFILE_UNAVAILABLE'; END IF;
 IF p.last_observation_at IS NULL OR p.last_observation_at<now()-interval '15 minutes' OR p.usage_error_code IS NOT NULL
  OR (p.bundle_state IN('active','depleted') AND p.confirmed_expires_at IS NULL) THEN RETURN 'PROFILE_REFRESH_REQUIRED'; END IF;
 IF p.plan_details->>'topup_support'='unsupported' THEN RETURN 'TOPUP_UNSUPPORTED'; END IF;
 IF coalesce(p.plan_details->>'topup_support','unknown') NOT IN('supported','daily_extension') THEN RETURN 'CAPABILITY_UNVERIFIED'; END IF;
 IF EXISTS(SELECT 1 FROM esim_private.order_runs WHERE order_id=p.order_id AND state<>'completed')
  OR EXISTS(SELECT 1 FROM public.esim_orders WHERE id=p.order_id AND status IN('pending','processing')) THEN RETURN 'UNRESOLVED_OPERATION'; END IF;
 RETURN NULL;
END $$;
CREATE FUNCTION esim_private.topup_retail(o jsonb,u uuid) RETURNS jsonb
LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT jsonb_build_object('package_id',o->>'package_id','title',o->>'title','currency','USD',
 'allowance_bytes',o->>'allowance_bytes','data_type',(o->>'data_type')::integer,
 'duration_value',(o->>'duration_value')::integer,'duration_unit',o->>'duration_unit',
 'effect',CASE WHEN o->>'data_type'='1' THEN 'allowance_and_validity' ELSE 'validity_only' END,
 'quote_supported',o->>'data_type'='1','discovery_type','TOPUP',
 'retail_total',public.resolve_esim_offer_price((o->>'wholesale_usd')::numeric,u),
 'expiry_provisional',true,'post_recharge_expires_at',NULL);
$$;
CREATE FUNCTION esim_private.topup_balance(u uuid,total numeric) RETURNS jsonb
LANGUAGE plpgsql SET search_path='' AS $$
DECLARE b jsonb; available numeric;
BEGIN
 BEGIN
  b:=public.get_wallet_summary(u);
  IF b->>'currency' IS DISTINCT FROM 'USD' OR b->>'available_balance' IS NULL THEN RAISE EXCEPTION 'Unavailable'; END IF;
  available:=(b->>'available_balance')::numeric;
  IF available::text IN('NaN','Infinity','-Infinity') OR available<0 THEN RAISE EXCEPTION 'Unavailable'; END IF;
  RETURN jsonb_build_object('balance_state',CASE WHEN available>=total THEN 'sufficient' ELSE 'insufficient' END,'available_balance',available);
 EXCEPTION WHEN OTHERS THEN RETURN '{"balance_state":"unknown","available_balance":null}'::jsonb;
 END;
END $$;
CREATE FUNCTION esim_private.topup_catalogue_changed() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN UPDATE esim_private.recharge_policy SET catalogue_revision=catalogue_revision+1 WHERE singleton; RETURN NULL; END $$;
CREATE TRIGGER topup_catalogue_changed AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON public.esim_offers_cache
FOR EACH STATEMENT EXECUTE FUNCTION esim_private.topup_catalogue_changed();

CREATE FUNCTION public.request_esim_topups(p_profile_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); p public.user_esims%ROWTYPE; c esim_private.topup_cache%ROWTYPE; reason text; ctx text; items jsonb;
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
 SELECT * INTO p FROM public.user_esims WHERE id=p_profile_id AND user_id=u FOR UPDATE;
 IF NOT FOUND THEN RETURN '{"status":"PROFILE_UNAVAILABLE"}'::jsonb; END IF;
 IF NOT (SELECT discovery_enabled FROM esim_private.recharge_policy WHERE singleton) THEN RETURN '{"status":"DISCOVERY_DISABLED"}'::jsonb; END IF;
 reason:=esim_private.topup_refusal(p);
 IF reason IS NOT NULL THEN RETURN jsonb_build_object('status',reason); END IF;
 ctx:=esim_private.topup_context(p);
 SELECT * INTO c FROM esim_private.topup_cache WHERE profile_id=p.id FOR UPDATE;
 IF FOUND AND c.context=ctx AND c.owner_id=u AND c.account_id=p.supplier_account_id THEN
  IF c.status='ready' AND c.expires_at>now() THEN
   SELECT coalesce(jsonb_agg(esim_private.topup_retail(value,u)),'[]') INTO items FROM jsonb_array_elements(c.offers);
   RETURN jsonb_build_object('status',CASE WHEN jsonb_array_length(items)=0 THEN 'NO_COMPATIBLE_OFFERS' ELSE 'READY' END,
    'offers',items,'offer_version',c.version,'expires_at',c.expires_at,'acceptance_enabled',false);
  END IF;
  IF c.status IN('pending','leased') AND c.requested_at>now()-interval '2 minutes' THEN RETURN '{"status":"PENDING"}'::jsonb; END IF;
  IF c.status='error' AND c.requested_at>now()-interval '30 seconds' THEN RETURN '{"status":"PROVIDER_UNAVAILABLE"}'::jsonb; END IF;
 END IF;
 INSERT INTO esim_private.topup_cache(profile_id,owner_id,account_id,context,status) VALUES(p.id,u,p.supplier_account_id,ctx,'pending')
 ON CONFLICT(profile_id) DO UPDATE SET owner_id=excluded.owner_id,account_id=excluded.account_id,context=excluded.context,
 status='pending',requested_at=now(),lease=NULL,lease_until=NULL,offers=NULL,fetched_at=NULL,expires_at=NULL,error_code=NULL,version=gen_random_uuid();
 RETURN '{"status":"PENDING"}'::jsonb;
END $$;
CREATE FUNCTION public.service_esim_claim_topups(p_account_key text DEFAULT 'primary') RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c esim_private.topup_cache%ROWTYPE; p public.user_esims%ROWTYPE;
BEGIN
 PERFORM esim_private.require_service();
 UPDATE esim_private.recharge_policy SET last_worker_seen_at=clock_timestamp() WHERE singleton;
 IF NOT (SELECT discovery_enabled FROM esim_private.recharge_policy WHERE singleton) THEN RETURN NULL; END IF;
 SELECT cache.* INTO c FROM esim_private.topup_cache cache JOIN esim_private.accounts a ON a.id=cache.account_id
 WHERE a.account_key=p_account_key AND cache.status IN('pending','leased') AND (cache.lease_until IS NULL OR cache.lease_until<now())
 ORDER BY requested_at FOR UPDATE OF cache SKIP LOCKED LIMIT 1;
 IF NOT FOUND THEN RETURN NULL; END IF;
 SELECT * INTO p FROM public.user_esims WHERE id=c.profile_id;
 IF NOT FOUND OR p.user_id IS DISTINCT FROM c.owner_id OR p.supplier_account_id IS DISTINCT FROM c.account_id
  OR c.context IS DISTINCT FROM esim_private.topup_context(p) OR esim_private.topup_refusal(p) IS NOT NULL THEN
  UPDATE esim_private.topup_cache SET status='error',error_code='PROFILE_CHANGED',offers=NULL,lease=NULL,lease_until=NULL WHERE profile_id=c.profile_id;
  RETURN NULL;
 END IF;
 UPDATE esim_private.topup_cache SET status='leased',lease=gen_random_uuid(),lease_until=now()+interval '90 seconds'
 WHERE profile_id=c.profile_id RETURNING * INTO c;
 RETURN jsonb_build_object('profile_id',p.id,'lease',c.lease,'account_key',p_account_key,'supplier_profile_ref',p.supplier_profile_ref,'iccid',p.iccid);
END $$;
CREATE FUNCTION public.service_esim_save_topups(p_profile_id uuid,p_lease uuid,p_offers jsonb DEFAULT NULL,p_error_code text DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c esim_private.topup_cache%ROWTYPE; p public.user_esims%ROWTYPE; o jsonb;
BEGIN
 PERFORM esim_private.require_service();
 SELECT * INTO p FROM public.user_esims WHERE id=p_profile_id FOR UPDATE;
 SELECT * INTO c FROM esim_private.topup_cache WHERE profile_id=p_profile_id FOR UPDATE;
 IF NOT FOUND OR p_lease IS NULL OR c.lease IS DISTINCT FROM p_lease OR c.lease_until IS NULL OR c.lease_until<now() OR c.status<>'leased' THEN RETURN '{"saved":false}'::jsonb; END IF;
 IF p.user_id IS DISTINCT FROM c.owner_id OR p.supplier_account_id IS DISTINCT FROM c.account_id
  OR c.context IS DISTINCT FROM esim_private.topup_context(p) OR esim_private.topup_refusal(p) IS NOT NULL
  OR NOT (SELECT discovery_enabled FROM esim_private.recharge_policy WHERE singleton) THEN p_error_code:='PROFILE_CHANGED'; END IF;
 IF p_error_code IS NOT NULL THEN
  UPDATE esim_private.topup_cache SET status='error',offers=NULL,error_code=CASE WHEN p_error_code~'^[A-Z0-9_]{1,64}$' THEN p_error_code ELSE 'PROVIDER_UNAVAILABLE' END,
   lease=NULL,lease_until=NULL WHERE profile_id=p_profile_id;
  RETURN '{"saved":false}'::jsonb;
 END IF;
 IF p_offers IS NULL OR jsonb_typeof(p_offers)<>'array' OR jsonb_array_length(p_offers)>500 OR octet_length(p_offers::text)>1048576 THEN RAISE EXCEPTION 'Invalid TOPUP offers'; END IF;
 FOR o IN SELECT value FROM jsonb_array_elements(p_offers) LOOP
  IF coalesce(o->>'discovery_type','')<>'TOPUP' OR coalesce(o->>'currency','')<>'USD' OR coalesce(o->>'package_id','')='' OR length(o->>'package_id')>100
   OR coalesce(o->>'wholesale_usd','')!~'^[0-9]+(\.[0-9]+)?$' OR (o->>'wholesale_usd')::numeric<=0
   OR coalesce(o->>'data_type','') NOT IN('1','2','3','4') OR coalesce(o->>'allowance_bytes','')!~'^[0-9]{1,16}$'
   OR coalesce(o->>'duration_value','')!~'^[0-9]{1,4}$' OR (o->>'duration_value')::integer<1
   OR coalesce(o->>'duration_unit','') NOT IN('DAY','HOUR') THEN RAISE EXCEPTION 'Invalid TOPUP offer'; END IF;
 END LOOP;
 IF (SELECT count(*)<>count(DISTINCT value->>'package_id') FROM jsonb_array_elements(p_offers)) THEN RAISE EXCEPTION 'Duplicate TOPUP offers'; END IF;
 UPDATE esim_private.topup_cache SET status='ready',offers=p_offers,fetched_at=now(),expires_at=now()+interval '5 minutes',
 version=gen_random_uuid(),lease=NULL,lease_until=NULL,error_code=NULL WHERE profile_id=p_profile_id;
 UPDATE esim_private.recharge_policy SET last_discovery_at=clock_timestamp() WHERE singleton;
 RETURN '{"saved":true}'::jsonb;
END $$;

CREATE FUNCTION public.quote_esim_topup(p_profile_id uuid,p_package_id text,p_offer_version uuid,p_expected_total numeric) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); p public.user_esims%ROWTYPE; c esim_private.topup_cache%ROWTYPE; q esim_private.recharge_quotes%ROWTYPE;
 o jsonb; retail jsonb; total numeric; reason text;
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
 SELECT * INTO p FROM public.user_esims WHERE id=p_profile_id AND user_id=u FOR UPDATE;
 IF NOT FOUND THEN RETURN '{"status":"PROFILE_UNAVAILABLE"}'::jsonb; END IF;
 IF NOT (SELECT discovery_enabled FROM esim_private.recharge_policy WHERE singleton) THEN RETURN '{"status":"DISCOVERY_DISABLED"}'::jsonb; END IF;
 reason:=esim_private.topup_refusal(p); IF reason IS NOT NULL THEN RETURN jsonb_build_object('status',reason); END IF;
 SELECT * INTO c FROM esim_private.topup_cache WHERE profile_id=p.id AND owner_id=u AND account_id=p.supplier_account_id;
 IF NOT FOUND OR c.status<>'ready' OR c.expires_at<=now() OR c.context IS DISTINCT FROM esim_private.topup_context(p)
  OR p_offer_version IS NULL OR c.version IS DISTINCT FROM p_offer_version THEN RETURN '{"status":"STALE_OFFERS"}'::jsonb; END IF;
 SELECT value INTO o FROM jsonb_array_elements(c.offers) WHERE value->>'package_id'=p_package_id;
 IF NOT FOUND THEN RETURN '{"status":"INCOMPATIBLE_OFFER"}'::jsonb; END IF;
 IF o->>'data_type'<>'1' THEN RETURN '{"status":"DURATION_QUOTE_UNAVAILABLE"}'::jsonb; END IF;
 retail:=esim_private.topup_retail(o,u); total:=(retail->>'retail_total')::numeric;
 IF total IS NULL OR total<=0 OR total::text IN('NaN','Infinity','-Infinity') THEN RETURN '{"status":"PRICE_UNAVAILABLE"}'::jsonb; END IF;
 IF p_expected_total IS NULL OR total IS DISTINCT FROM p_expected_total THEN RETURN '{"status":"PRICE_CHANGED"}'::jsonb; END IF;
 SELECT * INTO q FROM esim_private.recharge_quotes WHERE owner_id=u AND profile_id=p.id AND cache_version=c.version
  AND package_id=p_package_id AND retail_total=total AND expires_at>now() ORDER BY created_at DESC LIMIT 1;
 IF NOT FOUND THEN
  IF (SELECT count(*) FROM esim_private.recharge_quotes WHERE owner_id=u AND created_at>now()-interval '1 minute')>=20 THEN RETURN '{"status":"RATE_LIMITED"}'::jsonb; END IF;
  INSERT INTO esim_private.recharge_quotes(owner_id,payer_id,profile_id,account_id,provider,action,package_id,cache_version,context,
   wholesale_usd,retail_total,currency,duration_value,duration_unit,retail_snapshot,expires_at)
  VALUES(u,u,p.id,p.supplier_account_id,p.provider,'fixed_bundle_recharge',p_package_id,c.version,c.context,
   (o->>'wholesale_usd')::numeric,total,'USD',(o->>'duration_value')::integer,o->>'duration_unit',retail,least(c.expires_at,now()+interval '2 minutes')) RETURNING * INTO q;
 END IF;
 RETURN jsonb_build_object('status','QUOTED','quote_id',q.id,'acceptance_key',q.acceptance_key,'owner_id',u,'payer_id',u,
  'profile_id',p.id,'action',q.action,'offer',q.retail_snapshot,'expires_at',q.expires_at,'acceptance_enabled',false)
  ||esim_private.topup_balance(u,total);
END $$;
CREATE FUNCTION public.check_esim_topup_quote(p_quote_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); p public.user_esims%ROWTYPE; q esim_private.recharge_quotes%ROWTYPE; c esim_private.topup_cache%ROWTYPE;
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
 SELECT * INTO q FROM esim_private.recharge_quotes WHERE id=p_quote_id AND owner_id=u AND payer_id=u;
 IF NOT FOUND THEN RETURN '{"status":"QUOTE_UNAVAILABLE"}'::jsonb; END IF;
 SELECT * INTO p FROM public.user_esims WHERE id=q.profile_id AND user_id=u;
 SELECT * INTO c FROM esim_private.topup_cache WHERE profile_id=q.profile_id;
 IF p.id IS NULL OR q.expires_at<=now() OR c.status IS DISTINCT FROM 'ready' OR c.expires_at<=now()
  OR c.version IS DISTINCT FROM q.cache_version OR q.context IS DISTINCT FROM esim_private.topup_context(p)
  OR q.account_id IS DISTINCT FROM p.supplier_account_id OR esim_private.topup_refusal(p) IS NOT NULL
  OR NOT (SELECT discovery_enabled FROM esim_private.recharge_policy WHERE singleton)
  OR public.resolve_esim_offer_price(q.wholesale_usd,u) IS DISTINCT FROM q.retail_total THEN RETURN '{"status":"STALE_QUOTE","acceptance_enabled":false}'::jsonb; END IF;
 RETURN jsonb_build_object('status','QUOTED','quote_id',q.id,'acceptance_key',q.acceptance_key,'owner_id',u,'payer_id',u,
 'profile_id',p.id,'action',q.action,'offer',q.retail_snapshot,'expires_at',q.expires_at,'acceptance_enabled',false)||esim_private.topup_balance(u,q.retail_total);
END $$;
-- Quotes have no update/accept endpoint. ESIM-08 must atomically consume the
-- unique acceptance key with its financial operation, and extend sibling gates.
CREATE FUNCTION public.prune_esim_topup_discovery() RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM esim_private.require_service();
 DELETE FROM esim_private.recharge_quotes WHERE expires_at<now()-interval '30 days';
 DELETE FROM esim_private.topup_cache WHERE requested_at<now()-interval '1 day';
END $$;
REVOKE ALL ON FUNCTION esim_private.topup_context(public.user_esims),esim_private.topup_refusal(public.user_esims),
 esim_private.topup_retail(jsonb,uuid),esim_private.topup_balance(uuid,numeric),esim_private.topup_catalogue_changed() FROM PUBLIC,anon,authenticated;
DO $$ DECLARE r record; BEGIN
 FOR r IN SELECT p.oid::regprocedure sig,p.proname FROM pg_proc p WHERE p.pronamespace='public'::regnamespace
  AND p.proname IN('request_esim_topups','quote_esim_topup','check_esim_topup_quote','service_esim_claim_topups','service_esim_save_topups','prune_esim_topup_discovery') LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',r.sig);
  EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',r.sig);
  IF r.proname IN('request_esim_topups','quote_esim_topup','check_esim_topup_quote') THEN
   EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated',r.sig);
  END IF;
 END LOOP;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
