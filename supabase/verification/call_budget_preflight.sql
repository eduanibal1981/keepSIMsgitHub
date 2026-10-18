-- READ ONLY. Run before the separately authorized coordinated call release.
-- This block works on the old production schema as well as the proposed schema.
SELECT p.oid::regprocedure::text AS signature,p.prosecdef,p.proconfig,p.proacl
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname IN ('prepare_budgeted_media_call',
 'begin_media_call_leg','record_media_call_evidence','finish_media_call',
 'request_media_call_termination','settle_call_wallet_hold','recover_expired_wallet_holds')
ORDER BY 1;
SELECT count(*) AS unresolved_legacy_calls FROM public.call_records
WHERE status IN ('initiated','ringing','in_progress');
SELECT status,count(*) AS holds,sum(amount) AS amount_usd FROM public.wallet_holds
WHERE order_type='call_budget' GROUP BY status;
SELECT count(*) AS duplicated_existing_call_keys FROM (
 SELECT user_id,idempotency_key FROM public.call_records WHERE idempotency_key IS NOT NULL
 GROUP BY user_id,idempotency_key HAVING count(*)>1
) d;
-- After migration, also run supabase/tests/call_budget_contract_tests.sql.
-- Recovery inventory (post-migration only), no customer identifiers returned:
-- SELECT billing_state,reconciliation_reason,count(*) FROM public.call_records
-- WHERE budget_contract_version=1 AND (billing_state<>'settled' OR reconciliation_reason IS NOT NULL)
-- GROUP BY 1,2;
