-- Task 25: aggregate inventory on the old or repaired financial schema.
-- Execute the entire file, on the explicitly selected project, with an operator
-- read role that can see all rows. RLS-filtered zeroes are not release evidence.
-- No financial RPC, provider call, customer identifier or payload is returned.
-- Missing required relations/columns or a timeout aborts the review; do not
-- interpret partial output as success. This file does not certify readiness.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '3s';

SELECT now() AS captured_at, current_database() AS database_name,
  session_user AS session_role, current_user AS effective_role,
  current_setting('transaction_read_only') AS read_only;

-- Presence is reported independently of row counts. Version 0/missing remains
-- legacy evidence, never fabricated proof of a safe pre-submission state.
SELECT name, to_regclass('public.' || name) IS NOT NULL AS present
FROM (VALUES ('wallet_transaction_funding'), ('refill_supplier_submissions'),
  ('paypal_capture_receipts'), ('account_purge_jobs')) AS relations(name)
ORDER BY name;

SELECT status,
  coalesce(to_jsonb(e)->>'supplier_recovery_version', 'missing') AS recovery_version,
  coalesce(to_jsonb(e)->>'schedule_contract_version', 'missing') AS schedule_version,
  coalesce(e.carrier_in_flight, false) AS submission_marker,
  e.reloadly_transaction_id IS NOT NULL AS provider_identity_present,
  e.wallet_hold_id IS NOT NULL AS reservation_present,
  count(*) AS executions,
  count(*) FILTER (WHERE e.updated_at < now() - interval '15 minutes') AS older_than_15_minutes
FROM public.topup_executions e
WHERE e.status IN ('pending', 'processing', 'routing')
   OR coalesce(e.carrier_in_flight, false)
   OR (e.reloadly_transaction_id IS NOT NULL AND e.status IS DISTINCT FROM 'success')
GROUP BY 1,2,3,4,5,6 ORDER BY 1,2,3,4,5,6;

SELECT h.order_type, h.status,
  coalesce(to_jsonb(h)->>'recovery_contract_version', 'missing') AS recovery_version,
  coalesce(h.carrier_in_flight, false) AS submission_marker,
  count(*) AS reservations,
  count(*) FILTER (WHERE h.expires_at < now()) AS expired
FROM public.wallet_holds h WHERE h.status = 'active'
GROUP BY 1,2,3,4 ORDER BY 1,2,3,4;

SELECT status, provider,
  provider_refund_id IS NOT NULL AS payout_identity_present,
  count(*) AS items
FROM public.wallet_refund_items
GROUP BY 1,2,3 ORDER BY 1,2,3;

SELECT status,
  coalesce(to_jsonb(c)->>'budget_contract_version', 'missing') AS budget_version,
  coalesce(to_jsonb(c)->>'billing_state', 'missing') AS billing_state,
  count(*) AS calls
FROM public.call_records c GROUP BY 1,2,3 ORDER BY 1,2,3;

-- Candidate original-debit linkage only. Even exactly one matching debit does
-- not prove original lot allocations, refundability or a successful reversal.
-- Compare the funding trigger's accepted original types and reference mapping.
WITH reversals AS (
  SELECT t.*,
    nullif(t.metadata->>'reversal_of', '') AS original_id,
    CASE WHEN t.reference_id LIKE 'esim_refund_%' THEN 'esim_' || substr(t.reference_id,13)
      WHEN t.reference_id LIKE 'call_refund_%' THEN 'call_' || substr(t.reference_id,13)
      WHEN t.reference_id LIKE 'refund_%' THEN substr(t.reference_id,8) END AS original_reference
  FROM public.wallet_transactions t
  WHERE t.status = 'completed' AND t.type IN ('refund','esim_purchase_refund','call_refund')
), linked AS (
  SELECT r.type, (SELECT count(*) FROM public.wallet_transactions d
    WHERE d.wallet_id=r.wallet_id AND d.user_id=r.user_id
      AND d.status='completed' AND d.balance_after<d.balance_before
      AND d.type IN ('topup_debit','plan_fee_debit','home_mode_debit','esim_purchase_debit',
        'offline_voucher_debit','call_debit','did_purchase_debit','verification_debit')
      AND (r.type<>'esim_purchase_refund' OR d.type='esim_purchase_debit')
      AND (r.type<>'call_refund' OR d.type='call_debit')
      AND CASE WHEN r.original_id IS NOT NULL THEN d.id::text=r.original_id
        ELSE d.reference_id=r.original_reference END) AS candidates
  FROM reversals r
)
SELECT type, count(*) AS reversals,
  count(*) FILTER (WHERE candidates=0) AS missing_original,
  count(*) FILTER (WHERE candidates>1) AS ambiguous_original,
  count(*) FILTER (WHERE candidates=1) AS single_candidate_requires_allocation_review
FROM linked GROUP BY type ORDER BY type;

ROLLBACK;
