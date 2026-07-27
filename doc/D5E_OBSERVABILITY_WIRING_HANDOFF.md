# D5e — Finish the wiring D5d left inert

Written 2026-07-27 after reviewing D5d (commit `25c07a3`, **push verified real**:
`git ls-remote --heads origin` → `25c07a33a797b4da963d777754c2fbaec882d5d5`).

**D5d fixed the two things that mattered most, and the fixes are real.** What
remains is a short punch list: one client regression that is still live, and an
observability chain that was built but never connected.

---

## Verified correct — this is the security objective of D5, and it is now met

Reproduced independently, in one rolled-back transaction:

| Probe | Result |
|---|---|
| `trg_fn_prevent_sim_line_plan_tampering` | `prosecdef = false` (**SECURITY INVOKER**) ✅ |
| role `authenticated`, real grants | **`42501`** ✅ |
| role `authenticated`, **column grant restored** (trigger is the only control) | **`KS403`** ✅ |
| online client payload (`toClientWritableJson()`, no `id`) | **`OK`** ✅ |

Defense in depth is genuine now: the column revoke blocks first, and if the
column grant is ever restored the trigger still blocks. That is exactly the
outcome D5 asked for three sessions ago.

Also confirmed: residue clean (`a1111111-…` and `b2222222-…` both **gone**),
`a1-wallet-test@example.com` still **$35.86**, `analytics_events` exists with
correct insert-own/select-own RLS, two real analytics call sites
([paypal_checkout_screen.dart:66](lib/features/payments/presentation/screens/paypal_checkout_screen.dart#L66),
[sim_lines_list_screen.dart:45](lib/features/sim_lines/presentation/screens/sim_lines_list_screen.dart#L45)),
`flutter analyze` **134 / 0 errors** with an honest per-rule breakdown.

---

## D5e-1 🔴 The offline sync path still fails 42501

`updateSimLine`'s offline branch builds
`Map.from(payload)..['id'] = line.id` and queues it;
[sync_queue_service.dart:100](lib/core/services/sync_queue_service.dart#L100)
then does `.update(op.payload).eq('id', lineId)` — so **`id` is in the SET list**,
and `id` is not a granted column.

Proven live as role `authenticated`:

| Payload | Result |
|---|---|
| writable columns **+ `id`** (what the sync queue sends) | **`FAILED [42501] permission denied for table sim_lines`** |
| writable columns, no `id` | `OK` |

So every queued offline edit fails permanently and the queue retries it forever.
Online editing works; offline does not.

**Fix:** in `processQueue`, remove `id` from the payload before the update — it
is only needed for the `.eq('id', …)` filter:

```dart
final lineId = op.payload['id'] as String;
final body = Map<String, dynamic>.from(op.payload)..remove('id');
await client.from('sim_lines').update(body).eq('id', lineId);
```

Prove it with a test that runs the queued payload shape, not just the online one.

**While you are in this file** — `sim_line_add` queues
`updatedLine.toJson()` with `id = 'offline_<microseconds>'`, which is not a valid
UUID, so `upsert` fails with `22P02` before privileges are even checked. That is
**pre-existing**, not a D5d regression, but the offline path is now under
scrutiny and it has never worked. Either strip the synthetic id on flush or stop
generating one.

---

## D5e-2 🔴 The worker heartbeat chain is completely inert

Three separate breaks, all verified:

1. **`check_worker_heartbeat_health()` is not scheduled.** `cron.job` has 7 jobs
   — `process-hourly-notifications`, `reap-stuck-executions`,
   `refill-pipeline-health`, `purge-deleted-accounts-hourly`,
   `check-rate-limit-health`, `prune-rate-limit-data`,
   `reap-stale-esim-orders-hourly` — and **none for the heartbeat**. The function
   exists and never runs.
2. **The heartbeat key does not exist.** `system_configs` has no
   `WORKER_ESIM_FULFILLMENT_HEARTBEAT` row — `config_value` and `updated_at` are
   both NULL. The worker code does upsert it
   ([worker_esim_fulfillment.js:112](servers/worker_esim_fulfillment.js#L112)),
   but the write is swallowed by `.catch(() => {})`, so either the restart did not
   take or the upsert is failing silently.
3. **`system_alerts` has 0 rows of kind `worker_heartbeat_stale`** — consistent
   with (1) and (2).

**Fix:** schedule it (`cron.schedule('check-worker-heartbeat', '*/10 * * * *',
'SELECT public.check_worker_heartbeat_health()')`), remove the swallowing
`.catch(() => {})` so an upsert failure is logged, confirm the worker is actually
running the new code on the VM, then **paste the live
`WORKER_ESIM_FULFILLMENT_HEARTBEAT` row with a fresh `updated_at`**, and
demonstrate the alert by aging the row and running the function.

Note the loop placement: the heartbeat only writes inside `processPendingOrders`,
which returns early when `isProcessingFulfillment` is set or credentials are
missing — check it still beats when there is no work to do.

---

## D5e-3 🔴 The external uptime monitor was still not configured

The report lists two URLs to monitor but includes **no confirmation from any
monitoring provider** — no monitor id, no dashboard link, no first-check result.
Listing what should be watched is not configuring a monitor. This is the third
session in which uptime monitoring has been reported without evidence.

Two problems with the proposed heartbeat URL as well:
`https://…/rest/v1/system_configs?config_key=eq.WORKER_ESIM_FULFILLMENT_HEARTBEAT`
requires an `apikey` header, so an anonymous check returns 401; and pointing an
external service at `system_configs` exposes business config through a
third-party monitor. Monitor the `health` function instead and have **it** report
heartbeat freshness in its JSON body.

**Fix:** extend `supabase/functions/health/index.ts` to include heartbeat age and
return a non-200 when it is stale; point the monitor at that single URL; paste
the provider's confirmation and one green check.

---

## D5e-4 🟢 Small cleanups

* [sim_lines_repository_impl.dart:171](lib/features/sim_lines/data/repositories/sim_lines_repository_impl.dart#L171)
  — `final data = line.toJson();` is now dead (shadowed in the offline branch,
  unused online). Remove it.
* `carrier_pricing_id` is **granted** for client UPDATE but is **not** in
  `toClientWritableJson()`. Decide which is right and make them match — an unused
  grant is a hole with no purpose.
* One demo `analytics_events` row remains, inserted under the **real** power-user
  id `8a07a25b-…`. Harmless, but delete it so the first real event is the first
  row.
* `flutter analyze` went 133 → **134**. Not a concern given the new code, but the
  per-rule breakdown is the right habit — keep reporting it, and keep working
  `use_build_context_synchronously` (35) down.

---

## Still owed to the owner (carry forward, do not let these vanish)

* **Sentry DSN** — no crash can be proven until this exists. Everything else is
  wired correctly and waiting on it.
* A2 rotation (Supabase legacy JWT secret + Zendit key + the exposed PayPal
  sandbox secret), upload keystore + Play App Signing, hosted privacy/deletion
  URLs, C4 WABA/Twilio provisioning.

---

## Definition of done for D5e

1. Queued offline edit succeeds — paste the synced row, and a test covering the
   queue payload shape.
2. `cron.job` shows the heartbeat job — paste the row.
3. Live `WORKER_ESIM_FULFILLMENT_HEARTBEAT` row with a fresh `updated_at` —
   paste it; plus a demonstrated `worker_heartbeat_stale` alert.
4. `health` reports heartbeat freshness; external monitor configured against it —
   paste the provider confirmation and one check result.
5. Cleanups in D5e-4 done.
6. `flutter analyze` + `flutter test` with per-rule counts.
7. `git ls-remote --heads origin` shows the D5e commit.
