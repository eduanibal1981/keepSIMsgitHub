-- ISOLATED ONLY: exact Task 23 export dependencies; no records or provider calls.

CREATE TABLE IF NOT EXISTS "public"."notification_dispatch_jobs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "notification_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "payload" "jsonb" NOT NULL,
    "state" "text" DEFAULT 'pending'::"text" NOT NULL,
    "attempt_count" integer DEFAULT 0 NOT NULL,
    "next_attempt_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "lease_until" timestamp with time zone,
    "last_error" "text",
    "response_summary" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "completed_at" timestamp with time zone,
    CONSTRAINT "notification_dispatch_jobs_attempt_count_check" CHECK (("attempt_count" >= 0)),
    CONSTRAINT "notification_dispatch_jobs_state_check" CHECK (("state" = ANY (ARRAY['pending'::"text", 'leased'::"text", 'complete'::"text", 'unknown'::"text", 'failed'::"text", 'canceled'::"text"])))
);

CREATE TABLE IF NOT EXISTS "public"."notification_channel_targets" (
    "notification_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "channel" "text" NOT NULL,
    "target_key" "text" NOT NULL,
    "snapshot" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "state" "text" DEFAULT 'pending'::"text" NOT NULL,
    "attempt_count" integer DEFAULT 0 NOT NULL,
    "retryable" boolean DEFAULT false NOT NULL,
    "claim_token" "uuid",
    "lease_until" timestamp with time zone,
    "detail" "text",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "notification_channel_targets_channel_check" CHECK (("channel" = ANY (ARRAY['push'::"text", 'email'::"text", 'telegram'::"text", 'whatsapp'::"text", 'webhook'::"text"]))),
    CONSTRAINT "notification_channel_targets_state_check" CHECK (("state" = ANY (ARRAY['pending'::"text", 'attempting'::"text", 'accepted_by_provider'::"text", 'delivered'::"text", 'skipped'::"text", 'failed'::"text", 'unknown'::"text"])))
);

CREATE TABLE IF NOT EXISTS "public"."offline_voucher_purchase_jobs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "carrier_id" "uuid" NOT NULL,
    "provider_code" "text" DEFAULT 'ding'::"text" NOT NULL,
    "quantity" integer NOT NULL,
    "max_unit_cost_usd" numeric(10,2) NOT NULL,
    "account_number" "text",
    "status" "text" DEFAULT 'queued'::"text" NOT NULL,
    "produced_count" integer DEFAULT 0 NOT NULL,
    "spent_usd" numeric(10,2) DEFAULT 0 NOT NULL,
    "last_error" "text",
    "requested_by" "uuid",
    "requested_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "claimed_at" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "note" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "offline_voucher_purchase_jobs_max_unit_cost_usd_check" CHECK (("max_unit_cost_usd" > (0)::numeric)),
    CONSTRAINT "offline_voucher_purchase_jobs_quantity_check" CHECK ((("quantity" >= 1) AND ("quantity" <= 50))),
    CONSTRAINT "offline_voucher_purchase_jobs_status_check" CHECK (("status" = ANY (ARRAY['queued'::"text", 'claimed'::"text", 'done'::"text", 'failed'::"text", 'cancelled'::"text"])))
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

CREATE TABLE IF NOT EXISTS "public"."whatsapp_provider_profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "provider_kind" "text" NOT NULL,
    "label" "text" NOT NULL,
    "expected_sender_number" "text",
    "observed_sender_number" "text",
    "is_enabled" boolean DEFAULT true NOT NULL,
    "ready_state" "text" DEFAULT 'unconfigured'::"text" NOT NULL,
    "version" integer DEFAULT 1 NOT NULL,
    "last_probe_at" timestamp with time zone,
    "last_error_category" "text",
    "last_error_detail" "text",
    "connection_metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_by" "uuid",
    "updated_by" "uuid",
    CONSTRAINT "whatsapp_provider_profiles_provider_kind_check" CHECK (("provider_kind" = ANY (ARRAY['baileys'::"text", 'meta_cloud'::"text"]))),
    CONSTRAINT "whatsapp_provider_profiles_ready_state_check" CHECK (("ready_state" = ANY (ARRAY['ready'::"text", 'degraded'::"text", 'unconfigured'::"text", 'error'::"text"])))
);

CREATE TABLE IF NOT EXISTS "public"."whatsapp_message_attempts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "purpose" "text" NOT NULL,
    "notification_id" "uuid",
    "command_id" "text",
    "recipient_phone" "text" NOT NULL,
    "recipient_country_id" "uuid",
    "sim_line_id" "uuid",
    "sim_country_id" "uuid",
    "route_mode" "text" NOT NULL,
    "profile_id" "uuid",
    "profile_version" integer DEFAULT 1 NOT NULL,
    "sender_number" "text",
    "idempotency_key" "text" NOT NULL,
    "template_name" "text",
    "template_language" "text",
    "attempt_count" integer DEFAULT 1 NOT NULL,
    "state" "text" DEFAULT 'pending'::"text" NOT NULL,
    "provider_message_id" "text",
    "error_category" "text",
    "error_detail" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "delivered_at" timestamp with time zone,
    "sent_at" timestamp with time zone,
    "claim_token" "uuid",
    "lease_until" timestamp with time zone,
    "retryable" boolean DEFAULT false NOT NULL,
    "request_snapshot" "jsonb",
    "cycle_key" "text",
    CONSTRAINT "whatsapp_message_attempts_purpose_check" CHECK (("purpose" = ANY (ARRAY['subscription_alert'::"text", 'offline_refill_reply'::"text", 'admin_test'::"text"]))),
    CONSTRAINT "whatsapp_message_attempts_state_check" CHECK (("state" = ANY (ARRAY['pending'::"text", 'accepted'::"text", 'sent'::"text", 'delivered'::"text", 'failed'::"text", 'unknown'::"text", 'skipped'::"text"])))
);

CREATE TABLE IF NOT EXISTS "public"."supplier_policy" (
    "provider" "text" NOT NULL,
    "is_globally_enabled" boolean DEFAULT false NOT NULL,
    "risk_premium_percent" numeric(6,3) DEFAULT 0 NOT NULL,
    "flat_penalty_usd" numeric(10,4) DEFAULT 0 NOT NULL,
    "success_count" integer DEFAULT 0 NOT NULL,
    "failure_count" integer DEFAULT 0 NOT NULL,
    "last_failure_at" timestamp with time zone,
    "notes" "text",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "supplier_policy_flat_penalty_usd_check" CHECK (("flat_penalty_usd" >= (0)::numeric)),
    CONSTRAINT "supplier_policy_risk_premium_percent_check" CHECK ((("risk_premium_percent" >= (0)::numeric) AND ("risk_premium_percent" <= (100)::numeric)))
);

CREATE TABLE IF NOT EXISTS "public"."refill_approval_quotes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "execution_id" "uuid" NOT NULL,
    "requested_by" "uuid" NOT NULL,
    "execution_snapshot" "jsonb" NOT NULL,
    "status" "text" DEFAULT 'queued'::"text" NOT NULL,
    "route" "jsonb",
    "error_message" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "expires_at" timestamp with time zone DEFAULT ("now"() + '00:02:00'::interval) NOT NULL,
    CONSTRAINT "refill_approval_quotes_status_check" CHECK (("status" = ANY (ARRAY['queued'::"text", 'processing'::"text", 'ready'::"text", 'failed'::"text", 'approved'::"text"])))
);

ALTER TABLE public."supplier_policy" ADD CONSTRAINT "supplier_policy_pkey" PRIMARY KEY (provider);

ALTER TABLE public."admin_emails" ADD CONSTRAINT "admin_emails_pkey" PRIMARY KEY (id);

ALTER TABLE public."offline_voucher_purchase_jobs" ADD CONSTRAINT "offline_voucher_purchase_jobs_pkey" PRIMARY KEY (id);

ALTER TABLE public."refill_approval_quotes" ADD CONSTRAINT "refill_approval_quotes_pkey" PRIMARY KEY (id);

ALTER TABLE public."whatsapp_provider_profiles" ADD CONSTRAINT "whatsapp_provider_profiles_pkey" PRIMARY KEY (id);

ALTER TABLE public."whatsapp_message_attempts" ADD CONSTRAINT "whatsapp_message_attempts_pkey" PRIMARY KEY (id);

ALTER TABLE public."notification_dispatch_jobs" ADD CONSTRAINT "notification_dispatch_jobs_pkey" PRIMARY KEY (id);

ALTER TABLE public."notification_channel_targets" ADD CONSTRAINT "notification_channel_targets_pkey" PRIMARY KEY (notification_id, channel, target_key);

ALTER TABLE public."whatsapp_message_attempts" ADD CONSTRAINT "whatsapp_message_attempts_idempotency_key_key" UNIQUE (idempotency_key);

ALTER TABLE public."notification_dispatch_jobs" ADD CONSTRAINT "notification_dispatch_jobs_notification_id_key" UNIQUE (notification_id);

ALTER TABLE public."supplier_policy" ADD CONSTRAINT "supplier_policy_provider_fkey" FOREIGN KEY (provider) REFERENCES service_providers(code) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public."admin_emails" ADD CONSTRAINT "admin_emails_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public."offline_voucher_purchase_jobs" ADD CONSTRAINT "offline_voucher_purchase_jobs_carrier_id_fkey" FOREIGN KEY (carrier_id) REFERENCES carriers(id);

ALTER TABLE public."offline_voucher_purchase_jobs" ADD CONSTRAINT "offline_voucher_purchase_jobs_provider_code_fkey" FOREIGN KEY (provider_code) REFERENCES service_providers(code);

ALTER TABLE public."offline_voucher_purchase_jobs" ADD CONSTRAINT "offline_voucher_purchase_jobs_requested_by_fkey" FOREIGN KEY (requested_by) REFERENCES profiles(id);

ALTER TABLE public."refill_approval_quotes" ADD CONSTRAINT "refill_approval_quotes_execution_id_fkey" FOREIGN KEY (execution_id) REFERENCES topup_executions(id) ON DELETE CASCADE;

ALTER TABLE public."refill_approval_quotes" ADD CONSTRAINT "refill_approval_quotes_requested_by_fkey" FOREIGN KEY (requested_by) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public."whatsapp_provider_profiles" ADD CONSTRAINT "whatsapp_provider_profiles_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id);

ALTER TABLE public."whatsapp_provider_profiles" ADD CONSTRAINT "whatsapp_provider_profiles_updated_by_fkey" FOREIGN KEY (updated_by) REFERENCES auth.users(id);

ALTER TABLE public."whatsapp_message_attempts" ADD CONSTRAINT "whatsapp_message_attempts_notification_id_fkey" FOREIGN KEY (notification_id) REFERENCES notifications(id) ON DELETE SET NULL;

ALTER TABLE public."whatsapp_message_attempts" ADD CONSTRAINT "whatsapp_message_attempts_profile_id_fkey" FOREIGN KEY (profile_id) REFERENCES whatsapp_provider_profiles(id) ON DELETE SET NULL;

ALTER TABLE public."whatsapp_message_attempts" ADD CONSTRAINT "whatsapp_message_attempts_recipient_country_id_fkey" FOREIGN KEY (recipient_country_id) REFERENCES countries(id) ON DELETE SET NULL;

ALTER TABLE public."whatsapp_message_attempts" ADD CONSTRAINT "whatsapp_message_attempts_sim_country_id_fkey" FOREIGN KEY (sim_country_id) REFERENCES countries(id) ON DELETE SET NULL;

ALTER TABLE public."whatsapp_message_attempts" ADD CONSTRAINT "whatsapp_message_attempts_sim_line_id_fkey" FOREIGN KEY (sim_line_id) REFERENCES sim_lines(id) ON DELETE SET NULL;

ALTER TABLE public."notification_dispatch_jobs" ADD CONSTRAINT "notification_dispatch_jobs_notification_id_fkey" FOREIGN KEY (notification_id) REFERENCES notifications(id) ON DELETE CASCADE;

ALTER TABLE public."notification_dispatch_jobs" ADD CONSTRAINT "notification_dispatch_jobs_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public."notification_channel_targets" ADD CONSTRAINT "notification_channel_targets_notification_id_fkey" FOREIGN KEY (notification_id) REFERENCES notifications(id) ON DELETE CASCADE;

ALTER TABLE public."notification_channel_targets" ADD CONSTRAINT "notification_channel_targets_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

CREATE INDEX idx_admin_emails_status ON public.admin_emails USING btree (status, created_at DESC);

CREATE INDEX idx_admin_emails_created ON public.admin_emails USING btree (created_at DESC);

CREATE INDEX offline_voucher_purchase_jobs_queued_idx ON public.offline_voucher_purchase_jobs USING btree (requested_at) WHERE (status = 'queued'::text);

CREATE INDEX refill_approval_quotes_pending ON public.refill_approval_quotes USING btree (created_at) WHERE (status = 'queued'::text);

CREATE INDEX refill_approval_quotes_execution ON public.refill_approval_quotes USING btree (execution_id, created_at DESC);

CREATE INDEX refill_approval_quotes_requester ON public.refill_approval_quotes USING btree (requested_by);

CREATE INDEX idx_whatsapp_provider_profiles_kind ON public.whatsapp_provider_profiles USING btree (provider_kind);

CREATE INDEX idx_whatsapp_provider_profiles_ready ON public.whatsapp_provider_profiles USING btree (ready_state);

CREATE INDEX idx_whatsapp_attempts_created ON public.whatsapp_message_attempts USING btree (created_at DESC);

CREATE INDEX idx_whatsapp_attempts_purpose ON public.whatsapp_message_attempts USING btree (purpose);

CREATE INDEX idx_whatsapp_attempts_state ON public.whatsapp_message_attempts USING btree (state);

CREATE INDEX idx_whatsapp_attempts_country ON public.whatsapp_message_attempts USING btree (recipient_country_id);

CREATE INDEX idx_whatsapp_attempts_provider_msg ON public.whatsapp_message_attempts USING btree (provider_message_id) WHERE (provider_message_id IS NOT NULL);

CREATE INDEX idx_notification_dispatch_jobs_due ON public.notification_dispatch_jobs USING btree (next_attempt_at, created_at) WHERE (state = 'pending'::text);

CREATE INDEX idx_notification_dispatch_jobs_state ON public.notification_dispatch_jobs USING btree (state, created_at);

CREATE INDEX notification_channel_targets_user_id_idx ON public.notification_channel_targets USING btree (user_id);

CREATE TABLE public.account_purge_jobs(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deletion_id uuid NOT NULL UNIQUE REFERENCES public.account_deletions(id),
  target_user_id uuid NOT NULL,
  actor_id uuid,
  actor_email text NOT NULL,
  reason text,
  state text NOT NULL DEFAULT 'queued' CHECK(state IN ('queued','processing','failed','completed')),
  claim_token uuid,
  lease_until timestamptz,
  attempt_count integer NOT NULL DEFAULT 0,
  error_code text,
  dispatched_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
