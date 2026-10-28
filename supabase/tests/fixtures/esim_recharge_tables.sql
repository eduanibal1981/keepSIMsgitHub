-- ESIM-07 isolated table shapes from the 2026-10-19 captured baseline.
-- Only synthetic rows are inserted by the runner; not a provisioning migration.

CREATE TABLE public.esim_orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    provider text DEFAULT 'esim_go'::text NOT NULL,
    bundle_name text NOT NULL,
    quantity integer DEFAULT 1 NOT NULL,
    wholesale_price_usd numeric(10,4) NOT NULL,
    retail_price_usd numeric(10,2) NOT NULL,
    markup_percent numeric(5,2) NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    provider_order_ref text,
    error_message text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    offer_id text,
    total_amount_usd numeric(10,2),
    CONSTRAINT esim_orders_quantity_check CHECK (((quantity >= 1) AND (quantity <= 3))),
    CONSTRAINT esim_orders_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'processing'::text, 'completed'::text, 'failed'::text, 'refunded'::text])))
);


CREATE TABLE public.user_esims (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    order_id uuid NOT NULL,
    iccid text NOT NULL,
    smdp_address text NOT NULL,
    matching_id text NOT NULL,
    lpa_string text NOT NULL,
    bundle_name text NOT NULL,
    provider text DEFAULT 'esim_go'::text NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    purchased_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone,
    data_total_mb bigint NOT NULL,
    data_remaining_mb bigint NOT NULL,
    last_usage_check timestamp with time zone,
    low_data_notified boolean DEFAULT false NOT NULL,
    CONSTRAINT user_esims_status_check CHECK ((status = ANY (ARRAY['active'::text, 'expired'::text, 'depleted'::text, 'installed'::text])))
);


CREATE TABLE public.system_configs (
    config_key character varying NOT NULL,
    config_value character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


CREATE TABLE public.esim_suppliers (
    code text NOT NULL,
    name text NOT NULL,
    website_url text,
    api_base_url text,
    docs_url text,
    credential_secret text,
    is_active boolean DEFAULT false NOT NULL,
    priority integer DEFAULT 100 NOT NULL,
    markup_percent_override numeric,
    countries_supported text[] DEFAULT '{}'::text[] NOT NULL,
    last_sync_at timestamp with time zone,
    last_sync_status text,
    last_sync_count integer,
    last_sync_error text,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT esim_suppliers_last_sync_status_check CHECK ((last_sync_status = ANY (ARRAY['ok'::text, 'partial'::text, 'failed'::text])))
);


CREATE TABLE public.esim_offers_cache (
    provider text DEFAULT 'esim_go'::text NOT NULL,
    bundle_name text NOT NULL,
    description text,
    countries text[] DEFAULT '{}'::text[] NOT NULL,
    roaming_enabled text[] DEFAULT '{}'::text[] NOT NULL,
    data_amount_mb bigint DEFAULT 0 NOT NULL,
    duration_days integer DEFAULT 0 NOT NULL,
    wholesale_price_usd numeric(10,4) DEFAULT 0.0000 NOT NULL,
    image_url text,
    is_active boolean DEFAULT true NOT NULL,
    updated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    is_unlimited boolean DEFAULT false NOT NULL,
    bundle_group text,
    speed_tier text,
    region text,
    country_count integer DEFAULT 0 NOT NULL
);


CREATE TABLE public.app_fee_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    appfees_item text NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    free_percentage numeric(12,6) NOT NULL,
    free_minimum numeric(18,6) NOT NULL,
    stand_percentage numeric(12,6) NOT NULL,
    stand_minimum numeric(18,6) NOT NULL,
    prem_percentage numeric(12,6) NOT NULL,
    prem_minimum numeric(18,6) NOT NULL,
    currency text DEFAULT 'USD'::text NOT NULL,
    fee_basis text DEFAULT 'base_amount_usd'::text NOT NULL,
    charge_unit text DEFAULT 'purchase'::text NOT NULL,
    status text DEFAULT 'draft'::text NOT NULL,
    effective_from timestamp with time zone,
    effective_to timestamp with time zone,
    change_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    published_at timestamp with time zone,
    published_by uuid,
    CONSTRAINT app_fee_rules_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'published'::text, 'retired'::text]))),
    CONSTRAINT ck_app_fee_hierarchy CHECK (((free_percentage >= stand_percentage) AND (stand_percentage >= prem_percentage) AND (free_minimum >= stand_minimum) AND (stand_minimum >= prem_minimum))),
    CONSTRAINT ck_app_fee_nonnegative CHECK (((free_percentage >= (0)::numeric) AND (stand_percentage >= (0)::numeric) AND (prem_percentage >= (0)::numeric) AND (free_minimum >= (0)::numeric) AND (stand_minimum >= (0)::numeric) AND (prem_minimum >= (0)::numeric))),
    CONSTRAINT ck_intelcallfee_zero_minima CHECK (((appfees_item <> 'intelcallfee'::text) OR ((free_minimum = (0)::numeric) AND (stand_minimum = (0)::numeric) AND (prem_minimum = (0)::numeric))))
);


CREATE TABLE public.wallets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    balance numeric(12,2) DEFAULT 0.00,
    currency text DEFAULT 'USD'::text,
    auto_fund_enabled boolean DEFAULT false,
    auto_fund_threshold numeric(10,2),
    auto_fund_amount numeric(10,2),
    total_deposited numeric(12,2) DEFAULT 0.00,
    total_spent numeric(12,2) DEFAULT 0.00,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT wallets_balance_check CHECK ((balance >= (0)::numeric))
);


CREATE TABLE public.wallet_holds (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    wallet_id uuid NOT NULL,
    user_id uuid NOT NULL,
    order_type text NOT NULL,
    order_reference_id text NOT NULL,
    amount numeric NOT NULL,
    currency text DEFAULT 'USD'::text NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    reason text,
    captured_at timestamp with time zone,
    released_at timestamp with time zone,
    expires_at timestamp with time zone DEFAULT (now() + '02:00:00'::interval),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    carrier_in_flight boolean DEFAULT false NOT NULL,
    recovery_contract_version integer DEFAULT 1 NOT NULL,
    recovery_required_at timestamp with time zone,
    CONSTRAINT wallet_holds_amount_check CHECK ((amount > (0)::numeric)),
    CONSTRAINT wallet_holds_order_type_check CHECK ((order_type = ANY (ARRAY['refill_instant'::text, 'refill_scheduled'::text, 'setup_refill'::text, 'plan_fee'::text, 'esim_purchase'::text, 'call_budget'::text, 'offline_voucher'::text, 'refund_request'::text, 'line_verification'::text, 'second_number'::text]))),
    CONSTRAINT wallet_holds_status_check CHECK ((status = ANY (ARRAY['active'::text, 'captured'::text, 'released'::text, 'expired'::text])))
);


CREATE TABLE public.wallet_funding_lots (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    wallet_id uuid NOT NULL,
    user_id uuid NOT NULL,
    origin_type text NOT NULL,
    original_reference_id text,
    original_order_id text,
    currency text DEFAULT 'USD'::text NOT NULL,
    funded_amount numeric NOT NULL,
    remaining_amount numeric NOT NULL,
    is_refundable boolean DEFAULT false NOT NULL,
    refund_deadline timestamp with time zone,
    status text DEFAULT 'active'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT wallet_funding_lots_check CHECK (((remaining_amount >= (0)::numeric) AND (remaining_amount <= funded_amount))),
    CONSTRAINT wallet_funding_lots_funded_amount_check CHECK ((funded_amount >= (0)::numeric)),
    CONSTRAINT wallet_funding_lots_origin_type_check CHECK ((origin_type = ANY (ARRAY['paypal_deposit'::text, 'card_deposit'::text, 'promotional'::text, 'gift_received'::text, 'admin_adjustment'::text, 'unverified_legacy'::text]))),
    CONSTRAINT wallet_funding_lots_status_check CHECK ((status = ANY (ARRAY['active'::text, 'fully_consumed'::text, 'partially_refunded'::text, 'fully_refunded'::text, 'disputed'::text, 'restricted'::text])))
);
