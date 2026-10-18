-- READ ONLY. Aggregate diagnostics, never a balance/lot repair or proof of loss.
-- Run before rollout, after quiescing writers, and retain the timestamp/results.
WITH posted AS (
 SELECT * FROM public.wallet_transactions WHERE status='completed'
), ledger AS (
 SELECT wallet_id,sum(balance_after-balance_before) AS signed_delta FROM posted GROUP BY wallet_id
), lots AS (
 SELECT wallet_id,sum(remaining_amount) AS remaining FROM public.wallet_funding_lots GROUP BY wallet_id
), held AS (
 SELECT wallet_id,sum(amount) AS reserved FROM public.wallet_holds WHERE status='active' GROUP BY wallet_id
), chronology AS (
 SELECT wallet_id,created_at,balance_before,balance_after,
   lag(balance_after) OVER(PARTITION BY wallet_id ORDER BY created_at,id) AS previous_after,
   count(*) OVER(PARTITION BY wallet_id,created_at) AS simultaneous_rows FROM posted
), tied_wallets AS (
 SELECT DISTINCT wallet_id FROM chronology WHERE simultaneous_rows>1
), metrics AS (
 SELECT 'wallets_checked' AS metric,count(*) AS count FROM public.wallets
 UNION ALL SELECT 'wallet_vs_signed_ledger_difference',count(*) FROM public.wallets w LEFT JOIN ledger l ON l.wallet_id=w.id
   WHERE w.balance IS DISTINCT FROM coalesce(l.signed_delta,0)
 UNION ALL SELECT 'wallet_vs_funding_lot_difference',count(*) FROM public.wallets w LEFT JOIN lots l ON l.wallet_id=w.id
   WHERE w.balance IS DISTINCT FROM coalesce(l.remaining,0)
 UNION ALL SELECT 'reserved_exceeds_posted_balance',count(*) FROM public.wallets w JOIN held h ON h.wallet_id=w.id WHERE h.reserved>w.balance
 UNION ALL SELECT 'active_hold_allocation_total_mismatch',count(*) FROM public.wallet_holds h WHERE h.status='active'
   AND h.amount<>(SELECT coalesce(sum(amount),0) FROM public.wallet_hold_allocations WHERE hold_id=h.id)
 UNION ALL SELECT 'active_lot_overallocated',count(*) FROM public.wallet_funding_lots l WHERE remaining_amount<
   (SELECT coalesce(sum(a.amount),0) FROM public.wallet_hold_allocations a JOIN public.wallet_holds h ON h.id=a.hold_id WHERE a.lot_id=l.id AND h.status='active')
 UNION ALL SELECT 'lot_owner_or_currency_mismatch',count(*) FROM public.wallet_funding_lots l JOIN public.wallets w ON w.id=l.wallet_id
   WHERE l.user_id IS DISTINCT FROM w.user_id OR l.currency IS DISTINCT FROM w.currency
 UNION ALL SELECT 'hold_owner_or_currency_mismatch',count(*) FROM public.wallet_holds h JOIN public.wallets w ON w.id=h.wallet_id
   WHERE h.status='active' AND (h.user_id IS DISTINCT FROM w.user_id OR h.currency IS DISTINCT FROM w.currency)
 UNION ALL SELECT 'foreign_hold_allocation',count(*) FROM public.wallet_hold_allocations a JOIN public.wallet_holds h ON h.id=a.hold_id
   JOIN public.wallet_funding_lots l ON l.id=a.lot_id WHERE h.status='active' AND
   (h.wallet_id IS DISTINCT FROM l.wallet_id OR h.user_id IS DISTINCT FROM l.user_id OR h.currency IS DISTINCT FROM l.currency)
 UNION ALL SELECT 'wallets_with_ambiguous_timestamp_order',count(*) FROM tied_wallets
 UNION ALL SELECT 'chain_breaks_without_timestamp_ties',count(*) FROM chronology c WHERE previous_after IS NOT NULL
   AND balance_before IS DISTINCT FROM previous_after AND NOT EXISTS(SELECT 1 FROM tied_wallets t WHERE t.wallet_id=c.wallet_id)
 UNION ALL SELECT 'invalid_completed_amount_or_delta',count(*) FROM posted WHERE amount IS NULL OR amount<=0
   OR amount::text IN ('NaN','Infinity','-Infinity') OR abs(balance_after-balance_before) IS DISTINCT FROM amount
 UNION ALL SELECT 'unknown_completed_type',count(*) FROM posted WHERE type NOT IN
   ('deposit','topup_debit','refund','referral_credit','referral_withdrawal','plan_fee_debit','home_mode_debit','auto_fund',
    'esim_purchase_debit','esim_purchase_refund','wallet_settlement','wallet_forfeit','gift_sent','gift_received','admin_adjustment',
    'offline_voucher_debit','call_debit','call_refund','did_purchase_debit','refund_payout','verification_debit')
 UNION ALL SELECT 'incorrect_completed_direction',count(*) FROM posted WHERE
   (type IN ('deposit','auto_fund','refund','referral_credit','gift_received','esim_purchase_refund','call_refund') AND balance_after<=balance_before)
   OR (type NOT IN ('deposit','auto_fund','refund','referral_credit','gift_received','esim_purchase_refund','call_refund','admin_adjustment') AND balance_after>=balance_before)
 UNION ALL SELECT 'active_legacy_refund_items',count(*) FROM public.wallet_refund_items WHERE status IN ('pending','processing','reconciliation_required')
 UNION ALL SELECT 'duplicate_completed_reference_groups',count(*) FROM
   (SELECT user_id,type,reference_id FROM posted WHERE reference_id IS NOT NULL GROUP BY user_id,type,reference_id HAVING count(*)>1) d
)
SELECT jsonb_build_object('captured_at_utc',now(),'metrics',jsonb_object_agg(metric,count),
 'limits','No provider evidence, opening-balance inference, timestamp tie ordering or customer loss certification; no records changed') AS reconciliation_report FROM metrics;
