-- Actual inspected live wallet shapes. Synthetic test data only; not a migration.
CREATE TABLE public.wallets (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "user_id" uuid,
 "balance" numeric DEFAULT 0.00,
 "currency" text DEFAULT 'USD'::text,
 "auto_fund_enabled" boolean DEFAULT false,
 "auto_fund_threshold" numeric,
 "auto_fund_amount" numeric,
 "total_deposited" numeric DEFAULT 0.00,
 "total_spent" numeric DEFAULT 0.00,
 "created_at" timestamp with time zone DEFAULT now(),
 "updated_at" timestamp with time zone DEFAULT now()
);

CREATE TABLE public.wallet_holds (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "wallet_id" uuid NOT NULL,
 "user_id" uuid NOT NULL,
 "order_type" text NOT NULL,
 "order_reference_id" text NOT NULL,
 "amount" numeric NOT NULL,
 "currency" text DEFAULT 'USD'::text NOT NULL,
 "status" text DEFAULT 'active'::text NOT NULL,
 "reason" text,
 "captured_at" timestamp with time zone,
 "released_at" timestamp with time zone,
 "expires_at" timestamp with time zone DEFAULT (now() + '02:00:00'::interval) NOT NULL,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL,
 "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
 "carrier_in_flight" boolean DEFAULT false NOT NULL
);

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

CREATE TABLE public.wallet_hold_allocations (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "hold_id" uuid NOT NULL,
 "lot_id" uuid NOT NULL,
 "amount" numeric NOT NULL,
 "created_at" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.wallet_transactions (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "wallet_id" uuid NOT NULL,
 "user_id" uuid,
 "type" text NOT NULL,
 "amount" numeric NOT NULL,
 "balance_before" numeric NOT NULL,
 "balance_after" numeric NOT NULL,
 "description" text,
 "reference_id" text,
 "sim_line_id" uuid,
 "status" text DEFAULT 'completed'::text,
 "metadata" jsonb DEFAULT '{}'::jsonb,
 "created_at" timestamp with time zone DEFAULT now()
);

ALTER TABLE public.wallet_transactions ADD CONSTRAINT wallet_transactions_amount_positive CHECK ((amount > (0)::numeric)) NOT VALID;

ALTER TABLE public.wallet_transactions ADD CONSTRAINT wallet_transactions_pkey PRIMARY KEY (id);

ALTER TABLE public.wallet_transactions ADD CONSTRAINT wallet_transactions_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'completed'::text, 'failed'::text, 'reversed'::text])));

ALTER TABLE public.wallet_transactions ADD CONSTRAINT wallet_transactions_type_check CHECK ((type = ANY (ARRAY['deposit'::text, 'topup_debit'::text, 'refund'::text, 'referral_credit'::text, 'referral_withdrawal'::text, 'plan_fee_debit'::text, 'home_mode_debit'::text, 'auto_fund'::text, 'esim_purchase_debit'::text, 'esim_purchase_refund'::text, 'wallet_settlement'::text, 'wallet_forfeit'::text, 'gift_sent'::text, 'gift_received'::text, 'admin_adjustment'::text, 'offline_voucher_debit'::text, 'call_debit'::text, 'call_refund'::text, 'did_purchase_debit'::text])));

ALTER TABLE public.wallet_holds ADD CONSTRAINT uq_wallet_holds_ref UNIQUE (order_type, order_reference_id);

ALTER TABLE public.wallet_holds ADD CONSTRAINT wallet_holds_amount_check CHECK ((amount > (0)::numeric));

ALTER TABLE public.wallet_holds ADD CONSTRAINT wallet_holds_order_type_check CHECK ((order_type = ANY (ARRAY['refill_instant'::text, 'refill_scheduled'::text, 'setup_refill'::text, 'plan_fee'::text, 'esim_purchase'::text, 'call_budget'::text, 'offline_voucher'::text, 'refund_request'::text, 'line_verification'::text])));

ALTER TABLE public.wallet_holds ADD CONSTRAINT wallet_holds_pkey PRIMARY KEY (id);

ALTER TABLE public.wallet_holds ADD CONSTRAINT wallet_holds_status_check CHECK ((status = ANY (ARRAY['active'::text, 'captured'::text, 'released'::text, 'expired'::text])));

ALTER TABLE public.wallets ADD PRIMARY KEY(id);

ALTER TABLE public.wallets ADD UNIQUE(user_id);

ALTER TABLE public.wallet_funding_lots ADD PRIMARY KEY(id);
