-- P0 regression: the scheduled-job health checker is a postgres-only pg_cron
-- routine. Run this whole file in one session against an isolated database or
-- Supabase branch. All fixture writes are rolled back.

BEGIN;

CREATE TEMP TABLE p0_health_results(t text, outcome text) ON COMMIT DROP;

DO $$
DECLARE
  v_fn regprocedure := 'public.check_scheduled_jobs_health()'::regprocedure;
  v_result jsonb;
  v_denied boolean;
  v_passed integer := 0;
  v_expected integer := 13;
BEGIN
  -- T1-T4: the effective EXECUTE boundary is postgres only.
  IF has_function_privilege('anon', v_fn, 'EXECUTE') THEN
    RAISE EXCEPTION 'T1 FAIL: anon can execute check_scheduled_jobs_health';
  END IF;
  INSERT INTO p0_health_results VALUES ('T1 anon has no EXECUTE', 'PASS');
  v_passed := v_passed + 1;

  IF has_function_privilege('authenticated', v_fn, 'EXECUTE') THEN
    RAISE EXCEPTION 'T2 FAIL: authenticated can execute check_scheduled_jobs_health';
  END IF;
  INSERT INTO p0_health_results VALUES ('T2 authenticated has no EXECUTE', 'PASS');
  v_passed := v_passed + 1;

  IF has_function_privilege('service_role', v_fn, 'EXECUTE') THEN
    RAISE EXCEPTION 'T3 FAIL: service_role can execute postgres-only health checker';
  END IF;
  INSERT INTO p0_health_results VALUES ('T3 service_role has no EXECUTE', 'PASS');
  v_passed := v_passed + 1;

  IF NOT has_function_privilege('postgres', v_fn, 'EXECUTE') THEN
    RAISE EXCEPTION 'T4 FAIL: postgres cannot execute health checker; pg_cron would break';
  END IF;
  INSERT INTO p0_health_results VALUES ('T4 postgres keeps EXECUTE', 'PASS');
  v_passed := v_passed + 1;

  -- T5: the explicit EXECUTE ACL contains exactly one grantee: postgres.
  IF (SELECT count(*)
    FROM pg_proc p
    CROSS JOIN LATERAL aclexplode(p.proacl) a
    LEFT JOIN pg_roles grantee ON grantee.oid = a.grantee
    WHERE p.oid = v_fn::oid
      AND a.privilege_type = 'EXECUTE'
      AND grantee.rolname = 'postgres') <> 1
     OR EXISTS (
       SELECT 1
       FROM pg_proc p
       CROSS JOIN LATERAL aclexplode(p.proacl) a
       LEFT JOIN pg_roles grantee ON grantee.oid = a.grantee
       WHERE p.oid = v_fn::oid
         AND a.privilege_type = 'EXECUTE'
         AND (a.grantee = 0 OR grantee.rolname IS DISTINCT FROM 'postgres')
     ) THEN
    RAISE EXCEPTION 'T5 FAIL: explicit EXECUTE ACL is not exactly postgres-only';
  END IF;
  INSERT INTO p0_health_results VALUES ('T5 exact postgres-only EXECUTE ACL', 'PASS');
  v_passed := v_passed + 1;

  -- T6-T8: retain the reviewed definer properties without replacing the body.
  IF (SELECT pg_get_userbyid(proowner) FROM pg_proc WHERE oid = v_fn::oid) <> 'postgres' THEN
    RAISE EXCEPTION 'T6 FAIL: health checker owner is not postgres';
  END IF;
  INSERT INTO p0_health_results VALUES ('T6 owner is postgres', 'PASS');
  v_passed := v_passed + 1;

  IF NOT (SELECT prosecdef FROM pg_proc WHERE oid = v_fn::oid) THEN
    RAISE EXCEPTION 'T7 FAIL: health checker no longer has reviewed SECURITY DEFINER mode';
  END IF;
  INSERT INTO p0_health_results VALUES ('T7 SECURITY DEFINER retained', 'PASS');
  v_passed := v_passed + 1;

  IF (SELECT proconfig FROM pg_proc WHERE oid = v_fn::oid)
       IS DISTINCT FROM ARRAY['search_path=""']::text[] THEN
    RAISE EXCEPTION 'T8 FAIL: health checker search_path is not exactly empty';
  END IF;
  INSERT INTO p0_health_results VALUES ('T8 empty search_path retained', 'PASS');
  v_passed := v_passed + 1;

  -- T9-T10: exercise denial as the actual database roles, not only ACL metadata.
  EXECUTE 'SET LOCAL ROLE anon';
  v_denied := false;
  BEGIN
    PERFORM public.check_scheduled_jobs_health();
  EXCEPTION WHEN insufficient_privilege THEN
    v_denied := true;
  END;
  EXECUTE 'RESET ROLE';
  IF NOT v_denied THEN
    RAISE EXCEPTION 'T9 FAIL: anon execution was not denied';
  END IF;
  INSERT INTO p0_health_results VALUES ('T9 anon call denied with 42501', 'PASS');
  v_passed := v_passed + 1;

  EXECUTE 'SET LOCAL ROLE authenticated';
  v_denied := false;
  BEGIN
    PERFORM public.check_scheduled_jobs_health();
  EXCEPTION WHEN insufficient_privilege THEN
    v_denied := true;
  END;
  EXECUTE 'RESET ROLE';
  IF NOT v_denied THEN
    RAISE EXCEPTION 'T10 FAIL: authenticated execution was not denied';
  END IF;
  INSERT INTO p0_health_results VALUES ('T10 authenticated call denied with 42501', 'PASS');
  v_passed := v_passed + 1;

  -- T11-T12: clients receive no write capability through the function or RLS.
  EXECUTE 'SET LOCAL ROLE anon';
  v_denied := false;
  BEGIN
    INSERT INTO public.system_alerts (kind, message, details)
    VALUES ('p0_health_anon_probe', 'must be denied', '{}'::jsonb);
  EXCEPTION WHEN insufficient_privilege THEN
    v_denied := true;
  END;
  EXECUTE 'RESET ROLE';
  IF NOT v_denied THEN
    RAISE EXCEPTION 'T11 FAIL: anon gained direct system_alerts write access';
  END IF;
  INSERT INTO p0_health_results VALUES ('T11 anon has no direct alert-table write', 'PASS');
  v_passed := v_passed + 1;

  EXECUTE 'SET LOCAL ROLE authenticated';
  v_denied := false;
  BEGIN
    INSERT INTO public.system_alerts (kind, message, details)
    VALUES ('p0_health_auth_probe', 'must be denied', '{}'::jsonb);
  EXCEPTION WHEN insufficient_privilege THEN
    v_denied := true;
  END;
  EXECUTE 'RESET ROLE';
  IF NOT v_denied THEN
    RAISE EXCEPTION 'T12 FAIL: authenticated gained direct system_alerts write access';
  END IF;
  INSERT INTO p0_health_results VALUES ('T12 authenticated has no direct alert-table write', 'PASS');
  v_passed := v_passed + 1;

  -- T13: postgres/pg_cron execution still scans health and inserts an alert.
  INSERT INTO public.scheduled_job_registry (
    job_name, job_id, owner, category, expected_schedule,
    freshness_threshold_minutes, max_consecutive_failures, is_critical,
    description, created_at, updated_at
  ) VALUES (
    'p0-health-auth-test', -2147483648, 'test', 'test', '* * * * *',
    1, 3, false, 'rollback-only stale health fixture',
    pg_catalog.now() - interval '10 minutes', pg_catalog.now()
  );

  v_result := public.check_scheduled_jobs_health();

  IF (v_result->>'total_registered')::integer < 1
     OR (v_result->>'stale')::integer < 1
     OR NOT EXISTS (
       SELECT 1
       FROM public.system_alerts
       WHERE kind = 'scheduled_job_stale'
         AND details->>'job_name' = 'p0-health-auth-test'
     ) THEN
    RAISE EXCEPTION 'T13 FAIL: postgres health/alert workflow did not complete: %', v_result;
  END IF;
  INSERT INTO p0_health_results VALUES ('T13 postgres health scan inserts expected alert', 'PASS');
  v_passed := v_passed + 1;

  IF v_passed <> v_expected THEN
    RAISE EXCEPTION 'P0 health FAIL: only % of % assertions passed', v_passed, v_expected;
  END IF;
  INSERT INTO p0_health_results VALUES ('TOTAL', format('%s / %s PASSED', v_passed, v_expected));
END;
$$;

SELECT * FROM p0_health_results;

ROLLBACK;
