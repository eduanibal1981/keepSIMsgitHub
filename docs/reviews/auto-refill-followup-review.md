# Auto-refill follow-up review

15 September 2026 — review of remediation after the first implementation review.

## Opinion

**Meaningful progress, but changes are still required before accepting unattended real-money operation.** The previously reported anonymous approval access is closed, the pending-provider initialization is repaired, the six original resolver checks pass, and a customer approval action is connected. However, a newly deployed worker/database mismatch prevents purchases from reaching the supplier, and several financial and recovery requirements remain incomplete.

No production writes or paid purchases were made in this review. Added only this report and a separate local regression probe file. This review does not assert that a customer was overcharged or an owner loss actually occurred.

## Verification

- Read the new `20260915080000_remediation_security_and_concurrency.sql`, current workers/resolver, changed Flutter approval flow, and related existing migrations/adapters.
- Read actual Supabase function definitions, role permissions, table columns, constraints, and aggregate execution counts.
- Deployed VM file hashes match the three local files reviewed: resolver, custom worker, mini worker. This establishes deployed file parity, not in-memory process reload verification or a completed live refill.
- Executor phase suites: **26/26 pass**.
- Original review resolver probes: **6/6 now pass**.
- New boundary probes against the actual resolver: **0/4 pass**. These exercise request/quote consistency, missing legacy intent, service preservation, and out-of-range purchase values. They make no database/network/purchase calls.
- No PostgreSQL multi-connection integration test or Flutter end-to-end test was run here. The passing phase suites still include simulations/source-text checks and are not evidence that the new migration and workers function together.

## Confirmed improvements

1. **Approval and resume RPC privileges:** anonymous execution is revoked in the remediation. Approval includes owner/line-owner/household-manager checks. The original anonymous/cross-user approval defect is addressed for normal authenticated calls.
2. **Pending provider initialization:** the route trigger now initializes an empty attempted-provider array. All three currently pending custom executions have zero preattempted selected providers.
3. **Original matching failures:** preferred SKU benefit changes, source-cost substitution, historical-price substitution, and the explicit PIN fixture from the first review now fail appropriately. A range-maximum fixture now receives maximum rather than minimum cost.
4. **Customer approval wiring:** repository/controller calls and approval buttons are present in line details/history. The dialog mentions authorizing future refills up to the new amount.
5. **Persistence errors:** failed hold linkage or in-flight-marker writes now abort instead of merely warning and submitting anyway.
6. **Queue cap matching:** pending-row comparison now includes the cap, provider, engine version, and intent kind. Schedule changes/pause include awaiting-approval/funds states in cancellation.
7. **Retry intent:** the new retry function carries cap and intent fields and attempts to block unresolved purchases. Its implementation is currently broken by the missing field described below.

## Blocking findings

### S1 — P1: Both deployed workers require an execution column that does not exist

Sources:

- `C:/Users/abdal/Work/KeepSIMs/backend-sync-wt/worker_auto_custom_refill.js:339–347` and the equivalent mini-worker block.
- `supabase/migrations/20260915080000_remediation_security_and_concurrency.sql:397`.

Before sending a purchase, the workers update `topup_executions.carrier_in_flight=true` and throw if that write fails. **Live schema inspection found `carrier_in_flight` only on `wallet_holds`, not on `topup_executions`.** None of the supplied remediation migration statements adds it to executions.

Consequently, an otherwise valid refill reaching this code will fail before its supplier purchase. This is a deployed-file/schema incompatibility, not a hypothetical failed supplier response. The newly added retry function also reads `v_exec.carrier_in_flight` from an execution row and will error when that branch is reached.

**Correction:** implement the intended submission-state schema and migrate it before code depends on it, or consistently reference the actual persisted hold/attempt state. Verify both workers and the real Retry RPC in staging. Do not merely suppress the error: the durable submission guard is required for recovery.

### S2 — P1: Quoted amount and actual provider purchase amount can still differ

Source: `C:/Users/abdal/Work/KeepSIMs/backend-sync-wt/offer_validation.js:460–480`; the DT One/Reloadly purchase adapters send the supplied `offerValue`.

The revised resolver retains an existing `intent.offerValue`, while computing price from `targetValue` whenever it is present. It never proves these describe the same destination amount. This matters for legacy values, edited schedules, or provider changes with different units.

**Reproduced:** `targetValue=1`, `offerValue=100`, divisor 1, range cost $1–$100. The resolver returns an approved quote for **$1 cost plus fee**, but leaves **100** as the supplier purchase value. The amount held can therefore be far below the amount purchased once the submission-schema blocker is fixed.

Also reproduced: an old range `offerValue=1000` outside a catalog maximum of 100 is accepted. The pricing fraction is clamped to the maximum while the purchase value remains 1000. This can cause rejected purchases or inaccurate cost assumptions.

The minimum-cost bug is improved, but replacing it with generic linear interpolation is not proof of a supplier's actual debit or fee behavior.

**Correction:** derive the exact provider purchase payload from one canonical destination amount and that provider's units, reject inconsistent/out-of-range input, and obtain/prove the price for that exact payload. Do not carry another supplier's raw offer value into a replacement quote. Bind the checked payload, supplier cost bound, and wallet amount together.

### S3 — P1: Reminder-only schedules now enter the financial execution queue

Source: `supabase/migrations/20260915080000_remediation_security_and_concurrency.sql:272–350`; confirmed in deployed `trg_fn_sync_custom_refill_queue`.

The new function omitted the previous first guard:

```sql
IF NEW.schedule_type NOT IN ('refill_custom', 'refill_mini') THEN
  RETURN NEW;
END IF;
```

The trigger is attached to schedule insert/update generally. It now inserts `topup_executions` rows for an active `notify` schedule when the insert/update reaches its queue branch. Reminder-date changes can therefore create bogus financial queue rows and run fee/routing triggers. The live execution table allows arbitrary execution type text; its positive-amount constraint can also cause zero-amount reminder saves to fail through the nested insert.

This finding does **not** mean the two scheduled-refill workers currently purchase `notify` rows: they claim their own refill types. It means reminder-only work is now incorrectly coupled to financial queue creation and can break normal reminder operations.

**Correction:** restore the type guard before any queue mutation; test reminder create/edit/hourly advancement plus mini/custom create/edit against the actual trigger chain.

### S4 — P1: Recovery still stops at retained holds; reaper and worker disagree

Sources: custom worker catch at `610–624`, mini equivalent; deployed `reap_stuck_executions`; deployed settlement function.

The worker now intends to leave potentially submitted failures in processing, which is better. But the deployed reaper remains unchanged from the first review: it marks a stuck in-flight transaction `failed` after its threshold. The catch's attempt to persist the execution in-flight flag is also affected by S1. A provider's definitive decline still enters the general submitted-error path rather than releasing on proven non-delivery.

No new automatic provider-query/settlement recovery component was found in the remediation files. Keeping a hold, logging an alert, or forbidding Retry is not reconciliation. Delivered transactions can remain unsettled and customers can have unavailable funds with no automatic resolution.

**Correction:** implement a single persisted attempt state machine used by worker, reaper, Retry, and reconciler. Unknown/delivered-unsettled must remain distinguishable from confirmed failure. Query the original supplier reference; settle confirmed deliveries once; release confirmed non-deliveries; retain and escalate genuine uncertainty. Test worker crash, delayed supplier success, settlement outage, and terminal decline.

### S5 — P1: Incomplete intent still permits unrelated products; service requirements are dropped

Source: `offer_validation.js:355–404,431–432,606–615`.

The resolver now checks known benefit fields, but if a retired preferred ID has no saved amount/currency, it filters candidates against almost no intent and selects the cheapest. **Reproduced:** a retired SKU with no verified target selects an unrelated five-unit product. This remains relevant to mini/legacy schedules with incomplete target metadata.

`resolveBestSupplierRoute` also rebuilds the intent object without forwarding `serviceType` or `deliveryType`; the worker itself does not supply a verified service requirement. **Reproduced:** an explicitly requested airtime service resolves to a data offer after the route resolver drops the service field.

Unknown service/delivery metadata is often accepted rather than requiring evidence. The unchanged line-activity trigger still advances mini protection on successful custom/instant/manual transactions without proving that the carrier regards them as qualifying activity.

**Correction:** require complete, verified benefit and service/delivery semantics before automatic replacement; route all these fields unchanged; block for review when legacy intent cannot be recovered. Advance protection only from verified qualifying activity, not general purchase success.

### S6 — P1: Exact funding and successful settlement invariants remain incomplete

Sources: custom worker hold gate around `286`; deployed `settle_successful_execution`.

The worker still skips fresh reservation validation when an execution already has a hold ID. It does not prove that an existing hold matches the new quote's amount, owner, occurrence, and active status. The deployed settlement function remains unchanged: missing/null holds can bypass capture, and supplied holds are not required to match the execution payer/amount/reference before success is recorded.

Improved handling of failed persistence is useful, but it does not resolve this earlier review finding. Quote changes must not leave an underfunded old hold available for a larger purchase.

**Correction:** atomic quote/hold/attempt preparation, checked adoption, and settlement that requires a matching valid funded purchase or explicitly verified legacy funding arrangement. Delivered-but-unfunded is an exception for reconciliation, not success.

## Remaining work from the first review

| Earlier finding | Current assessment |
|---|---|
| R1: public approval | Normal anonymous access closed; authenticated ownership checks added. Privileged caller detection still uses `current_user` inside SECURITY DEFINER; verify service-role behavior separately. |
| R2: range pricing | Original maximum test fixed; S2 request/quote inconsistency and provider pricing proof remain. |
| R3: preattempted provider | Deployed trigger and three pending rows repaired. Resolver fallback now re-admits preferred provider even if actually attempted; distinguish real attempt history instead of overriding exclusions. |
| R4: product/validity semantics | Original cases fixed; incomplete metadata, dropped service, and unverified protection advancement remain. |
| R5: unresolved purchases | Worker catch improved; missing field, unchanged reaper, and absent demonstrated reconciliation remain. |
| R6: funding/settlement | Persistence errors now abort; matching-hold/settlement requirements remain. |
| R7: broad 1 OMR backfill | Unsafe migration remains unchanged; no evidence of audited restoration of original intents was supplied. Need row-level evidence before declaring resolved. |
| R8: approval UI | Button/API call added. It still labels customer total as “supplier price,” omits fee breakdown, and combines current approval with recurring authorization. Server quote/save and versioned consent are not complete. |
| R9: concurrency | DISTINCT ON and advisory locks added. Multi-connection correctness is unverified; other claim paths must participate. Same-statement snapshots and final dispatch checks require real concurrent testing. |
| R10: cap synchronization | Pending comparison and waiting-state cancellation improved. Claimed work still lacks a final schedule/consent version check; new reminder-scope regression S3 must be repaired. |
| R11: owner economics | Hard-coded worker fees, stale-cache fallback, and incomplete supplier-cost bounds remain. SQL quote path still requires review and UI/worker consistency. |
| R12: implementation/test completeness | Existing tests pass, but missing live column demonstrates lack of migration-to-worker integration coverage. No demonstrated full mini/customer/settlement journey. |

## Suggested execution order

1. Fix and verify S1 live-schema compatibility and S3 reminder isolation. Keep safety checks intact.
2. Close S2 exact payload/quote mismatch and reject incomplete/invalid amount inputs.
3. Complete S4/S6 reconciliation and funded settlement, including all retry entry points.
4. Close S5 product qualification and finish the audited legacy-intent repair.
5. Verify customer approval wording, published pricing, consent versions, and final dispatch authorization.
6. Run actual database integration tests and concurrent/crash scenarios, then an isolated provider-sandbox mini/custom journey. Do not declare success based only on the phase suites or by making individual source-text assertions pass.

## Reproduction commands and deployment evidence

From `C:/Users/abdal/Work/KeepSIMs/keep_sims`:

```powershell
node --test --test-isolation=none docs/reviews/auto-refill-review-repros.cjs
node --test --test-isolation=none docs/reviews/auto-refill-followup-repros.cjs
```

Observed: original suite 6 passes; follow-up suite 4 assertion failures against production resolver logic. Separate executor phase suites remain 26 passes.

Matching local/deployed SHA-256 hashes:

| File | Hash |
|---|---|
| offer_validation.js | e31e1d3b78e9e541c9d1caf01759a5bd9e734107051650d81d7c7039d20dc149 |
| worker_auto_custom_refill.js | b766d87aba953abaa6b0325c7c53beda35bf462c47a37ff499be198958f914aa |
| worker_auto_mini_refill.js | 71bb1539ffcc7f17ccd94cfdb020c6f599e4b4a81842a957485e6d8abf840143 |

**Acceptance recommendation:** retain the improvements, but request another implementation pass focused on the concrete blockers above. The implementation is closer to the plan, but not complete.
