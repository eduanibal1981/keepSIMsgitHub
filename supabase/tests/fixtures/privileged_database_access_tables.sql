-- Isolated authorization fixture, captured live column types on 2026-10-17.
-- No production data. Constraints/triggers are omitted: this is not a money test.
CREATE TABLE public.admin_audit_log (
  "id" uuid,
  "created_at" timestamp with time zone,
  "actor_id" uuid,
  "actor_email" text,
  "action" text,
  "target_type" text,
  "target_id" text,
  "before_value" jsonb,
  "after_value" jsonb,
  "note" text
);

CREATE TABLE public.app_fee_rules (
  "id" uuid,
  "appfees_item" text,
  "version" integer,
  "free_percentage" numeric(12,6),
  "free_minimum" numeric(18,6),
  "stand_percentage" numeric(12,6),
  "stand_minimum" numeric(18,6),
  "prem_percentage" numeric(12,6),
  "prem_minimum" numeric(18,6),
  "currency" text,
  "fee_basis" text,
  "charge_unit" text,
  "status" text,
  "effective_from" timestamp with time zone,
  "effective_to" timestamp with time zone,
  "change_reason" text,
  "created_at" timestamp with time zone,
  "created_by" uuid,
  "published_at" timestamp with time zone,
  "published_by" uuid
);

CREATE TABLE public.call_rates (
  "id" uuid,
  "country_code" text,
  "country_name" text,
  "phone_prefix" text,
  "destination_type" text,
  "cost_per_minute_usd" numeric(10,5),
  "rate_per_minute_usd" numeric(10,5),
  "connection_fee_usd" numeric(10,4),
  "billing_increment_seconds" integer,
  "is_active" boolean,
  "created_at" timestamp with time zone,
  "updated_at" timestamp with time zone
);

CREATE TABLE public.carriers (
  "id" uuid,
  "country_id" uuid,
  "name" text,
  "logo_url" text,
  "is_supported" boolean,
  "created_at" timestamp with time zone,
  "fulfillment_gateway" character varying,
  "default_refill_amount" numeric,
  "gateway_phone_number" text
);

CREATE TABLE public.countries (
  "id" uuid,
  "name" text,
  "iso_code" text,
  "dialing_code" text,
  "flag_emoji" text,
  "currency_code" text,
  "avg_sim_replacement_cost" numeric(10,2),
  "is_supported" boolean,
  "created_at" timestamp with time zone,
  "whatsapp_server_url" text,
  "whatsapp_account_phone" text,
  "sms_verify_cost" numeric(12,2),
  "call_verify_cost" numeric(12,2),
  "verification_price_version" integer
);

CREATE TABLE public.line_activity_log (
  "id" uuid,
  "sim_line_id" uuid,
  "user_id" uuid,
  "event_type" text,
  "description" text,
  "metadata" jsonb,
  "created_at" timestamp with time zone
);

CREATE TABLE public.line_verification_allowances (
  "id" uuid,
  "sim_line_id" uuid,
  "period_start" timestamp with time zone,
  "period_end" timestamp with time zone,
  "reserved_attempt_id" uuid,
  "consumed_attempt_id" uuid,
  "created_at" timestamp with time zone,
  "updated_at" timestamp with time zone
);

CREATE TABLE public.line_verification_attempts (
  "id" uuid,
  "sim_line_id" uuid,
  "user_id" uuid,
  "method" text,
  "destination_phone" text,
  "country_id" uuid,
  "retail_price" numeric(12,2),
  "funding_kind" text,
  "wallet_hold_id" uuid,
  "provider" text,
  "provider_resource_id" text,
  "status" text,
  "outcome" text,
  "settlement_status" text,
  "error_message" text,
  "carrier_name" text,
  "price_version" integer,
  "idempotency_key" text,
  "dispatched_at" timestamp with time zone,
  "completed_at" timestamp with time zone,
  "created_at" timestamp with time zone,
  "updated_at" timestamp with time zone
);

CREATE TABLE public.refill_approval_quotes (
  "id" uuid,
  "execution_id" uuid,
  "requested_by" uuid,
  "execution_snapshot" jsonb,
  "status" text,
  "route" jsonb,
  "error_message" text,
  "created_at" timestamp with time zone,
  "expires_at" timestamp with time zone
);

CREATE TABLE public.return_trip_packages (
  "id" uuid,
  "country_id" uuid,
  "carrier_id" uuid,
  "package_type" text,
  "title" text,
  "description" text,
  "data_allowance_mb" integer,
  "duration_days" integer,
  "is_unlimited" boolean,
  "supplier_cost_usd" numeric(10,2),
  "retail_price_usd" numeric(10,2),
  "ussd_recharge_code" text,
  "activation_instructions" text,
  "badge_label" text,
  "is_active" boolean,
  "created_at" timestamp with time zone,
  "updated_at" timestamp with time zone
);

CREATE TABLE public.return_trips (
  "id" uuid,
  "user_id" uuid,
  "sim_line_id" uuid,
  "destination_country_id" uuid,
  "arrival_date" date,
  "status" text,
  "chosen_package_type" text,
  "chosen_package_id" uuid,
  "notes" text,
  "created_at" timestamp with time zone,
  "updated_at" timestamp with time zone
);

CREATE TABLE public.scheduled_job_registry (
  "job_name" text,
  "job_id" integer,
  "owner" text,
  "category" text,
  "expected_schedule" text,
  "freshness_threshold_minutes" integer,
  "max_consecutive_failures" integer,
  "is_critical" boolean,
  "description" text,
  "created_at" timestamp with time zone,
  "updated_at" timestamp with time zone
);

CREATE TABLE public.sim_lines (
  "id" uuid,
  "user_id" uuid,
  "phone_number" text,
  "nickname" text,
  "avatar_icon" text,
  "country_id" uuid,
  "carrier_id" uuid,
  "carrier_rule_id" uuid,
  "status" text,
  "health_score" integer,
  "last_topup_at" timestamp with time zone,
  "next_topup_due" timestamp with time zone,
  "validity_expires_at" timestamp with time zone,
  "protection_tier" text,
  "is_auto_detected" boolean,
  "household_id" uuid,
  "created_at" timestamp with time zone,
  "updated_at" timestamp with time zone,
  "verification_status" text,
  "is_home_mode" boolean,
  "plan_type" character varying(20),
  "plan_expires_at" timestamp with time zone,
  "carrier_pricing_id" uuid,
  "protection_paused" boolean,
  "requires_protection_at_home" boolean,
  "is_carrier_verified" boolean,
  "carrier_status" text,
  "detected_operator_name" text,
  "carrier_verified_at" timestamp with time zone,
  "notification_entitlement_verified" boolean
);

CREATE TABLE public.system_alerts (
  "id" uuid,
  "created_at" timestamp with time zone,
  "kind" text,
  "message" text,
  "details" jsonb
);

CREATE TABLE public.topup_executions (
  "id" uuid,
  "scheduled_topup_id" uuid,
  "sim_line_id" uuid,
  "user_id" uuid,
  "amount" numeric(10,2),
  "currency" text,
  "reloadly_transaction_id" text,
  "status" text,
  "failure_reason" text,
  "retry_of" uuid,
  "validity_days_added" integer,
  "executed_at" timestamp with time zone,
  "completed_at" timestamp with time zone,
  "created_at" timestamp with time zone,
  "fulfillment_gateway" character varying,
  "api_provider" character varying,
  "execution_type" character varying,
  "execution_time" timestamp with time zone,
  "offer_id" character varying,
  "offer_value" bigint,
  "payment_gateway_code" text,
  "base_cost_usd" numeric,
  "gateway_fee_usd" numeric,
  "app_fee_usd" numeric,
  "processing_since" timestamp with time zone,
  "pre_processing_status" text,
  "reaper_retries" integer,
  "refill_channel" text,
  "message_fee_usd" numeric,
  "acting_user_id" uuid,
  "attempted_providers" text[],
  "pin_code" text,
  "pin_serial" text,
  "redeem_instructions" text,
  "updated_at" timestamp with time zone,
  "wallet_hold_id" uuid,
  "funding_kind" text,
  "target_local_value" numeric,
  "target_local_currency" text,
  "max_authorized_usd" numeric,
  "quoted_cost_usd" numeric,
  "quoted_fee_usd" numeric,
  "quote_id" uuid,
  "engine_version" integer,
  "intent_kind" text,
  "carrier_in_flight" boolean
);

CREATE TABLE public.wallet_holds (
  "id" uuid,
  "wallet_id" uuid,
  "user_id" uuid,
  "order_type" text,
  "order_reference_id" text,
  "amount" numeric,
  "currency" text,
  "status" text,
  "reason" text,
  "captured_at" timestamp with time zone,
  "released_at" timestamp with time zone,
  "expires_at" timestamp with time zone,
  "created_at" timestamp with time zone,
  "updated_at" timestamp with time zone,
  "carrier_in_flight" boolean
);

CREATE TABLE public.wallets (
  "id" uuid,
  "user_id" uuid,
  "balance" numeric(12,2),
  "currency" text,
  "auto_fund_enabled" boolean,
  "auto_fund_threshold" numeric(10,2),
  "auto_fund_amount" numeric(10,2),
  "total_deposited" numeric(12,2),
  "total_spent" numeric(12,2),
  "created_at" timestamp with time zone,
  "updated_at" timestamp with time zone
);

CREATE TABLE public.whatsapp_provider_profiles (
  "id" uuid,
  "provider_kind" text,
  "label" text,
  "expected_sender_number" text,
  "observed_sender_number" text,
  "is_enabled" boolean,
  "ready_state" text,
  "version" integer,
  "last_probe_at" timestamp with time zone,
  "last_error_category" text,
  "last_error_detail" text,
  "connection_metadata" jsonb,
  "created_at" timestamp with time zone,
  "updated_at" timestamp with time zone,
  "created_by" uuid,
  "updated_by" uuid
);
