# Task 14: notification SQL and scheduler continuation

Status: **REPAIRED LOCALLY; NOT DEPLOYED**, 2026-10-18 (Asia/Muscat).

The original upcoming-refill emitter uses rejected category `wallet` in both its
insert and deduplication query. It also claims push delivery from insertion and
omits the event type needed by the current dispatch trigger. An isolated call
to the original `process_due_notifications()` reproduced SQLSTATE `23514` with
the production category constraint. The failed call rolled back its earlier
due-schedule notification and prevented missing-date/urgent emission.

## Implemented behavior

Forward migration
[`20261018010000_notification_scheduler_contract.sql`](../../supabase/migrations/20261018010000_notification_scheduler_contract.sql)
changes the emitter to insert `wallet_low`, schema version 2, event type
`wallet_low`, a stable source key, occurrence/expiry times, template version/data
and a wallet navigation target. `delivered_via` starts empty. The existing
`trg_on_notification_created` trigger determines opted-in, eligible channels and
creates the durable `notification_dispatch_jobs` payload. No inline send or
new dispatch mechanism was introduced.

The balance check still subtracts active holds from the posted balance. The
future seven-day mini/custom refill window, active/unpaused line filter and
rolling one-reminder-per-line-per-24-hours cadence remain. The owner join now
requires the execution and line to belong to the same user. The nearest
execution is selected first. A shared transaction advisory lock serializes
direct and scheduled sweeps before the rolling deduplication check; this does
not assume the existing source-event index is unique. Supported legacy
`wallet_low` reminders with the original title also count toward the limit.
Activity records retain the accepted `reminder_sent` discriminator but explicitly
describe a queued event and include `state=queued` and its notification ID.

The scheduler runs due schedules, low-balance reminders, missing recharge dates
and urgent alerts in separate exception subtransactions. A failed stage rolls
back its partial writes, records a `notification_scheduler_failed` system alert
and continues. Due schedules advance only when their stage succeeds; failed
work remains eligible for the next sweep. A single bad due schedule currently
retries the entire due-schedule stage. Successful other stages survive.

Diagnostics contain only the job name, stage and SQLSTATE. Warnings never copy
`SQLERRM`, customer payloads or provider details. The existing system-alert
notification trigger now emits complete event metadata with an empty delivery
list too. If an outage also breaks that diagnostic insert/trigger, a second
sanitized PostgreSQL warning remains observable. A successful pg_cron status
alone is consequently insufficient to establish all-stage success; inspect
system alerts and PostgreSQL warning logs.

Both scheduler/emitter RPCs retain explicit postgres/service-role EXECUTE and
safe empty search paths. Anonymous/authenticated roles are denied. Body checks
also reject accidental grants or a customer-supplied service-role claim; the
actual database role must agree with the service identity, or the caller must
be the postgres scheduler session. The trigger function is not an API RPC.

## Verification

Command actually run:

```sh
EMBEDDED_POSTGRES_MODULE_PATH=/tmp/keepsims-financial-tests/node_modules/embedded-postgres/dist/index.js node tools/financial-tests/notifications.mjs
```

Result: **24 passed, 0 failed** on isolated native PostgreSQL. The local sandbox
required expanded execution permission for PostgreSQL shared memory and the
loopback listener; no production connection was made.

Coverage includes:

- Original category violation and complete scheduler rollback before the fix.
- Exact scheduler entry point as postgres; all four real emitters and outbox
  payloads; repeated sweeps produce one logical event per relevant source.
- Available funds reduced by holds; sufficient/exact funds, missing wallet,
  paused/inactive/foreign lines, past/out-of-window/nonpending executions,
  inclusive seven-day boundary and legacy null currency.
- Mini/custom ordering, rolling 24-hour suppression across source-key buckets,
  and supported legacy reminder deduplication.
- Category opt-out, channel opt-in and verified paid entitlement through the
  actual dispatch/eligibility functions.
- Outbox insertion failure rolls back the corresponding event/activity output;
  later real missing-date and urgent emitters continue. An injected missing-date
  failure also leaves urgent alerts functional.
- Failed due/low-balance stages and failed diagnostic storage remain observable.
  A total outbox outage attempts every stage, warns without raw payloads and
  recovers on the next successful sweep.
- Actual dispatch-job and target claim/completion RPCs: targets are absent before
  processing, and provider acceptance remains distinct from delivered state.
- Negative API roles, accidental EXECUTE grants, forged/missing service claims,
  authorized service processing and exact catalog grants/search paths.
- Independent PostgreSQL sessions demonstrably block on the transaction lock;
  concurrent direct sweeps and concurrent scheduler sweeps leave one event/job
  per logical reminder.

[`notification_scheduler_contract_tests.sql`](../../supabase/tests/notification_scheduler_contract_tests.sql)
provides a read-only post-release catalog check; zero rows means its grant/path
assertions hold. Behavioral scenarios live in
[`notifications.mjs`](../../tools/financial-tests/notifications.mjs).

## Evidence boundaries

The data-free fixture was extracted from the supplied
`/Users/thehonest/Work/live_public_schema.sql`. All 13 included function bodies
match independent SHA-256 source fingerprints in the October 16 live catalog.
Its 21 tables retain the dump's complete columns/defaults/CHECK constraints,
captured primary/unique constraints, local foreign keys and indexes. The
notification and system-alert insertion triggers are real definitions.
The real clock calculator/synchronizer execute with a synthetic verified
carrier rule; urgent alerts are not stubbed.

The stored live cron inventory identifies `process-hourly-notifications` as
active, hourly (`0 * * * *`), with username `postgres`. Its recorded command
SHA-256 matches `SELECT public.process_due_notifications();`, the command used
by the runner. The fixture executes that authorized SQL path directly;
pg_cron's extension, daemon and wall-clock scheduling are not installed/tested.

The generator and fixture manifest record one excluded foreign key to
`payment_gateways`, omitted unrelated trigger chains, API table ACL/RLS parity
and Supabase Auth lifecycle. There is no customer data, provider connection,
external delivery or full production-database reconstruction. The supplied
schema/catalog are snapshot evidence; no Supabase MCP tools were available for
a fresh live check. No Flutter, worker, Edge Function or provider configuration
change is required for this SQL contract repair.

## Targeted release requirements

1. Before an authorized release, inspect the current live scheduler/emitter,
   dispatch/eligibility/system-alert trigger definitions, grants, notification
   columns/constraints and cron caller/command. Reconcile any difference from
   this snapshot; local tests do not prove current live parity.
2. Apply only `20261018010000_notification_scheduler_contract.sql` as a targeted
   forward migration after review. Do not bulk-push the pending migration queue
   or replay archived history. This migration requires the existing October 1
   durable notification/event schema, not the pending financial migrations.
3. Run the read-only catalog assertions and observe the next scheduled sweep.
   Inspect low-balance event/outbox state, successful later stages, system
   alerts and PostgreSQL warnings. Do not create customer notifications or send
   real messages solely as a regression test without a separately scoped test.
4. Confirm deployed outbox/dispatcher processing separately. Event insertion,
   an outbox row, a completed dispatch job or provider acceptance alone does
   not establish delivery. Retain the existing quiet-hours/channel/entitlement
   controls and urgent-alert feature flag.

Task 14's local implementation and isolated acceptance checks are complete.
Production verification remains pending. Task 15 is independent and was not
started; this repair does not fix usage-forecast schema failures or close the
financial/provider release gates.
