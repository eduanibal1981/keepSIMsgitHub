"""Forward ESIM-09 migration; patch exact inspected ESIM-08 definitions."""
from pathlib import Path
import json,re,hashlib
root=Path(__file__).resolve().parents[1]
out=next((root/'supabase/migrations').glob('*_esim_daily_duration.sql'))
old=(root/'supabase/migrations/20261028032323_esim_fixed_recharge_settlement.sql').read_text()
defs={}
for m in re.finditer(r'CREATE (?:OR REPLACE )?FUNCTION ([\w.]+)\(',old):
 end=old.find('$function$;',m.start()) if old[m.start():old.find('AS ',m.start())+10].find('$function$')>=0 else -1
 # Definitions use both pg_get_functiondef and hand-written $$ bodies.
 tail=old[m.start():];delimiter='$function$' if re.search(r'AS\s+\$function\$',tail[:tail.find('BEGIN')+10]) else '$$'
 a=tail.find(delimiter);b=tail.find(delimiter,a+len(delimiter))
 defs[m[1].split('.')[-1]]=tail[:b+len(delimiter)+1]
hashes=json.loads((root/'docs/reviews/esimaccess-daily-duration-20261028/evidence/dependency-hashes.json').read_text())
preflight='DO $preflight$ BEGIN\n'+''.join(" IF md5(pg_get_functiondef('%s'::regprocedure))<>'%s' THEN RAISE EXCEPTION 'ESIM-09 dependency source drift'; END IF;\n"%(x['signature'],x['md5']) for x in hashes)+'END $preflight$;'
parts=["BEGIN;\nSET LOCAL lock_timeout='5s';",preflight,(root/'tools/esim09-core.sql').read_text()]
def emit(name,s):
 s=s.replace('CREATE FUNCTION','CREATE OR REPLACE FUNCTION')
 s=s.replace("operation_kind='fixed_recharge'","operation_kind IN('fixed_recharge','daily_extension')").replace("operation_kind<>'fixed_recharge'","operation_kind NOT IN('fixed_recharge','daily_extension')")
 parts.append(s)
def replace(s,a,b):
 assert s.count(a)==1,(a[:100],s.count(a));return s.replace(a,b)
for name in ['reserve_order','guard_order_hold','settle_order','service_esim_record_topup_receipt','gate_esim_order_submission']:
 if name in defs:
  value=defs[name]
  if name=='service_esim_record_topup_receipt':
   value=value.replace("digest_value:=encode","IF o.operation_kind='daily_extension' AND (p_receipt->>'period_count' IS DISTINCT FROM o.catalogue_snapshot->>'period_count' OR (p_receipt->>'expires_at')::timestamptz<=(o.catalogue_snapshot->>'daily_previous_expiry')::timestamptz) THEN RAISE EXCEPTION 'Unproven extension duration'; END IF;\n digest_value:=encode")
  emit(name,value)
# Hold guards are also authored in the core. Include all actual fixed checks.
for name,s in defs.items():
 if "operation_kind='fixed_recharge'" in s and name not in ['reserve_order','guard_order_hold','settle_order','service_esim_record_topup_receipt','gate_esim_order_submission','accept_esim_topup','service_esim_settle_topup','snapshot_esim_catalogue_order','service_esim_mark_submitted']:
  emit(name,s)
s=defs['accept_esim_topup']
s=replace(s,"IF NOT esim_private.recharge_can_accept() THEN","IF NOT esim_private.recharge_can_accept() OR (q.action='daily_extension' AND NOT EXISTS(SELECT 1 FROM esim_private.accounts WHERE id=q.account_id AND daily_duration_enabled AND daily_contract_verified)) THEN")
s=replace(s,"IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(c.offers) x WHERE x->>'package_id'=q.package_id AND x->>'data_type'='1'\n  AND (x->>'wholesale_usd')::numeric=q.wholesale_usd AND (x->>'allowance_bytes')::bigint>0)","IF NOT (CASE WHEN q.action='daily_extension' THEN esim_private.daily_extension_current(q,p,c) ELSE EXISTS(SELECT 1 FROM jsonb_array_elements(c.offers) x WHERE x->>'package_id'=q.package_id AND x->>'data_type'='1' AND (x->>'wholesale_usd')::numeric=q.wholesale_usd AND (x->>'allowance_bytes')::bigint>0) END)")
s=s.replace("'fixed_recharge',p.id,q.id", "CASE WHEN q.action='daily_extension' THEN 'daily_extension' ELSE 'fixed_recharge' END,p.id,q.id")
s=s.replace("'catalogue_details',q.retail_snapshot", "'catalogue_details',q.retail_snapshot,'period_count',CASE WHEN q.action='daily_extension' THEN q.period_count END,'daily_price_id',q.daily_price_id,'daily_source_facts',(SELECT value FROM jsonb_array_elements(c.offers) WHERE value->>'package_id'=q.package_id),'daily_base_price',(SELECT (value->>'wholesale_usd')::numeric FROM jsonb_array_elements(c.offers) WHERE value->>'package_id'=q.package_id),'daily_previous_expiry',p.confirmed_expires_at")
emit('accept_esim_topup',s)
s=defs['service_esim_mark_submitted']
s=replace(s,"IF NOT EXISTS(SELECT 1 FROM public.esim_offers_cache WHERE provider=o.provider AND bundle_name=o.bundle_name AND is_active\n   AND wholesale_price_usd=o.wholesale_price_usd)","IF o.daily_purchase_quote_id IS NULL AND NOT EXISTS(SELECT 1 FROM public.esim_offers_cache WHERE provider=o.provider AND bundle_name=o.bundle_name AND is_active AND wholesale_price_usd=o.wholesale_price_usd)")
s=replace(s,"IF reject_code IS NOT NULL THEN", "IF (o.daily_purchase_quote_id IS NOT NULL OR o.operation_kind='daily_extension') AND NOT EXISTS(SELECT 1 FROM esim_private.accounts WHERE id=r.account_id AND daily_duration_enabled AND daily_contract_verified) THEN reject_code:='SUBMISSION_DISABLED'; END IF;\n IF NOT esim_private.daily_order_current(o) THEN reject_code:='PRICE_CHANGED'; END IF;\n IF reject_code IS NOT NULL THEN")
emit('service_esim_mark_submitted',s)
s=defs['snapshot_esim_catalogue_order']
s=replace(s,"BEGIN\n IF NEW.operation_kind", "BEGIN\n IF NEW.daily_purchase_quote_id IS NOT NULL THEN\n  SELECT snapshot INTO STRICT NEW.catalogue_snapshot FROM esim_private.daily_purchase_quotes WHERE id=NEW.daily_purchase_quote_id AND owner_id=NEW.user_id AND package_id=NEW.bundle_name AND quantity=NEW.quantity AND wholesale_total=NEW.wholesale_price_usd AND retail_total=NEW.total_amount_usd;\n  RETURN NEW;\n END IF;\n IF NEW.operation_kind")
emit('snapshot_esim_catalogue_order',s)
s=defs['request_esim_purchase_v2']
s=replace(s,"  -- Use canonical tier-based pricing", "  IF v_offer.catalogue_details->>'plan_type' IN('daily_throttled','daily_cutoff','daily_unlimited') THEN RETURN jsonb_build_object('success',false,'code','DURATION_REQUIRED'); END IF;\n  -- Use canonical tier-based pricing")
s=s.replace("SET search_path TO 'public'","SET search_path TO ''")
emit('request_esim_purchase_v2',s)
s=defs['check_esim_topup_quote']
s=replace(s,"OR public.resolve_esim_offer_price(q.wholesale_usd,u)", "OR (q.action='daily_extension' AND NOT esim_private.daily_extension_current(q,p,c))\n  OR public.resolve_esim_offer_price(q.wholesale_usd,u)")
s=s.replace("'acceptance_enabled',esim_private.recharge_can_accept()","'acceptance_enabled',esim_private.recharge_can_accept() AND (q.action<>'daily_extension' OR EXISTS(SELECT 1 FROM esim_private.accounts WHERE id=q.account_id AND daily_duration_enabled AND daily_contract_verified))")
emit('check_esim_topup_quote',s)
s=defs['service_esim_settle_topup']
# A day extension does not replenish today's quota, change throttle state or
# declare delayed totals fresh. Only the confirmed validity is updated.
a=s.index(' UPDATE public.user_esims SET');b=s.index('\n PERFORM esim_private.open_alert_cycle',a)
s=s[:a]+" IF o.operation_kind='daily_extension' THEN\n  UPDATE public.user_esims SET confirmed_expires_at=CASE WHEN bundle_state IN('active','depleted') THEN (receipt_value->>'expires_at')::timestamptz ELSE confirmed_expires_at END,expires_at=CASE WHEN bundle_state IN('active','depleted') THEN (receipt_value->>'expires_at')::timestamptz ELSE expires_at END WHERE id=p.id;\n ELSE\n"+s[a:b]+"\n END IF;"+s[b:]
emit('service_esim_settle_topup',s)
# Daily aggregate usage does not prove today's remaining quota. Until a daily
# observation contract is verified, only validity alerts use those profiles.
alert_source=(root/'supabase/migrations/20261028013756_esim_actionable_alerts.sql').read_text()
a=alert_source.index('CREATE FUNCTION esim_private.alert_is_relevant(')
b=alert_source.index('END $$;',a)+len('END $$;')
alert=alert_source[a:b]
alert=alert.replace(' RETURN coalesce(CASE p_event_type', " IF p_event_type='esim_low_data' AND p.plan_details->>'plan_type' LIKE 'daily_%' THEN RETURN false; END IF;\n RETURN coalesce(CASE p_event_type")
emit('alert_is_relevant',alert)

s=defs['prune_esim_topup_discovery']
s=replace(s," DELETE FROM esim_private.topup_cache", " DELETE FROM esim_private.daily_purchase_quotes q WHERE expires_at<now()-interval '30 days' AND NOT EXISTS(SELECT 1 FROM public.esim_orders WHERE daily_purchase_quote_id=q.id);\n DELETE FROM esim_private.daily_prices r WHERE expires_at<now()-interval '30 days' AND NOT EXISTS(SELECT 1 FROM esim_private.daily_purchase_quotes WHERE price_id=r.id) AND NOT EXISTS(SELECT 1 FROM esim_private.recharge_quotes WHERE daily_price_id=r.id);\n DELETE FROM esim_private.topup_cache")
emit('prune_esim_topup_discovery',s)
s=defs['get_esim_operation_history']
s=replace(s,"'duration_value',e.duration_value,'duration_unit',e.duration_unit,", "'duration_value',coalesce(e.duration_value,(o.catalogue_snapshot->>'period_count')::integer),'duration_unit',coalesce(e.duration_unit,CASE WHEN o.catalogue_snapshot->>'period_count' IS NOT NULL THEN 'DAY' END),")
emit('get_esim_operation_history',s)
# Do not let existing insert/update snapshot triggers downgrade owner views.
parts.append("ALTER VIEW public.customer_esim_orders SET(security_invoker=true,security_barrier=true);\nNOTIFY pgrst,'reload schema';\nCOMMIT;")
out.write_text('\n\n'.join(parts)+'\n')
print(out.name)
