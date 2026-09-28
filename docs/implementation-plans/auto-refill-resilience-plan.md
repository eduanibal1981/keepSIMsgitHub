# KeepSIMs auto-refill reliability, customer authorization, and financial safety

Implementation brief for the executor agent • Reviewed 15 September 2026

## 1. Objective and scope

Fix both `refill_mini` and `refill_custom` so a future refill uses a current, appropriate product and price; spends only what the customer authorized; and does not knowingly create an unfunded or unprofitable supplier purchase.

This is a plan, not an implementation or permission to run paid test refills. No application code, production settings, schedules, balances, or supplier transactions were changed during this review. Implement and validate the complete flow before enabling it for customers. Follow the existing deployment authorization process when rollout is requested.

Two release requirements take priority:

1. **Customer transparency:** show the benefit being purchased, estimated versus final price, all fees, maximum authorized charge, timing, money held versus spent, and any action needed to protect the line.
2. **Owner financial protection:** require an accurate, bounded supplier cost and sufficient reserved funding before submission; prevent duplicate purchases; reconcile every submitted attempt; and never silently release funds for a delivered or unresolved purchase.

Absolute zero loss cannot be guaranteed against provider misconduct, later reversals, chargebacks, or external failures. The engineering requirement is no knowingly negative-margin or unfunded dispatch, bounded exceptional exposure, and prompt reconciliation. Do not promise customers that automation guarantees a carrier will keep their number active.

### Review coverage and limitations

- Read Flutter scheduling, quoting, and configuration code; authoritative local Node workers and provider adapters; relevant migrations and tests.
- Queried the connected KeepSIMs database read-only. The project matches the app's configured default project `zwxswagokhgbuzrrbnhr` (`simSaveDB`). Checked deployed function definitions, attached triggers, relevant job schedules, fee rules, and aggregate schedule/execution counts.
- Live snapshot: three active custom schedules with three pending custom executions; four active notification schedules; no mini schedules/executions in those queries. This is not evidence that mini scheduling is correct or that historical losses occurred.
- Supplier retry is currently disabled (`SUPPLIER_RETRY_ENABLED=false`); its implementation and trigger exist. The reaper is enabled every five minutes. Low-balance reminders run through the hourly notification job and inspect a seven-day window, not three days.
- Did not inspect the cloud VM's running worker files, run production mutations, place purchases, or execute test suites. Executor must compare runtime files with local code before deployment and refresh these observations.
- Local changes already existed in `scheduled_topup_sheet.dart` and `line_upgrade_sheet.dart`. Preserve them and review the combined diff.

### Workspace and deployment locations

- App, migrations, and SQL tests: `C:/Users/abdal/Work/KeepSIMs/keep_sims`.
- Authoritative workers: `C:/Users/abdal/Work/KeepSIMs/backend-sync-wt`.
- Admin app: `C:/Users/abdal/Work/KeepSIMs/keep_sims_admin` (inspect applicable instructions before editing).
- Deployment instructions: [AGENTS.md](../../.agents/AGENTS.md). Backend changes are synchronized directly by SSH/SCP from the authoritative worker directory to the VM's `/home/abdal/keepsims_backend/servers/`, followed by syntax verification and targeted PM2 restarts. Do not substitute a GitHub pull workflow.

## 2. Current flow and verified findings

### Current flow

**Custom:** Flutter selects a supplier offer, calculates a fee locally, and writes a schedule containing offer ID, amount, base cost, fee, tier, and fee version. The repository directly inserts/updates `scheduled_topups`. Its model does not retain a provider alongside the offer ID or a customer spending cap.

**Mini:** setup activation creates a premium keep-alive schedule from the carrier rule and initial refill cost. The inspected setup function writes `v_rule.offer_id` and `v_rule.offer_value`, without the richer pricing/provider fields used elsewhere.

**Both:** the schedule trigger inserts an execution; the execution insert triggers calculate fees and choose routing; a worker claims due pending rows; it checks line liveness and entitlement, fetches a provider catalog, compares current cost with saved cost, reserves the stored retail amount, and purchases/polls. On success it calls a status RPC and then captures the wallet hold. The status change triggers notifications, line activity updates, and creation of the next occurrence.

### Findings to address

| ID | Evidence and behavior | Required correction |
|---|---|---|
| F01 | `offer_validation.js`: fixed prices must match saved base cost within $0.01; missing IDs fail. | Resolve and quote just before purchase. Preserve strict quote validation rather than widening tolerance. |
| F02 | Live `update_sim_line_last_topup_at` copies historical amount/base cost/offer into the next row. Updating the schedule also invokes a second queue writer. | One owner for occurrence creation; no frozen price propagation. Test trigger interaction, not just each function alone. |
| F03 | Schedule model/queue insert omit provider. Live route trigger fills it from the carrier's primary mapping. | Preserve provider-qualified offer identity and verified carrier mapping. Never infer provider from a globally unqualified ID. |
| F04 | Both workers set success before capture; capture errors are logged and execution continues. Live success RPC only updates execution status/timestamps. | Atomic local settlement: wallet debit, settlement status, receipt event, and occurrence advancement. |
| F05 | General worker catch releases the hold even after purchase or a failed database success write. | Distinguish pre-submission failure, definitive provider failure, and unknown/delivered outcomes. No release on uncertainty. |
| F06 | Indeterminate polling returns with row still processing. Live reaper requeues after 15 minutes, eventually marking it failed without querying the supplier. | Separate lease recovery from payment reconciliation; unresolved submission must not be treated as a new purchase. |
| F07 | Live supplier failover inserts a new execution using another provider but the original offer ID/value; price notification uses base cost, not full customer charge. | Replace for v2 with equivalence matching, current authorized quote, explicit attempt history, and total-price notifications. Keep disabled until tested. |
| F08 | Workers retain a newly created hold ID only in a local variable; reservation RPC does not attach it to the execution. | Persist quote, attempt, and hold linkage atomically before network submission. |
| F09 | Live reservation adopts an active reference without checking requested user/amount/currency. Funding-lot allocation uses remaining amounts without subtracting other active allocations, and does not reject a residual unallocated amount. | Strengthen idempotency identity and multi-hold allocation invariants; validate other consumers of the same wallet functions. |
| F10 | Awaiting-funds handlers write `awaiting_funds`; live claim function only claims `pending`. No dedicated refill wake-up path was found in inspected database functions/workers. | Explicit wallet-credit wake-up plus periodic recovery, with fresh quote and consent checks. Verify all deployed jobs for any additional behavior. |
| F11 | Client computes prices and range conversions; range UI has fallback FX/divisor values. Local fee calculator and database trigger have separate fallback behavior. | Server-authoritative quoting; client submits intent, not supplier cost, fee, tier, or final debit. |
| F12 | `source_amount_native` is supplier-side cost. Cache writer drops fixed-product send min/max; cache fallback marks reconstructed offers enabled and can serve old data. | Preserve destination benefits for all products, units, availability, provenance, and actual fetched time. Never use cost as face value. |
| F13 | Current carrier resolver filters a USD price floor and prefers primary provider before direct delivery. It reports staleness rather than excluding it. | Determine carrier qualification from the delivered activity/denomination, then select among fresh eligible offers. Existing cost floor is not evidence of carrier validity. |
| F14 | Mini worker can record a PIN purchase as success; line trigger advances last-top-up for every successful execution. Mini PIN notification references an undefined `userId` and invents a dial instruction fallback. | Separate purchase delivery from qualifying carrier activity; reject PIN for unattended mini until verified redemption exists. Correct legacy PIN delivery handling. |
| F15 | Result trigger sends success before capture; worker catch and trigger can both send failure notifications. Messages may say no funds were deducted without proving release. | One durable notification event per transition; derive money wording from actual ledger/hold state. |
| F16 | Entitlement check rejects only when the RPC succeeds and returns a found record; unknown/error can fall through. | Require affirmative authorization and entitlement before new purchase. An unavailable dependency causes a recoverable wait. |
| F17 | Live `update_execution_status` has both a three-argument overload and a six-argument overload with defaults. | Verify PostgREST resolution; provide one unambiguous v2 settlement RPC and test legacy callers. |
| F18 | Some wallet worker tests only mutate a test object and assert its new value, without calling production logic. | Add real worker orchestration, adapter, database, concurrency, and fault-injection coverage. |

Do not assume retries necessarily omit fees: the live execution insert fee trigger can recalculate them. The underlying problem is that retries copy old base cost and product identity without an authorized current quote.

### Principal source map

Worker directory: `offer_validation.js`, `worker_auto_custom_refill.js`, `worker_auto_mini_refill.js`, `providers/{dtone,reloadly,ding,zendit}.js`, `offer_validation.test.js`, `test/wallet_reservation_fulfillment_test.js`.

App directory: `lib/features/scheduled_topups/{model,contract,repository,controller,ui,domain}`, `lib/features/sim_lines/domain/{line_refill_quote,refill_pricing}.dart`, `lib/features/sim_lines/presentation/providers/{api_offers_providers,line_refill_quote_provider}.dart`, `lib/features/sim_lines/presentation/widgets/{premium_refill_config_sheet,line_upgrade_sheet}.dart`, wallet/notification/activity/protection screens, and translations.

Database migrations to trace: `20260914030000_tier_aware_scheduled_refill_pricing.sql`, `20260908210000_refill_mini_queue_and_wallet_reminders.sql`, `20260909010000_fix_standard_line_setup_and_sim_line_binding.sql`, `20260907100000_wallet_holds_lots_and_refunds.sql`, `20260910020000_p1_p2_app_fee_rules_and_canonical_entitlements.sql`, `20260910031500_p4_calling_rate_precision_and_draft_fallback.sql`, `20260904000000_carrier_refill_offer_prefer_primary.sql`, `20260815000000_i5_supplier_policy_and_failover.sql`, `20260717060000_c3b2_cancel_and_claim_guard.sql`, `20260717080000_c3b2_scheduled_write_rpcs.sql`, and deployed reaper/status definitions missing from that migration search.

## 3. Product rules and implementation defaults

These defaults make implementation concrete. They are not invented customer consent. Preserve existing contracted terms; where legacy authorization cannot be established, request it before using variable pricing.

### Mini versus custom

| Rule | Mini keep-alive | Custom recurring refill |
|---|---|---|
| Intent | Perform the carrier's verified qualifying activity before its deadline. | Deliver the specified airtime amount or package benefits on the selected cadence. |
| Matching | Direct qualifying recharge; choose lowest total customer price among reliable, eligible routes; use existing routing preferences as tie-breakers. | Exact destination amount/currency and service/delivery semantics; package identity/benefits must match an approved equivalence group. |
| Substitution | Another qualifying denomination may be used only within the recorded mini authorization and cap. | No automatic amount increase, reduction, data substitution, or PIN substitution. An unverified replacement requires approval. |
| Carrier rules | Versioned rule, denomination currency/units, qualifying activity, evidence date, deadline, and safety margin. | Do not label successful purchase as line protection unless it qualifies under the carrier rule. |
| Timing | Recompute from verified qualifying activity and current reviewed carrier rule. | Preserve the customer's selected cadence. Default to the existing interval-after-completion behavior and explain it. |

Carriers requiring usage rather than recharge need an honest “additional activity required” state. Do not invent an automatic usage mechanism. Remove unsupported fixed grace-period assumptions from protection displays; the existing date helper's universal seven-day grace must not be treated as carrier evidence.

### Customer authorization

- Required for newly enabled auto-refill: maximum **total USD charge per refill**, including all customer fees, displayed separately from estimated destination benefit and current estimated charge.
- Require positive confirmation of the limit and substitution policy. Store payer, actor, schedule version, timestamp, policy version, and approved wording/terms reference.
- Default proposed limit in UI may equal the current server quote. Do not silently add 5%, $0.25, or any other allowance. Customer can explicitly increase it.
- Limit is an authorization ceiling, not a target selling price. The final charge follows the published pricing rule and may be lower.
- One-time quote approval authorizes that quote/benefit up to its expiry. A higher recurring limit is a separate explicit action. A later price above approved total needs new approval; a lower recalculated charge for identical authorized benefit can proceed under the recorded policy.
- Apply existing household permissions and spending caps, plus period-level reservations, at the final amount. Lowering/pausing a schedule invalidates unsubmitted quotes. Once submission is committed, cancellation cannot promise to recall it; show “already processing.”
- Pricing/fee/tier changes invalidate unsubmitted quotes. Incompatible changes to authorization terms require renewed consent. Resolve tier on the server.
- Do not introduce automatic wallet deposits or automatic charging of a saved payment card as part of this fix.

### Owner economics

Maintain distinct values:

`supplier cost upper bound = verified supplier debit + supplier fees + applicable taxes + conservative FX/settlement cost`

`expected contribution = final customer charge - supplier cost upper bound - allocated variable costs`

Dispatch only when expected contribution meets the versioned nonnegative margin floor, the final total is within customer authorization, and the exact charge is fully reserved. Use current published tier fees; a margin shortfall should block that route, not silently add a customer surcharge. Raise required prices only through a published, disclosed pricing policy.

Include known wallet-funding/conversion costs once, with explicit allocation rules. Do not count a fee twice or treat a catalog's display/override price as wholesale cost. Supplier account rebates/commissions count only when contractually reliable and measurable. Unknown economics block automatic dispatch. Promotional credits require a separately recorded, funded subsidy budget; they are not cash revenue.

At review time the published refill rule is version 1: Free max(7%, $0.50), Standard max(5%, $0.30), Premium max(3%, $0.10). Read rules at runtime; do not hard-code these as permanent policy. A valid published zero fee is different from no rule. Do not use unpublished/draft rules for live v2 refills; preserve unrelated calling behavior when adjusting the shared fee resolver.

Use decimal arithmetic internally and integer USD cents at the customer wallet boundary. Persist native supplier currency and amount with sufficient precision, destination units, FX rate/source/time, and deterministic rounding. Avoid floating-point equality for money. Validate finite positive costs and reject missing currencies/units; no guessed FX or default destination currency.

No submission may have unbounded supplier cost. Each adapter must prove a binding price, maximum-price enforcement, or a contractually bounded debit. Where supported, evaluate a create/quote/confirm flow before confirmation. A local five-minute quote alone does not lock a supplier price. Providers without a defensible bound stay in preview/manual review until their exposure policy is explicitly resolved. After submission, never increase the customer charge to compensate for an unexpected invoice; retain evidence, alert, and suspend that route if necessary.

## 4. Target data model

Reuse `scheduled_topups` and `topup_executions`; add normalized quote, attempt, consent, and notification records as needed. Names below describe proposed contracts, not existing APIs.

### Schedule intent and authorization

Add `engine_version`, `schedule_version`, `intent_kind`, carrier reference, destination currency/amount, service type, delivery type, exact package/equivalence reference where applicable, preferred provider/offer hint, substitution policy, authorization currency/maximum, consent ID/version, carrier-rule version for mini, and structured blocked reason.

Keep current timing/is_active fields compatible during migration. Distinguish “configured active” from “ready to execute.” A schedule awaiting approval/funds/catalog evidence is not fully protected. Amount fields retained for older clients become clearly documented estimates, not authority to debit.

### Occurrence

One logical occurrence per schedule cycle, with stable cycle identity and unique `(schedule_id, cycle_key)`. Store intended execution time, protection deadline if known, retry deadline, next retry time, engine version, schedule/consent version, quote ID, hold ID, settlement status, delivery/qualification status, and lease token/expiry.

Retries belong to this occurrence; they do not create another customer charge or another next-cycle chain. Keep old `retry_of` history for audit, but do not use a fresh execution ID as the identity of an uncertain original purchase.

### Immutable quote

Store occurrence/schedule versions, provider and provider-specific carrier/offer identity, full destination benefit and units, native supplier amount/currency, cost bound, supplier fees, FX provenance, selling-price components, total USD cents, pricing tier, fee-rule version, margin-policy version, quote creation/expiry, catalog evidence/freshness, and provider quote reference if supported.

For ranged offers store both canonical destination amount and the provider-specific purchase parameters. Derive the exact cost with that provider's calculation mechanism; do not assume linear interpolation or interchangeable minor units across suppliers.

Store catalog observation time separately from local cache access time. A database-cache read must never make an old supplier observation appear fresh.

### Fulfillment attempt

Store occurrence ID, monotonically numbered attempt, quote ID, provider, stable external request ID, request fingerprint, submission phase/time, provider transaction ID, outcome classification, cost evidence, response timestamps, retry/reconciliation schedule, and redacted diagnostic data.

Constraints: external ID unique per provider, at most one unresolved submission for an occurrence, and at most one completed local debit for the occurrence. A new provider attempt is allowed only after evidence that the previous attempt cannot fulfill, including supplier cancellation/void requirements. A fresh external ID must not be generated merely because the response was lost.

### Security and audit

Server owns prices, cost bounds, provider selection, holds, attempts, settlement, and qualification evidence. Client RPCs accept intent/authorization only and enforce authenticated ownership/household role plus version checks. Apply RLS and explicit grants; keep financial mutation RPCs service-only. Redact credentials, full phone numbers, and PINs from general logs. Give customers receipts/hold status and owners cost/margin evidence through separate authorized views.

## 5. Execution and recovery design

### State transitions

```text
scheduled -> quoting -> ready -> reserved -> submitting -> provider_pending
                |        |                           |          |
                v        v                           +----------+
      waiting_catalog / awaiting_approval / awaiting_funds       |
                                                          reconcile
                                                        /          \
                                                 delivered       definitive failure
                                                     |                   |
                                               settle locally       release hold
                                                     |                   |
                                                  settled       retry_wait / action_required
```

Keep fulfillment and settlement states separate: delivered but unsettled must remain recoverable, with funds reserved. Customer-visible status can say “Recharge delivered; payment finalizing.” A PIN purchase delivered is not evidence of airtime redemption.

### Ordered worker algorithm

1. Claim an occurrence with a bounded lease and fencing token. Require current schedule activation, ownership, entitlement, valid engine version, and supported fulfillment gateway. Never hold database locks during supplier HTTP calls.
2. If any persisted attempt is submitted or uncertain, go directly to reconciliation. Do not select a new offer or reprice an already submitted purchase.
3. Resolve fresh eligible offers from the canonical catalog and supplier APIs. Exclude disabled mappings/providers/products, stale FX, unknown benefits, unsupported gateways, and unhealthy/unfunded routes. A temporarily unavailable catalog is a recoverable state, not tampering.
4. Match intent first, then calculate full customer price and bounded costs using the authoritative server pricing service. Select a qualified, affordable, profitable route; keep deterministic tie-breakers and record the reason.
5. Compare price and benefits against current consent and all spending limits. Persist actionable waits without touching supplier funds if approval, funds, or rule evidence are missing.
6. In one database transaction, validate quote expiry/version, lock the relevant occurrence/payer budgets/wallet consistently, reserve the exact amount, validate/adopt only an identical hold, and attach quote + hold + prepared attempt. Return an immutable dispatch payload.
7. Immediately before network submission, atomically claim the submission transition using the current lease token. Pause/edit and dispatch race on this transition. Once committed, treat any crash as potentially submitted and reconcile by the saved external ID.
8. Submit using the adapter's verified amount/unit/price-bound and idempotency contract. Persist supplier identifiers as soon as obtained. Classify timeouts/network errors/ambiguous responses as unknown, not failed.
9. Confirmed delivery: persist provider evidence and invoke an idempotent settlement transaction. Capture the exact authorized hold, record receipt and financial ledger, mark settled, update qualifying activity only when proven, and ensure the next occurrence exactly once. Notification delivery is asynchronous.
10. If settlement fails, retry settlement/reconcile; never release the hold, resubmit the purchase, or mark provider delivery failed. Preserve both operational failure and supplier evidence.
11. Definitive non-delivery: release only after the supplier cannot fulfill. Schedule a bounded retry or alternative attempt if still authorized and before the deadline; re-quote before that new attempt. No customer debit for a failed refill. Record any nonrefundable supplier attempt fee as owner cost and enforce an attempt-exposure budget.
12. Unknown/pending: keep funds reserved, poll/query with bounded backoff and authenticated callback support, show a truthful delay message, and escalate when provider-specific time limits are exceeded. Never auto-release based solely on wall-clock hold expiry.

Use one shared engine for both workers with separate intent policies, not two copies of financial logic. Preserve current launch/process interfaces where possible.

### Reaper, retries, and settlement responsibilities

- Change `reap_stuck_executions` for v2: reclaim an abandoned pre-submission lease; schedule reconciliation for a possibly submitted attempt. Age or exhausted retries alone cannot prove failure.
- Keep the current supplier-failover trigger from creating v2 executions. V2 retry/failover must call the shared resolver and retain the original occurrence. Avoid breaking instant/manual legacy work that shares the trigger.
- Unify user Retry, system retry, wallet wake-up, callback, and admin retry under the same state checks. No caller may bypass cap, budget, qualification, current consent, or unresolved-attempt rules.
- Implement wallet-credit events plus a periodic sweep to revisit awaiting-funds rows. Recompute affordability with available balance, not posted balance. Do not allow an insufficient-funds loop to create repeated holds or notifications.
- Expired unsubmitted quotes may be replaced; their unused holds can be released/replaced transactionally. Once submitting, the quote/charge remains fixed. Supplier success after a client disconnect or expired lease still settles once.
- Refund/reversal is a compensating ledger transaction, never deletion of history. Verify supplier reversal evidence, reverse customer charges under the disclosed failed-delivery policy, update protection evidence, and alert on unrecovered supplier fees/cost. Handle duplicate/out-of-order callbacks monotonically, with explicit reversal transitions.
- Set one consistent lock order across all hold, capture, release, refund, gift, and budget operations; test concurrency and deadlocks. Active funding-lot allocations must be deducted before allocating another hold, and allocations must equal the full hold amount. A released allocation no longer consumes availability.

### Recurrence and protection

Replace the two competing queue-creation paths for v2 with a single `ensure_next_occurrence` operation. Retain schedule synchronization for legacy clients during rollout, but prevent it from cancelling/recreating an already reserved/submitted occurrence.

An error must not leave an active schedule without either a next occurrence or a visible blocked state. A periodic audit repairs missing unsubmitted occurrences idempotently. Do not schedule a mini refill beyond the protection deadline because the previous attempt was delayed. Separate cadence, attempt retry time, and carrier deadline.

Coordinate mini, custom, instant, and auto-rescue activity for the same line. Serialize qualifying-activity decisions; re-evaluate mini need after an actually qualifying custom/instant recharge. Do not silently cancel a separately requested custom benefit. While a relevant supplier outcome is unknown, another protection purchase must not assume it failed.

## 6. Customer experience and notifications

### Setup and edit screens

Both custom and premium-mini configuration must show:

- Destination benefit, currency, and delivery method.
- Current estimated recharge price, KeepSIMs fee, other applicable customer fees, and total in wallet currency.
- Maximum total per refill and permitted substitutions.
- Next planned attempt; mini protection deadline and basis when known; whether further carrier activity is required.
- “The price is checked before each refill. We reserve the final amount from your wallet. We ask before exceeding your limit.”
- Pause, change limit, and review activity actions; explain already-processing purchases.

Use server responses for saves and price display. Require connectivity for financial authorization. Show stale offline estimates as such, and never report a price/limit change saved before server confirmation. Localized USD versus recipient-currency labels must remain clear in all supported languages and RTL layouts.

### Example wording templates

Illustrative prices only; render actual quote, hold, and ledger values.

| Situation | Customer wording |
|---|---|
| Upcoming | “Your 1 OMR airtime refill is planned for 15 February. Estimated total: $3.64, including the KeepSIMs fee. Your limit is $4.00. We will check the price again before the refill.” |
| Approval | “The new total is $4.15, above your $4.00 limit. Approve this refill or change your limit. We have not submitted it. Action is needed before [verified deadline].” |
| Funds | “This refill needs $3.64. Your available wallet balance is $2.00. Add $1.64 to continue. No refill has been submitted.” |
| Processing | “We reserved $3.64 for your refill. The provider is still confirming delivery. Please do not retry; we are checking the result.” |
| Settled | “1 OMR airtime delivered. Charged $3.64: recharge $3.53 + KeepSIMs fee $0.11. View receipt and next refill.” |
| Confirmed failure, released | “The refill was not completed. The $3.64 reservation has been released. No refill charge was made. [Next attempt or action].” |
| PIN delivery, legacy/custom consent | “Your voucher is ready. Redeem it to apply the airtime. Your line's protection has not yet been confirmed.” |
| Blocked | “Automatic refill needs attention: [specific reason]. Your next protection deadline is [verified date], or ‘not confirmed’ if unknown.” |

Send an advance preflight message three days before planned execution by default, immediately if the schedule is created inside that window, and urgently when a protection deadline is close. Keep periodic seven-day wallet forecasting if useful, but deduplicate overlapping messages. Recheck at dispatch; the reminder is an estimate, not a locked price.

Use a durable outbox written with state changes, with unique `(occurrence, event_kind, event_version)` keys. Dispatch through existing notification preferences and supported push/WhatsApp channels. Distinguish queued, sent, delivered, and failed; writing `delivered_via=['push']` is not proof of delivery. Notification failure must not cause a financial retry. Keep an in-app action card even if external delivery fails.

Replace duplicate generic trigger/worker messages for v2. Do not expose “fraud/tampering” to customers for ordinary price drift. Use structured reasons: quote expired, catalog unavailable, product retired, approval needed, insufficient funds, entitlement unavailable, provider pending, definitive failure, settlement pending. Reserve security alerts for actual integrity violations.

Update wallet available/held/spent displays, receipts, activity logs, retry controls, and protection/health indicators. A configured schedule alone must not display “protected” if it cannot execute. Customer receipts show full selling-price components; owner reports show supplier cost, fees, subsidies, and contribution separately.

## 7. Implementation work packages and order

### Phase 0 — Baseline and reproducible failures

1. Refresh deployed definitions, trigger order, grants, state constraints, cron invocations, runtime versions/hashes, and active/queued records without exposing personal data.
2. Map every writer of scheduled executions: setup/upgrade, UI saves, recurrence, manual retries, supplier retries, reaper, auto-rescue, scripts/manual gateways, and any external services.
3. Capture redacted fixtures for all four provider adapters, fixed and ranged products, direct/PIN, costs and destination units. Verify each provider's duplicate request and status lookup guarantees against current official docs and sandbox behavior.
4. Add failing tests for F01–F18 where applicable. Do not run live purchase workers merely to import them; split engine modules from process startup.

**Exit:** documented flow/writer map, current runtime diff, reproduced priority failures, and a provider capability matrix. No live failover activation.

### Phase 1 — Settlement, holds, and recovery foundation

Implement occurrence/attempt identity, persisted hold linkage, atomic settlement, strict transition checks, hold allocation fixes, submission-aware reaper/reconciliation, and shared engine boundaries. Introduce engine-version gates so old recovery/fee/failover triggers cannot mutate v2 semantics. Fix success-before-capture and false no-charge messages for the migration path.

Audit the existing generic wallet debit/refund/gift paths because wallet protection fails if another debit ignores active holds. Reuse existing wallet accounting rather than create a second balance system.

**Exit:** lost-response/crash/concurrency tests prove one provider purchase and one authorized debit, or a visible unresolved reservation requiring reconciliation. Database failure after delivery cannot cause release or repurchase.

### Phase 2 — Canonical offers, pricing, and authorization

Extend provider normalization/cache schema to retain destination benefits and precise units for fixed and range offers. Remove unsafe stale-cache activation and guessed FX. Implement intent matcher, reviewed carrier-rule qualification, current server quotes, published-fee lookup, margin checks, explicit customer caps/consent, and ownership/versioned RPCs.

Audit adapter cost interpretation: source face amount, sender amount, wholesale price, fee, retail price, and settlement debit are not automatically interchangeable. Do not generalize DT One normalization to the other suppliers.

**Exit:** each supported route has a proven bounded-debit contract and matches benefit/price/ledger fixtures. Unproven routes remain unavailable for automatic spending.

### Phase 3 — Scheduling and customer surfaces

Wire both workers to the shared engine; establish single occurrence creation; update setup and upgrade paths to write intent/consent; update custom/mini forms, generated Dart models, wallet state, receipts, notifications/outbox, and protection status. Add awaiting-funds/approval recovery and cross-flow mini protection coordination.

Preserve existing instant/offline/manual behavior unless a shared financial fix requires changes; test those paths. A claimed gateway unsupported by the worker must be routed correctly or blocked before reserving or purchasing.

**Exit:** end-to-end mini and custom journeys pass, including setup, save/edit, pause/resume, approval, funding, provider delay, receipt, and next-cycle creation.

### Phase 4 — Safe product replacement and supplier failover

Enable preferred-offer replacement first, then cross-provider replacement only for capabilities proved in Phase 2. Replace the old same-ID failover logic for v2. Reprice and reauthorize each unsubmitted alternate attempt, preserve financial history, enforce attempt limits and aggregate owner exposure, and use terminal supplier evidence before switching after submission.

**Exit:** duplicate/lost responses, declined purchases, replacement SKUs, and different provider units all behave correctly with failover on; unknown outcomes never create an alternate purchase.

### Phase 5 — Backfill, staged release, and operational verification

Follow migration and rollout below. Produce a change summary, tests/evidence, applied migration names, worker hashes, PM2 process list checked, and remaining blocked routes. Do not claim completion with only syntax checks or simulated object tests.

## 8. Migration and compatibility

1. Add new fields/tables/RPCs compatibly. Use the repository's migration workflow; do not rewrite historical migrations. Compare actual deployed schema first because not every live function definition appeared in the local migration search.
2. Generate a read-only backfill report for active schedules and queued executions. Classify destination intent, provider identity, pricing provenance, authorization evidence, and any submitted/unknown attempt. Current three custom schedules are a small cohort, not permission for unconditional conversion.
3. Recover provider identity only from trusted schedule/setup records or a unique carrier/provider catalog match. A bare product ID or dollar amount is insufficient. Recover fixed destination benefit from provider metadata where possible; unavailable evidence requires customer/admin review.
4. Missing customer authorization is not equivalent to accepting a new variable price. Preserve documented legacy terms where provable. Otherwise migrate into `needs_authorization`, notify with the current estimate/limit proposal, and show protection attention. Do not delete the schedule or silently mark it protected.
5. Do not rewrite submitted/uncertain purchases, existing ledger entries, or old receipt prices. Reconcile them under their original references and charge authorization. Migrate unsubmitted occurrences using stable cycle keys, cancelling duplicates only when definitively unsubmitted and logging the reason.
6. Separate historically ambiguous amount/base/fee records. Never assume the old amount includes or excludes a fee. Do not retroactively bill customers for an inferred historical shortfall; report discrepancies for owner review.
7. Treat old mobile clients explicitly. They may view compatible estimates; financial edits to v2 schedules must use the new contract or return an actionable update-required response. Direct table writes must not overwrite quote/cap/consent fields or regress engine versions.
8. When a migrated schedule needs authorization or product review, show it visibly before the deadline. Provide reminders/manual action options; no paid fallback without consent.

## 9. Acceptance tests — release gate

Run SQL integration tests in an isolated/local or staging database with rollback fixtures, not paid production. Node tests must call production engine functions with controlled adapters and real database integration where appropriate. Add Flutter widget/integration tests for financial authorization and status journeys. Syntax checks supplement, not replace, behavior tests.

| Scenario | Required result |
|---|---|
| Same product costs $0.02 more at execution | New quote and exact new hold within consent; no false tampering; no stale debit. |
| Product becomes cheaper | Published pricing recalculates lower final charge; cap is not charged as a flat price. |
| Total exceeds customer limit by one cent | Zero supplier submission; explicit approval state and correct notification. |
| Profitable primary unavailable; alternate matches | Fresh alternate quote within authorization; actual alternate provider SKU and units used. |
| Alternate affordable but below margin floor | Route rejected; no hidden surcharge or silent owner subsidy. |
| Missing/old FX, NaN, zero cost, currency/divisor mismatch | No dispatch; diagnostic and recoverable/blocking state as appropriate. |
| Fixed SKU retired; equivalent replacement exists | Correct destination benefit and delivery preserved; replacement evidence recorded. |
| Same name or price but different benefit/PIN/data | Rejected as automatic equivalent. |
| DT One/Reloadly/Ding/Zendit ranged offers | Exact provider amount/currency payload and actual quoted total; no assumed linear conversion. |
| Two holds use the same funding lots | Available allocations do not overlap; capture leaves no negative lot or ledger imbalance. |
| Reuse hold reference with changed payer/amount/currency | Rejected; cannot adopt an underfunded or unrelated hold. |
| Two workers, user Retry, reaper, and callback race | One logical occurrence, at most one unresolved submission, one capture. |
| Crash before HTTP versus after accepted HTTP without response | Prepared state recovers safely; unknown request is reconciled using persisted identity. |
| Provider success; settlement database unavailable | Hold retained; no failure/refund lie; later settlement completes once. |
| Poll pending beyond 15 minutes / four-hour hold TTL | No blind failure, hold release, or supplier switch; visible reconciliation continues. |
| Provider decline with delayed response | Release/failover only after trustworthy terminal evidence. |
| Duplicate/out-of-order callbacks and later reversal | Idempotent monotonic state and compensating ledger, no extra debit/refund. |
| No wallet funds, then deposit | Fresh quote and authorization check; exactly one resumed occurrence. |
| Fee/tier/consent changes after preflight | Unsubmitted quote invalidated; reserved/submitted handling follows explicit rules. |
| Published zero fee, no published fee, draft-only fee | Zero respected when valid; absent policy blocks; draft never silently charges live refill. |
| Pause/delete/edit races with dispatch | Before submission prevents purchase; after submission shows processing and reconciles once. |
| Success invokes recurrence plus schedule triggers | Exactly one next occurrence, no inherited final quote, no cancel/recreate loop. |
| First attempt fails with no future row | Current cycle has retry/action state; schedule never silently disappears. |
| Custom refill already qualified for mini protection | Mini reevaluates need using verified activity; customer custom benefit is preserved. |
| PIN fulfilled but not redeemed | No automatic carrier-validity extension; secure delivery or actionable error. |
| Unknown/ineligible entitlement or unsupported gateway | No purchase; correct recoverable wait or customer action. |
| Notification fails/retries | No repeated purchase, settlement rollback, or duplicate receipt; delivery status truthful. |
| Legacy schedule missing provider/cap | Reviewed backfill or explicit action needed; no guessed authorization. |
| Older client, household manager, unauthorized caller | Read compatibility and explicit permission checks; no protected financial field writes. |
| Phone timezone/DST and rule change | Correct displayed date and UTC instant; no invented grace period or missed mini deadline. |

Extend existing SQL wallet and household tests with multi-connection contention, worker settlement tests, notification dispatch tests, scheduled-write/claim tests, offer-validation tests, and tier-pricing UI tests. Validate rollback behavior and adverse timing at each transaction/network boundary.

## 10. Rollout and operations

- Add controls for v2 dispatch, allowed carriers/providers, v2 substitution/failover, and a purchase kill switch. Reconciliation and settlement must remain running when new purchases are disabled.
- Start in shadow mode: resolve/price/report outcomes, with no wallet holds, supplier purchases, or customer notifications. Compare estimated customer totals, expected contribution, consent coverage, product match rates, and blocked reasons.
- Validate in supplier sandbox/staging, including a specifically seeded mini flow because live inspection had none. A paid production smoke test requires a concrete authorized test line and maximum spend.
- Release compatible schema and worker changes with v2 dispatch off; ship customer authorization/UI; backfill reviewed schedules; enable a small consented cohort per provider. Ensure old reaper, fee, and failover triggers cannot touch v2 rows incorrectly.
- Follow the direct synchronization workflow in AGENTS.md, transfer all changed dependencies, verify syntax and hashes remotely, restart only relevant processes, and check logs/status. Check cron recovery and outbox dispatch separately from PM2 worker uptime.
- Expand only after staging gates pass and the cohort shows no unlinked reservations, unauthorized charges, duplicate purchases, or settlement inconsistencies.
- Rollback means stop new v2 submissions while continuing reconciliation/settlement and preserving new tables/evidence. Do not revert submitted rows to the old engine, drop financial records, or reactivate unsafe blind retries. If safe purchase service cannot continue, display action-needed status and notify affected customers.

### Monitoring and reconciliation

Owner dashboard/alerts: delivered-but-unsettled count/value; unknown submissions and age; held amount without occurrence; execution/hold amount mismatch; supplier invoice versus quote delta; negative or below-floor contribution; missing pricing/cost evidence; failed notification delivery near deadline; active schedules without next occurrence; impending protection deadlines; pending approvals/funds; duplicate cycle keys; stale catalog/FX; funding-lot imbalance; owner exposure to nonrefundable failed attempts.

Reconcile supplier transaction reports, wallet holds/debits/refunds, quote snapshots, and local attempts at least daily, with faster processing for unresolved attempts and approaching deadlines. Use provider-specific SLAs and backoff. Alert immediately on delivered-but-unfunded, unauthorized debit, duplicate purchase, or inconsistent ledger; disable the affected purchase route while preserving reconciliation. Set measurable thresholds in configuration and document the responsible support/owner action.

Customer support must be able to see a redacted attempt timeline, authorized quote, money state, delivery evidence, next action, and notification history. Manual intervention must use audited RPCs; a “retry” button cannot bypass an unknown provider result.

## 11. Executor completion checklist

- [ ] Mini and custom share one verified financial engine and have distinct product-intent policies.
- [ ] Customer authorization is explicit, versioned, enforced server-side, and shown consistently.
- [ ] Current supplier cost is bounded; final charge covers the required economics without exceeding consent.
- [ ] Every possibly submitted purchase has a durable identity, linked hold, and reconciliation path.
- [ ] Atomic settlement, funding-lot allocation, hold adoption, retries, and refunds pass concurrency tests.
- [ ] Existing reaper/failover/fee/notification/recurrence triggers are coordinated with v2.
- [ ] Missing catalog or carrier evidence blocks transparently; PIN delivery is not treated as line protection.
- [ ] Next-cycle creation and awaiting-funds/approval recovery work without duplicates or lost schedules.
- [ ] Both customer surfaces, receipts, wallet states, and supported translations are updated.
- [ ] Legacy backfill, old-client behavior, shadow mode, rollout, and rollback are tested.
- [ ] Evidence includes actual test commands/results, provider capability checks, migration/runtime comparison, and remaining limitations. No claim of production verification without actual production evidence.

## 12. External technical references

- [DT One transaction lifecycle](https://developers.dtone.com/reference/transactions-1): submitted/confirmed are not final; transaction lookup supports external IDs; a completed PIN is distinct from a recharge; reversals can occur. This supports the reconciliation and delivery-state design, not a blanket price-lock guarantee.
- [DT One ranged recharge fields](https://developers.dtone.com/docs/new-mobile-template): source and destination amounts have different meanings. Verify adapter-specific currency/amount semantics for each supplier separately.
- [PostgreSQL row locking](https://www.postgresql.org/docs/17/explicit-locking.html): use short transactions and consistent lock ordering for financial state, with no external network request inside a database lock.

The detailed implementation above is a recommendation derived from the inspected KeepSIMs code and database. Before implementing provider-specific behavior, verify current official provider documentation and sandbox results. Do not copy unverified assumptions about duplicate-request handling, price guarantees, or carrier validity from comments.
