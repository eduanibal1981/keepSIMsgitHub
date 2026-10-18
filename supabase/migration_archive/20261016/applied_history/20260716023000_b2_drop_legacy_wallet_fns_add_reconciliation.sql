-- B2: legacy wallet mutators are no longer called (workers migrated to
-- debit_wallet_for_topup / credit_wallet_for_refund; no DB function or Edge
-- Function references them). Drop them so no path can move balance without a
-- ledger row. Applied to live 2026-07-16.
DROP FUNCTION public.deduct_wallet_atomic(uuid, numeric);
DROP FUNCTION public.refund_wallet_atomic(uuid, numeric);

-- Reconciliation: wallets.balance must equal the signed sum of its ledger.
-- Admin/audit view only — not exposed to clients.
CREATE OR REPLACE VIEW public.wallet_reconciliation
WITH (security_invoker = true) AS
SELECT
  w.id AS wallet_id,
  w.user_id,
  w.balance,
  COALESCE(SUM(
    CASE
      WHEN t.type IN ('deposit', 'refund', 'referral_credit', 'auto_fund') THEN t.amount
      WHEN t.type IN ('topup_debit', 'welcome_home_debit') THEN -t.amount
    END
  ), 0) AS ledger_sum,
  w.balance - COALESCE(SUM(
    CASE
      WHEN t.type IN ('deposit', 'refund', 'referral_credit', 'auto_fund') THEN t.amount
      WHEN t.type IN ('topup_debit', 'welcome_home_debit') THEN -t.amount
    END
  ), 0) AS drift
FROM public.wallets w
LEFT JOIN public.wallet_transactions t ON t.wallet_id = w.id
GROUP BY w.id, w.user_id, w.balance;

REVOKE ALL ON public.wallet_reconciliation FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.wallet_reconciliation TO service_role;
