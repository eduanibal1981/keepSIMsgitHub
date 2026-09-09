# Business Rules

These are implementation invariants derived from current domain code and migrations. Configuration-backed numbers can change without an app release; fetch authoritative values rather than duplicating literals.

## Authority hierarchy

1. Database/RPC constraints decide what is allowed and charged.
2. Trusted workers/Edge Functions choose provider action and execute external side effects.
3. Flutter mirrors rules for explanation/quoting but is never authoritative.
4. If a client quote differs from the server charge, the server wins and the mirror is a bug.

## SIM lines and plans

- A user may have only one `plan_type='free'` line. Paid additional lines are not capped by the old account-tier UI rule.
- Per-line `sim_lines.plan_type` is the authoritative paid entitlement.
- `protection_tier` is a legacy compatibility fallback that can widen entitlement; it must not override a valid `plan_type` downward.
- `profiles.subscription_tier` is not the source of a particular line's premium entitlement.
- A premium automation queue requires a paid, unexpired per-line entitlement (or explicit historical grandfathering).
- Standard and Premium are annual plan-fee concepts. Premium includes prepaid automated refills; Standard does not mean “up to five lines.”
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

- Refill total mirrors the database fee trigger: supplier/base cost + rounded gateway fee + rounded app fee.
- The app fee percentage comes from `APP_FEE_PERCENT`; the minimum app-fee floor is configuration-backed/current code defaults to USD 0.03.
- Premium per-refill net price is conceptually:

```text
qualifying supplier cost * (1 + app fee % + premium margin %) + flat premium margin
```

- An explicit positive per-carrier in-app price override wins where still supported.
- A Premium year is one charge: base annual service fee + all calculated yearly refills, then the payment gateway is grossed up once.
- Wallet payment has no external gateway fee. PayPal fallback must gross up so the intended net survives percentage plus fixed fees.
- Server `plan_price_net`, `quote_plan_price`, `pay_plan_fee_from_wallet`, and Dart `RefillPricing`/`PlanPayment` mirror one contract and must change together.
- A paid fee may be temporarily pending while its SIM line is being created; its stable reference prevents billing a second year on retry. Local pending-fee state expires after 24 hours but server ledger/payment state remains authoritative.

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

- Rates are selected by longest matching active phone prefix; client display is advisory until call creation validates again.
- Caller IDs must be system-provided or user-verified through the backend.
- Provider call/session IDs are the idempotency/reconciliation anchors for CDR handling.
- Webhooks must be signature verified and replay-safe.
- The current implementation's minimum-balance preflight is not a reservation. Do not treat it as assurance that the full call can be collected.

## Notifications, privacy, and lifecycle

- Notification preference/channel state is user-scoped; delivery attempts and system alerts are server-authored.
- Account deletion is a delayed/request/purge workflow, not a client cascade. Export/cancel/purge APIs enforce caller ownership or admin role.
- Activity, financial, payment, provider, and admin audit records must not be casually deleted as “unused data.” Retention should be explicit and legally/operationally approved.
- Client and operational logs must redact phone numbers, ICCIDs, wallet/payment values where sensitive, tokens, secrets, and raw provider payloads.
