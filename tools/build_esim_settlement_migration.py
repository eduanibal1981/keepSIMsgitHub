"""Build the scoped ESIM-08 migration from inspected live contract definitions."""
from pathlib import Path
import hashlib
import json

root=Path(__file__).resolve().parents[1]
e=root/'docs/reviews/esimaccess-recharge-settlement-20261028/evidence'
ops=json.loads((e/'operation.json').read_text())[0]['operation_contract']
patches=json.loads((e/'patch.json').read_text())
wallet=json.loads((e/'wallet.json').read_text())
shapes=json.loads((e/'shapes.json').read_text())
defs={x['name'].split('(')[0]:x['definition'] for x in ops['functions']}
defs.update({x['proname']:x['definition'] for x in patches})
defs['capture_wallet_hold']=next(x['definition'] for x in wallet if x['proname']=='capture_wallet_hold')
guards=[]
for x in ops['functions']:
 if x['name'].split('(')[0] in ['service_esim_claim_order','service_esim_mark_submitted','service_esim_save_issuance','request_esim_purchase']:
  guards.append((x['name'],hashlib.md5(x['definition'].encode()).hexdigest()))
for x in patches:guards.append((x['signature'],x['md5']))
for x in wallet:
 if x['proname'] in ['reserve_wallet_funds','capture_wallet_hold','release_wallet_hold','credit_wallet_for_refund']:
  guards.append((x['signature'],x['md5']))
preflight='DO $preflight$ BEGIN\n'+''.join(" IF md5(pg_get_functiondef('%s'::regprocedure))<>'%s' THEN RAISE EXCEPTION 'ESIM-08 dependency source drift'; END IF;\n"%(sig,md5) for sig,md5 in guards)+'END $preflight$;\n'
parts=['BEGIN;\nSET LOCAL lock_timeout=\'5s\';',preflight,(root/'tools/esim08-core.sql').read_text()]

def edit(name,changes):
 s=defs[name]
 for old,new in changes:
  assert s.count(old)==1,(name,old[:90],s.count(old));s=s.replace(old,new)
 parts.append(s)

edit('capture_wallet_hold',[
 ('  -- Lock hold',"  -- Use the common wallet-before-hold order.\n  PERFORM 1 FROM public.wallets WHERE id=(SELECT wallet_id FROM public.wallet_holds WHERE id=p_hold_id) FOR UPDATE;\n  -- Lock hold"),
 ('  -- Update wallet balance',"  INSERT INTO esim_private.capture_context(txid,hold_id,wallet_id)\n  SELECT txid_current(),p_hold_id,v_wallet.id WHERE EXISTS(SELECT 1 FROM public.wallet_holds h JOIN esim_private.order_runs r ON r.hold_id=h.id WHERE h.wallet_id=v_wallet.id AND h.status='active')\n  ON CONFLICT DO NOTHING;\n  -- Update wallet balance"),
 ('  RETURN v_txn_id;\nEND;',"  DELETE FROM esim_private.capture_context WHERE txid=txid_current() AND hold_id=p_hold_id;\n  RETURN v_txn_id;\nEND;")])

# The existing original-profile engine remains the issuance authority.
edit('service_esim_claim_order',[
 ("(run.state<>'prepared' OR a.new_sales_enabled)","(run.state<>'prepared' OR run.finance_kind='reserved')"),
 ("'hinted_order_ref',r.hinted_order_ref)","'hinted_order_ref',r.hinted_order_ref,'operation_kind',o.operation_kind,'has_receipt',r.receipt IS NOT NULL,\n 'supplier_profile_ref',o.catalogue_snapshot->>'supplier_profile_ref','iccid',o.catalogue_snapshot->>'iccid')")])

# Quote single-use adoption precedes expiry/gates. Later reads expose only capability.
for name in ['quote_esim_topup','check_esim_topup_quote']:
 s=defs[name];assert "'acceptance_enabled', false" in s or "'acceptance_enabled',false" in s
 s=s.replace("'acceptance_enabled', false","'acceptance_enabled',esim_private.recharge_can_accept()")
 s=s.replace("'acceptance_enabled',false","'acceptance_enabled',esim_private.recharge_can_accept()")
 if name=='quote_esim_topup':
  old='AND package_id=p_package_id AND retail_total=total AND expires_at>now() ORDER BY created_at DESC LIMIT 1;'
  assert old in s
  s=s.replace(old,"AND package_id=p_package_id AND retail_total=total AND expires_at>now() AND NOT EXISTS(SELECT 1 FROM public.esim_orders accepted WHERE accepted.recharge_quote_id=recharge_quotes.id) ORDER BY created_at DESC LIMIT 1;")
 parts.append(s)

base=defs['topup_refusal'].replace('esim_private.topup_refusal(', 'esim_private.topup_refusal_base(',1)
parts.append(base)
parts.append("""CREATE OR REPLACE FUNCTION esim_private.topup_refusal(p public.user_esims) RETURNS text
 LANGUAGE plpgsql STABLE SET search_path='' AS $$DECLARE reason text; BEGIN
 reason:=esim_private.topup_refusal_base(p); IF reason IS NOT NULL THEN RETURN reason; END IF;
 IF EXISTS(SELECT 1 FROM public.esim_orders WHERE recharge_profile_id=p.id AND status IN('pending','processing')) THEN RETURN 'UNRESOLVED_OPERATION'; END IF;
 RETURN NULL; END $$;""")

parts.append("""CREATE OR REPLACE FUNCTION public.gate_esim_order_submission() RETURNS trigger
 LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$DECLARE a esim_private.accounts; BEGIN
 SELECT * INTO STRICT a FROM esim_private.accounts WHERE account_key='primary';
 IF NEW.provider<>'esimaccess' OR (NEW.operation_kind='purchase' AND (NOT a.new_sales_enabled OR NOT a.wallet_boundary_verified))
  OR (NEW.operation_kind='fixed_recharge' AND NOT esim_private.recharge_can_accept()) THEN
  RAISE EXCEPTION 'eSIM purchases are temporarily unavailable while delivery safeguards are verified'; END IF;
 NEW.delivery_state:='queued';RETURN NEW; END $$;""")

parts.append("""CREATE OR REPLACE FUNCTION public.service_esim_mark_submitted(p_order_id uuid,p_lease uuid) RETURNS boolean
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
 IF o.operation_kind='fixed_recharge' THEN
  IF NOT esim_private.recharge_can_accept() THEN reject_code:='SUBMISSION_DISABLED'; END IF;
  SELECT * INTO STRICT q FROM esim_private.recharge_quotes WHERE id=o.recharge_quote_id;
  IF q.expires_at<=now() THEN reject_code:='QUOTE_EXPIRED'; END IF;
  IF q.context IS DISTINCT FROM esim_private.topup_context(p) OR p.user_id IS DISTINCT FROM o.user_id
   OR p.supplier_account_id IS DISTINCT FROM r.account_id OR esim_private.topup_refusal_base(p) IS NOT NULL THEN reject_code:='PROFILE_CHANGED'; END IF;
  IF EXISTS(SELECT 1 FROM public.esim_orders WHERE recharge_profile_id=p.id AND id<>o.id AND status IN('pending','processing')) THEN reject_code:='PROFILE_CHANGED'; END IF;
 ELSE
  IF NOT EXISTS(SELECT 1 FROM esim_private.accounts WHERE id=r.account_id AND new_sales_enabled AND wallet_boundary_verified) THEN reject_code:='SUBMISSION_DISABLED'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.esim_offers_cache WHERE provider=o.provider AND bundle_name=o.bundle_name AND is_active
   AND wholesale_price_usd=o.wholesale_price_usd) THEN reject_code:='PRICE_CHANGED'; END IF;
 END IF;
 IF public.resolve_esim_offer_price(o.wholesale_price_usd,o.user_id) IS DISTINCT FROM o.retail_price_usd THEN reject_code:='PRICE_CHANGED'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=o.user_id AND NOT coalesce(is_suspended,false)) THEN reject_code:='SUBMISSION_DISABLED'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.wallet_holds WHERE id=r.hold_id AND status='active' AND user_id=r.payer_id AND amount=o.total_amount_usd AND expires_at IS NULL) THEN reject_code:='SUBMISSION_DISABLED'; END IF;
 SELECT w.balance-coalesce((SELECT sum(amount) FROM public.wallet_holds WHERE wallet_id=w.id AND status='active'),0) INTO available FROM public.wallets w WHERE user_id=r.payer_id AND currency='USD';
 IF available IS NULL OR available<0 OR available::text IN('NaN','Infinity','-Infinity') THEN reject_code:='SUBMISSION_DISABLED'; END IF;
 IF reject_code IS NOT NULL THEN PERFORM public.service_esim_fail_before_submit(o.id,p_lease,reject_code);RETURN false; END IF;
 UPDATE esim_private.order_runs SET state='submitted',submitted_at=now(),updated_at=now() WHERE order_id=o.id;
 UPDATE public.esim_orders SET delivery_state='submitted' WHERE id=o.id;RETURN true;
END $$;""")

s=defs['request_esim_purchase']
s=s.replace('public.request_esim_purchase(p_offer_id text, p_quantity integer DEFAULT 1, p_device_id text DEFAULT NULL::text)',
 'public.request_esim_purchase_v2(p_offer_id text,p_quantity integer,p_device_id text,p_request_key uuid,p_reviewed_total numeric,p_expected_user uuid)')
assert 'public.request_esim_purchase_v2(' in s
s=s.replace('  v_guard jsonb;', '  v_guard jsonb;\n  existing public.esim_orders;')
needle="  IF EXISTS (SELECT 1 FROM public.profiles"
at=s.index(needle)
s=s[:at]+"""  IF p_expected_user IS DISTINCT FROM v_user_id THEN RETURN jsonb_build_object('success',false,'code','ACCOUNT_CHANGED'); END IF;
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
"""+s[at:]
s=s.replace('  v_total_cost := v_retail_price * p_quantity;', "  v_total_cost := v_retail_price * p_quantity;\n  IF v_total_cost IS DISTINCT FROM p_reviewed_total THEN RETURN jsonb_build_object('success',false,'code','PRICE_CHANGED'); END IF;")
s=s.replace('total_amount_usd, status\n  ) VALUES (','total_amount_usd, status, client_request_key\n  ) VALUES (')
s=s.replace("v_total_cost, 'pending'\n", "v_total_cost, 'pending', p_request_key\n")
a=s.index('  PERFORM public.debit_wallet_for_topup(');b=s.index('\n  );',a)+len('\n  );')
s=s[:a]+"  PERFORM esim_private.reserve_order(v_order_id);"+s[b:]
s=s.replace("SELECT COALESCE(balance, 0.00) INTO v_wallet_balance\n  FROM public.wallets WHERE user_id = v_user_id;", "SELECT (public.get_wallet_summary(v_user_id)->>'available_balance')::numeric INTO v_wallet_balance;")
assert 'PERFORM public.debit_wallet_for_topup' not in s
parts.append(s)

edit('snapshot_esim_catalogue_order', [('BEGIN\n', "BEGIN\n IF NEW.operation_kind='fixed_recharge' THEN RETURN NEW; END IF;\n")])
defs['emit_alert']=defs['emit_alert'].replace('Recharge is not available yet.','Open your eSIM to review compatible recharge options.')
edit('emit_alert', [
 ('DECLARE uid uuid;', 'DECLARE recharge_profile uuid; uid uuid;'),
 ("  target:=jsonb_build_object('route','/esim/orders/:id','id',p_order_id);", "  SELECT recharge_profile_id INTO recharge_profile FROM public.esim_orders WHERE id=p_order_id;\n  target:=CASE WHEN recharge_profile IS NULL THEN jsonb_build_object('route','/esim/orders/:id','id',p_order_id) ELSE jsonb_build_object('route','/esim/profiles/:id','id',recharge_profile) END;"),
 ("WHEN 'esim_order_completed' THEN 'Your eSIM order is ready'", "WHEN 'esim_order_completed' THEN CASE WHEN recharge_profile IS NOT NULL THEN 'Your eSIM recharge is complete' ELSE 'Your eSIM order is ready' END"),
 ("CASE WHEN p_profile_id IS NULL THEN '/esim/orders/'||p_order_id ELSE '/esim/profiles/'||p_profile_id END", "replace(target->>'route',':id',target->>'id')"),
 ])
parts.append("""CREATE OR REPLACE FUNCTION public.request_esim_purchase(p_offer_id text,p_quantity integer DEFAULT 1,p_device_id text DEFAULT NULL)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object('success',false,'code','UPDATE_REQUIRED','error','Reopen checkout in the updated app to review this purchase.');
$$;""")

s=defs['service_esim_save_issuance']
s=s.replace(' PERFORM esim_private.require_service();'," PERFORM esim_private.require_service();\n PERFORM 1 FROM public.wallets WHERE user_id=(SELECT user_id FROM public.esim_orders WHERE id=p_order_id) FOR UPDATE;",1)
s=s.replace(" IF o.user_id IS NULL OR o.provider<>'esimaccess'", " IF o.operation_kind<>'purchase' OR o.user_id IS NULL OR o.provider<>'esimaccess'",1)
needle=' UPDATE esim_private.order_runs SET provider_order_ref=p_provider_order_ref,state=CASE WHEN conflict THEN'
assert s.count(needle)==1
s=s.replace(needle,""" IF count_profiles=o.quantity AND NOT conflict THEN
  UPDATE esim_private.order_runs SET receipt=jsonb_build_object('outcome','success','source','verified_issuance',
   'transaction_id',submission_ref,'provider_order_ref',p_provider_order_ref,'profiles',count_profiles),receipt_at=now() WHERE order_id=o.id;
  PERFORM esim_private.settle_order(o.id,true);
 END IF;
"""+needle)
parts.append(s)

# Known legacy debits are adopted, never reserved or debited again. No current
# production order qualifies (the one old order belongs to eSIM Go).
parts.append("""UPDATE esim_private.order_runs r SET payer_id=o.user_id FROM public.esim_orders o WHERE o.id=r.order_id;
WITH proof AS(SELECT o.id,min(t.id::text)::uuid tx FROM public.esim_orders o JOIN public.wallet_transactions t
 ON t.reference_id='esim_'||o.id::text AND t.user_id=o.user_id AND t.type='esim_purchase_debit' AND t.status='completed'
 AND t.amount>0 AND t.amount=t.balance_before-t.balance_after GROUP BY o.id HAVING count(*)=1)
UPDATE esim_private.order_runs r SET finance_kind='legacy_debit',debit_tx_id=p.tx FROM proof p WHERE r.order_id=p.id AND r.hold_id IS NULL;""")

# Include the new eSIM ledger types without rewriting unrelated accounting rules.
view=shapes['reconciliation']
parts.append("DO $$ BEGIN IF md5(pg_get_viewdef('public.wallet_reconciliation'::regclass,true))<>'%s' THEN RAISE EXCEPTION 'Wallet reconciliation source drift'; END IF; END $$;"%hashlib.md5(view.encode()).hexdigest())
view=view.replace("'esim_purchase_debit'::text", "'esim_purchase_debit'::text, 'esim_recharge_debit'::text")
view=view.replace("'refund'::text", "'refund'::text, 'esim_purchase_refund'::text, 'esim_recharge_refund'::text")
parts.append('CREATE OR REPLACE VIEW public.wallet_reconciliation AS\n'+view)
customer_view=next(v['definition'] for v in ops['views'] if v['name']=='customer_esim_orders')
assert 'WHERE' not in customer_view.upper()
parts.append('CREATE OR REPLACE VIEW public.customer_esim_orders AS\n'+customer_view.rstrip().rstrip(';')+" WHERE operation_kind='purchase';")
parts.append("""CREATE OR REPLACE FUNCTION public.prune_esim_topup_discovery() RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN
 PERFORM esim_private.require_service();
 DELETE FROM esim_private.recharge_quotes q WHERE expires_at<now()-interval '30 days' AND NOT EXISTS(SELECT 1 FROM public.esim_orders WHERE recharge_quote_id=q.id);
 DELETE FROM esim_private.topup_cache WHERE requested_at<now()-interval '1 day'; END $$;""")

parts.append("""DO $$DECLARE r record; BEGIN
 FOR r IN SELECT p.oid::regprocedure sig,p.proname FROM pg_proc p WHERE p.pronamespace='public'::regnamespace AND
  p.proname IN('request_esim_purchase_v2','accept_esim_topup','get_esim_operation_history','admin_esim_operation_timeline','service_esim_adopt_purchase_reference','service_esim_record_topup_receipt','service_esim_settle_topup','service_esim_record_rejection','service_esim_fail_before_submit') LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',r.sig);
  EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',r.sig);
  IF r.proname IN('request_esim_purchase_v2','accept_esim_topup','get_esim_operation_history','admin_esim_operation_timeline') THEN EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated',r.sig); END IF;
 END LOOP;
 FOR r IN SELECT p.oid::regprocedure sig FROM pg_proc p WHERE p.pronamespace='esim_private'::regnamespace AND p.proname IN(
 'recharge_can_accept','require_live_owner','require_money_session','reserve_order','guard_operation_hold','guard_reserved_wallet','settle_order','topup_refusal_base') LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',r.sig);EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',r.sig);
 END LOOP;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;""")
target=list((root/'supabase/migrations').glob('*_esim_fixed_recharge_settlement.sql'));assert len(target)==1
target[0].write_text('-- Generated by tools/build_esim_settlement_migration.py; scoped, disabled financial release.\n'+'\n\n'.join(part.rstrip()+(';' if not part.rstrip().endswith(';') else '') for part in parts)+'\n')
print(target[0])
