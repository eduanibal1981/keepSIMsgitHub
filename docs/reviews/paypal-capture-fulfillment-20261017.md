# Task 5 — prevent duplicate PayPal wallet credits

Reviewed 2026-10-17 (Asia/Muscat). **REPAIRED LOCALLY; NOT DEPLOYED.**

Scope: Task 5 of [the executor plan](audit-executor-plan-20261016.md).
No live payments, captures, provider requests, balance corrections, migrations,
Edge deployments, credential changes or VM operations were performed. Existing
Task 2/4 credential/auth changes and unrelated dirty/staged work were preserved.

## Finding status and evidence

**F29: REPAIRED LOCALLY, OPEN IN DEPLOYED SOURCE.** Client capture previously
substituted `orderId` when `captureId` was absent, including
`ORDER_ALREADY_CAPTURED`; webhook fulfillment used the actual capture ID. These
were different idempotency keys. Client capture also set `paypal_orders.status`
to `captured` before wallet fulfillment and ignored the Supabase RPC's returned
error, allowing a retry to report success without repairing the missing credit.
Webhook attribution previously allowed missing local orders, used custom IDs as
owner/purpose authority without requiring matching stored ownership, and allowed
a one-cent amount discrepancy.

**STALE:** the allegation that the current APPROVED handler itself credits money.
It initiates capture. The wallet-credit event is PAYMENT.CAPTURE.COMPLETED.
Both actual paths are tested, including concurrent approval/client capture.

Read-only MCP retrieved deployed create v9 (`verify_jwt=true`), capture v5
(`true`) and webhook v11 (`false`). None matches the repaired local entrypoint.
[Sanitized deployment/preflight evidence](paypal-capture-live-20261017.json)
records bundle hashes, local hashes, settings and relevant live triggers. Live
metadata confirms the new fulfillment API, receipt table and order merchant
column are absent. The read-only catalog test returned the five expected missing
objects/constraints before release. The targeted aggregate checks found **zero**
orders with `paypal_<orderId>` deposit references and **zero** duplicated PayPal
funding-source identities. These bounded checks do not establish complete
historical payment reconciliation or prove whether any customer was affected.
Merchant configuration, credential validity and real provider responses remain
UNVERIFIED.

## Changes and trust boundary

The shared `paypal-capture.ts` verifies one purchase unit, CAPTURE intent,
stored owner/purpose, legacy plan/line identity when applicable, the configured
merchant/payee, exact USD cents and one full COMPLETED capture. Neither endpoint
trusts a client amount or substitutes an order ID for a capture ID. Missing,
pending, partial or multiple captures cannot fund a wallet. Signed webhook
capture IDs and amounts must agree with authoritative order/capture evidence;
provided webhook owner/payee fields must agree too.

Client and APPROVED paths retrieve the order before capture and use the same
stable `PayPal-Request-Id` for capture. Every capture outcome, including
ORDER_ALREADY_CAPTURED, non-success responses and timeouts, is followed by an
authoritative order retrieval. An error response is never treated as payment
proof. If no matching completed capture is retrieved, there is no fulfillment.
The provider's finite idempotency window is supplemented by checking its current
order state and a permanent local capture receipt.

Both client and COMPLETED webhook call **one service-only SQL API**:
`fulfill_paypal_capture(text,jsonb)`. It independently revalidates stored owner,
amount, purpose and pinned merchant against trusted Edge evidence. Ordinary
users/admin JWTs cannot call it directly. PayPal API evidence is fetched and
validated by the trusted Edge service; SQL does not itself call PayPal.

The forward migration is
`supabase/migrations/20261017110000_paypal_capture_fulfillment.sql`.
It adds a nullable expected merchant to orders and a private RLS-enabled capture
receipt table. Capture ID is the receipt primary key; order ID is independently
unique. Capture/order/wallet locks serialize concurrent fulfillment. Deposits use
ledger reference `paypal_<captureId>` and funding-source reference `<captureId>`.
The existing credit RPC remains responsible for the wallet/ledger/funding writes,
avoiding a competing accounting path. Receipt, credit, funding source and visible
`captured` status commit together. Any failure rolls all local effects back.

The APPROVED webhook never marks local fulfillment complete. The COMPLETED
webhook and authenticated client return success only after the atomic API
succeeds. A failed commit returns a retryable non-success response; a retry
retrieves/adopts the same provider capture. A historical premature `captured`
flag does not skip fulfillment. Late failure notifications cannot downgrade a
fulfilled order; an existing receipt can restore an older status downgrade
without another credit. Refund/reversal notifications remain reconciliation
alerts; this task does not implement a new refund or reversal debit.

The SQL adopts an existing canonical ledger entry only when its owner, amount,
wallet, completion state and single matching funding source agree. It preserves
spent funding-source balances. Historical order-ID credits, inconsistent or
missing funding sources, another capture for the same order and cross-purpose
reuse are rejected for reconciliation. No historical credits/lots or balances
are invented. Receipt identities survive linked ledger/lot/user deletion via
nullable references; order IDs are retained as receipt tombstones rather than a
cascade that would erase the deduplication key.

New orders explicitly pin `PAYPAL_MERCHANT_ID` in both the provider request and
stored order. Legacy orders without the new field can be fulfilled only against
the configured merchant and verified provider evidence; their merchant is pinned
on successful fulfillment. The wallet receipt UI retains numeric `gross`,
`paypal_fee` and `net` metadata. Existing direct-plan orders retain atomic plan
payment recording, separately from wallet deposits; new order creation remains
deposit-only. No Flutter payload/UI change or worker change is required.

## Tests actually run

**48 targeted tests passed:**

- **14 Edge/provider/SQL integration tests:**
  `PGLITE_MODULE_PATH=/tmp/keepsims-financial-tests/node_modules/@electric-sql/pglite/dist/index.js node --test test/paypal_capture_fulfillment.test.cjs`.
  Actual create/capture/webhook modules run against the actual migration and
  captured credit function in PGlite, with isolated Auth/PayPal/secret/rate-limit
  adapters. Tests cover client-first, webhook-first, overlapping requests,
  duplicate callbacks, shared capture idempotency IDs, already-captured and
  timeout adoption, database failure/retry, missing/incomplete captures,
  owner/purpose/payee/amount/currency mismatches, missing secrets/merchant,
  invalid signatures, approval versus completion, late failure status, premature
  local success flags, and merchant pinning during creation. Provider/Auth
  adapters are synthetic; there was no live Auth or PayPal request.
- **30 actual SQL tests:**
  `PGLITE_MODULE_PATH=/tmp/keepsims-financial-tests/node_modules/@electric-sql/pglite/dist/index.js npm run test:paypal --prefix tools/financial-tests`.
  Fifteen scenarios each run against the captured live credit function and the
  exact deposit-related M2 funding trigger/helper/credit definitions. They verify
  one deposit/receipt/lot, canonical identities, permissions, mismatch denial,
  late transaction rollback/retry, numeric receipt metadata, legacy adoption and
  quarantine, preservation of spent lots, plan/deposit separation, duplicate
  status recovery and the read-only release catalog check.
- **4 native PostgreSQL concurrency checks:**
  `EMBEDDED_POSTGRES_MODULE_PATH=/tmp/keepsims-financial-tests/node_modules/embedded-postgres/dist/index.js npm run test:paypal:concurrency --prefix tools/financial-tests`.
  Independent service-role sessions race client/webhook fulfillment in both live
  and M2 modes and verify that competing captures cannot fulfill an order again.
  The initial sandbox attempt could not allocate shared memory; the authorized
  temporary local PostgreSQL rerun passed and removed its server/data directory.
- Shared PayPal helper and webhook TypeScript `tsc --noEmit` passed using
  temporary Deno/remote-module declarations. Checking all three entrypoints also
  reported **two existing App Check BufferSource typing errors**, one in each
  unchanged `app_check.ts:124`. The two App Check copies remain byte-identical.
  They were not weakened or edited. Deno is unavailable here; actual Deno/runtime
  bundle validation remains a release gate.
- `git diff --check` passed. Read-only live source/settings/schema/constraint,
  selected aggregate and catalog checks were performed. No full Flutter build,
  broad financial suite or real PayPal sandbox payment was run.

The focused fixture preserves captured live numeric precision, NOT NULLs, all
CHECKs (including the actual 19 ledger types), foreign keys and indexes for the
five payment/wallet tables. Auth user and SIM tables are minimal dependencies.
Live notification/queue-resume/referral/plan-entitlement/timestamp trigger chains
are intentionally omitted; their inventory is in the evidence JSON. Atomicity
under a failing downstream insert is separately exercised. The M2 mode extracts
its exact deposit definitions, not the full pending migration; unused reservation
types have minimal stand-ins. This does **not** certify M2's refund/reversal
paths, its full bootstrap, live RLS/admin grants, missing production dependencies
or the known `refund_payout` incompatibility. Task 6 remains required.

## Compatibility and separate rollout — not executed

1. Obtain separately scoped deployment authorization. Recheck live definitions,
   canonical ledger/funding identities and any captured-but-unfulfilled orders.
   Inventory active payment producers. Prepare a coordinated capture/webhook
   cutover so an old handler cannot still mint an order-ID-based credit while
   a new handler credits the real capture. Any operational pause/drain requires
   that separately authorized scope; none was performed here.
2. Confirm `PAYPAL_MERCHANT_ID` for the actual sandbox/live account, matching
   `PAYPAL_API_BASE`, credentials and `PAYPAL_WEBHOOK_ID`. Provisioning values or
   rotation is separate work. Missing merchant configuration intentionally blocks
   new order creation/capture/webhook processing. Validate actual provider order
   responses include the required payee/custom identity and completed capture.
3. Apply only the reviewed Task 5 migration. It is independent of M2 and Task 4's
   event receipt migration and can run against the captured live credit API.
   Coordinate the earlier containment release first; do not push unrelated
   pending migrations or replay archived history. Do not add an automatic
   backfill for quarantined legacy records.
4. Deploy create-paypal-order, capture-paypal-order and paypal-webhook together
   with their complete local imports. Include `_shared/paypal-capture.ts`,
   `_shared/provider-secrets.ts`, `_shared/endpoint-auth.ts`, webhook's
   `_shared/webhook-events.ts`, and each unchanged `app_check.ts` where needed.
   Shared files must be included when using flat-file deployment tooling.
   Preserve Task 2's Vault-first reads and App Check/risk controls. Preserve
   existing return/cancel URL configuration; Task 5 does not authorize changing
   redirects or deploying an unverified return function.
5. Apply the explicit config settings: create/capture JWT on, PayPal webhook JWT
   off with mandatory provider signature verification. Run
   `supabase/tests/paypal_capture_fulfillment_catalog.sql`; require zero rows.
   Re-fetch bundles/settings, validate Deno compilation (including the existing
   App Check typing issue), then perform approved sandbox success/duplicate/
   concurrency/error-retry checks with known synthetic users. Confirm one
   receipt, deposit and funding lot and captured status after commit.
6. Record actual release evidence before marking VERIFIED DEPLOYED. Retain
   receipt identities and reconcile any contradictory legacy evidence using an
   owner-reviewed procedure. Do not erase receipts or revert to unsafe old
   handlers as a rollback shortcut. A paused/failed handler must continue
   returning retryable errors for externally completed but unfulfilled captures.

The repair remains local. Real provider configuration and full deployment/runtime
behavior are unverified. Task 6 can proceed and reuse this captured constraints
fixture, but its general harness, refund-type/reversal provenance regressions and
full financial release prerequisites are still outstanding. No Task 6 work was
started as part of this task.

Provider references consulted: [PayPal idempotency](https://developer.paypal.com/api/rest/reference/idempotency/),
[authoritative order lookup](https://developer.paypal.com/api/orders/v2/orders-get),
[capture order and representation rules](https://developer.paypal.com/api/orders/v2/orders-capture),
and [capture/payment identities](https://developer.paypal.com/sdk/orders/v2/definitions/capture/).
