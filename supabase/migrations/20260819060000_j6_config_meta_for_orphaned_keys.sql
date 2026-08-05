-- J6 — make eleven switches operable.
--
-- `validate_config_value()` returns "<key> is not a known configuration key"
-- for any key with no `system_config_meta` row, and `admin_set_config()` turns
-- that into KS466. So a config row without a meta row is not merely unlabelled
-- in the admin Settings screen — it is UNSETTABLE from the admin app entirely.
--
-- Proven, not inferred: `admin_set_config('AFFILIATE_ENABLED','true')` under a
-- real power-user JWT answered KS466 "is not a known configuration key".
--
-- Two features shipped with that defect:
--   * J2's affiliate rail (4 keys). AFFILIATE_ENABLED is the master switch the
--     entire rail waits on, so the feature could never have been turned on —
--     the owner went looking for it in Settings and it was not there.
--   * I5's supplier failover (7 keys). SUPPLIER_RETRY_ENABLED likewise, which
--     means that feature has been unswitchable since the day it was built.
--
-- This is the "control that ships dead" sibling of the dead-guard pattern that
-- has now recurred five times in this project. It passes every check the
-- pre-production stance asks for — the flag exists, it defaults to off, it
-- looks conservative — and it cannot be moved. The test to add for next time is
-- not "does the flag default to off" but **"can the owner actually flip it from
-- the admin app?"**

BEGIN;

INSERT INTO public.system_config_meta
  (config_key, label, group_name, value_type, min_value, max_value, unit, description, is_sensitive, is_readonly, sort_order)
VALUES
  -- ── Affiliate rail (J2) ────────────────────────────────────────────────
  ('AFFILIATE_ENABLED', 'Show partner deals', 'Partner deals', 'bool',
   NULL, NULL, NULL,
   'Master switch. While this is off, compare_esim_offers() returns only eSIMs we sell ourselves and no partner deal appears anywhere in the app, however many are staged. record_affiliate_click() also refuses.',
   false, false, 10),

  ('AFFILIATE_PRICE_MAX_AGE_DAYS', 'Partner price expires after', 'Partner deals', 'int',
   1, 365, 'days',
   'Partner prices are typed in by hand because the networks publish no product feed. Past this age the app stops quoting the number and shows "Price on partner site" instead. Lower is more honest and more work.',
   false, false, 20),

  ('AFFILIATE_MAX_PARTNER_ROWS', 'Max partner rows per search', 'Partner deals', 'int',
   1, 200, 'rows',
   'Ceiling on how many partner offers one comparison may contain, so a single partner cannot flood the list.',
   false, false, 30),

  ('RATE_LIMIT_AFFILIATE_CLICK', 'Outbound click limit', 'Rate limits', 'rate_limit',
   NULL, NULL, NULL,
   'Calls/minutes for record_affiliate_click. A click writes an attribution row and returns a tracked URL, so this stops one account generating unlimited rows.',
   false, false, 150),

  -- ── Supplier failover (I5) — pre-existing gap, identical cause ─────────
  ('SUPPLIER_RETRY_ENABLED', 'Retry at next supplier', 'Refill engine', 'bool',
   NULL, NULL, NULL,
   'When a top-up fails, automatically retry it at the next-cheapest supplier. Has been unswitchable from this screen since I5 built it.',
   false, false, 100),

  ('SUPPLIER_RETRY_MAX_ATTEMPTS', 'Max supplier attempts', 'Refill engine', 'int',
   1, 5, 'attempts',
   'How many suppliers one top-up may be tried at before it is left failed.',
   false, false, 110),

  ('SUPPLIER_RETRY_SAME_COST_TOLERANCE_USD', 'Silent retry tolerance', 'Refill engine', 'decimal',
   0, 10, 'USD',
   'A retry whose cost differs by less than this is not announced to the user. Above it, they are told the price changed.',
   false, false, 120),

  ('SUPPLIER_RETRY_SKIP_REASONS', 'Never retry these failures', 'Refill engine', 'text',
   NULL, NULL, NULL,
   'Comma-separated patterns matched against the supplier failure message. A permanent failure (invalid number, barred, suspended) must not be retried at another supplier — it will fail there too, and cost money to find out.',
   false, false, 130),

  ('SUPPLIER_SELECTION_MODE', 'Supplier selection mode', 'Refill engine', 'enum',
   NULL, NULL, NULL,
   'cheapest = pick lowest landed cost. margin_aware = also apply supplier_policy risk premiums and the switching threshold, so a cent of saving never churns suppliers.',
   false, false, 140),

  ('SUPPLIER_SWITCH_MIN_SAVING_USD', 'Min saving to switch (absolute)', 'Refill engine', 'decimal',
   0, 100, 'USD',
   'BOTH this and the percentage threshold must be beaten before we move off the incumbent supplier.',
   false, false, 150),

  ('SUPPLIER_SWITCH_MIN_SAVING_PERCENT', 'Min saving to switch (percent)', 'Refill engine', 'decimal',
   0, 100, '%',
   'BOTH this and the absolute threshold must be beaten before we move off the incumbent supplier.',
   false, false, 160)
ON CONFLICT (config_key) DO NOTHING;

-- The enum needs its options or validate_config_value() refuses every value.
UPDATE public.system_config_meta
   SET enum_options = ARRAY['cheapest','margin_aware']
 WHERE config_key = 'SUPPLIER_SELECTION_MODE';

COMMIT;
