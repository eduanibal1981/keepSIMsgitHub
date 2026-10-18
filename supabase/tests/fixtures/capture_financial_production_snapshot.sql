-- READ ONLY: bounded catalog export for the isolated financial fixture.
-- Run through Supabase execute_sql; save the returned JSON object as
-- financial_production_snapshot.json after reviewing its diff. Never deploy.
-- This captures metadata/function sources only, never customer table contents.
WITH selected AS (
 SELECT c.oid,c.relname,c.relkind,c.relrowsecurity,c.relforcerowsecurity,c.relowner,c.relacl
 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' AND c.relname IN ('account_deletions','affiliate_networks','affiliate_offers','affiliate_partners','app_fee_rules','call_rates','call_records','carrier_rules','carriers','countries','esim_offers_cache','esim_suppliers','free_line_grants','household_members','line_activity_log','line_verification_allowances','line_verification_attempts','notifications','payment_gateways','plan_payments','premium_entitlement_grandfather','profiles','provider_offers','referral_points','referral_redemptions','return_trip_packages','return_trips','scheduled_topups','security_logs','service_providers','sim_lines','sim_setup_orders','system_alerts','system_configs','topup_executions','wallet_funding_lots','wallet_hold_allocations','wallet_holds','wallet_refund_items','wallet_refund_requests','wallet_transactions','wallets')
), triggers AS (
 SELECT c.relname AS "table",t.tgname AS name,pg_get_triggerdef(t.oid) AS definition,
   t.tgfoid::regprocedure::text AS function,pg_get_functiondef(t.tgfoid) AS function_definition
 FROM pg_trigger t JOIN selected c ON c.oid=t.tgrelid WHERE NOT t.tgisinternal
)
SELECT jsonb_build_object(
 'captured_date',current_date::text,
 'views',(SELECT jsonb_agg(jsonb_build_object('name',c.relname,'definition',pg_get_viewdef(c.oid,true),
   'options',c.reloptions,'acl',c.relacl::text[],'owner',pg_get_userbyid(c.relowner)))
   FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname='public' AND c.relname='wallet_reconciliation' AND c.relkind='v'),
 'project_ref','zwxswagokhgbuzrrbnhr',
 'tables',(SELECT jsonb_agg(relname ORDER BY relname) FROM selected),
 'columns',(SELECT jsonb_agg(jsonb_build_object('table',c.relname,'kind',c.relkind,
   'column',a.attname,'type',format_type(a.atttypid,a.atttypmod),'not_null',a.attnotnull,
   'default',pg_get_expr(d.adbin,d.adrelid),'generated',a.attgenerated,'identity',a.attidentity)
   ORDER BY c.relname,a.attnum) FROM selected c JOIN pg_attribute a ON a.attrelid=c.oid
   LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum
   WHERE a.attnum>0 AND NOT a.attisdropped),
 'constraints',(SELECT jsonb_agg(jsonb_build_object('table',c.relname,'name',k.conname,'type',k.contype,
   'definition',pg_get_constraintdef(k.oid),'reference',CASE WHEN k.confrelid<>0 THEN k.confrelid::regclass::text END)
   ORDER BY c.relname,k.conname) FROM selected c JOIN pg_constraint k ON k.conrelid=c.oid WHERE k.contype IN ('p','u','c','f')),
 'indexes',(SELECT jsonb_agg(jsonb_build_object('table',c.relname,'name',i.relname,'unique',x.indisunique,
   'definition',pg_get_indexdef(i.oid)) ORDER BY c.relname,i.relname)
   FROM selected c JOIN pg_index x ON x.indrelid=c.oid JOIN pg_class i ON i.oid=x.indexrelid WHERE x.indisunique),
 'relations',(SELECT jsonb_agg(jsonb_build_object('table',relname,'kind',relkind,'rls',relrowsecurity,
   'force_rls',relforcerowsecurity,'owner',pg_get_userbyid(relowner),'acl',relacl::text[]) ORDER BY relname) FROM selected),
 'policies',(SELECT jsonb_agg(to_jsonb(p) ORDER BY p.tablename,p.policyname) FROM pg_policies p
   WHERE schemaname='public' AND tablename IN (SELECT relname FROM selected)),
 'column_grants',(SELECT jsonb_agg(jsonb_build_object('table',c.relname,'column',a.attname,'acl',a.attacl::text[])
   ORDER BY c.relname,a.attnum) FROM selected c JOIN pg_attribute a ON a.attrelid=c.oid WHERE a.attacl IS NOT NULL),
 'functions',(SELECT jsonb_agg(jsonb_build_object('proname',p.proname,'signature',p.oid::regprocedure::text,
   'definition',pg_get_functiondef(p.oid),'proacl',p.proacl::text[],'prosecdef',p.prosecdef,'proconfig',p.proconfig)
   ORDER BY p.oid::regprocedure::text) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.oid::regprocedure::text IN ('admin_adjust_wallet(uuid,numeric,text)','admin_list_refund_requests(text,integer)','assert_admin()','capture_wallet_hold(uuid,text,text,jsonb)','credit_wallet_for_deposit(uuid,numeric,text,text,jsonb)','credit_wallet_for_refund(uuid,numeric,text,text,uuid,text)','debit_wallet_for_call(uuid,uuid,numeric,text)','debit_wallet_for_topup(uuid,uuid,numeric,text,text,text)','ensure_wallet_v2(uuid)','finalize_sim_setup_order(uuid,text)','finalize_sim_setup_order(uuid,uuid)','get_call_rate_for_number(text,uuid)','get_return_trip_packages_for_line(uuid,uuid)','get_user_calling_rates(uuid)','get_wallet_summary(uuid)','has_paid_premium_entitlement(uuid)','is_power_user(uuid)','is_user_suspended()','quote_wallet_refund(uuid)','reap_stuck_executions(integer,integer)','release_wallet_hold(uuid,text)','request_wallet_refund(uuid,numeric,text)','reserve_sim_setup_holds(uuid)','reserve_wallet_funds(uuid,numeric,text,text,text,integer)','resolve_account_commerce_benefit(uuid)','resolve_app_fee(text,text,numeric)','resolve_esim_offer_price(numeric,uuid)','resolve_line_entitlement(uuid)','settle_line_verification_attempt(uuid,text,text,text)','settle_successful_execution(uuid,text,uuid,text,text,text,jsonb)','format_sim_line_tier_defaults()','reap_stale_esim_orders()','settle_call_wallet_hold(uuid,numeric,text,jsonb)','trg_fn_cancel_executions_on_schedule_delete()','trg_fn_sync_sim_line_health_and_due()','refill_interval_days(integer,integer)','calculate_topup_fees()','trg_fn_apply_plan_tier_from_payment()','trg_fn_award_referral_points()','trg_fn_prevent_sim_line_plan_tampering()','trg_fn_resume_awaiting_funds()','update_execution_status(uuid,text,text)','update_execution_status(uuid,text,text,text,text,text)','update_updated_at()')),
 'included_triggers',(SELECT jsonb_agg(to_jsonb(t) ORDER BY t."table",t.name) FROM triggers t WHERE name IN ('trg_apply_plan_tier_on_payment','trg_award_referral_paypal','trg_format_sim_line_tier_defaults','trg_prevent_sim_line_plan_tampering','trg_wallets_updated_at','trg_award_referral_wallet','trg_resume_awaiting_funds','trg_carrier_rules_updated_at','trg_cancel_executions_on_schedule_delete','trg_scheduled_topups_updated_at','tr_calculate_topup_fees')),
 'omitted_triggers',(SELECT jsonb_agg(to_jsonb(t) ORDER BY t."table",t.name) FROM triggers t WHERE name NOT IN ('trg_apply_plan_tier_on_payment','trg_award_referral_paypal','trg_format_sim_line_tier_defaults','trg_prevent_sim_line_plan_tampering','trg_wallets_updated_at','trg_award_referral_wallet','trg_resume_awaiting_funds','trg_carrier_rules_updated_at','trg_cancel_executions_on_schedule_delete','trg_scheduled_topups_updated_at','tr_calculate_topup_fees')),
 'live_ledger_consumers',(SELECT jsonb_agg(jsonb_build_object('signature',p.oid::regprocedure::text,
   'source_md5',md5(p.prosrc),'ledger_literals',(SELECT coalesce(jsonb_agg(DISTINCT m[1]),'[]'::jsonb)
     FROM regexp_matches(p.prosrc,'''(deposit|topup_debit|refund|referral_credit|referral_withdrawal|plan_fee_debit|home_mode_debit|auto_fund|esim_purchase_debit|esim_purchase_refund|wallet_settlement|wallet_forfeit|gift_sent|gift_received|admin_adjustment|offline_voucher_debit|call_debit|call_refund|did_purchase_debit|verification_debit|refund_payout|credit|manual_credit)''','g') m))
   ORDER BY p.oid::regprocedure::text) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.prokind='f' AND
     (p.prosrc ~ '(wallet_transactions|capture_wallet_hold|credit_wallet|debit_wallet|settle_call_wallet_hold|verification_debit)'
      OR p.proname='trg_fn_resume_awaiting_funds'))
) AS financial_production_snapshot;
