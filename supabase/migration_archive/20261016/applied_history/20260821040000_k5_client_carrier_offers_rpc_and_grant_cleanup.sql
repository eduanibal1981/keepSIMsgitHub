-- =============================================================================
-- K5 · The client's replacement for reading supplier columns, and one leftover
--      blanket grant on `carriers`
-- =============================================================================
-- The add-line flow has no SIM line yet, so it cannot use `list_refill_offers`.
-- It used to read `carriers.api_provider` plus `zen_carrier` / `dt_carrier` in
-- Dart and query `provider_offers_cache` itself — client-side supplier dispatch
-- over columns K4 has now dropped.
--
-- That shape was also a live defect before the columns went: it could only ever
-- see ONE supplier per carrier, and its `ding` / `reloadly` branches returned a
-- hardcoded empty list that would silently swallow a real catalogue the moment
-- those codes were populated. `carrier_provider_map` is deny-all to clients on
-- purpose — the app has no business dispatching on a supplier name — so the
-- replacement is an RPC that resolves it server-side.
--
-- It also returns `effective_price_usd`, so an operator's manual price appears
-- in the app with no client release.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.list_carrier_offers(p_carrier_id uuid)
RETURNS TABLE (
  provider              text,
  offer_id              text,
  offer_name            text,
  price_type            text,
  price_usd             numeric,
  price_min_usd         numeric,
  price_max_usd         numeric,
  send_min              numeric,
  send_max              numeric,
  send_currency         text,
  send_currency_divisor numeric,
  refreshed_at          timestamptz,
  is_stale              boolean)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  RETURN QUERY
  SELECT o.provider_code, o.offer_code, o.effective_name, o.source_price_type,
         o.effective_price_usd, o.source_price_min_usd, o.source_price_max_usd,
         o.source_send_min, o.source_send_max, o.source_send_currency,
         COALESCE(o.source_send_divisor, 100),
         o.source_refreshed_at,
         (o.source_refreshed_at < now() - interval '24 hours')
  FROM public.provider_offers o
  JOIN public.carrier_supplier_routing r
    ON r.carrier_id = o.carrier_id AND r.provider_code = o.provider_code
  WHERE o.carrier_id = p_carrier_id
    AND o.offer_kind = 'topup'
    AND o.is_active
    -- Only offers that can actually be routed and bought. Listing anything else
    -- is how a tap turns into "offer is not available for this SIM line" — I1's
    -- bug, which came from the list and the purchase path disagreeing.
    AND r.is_routable
  ORDER BY o.effective_price_usd ASC NULLS LAST, r.priority ASC, o.offer_code ASC;
END;
$function$;

REVOKE ALL ON FUNCTION public.list_carrier_offers(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_carrier_offers(uuid) TO authenticated, service_role;

COMMENT ON FUNCTION public.list_carrier_offers(uuid) IS
  'K5: the offers a carrier can be topped up with, for the add-line flow that has '
  'no sim_line id yet. Server-side supplier resolution; the client never sees a '
  'provider code it has to dispatch on.';

-- -----------------------------------------------------------------------------
-- Housekeeping in the area being touched
-- -----------------------------------------------------------------------------
-- `carriers` still carried the default blanket grant, so anon and authenticated
-- held INSERT / UPDATE / DELETE / TRUNCATE on it. Only RLS stood between a
-- client and the table that decides how every refill is routed — and H already
-- proved that a PATCH matching no policy returns HTTP 200 with 0 rows, so a
-- silent failure was the best case. One of the 31 F6 leftovers. The client only
-- ever reads this table.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.carriers FROM anon, authenticated;
GRANT SELECT ON public.carriers TO anon, authenticated;
