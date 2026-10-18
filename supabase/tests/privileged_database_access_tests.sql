-- Read-only catalog regression. Zero rows means PASS. Safe for live execute_sql.
-- Behavior tests run separately in tools/financial-tests/privileges.mjs.
WITH required_allowed(signature) AS (VALUES
    ('admin_add_voucher_stock(uuid,jsonb,jsonb,text)'),
    ('admin_adjust_wallet(uuid,numeric,text)'),
    ('admin_affiliate_overview(integer)'),
    ('admin_alert_clock_scheduler_status()'),
    ('admin_cancel_voucher_purchase_job(uuid,text)'),
    ('admin_cancel_voucher_request(uuid,text,text)'),
    ('admin_complete_manual_refill(uuid,text)'),
    ('admin_confirm_provider_credential_rotation(text,integer)'),
    ('admin_delete_affiliate_offer(uuid,text)'),
    ('admin_delete_offline_endpoint(uuid,text)'),
    ('admin_delete_whatsapp_profile(uuid)'),
    ('admin_fail_refill(uuid,text,boolean)'),
    ('admin_get_alert_clock_overview()'),
    ('admin_get_carrier_alert_rule(uuid)'),
    ('admin_get_scheduled_jobs_overview()'),
    ('admin_get_ticket(uuid)'),
    ('admin_get_user(uuid)'),
    ('admin_list_affiliate_offers(text,integer)'),
    ('admin_list_affiliate_partners()'),
    ('admin_list_alert_clocks(text,integer,integer)'),
    ('admin_list_app_fee_rules()'),
    ('admin_list_audit(integer,text,text)'),
    ('admin_list_campaigns()'),
    ('admin_list_carrier_provider_map(uuid)'),
    ('admin_list_carrier_self_service()'),
    ('admin_list_carrier_voucher_redemption()'),
    ('admin_list_carriers()'),
    ('admin_list_channels()'),
    ('admin_list_configs()'),
    ('admin_list_country_verification_prices(text,boolean,integer,integer)'),
    ('admin_list_emails(integer)'),
    ('admin_list_esim_suppliers()'),
    ('admin_list_line_verification_attempts(uuid,text,integer,integer)'),
    ('admin_list_notification_dispatch_incidents(integer)'),
    ('admin_list_offline_endpoints()'),
    ('admin_list_provider_credentials()'),
    ('admin_list_provider_offers(text,text,text,uuid,boolean,integer,integer)'),
    ('admin_list_refill_scripts()'),
    ('admin_list_refund_requests(text,integer)'),
    ('admin_list_service_providers()'),
    ('admin_list_supplier_policy()'),
    ('admin_list_tickets(text,integer)'),
    ('admin_list_users(text,integer)'),
    ('admin_list_users_extended()'),
    ('admin_list_voucher_grants(text,integer)'),
    ('admin_list_voucher_purchase_jobs(integer)'),
    ('admin_list_voucher_requests(text,integer)'),
    ('admin_list_voucher_stock(uuid,text,integer)'),
    ('admin_list_whatsapp_attempts(uuid,text,text,text,integer,integer)'),
    ('admin_list_whatsapp_profiles()'),
    ('admin_list_whatsapp_routes()'),
    ('admin_notification_dispatch_health()'),
    ('admin_notification_health(integer)'),
    ('admin_override_provider_offer(uuid,jsonb,text)'),
    ('admin_overview()'),
    ('admin_preview_carrier_alert_rule(uuid,jsonb)'),
    ('admin_prune_database_logs(integer,integer)'),
    ('admin_publish_app_fee_rule(text,numeric,numeric,numeric,numeric,numeric,numeric,text,text)'),
    ('admin_purge_user_account(uuid,text,text)'),
    ('admin_queue_ding_voucher_purchase(uuid,integer,text,numeric,text)'),
    ('admin_record_whatsapp_probe(uuid,text,text,text,text,jsonb)'),
    ('admin_refresh_provider_offers(text)'),
    ('admin_reply_ticket(uuid,text,text)'),
    ('admin_retry_notification_dispatch_job(uuid)'),
    ('admin_rotate_provider_credential(text,text,text,integer)'),
    ('admin_save_draft_app_fee_rule(text,numeric,numeric,numeric,numeric,numeric,numeric,text,text)'),
    ('admin_save_whatsapp_profile(uuid,text,text,text,boolean,jsonb,jsonb,integer)'),
    ('admin_send_campaign(uuid,text)'),
    ('admin_send_email(text[],text,text,text[],text,text,text)'),
    ('admin_set_alert_clock_scheduler_enabled(boolean)'),
    ('admin_set_config(text,text,text)'),
    ('admin_set_ticket_status(uuid,text,text)'),
    ('admin_set_user_flags(uuid,jsonb,text)'),
    ('admin_set_vault_secret(text,text,text)'),
    ('admin_switch_gateway_to_manual(uuid,text)'),
    ('admin_sync_affiliate_network(integer,text)'),
    ('admin_sync_alert_clocks()'),
    ('admin_sync_esim_catalogue(text)'),
    ('admin_update_carrier(uuid,jsonb,text)'),
    ('admin_update_carrier_rule(uuid,jsonb,text)'),
    ('admin_update_channel(text,jsonb,text)'),
    ('admin_update_country_verification_prices(uuid,numeric,numeric,integer)'),
    ('admin_update_supplier_policy(text,jsonb,text)'),
    ('admin_update_whatsapp_route(uuid,text,uuid,integer,text)'),
    ('admin_upsert_affiliate_offer(uuid,jsonb,text)'),
    ('admin_upsert_affiliate_partner(text,jsonb,text)'),
    ('admin_upsert_campaign(uuid,jsonb,text)'),
    ('admin_upsert_carrier_provider_map(uuid,text,jsonb,text)'),
    ('admin_upsert_carrier_rule(uuid,jsonb)'),
    ('admin_upsert_carrier_self_service(uuid,jsonb,text)'),
    ('admin_upsert_carrier_voucher_redemption(uuid,jsonb,text)'),
    ('admin_upsert_esim_supplier(text,jsonb,text)'),
    ('admin_upsert_offline_endpoint(uuid,jsonb,text)'),
    ('admin_upsert_refill_script(uuid,jsonb,text)'),
    ('admin_upsert_service_provider(text,jsonb,text)'),
    ('admin_void_voucher_stock(uuid,text,text)'),
    ('admin_voucher_overview()'),
    ('admin_write_off_voucher_grant(uuid,text,text)'),
    ('answer_voip_session(uuid,text,text)'),
    ('apply_referral(uuid,text)'),
    ('approve_refill_execution(uuid,numeric)'),
    ('approve_refill_execution_quote(uuid,numeric)'),
    ('assert_admin()'),
    ('cancel_account_deletion()'),
    ('cancel_sim_setup_order(uuid,text)'),
    ('cancel_topup_execution(uuid)'),
    ('compare_esim_filter_bounds(text)'),
    ('compare_esim_offers(text,text,bigint,integer,numeric,boolean,text[],text,integer,integer,bigint,bigint[],integer,integer[],numeric)'),
    ('create_sim_setup_order(text,text,uuid,text,text,uuid)'),
    ('create_telegram_bind_token()'),
    ('dismiss_promo(uuid)'),
    ('dispatch_sim_setup_verification(uuid,uuid)'),
    ('export_user_data()'),
    ('fallback_sim_setup_to_reminders(uuid,uuid,text)'),
    ('finalize_sim_setup_order(uuid,uuid)'),
    ('get_active_promos()'),
    ('get_active_return_trip_for_line(uuid,uuid)'),
    ('get_call_rate_for_number(text,uuid)'),
    ('get_current_context()'),
    ('get_fx_display_context()'),
    ('get_return_trip_history_for_line(uuid,uuid)'),
    ('get_return_trip_packages_for_line(uuid,uuid)'),
    ('get_supported_carriers_divert()'),
    ('get_user_calling_rates(uuid)'),
    ('get_user_dids()'),
    ('get_user_voicemails(integer)'),
    ('get_voip_call_history(integer)'),
    ('get_wallet_forecast(uuid)'),
    ('get_wallet_summary(uuid)'),
    ('household_spend_summary()'),
    ('invite_household_member(text,text)'),
    ('is_power_user(uuid)'),
    ('is_user_suspended()'),
    ('label_my_device(text,text)'),
    ('leave_household(uuid)'),
    ('list_carrier_offers(uuid)'),
    ('list_refill_offers(uuid)'),
    ('lookup_voip_contact_by_phone(text)'),
    ('mark_voicemail_read(uuid)'),
    ('mark_voip_session_connected(uuid)'),
    ('my_devices()'),
    ('my_household_allowances()'),
    ('my_roaming_carriers(text)'),
    ('normalize_device_id(text)'),
    ('offline_voucher_state()'),
    ('pay_plan_fee_from_wallet(text,uuid,text,text,uuid)'),
    ('pick_best_refill_offer(uuid,numeric)'),
    ('provision_offline_voucher(uuid,text)'),
    ('queue_premium_refill_executions(uuid,uuid,timestamp with time zone,timestamp with time zone)'),
    ('quote_line_verification(uuid,uuid)'),
    ('quote_plan_price(uuid,text,text,uuid)'),
    ('quote_premium_breakdown(uuid,uuid)'),
    ('quote_sim_setup(text,text,uuid,uuid)'),
    ('quote_wallet_refund(uuid)'),
    ('record_affiliate_click(uuid,text,text)'),
    ('record_manual_external_recharge(uuid,timestamp with time zone,numeric,text)'),
    ('redeem_referral_points()'),
    ('refill_interval_days(integer,integer)'),
    ('refills_per_year(integer,integer)'),
    ('refresh_own_sim_line_alert_clock(uuid)'),
    ('report_device_block(text,numeric,text)'),
    ('report_offline_voucher_reveal(uuid,timestamp with time zone)'),
    ('request_account_deletion(text,boolean)'),
    ('request_esim_purchase(text,integer,text)'),
    ('request_instant_refill(uuid,text,text,numeric,text)'),
    ('request_notification_event(text,uuid)'),
    ('request_notification_test(text,uuid,integer)'),
    ('request_refill_approval_quote(uuid)'),
    ('request_wallet_refund(uuid,numeric,text)'),
    ('reschedule_mini_refill(uuid,timestamp with time zone)'),
    ('reserve_sim_setup_holds(uuid)'),
    ('reset_mini_refill_to_default(uuid)'),
    ('resolve_country_by_phone(text)'),
    ('resolve_free_call_recipient(text,uuid)'),
    ('respond_to_household_invite(uuid,boolean)'),
    ('resume_awaiting_funds_executions(uuid)'),
    ('retry_topup_execution(uuid)'),
    ('revoke_my_device(text)'),
    ('roam_or_esim_quote(text,integer,bigint,uuid)'),
    ('save_voip_offer(uuid,text)'),
    ('set_household_member_cap(uuid,numeric,numeric)'),
    ('set_line_rescue_policy(uuid,numeric,integer,integer)'),
    ('settle_offline_voucher(uuid)'),
    ('terminate_voip_session(uuid,text,text)'),
    ('touch_user_device(text,text,text)'),
    ('transfer_wallet_credit(text,numeric,text,text,text)'),
    ('update_did_forwarding(uuid,text,text)'),
    ('update_mini_refill_dates(uuid,jsonb)'),
    ('url_encode(text)')
), allowed AS (
  SELECT signature FROM required_allowed
  UNION ALL
  -- Pending M2 adds these APIs after the independently deployed containment
  -- package. Check their ACLs when present without claiming M2 is live.
  SELECT s.signature FROM (VALUES ('request_wallet_refund_once(uuid,numeric,text,text)'),
    ('admin_adjust_wallet_once(uuid,numeric,text,text)')) s(signature)
  WHERE to_regprocedure('public.'||s.signature) IS NOT NULL
), functions AS (
  SELECT p.*, p.oid::regprocedure::text signature FROM pg_proc p
  JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.prokind='f'
    AND NOT EXISTS(SELECT 1 FROM pg_depend d
      WHERE d.classid='pg_proc'::regclass AND d.objid=p.oid AND d.deptype='e')
), violations AS (
  SELECT 'authenticated function outside allowlist' problem, f.signature object
  FROM functions f WHERE has_function_privilege('authenticated',f.oid,'EXECUTE')
    AND NOT EXISTS(SELECT 1 FROM allowed a WHERE a.signature=f.signature)
  UNION ALL
  SELECT 'missing authenticated API', a.signature FROM allowed a
  WHERE to_regprocedure('public.'||a.signature) IS NULL OR
    NOT has_function_privilege('authenticated',to_regprocedure('public.'||a.signature),'EXECUTE')
  UNION ALL
  SELECT 'anonymous function outside allowlist', f.signature FROM functions f
  WHERE has_function_privilege('anon',f.oid,'EXECUTE') AND f.signature NOT IN ('is_power_user(uuid)','is_user_suspended()')
  UNION ALL
  SELECT 'PUBLIC function execution', f.signature FROM functions f,
    LATERAL aclexplode(coalesce(f.proacl,acldefault('f',f.proowner))) a
  WHERE a.grantee=0 AND a.privilege_type='EXECUTE'
  UNION ALL
  SELECT 'unsafe privileged search path', f.signature FROM functions f
  WHERE f.prosecdef AND NOT EXISTS(SELECT 1 FROM unnest(f.proconfig) c
    WHERE c IN ('search_path=""','search_path=','search_path=pg_catalog, public, pg_temp'))
  UNION ALL
  SELECT 'dangerous table privilege: '||r.role||' '||v.privilege, c.oid::regclass::text
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  CROSS JOIN (VALUES ('anon'),('authenticated')) r(role)
  CROSS JOIN (VALUES ('TRUNCATE'),('REFERENCES'),('TRIGGER')) v(privilege)
  WHERE n.nspname='public' AND c.relkind IN ('r','p','v','m')
    AND has_table_privilege(r.role,c.oid,v.privilege)
  UNION ALL
  SELECT 'dangerous table privilege: '||r.role||' MAINTAIN', c.oid::regclass::text
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  CROSS JOIN (VALUES ('anon'),('authenticated')) r(role)
  WHERE n.nspname='public' AND c.relkind IN ('r','p','v','m')
    AND CASE WHEN current_setting('server_version_num')::integer >= 170000
      THEN has_table_privilege(r.role,c.oid,'MAINTAIN') ELSE false END
  UNION ALL
  SELECT 'dangerous column REFERENCES: '||r.role, c.oid::regclass::text||'.'||a.attname
  FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid
  JOIN pg_namespace n ON n.oid=c.relnamespace
  CROSS JOIN (VALUES ('anon'),('authenticated')) r(role)
  WHERE n.nspname='public' AND a.attnum>0 AND NOT a.attisdropped
    AND has_column_privilege(r.role,c.oid,a.attnum,'REFERENCES')
  UNION ALL
  SELECT 'unsafe owner default: '||coalesce(n.nspname,'<global>'), r.rolname||' '||d.defaclobjtype::text
  FROM pg_default_acl d JOIN pg_roles r ON r.oid=d.defaclrole
  LEFT JOIN pg_namespace n ON n.oid=d.defaclnamespace
  CROSS JOIN LATERAL aclexplode(d.defaclacl) a
  WHERE d.defaclnamespace IN (0,'public'::regnamespace) AND d.defaclobjtype IN ('f','r','S')
    AND (a.grantee=0 OR a.grantee IN ('anon'::regrole,'authenticated'::regrole))
  UNION ALL
  SELECT 'client-writable search-path schema', n.nspname FROM pg_namespace n
  WHERE n.nspname IN ('public','extensions') AND
    (has_schema_privilege('anon',n.oid,'CREATE') OR has_schema_privilege('authenticated',n.oid,'CREATE'))
  UNION ALL
  SELECT 'owner-only function exposed to service', s.signature
  FROM (VALUES ('finalize_sim_setup_order(uuid,text)'),('confirm_line_verification(uuid,text,text)'),('check_scheduled_jobs_health()'),('prune_database_logs(integer,integer)')) s(signature)
  WHERE has_function_privilege('service_role',to_regprocedure('public.'||s.signature),'EXECUTE')
  UNION ALL
  SELECT 'required service API missing', s.signature
  FROM (VALUES ('reap_stuck_executions(integer,integer)'),('resolve_app_fee(text,text,numeric)'),('resolve_line_entitlement(uuid)'),('resolve_account_commerce_benefit(uuid)'),('has_paid_premium_entitlement(uuid)'),('resolve_esim_offer_price(numeric,uuid)'),('get_authoritative_refill_quote(uuid,numeric,text,text,text)'),('calculate_health_score(uuid,text,timestamp with time zone)'),('settle_line_verification_attempt(uuid,text,text,text)')) s(signature)
  WHERE NOT has_function_privilege('service_role',to_regprocedure('public.'||s.signature),'EXECUTE')
)
SELECT problem, object FROM violations ORDER BY problem, object;

