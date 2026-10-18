-- B1 (refill engine audit), part 1 of 2. Applied to live 2026-07-16.
-- 1) Fix carriers.zen_carrier values that don't match Zendit's brand codes.
--    The Offers-API fallback filters ?brand=<zen_carrier>; these five silently
--    returned an empty catalog (verified against the sandbox on 2026-07-16).
UPDATE public.carriers SET zen_carrier = 'Att'          WHERE zen_country = 'United States' AND zen_carrier = 'AT&T';
UPDATE public.carriers SET zen_carrier = 'Tmobile'      WHERE zen_country = 'United States' AND zen_carrier = 'T-Mobile';
UPDATE public.carriers SET zen_carrier = 'TurkTelekom'  WHERE zen_country = 'Turkey'        AND zen_carrier = 'Turk Telekom';
UPDATE public.carriers SET zen_carrier = 'VodafoneIdea' WHERE zen_country = 'India'         AND zen_carrier = 'Vi';
UPDATE public.carriers SET zen_carrier = 'WETelecom'    WHERE zen_country = 'Egypt'         AND zen_carrier = 'WE';

-- 2) Pin verified sandbox offers on carrier_rules that had offer_id NULL.
--    Convention (matches existing rows): cheapest FIXED "Mobile Top Up" offer,
--    offer_value NULL; or an OPEN RANGE offer with offer_value = send.min
--    (send-currency minor units, the unit the purchase API's ZEND value takes).
--    minimum/recommended amounts realigned to the pinned offer's USD price so
--    the app can't schedule amounts Zendit can't fulfil.
UPDATE public.carrier_rules cr
SET offer_id = v.offer_id,
    offer_value = v.offer_value,
    minimum_topup_amount = v.min_usd,
    recommended_topup_amount = v.rec_usd,
    last_verified_at = now(),
    notes = COALESCE(cr.notes || ' ', '') || '[B1 2026-07-16: offer pinned from Zendit sandbox catalog]'
FROM (VALUES
  ('United States', 'Att',          'ATT_US_10',              NULL::bigint, 10.00, 10.00),
  ('United States', 'Tmobile',      'T-MOBILE_US_10-WS',      NULL,         10.00, 10.00),
  ('United States', 'Verizon',      'VERIZON_US_001-ROW_005', NULL,          5.00,  5.00),
  ('Egypt',         'Etisalat',     'ETISALAT_EG_001',        NULL,          0.25,  0.25),
  ('Turkey',        'TurkTelekom',  'TURKTELECOM_TR_004_USD', NULL,         15.00, 15.00),
  ('India',         'VodafoneIdea', 'VODAFONEIDEA_IN_7_FEE',  NULL,          9.00,  9.00),
  ('Pakistan',      'Zong',         'ZONG_PK_OPEN',           7898,          0.32,  0.50)
) AS v(zc, zb, offer_id, offer_value, min_usd, rec_usd)
JOIN public.carriers c ON c.zen_country = v.zc AND c.zen_carrier = v.zb
WHERE cr.carrier_id = c.id AND cr.offer_id IS NULL;
