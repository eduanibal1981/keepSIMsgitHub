-- ============================================================================
-- G11 — Multi-currency DISPLAY layer
--
-- Feature suggestion #11 in doc/PRODUCTION_PLAN_REVIEW.md § 6. The review asks
-- for "a display-only FX layer (`profiles.display_currency` + a daily rates row
-- in `system_configs`)". Two of those three nouns turned out to be wrong on
-- contact with the database, so read the decisions below before changing this.
--
-- ── Seven decisions worth not re-deriving ──────────────────────────────────
--
-- 1. THE COLUMN ALREADY EXISTED. `profiles.preferred_currency text DEFAULT
--    'USD'` has been in the schema since the beginning, `authenticated` already
--    holds column UPDATE on it (F6 kept it in the allow-list), and the
--    onboarding screen has been writing it for months via a 6-item dropdown.
--    Adding `display_currency` beside it would have created two columns that
--    disagree. There is no new profile column in this migration. What was
--    missing was never the preference — it was any rate to apply to it, and any
--    screen that read it. All 8 live profiles say 'USD' because that is the
--    dropdown's default and nothing downstream ever cared.
--
-- 2. RATES ARE A TABLE, NOT A `system_configs` ROW. `config_value` is an
--    unbounded varchar with no type, so the review's "daily rates row" would
--    have been a JSON blob in a text column: a fat-fingered `50.5` → `505`
--    silently multiplies every displayed price by ten with nothing to stop it.
--    Money-adjacent numbers get `numeric` and a CHECK. `system_configs` still
--    holds the *policy* knobs (FX_DISPLAY_ENABLED / FX_MAX_AGE_HOURS /
--    FX_MAX_MOVE_PERCENT), which is what that table is actually good at.
--
-- 3. NOTHING HERE MAY EVER TOUCH MONEY. Every charge, cap, wallet balance and
--    ledger row stays USD, end to end. This layer converts in one direction
--    only — USD → local, at render time, for the eye. There is deliberately no
--    local→USD helper anywhere in this feature: the moment an input is entered
--    in EGP and divided back into dollars, rounding drift is inside the money
--    path and a $10.00 deposit becomes $9.99. The RPC returns a *rate*, not a
--    converted amount, and the client is required to keep the USD figure
--    visible wherever a user commits to a charge.
--
-- 4. STALENESS IS DECIDED SERVER-SIDE, AND ITS FALLBACK IS USD. This is the bug
--    a single pass misses: if the daily refresh dies, the naive layer keeps
--    happily rendering a three-week-old rate as though it were today's, which
--    is worse than not having the feature — the user reads a number that is
--    simply false. Past `FX_MAX_AGE_HOURS` (default 72) the RPC stops returning
--    the currency at all and answers 'USD' with rate 1 and a `fallback_reason`.
--    The client cannot get this wrong because the client is never asked; a
--    device with a skewed clock would otherwise reach a different verdict than
--    the server.
--
-- 5. A RATE THAT MOVES TOO FAR IS REFUSED, NOT APPLIED. `tr_fx_rate_sanity`
--    rejects an automated update that jumps more than FX_MAX_MOVE_PERCENT
--    (25%) from the stored rate. A public FX endpoint returning garbage — or an
--    inverted quote, the classic — would otherwise repaint every price in the
--    app. Refusing leaves the old rate in place to go stale and fall back to
--    USD by decision 4, which is the correct failure direction. A genuine
--    devaluation larger than the band is a real event (EGP moved ~66% in a day
--    in March 2024) and needs a human: `rate_source = 'manual'` bypasses the
--    band, so an owner can always set a true rate deliberately.
--
-- 6. SEEDED RATES ARE PLACEHOLDERS AND SAY SO. `rate_source = 'seed'` values
--    below are the four already proven in `carrier_roaming_rates` plus
--    reasonable values for the rest. They are not live quotes. If the refresher
--    in G11b never runs, decision 4 turns the whole feature off after 72 hours
--    rather than leaving guesses on screen forever. That degradation is the
--    design, not an oversight.
--
-- 7. THE CURRENCY LIST FOLLOWS THE APP'S OWN LOCALES, NOT THE OLD DROPDOWN.
--    Onboarding offered six currencies (USD/EUR/GBP/SAR/EGP/AED) while the app
--    ships nine locales and the country picker lists India, Philippines,
--    Pakistan and Jordan — so the exact remittance corridors this feature is
--    for had no currency to pick. TRY, LKR, NPR and BDT each have a shipped
--    locale (tr/si/ne/bn) and no currency either. All of them are seeded here.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- 1. The rate table.
--
-- `usd_to_local` is the multiplier: local = usd * usd_to_local. Same direction
-- and same name-sense as G5's `carrier_roaming_rates.fx_rate_to_usd`, whose
-- stored values (EGP 50.5, PKR 278, AED 3.6725, SAR 3.75) are units of local
-- per dollar despite the column name reading the other way. Matching the data
-- rather than the older column name keeps the two tables comparable.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.fx_rates (
  currency_code   text PRIMARY KEY
                    CHECK (currency_code ~ '^[A-Z]{3}$'),
  display_name    text        NOT NULL,
  symbol          text        NOT NULL,
  -- 0 for JPY-style, 3 for the Gulf dinars. Drives client rounding only.
  decimal_digits  smallint    NOT NULL DEFAULT 2
                    CHECK (decimal_digits BETWEEN 0 AND 3),
  -- Bounded on both sides: a zero or negative rate is nonsense, and the widest
  -- real-world quote against the dollar is ~4 orders of magnitude short of the
  -- ceiling. Anything outside this is a broken feed, not a currency.
  usd_to_local    numeric(20,8) NOT NULL
                    CHECK (usd_to_local > 0 AND usd_to_local <= 10000000),
  rate_source     text        NOT NULL DEFAULT 'seed',
  rate_as_of      timestamptz NOT NULL DEFAULT now(),
  is_enabled      boolean     NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.fx_rates IS
  'G11 display-only FX. NEVER read this in a money path — every charge, cap and '
  'ledger row is USD. local = usd * usd_to_local, one direction, render time only.';
COMMENT ON COLUMN public.fx_rates.usd_to_local IS
  'Units of this currency per 1 USD. USD itself is stored as exactly 1.';
COMMENT ON COLUMN public.fx_rates.rate_as_of IS
  'When the quote was taken, NOT when the row was written. Staleness is measured '
  'from this, so a no-op refresh must not touch it.';
COMMENT ON COLUMN public.fx_rates.rate_source IS
  'Provenance. ''seed'' = placeholder shipped with the migration; ''manual'' = set '
  'by a human and exempt from the move-band check; anything else = a feed name.';


-- ---------------------------------------------------------------------------
-- 2. Move-band circuit breaker (decision 5).
--
-- Fires only on UPDATE of an existing rate — the first INSERT of a currency has
-- nothing to compare against. A no-op rewrite of the same value is allowed
-- through untouched so the refresher can be idempotent.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.tr_fx_rate_sanity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_band     numeric;
  v_move_pct numeric;
BEGIN
  NEW.updated_at := now();

  -- A deliberate human correction is exactly the escape hatch the band needs.
  IF NEW.rate_source = 'manual' THEN
    RETURN NEW;
  END IF;

  IF NEW.usd_to_local = OLD.usd_to_local THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(
           (SELECT NULLIF(config_value,'')::numeric
              FROM public.system_configs
             WHERE config_key = 'FX_MAX_MOVE_PERCENT'),
           25)
    INTO v_band;

  v_move_pct := abs(NEW.usd_to_local - OLD.usd_to_local) / OLD.usd_to_local * 100;

  IF v_move_pct > v_band THEN
    -- plpgsql RAISE has no printf conversions: '%' takes the next argument and
    -- '%%' is a literal percent sign. Round in the argument, not the format —
    -- and never write '%%%', which parses as literal-percent-then-argument,
    -- i.e. the opposite of the intended "42%". Spelled 'pct' to sidestep it.
    RAISE EXCEPTION
      'KS460: FX rate for % moved % pct (% -> %), outside the % pct band. '
      'Refusing — the stale rate will fall back to USD display. '
      'Set rate_source = ''manual'' to override deliberately.',
      NEW.currency_code, round(v_move_pct, 2), OLD.usd_to_local,
      NEW.usd_to_local, v_band
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_fx_rate_sanity ON public.fx_rates;
CREATE TRIGGER tr_fx_rate_sanity
  BEFORE UPDATE ON public.fx_rates
  FOR EACH ROW EXECUTE FUNCTION public.tr_fx_rate_sanity();


-- ---------------------------------------------------------------------------
-- 3. Grants and RLS.
--
-- F6's lesson, and G5b's: a new table inherits a default GRANT ALL that RLS
-- does not always stand in front of. Revoke first, then grant the one verb
-- clients need. Writes are service_role / postgres only and have no policy at
-- all, so RLS denies them outright rather than relying on the grant.
-- ---------------------------------------------------------------------------
REVOKE ALL ON public.fx_rates FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.fx_rates TO authenticated;

ALTER TABLE public.fx_rates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone signed in may read enabled FX rates" ON public.fx_rates;
CREATE POLICY "Anyone signed in may read enabled FX rates"
  ON public.fx_rates FOR SELECT
  TO authenticated
  USING (is_enabled AND NOT public.is_user_suspended());


-- ---------------------------------------------------------------------------
-- 4. Policy knobs.
-- ---------------------------------------------------------------------------
INSERT INTO public.system_configs (config_key, config_value)
VALUES
  ('FX_DISPLAY_ENABLED',   'true'),
  -- 72h, not 24h: the refresher runs daily, so a one-day outage must not blank
  -- the feature for everyone. Two consecutive misses is a real problem.
  ('FX_MAX_AGE_HOURS',     '72'),
  ('FX_MAX_MOVE_PERCENT',  '25')
ON CONFLICT (config_key) DO NOTHING;


-- ---------------------------------------------------------------------------
-- 5. Seed (decision 6 — these are placeholders, not live quotes).
--
-- AED / EGP / PKR / SAR are carried over from `carrier_roaming_rates` so the
-- two tables cannot disagree on day one.
-- ---------------------------------------------------------------------------
INSERT INTO public.fx_rates
  (currency_code, display_name, symbol, decimal_digits, usd_to_local, rate_source)
VALUES
  ('USD', 'US Dollar',        '$',   2,        1.00000000, 'base'),
  ('EUR', 'Euro',             '€',   2,        0.92000000, 'seed'),
  ('GBP', 'British Pound',    '£',   2,        0.79000000, 'seed'),
  ('AED', 'UAE Dirham',       'AED', 2,        3.67250000, 'seed'),
  ('SAR', 'Saudi Riyal',      'SR',  2,        3.75000000, 'seed'),
  ('EGP', 'Egyptian Pound',   'E£',  2,       50.50000000, 'seed'),
  ('JOD', 'Jordanian Dinar',  'JD',  3,        0.70900000, 'seed'),
  ('INR', 'Indian Rupee',     '₹',   2,       83.50000000, 'seed'),
  ('PKR', 'Pakistani Rupee',  'Rs',  2,      278.00000000, 'seed'),
  ('PHP', 'Philippine Peso',  '₱',   2,       57.50000000, 'seed'),
  ('BDT', 'Bangladeshi Taka', '৳',   2,      119.00000000, 'seed'),
  ('LKR', 'Sri Lankan Rupee', 'Rs',  2,      300.00000000, 'seed'),
  ('NPR', 'Nepalese Rupee',   'Rs',  2,      133.00000000, 'seed'),
  ('TRY', 'Turkish Lira',     '₺',   2,       34.00000000, 'seed')
ON CONFLICT (currency_code) DO NOTHING;

-- USD is the base and must never drift. A partial unique index would NOT do
-- this — a changed USD rate simply falls out of the index's WHERE clause and
-- raises nothing. It has to be a CHECK.
ALTER TABLE public.fx_rates DROP CONSTRAINT IF EXISTS fx_rates_base_is_one;
ALTER TABLE public.fx_rates ADD CONSTRAINT fx_rates_base_is_one
  CHECK (currency_code <> 'USD' OR usd_to_local = 1);


-- ---------------------------------------------------------------------------
-- 6. The one thing the client calls.
--
-- SECURITY INVOKER on purpose (F4b's lesson — a DEFINER guard reading
-- `current_user` is dead code, and there is nothing here worth elevating for).
-- RLS on `profiles` restricts it to the caller's own row; `fx_rates` and
-- `system_configs` are already readable by `authenticated`.
--
-- Returns *everything* the UI needs in one call, including the currency list
-- for the picker, so the formatter and the picker can never disagree about
-- which currencies are usable. `currency` is what to render in — already
-- collapsed to 'USD' when anything is wrong — and `requested_currency` is what
-- the profile asked for, so the UI can explain itself.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_fx_display_context()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid        uuid := auth.uid();
  v_enabled    boolean;
  v_max_age    numeric;
  v_requested  text;
  v_rate       public.fx_rates%ROWTYPE;
  v_age_hours  numeric;
  v_reason     text := NULL;
  v_available  jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'KS461: get_fx_display_context() requires an authenticated caller.'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  SELECT COALESCE(
           (SELECT lower(NULLIF(config_value,'')) = 'true'
              FROM public.system_configs WHERE config_key = 'FX_DISPLAY_ENABLED'),
           true)
    INTO v_enabled;

  SELECT COALESCE(
           (SELECT NULLIF(config_value,'')::numeric
              FROM public.system_configs WHERE config_key = 'FX_MAX_AGE_HOURS'),
           72)
    INTO v_max_age;

  SELECT upper(COALESCE(NULLIF(trim(preferred_currency), ''), 'USD'))
    INTO v_requested
    FROM public.profiles WHERE id = v_uid;

  v_requested := COALESCE(v_requested, 'USD');

  -- The picker's options. Always includes USD even if a future edit disables
  -- it, because "show me plain dollars" must never become unreachable.
  SELECT COALESCE(jsonb_agg(
           jsonb_build_object(
             'code',           currency_code,
             'name',           display_name,
             'symbol',         symbol,
             'decimal_digits', decimal_digits
           ) ORDER BY (currency_code <> 'USD'), display_name), '[]'::jsonb)
    INTO v_available
    FROM public.fx_rates
   WHERE is_enabled OR currency_code = 'USD';

  IF NOT v_enabled THEN
    v_reason := 'disabled';
  ELSIF v_requested = 'USD' THEN
    v_reason := 'base';
  ELSE
    SELECT * INTO v_rate
      FROM public.fx_rates
     WHERE currency_code = v_requested AND is_enabled;

    IF NOT FOUND THEN
      v_reason := 'unknown_currency';
    ELSE
      v_age_hours := EXTRACT(EPOCH FROM (now() - v_rate.rate_as_of)) / 3600.0;
      IF v_age_hours > v_max_age THEN
        v_reason := 'stale';
      END IF;
    END IF;
  END IF;

  -- Every non-null reason collapses to plain USD. One exit, so a new reason
  -- added later cannot accidentally leak a rate.
  IF v_reason IS NOT NULL THEN
    RETURN jsonb_build_object(
      'enabled',             v_enabled,
      'currency',            'USD',
      'requested_currency',  v_requested,
      'rate',                1,
      'symbol',              '$',
      'decimal_digits',      2,
      'as_of',               NULL,
      'age_hours',           v_age_hours,
      'stale',               v_reason = 'stale',
      'fallback_reason',     v_reason,
      'max_age_hours',       v_max_age,
      'available',           v_available
    );
  END IF;

  RETURN jsonb_build_object(
    'enabled',             true,
    'currency',            v_rate.currency_code,
    'requested_currency',  v_requested,
    'rate',                v_rate.usd_to_local,
    'symbol',              v_rate.symbol,
    'decimal_digits',      v_rate.decimal_digits,
    'as_of',               v_rate.rate_as_of,
    'age_hours',           round(v_age_hours, 2),
    'stale',               false,
    'fallback_reason',     NULL,
    'max_age_hours',       v_max_age,
    'available',           v_available
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_fx_display_context() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_fx_display_context() TO authenticated;

COMMENT ON FUNCTION public.get_fx_display_context() IS
  'G11. Returns the caller''s display-currency context: rate, symbol, digits, '
  'staleness verdict and the picker list. Collapses to USD/rate 1 whenever the '
  'feature is off, the currency is unknown, or the quote is older than '
  'FX_MAX_AGE_HOURS. Display only — never use the rate in a money path.';
