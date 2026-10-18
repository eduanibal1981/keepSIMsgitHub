# Unified pricing, upgrade credit and paid entitlement — Task 18

2026-10-18 (Asia/Muscat). **Implemented and verified locally; undeployed.**
The release remains coordinated with the pending financial repairs. No live price,
wallet, grant, provider purchase or deployment was changed.

## What changed

Forward migration `20261018050000_unified_pricing_entitlement.sql` completes the
pending canonical paid-pricing/eSIM catalogue contracts without changing their
history or restoring the superseded October 4 pricing migration.

`line_paid_plan_evidence` is shared by `resolve_line_entitlement` and
`standard_upgrade_credit_usd`. It recognizes owner-bound completed wallet
`plan_fee_debit` receipts, legitimate external `plan_payments`, approved
`line_plan_grants` and the existing explicit Premium grandfather policy. A wallet
purchase does not need a synthetic external-payment receipt to count. Setup
receipts that mirror a wallet capture cannot independently restore reversed
entitlement. Wallet evidence checks the posted balance change, wallet/currency,
line/setup binding and recorded reversals. External receipts require owner, plan,
positive finite net bounded by gross, a capture identity and no conflicting stored
PayPal order. They remain server-managed historical payment evidence; this is not
a new provider-capture verifier.

Paid evidence is bounded by its actual term and the line's expiry; extending a
line label cannot extend a payment beyond its 365-day receipt term. Drafts,
expired/future proof, foreign owners and legacy protection labels cannot create
paid benefits. Credit uses the latest valid Standard evidence rather than the
largest historical payment, is capped by the actual paid/approved amount and
current Standard/Premium membership prices, and is suppressed if a newer Premium
purchase already used that Standard term. Existing approved Premium grandfather
records remain supported. New Standard grandfather credit must be explicitly
approved with owner, term, amount and reason; nothing is automatically backfilled.

Memberships require configured `MEMBERSHIP_FEE_STANDARD_USD` and
`MEMBERSHIP_FEE_PREMIUM_USD`; the configured legacy `BASE_SERVICE_FEE_USD` remains a
Standard compatibility source. Missing configuration no longer invents $2.50 or
$5.00 prices. Published app fees use their effective date, USD currency and fee
basis. Missing/future/invalid policy fails closed. Explicit published zeros remain
zeros, including external quotes for a zero-price membership. These test values
are not a claim about production configuration.

An explicit zero-price membership records a service-only promotion grant instead
of an invalid zero-valued wallet ledger transaction. The same path covers direct
Standard payment, setup activation and Standard fallback. A grant has an owner,
line, term, source identity, reason and revocation state; ordinary clients cannot
create it. Legacy zero-fee rows are not silently promoted into proof.

## One quote through collection

`pay_quoted_plan_fee_from_wallet` locks the line/wallet and checks the reviewed
server amount before collection. The old unbound debit API is now service-only;
customer repository/controller callers carry the expected quote. A stable retry
adopts its original charge before repricing, and owner-scoped receipt recovery
lets a cached successful payment survive a later configuration change. The
server still validates reference, owner, line and plan identity. Reversed funding
cannot become a paid retry. A separate reserved setup blocks another plan charge.

Setup orders store an internal retail/supplier snapshot and a 15-minute quote
expiry. Reserving money requires a current matching quote; a changed annual fee,
first refill or total requires review. Funded setup states retain their snapshot.
A first Premium refill is priced using that specific funded purchase, even while
the line is still unpaid. The prior trigger used the Free tier in that state;
zero-fee test fixtures had hidden the mismatch. The new trigger checks exact
order/line/hold/cost bindings and applies the accepted fee. It does not grant
Premium entitlement to the draft line. Initial delivery/capture, setup membership,
receipt, schedules and fallback retain Task 9's atomic contracts.

Wallet prices have no second deposit-gateway charge. Existing direct external
plan quotes gross up the same net once with a configured active gateway. New
PayPal order creation remains deposit-only; this change does not reactivate direct
plan purchases. Currency is USD at pricing/capture boundaries. A non-USD manual
carrier override is refused instead of being combined with a USD supplier price;
API carriers continue to ignore manual overrides. Explicit carrier rules must
match the owned line's carrier.

The internal `get_authoritative_refill_quote` now checks the enabled carrier/provider
mapping, exact benefit/currency and dispatch range. RANGE cost is interpolated for
the requested provider-native value rather than always charging the minimum; the
stored send divisor is retained. Published zero fees are not replaced. This
supplier projection stays service-only; Task 19 owns customer-read sanitization.
Workers still verify fresh supplier evidence before spend. This fixture does not
certify live supplier price/FX freshness or invent a provider guarantee.

eSIM catalogue, bounds and purchase continue to use `resolve_esim_offer_price` and
the same paid account benefit. Tests execute the actual captured purchase function
against the catalogue migrations and real wallet debit. DID quoting now uses that
same paid-evidence account resolver and effective server fee rule instead of raw
`sim_lines.plan_type` labels.

## Client behavior

Premium display uses cached server breakdowns, including actual upgrade credit,
USD amounts and cadence. Missing or malformed quotes remain unavailable. Setup,
onboarding and upgrade displays no longer construct a Premium price from a
minimum denomination, guessed membership, unused margin arguments or a prepaid
refill-year formula. Onboarding describes the annual membership plus first refill
and future wallet charges when due. Upgrade checkout is disabled without a price.
The shared Standard provider also reads the server quote and preserves a valid
zero. The legacy advisory constants are not production price evidence.

Removed the obsolete Premium calculators/arguments from `refill_pricing` and
replaced stale tests instead of restoring old prices. Wallet-refill arithmetic
cannot add a deposit gateway fee. Fee floors are applied before rounding, and
binary half-cent cases such as 0.285 round to 0.29 like PostgreSQL numeric. The
strict Premium parser rejects missing currency, missing credit, nonfinite,
negative, subcent or inconsistent totals. Backend receipt evidence, not a client
line label, continues to authorize paid features.

## Verification

- **40 native PostgreSQL scenarios passed**, including Task 9 setup/fallback
  acceptance and independent-session upgrade, settlement and finalization races.
  Evidence: [results](pricing-entitlement-results-20261018.json).
- **147 focused Flutter tests passed** across SIM lines, pending plan-fee recovery
  and scheduled tier pricing.
- **18 Edge adapter tests passed**, including DID tier pricing through the shared
  settled account resolver. Provider/REST adapters were isolated.
- Core pricing, wallet and upgrade sources passed Flutter analysis. Broader
  onboarding analysis still reports its existing unused members, an async-context
  lint and deprecated radio properties; there are no new compile errors.

The pricing runner uses the existing production-shaped financial fixture and
actual pending financial migrations through Tasks 9–13, then the actual Task 18
forward migration. Its extension captures the supplied schema's PayPal order,
provider mapping, range catalogue and eSIM order/check shapes plus the actual
`request_esim_purchase` source. Reference fee/config rows are explicitly isolated
fixtures. Provider catalogue/risk/household adapters, full production trigger/ACL
parity, Auth lifecycle, external payments, network delivery and cron daemons are
outside the fixture. There are no Supabase database tools exposed in this session;
local success is not live verification or confirmation of production prices.

```sh
npm run test:pricing --prefix tools/financial-tests
PRICING_NATIVE=1 EMBEDDED_POSTGRES_MODULE_PATH=/path/to/embedded-postgres/dist/index.js \
  node tools/financial-tests/pricing.mjs
node --test test/second_number_backend.test.cjs
flutter test --no-pub test/features/sim_lines \
  test/features/wallet/pending_plan_fee_test.dart \
  test/features/scheduled_topups/scheduled_topup_sheet_tier_pricing_test.dart
```

`PGLITE_MODULE_PATH` supports a dependency cache outside the workspace. The native
runner uses only loopback port 56552 and removes its temporary database.

## Coordinated release gates

1. Capture the read-only
   [pricing preflight](../../supabase/verification/pricing_entitlement_preflight.sql).
   Confirm actual membership values, effective fee policy/basis/currency, gateway
   configuration and deployed source. Supply missing configuration through the
   authorized configuration process; do not seed fixture prices into production.
2. Review legacy receipts, reversals, unbound fees, old zero-fee memberships and
   grandfather policy. Do not invent funding or payment proof. Existing pending
   setup drafts need a fresh server snapshot; unresolved supplier work retains
   its reservations. Decide the treatment of valid historical exceptions explicitly.
3. Apply only the reviewed financial dependencies, canonical pricing/catalogue
   migrations, Tasks 9–13 contracts and this forward repair in the scoped release.
   The October 4 superseded migration must not follow or overwrite them. Do not
   bulk-push the active migration directory. This new standalone pricing runner
   is required in addition to the older financial harness.
4. Coordinate the new quote/receipt/fee-policy RPCs, client repository/controller,
   onboarding/upgrade display and shared `manage-dids` consumer. Old customers
   calling the unbound plan debit deliberately fail closed; prepare the compatible
   client or maintenance gate before revoking that API. Preserve the Task 17
   acquisition gate and the coordinated instant/scheduled worker requirements.
5. Check deployed bodies/grants/RLS, API schema cache and authenticated named calls.
   Run the read-only
   [pricing catalog checks](../../supabase/tests/pricing_entitlement_contract_tests.sql),
   then separately authorized controlled wallet/setup/upgrade/fallback/eSIM flows
   with the approved supplier budget. No such rollout or spend was performed here.
