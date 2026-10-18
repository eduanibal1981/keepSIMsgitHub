-- REQUEST B final step: stop clients writing wallet balances directly.
-- PREREQUISITE (do not apply before): a deposit has been verified end-to-end
-- through the wallet_transact Edge Function, because this breaks every
-- remaining direct client write to wallets / wallet_transactions.
--
-- After this migration:
--   * balance changes only via SECURITY DEFINER RPCs called by service_role
--     (credit_wallet, debit_wallet_for_topup, credit_wallet_for_refund)
--     through the wallet_transact Edge Function;
--   * users keep SELECT on their own wallet and ledger;
--   * users keep UPDATE strictly on the three auto_fund_* columns
--     (column-level grant), which payments_repository edits directly.

-- Drop the row-scoped-but-not-column-scoped write policies.
DROP POLICY IF EXISTS "Users can update own wallet" ON public.wallets;
DROP POLICY IF EXISTS "Users can insert own wallet" ON public.wallets;
DROP POLICY IF EXISTS "Users can insert own transactions" ON public.wallet_transactions;

-- Remove table-level write grants from client roles.
REVOKE INSERT, UPDATE, DELETE ON public.wallets FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.wallet_transactions FROM anon, authenticated;

-- Auto-fund settings stay client-editable: column-level grant + row-scoped policy.
GRANT UPDATE (auto_fund_enabled, auto_fund_threshold, auto_fund_amount)
  ON public.wallets TO authenticated;

CREATE POLICY "Users can update own wallet auto-fund settings" ON public.wallets
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id AND NOT is_user_suspended())
  WITH CHECK (auth.uid() = user_id AND NOT is_user_suspended());
