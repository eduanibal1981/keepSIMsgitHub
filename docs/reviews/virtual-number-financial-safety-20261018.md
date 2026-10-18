# Virtual-number purchase and renewal financial safety — Task 17

Reviewed 2026-10-18 (Asia/Muscat). **Implemented and tested locally; undeployed.**
No customer balance, provider account, production schema, cron or Edge deployment
was changed. Broad paid acquisition remains disabled by the new database gate.

## Result and trust boundary

This completes the financial boundary of the existing Second Number SMS pilot.
The customer supplies an owned quote ID and renewal consent. `manage-dids`
cryptographically resolves the user through Auth. The trusted Edge service reads
an expiring server quote, repeats the exact supplier number search, verifies SMS
availability, USD and unchanged monthly/setup supplier costs, and calls
`authorize_second_number_purchase`. It ignores submitted prices/provider names.
The transaction locks the owner-scoped order, checks the disabled-by-default
pilot gate and published policy/terms, reserves available wallet funding, and
commits its single submission marker before contacting Telnyx.

`20261018040000_second_number_financial_safety.sql` extends, rather than replaces,
`20261017024520_second_number_inbox_and_lifecycle.sql`. Existing unsubmitted quotes
remain version 0 and must be refreshed; no supplier setup price is invented.
Existing in-flight purchases continue reconciliation even when acquisition is
disabled. Existing legacy DIDs are not enrolled into recurring charges.

A timeout, 409, rate limit, server error or uncertain database response retains the
submission and funding. Retries never issue another order. Polling adopts only
one correlated provider order and the exact active number with confirmed messaging
profile binding. Conflicting/missing evidence remains pending. A terminal failed
order must also have no number on the provider account before releasing funds.
Explicit rejection of the original single POST uses the bound failure transition.
There is no new unsigned number-order callback route; repeated polling/completion
uses the same order identity and idempotent SQL completion.

Activation and charging commit together. Capture validates the hold's exact
owner, wallet, currency, purpose, reference, amount, funding contract version,
in-flight state and funding allocations. An expired in-flight reservation can be
captured after confirmed delivery; expiry never proves provider failure. Provider
order/resource uniqueness prevents concurrent identity reuse. Debit, funding-lot
consumption, ledger write and DID activation roll back together on capture failure.
Failure release validates the same purchase binding. No failed debit is ignored.

Customer inventory/order output contains retail monthly/setup/total charges and
terms only. Removed wholesale/monthly-number and margin breakdown fields from
search, the Dart model and checkout. The existing retail setup charge is preserved.
The Edge list/forwarding responses use explicit projections. The admin-only supply
probe still returns provider costs to authorized administrators.

## Renewal, suspension and cancellation

The published customer subscription remains **30 days**, anchored to the prior
paid renewal timestamp, with its stored retail price. Provider monthly billing is
a separate supplier obligation; it is not implemented by creating another order.

Three days before renewal the scheduler emits one warning for that period. At the
due date, local SMS delivery stops until provider ownership/profile and payment
are confirmed. The scheduler checks the exact active provider resource and profile,
then calls the service-only `settle_second_number_renewal` with the original full
precision period timestamp. SQL serializes on the DID and writes one receipt keyed
by DID/period. Reservation, capture, receipt and next paid interval commit together.
Retries/concurrent invocations adopt the receipt. Client roles cannot write DIDs,
receipts, quotes or the acquisition gate, or call trusted financial APIs.

Insufficient **available** funds leave the number suspended for a maximum of three
days from the original due date. A top-up during that window permits the same
period to settle once. Suspended/expired numbers do not receive new inbox messages.
Provider/capture uncertainty also leaves service suspended without advancing the
paid-through date. Turning off renewal preserves the current paid term, then queues
release; explicit cancellation queues release immediately. Neither path bills a
new period. Expired grace queues release and cannot reactivate through a stale
provider check. Renewal and release serialize on the DID row.

Release work has priority over purchase reconciliation and renewal polling in the
bounded sweep. It retains provider IDs and retries with claim fencing/backoff until
the exact resource is absent and an account lookup confirms absence. Numeric-only
account filters are required by Telnyx; sending `+` can otherwise return no rows.
A stale release claim cannot finish a later worker's release. Failed/ambiguous
provider deletion retains `release_pending` and the continuing supplier obligation.
Historical SMS can still be read by its existing owner.

## Provider facts and remaining activation evidence

Telnyx documents upfront/recurring number charges and states that deletion ends
future MRCs; a local status update cannot cancel them. See
[Search and Buy Numbers](https://support.telnyx.com/en/articles/4380325-search-and-buy-numbers).
Its [monthly-charge reporting](https://support-v2.telnyx.com/en/articles/4425088-reporting-monthly-charges)
describes calendar-month MRC collection at the start of each month. This differs
from the pilot's customer 30-day term. Grace and cancellation near that boundary
can incur supplier costs without another customer payment. This exposure remains
an operator-budgeted pilot cost; it is not charged retroactively or treated as
eliminated by suspension. No assumption of prorated refund is made.

The official [number search](https://developers.telnyx.com/docs/numbers/phone-numbers/number-search)
and [Telnyx SDK contracts](https://github.com/team-telnyx/telnyx-node/blob/master/src/resources/phone-numbers/phone-numbers.ts)
were checked for search, ownership, status, filtering and deletion semantics.
Supplier search does not provide an implemented binding price token; validate the
search-to-order cost guarantee/account invoice behavior under an authorized budget
before activation. The gate requires both `enabled=true` and explicit user IDs;
there is no broad enrollment setting in this change.

Before enabling even a scoped pilot, verify account-specific recurring/setup and
inbound-message charges, calendar-boundary exposure, regulatory eligibility,
provider response correlation, profile routing, successful deletion and its invoice
effect, purchase/capture recovery and scheduler freshness. Never silently turn
on an old country policy as proof of this evidence. Broader paid release remains
blocked until lifecycle/provider evidence and a costed usage policy are accepted.

## Verification and release

The native PostgreSQL harness runs the actual pending wallet/funding migrations
through Tasks 9–13, the existing Second Number migration and this forward repair.
It preserves production wallet constraints/funding triggers and recreates the
legacy DID table including the captured permissive table grants. The supplied
`/Users/thehonest/Work/live_public_schema.sql` confirms that legacy DID shape and
grants. This focused fixture omits full production trigger/ACL/Auth/cron parity;
there are no available Supabase database tools in this session for live checks.

Verified locally:

- 19 native PostgreSQL scenarios, including independent-session purchase/renewal
  races, changed/expired/foreign quotes, unavailable funds, capture/ledger rollback,
  duplicate completion, original funding consumption, grace recovery, cancellation,
  retained expired ambiguous holds, owner denial and exact trusted grants.
- 17 Edge adapter tests execute actual source with isolated supplier/REST responses:
  fresh quote verification, wholesale-free output, disabled acquisition, timeout
  retention, exact ownership/profile checks, capture failure, release uncertainty,
  numeric-only filters and existing signed SMS handling.
- 26 focused Flutter tests passed; analysis of changed Dart sources passed.
- TypeScript no-emit check passed for shared service and both Edge entry points,
  using local Deno/serve type declarations. No Deno runtime deployment is claimed.

Commands (dependency paths are optional cache overrides):

```sh
node --test test/second_number_backend.test.cjs
SECOND_NUMBER_NATIVE=1 \
  PGLITE_MODULE_PATH=/private/tmp/keepsims-financial-tests/node_modules/@electric-sql/pglite/dist/index.js \
  EMBEDDED_POSTGRES_MODULE_PATH=/private/tmp/keepsims-financial-tests/node_modules/embedded-postgres/dist/index.js \
  node tools/financial-tests/second-number.mjs
flutter test --no-pub test/features/calling/second_number_rollout_test.dart \
  test/features/calling/my_numbers_screen_test.dart \
  test/features/calling/smart_call_dashboard_review_test.dart
```

Release requires separately authorized coordinated wallet/Task 11/Task 13 and
Second Number migrations, this forward migration, matching `manage-dids`, shared
service, `second-number-lifecycle`, signed SMS handler and client. Pause the older
lifecycle invocation during the replacement: the old SQL renewal routine no longer
collects money, and the old Edge cannot perform the new provider-verified settlement.
Verify function bodies, ACLs/RLS, provider identities, API schema cache and Edge
`verify_jwt` settings. Install/verify the versioned lifecycle scheduler only after
these checks, with its trusted credential in Vault. Keep the acquisition gate off
and its user list empty until the scoped provider evidence above is accepted.
Do not bulk push the migration directory or apply this repair independently of
its pending financial dependencies. Existing ambiguous orders/holds need review;
never fabricate provider evidence or release funds solely from age.
