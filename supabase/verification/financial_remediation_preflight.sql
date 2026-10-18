-- Read-only deployment review. No financial RPCs or provider requests.
-- Run on the intended Supabase project before applying the remediation.
SELECT
  (SELECT count(*) FROM public.wallets w WHERE w.balance IS DISTINCT FROM
    (SELECT coalesce(sum(l.remaining_amount),0) FROM public.wallet_funding_lots l WHERE l.wallet_id=w.id)) AS funding_mismatches,
  (SELECT count(*) FROM public.wallets w WHERE w.balance<
    (SELECT coalesce(sum(h.amount),0) FROM public.wallet_holds h WHERE h.wallet_id=w.id AND h.status='active')) AS overheld_wallets,
  (SELECT count(*) FROM public.wallet_funding_lots l WHERE l.remaining_amount<
    (SELECT coalesce(sum(a.amount),0) FROM public.wallet_hold_allocations a JOIN public.wallet_holds h ON h.id=a.hold_id
      WHERE a.lot_id=l.id AND h.status='active')) AS overallocated_lots,
  (SELECT count(*) FROM public.wallet_holds WHERE status='active' AND expires_at<now()) AS expired_active_holds;

SELECT provider,count(*) AS duplicate_provider_id_groups FROM (
  SELECT provider,provider_refund_id FROM public.wallet_refund_items WHERE provider_refund_id IS NOT NULL
    GROUP BY provider,provider_refund_id HAVING count(*)>1
) duplicates GROUP BY provider;

SELECT p.oid::regprocedure AS signature,r.rolname AS owner,
  has_function_privilege('anon',p.oid,'EXECUTE') AS anon_execute,
  has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated_execute,
  has_function_privilege('service_role',p.oid,'EXECUTE') AS service_execute,p.proconfig
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace JOIN pg_roles r ON r.oid=p.proowner
WHERE n.nspname='public' AND p.proname IN ('finalize_sim_setup_order','reap_stuck_executions',
  'capture_sim_setup_holds','resolve_line_entitlement','resolve_account_commerce_benefit',
  'get_call_rate_for_number','get_user_calling_rates','get_return_trip_packages_for_line',
  'trg_fn_notify_topup_result','trg_scheduled_topup_health_sync') ORDER BY signature::text;

SELECT pg_get_userbyid(defaclrole) AS owner,defaclnamespace::regnamespace AS scope,defaclacl
FROM pg_default_acl WHERE defaclobjtype='f' AND defaclnamespace IN (0,'public'::regnamespace);

SELECT pg_describe_object(d.classid,d.objid,d.objsubid) AS dependent
FROM pg_depend d WHERE d.refclassid='pg_proc'::regclass
  AND d.refobjid=to_regprocedure('public.finalize_sim_setup_order(uuid,text)');

-- Aggregate owner states first; inspect specific expired holds privately before
-- deciding their disposition. Never infer release safety from expiry alone.
SELECT h.order_type,e.status AS execution_status,(coalesce(e.carrier_in_flight,false) OR coalesce(h.carrier_in_flight,false)) AS in_flight,
  e.reloadly_transaction_id IS NOT NULL AS has_provider_identity,count(*) AS holds
FROM public.wallet_holds h LEFT JOIN public.topup_executions e ON e.wallet_hold_id=h.id
WHERE h.status='active' AND h.expires_at<now()
GROUP BY h.order_type,e.status,(coalesce(e.carrier_in_flight,false) OR coalesce(h.carrier_in_flight,false)),e.reloadly_transaction_id IS NOT NULL;
