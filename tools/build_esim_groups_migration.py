"""Build ESIM-13 from frozen, inspected live contracts; no deployment."""
from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
rows=json.loads((root/'docs/reviews/esimaccess-groups-handover-20261028/evidence/dependencies.json').read_text())
defs={x['proname']:x['definition'] for x in rows}
parts=['BEGIN;\nSET LOCAL lock_timeout=\'5s\';']
parts.append('DO $preflight$ BEGIN\n'+''.join(" IF md5(pg_get_functiondef('%s.%s(%s)'::regprocedure))<>'%s' THEN RAISE EXCEPTION 'ESIM-13 dependency drift: %s'; END IF;\n"%(x['nspname'],x['proname'],', '.join(a.strip().split(' ',1)[1] for a in x['args'].split(',') if a.strip()),x['md5'],x['proname']) for x in rows)+'END $preflight$;')
parts.append((root/'tools/esim-groups-core.sql').read_text())
s=defs['service_esim_mark_submitted'];needle=' IF reject_code IS NOT NULL THEN';assert s.count(needle)==1
s=s.replace(needle," IF NOT esim_private.group_order_current(o) THEN reject_code:='PROFILE_CHANGED'; END IF;\n"+needle);parts.append(s+';')
s=defs['service_esim_claim_order'];needle="'supplier_profile_ref',o.catalogue_snapshot";assert s.count(needle)==1
s=s.replace(needle,"'group_batch_id',(SELECT batch_id FROM esim_private.group_members WHERE order_id=o.id),'group_member_index',(SELECT member_index FROM esim_private.group_members WHERE order_id=o.id),\n "+needle);parts.append(s+';')
# Quote retention uses the existing service-only cleanup rather than a new cron.
parts.append("""CREATE FUNCTION public.prune_esim_group_quotes() RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM esim_private.require_service();
 DELETE FROM esim_private.group_quotes q WHERE expires_at<now()-interval '30 days' AND NOT EXISTS(SELECT 1 FROM esim_private.group_batches WHERE quote_id=q.id);
END $$;
REVOKE ALL ON FUNCTION public.prune_esim_group_quotes() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.prune_esim_group_quotes() TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;""")
out=next((root/'supabase/migrations').glob('*_esim_traveller_groups.sql'));out.write_text('\n\n'.join(parts)+'\n');print(out)
