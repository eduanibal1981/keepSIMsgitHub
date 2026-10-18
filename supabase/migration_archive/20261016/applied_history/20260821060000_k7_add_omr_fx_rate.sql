-- =============================================================================
-- K7 · OMR, so DTOne prices can be converted instead of mislabelled
-- =============================================================================
-- DTOne settles this account in Omani rial. Verified against DTOne's own
-- product export: every price column is headed `(OMR)` and all 16,172 product
-- rows carry SOURCE CURRENCY = OMR. Not some — all.
--
-- `normalizeDtoneProduct` read `source.amount` and stored it as USD, which
-- understates every DTOne cost by ~2.6x (1 OMR = 2.6008 USD) and would sell
-- each refill far below what it costs us.
--
-- providers/dtone.js now REFUSES a non-USD price rather than mislabelling it,
-- so without this row DTOne can contribute nothing at all.
--
-- The rial is PEGGED: 1 OMR = 2.6008 USD, i.e. 1 USD = 0.384500 OMR, held since
-- 1986. `rate_source = 'peg'` is honest about where the number came from; G11's
-- nightly feed only ever UPDATEs currencies already present (never adds), so
-- this row is maintained from here on, and a pegged rate cannot trip the 25%
-- circuit breaker.
--
-- `is_enabled = true`: Oman is one of the 16 supported countries, so OMR belongs
-- in the display picker alongside AED/SAR/EGP, not only in cost conversion.
-- =============================================================================
INSERT INTO public.fx_rates
  (currency_code, display_name, symbol, decimal_digits, usd_to_local, rate_source, rate_as_of, is_enabled)
VALUES
  -- THREE decimal digits, not two. The rial divides into 1000 baisa, and
  -- rendering it at 2 silently drops a digit of precision on every amount.
  ('OMR', 'Omani Rial', 'ر.ع.', 3, 0.38450000, 'peg', now(), true)
ON CONFLICT (currency_code) DO UPDATE
  SET usd_to_local   = EXCLUDED.usd_to_local,
      display_name   = EXCLUDED.display_name,
      symbol         = EXCLUDED.symbol,
      decimal_digits = EXCLUDED.decimal_digits,
      rate_source    = EXCLUDED.rate_source,
      rate_as_of     = EXCLUDED.rate_as_of,
      is_enabled     = EXCLUDED.is_enabled,
      updated_at     = now();
