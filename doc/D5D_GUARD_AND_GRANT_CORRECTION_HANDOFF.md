# D5d — Correct the D5c guard and grant changes

Written 2026-07-26 after reviewing D5c (commit `cb17057`, **push verified real**:
`git ls-remote --heads origin` → `cb1705715469c11269944fe1d6254c4da84c565d`).

D5c did real work — the residue is genuinely gone, `health` is genuinely
deployed, Sentry's DSN gating is correct. But **the two headline security changes
did not do what the report says**, and one of them **broke SIM line editing in
the app**. Both were proven live.

---

## Confirmed good (do not regress)

* **Residue fully cleaned**: user `a1111111-…` gone from `auth.users`,
  `esim_orders` back to **1** row, 0 stray `esim_purchase_refund` transactions,
  `a1-wallet-test@example.com` still **$35.86**.
* **`health` is deployed** — MCP `list_edge_functions` shows slug `health`,
  version 1, `status: ACTIVE`, `verify_jwt: false`.
* **Sentry DSN gating is correct**: `String.fromEnvironment('SENTRY_DSN')`, init
  skipped when empty, and both capture sites guarded by `sentryDsn.isNotEmpty` —
  no more dead client silently swallowing events.
* `user_consents.analytics_consent` exists; the service now reads it.
* `flutter analyze` 147 → **133**, 0 errors.

---

## D5d-1 🔴 The fail-closed guard is dead code

`trg_fn_prevent_sim_line_plan_tampering` is still declared **`SECURITY DEFINER`**
and owned by **`postgres`**. Inside a `SECURITY DEFINER` function, `current_user`
resolves to the **function owner**, not the caller. So

```sql
IF current_user NOT IN ('service_role', 'postgres', 'supabase_admin') THEN
```

evaluates `current_user = 'postgres'` on **every** invocation — the condition is
never true and the trigger **never raises**.

Proven live, in one rolled-back transaction. The column `UPDATE` grant was
restored inside the transaction so that only the trigger could possibly block:

| Probe | Result |
|---|---|
| `fn_owner` | `postgres` |
| role `authenticated`, current grants | `BLOCKED [42501]` |
| role `authenticated`, **column grant restored** (trigger is the only control) | **`TRIGGER DID NOT BLOCK => exploit succeeded`** |

Two consequences:

1. The block reported in D5c comes **entirely from the column revoke**, not the
   trigger. There is no defense in depth — re-grant the column (Supabase
   blanket-grants on new columns, and any `GRANT ALL` maintenance script does it)
   and the hole reopens with no backstop.
2. **The report's probe output is wrong.** Both probes were labelled
   `BLOCKED [KS403: permission denied or trigger blocked]`. The real SQLSTATE is
   **42501** (`insufficient_privilege`). The probe caught any exception and
   labelled it KS403, which is exactly how a dead guard passes as a live one.

**Fix:** drop `SECURITY DEFINER` from the guard trigger — it needs no elevated
rights, it only inspects `NEW`/`OLD` and raises. As `SECURITY INVOKER`,
`current_user` becomes the PostgREST role and the allow-list works for all four
callers:

| Caller | `current_user` | Outcome |
|---|---|---|
| PostgREST client | `authenticated` / `anon` | blocked ✅ |
| pg_cron / migrations | `postgres` | allowed ✅ |
| `trg_fn_apply_plan_tier_from_payment` (SECURITY DEFINER, owner `postgres`) | `postgres` | allowed ✅ |
| service role calls | `service_role` | allowed ✅ |

**Re-probe with assertions on the specific SQLSTATE.** A probe that accepts any
exception proves nothing. Required output:

* column grant revoked + role `authenticated` → `42501`
* column grant **restored** + role `authenticated` → **`KS403`** (this is the one
  that currently fails)
* `plan_payments` INSERT with `kind='plan'` → `sim_lines.plan_type` actually
  changes (prove the legitimate path still works after the change)

---

## D5d-2 🔴 The column lockdown broke SIM line editing

`updateSimLine()` in
[lib/features/sim_lines/data/repositories/sim_lines_repository_impl.dart:186](lib/features/sim_lines/data/repositories/sim_lines_repository_impl.dart#L186)
sends **`line.toJson()`** — the entire model. That payload includes `plan_type`,
`plan_expires_at`, `verification_status`, `health_score`, `last_topup_at`,
`next_topup_due`, `validity_expires_at`, `protection_tier`, `is_auto_detected`,
`id`, `user_id`, `created_at`.

D5c granted column `UPDATE` on **13** columns only. Proven live as role
`authenticated`:

| Update shape | Result |
|---|---|
| full model (what the app sends) | **`FAILED [42501] permission denied for table sim_lines`** |
| granted subset (`nickname`, `updated_at`) | `OK` |

So **every SIM line edit from the app now fails** — the app's core object. The
same full payload also goes through
[sync_queue_service.dart:97](lib/core/services/sync_queue_service.dart#L97)
(`upsert`) and `:100` (`update`), so the **offline sync path breaks too**, and it
retries a permanently-failing operation.

This was not caught because the app was never run and no test covers
`updateSimLine`.

**Fix:** stop sending the whole model. Build an explicit writable-column map in
the repository (and in `sync_queue_service`), matching the granted set exactly.
Decide deliberately which of `verification_status`, `health_score`,
`protection_tier`, `last_topup_at`, `next_topup_due`, `validity_expires_at`,
`is_auto_detected` are client-owned versus server-owned, and grant only the
former. Then **run the app and edit a line**, and add a widget/integration test
that covers `updateSimLine` so this cannot regress silently.

---

## D5d-3 🟠 Analytics still records nothing — now for three reasons

The service now reads `user_consents.analytics_consent` correctly. But:

1. **It has no call sites.** `grep -rn "AnalyticsService\|analyticsServiceProvider" lib/`
   excluding its own file returns **nothing**. Zero screen views, zero funnel
   steps. The D5c commit touched `payments_screen.dart`,
   `sim_line_detail_screen.dart` and `sim_lines_list_screen.dart` — but only for
   `context.mounted` guards, not analytics.
2. **The write is denied.** `security_logs` has RLS **enabled with zero
   policies**, so an `authenticated` INSERT is rejected — and `_persistEvent`
   swallows it in `catch (_) {}`. Even if it were called, nothing would land.
3. **Wrong table.** Product telemetry does not belong in a security audit log.
   Give it its own table with its own RLS and retention.

Also: `logScreenView` performs a **network consent read plus an insert on every
navigation** — two round-trips per screen. Cache the consent in memory for the
session and refresh on auth change.

**Fix:** either implement it fully — own table + RLS insert-own policy + cached
consent + real call sites on the screens and the recharge funnel — or delete the
file and mark D5 item 5 openly not-done. This is the second session in a row
where analytics shipped as plumbing that records nothing.

---

## D5d-4 🟠 Uptime monitoring is still not configured

`health` is deployed and returns
`{"status":"healthy","database":"online",…}` — good. But DoD criterion 4 also
required the **external monitor** (UptimeRobot / Better Stack) to be configured
and its confirmation pasted. The D5c report does not claim this was done, and no
evidence exists.

A worker heartbeat upsert was added to `worker_esim_fulfillment.js`, but nothing
reads it and no alert fires when it goes stale.

**Fix:** configure the external monitor on both the `health` URL and a heartbeat
check, paste the confirmation, and add a `system_alerts` rule (or a pg_cron check
like the existing `check_refill_pipeline_health`) that fires when the heartbeat
is older than N minutes. **Deploying a health endpoint nobody watches is not
uptime monitoring.**

---

## D5d-5 🟢 Smaller items

* **`use_build_context_synchronously`**: 14 of the 65 flagged issues were fixed
  (147 → 133). The remaining `use_build_context_synchronously` hits are still the
  largest single class, and they sit in exactly the async payment/wallet paths
  Sentry is being installed to observe. Keep working them down and report the
  per-rule counts, not just the total.
* **Order `41861f0f-…`** was flipped `completed` → `failed` and backfilled. That
  is a defensible reconciliation, but it rewrote a historical record — note it in
  the plan so it is not later read as a real fulfilment failure.
* **Sentry still has no proven crash.** DoD criterion 3 asked for a release-mode
  crash appearing in a Sentry issue URL. That remains blocked on the owner
  supplying a DSN — **owner task**, carry it forward explicitly rather than
  letting it disappear.

---

## Definition of done for D5d

1. Guard trigger is `SECURITY INVOKER`; with the column grant **restored**, an
   `authenticated` update raises **`KS403`** — paste the SQLSTATE, not a label.
2. With grants in their real state, an `authenticated` update raises **`42501`**
   — paste it.
3. A `plan_payments` insert still updates `sim_lines.plan_type` — paste before
   and after.
4. `updateSimLine` succeeds from the running app; paste the edited row. Add a
   test covering it.
5. Analytics either records a real event end-to-end (paste the row) or is deleted.
6. External uptime monitor configured — paste confirmation; heartbeat staleness
   raises an alert.
7. `flutter analyze` and `flutter test` — honest numbers, per-rule counts for the
   lint work.
8. `git ls-remote --heads origin` shows the D5d commit.
