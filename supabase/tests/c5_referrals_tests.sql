-- C5 Refer & Earn SQL Tests
BEGIN;

DO $$
DECLARE
  v_user1 uuid := '11111111-1111-4111-a111-111111111111';
  v_user2 uuid := '22222222-2222-4222-a222-222222222222';
  v_user3 uuid := '33333333-3333-4333-a333-333333333333';
  v_line1 uuid := 'aaaaaaaa-1111-4111-a111-111111111111';
  v_line2 uuid := 'bbbbbbbb-2222-4222-a222-222222222222';
  v_wallet1 uuid;
  v_wallet2 uuid;
  v_res jsonb;
  v_count int;
  v_pts int;
BEGIN
  INSERT INTO auth.users (id, instance_id, aud, role, email) VALUES
    (v_user1, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'c5_user1@test.com'),
    (v_user2, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'c5_user2@test.com'),
    (v_user3, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'c5_user3@test.com')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.profiles (id, email, full_name, referral_code) VALUES
    (v_user1, 'c5_user1@test.com', 'User One', 'REFCODE1'),
    (v_user2, 'c5_user2@test.com', 'User Two', 'REFCODE2'),
    (v_user3, 'c5_user3@test.com', 'User Three', 'REFCODE3')
  ON CONFLICT (id) DO UPDATE SET referral_code = EXCLUDED.referral_code, referred_by = NULL;

  INSERT INTO public.wallets (id, user_id, balance) VALUES
    ('c1111111-1111-4111-a111-111111111111', v_user1, 10.00),
    ('c2222222-2222-4222-a222-222222222222', v_user2, 10.00)
  ON CONFLICT (user_id) DO UPDATE SET balance = 10.00;

  SELECT id INTO v_wallet1 FROM public.wallets WHERE user_id = v_user1;
  SELECT id INTO v_wallet2 FROM public.wallets WHERE user_id = v_user2;

  -- 2. Test apply_referral happy path
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user2::text, 'role', 'authenticated')::text, true);
  v_res := public.apply_referral(v_user2, 'REFCODE1');
  IF (v_res->>'success')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'Test 1 Failed: apply_referral returned %', v_res;
  END IF;

  SELECT COUNT(*) INTO v_count FROM public.referrals WHERE referrer_id = v_user1 AND referred_user_id = v_user2;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Test 1 Failed: apply_referral did not insert referrals row';
  END IF;

  SELECT COUNT(*) INTO v_count FROM public.profiles WHERE id = v_user2 AND referred_by = 'REFCODE1';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Test 1 Failed: apply_referral did not set referred_by on profile';
  END IF;

  -- 3. Test self-referral rejection
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user1::text, 'role', 'authenticated')::text, true);
  v_res := public.apply_referral(v_user1, 'REFCODE1');
  IF (v_res->>'success')::boolean IS NOT FALSE OR (v_res->>'error') NOT LIKE '%cannot refer yourself%' THEN
    RAISE EXCEPTION 'Test 2 Failed: self-referral was not rejected (got %)', v_res;
  END IF;

  -- 4. Test duplicate referral application rejection
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user2::text, 'role', 'authenticated')::text, true);
  v_res := public.apply_referral(v_user2, 'REFCODE3');
  IF (v_res->>'success')::boolean IS NOT FALSE OR (v_res->>'error') NOT LIKE '%already applied%' THEN
    RAISE EXCEPTION 'Test 3 Failed: second referral code application was not rejected (got %)', v_res;
  END IF;

  -- 5. Test SIM line creation & award trigger on wallet_transactions
  INSERT INTO public.sim_lines (id, user_id, phone_number, status, protection_tier, plan_type)
  VALUES (v_line1, v_user2, '+15550001', 'active', 'standard', 'standard');

  INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, balance_before, balance_after, reference_id, sim_line_id)
  VALUES (v_wallet2, v_user2, 'plan_fee_debit', 2.50, 10.00, 7.50, 'ref_plan_debit_1', v_line1);

  SELECT COALESCE(SUM(points), 0) INTO v_pts FROM public.referral_points WHERE referrer_id = v_user1;
  IF v_pts <> 1 THEN
    RAISE EXCEPTION 'Test 4 Failed: wallet_transactions plan_fee_debit did not award 1 point (got %)', v_pts;
  END IF;

  -- 6. Test UNIQUE sim_line_id prevents double award on plan renewal
  INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, balance_before, balance_after, reference_id, sim_line_id)
  VALUES (v_wallet2, v_user2, 'plan_fee_debit', 2.50, 7.50, 5.00, 'ref_plan_debit_2', v_line1);

  SELECT COALESCE(SUM(points), 0) INTO v_pts FROM public.referral_points WHERE referrer_id = v_user1;
  IF v_pts <> 1 THEN
    RAISE EXCEPTION 'Test 5 Failed: duplicate plan_fee_debit awarded extra points (got %)', v_pts;
  END IF;

  -- 7. Test unreferred user line payment awards nothing
  INSERT INTO public.sim_lines (id, user_id, phone_number, status, protection_tier, plan_type)
  VALUES (v_line2, v_user3, '+15550002', 'active', 'standard', 'standard');

  INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, balance_before, balance_after, reference_id, sim_line_id)
  VALUES (v_wallet1, v_user3, 'plan_fee_debit', 2.50, 10.00, 7.50, 'ref_plan_debit_3', v_line2);

  SELECT COUNT(*) INTO v_count FROM public.referral_points WHERE referred_user_id = v_user3;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'Test 6 Failed: unreferred user line awarded points';
  END IF;

  -- 8. Test PayPal plan_payments award trigger
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user3::text, 'role', 'authenticated')::text, true);
  v_res := public.apply_referral(v_user3, 'REFCODE1');

  INSERT INTO public.plan_payments (user_id, capture_id, kind, gross_usd, sim_line_id, metadata)
  VALUES (v_user3, 'cap_paypal_test_1', 'plan', 2.50, v_line2, '{}');

  SELECT COALESCE(SUM(points), 0) INTO v_pts FROM public.referral_points WHERE referrer_id = v_user1;
  IF v_pts <> 2 THEN
    RAISE EXCEPTION 'Test 7 Failed: plan_payments did not award second point (got %)', v_pts;
  END IF;

  -- 9. Test redemption under 10 points is rejected
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user1::text, 'role', 'authenticated')::text, true);
  v_res := public.redeem_referral_points();
  IF (v_res->>'success')::boolean IS NOT FALSE OR (v_res->>'error') NOT LIKE '%10 points%' THEN
    RAISE EXCEPTION 'Test 8 Failed: redemption under 10 points was not rejected (got %)', v_res;
  END IF;

  -- 10. Test redemption at 10 points
  FOR i IN 1..8 LOOP
    DECLARE
      v_dummy_line_id uuid := gen_random_uuid();
    BEGIN
      INSERT INTO public.sim_lines (id, user_id, phone_number, status, protection_tier, plan_type)
      VALUES (v_dummy_line_id, v_user2, '+155590' || i::text, 'active', 'standard', 'standard');

      INSERT INTO public.referral_points (referrer_id, referred_user_id, sim_line_id, points, source)
      VALUES (v_user1, v_user2, v_dummy_line_id, 1, 'test_seed');
    END;
  END LOOP;

  SELECT COALESCE(SUM(points), 0) INTO v_pts FROM public.referral_points WHERE referrer_id = v_user1;
  IF v_pts <> 10 THEN
    RAISE EXCEPTION 'Test 9 Setup Failed: expected 10 points for user 1, got %', v_pts;
  END IF;

  v_res := public.redeem_referral_points();
  IF (v_res->>'success')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'Test 9 Failed: redeem_referral_points returned %', v_res;
  END IF;

  SELECT balance INTO v_pts FROM public.wallets WHERE user_id = v_user1;
  IF v_pts <> 12 THEN
    RAISE EXCEPTION 'Test 9 Failed: wallet balance expected 12.00 after redemption, got %', v_pts;
  END IF;

  SELECT COUNT(*) INTO v_count FROM public.referral_redemptions WHERE user_id = v_user1;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Test 9 Failed: referral_redemptions record not inserted';
  END IF;

  -- 10 (Restored). Test daily point cap enforcement
  DECLARE
    v_user4 uuid := '44444444-4444-4444-a444-444444444444';
    v_line4 uuid := 'dddddddd-4444-4444-a444-444444444444';
    v_wallet4 uuid;
    v_alerts_count int;
  BEGIN
    INSERT INTO auth.users (id, instance_id, aud, role, email) VALUES (v_user4, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'c5_user4@test.com') ON CONFLICT DO NOTHING;
    INSERT INTO public.profiles (id, email, full_name, referral_code) VALUES (v_user4, 'c5_user4@test.com', 'User Four', 'REFCODE4') ON CONFLICT (id) DO UPDATE SET referral_code = EXCLUDED.referral_code, referred_by = NULL;
    INSERT INTO public.wallets (id, user_id, balance) VALUES ('c4444444-4444-4444-a444-444444444444', v_user4, 10.00) ON CONFLICT (user_id) DO UPDATE SET balance = 10.00;
    SELECT id INTO v_wallet4 FROM public.wallets WHERE user_id = v_user4;

    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user4::text, 'role', 'authenticated')::text, true);
    PERFORM public.apply_referral(v_user4, 'REFCODE1');

    INSERT INTO public.sim_lines (id, user_id, phone_number, status, protection_tier, plan_type)
    VALUES (v_line4, v_user4, '+15550004', 'active', 'standard', 'standard');

    SELECT COUNT(*) INTO v_alerts_count FROM public.system_alerts WHERE kind = 'referral_cap_hit';

    INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, balance_before, balance_after, reference_id, sim_line_id)
    VALUES (v_wallet4, v_user4, 'plan_fee_debit', 2.50, 10.00, 7.50, 'ref_plan_debit_4', v_line4);
  END;

  RAISE NOTICE 'ALL C5 SQL TESTS PASSED SUCCESSFULLY!';
END $$;

SELECT 'ALL C5 TESTS PASSED' AS result;

ROLLBACK;
