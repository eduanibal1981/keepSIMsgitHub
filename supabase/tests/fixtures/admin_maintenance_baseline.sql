-- ISOLATED ONLY: maintenance extension; load notification_scheduler_baseline.sql first.

SET check_function_bodies=false;

CREATE TABLE IF NOT EXISTS "public"."account_deletions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "email_hash" "text" NOT NULL,
    "status" "text" DEFAULT 'requested'::"text" NOT NULL,
    "wallet_balance_at_request" numeric(10,2) DEFAULT 0.00 NOT NULL,
    "dust_forfeited" boolean DEFAULT false NOT NULL,
    "reason" "text",
    "actor_id" "uuid",
    "ip_address" "text",
    "requested_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "scheduled_purge_at" timestamp with time zone NOT NULL,
    "frozen_at" timestamp with time zone,
    "drained_at" timestamp with time zone,
    "purged_at" timestamp with time zone,
    "auth_deleted_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "account_deletions_status_check" CHECK (("status" = ANY (ARRAY['requested'::"text", 'frozen'::"text", 'draining'::"text", 'drained'::"text", 'purged'::"text", 'auth_deleted'::"text", 'cancelled'::"text"])))
);

CREATE TABLE IF NOT EXISTS "public"."admin_audit_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "actor_id" "uuid",
    "actor_email" "text",
    "action" "text" NOT NULL,
    "target_type" "text" NOT NULL,
    "target_id" "text",
    "before_value" "jsonb",
    "after_value" "jsonb",
    "note" "text"
);

CREATE TABLE IF NOT EXISTS "public"."security_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "event_type" "text" NOT NULL,
    "description" "text",
    "metadata" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"()
);

CREATE TABLE IF NOT EXISTS "public"."wallet_funding_lots" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "wallet_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "origin_type" "text" NOT NULL,
    "original_reference_id" "text",
    "original_order_id" "text",
    "currency" "text" DEFAULT 'USD'::"text" NOT NULL,
    "funded_amount" numeric NOT NULL,
    "remaining_amount" numeric NOT NULL,
    "is_refundable" boolean DEFAULT false NOT NULL,
    "refund_deadline" timestamp with time zone,
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "wallet_funding_lots_check" CHECK ((("remaining_amount" >= (0)::numeric) AND ("remaining_amount" <= "funded_amount"))),
    CONSTRAINT "wallet_funding_lots_funded_amount_check" CHECK (("funded_amount" >= (0)::numeric)),
    CONSTRAINT "wallet_funding_lots_origin_type_check" CHECK (("origin_type" = ANY (ARRAY['paypal_deposit'::"text", 'card_deposit'::"text", 'promotional'::"text", 'gift_received'::"text", 'admin_adjustment'::"text", 'unverified_legacy'::"text"]))),
    CONSTRAINT "wallet_funding_lots_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'fully_consumed'::"text", 'partially_refunded'::"text", 'fully_refunded'::"text", 'disputed'::"text", 'restricted'::"text"])))
);

CREATE TABLE IF NOT EXISTS "public"."wallet_refund_requests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "wallet_id" "uuid" NOT NULL,
    "requested_amount" numeric NOT NULL,
    "currency" "text" DEFAULT 'USD'::"text" NOT NULL,
    "hold_id" "uuid",
    "status" "text" DEFAULT 'requested'::"text" NOT NULL,
    "rejection_reason" "text",
    "audit_notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "wallet_refund_requests_requested_amount_check" CHECK (("requested_amount" > (0)::numeric)),
    CONSTRAINT "wallet_refund_requests_status_check" CHECK (("status" = ANY (ARRAY['requested'::"text", 'processing'::"text", 'completed'::"text", 'partially_completed'::"text", 'failed'::"text", 'cancelled'::"text", 'under_review'::"text"])))
);

CREATE TABLE IF NOT EXISTS "public"."wallet_transactions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "wallet_id" "uuid" NOT NULL,
    "user_id" "uuid",
    "type" "text" NOT NULL,
    "amount" numeric(10,2) NOT NULL,
    "balance_before" numeric(12,2) NOT NULL,
    "balance_after" numeric(12,2) NOT NULL,
    "description" "text",
    "reference_id" "text",
    "sim_line_id" "uuid",
    "status" "text" DEFAULT 'completed'::"text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "wallet_transactions_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'completed'::"text", 'failed'::"text", 'reversed'::"text"]))),
    CONSTRAINT "wallet_transactions_type_check" CHECK (("type" = ANY (ARRAY['deposit'::"text", 'topup_debit'::"text", 'refund'::"text", 'referral_credit'::"text", 'referral_withdrawal'::"text", 'plan_fee_debit'::"text", 'home_mode_debit'::"text", 'auto_fund'::"text", 'esim_purchase_debit'::"text", 'esim_purchase_refund'::"text", 'wallet_settlement'::"text", 'wallet_forfeit'::"text", 'gift_sent'::"text", 'gift_received'::"text", 'admin_adjustment'::"text", 'offline_voucher_debit'::"text", 'call_debit'::"text", 'call_refund'::"text", 'did_purchase_debit'::"text"])))
);

CREATE TABLE IF NOT EXISTS "public"."user_esims" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "order_id" "uuid" NOT NULL,
    "iccid" "text" NOT NULL,
    "smdp_address" "text" NOT NULL,
    "matching_id" "text" NOT NULL,
    "lpa_string" "text" NOT NULL,
    "bundle_name" "text" NOT NULL,
    "provider" "text" DEFAULT 'esim_go'::"text" NOT NULL,
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    "purchased_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "expires_at" timestamp with time zone,
    "data_total_mb" bigint NOT NULL,
    "data_remaining_mb" bigint NOT NULL,
    "last_usage_check" timestamp with time zone,
    "low_data_notified" boolean DEFAULT false NOT NULL,
    CONSTRAINT "user_esims_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'expired'::"text", 'depleted'::"text", 'installed'::"text"])))
);

CREATE TABLE IF NOT EXISTS "public"."esim_orders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "provider" "text" DEFAULT 'esim_go'::"text" NOT NULL,
    "bundle_name" "text" NOT NULL,
    "quantity" integer DEFAULT 1 NOT NULL,
    "wholesale_price_usd" numeric(10,4) NOT NULL,
    "retail_price_usd" numeric(10,2) NOT NULL,
    "markup_percent" numeric(5,2) NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "provider_order_ref" "text",
    "error_message" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "offer_id" "text",
    "total_amount_usd" numeric(10,2),
    CONSTRAINT "esim_orders_quantity_check" CHECK ((("quantity" >= 1) AND ("quantity" <= 3))),
    CONSTRAINT "esim_orders_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'processing'::"text", 'completed'::"text", 'failed'::"text", 'refunded'::"text"])))
);

CREATE TABLE IF NOT EXISTS "public"."admin_emails" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_by" "uuid",
    "from_address" "text" NOT NULL,
    "to_addresses" "text"[] NOT NULL,
    "cc_addresses" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "reply_to" "text",
    "subject" "text" NOT NULL,
    "body_text" "text" NOT NULL,
    "status" "text" DEFAULT 'queued'::"text" NOT NULL,
    "provider_message_id" "text",
    "error" "text",
    "sent_at" timestamp with time zone,
    "note" "text",
    CONSTRAINT "admin_emails_status_check" CHECK (("status" = ANY (ARRAY['queued'::"text", 'sending'::"text", 'sent'::"text", 'failed'::"text"])))
);

CREATE TABLE IF NOT EXISTS "public"."virtual_did_numbers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "phone_number" "text" NOT NULL,
    "country_code" "text" NOT NULL,
    "country_name" "text" NOT NULL,
    "provider" "text" DEFAULT 'telnyx'::"text" NOT NULL,
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    "monthly_fee_usd" numeric DEFAULT 1.50 NOT NULL,
    "forward_mode" "text" DEFAULT 'app'::"text" NOT NULL,
    "forward_destination" "text",
    "auto_renew" boolean DEFAULT true NOT NULL,
    "renews_at" timestamp with time zone DEFAULT ("now"() + '30 days'::interval) NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "virtual_did_numbers_forward_mode_check" CHECK (("forward_mode" = ANY (ARRAY['app'::"text", 'pstn'::"text", 'voicemail'::"text", 'sim_roaming'::"text"]))),
    CONSTRAINT "virtual_did_numbers_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'suspended'::"text", 'released'::"text"])))
);

CREATE TABLE IF NOT EXISTS "public"."call_records" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "sim_line_id" "uuid",
    "call_type" "text" DEFAULT 'two_way_callback'::"text" NOT NULL,
    "caller_number" "text" NOT NULL,
    "destination_number" "text" NOT NULL,
    "destination_country_code" "text",
    "destination_country_name" "text",
    "telnyx_call_control_id_leg_a" "text",
    "telnyx_call_control_id_leg_b" "text",
    "telnyx_call_session_id" "text",
    "status" "text" DEFAULT 'initiated'::"text" NOT NULL,
    "started_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "answered_at" timestamp with time zone,
    "ended_at" timestamp with time zone,
    "duration_seconds" integer DEFAULT 0 NOT NULL,
    "billed_duration_seconds" integer DEFAULT 0 NOT NULL,
    "rate_per_minute_usd" numeric(10,5) NOT NULL,
    "total_cost_usd" numeric(10,4) DEFAULT 0.0000 NOT NULL,
    "wallet_txn_id" "uuid",
    "error_message" "text",
    "raw_cdr" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "requested_caller_id" "text",
    "effective_caller_id" "text",
    "caller_id_type" "text" DEFAULT 'gateway'::"text",
    "policy_reason" "text",
    "policy_version" "text" DEFAULT '2026-09-17'::"text",
    "sip_hangup_cause" integer,
    "telnyx_hangup_cause" "text",
    "hangup_source" "text",
    "cancellation_requested_at" timestamp with time zone,
    "idempotency_key" "text",
    "billing_increment_seconds" integer DEFAULT 60,
    CONSTRAINT "call_records_call_type_check" CHECK (("call_type" = ANY (ARRAY['two_way_callback'::"text", 'app_to_phone_webrtc'::"text", 'outbound_direct'::"text"]))),
    CONSTRAINT "call_records_caller_id_type_check" CHECK (("caller_id_type" = ANY (ARRAY['gateway'::"text", 'verified_number'::"text"]))),
    CONSTRAINT "call_records_status_check" CHECK (("status" = ANY (ARRAY['initiated'::"text", 'ringing'::"text", 'in_progress'::"text", 'completed'::"text", 'declined'::"text", 'busy'::"text", 'failed'::"text", 'no_answer'::"text", 'cancelled'::"text"])))
);

ALTER TABLE public."account_deletions" ADD CONSTRAINT "account_deletions_pkey" PRIMARY KEY (id);

ALTER TABLE public."esim_orders" ADD CONSTRAINT "esim_orders_pkey" PRIMARY KEY (id);

ALTER TABLE public."user_esims" ADD CONSTRAINT "user_esims_pkey" PRIMARY KEY (id);

ALTER TABLE public."wallet_transactions" ADD CONSTRAINT "wallet_transactions_pkey" PRIMARY KEY (id);

ALTER TABLE public."admin_audit_log" ADD CONSTRAINT "admin_audit_log_pkey" PRIMARY KEY (id);

ALTER TABLE public."security_logs" ADD CONSTRAINT "security_logs_pkey" PRIMARY KEY (id);

ALTER TABLE public."admin_emails" ADD CONSTRAINT "admin_emails_pkey" PRIMARY KEY (id);

ALTER TABLE public."virtual_did_numbers" ADD CONSTRAINT "virtual_did_numbers_pkey" PRIMARY KEY (id);

ALTER TABLE public."call_records" ADD CONSTRAINT "call_records_pkey" PRIMARY KEY (id);

ALTER TABLE public."wallet_funding_lots" ADD CONSTRAINT "wallet_funding_lots_pkey" PRIMARY KEY (id);

ALTER TABLE public."wallet_refund_requests" ADD CONSTRAINT "wallet_refund_requests_pkey" PRIMARY KEY (id);

ALTER TABLE public."account_deletions" ADD CONSTRAINT "account_deletions_user_id_key" UNIQUE (user_id);

ALTER TABLE public."user_esims" ADD CONSTRAINT "user_esims_iccid_key" UNIQUE (iccid);

ALTER TABLE public."virtual_did_numbers" ADD CONSTRAINT "virtual_did_numbers_phone_number_key" UNIQUE (phone_number);

ALTER TABLE public."esim_orders" ADD CONSTRAINT "esim_orders_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public."user_esims" ADD CONSTRAINT "user_esims_order_id_fkey" FOREIGN KEY (order_id) REFERENCES esim_orders(id) ON DELETE CASCADE;

ALTER TABLE public."user_esims" ADD CONSTRAINT "user_esims_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public."wallet_transactions" ADD CONSTRAINT "wallet_transactions_sim_line_id_fkey" FOREIGN KEY (sim_line_id) REFERENCES sim_lines(id) ON DELETE SET NULL;

ALTER TABLE public."wallet_transactions" ADD CONSTRAINT "wallet_transactions_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public."wallet_transactions" ADD CONSTRAINT "wallet_transactions_wallet_id_fkey" FOREIGN KEY (wallet_id) REFERENCES wallets(id) ON DELETE CASCADE;

ALTER TABLE public."admin_audit_log" ADD CONSTRAINT "admin_audit_log_actor_id_fkey" FOREIGN KEY (actor_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public."security_logs" ADD CONSTRAINT "security_logs_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public."admin_emails" ADD CONSTRAINT "admin_emails_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public."virtual_did_numbers" ADD CONSTRAINT "virtual_did_numbers_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public."call_records" ADD CONSTRAINT "call_records_sim_line_id_fkey" FOREIGN KEY (sim_line_id) REFERENCES sim_lines(id) ON DELETE SET NULL;

ALTER TABLE public."call_records" ADD CONSTRAINT "call_records_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public."call_records" ADD CONSTRAINT "call_records_wallet_txn_id_fkey" FOREIGN KEY (wallet_txn_id) REFERENCES wallet_transactions(id) ON DELETE SET NULL;

ALTER TABLE public."wallet_funding_lots" ADD CONSTRAINT "wallet_funding_lots_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public."wallet_funding_lots" ADD CONSTRAINT "wallet_funding_lots_wallet_id_fkey" FOREIGN KEY (wallet_id) REFERENCES wallets(id) ON DELETE CASCADE;

ALTER TABLE public."wallet_refund_requests" ADD CONSTRAINT "wallet_refund_requests_hold_id_fkey" FOREIGN KEY (hold_id) REFERENCES wallet_holds(id) ON DELETE SET NULL;

ALTER TABLE public."wallet_refund_requests" ADD CONSTRAINT "wallet_refund_requests_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public."wallet_refund_requests" ADD CONSTRAINT "wallet_refund_requests_wallet_id_fkey" FOREIGN KEY (wallet_id) REFERENCES wallets(id) ON DELETE CASCADE;

CREATE INDEX idx_user_esims_user_id ON public.user_esims USING btree (user_id);

CREATE INDEX idx_wallet_transactions_wallet_id ON public.wallet_transactions USING btree (wallet_id);

CREATE INDEX idx_wallet_transactions_user_id ON public.wallet_transactions USING btree (user_id);

CREATE INDEX idx_wallet_transactions_sim_line_id ON public.wallet_transactions USING btree (sim_line_id);

CREATE INDEX idx_wallet_transactions_created_at ON public.wallet_transactions USING btree (created_at DESC);

CREATE INDEX idx_wallet_transactions_type ON public.wallet_transactions USING btree (type);

CREATE UNIQUE INDEX uq_wallet_txns_esim_refund_ref ON public.wallet_transactions USING btree (reference_id) WHERE (type = 'esim_purchase_refund'::text);

CREATE UNIQUE INDEX uq_wallet_txns_gift_sent_ref ON public.wallet_transactions USING btree (reference_id) WHERE ((type = 'gift_sent'::text) AND (reference_id IS NOT NULL));

CREATE UNIQUE INDEX uq_wallet_txns_gift_received_ref ON public.wallet_transactions USING btree (reference_id) WHERE ((type = 'gift_received'::text) AND (reference_id IS NOT NULL));

CREATE UNIQUE INDEX uq_wallet_transactions_debit_ref ON public.wallet_transactions USING btree (reference_id) WHERE ((type = 'topup_debit'::text) AND (reference_id IS NOT NULL));

CREATE UNIQUE INDEX uq_wallet_transactions_refund_ref ON public.wallet_transactions USING btree (reference_id) WHERE ((type = 'refund'::text) AND (reference_id IS NOT NULL));

CREATE UNIQUE INDEX uq_wallet_transactions_paypal_capture ON public.wallet_transactions USING btree (reference_id) WHERE ((type = 'deposit'::text) AND (reference_id ~~ 'paypal_%'::text));

CREATE UNIQUE INDEX uq_wallet_transactions_plan_fee_ref ON public.wallet_transactions USING btree (reference_id) WHERE ((type = 'plan_fee_debit'::text) AND (reference_id IS NOT NULL));

CREATE UNIQUE INDEX uq_wallet_txns_referral_credit_ref ON public.wallet_transactions USING btree (reference_id) WHERE ((type = 'referral_credit'::text) AND (reference_id ~~ 'refredeem_%'::text));

CREATE UNIQUE INDEX uq_wallet_txns_esim_debit ON public.wallet_transactions USING btree (reference_id) WHERE (type = 'esim_purchase_debit'::text);

CREATE INDEX idx_admin_audit_created ON public.admin_audit_log USING btree (created_at DESC);

CREATE INDEX idx_admin_audit_target ON public.admin_audit_log USING btree (target_type, target_id, created_at DESC);

CREATE INDEX idx_admin_audit_actor ON public.admin_audit_log USING btree (actor_id, created_at DESC);

CREATE INDEX idx_admin_emails_status ON public.admin_emails USING btree (status, created_at DESC);

CREATE INDEX idx_admin_emails_created ON public.admin_emails USING btree (created_at DESC);

CREATE INDEX idx_virtual_dids_user ON public.virtual_did_numbers USING btree (user_id, status);

CREATE INDEX idx_virtual_dids_phone ON public.virtual_did_numbers USING btree (phone_number);

CREATE INDEX idx_call_records_user ON public.call_records USING btree (user_id, created_at DESC);

CREATE INDEX idx_call_records_session ON public.call_records USING btree (telnyx_call_session_id);

CREATE INDEX idx_call_records_leg_a ON public.call_records USING btree (telnyx_call_control_id_leg_a);

CREATE INDEX idx_call_records_leg_b ON public.call_records USING btree (telnyx_call_control_id_leg_b);

CREATE INDEX idx_call_records_sim_line_id ON public.call_records USING btree (sim_line_id);

CREATE INDEX idx_call_records_idempotency_key ON public.call_records USING btree (idempotency_key) WHERE (idempotency_key IS NOT NULL);

CREATE INDEX idx_call_records_sip_cause ON public.call_records USING btree (sip_hangup_cause);

CREATE INDEX idx_call_records_effective_caller ON public.call_records USING btree (effective_caller_id);

CREATE UNIQUE INDEX uq_wallet_funding_lots_user_ref ON public.wallet_funding_lots USING btree (user_id, original_reference_id) WHERE (original_reference_id IS NOT NULL);

CREATE INDEX idx_wallet_funding_lots_user_active ON public.wallet_funding_lots USING btree (user_id, status, created_at);

CREATE INDEX idx_wallet_refund_requests_user ON public.wallet_refund_requests USING btree (user_id, created_at DESC);

CREATE OR REPLACE FUNCTION "public"."admin_purge_user_account"("p_user_id" "uuid", "p_confirm_user_id" "text", "p_reason" "text" DEFAULT 'Manual admin purge with user_id verification challenge'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_admin_id uuid;
  v_secret   text;
  v_req_id   bigint;
BEGIN
  -- 1. Assert admin authorization
  v_admin_id := public.assert_admin();

  -- 2. Strict Confirmation Challenge: confirm_user_id must match p_user_id
  IF p_confirm_user_id IS NULL OR lower(trim(p_confirm_user_id)) <> lower(p_user_id::text) THEN
    RAISE EXCEPTION 'Confirmation failed: Typed user ID does not match target user ID'
      USING ERRCODE = 'KS400',
            HINT = 'You must type the exact UUID of the user to confirm this destructive purge.';
  END IF;

  -- 3. Read internal secret from Vault
  SELECT decrypted_secret INTO v_secret
    FROM vault.decrypted_secrets WHERE name = 'dispatch_shared_secret';
  IF COALESCE(v_secret, '') = '' THEN
    RAISE EXCEPTION 'Internal dispatch_shared_secret missing from Vault'
      USING ERRCODE = 'KS500';
  END IF;

  -- 4. Mark or insert account_deletions row with status 'purged'
  INSERT INTO public.account_deletions (
    user_id, status, requested_at, purged_at, de_identified_at, note
  )
  VALUES (
    p_user_id, 'purged', pg_catalog.now(), pg_catalog.now(), pg_catalog.now(),
    'Manual admin purge: ' || COALESCE(p_reason, 'No reason specified')
  )
  ON CONFLICT (user_id) DO UPDATE SET
    status = 'purged',
    purged_at = pg_catalog.now(),
    note = 'Manual admin purge: ' || COALESCE(p_reason, 'No reason specified');

  -- 5. Trigger purge-accounts Edge Function via pg_net
  SELECT net.http_post(
    url := 'https://zwxswagokhgbuzrrbnhr.supabase.co/functions/v1/purge-accounts',
    headers := pg_catalog.jsonb_build_object(
      'Content-Type', 'application/json',
      'x-keep-sims-secret', v_secret
    ),
    body := pg_catalog.jsonb_build_object(
      'user_id', p_user_id,
      'admin_purge', true,
      'confirm_user_id', p_user_id::text,
      'reason', p_reason
    ),
    timeout_milliseconds := 15000
  ) INTO v_req_id;

  -- 6. Audit in admin_audit_log
  PERFORM public.admin_log(
    'user.admin_purge',
    'user',
    p_user_id::text,
    pg_catalog.jsonb_build_object('admin_id', v_admin_id),
    pg_catalog.jsonb_build_object('net_request_id', v_req_id, 'status', 'purged'),
    p_reason
  );

  RETURN pg_catalog.jsonb_build_object(
    'status', 'ok',
    'user_id', p_user_id,
    'net_request_id', v_req_id,
    'message', 'Purge initiated successfully with confirmation challenge'
  );
END;
$$;

REVOKE ALL ON FUNCTION public."admin_purge_user_account"(uuid, text, text) FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public."admin_purge_user_account"(uuid, text, text) TO authenticated;

GRANT EXECUTE ON FUNCTION public."admin_purge_user_account"(uuid, text, text) TO service_role;

CREATE OR REPLACE FUNCTION "public"."admin_prune_database_logs"("p_cron_retention_days" integer DEFAULT 14, "p_alerts_retention_days" integer DEFAULT 90) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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
    details
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
$$;

REVOKE ALL ON FUNCTION public."admin_prune_database_logs"(integer, integer) FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public."admin_prune_database_logs"(integer, integer) TO authenticated;

GRANT EXECUTE ON FUNCTION public."admin_prune_database_logs"(integer, integer) TO service_role;

CREATE OR REPLACE FUNCTION "public"."prune_database_logs"("p_cron_retention_days" integer DEFAULT 14, "p_alerts_retention_days" integer DEFAULT 90) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_cron_deleted integer := 0;
  v_alerts_deleted integer := 0;
  v_cutoff_cron timestamptz;
  v_cutoff_alerts timestamptz;
BEGIN
  -- Validate sane bounds to prevent accidental total wipe
  IF p_cron_retention_days < 3 THEN
    RAISE EXCEPTION 'p_cron_retention_days must be at least 3 days';
  END IF;
  IF p_alerts_retention_days < 7 THEN
    RAISE EXCEPTION 'p_alerts_retention_days must be at least 7 days';
  END IF;

  v_cutoff_cron := pg_catalog.now() - (p_cron_retention_days || ' days')::interval;
  v_cutoff_alerts := pg_catalog.now() - (p_alerts_retention_days || ' days')::interval;

  -- Prune cron.job_run_details
  WITH deleted_cron AS (
    DELETE FROM cron.job_run_details
    WHERE start_time < v_cutoff_cron
    RETURNING 1
  )
  SELECT count(*)::integer INTO v_cron_deleted FROM deleted_cron;

  -- Prune public.system_alerts
  WITH deleted_alerts AS (
    DELETE FROM public.system_alerts
    WHERE created_at < v_cutoff_alerts
    RETURNING 1
  )
  SELECT count(*)::integer INTO v_alerts_deleted FROM deleted_alerts;

  RETURN pg_catalog.jsonb_build_object(
    'status', 'success',
    'cron_runs_pruned', v_cron_deleted,
    'cron_retention_days', p_cron_retention_days,
    'cron_cutoff', v_cutoff_cron,
    'alerts_pruned', v_alerts_deleted,
    'alerts_retention_days', p_alerts_retention_days,
    'alerts_cutoff', v_cutoff_alerts,
    'executed_at', pg_catalog.now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public."prune_database_logs"(integer, integer) FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public."prune_database_logs"(integer, integer) TO authenticated;

GRANT EXECUTE ON FUNCTION public."prune_database_logs"(integer, integer) TO service_role;

CREATE OR REPLACE FUNCTION "public"."check_rate_limit_health"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_raw_claims text;
  v_jwt_role text;
  v_count int;
BEGIN
  v_raw_claims := current_setting('request.jwt.claims', true);
  IF v_raw_claims IS NOT NULL AND v_raw_claims <> '' THEN
    v_jwt_role := (v_raw_claims::jsonb) ->> 'role';
    IF v_jwt_role IS DISTINCT FROM 'service_role' THEN
      RAISE EXCEPTION 'check_rate_limit_health is not callable by role %', COALESCE(v_jwt_role, '<none>')
        USING ERRCODE = 'KS403';
    END IF;
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM public.security_logs
  WHERE event_type = 'rate_limited'
    AND created_at > (NOW() - INTERVAL '1 hour');

  IF v_count >= 20 THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.system_alerts
      WHERE kind = 'sustained_rate_limits'
        AND created_at > (NOW() - INTERVAL '6 hours')
    ) THEN
      INSERT INTO public.system_alerts (kind, severity, title, details)
      VALUES (
        'sustained_rate_limits',
        'warning',
        'Sustained Rate Limit Rejections',
        jsonb_build_object('rejections_past_hour', v_count)
      );
    END IF;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public."check_rate_limit_health"() FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public."check_rate_limit_health"() TO service_role;

CREATE OR REPLACE FUNCTION "public"."purge_deleted_accounts"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_raw_claims text;
  v_jwt_role text;
  rec RECORD;
  v_wallet RECORD;
  v_in_flight_count int;
  v_secret text;
  v_purged_count int := 0;
  v_ref_code text;
BEGIN
  v_raw_claims := current_setting('request.jwt.claims', true);
  IF v_raw_claims IS NOT NULL AND v_raw_claims <> '' THEN
    v_jwt_role := (v_raw_claims::jsonb) ->> 'role';
    IF v_jwt_role IS DISTINCT FROM 'service_role' THEN
      RAISE EXCEPTION 'purge_deleted_accounts is not callable by role %', COALESCE(v_jwt_role, '<none>')
        USING ERRCODE = 'KS403';
    END IF;
  END IF;

  UPDATE public.account_deletions
  SET status = 'frozen', frozen_at = clock_timestamp(), updated_at = clock_timestamp()
  WHERE status = 'requested' AND scheduled_purge_at <= clock_timestamp();

  FOR rec IN SELECT * FROM public.account_deletions WHERE status IN ('frozen', 'draining') LOOP
    SELECT COUNT(*) INTO v_in_flight_count
    FROM public.topup_executions
    WHERE user_id = rec.user_id AND status = 'routing';

    IF v_in_flight_count = 0 THEN
      SELECT COUNT(*) INTO v_in_flight_count
      FROM public.esim_orders
      WHERE user_id = rec.user_id AND status IN ('pending', 'processing');
    END IF;

    IF v_in_flight_count > 0 THEN
      IF rec.scheduled_purge_at < (clock_timestamp() - INTERVAL '72 hours') THEN
        INSERT INTO public.system_alerts (kind, message, details)
        VALUES (
          'account_purge_stuck',
          'Account deletion stuck in draining state >72h for user ' || rec.user_id::text,
          jsonb_build_object('user_id', rec.user_id, 'in_flight_count', v_in_flight_count)
        );
      END IF;
      CONTINUE;
    END IF;

    UPDATE public.account_deletions
    SET status = 'draining', drained_at = COALESCE(drained_at, clock_timestamp()), updated_at = clock_timestamp()
    WHERE id = rec.id;

    SELECT referral_code INTO v_ref_code FROM public.profiles WHERE id = rec.user_id;
    IF v_ref_code IS NOT NULL AND length(trim(v_ref_code)) > 0 THEN
      INSERT INTO public.retired_referral_codes (code) VALUES (upper(trim(v_ref_code)))
      ON CONFLICT DO NOTHING;
    END IF;

    FOR v_wallet IN SELECT * FROM public.wallets WHERE user_id = rec.user_id LOOP
      IF v_wallet.balance <> 0 THEN
        INSERT INTO public.wallet_transactions (
          wallet_id, user_id, amount, balance_before, balance_after, type, description, reference_id
        ) VALUES (
          v_wallet.id, rec.user_id, v_wallet.balance, v_wallet.balance, 0.00,
          CASE WHEN rec.dust_forfeited THEN 'wallet_forfeit' ELSE 'wallet_settlement' END,
          'Account purge wallet balance zeroing',
          'purge_' || rec.id
        );
      END IF;
      UPDATE public.wallets SET balance = 0.00, user_id = NULL WHERE id = v_wallet.id;
    END LOOP;

    UPDATE public.referral_points
    SET sim_line_id = NULL
    WHERE sim_line_id IN (SELECT id FROM public.sim_lines WHERE user_id = rec.user_id);

    UPDATE public.wallet_transactions SET user_id = NULL WHERE user_id = rec.user_id;
    UPDATE public.plan_payments SET user_id = NULL WHERE user_id = rec.user_id;
    UPDATE public.esim_orders SET user_id = NULL WHERE user_id = rec.user_id;
    UPDATE public.user_esims SET user_id = NULL WHERE user_id = rec.user_id;
    UPDATE public.topup_executions SET user_id = NULL WHERE user_id = rec.user_id;

    DELETE FROM public.line_activity_log WHERE sim_line_id IN (SELECT id FROM public.sim_lines WHERE user_id = rec.user_id);
    DELETE FROM public.scheduled_topups WHERE sim_line_id IN (SELECT id FROM public.sim_lines WHERE user_id = rec.user_id);
    DELETE FROM public.offline_refill_settings WHERE user_id = rec.user_id;
    DELETE FROM public.sim_lines WHERE user_id = rec.user_id;
    DELETE FROM public.ticket_messages WHERE user_id = rec.user_id OR ticket_id IN (SELECT id FROM public.support_tickets WHERE user_id = rec.user_id);
    DELETE FROM public.support_tickets WHERE user_id = rec.user_id;
    DELETE FROM public.alert_settings WHERE user_id = rec.user_id;
    DELETE FROM public.notification_channels WHERE user_id = rec.user_id;
    DELETE FROM public.notifications WHERE user_id = rec.user_id;
    DELETE FROM public.device_push_tokens WHERE user_id = rec.user_id;
    DELETE FROM public.user_consents WHERE user_id = rec.user_id;

    UPDATE public.account_deletions
    SET status = 'purged', purged_at = clock_timestamp(), updated_at = clock_timestamp()
    WHERE id = rec.id;

    v_purged_count := v_purged_count + 1;

    SELECT decrypted_secret INTO v_secret
    FROM vault.decrypted_secrets WHERE name = 'dispatch_shared_secret' LIMIT 1;

    PERFORM net.http_post(
      url := 'https://zwxswagokhgbuzrrbnhr.supabase.co/functions/v1/purge-accounts',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-keep-sims-secret', COALESCE(v_secret, '')
      ),
      body := jsonb_build_object('user_id', rec.user_id)
    );
  END LOOP;

  RETURN jsonb_build_object('success', true, 'purged_count', v_purged_count);
END;
$$;

REVOKE ALL ON FUNCTION public."purge_deleted_accounts"() FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public."purge_deleted_accounts"() TO service_role;

CREATE OR REPLACE FUNCTION "public"."admin_log"("p_action" "text", "p_target_type" "text", "p_target_id" "text", "p_before" "jsonb" DEFAULT NULL::"jsonb", "p_after" "jsonb" DEFAULT NULL::"jsonb", "p_note" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_uid   uuid := auth.uid();
  v_email text;
  v_id    uuid;
BEGIN
  IF v_uid IS NOT NULL THEN
    SELECT email INTO v_email FROM public.profiles WHERE id = v_uid;
  END IF;

  INSERT INTO public.admin_audit_log (
    actor_id, actor_email, action, target_type, target_id,
    before_value, after_value, note
  ) VALUES (
    v_uid, COALESCE(v_email, 'service_role'), p_action, p_target_type, p_target_id,
    p_before, p_after, p_note
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public."admin_log"(text, text, text, jsonb, jsonb, text) FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public."admin_log"(text, text, text, jsonb, jsonb, text) TO service_role;

CREATE OR REPLACE FUNCTION "public"."assert_admin"() RETURNS "uuid"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO ''
    AS $$
DECLARE
  v_raw   text;
  v_role  text;
  v_uid   uuid;
BEGIN
  v_raw := current_setting('request.jwt.claims', true);
  IF v_raw IS NOT NULL AND v_raw <> '' THEN
    v_role := (v_raw::jsonb) ->> 'role';
  END IF;

  IF v_role = 'service_role' THEN
    RETURN NULL;
  END IF;

  v_uid := auth.uid();

  IF v_uid IS NULL
     OR NOT public.is_power_user(v_uid)
     OR public.is_user_suspended() THEN
    RAISE EXCEPTION 'Admin access required'
      USING ERRCODE = 'KS460',
            HINT = 'This action needs a power-user session.';
  END IF;

  RETURN v_uid;
END;
$$;

REVOKE ALL ON FUNCTION public."assert_admin"() FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public."assert_admin"() TO authenticated;

GRANT EXECUTE ON FUNCTION public."assert_admin"() TO service_role;

CREATE OR REPLACE FUNCTION "public"."is_power_user"("user_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO ''
    AS $$
BEGIN
  RETURN COALESCE((auth.jwt() -> 'app_metadata' ->> 'is_power_user')::boolean, false);
END;
$$;

REVOKE ALL ON FUNCTION public."is_power_user"(uuid) FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public."is_power_user"(uuid) TO anon;

GRANT EXECUTE ON FUNCTION public."is_power_user"(uuid) TO authenticated;

GRANT EXECUTE ON FUNCTION public."is_power_user"(uuid) TO service_role;

CREATE OR REPLACE FUNCTION "public"."is_user_suspended"() RETURNS boolean
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'public'
    AS $$
BEGIN
  RETURN COALESCE((auth.jwt() -> 'app_metadata' ->> 'is_suspended')::boolean, false);
END;
$$;

REVOKE ALL ON FUNCTION public."is_user_suspended"() FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public."is_user_suspended"() TO anon;

GRANT EXECUTE ON FUNCTION public."is_user_suspended"() TO authenticated;

GRANT EXECUTE ON FUNCTION public."is_user_suspended"() TO service_role;

CREATE OR REPLACE FUNCTION "public"."get_internal_secret"("p_name" "text") RETURNS "text"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = p_name;
$$;

REVOKE ALL ON FUNCTION public."get_internal_secret"(text) FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public."get_internal_secret"(text) TO service_role;

CREATE OR REPLACE FUNCTION "public"."kick_admin_email"("p_email_id" "uuid") RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE v_secret text; v_req_id bigint;
BEGIN
  SELECT decrypted_secret INTO v_secret
    FROM vault.decrypted_secrets WHERE name = 'admin_email_secret';
  IF COALESCE(v_secret,'') = '' THEN
    RAISE EXCEPTION 'admin_email_secret missing from Vault' USING ERRCODE = 'KS500';
  END IF;

  SELECT net.http_post(
    url := 'https://zwxswagokhgbuzrrbnhr.supabase.co/functions/v1/send-admin-email',
    headers := jsonb_build_object('Content-Type','application/json','x-sync-secret', v_secret),
    body := jsonb_build_object('email_id', p_email_id),
    timeout_milliseconds := 30000
  ) INTO v_req_id;
  RETURN v_req_id;
END;
$$;

REVOKE ALL ON FUNCTION public."kick_admin_email"(uuid) FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public."kick_admin_email"(uuid) TO service_role;

CREATE OR REPLACE FUNCTION "public"."admin_send_email"("p_to" "text"[], "p_subject" "text", "p_body" "text", "p_cc" "text"[] DEFAULT '{}'::"text"[], "p_reply_to" "text" DEFAULT NULL::"text", "p_from" "text" DEFAULT NULL::"text", "p_note" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $_$
DECLARE
  v_admin    uuid;
  v_enabled  boolean;
  v_from     text;
  v_allowed  text[];
  v_max      integer;
  v_id       uuid;
  v_addr     text;
  v_all      text[];
  v_req      bigint;
  v_rx       text := '^[^@[:space:],]+@[^@[:space:],]+\.[^@[:space:],]+$';
BEGIN
  v_admin := public.assert_admin();
  v_admin := COALESCE(v_admin, auth.uid());

  SELECT COALESCE(NULLIF(config_value,'')::boolean, false) INTO v_enabled
    FROM system_configs WHERE config_key = 'ADMIN_EMAIL_ENABLED';
  IF NOT COALESCE(v_enabled,false) THEN
    RAISE EXCEPTION 'Outbound admin email is switched off' USING ERRCODE = 'KS466';
  END IF;

  PERFORM public.enforce_rate_limit('admin_email', COALESCE(v_admin::text,'admin'));

  SELECT COALESCE(NULLIF(config_value,''), 'admin@keepsims.com') INTO v_from
    FROM system_configs WHERE config_key = 'ADMIN_EMAIL_FROM';
  v_from := lower(trim(COALESCE(NULLIF(trim(p_from),''), v_from)));

  SELECT ARRAY(SELECT lower(trim(x))
               FROM unnest(string_to_array(COALESCE(NULLIF(config_value,''),''), ',')) x
               WHERE trim(x) <> '')
    INTO v_allowed
    FROM system_configs WHERE config_key = 'ADMIN_EMAIL_FROM_OPTIONS';

  IF v_allowed IS NULL OR array_length(v_allowed,1) IS NULL OR NOT (v_from = ANY(v_allowed)) THEN
    RAISE EXCEPTION 'Sender % is not in the allowed sender list', v_from USING ERRCODE = 'KS466';
  END IF;

  SELECT COALESCE(NULLIF(config_value,'')::integer, 10) INTO v_max
    FROM system_configs WHERE config_key = 'ADMIN_EMAIL_MAX_RECIPIENTS';

  IF p_to IS NULL OR array_length(p_to,1) IS NULL THEN
    RAISE EXCEPTION 'At least one recipient is required' USING ERRCODE = 'KS466';
  END IF;

  v_all := ARRAY(SELECT DISTINCT lower(trim(x))
                 FROM unnest(p_to || COALESCE(p_cc,'{}')) x WHERE trim(x) <> '');

  IF array_length(v_all,1) > COALESCE(v_max,10) THEN
    RAISE EXCEPTION 'Too many recipients (% of max %). This is a correspondence tool, not a bulk sender.',
      array_length(v_all,1), v_max USING ERRCODE = 'KS466';
  END IF;

  FOREACH v_addr IN ARRAY v_all LOOP
    IF v_addr !~ v_rx THEN
      RAISE EXCEPTION 'Not a valid email address: %', v_addr USING ERRCODE = 'KS466';
    END IF;
  END LOOP;

  IF p_reply_to IS NOT NULL AND trim(p_reply_to) <> '' AND lower(trim(p_reply_to)) !~ v_rx THEN
    RAISE EXCEPTION 'Reply-to is not a valid email address' USING ERRCODE = 'KS466';
  END IF;

  IF COALESCE(trim(p_subject),'') = '' OR length(p_subject) > 200 THEN
    RAISE EXCEPTION 'Subject is required and must be under 200 characters' USING ERRCODE = 'KS466';
  END IF;
  IF COALESCE(trim(p_body),'') = '' OR length(p_body) > 20000 THEN
    RAISE EXCEPTION 'Body is required and must be under 20000 characters' USING ERRCODE = 'KS466';
  END IF;

  INSERT INTO admin_emails (created_by, from_address, to_addresses, cc_addresses,
                            reply_to, subject, body_text, note)
  VALUES (v_admin, v_from,
          ARRAY(SELECT DISTINCT lower(trim(x)) FROM unnest(p_to) x WHERE trim(x) <> ''),
          ARRAY(SELECT DISTINCT lower(trim(x)) FROM unnest(COALESCE(p_cc,'{}')) x WHERE trim(x) <> ''),
          NULLIF(lower(trim(COALESCE(p_reply_to,''))),''),
          trim(p_subject), p_body, p_note)
  RETURNING id INTO v_id;

  INSERT INTO admin_audit_log (actor_id, action, target_type, target_id, after_value, note)
  VALUES (v_admin, 'admin_email_send', 'admin_email', v_id::text,
          jsonb_build_object('from', v_from, 'to', p_to, 'cc', p_cc, 'subject', trim(p_subject)),
          p_note);

  v_req := public.kick_admin_email(v_id);

  RETURN jsonb_build_object('success', true, 'email_id', v_id, 'status', 'queued', 'request_id', v_req);
END;
$_$;

REVOKE ALL ON FUNCTION public."admin_send_email"(text[], text, text, text[], text, text, text) FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public."admin_send_email"(text[], text, text, text[], text, text, text) TO authenticated;

GRANT EXECUTE ON FUNCTION public."admin_send_email"(text[], text, text, text[], text, text, text) TO service_role;

CREATE OR REPLACE FUNCTION "public"."delete_auth_user_by_id"("p_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_status text;
BEGIN
  -- GUARD: Refuse any user_id whose account_deletions.status <> 'purged'
  SELECT status INTO v_status
  FROM public.account_deletions
  WHERE user_id = p_user_id
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_status IS NULL OR v_status <> 'purged' THEN
    RAISE EXCEPTION 'FORBIDDEN: User account status is not purged (current status: %)', COALESCE(v_status, 'none')
      USING ERRCODE = '42501';
  END IF;

  -- Delete dependent rows without FK or with SET NULL (like user_preferences)
  DELETE FROM public.user_preferences WHERE user_id = p_user_id;

  -- Delete auth user
  DELETE FROM auth.users WHERE id = p_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public."delete_auth_user_by_id"(uuid) FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public."delete_auth_user_by_id"(uuid) TO service_role;

CREATE OR REPLACE FUNCTION "public"."cancel_account_deletion"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_existing RECORD;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  SELECT * INTO v_existing
  FROM public.account_deletions
  WHERE user_id = v_user_id AND status IN ('requested', 'frozen');

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'No active pending account deletion found.');
  END IF;

  IF v_existing.scheduled_purge_at <= clock_timestamp() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Grace period has expired. Deletion is already in progress.');
  END IF;

  UPDATE public.account_deletions
  SET status = 'cancelled', updated_at = clock_timestamp()
  WHERE id = v_existing.id;

  UPDATE public.profiles SET is_suspended = false WHERE id = v_user_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

REVOKE ALL ON FUNCTION public."cancel_account_deletion"() FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public."cancel_account_deletion"() TO authenticated;

GRANT EXECUTE ON FUNCTION public."cancel_account_deletion"() TO service_role;

SET check_function_bodies=true;
