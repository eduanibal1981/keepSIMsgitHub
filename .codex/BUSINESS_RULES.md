# Business Rules

## Scheduled pricing and legacy queue — Task 20 (2026-10-18, local/undeployed)

`20261018070000_scheduled_pricing_boundary.sql` makes schedule finances and engine state server-owned. Creation and upgrade use `initialize_line_schedules`, never the retired yearly queue. Paid mini/custom saves require actual paid Premium entitlement and a reviewed finite USD ceiling covering the fresh retail total; the annual plan fee does not prepay future refills. Mini cadence and qualifying offer are server-derived. Native dispatch units and major-currency airtime targets stay distinct, including funded setup finalization. Owner/accepted-manager controls, reminders and offline reminder replay use validated RPCs. One validated waiting occurrence is maintained per schedule; claimed/held/provider evidence is retained. Existing paid schedules are paused for fresh authorization, without invented funding or balance changes. Stable offline free-line IDs allow deferred initialization after reconnect. See [Task 20 evidence](../docs/reviews/scheduled-pricing-boundary-20261018.md). Production remains on the old grants/API until coordinated release.

These are implementation invariants derived from current domain code and migrations. Configuration-backed numbers can change without an app release; fetch authoritative values rather than duplicating literals.

## Authority hierarchy

1. Database/RPC constraints decide what is allowed and charged.
2. Trusted workers/Edge Functions choose provider action and execute external side effects.
3. Flutter mirrors rules for explanation/quoting but is never authoritative.
4. If a client quote differs from the server charge, the server wins and the mirror is a bug.

## SIM lines and plans

- A user may have only one `plan_type='free'` line. Paid additional lines are not capped by the old account-tier UI rule.
- Per-line `sim_lines.plan_type` names the requested tier. Trusted `resolve_line_entitlement` requires settled owner-bound payment or an explicit approved grant and a valid term.
- `protection_tier` is a legacy UI compatibility label; it cannot create backend paid entitlement.
- `profiles.subscription_tier` is not the source of a particular line's premium entitlement.
- A premium automation queue requires a paid, unexpired per-line entitlement (or explicit historical grandfathering).
- Standard and Premium are annual membership concepts. Premium checkout includes the first refill; subsequent automated refills are wallet-funded when due. Standard does not mean “up to five lines.”
- A line whose carrier inactivity clock resets only through outgoing usage—not recharge—must not be sold automated refill protection as if it could preserve the number.
- Protection pause is separate from location: `is_home_mode` describes location; `protection_paused` controls automation. `requires_protection_at_home` can keep a line protected while home.

## Carrier validity and refill cadence

- The qualifying recharge amount is `validity_qualifying_topup_amount` when present, otherwise `minimum_topup_amount`.
- A user/provider request may select an amount above the qualifying amount, never below it. A cheaper denomination that buys credit but no validity is not sufficient.
- Automated cadence is based on the carrier inactivity/termination window, not the purchased bundle's credit-validity period.
- Default cadence leaves a safety margin of 15% of the inactivity window, at least seven days, clamped to 1–365 days. A positive explicit override wins, capped at 365.
- Premium refills per year are `ceil(365 / cadence)`.
- Carrier rules and evidence URLs are operational data, not timeless truth; re-verify when carriers change policies.

## Pricing

- Trusted USD quotes and stored purchase snapshots determine charges. Device arithmetic and display defaults never authorize a purchase.
- Membership amounts come from configured `MEMBERSHIP_FEE_STANDARD_USD` / `MEMBERSHIP_FEE_PREMIUM_USD`; configured `BASE_SERVICE_FEE_USD` is a legacy Standard source. Missing configuration fails closed.
- Effective published `app_fee_rules` determine percentage/minimum fees. Apply the floor before rounding; explicit zero policies stay zero. Invalid currency/basis/policy fails closed.
- A wallet-funded purchase/refill pays no second deposit gateway fee. A supported external quote grosses up its net once using the configured active gateway; a zero net remains zero.
- API Premium pricing uses the authoritative qualifying supplier offer plus its published Premium fee and annual membership. Non-API manual overrides must be explicitly USD. Later refills are charged separately when due.
- Upgrade credit and paid entitlement share `line_paid_plan_evidence`: owner-bound wallet receipts, legitimate external plan receipts or approved grants. Draft labels, expired proof, reversals and duplicated setup mirrors do not create credit. Credit uses the latest valid paid/approved Standard amount, bounded by current membership prices.
- Explicit zero-price memberships create service-maintained promotion grants rather than zero-valued ledger debits. Legacy zero-fee records are not automatically promoted.
- Setup quotes expire before reservation; changed components require review. The initial refill uses its exact funded setup snapshot while the line remains unpaid. Capture/finalization/fallback stay atomic.
- Customer payment uses `pay_quoted_plan_fee_from_wallet` and the reviewed server amount. The unbound wallet plan API is service-only; stable owner/plan/line retries adopt the original payment before repricing.
- RANGE refill quotes price the exact provider-native dispatch value with its stored divisor, not the minimum cost. Fresh provider evidence is still required before spend.
- Task 18 is local/undeployed. Read `docs/reviews/pricing-entitlement-unification-20261018.md` for reference fixtures, migration/client dependencies and mandatory production configuration/runtime verification.

## Wallet and ledger

- Wallet balances are USD-denominated in the current core model; display currency conversion is separate from stored value.
- Every completed mutation records amount, balance before/after, type, reference, and metadata needed for support/reconciliation.
- Reference IDs are idempotency keys. Replaying the same logical action must return/adopt the original result, not charge again.
- Client code does not write balance or financial ledger rows directly.
- Refunds reference the original execution/order/action and are themselves idempotent.
- Account/admin corrections use a distinct `admin_adjustment` type with reason/audit; they are not deposits or refunds.
- Current reconciliation code is incomplete for modern transaction types; consult `DATA_BACKEND_SECURITY.md` before any balance repair.

## Wallet gifts

- Gift transfer is one atomic server function locking sender/recipient wallets in stable order.
- Users cannot gift themselves or gift to missing/unavailable/closing/suspended recipients.
- Only giftable funding can be forwarded: conceptually `min(balance, deposits + gifts_received - gifts_sent)`. Referral, refund, plan, admin, and other credits are not automatically giftable.
- Minimum, maximum, rolling daily cap, and rate limit come from `GIFT_MIN_USD`, `GIFT_MAX_USD`, `GIFT_DAILY_MAX_USD`, and `RATE_LIMIT_GIFT_CREDIT`.
- Historical seeded defaults are $1 minimum, $100 single maximum, $250 daily maximum, and 5 calls/hour; do not hardcode them as current live values.

## Household access and funding

- Roles are `viewer` and `manager`; invitation must be accepted.
- Viewing and spending are separate. A manager does not automatically spend the owner's wallet.
- The owner must set a positive monthly cap to fund a manager; zero means spending off.
- An optional per-transaction/refill cap cannot exceed the monthly cap.
- Both request-time and debit-time checks enforce membership, acceptance, manager role, monthly cap, per-transaction cap, and month-to-date/in-flight spend.
- If household funding conditions do not hold, the actor pays from their own wallet rather than silently using the owner's.
- Owner or accepted manager can act on a line only through server ownership checks; viewer access remains read-only.

## Provider selection and purchase

- Use `carrier_provider_map` for provider-specific country/carrier identifiers. Carrier display names are not provider IDs.
- Only enabled/routable providers and active non-stale offers are eligible.
- Selection order is primary supplier first, direct airtime before PIN voucher, then effective customer price, priority, and deterministic offer code. This behavior was verified in the live function even though the matching local migration version is absent from live migration history—evidence of history drift, not a missing runtime rule.
- Fixed and range offers have different validation; a requested range value must remain inside both supplier value and price bounds.
- Currency units and divisors are provider-specific. Record conversion source/rate/time.
- Content/data bundles are not plain airtime even when cheaper. The current Ding classifier violates this rule and its test fails.
- A purchase timeout is ambiguous. Poll/adopt using the same external ID before retrying.

## Scheduled/instant refills

- A client request creates an execution; a trusted worker claims it. Claims prevent two workers from buying the same execution.
- Offer and price are resolved from server catalogue/routing, not trusted from the client.
- Debit precedes supplier spend under the defined execution state machine; a terminal failed purchase refunds once.
- Terminal histories are retained for audit; client retry creates/requeues an explicit execution rather than relabeling historical success/failure.
- Reaper/health jobs recover stuck work and alert, but do not prove a supplier transaction did not occur.

### Scheduled-refill reservation completion

Task 10 local scheduled-refill contract (2026-10-17; **not deployed**): prepare
the resolved route and reservation atomically, then commit a bound submission
snapshot before supplier purchase. An execution's payer, wallet, USD amount,
owned line and reservation purpose/reference/allocations must agree at submission
and settlement. A populated hold ID or prepaid label is not proof of funding.
Only wallet-due API refills use this contract; another payment rail needs explicit
trusted paid evidence. Canonical fee disagreement stops before purchase.
Confirmed delivery captures once and persists PIN/serial/redemption details;
unknown outcomes stay reserved, even after expiry. Only a locked, proven
pre-submission stop may release funds. The coordinated release must replace the
deployed legacy instant worker before retiring its old status RPCs. See
`docs/reviews/scheduled-refill-holds-worker-contracts-20261017.md`.

## Offline vouchers

- Offline recovery is wallet-funded and server-authorized; the offline client does not bypass accounting.
- Entitlement currently includes Standard and Premium lines (later tier expansion supersedes older Premium-only comments).
- Exposure is structurally capped to one live voucher grant per eligible SIM line.
- PIN/serial/instructions are sensitive and should only be revealed to the entitled user/admin support path.
- Voucher delivery, carrier redemption syntax, expiry, inventory, settlement, and write-off are distinct states.
- Placeholder contact endpoints or generated fallback settings are not evidence that offline recovery works.

## eSIM

- Customer reads retail catalogue/compare data, not wholesale cost.
- Purchase request verifies identity, offer, amount, wallet, and idempotency server-side, then creates a fulfillment order.
- Only a trusted worker uses provider credentials and writes ICCID/LPA/activation data.
- An unfulfilled/stale order is reconciled/refunded once; an ambiguous provider order is polled/adopted before replacement.
- ICCID and activation codes are sensitive and must be redacted from logs/errors.

## Calling

### Second Number SMS pilot (local implementation, 2026-10-17)

New incoming-SMS purchases use server-owned expiring quotes, an atomic
`second_number` wallet reservation, one persisted carrier submission, and exact
order/resource reconciliation before capture. A timeout does not authorize a
second order or a refund. Rental terms are explicitly 30 days; no WhatsApp or
universal OTP acceptance is inferred from SMS support or a mobile range.
Country/retail/usage policies remain disabled until supply validation. Only
validated markets without per-user identity requirements can use this pilot.
Legacy DIDs are excluded from automatic billing unless explicitly enrolled in
managed lifecycle. Inbox writes are server-only and notifications omit content
and codes. See `docs/reviews/second-number-first-release-20261017.md` for the
coordinated wallet-release dependency and remaining launch gates.
Task 17 adds a disabled-by-default acquisition gate with explicit pilot users,
a fresh supplier price check, exact funded capture and retail-only customer
quotes. Renewals require provider ownership/profile verification and one atomic
receipt per original paid-period timestamp. Due or suspended managed numbers do
not receive new messages until payment succeeds. The three-day recovery window
is supplier exposure: local suspension does not stop Telnyx recurring charges.
Confirmed provider release is required, with retained IDs and retry state until
absence is proven. Customer 30-day billing remains distinct from supplier
calendar-month MRCs. Broad paid use requires invoice/usage/lifecycle validation;
see `docs/reviews/virtual-number-financial-safety-20261018.md`.
Clients must tolerate the pre-pilot backend: only the missing-function error
`PGRST202` permits the owner-scoped `get_user_dids()` fallback or an absent
optional pending-order list. Unsupported/empty coverage disables acquisition;
authentication, permission and network failures must not become empty success.

- Rates are selected by longest matching active phone prefix; client display is advisory until call creation validates again.
- Caller IDs must be system-provided or user-verified through the backend.
- Provider call/session IDs are the idempotency/reconciliation anchors for CDR handling.
- Webhooks must be signature verified and replay-safe.
- Task 13 (2026-10-18), **REPAIRED LOCALLY; NOT DEPLOYED**: paid app calls atomically save the server tariff, fee, billing increment, exact funded hold and an affordable provider duration capped at 300 seconds. No extension is supported. Unanswered calls cost zero; a confirmed bridge rounds up to its increment and the total rounds once to cents. Settlement never exceeds its reservation and records only collected money as `total_cost_usd`; observed overruns are retained for reconciliation. Unknown submission/termination keeps its hold; timers cannot release or re-dial it. Destination termination/bridge evidence drives settlement; legacy calls cannot fall back to an unreserved debit. See `docs/reviews/call-budget-billing-20261018.md` for live gaps and release gates.

## Notifications, privacy, and lifecycle

- Notification preference/channel state is user-scoped; delivery attempts and system alerts are server-authored.
- Account setup requires explicit terms/privacy acceptance separately from device permission choices. Device access is optional and may be configured later (2026-10-10).
- Do not request notification access at app startup. Offer an explicit action in onboarding and push settings, display the actual device status, and recheck on resume. Denial must not block setup or automatically open phone settings.
- Request microphone access when making or answering a call, not during account setup. Do not request contacts or phone access without a supported feature that needs it.
- Opening alarm settings must not request access. Request notifications when the user enables device alarms; request exact-alarm settings only after that opt-in. Keep device permissions distinct from server-side alert channel preferences.
- Account deletion is a delayed/request/purge workflow, not a client cascade. Export/cancel/purge APIs enforce caller ownership or admin role.
- Activity, financial, payment, provider, and admin audit records must not be casually deleted as “unused data.” Retention should be explicit and legally/operationally approved.
- Client and operational logs must redact phone numbers, ICCIDs, wallet/payment values where sensitive, tokens, secrets, and raw provider payloads.

## Supplier outcome recovery — Task 11, 2026-10-18

**REPAIRED LOCALLY; NOT DEPLOYED.** Forward migration
`20261017190000_supplier_outcome_recovery.sql` records stable supplier references
and reservation/route bindings atomically with the Tasks 9/10 submission markers.
A new authoritative background worker performs lookups only, with bounded leases,
backoff and operator quarantine. Confirmed delivery captures once and finalizes
setup without an app reopen; confirmed terminal failure releases once. Missing,
conflicting, pending or unknown evidence retains money. Calls/payouts are never
released from expiry alone. Existing executions remain recovery version 0; direct
clients cannot manufacture the trusted version/marker. Do not bulk promote legacy
rows. The reaper quarantines uncertainty in place and new submissions block
unresolved sibling supplier work on the same line under the payer wallet lock.
Reaper/expiry allow the actual postgres cron caller plus service_role; claim and
completion APIs remain service-only. Compatible workers, provider-account proof,
legacy review and coordinated release are required before activation. See
`docs/reviews/supplier-outcome-recovery-20261018.md` for evidence and gates.

## Liveness verification — Task 12 local contract (2026-10-18, undeployed)

- Customer/admin clients cannot confirm provider verification or set its health
  points. Manual activity remains history, not authenticated carrier evidence.
- One owned stored attempt snapshots destination, method, price and its exact
  reservation/allowance. Only authenticated provider delivery or observed ring/
  answer can succeed; no-answer, hangup cause, number format or operator metadata
  alone cannot. Terminal settlement is immutable and charges/consumes once.
- Health remains 25 verification + 25 active notification + 50 recent recharge;
  no check unconditionally sets 100. Legacy logs/attempts are not promoted.
- Unknown dispatch outcomes retain reservations and block another dispatch.
  Reconciliation needs authenticated provider evidence, never a client report.
- See `docs/reviews/liveness-verification-repair-20261018.md` for the pending
  migration, legacy-data reset, scoped tests and coordinated release gates.
