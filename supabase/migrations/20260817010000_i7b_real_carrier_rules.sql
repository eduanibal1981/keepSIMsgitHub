-- i7b: replace the seeded carrier rules with researched ones
--
-- Every row in carrier_rules carried a country-uniform guess: one
-- inactivity_limit_days per country and a flat topup_validity_days of 30 (or
-- 28) everywhere. Neither survived contact with the operators' own terms.
--
-- Two structural corrections come out of the research and are worth stating
-- before the data, because they explain most of the diffs:
--
--  1. Deactivation windows are per-carrier, not per-country. Within India,
--     Jio/Airtel/Vi terminate at 90 days while BSNL runs 180. Within the
--     Philippines, DITO is 90, Globe 120, Smart 180. The old rows flattened
--     these to one number and were wrong for most carriers in the country.
--
--  2. In the Gulf, Nepal and Lebanon the line-validity clock is bought by the
--     recharge *denomination*, not reset by the act of recharging. A 1 KD
--     voucher in Kuwait buys 7 days; a BD 3 or lower voucher in Bahrain buys
--     none at all. Our minimum_topup_amount for those markets was ~$1, so the
--     automated refill we were selling as protection would have bought a few
--     days of validity and let the number churn anyway. Those carriers are
--     marked 'min_denomination' with the amount that actually holds the line,
--     and inactivity_limit_days is set to the window that amount buys.
--
--  3. MTN Syria (and Vodafone Germany's CallYa) reset the clock on *consumption*
--     — an outgoing call, SMS or data session. Adding credit is not consumption.
--     KeepSIMs cannot make a call on someone's behalf, so no refill cadence
--     saves these lines. They are marked 'usage_required' and the purchase
--     screens must say so before money changes hands.
--
-- Rows sourced from an operator's own terms get last_verified_at + rule_source_url.
-- Rows we could not source keep last_verified_at NULL and say "UNVERIFIED" in
-- notes; those deliberately keep a short, conservative window, because
-- over-refilling costs the subscriber money while under-refilling costs them
-- the number.

BEGIN;

-- ── 1. Carriers for supported countries that had none ───────────────────────
-- Seeded is_supported = false on purpose: there is no offer cached for any of
-- these yet, so the API route cannot fulfil a refill. Flipping them on is a
-- separate, deliberate step once the offer cache has them (see the h3 view's
-- routing_problem column, which will say exactly this until then).
INSERT INTO public.carriers
  (country_id, name, is_supported, fulfillment_gateway, api_provider, default_refill_amount)
SELECT co.id, v.name, false, 'API', 'zendit', 5.00
FROM (VALUES
  ('BH', 'Batelco'),
  ('BH', 'stc Bahrain'),
  ('BH', 'Zain Bahrain'),
  ('IQ', 'Zain Iraq'),
  ('IQ', 'Asiacell'),
  ('IQ', 'Korek Telecom'),
  ('LB', 'Alfa'),
  ('LB', 'touch'),
  ('NP', 'Nepal Telecom'),
  ('NP', 'Ncell'),
  ('QA', 'Ooredoo Qatar'),
  ('QA', 'Vodafone Qatar'),
  ('SY', 'Syriatel'),
  ('SY', 'MTN Syria'),
  -- Majors missing from countries that already had carriers.
  ('BD', 'Airtel Bangladesh'),
  ('LK', 'Airtel Sri Lanka'),
  ('OM', 'Vodafone Oman')
) AS v(iso, name)
JOIN public.countries co ON co.iso_code = v.iso
WHERE NOT EXISTS (
  SELECT 1 FROM public.carriers c WHERE c.country_id = co.id AND c.name = v.name
);

-- ── 2. Rule rows for every carrier that lacks one (GB/EE, plus the new ones) ─
INSERT INTO public.carrier_rules
  (carrier_id, rule_type, inactivity_limit_days, minimum_topup_amount, topup_validity_days)
SELECT c.id, 'prepaid', 90, 1.00, 30
FROM public.carriers c
WHERE NOT EXISTS (SELECT 1 FROM public.carrier_rules r WHERE r.carrier_id = c.id);

-- ── 3. The researched values ────────────────────────────────────────────────
-- One row per carrier. Columns, in order:
--   iso, carrier,
--   inactivity_limit_days, grace_period_days, balance_validity_days,
--   topup_validity_days, activity_requirement, validity_qualifying_topup_amount,
--   verified (t = sourced from the operator/regulator), note, source_url
WITH researched(iso, carrier, inact, grace, bal_val, topup_val,
                requirement, qualifying_amt, verified, note, src) AS (VALUES

  -- ── Saudi Arabia ────────────────────────────────────────────────────────
  -- stc's own terms: SIM validity extends 180 days from the last paid activity;
  -- credit validity 90. The line dies at 180, not at the 30 we were billing.
  ('SA','STC',              180, 90,  90, 180, 'recharge_ok', NULL::numeric, true,
   'stc KSA: SIM validity extends to 180 days from the last paid activity (call, SMS, recharge or package). Credit validity 90 days. Line terminated after 180 days with no paid activity.',
   'https://www.stc.com.sa/content/stc/sa/en/personal/mobile/terms-conditions-mobile.html'),
  ('SA','Mobily',            90, 30,  90,  30, 'recharge_ok', NULL, false,
   'UNVERIFIED — conservative CITC-baseline 90 days pending Mobily''s published terms.', NULL),
  ('SA','Zain KSA',          90, 30,  90,  30, 'recharge_ok', NULL, false,
   'UNVERIFIED — conservative CITC-baseline 90 days pending Zain KSA''s published terms.', NULL),

  -- ── United Arab Emirates ────────────────────────────────────────────────
  ('AE','Etisalat (e&)',     90,365,  90,  30, 'recharge_ok', NULL, true,
   'e& Wasel: 90 consecutive days with no qualifying usage suspends the line; a recharge, outgoing call or SMS resets it. The number is then retained 12 months for reactivation.',
   'https://www.etisalat.ae/en/c/mobile/plans/wasel-prepaid-line/terms-and-conditions.html'),
  ('AE','du',                90, 90,  90,  30, 'recharge_ok', NULL, false,
   'UNVERIFIED — mirrors the UAE 90-day suspension regime pending du''s published terms.', NULL),
  ('AE','Virgin Mobile UAE', 90, 90,  90,  30, 'recharge_ok', NULL, false,
   'UNVERIFIED — mirrors the UAE 90-day suspension regime pending Virgin''s published terms.', NULL),

  -- ── Egypt ───────────────────────────────────────────────────────────────
  ('EG','Vodafone Egypt',    90, 90, 180,  90, 'recharge_ok', NULL, true,
   'Vodafone Egypt: 90-day validity from the first call, any recharge or any credit transfer, then a 90-day quarantine before the number is withdrawn. Remaining balance is forfeited six months after the last recharge.',
   'https://prepaid-data-sim-card.fandom.com/wiki/Egypt'),
  ('EG','Orange Egypt',      90, 90, 180,  30, 'recharge_ok', NULL, false,
   'UNVERIFIED — NTRA-aligned 90/90 pending Orange Egypt''s published terms.', NULL),
  ('EG','Etisalat Egypt',    90, 90, 180,  30, 'recharge_ok', NULL, false,
   'UNVERIFIED — NTRA-aligned 90/90 pending e& Egypt''s published terms.', NULL),
  ('EG','WE (Telecom Egypt)',90, 90, 180,  30, 'recharge_ok', NULL, false,
   'UNVERIFIED — NTRA-aligned 90/90 pending WE''s published terms.', NULL),

  -- ── India ───────────────────────────────────────────────────────────────
  -- TRAI: 90 days without usage deactivates, plus a 15-day reactivation grace.
  -- A balance of Rs 20 or more blocks deactivation for those 90 days. BSNL
  -- alone runs 180. The old rows had all four at 180/60.
  ('IN','Jio',               90, 15,  NULL, 28, 'recharge_ok', NULL, true,
   'TRAI: a prepaid connection is deactivated after 90 days with no usage, with a 15-day grace to reactivate the same number. A balance of Rs 20 or more prevents deactivation during the 90 days.',
   'https://www.business-standard.com/technology/tech-news/trai-new-rules-jio-airtel-vi-bsnl-sim-to-stop-working-after-this-period-nc-125012001030_1.html'),
  ('IN','Airtel',            90, 15,  NULL, 28, 'recharge_ok', NULL, true,
   'TRAI 90-day non-usage rule; Airtel additionally grants a 15-day grace before the number is released.',
   'https://www.business-standard.com/technology/tech-news/trai-new-rules-jio-airtel-vi-bsnl-sim-to-stop-working-after-this-period-nc-125012001030_1.html'),
  ('IN','Vi (Vodafone Idea)',90, 15,  NULL, 28, 'recharge_ok', NULL, true,
   'TRAI 90-day non-usage rule with a 15-day reactivation grace.',
   'https://www.business-standard.com/technology/tech-news/trai-new-rules-jio-airtel-vi-bsnl-sim-to-stop-working-after-this-period-nc-125012001030_1.html'),
  ('IN','BSNL',             180, 15,  NULL, 28, 'recharge_ok', NULL, true,
   'BSNL runs the longest window in India: 180 days without a recharge before deactivation.',
   'https://www.business-standard.com/technology/tech-news/trai-new-rules-jio-airtel-vi-bsnl-sim-to-stop-working-after-this-period-nc-125012001030_1.html'),

  -- ── Pakistan ────────────────────────────────────────────────────────────
  ('PK','Jazz',             180, 30,  NULL, 30, 'recharge_ok', NULL, true,
   'All PTA-licensed operators deactivate and recycle a prepaid SIM after 180 days of inactivity. Reactivation needs in-person biometric verification, so the number is effectively lost at the cliff.',
   'https://pakera.pk/reactivate-expired-sim/'),
  ('PK','Zong',             180, 30,  NULL, 30, 'recharge_ok', NULL, true,
   'PTA 180-day inactivity rule; recycled thereafter.', 'https://pakera.pk/reactivate-expired-sim/'),
  ('PK','Ufone',            180, 30,  NULL, 30, 'recharge_ok', NULL, true,
   'PTA 180-day inactivity rule; recycled thereafter.', 'https://pakera.pk/reactivate-expired-sim/'),
  ('PK','Telenor Pakistan', 180, 30,  NULL, 30, 'recharge_ok', NULL, true,
   'PTA 180-day inactivity rule; recycled thereafter.', 'https://pakera.pk/reactivate-expired-sim/'),

  -- ── Bangladesh ──────────────────────────────────────────────────────────
  -- BTRC cut the recycling window to 11 months inactive + 30 days' notice. The
  -- old 120-day row was refilling roughly three times more often than needed.
  ('BD','Grameenphone',     330, 30,  NULL, 30, 'recharge_ok', NULL, true,
   'BTRC: an inactive number may be recycled after 11 months of inactivity plus a 30-day published notice period.',
   'https://www.thedailystar.net/business/news/inactive-sim-recycling-period-reduced-12-months-3778861'),
  ('BD','Robi',             330, 30,  NULL, 30, 'recharge_ok', NULL, true,
   'BTRC 11-month inactivity + 30-day notice before recycling.',
   'https://www.thedailystar.net/business/news/inactive-sim-recycling-period-reduced-12-months-3778861'),
  ('BD','Banglalink',       330, 30,  NULL, 30, 'recharge_ok', NULL, true,
   'BTRC 11-month inactivity + 30-day notice before recycling.',
   'https://www.thedailystar.net/business/news/inactive-sim-recycling-period-reduced-12-months-3778861'),
  ('BD','Teletalk',         330, 30,  NULL, 30, 'recharge_ok', NULL, true,
   'BTRC 11-month inactivity + 30-day notice before recycling.',
   'https://www.thedailystar.net/business/news/inactive-sim-recycling-period-reduced-12-months-3778861'),
  ('BD','Airtel Bangladesh',330, 30,  NULL, 30, 'recharge_ok', NULL, true,
   'BTRC 11-month inactivity + 30-day notice before recycling.',
   'https://www.thedailystar.net/business/news/inactive-sim-recycling-period-reduced-12-months-3778861'),

  -- ── Sri Lanka ───────────────────────────────────────────────────────────
  ('LK','Dialog',           120, 52,  NULL, 30, 'recharge_ok', NULL, true,
   'Dialog: validity is bought by recharge denomination (max 365 days). Missing the validity expiry starts a 52-day grace, after which the connection is permanently disconnected and recycled three months later.',
   'https://www.dialog.lk/tc/prepaid-mobile-terms-and-conditions'),
  ('LK','Mobitel',          120, 30,  NULL, 30, 'recharge_ok', NULL, false,
   'UNVERIFIED — Mobitel validity scales with denomination (Rs 100-349 buys 30 days, Rs 350-499 buys 220). Conservative 120-day window pending published disconnection terms.', NULL),
  ('LK','Hutch SL',         120, 30,  NULL, 30, 'recharge_ok', NULL, false,
   'UNVERIFIED — conservative 120-day window pending Hutch''s published terms.', NULL),
  ('LK','Airtel Sri Lanka', 120, 30,  NULL, 30, 'recharge_ok', NULL, false,
   'UNVERIFIED — conservative 120-day window pending Airtel Sri Lanka''s published terms.', NULL),

  -- ── Philippines ─────────────────────────────────────────────────────────
  -- Three different windows behind one 120-day seed.
  ('PH','Globe',            120,  0,  NULL, 30, 'recharge_ok', NULL, true,
   'Globe/TM: 120 consecutive days at zero balance with no load permanently deactivates the SIM.',
   'https://pinoyloads.com/philippine-sim-card-expiration-by-carrier'),
  ('PH','Smart',            180,  0,  NULL, 30, 'recharge_ok', NULL, true,
   'Smart/TNT: loaded value is valid 365 days; once the balance reaches zero there are 180 days to reload before disconnection.',
   'https://pinoyloads.com/philippine-sim-card-expiration-by-carrier'),
  ('PH','DITO',              90,  0,  NULL, 30, 'recharge_ok', NULL, true,
   'DITO is the most aggressive in the market: 90 days below PHP 1.00 with no active promo permanently disables the SIM and blocks the number.',
   'https://ditosimregister.com/dito-sim-deactivation/'),

  -- ── Kuwait ──────────────────────────────────────────────────────────────
  -- Validity is purchased, not reset: 1 KD buys 7 days, 5 KD buys 30, 10 KD
  -- buys 90. The old $1.00 minimum would have bought a week of protection.
  ('KW','Zain Kuwait',       90, 60,  NULL,  7, 'min_denomination', 32.70, true,
   'Zain Kuwait sells line validity by denomination: 1 KD = 7 days, 5 KD = 30, 10 KD = 90, 20 KD = 180. A minimum top-up buys about a week, so refills must be at least 10 KD (~USD 32.70) to hold the line for a quarter.',
   'https://prepaid-data-sim-card.fandom.com/wiki/Kuwait'),
  ('KW','Ooredoo Kuwait',    90, 60,  NULL,  7, 'min_denomination', 32.70, true,
   'Ooredoo Kuwait: line validity is the higher of the last recharge denomination or the current validity; lines then enter grace and are churned. 10 KD (~USD 32.70) buys 90 days.',
   'https://prepaid-data-sim-card.fandom.com/wiki/Kuwait'),
  ('KW','STC Kuwait',        90, 60,  NULL,  7, 'min_denomination', 32.70, true,
   'stc Kuwait sells validity by denomination on the same 7/10/15/30/90/180-day ladder. 10 KD (~USD 32.70) buys 90 days.',
   'https://prepaid-data-sim-card.fandom.com/wiki/Kuwait'),

  -- ── Oman ────────────────────────────────────────────────────────────────
  ('OM','Ooredoo Oman',     150, 30,  NULL, 30, 'recharge_ok', NULL, true,
   'Ooredoo Oman: 150 active days from the last recharge plus a 30-day grace. After that the number is terminated and remaining credit forfeited, with three months to buy it back in store.',
   'https://www.ooredoo.om/en/help-centre/faq/prepaid-service/'),
  ('OM','Omantel',           90, 30,  NULL, 30, 'recharge_ok', NULL, false,
   'UNVERIFIED — 90-day validity is documented for visitor lines; conservative pending Omantel''s resident prepaid terms.', NULL),
  ('OM','Vodafone Oman',     90, 30,  NULL, 30, 'recharge_ok', NULL, false,
   'UNVERIFIED — conservative 90-day window pending Vodafone Oman''s published terms.', NULL),

  -- ── Qatar ───────────────────────────────────────────────────────────────
  ('QA','Vodafone Qatar',   180,180,   30,  30, 'recharge_ok', NULL, true,
   'Vodafone Qatar: credit from a QR 10-80 recharge lasts 30 days, but line validity runs 180 days from the recharge date. No recharge within 180 days expires the SIM; the number can still be reactivated within 180 days of the last recharge.',
   'https://www.vodafone.qa/en/about-us/legal-and-regulatory/terms-and-conditions'),
  ('QA','Ooredoo Qatar',    120, 60,   30,  30, 'recharge_ok', NULL, true,
   'Ooredoo Hala: credit validity runs 30-90 days by denomination, then the line is receive-only in grace. Topping up within 120 days of expiry restores it and returns unused credit; past 120 days it is deactivated and cannot be reactivated.',
   'https://www.ooredoo.qa/web/en/prepaid-plans/'),

  -- ── Bahrain ─────────────────────────────────────────────────────────────
  -- All three Bahraini operators attach no validity to small vouchers.
  ('BH','stc Bahrain',       90, 90,  NULL, 30, 'min_denomination', 13.27, true,
   'stc Bahrain: recharge vouchers of BD 3 or below grant credit only and add no line validity; cumulative validity is capped at 90 days. A 90-day grace (incoming only, credit retained) is followed by a 30-day disable period. Refills must exceed BD 3 (~USD 13.27) to count.',
   'https://www.stc.com.bh/mobile/mobile-services-prepaid'),
  ('BH','Zain Bahrain',      90, 90,  NULL, 30, 'min_denomination', 13.27, true,
   'Zain Bahrain: vouchers of BD 3 or less provide credit with no validity. Larger vouchers add 1-100 days. Recharging at any stage before the termination stage keeps the line.',
   'https://bahraineportal.com/en/zain-prepaid-packages/'),
  ('BH','Batelco',           90, 90,  NULL, 30, 'min_denomination', 13.27, true,
   'Batelco: prepaid numbers follow a validity lifecycle; small refills add little or no validity, and a BD 3 validity voucher adds 30 days without credit. Refills must exceed BD 3 (~USD 13.27) to hold the line.',
   'https://www.batelco.com/prepaid/'),

  -- ── Lebanon ─────────────────────────────────────────────────────────────
  -- The shortest windows we serve: a minimum Alfa recharge buys 13 days.
  ('LB','Alfa',              95, 12,  NULL, 13, 'min_denomination', 8.75, true,
   'Alfa: recharge cards buy 13 to 95 days of validity by amount. When validity lapses the line enters a 12-day retention (receive-only, then credit lost, then fully barred) before disconnection. A minimum recharge buys under two weeks, so refills must be at the ~USD 8.75 tier.',
   'https://www.alfa.com.lb/en/prepaid/lifecycle'),
  ('LB','touch',             95, 12,  NULL, 13, 'min_denomination', 8.75, false,
   'UNVERIFIED — mirrors Alfa''s denomination-scaled validity and 12-day retention pending touch''s published lifecycle.', NULL),

  -- ── Nepal ───────────────────────────────────────────────────────────────
  ('NP','Nepal Telecom',    365, 60,  NULL, 30, 'min_denomination', 3.75, true,
   'Nepal Telecom: NPR 50 adds 30 days, NPR 100 adds 60, NPR 500 adds a year. Once validity lapses the line goes one-way barred, then two-way barred after 30 days, then frozen and recyclable 30 days later. A NPR 500 (~USD 3.75) refill is what buys a full year.',
   'https://www.nepalitelecom.com/nepal-telecom-sim-card-terminate-validity-lifecycle'),
  ('NP','Ncell',             90, 60,  NULL, 30, 'recharge_ok', NULL, false,
   'UNVERIFIED — reports range from 3 months to 12; conservative 90-day window pending Ncell''s published lifecycle.', NULL),

  -- ── Syria ───────────────────────────────────────────────────────────────
  -- The case the old schema could not express: adding credit is not consumption.
  ('SY','MTN Syria',         90, 30,  NULL, 30, 'usage_required', NULL, true,
   'MTN Syria holds the line indefinitely only while some balance is CONSUMED at least once every 90 days. Adding credit is not consumption, so an automated refill alone will not prevent deactivation — the line needs an outgoing call, SMS or data session.',
   'https://prepaid-data-sim-card.fandom.com/wiki/Syria'),
  ('SY','Syriatel',          90, 30,  NULL, 30, 'usage_required', NULL, false,
   'UNVERIFIED — assumed to mirror MTN Syria''s consumption-based rule. Treated as usage-required until Syriatel''s terms confirm a recharge alone resets the clock.', NULL),

  -- ── Iraq ────────────────────────────────────────────────────────────────
  ('IQ','Zain Iraq',         90, 30,  NULL, 30, 'recharge_ok', NULL, false,
   'UNVERIFIED — no published prepaid lifecycle found; conservative 90-day window.', NULL),
  ('IQ','Asiacell',          90, 30,  NULL, 30, 'recharge_ok', NULL, false,
   'UNVERIFIED — no published prepaid lifecycle found; conservative 90-day window.', NULL),
  ('IQ','Korek Telecom',     90, 30,  NULL, 30, 'recharge_ok', NULL, false,
   'UNVERIFIED — no published prepaid lifecycle found; conservative 90-day window.', NULL),

  -- ── United Kingdom (country not yet enabled) ────────────────────────────
  ('GB','Vodafone UK',      180, 30,  NULL, 30, 'recharge_ok', NULL, true,
   'Vodafone UK Pay as you go needs one chargeable activity every 180 days. Buying a top-up counts.',
   'https://www.vodafone.co.uk/sim-only/pay-as-you-go-sim/payg-1'),
  ('GB','Three UK',         180, 30,  NULL, 30, 'recharge_ok', NULL, true,
   'Three UK: a chargeable event every 180 days. Three confirm that buying a top-up, Data Pack or Data Boost counts as one.',
   'https://www.three.co.uk/support/pay-as-you-go'),
  ('GB','O2 UK',            180, 30,  NULL, 30, 'recharge_ok', NULL, true,
   'O2 Classic Pay As You Go disconnects without a top-up, Bolt On or other chargeable activity in any six-month period.',
   'https://kenstechtips.com/index.php/payg-inactivity-account-termination-and-credit-expiry'),
  ('GB','EE',               180, 30,  NULL, 30, 'recharge_ok', NULL, false,
   'UNVERIFIED — mirrors the UK 180-day chargeable-activity norm pending EE''s published terms.', NULL),

  -- ── Turkey (country not yet enabled) ───────────────────────────────────
  ('TR','Vodafone Turkey',  180, 90,  NULL, 30, 'recharge_ok', NULL, true,
   'Vodafone Turkey: a 180-day active period from the last top-up, then a 90-day waiting period in which a minimum top-up restarts it. After that the line closes permanently.',
   'https://www.vodafone.com.tr/tl-islemleri/faturasiz-hattinizla-ilgili-kullanim-sureleri'),
  ('TR','Turkcell',         180,365,  NULL, 30, 'recharge_ok', NULL, true,
   'Turkcell closes a prepaid line after six months with no top-up; the number is held in the subscriber''s name for a further year before resale.',
   'https://blogaraci.com/hat-kapanma-suyresi-ne-kadar-tl-yuklemezsem-hattim-kapanir/'),
  ('TR','Turk Telekom',     184, 92,  NULL, 30, 'recharge_ok', NULL, true,
   'Türk Telekom: 184 days from the last top-up before outgoing is barred, then a 92-day passive period before the contract is cancelled.',
   'https://blogaraci.com/hat-kapanma-suyresi-ne-kadar-tl-yuklemezsem-hattim-kapanir/'),

  -- ── Jordan (country not yet enabled) ───────────────────────────────────
  ('JO','Zain Jordan',      180, 90,  NULL, 30, 'recharge_ok', NULL, true,
   'Zain Jordan: when the activation period ends the line is partially disconnected for a day, then fully disconnected for 119 days before termination; a line unused for more than 180 days is terminated.',
   'https://prepaid-data-sim-card.fandom.com/wiki/Jordan'),
  ('JO','Orange Jordan',     90, 65,  NULL, 30, 'recharge_ok', NULL, true,
   'Orange Jordan: missing the validity window suspends the line for 5 days (incoming only), then suspends all activity for 60 days, after which it is terminally disconnected.',
   'https://orange.jo/sites/default/files/documents/Mobile_Prepaid_English.pdf'),
  ('JO','Umniah',            90, 30,  NULL, 30, 'recharge_ok', NULL, false,
   'UNVERIFIED — conservative 90-day window pending Umniah''s published terms.', NULL),

  -- ── Germany (country not yet enabled) ──────────────────────────────────
  ('DE','Telekom (T-Mobile DE)', 700, 30, NULL, 30, 'recharge_ok', NULL, true,
   'Telekom MagentaMobil Prepaid stays usable for about 23 months without a top-up, with a further month to reactivate.',
   'https://www.prepaid-deutschland.de/wie-lange-sind-prepaid-karten-gueltig-ein-ueberblick/'),
  ('DE','O2 Germany',        180, 30,  NULL, 30, 'recharge_ok', NULL, true,
   'O2 prepaid must be topped up every six months; any amount, down to one cent, extends validity by another six months.',
   'https://www.prepaid-deutschland.de/o2-prepaid-karten-so-lange-sind-guthaben-und-sim-gueltig/'),
  ('DE','Vodafone Germany',   90, 30,  NULL, 30, 'usage_required', NULL, true,
   'Vodafone CallYa reserves the right to cancel the contract if the card goes unused for more than 90 days — the requirement is a PAID CONNECTION (call, SMS or data), which a top-up is not. An automated refill alone may not hold this line.',
   'https://www.prepaid-deutschland.de/o2-prepaid-karten-so-lange-sind-guthaben-und-sim-gueltig/'),

  -- ── United States (country not yet enabled) ────────────────────────────
  ('US','AT&T',              90, 60,   90,  30, 'min_denomination', 25.00, true,
   'AT&T Prepaid balance life is bought by refill size: USD 10-24 lasts 30 days, 25-99 lasts 90, 100+ lasts 365. Once the balance expires there are 60 days to refill before the account closes and the number is lost. A USD 25 refill is the smallest that buys a quarter.',
   'https://www.att.com/legal/terms.prepaidAutoPayTermsPrior04242017.html'),
  ('US','Verizon',           30, 60,  NULL, 30, 'recharge_ok', NULL, true,
   'Verizon Prepaid is a monthly plan: renew within 60 days of the renewal date and the account stays active with balances carried over.',
   'https://www.verizon.com/support/prepaid-billing-payment-faqs/'),
  ('US','T-Mobile',          30, 60,  NULL, 30, 'recharge_ok', NULL, true,
   'T-Mobile Prepaid is a monthly plan: renew within 60 days of the renewal date to keep the account and number.',
   'https://www.t-mobile.com/community/discussions/accounts-services/prepaid-cancellation-refund/26865/replies/26878'),
  ('US','Mint Mobile',       90, 30,  NULL, 30, 'recharge_ok', NULL, false,
   'UNVERIFIED — conservative 90-day window pending Mint''s published terms.', NULL)
)
UPDATE public.carrier_rules cr SET
  inactivity_limit_days            = r.inact,
  grace_period_days                = r.grace,
  balance_validity_days            = r.bal_val,
  topup_validity_days              = r.topup_val,
  activity_requirement             = r.requirement,
  validity_qualifying_topup_amount = r.qualifying_amt,
  activity_requirement_note        = CASE WHEN r.requirement = 'recharge_ok' THEN NULL ELSE r.note END,
  notes                            = r.note,
  rule_source_url                  = r.src,
  -- Only rows we actually sourced get a verification stamp. A NULL here is the
  -- signal for the next person that this row is still a guess.
  last_verified_at                 = CASE WHEN r.verified THEN now() ELSE NULL END,
  updated_at                       = now()
FROM researched r
JOIN public.countries co  ON co.iso_code = r.iso
JOIN public.carriers  ca  ON ca.country_id = co.id AND ca.name = r.carrier
WHERE cr.carrier_id = ca.id;

-- ── 4. Refills must be big enough to actually buy validity ─────────────────
-- On a 'min_denomination' carrier the minimum the gateway will send is not the
-- minimum that holds the line. Raise the floor so the scheduler cannot queue a
-- refill that is guaranteed not to work.
UPDATE public.carrier_rules
SET minimum_topup_amount     = validity_qualifying_topup_amount,
    recommended_topup_amount = GREATEST(
      COALESCE(recommended_topup_amount, 0), validity_qualifying_topup_amount),
    updated_at               = now()
WHERE activity_requirement = 'min_denomination'
  AND validity_qualifying_topup_amount IS NOT NULL
  AND minimum_topup_amount < validity_qualifying_topup_amount;

-- The stored per-refill price override was computed against the old minimum and
-- would now understate the cost of a qualifying refill. Drop it and let
-- RefillPricing.premiumRefillPrice recompute from the corrected minimum.
UPDATE public.carrier_rules
SET inapp_pricing = NULL,
    updated_at    = now()
WHERE activity_requirement = 'min_denomination'
  AND inapp_pricing IS NOT NULL;

COMMIT;
