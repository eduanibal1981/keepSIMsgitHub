# D5b — Close the D5 gaps (observability, plan-tier lockdown, reaper correctness)

Written 2026-07-26 after reviewing D5 (local commit `816c80e`) against the live
database, the live edge/worker code, and the original D5 spec.

**D5 delivered 2 of its 6 items, and the two that shipped both contain money or
security defects.** This brief is the fix list. Nothing here is speculative —
every item below was verified live via `execute_sql` / `get_advisors` / `git`.

---

## 0. Ground truth before you start

| Claim in the D5 report | Verified reality |
|---|---|
| "Commit `f19b5df…` verified on origin/main" | `git cat-file -t f19b5df` → **fatal: Not a valid object name**. `git ls-remote --heads origin` → **`fa32d4b`** (D4d). D5 is local commit **`816c80e`**, unpushed. |
| "`flutter analyze`: 0 issues found" | `analysis_options.yaml` was rewritten across 6 commits (`b283f09`…`d8feb05`) to `ignore` 17 rules and exclude `tool/**`. Real baseline is 153–162 infos; **none were fixed**. |
| "`flutter test`: 71/71 passed" | That is D4's number. D5 added **zero** Dart tests. |
| "Migration applied cleanly" | Objects exist live, but `20260801000000` is **absent from `supabase_migrations.schema_migrations`** — fourth migration-ledger drift in this project. |
| "eliminating client-side plan tier tampering" | **False.** See D5b-1. |

Verify every hash with `git cat-file -t <sha>` and every push with
`git ls-remote --heads origin`. Never with `git log`.

---

## D5b-1 🔴 The plan-tier tampering hole is still wide open

Verified live:

* `information_schema.column_privileges` → `authenticated` **and `anon`** both hold
  `UPDATE` on `public.sim_lines.plan_type`.
* RLS policy `Users can update own sim lines` has
  `WITH CHECK ((auth.uid() = user_id) AND (NOT is_user_suspended()))` — **no column
  restriction**.
* `pg_trigger` on `sim_lines` → only `enforce_free_line_limit` and
  `trg_update_line_health`. **Nothing guards `plan_type`.**

⇒ `PATCH /rest/v1/sim_lines?id=eq.<own_line_id>` with `{"plan_type":"premium"}`
still grants a free upgrade with nothing but the publishable key.

The AFTER INSERT trigger D5 added is purely **additive** — it revokes nothing.
And it has never executed: `SELECT count(*) FROM plan_payments` = **0 rows, ever**.

**Fix (all three layers, not one):**
1. `REVOKE UPDATE (plan_type, plan_expires_at) ON public.sim_lines FROM authenticated, anon;`
   (column-level REVOKE — Supabase blanket-grants on new columns; a `GRANT … TO
   service_role` does **not** remove `anon`/`authenticated`. Same defect class as
   D2's `request_esim_purchase` and `06a008d`'s `delete_auth_user_by_id`.)
2. Add a `BEFORE UPDATE` trigger on `sim_lines` that raises when
   `NEW.plan_type IS DISTINCT FROM OLD.plan_type` and the caller is not
   `service_role`/`postgres` — belt and braces, because a future column GRANT
   silently reopens layer 1.
3. Only then does the `plan_payments` trigger become the sole write path.

**Prove it with a negative test**, executed as the `authenticated` role via
`SET LOCAL ROLE authenticated; SET LOCAL request.jwt.claims = …` — the update must
raise. D5's test suite has no negative test at all.

---

## D5b-2 🔴 `reap_stale_esim_orders` refunds the wrong amount

* `request_esim_purchase` (live) debits
  `v_total_cost := retail_price × p_quantity` via
  `debit_wallet_for_topup(…, 'esim_purchase_debit', 'esim_' || order_id)`.
  `p_quantity` is validated `1..3`.
* The reaper credits **`v_order.retail_price_usd`** — the *unit* price.

⇒ A stale 3-unit order refunds one third of what was taken. Silent.

**Fix:** the reaper must refund the amount that was actually debited — read it
from the `wallet_transactions` row keyed `esim_<order_id>` / type
`esim_purchase_debit`, not from a price column. **If no debit row exists, refund
nothing** and raise a `system_alerts` row instead. That single rule also removes
the free-money path D5's own test encoded.

---

## D5b-3 🔴 No idempotency on the new refund type + cross-path double refund

* This repo's established pattern is a partial unique index on
  `wallet_transactions.reference_id` per money type —
  `uq_wallet_txns_esim_debit`, `uq_wallet_transactions_refund_ref`,
  `uq_wallet_transactions_plan_fee_ref`, `uq_wallet_txns_referral_credit_ref`.
  D5 introduced the type `esim_purchase_refund` and added **no index**.
* `credit_wallet` has **zero** dedupe logic — it inserts unconditionally.
* `servers/worker_esim_fulfillment.js:219` refunds the same failure via
  `credit_wallet_for_refund`, ref `esim_refund_<order_id>`, type `refund`.
  The reaper uses ref `ref_reap_<order_id>`, type `esim_purchase_refund`.
  **Different type + different ref ⇒ neither partial index can dedupe against
  the other ⇒ an order reaped and then failed by the worker is refunded twice.**

**Fix:** one refund reference scheme (`esim_refund_<order_id>`) and one type for
the eSIM path, plus the matching partial unique index, plus a guard in the reaper
that skips any order already carrying a refund row.

Note also that `credit_wallet` increments `wallets.total_deposited` on every
credit — refunds will inflate lifetime-deposit accounting. Use the refund-aware
helper (`credit_wallet_for_refund`) or fix the accounting.

---

## D5b-4 🟠 Reaper/worker race → user keeps the refund *and* gets the eSIM

`worker_esim_fulfillment.js:126-137` claims an order with
`.update({status:'processing'}).eq('id', …).eq('status','pending')` and then only
checks `markErr`. PostgREST returns **no error when zero rows match**, so if the
reaper flipped the row to `failed` first, the worker proceeds to call eSIM Go and
insert `user_esims` anyway.

**Fix:** (a) worker must `.select('id')` on the claim and `continue` when the
result is empty; (b) reaper must skip rows with `provider_order_ref IS NOT NULL`;
(c) reaper's cursor should use `FOR UPDATE SKIP LOCKED`.

Also reconsider the 1-hour window: the worker polls continuously, so 1 h of
backlog means the worker is down — reaping then races the recovery. 2–3 h with
the `provider_order_ref` guard is safer, and the threshold belongs in
`system_configs` (`ESIM_STALE_ORDER_HOURS`), consistent with this project's
"change it in the DB, no redeploy" doctrine.

---

## D5b-5 🔴 `request_esim_purchase` is broken live — the reaper guards a queue that cannot fill

Live `public.esim_orders` columns:
`id, user_id, provider, bundle_name, quantity, wholesale_price_usd,
retail_price_usd, markup_percent, status, provider_order_ref, error_message,
created_at, updated_at`.

Live `request_esim_purchase` inserts:
`(user_id, offer_id, quantity, wholesale_price_usd, retail_price_usd,
total_amount_usd, status)`.

**`offer_id` and `total_amount_usd` do not exist.** Every eSIM purchase raises
`column "offer_id" of relation "esim_orders" does not exist`. Live counts confirm
it: 1 order total, **0 pending**, 1 debit, 0 refunds.

`worker_esim_fulfillment.js` compounds the drift — it reads `order.bundle_name`
and joins `esim_offers_cache` on `bundle_name`, while the RPC was written to
store `offer_id`.

D5's test never caught this because it **bypasses the RPC** and hand-inserts into
`esim_orders`.

**Fix:** reconcile the three (table ↔ RPC ↔ worker) in one migration — add
`offer_id text` + `total_amount_usd numeric(10,2)` to `esim_orders` and keep
`bundle_name` populated, or rewrite the RPC to the current columns. Then make the
D5b test suite drive the **real RPC**, never a hand-rolled INSERT.

---

## D5b-6 🟠 Trigger correctness + `search_path`

`get_advisors('security')` now reports **2 net-new**
`function_search_path_mutable` findings:
`public.trg_fn_apply_plan_tier_from_payment` and `public.reap_stale_esim_orders`.
Every other money function here (`credit_wallet`, `request_esim_purchase`,
`purge_deleted_accounts`) carries `SET search_path TO ''`. D3's standard was
0 net-new findings.

`trg_fn_apply_plan_tier_from_payment` additionally:
* has **no whitelist** on `metadata->>'plan'` — any string lands in `plan_type`;
* **never checks the payment is captured/settled** — it fires on a bare INSERT;
* **never checks `NEW.user_id` owns `NEW.sim_line_id`**;
* is an unguarded `AFTER INSERT`, so **any exception rolls back the
  `plan_payments` row itself** — a captured PayPal payment would be lost while
  PayPal keeps the money. Wrap the `sim_lines` UPDATE in
  `BEGIN … EXCEPTION WHEN OTHERS THEN <insert system_alerts> END;`.
* should also set `plan_expires_at` (yearly, per C3c) — right now the tier
  changes but the expiry does not.

---

## D5b-7 🔴 Observability — the actual point of D5 — is a net regression

`pubspec.yaml` contains **no** `sentry_flutter`, `firebase_crashlytics`, or
`firebase_analytics`. `lib/main.dart:31-41` only `debugPrint`s, and
`platformDispatcher.onError` **returns `true` for every async error** — marking
it handled with no sink. In a release build nothing collects `debugPrint`, so
D5 made async failures *less* visible than before it landed.

**Fix:** wire a real sink (Sentry is the lighter lift — one package, a DSN in
Edge-Function-style config, no `google-services.json` dependency, and it works on
iOS where Firebase is currently inert by design per C1b). Then:
`runZonedGuarded` around `runApp`, `FlutterError.onError` → sink,
`platformDispatcher.onError` → sink **then** return `true`,
`Isolate.current.addErrorListener`, release-only gating, and PII scrubbing
(this app handles wallets, phone numbers, ICCIDs — `beforeSend` must strip them).

---

## D5b-8 🟠 `pm2 save` without `pm2 startup` does not survive a reboot

D5 ran `pm2 save`, which only writes the process list to `~/.pm2/dump.pm2`.
Without `pm2 startup` installing the systemd unit, nothing reads that dump at
boot — **a GCE reboot still silently kills all 7 workers**, which is precisely the
failure D5 existed to prevent. The plan's own line 47 says `pm2 startup/save`.

**Fix on the VM (`34.185.194.90`, user `abdal`, `/home/abdal/keepsims_backend`):**
run `pm2 startup systemd`, execute the `sudo env PATH=… pm2 startup systemd -u
abdal --hp /home/abdal` command it prints, then `pm2 save`, then **prove it** with
`systemctl is-enabled pm2-abdal` and a real `sudo reboot` followed by
`pm2 list` showing 7 online. A `pm2 save` that was never proven across a reboot
is not persistence.

---

## D5b-9 🟠 Restore the analyzer as a real signal

`analysis_options.yaml` currently ignores 17 rules and excludes `tool/**` — which
is where D4's `verify_release_bundle` secret scanner lives. Two of the muted rules
matter for a payments app about to ship:

* `use_build_context_synchronously` — a genuine crash class across the async
  PayPal/wallet flows;
* `deprecated_member_use` — hides API removals right before a store submission.

The file also self-cancels: `linter.rules` enables `avoid_print` and
`prefer_single_quotes` while `analyzer.errors` sets both to `ignore`.

**Fix:** drop `exclude: tool/**`; un-ignore `use_build_context_synchronously` and
`deprecated_member_use` and **actually fix** those hits; keep the generated-file
excludes (`*.g.dart`, `*.freezed.dart`) which are legitimate; remove the
contradictory `ignore` entries for rules the linter section enables. Report the
honest number. A truthful `153 infos / 0 errors` is worth more than a
manufactured `0 issues`.

---

## Remaining D5 items still owed (untouched)

* **`system_alerts` → C1 push** (spec item 4) — the reaper writes alerts nobody
  is paged for. The `trg_fn_dispatch_notification` → `dispatch-alert` path from C1
  already exists; `system_alerts` → power users is wired, so confirm
  `stale_esim_order_reaped` actually routes, don't assume.
* **External uptime monitor** (spec item 3) — UptimeRobot/Better Stack on a
  worker heartbeat endpoint **and** on Supabase Edge health.
* **Basic analytics** (spec item 5) — screen views + recharge funnel, gated on the
  `promo`/consent flag (`user_consents`, default `false`, per D3b).

---

## Definition of done for D5b

1. A logged-in user **cannot** change `sim_lines.plan_type` — proven by a negative
   test that runs as `authenticated` and expects a raise.
2. The reaper refunds exactly the debited amount, or nothing plus an alert.
3. Running the reaper twice on the same order credits once — proven.
4. `request_esim_purchase` completes end-to-end against the real table, and the
   D5b test suite drives the **RPC**, not hand-inserts.
5. `get_advisors('security')`: **0 net-new** findings vs the pre-D5b baseline.
6. Migration `20260801000000` **and** the new D5b migration are both registered in
   `supabase_migrations.schema_migrations`.
7. A crash in release reaches a dashboard you can open.
8. `systemctl is-enabled pm2-abdal` → `enabled`, and 7 workers online after a real
   reboot.
9. `git ls-remote --heads origin` shows the D5b commit. Paste that output.
