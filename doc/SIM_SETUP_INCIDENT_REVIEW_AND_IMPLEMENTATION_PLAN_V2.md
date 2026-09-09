# KeepSIMs SIM setup: incident review and corrective implementation plan, V2

Prepared 2026-09-08. Status: investigation and implementation specification only. No application code, live money, provider transactions, schedules, or database rows were changed during this review.

This is the current, standalone handoff for the next AI executor. It supersedes `SIM_ONBOARDING_AND_REFILL_BILLING_IMPLEMENTATION_PLAN.md` where that document differs, particularly the Free-line policy. It includes the unfinished requirements from the first plan, the defects in the subsequent implementation, and the owner's new commercial decisions.

## 1. Outcome of the investigation

The test was not evidence of a carrier rejecting the number. Two separate purchase paths ran:

1. The new form reserved money, then created an ordinary Premium line through the old controller. That controller immediately created an active notification schedule and a legacy annual refill queue, including a refill due immediately.
2. The form separately called `execute_zendit_recharge`. The deployed endpoint returned HTTP 410 because that direct-purchase endpoint had been retired. The form interpreted this application integration error as a failed carrier verification and released the setup holds.
3. The independently queued `refill_mini` worker recorded a successful Zendit recharge. This path had no connection to the setup holds and did not debit this wallet.
4. The requested Free fallback used a direct client row update. The database denied the update, but the controller stored the error instead of propagating it. The screen nevertheless displayed “Saved with Free Plan. Manual reminders active.”
5. Reloading fetched the actual database record: still Premium, with a refill date recorded by the successful background execution. The recharge date in this particular test is supported by that execution; it must not simply be erased to make the failed screen look consistent.

This requires replacing the competing orchestration paths, not restoring the retired endpoint or relaxing table permissions.

### Evidence and limits

Inspected the current customer working-tree changes, authoritative local backend worker changes, deployed database table schemas, grants, triggers, function definitions, and the test's setup/hold/line/execution/payment records. Database access was read-only. The screenshots were also reviewed.

The provider purchase is recorded as successful in `topup_executions`, consistent with the owner's Zendit observation. Provider portal receipts and VM process versions were not independently fetched in this review. The repair phase must verify the provider receipt before any financial compensation. Local source is not proof of the deployed worker version.

Test number is masked here as `+20…1020`. Full private data stays in the application database. Correlation references needed by the executor:

- Latest setup: `1df6ff7d-81d3-4d65-9622-b0f8105ea1fd`.
- Previous failed setup for the same number: `fa46236c-0256-4e3f-aa74-886c79ff2e46`.
- Current line: `3ba2e784-bd6d-4a6f-b3ad-23f167e90cea`.
- Successful execution: `e96d3268-5095-4f87-bb1f-9ef541b902be`.
- Refill schedule: `e36523d9-1ebb-4ea4-bde5-435b130423ba`.

| UTC timestamp on 2026-09-08 | Confirmed database event |
|---|---|
| 11:28:57.908918 | Latest Premium setup created; line reference null; annual fee $2.50, initial refill $0.59, total $3.09. |
| 11:29:16.877879 | $2.50 and $0.59 setup holds created. |
| 11:29:17.091655 | Normal Premium line inserted before setup delivery confirmation. |
| 11:29:18.662899 | Five legacy `refill_mini` occurrences created: one due immediately, four in the future. |
| 11:29:19.359826 | Setup failed because of the retired endpoint's HTTP 410; both holds released, neither captured. |
| 11:29:23.500736 | Independent Zendit mini-refill recorded successful; line `last_topup_at` updated. |

At inspection, wallet balance remained **$1,987.05**, with no account plan/refill debit since before the test, no line-bound plan payment, and no line-bound wallet debit. The line still had active notify/refill schedules and four pending future refill occurrences. Setup `sim_line_id` and provider reference were null. Subscriber verification remained unverified/pending, despite the Premium badge.

The live entitlement helper returned true for this line although it was not grandfathered and had no line-bound payment. Its code accepts older account payments with null line references. Such a payment existed. This explains why the old queue's paid-entitlement guard did not stop the unfunded new line.

## 2. Required commercial behavior

| Tier | Enrollment payment | Term | Verification and automation |
|---|---|---|---|
| Free | $0 | Six calendar months, once per normalized phone number across KeepSIMs | Unlimited distinct eligible numbers per account; permitted Free reminders only; no automatic paid verification or refill. |
| Standard | Current configured annual fee, presently $2.50 | One paid annual term | Reminders; optional included call check subject to server limits; no mandatory recharge. |
| Premium | Annual fee + first qualifying refill | Annual subscription starts on confirmed setup settlement | First recharge must finish successfully before activation; later refills charge the wallet individually when due. |

Free is a one-time benefit for the number, not a new six-month benefit per account, installation, country-prefix representation, or deleted/re-added row. Treat six months as calendar months using server timestamps, not 180 days. The term begins at successful Free activation even if the user skips the last-recharge-date step.

After definite Premium setup failure:

- Restore/release all Premium setup funds first.
- If the user chooses manual reminders and the number has never received Free: activate its six-month Free entitlement for $0.
- If the number previously received Free: the manual-reminder fallback is Standard, with a separate $2.50 annual fee deducted once from available wallet funds, as requested by the owner.
- Display the actual fallback tier and fee before the user chooses it. An initial checkout can authorize this contingent fallback, but a generic “Skip” button must not conceal a new charge. If consent was already recorded for this exact fallback, do not ask for repeated approval.
- If Standard funding is insufficient, retain an incomplete draft and offer wallet funding. Do not activate paid reminders, overdraw, or dispatch another recharge.
- A failed Premium attempt alone never automatically creates a paid Standard subscription if the user chooses another number or exits instead of the manual-reminder fallback.

Free expiry does not automatically charge Standard unless the user separately approved that conversion. Keep the line visible as “Free period ended” with an explicit Standard/Premium purchase option. Recharge history remains visible. Recharging manually does not extend a Free subscription term.

## 3. Confirmed defects and required corrections

Priorities are release priorities, not claims that exploits were executed. No cross-user mutation or real purchase was used to test these findings.

| ID | Priority | Finding and evidence | Required correction |
|---|---|---|---|
| D01 | P0 | `PlanPayment.executeVerificationRecharge()` invokes the retired endpoint; live setup failure stores HTTP 410. Local endpoint source still contains old purchasing code. | Keep endpoint retired; replace its caller with the canonical order/execution worker path. Reconcile local/deployed endpoint contracts. |
| D02 | P0 | Form saves Premium before confirmation. Controller `addSimLine()` creates notifications and queues legacy refills immediately. | Draft creation has no paid entitlement or recurring scheduling side effects. A single server finalizer activates after delivery and settlement. |
| D03 | P0 | Setup has no line/execution relationship, while the old queue spends independently. Mini worker has no new-model wallet-hold gate. | Durable foreign-key relationships and an explicit execution funding model; every new supplier purchase requires its own valid held funds or proven legacy prepaid allocation. |
| D04 | P0 | `has_paid_premium_entitlement()` accepts any recent unbound account payment. Test line qualifies despite zero linked payments. | Bind payment to one purchased entitlement; claim any valid legacy unbound payment once, with compatibility checks. Never reuse it across lines. |
| D05 | P0 | Live `capture_sim_setup_holds` and `release_sim_setup_holds` are authenticated-callable security-definer functions with no owner check and no trusted delivery-state validation. | Move financial finalization/release to service-only operations. Expose owner/manager-authorized intent endpoints, not arbitrary capture/release. |
| D06 | P0 | Setup INSERT is available to authenticated callers with only an owner-row policy, allowing client-supplied financial/state fields. | Revoke direct setup writes; server creates/prices orders and controls state, amounts, holds, identity and entitlement. |
| D07 | P0 | Live activation function references nonexistent columns: line `plan`, `last_topup_date`, `last_verified_at`, `liveness_signal`; nonexistent plan-payment/schedule fields. With a null line ID it skips these branches and can still mark the setup active. | Write/test against the actual schema. Require complete line/execution linkage and validated evidence before success; no “active with no line” path. |
| D08 | P1 | Direct `updateSimLine()` sends restricted verification columns. `toClientWritableJson()` also omits plan type, protection tier, expiry, and last refill. | Use separate authorized RPCs for fallback, plan changes and evidence; narrowly scoped metadata editing. Merely granting UPDATE cannot fix omitted fields and would weaken security. |
| D09 | P1 | `AsyncValue.guard` captures mutation failures without rethrowing/returning failure. Fallback uses a `VoidCallback` for an async operation and announces success anyway. | Return typed mutation results; await callbacks; separate list state from command errors. Navigate/show success only after a confirmed server result. |
| D10 | P1 | Screenshot quote $3.04/$0.54 differs from reserved $3.09/$0.59. UI uses local `inapp_pricing` of $0.54; server API pricing uses the selected supplier's cost/margins. Server breakdown helper exists but UI does not use it. | One persisted server quote for itemization, confirmation, holds and receipt. Requote/reapprove changes; no silent local fallback for purchasable amounts. |
| D11 | P1 | Reserve RPC returns `code: insufficient_funds` and `available_balance`; form expects `error: insufficient_balance` and `current_balance`. | Typed shared response contract and insufficient-funds integration test. |
| D12 | P1 | Deposit helper ignores the wallet-credit wait result, treats exceptions as successful continuation, waits against deposit amount rather than total required available balance, and lacks a completed cancellation path. | Durable deposit/order association, typed confirmed/pending/cancelled outcomes, available-balance recheck, resolved navigation and restart recovery. |
| D13 | P1 | Standard commits active line before capture, also with an unlinked setup; activation branch wrongly assumes recharge evidence for all plans. | Standard fee capture, line linking and entitlement activation must be atomic and must not invent a recharge. |
| D14 | P1 | Same-tier editing sets a new client annual expiry although no payment is due; server payload currently prevents some persistence by omission. | Metadata edits never renew entitlement or reset dates. All term changes server-owned; test after fixing update RPCs. |
| D15 | P1 | All plans receive an active notification schedule based on signup time even with no recharge baseline. | No date-based schedule until actual/user-reported qualifying activity; skip creates no date. |
| D16 | P1 | Existing onboarding and upgrade sheet still use old payment/queue paths; old paid-tier liveness gates remain despite metadata now returning unverified. | Unify add, onboarding, upgrade, renewal, fallback and recovery through one use-case contract. Remove requirement for a prior positive lookup before Premium's initial recharge. |
| D17 | P1 | New custom-refill hold variable is declared inside `try`, so its `catch` cannot release it; success is marked before capture, and capture errors are merely logged. | Durable execution hold ID, correct scope, atomic completion/capture or explicit settlement-pending recovery. |
| D18 | P1 | Custom worker writes `awaiting_funds` plus `updated_at` into executions. Live status constraint excludes that status and live table lacks `updated_at`. Errors are not checked. | Add an intentional compatible schema/state migration or map to a supported financial substate. Worker cannot pretend the update succeeded. |
| D19 | P1 | No inspected billing-model column or setup-execution FK exists in live payment/schedule/execution schema. New worker logic does not distinguish legacy prepaid funding. | Persist billing/funding version and price allocations; preserve legacy obligations without double-debit. |
| D20 | P1 | One-Free-line trigger remains live and UI disables Free if another Free line exists. No inspected number-based six-month grant history exists. | Replace both client restriction and server count trigger with the durable policy in section 7. |
| D21 | P1 | Call endpoints do not consistently require a paid line/attempt budget. Local OTP authentication and limiter handling can continue after missing/invalid authentication or RPC errors. | Enforce ownership, paid eligibility and bounded spend on every paid verification route, including direct API calls. |

Also review the wallet allocation invariant already identified in the earlier wallet plan: allocations must subtract amounts assigned to other active holds before choosing funding lots. Two-component setup reservations must not consume the same lot twice. Do not assume the wallet migration implements all required behavior merely because tables exist.

## 4. Execution boundaries and immediate containment

Authoritative repos:

- Customer/Supabase: `C:/Users/abdal/Work/KeepSIMs/keep_sims`.
- Workers: `C:/Users/abdal/Work/KeepSIMs/backend-sync-wt`.
- Admin: `C:/Users/abdal/Work/KeepSIMs/keep_sims_admin`.

Read `.agents/AGENTS.md` and relevant `.codex` architecture/security/business documents. This policy overrides the old one-Free-line and annual-prepaid-for-new-Premium rules. It does not override security boundaries or existing prepaid commitments. Preserve unrelated edits. Do not implement workers in the customer `servers/` copy.

First executor phase, under the authorization of that session:

1. Disable affected new-model enrollment and unpaid new-model dispatch until D01–D07 are corrected. Preserve legitimate prepaid customers and reconciliation of already-dispatched transactions.
2. Revoke inappropriate public/authenticated financial-finalization access and direct setup writes. Keep the retired direct supplier-purchase route disabled.
3. Inspect and suspend the four unearned future occurrences on the test schedule after confirming none is in flight. Retain receipts and immutable histories. Do not blindly refund future legacy executions that were never individually charged.
4. Audit all new setup orders created during the rollout for null links, failed setups with Premium lines, unbound reused payments, succeeded purchases without settlement, and active drafts. Join on owner/normalized number/time only to produce repair candidates; do not treat that heuristic as authorization to mutate.
5. Verify the successful Zendit receipt. Do not retry the test recharge. The screen already promised funds returned and showed a mismatched amount, so do not quietly collect a retroactive charge. Produce an incident repair preview: provider outcome, wallet impact, intended tier, retained history and schedule changes. Reconcile through an approved adjustment/consented purchase, never by editing a balance field.
6. For this incident, a false “Free saved” toast is not evidence of a consumed Free grant. Preserve the real recharge date if the provider receipt confirms it, even if the user ultimately chooses reminders only.

The executor must report local, staging and deployed versions separately. New migrations are forward corrections; do not edit an already-applied migration and claim the live schema changed. Local/deployed function bodies and old app compatibility are release checks.

## 5. One canonical setup workflow

### Data and ownership

Extend/reuse existing tables rather than duplicate the financial ledger. Proposed concepts and contracts may be named differently to fit the architecture, but all invariants are mandatory:

- Setup order: normalized number identity, owner/payer, line/draft identity, requested tier, lifecycle status, immutable quote/version, consent reference, fallback policy, annual/refill holds, first-execution ID, parent attempt, and failure category.
- Quote: retail annual fee, retail first-refill amount, total/currency, provider/offer/denomination, qualifying validity evidence, quote expiry, cadence, later per-refill cap, applicable fallback tier/fee, and upgrade credit if any. Preserve supplier cost separately; do not send retail price as the supplier denomination.
- Entitlement: exactly one line and funding/Free-grant source, type, start/end, state and billing model. Distinguish service entitlement from subscriber activity and reminder readiness.
- Execution: setup/schedule occurrence, funding kind (`setup_hold`, `wallet_due`, `legacy_prepaid`), exact price, holds/allocation, provider ID, dispatch identity, delivery status and financial settlement status.
- Event log: request/quote/consent/dispatch/delivery/settlement/fallback/reversal references with timestamps; redact raw phone/credentials in operational logs.

Create an inactive server-side draft or separate draft object. Do not reuse `plan_type=premium` plus `status=active` as a draft. Every relationship needed for settlement must be durably linked before supplier dispatch. Protect order and entitlement history from cascade deletion of a SIM row; use archival or nullable historical links as appropriate.

### Server operations

Use typed responses, with one contract shared by UI/repository/tests. Illustrative operations:

| Operation | Allowed caller and effect |
|---|---|
| Quote setup / check eligibility | Authenticated owner or authorized manager; read-only pricing/eligibility, no purchase or Free claim consumption. |
| Start/resume setup | Validated owner/payer/consent; creates or adopts the same draft, reserves components atomically and queues at most one first execution. |
| Read setup status | Owner/authorized reader; reports server state, money state and allowed next actions. |
| Cancel before dispatch | Owner-authorized intent; service verifies no dispatch ambiguity, releases once. |
| Finalize provider outcome | Service only; checks trusted provider evidence and exact order/line/execution/hold relationships. |
| Choose manual fallback | Owner/payer intent; rechecks Free eligibility, price and consent; atomically activates Free or paid Standard. |
| Update metadata | Narrow permitted fields only; cannot change number identity, plan, expiry, wallet or verification. |
| Record manual recharge date | Authorized intent; validates date/provenance and updates permitted reminder baseline without fabricating provider confirmation. |

Unique keys/locks prevent duplicate active setup for the same owner/number and prevent two users simultaneously claiming the same global Free benefit. Idempotency keys are checked against owner, normalized number, requested tier, quote and payer; a different payload cannot adopt an earlier financial action.

### State transitions

```text
draft -> quoted -> authorized -> awaiting_funds/reserved
Premium reserved -> queued -> provider_pending -> delivered_settlement_pending -> active
Standard reserved -> fee_settlement -> active
Free eligible -> atomic_grant_activation -> active
confirmed no-delivery -> failure_settlement -> failed_funds_restored
failed_funds_restored -> user_chosen_free_or_standard_fallback -> fallback_active
ambiguous dispatch/delivery -> reconciliation_required (no release or fallback)
delivered -> later verified reversal -> compensating reconciliation
```

Do not constrain implementation to a single overloaded status enum. Delivery and money status may be orthogonal if that makes recovery explicit. Update constraints, worker claim filters, client parsing, realtime subscriptions and recovery jobs together.

Premium success transaction captures fee/refill holds, records exact entitlement/payment, records qualifying recharge time, marks active and creates one next occurrence at the carrier interval. Standard success captures only its fee, creates the annual entitlement, and leaves the recharge baseline empty unless an existing valid baseline is available. An accepted provider HTTP request is not delivery confirmation.

If provider delivery succeeds but database settlement fails, retry settlement using the same execution. Do not classify as carrier failure, resend the recharge, release held money, or offer fallback. If the original recharge is reversed later, compensate its ledger entries once, repair evidence and suspend affected automation; do not erase unrelated delivered recharges or silently charge Standard.

## 6. User confirmation, funding, errors and navigation

- Render the exact server quote before the activation button and biometric/typed confirmation. In this test $3.04 versus $3.09 is a failed acceptance criterion regardless of which price policy ultimately wins.
- Retain biometric/device confirmation. When genuinely unavailable, use the last four digits of the canonical destination number as requested. Those digits acknowledge intent; they do not prove number possession or replace server session/ownership checks.
- Cancellation or biometric lockout is not approval. An authentication grace period must not skip explicit confirmation of a changed number, increased amount, different payer or fallback purchase. Bind consent to the quote and fallback terms.
- A conditional Standard fallback authorization may be presented at Premium checkout: “If the initial recharge fails and I choose manual reminders, use Free if eligible; otherwise start Standard for $2.50/year.” Persist the exact agreed terms. Do not trigger Standard simply because the app receives an error.
- Available balance is ledger balance minus active holds. Use existing funds first. Preserve configurable $5 minimum deposit; excess remains available wallet credit and is not added to the plan charge.
- Deposit cancellation/back navigation resolves the waiting future; pending deposit stays pending. A deposit-success screen or payment-provider approval does not establish settled wallet credit. Match the deposit to this pending purchase and resume from the server after background/restart.
- Return mutation `Result<CanonicalSetupSnapshot>` or throw intentionally; do not use list-provider state as the only command result. Retain last loaded list on mutation failure and show the action error locally. All async sheet callbacks are awaited futures.
- Home, Protected SIMs, detail, wallet and schedules refresh from the same canonical response/realtime state. Never require navigating between tabs to clear a swallowed exception. No paid activation or “reminders active” toast before the required state is established.
- Use separate messages for application incompatibility, unavailable service, insufficient funds, provider-pending, recipient ineligibility and confirmed carrier failure. HTTP 410 is a setup service error; it does not imply deactivation.

Required failed-Premium manual-reminder actions:

| Eligibility/result | Button and settlement |
|---|---|
| Never used Free | “Use Free reminders for 6 months”; $0. Show missing-date setup if applicable. |
| Previously used Free | “Use Standard reminders — $2.50/year”; separate fee capture once, after Premium funds restored. |
| Standard balance short | “Add funds to start Standard”; no active paid entitlement yet. |
| Pending provider outcome | No fallback/retry purchase action; show processing/support state. |
| Infrastructure failure before dispatch | Restore safe-to-release funds; explain service failure. Manual fallback remains an explicit choice. |

The user can also choose another number or open Wallet to request a refund of eligible unused paid funds to their original payment source. Preserve funding-lot eligibility; returning a hold is not a new deposit or extra refund credit.

## 7. Unlimited Free lines, once per number, six months

### Durable eligibility registry

Create a server-controlled registry outside deletable SIM rows. A grant stores canonical phone identity (or a keyed HMAC representation), first grant ID, original start/end, provenance and status. It may link to a user/line for support, but account/line deletion must not delete the fact that the benefit was used. A bare hash is insufficient protection for low-entropy phone numbers; use a server-held key and a rotation/migration strategy that preserves matching and uniqueness.

Keep minimal benefit-redemption history and appropriate user-facing retention disclosure. Do not expose other users' number history: eligibility responses provide only whether this user's requested Free enrollment is eligible and its permitted actions, not who used it or their dates/details.

Rules:

1. Normalize to canonical E.164 consistently at every entry point, including imports, offline sync, admin actions, upgrades and fallback. International/national representations of the same number share one identity.
2. There is no subscription count limit on distinct eligible Free numbers per account. Rate/spend/anti-abuse controls may limit rapid requests without reinstating a one-Free-line product rule.
3. Consume eligibility only in the same transaction as successful Free entitlement/line activation. Viewing a quote, abandoned signup, Premium failure alone, invalid input or a rolled-back save does not consume it.
4. A successful grant has `starts_at = server activation time` and `ends_at = starts_at + interval '6 months'` under a documented UTC calendar convention. Test month-end/leap-year arithmetic. Localized display must not shift stored timestamps by the device's UTC offset.
5. Deleting/reinstalling/re-registering, moving between accounts/households, changing carrier, removing/re-adding the number or upgrading then downgrading cannot issue a second grant or reset its end date.
6. Retrying/resuming the SAME activation operation is idempotent, not a second grant. Reopening an existing line preserves its remaining term; a newly added row cannot claim a fresh Free period for an already-used number. An audited restoration of the same entitlement must preserve its original identity and end date.
7. Number edits are not ordinary metadata edits. Changing the normalized number requires the new number's eligibility/setup workflow; do not transfer a Free grant from A to B or reset A's history.
8. A manually entered last refill date and a successful paid manual recharge never renew or restart the six-month Free entitlement.
9. On expiry, gate every benefit check server-side even if the expiry job is delayed. Mark the Free subscription expired, stop its notification scheduling, and keep history/upgrade access. Do not call the carrier line deactivated because the app subscription expired.
10. Send optional permitted push/in-app expiry reminders, suggested at 14 days, 3 days and expiry. No Free SMS/voice/WhatsApp spend is introduced. No automatic $2.50 debit on expiry absent separate user authorization.

### Anti-abuse and reassignment

Free enrollment has no paid OTP requirement. Therefore it cannot cryptographically prove control of a entered number. Enforce authenticated requests, rate limits, duplicate prevention and an audited dispute process so one user cannot silently consume benefits for a large list of other people's numbers. Do not add paid calls to Free to solve this.

Under the requested global once-per-number rule, a legitimately reassigned number may already be ineligible. Explain “This number has already used its Free period” without identifying its earlier account. If support corrects a fraudulent/erroneous claim, require evidence, an admin reason and an audit trail; a normal client can never reset the registry. Define any exceptional correction as a correction of bad history, not a repeat promotion.

### Existing Free history and cutover

- Audit current Free lines, historical plan changes, archived rows and available audit logs. A fallback that failed to save in this incident does not count as prior Free usage.
- Backfill known prior grants using earliest reliable Free-activation evidence; previously upgraded/deleted Free numbers remain used. Do not mark all current Premium numbers as having used Free.
- For existing Free lines with a reliable start, compute original start + six months. If already expired, apply the new policy at the announced cutover and offer Standard; do not silently charge.
- When historical activation time is unknown for an existing Free line, record `legacy_start_unknown` and use a documented one-time cutover start as the migration default. Flag this as a migration concession, not proof of old usage dates. Do not guess a start from last recharge.
- Deleted historical numbers with no surviving record cannot be reliably reconstructed. Document coverage gaps. Enforce once-per-number for all recovered history and all grants after cutover; never claim retroactive certainty that the database cannot support.
- Replace live `check_free_lines_limit`/`enforce_free_line_limit` with the new grant/entitlement enforcement. Remove `_isFreePlanDisabled` account-count logic in add form/onboarding and all “Limited to 1 line” copy, settings, tests and admin validations.
- Refresh effective-tier resolution in all clients/workers so legacy `protection_tier` cannot revive expired Free or failed Premium. Preserve valid paid entitlements during migration.

## 8. Complete flow matrix

| Entry/case | Required result |
|---|---|
| New Free, unused number | Atomic six-month grant and line; no paid provider request; no date-based alerts without baseline. |
| New Free, used number | Explain ineligibility and show priced Standard option. No silent debit on choosing a label that said Free. |
| New Standard, sufficient funds | Exact fee captured once with line/annual entitlement; optional user-triggered bounded call; date setup independent. |
| New Standard, insufficient funds | Durable await-funding; no active paid line, no paid verification until fee paid. |
| New Premium success | One first execution, exact fee/refill capture, one paid line and one next occurrence. |
| Premium confirmed failure + eligible manual fallback | Full release, then $0 Free activation and six-month start; no refill schedule. |
| Premium confirmed failure + used-number manual fallback | Full release, then separately authorized Standard $2.50 capture; one annual term, no refill schedule. |
| Premium failure + another number/exit | Safe release; failed/draft history retained; no Free claim/Standard fee/paid schedule. |
| Premium pending/timeout | Pending/reconciliation screen; funds remain protected; no fallback or duplicate purchase. |
| Provider success, settlement/save failure | Resume settlement/activation, not recharge or refund. |
| Existing Standard -> Premium | Preserve old entitlement while setup pending. Quote fee credit/remaining term explicitly so the same annual service is not charged twice. Failure restores old paid Standard without an extra $2.50 fallback fee. |
| Existing Free -> paid | Preserve grant history/end date; paid setup follows canonical path. A failed upgrade must not mint a new Free term. |
| Existing paid -> same tier edit | Metadata only; no renewal charge, new recharge, expiry reset or verification reset. |
| Expired paid -> renewal | Explicit renewal purchase; not an ordinary edit. Existing line renewal does not automatically replay first-time onboarding recharge. |
| Failed orphan Premium from this incident | Repair/reconcile actual delivery and intended entitlement before allowing new setup. Do not treat its displayed Premium badge as valid paid status. |
| Re-add, double-tap, two devices, lost response | Same server operation/entitlement result; no duplicate grant, fee or first recharge. |
| Offline | Save local draft only; eligibility, paid activation and Free grant consumption wait for server confirmation. Sync never bypasses new endpoints. |
| Family manager | Explicit owner/actor/payer authorization and caps; viewing rights alone cannot spend or consume/transfer another account's grant. |
| Delete while provider pending | Archive/cancel intent; preserve pending execution and money reconciliation; do not cascade away evidence. |

For Standard/Premium upgrades, old paid entitlement restoration takes precedence over treating an already-paid customer as a new Standard purchase. The requested $2.50 fallback applies to NEW manual-reminder entitlement when Free is unavailable, not charging a second fee for an existing active Standard term.

## 9. Later refill collection and worker corrections

Retain the agreed model: charge the wallet at each due refill; annual fee is separate. Suggest funding reminders 7 days and 1 day before due, configurable, aggregated across the wallet's near-term obligations. No automatic card/PayPal funding is introduced.

At due time: claim occurrence; validate active entitlement/automation and approved spending cap; obtain a fresh qualifying retail quote; reserve this occurrence's funds; persist dispatch identity; invoke provider; settle the same occurrence from trusted completion evidence. Insufficient funds cause no provider request. Above-cap prices require fresh consent.

Fix the authoritative mini, custom and instant worker paths together:

- An execution stores its hold ID and funding model durably. A setup execution adopts the setup's refill hold, not a second reservation. Legacy prepaid executions consume their recorded paid allocation, not wallet funds again.
- Fix custom-worker `holdId` scope and ignored RPC errors. Do not mark generic success before money settlement; use delivery-confirmed/settlement-pending state if needed.
- Add or correctly map awaiting-funds state and timestamps; update all database constraints, claim queries, retry/reaper jobs and parsers. Test schema compatibility rather than relying on JavaScript syntax checks.
- Mark dispatched purchases in flight before network submission. Hold expiry never proves no purchase; persist uncertain dispatch and reconcile it. Client-supplied strings cannot establish success/failure.
- Idempotency/reference adoption must prevent duplicate provider purchases after timeout. Never fail over to another provider while the first could still deliver.
- Unrelated exceptions, notification failures and DB errors must not run a blanket refund handler. Financial release depends on verified no-delivery; refunds require an actual prior capture; releases require a still-active reservation.
- When funding arrives, resume at most one safely eligible overdue occurrence. Do not replay a backlog of missed recharges. If late enough that number status/reassignment is uncertain, request review.
- Successful qualifying manual recharge moves the next due time atomically and suppresses an undispatched overlapping occurrence. Manual date entry can update reminders but cannot silently authorize spending or undo an already-submitted refill.
- Annual entitlement expiry blocks new dispatch, not reconciliation. Respect deliberate protection pauses and carrier-specific Home Mode rules. Funding/processing errors remain visible independently of optional notification settings.

## 10. Console and verification behavior

- No recharge baseline: display “No recharge recorded” plus Set last recharge date / Recharge now. Skip dismisses the large prompt but leaves this compact setup reminder.
- Baseline source is explicit: Added by you versus Confirmed by KeepSIMs. Do not erase genuine delivery evidence when a plan fallback occurs; subscription and recharge history are distinct.
- Show Free expiry and remaining term; Standard/Premium annual expiry; next refill date/cost/funding state only where supported by an active schedule.
- Replace hardcoded successful-health scoring with explicit setup/readiness information. A plan badge, paused state, skipped check or manually entered date does not prove subscriber activity.
- Carrier lookup identifies carrier only; keep paid-tier selection possible when metadata is inconclusive. Real invalid format/unsupported qualifying product can block the appropriate action with the correct explanation.
- Standard call check is explicit after fee payment, route-gated and budget-limited. Ringing or voicemail is not completed verification. Verify a user challenge where available; otherwise label the evidence only as a limited call signal.
- Free must cause zero automatic paid call/SMS/lookup requests across refresh, selection, onboarding, fallback, deep links and direct API calls. Enforce this server-side, not just by hiding a button.
- Do not move provider credentials into client-readable configuration to fix missing secrets. Use server secret storage and authenticated, authorized callbacks. Audit touched routes for fail-open authentication/limiter behavior.
- Use the user's permitted notification channels. Unlimited Free lines do not grant unlimited paid-channel delivery; Free retains push/in-app channels under the existing benefit policy.

## 11. Security, accounting and migration invariants

1. No client can set paid tier, expiry, provider verification, financial status or amount through generic inserts/updates. Preserve safe metadata edits via narrow APIs.
2. Trusted settlement validates order ownership, payer authorization, line identity, exact quote, supplier reference and valid predecessor state. Revoke default PUBLIC execute grants explicitly.
3. Capture/release/fallback and grant creation are transactionally idempotent with consistent wallet/lot/hold/entitlement lock ordering.
4. Available funds cannot be simultaneously spent, gifted, refunded or allocated to two holds. Use fixed-precision accounting; distinguish retail price, wholesale cost, destination credit and display FX.
5. All plan terms and canonical timestamps are server-generated. Test the observed four-hour local/UTC serialization risk; metadata edits must not extend a paid term.
6. Initial setup failure restores both components; later scheduled failure restores only its occurrence. Never refund an uncharged amount into new spendable money.
7. New versus legacy billing model must be explicit and evidence-backed. Do not silently reinterpret already-paid annual refill coverage after changing `plan_price_net`.
8. Old unbound payments may be adopted only once and only after verifying purchased tier/amount/term, original owner and compatibility. After adoption, they cannot satisfy another line's entitlement. Historical exemptions require explicit audit evidence.
9. Preserve transaction, Free-use, refund and entitlement records across line/account deletion to the minimum extent required for the policy/reconciliation, with privacy-aware storage and disclosure. Do not retain unnecessary profile data in the global registry.
10. Read current Supabase documentation before implementing changed APIs, follow repository migrations, and run relevant grant/RLS/advisor checks. Source-only migration success is not proof that all PL/pgSQL branches execute against real columns.

## 12. Implementation phases and deliverables

### Phase A — Containment and evidence

Produce a non-mutating incident inventory/repair preview. Verify deployed endpoint and worker versions. Close unsafe callable finalizers and dispatch bypasses under the executing session's authorization. Preserve and reconcile the successful test recharge. Record affected orphan schedules and unbound-payment reuse.

### Phase B — Schema and canonical contracts

Implement forward migrations for order/execution/entitlement linkage, funding versions, quote/consent references, compatible processing/settlement states, typed RPC responses and Free registry/terms. Test all actual columns. Add restricted service finalizers and owner intent APIs. Ensure authoritative old payment behavior remains available for legacy unsettled purchases.

### Phase C — Fulfillment and money

Move first refill to the existing worker execution infrastructure, fix mini/custom/instant settlement consistently, remove duplicate client scheduling, implement reconciliation/outbox behavior and later due-time charging. Add safe one-time payment adoption and grant allocation. Finish insufficient-funds/deposit resume behavior.

### Phase D — All client entry points

Integrate add-line form, initial onboarding, line-upgrade sheet, renewal, manual fallback, metadata edit, offline-sync resume and household paths with the same controller/repository contract. Render server quotes and awaited typed results. Update Home/list/detail/wallet state and Free expiry copy; remove account-count restrictions everywhere.

### Phase E — Admin and policy cutover

Add order/hold/execution/entitlement correlation, unresolved settlement queue, incident repair preview and audited actions, Free eligibility/history support, and configurable trial/verification/funding reminders. Backfill Free and legacy prepaid records with evidence labels. Update copied admin models, docs and business rules. Do not grant admins unrestricted arbitrary balance/Free-history edits.

### Phase F — Verification and release

Run the acceptance suite below, check deployed schema/function/worker/client contract versions, stage provider-specific end-to-end tests, and write exact migration/deployment/rollback steps. A rollback disables new enrollment/dispatch but leaves recovery operational. Follow `.agents/AGENTS.md` for the authoritative worker deployment when authorized; do not rely on a VM Git pull.

Deliver the code across all affected repos, forward migrations, incident repair proposal and execution record if authorized, test results, UI evidence, compatibility report, limitations, and deployment status. Do not declare completion based on pricing tests or a successful app build alone.

## 13. Acceptance tests and expected balances

Use deterministic mocks/sandbox data first, with production-like schema/grants. Do not run real purchases or retroactive wallet adjustments without explicit authorization in the executor's session.

Balance examples assume starting available/ledger funds $1,987.05 and an approved server quote of $3.09 ($2.50 + $0.59), with no other operations:

| Scenario | Final ledger balance | Required state |
|---|---:|---|
| Premium fully successful | $1,983.96 | Both components captured once; one Premium entitlement; one confirmed first recharge; next occurrence in future. |
| Initial provider definitely fails | $1,987.05 | Both holds released; no paid entitlement or active refill queue. |
| Failed Premium -> unused-number Free | $1,987.05 | One six-month grant; reminder readiness depends on baseline. |
| Failed Premium -> previously-Free Standard | $1,984.55 | Premium holds released, one separate $2.50 Standard fee, annual Standard, no refill queue. |
| Direct new Standard | $1,984.55 | One annual fee, no fabricated recharge. |
| Premium pending | Ledger $1,987.05; available $1,983.96 | Funds held, no false failure or active Premium. |
| Later $0.59 refill after successful Premium | $1,983.37 | Refill-only capture; annual fee not charged again. |

If the business elects the $3.04 retail quote instead, derive every expected amount from that same persisted quote. The UI may not display $3.04 and then silently reserve $3.09.

Required test cases:

1. Reproduce this exact retired-endpoint + prematurely queued refill incident as a regression fixture; the corrected flow has one supplier path and no provider request before linked reservation.
2. Confirm full setup success/failure/Free fallback/Standard fallback balances above, including original funding provenance and no double credit.
3. Assert no Premium line activation, paid entitlement, immediate legacy queue or welcome-protection claim on draft save.
4. A new line cannot use another line's fee, an unbound old fee already claimed once, a client expiry, a forged provider ID, or an arbitrary setup row to obtain Premium.
5. Authenticated/anonymous users cannot call service capture/release, write financial setup fields, change plan/expiry/verification through generic row updates, or affect another owner's order.
6. Execute every Standard and Premium finalization SQL branch against the exact production schema; catch nonexistent columns and invalid enums. Repeat after a simulated failure halfway through to prove rollback.
7. Provider pending after local TTL; lost response; worker crash before/after dispatch; duplicate/out-of-order callbacks; delivery success with DB failure; later reversal. No duplicate provider request or improper release.
8. Two simultaneous activations of one number and concurrent wallet operations cannot duplicate grants, fees, purchases or lot allocation. Order retries return original outcomes; conflicting key payloads fail.
9. Reserve insufficient-funds response matches client parsing. Deposit approved-but-uncredited, cancelled, browser back, timeout, excess deposit, concurrent spending and app restart all recover correctly.
10. Mutation failure retains list data and shows the action error; never displays “Free saved.” Fallback callbacks are awaited; all pages show the same server tier without tab-switch repair.
11. Quote remains identical across card, biometric/typed confirmation, reservation and receipt. Provider/price change invalidates prior approval. Public last-four-digit confirmation is never treated as SIM verification.
12. Unlimited distinct eligible Free numbers succeed; the second Free line is not blocked by old trigger/UI/admin logic. Reusing a number on another account, deleting/re-adding, prefix formatting changes, carrier changes and downgrade cannot start another Free grant.
13. Free starts/ends in server calendar time; month-end/leap-year and Muscat/local UTC offsets tested; skip/manual recharge/app reinstall does not extend it. Expiry works even with delayed cron and offline client.
14. Failed/abandoned Free activation and false historical UI success do not consume eligibility; committed activation does. Historical migration marks uncertain evidence accurately; restored same grant does not reset dates.
15. Previously-Free fallback charges Standard only when that fallback is chosen and authorized. Insufficient funds gives awaiting payment. Existing paid Standard upgraded to Premium restores its original entitlement on failure without a duplicate fee.
16. Same-tier metadata edit cannot renew; expired plan renewal is explicit; phone change runs a new eligibility workflow; concurrent deletion preserves in-flight history.
17. No baseline yields no scheduled expiry alerts or “100 health.” Actual successful recharge history is preserved through fallback. User-reported dates are labeled and future dates rejected.
18. Free/expired Free/unauthenticated requests cause zero paid verification calls, including direct endpoint invocation. Standard attempt caps and failed authentication/limiter handling stop supplier requests.
19. New due mini/custom/instant workers reserve/capture correctly, do not swallow settlement errors, and handle insufficient funds using valid schema. Legacy prepaid executions are not charged twice.
20. Manual versus scheduled recharge, two devices, annual renewal overlap, Home Mode/explicit pause, funding arrival, above-cap price and very late catch-up all avoid duplicate/unauthorized spending.
21. Old app/version contracts fail safely; pending old purchases retain their purchased terms; rollout/rollback preserve reconciliation. Incident repairs are replay-safe and never silently recollect money after a promised refund.

Test evidence must include SQL financial/grant/entitlement tests, worker fulfillment/recovery tests from the authoritative repo, Flutter repository/controller/widget tests, and navigation screenshots or equivalent controlled UI evidence. Add coverage beyond the current modified pricing test. Report pre-existing failures separately and verify the production migration inventory before deployment.

## 14. Source map for the executor

Use absolute workspace roots from section 4. Key relative paths below are navigational references within those repositories; recheck line numbers after edits.

| Customer/Supabase path | Work |
|---|---|
| `lib/features/sim_lines/presentation/screens/sim_line_form_screen.dart` | Server quote, intent confirmation, canonical signup/fallback, typed errors, six-month Free policy. |
| `lib/features/sim_lines/domain/plan_payment.dart` | Remove retired recharge caller and client finalization; shared typed setup/payment operations. |
| `lib/features/sim_lines/domain/refill_pricing.dart` | Display server quote; retain compatible legacy accounting without a competing purchasable price. |
| `lib/features/sim_lines/presentation/controllers/sim_lines_controller.dart` | Remove draft scheduling/activation; separate command outcomes from list state. |
| `lib/features/sim_lines/data/repositories/sim_lines_repository_impl.dart` | Intent RPCs instead of generic financial/plan row updates; safe offline draft sync. |
| `lib/features/sim_lines/data/models/sim_line_model.dart` | Typed entitlement/readiness fields and safe metadata payloads. |
| `lib/features/profile/presentation/ui/onboarding_screen.dart` | Same setup contract, new Free policy, remove obsolete paid liveness prerequisites. |
| `lib/features/sim_lines/presentation/widgets/line_upgrade_sheet.dart` | Same upgrade/renewal contract, fee-credit/prior-entitlement preservation. |
| `lib/features/sim_lines/presentation/screens/sim_line_detail_screen.dart` and health domain | Truthful evidence/readiness, subscription expiry, due funding status. |
| `lib/core/services/biometric_auth_service.dart` | Quote-bound confirmation and correct unavailable/cancelled/lockout semantics. |
| Wallet/payment/scheduled-topup/notification/offline-sync features | Shared funds/readiness/expiry/response contracts and recovery. |
| `supabase/migrations/20260908120000_sim_setup_orders_and_pay_per_refill.sql` | Treat as deployed historical defect; fix through forward migrations. |
| `supabase/functions/execute_zendit_recharge/index.ts` | Keep disabled; synchronize tombstone source with deployed behavior. |
| Liveness/OTP/callback Edge Functions | Tier/ownership/budget checks, real evidence, authenticated callbacks. |
| SQL pricing/queue/entitlement/free-limit/wallet RPCs and tests | Canonical financial workflow, exact schema, new eligibility and negative authorization tests. |

Authoritative backend paths: `worker_auto_mini_refill.js`, `worker_auto_custom_refill.js`, `worker_instant_refill.js`, `sim_liveness_service.js`, existing `providers/`, and their claim/recovery/notification jobs and tests. Admin counterparts require the same field/enum/billing changes plus audited incident and Free-history operations.

Implementation completion means every supported entry point reaches the same durable outcome for line tier, paid/Free entitlement, wallet, provider delivery, recharge history and schedules. A success toast is evidence only of what the UI displayed.
