BEGIN;
SET LOCAL lock_timeout='5s';

DO $preflight$ BEGIN
 IF md5(pg_get_functiondef('accept_esim_topup(uuid,uuid,text)'::regprocedure))<>'91b7d0841def3fe11c0376e9688f9de9' THEN RAISE EXCEPTION 'ESIM-09 dependency source drift'; END IF;
 IF md5(pg_get_functiondef('capture_wallet_hold(uuid,text,text,jsonb)'::regprocedure))<>'91f7f88c75b0f25d55bb7a3e792a5f72' THEN RAISE EXCEPTION 'ESIM-09 dependency source drift'; END IF;
 IF md5(pg_get_functiondef('check_esim_topup_quote(uuid)'::regprocedure))<>'74a45aafea2880356a7559c43b8d9988' THEN RAISE EXCEPTION 'ESIM-09 dependency source drift'; END IF;
 IF md5(pg_get_functiondef('gate_esim_order_submission()'::regprocedure))<>'6f7459434b5e62f854408f21261c47b4' THEN RAISE EXCEPTION 'ESIM-09 dependency source drift'; END IF;
 IF md5(pg_get_functiondef('prune_esim_topup_discovery()'::regprocedure))<>'e15c9c2840c350884b3bcacefab3d12d' THEN RAISE EXCEPTION 'ESIM-09 dependency source drift'; END IF;
 IF md5(pg_get_functiondef('release_wallet_hold(uuid,text)'::regprocedure))<>'ad1590773eff9de011eeb255efac6f30' THEN RAISE EXCEPTION 'ESIM-09 dependency source drift'; END IF;
 IF md5(pg_get_functiondef('request_esim_purchase_v2(text,integer,text,uuid,numeric,uuid)'::regprocedure))<>'db6948961242741acf2ea9303235d879' THEN RAISE EXCEPTION 'ESIM-09 dependency source drift'; END IF;
 IF md5(pg_get_functiondef('reserve_wallet_funds(uuid,numeric,text,text,text,integer)'::regprocedure))<>'75aaad1ad02b099728c55fb55619819d' THEN RAISE EXCEPTION 'ESIM-09 dependency source drift'; END IF;
 IF md5(pg_get_functiondef('service_esim_mark_submitted(uuid,uuid)'::regprocedure))<>'fee23c5c863d46d033099099f6d6d9cb' THEN RAISE EXCEPTION 'ESIM-09 dependency source drift'; END IF;
 IF md5(pg_get_functiondef('service_esim_record_topup_receipt(uuid,text,jsonb)'::regprocedure))<>'52ef4e4df11e3f4b05eb3a94428a6a55' THEN RAISE EXCEPTION 'ESIM-09 dependency source drift'; END IF;
 IF md5(pg_get_functiondef('service_esim_settle_topup(uuid)'::regprocedure))<>'af3b36b9c66cb75b5856eb25df6fa3e5' THEN RAISE EXCEPTION 'ESIM-09 dependency source drift'; END IF;
 IF md5(pg_get_functiondef('snapshot_esim_catalogue_order()'::regprocedure))<>'534b2e81544d59d8292ca303cf31b288' THEN RAISE EXCEPTION 'ESIM-09 dependency source drift'; END IF;
 IF md5(pg_get_functiondef('esim_private.alert_is_relevant(uuid,text,integer)'::regprocedure))<>'ff9c7cc053fdc6d7a0dda9e677130f4f' THEN RAISE EXCEPTION 'ESIM-09 dependency source drift'; END IF;
 IF md5(pg_get_functiondef('esim_private.guard_operation_hold()'::regprocedure))<>'a0ae1543207bba8a7d02933454dfb561' THEN RAISE EXCEPTION 'ESIM-09 dependency source drift'; END IF;
 IF md5(pg_get_functiondef('esim_private.reserve_order(uuid)'::regprocedure))<>'ff8c96f9b0729ed4415043074bd3b7fe' THEN RAISE EXCEPTION 'ESIM-09 dependency source drift'; END IF;
 IF md5(pg_get_functiondef('esim_private.settle_order(uuid,boolean)'::regprocedure))<>'b0cbc5f5406cfeb1f033e8836bebce96' THEN RAISE EXCEPTION 'ESIM-09 dependency source drift'; END IF;
END $preflight$;

-- ESIM-09: exact, expiring supplier duration totals. No marketing-price seeds.
ALTER TABLE esim_private.accounts ADD COLUMN daily_duration_enabled boolean NOT NULL DEFAULT false,ADD COLUMN daily_contract_verified boolean NOT NULL DEFAULT false;
CREATE TABLE esim_private.daily_prices (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), revision bigint GENERATED ALWAYS AS IDENTITY, account_id uuid NOT NULL REFERENCES esim_private.accounts(id),
 package_id text NOT NULL CHECK(length(package_id) BETWEEN 1 AND 100), profile_id uuid REFERENCES public.user_esims(id),
 period_count integer NOT NULL CHECK(period_count BETWEEN 1 AND 365),
 wholesale_total numeric(12,4) NOT NULL CHECK(wholesale_total>0), facts_hash text NOT NULL,
 context text NOT NULL, source_reference text NOT NULL CHECK(length(source_reference) BETWEEN 8 AND 250),
 observed_at timestamptz NOT NULL, expires_at timestamptz NOT NULL, imported_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 max_recharges integer, observed_recharges integer,
 CHECK(expires_at>observed_at AND expires_at<=observed_at+interval '24 hours'),
 CHECK(profile_id IS NULL OR (max_recharges>0 AND observed_recharges>=0 AND observed_recharges<max_recharges))
);
CREATE INDEX daily_price_context ON esim_private.daily_prices(account_id,package_id,coalesce(profile_id,'00000000-0000-0000-0000-000000000000'::uuid),period_count);
CREATE INDEX daily_price_profile ON esim_private.daily_prices(profile_id);
CREATE TABLE esim_private.daily_purchase_quotes (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), acceptance_key uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 owner_id uuid NOT NULL, account_id uuid NOT NULL REFERENCES esim_private.accounts(id),
 package_id text NOT NULL, period_count integer NOT NULL CHECK(period_count BETWEEN 1 AND 365),
 quantity integer NOT NULL CHECK(quantity BETWEEN 1 AND 3), price_id uuid NOT NULL REFERENCES esim_private.daily_prices(id),
 wholesale_total numeric(12,4) NOT NULL, retail_unit numeric(12,2) NOT NULL CHECK(retail_unit>0),
 retail_total numeric(12,2) NOT NULL CHECK(retail_total>0), snapshot jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(), expires_at timestamptz NOT NULL
);
CREATE INDEX daily_purchase_quotes_owner ON esim_private.daily_purchase_quotes(owner_id,created_at);
ALTER TABLE public.esim_orders ADD COLUMN daily_purchase_quote_id uuid REFERENCES esim_private.daily_purchase_quotes(id);
CREATE UNIQUE INDEX daily_purchase_quote_acceptance ON public.esim_orders(daily_purchase_quote_id) WHERE daily_purchase_quote_id IS NOT NULL;
ALTER TABLE esim_private.recharge_quotes DROP CONSTRAINT recharge_quotes_period_count_check;
ALTER TABLE esim_private.recharge_quotes ADD CONSTRAINT recharge_quotes_period_count_check CHECK(period_count BETWEEN 1 AND 365);
ALTER TABLE esim_private.recharge_quotes DROP CONSTRAINT recharge_quotes_action_check;
ALTER TABLE esim_private.recharge_quotes ADD CONSTRAINT recharge_quotes_action_check CHECK(action IN('fixed_bundle_recharge','daily_extension'));
ALTER TABLE esim_private.recharge_quotes ADD COLUMN daily_price_id uuid REFERENCES esim_private.daily_prices(id);
ALTER TABLE public.esim_orders DROP CONSTRAINT esim_orders_operation_kind_check;
ALTER TABLE public.esim_orders ADD CONSTRAINT esim_orders_operation_kind_check CHECK(operation_kind IN('purchase','fixed_recharge','daily_extension'));
ALTER TABLE public.esim_orders DROP CONSTRAINT esim_operation_shape;
ALTER TABLE public.esim_orders ADD CONSTRAINT esim_operation_shape CHECK(
 (operation_kind='purchase' AND recharge_profile_id IS NULL AND recharge_quote_id IS NULL) OR
 (operation_kind IN('fixed_recharge','daily_extension') AND recharge_profile_id IS NOT NULL AND recharge_quote_id IS NOT NULL AND quantity=1 AND daily_purchase_quote_id IS NULL));
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['daily_prices','daily_purchase_quotes'] LOOP
  EXECUTE format('ALTER TABLE esim_private.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('REVOKE ALL ON esim_private.%I FROM PUBLIC,anon,authenticated',t);
  EXECUTE format('GRANT SELECT ON esim_private.%I TO service_role',t);
 END LOOP;
END $$;

CREATE FUNCTION esim_private.daily_facts(j jsonb) RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT md5(jsonb_build_array(j->>'package_id',j->>'supplier_product_id',j->>'product_alias',j->>'alias',
 j->>'data_type',j->>'plan_type',j->>'allowance_bytes',j->>'fup_text',j->>'duration_value',j->>'duration_unit',
 j->>'wholesale_usd',j->>'topup_support')::text);
$$;
CREATE FUNCTION esim_private.daily_base_context(c public.esim_offers_cache) RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT md5(jsonb_build_array(c.provider,c.bundle_name,c.wholesale_price_usd,c.catalogue_details)::text);
$$;
-- Service-only import of an EXACT supplier total for an exact duration/variant.
-- Source must be independently verified account pricing. No client, daily retail
-- multiplication, guessed discount coefficient or undocumented supplier endpoint.
CREATE FUNCTION public.service_esim_store_daily_price(p_package_id text,p_period_count integer,p_wholesale_units bigint,
 p_source_reference text,p_observed_at timestamptz,p_expires_at timestamptz,p_profile_id uuid DEFAULT NULL,
 p_max_recharges integer DEFAULT NULL,p_observed_recharges integer DEFAULT NULL) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE a esim_private.accounts; c public.esim_offers_cache; p public.user_esims; cache esim_private.topup_cache; facts jsonb; ctx text; result uuid;
BEGIN
 PERFORM esim_private.require_service();
 SELECT * INTO STRICT a FROM esim_private.accounts WHERE provider='esimaccess' AND account_key='primary';
 IF p_period_count IS NULL OR p_period_count NOT BETWEEN 1 AND 365 OR p_wholesale_units IS NULL OR p_wholesale_units<=0
  OR p_wholesale_units>999999999999 OR p_source_reference IS NULL OR length(p_source_reference) NOT BETWEEN 8 AND 250
  OR p_observed_at IS NULL OR p_observed_at>now()+interval '5 minutes' OR p_observed_at<now()-interval '24 hours'
  OR p_expires_at IS NULL OR p_expires_at<=now() OR p_expires_at>p_observed_at+interval '24 hours' THEN RAISE EXCEPTION 'Invalid verified duration price'; END IF;
 IF p_profile_id IS NULL THEN
  SELECT * INTO STRICT c FROM public.esim_offers_cache WHERE provider='esimaccess' AND bundle_name=p_package_id AND is_active;
  facts:=c.catalogue_details;ctx:=esim_private.daily_base_context(c);
  IF coalesce(facts->>'plan_type','') NOT IN('daily_throttled','daily_cutoff','daily_unlimited') OR coalesce(facts->>'duration_unit','')<>'DAY' THEN RAISE EXCEPTION 'Not a daily product'; END IF;
 ELSE
  SELECT * INTO STRICT p FROM public.user_esims WHERE id=p_profile_id AND supplier_account_id=a.id;
  SELECT * INTO STRICT cache FROM esim_private.topup_cache WHERE profile_id=p.id AND status='ready' AND expires_at>now() AND context=esim_private.topup_context(p);
  SELECT value INTO facts FROM jsonb_array_elements(cache.offers) WHERE value->>'package_id'=p_package_id;
  IF facts IS NULL OR coalesce(facts->>'data_type','') NOT IN('2','3','4') OR coalesce(facts->>'topup_support','')<>'daily_extension'
   OR coalesce(p.plan_details->>'topup_support','')<>'daily_extension' OR coalesce(p.plan_details->>'plan_type','') NOT IN('daily_throttled','daily_cutoff','daily_unlimited')
   OR coalesce(facts->>'alias',facts->>'package_id') IS DISTINCT FROM coalesce(p.plan_details->>'product_alias',p.plan_details->>'supplier_product_id')
   OR p_max_recharges IS NULL OR p_observed_recharges IS NULL OR p_max_recharges<=0 OR p_observed_recharges<0 OR p_observed_recharges>=p_max_recharges
   OR p_observed_at<cache.fetched_at THEN RAISE EXCEPTION 'Daily variant or account limit unverified'; END IF;
  ctx:=cache.context;
 END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(a.id::text||p_package_id||coalesce(p_profile_id::text,'BASE')||p_period_count::text,0));
 IF EXISTS(SELECT 1 FROM esim_private.daily_prices WHERE account_id=a.id AND package_id=p_package_id AND profile_id IS NOT DISTINCT FROM p_profile_id AND period_count=p_period_count AND observed_at>p_observed_at) THEN RAISE EXCEPTION 'Newer supplier price already observed'; END IF;
 INSERT INTO esim_private.daily_prices(account_id,package_id,profile_id,period_count,wholesale_total,facts_hash,context,source_reference,observed_at,expires_at,max_recharges,observed_recharges)
 VALUES(a.id,p_package_id,p_profile_id,p_period_count,p_wholesale_units::numeric/10000,esim_private.daily_facts(facts),ctx,p_source_reference,p_observed_at,p_expires_at,p_max_recharges,p_observed_recharges)
 RETURNING id INTO result;
 RETURN result;
END $$;

CREATE FUNCTION esim_private.daily_price_current(price_id uuid,ctx text,facts jsonb) RETURNS boolean LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM esim_private.daily_prices r WHERE r.id=price_id AND r.context=ctx AND r.facts_hash=esim_private.daily_facts(facts)
 AND r.expires_at>now() AND r.observed_at<=now()+interval '5 minutes' AND NOT EXISTS(SELECT 1 FROM esim_private.daily_prices newer WHERE newer.account_id=r.account_id AND newer.package_id=r.package_id AND newer.profile_id IS NOT DISTINCT FROM r.profile_id AND newer.period_count=r.period_count AND newer.revision>r.revision));
$$;

CREATE FUNCTION public.quote_esim_daily_extension(p_profile_id uuid,p_package_id text,p_offer_version uuid,p_period_count integer) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); p public.user_esims; c esim_private.topup_cache; r esim_private.daily_prices; q esim_private.recharge_quotes; o jsonb; retail jsonb; total numeric; reason text;
BEGIN
 PERFORM esim_private.require_live_owner(u);
 IF p_period_count IS NULL OR p_period_count NOT BETWEEN 1 AND 365 THEN RETURN '{"status":"INVALID_DURATION"}'::jsonb; END IF;
 SELECT * INTO p FROM public.user_esims WHERE id=p_profile_id AND user_id=u FOR UPDATE;
 IF NOT FOUND THEN RETURN '{"status":"PROFILE_UNAVAILABLE"}'::jsonb; END IF;
 IF NOT(SELECT discovery_enabled FROM esim_private.recharge_policy WHERE singleton) THEN RETURN '{"status":"DISCOVERY_DISABLED"}'::jsonb; END IF;
 reason:=esim_private.topup_refusal(p);IF reason IS NOT NULL THEN RETURN jsonb_build_object('status',reason); END IF;
 SELECT * INTO c FROM esim_private.topup_cache WHERE profile_id=p.id AND owner_id=u AND account_id=p.supplier_account_id;
 IF c.status IS DISTINCT FROM 'ready' OR c.expires_at<=now() OR c.version IS DISTINCT FROM p_offer_version OR c.context IS DISTINCT FROM esim_private.topup_context(p) THEN RETURN '{"status":"STALE_OFFERS"}'::jsonb; END IF;
 SELECT value INTO o FROM jsonb_array_elements(c.offers) WHERE value->>'package_id'=p_package_id;
 IF o IS NULL OR coalesce(o->>'data_type','') NOT IN('2','3','4') OR coalesce(o->>'topup_support','')<>'daily_extension'
  OR coalesce(p.plan_details->>'topup_support','')<>'daily_extension' OR coalesce(p.plan_details->>'plan_type','') NOT IN('daily_throttled','daily_cutoff','daily_unlimited')
  OR coalesce(o->>'alias',o->>'package_id') IS DISTINCT FROM coalesce(p.plan_details->>'product_alias',p.plan_details->>'supplier_product_id') THEN RETURN '{"status":"INCOMPATIBLE_OFFER"}'::jsonb; END IF;
 SELECT * INTO r FROM esim_private.daily_prices WHERE account_id=p.supplier_account_id AND package_id=p_package_id AND profile_id=p.id AND period_count=p_period_count ORDER BY revision DESC LIMIT 1;
 IF NOT FOUND OR NOT esim_private.daily_price_current(r.id,c.context,o) THEN RETURN '{"status":"DURATION_PRICE_UNAVAILABLE"}'::jsonb; END IF;
 IF r.max_recharges IS NULL OR r.observed_recharges IS NULL OR r.observed_recharges>=r.max_recharges THEN RETURN '{"status":"DAILY_LIMIT_UNVERIFIED"}'::jsonb; END IF;
 total:=public.resolve_esim_offer_price(r.wholesale_total,u);
 IF total IS NULL OR total<=0 OR total::text IN('NaN','Infinity','-Infinity') THEN RETURN '{"status":"PRICE_UNAVAILABLE"}'::jsonb; END IF;
 retail:=esim_private.topup_retail(o,u)||jsonb_build_object('retail_total',total,'duration_value',p_period_count,'duration_unit','DAY','period_count',p_period_count,
 'quote_supported',true,'effect','validity_only','daily_reset_time',NULL,'daily_reset_known',false);
 IF (SELECT count(*) FROM esim_private.recharge_quotes WHERE owner_id=u AND created_at>now()-interval '1 minute')>=20 THEN RETURN '{"status":"RATE_LIMITED"}'::jsonb; END IF;
 INSERT INTO esim_private.recharge_quotes(owner_id,payer_id,profile_id,account_id,provider,action,package_id,cache_version,context,wholesale_usd,retail_total,currency,duration_value,duration_unit,period_count,retail_snapshot,expires_at,daily_price_id)
 VALUES(u,u,p.id,p.supplier_account_id,p.provider,'daily_extension',p_package_id,c.version,c.context,r.wholesale_total,total,'USD',p_period_count,'DAY',p_period_count,retail,least(c.expires_at,r.expires_at,now()+interval '2 minutes'),r.id) RETURNING * INTO q;
 RETURN jsonb_build_object('status','QUOTED','quote_id',q.id,'acceptance_key',q.acceptance_key,'owner_id',u,'payer_id',u,'profile_id',p.id,'action',q.action,'offer',retail,
 'expires_at',q.expires_at,'acceptance_enabled',esim_private.recharge_can_accept() AND (SELECT daily_duration_enabled AND daily_contract_verified FROM esim_private.accounts WHERE id=p.supplier_account_id))||esim_private.topup_balance(u,total);
END $$;

CREATE FUNCTION public.quote_esim_daily_purchase(p_offer_id text,p_period_count integer,p_quantity integer DEFAULT 1) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); a esim_private.accounts; c public.esim_offers_cache; r esim_private.daily_prices; q esim_private.daily_purchase_quotes; unit_price numeric; retail jsonb;
BEGIN
 PERFORM esim_private.require_live_owner(u);
 IF p_period_count IS NULL OR p_period_count NOT BETWEEN 1 AND 365 OR p_quantity IS NULL OR p_quantity NOT BETWEEN 1 AND 3 THEN RETURN '{"status":"INVALID_DURATION"}'::jsonb; END IF;
 SELECT * INTO STRICT a FROM esim_private.accounts WHERE provider='esimaccess' AND account_key='primary';
 IF NOT(SELECT discovery_enabled FROM esim_private.recharge_policy WHERE singleton) THEN RETURN '{"status":"DISCOVERY_DISABLED"}'::jsonb; END IF;
 SELECT c0.* INTO c FROM public.esim_offers_cache c0 JOIN public.esim_suppliers s ON s.code=c0.provider AND s.is_active
 WHERE c0.provider='esimaccess' AND c0.is_active AND (c0.bundle_name=p_offer_id OR c0.provider||'_'||c0.bundle_name=p_offer_id);
 IF c.bundle_name IS NULL THEN RETURN '{"status":"INCOMPATIBLE_OFFER"}'::jsonb; END IF;
 IF coalesce(c.catalogue_details->>'plan_type','') NOT IN('daily_throttled','daily_cutoff','daily_unlimited') OR coalesce(c.catalogue_details->>'duration_unit','')<>'DAY' THEN RETURN '{"status":"UNSUPPORTED_DURATION"}'::jsonb; END IF;
 SELECT * INTO r FROM esim_private.daily_prices WHERE account_id=a.id AND package_id=c.bundle_name AND profile_id IS NULL AND period_count=p_period_count ORDER BY revision DESC LIMIT 1;
 IF NOT FOUND OR NOT esim_private.daily_price_current(r.id,esim_private.daily_base_context(c),c.catalogue_details) THEN RETURN '{"status":"DURATION_PRICE_UNAVAILABLE"}'::jsonb; END IF;
 unit_price:=public.resolve_esim_offer_price(r.wholesale_total,u);
 IF unit_price IS NULL OR unit_price<=0 OR unit_price::text IN('NaN','Infinity','-Infinity') THEN RETURN '{"status":"PRICE_UNAVAILABLE"}'::jsonb; END IF;
 retail:=jsonb_build_object('package_id',c.bundle_name,'title',c.description,'currency','USD','retail_total',unit_price*p_quantity,
 'allowance_bytes',c.catalogue_details->>'allowance_bytes','data_type',CASE c.catalogue_details->>'plan_type' WHEN 'daily_throttled' THEN 2 WHEN 'daily_cutoff' THEN 3 ELSE 4 END,
 'duration_value',p_period_count,'duration_unit','DAY','period_count',p_period_count,'effect','new_daily_profile','quote_supported',true,'daily_reset_time',NULL);
 IF(SELECT count(*) FROM esim_private.daily_purchase_quotes WHERE owner_id=u AND created_at>now()-interval '1 minute')>=20 THEN RETURN '{"status":"RATE_LIMITED"}'::jsonb; END IF;
 INSERT INTO esim_private.daily_purchase_quotes(owner_id,account_id,package_id,period_count,quantity,price_id,wholesale_total,retail_unit,retail_total,snapshot,expires_at)
 VALUES(u,a.id,c.bundle_name,p_period_count,p_quantity,r.id,r.wholesale_total,unit_price,unit_price*p_quantity,
 jsonb_build_object('catalogue_details',c.catalogue_details||jsonb_build_object('duration_value',p_period_count,'period_count',p_period_count),
 'daily_source_facts',c.catalogue_details,'daily_price_id',r.id,'daily_context',r.context,'period_count',p_period_count,'duration_days',p_period_count,
 'daily_base_price',c.wholesale_price_usd,'countries',c.countries,'data_amount_mb',c.data_amount_mb,'is_unlimited',c.is_unlimited),least(r.expires_at,now()+interval '2 minutes')) RETURNING * INTO q;
 RETURN jsonb_build_object('status','QUOTED','quote_id',q.id,'acceptance_key',q.acceptance_key,'owner_id',u,'payer_id',u,'action','daily_purchase','offer',retail,'quantity',q.quantity,
 'expires_at',q.expires_at,'acceptance_enabled',a.new_sales_enabled AND a.wallet_boundary_verified AND a.daily_duration_enabled AND a.daily_contract_verified)||esim_private.topup_balance(u,q.retail_total);
END $$;

CREATE FUNCTION public.accept_esim_daily_purchase(p_quote_id uuid,p_acceptance_key uuid,p_request_key uuid,p_device_id text DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); q esim_private.daily_purchase_quotes; c public.esim_offers_cache; a esim_private.accounts; o public.esim_orders; guard jsonb;
BEGIN
 PERFORM esim_private.require_money_session(u);
 SELECT * INTO q FROM esim_private.daily_purchase_quotes WHERE id=p_quote_id AND owner_id=u AND acceptance_key=p_acceptance_key;
 IF NOT FOUND OR p_request_key IS NULL THEN RETURN '{"status":"QUOTE_UNAVAILABLE"}'::jsonb; END IF;
 PERFORM 1 FROM public.wallets WHERE user_id=u FOR UPDATE;
 SELECT * INTO o FROM public.esim_orders WHERE user_id=u AND (daily_purchase_quote_id=q.id OR client_request_key=p_request_key);
 IF FOUND THEN
  IF o.daily_purchase_quote_id IS DISTINCT FROM q.id THEN RETURN '{"status":"INTENT_CONFLICT"}'::jsonb; END IF;
  RETURN jsonb_build_object('status','ADOPTED','order_id',o.id);
 END IF;
 SELECT * INTO STRICT a FROM esim_private.accounts WHERE id=q.account_id;
 IF NOT a.new_sales_enabled OR NOT a.wallet_boundary_verified OR NOT a.daily_duration_enabled OR NOT a.daily_contract_verified THEN RETURN '{"status":"SALES_DISABLED"}'::jsonb; END IF;
 SELECT * INTO c FROM public.esim_offers_cache WHERE provider='esimaccess' AND bundle_name=q.package_id AND is_active;
 IF q.expires_at<=now() OR c.bundle_name IS NULL OR NOT esim_private.daily_price_current(q.price_id,esim_private.daily_base_context(c),c.catalogue_details)
  OR public.resolve_esim_offer_price(q.wholesale_total,u) IS DISTINCT FROM q.retail_unit
  OR NOT EXISTS(SELECT 1 FROM public.esim_suppliers WHERE code='esimaccess' AND is_active) THEN RETURN '{"status":"STALE_QUOTE"}'::jsonb; END IF;
 IF (esim_private.topup_balance(u,q.retail_total)->>'balance_state')<>'sufficient' THEN RETURN '{"status":"BALANCE_UNAVAILABLE"}'::jsonb; END IF;
 guard:=public.guard_money_action('esim_purchase',q.retail_total,p_device_id,NULL,u);
 IF coalesce((guard->>'blocked')::boolean,true) THEN RETURN '{"status":"DEVICE_BLOCKED"}'::jsonb; END IF;
 INSERT INTO public.esim_orders(user_id,offer_id,bundle_name,provider,quantity,wholesale_price_usd,retail_price_usd,markup_percent,total_amount_usd,status,client_request_key,daily_purchase_quote_id,catalogue_snapshot)
 VALUES(u,q.package_id,q.package_id,'esimaccess',q.quantity,q.wholesale_total,q.retail_unit,round((q.retail_unit/q.wholesale_total-1)*100,2),q.retail_total,'pending',p_request_key,q.id,q.snapshot) RETURNING * INTO o;
 PERFORM esim_private.reserve_order(o.id);
 RETURN jsonb_build_object('status','ACCEPTED','order_id',o.id);
END $$;

CREATE FUNCTION esim_private.daily_extension_current(q esim_private.recharge_quotes,p public.user_esims,c esim_private.topup_cache) RETURNS boolean LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT q.action='daily_extension' AND q.period_count BETWEEN 1 AND 365 AND q.duration_value=q.period_count AND q.duration_unit='DAY'
 AND EXISTS(SELECT 1 FROM jsonb_array_elements(c.offers) f JOIN esim_private.daily_prices r ON r.id=q.daily_price_id
 WHERE f->>'package_id'=q.package_id AND f->>'data_type' IN('2','3','4') AND f->>'topup_support'='daily_extension'
 AND p.plan_details->>'topup_support'='daily_extension' AND p.plan_details->>'plan_type' IN('daily_throttled','daily_cutoff','daily_unlimited')
 AND coalesce(f->>'alias',f->>'package_id')=coalesce(p.plan_details->>'product_alias',p.plan_details->>'supplier_product_id')
 AND r.profile_id=p.id AND r.account_id=p.supplier_account_id AND r.package_id=q.package_id AND r.period_count=q.period_count
 AND r.wholesale_total=q.wholesale_usd AND r.max_recharges IS NOT NULL AND r.observed_recharges IS NOT NULL AND r.observed_recharges<r.max_recharges
 AND esim_private.daily_price_current(r.id,c.context,f));
$$;

CREATE FUNCTION esim_private.daily_order_current(o public.esim_orders) RETURNS boolean LANGUAGE plpgsql STABLE SET search_path='' AS $$
DECLARE q esim_private.daily_purchase_quotes; c public.esim_offers_cache; t esim_private.recharge_quotes; p public.user_esims; cache esim_private.topup_cache;
BEGIN
 IF o.operation_kind='daily_extension' THEN
  SELECT * INTO t FROM esim_private.recharge_quotes WHERE id=o.recharge_quote_id;
  SELECT * INTO p FROM public.user_esims WHERE id=o.recharge_profile_id;
  SELECT * INTO cache FROM esim_private.topup_cache WHERE profile_id=p.id;
  RETURN coalesce(esim_private.daily_extension_current(t,p,cache),false);
 END IF;
 IF o.daily_purchase_quote_id IS NULL THEN RETURN true; END IF;
 SELECT * INTO q FROM esim_private.daily_purchase_quotes WHERE id=o.daily_purchase_quote_id;
 SELECT * INTO c FROM public.esim_offers_cache WHERE provider=o.provider AND bundle_name=o.bundle_name AND is_active;
 RETURN coalesce(q.owner_id=o.user_id AND q.quantity=o.quantity AND q.package_id=o.bundle_name AND q.wholesale_total=o.wholesale_price_usd
 AND q.retail_total=o.total_amount_usd AND q.expires_at>now() AND esim_private.daily_price_current(q.price_id,esim_private.daily_base_context(c),c.catalogue_details),false);
END $$;

-- Pin privileges on every new function, including private helpers.
DO $$ DECLARE f record; BEGIN
 FOR f IN SELECT p.oid::regprocedure signature,n.nspname,p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE (n.nspname='esim_private' AND p.proname IN('daily_facts','daily_base_context','daily_price_current','daily_extension_current','daily_order_current'))
 OR (n.nspname='public' AND p.proname IN('service_esim_store_daily_price','quote_esim_daily_extension','quote_esim_daily_purchase','accept_esim_daily_purchase')) LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',f.signature);
  EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',f.signature);
  IF f.proname IN('quote_esim_daily_extension','quote_esim_daily_purchase','accept_esim_daily_purchase') THEN EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated',f.signature); END IF;
 END LOOP;
END $$;


CREATE OR REPLACE FUNCTION esim_private.reserve_order(p_order_id uuid) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE o public.esim_orders; r esim_private.order_runs; h uuid; w public.wallets;
BEGIN
 SELECT * INTO STRICT o FROM public.esim_orders WHERE id=p_order_id;
 IF auth.uid() IS DISTINCT FROM o.user_id AND coalesce(auth.role(),'')<>'service_role' THEN RAISE EXCEPTION 'Owner required' USING ERRCODE='42501'; END IF;
 PERFORM esim_private.require_live_owner(o.user_id);
 SELECT * INTO STRICT w FROM public.wallets WHERE user_id=o.user_id FOR UPDATE;
 IF w.currency IS DISTINCT FROM 'USD' THEN RAISE EXCEPTION 'Unsupported wallet currency'; END IF;
 SELECT * INTO STRICT r FROM esim_private.order_runs WHERE order_id=o.id FOR UPDATE;
 IF r.hold_id IS NOT NULL THEN RETURN r.hold_id; END IF;
 IF r.state<>'prepared' OR r.submitted_at IS NOT NULL OR o.provider<>'esimaccess' THEN RAISE EXCEPTION 'Reservation intent unavailable'; END IF;
 IF EXISTS(SELECT 1 FROM public.wallet_transactions WHERE reference_id='esim_'||o.id::text AND type='esim_purchase_debit') THEN
  RAISE EXCEPTION 'Already-debited legacy order cannot be reserved'; END IF;
 UPDATE esim_private.order_runs SET finance_kind='reserved',payer_id=o.user_id WHERE order_id=o.id;
 h:=public.reserve_wallet_funds(o.user_id,o.total_amount_usd,
  CASE WHEN o.operation_kind IN('fixed_recharge','daily_extension') THEN 'esim_recharge' ELSE 'esim_purchase' END,'esim_op:'||o.id::text,'eSIM operation reservation',120);
 UPDATE esim_private.order_runs SET hold_id=h WHERE order_id=o.id;
 UPDATE public.wallet_holds SET expires_at=NULL WHERE id=h;
 RETURN h;
END $$;

CREATE OR REPLACE FUNCTION esim_private.settle_order(p_order_id uuid,p_capture boolean) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r esim_private.order_runs; o public.esim_orders; h public.wallet_holds; tx uuid; charged public.wallet_transactions;
 refunded numeric; ref text;
BEGIN
 PERFORM esim_private.require_service();
 SELECT * INTO STRICT o FROM public.esim_orders WHERE id=p_order_id;
 PERFORM 1 FROM public.wallets WHERE user_id=o.user_id FOR UPDATE;
 SELECT * INTO STRICT r FROM esim_private.order_runs WHERE order_id=o.id FOR UPDATE;
 IF r.settlement_state IN('captured','refunded','released') THEN
  IF (p_capture AND r.settlement_state<>'captured') OR (NOT p_capture AND r.settlement_state='captured') THEN RAISE EXCEPTION 'Settlement direction conflict'; END IF;
  RETURN r.settlement_tx_id;
 END IF;
 IF r.receipt IS NULL THEN RAISE EXCEPTION 'Receipt required'; END IF;
 IF r.finance_kind='reserved' THEN
  SELECT * INTO STRICT h FROM public.wallet_holds WHERE id=r.hold_id FOR UPDATE;
  IF h.user_id IS DISTINCT FROM r.payer_id OR h.amount IS DISTINCT FROM o.total_amount_usd OR h.status<>'active'
   OR h.order_reference_id IS DISTINCT FROM 'esim_op:'||o.id::text THEN RAISE EXCEPTION 'Reservation changed'; END IF;
  IF p_capture THEN
   IF r.receipt->>'outcome'<>'success' THEN RAISE EXCEPTION 'Confirmed service required'; END IF;
   UPDATE esim_private.order_runs SET settlement_state='capturing' WHERE order_id=o.id;
   tx:=public.capture_wallet_hold(h.id,CASE WHEN o.operation_kind IN('fixed_recharge','daily_extension') THEN 'esim_recharge_debit' ELSE 'esim_purchase_debit' END,
    'eSIM operation completed',jsonb_build_object('esim_order_id',o.id,'quote_id',o.recharge_quote_id,'action',o.operation_kind));
   UPDATE esim_private.order_runs SET settlement_state='captured',settlement_tx_id=tx WHERE order_id=o.id;
  ELSE
   IF r.state<>'failed' OR r.receipt->>'outcome'<>'failed' THEN RAISE EXCEPTION 'Definitive failure required'; END IF;
   UPDATE esim_private.order_runs SET settlement_state='releasing' WHERE order_id=o.id;
   PERFORM public.release_wallet_hold(h.id,'Verified eSIM failure or no submission');
   UPDATE esim_private.order_runs SET settlement_state='released' WHERE order_id=o.id;
  END IF;
 ELSIF r.finance_kind='legacy_debit' THEN
  SELECT * INTO STRICT charged FROM public.wallet_transactions WHERE id=r.debit_tx_id AND type='esim_purchase_debit'
   AND status='completed' AND reference_id='esim_'||o.id::text AND user_id=r.payer_id FOR UPDATE;
  IF charged.amount<=0 OR charged.amount::text IN('NaN','Infinity','-Infinity') OR charged.amount IS DISTINCT FROM (charged.balance_before-charged.balance_after) THEN RAISE EXCEPTION 'Unproven legacy charge'; END IF;
  IF charged.wallet_id IS DISTINCT FROM (SELECT id FROM public.wallets WHERE user_id=r.payer_id) THEN RAISE EXCEPTION 'Original wallet changed'; END IF;
  ref:='esim_refund_'||o.id::text;
  IF EXISTS(SELECT 1 FROM public.wallet_transactions WHERE status='completed'
   AND (reference_id=ref OR (metadata->>'esim_order_id'=o.id::text AND type IN('refund','esim_purchase_refund')))
   AND (user_id IS DISTINCT FROM r.payer_id OR wallet_id IS DISTINCT FROM charged.wallet_id OR type NOT IN('refund','esim_purchase_refund')
    OR amount<=0 OR balance_after-balance_before IS DISTINCT FROM amount)) THEN RAISE EXCEPTION 'Unproven prior refund'; END IF;
  SELECT coalesce(sum(amount),0) INTO refunded FROM public.wallet_transactions WHERE status='completed' AND
   (reference_id=ref OR (metadata->>'esim_order_id'=o.id::text AND type IN('refund','esim_purchase_refund')));
  IF p_capture THEN
   IF refunded<>0 THEN RAISE EXCEPTION 'Legacy delivery has prior refund; support required'; END IF;
   tx:=charged.id;
   UPDATE esim_private.order_runs SET settlement_state='captured',settlement_tx_id=tx WHERE order_id=o.id;
  ELSE
   IF r.state<>'failed' OR r.receipt->>'outcome'<>'failed' OR refunded>charged.amount THEN RAISE EXCEPTION 'Unproven legacy refund'; END IF;
   IF EXISTS(SELECT 1 FROM public.user_esims WHERE order_id=o.id) THEN RAISE EXCEPTION 'Partial issuance requires support'; END IF;
   IF refunded<charged.amount THEN
    UPDATE esim_private.order_runs SET settlement_state='refunding' WHERE order_id=o.id;
    tx:=public.credit_wallet_for_refund(r.payer_id,charged.amount-refunded,ref,'Verified legacy eSIM failure',NULL,'esim_purchase_refund');
   END IF;
   UPDATE esim_private.order_runs SET settlement_state='refunded',settlement_tx_id=coalesce(tx,settlement_tx_id) WHERE order_id=o.id;
  END IF;
 ELSE RAISE EXCEPTION 'Legacy financial proof required';
 END IF;
 RETURN tx;
END $$;

CREATE OR REPLACE FUNCTION public.service_esim_record_topup_receipt(p_order_id uuid,p_submission_ref text,p_receipt jsonb) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE o public.esim_orders; r esim_private.order_runs; p public.user_esims; digest_value text;
BEGIN
 PERFORM esim_private.require_service();
 SELECT * INTO STRICT o FROM public.esim_orders WHERE id=p_order_id;
 PERFORM 1 FROM public.wallets WHERE user_id=o.user_id FOR UPDATE;
 SELECT * INTO STRICT p FROM public.user_esims WHERE id=o.recharge_profile_id FOR UPDATE;
 SELECT * INTO STRICT r FROM esim_private.order_runs WHERE order_id=o.id FOR UPDATE;
 IF o.operation_kind NOT IN('fixed_recharge','daily_extension') OR r.submitted_at IS NULL OR r.submission_ref IS DISTINCT FROM p_submission_ref
  OR p_receipt->>'transaction_id' IS DISTINCT FROM r.submission_ref OR p_receipt->>'iccid' IS DISTINCT FROM o.catalogue_snapshot->>'iccid'
  OR p_receipt->>'supplier_profile_ref' IS DISTINCT FROM o.catalogue_snapshot->>'supplier_profile_ref'
  OR p.user_id IS DISTINCT FROM o.user_id OR p.supplier_account_id IS DISTINCT FROM r.account_id
  OR p.iccid IS DISTINCT FROM p_receipt->>'iccid' OR p.supplier_profile_ref IS DISTINCT FROM p_receipt->>'supplier_profile_ref'
  OR p_receipt->>'package_id' IS DISTINCT FROM o.bundle_name OR p_receipt->>'outcome'<>'success'
  OR nullif(p_receipt->>'topup_ref','') IS NULL OR length(p_receipt->>'topup_ref')>100 OR octet_length(p_receipt::text)>4096
  OR coalesce(p_receipt->>'total_bytes','')!~'^[0-9]{1,16}$' OR coalesce(p_receipt->>'used_bytes','')!~'^[0-9]{1,16}$'
  OR (p_receipt->>'used_bytes')::bigint>(p_receipt->>'total_bytes')::bigint OR (p_receipt->>'expires_at')::timestamptz IS NULL
  OR NOT isfinite((p_receipt->>'expires_at')::timestamptz) THEN RAISE EXCEPTION 'Unproven recharge receipt'; END IF;
 IF o.operation_kind='daily_extension' AND (p_receipt->>'period_count' IS DISTINCT FROM o.catalogue_snapshot->>'period_count' OR (p_receipt->>'expires_at')::timestamptz<=(o.catalogue_snapshot->>'daily_previous_expiry')::timestamptz) THEN RAISE EXCEPTION 'Unproven extension duration'; END IF;
 digest_value:=encode(sha256(convert_to(p_receipt::text,'UTF8')),'hex');
 IF r.receipt IS NOT NULL THEN
  IF r.receipt_hash IS DISTINCT FROM digest_value THEN RAISE EXCEPTION 'Conflicting receipt'; END IF;RETURN true;
 END IF;
 IF r.state NOT IN('submitted','reconciling','support_required') THEN RAISE EXCEPTION 'Invalid receipt state'; END IF;
 UPDATE esim_private.order_runs SET receipt=p_receipt,receipt_hash=digest_value,receipt_at=now(),state='reconciling',next_check_at=now(),
  provider_order_ref=p_receipt->>'topup_ref',error_code=NULL WHERE order_id=o.id;
 RETURN true;
END $$;

CREATE OR REPLACE FUNCTION public.gate_esim_order_submission() RETURNS trigger
 LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$DECLARE a esim_private.accounts; BEGIN
 SELECT * INTO STRICT a FROM esim_private.accounts WHERE account_key='primary';
 IF NEW.provider<>'esimaccess' OR (NEW.operation_kind='purchase' AND (NOT a.new_sales_enabled OR NOT a.wallet_boundary_verified))
  OR (NEW.operation_kind IN('fixed_recharge','daily_extension') AND NOT esim_private.recharge_can_accept()) THEN
  RAISE EXCEPTION 'eSIM purchases are temporarily unavailable while delivery safeguards are verified'; END IF;
 NEW.delivery_state:='queued';RETURN NEW; END $$;

CREATE OR REPLACE FUNCTION esim_private.guard_operation_hold() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r esim_private.order_runs; o public.esim_orders; operation_id uuid;
BEGIN
 IF NEW.order_type NOT IN('esim_purchase','esim_recharge') OR NEW.order_reference_id NOT LIKE 'esim_op:%' THEN RETURN NEW; END IF;
 operation_id:=substr(NEW.order_reference_id,9)::uuid;
 SELECT * INTO STRICT r FROM esim_private.order_runs WHERE order_id=operation_id;
 SELECT * INTO STRICT o FROM public.esim_orders WHERE id=operation_id;
 IF r.finance_kind<>'reserved' OR r.payer_id IS DISTINCT FROM NEW.user_id OR o.total_amount_usd IS DISTINCT FROM NEW.amount
  OR NEW.currency<>'USD' OR NEW.wallet_id IS DISTINCT FROM (SELECT id FROM public.wallets WHERE user_id=r.payer_id)
  OR NEW.order_type IS DISTINCT FROM (CASE WHEN o.operation_kind IN('fixed_recharge','daily_extension') THEN 'esim_recharge' ELSE 'esim_purchase' END) THEN
  RAISE EXCEPTION 'eSIM hold binding mismatch'; END IF;
 IF TG_OP='INSERT' THEN
  IF r.hold_id IS NOT NULL OR r.state<>'prepared' OR NEW.status<>'active' THEN RAISE EXCEPTION 'Invalid eSIM reservation'; END IF;
 ELSE
  IF (NEW.wallet_id,NEW.user_id,NEW.amount,NEW.order_type,NEW.order_reference_id,NEW.currency) IS DISTINCT FROM
     (OLD.wallet_id,OLD.user_id,OLD.amount,OLD.order_type,OLD.order_reference_id,OLD.currency) THEN RAISE EXCEPTION 'Immutable eSIM hold'; END IF;
  IF NEW.status IS DISTINCT FROM OLD.status THEN
   PERFORM esim_private.require_service();
   IF (NEW.status='captured' AND r.settlement_state='capturing' AND r.receipt IS NOT NULL) OR
      (NEW.status='released' AND r.settlement_state='releasing' AND r.state='failed' AND r.receipt IS NOT NULL) THEN NULL;
   ELSE RAISE EXCEPTION 'Unproven eSIM settlement'; END IF;
  END IF;
 END IF;
 -- New reservations have no timer-based release, even after a process restart.
 NEW.expires_at:=NULL;
 RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION public.accept_esim_topup(p_quote_id uuid,p_acceptance_key uuid,p_device_id text DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); q esim_private.recharge_quotes; p public.user_esims; c esim_private.topup_cache;
 o public.esim_orders; total numeric; reason text; guard jsonb;
BEGIN
 PERFORM esim_private.require_money_session(u);
 SELECT * INTO q FROM esim_private.recharge_quotes WHERE id=p_quote_id AND owner_id=u AND payer_id=u AND acceptance_key=p_acceptance_key;
 IF NOT FOUND THEN RETURN '{"status":"QUOTE_UNAVAILABLE"}'::jsonb; END IF;
 -- Wallet -> profile -> quote/run/hold is the common financial lock order.
 PERFORM 1 FROM public.wallets WHERE user_id=u FOR UPDATE;
 SELECT * INTO p FROM public.user_esims WHERE id=q.profile_id AND user_id=u FOR UPDATE;
 IF NOT FOUND THEN RETURN '{"status":"PROFILE_UNAVAILABLE"}'::jsonb; END IF;
 SELECT * INTO o FROM public.esim_orders WHERE recharge_quote_id=q.id AND user_id=u;
 IF FOUND THEN RETURN jsonb_build_object('status','ADOPTED','order_id',o.id); END IF;
 IF NOT esim_private.recharge_can_accept() OR (q.action='daily_extension' AND NOT EXISTS(SELECT 1 FROM esim_private.accounts WHERE id=q.account_id AND daily_duration_enabled AND daily_contract_verified)) THEN RETURN '{"status":"RECHARGE_DISABLED"}'::jsonb; END IF;
 reason:=esim_private.topup_refusal(p);IF reason IS NOT NULL THEN RETURN jsonb_build_object('status',reason); END IF;
 SELECT * INTO c FROM esim_private.topup_cache WHERE profile_id=p.id AND owner_id=u AND account_id=q.account_id;
 IF q.expires_at<=now() OR c.expires_at<=now() OR c.status IS DISTINCT FROM 'ready' OR c.version IS DISTINCT FROM q.cache_version
  OR q.context IS DISTINCT FROM esim_private.topup_context(p) OR p.supplier_account_id IS DISTINCT FROM q.account_id THEN RETURN '{"status":"STALE_QUOTE"}'::jsonb; END IF;
 IF NOT (CASE WHEN q.action='daily_extension' THEN esim_private.daily_extension_current(q,p,c) ELSE EXISTS(SELECT 1 FROM jsonb_array_elements(c.offers) x WHERE x->>'package_id'=q.package_id AND x->>'data_type'='1' AND (x->>'wholesale_usd')::numeric=q.wholesale_usd AND (x->>'allowance_bytes')::bigint>0) END) THEN RETURN '{"status":"INCOMPATIBLE_OFFER"}'::jsonb; END IF;
 total:=public.resolve_esim_offer_price(q.wholesale_usd,u);
 IF total IS DISTINCT FROM q.retail_total THEN RETURN '{"status":"PRICE_CHANGED"}'::jsonb; END IF;
 IF (esim_private.topup_balance(u,total)->>'balance_state')<>'sufficient' THEN RETURN '{"status":"BALANCE_UNAVAILABLE"}'::jsonb; END IF;
 guard:=public.guard_money_action('esim_purchase',total,p_device_id,NULL,u);
 IF coalesce((guard->>'blocked')::boolean,true) THEN RETURN '{"status":"DEVICE_BLOCKED"}'::jsonb; END IF;
 INSERT INTO public.esim_orders(user_id,offer_id,bundle_name,provider,quantity,wholesale_price_usd,retail_price_usd,markup_percent,
  total_amount_usd,status,operation_kind,recharge_profile_id,recharge_quote_id,catalogue_snapshot)
 VALUES(u,q.package_id,q.package_id,'esimaccess',1,q.wholesale_usd,total,round((total/q.wholesale_usd-1)*100,2),total,'pending',
  CASE WHEN q.action='daily_extension' THEN 'daily_extension' ELSE 'fixed_recharge' END,p.id,q.id,jsonb_build_object('catalogue_details',q.retail_snapshot,'period_count',CASE WHEN q.action='daily_extension' THEN q.period_count END,'daily_price_id',q.daily_price_id,'daily_source_facts',(SELECT value FROM jsonb_array_elements(c.offers) WHERE value->>'package_id'=q.package_id),'daily_base_price',(SELECT (value->>'wholesale_usd')::numeric FROM jsonb_array_elements(c.offers) WHERE value->>'package_id'=q.package_id),'daily_previous_expiry',p.confirmed_expires_at,'supplier_profile_ref',p.supplier_profile_ref,
  'iccid',p.iccid,'supplier_account_id',p.supplier_account_id,'quote_context',q.context)) RETURNING * INTO o;
 PERFORM esim_private.reserve_order(o.id);
 RETURN jsonb_build_object('status','ACCEPTED','order_id',o.id);
END $$;

CREATE OR REPLACE FUNCTION public.service_esim_mark_submitted(p_order_id uuid,p_lease uuid) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r esim_private.order_runs; o public.esim_orders; p public.user_esims; q esim_private.recharge_quotes; reason text; reject_code text; available numeric;
BEGIN
 PERFORM esim_private.require_service();SELECT * INTO STRICT o FROM public.esim_orders WHERE id=p_order_id;
 PERFORM 1 FROM public.wallets WHERE user_id=o.user_id FOR UPDATE;
 IF o.recharge_profile_id IS NOT NULL THEN SELECT * INTO STRICT p FROM public.user_esims WHERE id=o.recharge_profile_id FOR UPDATE; END IF;
 SELECT * INTO STRICT r FROM esim_private.order_runs WHERE order_id=o.id FOR UPDATE;
 IF p_lease IS NULL OR r.lease IS DISTINCT FROM p_lease OR r.lease_until IS NULL OR r.lease_until<now() OR r.state<>'prepared' OR r.submitted_at IS NOT NULL THEN RETURN false; END IF;
 IF r.finance_kind<>'reserved' OR r.hold_id IS NULL OR r.payer_id IS DISTINCT FROM o.user_id THEN RETURN false; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.esim_suppliers WHERE code=o.provider AND is_active) THEN reject_code:='SUPPLIER_DISABLED'; END IF;
 IF o.operation_kind IN('fixed_recharge','daily_extension') THEN
  IF NOT esim_private.recharge_can_accept() THEN reject_code:='SUBMISSION_DISABLED'; END IF;
  SELECT * INTO STRICT q FROM esim_private.recharge_quotes WHERE id=o.recharge_quote_id;
  IF q.expires_at<=now() THEN reject_code:='QUOTE_EXPIRED'; END IF;
  IF q.context IS DISTINCT FROM esim_private.topup_context(p) OR p.user_id IS DISTINCT FROM o.user_id
   OR p.supplier_account_id IS DISTINCT FROM r.account_id OR esim_private.topup_refusal_base(p) IS NOT NULL THEN reject_code:='PROFILE_CHANGED'; END IF;
  IF EXISTS(SELECT 1 FROM public.esim_orders WHERE recharge_profile_id=p.id AND id<>o.id AND status IN('pending','processing')) THEN reject_code:='PROFILE_CHANGED'; END IF;
 ELSE
  IF NOT EXISTS(SELECT 1 FROM esim_private.accounts WHERE id=r.account_id AND new_sales_enabled AND wallet_boundary_verified) THEN reject_code:='SUBMISSION_DISABLED'; END IF;
  IF o.daily_purchase_quote_id IS NULL AND NOT EXISTS(SELECT 1 FROM public.esim_offers_cache WHERE provider=o.provider AND bundle_name=o.bundle_name AND is_active AND wholesale_price_usd=o.wholesale_price_usd) THEN reject_code:='PRICE_CHANGED'; END IF;
 END IF;
 IF public.resolve_esim_offer_price(o.wholesale_price_usd,o.user_id) IS DISTINCT FROM o.retail_price_usd THEN reject_code:='PRICE_CHANGED'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=o.user_id AND NOT coalesce(is_suspended,false)) THEN reject_code:='SUBMISSION_DISABLED'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.wallet_holds WHERE id=r.hold_id AND status='active' AND user_id=r.payer_id AND amount=o.total_amount_usd AND expires_at IS NULL) THEN reject_code:='SUBMISSION_DISABLED'; END IF;
 SELECT w.balance-coalesce((SELECT sum(amount) FROM public.wallet_holds WHERE wallet_id=w.id AND status='active'),0) INTO available FROM public.wallets w WHERE user_id=r.payer_id AND currency='USD';
 IF available IS NULL OR available<0 OR available::text IN('NaN','Infinity','-Infinity') THEN reject_code:='SUBMISSION_DISABLED'; END IF;
 IF (o.daily_purchase_quote_id IS NOT NULL OR o.operation_kind='daily_extension') AND NOT EXISTS(SELECT 1 FROM esim_private.accounts WHERE id=r.account_id AND daily_duration_enabled AND daily_contract_verified) THEN reject_code:='SUBMISSION_DISABLED'; END IF;
 IF NOT esim_private.daily_order_current(o) THEN reject_code:='PRICE_CHANGED'; END IF;
 IF reject_code IS NOT NULL THEN PERFORM public.service_esim_fail_before_submit(o.id,p_lease,reject_code);RETURN false; END IF;
 UPDATE esim_private.order_runs SET state='submitted',submitted_at=now(),updated_at=now() WHERE order_id=o.id;
 UPDATE public.esim_orders SET delivery_state='submitted' WHERE id=o.id;RETURN true;
END $$;

CREATE OR REPLACE FUNCTION public.snapshot_esim_catalogue_order()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 IF NEW.daily_purchase_quote_id IS NOT NULL THEN
  SELECT snapshot INTO STRICT NEW.catalogue_snapshot FROM esim_private.daily_purchase_quotes WHERE id=NEW.daily_purchase_quote_id AND owner_id=NEW.user_id AND package_id=NEW.bundle_name AND quantity=NEW.quantity AND wholesale_total=NEW.wholesale_price_usd AND retail_total=NEW.total_amount_usd;
  RETURN NEW;
 END IF;
 IF NEW.operation_kind IN('fixed_recharge','daily_extension') THEN RETURN NEW; END IF;
  SELECT jsonb_build_object('provider',c.provider,'bundle_name',c.bundle_name,
    'catalogue_details',c.catalogue_details,'countries',c.countries,
    'data_amount_mb',c.data_amount_mb,'duration_days',c.duration_days,
    'is_unlimited',c.is_unlimited,'retail_price_usd',NEW.retail_price_usd,
    'catalogue_observed_at',c.updated_at)
  INTO NEW.catalogue_snapshot FROM public.esim_offers_cache c
  WHERE c.provider=NEW.provider AND c.bundle_name=NEW.bundle_name;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.request_esim_purchase_v2(p_offer_id text,p_quantity integer,p_device_id text,p_request_key uuid,p_reviewed_total numeric,p_expected_user uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_offer RECORD;
  v_supplier_markup numeric;
  v_markup_percent numeric := 30.0;
  v_retail_price numeric(10,2);
  v_total_cost numeric(10,2);
  v_wallet_balance numeric(10,2);
  v_order_id uuid;
  v_txn_ref text;
  v_guard jsonb;
  existing public.esim_orders;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  IF p_expected_user IS DISTINCT FROM v_user_id THEN RETURN jsonb_build_object('success',false,'code','ACCOUNT_CHANGED'); END IF;
  PERFORM esim_private.require_money_session(v_user_id);
  IF p_request_key IS NULL OR p_reviewed_total IS NULL OR p_reviewed_total<=0 OR p_reviewed_total::text IN('NaN','Infinity','-Infinity') THEN
    RETURN jsonb_build_object('success',false,'code','INVALID_REVIEWED_INTENT'); END IF;
  PERFORM 1 FROM public.wallets WHERE user_id=v_user_id FOR UPDATE;
  SELECT * INTO existing FROM public.esim_orders WHERE user_id=v_user_id AND client_request_key=p_request_key;
  IF FOUND THEN
    IF existing.offer_id IS DISTINCT FROM p_offer_id OR existing.quantity IS DISTINCT FROM p_quantity OR existing.total_amount_usd IS DISTINCT FROM p_reviewed_total THEN
      RETURN jsonb_build_object('success',false,'code','INTENT_CONFLICT'); END IF;
    RETURN jsonb_build_object('success',true,'order_id',existing.id,'status',existing.status,'adopted',true);
  END IF;
  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = v_user_id AND is_suspended = true) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Account is suspended. Purchases are disabled.');
  END IF;

  PERFORM public.enforce_rate_limit('esim_purchase', v_user_id::text);

  IF p_quantity IS NULL OR p_quantity < 1 OR p_quantity > 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Quantity must be between 1 and 3');
  END IF;

  SELECT c.* INTO v_offer
  FROM public.esim_offers_cache c
  JOIN public.esim_suppliers s ON s.code = c.provider AND s.is_active = true
  WHERE (c.bundle_name = p_offer_id OR (c.provider || '_' || c.bundle_name = p_offer_id))
    AND c.is_active = true
  ORDER BY c.updated_at DESC
  LIMIT 1;

  IF v_offer IS NULL OR v_offer.bundle_name IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'eSIM offer not found or inactive');
  END IF;

  IF v_offer.catalogue_details->>'plan_type' IN('daily_throttled','daily_cutoff','daily_unlimited') THEN RETURN jsonb_build_object('success',false,'code','DURATION_REQUIRED'); END IF;
  -- Use canonical tier-based pricing via resolve_esim_offer_price
  v_retail_price := public.resolve_esim_offer_price(v_offer.wholesale_price_usd, v_user_id);
  IF v_retail_price IS NULL OR v_retail_price <= 0 THEN
    SELECT markup_percent_override INTO v_supplier_markup
    FROM public.esim_suppliers
    WHERE code = v_offer.provider;

    IF v_supplier_markup IS NOT NULL THEN
      v_markup_percent := v_supplier_markup;
    ELSE
      BEGIN
        SELECT config_value::numeric INTO v_markup_percent
        FROM public.system_configs WHERE config_key = 'ESIM_MARKUP_PERCENT';
      EXCEPTION WHEN OTHERS THEN v_markup_percent := 30.0; END;
    END IF;
    IF v_markup_percent IS NULL THEN v_markup_percent := 30.0; END IF;

    v_retail_price := round(v_offer.wholesale_price_usd * (1.0 + (v_markup_percent / 100.0)), 2);
  ELSE
    v_markup_percent := round(((v_retail_price - v_offer.wholesale_price_usd) / NULLIF(v_offer.wholesale_price_usd, 0)) * 100.0, 2);
  END IF;

  v_total_cost := v_retail_price * p_quantity;
  IF v_total_cost IS DISTINCT FROM p_reviewed_total THEN RETURN jsonb_build_object('success',false,'code','PRICE_CHANGED'); END IF;

  SELECT (public.get_wallet_summary(v_user_id)->>'available_balance')::numeric INTO v_wallet_balance;

  IF v_wallet_balance < v_total_cost THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'INSUFFICIENT_FUNDS',
      'error', 'Insufficient wallet balance. Required: $' || v_total_cost::text || ', Available: $' || v_wallet_balance::text
    );
  END IF;

  v_guard := public.guard_money_action('esim_purchase', v_total_cost, p_device_id, NULL, v_user_id);
  IF (v_guard ->> 'blocked')::boolean THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'DEVICE_BLOCKED',
      'reason', v_guard ->> 'reason',
      'error', 'This purchase was stopped by a security check on this device. Contact support if this is a mistake.'
    );
  END IF;

  INSERT INTO public.esim_orders (
    user_id, offer_id, bundle_name, provider, quantity, wholesale_price_usd, retail_price_usd, markup_percent, total_amount_usd, status, client_request_key
  ) VALUES (
    v_user_id, p_offer_id, v_offer.bundle_name, v_offer.provider, p_quantity, v_offer.wholesale_price_usd, v_retail_price, v_markup_percent, v_total_cost, 'pending', p_request_key
  ) RETURNING id INTO v_order_id;

  v_txn_ref := 'esim_' || v_order_id::text;

  PERFORM esim_private.reserve_order(v_order_id);

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'retail_price_usd', v_retail_price,
    'total_amount_usd', v_total_cost,
    'status', 'pending'
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.check_esim_topup_quote(p_quote_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  OR (q.action='daily_extension' AND NOT esim_private.daily_extension_current(q,p,c))
  OR public.resolve_esim_offer_price(q.wholesale_usd,u) IS DISTINCT FROM q.retail_total THEN RETURN '{"status":"STALE_QUOTE","acceptance_enabled":false}'::jsonb; END IF;
 RETURN jsonb_build_object('status','QUOTED','quote_id',q.id,'acceptance_key',q.acceptance_key,'owner_id',u,'payer_id',u,
 'profile_id',p.id,'action',q.action,'offer',q.retail_snapshot,'expires_at',q.expires_at,'acceptance_enabled',esim_private.recharge_can_accept() AND (q.action<>'daily_extension' OR EXISTS(SELECT 1 FROM esim_private.accounts WHERE id=q.account_id AND daily_duration_enabled AND daily_contract_verified)))||esim_private.topup_balance(u,q.retail_total);
END $function$;

CREATE OR REPLACE FUNCTION public.service_esim_settle_topup(p_order_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE o public.esim_orders; r esim_private.order_runs; p public.user_esims; q esim_private.recharge_quotes; receipt_value jsonb;
BEGIN
 PERFORM esim_private.require_service();
 SELECT * INTO STRICT o FROM public.esim_orders WHERE id=p_order_id;
 PERFORM 1 FROM public.wallets WHERE user_id=o.user_id FOR UPDATE;
 SELECT * INTO STRICT p FROM public.user_esims WHERE id=o.recharge_profile_id FOR UPDATE;
 SELECT * INTO STRICT r FROM esim_private.order_runs WHERE order_id=o.id FOR UPDATE;
 IF r.state='completed' AND r.settlement_state='captured' THEN RETURN '{"completed":true}'::jsonb; END IF;
 receipt_value:=r.receipt;
 IF o.operation_kind NOT IN('fixed_recharge','daily_extension') OR receipt_value IS NULL OR receipt_value->>'outcome'<>'success'
  OR p.user_id IS DISTINCT FROM o.user_id OR p.iccid IS DISTINCT FROM receipt_value->>'iccid'
  OR p.supplier_profile_ref IS DISTINCT FROM receipt_value->>'supplier_profile_ref' THEN RAISE EXCEPTION 'Settlement binding changed'; END IF;
 SELECT * INTO STRICT q FROM esim_private.recharge_quotes WHERE id=o.recharge_quote_id;
 PERFORM esim_private.settle_order(o.id,true);
 INSERT INTO esim_private.entitlements(order_id,profile_id,account_id,supplier_topup_ref,package_id,allowance_bytes,duration_value,duration_unit,retail_total,currency,provider_expires_at,expiry_confirmed)
 VALUES(o.id,p.id,r.account_id,receipt_value->>'topup_ref',o.bundle_name,(q.retail_snapshot->>'allowance_bytes')::bigint,
 q.duration_value,q.duration_unit,o.total_amount_usd,'USD',(receipt_value->>'expires_at')::timestamptz,p.bundle_state IN('active','depleted'));
 IF o.operation_kind='daily_extension' THEN
  UPDATE public.user_esims SET confirmed_expires_at=CASE WHEN bundle_state IN('active','depleted') THEN (receipt_value->>'expires_at')::timestamptz ELSE confirmed_expires_at END,expires_at=CASE WHEN bundle_state IN('active','depleted') THEN (receipt_value->>'expires_at')::timestamptz ELSE expires_at END WHERE id=p.id;
 ELSE
 UPDATE public.user_esims SET data_total_bytes=(receipt_value->>'total_bytes')::bigint,data_used_bytes=(receipt_value->>'used_bytes')::bigint,
  data_remaining_bytes=(receipt_value->>'total_bytes')::bigint-(receipt_value->>'used_bytes')::bigint,
  data_total_mb=floor((receipt_value->>'total_bytes')::numeric/1048576),
  data_remaining_mb=floor(((receipt_value->>'total_bytes')::numeric-(receipt_value->>'used_bytes')::numeric)/1048576),
  confirmed_expires_at=CASE WHEN bundle_state IN('active','depleted') THEN (receipt_value->>'expires_at')::timestamptz ELSE confirmed_expires_at END,
  expires_at=CASE WHEN bundle_state IN('active','depleted') THEN (receipt_value->>'expires_at')::timestamptz ELSE expires_at END,
  bundle_state=CASE WHEN bundle_state='depleted' THEN 'active' ELSE bundle_state END,last_observation_at=clock_timestamp(),
  last_usage_check=clock_timestamp(),usage_observed_at=NULL,usage_error_code=NULL WHERE id=p.id;
 END IF;
 PERFORM esim_private.open_alert_cycle(p.id,'recharge:'||o.id::text);
 DELETE FROM esim_private.topup_cache WHERE profile_id=p.id;
 UPDATE esim_private.profile_work SET next_check_at=now() WHERE profile_id=p.id;
 UPDATE esim_private.order_runs SET state='completed',lease=NULL,lease_until=NULL,next_check_at=NULL,error_code=NULL,updated_at=now() WHERE order_id=o.id;
 UPDATE public.esim_orders SET status='completed',delivery_state='completed',provider_order_ref=receipt_value->>'topup_ref',updated_at=now() WHERE id=o.id;
 RETURN '{"completed":true}'::jsonb;
END $$;

CREATE OR REPLACE FUNCTION esim_private.alert_is_relevant(p_profile_id uuid,p_event_type text,p_threshold integer DEFAULT 0)
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
 IF p_event_type='esim_low_data' AND p.plan_details->>'plan_type' LIKE 'daily_%' THEN RETURN false; END IF;
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

CREATE OR REPLACE FUNCTION public.prune_esim_topup_discovery() RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN
 PERFORM esim_private.require_service();
 DELETE FROM esim_private.recharge_quotes q WHERE expires_at<now()-interval '30 days' AND NOT EXISTS(SELECT 1 FROM public.esim_orders WHERE recharge_quote_id=q.id);
 DELETE FROM esim_private.daily_purchase_quotes q WHERE expires_at<now()-interval '30 days' AND NOT EXISTS(SELECT 1 FROM public.esim_orders WHERE daily_purchase_quote_id=q.id);
 DELETE FROM esim_private.daily_prices r WHERE expires_at<now()-interval '30 days' AND NOT EXISTS(SELECT 1 FROM esim_private.daily_purchase_quotes WHERE price_id=r.id) AND NOT EXISTS(SELECT 1 FROM esim_private.recharge_quotes WHERE daily_price_id=r.id);
 DELETE FROM esim_private.topup_cache WHERE requested_at<now()-interval '1 day'; END $$;

CREATE OR REPLACE FUNCTION public.get_esim_operation_history(p_profile_id uuid DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); result jsonb;
BEGIN
 PERFORM esim_private.require_live_owner(u);
 IF p_profile_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.user_esims WHERE id=p_profile_id AND user_id=u) THEN RETURN '[]'::jsonb; END IF;
 SELECT coalesce(jsonb_agg(value ORDER BY created_at DESC),'[]') INTO result FROM(
  SELECT o.created_at,jsonb_build_object('id',o.id,'profile_id',o.recharge_profile_id,'kind',o.operation_kind,'package_id',o.bundle_name,
   'retail_total',o.total_amount_usd,'currency','USD','status',o.status,'delivery_state',o.delivery_state,'created_at',o.created_at,
   'financial_state',coalesce(r.settlement_state,'support_required'),'funds_reserved',r.finance_kind='reserved' AND r.settlement_state='pending',
   'confirmed_expiry',CASE WHEN e.expiry_confirmed THEN e.provider_expires_at END,'duration_value',coalesce(e.duration_value,(o.catalogue_snapshot->>'period_count')::integer),'duration_unit',coalesce(e.duration_unit,CASE WHEN o.catalogue_snapshot->>'period_count' IS NOT NULL THEN 'DAY' END),
   'support_required',o.delivery_state='support_required') value
  FROM public.esim_orders o LEFT JOIN esim_private.order_runs r ON r.order_id=o.id
  LEFT JOIN esim_private.entitlements e ON e.order_id=o.id WHERE o.user_id=u
   AND (p_profile_id IS NULL OR o.recharge_profile_id=p_profile_id OR o.id=(SELECT order_id FROM public.user_esims WHERE id=p_profile_id AND user_id=u))
  ORDER BY o.created_at DESC LIMIT 50) rows;
 RETURN result;
END $$;

ALTER VIEW public.customer_esim_orders SET(security_invoker=true,security_barrier=true);
NOTIFY pgrst,'reload schema';
COMMIT;
