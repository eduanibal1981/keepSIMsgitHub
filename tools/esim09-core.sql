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
