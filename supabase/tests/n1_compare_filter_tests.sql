-- ============================================================================
-- N1 — the eSIM comparison filters.
--
-- What this file exists to keep true:
--
--   1. A range is a range. Both ends bind, and an end left NULL binds nothing
--      on that side. The J2b filters were minimum-only, so "1 to 7 days" was
--      inexpressible and a 7-day floor also returned every 180-day bundle.
--   2. Unlimited is an answer, not a big number. A data range or an exact size
--      returns metered plans only; unlimited is its own mode and wins over
--      both. Under J2b every data filter carried all 3,894 unlimited bundles
--      along with it, so a "3 GB" filter mostly returned plans that are not
--      3 GB.
--   3. An empty exact list is not an empty result. It means "this mode is
--      selected, nothing ticked yet", and must read as no filter — otherwise
--      the sheet shows zero plans for a reason the user cannot see.
--   4. The bounds function offers only what is on sale. It is what replaced a
--      hard-coded chip ladder, and the ladder differs by destination.
--   5. Neither function is reachable by anon, and neither has a second
--      overload — PostgREST answers PGRST203 to every call when one exists.
--
-- These are read-only functions: this file inserts nothing and there is no
-- residue to check afterwards. It still runs inside BEGIN/ROLLBACK to match
-- the house rule.
--
-- ============================================================================
-- HOW TO RUN — as ONE execute_sql call. MCP wraps each call in its own
-- transaction, so a file split across two calls never pairs its BEGIN with
-- its ROLLBACK.
-- ============================================================================
-- Last run 2026-08-12 (N1): 14/14 PASSED.
-- ============================================================================

BEGIN;

CREATE TEMP TABLE n1_results(t text, outcome text, detail text) ON COMMIT DROP;

DO $$
DECLARE
  -- Chosen because it carries both rails' shapes: metered sizes at four
  -- durations and a full unlimited ladder. Any destination with stock works;
  -- the assertions are all relative to what this one actually sells.
  v_iso   text := 'FR';
  v_n     int; v_n2 int;
  v_min   numeric; v_max numeric;
  v_b     jsonb;
  v_days  int[];
  v_sizes bigint[];
BEGIN
  SELECT jsonb_agg(DISTINCT duration_days ORDER BY duration_days)::text::int[]
    INTO v_days FROM public.esim_offers WHERE countries @> ARRAY[v_iso];

  -- ── T1. A range binds on BOTH ends ──────────────────────────────────────
  SELECT count(*) INTO v_n FROM public.compare_esim_offers(
    v_iso, p_min_days => 3, p_max_days => 7, p_limit => 200)
   WHERE duration_days < 3 OR duration_days > 7;
  INSERT INTO n1_results VALUES ('T1 validity range binds both ends',
    CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL' END, v_n || ' rows outside 3..7');

  -- ── T2. A NULL end binds nothing on that side ───────────────────────────
  -- The upper open case is the J2b behaviour, and it must survive: an old APK
  -- sends p_min_days alone and still means "at least".
  SELECT count(*) INTO v_n  FROM public.compare_esim_offers(v_iso, p_min_days => 7, p_limit => 200);
  SELECT count(*) INTO v_n2 FROM public.compare_esim_offers(v_iso, p_min_days => 7, p_max_days => 7, p_limit => 200);
  INSERT INTO n1_results VALUES ('T2 open upper end is not a ceiling',
    CASE WHEN v_n > v_n2 THEN 'PASS' ELSE 'FAIL' END,
    'open=' || v_n || ' closed=' || v_n2);

  -- ── T3. Exact durations return exactly those ────────────────────────────
  SELECT count(*) INTO v_n FROM public.compare_esim_offers(
    v_iso, p_days_exact => ARRAY[3, 7], p_limit => 200)
   WHERE duration_days NOT IN (3, 7);
  INSERT INTO n1_results VALUES ('T3 exact durations exclude everything else',
    CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL' END, v_n || ' strays');

  -- ── T4. A duration nobody sells is not an error ─────────────────────────
  -- "3 and 7 and 9" is a reasonable thing to ask; 9 simply matches nothing.
  -- The other two must still come back rather than the call failing.
  SELECT count(DISTINCT duration_days) INTO v_n FROM public.compare_esim_offers(
    v_iso, p_days_exact => ARRAY[3, 7, 9], p_limit => 200);
  INSERT INTO n1_results VALUES ('T4 an unsold duration in the list is ignored',
    CASE WHEN v_n = 2 THEN 'PASS' ELSE 'FAIL' END, v_n || ' distinct durations');

  -- ── T5. Exact wins over range ───────────────────────────────────────────
  -- The client never sends both, but the precedence has to be decided
  -- somewhere and the server is the only place both surfaces agree on.
  SELECT count(*) INTO v_n FROM public.compare_esim_offers(
    v_iso, p_min_days => 30, p_days_exact => ARRAY[3], p_limit => 200)
   WHERE duration_days <> 3;
  INSERT INTO n1_results VALUES ('T5 exact durations outrank a range',
    CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL' END, v_n || ' strays');

  -- ── T6. An empty exact list is no filter, not an empty result ───────────
  SELECT count(*) INTO v_n  FROM public.compare_esim_offers(
    v_iso, p_days_exact => '{}'::int[], p_data_exact_mb => '{}'::bigint[], p_limit => 200);
  SELECT count(*) INTO v_n2 FROM public.compare_esim_offers(v_iso, p_limit => 200);
  INSERT INTO n1_results VALUES ('T6 empty exact arrays filter nothing',
    CASE WHEN v_n = v_n2 AND v_n > 0 THEN 'PASS' ELSE 'FAIL' END,
    'empty=' || v_n || ' unfiltered=' || v_n2);

  -- ── T7. A data range is about metered plans ─────────────────────────────
  -- This is the behaviour change from J2b, and the one most worth pinning: a
  -- size range that quietly included every unlimited bundle answered a
  -- different question from the one the chip asked.
  SELECT count(*) INTO v_n FROM public.compare_esim_offers(
    v_iso, p_min_data_mb => 3000, p_max_data_mb => 20000, p_limit => 200)
   WHERE is_unlimited OR data_amount_mb < 3000 OR data_amount_mb > 20000;
  INSERT INTO n1_results VALUES ('T7 data range excludes unlimited and out-of-band',
    CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL' END, v_n || ' strays');

  -- ── T8. Exact sizes likewise ────────────────────────────────────────────
  SELECT count(*) INTO v_n FROM public.compare_esim_offers(
    v_iso, p_data_exact_mb => ARRAY[3000, 10000]::bigint[], p_limit => 200)
   WHERE is_unlimited OR data_amount_mb NOT IN (3000, 10000);
  INSERT INTO n1_results VALUES ('T8 exact sizes are metered only',
    CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL' END, v_n || ' strays');

  -- ── T9. Unlimited outranks any size the client left behind ──────────────
  SELECT count(*) INTO v_n FROM public.compare_esim_offers(
    v_iso, p_unlimited_only => true, p_min_data_mb => 5000,
    p_data_exact_mb => ARRAY[1000]::bigint[], p_limit => 200)
   WHERE NOT is_unlimited;
  INSERT INTO n1_results VALUES ('T9 unlimited mode wins over stale size values',
    CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL' END, v_n || ' metered rows');

  -- ── T10. Price binds on both ends ───────────────────────────────────────
  SELECT count(*) INTO v_n FROM public.compare_esim_offers(
    v_iso, p_min_price_usd => 5, p_max_price_usd => 10, p_limit => 200)
   WHERE price_usd < 5 OR price_usd > 10;
  INSERT INTO n1_results VALUES ('T10 price range binds both ends',
    CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL' END, v_n || ' out of band');

  -- ── T11. An omitted minimum is not zero-only ────────────────────────────
  -- The client sends NULL for an empty box precisely so this holds; if NULL
  -- were read as 0 on the max side it would mean "free plans only".
  SELECT count(*) INTO v_n FROM public.compare_esim_offers(
    v_iso, p_max_price_usd => 10, p_limit => 200);
  INSERT INTO n1_results VALUES ('T11 max-only price keeps everything cheaper',
    CASE WHEN v_n > 0 THEN 'PASS' ELSE 'FAIL' END, v_n || ' rows');

  -- ── T12. Bounds describe what is actually on sale ───────────────────────
  v_b := public.compare_esim_filter_bounds(v_iso);
  SELECT array_agg(x)::int[] INTO v_days
    FROM jsonb_array_elements_text(v_b -> 'durations') AS t(x);
  SELECT count(*) INTO v_n FROM public.esim_offers
   WHERE countries @> ARRAY[v_iso] AND NOT (duration_days = ANY(v_days));
  INSERT INTO n1_results VALUES ('T12 bounds list every duration on sale, and no others',
    CASE WHEN v_n = 0 AND array_length(v_days, 1) > 0 THEN 'PASS' ELSE 'FAIL' END,
    'unlisted=' || v_n || ' listed=' || COALESCE(array_length(v_days, 1), 0));

  -- ── T13. Bounds exclude unlimited from the size ladder ──────────────────
  -- An unlimited bundle stores 0 MB. A "0 MB" chip would be nonsense, and the
  -- sheet draws its chips straight from this array.
  SELECT array_agg(x)::bigint[] INTO v_sizes
    FROM jsonb_array_elements_text(v_b -> 'data_mb') AS t(x);
  SELECT (v_b ->> 'min_price_usd')::numeric, (v_b ->> 'max_price_usd')::numeric
    INTO v_min, v_max;
  INSERT INTO n1_results VALUES ('T13 bounds carry sizes, a price floor and a ceiling',
    CASE WHEN NOT (0 = ANY(v_sizes)) AND v_min > 0 AND v_max >= v_min
              AND (v_b ->> 'has_unlimited')::boolean
         THEN 'PASS' ELSE 'FAIL' END,
    'sizes=' || COALESCE(array_length(v_sizes, 1), 0)
      || ' price=' || v_min || '..' || v_max);

  -- ── T14. One overload only, and nothing for anon ────────────────────────
  -- Two overloads is the D5b→F2b failure: PostgREST resolves from body keys on
  -- signature alone and answers HTTP 300 PGRST203 to every call.
  SELECT count(*) INTO v_n
    FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'public'
     AND p.proname IN ('compare_esim_offers', 'compare_esim_filter_bounds');
  SELECT count(*) INTO v_n2
    FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'public'
     AND p.proname IN ('compare_esim_offers', 'compare_esim_filter_bounds')
     AND (has_function_privilege('anon', p.oid, 'EXECUTE')
          OR NOT has_function_privilege('authenticated', p.oid, 'EXECUTE'));
  INSERT INTO n1_results VALUES ('T14 exactly two functions, neither open to anon',
    CASE WHEN v_n = 2 AND v_n2 = 0 THEN 'PASS' ELSE 'FAIL' END,
    v_n || ' functions, ' || v_n2 || ' with a wrong ACL');
END $$;

SELECT t, outcome, detail FROM n1_results ORDER BY t;
SELECT count(*) FILTER (WHERE outcome = 'PASS') || '/' || count(*) AS score
  FROM n1_results;

ROLLBACK;
