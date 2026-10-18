# Task 1 live verification after Supabase MCP connection

Date: 2026-10-16, Asia/Muscat. Supabase catalog collected at approximately 16:30; refreshed VM inventory at 16:32. This updates the deployment evidence in [the original Task 1 register](audit-baseline-20261016.md). Scope remains verification only.

The connections close the earlier management-access gap. They confirm that the October 16 financial package is **not deployed**, that its compatibility blockers remain, and that several older unsafe implementations are still deployed. They also correct earlier assumptions about deployed calling, refund accounting and missing functions. No migration, provider request, payment, payout, customer-record change, credential change, deployment, cron invocation or VM restart was performed.

## What is now verified

| Area | Fresh result | Evidence |
| --- | --- | --- |
| Target and SQL access | Intended project `zwxswagokhgbuzrrbnhr`; PostgreSQL 17.6; `supabase_read_only_user`; `transaction_read_only=on`. | [Live Supabase evidence](audit-baseline-20261016/live-supabase-verification.json) |
| Database definitions | All **366 public function bodies** have the same SHA-256 values as the earlier captured catalog. This proves the older definitions remain deployed; it does not certify their behavior. Current catalog also contains 114 public tables, seven views and 543 constraints. | Same evidence, `catalog` and `comparison_with_captured_catalog` |
| Financial migrations | **238 applied history rows**; none of the eight October 16 financial migrations is recorded. `wallet_transaction_funding`, its booking trigger, and the new submission/refund/recovery functions are absent from the live catalog. All eight local source hashes remain identical to the initial baseline. | Same evidence, `migrations`, `catalog.repair_objects` and function inventory |
| Effective privileges | Unsafe text finalizer, reaper and scheduled-health RPC still permit anon execution; underlying prune RPC still permits ordinary authenticated execution. Effective TRUNCATE remains on 55 tables for anon and 56 for authenticated, including wallets, wallet transactions, funding lots, holds and setup orders. No destructive privilege test was run. | Same evidence, function and table privilege matrices |
| Default privileges | Broad public-schema function/table/sequence defaults remain for `postgres` and `supabase_admin`; containment is unapplied. | Same evidence, `catalog.default_acl` |
| Edge inventory | **38 deployed functions**, all ACTIVE; exact versions, deployed `verify_jwt`, bundle hashes and retrieved source-file hashes recorded. Seventeen have JWT verification enabled, 21 disabled. Disabling gateway JWT is not itself a defect for a properly authenticated webhook. | [Deployed Edge comparison](audit-baseline-20261016/live-edge-source-comparison.json) |
| VM | Eight PM2 processes online. Instant worker still exactly matches its pre-repair Git HEAD, not the dirty local repair. eSIM catalog still differs; other previously compared worker/provider files match local source. | [Fresh VM inventory](audit-baseline-20261016/live-worker-vm-inventory.json) |
| Financial aggregates | Zero funding-total mismatches, overheld wallets, overallocated lots or duplicate provider-refund-ID groups; **one expired active plan-fee hold** remains. These aggregates do not establish historical ledger correctness or safe release of that hold. | Live Supabase evidence, `financial_preflight` |
| Cron | 22 active jobs, all run as `postgres`; registry has 18 entries. Latest recorded run succeeded for 21 jobs and failed for forecasts. A successful async-dispatch cron does not prove downstream delivery. Recovery cron is absent. | Same evidence, `cron` |

## Deployment findings that change the original assessment

1. **Refund incompatibility is already in deployed source.** `process-wallet-refund` v2, with `verify_jwt=true`, independently updates a funding lot and wallet, then inserts `type: "refund_payout"` at deployed `index.ts:202`. The live wallet CHECK does not permit that type. The handler does not inspect the returned insert error before increasing its processed count, and partially completed requests do not resolve their full hold. This is deployed source/constraint evidence; no refund was attempted and no historical loss is asserted. The local atomic replacement is also blocked by the same unsupported type in its SQL settlement. Tasks 6–8 must cover both the current deployed processor and the pending replacement.
2. **Deployed calling predates even the local five-minute hold.** `make-call` v12 contains neither `reserve_wallet_funds` nor `wallet_hold_id`, and dials after a posted-balance check. Its `balance` variable is declared, so the local undeclared retry variable is not a deployed-v12 defect. Its packaged call-media logic still derives the bridge limit from posted wallet balance. The live finalizer/settlement functions match the captured definitions. Task 13 must reconcile the entire deployed caller/media/SQL contract; deploying the incomplete local hold patch alone would not certify it.
3. **The eSIM catalog mismatch is substantive.** The deployed VM worker syncs eSIM Go. The authoritative local worker additionally syncs Zendit and eSIM Access, uses shared supplier adapters, and updates country-count/supplier-country metadata. This explains the hash mismatch without assuming which version should be released. A separate deployed `sync-esim-catalogue` Edge function also exists; no conclusion is drawn that Zendit/eSIM Access data is globally absent. Tasks 22–23 must establish the intended synchronization owners and configuration.
4. **The direct supplier bypass is retired in deployment.** `execute_zendit_recharge` v7 returns HTTP 410 and does not call Zendit. Its source differs from the local 410 implementation, but the retirement behavior agrees. This was verified by reading deployed source, not by invoking the endpoint.
5. **The live-only email function exists.** `send-admin-email` v2 is deployed with `verify_jwt=false`; its source requires `x-sync-secret`, checked through `get_internal_secret`. The missing-live-function claim is stale. Local source recovery/reproducibility remains open, and no email was sent.

## Authentication, money and source parity

| Deployed component | Version / `verify_jwt` | Current evidence and task |
| --- | --- | --- |
| `capture-paypal-order` | 5 / true | Still uses `captureObj?.id || orderId` at deployed line 221. Task 5 remains open. |
| `paypal-webhook` | 11 / false | Capture-completed fulfillment uses capture identity; approved event initiates capture. Canonical identity/atomic fulfillment still require Task 5. |
| `process-wallet-refund` | 2 / true | Old sequential mutation processor, unsupported payout type and partial-hold handling remain. Tasks 6–8. |
| `make-call` | 12 / true | No wallet reservation in deployed caller; source differs from local. Tasks 7 and 13. |
| `manage-dids` | 3 / true | Provider ordering precedes debit; debit failure is logged and activation continues; supplier fields are returned. Tasks 17 and 19. |
| `process-voicemail` | 2 / false | Entrypoint exactly matches local header-presence-only handler, including body-supplied owner. Task 4. |
| `admin-telnyx-billing` | 4 / true | Entrypoint exactly matches local unsigned-claim/profile authorization logic. Gateway JWT verification is enabled; a forged-token bypass was not tested or established. Task 4. |
| `liveness-verification` | 8 / true | `cancel_call`/`twilio_cancel_call` accept an unbound provider call identity. Credential fallbacks remain in deployed source; values withheld. Tasks 2, 4 and 12. |
| `liveness-verification-webhook` | 6 / false | No provider-signature verification found; invokes the captured settlement function whose paid ledger type is invalid. Tasks 2, 4, 6 and 12. |
| `telnyx-cdr` | 8 / false | Entrypoint matches local; signature checking remains conditional on configured key. Tasks 2 and 4. |
| `twilio-voice-webhook` | 3 / false | Deployed source skips signature validation if its token is missing. Task 4. |
| `sms-webhook` | 5 / false | Entrypoint exactly matches the fail-closed local handler. Preserve and regression-test in Task 4. |
| `waba-webhook` | 7 / false | Entrypoint exactly matches the fail-closed local handler. Auxiliary deployed files are hashed; not every auxiliary file was compared locally. Task 4. |
| `get-turn-credentials` | 6 / false | Entrypoint matches local, including predictable secret fallback; actual value omitted. Task 2. |
| `validate-sim-liveness` | 12 / true | Credential-like fallback literals remain in deployed source, including Zendit/Telnyx paths. Validity was not tested. Task 2. |
| `purge-accounts` | 10 / false | Entrypoint matches local incompatible `admin_log` argument path. Task 16. |
| `health` | 3 / false | Entrypoint matches local limited eSIM-fulfillment health check. Online PM2 is not a fleet heartbeat. Task 23. |
| `execute_zendit_recharge` | 7 / true | Retired with HTTP 410. Task 25 retains final operational smoke checks. |
| `send-admin-email` | 2 / false | Deployed-only source; explicit internal-secret check present. Tasks 16 and 22. |

Across all 38 retrieved entrypoints, **19 match local source byte-for-byte**, one (`initiate-voip-call`) differs only in line endings, **16 differ beyond line endings**, and two have no local counterpart (`send-admin-email`, `test-func-check`). Differences may include bundling/import rewrites; a mismatch alone is not a defect. `recovery-service` is the one local-only slug and remains deferred Firsty scope. The current local-only/deployed-only comparison replaces the older missing-function inventory.

## Live constraints and operational evidence

The live wallet type CHECK still allows its 19 captured discriminators and excludes both `refund_payout` and `verification_debit`. `esim_purchase_refund` and `call_refund` are valid live types. The pending funding trigger still recognizes the different reversal list identified by the executor plan. Thus both pending repair blockers remain open with current production-constraint evidence; passing permissive fixture/adapter tests do not close them.

The two finalizer overloads still exist with defaulted second parameters; both update-status overloads also survive. No financial RPC or PostgREST finalizer call was invoked to reproduce ambiguity. Owner/default/effective grants and the definitions are now verified, while actual compatible HTTP behavior remains a later rollout/isolated-test obligation.

The failed `refresh-usage-forecasts` cron ran at **06:20 Asia/Muscat** on October 16. A read-only classification of its recorded error confirms the missing `esims` relation, matching the function-body finding. Raw error text and customer data were not copied. The hourly notification job's latest successful run does not close its conditional invalid-category branch.

The one expired plan-fee hold has no joined top-up execution in the aggregate. This is not enough to prove its payment/order/provider state; it was not released. No legacy funding lots or balances were invented or changed.

Security advisors currently report 3 error findings (the three definer views), 234 warning findings and 40 informational findings. These include 40 anon-executable and 190 authenticated-executable definer definitions, not 230 proven unauthorized operations: guarded admin/customer APIs and triggers require body/caller review. Both unpinned trigger search paths remain. Remediation references: [definer views](https://supabase.com/docs/guides/database/database-linter?lint=0010_security_definer_view), [mutable function paths](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable), [anon function access](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable). The complete grouped advisor results/links are preserved in the evidence JSON; none was applied mechanically.

## Register changes and next work

The original 52-row register remains the task index. All SQL entries can now use fresh catalog/constraint/ACL evidence because all 366 body hashes match the captured catalog. Existing local implementations remain **REPAIRED LOCALLY**, not deployed fixes. Specifically:

- F01/F03–F27/F28/F41/F42/F48/F50/F52 retain their repair/open statuses; missing deployment contracts, effective grants, defaults, constraints and cron callers are now verified where relevant.
- F12 additionally has a real recorded failed cron with the matching error classification.
- F29–F39 now have the exact deployed Edge versions/settings/source observations above. F30 must distinguish deployed no-hold behavior from local five-minute-hold and retry-variable defects. F34/A01 now include the deployed unsupported payout type.
- F38's blanket SMS/WhatsApp allegation remains **STALE**; the fail-closed entrypoints are deployed as versions 5 and 7.
- F40's alleged missing live email handler becomes **STALE**; live-only source recovery remains assigned to Tasks 16/22.
- F44 retains incomplete process/health manifest coverage, with eSIM-catalog drift now explained. F45–F47 retain limited **VERIFIED DEPLOYED** file-parity evidence; no provider fulfillment was exercised.
- F51's existing pricing failures remain open. The 36 passing Node tests, 24-pass/9-fail pricing suite and 254 verified archive hashes are results of the earlier Task 1 run. They were not rerun here; all eight financial migration hashes remain unchanged, and this follow-up changes only review artifacts.

The next authorized numbered work package remains Task 2. These connections make its deployed-consumer inventory stronger, and enable Task 3's live privilege checks. They do not authorize credential rotation, production fixes, supplier operations or rollout. Immediate access containment remains the separately reviewable recommendation in the original report; the refreshed evidence strengthens its priority.

Remaining unknowns are behavioral rather than lack of management access: actual provider credential validity/configuration, provider outcomes for legacy operations, historical reconciliation, complete auxiliary source parity, installed client artifact versions, loaded VM process identity beyond on-disk hashes, required voucher/reconciler services, and safe isolated/authorized runtime acceptance checks. No claim of current exploitation or historical customer loss is made.
