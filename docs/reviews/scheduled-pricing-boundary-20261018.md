# Legacy queue retirement and scheduled pricing — Task 20

Implemented locally on 2026-10-18 (Asia/Muscat). **REPAIRED LOCALLY; NOT DEPLOYED.**
No production writes, customer-data queries, supplier requests, balance backfills,
deployments, credential changes or VM restarts were performed.

## Finding status

| Finding | Evidence and disposition |
| --- | --- |
| Creation and upgrade call the yearly queue | Both active customer controller paths were traced and replaced with `initialize_line_schedules`. No active app calls to the legacy API remain. Its signature is retained as a throwing tombstone and EXECUTE is revoked from every API role, including service role. |
| Customers can write schedule prices and engine fields | Fresh live metadata still grants authenticated INSERT/UPDATE/DELETE and contains permissive ALL policies. The forward migration revokes table and historical column mutations, replaces ALL policies with read-only owner/household RLS, and supplies validated mutations. |
| Multiple future executions and untrusted old authorization | The migration pauses old paid schedules, keeps history and settings, and cancels only clearly unsubmitted waiting rows. Held, processing, submission-marked or provider-marked work is retained for reconciliation. Old execution versions cannot be claimed even after a parent is reauthorized. |
| Both clients and trusted execution | Customer saves/controls and both offline queues use validated RPCs. Admin monitoring uses an immediately loaded, guarded internal view. Workers retain their current claim signature and funded preparation/submission/settlement contracts. |
| Production closure | **OPEN IN PRODUCTION / NOT VERIFIED DEPLOYED.** Fresh metadata shows the legacy callable API and writable schedule fields; the new migration is absent. |

See [live metadata](scheduled-pricing-live-20261018.json) and
[test results](scheduled-pricing-results-20261018.json). No queued row is treated
as evidence that a future supplier refill was prepaid or free.

## Server contract

`20261018070000_scheduled_pricing_boundary.sql` follows Tasks 9, 10, 18 and 19
and their reviewed wallet, entitlement and recovery dependencies:

- `save_customer_schedule` takes line/type, frequency, next date, active state,
  selected offer/native range value, reviewed ceiling and optional existing ID.
  It derives the line owner, validates the owner or accepted household manager,
  rejects suspended accounts, checks actual paid Premium entitlement for paid
  automation, and derives price, internal costs, fee, tier, provider, units and
  engine/version from trusted catalogue and fee rules. An ID cannot be used to
  mutate another line/type. The returned row is the retail projection.
- Mini refills derive the qualifying offer and carrier cadence. Custom refills
  use the selected current offer. Native integer range dispatch units remain
  separate from major-currency airtime targets. The reviewed USD ceiling must
  cover the fresh retail quote, be finite cents, and be at most $1,000; it does
  not authorize a lower price or a higher entitlement. Pricing drift rolls the
  save back. Wallet balances and holds do not change when schedules are saved.
- Reminder saves retain controls and accept overdue offline dates within 366
  days. Reminder amount is a positive server-derived display hint, not payment
  authorization. Paid settings require an online price review.
- A locked parent plus a partial unique index maintains one validated waiting
  occurrence. Identical saves retain that occurrence; changed settings cancel
  only safe waiting work and create one replacement. Processing or uncertain
  work blocks replacement. NOWAIT execution locks avoid waiting on a worker
  while holding its line/parent. Concurrent claims use SKIP LOCKED plus the
  per-line advisory lock and exclude paused, foreign-bound and legacy work.
- Success advances the parent once, preserving cross-flow mini coordination.
  Pause/resume, delete, next-date and reset controls operate on the parent.
  Deletion refuses uncertain/financial work and rolls back its attempted pause.
  Quote-bound single-execution approval stays supported; the old unbound
  ceiling-changing approval API is client-inaccessible.
- Setup completion retains Task 18's actual funded capture function, with an
  explicit validated version on both insert and conflict update, deriving future
  major-currency airtime targets from its bound provider/SKU. Missing unit data
  rolls finalization back without a second charge; a later retry can finish. Real setup
  reservation, initial settlement and repeated finalization are tested against
  an existing legacy parent. Initialization is idempotent; missing reviewed
  paid settings remain paused and report `needs_authorization`, rather than
  inventing consent. A paid plan remains saved when schedule review fails, and
  UI messages tell the customer not to pay again.

The customer repository sends an explicit input allowlist, uses server-returned
prices, and leaves natural-key upsert serialization to SQL. Existing reminder
operations default to `notify` when old payloads omit the type. Cross-account
schedule operations remain queued for their owner. Legacy offline paid-setting
operations are discarded because they lack a fresh price review. Free offline
line creation keeps a stable UUID; deferred initialization follows its queued
insert on reconnect. Paid offline creation still fails before claiming success.
The admin monitor polls every three seconds after an immediate read; its view
uses the real `assert_admin` app-metadata contract. Ordinary and forged
user-metadata sessions cannot inspect internal schedule prices.

## Verification

- **36 native PostgreSQL/API scenarios pass:** 26 transaction/authorization/
  lifecycle cases, three independent-session races and seven real local
  PostgREST 16.4 cases. They include raw table writes, extra RPC arguments,
  anonymous/foreign/manager/admin access, unit conversion, stale price ceilings,
  setup settlement/replay, pause/resume/delete/date controls, migration history
  retention, claimed-work preservation and exactly-once concurrent claiming.
- **60 focused customer Flutter tests pass**, including creation and upgrade
  success/failure, server request bodies, controls, offline reminder/account
  boundaries, stable offline creation/reconnect ordering, retail pricing UI,
  current-price approval and schedule math. The approval fixture was updated
  for the retail-only DTO; its price and expiry assertions remain intact.
- **Two admin Flutter tests pass** for its copied mapper and offline replay.
- **62 authoritative backend tests pass** across scheduled boundaries and phases
  1–3. The phase-3 source check now reads the forward scheduling contract and
  verifies server delegation instead of requiring obsolete client price stamps.
  Only that test file changed in `backend-sync-wt`; worker runtime was not edited.
- Both apps' Riverpod code was regenerated. Focused analysis has no errors;
  eight existing customer internal-member/unused-field warnings and six
  logging/UI lint notices remain. Admin analysis has two existing logging
  notices only. Analysis commands exit nonzero for these diagnostics.
- A broader schedule-folder run exposed an existing notification-channel test
  expecting the old email/ACTIVE display. That unrelated assertion was left
  unchanged and is not counted among the 60 passing focused tests. Initial
  exploratory runs also exposed the stale approval DTO fixture (corrected) and
  an incorrectly requested nonexistent test path (removed from the command).
  No full application build or full-repository test pass is claimed.

The isolated runner loads the real proposed migrations, production-shaped
financial constraints and a data-free extension containing ten independently
hash-verified scheduling function bodies, with the real queue and success
triggers. Fixture notification/health/risk adapters and external providers remain
limited as documented; this is not a full production schema/reset baseline.
`capture-schedule-fixture.py` reproduces the extension from an operator-supplied
schema export. The pinned local CLI package was unavailable offline, so the
forward migration was manually versioned; no migration history was repaired.

Reproduce with `npm run test:schedules --prefix tools/financial-tests` using the
pinned embedded PostgreSQL dependency. Set `POSTGREST_BINARY` to the verified
local binary to include the seven HTTP cases, and, on macOS if required,
`POSTGREST_LIBRARY_PATH` to its PostgreSQL native libraries.
`SCHEDULE_TEST_REPORT` writes results; ports 56558/56559 can be overridden with
`SCHEDULE_TEST_PORT`/`SCHEDULE_HTTP_PORT`. The runner uses localhost and deletes
its disposable database. It cannot connect to Supabase or a supplier.

## Coordinated release and remaining limits

1. Use the reviewed dependency manifest and backups. Active migrations are a
   review queue, not a reset baseline; do not run an unfiltered push. Task 3
   containment must precede the newer financial/retail definitions.
2. Stop scheduled claim/processing during this migration. Reconcile existing
   held/provider-marked operations under Task 11 before resuming; do not cancel
   money or infer funding from a queued row. This repair intentionally requires
   existing paid schedules to be reviewed and reauthorized. Plan that customer
   communication and pause window as part of the separately approved release.
3. Release the SQL with compatible customer/admin clients and the already
   reviewed Tasks 9–11 workers. Old raw schedule writes and yearly queue calls
   fail closed. Both creation and upgrade payment success must remain distinct
   from “future automation authorized.” New setup snapshots explicitly revalidate
   old parents when funded initial delivery succeeds.
4. Reload PostgREST's schema cache, run the read-only
   `supabase/verification/scheduled_pricing_preflight.sql`, and verify real API
   roles/controls using approved test accounts. The isolated API pass does not
   establish the deployed gateway, actual user JWTs or production trigger chain.
5. Review legacy quarantined work, reminder health/notification side effects,
   retail polling load and the actual provider outcomes in the controlled
   Task 24/25 acceptance window. Keep provider spend disabled until that release
   gate passes. Forward-fix rather than restoring raw writes or the old queue.

Task 20's local implementation prerequisites are satisfied. Task 21's offline
voucher-state work is independent and may proceed locally; it was not started.
