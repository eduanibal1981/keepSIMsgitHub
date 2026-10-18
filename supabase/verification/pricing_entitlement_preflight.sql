-- Read-only release evidence. Prices below are configuration, never test defaults.
-- Run before enabling the coordinated pricing release. Do not repair balances,
-- seed prices, create grants or promote old drafts from this report.
SELECT config_key,config_value FROM public.system_configs
WHERE config_key IN ('MEMBERSHIP_FEE_STANDARD_USD','MEMBERSHIP_FEE_PREMIUM_USD','BASE_SERVICE_FEE_USD')
ORDER BY config_key;
SELECT appfees_item,version,currency,fee_basis,charge_unit,
 free_percentage,free_minimum,stand_percentage,stand_minimum,prem_percentage,prem_minimum,
 effective_from,effective_to
FROM public.app_fee_rules WHERE status='published'
 AND (effective_from IS NULL OR effective_from<=now()) AND (effective_to IS NULL OR effective_to>now())
ORDER BY appfees_item,version DESC;
SELECT code,is_active,fee_percentage,fee_fixed FROM public.payment_gateways
WHERE code IN ('wallet','paypal') ORDER BY code;
SELECT proname,pg_get_function_identity_arguments(oid) arguments,md5(pg_get_functiondef(oid)) source_md5
FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname IN
 ('membership_fee_usd','resolve_app_fee','resolve_line_entitlement','standard_upgrade_credit_usd',
 'quote_premium_breakdown','quote_plan_price','quote_sim_setup','create_sim_setup_order',
 'reserve_sim_setup_holds','capture_sim_setup_holds','calculate_topup_fees','request_esim_purchase')
ORDER BY proname,arguments;
