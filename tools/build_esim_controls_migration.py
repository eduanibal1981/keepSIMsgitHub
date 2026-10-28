"""Build a scoped forward migration from inspected live dependencies."""
from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
deps=json.loads((root/'docs/reviews/esimaccess-controls-automation-20261028/evidence/dependencies.json').read_text())
defs={x['proname']:x['definition'] for x in deps}
out=next((root/'supabase/migrations').glob('*_esim_controls_automation.sql'))
parts=["BEGIN;\nSET LOCAL lock_timeout='5s';"]
parts.append('DO $preflight$ BEGIN\n'+''.join(" IF md5(pg_get_functiondef('%s.%s(%s)'::regprocedure))<>'%s' THEN RAISE EXCEPTION 'Dependency drift: %s'; END IF;\n"%(x['nspname'],x['proname'],', '.join(a.strip().split(' ',1)[1] for a in x.get('args','').split(',') if a.strip()),x['md5'],x['proname']) for x in deps if x.get('args') is not None)+'END $preflight$;')
# Table definitions precede executable functions that use their rowtypes.
controls=(root/'tools/esim-controls-core.sql').read_text()
auto=(root/'tools/esim-automation-core.sql').read_text()
idx=auto.index('CREATE FUNCTION')
parts += [auto[:idx],controls,auto[idx:]]
# Private entry points reuse the reviewed manual quote/acceptance implementation.
# The caller is either an owner-checked public RPC or service evaluator with
# a locked, versioned, explicit consent. No JWT impersonation is performed.
s=defs['accept_esim_topup'].replace('public.accept_esim_topup(p_quote_id','esim_private.accept_recharge(u uuid, p_quote_id').replace('DECLARE u uuid:=auth.uid();','DECLARE').replace('PERFORM esim_private.require_money_session(u);','PERFORM esim_private.require_live_owner(u);')
parts.append(s+';')
parts.append("CREATE OR REPLACE FUNCTION public.accept_esim_topup(p_quote_id uuid,p_acceptance_key uuid,p_device_id text DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN PERFORM esim_private.require_money_session(auth.uid());RETURN esim_private.accept_recharge(auth.uid(),p_quote_id,p_acceptance_key,p_device_id);END $$;")
for name,new in [('quote_esim_topup','quote_auto_fixed'),('quote_esim_daily_extension','quote_auto_daily')]:
 s=defs[name].replace('public.'+name+'(p_profile_id','esim_private.'+new+'(u uuid, p_profile_id').replace('DECLARE u uuid:=auth.uid();','DECLARE')
 parts.append(s+';')
s=defs['topup_refusal'].replace(' reason:=esim_private.topup_refusal_base(p);'," IF esim_private.control_pending(p.id) THEN RETURN 'UNRESOLVED_OPERATION'; END IF;\n reason:=esim_private.topup_refusal_base(p);")
assert s!=defs['topup_refusal'];parts.append(s+';')
s=defs['service_esim_mark_submitted']
a=' IF reject_code IS NOT NULL THEN'
assert s.count(a)==1
s=s.replace(a," IF o.recharge_profile_id IS NOT NULL AND esim_private.control_pending(o.recharge_profile_id) THEN reject_code:='PROFILE_CHANGED'; END IF;\n IF EXISTS(SELECT 1 FROM esim_private.automation_orders WHERE order_id=o.id) AND NOT EXISTS(\n SELECT 1 FROM esim_private.automation_orders x JOIN esim_private.automation_consents c ON c.profile_id=x.profile_id JOIN esim_private.accounts a ON a.id=r.account_id\n WHERE x.order_id=o.id AND c.enabled AND c.revision=x.consent_revision AND c.owner_id=o.user_id AND c.payer_id=r.payer_id\n AND (c.ends_at IS NULL OR c.ends_at>now()) AND a.automation_enabled AND o.total_amount_usd<=c.max_charge AND o.total_amount_usd<=c.reviewed_charge\n AND esim_private.automation_exposure(c.profile_id)<=c.monthly_cap) THEN reject_code:='SUBMISSION_DISABLED'; END IF;\n"+a)
parts.append(s+';')
# Queue automatic refresh/discovery ahead of evaluation as a separate statement
# in the worker, so profile_work is never locked behind a profile financial lock.
parts.append("""CREATE FUNCTION public.service_esim_prepare_automation() RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM esim_private.require_service();
 INSERT INTO esim_private.profile_work(profile_id,next_check_at,requested_at)
 SELECT p.id,now(),now() FROM public.user_esims p JOIN esim_private.automation_consents c ON c.profile_id=p.id JOIN esim_private.accounts a ON a.id=p.supplier_account_id
 WHERE c.enabled AND a.automation_enabled AND p.profile_state IN('issued','active') AND (p.last_observation_at IS NULL OR p.last_observation_at<now()-interval '15 minutes' OR (c.trigger_kind='fixed_low_data' AND (p.usage_observed_at IS NULL OR p.usage_observed_at<now()-interval '15 minutes')))
 ON CONFLICT(profile_id) DO UPDATE SET next_check_at=least(profile_work.next_check_at,now()),requested_at=now();
 INSERT INTO esim_private.topup_cache(profile_id,owner_id,account_id,context,status,requested_at)
 SELECT p.id,p.user_id,p.supplier_account_id,esim_private.topup_context(p),'pending',now() FROM public.user_esims p JOIN esim_private.automation_consents c ON c.profile_id=p.id JOIN esim_private.accounts a ON a.id=p.supplier_account_id
 WHERE c.enabled AND a.automation_enabled AND p.profile_state IN('issued','active')
 ON CONFLICT(profile_id) DO UPDATE SET status='pending',requested_at=now() WHERE topup_cache.expires_at<=now() AND (topup_cache.lease_until IS NULL OR topup_cache.lease_until<now());
END $$;
REVOKE ALL ON FUNCTION public.service_esim_prepare_automation() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.service_esim_prepare_automation() TO service_role;""")
s=defs['service_esim_alert_is_current']
needle=" IF NOT FOUND OR n.expires_at<=now() THEN RETURN false; END IF;"
assert needle in s
s=s.replace(needle,needle+"\n IF n.event_type='esim_automation_paused' THEN RETURN EXISTS(SELECT 1 FROM esim_private.automation_consents c JOIN public.user_esims p ON p.id=c.profile_id WHERE c.profile_id=(n.template_data->>'profile_id')::uuid AND c.owner_id=n.user_id AND p.user_id=n.user_id AND NOT c.enabled AND c.revision=(n.template_data->>'revision')::integer AND c.stop_reason=n.template_data->>'reason'); END IF;")
parts.append(s+';')
parts.append((root/'tools/esim-support-core.sql').read_text())
parts.append('COMMIT;')
out.write_text('\n\n'.join(parts)+'\n');print(out)
