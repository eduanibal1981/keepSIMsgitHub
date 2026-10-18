-- =============================================================================
-- K8 · A mapping must speak its provider's dialect, enforced at write time
-- =============================================================================
-- `carrier_provider_map` for dtone:STC held the string 'STC' where DTOne
-- requires a numeric operator id (3221). The adapter's
-- `if (carrierCode && !isNaN(carrierCode))` then SILENTLY dropped the
-- operator_id filter, fetched the whole country, matched nothing, and fell back
-- to fabricated products. Months of "DTOne has no STC offers" traced to one
-- wrong-shaped string that nothing was checking.
--
-- `service_providers` has DECLARED each supplier's conventions since K1
-- (country_label_style / carrier_label_style). Until now that declaration was
-- decorative. This makes it load-bearing.
--
-- The four dialects, confirmed against each adapter's actual request:
--   zendit    country=ISO2   brand=brand string   (`&country=SA&brand=STC`)
--   dtone     country=ISO3   operator_id=numeric  (`&country_iso_code=SAU&operator_id=3221`)
--   ding      countryIsos=ISO2   providerCodes=string
--   reloadly  /operators/countries/{ISO2}   operatorId=numeric
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Remove the mappings that cannot work
-- -----------------------------------------------------------------------------
-- All 11 matched: DTOne, disabled, in countries with is_supported = false
-- (GB/JO/US), every one holding a brand name where a numeric operator id is
-- required. A mapping with a wrong code is worse than no mapping — it reads as
-- configured. They can be re-added correctly through operator discovery if
-- those countries are ever enabled.
DELETE FROM public.carrier_provider_map m
USING public.service_providers sp
WHERE sp.code = m.provider
  AND NOT m.is_enabled
  AND sp.carrier_label_style = 'numeric_id'
  AND m.provider_carrier_code !~ '^[0-9]+$';

-- -----------------------------------------------------------------------------
-- 2. The guard, folded into the trigger already on this table
-- -----------------------------------------------------------------------------
-- One trigger rather than two, so there is a single place to look when a write
-- is refused.
CREATE OR REPLACE FUNCTION public.trg_fn_carrier_map_provider_sells_topup()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_sp RECORD;
BEGIN
  SELECT supports_topup, country_label_style, carrier_label_style
  INTO v_sp
  FROM public.service_providers
  WHERE code = NEW.provider;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unknown provider %', NEW.provider USING ERRCODE = 'KS461';
  END IF;

  IF NOT v_sp.supports_topup THEN
    RAISE EXCEPTION 'Provider % does not sell mobile top-ups', NEW.provider
      USING ERRCODE = 'KS466';
  END IF;

  IF v_sp.country_label_style = 'iso2' AND NEW.provider_country_code !~ '^[A-Z]{2}$' THEN
    RAISE EXCEPTION '% expects an ISO-2 country code, got "%"', NEW.provider, NEW.provider_country_code
      USING ERRCODE = 'KS466', HINT = 'Two uppercase letters, e.g. SA.';
  ELSIF v_sp.country_label_style = 'iso3' AND NEW.provider_country_code !~ '^[A-Z]{3}$' THEN
    RAISE EXCEPTION '% expects an ISO-3 country code, got "%"', NEW.provider, NEW.provider_country_code
      USING ERRCODE = 'KS466', HINT = 'Three uppercase letters, e.g. SAU.';
  ELSIF v_sp.country_label_style = 'numeric' AND NEW.provider_country_code !~ '^[0-9]+$' THEN
    RAISE EXCEPTION '% expects a numeric country id, got "%"', NEW.provider, NEW.provider_country_code
      USING ERRCODE = 'KS466';
  END IF;

  -- The check that would have caught dtone:STC = 'STC' the day it was written.
  IF v_sp.carrier_label_style = 'numeric_id' AND NEW.provider_carrier_code !~ '^[0-9]+$' THEN
    RAISE EXCEPTION '% identifies operators by numeric id, got "%"', NEW.provider, NEW.provider_carrier_code
      USING ERRCODE = 'KS466',
            HINT = 'Use the OPERATOR ID from the provider (e.g. 3221 for STC Saudi Arabia), not the brand name.';
  END IF;

  IF btrim(COALESCE(NEW.provider_carrier_code, '')) = '' THEN
    RAISE EXCEPTION 'A mapping needs the supplier''s carrier code' USING ERRCODE = 'KS466';
  END IF;

  NEW.updated_at := now();
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.trg_fn_carrier_map_provider_sells_topup() FROM PUBLIC, anon, authenticated;

COMMENT ON FUNCTION public.trg_fn_carrier_map_provider_sells_topup() IS
  'K8: a mapping must speak its provider''s declared dialect. '
  'service_providers.*_label_style stopped being decorative here — a brand name '
  'where a numeric operator id belongs is now refused instead of silently '
  'dropping the operator filter.';

-- -----------------------------------------------------------------------------
-- NOTE ON THE OPERATOR IDS THEMSELVES
-- -----------------------------------------------------------------------------
-- The correct DTOne ids (3221 STC SA, 1811/1812/1813 Kuwait, 2097/2098 UAE, …)
-- were applied as DATA through `admin_upsert_carrier_provider_map`, so each
-- carries an `admin_audit_log` row naming who changed it and why. They are
-- deliberately NOT seeded here: operator ids are operator-editable reference
-- data, not schema, and a migration that hardcodes them would fight the admin
-- UI the next time a provider renumbers.
--
-- Source of those ids: DTOne's own product export, filtered to SERVICE=Mobile /
-- SUBSERVICE=Airtime. That export also established that DTOne sells NO direct
-- recharge in Saudi Arabia, Oman or Qatar — only FIXED_VALUE_PIN_PURCHASE,
-- which a subscriber must redeem by hand and which therefore cannot keep a line
-- alive. Those mappings are recorded but disabled, with the reason in `notes`.
