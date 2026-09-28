# Premium SIM setup and refill test report

Date: 15 September 2026. Project: simSaveDB (`zwxswagokhgbuzrrbnhr`).
Test user: `8a07a25b-a49b-4ec3-a56c-cfe7f7ea0c0e`.

## Verdict

**Premium setup and its first refill passed. Notification delivery is degraded. The next scheduled refill has a pricing inconsistency.**

Executed the Add SIM backend sequence through Supabase MCP under the test user's authenticated database role: create order → reserve funds → insert draft SIM using app fields → dispatch supplier recharge → finalize setup. The existing worker processed the real queue entry and returned supplier success. This was backend integration testing, not a click-through test of the Flutter screens or a new HTTP login/JWT verification test. Native app controls were unavailable in this session.

## Results

| Check | Result | Evidence |
| --- | --- | --- |
| Account and wallet | PASS | User found; starting wallet balance $1,883.44. |
| Premium quote and reservation | PASS | $5 annual fee + $7.18 initial refill = $12.18. |
| Add SIM and supplier execution | PASS | Test number +966000000000, STC; Ding reported success, transaction 864971269. The number is documented in the repository's supplier test protocol. |
| Premium activation | PASS | Plan and protection tier premium; active; verification verified; expires 15 September 2027. |
| Wallet accounting | PASS | Exactly two completed debits, $7.18 and $5; final balance $1,871.26. Both holds captured. No duplicate refill debit when finalization encountered the already captured refill hold. |
| First refill classification | PASS, accounting only | Hold order_type and debit metadata order_type are setup_refill. Execution remains refill_instant with funding_kind=setup_hold. |
| Automatic refill creation | PASS | notify and refill_mini schedules created, cadence 153 days; next due 15 February 2027. |
| Scheduled refill pricing | ISSUE | Schedule $7.18; generated execution $7.40; authorized limit $7.18. |
| Recharge notification | PASS, backend | One top_up_success notification and matching activity entries created. |
| Push delivery | PARTIAL | OneSignal failed with invalid_aliases / zero recipients. FCM fallback reported delivery to 2 of 3 devices. Handset display was not visually verified. |
| Authenticated reads | PASS, limited check | Own profile and new SIM visible; zero other users' profiles or SIMs visible to this identity. Other users' SIM isolation was not separately seeded. |
| Execute scheduled refill now | BLOCKED | Automatic approval review rejected the additional supplier top-up / wallet charge. The scheduled execution remains pending. |

## Findings and suggested fixes

### 1. Scheduled refill adds a fee to an amount that already includes a fee

The setup supplier base cost was $6.9701 and the customer refill total was $7.18. Finalization copied the $7.18 customer total into the refill schedule but left base_cost_usd, pricing_tier and app_fee_usd unset.

Queue generation then used the schedule amount as base_cost_usd ($7.18). The fee trigger added $0.22, producing $7.40 while preserving max_authorized_usd=$7.18. This inconsistent queued price is directly observed; an actual scheduled overcharge or failure was **not** demonstrated.

Keep supplier base, customer fee, customer total and authorized limit separate when creating the schedule. The schedule also contains the carrier-rule Zendit SKU STC_SA_001_USD although setup selected Ding SKU XCSASA72721. A supplier change is not inherently a defect, but the queued cost must match the chosen product and supplier.

### 2. Push relies on fallback

The fresh setup alert reproduced the OneSignal external-user alias failure. FCM reported delivery to 2/3 devices. Repair OneSignal identity/subscription association and inspect the unsuccessful device token.

### 3. setup_refill naming is only partially propagated

The requested accounting rename is deployed and working for new setup holds and ledger metadata. However, the execution and activity records still say refill_instant, and the wallet description is “Instant Mobile Refill for SIM Line (...)”. The Flutter TopupExecution model does not expose funding_kind.

If setup refills should appear distinctly in history, map funding_kind=setup_hold or the linked hold order_type to a “Setup refill” label. Do not rename worker execution types without updating dispatch and claim logic.

### 4. Freshly verified line still has incomplete health fields

After successful setup: health_score=50, next_topup_due=null, validity_expires_at=null. A valid next refill exists in scheduled_topups. Check whether these line fields should be populated during finalization or whether all screens consistently derive them from the schedule.

## Notification channels

| Channel | Test-account / global state | Outcome |
| --- | --- | --- |
| Push | Enabled / enabled | Fresh test: OneSignal failed; FCM fallback reported 2/3 devices. |
| Email | Disabled by user / enabled | No email attempted; disabled preference preserved. |
| Telegram | Disabled; empty config / enabled | No Telegram delivery attempted; no chat ID configured. |
| WhatsApp | Enabled by user / globally disabled; credentials marked missing | Excluded from dispatch. User setting alone cannot enable delivery. |
| Webhook | No account channel / globally enabled | No endpoint configured; not attempted. |

The profile subscription_tier is standard while the test line is premium. The deployed notification trigger resolves the SIM line tier first for line-specific notifications, so this difference alone does not prove incorrect gating.

## Persistent test records

- SIM: `da7eb107-1a84-4a87-a563-4aacba4ed86f`, nickname **QA Premium 20260915**, phone **+966000000000**.
- Setup order: `edd42ee5-27ab-49ca-ad45-bdcac4dd44a6`.
- Successful setup execution: `eaa197f7-c3a9-4207-84d9-b25fcc401199`.
- Pending scheduled refill: `c3dad031-c9dc-48d0-8d69-f5cae8fe6c97`.
- Notification: `8be45b0c-aa6d-4861-8f2b-f1132f140d5e`.
- Wallet change: **−$12.18**. Test SIM and its schedules remain active.
- No application fixes or database schema changes were made.

## Limits and execution notes

Existing earlier failed setup attempts and an existing refill awaiting approval were not altered or counted as new test outcomes. The extra scheduled refill, standalone instant refill, custom refill and failure/refund flows were not executed.

An initial test insert used status=unverified and was rejected by the table constraint, with no inserted row. The harness was corrected to the app's actual status=active / carrier_status=pending combination. This harness mistake is not counted as an Add SIM app failure; separately, the database default status=unverified is inconsistent with its own check constraint.

Automatic approval review rejected the attempt to reschedule the refill for immediate execution and repeat finalization because it could cause an additional financial transaction or unintended state changes. No workaround was used. Approval is needed before that additional paid test.

Detailed MCP results are in evidence.json.

