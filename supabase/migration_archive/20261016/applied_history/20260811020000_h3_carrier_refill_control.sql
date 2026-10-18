-- ============================================================================
-- H3 — per-carrier refill control.
--
-- `carriers` carries the live routing decision: route_topup_execution() reads
-- fulfillment_gateway and api_provider off this table on every INSERT into
-- topup_executions and stamps them onto the execution. The admin app has always
-- had a Routing tab for it — and it has never worked. `carriers` has exactly one
-- policy ("Anyone can read carriers", SELECT) so the PATCH matched zero rows and
-- returned HTTP 200. Proven live 2026-07-31 with a real power-user JWT: rows=0,
-- no error. The UI said "Saved" and nothing changed, for months.
--
-- Fixed through an RPC rather than a new UPDATE policy, so the writable surface
-- is a named set of fields with validation instead of "every column".
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_list_carriers()
RETURNS TABLE (
  id                       uuid,
  name                     text,
  country_id               uuid,
  country_name             text,
  country_iso              text,
  is_supported             boolean,
  fulfillment_gateway      text,
  api_provider             text,
  default_refill_amount    numeric,
  gateway_phone_number     text,
  zen_carrier              text,
  ding_carrier             text,
  dt_carrier               text,
  reloadly_operator_id     text,
  active_lines             bigint,
  offers_available         bigint,
  min_offer_usd            numeric,
  max_offer_usd            numeric,
  rule_minimum_topup       numeric,
  rule_recommended_topup   numeric,
  rule_validity_days       integer,
  rule_inactivity_days     integer,
  rule_grace_days          integer,
  rule_notes               text,
  rule_last_verified_at    timestamptz,
  routing_problem          text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  PERFORM public.assert_admin();

  RETURN QUERY
  SELECT
    ca.id, ca.name, ca.country_id,
    co.name           AS country_name,
    co.iso_code::text AS country_iso,
    COALESCE(ca.is_supported, true),
    ca.fulfillment_gateway::text,
    ca.api_provider::text,
    ca.default_refill_amount,
    ca.gateway_phone_number,
    ca.zen_carrier::text,
    ca.ding_carrier::text,
    ca.dt_carrier::text,
    ca.reloadly_operator_id,
    (SELECT count(*) FROM public.sim_lines sl WHERE sl.carrier_id = ca.id),
    o.n_offers, o.min_usd, o.max_usd,
    cr.minimum_topup_amount, cr.recommended_topup_amount, cr.topup_validity_days,
    cr.inactivity_limit_days, cr.grace_period_days, cr.notes, cr.last_verified_at,
    -- The one thing an operator cannot see by eye: a route that cannot fulfil.
    CASE
      WHEN ca.fulfillment_gateway = 'API' AND ca.api_provider IS NULL
        THEN 'Routed to API with no provider — no worker can claim these refills'
      WHEN ca.fulfillment_gateway = 'API' AND COALESCE(o.n_offers, 0) = 0
        THEN 'Routed to API but the offer cache holds nothing for this carrier'
      WHEN ca.fulfillment_gateway = 'MANUAL' AND ca.gateway_phone_number IS NULL
        THEN 'Manual fulfilment with no gateway number recorded'
      ELSE NULL
    END AS routing_problem
  FROM public.carriers ca
  JOIN public.countries co ON co.id = ca.country_id
  LEFT JOIN public.carrier_rules cr ON cr.carrier_id = ca.id
  LEFT JOIN LATERAL (
    SELECT count(*) AS n_offers,
           min(COALESCE(p.price_fixed_usd, p.price_min_usd)) AS min_usd,
           max(COALESCE(p.price_fixed_usd, p.price_max_usd)) AS max_usd
    FROM public.provider_offers_cache p
    WHERE p.country_code = co.iso_code
      AND p.api_provider = COALESCE(ca.api_provider::text, 'zendit')
      AND p.carrier_code = CASE COALESCE(ca.api_provider::text, 'zendit')
                             WHEN 'ding'  THEN ca.ding_carrier::text
                             WHEN 'dtone' THEN ca.dt_carrier::text
                             ELSE ca.zen_carrier::text
                           END
  ) o ON true
  ORDER BY co.name, ca.name;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_carriers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_carriers() TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Writes take a jsonb patch rather than a long parameter list.
--
-- Two reasons: a defaulted-NULL parameter cannot distinguish "leave alone" from
-- "set to NULL", which matters because api_provider legitimately IS NULL for a
-- manual carrier; and adding a field later would change the signature, which is
-- the PGRST203 overload trap. Keys absent = unchanged. Unknown keys are refused
-- rather than ignored, so a typo fails loudly instead of silently saving
-- nothing — which is the exact failure this migration exists to end.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_update_carrier(
  p_carrier_id uuid,
  p_patch      jsonb,
  p_note       text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_allowed  text[] := ARRAY['fulfillment_gateway','api_provider','default_refill_amount',
                             'gateway_phone_number','is_supported','zen_carrier',
                             'ding_carrier','dt_carrier','reloadly_operator_id'];
  v_bad      text;
  v_before   RECORD;
  v_gateway  text;
  v_provider text;
  v_amount   numeric;
  v_phone    text;
  v_after    RECORD;
BEGIN
  PERFORM public.assert_admin();

  IF p_patch IS NULL OR jsonb_typeof(p_patch) <> 'object' OR p_patch = '{}'::jsonb THEN
    RAISE EXCEPTION 'Nothing to change' USING ERRCODE = 'KS467';
  END IF;

  SELECT string_agg(k, ', ') INTO v_bad
  FROM jsonb_object_keys(p_patch) k WHERE k <> ALL (v_allowed);
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'Unknown field(s): %', v_bad USING ERRCODE = 'KS467';
  END IF;

  SELECT * INTO v_before FROM public.carriers WHERE id = p_carrier_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Carrier % not found', p_carrier_id USING ERRCODE = 'KS461';
  END IF;

  v_gateway  := COALESCE(p_patch ->> 'fulfillment_gateway', v_before.fulfillment_gateway::text);
  v_provider := CASE WHEN p_patch ? 'api_provider'
                     THEN NULLIF(p_patch ->> 'api_provider', '')
                     ELSE v_before.api_provider::text END;
  v_amount   := CASE WHEN p_patch ? 'default_refill_amount'
                     THEN (p_patch ->> 'default_refill_amount')::numeric
                     ELSE v_before.default_refill_amount END;
  v_phone    := CASE WHEN p_patch ? 'gateway_phone_number'
                     THEN NULLIF(btrim(p_patch ->> 'gateway_phone_number'), '')
                     ELSE v_before.gateway_phone_number END;

  IF v_gateway NOT IN ('MANUAL','TASKER_SCRIPT','API') THEN
    RAISE EXCEPTION 'Gateway must be MANUAL, TASKER_SCRIPT or API' USING ERRCODE = 'KS466';
  END IF;

  IF v_provider IS NOT NULL AND v_provider NOT IN ('zendit','reloadly','ding','dtone') THEN
    RAISE EXCEPTION 'API provider must be zendit, reloadly, ding or dtone' USING ERRCODE = 'KS466';
  END IF;

  -- The trap this check exists for: route_topup_execution() copies api_provider
  -- onto every execution it routes. API with a NULL provider produces rows no
  -- worker filters for, so they sit in the queue forever looking healthy.
  IF v_gateway = 'API' AND v_provider IS NULL THEN
    RAISE EXCEPTION 'An API-routed carrier needs an API provider, or its refills will never be claimed'
      USING ERRCODE = 'KS466';
  END IF;

  IF v_gateway <> 'API' AND v_provider IS NOT NULL AND NOT (p_patch ? 'api_provider') THEN
    v_provider := NULL;
  END IF;

  IF v_amount IS NULL OR v_amount <= 0 OR v_amount > 1000 THEN
    RAISE EXCEPTION 'Default refill amount must be between 0.01 and 1000 USD' USING ERRCODE = 'KS466';
  END IF;

  IF v_phone IS NOT NULL AND v_phone !~ '^\+?[0-9][0-9 *#]{4,24}$' THEN
    RAISE EXCEPTION 'Gateway number must be digits, optionally starting with +' USING ERRCODE = 'KS466';
  END IF;

  UPDATE public.carriers SET
    fulfillment_gateway  = v_gateway,
    api_provider         = v_provider,
    default_refill_amount= v_amount,
    gateway_phone_number = v_phone,
    is_supported         = CASE WHEN p_patch ? 'is_supported'
                                THEN (p_patch ->> 'is_supported')::boolean
                                ELSE v_before.is_supported END,
    zen_carrier          = CASE WHEN p_patch ? 'zen_carrier'
                                THEN NULLIF(btrim(p_patch ->> 'zen_carrier'), '')
                                ELSE v_before.zen_carrier END,
    ding_carrier         = CASE WHEN p_patch ? 'ding_carrier'
                                THEN NULLIF(btrim(p_patch ->> 'ding_carrier'), '')
                                ELSE v_before.ding_carrier END,
    dt_carrier           = CASE WHEN p_patch ? 'dt_carrier'
                                THEN NULLIF(btrim(p_patch ->> 'dt_carrier'), '')
                                ELSE v_before.dt_carrier END,
    reloadly_operator_id = CASE WHEN p_patch ? 'reloadly_operator_id'
                                THEN NULLIF(btrim(p_patch ->> 'reloadly_operator_id'), '')
                                ELSE v_before.reloadly_operator_id END
  WHERE id = p_carrier_id;

  SELECT * INTO v_after FROM public.carriers WHERE id = p_carrier_id;

  PERFORM public.admin_log(
    'carrier.update', 'carrier', p_carrier_id::text,
    jsonb_build_object('gateway', v_before.fulfillment_gateway, 'api_provider', v_before.api_provider,
                       'default_refill_amount', v_before.default_refill_amount,
                       'gateway_phone_number', v_before.gateway_phone_number,
                       'is_supported', v_before.is_supported, 'zen_carrier', v_before.zen_carrier,
                       'ding_carrier', v_before.ding_carrier, 'dt_carrier', v_before.dt_carrier),
    jsonb_build_object('gateway', v_after.fulfillment_gateway, 'api_provider', v_after.api_provider,
                       'default_refill_amount', v_after.default_refill_amount,
                       'gateway_phone_number', v_after.gateway_phone_number,
                       'is_supported', v_after.is_supported, 'zen_carrier', v_after.zen_carrier,
                       'ding_carrier', v_after.ding_carrier, 'dt_carrier', v_after.dt_carrier),
    COALESCE(p_note, 'via admin app') || ' (' || v_after.name || ')'
  );

  RETURN jsonb_build_object('success', true, 'carrier_id', p_carrier_id, 'name', v_after.name);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_update_carrier(uuid,jsonb,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_carrier(uuid,jsonb,text) TO authenticated, service_role;
