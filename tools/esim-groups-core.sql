-- ESIM-13: purchaser-owned groups with one existing financial operation per member.
ALTER TABLE esim_private.accounts ADD COLUMN group_orders_enabled boolean NOT NULL DEFAULT false,
 ADD COLUMN max_group_members integer NOT NULL DEFAULT 3 CHECK(max_group_members BETWEEN 1 AND 3);
CREATE TABLE esim_private.group_quotes(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),owner_id uuid NOT NULL,acceptance_key uuid NOT NULL DEFAULT gen_random_uuid(),
 group_label text NOT NULL,members jsonb NOT NULL CHECK(jsonb_typeof(members)='array' AND jsonb_array_length(members) BETWEEN 1 AND 3),
 total numeric(12,2) NOT NULL CHECK(total>0),created_at timestamptz NOT NULL DEFAULT now(),expires_at timestamptz NOT NULL
);
CREATE INDEX esim_group_quotes_owner ON esim_private.group_quotes(owner_id,created_at);
CREATE TABLE esim_private.group_batches(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),owner_id uuid NOT NULL,payer_id uuid NOT NULL CHECK(payer_id=owner_id),
 quote_id uuid NOT NULL UNIQUE REFERENCES esim_private.group_quotes(id),request_key uuid NOT NULL,
 group_label text NOT NULL,total numeric(12,2) NOT NULL CHECK(total>0),created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(owner_id,request_key)
);
CREATE INDEX esim_group_batches_owner ON esim_private.group_batches(owner_id,created_at);
CREATE TABLE esim_private.group_members(
 batch_id uuid NOT NULL REFERENCES esim_private.group_batches(id),member_index integer NOT NULL CHECK(member_index BETWEEN 1 AND 3),
 order_id uuid NOT NULL UNIQUE REFERENCES public.esim_orders(id),profile_id uuid UNIQUE REFERENCES public.user_esims(id),
 traveller_label text NOT NULL,package_id text NOT NULL,quote_context text NOT NULL,retail_total numeric(12,2) NOT NULL CHECK(retail_total>0),
 PRIMARY KEY(batch_id,member_index)
);
CREATE TABLE esim_private.profile_labels(
 profile_id uuid PRIMARY KEY REFERENCES public.user_esims(id) ON DELETE CASCADE,owner_id uuid NOT NULL,
 traveller_label text NOT NULL DEFAULT '' CHECK(length(traveller_label)<=60),group_label text NOT NULL DEFAULT '' CHECK(length(group_label)<=60),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX esim_profile_labels_owner ON esim_private.profile_labels(owner_id,group_label);

CREATE FUNCTION esim_private.group_label_valid(value text) RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT value IS NOT NULL AND length(value)<=60 AND value!~'[[:cntrl:]]';
$$;
CREATE FUNCTION esim_private.group_offer_context(c public.esim_offers_cache,u uuid) RETURNS text LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT md5(jsonb_build_array(c.provider,c.bundle_name,c.is_active,c.wholesale_price_usd,c.catalogue_details,c.countries,c.data_amount_mb,c.duration_days,
  public.resolve_esim_offer_price(c.wholesale_price_usd,u))::text);
$$;
CREATE FUNCTION public.set_esim_profile_label(p_profile_id uuid,p_traveller_label text,p_group_label text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();p public.user_esims;
BEGIN
 PERFORM esim_private.require_live_owner(u);
 IF NOT esim_private.group_label_valid(p_traveller_label) OR NOT esim_private.group_label_valid(p_group_label) THEN RETURN '{"status":"INVALID_LABEL"}'::jsonb; END IF;
 SELECT * INTO p FROM public.user_esims WHERE id=p_profile_id AND user_id=u FOR UPDATE;
 IF NOT FOUND THEN RETURN '{"status":"PROFILE_UNAVAILABLE"}'::jsonb; END IF;
 IF p.provider IS DISTINCT FROM 'esimaccess' THEN RETURN '{"status":"UNSUPPORTED_PROFILE"}'::jsonb; END IF;
 INSERT INTO esim_private.profile_labels(profile_id,owner_id,traveller_label,group_label) VALUES(p.id,u,trim(p_traveller_label),trim(p_group_label))
 ON CONFLICT(profile_id) DO UPDATE SET traveller_label=excluded.traveller_label,group_label=excluded.group_label,updated_at=now() WHERE profile_labels.owner_id=u;
 RETURN '{"status":"SAVED"}'::jsonb;
END $$;
CREATE FUNCTION public.quote_esim_group(p_group_label text,p_members jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();a esim_private.accounts;item jsonb;c public.esim_offers_cache;members jsonb:='[]';retail jsonb;daily_quote jsonb;
 unit_total numeric;total_value numeric:=0;idx integer:=0;days integer;expires timestamptz:=now()+interval '2 minutes';q esim_private.group_quotes;label text;
BEGIN
 PERFORM esim_private.require_live_owner(u);
 SELECT * INTO STRICT a FROM esim_private.accounts WHERE account_key='primary';
 IF NOT esim_private.group_label_valid(p_group_label) THEN RETURN '{"status":"INVALID_LABEL"}'::jsonb; END IF;
 IF jsonb_typeof(p_members) IS DISTINCT FROM 'array' OR jsonb_array_length(p_members) NOT BETWEEN 1 AND a.max_group_members OR octet_length(p_members::text)>8192 THEN RETURN '{"status":"INVALID_GROUP_SIZE"}'::jsonb; END IF;
 IF (SELECT count(*) FROM esim_private.group_quotes WHERE owner_id=u AND created_at>now()-interval '1 minute')>=10 THEN RETURN '{"status":"RATE_LIMITED"}'::jsonb; END IF;
 FOR item IN SELECT value FROM jsonb_array_elements(p_members) LOOP
  IF jsonb_typeof(item) IS DISTINCT FROM 'object' OR EXISTS(SELECT 1 FROM jsonb_object_keys(item) k WHERE k NOT IN('offer_id','traveller_label','period_count'))
   OR jsonb_typeof(item->'offer_id') IS DISTINCT FROM 'string' OR length(item->>'offer_id') NOT BETWEEN 1 AND 120
   OR jsonb_typeof(item->'traveller_label') IS DISTINCT FROM 'string' OR NOT esim_private.group_label_valid(item->>'traveller_label') THEN RETURN '{"status":"INVALID_MEMBER"}'::jsonb; END IF;
 END LOOP;
 FOR item IN SELECT value FROM jsonb_array_elements(p_members) LOOP
  idx:=idx+1;
  SELECT * INTO c FROM public.esim_offers_cache WHERE provider='esimaccess' AND is_active
   AND (bundle_name=item->>'offer_id' OR 'esimaccess_'||bundle_name=item->>'offer_id') ORDER BY updated_at DESC LIMIT 1;
  IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM public.esim_suppliers WHERE code='esimaccess' AND is_active) THEN RETURN '{"status":"OFFER_UNAVAILABLE"}'::jsonb; END IF;
  IF c.updated_at IS NULL OR c.updated_at<now()-interval '2 hours' THEN RETURN '{"status":"CATALOGUE_STALE"}'::jsonb; END IF;
  days:=NULL;daily_quote:=NULL;
  IF c.catalogue_details->>'plan_type' IN('daily_throttled','daily_cutoff','daily_unlimited') THEN
   IF item->>'period_count' IS NULL OR (item->>'period_count')!~'^[0-9]{1,3}$' OR (item->>'period_count')::integer NOT BETWEEN 1 AND 365 THEN RETURN '{"status":"INVALID_DURATION"}'::jsonb; END IF;
   days:=(item->>'period_count')::integer;
   daily_quote:=public.quote_esim_daily_purchase(c.bundle_name,days,1);
   IF daily_quote->>'status' IS DISTINCT FROM 'QUOTED' THEN RETURN jsonb_build_object('status',daily_quote->>'status','member_index',idx); END IF;
   unit_total:=(daily_quote#>>'{offer,retail_total}')::numeric;
   expires:=least(expires,(daily_quote->>'expires_at')::timestamptz);
  ELSE
   IF c.catalogue_details->>'plan_type' IS DISTINCT FROM 'total' THEN RETURN '{"status":"CAPABILITY_UNVERIFIED"}'::jsonb; END IF;
   IF item->>'period_count' IS NOT NULL THEN RETURN '{"status":"INVALID_DURATION"}'::jsonb; END IF;
   unit_total:=public.resolve_esim_offer_price(c.wholesale_price_usd,u);
  END IF;
  IF unit_total IS NULL OR unit_total<=0 OR unit_total::text IN('NaN','Infinity','-Infinity') THEN RETURN '{"status":"PRICE_UNAVAILABLE"}'::jsonb; END IF;
  label:=coalesce(nullif(trim(item->>'traveller_label'),''),'Traveller '||idx);
  retail:=jsonb_build_object('member_index',idx,'traveller_label',label,'offer_id','esimaccess_'||c.bundle_name,'package_id',c.bundle_name,'title',c.description,
   'retail_total',unit_total,'currency','USD','plan_type',c.catalogue_details->>'plan_type','period_count',days,'allowance_bytes',c.catalogue_details->>'allowance_bytes',
   'duration_value',coalesce(days,(c.catalogue_details->>'duration_value')::integer),'duration_unit',CASE WHEN days IS NOT NULL THEN 'DAY' ELSE c.catalogue_details->>'duration_unit' END);
  members:=members||jsonb_build_array(jsonb_build_object('retail',retail,'context',esim_private.group_offer_context(c,u),
   'child_request_key',gen_random_uuid(),'daily_quote_id',daily_quote->>'quote_id','daily_acceptance_key',daily_quote->>'acceptance_key'));
  total_value:=total_value+unit_total;
 END LOOP;
 INSERT INTO esim_private.group_quotes(owner_id,group_label,members,total,expires_at)
 VALUES(u,coalesce(nullif(trim(p_group_label),''),'Travel group'),members,total_value,expires) RETURNING * INTO q;
 RETURN jsonb_build_object('status','QUOTED','quote_id',q.id,'acceptance_key',q.acceptance_key,'owner_id',u,'payer_id',u,'group_label',q.group_label,
 'members',(SELECT jsonb_agg(value->'retail' ORDER BY (value#>>'{retail,member_index}')::integer) FROM jsonb_array_elements(members)),
 'retail_total',total_value,'currency','USD','expires_at',expires,'max_members',a.max_group_members,
 'acceptance_enabled',a.group_orders_enabled AND a.new_sales_enabled AND a.wallet_boundary_verified AND
  (NOT EXISTS(SELECT 1 FROM jsonb_array_elements(members) x WHERE x->>'daily_quote_id' IS NOT NULL) OR (a.daily_duration_enabled AND a.daily_contract_verified)))||esim_private.topup_balance(u,total_value);
END $$;
CREATE FUNCTION public.accept_esim_group(p_quote_id uuid,p_acceptance_key uuid,p_request_key uuid,p_device_id text DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();q esim_private.group_quotes;b esim_private.group_batches;a esim_private.accounts;item jsonb;c public.esim_offers_cache;
 result jsonb;child_id uuid;idx integer;reason text;child public.esim_orders;
BEGIN
 PERFORM esim_private.require_money_session(u);
 IF p_request_key IS NULL THEN RETURN '{"status":"INVALID_REQUEST"}'::jsonb; END IF;
 PERFORM 1 FROM public.wallets WHERE user_id=u FOR UPDATE;
 SELECT * INTO q FROM esim_private.group_quotes WHERE id=p_quote_id AND owner_id=u AND acceptance_key=p_acceptance_key FOR UPDATE;
 IF NOT FOUND THEN RETURN '{"status":"QUOTE_UNAVAILABLE"}'::jsonb; END IF;
 SELECT * INTO b FROM esim_private.group_batches WHERE owner_id=u AND (quote_id=q.id OR request_key=p_request_key);
 IF FOUND THEN
  IF b.quote_id IS DISTINCT FROM q.id THEN RETURN '{"status":"REQUEST_CONFLICT"}'::jsonb; END IF;
  RETURN jsonb_build_object('status','ADOPTED','batch_id',b.id);
 END IF;
 SELECT * INTO STRICT a FROM esim_private.accounts WHERE account_key='primary';
 IF NOT a.group_orders_enabled OR NOT a.new_sales_enabled OR NOT a.wallet_boundary_verified THEN RETURN '{"status":"GROUP_ORDERS_DISABLED"}'::jsonb; END IF;
 IF q.expires_at<=now() OR jsonb_array_length(q.members)>a.max_group_members THEN RETURN '{"status":"STALE_QUOTE"}'::jsonb; END IF;
 IF (esim_private.topup_balance(u,q.total)->>'balance_state') IS DISTINCT FROM 'sufficient' THEN RETURN '{"status":"BALANCE_UNAVAILABLE"}'::jsonb; END IF;
 -- The inner transaction rolls back every reservation/child on any refusal.
 BEGIN
  INSERT INTO esim_private.group_batches(owner_id,payer_id,quote_id,request_key,group_label,total) VALUES(u,u,q.id,p_request_key,q.group_label,q.total) RETURNING * INTO b;
  FOR item IN SELECT value FROM jsonb_array_elements(q.members) LOOP
   idx:=(item#>>'{retail,member_index}')::integer;
   SELECT * INTO c FROM public.esim_offers_cache WHERE provider='esimaccess' AND bundle_name=item#>>'{retail,package_id}' AND is_active FOR SHARE;
   IF NOT FOUND OR c.updated_at<now()-interval '2 hours' OR item->>'context' IS DISTINCT FROM esim_private.group_offer_context(c,u) THEN reason:='STALE_QUOTE';RAISE EXCEPTION 'Group refused' USING ERRCODE='KS413'; END IF;
   IF item->>'daily_quote_id' IS NOT NULL THEN
    result:=public.accept_esim_daily_purchase((item->>'daily_quote_id')::uuid,(item->>'daily_acceptance_key')::uuid,(item->>'child_request_key')::uuid,p_device_id);
    IF result->>'status' NOT IN('ACCEPTED','ADOPTED') OR result->>'status' IS NULL THEN reason:=coalesce(result->>'status','TEMPORARILY_UNAVAILABLE');RAISE EXCEPTION 'Group refused' USING ERRCODE='KS413'; END IF;
   ELSE
    result:=public.request_esim_purchase_v2(item#>>'{retail,offer_id}',1,p_device_id,(item->>'child_request_key')::uuid,(item#>>'{retail,retail_total}')::numeric,u);
    IF result->>'success' IS DISTINCT FROM 'true' THEN reason:=coalesce(result->>'code','TEMPORARILY_UNAVAILABLE');RAISE EXCEPTION 'Group refused' USING ERRCODE='KS413'; END IF;
   END IF;
   child_id:=(result->>'order_id')::uuid;SELECT * INTO STRICT child FROM public.esim_orders WHERE id=child_id;
   IF child.user_id IS DISTINCT FROM u OR child.provider<>'esimaccess' OR child.quantity<>1 OR child.bundle_name IS DISTINCT FROM c.bundle_name
    OR child.total_amount_usd IS DISTINCT FROM (item#>>'{retail,retail_total}')::numeric THEN reason:='STALE_QUOTE';RAISE EXCEPTION 'Group refused' USING ERRCODE='KS413'; END IF;
   INSERT INTO esim_private.group_members(batch_id,member_index,order_id,traveller_label,package_id,quote_context,retail_total)
   VALUES(b.id,idx,child_id,item#>>'{retail,traveller_label}',c.bundle_name,item->>'context',child.total_amount_usd);
  END LOOP;
 EXCEPTION WHEN SQLSTATE 'KS413' THEN RETURN jsonb_build_object('status',reason); END;
 RETURN jsonb_build_object('status','ACCEPTED','batch_id',b.id);
END $$;
CREATE FUNCTION esim_private.bind_group_profile() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE m esim_private.group_members;b esim_private.group_batches;
BEGIN
 SELECT * INTO m FROM esim_private.group_members WHERE order_id=NEW.order_id FOR UPDATE;
 IF NOT FOUND THEN RETURN NEW; END IF;
 SELECT * INTO STRICT b FROM esim_private.group_batches WHERE id=m.batch_id;
 IF NEW.user_id IS DISTINCT FROM b.owner_id OR NEW.provider IS DISTINCT FROM 'esimaccess' OR m.profile_id IS NOT NULL THEN RAISE EXCEPTION 'Group profile binding conflict'; END IF;
 UPDATE esim_private.group_members SET profile_id=NEW.id WHERE batch_id=m.batch_id AND member_index=m.member_index;
 INSERT INTO esim_private.profile_labels(profile_id,owner_id,traveller_label,group_label) VALUES(NEW.id,b.owner_id,m.traveller_label,b.group_label);
 RETURN NEW;
END $$;
CREATE TRIGGER bind_esim_group_profile AFTER INSERT ON public.user_esims FOR EACH ROW EXECUTE FUNCTION esim_private.bind_group_profile();
CREATE FUNCTION esim_private.group_order_current(o public.esim_orders) RETURNS boolean LANGUAGE plpgsql STABLE SET search_path='' AS $$
DECLARE m esim_private.group_members;b esim_private.group_batches;c public.esim_offers_cache;
BEGIN
 SELECT * INTO m FROM esim_private.group_members WHERE order_id=o.id;IF NOT FOUND THEN RETURN true; END IF;
 SELECT * INTO STRICT b FROM esim_private.group_batches WHERE id=m.batch_id;
 SELECT * INTO c FROM public.esim_offers_cache WHERE provider='esimaccess' AND bundle_name=m.package_id AND is_active;
 RETURN coalesce(o.operation_kind='purchase' AND o.quantity=1 AND o.user_id=b.owner_id AND b.payer_id=o.user_id AND o.total_amount_usd=m.retail_total
 AND c.updated_at>now()-interval '2 hours' AND m.quote_context=esim_private.group_offer_context(c,b.owner_id)
 AND EXISTS(SELECT 1 FROM esim_private.accounts WHERE account_key='primary' AND group_orders_enabled),false);
END $$;
CREATE FUNCTION esim_private.group_projection(p_batch_id uuid) RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='' AS $$
DECLARE b esim_private.group_batches;members jsonb;state_value text;
BEGIN
 SELECT * INTO STRICT b FROM esim_private.group_batches WHERE id=p_batch_id;
 SELECT jsonb_agg(jsonb_build_object('member_index',m.member_index,'traveller_label',m.traveller_label,'order_id',o.id,'profile_id',m.profile_id,
 'package_id',m.package_id,'retail_total',m.retail_total,'currency','USD','delivery_state',o.delivery_state,'operation_state',r.state,'settlement_state',r.settlement_state,
 'profile_state',p.profile_state,'reserved_amount',CASE WHEN h.status='active' THEN h.amount ELSE 0 END,
 'charged_amount',CASE WHEN r.settlement_state='captured' THEN o.total_amount_usd ELSE 0 END,
 'released_amount',CASE WHEN r.settlement_state='released' THEN o.total_amount_usd ELSE 0 END,
 'refunded_amount',(SELECT coalesce(sum(f.amount),0) FROM esim_private.cancellation_refunds f WHERE f.debit_id=r.settlement_tx_id),
 'refund_pending',EXISTS(SELECT 1 FROM esim_private.controls WHERE profile_id=p.id AND state='refund_pending')) ORDER BY m.member_index) INTO members
 FROM esim_private.group_members m JOIN public.esim_orders o ON o.id=m.order_id JOIN esim_private.order_runs r ON r.order_id=o.id
 LEFT JOIN public.user_esims p ON p.id=m.profile_id AND p.user_id=b.owner_id LEFT JOIN public.wallet_holds h ON h.id=r.hold_id WHERE m.batch_id=b.id;
 SELECT CASE WHEN bool_and(coalesce(x->>'profile_state'='cancelled',false)) THEN 'cancelled'
 WHEN bool_or(x->>'profile_state'='cancelled') THEN 'partially_cancelled'
 WHEN bool_and(x->>'operation_state'='completed') THEN 'completed'
 WHEN bool_or(x->>'operation_state'='completed') THEN 'partial'
 WHEN bool_and(x->>'operation_state'='failed') THEN 'failed'
 WHEN bool_or(x->>'operation_state'='support_required') THEN 'needs_support' ELSE 'pending' END INTO state_value FROM jsonb_array_elements(members) x;
 RETURN jsonb_build_object('batch_id',b.id,'owner_id',b.owner_id,'payer_id',b.payer_id,'group_label',b.group_label,'state',state_value,'retail_total',b.total,'currency','USD','created_at',b.created_at,'members',members);
END $$;
CREATE FUNCTION public.get_esim_organization(p_batch_id uuid DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();groups jsonb;labels jsonb;
BEGIN
 PERFORM esim_private.require_live_owner(u);
 SELECT coalesce(jsonb_agg(esim_private.group_projection(x.id) ORDER BY x.created_at DESC),'[]'::jsonb) INTO groups
 FROM (SELECT id,created_at FROM esim_private.group_batches WHERE owner_id=u AND (p_batch_id IS NULL OR id=p_batch_id) ORDER BY created_at DESC LIMIT 50) x;
 SELECT coalesce(jsonb_agg(jsonb_build_object('profile_id',l.profile_id,'traveller_label',l.traveller_label,'group_label',l.group_label)),'[]'::jsonb) INTO labels
 FROM esim_private.profile_labels l JOIN public.user_esims p ON p.id=l.profile_id AND p.user_id=u WHERE l.owner_id=u;
 RETURN jsonb_build_object('status','READY','owner_id',u,'groups',groups,'labels',labels,'max_members',(SELECT max_group_members FROM esim_private.accounts WHERE account_key='primary'));
END $$;
CREATE FUNCTION public.admin_esim_group(p_batch_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 PERFORM public.assert_admin();
 IF NOT EXISTS(SELECT 1 FROM esim_private.group_batches WHERE id=p_batch_id) THEN RETURN '{"status":"GROUP_UNAVAILABLE"}'::jsonb; END IF;
 result:=esim_private.group_projection(p_batch_id)-'group_label';
 result:=jsonb_set(result,'{members}',(SELECT jsonb_agg(value-'traveller_label') FROM jsonb_array_elements(result->'members')));
 PERFORM public.admin_log('esim.group.inspect','esim_group',p_batch_id::text,NULL,jsonb_build_object('members',jsonb_array_length(result->'members')),'Read-only group settlement inspection');
 RETURN result;
END $$;
CREATE FUNCTION public.admin_pause_esim_group_orders(p_reason text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.assert_admin();
 IF p_reason IS NULL OR length(trim(p_reason)) NOT BETWEEN 8 AND 500 THEN RAISE EXCEPTION 'A reason is required'; END IF;
 UPDATE esim_private.accounts SET group_orders_enabled=false WHERE account_key='primary';
 PERFORM public.admin_log('esim.group.pause','esim','group_orders',NULL,jsonb_build_object('enabled',false,'recovery_preserved',true),p_reason);
 RETURN '{"status":"PAUSED","recovery_preserved":true}'::jsonb;
END $$;
DO $acl$ DECLARE n text;r record; BEGIN
 FOREACH n IN ARRAY ARRAY['group_quotes','group_batches','group_members','profile_labels'] LOOP
  EXECUTE format('ALTER TABLE esim_private.%I ENABLE ROW LEVEL SECURITY',n);
  EXECUTE format('REVOKE ALL ON esim_private.%I FROM PUBLIC,anon,authenticated',n);
  EXECUTE format('GRANT SELECT ON esim_private.%I TO service_role',n);
 END LOOP;
 FOR r IN SELECT p.oid::regprocedure ident FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='esim_private'
 AND p.proname IN('group_label_valid','group_offer_context','bind_group_profile','group_order_current','group_projection') LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',r.ident);
 END LOOP;
 FOR r IN SELECT p.oid::regprocedure ident FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'
 AND p.proname IN('set_esim_profile_label','quote_esim_group','accept_esim_group','get_esim_organization','admin_esim_group','admin_pause_esim_group_orders') LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',r.ident);
  EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated',r.ident);
 END LOOP;
END $acl$;
