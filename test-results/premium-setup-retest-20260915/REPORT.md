# Premium setup retest: comparison with the first run

**Run:** 15 September 2026, 17:42–17:48 UTC (21:42–21:48 Muscat, core live checks).
**Project:** simSaveDB / zwxswagokhgbuzrrbnhr.
**Test user:** 8a07a25b-a49b-4ec3-a56c-cfe7f7ea0c0e.
**Fresh number:** +966000000100, nickname **QA Premium Retest 20260915**.

## Verdict

The fresh premium setup succeeded. **The duplicated scheduled-refill fee is fixed for new setups.** Supplier/SKU propagation, post-activation health and due dates, the SIM status default, pending execution timestamps, and the new wallet description also improved.

**OneSignal remains broken for this user.** FCM fallback still reported 2/3 device sends, but now identified UNREGISTERED and cleared the stale token. Telegram and WhatsApp remain unavailable for delivery under current configuration.

These are live backend integration results through Supabase MCP, using the authenticated test-user role for the Add SIM sequence. Flutter screen behavior was not exercised.

## Before / after

| Area | First run | Fresh retest | Assessment |
| --- | --- | --- | --- |
| Premium setup / supplier result | Success | Success; Ding transaction 865030474 | Still passing |
| Annual fee + first refill | $5 + $7.18 = $12.18 | $5 + $7.18 = $12.18 | Still passing; no duplicate debit |
| Next scheduled refill total | $7.40 | $7.18 | **Fixed in fresh setup** |
| Supplier base / fee | $7.18 retail total reused as base; extra $0.22 | Base $6.9701, fee $0.21 | **Fixed** |
| Authorized limit | $7.18 against $7.40 execution | $7.18 against $7.18 execution | **Fixed** |
| Next refill supplier / SKU | Zendit / STC_SA_001_USD despite Ding setup | Ding / XCSASA72721, same as setup | **Fixed** |
| Original affected future refill | Incorrect $7.40 | Now $7.18 with Ding route | **Existing test row repaired**, read-only verification |
| Setup hold / ledger metadata | setup_refill | setup_refill; funding_kind=setup_hold also in debit metadata | Still passing; metadata improved |
| New wallet description | Instant Mobile Refill... | Setup Refill for SIM Line... | **Fixed in deployed worker output** |
| Execution machine type | refill_instant / setup_hold | refill_instant / setup_hold | Correct routing contract retained |
| Activity metadata | refill_instant; no funding_kind | Same | Presentation classification still incomplete at activity-record level |
| Post-activation stored health | 50 | 100, matching fresh server calculation | **Fixed for activated fresh SIM** |
| next_topup_due | null | 15 February 2027, matching refill schedule | **Fixed for fresh SIM** |
| Pending executed_at | Incorrect creation timestamp | null; future execution_time set | **Fixed** |
| SIM status default | unverified, rejected by constraint | active; insert omitting status succeeded | **Fixed** |
| OneSignal | invalid_aliases, zero recipients | Same explicit invalid_aliases error | **Not fixed** |
| FCM fallback detail | Delivered to 2/3, no reason for third | Delivered to 2/3; failed: UNREGISTERED | **Diagnostics fixed; delivery remains partial for this send** |
| Stale FCM token | Not cleared by old path | One token cleared during this run; two distinct tokens remain | **Cleanup worked** |
| Email | User disabled | User enabled; non-critical success email skipped by policy | Configuration changed; email delivery not proven |
| Telegram | User disabled, empty configuration | User enabled; no chat ID; skipped | **Not operational** |
| WhatsApp | User enabled; globally off, credentials marked missing | Same | **Not operational** |
| Flutter labels / availability UI | Not exercised | Source changes present; screens not exercised | **Not verified end-to-end** |

## Fresh execution and accounting evidence

The number was absent from sim_lines and sim_setup_orders before the run. It uses a synthetic Saudi test-number pattern with the same STC carrier/rule and Ding route as the baseline. Ding returned success; physical airtime receipt was not independently verified.

Sequence completed:
1. Quote premium: $12.18.
2. Create setup order.
3. Reserve $5 plan hold and $7.18 setup_refill hold.
4. Insert premium draft SIM with carrier_status=pending and is_carrier_verified=false; omit status to test the corrected default.
5. Dispatch setup execution.
6. Existing worker reported supplier success and captured $7.18.
7. Finalize order; captured $5, activated premium, created notify and refill_mini schedules.

Wallet:
- Start: **$1,871.26**.
- Refill debit: **$7.18**.
- Annual plan debit: **$5.00**.
- End: **$1,859.08**.
- Both holds captured; one plan-payment row; two schedules.
- No extra scheduled or standalone refill was purchased.

New refill schedule and execution agree:
- amount / cap: **$7.18 / $7.18**.
- base_cost_usd: **6.9701**.
- app_fee_usd: **0.21**.
- provider: **ding**.
- offer: **XCSASA72721**.
- cadence: **153 days**.
- next execution: **2027-02-15 17:46:09.919630 UTC**.
- pending executed_at: **null**.
- plan expiry: **2027-09-15 17:46:09.919630 UTC**.

## Remaining findings

### 1. OneSignal identity still fails in the live environment

Notification 574a1890-9515-4218-a9b4-65e8b657eea9 produced HTTP 200 with an explicit invalid_aliases error for this user's external ID. This is not a successful OneSignal send.

The local authentication and device-registration lifecycle code has changed, but this run does not prove those changes are installed on the user's device or that the OneSignal account association has been repaired. Rebuild/relaunch the client as appropriate and inspect the actual subscription-to-external-ID association.

### 2. FCM improved, but subsequent all-device success is not yet verified

The dispatcher now exposes UNREGISTERED and clears that token. Database inspection found three device rows, two non-null distinct FCM tokens, and one row cleared during this run.

That proves the cleanup path ran. It does not prove the next notification will succeed on every remaining device, or that the two accepted messages were visibly shown on their screens.

### 3. Draft health still starts at 100 before verification

The draft insert returned:
- status=active,
- verification_status=unverified,
- health_score=100.

This was before setup dispatch, before a successful refill, and before creating notification/refill schedules. Thus the post-activation health fix works, but the stored score on a new draft is still misleading. Check insert-time defaults/calculation and whether any UI reads this stored value directly.

### 4. Some planned data improvements remain incomplete

- target_local_value, target_local_currency and fee_rule_version remain null on the new mini-refill schedule. This did not prevent setup or coherent initial pricing, but semantic failover/price-approval behavior is not proven.
- Line activity records still only carry refill_instant and do not expose funding_kind. The linked execution does expose setup_hold.
- validity_expires_at remains null. This is appropriate when actual carrier validity is unknown; do not fabricate it from protection expiry.
- Another older existing test line, 546a5c1b-24c0-42c1-b3cb-f894c4997024, still showed health_score=50 and next_topup_due=null at baseline. The previous report's specific line was repaired, but existing-line health repair is not universal.

### 5. Channel configuration is still a delivery limitation

- Email is now enabled, but the success notification is deliberately skipped as non-critical. Critical email delivery was not tested.
- Telegram is now enabled, but the account has no chat_id. The delivery log says bot token or chat ID missing; the missing chat ID is directly confirmed.
- WhatsApp remains globally disabled with credentials marked missing.
- No webhook channel was configured for this account.

The notification row's delivered_via array contains push, email and telegram, but actual delivery rows show email and Telegram were skipped. Treat delivered_via as selected routes, not proof of receipt.

## Source-only findings

Current source now contains:
- fundingKind in the execution model.
- Setup Refill labels in execution history and wallet UI.
- Pending execution date selection changes.
- Notification catalog availability messaging.
- Auth/device token lifecycle changes.

These are code-presence observations, not confirmation of installed Flutter behavior. Setup Refill labels are currently literal English strings at the inspected locations; localization is not complete there.

A focused Flutter health/pricing test run was attempted with --no-pub. It produced no output and did not finish during the observation window, so it was interrupted. No Flutter test pass is claimed.

## Scope and retained state

No application code, database functions, global channel settings or existing test records were modified during this retest. New test records and their normal wallet charges/notifications were created through the application backend flow. The deployed FCM dispatcher automatically cleared the stale token.

No additional scheduled execution was forced to run. This confirms correct queue creation, not future provider execution, price-change approval, failure/refund behavior, or concurrency/idempotency under repeated client requests.

The fresh SIM and its schedules remain active.

## Reference IDs

- SIM: 97172263-4221-4e1d-9fdc-3b04a51f57cc
- Setup order: e605b84d-2994-4eb0-9290-bcaec82970e7
- Successful setup execution: 3190a091-4352-4854-ac4a-6677bb3ea01f
- Supplier transaction: 865030474
- Scheduled mini refill: 7da4f4b5-297b-426c-84e2-d03e8045a4b2
- Mini-refill schedule: d23ea5b5-cefb-4441-abc2-32648d39bb57
- Notification: 574a1890-9515-4218-a9b4-65e8b657eea9

[Previous report](C:/Users/abdal/Work/KeepSIMs/keep_sims/test-results/premium-setup-20260915/REPORT.md)
[Retest evidence](C:/Users/abdal/Work/KeepSIMs/keep_sims/test-results/premium-setup-retest-20260915/evidence.json)

