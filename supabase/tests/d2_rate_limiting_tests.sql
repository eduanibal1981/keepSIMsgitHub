-- D2 Rate Limiting Test Suite
-- Run live inside BEGIN..ROLLBACK so no rows remain.

BEGIN;

DO $$
DECLARE
  v_res RECORD;
BEGIN
  -- Test 1: consume_rate_limit allows up to capacity, then rejects
  SELECT * INTO v_res FROM public.consume_rate_limit('test_d2', 'user_1', 2, 2.0/60.0);
  IF NOT v_res.allowed THEN
    RAISE EXCEPTION 'Assertion failed: Call 1 should be allowed';
  END IF;

  SELECT * INTO v_res FROM public.consume_rate_limit('test_d2', 'user_1', 2, 2.0/60.0);
  IF NOT v_res.allowed THEN
    RAISE EXCEPTION 'Assertion failed: Call 2 should be allowed';
  END IF;

  -- Call 3 should be rejected by consume_rate_limit
  SELECT * INTO v_res FROM public.consume_rate_limit('test_d2', 'user_1', 2, 2.0/60.0);
  IF v_res.allowed THEN
    RAISE EXCEPTION 'Assertion failed: Call 3 should be rejected';
  END IF;
  IF v_res.retry_after_seconds <= 0 THEN
    RAISE EXCEPTION 'Assertion failed: retry_after_seconds should be > 0';
  END IF;

  -- Test 2: auth.uid() IS NULL / empty key bypasses (returns allowed = true, retry = 0)
  SELECT * INTO v_res FROM public.consume_rate_limit('test_d2', NULL, 2, 2.0/60.0);
  IF NOT v_res.allowed THEN
    RAISE EXCEPTION 'Assertion failed: NULL key should bypass rate limit';
  END IF;

  SELECT * INTO v_res FROM public.consume_rate_limit('test_d2', '', 2, 2.0/60.0);
  IF NOT v_res.allowed THEN
    RAISE EXCEPTION 'Assertion failed: Empty key should bypass rate limit';
  END IF;

  -- Test 3: Verify rejection was logged to security_logs
  IF NOT EXISTS (
    SELECT 1 FROM public.security_logs
    WHERE event_type = 'rate_limited'
      AND metadata->>'bucket' = 'test_d2'
      AND metadata->>'key' = 'user_1'
  ) THEN
    RAISE EXCEPTION 'Assertion failed: Rejection was not logged to security_logs';
  END IF;

  RAISE NOTICE 'ALL D2 RATE LIMITING TESTS PASSED!';
END;
$$;

ROLLBACK;
