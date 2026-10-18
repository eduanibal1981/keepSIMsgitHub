-- Task 3 containment. Independently reviewable; does not require wallet repairs.
-- See docs/reviews/privileged-database-access-20261017.md.
BEGIN;

-- Refuse to overwrite a different/newer body, especially the pending retail
-- contracts with changed return shapes. An unknown version needs fresh review.
DO $preflight$
DECLARE changed text;
BEGIN
  SELECT string_agg(v.signature, ', ') INTO changed
  FROM (VALUES
    ('admin_prune_database_logs(integer,integer)','215d72c5be94d4ab83f450736899ebe3','25fd9ed74c4a8f953919cd5cee106c4a'),
    ('get_active_return_trip_for_line(uuid,uuid)','2ca85da3254f9ae61a104364daa08653','b874c5ce5e85d0b7eef31dbef44ca25e'),
    ('get_call_rate_for_number(text,uuid)','f14a1bea448e218a49b926a5836153f1','4adcdbdd25f94400b45cb46aedb457e7'),
    ('get_return_trip_history_for_line(uuid,uuid)','e4ba501961578682415d17e62f255103','c2605a5e8b51478a0d564fb7fa2e2299'),
    ('get_return_trip_packages_for_line(uuid,uuid)','1cc8a59a531204d905d34da821e92066','7b21466f881f5e8bcefbb0ab8f06c058'),
    ('get_user_calling_rates(uuid)','a78f65c1c7a3a10e53bacbdbf22f26d6','cb8f2655d3640f72a05ba843915a1097')
  ) v(signature, old_hash, contained_hash)
  LEFT JOIN pg_proc p ON p.oid=to_regprocedure('public.'||v.signature)
  WHERE p.oid IS NULL OR md5(p.prosrc) NOT IN (v.old_hash,v.contained_hash);
  IF changed IS NOT NULL THEN
    RAISE EXCEPTION 'Containment body preflight failed: %', changed
      USING ERRCODE='55000', HINT='Review current definitions before adapting this targeted release.';
  END IF;
END;
$preflight$;

-- No client may place shadow objects on a privileged function's search path.
REVOKE CREATE ON SCHEMA public FROM PUBLIC, anon, authenticated;
REVOKE CREATE ON SCHEMA extensions FROM PUBLIC, anon, authenticated;

-- Close implicit PUBLIC execution and reset only API-client access, preserving
-- existing worker grants. Trigger execution does not require caller EXECUTE.
DO $acl$
DECLARE f record;
BEGIN
  FOR f IN
    SELECT p.oid::regprocedure AS signature
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.prokind='f'
      AND NOT EXISTS (SELECT 1 FROM pg_depend d
        WHERE d.classid='pg_proc'::regclass AND d.objid=p.oid AND d.deptype='e')
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', f.signature);
  END LOOP;
END;
$acl$;

-- Explicit signed-in application API, including guarded admin RPCs.
-- Identity/ownership checks remain in these bodies; grants alone are not admin.
GRANT EXECUTE ON FUNCTION public.admin_add_voucher_stock(uuid,jsonb,jsonb,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_adjust_wallet(uuid,numeric,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_affiliate_overview(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_alert_clock_scheduler_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_cancel_voucher_purchase_job(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_cancel_voucher_request(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_complete_manual_refill(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_confirm_provider_credential_rotation(text,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_affiliate_offer(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_offline_endpoint(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_whatsapp_profile(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_fail_refill(uuid,text,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_alert_clock_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_carrier_alert_rule(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_scheduled_jobs_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_ticket(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_user(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_affiliate_offers(text,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_affiliate_partners() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_alert_clocks(text,integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_app_fee_rules() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_audit(integer,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_campaigns() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_carrier_provider_map(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_carrier_self_service() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_carrier_voucher_redemption() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_carriers() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_channels() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_configs() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_country_verification_prices(text,boolean,integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_emails(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_esim_suppliers() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_line_verification_attempts(uuid,text,integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_notification_dispatch_incidents(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_offline_endpoints() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_provider_credentials() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_provider_offers(text,text,text,uuid,boolean,integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_refill_scripts() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_refund_requests(text,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_service_providers() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_supplier_policy() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_tickets(text,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_users(text,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_users_extended() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_voucher_grants(text,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_voucher_purchase_jobs(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_voucher_requests(text,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_voucher_stock(uuid,text,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_whatsapp_attempts(uuid,text,text,text,integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_whatsapp_profiles() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_whatsapp_routes() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_notification_dispatch_health() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_notification_health(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_override_provider_offer(uuid,jsonb,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_preview_carrier_alert_rule(uuid,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_prune_database_logs(integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_publish_app_fee_rule(text,numeric,numeric,numeric,numeric,numeric,numeric,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_purge_user_account(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_queue_ding_voucher_purchase(uuid,integer,text,numeric,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_record_whatsapp_probe(uuid,text,text,text,text,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_refresh_provider_offers(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reply_ticket(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_retry_notification_dispatch_job(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_rotate_provider_credential(text,text,text,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_save_draft_app_fee_rule(text,numeric,numeric,numeric,numeric,numeric,numeric,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_save_whatsapp_profile(uuid,text,text,text,boolean,jsonb,jsonb,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_send_campaign(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_send_email(text[],text,text,text[],text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_alert_clock_scheduler_enabled(boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_config(text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_ticket_status(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_user_flags(uuid,jsonb,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_vault_secret(text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_switch_gateway_to_manual(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_sync_affiliate_network(integer,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_sync_alert_clocks() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_sync_esim_catalogue(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_carrier(uuid,jsonb,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_carrier_rule(uuid,jsonb,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_channel(text,jsonb,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_country_verification_prices(uuid,numeric,numeric,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_supplier_policy(text,jsonb,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_whatsapp_route(uuid,text,uuid,integer,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_affiliate_offer(uuid,jsonb,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_affiliate_partner(text,jsonb,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_campaign(uuid,jsonb,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_carrier_provider_map(uuid,text,jsonb,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_carrier_rule(uuid,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_carrier_self_service(uuid,jsonb,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_carrier_voucher_redemption(uuid,jsonb,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_esim_supplier(text,jsonb,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_offline_endpoint(uuid,jsonb,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_refill_script(uuid,jsonb,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_service_provider(text,jsonb,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_void_voucher_stock(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_voucher_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_write_off_voucher_grant(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.answer_voip_session(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.apply_referral(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_refill_execution(uuid,numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_refill_execution_quote(uuid,numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assert_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_account_deletion() TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_sim_setup_order(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_topup_execution(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.compare_esim_filter_bounds(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.compare_esim_offers(text,text,bigint,integer,numeric,boolean,text[],text,integer,integer,bigint,bigint[],integer,integer[],numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_sim_setup_order(text,text,uuid,text,text,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_telegram_bind_token() TO authenticated;
GRANT EXECUTE ON FUNCTION public.dismiss_promo(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.dispatch_sim_setup_verification(uuid,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.export_user_data() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fallback_sim_setup_to_reminders(uuid,uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.finalize_sim_setup_order(uuid,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_active_promos() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_active_return_trip_for_line(uuid,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_call_rate_for_number(text,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_context() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_fx_display_context() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_return_trip_history_for_line(uuid,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_return_trip_packages_for_line(uuid,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_supported_carriers_divert() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_calling_rates(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_dids() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_voicemails(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_voip_call_history(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_wallet_forecast(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_wallet_summary(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.household_spend_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.invite_household_member(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_power_user(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_user_suspended() TO authenticated;
GRANT EXECUTE ON FUNCTION public.label_my_device(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.leave_household(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_carrier_offers(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_refill_offers(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.lookup_voip_contact_by_phone(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_voicemail_read(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_voip_session_connected(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.my_devices() TO authenticated;
GRANT EXECUTE ON FUNCTION public.my_household_allowances() TO authenticated;
GRANT EXECUTE ON FUNCTION public.my_roaming_carriers(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.normalize_device_id(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.offline_voucher_state() TO authenticated;
GRANT EXECUTE ON FUNCTION public.pay_plan_fee_from_wallet(text,uuid,text,text,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pick_best_refill_offer(uuid,numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.provision_offline_voucher(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.queue_premium_refill_executions(uuid,uuid,timestamp with time zone,timestamp with time zone) TO authenticated;
GRANT EXECUTE ON FUNCTION public.quote_line_verification(uuid,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.quote_plan_price(uuid,text,text,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.quote_premium_breakdown(uuid,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.quote_sim_setup(text,text,uuid,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.quote_wallet_refund(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_affiliate_click(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_manual_external_recharge(uuid,timestamp with time zone,numeric,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.redeem_referral_points() TO authenticated;
GRANT EXECUTE ON FUNCTION public.refill_interval_days(integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.refills_per_year(integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_own_sim_line_alert_clock(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.report_device_block(text,numeric,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.report_offline_voucher_reveal(uuid,timestamp with time zone) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_account_deletion(text,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_esim_purchase(text,integer,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_instant_refill(uuid,text,text,numeric,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_notification_event(text,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_notification_test(text,uuid,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_refill_approval_quote(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_wallet_refund(uuid,numeric,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reschedule_mini_refill(uuid,timestamp with time zone) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reserve_sim_setup_holds(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reset_mini_refill_to_default(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_country_by_phone(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_free_call_recipient(text,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_to_household_invite(uuid,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resume_awaiting_funds_executions(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.retry_topup_execution(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_my_device(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.roam_or_esim_quote(text,integer,bigint,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_voip_offer(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_household_member_cap(uuid,numeric,numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_line_rescue_policy(uuid,numeric,integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.settle_offline_voucher(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.terminate_voip_session(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.touch_user_device(text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.transfer_wallet_credit(text,numeric,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_did_forwarding(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_mini_refill_dates(uuid,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.url_encode(text) TO authenticated;

-- Invoker-only JWT predicates required by anonymous RLS evaluation.
GRANT EXECUTE ON FUNCTION public.is_power_user(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.is_user_suspended() TO anon;

-- Disable both obsolete bypass endpoints even for service callers.
REVOKE ALL ON FUNCTION public.finalize_sim_setup_order(uuid,text),
  public.confirm_line_verification(uuid,text,text) FROM service_role;
-- pg_cron invokes these as postgres. Admin pruning goes through its wrapper.
REVOKE ALL ON FUNCTION public.check_scheduled_jobs_health(),
  public.prune_database_logs(integer,integer) FROM service_role;
GRANT EXECUTE ON FUNCTION public.check_scheduled_jobs_health(),
  public.prune_database_logs(integer,integer) TO postgres;
GRANT EXECUTE ON FUNCTION public.reap_stuck_executions(integer,integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.resolve_app_fee(text,text,numeric) TO service_role;
GRANT EXECUTE ON FUNCTION public.resolve_line_entitlement(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.resolve_account_commerce_benefit(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.has_paid_premium_entitlement(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.resolve_esim_offer_price(numeric,uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_authoritative_refill_quote(uuid,numeric,text,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.calculate_health_score(uuid,text,timestamp with time zone) TO service_role;

-- Existing public-only paths implicitly search pg_temp first for relations.
-- Put pg_catalog first and pg_temp last; public is not client-writable.
-- Keep qualified empty-path functions unchanged; fix the two unpinned triggers.
DO $paths$
DECLARE f record;
BEGIN
  FOR f IN
    SELECT p.oid::regprocedure AS signature, p.proconfig
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.prosecdef AND p.prokind='f'
      AND NOT EXISTS (SELECT 1 FROM pg_depend d
        WHERE d.classid='pg_proc'::regclass AND d.objid=p.oid AND d.deptype='e')
  LOOP
    IF f.signature::text IN ('trg_fn_notify_topup_result()', 'trg_scheduled_topup_health_sync()') THEN
      EXECUTE format('ALTER FUNCTION %s SET search_path = %L', f.signature, '');
    ELSIF f.proconfig IS NULL OR NOT EXISTS (
      SELECT 1 FROM unnest(f.proconfig) c WHERE c IN ('search_path=""','search_path=')
    ) THEN
      EXECUTE format('ALTER FUNCTION %s SET search_path = pg_catalog, public, pg_temp', f.signature);
    END IF;
  END LOOP;
END;
$paths$;

-- These three trigger bodies use schema-qualified application relations.
ALTER FUNCTION public.trg_fn_log_topup_activity() SET search_path = '';

-- RLS does not protect TRUNCATE or DDL privileges. Preserve existing row DML.
REVOKE TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA public
  FROM PUBLIC, anon, authenticated;
-- Column-level REFERENCES grants survive a table-level REVOKE.
DO $columns$
DECLARE c record;
BEGIN
  FOR c IN SELECT a.attname, a.attrelid::regclass AS relation
    FROM pg_attribute a JOIN pg_class t ON t.oid=a.attrelid
    JOIN pg_namespace n ON n.oid=t.relnamespace
    WHERE n.nspname='public' AND a.attnum>0 AND NOT a.attisdropped
      AND a.attacl IS NOT NULL
  LOOP
    EXECUTE format('REVOKE REFERENCES (%I) ON TABLE %s FROM PUBLIC, anon, authenticated', c.attname, c.relation);
  END LOOP;
END;
$columns$;
DO $maintain$
BEGIN
  IF current_setting('server_version_num')::integer >= 170000 THEN
    EXECUTE 'REVOKE MAINTAIN ON ALL TABLES IN SCHEMA public FROM PUBLIC, anon, authenticated';
  END IF;
END;
$maintain$;

-- Schema defaults are additive to global defaults: clear both for every
-- application-object owner and every owner with relevant default ACLs.
-- A role unable to administer an owner MUST fail and roll back, not skip it.
DO $defaults$
DECLARE owner_name text;
BEGIN
  FOR owner_name IN
    SELECT DISTINCT r.rolname FROM pg_roles r WHERE r.oid IN (
      SELECT p.proowner FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
      WHERE n.nspname='public' AND NOT EXISTS (
        SELECT 1 FROM pg_depend d WHERE d.classid='pg_proc'::regclass
          AND d.objid=p.oid AND d.deptype='e')
      UNION
      SELECT c.relowner FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relkind IN ('r','p','v','m','S')
      UNION
      SELECT d.defaclrole FROM pg_default_acl d
      WHERE d.defaclnamespace IN (0,'public'::regnamespace)
        AND d.defaclobjtype IN ('f','r','S')
    )
  LOOP
    EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %I REVOKE ALL ON FUNCTIONS FROM PUBLIC, anon, authenticated', owner_name);
    EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM PUBLIC, anon, authenticated', owner_name);
    EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %I REVOKE ALL ON TABLES FROM PUBLIC, anon, authenticated', owner_name);
    EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public REVOKE ALL ON TABLES FROM PUBLIC, anon, authenticated', owner_name);
    EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %I REVOKE ALL ON SEQUENCES FROM PUBLIC, anon, authenticated', owner_name);
    EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public REVOKE ALL ON SEQUENCES FROM PUBLIC, anon, authenticated', owner_name);
  END LOOP;
END;
$defaults$;

-- Retained user-facing APIs must not accept a different user's identity.
-- Bodies below retain their captured return shapes/pricing; retail projection
-- and financial changes remain in the separately coordinated migrations.

CREATE OR REPLACE FUNCTION public.get_active_return_trip_for_line(p_sim_line_id uuid, p_user_id uuid DEFAULT auth.uid())
 RETURNS TABLE(trip_id uuid, sim_line_id uuid, destination_country_id uuid, arrival_date date, status text, package_id uuid, package_type text, package_title text, carrier_name text, data_allowance_mb integer, duration_days integer, is_unlimited boolean, effective_price_usd numeric, ussd_recharge_code text, activation_instructions text, badge_label text, notes text, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN

  IF COALESCE(auth.jwt()->>'role', '') <> 'service_role' THEN
    IF auth.uid() IS NULL OR p_user_id IS DISTINCT FROM auth.uid() THEN
      RAISE EXCEPTION 'Own authenticated account required' USING ERRCODE = '42501';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.sim_lines sl
      WHERE sl.id=p_sim_line_id AND sl.user_id=auth.uid()) THEN
      RAISE EXCEPTION 'SIM ownership required' USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN QUERY
  SELECT 
    t.id AS trip_id,
    t.sim_line_id,
    t.destination_country_id,
    t.arrival_date,
    t.status,
    p.id AS package_id,
    coalesce(p.package_type, t.chosen_package_type) AS package_type,
    coalesce(p.title, 'Curated Return Pack') AS package_title,
    c.name AS carrier_name,
    coalesce(p.data_allowance_mb, 0) AS data_allowance_mb,
    coalesce(p.duration_days, 1) AS duration_days,
    coalesce(p.is_unlimited, false) AS is_unlimited,
    coalesce(p.retail_price_usd, 0.00) AS effective_price_usd,
    p.ussd_recharge_code,
    p.activation_instructions,
    p.badge_label,
    t.notes,
    t.created_at
  FROM public.return_trips t
  LEFT JOIN public.return_trip_packages p ON p.id = t.chosen_package_id
  LEFT JOIN public.carriers c ON c.id = p.carrier_id
  WHERE t.sim_line_id = p_sim_line_id
    AND t.user_id = p_user_id
    AND t.status IN ('planning', 'data_ready', 'arrived')
  ORDER BY t.created_at DESC
  LIMIT 1;
END;
$function$;


CREATE OR REPLACE FUNCTION public.get_return_trip_history_for_line(p_sim_line_id uuid, p_user_id uuid DEFAULT auth.uid())
 RETURNS TABLE(trip_id uuid, sim_line_id uuid, destination_country_id uuid, arrival_date date, status text, package_id uuid, package_type text, package_title text, carrier_name text, data_allowance_mb integer, duration_days integer, is_unlimited boolean, effective_price_usd numeric, ussd_recharge_code text, activation_instructions text, badge_label text, notes text, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN

  IF COALESCE(auth.jwt()->>'role', '') <> 'service_role' THEN
    IF auth.uid() IS NULL OR p_user_id IS DISTINCT FROM auth.uid() THEN
      RAISE EXCEPTION 'Own authenticated account required' USING ERRCODE = '42501';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.sim_lines sl
      WHERE sl.id=p_sim_line_id AND sl.user_id=auth.uid()) THEN
      RAISE EXCEPTION 'SIM ownership required' USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN QUERY
  SELECT 
    t.id AS trip_id,
    t.sim_line_id,
    t.destination_country_id,
    t.arrival_date,
    t.status,
    p.id AS package_id,
    coalesce(p.package_type, t.chosen_package_type) AS package_type,
    coalesce(p.title, 'Curated Return Pack') AS package_title,
    c.name AS carrier_name,
    coalesce(p.data_allowance_mb, 0) AS data_allowance_mb,
    coalesce(p.duration_days, 1) AS duration_days,
    coalesce(p.is_unlimited, false) AS is_unlimited,
    coalesce(p.retail_price_usd, 0.00) AS effective_price_usd,
    p.ussd_recharge_code,
    p.activation_instructions,
    p.badge_label,
    t.notes,
    t.created_at
  FROM public.return_trips t
  LEFT JOIN public.return_trip_packages p ON p.id = t.chosen_package_id
  LEFT JOIN public.carriers c ON c.id = p.carrier_id
  WHERE t.sim_line_id = p_sim_line_id
    AND t.user_id = p_user_id
  ORDER BY t.arrival_date DESC, t.created_at DESC;
END;
$function$;


CREATE OR REPLACE FUNCTION public.get_return_trip_packages_for_line(p_sim_line_id uuid, p_user_id uuid DEFAULT auth.uid())
 RETURNS TABLE(id uuid, country_id uuid, carrier_id uuid, carrier_name text, package_type text, title text, description text, data_allowance_mb integer, duration_days integer, is_unlimited boolean, supplier_cost_usd numeric, retail_price_usd numeric, effective_price_usd numeric, app_fee_usd numeric, discount_usd numeric, ussd_recharge_code text, activation_instructions text, badge_label text, account_tier text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_line_country_id UUID;
  v_line_carrier_id UUID;
  v_tier            TEXT := 'free';
  v_discount_rate   NUMERIC := 0.00;
BEGIN

  IF COALESCE(auth.jwt()->>'role', '') <> 'service_role' THEN
    IF auth.uid() IS NULL OR p_user_id IS DISTINCT FROM auth.uid() THEN
      RAISE EXCEPTION 'Own authenticated account required' USING ERRCODE = '42501';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.sim_lines sl
      WHERE sl.id=p_sim_line_id AND sl.user_id=auth.uid()) THEN
      RAISE EXCEPTION 'SIM ownership required' USING ERRCODE = '42501';
    END IF;
  END IF;
  -- Resolve line country and carrier
  SELECT sl.country_id, sl.carrier_id INTO v_line_country_id, v_line_carrier_id
  FROM public.sim_lines sl
  WHERE sl.id = p_sim_line_id;

  IF v_line_country_id IS NULL THEN
    RETURN;
  END IF;

  v_tier := public.resolve_account_commerce_benefit(p_user_id);
  IF v_tier IS NULL THEN
    v_tier := 'free';
  END IF;

  IF v_tier = 'premium' THEN
    v_discount_rate := 1.00;
  ELSIF v_tier = 'standard' THEN
    v_discount_rate := 0.50;
  ELSE
    v_discount_rate := 0.00;
  END IF;

  RETURN QUERY
  SELECT 
    pkg.id,
    pkg.country_id,
    pkg.carrier_id,
    c.name AS carrier_name,
    pkg.package_type,
    pkg.title,
    pkg.description,
    pkg.data_allowance_mb,
    pkg.duration_days,
    pkg.is_unlimited,
    pkg.supplier_cost_usd,
    pkg.retail_price_usd,
    round(
      pkg.supplier_cost_usd + ((pkg.retail_price_usd - pkg.supplier_cost_usd) * (1.00 - v_discount_rate)),
      2
    ) AS effective_price_usd,
    round((pkg.retail_price_usd - pkg.supplier_cost_usd) * (1.00 - v_discount_rate), 2) AS app_fee_usd,
    round((pkg.retail_price_usd - pkg.supplier_cost_usd) * v_discount_rate, 2) AS discount_usd,
    pkg.ussd_recharge_code,
    pkg.activation_instructions,
    pkg.badge_label,
    v_tier AS account_tier
  FROM public.return_trip_packages pkg
  LEFT JOIN public.carriers c ON c.id = pkg.carrier_id
  WHERE pkg.country_id = v_line_country_id
    AND pkg.is_active = true
  ORDER BY 
    CASE 
      WHEN pkg.package_type = 'esim' THEN 0
      WHEN v_line_carrier_id IS NOT NULL AND pkg.carrier_id = v_line_carrier_id THEN 1
      ELSE 2
    END,
    effective_price_usd ASC;
END;
$function$;


CREATE OR REPLACE FUNCTION public.get_call_rate_for_number(p_phone_number text, p_user_id uuid DEFAULT auth.uid())
 RETURNS TABLE(id uuid, country_code text, country_name text, phone_prefix text, rate_per_minute_usd numeric, cost_per_minute_usd numeric, connection_fee_usd numeric, billing_increment_seconds integer, account_tier text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_clean_number TEXT;
  v_tier         TEXT;
  v_rate         RECORD;
  v_effective    NUMERIC;
  v_fee          NUMERIC;
BEGIN

  IF COALESCE(auth.jwt()->>'role', '') <> 'service_role' THEN
    IF auth.uid() IS NULL OR p_user_id IS DISTINCT FROM auth.uid() THEN
      RAISE EXCEPTION 'Own authenticated account required' USING ERRCODE = '42501';
    END IF;
  END IF;
  -- 1. Resolve Halo tier for this account
  v_tier := public.resolve_account_commerce_benefit(p_user_id);

  -- 2. Normalize number format
  v_clean_number := regexp_replace(p_phone_number, '[^0-9+]', '', 'g');
  IF NOT (v_clean_number LIKE '+%') THEN
    v_clean_number := '+' || v_clean_number;
  END IF;

  SELECT
    cr.id,
    cr.country_code,
    cr.country_name,
    cr.phone_prefix,
    cr.rate_per_minute_usd,
    cr.cost_per_minute_usd,
    0.00::NUMERIC AS connection_fee_usd, -- Strictly $0 connection fee per C12
    cr.billing_increment_seconds
  INTO v_rate
  FROM public.call_rates cr
  WHERE cr.is_active = TRUE
    AND v_clean_number LIKE (cr.phone_prefix || '%')
  ORDER BY length(cr.phone_prefix) DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- 3. Calculate effective rate per minute with intelcallfee app fee rule
  IF v_rate.cost_per_minute_usd IS NOT NULL AND v_rate.cost_per_minute_usd > 0 THEN
    v_fee := public.resolve_app_fee('intelcallfee', v_tier, v_rate.cost_per_minute_usd);
    IF v_fee IS NULL THEN
      -- Fallback to default draft percentages if no rule in table
      v_fee := CASE v_tier
        WHEN 'premium'  THEN round(v_rate.cost_per_minute_usd * 0.05, 4)
        WHEN 'standard' THEN round(v_rate.cost_per_minute_usd * 0.10, 4)
        ELSE round(v_rate.cost_per_minute_usd * 0.15, 4)
      END;
    END IF;
    v_effective := round(v_rate.cost_per_minute_usd + v_fee, 4);
  ELSE
    v_effective := v_rate.rate_per_minute_usd;
  END IF;

  RETURN QUERY
  SELECT
    v_rate.id,
    v_rate.country_code,
    v_rate.country_name,
    v_rate.phone_prefix,
    v_effective AS rate_per_minute_usd,
    v_rate.cost_per_minute_usd,
    0.00::NUMERIC AS connection_fee_usd,
    v_rate.billing_increment_seconds,
    v_tier AS account_tier;
END;
$function$;


CREATE OR REPLACE FUNCTION public.get_user_calling_rates(p_user_id uuid DEFAULT auth.uid())
 RETURNS TABLE(id uuid, country_code text, country_name text, phone_prefix text, destination_type text, cost_per_minute_usd numeric, base_rate_per_minute_usd numeric, effective_rate_per_minute_usd numeric, connection_fee_usd numeric, billing_increment_seconds integer, account_tier text, is_active boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_tier TEXT;
BEGIN

  IF COALESCE(auth.jwt()->>'role', '') <> 'service_role' THEN
    IF auth.uid() IS NULL OR p_user_id IS DISTINCT FROM auth.uid() THEN
      RAISE EXCEPTION 'Own authenticated account required' USING ERRCODE = '42501';
    END IF;
  END IF;
  v_tier := public.resolve_account_commerce_benefit(p_user_id);
  
  RETURN QUERY
  SELECT 
    r.id,
    r.country_code,
    r.country_name,
    r.phone_prefix,
    r.destination_type,
    r.cost_per_minute_usd,
    r.rate_per_minute_usd AS base_rate_per_minute_usd,
    round(
      CASE 
        WHEN r.cost_per_minute_usd IS NOT NULL AND r.cost_per_minute_usd > 0 THEN
          r.cost_per_minute_usd + COALESCE(
            public.resolve_app_fee('intelcallfee', v_tier, r.cost_per_minute_usd),
            CASE v_tier
              WHEN 'premium'  THEN round(r.cost_per_minute_usd * 0.05, 4)
              WHEN 'standard' THEN round(r.cost_per_minute_usd * 0.10, 4)
              ELSE round(r.cost_per_minute_usd * 0.15, 4)
            END
          )
        ELSE r.rate_per_minute_usd
      END,
      4
    ) AS effective_rate_per_minute_usd,
    0.00::NUMERIC AS connection_fee_usd, -- Strictly $0 connection fee per C12
    r.billing_increment_seconds,
    v_tier AS account_tier,
    r.is_active
  FROM public.call_rates r
  WHERE r.is_active = true
  ORDER BY r.country_name;
END;
$function$;


-- Preserve the guarded admin route using the actual audit-table contract.
CREATE OR REPLACE FUNCTION public.admin_prune_database_logs(p_cron_retention_days integer DEFAULT 14, p_alerts_retention_days integer DEFAULT 90)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_actor_id uuid;
  v_actor_email text;
  v_result jsonb;
BEGIN
  PERFORM public.assert_admin();

  v_actor_id := auth.uid();
  v_actor_email := public.current_user_email();

  v_result := public.prune_database_logs(p_cron_retention_days, p_alerts_retention_days);

  INSERT INTO public.admin_audit_log (
    actor_id,
    actor_email,
    action,
    target_type,
    target_id,
    after_value
  ) VALUES (
    v_actor_id,
    v_actor_email,
    'prune_database_logs',
    'maintenance',
    'database_logs',
    v_result
  );

  RETURN v_result;
END;
$function$;

COMMIT;
