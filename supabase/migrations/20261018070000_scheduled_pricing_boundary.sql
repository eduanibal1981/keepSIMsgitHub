BEGIN;

-- Existing refill configurations have no trustworthy new authorization evidence.
-- Preserve their settings/history, pause for review, and cancel only proven
-- unsubmitted queue rows. No balances, holds or provider outcomes are rewritten.
ALTER TABLE public.scheduled_topups ADD COLUMN schedule_contract_version integer NOT NULL DEFAULT 0;
ALTER TABLE public.topup_executions ADD COLUMN schedule_contract_version integer NOT NULL DEFAULT 0;

REVOKE INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER ON public.scheduled_topups FROM PUBLIC,anon,authenticated;
DO $$ DECLARE cols text; BEGIN
 SELECT string_agg(quote_ident(attname),',') INTO cols FROM pg_attribute
 WHERE attrelid='public.scheduled_topups'::regclass AND attnum>0 AND NOT attisdropped;
 EXECUTE format('REVOKE INSERT (%s),UPDATE (%s),REFERENCES (%s) ON public.scheduled_topups FROM PUBLIC,anon,authenticated',cols,cols,cols);
END $$;
-- Replace permissive ALL policies with an explicit owner/household read policy.
DO $$ DECLARE p record; BEGIN
 FOR p IN SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename='scheduled_topups' LOOP
  EXECUTE format('DROP POLICY %I ON public.scheduled_topups',p.policyname);
 END LOOP;
END $$;
ALTER TABLE public.scheduled_topups ENABLE ROW LEVEL SECURITY;
CREATE POLICY customer_schedule_read ON public.scheduled_topups FOR SELECT TO authenticated
 USING(NOT public.is_user_suspended() AND EXISTS(SELECT 1 FROM public.sim_lines l
 WHERE l.id=sim_line_id AND l.user_id=scheduled_topups.user_id AND (l.user_id=(SELECT auth.uid()) OR EXISTS(
 SELECT 1 FROM public.household_members m WHERE m.owner_id=l.user_id AND m.member_id=(SELECT auth.uid()) AND m.invite_status='accepted'))));

CREATE FUNCTION public.assert_schedule_access(p_sim_line_id uuid) RETURNS uuid
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE owner_id uuid;
BEGIN
 IF auth.uid() IS NULL OR public.is_user_suspended() THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
 SELECT l.user_id INTO owner_id FROM public.sim_lines l WHERE l.id=p_sim_line_id AND l.status='active'
 AND (l.user_id=auth.uid() OR EXISTS(SELECT 1 FROM public.household_members m WHERE m.owner_id=l.user_id
   AND m.member_id=auth.uid() AND m.invite_status='accepted' AND m.role='manager'));
 IF owner_id IS NULL OR EXISTS(SELECT 1 FROM auth.users u WHERE u.id=owner_id
   AND coalesce((u.raw_app_meta_data->>'is_suspended')::boolean,false)) THEN
  RAISE EXCEPTION 'SIM ownership required' USING ERRCODE='42501'; END IF;
 RETURN owner_id;
END $$;
REVOKE ALL ON FUNCTION public.assert_schedule_access(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.assert_schedule_access(uuid) TO service_role;

-- One waiting occurrence per newly validated schedule, serialized on its parent.
-- A claimed/held/provider-marked operation is never cancelled or replaced here.
CREATE FUNCTION public.sync_next_schedule_occurrence(p_schedule_id uuid) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE s public.scheduled_topups; keep_id uuid; blocked boolean;
BEGIN
 SELECT * INTO s FROM public.scheduled_topups WHERE id=p_schedule_id FOR UPDATE;
 IF NOT FOUND OR s.schedule_type NOT IN ('refill_mini','refill_custom') THEN RETURN NULL; END IF;
 -- Refuse a concurrent worker claim instead of waiting while holding its parent
 -- or line lock (workers settle in execution -> wallet -> line order).
 PERFORM 1 FROM public.topup_executions e WHERE e.scheduled_topup_id=s.id
 AND e.status IN ('pending','pending_payment','awaiting_approval','awaiting_funds','processing','routing')
 ORDER BY e.id FOR UPDATE NOWAIT;
 SELECT EXISTS(SELECT 1 FROM public.topup_executions e WHERE e.scheduled_topup_id=s.id AND e.status<>'success'
   AND ((e.status IN ('pending','pending_payment','awaiting_approval','awaiting_funds') AND e.wallet_hold_id IS NOT NULL)
   OR e.status IN ('processing','routing') OR e.carrier_in_flight OR e.reloadly_transaction_id IS NOT NULL
   OR e.scheduled_refill_submission IS NOT NULL OR (e.wallet_hold_id IS NOT NULL AND EXISTS(
     SELECT 1 FROM public.wallet_holds h WHERE h.id=e.wallet_hold_id AND h.status IN ('active','captured'))))) INTO blocked;
 IF s.schedule_contract_version=1 AND s.is_active AND s.status='active' AND NOT blocked THEN
  SELECT e.id INTO keep_id FROM public.topup_executions e WHERE e.scheduled_topup_id=s.id
    AND e.status IN ('pending','pending_payment','awaiting_approval','awaiting_funds')
    AND e.wallet_hold_id IS NULL AND NOT e.carrier_in_flight AND e.reloadly_transaction_id IS NULL
    AND e.scheduled_refill_submission IS NULL AND e.schedule_contract_version=1
    AND e.user_id=s.user_id AND e.sim_line_id=s.sim_line_id AND e.execution_type=s.schedule_type
    AND e.execution_time=s.next_execution_at AND e.amount=s.amount AND e.base_cost_usd IS NOT DISTINCT FROM s.base_cost_usd
    AND e.app_fee_usd IS NOT DISTINCT FROM s.app_fee_usd AND e.offer_id IS NOT DISTINCT FROM s.offer_id
    AND e.offer_value IS NOT DISTINCT FROM s.offer_value AND e.max_authorized_usd=s.max_authorized_usd
    AND e.target_local_value IS NOT DISTINCT FROM s.target_local_value AND e.target_local_currency IS NOT DISTINCT FROM s.target_local_currency
    AND e.api_provider IS NOT DISTINCT FROM s.preferred_provider AND e.engine_version=2 AND e.intent_kind=s.intent_kind
  ORDER BY e.created_at,e.id LIMIT 1 FOR UPDATE;
 END IF;
 UPDATE public.topup_executions e SET status='cancelled',completed_at=now(),updated_at=now()
 WHERE e.scheduled_topup_id=s.id AND e.id IS DISTINCT FROM keep_id
   AND e.status IN ('pending','pending_payment','awaiting_approval','awaiting_funds')
   AND e.wallet_hold_id IS NULL AND NOT e.carrier_in_flight AND e.reloadly_transaction_id IS NULL
   AND e.scheduled_refill_submission IS NULL;
 IF s.schedule_contract_version<>1 OR NOT s.is_active OR s.status IS DISTINCT FROM 'active' OR blocked THEN RETURN NULL; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.sim_lines l WHERE l.id=s.sim_line_id AND l.user_id=s.user_id AND l.status='active') THEN
  RAISE EXCEPTION 'Schedule owner must match the active line' USING ERRCODE='42501'; END IF;
 IF keep_id IS NOT NULL THEN RETURN keep_id; END IF;
 INSERT INTO public.topup_executions(sim_line_id,user_id,scheduled_topup_id,amount,base_cost_usd,app_fee_usd,
 currency,status,execution_type,execution_time,offer_id,offer_value,payment_gateway_code,api_provider,
 target_local_value,target_local_currency,max_authorized_usd,engine_version,intent_kind,schedule_contract_version)
 VALUES(s.sim_line_id,s.user_id,s.id,s.amount,s.base_cost_usd,s.app_fee_usd,'USD','pending',s.schedule_type,
 s.next_execution_at,s.offer_id,s.offer_value,'wallet',s.preferred_provider,s.target_local_value,s.target_local_currency,
 s.max_authorized_usd,2,s.intent_kind,1) RETURNING id INTO keep_id;
 RETURN keep_id;
END $$;
REVOKE ALL ON FUNCTION public.sync_next_schedule_occurrence(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sync_next_schedule_occurrence(uuid) TO service_role;
CREATE OR REPLACE FUNCTION public.trg_fn_sync_custom_refill_queue() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN PERFORM public.sync_next_schedule_occurrence(NEW.id); RETURN NEW; END $$;

-- Install the lifecycle even on a database whose historical trigger was absent.
DROP TRIGGER IF EXISTS trg_sync_custom_refill_queue ON public.scheduled_topups;
CREATE TRIGGER trg_sync_custom_refill_queue AFTER INSERT OR UPDATE ON public.scheduled_topups
 FOR EACH ROW EXECUTE FUNCTION public.trg_fn_sync_custom_refill_queue();
UPDATE public.scheduled_topups SET is_active=false,status='paused',updated_at=now()
 WHERE schedule_type IN ('refill_mini','refill_custom');
ALTER TABLE public.scheduled_topups ALTER COLUMN schedule_contract_version SET DEFAULT 1;
CREATE UNIQUE INDEX one_validated_waiting_schedule_occurrence ON public.topup_executions(scheduled_topup_id)
 WHERE scheduled_topup_id IS NOT NULL AND schedule_contract_version=1
 AND status IN ('pending','pending_payment','awaiting_approval','awaiting_funds');

-- Shape-only invariant protects trusted triggers as well as customer RPCs.
CREATE FUNCTION public.guard_schedule_identity() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.sim_lines l WHERE l.id=NEW.sim_line_id AND l.user_id=NEW.user_id) THEN
  RAISE EXCEPTION 'Schedule owner must match line owner' USING ERRCODE='42501'; END IF;
 IF TG_OP='UPDATE' AND (NEW.user_id IS DISTINCT FROM OLD.user_id OR NEW.sim_line_id IS DISTINCT FROM OLD.sim_line_id
   OR NEW.schedule_type IS DISTINCT FROM OLD.schedule_type) THEN
  RAISE EXCEPTION 'Schedule identity cannot change' USING ERRCODE='42501'; END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.guard_schedule_identity() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER guard_schedule_identity BEFORE INSERT OR UPDATE ON public.scheduled_topups
 FOR EACH ROW EXECUTE FUNCTION public.guard_schedule_identity();

CREATE FUNCTION public.save_customer_schedule(p_sim_line_id uuid,p_schedule_type text,p_frequency_days integer,
 p_next_execution_at timestamptz,p_is_active boolean DEFAULT true,p_offer_id text DEFAULT NULL,
 p_offer_value numeric DEFAULT NULL,p_max_authorized_usd numeric DEFAULT NULL,p_schedule_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE owner_id uuid; s public.scheduled_topups; r public.carrier_rules; l public.sim_lines;
 q jsonb; offer record; c public.provider_offers_cache; freq integer; amount numeric; cost numeric; fee numeric;
 tier text; cap numeric; sid uuid; target numeric; target_currency text; provider text; ver integer;
BEGIN
 owner_id:=public.assert_schedule_access(p_sim_line_id);
 PERFORM 1 FROM public.sim_lines WHERE id=p_sim_line_id FOR UPDATE;
 SELECT * INTO l FROM public.sim_lines WHERE id=p_sim_line_id;
 IF p_schedule_type NOT IN ('notify','refill_mini','refill_custom') OR p_schedule_type IS NULL OR p_is_active IS NULL THEN
  RAISE EXCEPTION 'Invalid schedule controls' USING ERRCODE='22023'; END IF;
 IF p_schedule_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.scheduled_topups
   WHERE id=p_schedule_id AND sim_line_id=l.id AND user_id=owner_id AND schedule_type=p_schedule_type) THEN
  RAISE EXCEPTION 'Schedule ownership required' USING ERRCODE='42501'; END IF;
 SELECT * INTO s FROM public.scheduled_topups WHERE sim_line_id=l.id AND schedule_type=p_schedule_type FOR UPDATE;
 IF p_next_execution_at IS NULL OR NOT isfinite(p_next_execution_at) OR p_next_execution_at<now()-(CASE WHEN p_schedule_type='notify' THEN interval '366 days' ELSE interval '1 minute' END)
   OR p_next_execution_at>now()+interval '366 days' THEN RAISE EXCEPTION 'Invalid next occurrence' USING ERRCODE='22023'; END IF;
 freq:=p_frequency_days;
 IF freq IS NULL OR freq NOT BETWEEN 1 AND 365 THEN RAISE EXCEPTION 'Invalid schedule frequency' USING ERRCODE='22023'; END IF;
 IF p_schedule_type='notify' THEN
  -- Reminder amount is a positive display hint, never a spend authorization.
  SELECT * INTO r FROM public.carrier_rules WHERE id=l.carrier_rule_id AND carrier_id=l.carrier_id;
  amount:=greatest(coalesce(r.minimum_topup_amount,1),0.01);cost:=NULL;fee:=NULL;cap:=NULL;tier:=NULL;
 ELSE
  IF coalesce((public.resolve_line_entitlement(l.id)->>'automation_eligible')::boolean,false) IS NOT TRUE THEN
   RAISE EXCEPTION 'Paid Premium automation required' USING ERRCODE='42501'; END IF;
  SELECT * INTO r FROM public.carrier_rules WHERE id=coalesce(l.carrier_rule_id,
   (SELECT id FROM public.carrier_rules WHERE carrier_id=l.carrier_id ORDER BY created_at DESC,id LIMIT 1)) AND carrier_id=l.carrier_id;
  IF NOT FOUND OR r.activity_requirement='usage_required' OR r.minimum_topup_amount IS NULL OR r.minimum_topup_amount<=0 THEN
   RAISE EXCEPTION 'Carrier does not support automatic refills' USING ERRCODE='22023'; END IF;
  IF p_schedule_type='refill_mini' THEN
   freq:=public.refill_interval_days(r.inactivity_limit_days,r.refill_interval_days_override);
   SELECT * INTO offer FROM public.carrier_refill_offer(l.carrier_id,greatest(r.minimum_topup_amount,coalesce(r.validity_qualifying_topup_amount,0)));
   IF offer.offer_code IS NULL OR offer.is_stale THEN RAISE EXCEPTION 'Refill pricing unavailable'; END IF;
   q:=public.selected_refill_quote_internal(l.id,offer.offer_code,offer.offer_value);
  ELSE
   IF nullif(p_offer_id,'') IS NULL THEN RAISE EXCEPTION 'Select a current refill offer'; END IF;
   q:=public.selected_refill_quote_internal(l.id,p_offer_id,p_offer_value);
  END IF;
  IF freq IS NULL OR freq NOT BETWEEN 1 AND 365 THEN RAISE EXCEPTION 'Carrier cadence unavailable'; END IF;
  cost:=(q->>'wholesale_cost_usd')::numeric;amount:=(q->>'total_charge_usd')::numeric;
  fee:=round(amount-cost,2);tier:=q->>'pricing_tier';provider:=q->>'provider';
  SELECT * INTO c FROM public.provider_offers_cache WHERE api_provider=provider AND offer_id=q->>'offer_id';
  IF c.send_currency_divisor IS NULL OR c.send_currency_divisor<=0 THEN RAISE EXCEPTION 'Refill unit divisor unavailable'; END IF;
  target:=CASE WHEN c.price_type='RANGE' THEN (q->>'offer_value')::numeric/c.send_currency_divisor ELSE c.send_min/c.send_currency_divisor END;
  target_currency:=c.send_currency;
  IF c.price_type='FIXED' THEN q:=q||jsonb_build_object('offer_value',NULL);
  ELSIF (q->>'offer_value')::numeric<>trunc((q->>'offer_value')::numeric) THEN RAISE EXCEPTION 'Whole provider units required'; END IF;
  IF target IS NULL OR target<=0 OR nullif(target_currency,'') IS NULL THEN RAISE EXCEPTION 'Refill destination value unavailable'; END IF;
  cap:=p_max_authorized_usd;
  IF cap IS NULL OR cap::text IN ('NaN','Infinity','-Infinity') OR cap<>round(cap,2) OR cap<amount OR cap>1000 THEN
   RAISE EXCEPTION 'Review the current retail price and authorization limit' USING ERRCODE='22023'; END IF;
  SELECT version INTO ver FROM public.app_fee_rules WHERE appfees_item='refills' AND status='published'
   AND (effective_from IS NULL OR effective_from<=now()) AND (effective_to IS NULL OR effective_to>now()) ORDER BY version DESC LIMIT 1;
 END IF;
 INSERT INTO public.scheduled_topups(user_id,sim_line_id,amount,currency,frequency_days,next_execution_at,is_active,status,schedule_type,
 offer_id,offer_value,base_cost_usd,app_fee_usd,pricing_tier,fee_rule_version,target_local_value,target_local_currency,
 max_authorized_usd,preferred_provider,engine_version,intent_kind,schedule_contract_version)
 VALUES(owner_id,l.id,amount,'USD',freq,p_next_execution_at,p_is_active,CASE WHEN p_is_active THEN 'active' ELSE 'paused' END,p_schedule_type,
 q->>'offer_id',(q->>'offer_value')::numeric,cost,fee,tier,ver,target,target_currency,cap,provider,2,'exact_airtime',1)
 ON CONFLICT(sim_line_id,schedule_type) DO UPDATE SET amount=excluded.amount,frequency_days=excluded.frequency_days,
 next_execution_at=excluded.next_execution_at,is_active=excluded.is_active,status=excluded.status,offer_id=excluded.offer_id,
 offer_value=excluded.offer_value,base_cost_usd=excluded.base_cost_usd,app_fee_usd=excluded.app_fee_usd,pricing_tier=excluded.pricing_tier,
 fee_rule_version=excluded.fee_rule_version,target_local_value=excluded.target_local_value,target_local_currency=excluded.target_local_currency,
 max_authorized_usd=excluded.max_authorized_usd,preferred_provider=excluded.preferred_provider,engine_version=2,intent_kind='exact_airtime',
 schedule_contract_version=1,updated_at=now() RETURNING id INTO sid;
 RETURN (SELECT to_jsonb(v) FROM public.customer_scheduled_topups v WHERE id=sid);
END $$;
REVOKE ALL ON FUNCTION public.save_customer_schedule(uuid,text,integer,timestamptz,boolean,text,numeric,numeric,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.save_customer_schedule(uuid,text,integer,timestamptz,boolean,text,numeric,numeric,uuid) TO authenticated;

CREATE FUNCTION public.set_customer_schedule_active(p_schedule_id uuid,p_is_active boolean) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE s public.scheduled_topups;
BEGIN
 SELECT * INTO s FROM public.scheduled_topups WHERE id=p_schedule_id;
 PERFORM public.assert_schedule_access(s.sim_line_id);
 PERFORM 1 FROM public.sim_lines WHERE id=s.sim_line_id FOR UPDATE;
 SELECT * INTO s FROM public.scheduled_topups WHERE id=p_schedule_id FOR UPDATE;
 IF p_is_active IS NULL THEN RAISE EXCEPTION 'Invalid active state'; END IF;
 IF p_is_active AND s.schedule_type<>'notify' AND (s.schedule_contract_version<>1 OR
  coalesce((public.resolve_line_entitlement(s.sim_line_id)->>'automation_eligible')::boolean,false) IS NOT TRUE) THEN
  RAISE EXCEPTION 'Review and authorize the current refill settings' USING ERRCODE='42501'; END IF;
 UPDATE public.scheduled_topups SET is_active=p_is_active,status=CASE WHEN p_is_active THEN 'active' ELSE 'paused' END,updated_at=now() WHERE id=s.id;
 RETURN (SELECT to_jsonb(v) FROM public.customer_scheduled_topups v WHERE id=s.id);
END $$;
CREATE FUNCTION public.delete_customer_schedule(p_schedule_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE s public.scheduled_topups;
BEGIN
 SELECT * INTO s FROM public.scheduled_topups WHERE id=p_schedule_id;
 PERFORM public.assert_schedule_access(s.sim_line_id);
 PERFORM 1 FROM public.sim_lines WHERE id=s.sim_line_id FOR UPDATE;
 SELECT * INTO s FROM public.scheduled_topups WHERE id=p_schedule_id FOR UPDATE;
 -- Pause/cancel only safe waiting rows before removing the schedule. Any money
 -- or supplier marker blocks deletion so its evidence cannot be orphaned.
 UPDATE public.scheduled_topups SET is_active=false,status='paused' WHERE id=s.id;
 IF EXISTS(SELECT 1 FROM public.topup_executions e WHERE e.scheduled_topup_id=s.id AND e.status<>'success'
  AND (e.status IN ('processing','routing') OR e.carrier_in_flight OR e.reloadly_transaction_id IS NOT NULL
   OR e.scheduled_refill_submission IS NOT NULL OR e.wallet_hold_id IS NOT NULL)) THEN
  RAISE EXCEPTION 'Refill reconciliation required before deleting schedule'; END IF;
 DELETE FROM public.scheduled_topups WHERE id=s.id;
END $$;
REVOKE ALL ON FUNCTION public.set_customer_schedule_active(uuid,boolean),public.delete_customer_schedule(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.set_customer_schedule_active(uuid,boolean),public.delete_customer_schedule(uuid) TO authenticated;

-- Source-compatible tombstone: no caller can resurrect the yearly batch queue.
CREATE OR REPLACE FUNCTION public.queue_premium_refill_executions(p_sim_line_id uuid,p_scheduled_topup_id uuid,
 p_plan_expires_at timestamptz DEFAULT NULL,p_start_at timestamptz DEFAULT now()) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN RAISE EXCEPTION 'Legacy refill queue retired; use validated schedule settings' USING ERRCODE='0A000'; END $$;
REVOKE ALL ON FUNCTION public.queue_premium_refill_executions(uuid,uuid,timestamptz,timestamptz) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION "public"."update_sim_line_last_topup_at"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_freq INTEGER;
    v_mini_freq INTEGER;
BEGIN
    IF NEW.status = 'success' AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'success') THEN
        -- 1. Update sim_lines last_topup_at
        UPDATE public.sim_lines
        SET last_topup_at = COALESCE(NEW.completed_at, now()),
            updated_at = now()
        WHERE id = NEW.sim_line_id;

        -- 2. Advance parent schedule (trg_fn_sync_custom_refill_queue creates the next clean pending occurrence)
        IF NEW.execution_type IN ('refill_custom', 'refill_mini') AND NEW.scheduled_topup_id IS NOT NULL THEN
            SELECT frequency_days INTO v_freq
            FROM public.scheduled_topups
            WHERE id = NEW.scheduled_topup_id
            AND is_active = true;

            IF v_freq IS NOT NULL AND v_freq > 0 THEN
                UPDATE public.scheduled_topups
                SET next_execution_at = COALESCE(NEW.completed_at, now()) + (v_freq || ' days')::interval,
                    last_execution_at = COALESCE(NEW.completed_at, now()),
                    updated_at = now()
                WHERE id = NEW.scheduled_topup_id;
            END IF;
        END IF;

        -- 3. Cross-Flow Protection Coordination:
        -- If this recharge was a custom refill, instant refill, or manual topup,
        -- it successfully extended line validity. If this line has an active refill_mini
        -- schedule, push its next_execution_at out by its frequency window so the customer
        -- is not prematurely billed for an unneeded mini keep-alive refill.
        IF NEW.execution_type IN ('refill_custom', 'refill_instant', 'manual') OR NEW.execution_type IS NULL THEN
            SELECT frequency_days INTO v_mini_freq
            FROM public.scheduled_topups
            WHERE sim_line_id = NEW.sim_line_id
              AND schedule_type = 'refill_mini'
              AND is_active = true
            LIMIT 1;

            IF v_mini_freq IS NOT NULL AND v_mini_freq > 0 THEN
                UPDATE public.scheduled_topups
                SET next_execution_at = COALESCE(NEW.completed_at, now()) + (v_mini_freq || ' days')::interval,
                    updated_at = now()
                WHERE sim_line_id = NEW.sim_line_id
                  AND schedule_type = 'refill_mini'
                  AND is_active = true;
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trigger_update_sim_line_last_topup ON public.topup_executions;
CREATE TRIGGER trigger_update_sim_line_last_topup AFTER INSERT OR UPDATE OF status ON public.topup_executions
 FOR EACH ROW EXECUTE FUNCTION public.update_sim_line_last_topup_at();

-- Schedule initialization after create/upgrade never queues a paid year. The
-- trusted setup finalizer already saved the reviewed future authorization. For
-- older paths lacking that evidence, retain a paused configuration for review.
CREATE FUNCTION public.initialize_line_schedules(p_sim_line_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE owner_id uuid; l public.sim_lines; r public.carrier_rules; s public.scheduled_topups;
 freq integer; sid uuid; needs_review boolean:=false;
BEGIN
 owner_id:=public.assert_schedule_access(p_sim_line_id);
 SELECT * INTO l FROM public.sim_lines WHERE id=p_sim_line_id FOR UPDATE;
 SELECT * INTO r FROM public.carrier_rules WHERE id=coalesce(l.carrier_rule_id,
 (SELECT id FROM public.carrier_rules WHERE carrier_id=l.carrier_id ORDER BY created_at DESC,id LIMIT 1)) AND carrier_id=l.carrier_id;
 freq:=public.refill_interval_days(r.inactivity_limit_days,r.refill_interval_days_override);
 IF freq IS NULL OR freq NOT BETWEEN 1 AND 365 THEN freq:=30; END IF;
 INSERT INTO public.scheduled_topups(user_id,sim_line_id,amount,currency,frequency_days,next_execution_at,is_active,status,schedule_type)
 VALUES(owner_id,l.id,greatest(coalesce(r.minimum_topup_amount,1),0.01),'USD',freq,now()+make_interval(days=>freq),true,'active','notify')
 ON CONFLICT(sim_line_id,schedule_type) DO NOTHING;
 IF lower(l.plan_type)='premium' THEN
  SELECT * INTO s FROM public.scheduled_topups WHERE sim_line_id=l.id AND schedule_type='refill_mini' FOR UPDATE;
  IF NOT FOUND THEN
   INSERT INTO public.scheduled_topups(user_id,sim_line_id,amount,currency,frequency_days,next_execution_at,is_active,status,
    schedule_type,engine_version,intent_kind,schedule_contract_version)
   VALUES(owner_id,l.id,greatest(coalesce(r.minimum_topup_amount,1),0.01),'USD',freq,now()+make_interval(days=>freq),false,'paused',
    'refill_mini',2,'exact_airtime',0) RETURNING * INTO s;
  END IF;
  needs_review:=s.schedule_contract_version<>1 OR NOT s.is_active OR
   coalesce((public.resolve_line_entitlement(l.id)->>'automation_eligible')::boolean,false) IS NOT TRUE;
  IF NOT needs_review THEN PERFORM public.sync_next_schedule_occurrence(s.id); END IF;
 END IF;
 RETURN jsonb_build_object('success',true,'needs_authorization',needs_review);
END $$;
REVOKE ALL ON FUNCTION public.initialize_line_schedules(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.initialize_line_schedules(uuid) TO authenticated;

-- Date controls move the parent, never an independent member of a yearly batch.
CREATE OR REPLACE FUNCTION public.reschedule_mini_refill(p_sim_line_id uuid,p_new_date timestamptz) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE s public.scheduled_topups;
BEGIN
 PERFORM public.assert_schedule_access(p_sim_line_id);
 PERFORM 1 FROM public.sim_lines WHERE id=p_sim_line_id FOR UPDATE;
 SELECT * INTO s FROM public.scheduled_topups WHERE sim_line_id=p_sim_line_id AND schedule_type='refill_mini' FOR UPDATE;
 IF s.id IS NULL OR s.schedule_contract_version<>1 THEN RAISE EXCEPTION 'Review and authorize the refill settings'; END IF;
 IF p_new_date IS NULL OR NOT isfinite(p_new_date) OR p_new_date<now()-interval '1 minute' OR p_new_date>now()+interval '366 days' THEN
  RAISE EXCEPTION 'Invalid next occurrence' USING ERRCODE='22023'; END IF;
 UPDATE public.scheduled_topups SET next_execution_at=p_new_date,updated_at=now() WHERE id=s.id;
END $$;
CREATE OR REPLACE FUNCTION public.reset_mini_refill_to_default(p_sim_line_id uuid) RETURNS timestamptz
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE s public.scheduled_topups; anchor timestamptz; next_at timestamptz;
BEGIN
 PERFORM public.assert_schedule_access(p_sim_line_id);
 SELECT last_topup_at INTO anchor FROM public.sim_lines WHERE id=p_sim_line_id FOR UPDATE;
 SELECT * INTO s FROM public.scheduled_topups WHERE sim_line_id=p_sim_line_id AND schedule_type='refill_mini' FOR UPDATE;
 IF s.id IS NULL THEN RAISE EXCEPTION 'No automatic refill schedule'; END IF;
 next_at:=greatest(now(),coalesce(anchor,now())+make_interval(days=>s.frequency_days));
 PERFORM public.reschedule_mini_refill(p_sim_line_id,next_at);
 RETURN next_at;
END $$;
CREATE OR REPLACE FUNCTION public.update_mini_refill_dates(p_sim_line_id uuid,p_updates jsonb) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE item record; line_id uuid;
BEGIN
 PERFORM public.assert_schedule_access(p_sim_line_id);
 IF p_updates IS NULL OR jsonb_typeof(p_updates)<>'object' OR (SELECT count(*) FROM jsonb_object_keys(p_updates))<>1 THEN
  RAISE EXCEPTION 'Only the next refill occurrence may be moved' USING ERRCODE='22023'; END IF;
 SELECT key,value INTO item FROM jsonb_each_text(p_updates);
 SELECT e.sim_line_id INTO line_id FROM public.topup_executions e WHERE e.id=item.key::uuid
  AND e.sim_line_id=p_sim_line_id AND e.execution_type='refill_mini' AND e.status='pending'
  AND e.schedule_contract_version=1 AND e.wallet_hold_id IS NULL AND NOT e.carrier_in_flight
  AND e.reloadly_transaction_id IS NULL AND e.scheduled_refill_submission IS NULL;
 IF line_id IS NULL THEN RAISE EXCEPTION 'Current refill occurrence required' USING ERRCODE='42501'; END IF;
 PERFORM public.reschedule_mini_refill(p_sim_line_id,item.value::timestamptz);
 RETURN 1;
END $$;
REVOKE ALL ON FUNCTION public.reschedule_mini_refill(uuid,timestamptz),public.reset_mini_refill_to_default(uuid),
 public.update_mini_refill_dates(uuid,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.reschedule_mini_refill(uuid,timestamptz),public.reset_mini_refill_to_default(uuid),
 public.update_mini_refill_dates(uuid,jsonb) TO authenticated;
-- The quote-bound approval API stays supported; the older unbound ceiling API
-- must not become a route around validated schedule writes.
REVOKE ALL ON FUNCTION public.approve_refill_execution(uuid,numeric) FROM PUBLIC,anon,authenticated;

CREATE VIEW public.admin_internal_scheduled_topups WITH(security_barrier=true,security_invoker=false) AS
 SELECT s.* FROM public.scheduled_topups s WHERE (SELECT public.authorize_admin_catalogue_read());
REVOKE ALL ON public.admin_internal_scheduled_topups FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.admin_internal_scheduled_topups TO authenticated;

-- Claims exclude old/unreviewed rows even if a customer later reauthorizes
-- the same parent. Existing held/provider-marked rows require reconciliation.
CREATE OR REPLACE FUNCTION public.claim_due_executions(p_execution_type varchar,p_limit integer)
RETURNS SETOF public.topup_executions LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
 IF p_execution_type NOT IN ('refill_mini','refill_custom') THEN RAISE EXCEPTION 'Unsupported scheduled execution type'; END IF;
 RETURN QUERY WITH candidates AS (
  SELECT e.id FROM public.topup_executions e
  JOIN public.scheduled_topups s ON s.id=e.scheduled_topup_id AND s.sim_line_id=e.sim_line_id AND s.user_id=e.user_id
  JOIN public.sim_lines l ON l.id=e.sim_line_id AND l.user_id=e.user_id AND l.status='active'
  WHERE e.status='pending' AND e.execution_type=p_execution_type AND e.execution_time<=now()
   AND e.schedule_contract_version=1 AND s.schedule_contract_version=1 AND s.is_active AND s.status='active'
   AND NOT e.carrier_in_flight AND e.scheduled_refill_submission IS NULL AND e.reloadly_transaction_id IS NULL
   AND NOT EXISTS(SELECT 1 FROM public.topup_executions busy WHERE busy.sim_line_id=e.sim_line_id AND busy.status IN ('processing','routing'))
   AND pg_try_advisory_xact_lock(hashtext('sim_line_'||e.sim_line_id::text))
  ORDER BY e.execution_time,e.id LIMIT least(greatest(coalesce(p_limit,10),1),100)
  FOR UPDATE OF e SKIP LOCKED
 ) UPDATE public.topup_executions e SET status='processing',processing_since=now(),pre_processing_status='pending'
 FROM candidates c WHERE e.id=c.id RETURNING e.*;
END $$;
REVOKE ALL ON FUNCTION public.claim_due_executions(varchar,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.claim_due_executions(varchar,integer) TO service_role;

-- Preserve Task 18's funded setup capture contract. A newly reviewed initial
-- delivery also revalidates an existing paused schedule on the conflict path.
CREATE OR REPLACE FUNCTION public.capture_sim_setup_holds(
  p_order_id UUID,
  p_provider_tx_id TEXT DEFAULT NULL::TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_order            RECORD;
  v_line_id          UUID;
  v_interval_days    INTEGER := 30;
  v_rule             RECORD;
  v_notify_amount    NUMERIC := 1.00;
  v_execution        RECORD;
  v_base_cost        NUMERIC := NULL;
  v_app_fee          NUMERIC := NULL;
  v_refill_amount    NUMERIC := NULL;
  v_offer_id         TEXT := NULL;
  v_offer_value      BIGINT := NULL;
  v_provider         TEXT := NULL;
  v_intent_kind      TEXT := 'exact_airtime';
  v_target_local_val NUMERIC := NULL;
  v_target_local_cur TEXT := NULL;
  v_fee_rule_ver     INTEGER := NULL;
BEGIN
  SELECT * INTO v_order
  FROM public.sim_setup_orders
  WHERE id = p_order_id FOR UPDATE;

  IF v_order.id IS NULL THEN
    RAISE EXCEPTION 'Setup order not found: %', p_order_id;
  END IF;

  PERFORM 1 FROM public.sim_lines WHERE id=v_order.sim_line_id AND user_id=v_order.user_id
    AND phone_number=v_order.phone_number FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Owned matching line required'; END IF;
  PERFORM public.assert_setup_hold_bindings(v_order.id);
  IF v_order.plan='standard' AND (v_order.first_refill_hold_id IS NOT NULL OR v_order.first_refill_cost_usd<>0) THEN
    RAISE EXCEPTION 'Standard setup must not include a refill reservation'; END IF;
  IF v_order.status = 'active' THEN
    RETURN jsonb_build_object('success', true, 'status', 'active', 'already_captured', true);
  END IF;

  IF v_order.status NOT IN ('reserved','dispatching') OR v_order.plan NOT IN ('standard','premium') THEN
    RAISE EXCEPTION 'Invalid setup capture state';
  END IF;
  PERFORM 1 FROM public.sim_lines WHERE id=v_order.sim_line_id
    AND user_id=v_order.user_id AND phone_number=v_order.phone_number FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Owned matching line required'; END IF;
  IF v_order.annual_fee_usd>0 AND NOT EXISTS (
    SELECT 1 FROM public.wallet_holds WHERE id=v_order.annual_fee_hold_id
      AND user_id=v_order.user_id AND amount=v_order.annual_fee_usd
      AND status IN ('active','captured') AND order_type='plan_fee'
      AND order_reference_id IN ('setup_fee_'||v_order.id::text,'std_fallback_'||v_order.id::text)
      AND currency='USD' AND wallet_id=(SELECT id FROM public.wallets WHERE user_id=v_order.user_id AND currency='USD')
  ) THEN RAISE EXCEPTION 'Annual fee reservation required'; END IF;
  IF v_order.plan='premium' THEN
    SELECT * INTO v_execution FROM public.topup_executions
      WHERE wallet_hold_id=v_order.first_refill_hold_id AND user_id=v_order.user_id
        AND sim_line_id=v_order.sim_line_id AND status='success'
        AND reloadly_transaction_id IS NOT NULL ORDER BY created_at DESC LIMIT 1;
    IF v_execution.id IS NULL THEN RAISE EXCEPTION 'Confirmed initial delivery required'; END IF;
    PERFORM public.assert_instant_refill_reservation(v_execution.id,v_order.first_refill_hold_id);
    IF NOT EXISTS(SELECT 1 FROM public.wallet_holds h JOIN public.wallet_transactions t
      ON t.reference_id='hold_'||h.id::text WHERE h.id=v_order.first_refill_hold_id AND h.status='captured'
      AND t.type='topup_debit' AND t.status='completed' AND t.amount=v_order.first_refill_cost_usd
      AND t.wallet_id=h.wallet_id AND t.user_id=v_order.user_id
      AND t.metadata->>'execution_id'=v_execution.id::text
      AND t.metadata->>'provider_tx_id'=v_execution.reloadly_transaction_id) THEN
      RAISE EXCEPTION 'Settled initial delivery receipt required'; END IF;
    p_provider_tx_id:=v_execution.reloadly_transaction_id;
    IF NOT EXISTS (SELECT 1 FROM public.wallet_holds WHERE id=v_order.first_refill_hold_id
      AND user_id=v_order.user_id AND amount=v_order.first_refill_cost_usd
      AND status IN ('active','captured')) THEN RAISE EXCEPTION 'Refill reservation required'; END IF;
  END IF;

  -- 1. Capture annual fee hold
  IF v_order.annual_fee_hold_id IS NOT NULL THEN
    PERFORM public.capture_wallet_hold(
      v_order.annual_fee_hold_id,
      'plan_fee_debit',
      'Annual Protection Fee (' || v_order.plan || ')',
      jsonb_build_object('setup_order_id', p_order_id, 'sim_line_id',v_order.sim_line_id, 'plan', v_order.plan, 'order_type', 'plan_fee')
    );
  END IF;

  -- 2. Capture initial refill hold
  IF v_order.first_refill_hold_id IS NOT NULL THEN
    PERFORM public.capture_wallet_hold(
      v_order.first_refill_hold_id,
      'topup_debit',
      'Initial SIM Recharge (' || v_order.phone_number || ')',
      jsonb_build_object('setup_order_id', p_order_id, 'provider_tx_id', p_provider_tx_id, 'order_type', 'setup_refill')
    );
  END IF;

  v_line_id := v_order.sim_line_id;
  IF v_line_id IS NULL THEN
    -- Resilient fallback: link matching SIM line if user already created it
    SELECT id INTO v_line_id
    FROM public.sim_lines
    WHERE user_id = v_order.user_id AND phone_number = v_order.phone_number
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_line_id IS NOT NULL THEN
      UPDATE public.sim_setup_orders
      SET sim_line_id = v_line_id, updated_at = now()
      WHERE id = p_order_id;
    ELSE
      RAISE EXCEPTION 'Cannot activate setup order without an associated sim_line_id: %', p_order_id;
    END IF;
  END IF;

  IF v_order.plan='standard' THEN
    UPDATE public.scheduled_topups SET is_active=false,status='paused',updated_at=now()
      WHERE sim_line_id=v_line_id AND schedule_type<>'notify';
  END IF;
  -- 3. Activate SIM Line with valid carrier_status ('active')
  UPDATE public.sim_lines
  SET status = 'active',
      plan_type = v_order.plan,
      protection_tier = CASE WHEN v_order.plan = 'free' THEN 'basic' ELSE v_order.plan END,
      plan_expires_at = now() + INTERVAL '365 days',
      last_topup_at = CASE WHEN v_order.plan = 'premium' THEN now() ELSE last_topup_at END,
      updated_at = now()
  WHERE id = v_line_id;

  -- 4. Record plan payment with EXACT column names
  IF v_order.annual_fee_usd > 0 THEN
    INSERT INTO public.plan_payments (
      user_id, sim_line_id, capture_id, order_id, kind, gross_usd, net_usd,
      paypal_fee_usd, metadata, created_at
    ) VALUES (
      v_order.user_id,
      v_line_id,
      COALESCE(v_order.annual_fee_hold_id::text, 'setup_' || p_order_id::text),
      p_order_id::text,
      'plan',
      v_order.annual_fee_usd,
      v_order.annual_fee_usd,
      0.00,
      jsonb_build_object('billing_model', 'pay_per_refill', 'plan', v_order.plan, 'setup_order_id', p_order_id),
      now()
    );
  END IF;

  IF v_order.plan IN ('standard','premium') AND v_order.annual_fee_usd=0 THEN
    IF v_order.pricing_snapshot IS NULL OR (v_order.pricing_snapshot->>'annual_fee_usd')::numeric IS DISTINCT FROM 0 THEN
      RAISE EXCEPTION 'Zero fee requires an accepted server price'; END IF;
    INSERT INTO public.line_plan_grants(sim_line_id,user_id,plan,source,source_key,credit_usd,expires_at,reason)
      VALUES(v_line_id,v_order.user_id,v_order.plan,'promotion','setup:'||v_order.id,0,
        now()+interval '365 days','Accepted server-priced zero membership fee') ON CONFLICT(source_key) DO NOTHING;
  END IF;

  -- 5. Calculate cadence and schedule next occurrences
  IF v_order.carrier_rule_id IS NOT NULL THEN
    SELECT * INTO v_rule FROM public.carrier_rules WHERE id = v_order.carrier_rule_id;
  ELSE
    SELECT cr.* INTO v_rule
    FROM public.sim_lines sl
    JOIN public.carrier_rules cr ON cr.id = sl.carrier_rule_id OR cr.carrier_id = sl.carrier_id
    WHERE sl.id = v_line_id
    LIMIT 1;
  END IF;

  IF v_rule.id IS NOT NULL THEN
    v_interval_days := public.refill_interval_days(v_rule.inactivity_limit_days, v_rule.refill_interval_days_override);
    IF v_interval_days IS NULL OR v_interval_days < 1 THEN
      v_interval_days := 30;
    END IF;

    -- Resolve valid positive notify amount
    v_notify_amount := COALESCE(
      NULLIF(v_order.first_refill_cost_usd, 0),
      NULLIF(v_rule.minimum_topup_amount, 0),
      NULLIF(v_rule.recommended_topup_amount, 0),
      1.00
    );

    -- 5a. Always create 'notify' schedule for user alert reminders
    INSERT INTO public.scheduled_topups (
      user_id, sim_line_id, amount, currency, frequency_days,
      next_execution_at, is_active, status, schedule_type
    ) VALUES (
      v_order.user_id,
      v_line_id,
      v_notify_amount,
      'USD',
      v_interval_days,
      now() + (v_interval_days || ' days')::interval,
      true,
      'active',
      'notify'
    )
    ON CONFLICT (sim_line_id, schedule_type)
    DO UPDATE SET
      amount = EXCLUDED.amount,
      frequency_days = EXCLUDED.frequency_days,
      next_execution_at = EXCLUDED.next_execution_at,
      is_active = true,
      status = 'active',
      updated_at = now();

    -- 5b. For Premium lines, look up execution snapshot to establish a coherent pricing contract
    IF v_order.plan = 'premium' THEN
      SELECT * INTO v_execution
      FROM public.topup_executions
      WHERE wallet_hold_id = v_order.first_refill_hold_id
      ORDER BY created_at DESC
      LIMIT 1;

      IF v_execution.id IS NOT NULL THEN
        v_offer_id := v_execution.offer_id;
        v_offer_value := v_execution.offer_value;
        v_provider := v_execution.api_provider;
        v_base_cost := v_execution.base_cost_usd;
        v_app_fee := COALESCE(
          v_execution.app_fee_usd,
          round(v_order.first_refill_cost_usd - COALESCE(v_execution.base_cost_usd, 0), 2)
        );
        v_refill_amount := v_order.first_refill_cost_usd;
        v_intent_kind := COALESCE(v_execution.intent_kind, 'exact_airtime');
        v_target_local_val := v_execution.target_local_value;
        v_target_local_cur := v_execution.target_local_currency;
      ELSE
        v_offer_id := v_rule.offer_id;
        v_offer_value := v_rule.offer_value;
        v_refill_amount := COALESCE(NULLIF(v_order.first_refill_cost_usd, 0), v_rule.minimum_topup_amount, 1.00);
      END IF;

      -- Resolve active fee rule version
      SELECT version INTO v_fee_rule_ver
      FROM public.app_fee_rules
      WHERE appfees_item = 'refills'
      ORDER BY (status = 'published') DESC, version DESC
      LIMIT 1;

      -- The older initial-delivery snapshot may have a missing/raw native
      -- target. Establish the future intent in the same major-currency units
      -- used by validated saves and workers, from its bound provider/SKU.
      SELECT CASE WHEN c.price_type='FIXED' THEN c.send_min/c.send_currency_divisor
                  WHEN c.price_type='RANGE' THEN v_offer_value::numeric/c.send_currency_divisor END,
             c.send_currency, CASE WHEN c.price_type='FIXED' THEN NULL ELSE v_offer_value END
      INTO v_target_local_val,v_target_local_cur,v_offer_value
      FROM public.provider_offers_cache c WHERE c.api_provider=v_provider AND c.offer_id=v_offer_id
        AND c.send_currency_divisor>0;
      IF NOT FOUND OR v_target_local_val IS NULL OR v_target_local_val<=0 OR nullif(v_target_local_cur,'') IS NULL THEN
        RAISE EXCEPTION 'Future refill target unavailable; review the current catalogue before completing setup';
      END IF;

      INSERT INTO public.scheduled_topups (
        user_id, sim_line_id, amount, base_cost_usd, app_fee_usd, max_authorized_usd,
        currency, frequency_days, next_execution_at, is_active, status, schedule_type,
        offer_id, offer_value, preferred_provider, pricing_tier, intent_kind,
        target_local_value, target_local_currency, engine_version, fee_rule_version, schedule_contract_version
      ) VALUES (
        v_order.user_id,
        v_line_id,
        v_refill_amount,
        v_base_cost,
        v_app_fee,
        v_refill_amount,
        'USD',
        v_interval_days,
        now() + (v_interval_days || ' days')::interval,
        true,
        'active',
        'refill_mini',
        v_offer_id,
        v_offer_value,
        v_provider,
        'premium',
        v_intent_kind,
        v_target_local_val,
        v_target_local_cur,
        2,
        COALESCE(v_fee_rule_ver, 1),
        1
      )
      ON CONFLICT (sim_line_id, schedule_type)
      DO UPDATE SET
        amount = EXCLUDED.amount,
        base_cost_usd = EXCLUDED.base_cost_usd,
        app_fee_usd = EXCLUDED.app_fee_usd,
        max_authorized_usd = EXCLUDED.max_authorized_usd,
        currency = EXCLUDED.currency,
        frequency_days = EXCLUDED.frequency_days,
        next_execution_at = EXCLUDED.next_execution_at,
        is_active = true,
        status = 'active',
        offer_id = EXCLUDED.offer_id,
        offer_value = EXCLUDED.offer_value,
        preferred_provider = EXCLUDED.preferred_provider,
        pricing_tier = EXCLUDED.pricing_tier,
        intent_kind = EXCLUDED.intent_kind,
        target_local_value = EXCLUDED.target_local_value,
        target_local_currency = EXCLUDED.target_local_currency,
        engine_version = EXCLUDED.engine_version,
        fee_rule_version = EXCLUDED.fee_rule_version,
        schedule_contract_version = 1,
        updated_at = now();
    END IF;
  END IF;

  UPDATE public.sim_setup_orders
  SET status = 'active',
      provider_tx_id = COALESCE(p_provider_tx_id, provider_tx_id),
      updated_at = now()
  WHERE id = p_order_id;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'active',
    'sim_line_id', v_line_id,
    'plan', v_order.plan
  );
END;
$function$;
REVOKE ALL ON FUNCTION public.capture_sim_setup_holds(uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.capture_sim_setup_holds(uuid,text) TO service_role;

-- Deliberately no supplier purchase, hold release, or yearly prepayment claim.
NOTIFY pgrst,'reload schema';
COMMIT;
