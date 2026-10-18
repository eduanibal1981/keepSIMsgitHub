-- Migration: 20260724000000_c5_refer_and_earn.sql
-- Description: C5 Refer & Earn schema overhaul (points system, redemptions, award triggers, paypal plan_payments line link, apply_referral rewrite)

-- ── 1. Reshape public.referrals table ─────────────────────────────────────────
-- Existing referrals table has 0 rows (verified). We drop and recreate with new schema.
DROP TABLE IF EXISTS public.referrals CASCADE;

CREATE TABLE public.referrals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  referred_user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  code text NOT NULL,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;

CREATE POLICY referrals_select ON public.referrals
  FOR SELECT USING (auth.uid() IN (referrer_id, referred_user_id));

-- Client writes strictly denied.

-- ── 2. Create public.referral_points table ────────────────────────────────────
CREATE TABLE public.referral_points (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  referred_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  sim_line_id uuid UNIQUE REFERENCES public.sim_lines(id) ON DELETE CASCADE,
  points integer NOT NULL DEFAULT 1 CHECK (points > 0),
  source text NOT NULL,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.referral_points ENABLE ROW LEVEL SECURITY;

CREATE POLICY referral_points_select ON public.referral_points
  FOR SELECT USING (auth.uid() = referrer_id);

-- Client writes strictly denied.

-- ── 3. Create public.referral_redemptions table ───────────────────────────────
CREATE TABLE public.referral_redemptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  points_spent integer NOT NULL CHECK (points_spent > 0),
  wallet_txn_id uuid REFERENCES public.wallet_transactions(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.referral_redemptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY referral_redemptions_select ON public.referral_redemptions
  FOR SELECT USING (auth.uid() = user_id);

-- Client writes strictly denied.

-- ── 4. Alter public.plan_payments ─────────────────────────────────────────────
ALTER TABLE public.plan_payments
  ADD COLUMN IF NOT EXISTS sim_line_id uuid REFERENCES public.sim_lines(id) ON DELETE SET NULL;

-- ── 5. Partial Unique Index on wallet_transactions for referral_credit ─────────
CREATE UNIQUE INDEX IF NOT EXISTS uq_wallet_txns_referral_credit_ref
  ON public.wallet_transactions (reference_id)
  WHERE type = 'referral_credit' AND reference_id LIKE 'refredeem_%';

-- ── 6. System Config Seed ──────────────────────────────────────────────────────
INSERT INTO public.system_configs (config_key, config_value)
VALUES ('REFERRAL_DAILY_POINT_CAP', '10')
ON CONFLICT (config_key) DO UPDATE SET config_value = EXCLUDED.config_value;

-- ── 7. Rewrite public.apply_referral RPC ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.apply_referral(
  p_referred_id uuid,
  p_referral_code text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_referrer_id uuid;
  v_already_referred_by text;
BEGIN
  -- Defense in depth: JWT caller may only apply a code to themselves
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_referred_id THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  p_referral_code := UPPER(TRIM(p_referral_code));

  SELECT id INTO v_referrer_id
  FROM public.profiles
  WHERE UPPER(referral_code) = p_referral_code;

  IF v_referrer_id IS NULL THEN
    RAISE EXCEPTION 'Invalid referral code';
  END IF;

  IF v_referrer_id = p_referred_id THEN
    RAISE EXCEPTION 'You cannot refer yourself';
  END IF;

  SELECT referred_by INTO v_already_referred_by
  FROM public.profiles
  WHERE id = p_referred_id;

  IF v_already_referred_by IS NOT NULL THEN
    RAISE EXCEPTION 'You have already applied a referral code';
  END IF;

  -- Link referrer code on user profile
  UPDATE public.profiles
  SET referred_by = p_referral_code
  WHERE id = p_referred_id;

  -- Record referral connection (points are awarded upon subscription)
  INSERT INTO public.referrals (referrer_id, referred_user_id, code)
  VALUES (v_referrer_id, p_referred_id, p_referral_code);

END;
$$;

GRANT EXECUTE ON FUNCTION public.apply_referral(uuid, text) TO authenticated;

-- ── 8. Award Function & Triggers ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.trg_fn_award_referral_points()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_sim_line_id uuid;
  v_line_owner_id uuid;
  v_referred_by text;
  v_referrer_id uuid;
  v_daily_cap int := 10;
  v_today_points int := 0;
  v_current_balance int := 0;
  v_inserted_id uuid;
BEGIN
  -- Extract sim_line_id based on source table
  IF TG_TABLE_NAME = 'wallet_transactions' THEN
    IF NEW.type <> 'plan_fee_debit' OR NEW.sim_line_id IS NULL THEN
      RETURN NEW;
    END IF;
    v_sim_line_id := NEW.sim_line_id;
  ELSIF TG_TABLE_NAME = 'plan_payments' THEN
    IF NEW.kind <> 'plan' OR NEW.sim_line_id IS NULL THEN
      RETURN NEW;
    END IF;
    v_sim_line_id := NEW.sim_line_id;
  ELSE
    RETURN NEW;
  END IF;

  -- Resolve line owner
  SELECT user_id INTO v_line_owner_id
  FROM public.sim_lines
  WHERE id = v_sim_line_id;

  IF v_line_owner_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Resolve line owner's referrer code
  SELECT referred_by INTO v_referred_by
  FROM public.profiles
  WHERE id = v_line_owner_id;

  IF v_referred_by IS NULL OR length(trim(v_referred_by)) = 0 THEN
    RETURN NEW;
  END IF;

  -- Resolve referrer UUID
  SELECT id INTO v_referrer_id
  FROM public.profiles
  WHERE UPPER(referral_code) = UPPER(TRIM(v_referred_by));

  IF v_referrer_id IS NULL THEN
    RAISE LOG 'Referral code % not found for referred user %', v_referred_by, v_line_owner_id;
    RETURN NEW;
  END IF;

  -- Read daily cap from system_configs
  BEGIN
    SELECT config_value::int INTO v_daily_cap
    FROM public.system_configs
    WHERE config_key = 'REFERRAL_DAILY_POINT_CAP';
  EXCEPTION WHEN OTHERS THEN
    v_daily_cap := 10;
  END;
  IF v_daily_cap IS NULL OR v_daily_cap <= 0 THEN
    v_daily_cap := 10;
  END IF;

  -- Count referrer's awarded points today
  SELECT COALESCE(SUM(points), 0) INTO v_today_points
  FROM public.referral_points
  WHERE referrer_id = v_referrer_id
    AND created_at >= date_trunc('day', now());

  -- Daily cap check
  IF v_today_points >= v_daily_cap THEN
    INSERT INTO public.system_alerts (kind, message, details)
    VALUES (
      'referral_cap_hit',
      'Daily referral point cap hit for referrer ' || v_referrer_id::text,
      jsonb_build_object(
        'referrer_id', v_referrer_id,
        'referred_user_id', v_line_owner_id,
        'sim_line_id', v_sim_line_id,
        'daily_cap', v_daily_cap,
        'today_points', v_today_points
      )
    );
    RETURN NEW;
  END IF;

  -- Insert 1 point (UNIQUE on sim_line_id prevents duplicate awards across renewals)
  INSERT INTO public.referral_points (referrer_id, referred_user_id, sim_line_id, points, source)
  VALUES (v_referrer_id, v_line_owner_id, v_sim_line_id, 1, TG_TABLE_NAME)
  ON CONFLICT (sim_line_id) DO NOTHING
  RETURNING id INTO v_inserted_id;

  -- On a real new award, insert notification for referrer
  IF v_inserted_id IS NOT NULL THEN
    SELECT COALESCE(SUM(p.points), 0) - COALESCE((
      SELECT SUM(r.points_spent) FROM public.referral_redemptions r WHERE r.user_id = v_referrer_id
    ), 0) INTO v_current_balance
    FROM public.referral_points p
    WHERE p.referrer_id = v_referrer_id;

    INSERT INTO public.notifications (user_id, category, title, body)
    VALUES (
      v_referrer_id,
      'referral_reward',
      'Referral Point Earned! 🎁',
      'You earned 1 point for a friend''s SIM line subscription! Your current balance is ' || v_current_balance::text || ' points.'
    );
  END IF;

  RETURN NEW;
END;
$$;

-- Trigger security: revoke EXECUTE from public/authenticated (trigger-only execution)
REVOKE EXECUTE ON FUNCTION public.trg_fn_award_referral_points() FROM PUBLIC, authenticated;

-- Attach triggers
DROP TRIGGER IF EXISTS trg_award_referral_wallet ON public.wallet_transactions;
CREATE TRIGGER trg_award_referral_wallet
  AFTER INSERT ON public.wallet_transactions
  FOR EACH ROW
  WHEN (NEW.type = 'plan_fee_debit' AND NEW.sim_line_id IS NOT NULL)
  EXECUTE FUNCTION public.trg_fn_award_referral_points();

DROP TRIGGER IF EXISTS trg_award_referral_paypal ON public.plan_payments;
CREATE TRIGGER trg_award_referral_paypal
  AFTER INSERT ON public.plan_payments
  FOR EACH ROW
  WHEN (NEW.kind = 'plan' AND NEW.sim_line_id IS NOT NULL)
  EXECUTE FUNCTION public.trg_fn_award_referral_points();

-- ── 9. Point Redemption RPC ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.redeem_referral_points()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_total_points int := 0;
  v_spent_points int := 0;
  v_balance int := 0;
  v_ref text;
  v_txn_id uuid;
  v_redemption_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Lock referral points and redemptions rows
  PERFORM 1 FROM public.referral_points WHERE referrer_id = v_user_id FOR UPDATE;
  PERFORM 1 FROM public.referral_redemptions WHERE user_id = v_user_id FOR UPDATE;

  SELECT COALESCE(SUM(points), 0) INTO v_total_points
  FROM public.referral_points
  WHERE referrer_id = v_user_id;

  SELECT COALESCE(SUM(points_spent), 0) INTO v_spent_points
  FROM public.referral_redemptions
  WHERE user_id = v_user_id;

  v_balance := v_total_points - v_spent_points;

  IF v_balance < 10 THEN
    RAISE EXCEPTION 'Insufficient points balance for redemption (10 points required, current balance: %)', v_balance;
  END IF;

  v_ref := 'refredeem_' || gen_random_uuid()::text;

  -- Credit $2.00 to user's wallet
  PERFORM public.credit_wallet(
    v_user_id,
    2.00,
    'referral_credit',
    'Redeemed 10 referral points for $2.00 wallet credit',
    v_ref
  );

  -- Fetch created wallet transaction id
  SELECT id INTO v_txn_id
  FROM public.wallet_transactions
  WHERE type = 'referral_credit' AND reference_id = v_ref;

  -- Insert redemption log
  INSERT INTO public.referral_redemptions (user_id, points_spent, wallet_txn_id)
  VALUES (v_user_id, 10, v_txn_id)
  RETURNING id INTO v_redemption_id;

  RETURN jsonb_build_object(
    'success', true,
    'redemption_id', v_redemption_id,
    'wallet_txn_id', v_txn_id,
    'points_spent', 10,
    'remaining_points', v_balance - 10
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.redeem_referral_points() TO authenticated;
