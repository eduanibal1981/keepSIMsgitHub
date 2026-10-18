BEGIN;

-- Disabled even if an old country policy was enabled. Only explicitly budgeted
-- pilot accounts may be enrolled after provider/invoice validation.
CREATE TABLE public.second_number_purchase_gate (
  singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
  enabled boolean NOT NULL DEFAULT false,
  pilot_user_ids uuid[] NOT NULL DEFAULT '{}'
);
INSERT INTO public.second_number_purchase_gate DEFAULT VALUES;
ALTER TABLE public.second_number_purchase_gate ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.second_number_purchase_gate FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.second_number_purchase_gate TO service_role;
ALTER TABLE public.second_number_orders
  ADD COLUMN wholesale_setup_usd numeric(10,2) CHECK(wholesale_setup_usd>=0),
  ADD COLUMN supplier_checked_at timestamptz,
  ADD COLUMN quote_contract_version integer NOT NULL DEFAULT 0;
-- Existing quotes have no proven setup-cost snapshot and cannot authorize spend.
CREATE TABLE public.second_number_renewals (
  did_id uuid NOT NULL REFERENCES public.virtual_did_numbers(id),
  period_start timestamptz NOT NULL,
  user_id uuid NOT NULL REFERENCES auth.users(id),
  amount numeric(10,2) NOT NULL CHECK(amount>0),
  provider_sid text NOT NULL CHECK(length(provider_sid)>0),
  hold_id uuid REFERENCES public.wallet_holds(id),
  transaction_id uuid REFERENCES public.wallet_transactions(id),
  provider_checked_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(did_id,period_start)
);
ALTER TABLE public.second_number_renewals ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.second_number_renewals FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.second_number_renewals TO service_role;
REVOKE ALL ON public.virtual_did_numbers FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.virtual_did_numbers TO authenticated;
GRANT ALL ON public.virtual_did_numbers TO service_role;

CREATE OR REPLACE FUNCTION public.begin_second_number_purchase(p_user_id uuid,p_quote_id uuid,p_auto_renew boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE o public.second_number_orders; h uuid;
BEGIN
  PERFORM public.second_number_service_only();
  SELECT * INTO o FROM public.second_number_orders WHERE id=p_quote_id AND user_id=p_user_id FOR UPDATE;
  IF o.id IS NULL THEN RAISE EXCEPTION 'Quote unavailable'; END IF;
  IF EXISTS(SELECT 1 FROM auth.users WHERE id=p_user_id AND coalesce((raw_app_meta_data->>'is_suspended')::boolean,false)) THEN RAISE EXCEPTION 'Account unavailable'; END IF;
  IF o.state<>'quoted' THEN RETURN jsonb_build_object('submit',false,'order_id',o.id,'state',o.state); END IF;
  IF NOT EXISTS(SELECT 1 FROM public.second_number_purchase_gate WHERE enabled AND p_user_id=ANY(pilot_user_ids)) THEN
    RAISE EXCEPTION 'Second Number purchases are disabled'; END IF;
  IF o.quote_contract_version<>1 OR o.wholesale_setup_usd IS NULL OR o.supplier_checked_at IS NULL
    OR o.supplier_checked_at<now()-interval '1 minute' THEN RAISE EXCEPTION 'Fresh supplier quote required'; END IF;
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


CREATE FUNCTION public.authorize_second_number_purchase(p_user_id uuid,p_quote_id uuid,p_auto_renew boolean,
  p_supplier_monthly numeric,p_supplier_setup numeric) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE o public.second_number_orders;
BEGIN
  PERFORM public.second_number_service_only();
  SELECT * INTO o FROM public.second_number_orders WHERE id=p_quote_id AND user_id=p_user_id FOR UPDATE;
  IF o.id IS NULL THEN RAISE EXCEPTION 'Quote unavailable'; END IF;
  IF o.state='quoted' THEN
    IF p_supplier_monthly IS DISTINCT FROM o.wholesale_monthly_usd OR p_supplier_setup IS DISTINCT FROM o.wholesale_setup_usd THEN
      RAISE EXCEPTION 'Quote expired; supplier price changed'; END IF;
    UPDATE public.second_number_orders SET supplier_checked_at=now() WHERE id=o.id;
  END IF;
  RETURN public.begin_second_number_purchase(p_user_id,p_quote_id,p_auto_renew);
END $$;


CREATE OR REPLACE FUNCTION public.capture_second_number_hold(p_hold_id uuid,p_reference text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE h public.wallet_holds; w public.wallets; tx uuid; expected_user uuid; expected_amount numeric;
BEGIN
  PERFORM public.second_number_service_only();
  SELECT * INTO w FROM public.wallets WHERE id=(SELECT wallet_id FROM public.wallet_holds WHERE id=p_hold_id) FOR UPDATE;
  SELECT * INTO h FROM public.wallet_holds WHERE id=p_hold_id FOR UPDATE;
  IF h.id IS NULL OR h.order_type<>'second_number' OR h.order_reference_id IS DISTINCT FROM p_reference
    OR h.user_id IS DISTINCT FROM w.user_id OR h.currency<>'USD' OR w.currency<>'USD' THEN RAISE EXCEPTION 'Reservation mismatch'; END IF;
  SELECT o.user_id,o.monthly_fee_usd+o.setup_fee_usd INTO expected_user,expected_amount
    FROM public.second_number_orders o WHERE o.hold_id=h.id AND o.id::text=p_reference
      AND o.state IN ('submitting','provisioning','reconciliation','active');
  IF expected_user IS NULL THEN
    SELECT r.user_id,r.amount INTO expected_user,expected_amount FROM public.second_number_renewals r
      JOIN public.virtual_did_numbers d ON d.id=r.did_id
      WHERE r.hold_id=h.id AND p_reference='renew:'||r.did_id||':'||extract(epoch FROM r.period_start)::text
        AND r.user_id=d.user_id AND r.provider_sid=d.provider_sid;
  END IF;
  IF expected_user IS DISTINCT FROM h.user_id OR expected_amount IS DISTINCT FROM h.amount
    OR h.recovery_contract_version<>1 THEN RAISE EXCEPTION 'Reservation mismatch'; END IF;
  SELECT id INTO tx FROM public.wallet_transactions WHERE reference_id='hold_'||h.id AND wallet_id=w.id
    AND user_id=w.user_id AND type='did_purchase_debit' AND amount=h.amount AND status='completed';
  IF h.status='captured' AND tx IS NOT NULL THEN RETURN tx; END IF;
  IF h.status<>'active' OR NOT h.carrier_in_flight OR w.balance<h.amount THEN RAISE EXCEPTION 'Funded reservation required'; END IF;
  PERFORM public.assert_wallet_funding_integrity(w.id);
  UPDATE public.wallets SET balance=balance-h.amount,total_spent=total_spent+h.amount,updated_at=now() WHERE id=w.id;
  UPDATE public.wallet_holds SET status='captured',carrier_in_flight=false,captured_at=now(),updated_at=now() WHERE id=h.id;
  -- The installed funding trigger is the only funding-lot consumer.
  INSERT INTO public.wallet_transactions(wallet_id,user_id,type,amount,balance_before,balance_after,description,reference_id,status,metadata)
    VALUES(w.id,w.user_id,'did_purchase_debit',h.amount,w.balance,w.balance-h.amount,'Second Number subscription',
      'hold_'||h.id,'completed',jsonb_build_object('hold_id',h.id,'order_type','second_number','order_reference_id',p_reference)) RETURNING id INTO tx;
  RETURN tx;
END $$;

CREATE OR REPLACE FUNCTION public.finish_second_number_purchase(p_order_id uuid,p_provider_order_id text,p_provider_sid text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE o public.second_number_orders; d uuid;
BEGIN
  PERFORM public.second_number_service_only();
  SELECT * INTO o FROM public.second_number_orders WHERE id=p_order_id FOR UPDATE;
  IF o.id IS NULL OR nullif(p_provider_order_id,'') IS NULL OR nullif(p_provider_sid,'') IS NULL THEN RAISE EXCEPTION 'Verified carrier order required'; END IF;
  IF o.state='active' THEN
    IF o.provider_order_id IS DISTINCT FROM p_provider_order_id OR o.provider_sid IS DISTINCT FROM p_provider_sid THEN RAISE EXCEPTION 'Carrier identity mismatch'; END IF;
    RETURN o.did_id;
  END IF;
  IF o.state NOT IN ('submitting','provisioning','reconciliation') OR
    (o.provider_order_id IS NOT NULL AND o.provider_order_id<>p_provider_order_id) THEN RAISE EXCEPTION 'Order requires reconciliation'; END IF;
  IF EXISTS(SELECT 1 FROM public.second_number_orders WHERE id<>o.id AND
    (provider_order_id=p_provider_order_id OR provider_sid=p_provider_sid)) THEN RAISE EXCEPTION 'Carrier identity already bound'; END IF;
  PERFORM public.capture_second_number_hold(o.hold_id,o.id::text);
  INSERT INTO public.virtual_did_numbers(user_id,phone_number,country_code,country_name,provider,provider_sid,status,monthly_fee_usd,
    number_type,supports_sms,supports_voice,kyc_status,forward_mode,auto_renew,assigned_at,renews_at,lifecycle_managed)
    VALUES(o.user_id,o.phone_number,o.country_code,o.country_name,'telnyx',p_provider_sid,'active',o.monthly_fee_usd,
      o.number_type,true,false,o.terms->>'kyc_status','voicemail',o.auto_renew,now(),now()+interval '30 days',true) RETURNING id INTO d;
  UPDATE public.second_number_orders SET state='active',provider_order_id=p_provider_order_id,provider_sid=p_provider_sid,did_id=d,updated_at=now() WHERE id=o.id;
  RETURN d;
END $$;


CREATE OR REPLACE FUNCTION public.fail_second_number_purchase(p_order_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE o public.second_number_orders;
BEGIN
  PERFORM public.second_number_service_only();
  SELECT * INTO o FROM public.second_number_orders WHERE id=p_order_id FOR UPDATE;
  IF o.state='failed' THEN RETURN; END IF;
  IF o.state NOT IN ('submitting','provisioning','reconciliation') THEN RAISE EXCEPTION 'Order cannot fail'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.wallet_holds h JOIN public.wallets w ON w.id=h.wallet_id
    WHERE h.id=o.hold_id AND h.user_id=o.user_id AND w.user_id=o.user_id AND h.currency='USD' AND w.currency='USD'
      AND h.order_type='second_number' AND h.order_reference_id=o.id::text
      AND h.amount=o.monthly_fee_usd+o.setup_fee_usd AND h.status='active' AND h.recovery_contract_version=1) THEN
    RAISE EXCEPTION 'Reservation mismatch'; END IF;
  -- Caller must have authoritative rejection/cancellation evidence, never timeout.
  UPDATE public.wallet_holds SET carrier_in_flight=false WHERE id=o.hold_id;
  PERFORM public.release_wallet_hold(o.hold_id,'Carrier confirmed purchase failure');
  UPDATE public.second_number_orders SET state='failed',updated_at=now() WHERE id=o.id;
END $$;

CREATE UNIQUE INDEX second_number_provider_order_identity ON public.second_number_orders(provider_order_id) WHERE provider_order_id IS NOT NULL;
CREATE UNIQUE INDEX second_number_provider_resource_identity ON public.second_number_orders(provider_sid) WHERE provider_sid IS NOT NULL;


CREATE OR REPLACE FUNCTION public.process_second_number_renewals(p_limit integer DEFAULT 50) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE d public.virtual_did_numbers; n integer:=0;
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
    -- Due numbers stop serving until a trusted provider check and atomic
    -- collection succeed. Local suspension does not stop supplier MRCs.
    UPDATE public.virtual_did_numbers SET status='suspended',
      grace_expires_at=coalesce(d.grace_expires_at,d.renews_at+interval '3 days'),updated_at=now() WHERE id=d.id;
    IF d.status<>'suspended' THEN INSERT INTO public.notifications(user_id,category,title,body,source_event_key)
      VALUES(d.user_id,'system','Second Number renewal pending','Your number is paused until renewal is confirmed. Review your wallet and renewal settings.',
        'did_grace:'||d.id||':'||extract(epoch FROM d.renews_at)::text); END IF;
  END LOOP;
  RETURN n;
END $$;


-- p_period_start fences stale/concurrent provider reads. No provider purchase is
-- needed for renewal: Telnyx bills retained numbers on its own monthly cycle.
CREATE FUNCTION public.settle_second_number_renewal(p_did_id uuid,p_period_start timestamptz,p_provider_sid text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE d public.virtual_did_numbers; h uuid; tx uuid; reference text;
BEGIN
  PERFORM public.second_number_service_only();
  SELECT * INTO d FROM public.virtual_did_numbers WHERE id=p_did_id FOR UPDATE;
  IF d.id IS NULL THEN RAISE EXCEPTION 'Number unavailable'; END IF;
  IF EXISTS(SELECT 1 FROM public.second_number_renewals WHERE did_id=d.id AND period_start=p_period_start
    AND provider_sid=p_provider_sid AND transaction_id IS NOT NULL) THEN RETURN true; END IF;
  IF NOT d.lifecycle_managed OR d.provider<>'telnyx' OR d.provider_sid IS DISTINCT FROM p_provider_sid
    OR p_provider_sid IS NULL OR d.renews_at IS DISTINCT FROM p_period_start OR d.renews_at>now()
    OR d.status NOT IN ('active','suspended') OR NOT d.auto_renew
    OR d.renews_at<=now()-interval '3 days'
    OR coalesce(d.grace_expires_at,now()+interval '1 second')<=now() THEN RETURN false; END IF;
  reference:='renew:'||d.id||':'||extract(epoch FROM d.renews_at)::text;
  BEGIN
    INSERT INTO public.second_number_renewals(did_id,period_start,user_id,amount,provider_sid)
      VALUES(d.id,d.renews_at,d.user_id,d.monthly_fee_usd,d.provider_sid);
    h:=public.reserve_wallet_funds(d.user_id,d.monthly_fee_usd,'second_number',reference,'Second Number renewal',120);
    UPDATE public.second_number_renewals SET hold_id=h WHERE did_id=d.id AND period_start=d.renews_at;
    UPDATE public.wallet_holds SET carrier_in_flight=true WHERE id=h;
    tx:=public.capture_second_number_hold(h,reference);
    UPDATE public.second_number_renewals SET transaction_id=tx WHERE did_id=d.id AND period_start=d.renews_at;
    UPDATE public.virtual_did_numbers SET status='active',renews_at=d.renews_at+make_interval(days=>d.billing_period_days),
      grace_expires_at=NULL,renewal_warning_for=NULL,updated_at=now() WHERE id=d.id;
    RETURN true;
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'Insufficient available balance%' THEN RAISE; END IF;
    -- All receipt/hold/debit writes roll back together on insufficient funds.
    UPDATE public.virtual_did_numbers SET status='suspended',grace_expires_at=coalesce(d.grace_expires_at,d.renews_at+interval '3 days'),updated_at=now() WHERE id=d.id;
    RETURN false;
  END;
END $$;


CREATE OR REPLACE FUNCTION public.route_second_number_sms(p_provider text,p_provider_msg_id text,p_to text,p_from text,p_body text,p_received_at timestamptz)
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
  IF d.provider<>p_provider OR NOT d.supports_sms OR d.status<>'active' OR (d.lifecycle_managed AND d.renews_at<=now()) OR
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

CREATE OR REPLACE FUNCTION public.finish_second_number_release(p_did_id uuid,p_claim uuid,p_confirmed boolean) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  PERFORM public.second_number_service_only();
  UPDATE public.virtual_did_numbers SET status=CASE WHEN p_confirmed THEN 'released' ELSE 'release_pending' END,
    released_at=CASE WHEN p_confirmed THEN now() ELSE released_at END,
    release_retry_at=now()+make_interval(mins=>least(1440,(power(2,least(release_attempts,10)))::integer)),
    release_claim=NULL,release_claim_expires_at=NULL,updated_at=now()
    WHERE id=p_did_id AND status='release_pending' AND release_claim=p_claim AND release_claim_expires_at>now();
  IF NOT FOUND THEN RAISE EXCEPTION 'Release claim mismatch'; END IF;
END $$;


REVOKE ALL ON FUNCTION public.authorize_second_number_purchase(uuid,uuid,boolean,numeric,numeric),
  public.settle_second_number_renewal(uuid,timestamptz,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.authorize_second_number_purchase(uuid,uuid,boolean,numeric,numeric),
  public.settle_second_number_renewal(uuid,timestamptz,text) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;
