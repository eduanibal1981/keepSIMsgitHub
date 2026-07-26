# D5c — Close out D5b (fail-closed tamper guard, real Sentry sink, deploy health, real analytics)

Written 2026-07-26 after reviewing D5b (commit `3a44430`, **push verified real**:
`git ls-remote --heads origin` → `3a444306b8eb28499cc33357eee5543340cc1041`).

**D5b is a genuine improvement — most of it holds up under live probing.** What
follows is the remaining 5 gaps plus residue cleanup. Nothing here is
speculative; each item was verified against the live database, the deployed
function list, or the running app source.

---

## What D5b got right (do not re-do, do not regress)

Verified live, not taken on report:

* **The plan-tier exploit is genuinely closed on the real path.** Probed by
  simulating PostgREST — `SET LOCAL ROLE authenticated` +
  `request.jwt.claims = '{"sub":…,"role":"authenticated"}'` then
  `UPDATE public.sim_lines SET plan_type='premium'` → **`BLOCKED [KS403]`**.
* **The reaper is now correct**: reads the exact debit row
  (`reference_id = 'esim_'||order_id`, type `esim_purchase_debit`); no debit ⇒
  **no refund** + a `stale_esim_order_unpaid` alert; `FOR UPDATE SKIP LOCKED`;
  skips `provider_order_ref IS NOT NULL`; threshold from
  `system_configs.ESIM_STALE_ORDER_HOURS` (=3); refund ref/type unified with the
  worker (`esim_refund_<id>` / `esim_purchase_refund`) and backed by the new
  partial unique index `uq_wallet_txns_esim_refund_ref`.
* **Worker claim fixed**: `.select('id')` + empty-array check, so a reaped order
  can no longer be fulfilled after the fact.
* **`esim_orders` reconciled** — `offer_id` + `total_amount_usd` exist and
  `request_esim_purchase` now inserts them.
* Both new functions carry `SET search_path TO ''`; **both** migrations
  (`20260801000000`, `20260801010000`) are registered in `schema_migrations`;
  `get_advisors('security')` shows no net-new findings.
* **The analyzer is honest again**: `flutter analyze` reproduces at
  **147 issues, 0 errors** with `tool/**` back in scope.
* `a1-wallet-test@example.com` balance intact at **$35.86**.

---

## D5c-1 🔴 The tamper guard is FAIL-OPEN

`trg_fn_prevent_sim_line_plan_tampering` blocks on
`IF auth.role() IN ('authenticated','anon')`.

When `auth.role()` returns NULL, `NULL IN (…)` evaluates to NULL, the `IF` is not
taken, and **the update is allowed**. Probed live, same transaction, same row:

| Probe | Result |
|---|---|
| role `authenticated` **+** `request.jwt.claims` set | `BLOCKED [KS403]` ✅ |
| role `authenticated`, `request.jwt.claims` **empty** | **`EXPLOIT SUCCEEDED`** ❌ |

This is a deny-list keyed on a GUC that may be absent, in a project whose own
doctrine is fail-closed (D3b's `purge-accounts` fix was explicitly
"fail-CLOSED secret"). It matters concretely because **A2 JWT rotation is still
pending** and changes how claims are populated.

**Fix:** invert to an allow-list on the *real* Postgres role, which is never NULL:

```sql
IF current_user NOT IN ('service_role', 'postgres', 'supabase_admin') THEN
  RAISE EXCEPTION 'Direct modification of plan_type or plan_expires_at is forbidden.'
    USING ERRCODE = 'KS403';
END IF;
```

Then re-run **both** probes above and paste both outputs. Case B must also read
`BLOCKED`.

---

## D5c-2 🟠 The column REVOKE was a silent no-op

D5b reported "Revoked `UPDATE (plan_type, plan_expires_at)` … from
`authenticated` and `anon`". Live state says otherwise:
`information_schema.column_privileges` still returns **4 rows**, because
`information_schema.role_table_grants` shows `authenticated` **and** `anon` still
hold **table-level** `UPDATE` on `public.sim_lines`.

Postgres does not let a column-level `REVOKE` remove a table-level privilege —
the statement succeeds and changes nothing. So Layer 1 does not exist, and the
fail-open trigger from D5c-1 is the *only* thing standing between a user and a
free premium plan.

**Fix:** either `REVOKE UPDATE ON public.sim_lines FROM authenticated, anon;`
followed by an explicit column-list `GRANT UPDATE (…) ` of exactly the columns
clients may write, or accept the trigger as the sole control — but then it must
be fail-closed per D5c-1 and that decision should be written down. Do not report
a REVOKE as effective without re-reading `role_table_grants` afterwards.

---

## D5c-3 🔴 Sentry is plumbing with no proven sink

[lib/main.dart:38-41](lib/main.dart#L38):

```dart
options.dsn = const String.fromEnvironment(
  'SENTRY_DSN',
  defaultValue: 'https://placeholder_key@o0.ingest.sentry.io/0',
);
```

* Nothing in `android/app/build.gradle.kts` or any CI step passes
  `--dart-define=SENTRY_DSN=…`, so **a release build initialises Sentry against a
  non-existent project and silently drops every event** — the same blindness D5
  had, now wearing a green badge.
* The D5b report never claims a test crash was seen in a dashboard. The handoff's
  definition of done was *"a crash in release reaches a dashboard you can open"*.
  That is **unmet**.
* `beforeSend` scrubs **only `event.extra`**. It does not touch `breadcrumbs`
  (the Sentry SDK auto-captures HTTP breadcrumbs — Supabase REST URLs carry
  `?phone=eq.…`, `?id=eq.<uuid>`), `event.exceptions[].value` (a thrown message
  containing an ICCID or amount passes straight through), `event.contexts`, or
  `event.user`.
* `options.tracesSampleRate = kReleaseMode ? 0.2 : 1.0` — 20 % performance
  tracing in production will exhaust a free-tier transaction quota quickly.

**Fix:**
1. Owner creates the Sentry project and supplies the DSN (**owner task** — add it
   to the checklist next to the other secrets; it is not a secret in the Edge
   Function sense, but it must not be a placeholder).
2. Make a missing DSN **loud, not silent**: if the define is empty, skip
   `SentryFlutter.init` and `debugPrint` a warning, rather than initialising a
   dead client.
3. Wire the dart-define into the release build so an AAB cannot ship without it.
4. Extend `beforeSend` to breadcrumbs, exception values and contexts; set
   `options.sendDefaultPii = false` explicitly.
5. Drop `tracesSampleRate` to ≤ 0.05 in release.
6. **Prove it**: trigger a real crash in a release-mode build and paste the
   Sentry issue id/URL.

---

## D5c-4 🔴 The `health` function was never deployed, and no uptime monitor exists

`supabase/functions/health/index.ts` is in the repo. The deployed function list
(MCP `list_edge_functions`) has 13 entries — `dispatch-alert`, `paypal-webhook`,
`purge-accounts`, `create-paypal-order`, `capture-paypal-order`, … — and **no
`health`**. An endpoint that is not deployed cannot be monitored.

This repeats the D4c failure mode recorded in memory: correct code written,
never deployed, reported as done.

**Fix:** deploy it (`verify_jwt: false`, or an external monitor cannot reach it),
`curl` the live URL and paste the response, then actually configure the external
monitor (UptimeRobot / Better Stack) on **both** the Edge health URL and a worker
heartbeat, and paste the monitor's confirmation. Also confirm the worker
heartbeat surface exists — the plan asks for one and D5b did not add it.

---

## D5c-5 🟠 `analytics_service.dart` is a stub wired to nothing

[lib/core/services/analytics_service.dart](lib/core/services/analytics_service.dart):

* Both methods only `debugPrint` — there is **no analytics backend**.
* `grep` for `AnalyticsService` across `lib/` returns **no usages outside the file
  itself** — zero screen views and zero funnel steps are ever recorded.
* Consent is read from a **SharedPreferences** key
  `analytics_tracking_consent_enabled` that nothing in the app writes. The
  handoff specified the `user_consents` **table** (created in D3b, default
  `false`), which is the compliance-relevant source.

**Fix:** either implement it properly — a real sink, consent read from
`user_consents`, and call sites on the screens and the recharge funnel — or
delete the file and leave D5 item 5 openly marked not-done. A stub that reads a
key nobody sets is worse than an honest gap, because it looks like coverage.

---

## D5c-6 🟠 Committed test residue (third occurrence in this project)

`supabase/tests/d5b_plan_tier_and_reaper_tests.sql` is correctly written as
`BEGIN;` (line 2) … `ROLLBACK;` (line 178). The data was committed anyway:

| Object | Residue |
|---|---|
| `auth.users` / `profiles` / `wallets` | fabricated user `a1111111-1111-1111-1111-111111111111` |
| `wallet_transactions` | 2 rows for that user (incl. 1 `esim_purchase_refund`) |
| `sim_lines` | 1 row |
| `esim_orders` | 2 rows — `d5b_offer_101`, `"D5b Test Unpaid"` |
| `system_alerts` | 2 rows (`stale_esim_order_reaped`, `stale_esim_order_unpaid`) |

**Root cause:** MCP `execute_sql` runs each call in its own transaction, so a
suite split across calls never pairs its `BEGIN` with its `ROLLBACK`. Run the
whole file as **one** `execute_sql` call, or seed committed fixtures and delete
them explicitly in a teardown.

**Fix:** delete the residue (verify `a1-wallet-test@example.com` stays at
**$35.86** and that the real order `41861f0f-…` is untouched), and re-run the
suite as a single call to prove it leaves nothing behind.

While there: **backfill** `offer_id` / `total_amount_usd` on the pre-existing
order `41861f0f-a5ad-4755-96c4-0a1c28e7e3d0` (both NULL), which is also sitting
at `status='completed'` with `error_message = 'ESIM_GO_API_KEY is not configured
in servers/.env'` — one of those two fields is lying.

---

## D5c-7 🟠 The un-ignored lint rules were exposed but never fixed

D5b correctly stopped muting `use_build_context_synchronously` and
`deprecated_member_use` — that part is honest and welcome. But the hits were not
addressed. Of the 147 issues, independently counted:

* **48 × `use_build_context_synchronously`**
* **17 × `deprecated_member_use`**

— i.e. **65 of 147 issues are exactly the two classes the previous session was
asked to fix.** `use_build_context_synchronously` is a genuine crash class
(`BuildContext` used after an `await`), and this app's async gaps are in the
wallet, PayPal checkout and refill flows. That is the single most likely source
of the crashes Sentry is being installed to catch.

**Fix:** work the 48 down (guard with `if (!context.mounted) return;` after each
await, or capture `Navigator`/`ScaffoldMessenger` before the gap). Prioritise
`lib/features/payments/`, `lib/features/wallet/` and the refill sheets. Report
the honest before/after counts. The 17 deprecations can follow.

---

## D5c-8 🟢 Small correctness nits

* `reap_stale_esim_orders`: `v_reaped_count` is incremented **only** in the
  refund branch, so unpaid reaps are invisible in the return value. Return both
  counts.
* The debit lookup is `SELECT amount … LIMIT 1` with no `status = 'completed'`
  filter — a reversed or failed debit would still be refunded.
* Confirm `stale_esim_order_reaped` / `stale_esim_order_unpaid` actually reach a
  human through the C1 dispatcher (`system_alerts` → power users is wired, but
  D5b never verified these two kinds route). Insert one and show the
  `notification_deliveries` row.

---

## Definition of done for D5c

1. **Both** tamper probes (with and without `request.jwt.claims`) return
   `BLOCKED` — paste both.
2. `role_table_grants` re-read after the grant change — paste it.
3. A real crash from a release-mode build appears in Sentry — paste the issue URL.
4. `curl` against the deployed `health` URL returns 200 — paste it; and the
   external monitor is configured — paste its confirmation.
5. Analytics is either wired end-to-end with `user_consents` gating **or**
   deleted and marked not-done.
6. Residue gone; suite re-run as one call leaves zero rows; a1 wallet = $35.86.
7. `flutter analyze` — report the honest number, no new ignores.
8. `git ls-remote --heads origin` shows the D5c commit. (D5b did this correctly;
   keep it up.)
