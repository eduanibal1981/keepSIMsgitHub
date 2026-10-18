# Task 15: usage forecasts against the actual eSIM schema

Status: **REPAIRED LOCALLY; NOT DEPLOYED**, 2026-10-18 (Asia/Muscat).

The captured production computation references missing `public.esims` and
nonexistent eSIM `validity_days`/`metadata` columns. Renaming the table alone
would leave those errors. The retained null-anchor migration also emits method
`none`, rejected by the actual forecast CHECK constraint. Both failures were
reproduced in isolated native PostgreSQL using captured table contracts and
original function definitions; the original missing-relation failure rolls
back physical forecast writes too. No production query or migration was run.

## Actual data mapping

| Forecast evidence | Actual source and handling |
|---|---|
| Subject/ownership | `user_esims.id`, `user_id`; forecast/sample eSIM IDs reference this table. Ownerless subjects or subjects without a profile are omitted. |
| Initial/current data | `user_esims.data_total_mb`, `data_remaining_mb`; zero/nonpositive totals are not treated as a measured empty bundle. |
| Usage observation | `last_usage_check` and `esim_usage_samples(esim_id,sampled_on)`. Snapshot the observation's UTC date rather than manufacturing a fresh reading each job day. |
| Absolute expiry | `user_esims.expires_at`. Never reconstruct expiry from purchase time or catalogue duration. |
| Nominal duration | Positive `esim_offers_cache.duration_days`, matched by **provider and bundle_name**. This is current advisory catalogue metadata, not a historical purchased-duration guarantee. Missing/nonpositive values stay null. |
| Historical customer value | Completed `esim_orders` via `user_esims.order_id`, additionally matching owner/provider/bundle. `retail_price_usd` is the per-unit retail amount; `total_amount_usd` may include multiple units. Wholesale values are never selected. |
| Offer identity | The matched order's nonempty `offer_id`, when it fits the existing 120-character forecast field. Missing/oversized values stay null. |

The current schema stores no activation timestamp or immutable purchased
duration snapshot. Current worker source initializes expiry from catalogue
duration with a legacy 30-day fallback and may initially store zero data.
This SQL repair consumes stored expiry as the existing database contract; it
does not certify provider activation/expiry semantics or rewrite worker values.
Those remain supplier/fulfillment verification obligations. Historical retail
suggestions are advisory and do not authorize a purchase at that price.

## Implemented behavior

[`20261018020000_usage_forecast_schema_contract.sql`](../../supabase/migrations/20261018020000_usage_forecast_schema_contract.sql)
is forward-only. The older null-anchor source remains unchanged and superseded;
do not include it in a bulk migration push.

Physical lines retain the existing successful-execution history, retry-gap
floor, carrier-derived cadence, pricing suggestions and allowed method labels.
Missing `last_topup_at` leaves depletion/days remaining null with low confidence.
No `created_at`/current-time recharge baseline or rejected `none` method is
introduced. The hard inactivity cap no longer includes grace, consistent with
the existing carrier business rule. Inactive physical forecasts are removed.

Active/installed eSIMs use finite stored expiry and measured data when available.
Terminal, expired and ownerless subjects lose stale forecasts. Valid observations
must have nonnegative remaining data within a positive total, fall after purchase
and within the recent 30-day window, and not be future observations. Repeated
refreshes upsert one sample for the actual observation's UTC date. Known unlimited
bundles are not fitted as finite data allowances.

The fitted rate uses the real day span between first and last valid readings.
Data increases or total changes reset the segment. A newly increased current
balance also invalidates an older fit before the next snapshot. Projections start
at `last_usage_check`, so stale readings do not acquire extra days merely because
the job runs later. The prediction is bounded by stored expiry. One sample, flat
usage, missing evidence or invalid numerical ranges produces an expiry-only
low-confidence forecast, or null depletion if expiry is unknown. There is no
default 30-day eSIM duration or inferred initial price.

Rates must fit the existing `numeric(12,2)` field. Usage projections beyond
36,500 days are withheld rather than overflowing date/integer fields; any known
stored expiry remains usable. These guards produce unknowns, not capped guesses.

Unexpected eSIM errors roll back the eSIM subtransaction, invalidate old eSIM
predictions/suggestions, warn and attempt a sanitized `usage_forecast_failed`
system alert. Valid physical output survives. Snapshot/alert failures also warn
and preserve computation. If diagnostics fail, a second PostgreSQL warning
remains. Raw exception messages and customer/provider payloads are not copied.
Physical computation failures still propagate. Existing refresh JSON keys and
integer RPC signatures are preserved; counts report successful work, not proof
that every subject/stage succeeded. Inspect system alerts and warning logs.

The new owner-only **SECURITY INVOKER** core has no API-role EXECUTE. Its trusted
callers are the postgres/service bulk wrapper and the existing owner/accepted
household-manager manual recharge definer. The latter retains its checks and
return shape, calls the protected core, and warns if recomputation fails.
Anonymous/viewer/unrelated callers cannot use that manual path, and clients
cannot call the core/bulk functions even with forged service claims. Safe empty
search paths and explicit grants are asserted in SQL tests.

Forecast alerts now provide versioned event/template metadata, the current line
route and an empty delivery list to the existing notification outbox trigger.
Forecast-row locks and `last_alert_at` suppress repeated/concurrent alerts.
An outbox failure leaves `last_alert_at` unchanged and does not undo forecasts.
No send occurs in SQL, and no provider delivery is claimed from insertion.

## Verification

Command run successfully:

```sh
EMBEDDED_POSTGRES_MODULE_PATH=/tmp/keepsims-financial-tests/node_modules/embedded-postgres/dist/index.js node tools/financial-tests/forecasts.mjs
```

Result: **32 passed, 0 failed** in isolated native PostgreSQL. Expanded execution
permission was required for local PostgreSQL shared memory/loopback access.
The suite does not connect to Supabase or providers.

Coverage includes both original failure reproductions; no data; null recharge
anchors; physical history/retry-floor/default/carrier-cap behavior; mixed subjects;
composite catalogue matching; retail unit pricing; sparse/flat/one-sample usage;
expiry bounds; stale observation timing; missing metadata; data resets; invalid,
future, pre-purchase and mismatched-total samples; unlimited/zero baselines;
extreme numeric values; terminal/expired/ownerless eSIM cleanup; owner/manager
manual recharge and negative roles; snapshot/eSIM/outbox failures; durable alert
state; exact grants/search paths; and independent-session refresh serialization.

The captured cron is `refresh-usage-forecasts`, `20 2 * * *`, username `postgres`.
The runner verifies its stored command SHA-256 against
`SELECT public.refresh_usage_forecasts();` and executes that SQL as postgres.
It also invokes the actual customer manual-recharge function under API roles.
pg_cron's extension/daemon itself is outside the fixture.

The forecast fixture extends Task 14's 21-table/13-function notification baseline
with seven exact table shapes and six function bodies independently matched to
October 16 catalog SHA-256 fingerprints. It retains the supplied dump's columns,
CHECK constraints, keys, foreign keys and indexes for the extension. The base
fixture's excluded payment-gateway foreign key remains excluded. The real
notification/system-alert triggers run. Tests apply Task 14's notification
migration and Task 15's forecast migration; pending financial migrations are
not part of this suite.

The bounded fixture omits unrelated triggers, full API table ACL/RLS parity,
Supabase Auth lifecycle, health/rescue trigger chains, provider usage calls and
activation semantics. Synthetic JWT claims exercise SQL authorization but do
not test JWT cryptography. No fresh Supabase verification tool was available;
the supplied public schema and stored live catalog remain snapshot evidence.

Supporting files:

- [Native scenarios](../../tools/financial-tests/forecasts.mjs).
- [Read-only catalog assertions](../../supabase/tests/usage_forecast_contract_tests.sql), returning zero rows on success.
- [Fixture manifest](../../supabase/tests/fixtures/usage_forecast_baseline.json).
- [Capture script](../../tools/financial-tests/capture-notification-fixture.py): pass the supplied schema dump path followed by `--forecasts`.

## Targeted release requirements

1. Inspect current live function definitions/grants, forecast/sample constraints,
   eSIM/order/catalogue relationships, manual recharge/household permissions,
   triggers and cron caller/command. Reconcile drift before applying this snapshot
   repair. Confirm the existing PostgreSQL owner is `postgres` as captured.
2. Release the reviewed Task 14 notification contract and this migration as
   targeted changes. Task 14 provides honest system-alert diagnostics; Task 15
   supplies the forecast alert contract. Neither requires the pending wallet
   package. Do not bulk-push the migration queue or apply the superseded
   `20260916080000_fix_forecast_anchor_null_recharge.sql` unchanged.
3. Run the read-only catalog assertions. Observe the next scheduled run and
   inspect counts, unknown predictions, samples keyed by observation date,
   system alerts and PostgreSQL warnings. Existing forecasts are refreshed or
   invalidated by execution; the migration does not backfill usage, purchase
   metadata or historical observations.
4. Verify stored provider expiry/data/freshness and deployed outbox delivery
   separately with an explicitly scoped test. A successful cron run or forecast
   row does not establish provider truth or message delivery. No real messages
   or purchases were used for these regressions.

Task 15's local implementation and acceptance checks are complete. Deployment
and current live/provider verification remain pending. Task 16 is independent
and was not started; this work does not repair its maintenance/deletion contracts
or close financial/provider release gates.
