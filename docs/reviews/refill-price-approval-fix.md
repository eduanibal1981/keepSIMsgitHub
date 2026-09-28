# Refill price approval fix — 15 September 2026

## Cause

The sandbox edit changed the execution display price to $3.50 and its limit to $1.00. It did not change supplier pricing. The old dialog approved $3.50, the RPC queued the execution, and the worker then repriced it at $7.31 and correctly returned it to `awaiting_approval`. A later attempt found $7.18 through Ding. The old message and stale display obscured these transitions.

## Implemented behavior

- Both mini and custom refill history views use the same current-price dialog. Opening it requests a supplier check without changing execution status, reserving funds, or purchasing airtime.
- The workers resolve that request using their existing supplier routing, currency conversion, and fee calculation. Approval checks require live catalog data; an outage cannot silently reuse a stale catalog.
- The database stores a short-lived quote with the execution snapshot. The customer approves its exact total. A changed execution, different amount, expired quote, paused schedule, or unauthorized user cannot queue it.
- Approval atomically saves the quote’s supplier, product, benefit, cost, fee, and limit and sets the execution to `pending`. Repeated submission of the same approved quote is idempotent. Processing may start immediately.
- Approval applies to this refill only. The dialog explicitly says that it will run now and future scheduled spending limits remain unchanged.
- Dispatch checks live prices again and retains the approved spending ceiling. Another increase requires another approval.
- The fee insertion trigger now preserves an explicit spending ceiling. It previously increased that ceiling automatically when retail fees exceeded it.
- When workers request approval, they now store the selected supplier alongside its product and clear the obsolete processing timestamp.
- Old clients receive an update/reload message rather than being allowed to approve stale display values.

## Deployment and checks

- Applied migration `fresh_refill_price_approval` to project `zwxswagokhgbuzrrbnhr`.
- The migration was created using the CLI; its local version was placed after the executor’s existing `20260915110000` migration so replay does not restore the old approval function or limit increase.
- Updated the authoritative backend in `../backend-sync-wt`, transferred the four changed files directly to the VM, checked syntax, and restarted only the mini/custom workers. Verified matching local/server hashes and both processes online.
- Passed 16 Node tests (5 new approval checks and 11 existing pricing/failover regressions), 2 Flutter dialog tests, and focused Dart analysis with no issues.
- Database transaction tests verified exact-price approval, stale amount rejection, expiry, execution changes, ownership, grants, duplicate submission, unchanged future limits, and preservation of explicit limits during fee calculation. All test execution changes rolled back before workers could observe them.
- A real **quote-only** check of execution `fb441af6-1ed1-4e1f-be9b-965cb557f1b5` returned **20 SAR through Ding for $7.18**, including a $0.21 service fee. The execution stayed `awaiting_approval`, its limit stayed $3.50, and no hold or supplier transaction was created.
- Supabase advisors also ran. The new approval functions are intentionally callable by authenticated customers, with explicit identity and ownership checks; the quote table disallows customer writes. The project still has unrelated existing advisor findings, including [publicly executable privileged functions](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable). This scoped fix is not a clean bill of health for the entire money system.

## Customer retest

Run the updated Flutter app, open the blocked refill, and choose **Review Current Price**. Wait for the current quote, review the total, and approve that amount. It should enter `pending` and may quickly become `processing` or `success`. A genuinely higher supplier price or insufficient wallet funds must still stop fulfillment.

No price was approved on the customer’s behalf during verification. The observed $7.18 is a test-time quote, not a guaranteed future price.
