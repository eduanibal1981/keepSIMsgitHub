-- j4_affiliate_admin_tests.sql — guards on the affiliate control plane.
--
-- Run:  psql "$DB_URL" -f supabase/tests/j4_affiliate_admin_tests.sql
--
-- Everything runs inside one transaction that ROLLBACKs, so it leaves no rows.
-- An allow-list entry in f0_grant_matrix_tests.sql without a tested internal
-- check is exactly what F-4's apply_referral was, which is why these exist.
--
-- Note on the admin identity: is_power_user() reads
-- `auth.jwt() -> 'app_metadata' ->> 'is_power_user'`, NOT profiles.is_power_user.
-- A test that only sets `sub` gets KS460 and looks like a broken guard. Setting
-- the profile column would not help either — and that is the point of F4b's
-- design: writing to profiles cannot grant admin.

BEGIN;

CREATE TEMP TABLE j4_results (name text, status text) ON COMMIT DROP;

DO $t$
DECLARE
  v_admin  uuid;
  v_plain  uuid;
  v_offer  uuid;
  v_row    record;
BEGIN
  SELECT id INTO v_admin FROM public.profiles WHERE is_power_user = true LIMIT 1;
  SELECT id INTO v_plain FROM public.profiles WHERE COALESCE(is_power_user, false) = false LIMIT 1;
  IF v_admin IS NULL OR v_plain IS NULL THEN
    RAISE EXCEPTION 'Fixtures missing: need one power user and one ordinary user';
  END IF;

  -- ── T1: a non-admin may not read the partner list ───────────────────────
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_plain::text, 'role', 'authenticated',
                      'app_metadata', json_build_object('is_power_user', false))::text, true);
  BEGIN
    PERFORM public.admin_list_affiliate_partners();
    INSERT INTO j4_results VALUES ('T1 non-admin refused', 'FAIL: list returned');
  EXCEPTION WHEN SQLSTATE 'KS460' THEN
    INSERT INTO j4_results VALUES ('T1 non-admin refused', 'PASS');
  END;

  -- Become the admin for the rest.
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_admin::text, 'role', 'authenticated',
                      'app_metadata', json_build_object('is_power_user', true))::text, true);

  -- ── T2: an unknown patch key is refused, not silently dropped ───────────
  -- price_checked_at is the specific key that must never be caller-supplied:
  -- the staleness guard is worthless if a caller can backdate or forward-date
  -- its own check. Same stance as I8's carrier_self_service.verified_at.
  BEGIN
    PERFORM public.admin_upsert_affiliate_partner('billion_connect',
      '{"price_checked_at":"2099-01-01"}'::jsonb);
    INSERT INTO j4_results VALUES ('T2 unknown patch key refused', 'FAIL: accepted');
  EXCEPTION WHEN SQLSTATE 'KS467' THEN
    INSERT INTO j4_results VALUES ('T2 unknown patch key refused', 'PASS');
  END;

  -- ── T3: a partner cannot go live without a way to get paid ─────────────
  -- Orange is seeded with a NULL tracking URL on purpose. Activating it would
  -- send users to a partner untracked, which earns nothing.
  BEGIN
    PERFORM public.admin_upsert_affiliate_partner('orange_travel', '{"is_active":true}'::jsonb);
    INSERT INTO j4_results VALUES ('T3 activation needs a tracking URL', 'FAIL: activated');
  EXCEPTION WHEN SQLSTATE 'KS466' THEN
    INSERT INTO j4_results VALUES ('T3 activation needs a tracking URL', 'PASS');
  END;

  -- ── T4: disclosure cannot be switched off while we are paid ────────────
  BEGIN
    PERFORM public.admin_upsert_affiliate_partner('billion_connect',
      '{"disclosure_required":false}'::jsonb);
    INSERT INTO j4_results VALUES ('T4 disclosure locked while commission > 0', 'FAIL: disabled');
  EXCEPTION WHEN SQLSTATE 'KS466' THEN
    INSERT INTO j4_results VALUES ('T4 disclosure locked while commission > 0', 'PASS');
  END;

  -- ── T5: an offer cannot be attached to a partner that does not exist ────
  BEGIN
    PERFORM public.admin_upsert_affiliate_offer(NULL,
      '{"partner_code":"nope","title":"x","price_usd":1}'::jsonb);
    INSERT INTO j4_results VALUES ('T5 unknown partner_code refused', 'FAIL: accepted');
  EXCEPTION WHEN SQLSTATE 'KS461' THEN
    INSERT INTO j4_results VALUES ('T5 unknown partner_code refused', 'PASS');
  END;

  -- ── T6: creating an offer stamps the price check server-side ───────────
  SELECT (public.admin_upsert_affiliate_offer(NULL, jsonb_build_object(
      'partner_code','billion_connect','title','J4 fixture 3GB Egypt',
      'countries', jsonb_build_array('eg'), 'data_amount_mb', 3000,
      'duration_days', 30, 'price_usd', 8.10, 'list_price_usd', 9.00,
      'coupon_code','NEWBC20') ) ->> 'id')::uuid INTO v_offer;

  SELECT * INTO v_row FROM public.affiliate_offers WHERE id = v_offer;
  IF v_row.price_checked_at IS NULL OR v_row.checked_by IS DISTINCT FROM v_admin THEN
    INSERT INTO j4_results VALUES ('T6 price check stamped server-side', 'FAIL');
  ELSE
    INSERT INTO j4_results VALUES ('T6 price check stamped server-side', 'PASS');
  END IF;

  -- ── T7: countries are normalised to upper case ─────────────────────────
  -- The compare RPC matches with `countries @> ARRAY['EG']`, so a lower-case
  -- row would be invisible to every search while looking correct in the admin
  -- list. Silent, and exactly the kind of thing only a probe catches.
  IF v_row.countries = ARRAY['EG'] AND v_row.country_count = 1 THEN
    INSERT INTO j4_results VALUES ('T7 countries upper-cased and counted', 'PASS');
  ELSE
    INSERT INTO j4_results VALUES ('T7 countries upper-cased and counted', 'FAIL: ' || v_row.countries::text);
  END IF;

  -- ── T8: a "discount" may not raise the price ───────────────────────────
  BEGIN
    PERFORM public.admin_upsert_affiliate_offer(v_offer, '{"list_price_usd": 1.00}'::jsonb);
    INSERT INTO j4_results VALUES ('T8 list price below sale price refused', 'FAIL: accepted');
  EXCEPTION WHEN check_violation THEN
    INSERT INTO j4_results VALUES ('T8 list price below sale price refused', 'PASS');
  END;

  -- ── T9: delete is a deactivation, so click history survives ────────────
  -- affiliate_clicks.offer_id is ON DELETE SET NULL; a real DELETE would orphan
  -- the clicks that conversions are reconciled against.
  PERFORM public.admin_delete_affiliate_offer(v_offer, 'j4 test');
  SELECT * INTO v_row FROM public.affiliate_offers WHERE id = v_offer;
  IF v_row.id IS NOT NULL AND v_row.is_active = false THEN
    INSERT INTO j4_results VALUES ('T9 delete deactivates, row survives', 'PASS');
  ELSE
    INSERT INTO j4_results VALUES ('T9 delete deactivates, row survives', 'FAIL');
  END IF;

  -- ── T10: successful mutations are audited ──────────────────────────────
  IF EXISTS (SELECT 1 FROM public.admin_audit_log
              WHERE action = 'affiliate_offer_create' AND actor_id = v_admin)
     AND EXISTS (SELECT 1 FROM public.admin_audit_log
              WHERE action = 'affiliate_offer_deactivate' AND actor_id = v_admin) THEN
    INSERT INTO j4_results VALUES ('T10 successful mutations are audited', 'PASS');
  ELSE
    INSERT INTO j4_results VALUES ('T10 successful mutations are audited', 'FAIL');
  END IF;

  -- ── T11: a REFUSED mutation leaves no audit row ────────────────────────
  -- Every partner upsert attempted above (T2, T3, T4) raised, so there must be
  -- zero affiliate_partner_upsert rows. A refusal that audits as though it
  -- happened turns the log into fiction.
  --
  -- The first version of T10 asserted ">= 3 audit rows" and failed here for
  -- exactly this reason — the test was wrong, the code was right. Worth
  -- keeping as the positive assertion it should have been.
  IF NOT EXISTS (SELECT 1 FROM public.admin_audit_log
                  WHERE action = 'affiliate_partner_upsert' AND actor_id = v_admin) THEN
    INSERT INTO j4_results VALUES ('T11 refused mutations are not audited', 'PASS');
  ELSE
    INSERT INTO j4_results VALUES ('T11 refused mutations are not audited', 'FAIL: refusal logged');
  END IF;
END $t$;

SELECT name, status FROM j4_results ORDER BY name;

DO $chk$
DECLARE v_fail int;
BEGIN
  SELECT count(*) INTO v_fail FROM j4_results WHERE status <> 'PASS';
  IF v_fail > 0 THEN
    RAISE EXCEPTION 'j4: % test(s) FAILED', v_fail;
  END IF;
  RAISE NOTICE 'j4: all 10 tests passed';
END $chk$;

ROLLBACK;
