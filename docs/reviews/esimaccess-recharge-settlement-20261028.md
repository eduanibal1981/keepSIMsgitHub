# ESIM-08 fixed recharge and settlement — 28 October 2026

Implements fixed-bundle recharge on the original owned profile through the existing
`esim_orders`/private run engine. Customer confirmation, retry adoption, receipts
and history are implemented; Admin Operations has a read-only operation inspector.
New actions remain disabled pending scoped provider and wallet acceptance.

## Financial and recovery contract

- Atomic owner/session checks, exact quote/price/context checks and wallet/profile
  locks produce one order and durable reservation. No expiry-based release applies
  to the new `esim_op:` hold namespace. A duplicate accepted quote or purchase nonce
  adopts the original operation, including after expiry or rollout disablement.
- Actual deployed reserve/capture/release primitives are reused. The capture helper
  gets wallet-before-hold locking and private transaction-local capture provenance;
  its lot/ledger accounting and grants are preserved. A wallet trigger protects
  outstanding eSIM reservations against older direct debit writers. Tests also cover
  an ordinary hold capture sharing that wallet. Reconciliation includes the new
  debit/refund types. This is a scoped boundary, not a general wallet rewrite.
- Confirmed delivery captures once. A known refusal before submission releases
  once. A documented definitive inline rejection releases, or refunds a proven
  legacy debit to its recorded original payer within the actual unrefunded amount.
  Legacy orders are never reserved or debited again. Unproven legacy money needs
  support. The pre-existing failed eSIM Go order is not modified financially.
- Supplier success plus a database outage uses a private fsync receipt journal,
  then records/settles the same operation. The installed profile, ICCID and
  activation credentials remain the same. One entitlement records the supplier
  transaction. Expiry is shown as confirmed only for activated profile states.
  Alert-cycle reopening is in the settlement transaction; an alert failure rolls
  back settlement and recovery retries the saved evidence.
- New-profile fulfillment uses the same financial authority. Its received supplier
  order reference is journaled and adopted exactly; partial issuance stays reserved.
  No fabricated issuance, timeout refund or automatic second supplier submission.
  Old checkout clients receive `UPDATE_REQUIRED`; the new API binds actor, nonce
  and reviewed amount to the intent.

## Supplier contract and limits

Reviewed the public [eSIM Access API contract](https://docs.esimaccess.com/) and its
published Postman collection `2s93mBxf3q` on 28 October 2026. `/esim/topup` accepts
`esimTranNo`, `packageCode`, `transactionId` and an optional amount string in
1/10000 USD units. ICCID submission is deprecated. Fixed plans do not send a
daily duration. The response contract identifies `topUpEsimTranNo` as the unique
top-up reference, but older published examples omit it.

The adapter requires an exact transaction/profile match, unique top-up reference,
valid expiry and safe allowance/usage values before capture. A missing reference,
timeout, ambiguous response or unknown supplier error remains reserved for support.
Only documented validation failures 200005–200008, 310241 and 310243 are classified
as definitive inline rejection. Error 900001 remains unknown.

No documented read-only recovery endpoint for a lost top-up response was found.
The journal recovers received confirmations; it cannot recover a response never
received. No undocumented lookup or usage-delta inference is used, and supplier
idempotency is not assumed. This prevents claiming real-provider acceptance.
No paid supplier call or live wallet mutation was used for testing. Enabling
spending still requires a specified owned test profile and named spending ceiling,
plus provider and wallet acceptance; all three new gates remain false.

## Verification

- 110 customer eSIM tests, including confirmation, account switching, duplicate taps,
  uncertain results and financial receipt wording; customer feature analysis clean.
- 57 worker tests, including SQL outage recovery, durable purchase references,
  no replay on timeouts, receipt conflicts and private journal permissions.
- 23 SQL scenario groups using inspected deployed wallet definitions and isolated
  schema fixtures; five native PostgreSQL concurrency/reconciliation groups.
- Eight Edge identity/allowlist tests; JWT verification retained and Deno checked
  with the committed dependency lock.
- Two Admin inspector tests (invalid input and clearing on logout); scoped analysis clean.

Fixtures use actual inspected wallet/helper definitions but stub broader device-risk
and notification-delivery dependencies. They do not prove every unrelated live
money writer, provider behavior, account-deletion flow or mobile binary behavior.
App source is tested locally; no customer/Admin binary is published.

## Deployment and recovery

The [release manifest](esimaccess-recharge-settlement-20261028/release/manifest.json)
contains file hashes, source bases, flags and exclusions. Deployment receipts are
recorded alongside it. Only `worker-esim-fulfillment` may restart. VM transfer is
direct from authoritative `backend-sync-wt`; no VM Git pull. Credentials and other
processes stay outside this release.

Disable new actions by keeping `recharge_enabled=false` and `new_sales_enabled=false`.
Recovery of submitted operations and saved receipts must keep running. Never release
unknown holds, replay supplier POSTs, restore the old timeout/refund worker, delete
the private journal or reverse settled money as a software rollback. Correct a
deployment through a reviewed forward migration/runtime fix. The journal must be
retained through host maintenance; its directory is mode 0700 and entries mode 0600.


## Deployment result

Applied migration `20261028042251` (`esim_fixed_recharge_settlement`) and corrective
migration `20261028042532` (`esim_settlement_view_boundary`) to project
`zwxswagokhgbuzrrbnhr`. Edge `esim-recharge-discovery` version 2 is active with JWT
verification; retrieved entry/helper sources match the release artifact exactly.
The dependency lock was included in deployment (retrieval omits that lock).
Unauthenticated POST returns 401 and CORS preflight returns 204.

Four worker files match the manifest hashes on the VM. Only
`worker-esim-fulfillment` restarted (PID 1064136, restart count 22); all other PM2
processes retained their PIDs, states and restart counts. Backup:
`/home/abdal/keepsims_backend/backups/esim08-20261028`. The private journal is mode
0700 and empty. Fresh database heartbeats show zero cycle errors. The existing
PM2 error log last changed on 18 October and is historical, not a release error.

Post-deployment advisor verification caught a view-options reset in the first
migration. A forward corrective migration immediately restored
`security_invoker=true,security_barrier=true`, granted only the safe filter column,
pinned the new checkout RPC to an empty search path and indexed settlement-ledger
lookups. Both isolated engines now test owner/non-owner view reads and denial of
wholesale access. The live null-owner read returns zero rows. The final advisor
comparison has no new errors or anonymous function exposures. Intentional notices
remain for two private deny-client RLS tables and the authorized customer/Admin
SECURITY DEFINER RPCs. Existing project-wide notices are outside this release.
See [final advisor delta](esimaccess-recharge-settlement-20261028/evidence/final-advisor-delta.json)
for the individual findings and remediation URLs.

The final read-only checks show all spending gates false, read-only discovery
true, no Access profiles, operation runs, entitlements or new escrow holds, and
the same failed legacy eSIM Go order. No live financial or provider acceptance is
claimed. ESIM-09 remains the next implementation step; enabling spend is separate.

Runtime source commits: customer `6e731da8c1487ac9a59d0f029620879f7dcd1275`, backend
`968b1f68c679b1dd4d7be809e2c2dab465cca92a`, Admin
`29e6c0f027ad8195f2074cfab7178c14f51801be`. Follow-up source records contain the
corrective migration, expanded regression tests and final receipts. All work is
scoped to `codex/esim08-fixed-recharge-20261028`; default branches and unrelated
workspace edits are preserved.

To reproduce financial checks, run `npm ci` in `tools/financial-tests`, then
`node tools/financial-tests/esim-settlement.mjs` and
`node tools/financial-tests/esim-settlement-concurrency.mjs` from the customer root.
The native harness uses a temporary local PostgreSQL instance and random fixture
credentials; it never connects to production.


Final implementation revisions pushed to the scoped branch: customer
`b8c30edd6ce12eff065c911a3e84bd6dfb20c74f` (includes the corrective migration),
backend `3c3961d18cd428817efe1abc18dfbaefa9e27766`, Admin
`29e6c0f027ad8195f2074cfab7178c14f51801be`. The final receipt commit only adds
source synchronization evidence; the tested/deployed sources remain these revisions.
