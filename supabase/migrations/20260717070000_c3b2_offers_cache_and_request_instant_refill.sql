-- C3b-2 (2/4): the server prices instant refills; the client only names an
-- offer. zendit_offers_cache is the server-side copy of Zendit's price list
-- (refreshed by the VM's worker_offers_cache), and request_instant_refill is
-- the only way a client starts an instant refill: it looks the offer up in the
-- line's own country/carrier catalog and sets base_cost_usd itself, so the
-- C3b-1 exploit ("name a $6.22 offer, declare $0.01") has no client input left
-- to tamper with. The C3b-1 worker check stays as the drift guard: if the
-- cache lags a Zendit reprice, the worker rejects the mismatch and refunds.

CREATE TABLE public.zendit_offers_cache (
  offer_id        text PRIMARY KEY,
  country_code    text NOT NULL,          -- ISO-2, matches countries.iso_code
  zen_carrier     text NOT NULL,          -- Zendit brand, matches carriers.zen_carrier
  offer_name      text,
  price_type      text NOT NULL CHECK (price_type IN ('FIXED', 'RANGE')),
  price_fixed_usd numeric,                -- FIXED only
  price_min_usd   numeric,                -- RANGE only
  price_max_usd   numeric,
  send_min        numeric,                -- RANGE only: receiver-value bounds
  send_max        numeric,
  send_currency   text,
  refreshed_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT zendit_offers_cache_fixed_priced CHECK (price_type <> 'FIXED' OR price_fixed_usd IS NOT NULL),
  CONSTRAINT zendit_offers_cache_range_priced CHECK (price_type <> 'RANGE' OR (price_min_usd IS NOT NULL AND price_max_usd IS NOT NULL AND send_min IS NOT NULL AND send_max IS NOT NULL))
);

CREATE INDEX idx_zendit_offers_cache_catalog ON public.zendit_offers_cache (country_code, zen_carrier);

ALTER TABLE public.zendit_offers_cache ENABLE ROW LEVEL SECURITY;

-- Clients read it (the manual-refill sheet lists offers from here); only the
-- VM worker (service role) writes it.
CREATE POLICY "Authenticated can read offers cache" ON public.zendit_offers_cache
  FOR SELECT TO authenticated USING (true);

REVOKE ALL ON public.zendit_offers_cache FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.zendit_offers_cache FROM authenticated;

-- The one entry point for instant refills. Pricing rules mirror
-- servers/offer_validation.js: FIXED offers cost exactly their catalog price
-- (the client sends no price at all); RANGE offers take the user's chosen USD
-- amount, which must sit inside the range, and the receiver value is
-- interpolated from it so paying the minimum cannot claim the maximum.
CREATE OR REPLACE FUNCTION public.request_instant_refill(
  p_sim_line_id uuid,
  p_offer_id text,
  p_payment_gateway_code text,
  p_amount_usd numeric DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_iso text;
  v_zen_carrier text;
  v_offer RECORD;
  v_base numeric;
  v_value numeric;
  v_execution_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  -- Line ownership (owner or accepted household manager), and the line's own
  -- Zendit catalog coordinates in one lookup.
  SELECT co.iso_code, ca.zen_carrier
  INTO v_iso, v_zen_carrier
  FROM public.sim_lines sl
  JOIN public.countries co ON co.id = sl.country_id
  JOIN public.carriers ca ON ca.id = sl.carrier_id
  WHERE sl.id = p_sim_line_id
    AND (sl.user_id = auth.uid()
         OR EXISTS (SELECT 1 FROM public.household_members hm
                    WHERE hm.owner_id = sl.user_id
                      AND hm.member_id = auth.uid()
                      AND hm.invite_status = 'accepted'
                      AND hm.role = 'manager'));

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Not authorized to refill this SIM line';
  END IF;

  IF v_zen_carrier IS NULL THEN
    RAISE EXCEPTION 'This carrier has no online top-up catalog';
  END IF;

  -- The offer must be in THIS line's country/carrier catalog: naming another
  -- carrier's offer is the same tampering C3b-1 blocks at spend time.
  SELECT * INTO v_offer
  FROM public.zendit_offers_cache z
  WHERE z.offer_id = p_offer_id
    AND z.country_code = v_iso
    AND z.zen_carrier = v_zen_carrier;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Offer % is not available for this SIM line', p_offer_id;
  END IF;

  -- A dead refresher must not let month-old prices buy things. Within the
  -- window, drift is caught by the worker check at spend time.
  IF v_offer.refreshed_at < now() - interval '24 hours' THEN
    RAISE EXCEPTION 'Offer pricing is temporarily unavailable. Please try again later.';
  END IF;

  IF v_offer.price_type = 'FIXED' THEN
    v_base := v_offer.price_fixed_usd;
    v_value := NULL;
  ELSE
    IF p_amount_usd IS NULL THEN
      RAISE EXCEPTION 'This offer requires an amount';
    END IF;
    v_base := round(p_amount_usd, 2);
    IF v_base < v_offer.price_min_usd - 0.01 OR v_base > v_offer.price_max_usd + 0.01 THEN
      RAISE EXCEPTION 'Amount % is outside this offer''s %-% USD range',
        v_base, v_offer.price_min_usd, v_offer.price_max_usd;
    END IF;
    -- Same interpolation as offer_validation.js interpolateSendValue().
    v_value := least(v_offer.send_max, greatest(v_offer.send_min, round(
      v_offer.send_min
      + CASE WHEN v_offer.price_max_usd - v_offer.price_min_usd > 0
             THEN (v_base - v_offer.price_min_usd)
                  * (v_offer.send_max - v_offer.send_min)
                  / (v_offer.price_max_usd - v_offer.price_min_usd)
             ELSE 0 END)));
  END IF;

  IF v_base IS NULL OR v_base <= 0 THEN
    RAISE EXCEPTION 'Offer % has no usable price', p_offer_id;
  END IF;

  -- BEFORE INSERT triggers do the rest: check_topup_rate_limit throttles,
  -- calculate_topup_fees computes amount from base_cost_usd + gateway, and
  -- route_topup_execution bumps a pending instant refill to 'routing' for the
  -- worker to claim.
  INSERT INTO public.topup_executions (
    sim_line_id, user_id, amount, base_cost_usd, payment_gateway_code,
    currency, status, execution_type, execution_time, offer_id, offer_value
  ) VALUES (
    p_sim_line_id, auth.uid(), v_base, v_base, p_payment_gateway_code,
    'USD', 'pending', 'refill_instant', now(), p_offer_id, v_value
  )
  RETURNING id INTO v_execution_id;

  RETURN v_execution_id;
END;
$$;

REVOKE ALL ON FUNCTION public.request_instant_refill(uuid, text, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_instant_refill(uuid, text, text, numeric) TO authenticated;