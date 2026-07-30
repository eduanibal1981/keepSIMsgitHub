-- G11 regression suite — multi-currency display layer
-- (doc/PRODUCTION_PLAN_REVIEW.md § 6, feature #11).
--
-- This feature can never move money, so the suite is not about theft. It is
-- about the one way a display layer can genuinely hurt a user: showing them a
-- number that is not true. Every group below is a way that could happen.
--
--   1. Perimeter — a new table and three new functions must not widen F0/F6.
--      Clients read rates and nothing else; nobody but service_role writes one.
--   2. Fallbacks — the four routes to "we cannot price this honestly" must all
--      land on plain USD with rate 1, decided SERVER-side. A client that made
--      this call itself would disagree with the server whenever its clock was
--      wrong.
--   3. The circuit breaker — an implausible rate is refused and the OLD value
--      survives; a placeholder is NOT defended, or the first real quote is
--      rejected forever.
--   4. Arithmetic — USD stays pinned at 1, and the rate table cannot hold a
--      value that would make a price meaningless.
--
-- Probed as a REAL `authenticated` role with a JWT, never as postgres.
--
-- Uses the existing fixtures only — creates no auth.users rows. Every write is
-- undone by the single ROLLBACK at the end.
--
-- ============================================================================
-- HOW TO RUN — as ONE execute_sql call. MCP makes each call its own
-- transaction, so a split file never pairs BEGIN with ROLLBACK and the writes
-- COMMIT. That is how test residue leaked into production three times here.
-- ============================================================================
-- Last run 2026-07-30: 26/26 PASSED.
-- ============================================================================

BEGIN;

CREATE TEMP TABLE g11(t text, outcome text) ON COMMIT DROP;
GRANT INSERT, SELECT ON g11 TO authenticated, anon;

-- A real profile from the fixtures; its currency is restored by the ROLLBACK.
CREATE TEMP TABLE g11_who(uid uuid) ON COMMIT DROP;
INSERT INTO g11_who
SELECT id FROM public.profiles WHERE is_suspended = false ORDER BY created_at LIMIT 1;
-- as_user() is called *after* SET LOCAL ROLE, so the impersonated role has to
-- be able to read the table behind it.
GRANT SELECT ON g11_who TO authenticated, anon;

CREATE OR REPLACE FUNCTION pg_temp.as_user() RETURNS text
LANGUAGE sql AS $$
  SELECT jsonb_build_object('sub', (SELECT uid FROM g11_who), 'role', 'authenticated')::text;
$$;


-- ---------------------------------------------------------------------------
-- Part 1 — the perimeter.
-- ---------------------------------------------------------------------------
DO $$
DECLARE v_n int;
BEGIN
  -- Clients may SELECT rates and do nothing else.
  SELECT count(*) INTO v_n
    FROM information_schema.role_table_grants
   WHERE table_schema = 'public' AND table_name = 'fx_rates'
     AND grantee IN ('anon', 'authenticated')
     AND privilege_type <> 'SELECT';
  INSERT INTO g11 VALUES ('1.1 no client write grant on fx_rates',
    CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL (' || v_n || ' extra grants)' END);

  -- anon may not even read: rates are harmless, but the F6 sweep found 31
  -- tables that were readable only because nobody had looked.
  SELECT count(*) INTO v_n
    FROM information_schema.role_table_grants
   WHERE table_schema = 'public' AND table_name = 'fx_rates' AND grantee = 'anon';
  INSERT INTO g11 VALUES ('1.2 anon has no grant at all on fx_rates',
    CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL' END);

  -- RLS is on, and there is no write policy for anyone.
  SELECT count(*) INTO v_n FROM pg_policy p
    JOIN pg_class c ON c.oid = p.polrelid
   WHERE c.relname = 'fx_rates' AND p.polcmd <> 'r';
  INSERT INTO g11 VALUES ('1.3 fx_rates has no write policy',
    CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL' END);

  -- The writer is service_role-only.
  SELECT count(*) INTO v_n
    FROM information_schema.role_routine_grants
   WHERE routine_schema = 'public' AND routine_name = 'refresh_fx_rates'
     AND grantee IN ('anon', 'authenticated', 'PUBLIC');
  INSERT INTO g11 VALUES ('1.4 refresh_fx_rates unreachable by clients',
    CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL' END);

  -- Nothing in G11 is SECURITY DEFINER (F4b: four dead guards and counting).
  SELECT count(*) INTO v_n FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.prosecdef
     AND p.proname IN ('get_fx_display_context','refresh_fx_rates',
                       'kick_fx_refresh','tr_fx_rate_sanity');
  INSERT INTO g11 VALUES ('1.5 no SECURITY DEFINER in G11',
    CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL (' || v_n || ')' END);
END $$;

-- anon cannot call the context RPC.
DO $$
BEGIN
  SET LOCAL ROLE anon;
  PERFORM public.get_fx_display_context();
  INSERT INTO g11 VALUES ('1.6 anon cannot read a display context', 'FAIL');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO g11 VALUES ('1.6 anon cannot read a display context',
    CASE WHEN SQLSTATE = '42501' THEN 'PASS' ELSE 'FAIL ' || SQLSTATE END);
END $$;
RESET ROLE;

-- A signed-in user cannot rewrite a rate, nor delete the catalogue (G5b).
DO $$
BEGIN
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', pg_temp.as_user(), true);
  UPDATE public.fx_rates SET usd_to_local = 1 WHERE currency_code = 'EGP';
  INSERT INTO g11 VALUES ('1.7 client cannot UPDATE a rate', 'FAIL');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO g11 VALUES ('1.7 client cannot UPDATE a rate',
    CASE WHEN SQLSTATE = '42501' THEN 'PASS' ELSE 'FAIL ' || SQLSTATE END);
END $$;
RESET ROLE;

DO $$
BEGIN
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', pg_temp.as_user(), true);
  DELETE FROM public.fx_rates;
  INSERT INTO g11 VALUES ('1.8 client cannot DELETE the catalogue', 'FAIL');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO g11 VALUES ('1.8 client cannot DELETE the catalogue',
    CASE WHEN SQLSTATE = '42501' THEN 'PASS' ELSE 'FAIL ' || SQLSTATE END);
END $$;
RESET ROLE;


-- ---------------------------------------------------------------------------
-- Part 2 — the four fallbacks. Each must yield USD / rate 1 / a named reason.
-- ---------------------------------------------------------------------------

-- 2.1 a live conversion actually happens
UPDATE public.profiles SET preferred_currency = 'EGP' WHERE id = (SELECT uid FROM g11_who);
UPDATE public.fx_rates SET rate_as_of = now(), rate_source = 'manual' WHERE currency_code = 'EGP';
DO $$
DECLARE j jsonb;
BEGIN
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', pg_temp.as_user(), true);
  j := public.get_fx_display_context();
  INSERT INTO g11 VALUES ('2.1 EGP profile gets a real rate',
    CASE WHEN j->>'currency' = 'EGP'
           AND (j->>'rate')::numeric > 1
           AND (j->>'stale')::boolean = false
           AND j->>'fallback_reason' IS NULL
         THEN 'PASS' ELSE 'FAIL ' || j::text END);
END $$;
RESET ROLE;

-- 2.2 stale -> USD. THE bug this feature exists to avoid.
UPDATE public.fx_rates SET rate_as_of = now() - interval '80 hours',
       rate_source = 'manual' WHERE currency_code = 'EGP';
DO $$
DECLARE j jsonb;
BEGIN
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', pg_temp.as_user(), true);
  j := public.get_fx_display_context();
  INSERT INTO g11 VALUES ('2.2 stale quote collapses to USD',
    CASE WHEN j->>'currency' = 'USD' AND (j->>'rate')::numeric = 1
           AND j->>'fallback_reason' = 'stale'
           AND (j->>'stale')::boolean
           AND j->>'requested_currency' = 'EGP'
         THEN 'PASS' ELSE 'FAIL ' || j::text END);
END $$;
RESET ROLE;

-- 2.3 the boundary itself: just inside FX_MAX_AGE_HOURS is still good.
UPDATE public.fx_rates SET rate_as_of = now() - interval '71 hours',
       rate_source = 'manual' WHERE currency_code = 'EGP';
DO $$
DECLARE j jsonb;
BEGIN
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', pg_temp.as_user(), true);
  j := public.get_fx_display_context();
  INSERT INTO g11 VALUES ('2.3 71h of 72h is still fresh',
    CASE WHEN j->>'currency' = 'EGP' AND j->>'fallback_reason' IS NULL
         THEN 'PASS' ELSE 'FAIL ' || j::text END);
END $$;
RESET ROLE;
UPDATE public.fx_rates SET rate_as_of = now(), rate_source = 'manual' WHERE currency_code = 'EGP';

-- 2.4 unknown currency -> USD
UPDATE public.profiles SET preferred_currency = 'XXX' WHERE id = (SELECT uid FROM g11_who);
DO $$
DECLARE j jsonb;
BEGIN
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', pg_temp.as_user(), true);
  j := public.get_fx_display_context();
  INSERT INTO g11 VALUES ('2.4 unknown currency collapses to USD',
    CASE WHEN j->>'currency' = 'USD' AND (j->>'rate')::numeric = 1
           AND j->>'fallback_reason' = 'unknown_currency'
         THEN 'PASS' ELSE 'FAIL ' || j::text END);
END $$;
RESET ROLE;

-- 2.5 a USD user is 'base', not an error
UPDATE public.profiles SET preferred_currency = 'USD' WHERE id = (SELECT uid FROM g11_who);
DO $$
DECLARE j jsonb;
BEGIN
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', pg_temp.as_user(), true);
  j := public.get_fx_display_context();
  INSERT INTO g11 VALUES ('2.5 USD profile reports reason=base',
    CASE WHEN j->>'currency' = 'USD' AND j->>'fallback_reason' = 'base'
         THEN 'PASS' ELSE 'FAIL ' || j::text END);
END $$;
RESET ROLE;

-- 2.6 the global brake
UPDATE public.profiles SET preferred_currency = 'EGP' WHERE id = (SELECT uid FROM g11_who);
UPDATE public.system_configs SET config_value = 'false' WHERE config_key = 'FX_DISPLAY_ENABLED';
DO $$
DECLARE j jsonb;
BEGIN
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', pg_temp.as_user(), true);
  j := public.get_fx_display_context();
  INSERT INTO g11 VALUES ('2.6 FX_DISPLAY_ENABLED=false stops everyone',
    CASE WHEN j->>'currency' = 'USD' AND j->>'fallback_reason' = 'disabled'
         THEN 'PASS' ELSE 'FAIL ' || j::text END);
END $$;
RESET ROLE;
UPDATE public.system_configs SET config_value = 'true' WHERE config_key = 'FX_DISPLAY_ENABLED';

-- 2.7 the picker list always offers USD, and never a currency we cannot render
DO $$
DECLARE j jsonb;
BEGIN
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', pg_temp.as_user(), true);
  j := public.get_fx_display_context();
  INSERT INTO g11 VALUES ('2.7 picker offers USD first and only real rows',
    CASE WHEN j->'available'->0->>'code' = 'USD'
           AND jsonb_array_length(j->'available') =
               (SELECT count(*) FROM public.fx_rates WHERE is_enabled)
         THEN 'PASS' ELSE 'FAIL ' || (j->'available')::text END);
END $$;
RESET ROLE;


-- ---------------------------------------------------------------------------
-- Part 3 — the circuit breaker.
-- ---------------------------------------------------------------------------
DO $$
DECLARE v_before numeric; v_after numeric;
BEGIN
  UPDATE public.fx_rates SET usd_to_local = 50.5, rate_source = 'manual'
   WHERE currency_code = 'EGP';
  SELECT usd_to_local INTO v_before FROM public.fx_rates WHERE currency_code = 'EGP';

  BEGIN
    UPDATE public.fx_rates SET usd_to_local = 200, rate_source = 'feed'
     WHERE currency_code = 'EGP';
    INSERT INTO g11 VALUES ('3.1 implausible jump refused', 'FAIL - accepted');
  EXCEPTION WHEN OTHERS THEN
    SELECT usd_to_local INTO v_after FROM public.fx_rates WHERE currency_code = 'EGP';
    -- The refusal must also leave the old rate intact, not blank it.
    INSERT INTO g11 VALUES ('3.1 implausible jump refused, old rate survives',
      CASE WHEN SQLERRM LIKE '%KS460%' AND v_after = v_before
           THEN 'PASS' ELSE 'FAIL ' || SQLERRM END);
  END;
END $$;

DO $$
BEGIN
  UPDATE public.fx_rates SET usd_to_local = 55, rate_source = 'feed'
   WHERE currency_code = 'EGP';
  INSERT INTO g11 VALUES ('3.2 a move inside the band is applied',
    CASE WHEN (SELECT usd_to_local FROM public.fx_rates WHERE currency_code='EGP') = 55
         THEN 'PASS' ELSE 'FAIL' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO g11 VALUES ('3.2 a move inside the band is applied', 'FAIL ' || SQLERRM);
END $$;

DO $$
BEGIN
  UPDATE public.fx_rates SET usd_to_local = 300, rate_source = 'manual'
   WHERE currency_code = 'EGP';
  INSERT INTO g11 VALUES ('3.3 manual overrides the band',
    CASE WHEN (SELECT usd_to_local FROM public.fx_rates WHERE currency_code='EGP') = 300
         THEN 'PASS' ELSE 'FAIL' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO g11 VALUES ('3.3 manual overrides the band', 'FAIL ' || SQLERRM);
END $$;

-- THE deadlock this suite exists to prevent. A seeded placeholder must NOT be
-- defended by the band: if it were, the first real quote that differs by more
-- than 25% would be refused, leaving rate_source='seed', so tomorrow's run is
-- refused identically — forever. Proven live: TRY's seed was 34 and the real
-- quote 47.43, a 39.5% move.
DO $$
BEGIN
  -- Getting TRY back to its seeded state takes two statements, and the reason
  -- is itself the point: dropping the live 47.43 to 34 is a 28% move, so a
  -- single UPDATE would be refused by the very band under test. Set the value
  -- under the 'manual' exemption, then relabel it at an unchanged value.
  UPDATE public.fx_rates SET usd_to_local = 34, rate_source = 'manual'
   WHERE currency_code = 'TRY';
  UPDATE public.fx_rates SET rate_source = 'seed' WHERE currency_code = 'TRY';

  UPDATE public.fx_rates SET usd_to_local = 47.425938, rate_source = 'feed'
   WHERE currency_code = 'TRY';
  INSERT INTO g11 VALUES ('3.4 first real quote replaces a seed placeholder',
    CASE WHEN (SELECT usd_to_local FROM public.fx_rates WHERE currency_code='TRY')
              = 47.425938
         THEN 'PASS' ELSE 'FAIL' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO g11 VALUES ('3.4 first real quote replaces a seed placeholder',
    'FAIL ' || SQLERRM);
END $$;


-- ---------------------------------------------------------------------------
-- Part 4 — arithmetic that must be impossible to break.
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  UPDATE public.fx_rates SET usd_to_local = 1.02, rate_source = 'manual'
   WHERE currency_code = 'USD';
  INSERT INTO g11 VALUES ('4.1 USD is pinned at exactly 1', 'FAIL - accepted');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO g11 VALUES ('4.1 USD is pinned at exactly 1',
    CASE WHEN SQLSTATE = '23514' THEN 'PASS' ELSE 'FAIL ' || SQLSTATE END);
END $$;

DO $$
BEGIN
  UPDATE public.fx_rates SET usd_to_local = 0, rate_source = 'manual'
   WHERE currency_code = 'INR';
  INSERT INTO g11 VALUES ('4.2 a zero rate is impossible', 'FAIL - accepted');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO g11 VALUES ('4.2 a zero rate is impossible',
    CASE WHEN SQLSTATE = '23514' THEN 'PASS' ELSE 'FAIL ' || SQLSTATE END);
END $$;

DO $$
BEGIN
  UPDATE public.fx_rates SET usd_to_local = -5, rate_source = 'manual'
   WHERE currency_code = 'INR';
  INSERT INTO g11 VALUES ('4.3 a negative rate is impossible', 'FAIL - accepted');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO g11 VALUES ('4.3 a negative rate is impossible',
    CASE WHEN SQLSTATE = '23514' THEN 'PASS' ELSE 'FAIL ' || SQLSTATE END);
END $$;

DO $$
BEGIN
  INSERT INTO public.fx_rates (currency_code, display_name, symbol, usd_to_local)
  VALUES ('eg', 'lowercase', 'x', 1.5);
  INSERT INTO g11 VALUES ('4.4 currency codes must be 3 upper letters',
    'FAIL - accepted');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO g11 VALUES ('4.4 currency codes must be 3 upper letters',
    CASE WHEN SQLSTATE = '23514' THEN 'PASS' ELSE 'FAIL ' || SQLSTATE END);
END $$;

-- refresh_fx_rates refuses a payload it cannot trust.
DO $$
BEGIN
  PERFORM public.refresh_fx_rates('{"EGP":50}'::jsonb, now() + interval '2 days');
  INSERT INTO g11 VALUES ('4.5 a future as_of is refused', 'FAIL - accepted');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO g11 VALUES ('4.5 a future as_of is refused',
    CASE WHEN SQLERRM LIKE '%KS463%' THEN 'PASS' ELSE 'FAIL ' || SQLERRM END);
END $$;

DO $$
BEGIN
  PERFORM public.refresh_fx_rates('[1,2,3]'::jsonb, now());
  INSERT INTO g11 VALUES ('4.6 a non-object payload is refused', 'FAIL - accepted');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO g11 VALUES ('4.6 a non-object payload is refused',
    CASE WHEN SQLERRM LIKE '%KS462%' THEN 'PASS' ELSE 'FAIL ' || SQLERRM END);
END $$;

-- The feed may update currencies but must never add them (decision 2).
DO $$
DECLARE v_before int; v_after int; j jsonb;
BEGIN
  SELECT count(*) INTO v_before FROM public.fx_rates;
  j := public.refresh_fx_rates(
         '{"EGP":51,"ZWL":322000,"KPW":900}'::jsonb, now(), 'manual');
  SELECT count(*) INTO v_after FROM public.fx_rates;
  INSERT INTO g11 VALUES ('4.7 unknown feed currencies are ignored, not added',
    CASE WHEN v_after = v_before THEN 'PASS'
         ELSE 'FAIL ' || v_before || ' -> ' || v_after END);
END $$;


SELECT t, outcome FROM g11 ORDER BY t;
SELECT count(*) FILTER (WHERE outcome = 'PASS') AS passed,
       count(*) FILTER (WHERE outcome <> 'PASS') AS failed,
       count(*) AS total
  FROM g11;

ROLLBACK;
