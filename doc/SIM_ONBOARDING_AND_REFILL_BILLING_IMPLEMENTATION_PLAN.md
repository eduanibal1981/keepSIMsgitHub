# KeepSIMs: SIM onboarding and payment per scheduled refill

> Superseded for implementation by [SIM setup incident review and implementation plan V2](SIM_SETUP_INCIDENT_REVIEW_AND_IMPLEMENTATION_PLAN_V2.md), prepared after the 2026-09-08 test. V2 includes verified live defects and replaces the one-Free-line rule with unlimited eligible Free numbers, six calendar months once per number, and the disclosed paid Standard fallback. This original plan is retained as historical context.

Prepared 2026-09-08. Status: implementation handoff; not implemented or deployed.

## 1. Objective and authority

Implement truthful SIM-status messaging and tier-specific onboarding. New Premium purchases collect the annual subscription fee plus one initial recharge, then fund later recharges from the wallet individually when due. Standard uses an optional, limited call check. Free never automatically invokes paid verification. Date-based reminders require a recorded qualifying recharge date.

This specification incorporates the owner's revised failure screen: return the complete initial purchase amount to the wallet, offer another number or manual recharge with reminders, and explain that eligible wallet funds can be refunded to their payment source.

This is a deliberate change to the commercial model for NEW Premium purchases. It supersedes the annual prepaid-refill pricing rule in older `.codex` business rules and `doc/WALLET_PAYMENTS_IMPLEMENTATION_PLAN.md` for those purchases only. Preserve their wallet-only funding, refund provenance, security, and legacy prepaid protections. Do not infer that existing prepaid customers agreed to pay for included refills again.

The task for the executor is to implement and test the full scoped change across the affected repositories. This planning request does not authorize deployment or real-money tests. Apply the authorization and deployment rules of the executing session. Preserve unrelated working-tree changes.

## 2. Product decisions

| Item | Required behavior |
|---|---|
| Subscription | Standard and Premium retain the existing annual, per-line billing period. Base fee is configuration-backed, currently discussed as USD 2.50/year. |
| Premium initial purchase | Annual fee + one qualifying direct recharge at the displayed retail price. |
| Later Premium refills | Reserve only that refill's price from available wallet funds when it is due; settle after provider confirmation. No additional annual subscription fee on each refill. |
| External payment | Card/PayPal funds the wallet. No automatic external charge or automatic wallet funding in this release. |
| Minimum deposit | Preserve the configurable USD 5 wallet minimum from the wallet plan. Clearly show any excess as retained available wallet credit; it is not a plan charge. |
| Free verification | No paid lookups, SMS, or calls caused by opening, typing, refreshing, saving, or retrying a Free line. |
| Standard check | User-triggered, included in the subscription within configured limits, and available only on tested routes. No surprise per-attempt wallet debit. |
| Skip | Save setup progress without asserting activity or inventing a recharge date. |
| Manual date | Starts reminder calculations as user-reported evidence, not provider-confirmed subscriber activity. |
| Failure fallback | After full Premium setup refund, offer Free manual reminders subject to the existing Free-line limit. Paid Standard is a separately disclosed purchase. |
| Existing prepaid Premium | Continue honoring remaining included refills without a second wallet charge. |

Default low-balance reminders: 7 days and 1 day before a due refill, plus a due-time failure notification. Make timing configurable and deduplicate messages. These are funding reminders, not advance holds. Available wallet credit remains spendable until execution.

Example only: if the annual fee is $2.50 and a qualifying refill costs $3.50, the initial purchase is $6.00. At each subsequent due date, reserve $3.50 if the price is unchanged. A $10 deposit leaves $4 available after successful setup. Later recharge failures release only that occurrence's reservation, not the already-earned annual subscription fee. Initial setup failure returns the full $6 purchase reservation; the other $4 was never spent.

## 3. Repository discovery and implementation surfaces

Read `.agents/AGENTS.md` and relevant `.codex` architecture, business, security, and status documents before editing. Recheck current source, deployed contracts when accessible, and working-tree changes; file presence is not deployment evidence.

| Repository | Scope |
|---|---|
| `C:/Users/abdal/Work/KeepSIMs/keep_sims` | Flutter customer app; Supabase schema, functions, SQL tests; documentation. |
| `C:/Users/abdal/Work/KeepSIMs/backend-sync-wt` | Authoritative Node workers, provider adapters, scheduling/recovery and worker tests. |
| `C:/Users/abdal/Work/KeepSIMs/keep_sims_admin` | Matching models, plan and route settings, order/refund inspection and support actions. |

Do not implement worker changes in the historical customer-repo `servers/` copy. Deployment, if authorized later, follows the direct synchronization instructions in `.agents/AGENTS.md`.

Confirmed in inspected customer source (validate latest definitions before editing):

- `lib/features/sim_lines/domain/plan_payment.dart` and `refill_pricing.dart` currently calculate Premium using a year of prepaid refills. Update their contracts alongside server quotes; changing labels alone is insufficient.
- Inspect latest definitions of `plan_price_net`, `quote_plan_price`, `pay_plan_fee_from_wallet`, `has_paid_premium_entitlement`, and `queue_premium_refill_executions`. Earlier definitions occur in the J8 pricing and I2 entitlement migrations. Search ALL subsequent migrations and runtime definitions for overrides.
- `supabase/migrations/20260907100000_wallet_holds_lots_and_refunds.sql` defines funding lots, reservations, capture/release and refund operations. Reuse and harden these; do not add a second wallet ledger. Its default two-hour hold expiry requires explicit treatment for pending carrier transactions.
- `supabase/functions/validate-sim-liveness/index.ts` maps carrier identification to activity. The corresponding authoritative worker service must be inspected and corrected consistently.
- Update customer onboarding, `sim_line_form_screen.dart`, `line_upgrade_sheet.dart`, `sim_line_detail_screen.dart`, the detail controller, `carrier_liveness_badge.dart`, `premium_refill_config_sheet.dart`, manual refill UI, wallet flows, and notification scheduling.
- Inspect `send-sim-otp`, `verify-sim-otp`, `twilio-voice-webhook`, relevant Telnyx callbacks, payment deposit callbacks, and `process-wallet-refund` for shared contracts.
- Inspect `lib/features/sim_lines/domain/sim_line_health.dart`: existing pause/non-Premium score shortcuts must not imply confirmed activity.

## 4. Separate the states that the current UI conflates

Add or extend typed server-owned models; names below express required concepts, not mandatory duplicate tables.

1. Purchase/setup: draft, awaiting funding, processing, activation pending, active, failed, reconciliation required, reversed.
2. Annual entitlement: plan, validity period, fee payment reference, and billing model (`legacy_prepaid` or new payment-per-refill model).
3. Evidence: carrier detected; user completed challenge; provider recharge confirmed; explicit subscriber-status report; unknown. Record source and observation time independently.
4. Reminder baseline: date/time and provenance (`provider_confirmed` or `user_reported`), plus skip/dismissal state.
5. Schedule: next due time, enabled/paused reason, approved per-refill spending cap, billing model, last successful qualifying refill, and outstanding occurrence.
6. Occurrence: stable ID, amount/currency and quote snapshot, funding source, wallet hold(s), provider reference, delivery/settlement state, and failure category.

Carrier metadata never sets subscriber activity to confirmed. Do not describe suspended/barred accounts as permanently deactivated merely by matching error text. Unsupported lookup, invalid format, recipient ineligibility, temporary routing failure, and confirmed subscriber disconnection remain distinct.

Retain evidence history. A manual date, completed recharge, or call challenge does not prove that the number still belongs to its original subscriber. Display only the fact established.

## 5. Premium onboarding and settlement

1. Normalize and validate the number locally/server-side; identify carrier where supported. Do not require successful HLR/BSS or a call to proceed with an explicitly approved initial recharge.
2. Resolve an enabled carrier rule and a direct top-up that qualifies for extending SIM validity. Respect existing supplier routing, minimum qualifying amount, and outgoing-usage-only exclusions. PIN delivery alone is not evidence of a recharge.
3. Obtain a server quote with annual fee, first refill retail charge, total USD charge, displayed destination credit, expiry, cadence, and future per-refill spending cap. Show that future refills are separate wallet charges. Do not trust client prices.
4. Persist a resumable setup order. A draft SIM record may exist for linkage, but it must not be an active Premium line, count as a paid entitlement, or queue recurring refills.
5. If necessary, deposit the shortfall subject to wallet minimums. Resume only after server-confirmed wallet credit, using the same setup ID across app restarts/deep links/devices.
6. Reserve annual fee and first-refill amount atomically. Prefer linked component holds created in one transaction so both succeed or neither succeeds. Store payer and owner explicitly and enforce household spending rules.
7. Commit the provider request identity before dispatch. Execute the first refill once. Process intermediate responses as pending; callbacks and recovery queries converge on the same settlement operation.
8. On verified delivery, atomically capture the component holds, record plan payment and recharge, activate the line and annual entitlement, and create exactly one subsequent schedule. If using an outbox for scheduling, show activation pending until scheduling is durably ensured.
9. Base cadence on the provider-confirmed delivery time where available, otherwise a documented server confirmation timestamp. The first refill is occurrence zero; the next is one interval later. Do not immediately charge another refill because a prebuilt annual queue starts at signup.
10. If provider delivery succeeded but local settlement fails, reconcile settlement/activation. Do not issue another recharge or refund because a database write failed.
11. On definite initial refill failure, release both holds once and show the full purchase amount restored to available wallet funds. Preserve funding-lot origins and refund eligibility. Do not create an extra refund credit for a reservation that was merely released.
12. On unknown outcome, keep processing and reconcile. Do not expire/release a dispatched transaction's hold because its local TTL elapsed. Escalate unresolved cases to support after the provider-specific reconciliation window; elapsed time alone is not proof of failure.
13. On a later provider reversal of the initial recharge, compensate the original setup once, revoke the failed setup entitlement, suspend future dispatch and invalidate that recharge evidence. Reconcile any already-dispatched later occurrences independently; never erase completed delivery records or issue duplicate credits. Obtain fresh user consent before restarting setup.

Before dispatch, cancellation can release holds. After dispatch, leaving the screen or choosing another screen does not cancel the supplier purchase. Disable conflicting manual-fallback/retry actions until the outcome is known.

## 6. Failed Premium setup: copy and navigation

Use the owner's revised meaning, with corrected spelling and precise funding state. Only display returned-money copy after the wallet release/refund actually succeeds.

For recipient-related failure:

> Your number may be inactive or unable to receive this recharge. Premium hasn't started.
>
> The full amount of $[total], including the $[annual_fee] subscription fee, has been returned to your KeepSIMs wallet.
>
> [Use another number] [Skip — recharge manually, just remind me]
>
> You can request a refund of eligible unused funds to your original payment method from Wallet.

For temporary provider failure, replace the first sentence with a service-specific explanation; do not imply deactivation. Offer an explicit retry only after terminal failure and a new approved quote.

“Use another number” preserves available wallet balance and starts a new setup order. “Skip — recharge manually, just remind me” goes to manual reminder setup. Default to Free where the account's Free-line allowance permits. If already used, explain the limit and offer separately priced Standard or leaving the line as an incomplete draft. Never silently re-deduct $2.50 or provide a paid entitlement on the refunded purchase.

The wallet refund link uses the existing refund quote/request flow. Promotional/gift funds do not become withdrawable due to setup failure. External refund completion is a separate status from wallet restoration.

## 7. Later scheduled Premium recharges: when money is collected

### Advance reminders

- Display next due date, current estimated retail price, authorized cap, available wallet balance, and estimated shortfall.
- At the configured reminder times, evaluate available balance after all active holds and other upcoming obligations. For a shared wallet, group reminders and explain the total near-term shortfall rather than assuming each line can independently spend the same dollars.
- Funding reminders never lock money or charge the payment card. After a deposit, recompute all affected schedules.
- Price estimates must not be presented as locked funding. Recheck price and balance at execution.

### At the due time

1. Atomically claim one logical occurrence, validate the current paid entitlement and automation/pause settings, and check for another pending recharge for the same line.
2. Resolve a fresh qualifying offer and retail quote. Never spend above the user-approved per-refill cap. If price exceeds the cap or the qualifying offer changed materially, mark awaiting approval and request approval; do not increase the cap silently.
3. Reserve this occurrence's charge from available wallet funds immediately before provider dispatch. The annual subscription fee is not included again.
4. If balance is insufficient, do not contact the recharge provider. Mark the occurrence awaiting funds; preserve its due date and notify the user that this refill cannot run yet.
5. If delivered, capture once, record the receipt, update the recharge baseline, and schedule the next occurrence from that qualifying recharge. If terminally failed, release once and leave the baseline unchanged.
6. Unknown/timeout means pending reconciliation, not a release, a refund, a new provider attempt, or an advanced due date. Do not switch suppliers while the original may complete.
7. Temporary failure can use a bounded, documented retry policy only after absence of an in-flight purchase is established. Explicit recipient problems suspend automatic retries and ask for action. Retain the future schedule without presenting it as running normally.

### Recovery and annual renewal

- After wallet funding, resume one overdue occurrence automatically only while the original authorization, entitlement, cap, and carrier safety window remain valid. Never execute a burst of missed historical top-ups.
- Define the safety window from current carrier policy/baseline. If it is exceeded or uncertain, ask for user review/confirmation instead of silently sending a very late recharge that could go to a reassigned number.
- App-confirmed manual recharges reschedule/cancel undispatched occurrences transactionally. Serialize manual and scheduled recharge dispatch to prevent duplicate funding. A manual date edit must not cancel a provider transaction already submitted.
- Keep location (`is_home_mode`) distinct from deliberate automation pause and `requires_protection_at_home`. Missing-funds and processing-failure messages must remain visible even if optional reminder notifications are paused. Use only the user's permitted notification channels.
- Annual fee renewal is separate from refill cadence. Start the first Premium year on confirmed initial setup success. Preserve supported renewal consent semantics: charge the annual fee once only with explicit applicable wallet-renewal authorization; otherwise request renewal. No card auto-funding is introduced.
- At entitlement expiry, block new scheduled dispatch until renewed, while reconciling already-submitted transactions. Coordinate renewal and refill reservations if both fall due together so funds are not overspent. Renewal of an already-active line must not create another onboarding refill automatically.

## 8. Standard and Free onboarding

### Standard

- Quote and collect only the annual subscription fee through the shared wallet flow. Offer a last recharge date before payment; if skipped, disclose that date-based reminders await setup. Create the line/payment idempotently so a save retry cannot charge twice.
- Offer “Check by call” after subscription activation, only for supported country/operator routes. No automatic call on typing, tier selection, navigation or refresh.
- Default budget: one user-requested attempt per newly subscribed line, one explicitly requested retry after a configurable cooldown, plus account/device/destination and global spend limits enforced on the server. Limits and route availability must be configurable. Prevent abuse through delete/re-add loops.
- Do not promise free calling. Budget answered-call costs, setup costs, abandoned-call surcharges and provider minimum increments. Reuse a supported verification method; a call initiated, ringing, answered by voicemail, forwarded, or returning a network announcement is not a completed user challenge.
- If the supported challenge succeeds, record access verification with timestamp. If an implementation only observes ringing, label it as a limited call-check signal and never a verified SIM. Failure remains unable to verify.
- After failure/unsupported route, show a recommendation to recharge and the three choices: Recharge now; Set last recharge date; Skip for now. Persist it until an action is taken. Successful call verification still leaves reminder setup incomplete if no date exists.

### Free

- Allow saving subject to the existing one-Free-line allowance; apply no paid verification attempts on any entry point.
- Offer the same date/recharge/skip choices without claiming a check occurred.
- An explicitly approved manual recharge remains a separate paid purchase and does not automatically upgrade the line.
- Enforce allowed notification channels and tier benefits on the server; Free must not inherit paid SMS/call costs through another endpoint.

## 9. Reminder setup and Protection Console

| Condition | Display and behavior |
|---|---|
| No baseline | “No recharge recorded”; “Add your last recharge date or recharge now so we can calculate your reminders.” Buttons: Set last recharge date; Recharge now. No calculated next-alert date. |
| Skip selected | Dismiss the large onboarding prompt; keep the compact missing-date note. Never set the date to today or claim notifications started. |
| Date entered | “Last recharge: [date] · Added by you.” Calculate eligible reminders; reject future dates and handle local calendar dates/time zones consistently. |
| Provider recharge confirmed | “Last recharge: [date] · Confirmed by KeepSIMs.” Update baseline and applicable schedule once. |
| First Premium refill pending | “Setting up — first recharge processing.” No active Premium/keep-alive badge yet. |
| Insufficient funds | “Auto-refill awaiting wallet funds.” Show amount needed and Add funds action. |
| Notifications paused/disabled | Show the actual cause independently from baseline completeness; request OS permission where required. |

Remove automatic “Carrier BSS confirmed,” “Active on [carrier] (Prepaid),” and “100 health” claims based on metadata, plan selection, pause, or a manually entered date. Preserve useful carrier detection with an explicit “Line activity not verified” qualifier. Present any retained score as an estimated protection/readiness measure, never as a measured subscriber health percentage.

Use the customer's recorded date only if the activity qualifies under carrier rules; warn when the entered date implies reminders are already overdue. Schedule one relevant alert rather than replaying every missed reminder. Do not automatically charge a recharge merely because a manual date was entered.

## 10. Financial implementation and security requirements

- Keep all quote, reserve, settlement, entitlement and schedule authorization server-side. Flutter UI mirrors typed results and contains no privileged direct balance writes.
- Use integer minor units or fixed-precision decimals for USD accounting. Preserve destination currency/divisor and FX evidence separately. Do not compound currency conversion/rounding on retries.
- Validate that an idempotency key belongs to the same user, line, purchase type, billing model, amount and quote; reject conflicting reuse. Use stable keys for setup, annual fee, occurrence, supplier request, reversal and refund.
- Maintain a consistent wallet/lot/hold lock order across purchase, gift, refund and settlement operations. Available balance is ledger balance minus active reservations. Pending refunds also reserve funds.
- Verify wallet funding-lot allocation excludes funds already allocated to other active holds; never consume/refund the same lot twice.
- Callback authentication and deduplication are mandatory. Out-of-order events must not move terminal transactions backwards. A verified reversal is an explicit compensating transition.
- Introduce durable recovery for accepted-but-unrecorded requests, missing callbacks, worker crashes, expired leases and local settlement failures. Do not use broad exception handlers that refund all provider/DB errors indiscriminately.
- Preserve initial fee/refill components and original funding provenance on reversals. No synthetic paid deposits for released holds; no refundable conversion of prepaid legacy entitlements.
- Audit/remove hardcoded provider credential fallbacks on touched verification paths, and require explicit live/sandbox configuration. Never log secrets or unredacted subscriber data. Do not reproduce secrets in reports.
- Recheck RLS, RPC grants and owner/household caps for every new operation. Read current Supabase documentation before implementing changed APIs and use the project's migration workflow. Run applicable database advisors and security tests.

## 11. Legacy compatibility and rollout

1. Add the new billing model as an additive version, with a feature flag for new purchases. Never infer paid refill coverage from the word Premium alone.
2. Backfill existing lines/payments/occurrences conservatively from payment evidence. Mark unresolved records for review, not new automatic charges. Pending old checkouts must retain their original purchased terms when they settle.
3. Preserve remaining included legacy refills and their refund accounting. The new worker branches on occurrence funding source; it must not reserve wallet money for a prepaid included refill.
4. At renewal, offer the new model with clear consent; no silent conversion. Existing Standard-to-Premium upgrades need an explicit quote and policy that avoids charging the same annual period twice. Recommended default: credit the unused portion of an already-paid Standard annual fee against the new fee; record this credit separately from cash-funded amounts and restore the old entitlement if setup fails.
5. Deploy compatible schema/settlement contracts before enabling new clients/workers. Old clients must receive their original supported quote or an upgrade-required response, never an old annual label with a new charge underneath.
6. Rollback disables new-model enrollment/dispatch while preserving reconciliation and settlement of already-submitted work. Do not downgrade schemas or reinterpret existing money records.
7. Update customer/admin copy, help text, pricing contracts, `.codex` decisions and the wallet plan to describe both billing models accurately. Mark completion only with test/runtime evidence.

## 12. Execution phases and acceptance tests

Implement in this order: discovery and contract mapping; additive schema/financial state machine; provider reconciliation and due-refill worker; tier onboarding and console; admin controls and recovery; legacy migration tests; release handoff. Reuse existing components and keep the UI/controller/repository/domain boundaries.

Required tests cover actual financial/state invariants, not just mocked UI success:

1. Premium first success captures fee and refill once, starts one entitlement, records one baseline and creates one next occurrence.
2. Definite first failure restores all setup funds, including the fee; no active entitlement or schedule. Existing surplus deposit remains untouched.
3. Provider pending longer than the hold's default TTL neither releases money nor starts a second recharge. Simulate app restart, worker crash and missing callback.
4. Provider succeeds but database settlement initially fails: retry activates without another supplier purchase or refund.
5. Duplicate/reordered callbacks and initial/later reversals result in exactly one appropriate settlement/compensation.
6. Later due refill reserves only its own price; low funds cause no provider call; funding resumes at most one eligible overdue occurrence.
7. Two lines, a gift, and a refund competing for wallet funds cannot overspend or double-allocate lots. Conflicting idempotency-key reuse is rejected.
8. Price above cap pauses for approval; stale/changed offers and nonqualifying top-ups are not purchased silently.
9. Annual renewal is distinct from recharge billing; expired entitlement prevents new dispatch and does not interrupt reconciliation.
10. Legacy prepaid refills are delivered without a second wallet charge; old pending payments retain original terms; failed upgrade restores prior paid access/credit correctly.
11. Standard verification is explicit, route-gated, cost-limited and server-enforced. Ringing, voicemail and failed delivery do not establish verified access.
12. Free causes zero paid verification requests through UI or direct unauthorized API invocation. Re-add/refresh paths cannot evade limits.
13. Skip leaves no date; manual date is marked user-reported; confirmed recharge updates baseline once; missing date never yields “100 health” or a fabricated alert schedule.
14. Failed Premium manual fallback respects the Free limit and never silently charges Standard. A separate Standard purchase is explicit and idempotent.
15. Concurrent manual/scheduled refills, date changes, Home Mode, explicit pauses, notification permissions and time-zone boundaries preserve the intended schedule without duplicate purchases.
16. Refund requests respect source eligibility, holds and completed provider refunds; full setup restoration does not transform promotional funds into withdrawable money.

Run targeted Flutter domain/widget tests, worker fulfillment/recovery tests in the authoritative repo, and SQL accounting/entitlement/grant tests. Existing candidates include `test/features/wallet/`, `test/features/sim_lines/refill_pricing_test.dart`, `sim_liveness_test.dart`, `test/features/scheduled_topups/refill_schedule_math_test.dart`, and Supabase wallet/pricing/tier suites. Report pre-existing failures separately. Regenerate generated models using the project's tooling; run relevant format, analysis and syntax checks.

Use sandbox providers and deterministic fixtures for financial tests. Do not run scripts against real numbers or fund actual provider purchases without explicit session authorization. If live capability cannot be verified, leave that verification route disabled and report the limitation; never simulate success for real users.

Executor deliverables: reviewed code across affected repos; forward migrations and compatibility/backfill report; passing relevant tests with evidence; updated UI copy and documentation; exact deployment/rollback steps and residual runtime checks. This is complete only when onboarding, later collections, refunds, reconciliation, reminders and legacy compatibility work together.

## 13. Provider references to verify during execution

- [DT One transaction lifecycle](https://developers.dtone.com/reference/transactions-1): submitted/confirmed is not completed; callbacks, polling and reversals require reconciliation.
- [DT One status and errors](https://developers.dtone.com/reference/status-and-errors): provider outage, recipient ineligibility and barred accounts have different meanings.
- [Zendit API](https://developers.zendit.io/api/): inspect the documented lookup contract and account eligibility; carrier information is not explicit subscriber-status evidence.
- [Telnyx abandoned-call surcharge](https://support.telnyx.com/en/articles/12805746-surcharge-for-high-abandoned-call-rates): short cancelled calls cannot be assumed free.
- [Twilio call billing](https://www.twilio.com/docs/voice/why-doesnt-my-invoice-match-what-i-pull-from-the-call-logs): connectivity billing and other feature costs are distinct.

These references support provider constraints; reminder timings, spending-cap defaults and the new commercial flow above are product decisions, not provider guarantees.
