-- Task 5 isolated fixture: captured live column types, constraints, indexes.
-- Non-money Auth/SIM rows and notification/queue triggers are represented below.
CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS;
CREATE SCHEMA auth;
CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $$ SELECT coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'role',''); $$;
GRANT USAGE ON SCHEMA auth,public TO anon,authenticated,service_role;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
CREATE TABLE public.sim_lines(id uuid PRIMARY KEY,user_id uuid REFERENCES auth.users(id));
CREATE TABLE public.wallets (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "user_id" uuid,
  "balance" numeric(12,2) DEFAULT 0.00,
  "currency" text DEFAULT 'USD'::text,
  "auto_fund_enabled" boolean DEFAULT false,
  "auto_fund_threshold" numeric(10,2),
  "auto_fund_amount" numeric(10,2),
  "total_deposited" numeric(12,2) DEFAULT 0.00,
  "total_spent" numeric(12,2) DEFAULT 0.00,
  "created_at" timestamp with time zone DEFAULT now(),
  "updated_at" timestamp with time zone DEFAULT now()
);
ALTER TABLE public.wallets ADD CONSTRAINT "wallets_pkey" PRIMARY KEY (id);
ALTER TABLE public.wallets ADD CONSTRAINT "wallets_balance_check" CHECK ((balance >= (0)::numeric));
ALTER TABLE public.wallets ADD CONSTRAINT "wallets_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.wallets ADD CONSTRAINT "wallets_user_id_key" UNIQUE (user_id);
CREATE INDEX idx_wallets_user_id ON public.wallets USING btree (user_id);
CREATE TABLE public.wallet_transactions (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "wallet_id" uuid NOT NULL,
  "user_id" uuid,
  "type" text NOT NULL,
  "amount" numeric(10,2) NOT NULL,
  "balance_before" numeric(12,2) NOT NULL,
  "balance_after" numeric(12,2) NOT NULL,
  "description" text,
  "reference_id" text,
  "sim_line_id" uuid,
  "status" text DEFAULT 'completed'::text,
  "metadata" jsonb DEFAULT '{}'::jsonb,
  "created_at" timestamp with time zone DEFAULT now()
);
ALTER TABLE public.wallet_transactions ADD CONSTRAINT "wallet_transactions_pkey" PRIMARY KEY (id);
ALTER TABLE public.wallet_transactions ADD CONSTRAINT "wallet_transactions_amount_positive" CHECK ((amount > (0)::numeric)) NOT VALID;
ALTER TABLE public.wallet_transactions ADD CONSTRAINT "wallet_transactions_sim_line_id_fkey" FOREIGN KEY (sim_line_id) REFERENCES sim_lines(id) ON DELETE SET NULL;
ALTER TABLE public.wallet_transactions ADD CONSTRAINT "wallet_transactions_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'completed'::text, 'failed'::text, 'reversed'::text])));
ALTER TABLE public.wallet_transactions ADD CONSTRAINT "wallet_transactions_type_check" CHECK ((type = ANY (ARRAY['deposit'::text, 'topup_debit'::text, 'refund'::text, 'referral_credit'::text, 'referral_withdrawal'::text, 'plan_fee_debit'::text, 'home_mode_debit'::text, 'auto_fund'::text, 'esim_purchase_debit'::text, 'esim_purchase_refund'::text, 'wallet_settlement'::text, 'wallet_forfeit'::text, 'gift_sent'::text, 'gift_received'::text, 'admin_adjustment'::text, 'offline_voucher_debit'::text, 'call_debit'::text, 'call_refund'::text, 'did_purchase_debit'::text])));
ALTER TABLE public.wallet_transactions ADD CONSTRAINT "wallet_transactions_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.wallet_transactions ADD CONSTRAINT "wallet_transactions_wallet_id_fkey" FOREIGN KEY (wallet_id) REFERENCES wallets(id) ON DELETE CASCADE;
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
CREATE TABLE public.wallet_funding_lots (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "wallet_id" uuid NOT NULL,
  "user_id" uuid NOT NULL,
  "origin_type" text NOT NULL,
  "original_reference_id" text,
  "original_order_id" text,
  "currency" text DEFAULT 'USD'::text NOT NULL,
  "funded_amount" numeric NOT NULL,
  "remaining_amount" numeric NOT NULL,
  "is_refundable" boolean DEFAULT false NOT NULL,
  "refund_deadline" timestamp with time zone,
  "status" text DEFAULT 'active'::text NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE public.wallet_funding_lots ADD CONSTRAINT "wallet_funding_lots_pkey" PRIMARY KEY (id);
ALTER TABLE public.wallet_funding_lots ADD CONSTRAINT "wallet_funding_lots_check" CHECK (((remaining_amount >= (0)::numeric) AND (remaining_amount <= funded_amount)));
ALTER TABLE public.wallet_funding_lots ADD CONSTRAINT "wallet_funding_lots_funded_amount_check" CHECK ((funded_amount >= (0)::numeric));
ALTER TABLE public.wallet_funding_lots ADD CONSTRAINT "wallet_funding_lots_origin_type_check" CHECK ((origin_type = ANY (ARRAY['paypal_deposit'::text, 'card_deposit'::text, 'promotional'::text, 'gift_received'::text, 'admin_adjustment'::text, 'unverified_legacy'::text])));
ALTER TABLE public.wallet_funding_lots ADD CONSTRAINT "wallet_funding_lots_status_check" CHECK ((status = ANY (ARRAY['active'::text, 'fully_consumed'::text, 'partially_refunded'::text, 'fully_refunded'::text, 'disputed'::text, 'restricted'::text])));
ALTER TABLE public.wallet_funding_lots ADD CONSTRAINT "wallet_funding_lots_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.wallet_funding_lots ADD CONSTRAINT "wallet_funding_lots_wallet_id_fkey" FOREIGN KEY (wallet_id) REFERENCES wallets(id) ON DELETE CASCADE;
CREATE UNIQUE INDEX uq_wallet_funding_lots_user_ref ON public.wallet_funding_lots USING btree (user_id, original_reference_id) WHERE (original_reference_id IS NOT NULL);
CREATE INDEX idx_wallet_funding_lots_user_active ON public.wallet_funding_lots USING btree (user_id, status, created_at);
CREATE TABLE public.paypal_orders (
  "order_id" text NOT NULL,
  "user_id" uuid NOT NULL,
  "kind" text NOT NULL,
  "plan" text,
  "sim_line_id" uuid,
  "amount_usd" numeric(12,2) NOT NULL,
  "status" text DEFAULT 'created'::text NOT NULL,
  "created_at" timestamp with time zone DEFAULT now(),
  "captured_at" timestamp with time zone
);
ALTER TABLE public.paypal_orders ADD CONSTRAINT "paypal_orders_pkey" PRIMARY KEY (order_id);
ALTER TABLE public.paypal_orders ADD CONSTRAINT "paypal_orders_amount_usd_check" CHECK ((amount_usd > (0)::numeric));
ALTER TABLE public.paypal_orders ADD CONSTRAINT "paypal_orders_kind_check" CHECK ((kind = ANY (ARRAY['deposit'::text, 'plan'::text])));
ALTER TABLE public.paypal_orders ADD CONSTRAINT "paypal_orders_plan_check" CHECK ((plan = ANY (ARRAY['standard'::text, 'premium'::text])));
ALTER TABLE public.paypal_orders ADD CONSTRAINT "paypal_orders_sim_line_id_fkey" FOREIGN KEY (sim_line_id) REFERENCES sim_lines(id) ON DELETE SET NULL;
ALTER TABLE public.paypal_orders ADD CONSTRAINT "paypal_orders_status_check" CHECK ((status = ANY (ARRAY['created'::text, 'approved'::text, 'captured'::text, 'failed'::text, 'expired'::text])));
ALTER TABLE public.paypal_orders ADD CONSTRAINT "paypal_orders_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
CREATE INDEX idx_paypal_orders_user_id ON public.paypal_orders USING btree (user_id);
CREATE INDEX idx_paypal_orders_status ON public.paypal_orders USING btree (status);
CREATE TABLE public.plan_payments (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "user_id" uuid,
  "capture_id" text NOT NULL,
  "order_id" text,
  "kind" text DEFAULT 'plan'::text NOT NULL,
  "gross_usd" numeric NOT NULL,
  "paypal_fee_usd" numeric,
  "net_usd" numeric,
  "metadata" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "sim_line_id" uuid
);
ALTER TABLE public.plan_payments ADD CONSTRAINT "plan_payments_pkey" PRIMARY KEY (id);
ALTER TABLE public.plan_payments ADD CONSTRAINT "plan_payments_capture_id_key" UNIQUE (capture_id);
ALTER TABLE public.plan_payments ADD CONSTRAINT "plan_payments_gross_usd_check" CHECK ((gross_usd > (0)::numeric));
ALTER TABLE public.plan_payments ADD CONSTRAINT "plan_payments_sim_line_id_fkey" FOREIGN KEY (sim_line_id) REFERENCES sim_lines(id) ON DELETE SET NULL;
ALTER TABLE public.plan_payments ADD CONSTRAINT "plan_payments_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
CREATE INDEX idx_plan_payments_user ON public.plan_payments USING btree (user_id);
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO anon,authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon,authenticated;
