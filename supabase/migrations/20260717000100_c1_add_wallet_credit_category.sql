-- C1 follow-up: allow the 'wallet_credit' notification category.
--
-- The wallet-credit trigger from 20260717000000 inserts notifications with
-- category='wallet_credit', which the existing notifications_category_check
-- did not permit — without this, every deposit would abort. Applied live
-- 2026-07-17.
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_category_check;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_category_check
  CHECK (category = ANY (ARRAY[
    'top_up_success','top_up_failed','wallet_low','wallet_depleted','line_critical',
    'line_entering_grace','geo_fence_triggered','welcome_home_ready','referral_reward',
    'system','wallet_credit'
  ]));
