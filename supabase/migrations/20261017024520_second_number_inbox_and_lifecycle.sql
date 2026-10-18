BEGIN;

-- Requires the coordinated wallet-funding release, not the legacy live helpers.
DO $$ BEGIN
  IF to_regprocedure('public.assert_wallet_funding_integrity(uuid,numeric)') IS NULL THEN
    RAISE EXCEPTION 'Deploy and verify wallet funding integrity before Second Number';
  END IF;
END $$;

ALTER TABLE public.virtual_did_numbers
  ADD COLUMN provider_sid text,
  ADD COLUMN number_type text NOT NULL DEFAULT 'unknown',
  ADD COLUMN supports_sms boolean NOT NULL DEFAULT false,
  ADD COLUMN supports_voice boolean NOT NULL DEFAULT false,
  ADD COLUMN kyc_status text NOT NULL DEFAULT 'unknown',
  ADD COLUMN grace_expires_at timestamptz,
  ADD COLUMN assigned_at timestamptz,
  ADD COLUMN released_at timestamptz,
  ADD COLUMN release_attempts integer NOT NULL DEFAULT 0,
  ADD COLUMN release_retry_at timestamptz,
  ADD COLUMN release_claim uuid,
  ADD COLUMN release_claim_expires_at timestamptz,
  ADD COLUMN billing_period_days integer NOT NULL DEFAULT 30,
  ADD COLUMN lifecycle_managed boolean NOT NULL DEFAULT false,
  ADD COLUMN renewal_warning_for timestamptz;
ALTER TABLE public.virtual_did_numbers DROP CONSTRAINT virtual_did_numbers_status_check;
ALTER TABLE public.virtual_did_numbers ADD CONSTRAINT virtual_did_numbers_status_check
  CHECK(status IN ('active','suspended','release_pending','released'));
ALTER TABLE public.wallet_holds DROP CONSTRAINT wallet_holds_order_type_check;
ALTER TABLE public.wallet_holds ADD CONSTRAINT wallet_holds_order_type_check CHECK(order_type IN
  ('refill_instant','refill_scheduled','setup_refill','plan_fee','esim_purchase','call_budget',
   'offline_voucher','refund_request','line_verification','second_number'));

-- No countries or prices are enabled by migration. Publish only pilot-verified
-- inventory and costed receive-only terms through an authorized operations path.
CREATE TABLE public.second_number_policies (
  country_code text NOT NULL CHECK(country_code ~ '^[A-Z]{2}$'),
  number_type text NOT NULL CHECK(number_type IN ('local','mobile','national','toll-free')),
  country_name text NOT NULL,
  enabled boolean NOT NULL DEFAULT false,
  minimum_monthly_usd numeric(10,2) NOT NULL CHECK(minimum_monthly_usd>0),
  usage_terms text NOT NULL CHECK(length(usage_terms) BETWEEN 20 AND 2000),
  terms_version text NOT NULL,
  -- Per-user regulatory onboarding is a later release. A global policy must
  -- never claim that all customers have already passed an identity check.
  kyc_status text NOT NULL CHECK(kyc_status='not_required'),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(country_code,number_type)
);
CREATE TABLE public.second_number_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES auth.users(id),
  phone_number text NOT NULL CHECK(phone_number ~ '^\+[1-9][0-9]{6,14}$'),
  country_code text NOT NULL, country_name text NOT NULL, number_type text NOT NULL,
  wholesale_monthly_usd numeric(10,2) NOT NULL CHECK(wholesale_monthly_usd>0),
  monthly_fee_usd numeric(10,2) NOT NULL CHECK(monthly_fee_usd>0),
  service_fee_usd numeric(10,2) NOT NULL CHECK(service_fee_usd>=0),
  setup_fee_usd numeric(10,2) NOT NULL CHECK(setup_fee_usd>=0),
  terms jsonb NOT NULL, expires_at timestamptz NOT NULL DEFAULT now()+interval '10 minutes',
  state text NOT NULL DEFAULT 'quoted' CHECK(state IN ('quoted','submitting','provisioning','reconciliation','active','failed')),
  auto_renew boolean NOT NULL DEFAULT false,
  hold_id uuid REFERENCES public.wallet_holds(id), provider_order_id text,
  provider_sid text, did_id uuid REFERENCES public.virtual_did_numbers(id),
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX second_number_one_live_order ON public.second_number_orders(phone_number)
  WHERE state IN ('submitting','provisioning','reconciliation','active');
CREATE INDEX second_number_order_owner ON public.second_number_orders(user_id,created_at DESC);
CREATE TABLE public.virtual_did_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), did_id uuid NOT NULL REFERENCES public.virtual_did_numbers(id),
  user_id uuid NOT NULL REFERENCES auth.users(id), sender_number text NOT NULL, recipient_number text NOT NULL,
  body text NOT NULL CHECK(length(body)<=16000), extracted_otp text,
  provider text NOT NULL, provider_msg_id text NOT NULL,
  is_read boolean NOT NULL DEFAULT false, received_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(provider,provider_msg_id)
);
CREATE INDEX virtual_did_messages_owner_time ON public.virtual_did_messages(user_id,received_at DESC,id);
CREATE INDEX virtual_did_messages_unread ON public.virtual_did_messages(did_id) WHERE NOT is_read;
CREATE INDEX second_number_renewal_due ON public.virtual_did_numbers(renews_at) WHERE status IN ('active','suspended');
CREATE INDEX second_number_release_due ON public.virtual_did_numbers(release_retry_at) WHERE status='release_pending';

ALTER TABLE public.second_number_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.second_number_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.virtual_did_messages ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.second_number_policies,public.second_number_orders,public.virtual_did_messages FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.second_number_policies,public.second_number_orders,public.virtual_did_messages TO service_role;
GRANT SELECT ON public.virtual_did_messages TO authenticated;
CREATE POLICY did_message_owner_read ON public.virtual_did_messages FOR SELECT TO authenticated
  USING(user_id=(select auth.uid()) AND NOT public.is_user_suspended());

CREATE FUNCTION public.admin_set_second_number_policy(p_config jsonb) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE before_row jsonb; r public.second_number_policies;
BEGIN
  PERFORM public.assert_admin();
  r:=jsonb_populate_record(NULL::public.second_number_policies,p_config);
  IF r.country_code NOT IN ('US','GB') OR r.country_code IS NULL OR nullif(r.terms_version,'') IS NULL THEN
    RAISE EXCEPTION 'Only US and UK pilot policies are supported'; END IF;
  SELECT to_jsonb(p) INTO before_row FROM public.second_number_policies p WHERE country_code=r.country_code AND number_type=r.number_type;
  INSERT INTO public.second_number_policies(country_code,number_type,country_name,enabled,minimum_monthly_usd,usage_terms,terms_version,kyc_status)
    VALUES(r.country_code,r.number_type,r.country_name,coalesce(r.enabled,false),r.minimum_monthly_usd,r.usage_terms,r.terms_version,r.kyc_status)
    ON CONFLICT(country_code,number_type) DO UPDATE SET country_name=excluded.country_name,enabled=excluded.enabled,
      minimum_monthly_usd=excluded.minimum_monthly_usd,usage_terms=excluded.usage_terms,terms_version=excluded.terms_version,
      kyc_status=excluded.kyc_status,updated_at=now();
  PERFORM public.admin_log('set_second_number_policy','second_number_policies',r.country_code,before_row,p_config,'Validated number supply and retail terms');
END $$;

CREATE FUNCTION public.second_number_service_only() RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF coalesce(auth.role(),'')<>'service_role' THEN RAISE EXCEPTION 'Trusted service required' USING ERRCODE='42501'; END IF;
END $$;

CREATE FUNCTION public.begin_second_number_purchase(p_user_id uuid,p_quote_id uuid,p_auto_renew boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE o public.second_number_orders; h uuid;
BEGIN
  PERFORM public.second_number_service_only();
  SELECT * INTO o FROM public.second_number_orders WHERE id=p_quote_id AND user_id=p_user_id FOR UPDATE;
  IF o.id IS NULL THEN RAISE EXCEPTION 'Quote unavailable'; END IF;
  IF EXISTS(SELECT 1 FROM auth.users WHERE id=p_user_id AND coalesce((raw_app_meta_data->>'is_suspended')::boolean,false)) THEN RAISE EXCEPTION 'Account unavailable'; END IF;
  IF o.state<>'quoted' THEN RETURN jsonb_build_object('submit',false,'order_id',o.id,'state',o.state); END IF;
  IF EXISTS(SELECT 1 FROM public.virtual_did_numbers WHERE phone_number=o.phone_number) THEN
    RAISE EXCEPTION 'Number is no longer available'; END IF;
  IF o.expires_at<=now() OR NOT EXISTS(SELECT 1 FROM public.second_number_policies WHERE country_code=o.country_code
    AND number_type=o.number_type AND enabled AND terms_version=o.terms->>'version') THEN RAISE EXCEPTION 'Quote expired; refresh availability'; END IF;
  h:=public.reserve_wallet_funds(p_user_id,o.monthly_fee_usd+o.setup_fee_usd,'second_number',o.id::text,'Second Number purchase',120);
  -- Durable ambiguity marker commits BEFORE the first upstream request.
  UPDATE public.wallet_holds SET carrier_in_flight=true WHERE id=h;
  UPDATE public.second_number_orders SET state='submitting',hold_id=h,auto_renew=p_auto_renew,updated_at=now() WHERE id=o.id;
  RETURN jsonb_build_object('submit',true,'order_id',o.id,'state','submitting');
END $$;

CREATE FUNCTION public.capture_second_number_hold(p_hold_id uuid,p_reference text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE h public.wallet_holds; w public.wallets; tx uuid;
BEGIN
  PERFORM public.second_number_service_only();
  SELECT * INTO w FROM public.wallets WHERE id=(SELECT wallet_id FROM public.wallet_holds WHERE id=p_hold_id) FOR UPDATE;
  SELECT * INTO h FROM public.wallet_holds WHERE id=p_hold_id FOR UPDATE;
  IF h.id IS NULL OR h.order_type<>'second_number' OR h.order_reference_id IS DISTINCT FROM p_reference
    OR h.user_id IS DISTINCT FROM w.user_id OR h.currency<>'USD' OR w.currency<>'USD' THEN RAISE EXCEPTION 'Reservation mismatch'; END IF;
  SELECT id INTO tx FROM public.wallet_transactions WHERE reference_id='hold_'||h.id AND wallet_id=w.id
    AND user_id=w.user_id AND type='did_purchase_debit' AND amount=h.amount AND status='completed';
  IF h.status='captured' AND tx IS NOT NULL THEN RETURN tx; END IF;
  IF h.status<>'active' OR w.balance<h.amount THEN RAISE EXCEPTION 'Funded reservation required'; END IF;
  PERFORM public.assert_wallet_funding_integrity(w.id);
  UPDATE public.wallets SET balance=balance-h.amount,total_spent=total_spent+h.amount,updated_at=now() WHERE id=w.id;
  UPDATE public.wallet_holds SET status='captured',carrier_in_flight=false,captured_at=now(),updated_at=now() WHERE id=h.id;
  -- The installed funding trigger is the only funding-lot consumer.
  INSERT INTO public.wallet_transactions(wallet_id,user_id,type,amount,balance_before,balance_after,description,reference_id,status,metadata)
    VALUES(w.id,w.user_id,'did_purchase_debit',h.amount,w.balance,w.balance-h.amount,'Second Number subscription',
      'hold_'||h.id,'completed',jsonb_build_object('hold_id',h.id,'order_type','second_number','order_reference_id',p_reference)) RETURNING id INTO tx;
  RETURN tx;
END $$;

CREATE FUNCTION public.finish_second_number_purchase(p_order_id uuid,p_provider_order_id text,p_provider_sid text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE o public.second_number_orders; d uuid;
BEGIN
  PERFORM public.second_number_service_only();
  SELECT * INTO o FROM public.second_number_orders WHERE id=p_order_id FOR UPDATE;
  IF o.id IS NULL OR nullif(p_provider_order_id,'') IS NULL OR nullif(p_provider_sid,'') IS NULL THEN RAISE EXCEPTION 'Verified carrier order required'; END IF;
  IF o.state='active' THEN
    IF o.provider_order_id<>p_provider_order_id OR o.provider_sid<>p_provider_sid THEN RAISE EXCEPTION 'Carrier identity mismatch'; END IF;
    RETURN o.did_id;
  END IF;
  IF o.state NOT IN ('submitting','provisioning','reconciliation') OR
    (o.provider_order_id IS NOT NULL AND o.provider_order_id<>p_provider_order_id) THEN RAISE EXCEPTION 'Order requires reconciliation'; END IF;
  PERFORM public.capture_second_number_hold(o.hold_id,o.id::text);
  INSERT INTO public.virtual_did_numbers(user_id,phone_number,country_code,country_name,provider,provider_sid,status,monthly_fee_usd,
    number_type,supports_sms,supports_voice,kyc_status,forward_mode,auto_renew,assigned_at,renews_at,lifecycle_managed)
    VALUES(o.user_id,o.phone_number,o.country_code,o.country_name,'telnyx',p_provider_sid,'active',o.monthly_fee_usd,
      o.number_type,true,false,o.terms->>'kyc_status','voicemail',o.auto_renew,now(),now()+interval '30 days',true) RETURNING id INTO d;
  UPDATE public.second_number_orders SET state='active',provider_order_id=p_provider_order_id,provider_sid=p_provider_sid,did_id=d,updated_at=now() WHERE id=o.id;
  RETURN d;
END $$;

CREATE FUNCTION public.fail_second_number_purchase(p_order_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE o public.second_number_orders;
BEGIN
  PERFORM public.second_number_service_only();
  SELECT * INTO o FROM public.second_number_orders WHERE id=p_order_id FOR UPDATE;
  IF o.state='failed' THEN RETURN; END IF;
  IF o.state NOT IN ('submitting','provisioning','reconciliation') THEN RAISE EXCEPTION 'Order cannot fail'; END IF;
  -- Caller must have authoritative rejection/cancellation evidence, never timeout.
  UPDATE public.wallet_holds SET carrier_in_flight=false WHERE id=o.hold_id;
  PERFORM public.release_wallet_hold(o.hold_id,'Carrier confirmed purchase failure');
  UPDATE public.second_number_orders SET state='failed',updated_at=now() WHERE id=o.id;
END $$;

CREATE FUNCTION public.get_second_numbers() RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
  SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY r.created_at),'[]'::jsonb) FROM (
    SELECT d.id,d.phone_number,d.country_code,d.country_name,d.status,d.monthly_fee_usd,d.forward_mode,d.forward_destination,
      d.auto_renew,d.renews_at,d.created_at,d.number_type,d.supports_sms,d.supports_voice,d.kyc_status,d.grace_expires_at,
      d.billing_period_days,d.lifecycle_managed,(SELECT count(*) FROM public.virtual_did_messages m WHERE m.did_id=d.id AND NOT m.is_read) unread_sms_count
    FROM public.virtual_did_numbers d WHERE d.user_id=auth.uid() AND NOT public.is_user_suspended() AND d.status<>'released'
  ) r;
$$;
CREATE FUNCTION public.mark_did_message_read(p_message_id uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF auth.uid() IS NULL OR public.is_user_suspended() THEN RAISE EXCEPTION 'Account unavailable' USING ERRCODE='42501'; END IF;
  UPDATE public.virtual_did_messages SET is_read=true WHERE id=p_message_id AND user_id=auth.uid();
END $$;
CREATE FUNCTION public.get_pending_second_number_orders() RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'state',state,'phone_number',phone_number,'did_id',did_id) ORDER BY created_at),'[]'::jsonb)
    FROM public.second_number_orders WHERE user_id=auth.uid() AND NOT public.is_user_suspended()
      AND state IN ('submitting','provisioning','reconciliation');
$$;
CREATE FUNCTION public.set_second_number_renewal(p_did_id uuid,p_auto_renew boolean) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF auth.uid() IS NULL OR public.is_user_suspended() THEN RAISE EXCEPTION 'Account unavailable' USING ERRCODE='42501'; END IF;
  UPDATE public.virtual_did_numbers SET auto_renew=p_auto_renew,updated_at=now() WHERE id=p_did_id AND user_id=auth.uid() AND lifecycle_managed AND status IN ('active','suspended');
  IF NOT FOUND THEN RAISE EXCEPTION 'Number unavailable'; END IF;
END $$;
CREATE FUNCTION public.request_second_number_release(p_did_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF auth.uid() IS NULL OR public.is_user_suspended() THEN RAISE EXCEPTION 'Account unavailable' USING ERRCODE='42501'; END IF;
  UPDATE public.virtual_did_numbers SET status='release_pending',auto_renew=false,release_retry_at=now(),updated_at=now()
    WHERE id=p_did_id AND user_id=auth.uid() AND provider='telnyx' AND status IN ('active','suspended','release_pending');
  IF NOT FOUND THEN RAISE EXCEPTION 'Number unavailable'; END IF;
END $$;

CREATE FUNCTION public.route_second_number_sms(p_provider text,p_provider_msg_id text,p_to text,p_from text,p_body text,p_received_at timestamptz)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE d public.virtual_did_numbers; msg uuid; candidate text; n text:=regexp_replace(p_to,'[ ()-]','','g'); old public.virtual_did_messages;
BEGIN
  PERFORM public.second_number_service_only();
  IF n IS NULL OR n!~'^\+[1-9][0-9]{6,14}$' OR p_provider NOT IN ('telnyx','twilio') OR
    nullif(p_provider_msg_id,'') IS NULL OR length(p_provider_msg_id)>200 OR nullif(p_from,'') IS NULL OR
    length(p_from)>200 OR p_body IS NULL OR length(p_body)>16000 OR p_received_at IS NULL OR p_received_at>now()+interval '5 minutes'
    THEN RAISE EXCEPTION 'Invalid message'; END IF;
  SELECT * INTO d FROM public.virtual_did_numbers WHERE phone_number=n FOR SHARE;
  IF d.id IS NULL THEN
    RETURN jsonb_build_object('route',CASE WHEN EXISTS(SELECT 1 FROM public.offline_refill_endpoints
      WHERE phone_number=n AND channel='sms' AND is_active) THEN 'refill' ELSE 'ignore' END);
  END IF;
  -- A known DID, even released/disabled or with stale ownership, never becomes a refill command.
  IF d.provider<>p_provider OR NOT d.supports_sms OR d.status NOT IN ('active','suspended') OR
    (d.status='suspended' AND (d.grace_expires_at IS NULL OR d.grace_expires_at<=now())) OR
    p_received_at<coalesce(d.assigned_at,d.created_at) THEN RETURN jsonb_build_object('route','did','stored',false); END IF;
  SELECT * INTO old FROM public.virtual_did_messages WHERE provider=p_provider AND provider_msg_id=p_provider_msg_id;
  IF old.id IS NOT NULL THEN
    IF old.did_id<>d.id OR old.sender_number<>p_from OR old.body<>p_body THEN RAISE EXCEPTION 'Message identity mismatch'; END IF;
    RETURN jsonb_build_object('route','did','stored',false);
  END IF;
  SELECT CASE WHEN count(*)=1 THEN min(parts[1]) END INTO candidate
    FROM regexp_matches(p_body,'\m([0-9]{3}-[0-9]{3}|[0-9]{4,8})\M','g') AS parts;
  INSERT INTO public.virtual_did_messages(did_id,user_id,sender_number,recipient_number,body,extracted_otp,provider,provider_msg_id,received_at)
    VALUES(d.id,d.user_id,p_from,n,p_body,replace(candidate,'-',''),p_provider,p_provider_msg_id,p_received_at)
    ON CONFLICT(provider,provider_msg_id) DO NOTHING RETURNING id INTO msg;
  IF msg IS NOT NULL THEN
    INSERT INTO public.notifications(user_id,category,title,body,action_url,source_event_key,template_data)
      VALUES(d.user_id,'system','New message on your second number','Open KeepSIMs to read your message.',
        '/calling/my-numbers?didId='||d.id||'&tab=sms','did_sms:'||p_provider||':'||p_provider_msg_id,jsonb_build_object('did_id',d.id));
  ELSE
    SELECT * INTO old FROM public.virtual_did_messages WHERE provider=p_provider AND provider_msg_id=p_provider_msg_id;
    IF old.did_id<>d.id OR old.sender_number<>p_from OR old.body<>p_body THEN RAISE EXCEPTION 'Message identity mismatch'; END IF;
  END IF;
  RETURN jsonb_build_object('route','did','stored',msg IS NOT NULL);
END $$;

CREATE FUNCTION public.process_second_number_renewals(p_limit integer DEFAULT 50) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE d public.virtual_did_numbers; h uuid; n integer:=0; reference text;
BEGIN
  PERFORM public.second_number_service_only();
  FOR d IN SELECT * FROM public.virtual_did_numbers WHERE lifecycle_managed AND provider='telnyx' AND provider_sid IS NOT NULL
    AND status IN ('active','suspended') AND renews_at<=now()+interval '3 days' ORDER BY renews_at
    LIMIT least(greatest(p_limit,1),100) FOR UPDATE SKIP LOCKED
  LOOP
    IF d.renews_at>now() THEN
      IF d.renewal_warning_for IS DISTINCT FROM d.renews_at THEN
        INSERT INTO public.notifications(user_id,category,title,body,source_event_key)
          VALUES(d.user_id,'system','Second Number renewal approaching','Review your balance and number renewal settings.',
            'did_warning:'||d.id||':'||extract(epoch FROM d.renews_at)::text);
        UPDATE public.virtual_did_numbers SET renewal_warning_for=d.renews_at WHERE id=d.id;
      END IF;
      CONTINUE;
    END IF;
    IF NOT d.auto_renew OR (d.grace_expires_at IS NOT NULL AND d.grace_expires_at<=now()) OR d.renews_at<now()-interval '3 days' THEN
      UPDATE public.virtual_did_numbers SET status='release_pending',release_retry_at=now(),auto_renew=false,updated_at=now() WHERE id=d.id;
      CONTINUE;
    END IF;
    reference:='renew:'||d.id||':'||extract(epoch FROM d.renews_at)::text;
    BEGIN
      h:=public.reserve_wallet_funds(d.user_id,d.monthly_fee_usd,'second_number',reference,'Second Number renewal',120);
      PERFORM public.capture_second_number_hold(h,reference);
      UPDATE public.virtual_did_numbers SET status='active',renews_at=d.renews_at+make_interval(days=>d.billing_period_days),
        grace_expires_at=NULL,renewal_warning_for=NULL,updated_at=now() WHERE id=d.id;
      n:=n+1;
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM NOT LIKE 'Insufficient available balance%' THEN RAISE; END IF;
      -- No partial debit survives the subtransaction. Keep a bounded recovery window.
      UPDATE public.virtual_did_numbers SET status='suspended',grace_expires_at=coalesce(d.grace_expires_at,d.renews_at+interval '3 days'),updated_at=now() WHERE id=d.id;
      IF d.status<>'suspended' THEN INSERT INTO public.notifications(user_id,category,title,body,source_event_key)
        VALUES(d.user_id,'wallet_low','Second Number renewal needs attention','Top up your wallet and review your number before its release deadline.',
          'did_grace:'||d.id||':'||extract(epoch FROM d.renews_at)::text); END IF;
    END;
  END LOOP;
  RETURN n;
END $$;

CREATE FUNCTION public.claim_second_number_releases(p_limit integer DEFAULT 10) RETURNS SETOF public.virtual_did_numbers
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  PERFORM public.second_number_service_only();
  RETURN QUERY UPDATE public.virtual_did_numbers SET release_claim=gen_random_uuid(),release_claim_expires_at=now()+interval '5 minutes',
    release_attempts=release_attempts+1 WHERE id IN(SELECT id FROM public.virtual_did_numbers
      WHERE status='release_pending' AND provider='telnyx' AND coalesce(release_retry_at,now())<=now()
      AND coalesce(release_claim_expires_at,now())<=now() ORDER BY release_retry_at LIMIT least(greatest(p_limit,1),30) FOR UPDATE SKIP LOCKED)
    RETURNING *;
END $$;
CREATE FUNCTION public.finish_second_number_release(p_did_id uuid,p_claim uuid,p_confirmed boolean) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  PERFORM public.second_number_service_only();
  UPDATE public.virtual_did_numbers SET status=CASE WHEN p_confirmed THEN 'released' ELSE 'release_pending' END,
    released_at=CASE WHEN p_confirmed THEN now() ELSE released_at END,
    release_retry_at=now()+make_interval(mins=>least(1440,(power(2,least(release_attempts,10)))::integer)),
    release_claim=NULL,release_claim_expires_at=NULL,updated_at=now()
    WHERE id=p_did_id AND status='release_pending' AND release_claim=p_claim;
  IF NOT FOUND THEN RAISE EXCEPTION 'Release claim mismatch'; END IF;
END $$;

-- Explicit ACLs, even on installations with permissive default privileges.
DO $$ DECLARE f record; BEGIN
  FOR f IN SELECT p.oid::regprocedure sig FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname IN ('second_number_service_only','begin_second_number_purchase','capture_second_number_hold',
      'finish_second_number_purchase','fail_second_number_purchase','get_second_numbers','mark_did_message_read','set_second_number_renewal',
      'request_second_number_release','route_second_number_sms','process_second_number_renewals','claim_second_number_releases','finish_second_number_release','get_pending_second_number_orders','admin_set_second_number_policy')
  LOOP EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated,service_role',f.sig);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',f.sig); END LOOP;
END $$;
GRANT EXECUTE ON FUNCTION public.get_second_numbers(),public.mark_did_message_read(uuid),
  public.set_second_number_renewal(uuid,boolean),public.request_second_number_release(uuid),public.get_pending_second_number_orders() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_second_number_policy(jsonb) TO authenticated;
DO $$ BEGIN
  IF NOT EXISTS(SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='virtual_did_messages') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.virtual_did_messages;
  END IF;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
