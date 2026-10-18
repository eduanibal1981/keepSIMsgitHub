-- Isolated Task 18 dependency from the supplied production schema export.
-- The financial fixture already captures plan_payments. Auth/PayPal adapters,
-- receipt webhooks and external delivery are not reproduced by this extension.
CREATE TABLE IF NOT EXISTS "public"."paypal_orders" (
    "order_id" "text" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "kind" "text" NOT NULL,
    "plan" "text",
    "sim_line_id" "uuid",
    "amount_usd" numeric(12,2) NOT NULL,
    "status" "text" DEFAULT 'created'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "captured_at" timestamp with time zone,
    CONSTRAINT "paypal_orders_amount_usd_check" CHECK (("amount_usd" > (0)::numeric)),
    CONSTRAINT "paypal_orders_kind_check" CHECK (("kind" = ANY (ARRAY['deposit'::"text", 'plan'::"text"]))),
    CONSTRAINT "paypal_orders_plan_check" CHECK (("plan" = ANY (ARRAY['standard'::"text", 'premium'::"text"]))),
    CONSTRAINT "paypal_orders_status_check" CHECK (("status" = ANY (ARRAY['created'::"text", 'approved'::"text", 'captured'::"text", 'failed'::"text", 'expired'::"text"])))
);;
ALTER TABLE public.paypal_orders ADD PRIMARY KEY(order_id);
ALTER TABLE public.paypal_orders ADD FOREIGN KEY(user_id) REFERENCES auth.users(id);
ALTER TABLE public.paypal_orders ADD FOREIGN KEY(sim_line_id) REFERENCES public.sim_lines(id);
GRANT ALL ON public.paypal_orders TO service_role;

CREATE TABLE IF NOT EXISTS "public"."carrier_provider_map" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "carrier_id" "uuid" NOT NULL,
    "provider" "text" NOT NULL,
    "provider_country_code" "text" NOT NULL,
    "provider_carrier_code" "text" NOT NULL,
    "is_enabled" boolean DEFAULT false NOT NULL,
    "priority" integer DEFAULT 100 NOT NULL,
    "last_verified_at" timestamp with time zone,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "provider_country_label" "text" NOT NULL,
    "provider_carrier_label" "text" NOT NULL,
    "is_primary" boolean DEFAULT false NOT NULL,
    CONSTRAINT "carrier_provider_map_primary_is_enabled" CHECK (((NOT "is_primary") OR "is_enabled"))
);

CREATE TABLE IF NOT EXISTS "public"."provider_offers_cache" (
    "api_provider" "text" DEFAULT 'zendit'::"text" NOT NULL,
    "offer_id" "text" NOT NULL,
    "country_code" "text" NOT NULL,
    "carrier_code" "text" NOT NULL,
    "offer_name" "text",
    "price_type" "text" NOT NULL,
    "price_fixed_usd" numeric,
    "price_min_usd" numeric,
    "price_max_usd" numeric,
    "send_min" numeric,
    "send_max" numeric,
    "send_currency" "text",
    "send_currency_divisor" numeric DEFAULT 100,
    "refreshed_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "source_currency" "text",
    "source_amount_native" numeric(14,4),
    "fx_usd_to_local" numeric(18,8),
    "fx_rate_as_of" timestamp with time zone,
    "delivery_type" "text" DEFAULT 'direct'::"text",
    "redeem_instructions" "text",
    "service_type" "text" DEFAULT 'airtime'::"text",
    "benefit_summary" "text",
    "data_mb" bigint,
    "duration_days" integer,
    CONSTRAINT "provider_offers_cache_fixed_priced" CHECK ((("price_type" <> 'FIXED'::"text") OR ("price_fixed_usd" IS NOT NULL))),
    CONSTRAINT "provider_offers_cache_price_type_check" CHECK (("price_type" = ANY (ARRAY['FIXED'::"text", 'RANGE'::"text"]))),
    CONSTRAINT "provider_offers_cache_range_priced" CHECK ((("price_type" <> 'RANGE'::"text") OR (("price_min_usd" IS NOT NULL) AND ("price_max_usd" IS NOT NULL) AND ("send_min" IS NOT NULL) AND ("send_max" IS NOT NULL))))
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

ALTER TABLE public.carrier_provider_map ADD PRIMARY KEY(id);
ALTER TABLE public.provider_offers_cache ADD PRIMARY KEY(api_provider,offer_id);
ALTER TABLE public.esim_orders ADD PRIMARY KEY(id);
ALTER TABLE public.esim_orders ADD FOREIGN KEY(user_id) REFERENCES auth.users(id);
ALTER TABLE public.carrier_provider_map ADD FOREIGN KEY(carrier_id) REFERENCES public.carriers(id);

CREATE OR REPLACE FUNCTION "public"."request_esim_purchase"("p_offer_id" "text", "p_quantity" integer DEFAULT 1, "p_device_id" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
DECLARE
  v_user_id uuid := auth.uid();
  v_offer RECORD;
  v_supplier_markup numeric;
  v_markup_percent numeric := 30.0;
  v_retail_price numeric(10,2);
  v_total_cost numeric(10,2);
  v_wallet_balance numeric(10,2);
  v_order_id uuid;
  v_txn_ref text;
  v_guard jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = v_user_id AND is_suspended = true) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Account is suspended. Purchases are disabled.');
  END IF;

  PERFORM public.enforce_rate_limit('esim_purchase', v_user_id::text);

  IF p_quantity IS NULL OR p_quantity < 1 OR p_quantity > 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Quantity must be between 1 and 3');
  END IF;

  SELECT * INTO v_offer
  FROM public.esim_offers_cache
  WHERE (bundle_name = p_offer_id OR (provider || '_' || bundle_name = p_offer_id))
    AND is_active = true
  ORDER BY updated_at DESC
  LIMIT 1;

  IF v_offer IS NULL OR v_offer.bundle_name IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'eSIM offer not found or inactive');
  END IF;

  -- Use canonical tier-based pricing via resolve_esim_offer_price
  v_retail_price := public.resolve_esim_offer_price(v_offer.wholesale_price_usd, v_user_id);
  IF v_retail_price IS NULL OR v_retail_price <= 0 THEN
    SELECT markup_percent_override INTO v_supplier_markup
    FROM public.esim_suppliers
    WHERE code = v_offer.provider;

    IF v_supplier_markup IS NOT NULL THEN
      v_markup_percent := v_supplier_markup;
    ELSE
      BEGIN
        SELECT config_value::numeric INTO v_markup_percent
        FROM public.system_configs WHERE config_key = 'ESIM_MARKUP_PERCENT';
      EXCEPTION WHEN OTHERS THEN v_markup_percent := 30.0; END;
    END IF;
    IF v_markup_percent IS NULL THEN v_markup_percent := 30.0; END IF;

    v_retail_price := round(v_offer.wholesale_price_usd * (1.0 + (v_markup_percent / 100.0)), 2);
  ELSE
    v_markup_percent := round(((v_retail_price - v_offer.wholesale_price_usd) / NULLIF(v_offer.wholesale_price_usd, 0)) * 100.0, 2);
  END IF;

  v_total_cost := v_retail_price * p_quantity;

  SELECT COALESCE(balance, 0.00) INTO v_wallet_balance
  FROM public.wallets WHERE user_id = v_user_id;

  IF v_wallet_balance < v_total_cost THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'INSUFFICIENT_FUNDS',
      'error', 'Insufficient wallet balance. Required: $' || v_total_cost::text || ', Available: $' || v_wallet_balance::text
    );
  END IF;

  v_guard := public.guard_money_action('esim_purchase', v_total_cost, p_device_id, NULL, v_user_id);
  IF (v_guard ->> 'blocked')::boolean THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'DEVICE_BLOCKED',
      'reason', v_guard ->> 'reason',
      'error', 'This purchase was stopped by a security check on this device. Contact support if this is a mistake.'
    );
  END IF;

  INSERT INTO public.esim_orders (
    user_id, offer_id, bundle_name, provider, quantity, wholesale_price_usd, retail_price_usd, markup_percent, total_amount_usd, status
  ) VALUES (
    v_user_id, p_offer_id, v_offer.bundle_name, v_offer.provider, p_quantity, v_offer.wholesale_price_usd, v_retail_price, v_markup_percent, v_total_cost, 'pending'
  ) RETURNING id INTO v_order_id;

  v_txn_ref := 'esim_' || v_order_id::text;

  PERFORM public.debit_wallet_for_topup(
    p_user_id => v_user_id,
    p_sim_line_id => NULL,
    p_amount => v_total_cost,
    p_description => 'eSIM Purchase: ' || v_offer.bundle_name,
    p_reference_id => v_txn_ref,
    p_txn_type => 'esim_purchase_debit'
  );

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'retail_price_usd', v_retail_price,
    'total_amount_usd', v_total_cost,
    'status', 'pending'
  );
END;
$_$;
REVOKE ALL ON FUNCTION public.request_esim_purchase(text,integer,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.request_esim_purchase(text,integer,text) TO authenticated,service_role;
