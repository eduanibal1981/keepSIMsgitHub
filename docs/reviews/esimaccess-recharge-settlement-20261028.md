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
- 22 SQL scenario groups using inspected deployed wallet definitions and isolated
  schema fixtures; four native PostgreSQL concurrency/reconciliation groups.
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
