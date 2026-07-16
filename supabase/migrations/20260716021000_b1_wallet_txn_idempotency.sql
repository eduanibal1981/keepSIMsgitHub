-- B1 (refill engine audit), part 2 of 2: make per-execution wallet debits and
-- refunds idempotent at the database level. Applied to live 2026-07-16.
--
-- Evidence this is needed: executions fcab87db-871a-4021-9e47-2059b0013ed3 and
-- 40eec7ae-f1b6-43fa-a4ca-a891b5d49b97 each carry 3 'exec_<id>' debit rows and
-- 3 'refund_exec_<id>' refund rows — the reaper requeued them and each retry
-- debited the wallet again.

-- 1) Rename historical duplicate references (keep the oldest row canonical) so
--    the unique indexes can be created. Rows are preserved for audit.
WITH d AS (
  SELECT id,
         row_number() OVER (PARTITION BY type, reference_id ORDER BY created_at, id) AS rn
  FROM public.wallet_transactions
  WHERE reference_id IS NOT NULL AND type IN ('topup_debit', 'refund')
)
UPDATE public.wallet_transactions w
SET reference_id = w.reference_id || '_hist_dup' || (d.rn - 1),
    description = COALESCE(w.description || ' ', '') || '[B1 2026-07-16: duplicate of same reference, renamed to enable idempotency index]'
FROM d
WHERE w.id = d.id AND d.rn > 1;

-- 2) One debit and one refund per reference. Workers write
--    reference_id = 'exec_<execution_id>' / 'refund_exec_<execution_id>', so a
--    reaped-and-retried execution can no longer debit or refund twice.
CREATE UNIQUE INDEX IF NOT EXISTS uq_wallet_transactions_debit_ref
  ON public.wallet_transactions (reference_id)
  WHERE type = 'topup_debit' AND reference_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_wallet_transactions_refund_ref
  ON public.wallet_transactions (reference_id)
  WHERE type = 'refund' AND reference_id IS NOT NULL;
