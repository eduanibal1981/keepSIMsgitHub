# Required worker fleet and reconciliation monitoring — Task 23

**Implemented locally; not deployed.** A fresh read-only, sanitized PM2 inventory
confirmed eight online VM services on 2026-10-18. The new versioned manifest
covers those eight and the required supplier-reconciliation consumer from the
pending financial release. It does not infer required services from filenames.
The old eSIM-only heartbeat cannot establish fleet health.

## Required services and work

The authoritative manifest is `../backend-sync-wt/worker-fleet.json`, version 1.
Every entry retains the observed PM2 name, script and working directory, records
its source/evidence and defines heartbeat and successful-work deadlines.

| Process | Independently monitored work |
| --- | --- |
| `worker_instant_refill` | Queue claims and completed processing cycles |
| `worker_auto_mini_refill` | Queue processing and approval pricing |
| `worker_auto_custom_refill` | Queue processing and approval pricing |
| `worker_offers_cache` | Catalogue refresh, including partial/credential/sync failures |
| `worker-esim-catalog` | Catalogue refresh for explicitly active suppliers |
| `worker-esim-fulfillment` | Fulfillment and usage polling separately |
| `server_baileys` | Actual connection readiness and durable receipt synchronization |
| `server_tg` | Successful Telegram long polls, including HTTP/API failures |
| `supplier-reconciliation` | Durable reconciliation claim/lookup/completion cycles |

The first eight are deployment-observed. Supplier reconciliation is **required
for the repaired financial system but absent from the current PM2 inventory**;
its missing heartbeat deliberately prevents a healthy release assessment.
`worker_voucher_stock.js` is unconfirmed and can purchase stock, `server_ww.js`
is a dormant alternative to Baileys, and `sim_liveness_service.js` is an imported
library. None is added to the start list. Existing voucher requests and purchase
jobs are still observed for overdue/failed work.

`worker-fleet.pm2.config.cjs` defines the observed eight services, with one
instance each, absolute script paths, observed working directories and explicit
restart settings. Supplier reconciliation retains its separate, gated financial
cutover config. The customer `ecosystem.config.js` now delegates to this
manifest rather than defining duplicate `queue-*` process aliases.
The VM metadata evidence is in [the sanitized inventory](worker-fleet-vm-read-20261018.json).
Online PM2 status alone does not verify provider, database or work progress.

## Telemetry and health semantics

`worker_health.js` sends a heartbeat every 30 seconds through service-only
`report_worker_health`. The database timestamps receipt; there is no heartbeat
write to broadly readable `system_configs`. Each work lane reports a bounded
phase, successful-cycle counter, failure counter and running duration. Idle
successful queue polls are real progress; a heartbeat timer alone is not. The
first uncompleted cycle stays unhealthy. Failures remain failed until an actual
successful cycle. A hung awaited operation eventually exceeds its lane deadline
while liveness continues; a blocked event loop or stopped process exceeds the
180-second heartbeat deadline.

Telemetry includes a process-instance UUID, startup time, monotonic report
sequence and SHA-256 source fingerprint. Reordered reports and older instances
cannot overwrite newer observations. The fingerprint covers the backend root
JavaScript files, provider JavaScript, monitor and manifest read at startup.
It establishes source identity, not installed dependency equivalence or runtime
attestation. Host clock skew beyond the accepted startup tolerance fails closed.
The service credential remains in the request authorization headers; neither
configuration values nor error/provider/customer payloads enter telemetry.
Failures to send telemetry emit a constant warning at most once per five minutes
and never change purchase, retry, debit or refund authorization.

Baileys readiness follows the actual connection flag. Receipt-sync backlog or
exhausted/discarded synchronization reports a failed receipts lane. A new
aggregate-only `.receipt_sync.json.health` counter preserves dropped-receipt
evidence across restarts. Existing retry/TTL/send behavior is unchanged. A
successful send is never replayed to repair a missing receipt. After proving
receipt reconciliation, an operator may reset the health counter through a
separately authorized maintenance action; restarting alone does not clear it.
Historical drops before this instrumentation cannot be reconstructed by it.

## Database work and reconciliation

`20261018090000_worker_fleet_monitoring.sql` installs private requirement,
runtime, probe, cron, observation-cache and incident tables. Client roles have no
raw access. `report_worker_health` additionally checks service identity in its
body and validates every field/lane. Detailed reads use service-only
`get_worker_fleet_health()` or JWT/assert-admin guarded
`admin_worker_fleet_health()`.

Twenty-four fixed probes expose aggregate backlog, oldest age and unresolved
issue counts across:

- Due refill queues, stale processing/routing claims and failed approval pricing.
- Supplier ambiguity, expired reconciliation leases and operator-review cases.
- Expired unresolved holds, payout reconciliation and failed payout records.
- Ledger reconciliation drift, calling settlement and liveness reconciliation.
- eSIM fulfillment, active catalogue freshness and enabled carrier/supplier offer freshness.
- Open voucher promises and queued/claimed/failed manual-stock purchase jobs.
- Notification outbox claims, failed/unknown channel targets, scheduler failures and WhatsApp attempts.
- Queued/sending/failed billing email, DID purchase ambiguity, overdue renewal/release work and failed purge jobs.

Disabled suppliers/routes do not create invented freshness requirements. Future
refills and future voucher deadlines are not overdue queues. Missing relations,
unsupported shapes or failed probes produce `unknown`, never a healthy zero.
The probes observe financial state; they do not reconcile money, release holds,
retry payouts, buy stock or resubmit providers.

Twenty-three cron requirements cover the 22 captured active named jobs plus the
required hold-recovery job from the repaired financial release. Missing/disabled
jobs, absent run history, failed runs and overdue/hung runs degrade health.
No cron schedule is installed or activated by this migration.

The existing `check-worker-heartbeat` ten-minute cron entry invokes the replaced
`check_worker_heartbeat_health()` wrapper, which measures all probes, persists the
observation and checks the full fleet. Financial aggregates are measured only by
this trusted sweep, rather than rescanned for every public health poll. API reads
combine those measurements with current worker/cron health. A missing queue
observation or one older than 15 minutes degrades health. Queue detection is
therefore the configured age threshold plus up to one ten-minute sweep; the
admin panel labels the measurement timestamp. Process liveness remains current
on every health read.

Alerts use one fixed incident key per component, a transaction advisory lock and
a six-hour cooldown that survives recovery/flapping. Concurrent sweeps cannot
insert duplicate alerts. Recovery updates the incident state. If alert storage
fails, the incident's alert timestamp is not advanced; the next sweep can retry,
and a sanitized PostgreSQL warning preserves the persistence failure. Alert rows
contain component/status/count/age only. Existing legacy worker/application logs
are not certified by this telemetry privacy boundary.

## Endpoint and admin visibility

The `health` Edge function now calls the full fleet API. It returns HTTP 200 only
for an internally consistent healthy fleet, HTTP 503 for partial failure,
unknown/stale measurements, database/configuration errors or malformed results,
and sanitized failures. Public output contains aggregate counts, overall status,
database availability and timestamp only, with `Cache-Control: no-store`.
It does not return component names, versions, queue details or error messages.
Its explicit `verify_jwt=false` configuration matches that public aggregate
contract. Detailed SQL APIs remain protected.

The admin Background Automation & Cron Jobs screen includes a polling,
expandable **Worker fleet and reconciliation** panel. It shows component state,
work-lane failures, backlog, oldest age, last heartbeat and source fingerprint.
It checks the power-user flag before constructing its API read; server
`assert_admin()` remains the authorization boundary. Errors display unavailable
health rather than a healthy default. Refresh is read-only and introduces no
restart, purchase or reconciliation action.

## Verification

- **50 isolated native PostgreSQL scenarios pass**, including stopped/stalled
  states for each required process; lane separation; first-run and stale-success
  rejection; the actual Node reporter connected to the real SQL RPC through a
  local adapter; fencing; schema/grant/body denials; guarded admin reads; failed
  queue/claim/payout/catalogue/notification/DID/ledger/purge observations; cached
  queue freshness; incident cooldown/storage failure; and independent-session
  alert deduplication.
- **125 focused authoritative backend tests pass**, including actual empty/error
  entrypoint execution for the queue, catalogue, eSIM, Telegram and reconciler
  workers, reporter semantics, restart-persistent receipt-drop health and the
  existing financial boundary/catalogue/fulfillment/durable-queue checks.
- **10 health Edge handler tests pass**, covering partial failure, sanitization,
  configuration/contract failures, public response shape and allowed methods.
- **Two admin tests pass**, covering visible partial failure/backlog/work lanes
  and pre-API non-admin denial. Focused admin analysis is clean.
- Node syntax checks pass for all 12 changed backend entrypoint/helper/config
  files; the health handler passes TypeScript no-emit checking. Relevant diffs
  pass whitespace checks.

The SQL result file is [worker-fleet-results-20261018.json](worker-fleet-results-20261018.json).
The fixture captures actual table shapes, all associated constraints and indexes,
with no omitted foreign keys. Its cron relations and Auth identity helpers are
isolated adapters. These are not full Supabase REST/pg_cron, provider, WhatsApp
connection or deployed-runtime tests. The Node-to-SQL integration uses an injected
HTTP adapter rather than a real PostgREST server. No live process was stopped,
stalled, restarted, deployed or messaged, and no provider or financial action ran.

```sh
FLEET_NATIVE=1 EMBEDDED_POSTGRES_MODULE_PATH=/path/to/embedded-postgres/dist/index.js \
FLEET_TEST_REPORT=docs/reviews/worker-fleet-results-20261018.json \
node tools/financial-tests/fleet.mjs
node --test test/worker_fleet_health_backend.test.cjs
```

From `../backend-sync-wt`, run:

```sh
node --test test/worker_health_test.js test/instant_refill_boundary_test.js \
  test/scheduled_refill_boundary_test.js test/supplier_reconciliation_test.js \
  test/esim_catalog_test.js test/fulfillment_test.js test/durable_whatsapp_queue_test.js
```

Run `node --check` on the changed backend files and run
`flutter test --no-pub test/features/control/worker_fleet_panel_test.dart` from
`../keep_sims_admin`.

## Coordinated release and acceptance

1. Refresh current VM process/source/config-name evidence and run the read-only
   `supabase/verification/worker_fleet_preflight.sql`. Compare actual dependency
   tables/columns, cron names/run retention, function owners and grants. The
   source-reproducibility candidate currently excludes this concurrent Task 23
   change; explicitly add/review it in the approved release bundle. A safe full
   migration replay or production release gate is not established here.
2. After the wallet/recovery, calling, liveness, notification, maintenance, DID
   and retail prerequisite releases are approved, release the reviewed SQL,
   reporter/manifest/worker sources, compatible health Edge function and admin
   panel together. Preserve `.env`, Baileys authentication/session state,
   durable message/receipt queues and receipt-health state. Include
   `durable_whatsapp_receipts.js`, `worker_health.js` and `worker-fleet.json` with
   the entrypoints; a worker file alone is not the deployment bundle.
3. Use the project's direct SSH/SCP deployment and remote syntax/restart
   procedure from the authoritative backend worktree. Preserve observed PM2
   names and working directories. Only the observed-eight config belongs to
   this fleet start list. Start supplier reconciliation from its separate config
   only as part of the authorized Task 11 financial cutover. Do not start dormant
   voucher or alternative messaging scripts.
4. Allow actual first cycles and the existing health sweep to populate evidence.
   Compare reported source versions with the released source bundle. Confirm
   guarded admin detail, public 503 for a partial failure and no exposed payloads.
   Only during a separately authorized controlled VM exercise should each
   required process be stopped/stalled and recovered to prove alert delivery and
   timing; isolated tests do not establish that runtime acceptance. Validate
   external monitoring consumers against the new aggregate response contract.

No Supabase SQL MCP tools were exposed in this task session, so fresh live SQL
behavior, production probe cost and actual alert delivery remain release checks.
Existing unsafe legacy provider/financial behaviors are not fixed or certified
by adding monitoring. Healthy observations must not replace the financial,
provider and coordinated rollout gates.
