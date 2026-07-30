# KeepSIMs — Production Plan Review & Phase F Plan

**Reviewed:** 2026-07-27 · against `doc/PRODUCTION_PLAN.md` (A–E), the D1–D5e handoff
records, and the **live** project `zwxswagokhgbuzrrbnhr` + working tree at `ce2a844`.

**How this review was produced (so nothing here is a claim you have to take on faith):**
every finding below is either (a) a live SQL/`curl` probe whose exact output is quoted,
(b) a file:line in the working tree, or (c) a live row count. Nothing was accepted from a
previous session's report. Where I could not prove something without creating production
residue, it is labelled **CONFIRMED-BY-GRANT** or **UNVERIFIED**, never "done".

Baseline re-measured this session: `flutter analyze` → **134 issues, 0 errors** (101.9 s),
working tree clean at `ce2a844`, 69,750 lines of hand-written Dart, 9 locales, 8 PM2 workers.

> ## ✅ STATUS UPDATE — 2026-07-29 · Phase F0 (the grant lockdown) is COMPLETE
> **All six 🔴 findings in §1 are closed and pushed. There are no known live security holes.**
>
> | | closed by | commit |
> |---|---|---|
> | F-1 wallet minting | `20260801040000` | `3acec84` |
> | F-2 wallet draining | `20260801050000` + `20260801060000` | `7bb72a0` |
> | F-3 · F-4 · F-5 · F-6 · F0.6 | `20260801070000` … `20260801100000` | `2e4039e` |
>
> Two further live holes were found *while verifying* F-4 and F-6 and are fixed in the same
> commit — neither was in this review (see the 🆕 blocks in §1). One item in this document was
> **wrong** and is corrected in place: see *"F0.3 — partly a mistake"* under §5.
>
> Current advisor count: **29**, down from 47. Reported honestly — it is not zero and was never
> going to be; the residue is enumerated in `doc/RLS_MATRIX.md` as accepted exceptions.
> Baselines now: `flutter test` **76/76**, `flutter analyze` **134**, a1 wallet **$35.86**.
>
> **Still needs the owner:** enable HaveIBeenPwned leaked-password protection
> (Dashboard → Auth → Passwords). No API or SQL toggle exists. See §7 item 11.

---

## 0. Executive verdict

The plan is **well written and the engineering behind A–D is real** — the money path is
atomic and idempotent, RLS on the money tables holds, the refill pipeline is genuinely
server-priced, and D5e's observability chain is live (worker heartbeat measured at 0.0 min
age this session, 8 pg_cron jobs scheduled, `health` returns 503 on a stale worker).

Two things are nevertheless true:

1. **🔴 There is a live, unauthenticated money hole that every phase from A1 to D5e walked
   past.** A1/B2 revoked *table* writes on `wallets`, but never revoked the *function*
   grants. `debit_wallet_for_topup` is executable by **`anon`** and `credit_wallet_for_refund`
   by **`authenticated`**, both `SECURITY DEFINER`, both taking `p_user_id` and `p_amount` as
   arguments with **no caller check whatsoever**. Proven live below. This outranks everything
   else in this document.

   > **✅ CLOSED 2026-07-29.** Both, plus the four other grant findings, plus two holes this
   > review missed. The diagnosis above was correct and its root cause — *"swept tables, never
   > sweept functions"* — turned out to describe a whole class, not two functions: **12** RPCs
   > were anon-callable and **five** client-facing tables still carried the default
   > `GRANT ALL`. The class is now closed by assertion, not by inspection:
   > `supabase/tests/f0_grant_matrix_tests.sql` fails the build if any `SECURITY DEFINER`
   > function in `public` is callable by `anon`/`PUBLIC` or is not on an explicit allow-list.

2. **The four headline objectives are coded but barely *operating*.** Notifications, offline
   refill and eSIM fulfilment are all "shipped" in the plan: **18 of the last 31 push
   dispatches reached nobody on any channel**, email and Telegram are disabled for every user,
   **0** offline refill events have ever been ingested, and the only eSIM order in the database
   was fulfilled with a fake provider reference. The gap is roughly half owner-provisioning and
   half a missing "prove it end-to-end with a real recipient" step that no phase ever owned.

The plan's phase order was right. What it lacks is a **phase that proves the product works
for a real user on a real device**, which is what Phase F below is.

---

## 1. 🔴 Live findings (fix before anything else)

### F-1 · Any signed-in user can mint unlimited wallet balance — **CONFIRMED-BY-GRANT**

```
credit_wallet_for_refund(p_user_id uuid, p_amount numeric, p_reference_id text,
                         p_description text, p_sim_line_id uuid, p_type text)
  prosecdef = true
  acl       = postgres=X/postgres authenticated=X/postgres service_role=X/postgres
```

The body (read live from `pg_proc`) validates only `p_amount > 0` and that the wallet exists.
There is **no `auth.uid()` check, no ownership check, no reference-idempotency check**. Any
account that can sign up can `POST /rest/v1/rpc/credit_wallet_for_refund` with its own
`user_id` and `p_amount: 100000` and the balance is created out of nothing, with a matching
`wallet_transactions` row that looks legitimate in the ledger.

Probed as `anon` → `42501 permission denied` (expected: the grant is to `authenticated`, not
`anon`). Proving it end-to-end needs a real user JWT; I did **not** create a throwaway
production account to demo it, because the grant plus the body is already conclusive and the
last thing this project needs is more test residue. The one-line proof for the fix session:

```bash
curl -s -X POST "$URL/rest/v1/rpc/credit_wallet_for_refund" -H "apikey: $ANON" -H "Authorization: Bearer $USER_JWT" -H 'Content-Type: application/json' -d '{"p_user_id":"<self>","p_amount":-1,"p_reference_id":"probe","p_description":"probe","p_sim_line_id":null,"p_type":"refund"}'
```

A negative amount is non-mutating: `P0001 Refund amount must be positive` means the grant is
still open; `42501` means it is fixed.

> **✅ RESOLVED 2026-07-29** — migration `20260801040000_f1_credit_wallet_refund_grant_lockdown.sql`
> (registered in `schema_migrations` at version `20260801040000`, i.e. *after* the
> `20260801010000` that introduced the grant, so a replay cannot re-open it).
>
> * **Layer 1** — `REVOKE ALL … FROM PUBLIC, anon, authenticated`; `GRANT EXECUTE … TO service_role`.
>   ACL is now `{postgres=X/postgres,service_role=X/postgres}`.
> * **Layer 2** — in-body guard that rejects any call arriving with a `request.jwt.claims`
>   role other than `service_role` (`ERRCODE = 'KS403'`). Note the guard suggested above
>   (`auth.uid() <> p_user_id`) would **not** have stopped this exploit — the attacker credits
>   their own wallet, so the ids match. It also cannot key on `current_user`, which is the
>   owner inside a `SECURITY DEFINER` body (that is what made D5c's tamper guard dead code).
> * **Acceptance probe, run live with a real user JWT** (a1 fixture, `p_amount:-1`):
>   `{"code":"42501","message":"permission denied for function credit_wallet_for_refund"}` — HTTP 403.
>   Same call as `anon` → `42501`/401. Control: the same JWT still gets HTTP 200 from
>   `get_wallet_forecast`, balance `35.86`.
> * **Layer 2 proven independently** (grant restored inside a rolled-back txn, so only the
>   guard can block): `SET LOCAL ROLE authenticated` + exploit → `BLOCKED [KS403]`, balance
>   `35.86 → 35.86`. Defence in depth is real, not asserted.
> * Regression test: `supabase/tests/f1_wallet_refund_grant_tests.sql`, 11/11.
> * No caller changed: nothing in `lib/` calls this RPC; the callers are
>   `worker_instant_refill.js:270`, `worker_esim_fulfillment.js:241` (both service_role) and
>   `reap_stale_esim_orders()` (SECURITY DEFINER, no JWT claims). Both shapes covered by the tests.
>
> ~~**F-2 through F-6 below are still open** — this session closed F-1 only.~~
> **Superseded 2026-07-29: F-2 through F-6 are now closed too. See each section.**

### F-2 · Anyone holding the public anon key can drain any wallet — **PROVEN LIVE**

The anon key ships inside the APK (`lib/core/supabase_client.dart:26`), so "anyone" is literal.

```bash
POST /rest/v1/rpc/debit_wallet_for_topup   # apikey + Authorization: <anon key>
{"p_user_id":"00000000-...","p_amount":-1,"p_reference_id":"probe_readonly", ...}
→ HTTP 400 {"code":"P0001","message":"Debit amount must be positive, got -1"}
```

HTTP 400 with a `P0001` raised **from inside the function body** proves the call passed the
permission check and executed. With a positive amount and a real `p_user_id`, it debits that
user's wallet and writes an arbitrary `type` string into the ledger. `acl` confirms:
`=X/postgres` (PUBLIC) `anon=X/postgres authenticated=X/postgres`.

Note this is the **6-argument overload**. The 5-argument one is correctly `service_role`-only —
which is exactly how it slipped through: someone revoked the old signature and the new one
inherited the default `GRANT EXECUTE TO PUBLIC`.

> **✅ RESOLVED 2026-07-29** — migrations `20260801050000_f2_debit_wallet_grant_lockdown.sql`
> and `20260801060000_f2b_drop_ambiguous_debit_overload.sql` (both registered, both sorting
> after the D5b work that created the overload).
>
> * **Reproduced first.** With only the anon key: `P0001 "Debit amount must be positive, got -1"`,
>   HTTP 400 — raised from inside the body, so permission had passed. After the fix, every
>   payload shape returns `42501 permission denied for function debit_wallet_for_topup`.
> * **Layer 1** — `REVOKE ALL … FROM PUBLIC, anon, authenticated`, `GRANT EXECUTE … TO service_role`.
> * **Layer 2** — in-body guard, but **not** the same shape as F-1's. This function is called
>   from *inside* `request_esim_purchase` and `pay_plan_fee_from_wallet`, which signed-in users
>   invoke directly; `request.jwt.claims` still reads `role=authenticated` in those nested
>   calls, so F-1's "reject any non-service_role JWT" would have broken every eSIM purchase and
>   plan-fee payment. The discriminator used is **plpgsql call depth** (`GET DIAGNOSTICS PG_CONTEXT`):
>   a PostgREST RPC is always the top frame, an internal call never is.
> * **Layer 2 proven on its own** (grant restored inside a rolled-back txn, real `SET LOCAL ROLE`,
>   top-level statement): authenticated → `KS403`; anon → `KS403`; malformed claims → `22P02`
>   at the claims cast, i.e. fail-closed before any balance is touched.
> * Regression test `supabase/tests/f2_debit_wallet_grant_tests.sql` — Part A 7/7 including a
>   real nested debit (a1 `35.86 → 33.36 → 35.86`, rolled back), Part B the three direct-call
>   probes. **Part B cannot live inside a `DO` block**: a `DO` block is itself a frame, so an
>   in-block "direct call" probe passes vacuously. Found the hard way.
>
> **🔴 Second, unrelated defect found while fixing this — the overload had already broken both
> money paths.** PostgREST resolves an RPC overload from the request body's keys, on signature
> alone (it does *not* filter candidates by `EXECUTE` privilege — confirmed live). Neither real
> caller sends `p_txn_type`, so neither payload could be resolved:
>
> ```
> worker_instant_refill.js:161        5 keys -> HTTP 300 PGRST203 "Could not choose the best candidate function"
> supabase/functions/wallet_transact  4 keys -> HTTP 300 PGRST203
> ```
>
> The 6-arg overload was created **live via execute_sql during D5b on 2026-07-26** and never
> existed as a migration file (the fifth such drift). The last successful refill was
> **2026-07-21**, which is why nobody had hit it — the next real instant refill would have
> failed at the debit step. Dropping the 5-arg overload (F0 item 1, now evidence-backed rather
> than precautionary) resolves both callers to the single remaining function, where
> `p_txn_type` defaults to `topup_debit` — byte-identical to what the 5-arg wrote. No worker or
> Edge Function code change was needed.

### F-3 · `purge_deleted_accounts()` is callable by `anon` — **PROVEN LIVE** (`HTTP 200`)

D3's purge state machine can be advanced on demand by an unauthenticated caller. The body
does gate on `scheduled_purge_at <= clock_timestamp()`, so it cannot skip the 14-day grace
window — the damage is bounded to "an attacker controls *when* the hourly job effectively
runs" plus a free unauthenticated compute loop (it iterates all `frozen`/`draining` rows and
calls the Admin API per row). It must still be `service_role`-only.

> **✅ RESOLVED 2026-07-29** — migration `20260801070000_f3_f4_rpc_grant_lockdown.sql`.
>
> * **Reproduced first**, exactly as described: anon `POST /rest/v1/rpc/purge_deleted_accounts`
>   → `HTTP 200`. After the fix, `42501 permission denied for function purge_deleted_accounts`
>   (HTTP 401).
> * **Layer 1** — `REVOKE ALL … FROM PUBLIC, anon, authenticated` + `GRANT … TO service_role`.
> * **Layer 2** — the F-1 guard shape (reject any JWT whose role is not `service_role`). This is
>   the right shape here because the only caller is `cron.job` 10, which runs with no JWT at
>   all; nothing in `lib/`, `servers/` or `supabase/functions/` calls it. Verified by grep.
> * **Layer 2 proven on its own** (grant restored inside a rolled-back txn, top-level statement,
>   `SET LOCAL ROLE authenticated`): `KS403 purge_deleted_accounts is not callable by role
>   authenticated`. Malformed claims → `22P02` raised at the claims cast on line 14, i.e.
>   **before** the deletion state machine runs — fail-closed.
> * Regression test: `supabase/tests/f3_f4_rpc_grant_tests.sql` (Part A T1/T3, Part B P4/P6).

### F-4 · `consume_rate_limit` / `enforce_rate_limit` are callable by `anon` with an arbitrary key — **PROVEN LIVE**

```bash
POST /rest/v1/rpc/consume_rate_limit {"p_bucket":"probe_bucket_readonly","p_key":"probe","p_capacity":0,"p_refill_per_minute":0}
→ [{"allowed":true,"retry_after_seconds":0}]
```

The bucket *and the key* are caller-supplied. An attacker can spend another user's tokens on
`instant_refill`, `esim_purchase`, `plan_fee`, `wallet_deduct` and lock that user out of every
money path — D2's own rate limiter turned into a denial-of-service weapon. Also anon-callable
and equally wrong: `prune_rate_limit_data()`, `check_rate_limit_health()`, `export_user_data()`,
`is_power_user()`, `apply_referral()`, `request_account_deletion()`, `cancel_account_deletion()`,
`redeem_referral_points()`, `trg_fn_award_referral_points()`.

> **✅ RESOLVED 2026-07-29** — migrations `20260801070000_f3_f4_rpc_grant_lockdown.sql` and
> `20260801100000_f4b_is_power_user_security_invoker.sql`.
>
> **All 12 reproduced first.** Anon over HTTP: `consume_rate_limit` →
> `[{"allowed":true,...}]`; `enforce_rate_limit` → `KS429 RATE_LIMITED:…:360` (i.e. it ran and
> drained the bucket); `prune_rate_limit_data` / `check_rate_limit_health` → `204`;
> `export_user_data` / `cancel_account_deletion` / `redeem_referral_points` /
> `request_account_deletion` → `200 {"error":"UNAUTHORIZED"}` (executed, self-blocked);
> `is_power_user` → `false`; `apply_referral` → **`{"success": true}`**. After the fix all
> eleven REST-reachable ones return `42501`.
>
> ⚠️ **Four of this review's own probe payloads were wrong** and would have read as "already
> blocked": `is_power_user`, `apply_referral`, `request_account_deletion` and
> `trg_fn_award_referral_points` return **`PGRST202`** for the parameter names used above —
> that is *schema-cache miss on bad param names*, not a permission denial. The real signatures
> are `is_power_user(user_id)`, `apply_referral(p_referral_code, p_referred_id)`,
> `request_account_deletion(p_forfeit_dust, p_reason)`. Re-derive from `pg_proc` before
> concluding anything from a probe.
>
> **Guard shapes — the trap here was worse than F-2's.**
> * `enforce_rate_limit` is called from inside six user-facing money RPCs and has **no**
>   legitimate top-level caller. `consume_rate_limit` is called nested from `apply_referral`
>   and `enforce_rate_limit`, **and top-level as `service_role` by five Edge Functions**
>   (`create-paypal-order:63`, `capture-paypal-order:61`, `detect-country:102`,
>   `paypal-webhook:346`, `sms-webhook:81` — all verified to use `SUPABASE_SERVICE_ROLE_KEY`).
>   So the guard is the F-2 call-depth check **plus** a `service_role` escape hatch: allow
>   `service_role` at any depth, allow anyone nested, refuse only a non-`service_role` JWT at
>   the top frame. A depth-only guard would have broken all five Edge Functions.
> * 🔴 **`enforce_rate_limit` ends in `EXCEPTION … WHEN OTHERS THEN RAISE NOTICE`.** That
>   catch-all silently swallows a `KS403` raised by its own guard *and* any `KS403` bubbling up
>   out of `consume_rate_limit` beneath it — leaving the guard as dead code **and disabling
>   rate limiting entirely**, failing open on every money path. It needs an explicit
>   `WHEN SQLSTATE 'KS403' THEN RAISE;` next to the existing KS429 branch. **General rule:
>   check for a catch-all handler before adding a guard to an existing function.**
> * `purge_deleted_accounts`, `prune_rate_limit_data`, `check_rate_limit_health` → F-1 shape
>   (cron-only). `trg_fn_award_referral_points` → `service_role` only; Postgres additionally
>   refuses a direct call to a trigger function with `0A000`.
>
> **Layer 2 proven on its own** (grant restored in a rolled-back txn, top-level statements):
> `consume_rate_limit` → `KS403` as both `authenticated` and `anon`; `enforce_rate_limit` →
> `KS403` **(which also proves the KS403 branch beats the `WHEN OTHERS`)**;
> `prune_rate_limit_data` / `check_rate_limit_health` → `KS403`. Legitimate paths re-verified:
> nested plan fee debits a1 `35.86 → 33.36`, and `service_role` top-level `consume` still
> returns `allowed:true`.
>
> Regression test: `supabase/tests/f3_f4_rpc_grant_tests.sql`, **9/9** + six Part-B probes.

> ### 🆕 F-4a · `apply_referral()` was an unauthenticated write to **any** user's profile
> **Not in this review. Found while verifying F-4, proven live, fixed in the same migration.**
>
> The ownership check read:
>
> ```sql
> IF auth.uid() IS NOT NULL AND auth.uid() <> p_referred_id THEN ... UNAUTHORIZED
> ```
>
> As `anon`, `auth.uid()` is NULL, so the whole predicate is false and the check is skipped —
> leaving `p_referred_id`, *the account being modified*, entirely caller-chosen. Proven in a
> rolled-back transaction against a real user who had no referrer:
>
> ```
> victim referred_by BEFORE   <null>
> anon apply_referral RESULT  {"success": true}
> victim referred_by AFTER    SS2A150D18        referrals rows 0 -> 1
> ```
>
> **This is a money path, not just data tampering.** `trg_fn_award_referral_points` awards the
> referrer a point whenever a referred user pays a plan fee, and `redeem_referral_points`
> converts 10 points into **$2.00 of real wallet credit** via `credit_wallet_for_deposit`. An
> unauthenticated attacker could attach every existing user to their own referral code and farm
> it (capped at 10 points/day by `REFERRAL_DAILY_POINT_CAP`, so ~$2/day — bounded, but real and
> requiring no account).
>
> Fixed to `IF auth.uid() IS NULL OR auth.uid() <> p_referred_id`. Pinned by T7.
>
> **Worth generalising:** an `IS NOT NULL AND …` ownership guard is a no-op for anon. Any
> SECURITY DEFINER function on the authenticated allow-list should be read for this shape.

> ### ⚠️ F0.3 correction — revoking `anon` from `is_power_user` was a **mistake**, and reverted
> This document's F0.3 lists `is_power_user` among the six RPCs that should "lose `anon`".
> Doing that **broke anonymous reads of `sim_lines`**:
>
> ```
> SET LOCAL ROLE anon; SELECT count(*) FROM public.sim_lines;
> -> ERROR 42501 permission denied for function is_power_user
> ```
>
> The `sim_lines` policy *"Allow power users full access on sim_lines"* is defined
> `FOR ALL TO public`, so it is evaluated for `anon` as well, and its `USING` clause calls
> `is_power_user(auth.uid())`. **RLS policy expressions execute as the querying role**, so
> without `EXECUTE` the entire `SELECT` errors instead of returning zero rows — an expired
> token mid-request would surface as a hard `42501` rather than an empty list. (`profiles` and
> `scheduled_topups` were unaffected: their `is_power_user`-bearing policies are scoped
> `TO authenticated`.)
>
> `doc/RLS_MATRIX.md` had already flagged this — *"Required: used in RLS policies evaluated as
> `anon`"* — and was right about the requirement, though it framed the function as a necessary
> exception. It is not: `is_power_user` never needed definer rights. Its whole body reads the
> **caller's own** JWT claim and it ignores its `user_id` argument, so it is not a lookup
> oracle. Migration `20260801100000` makes it `SECURITY INVOKER` and re-grants `anon`.
>
> Net effect: anon reads work again, **and** it leaves the SECURITY DEFINER perimeter — so the
> "zero anon-callable `SECURITY DEFINER` functions" result is honest rather than a carve-out.
> Pinned by T9, which asserts *both* halves (still INVOKER, still anon-callable).
>
> **Lesson for future lockdowns: check `pg_policies` for functions referenced in `USING` /
> `WITH CHECK` before revoking `anon` from anything.**

### F-5 · A4's acceptance criterion ("advisor security findings = 0") was never met

Live `get_advisors(security)` right now:

| level | lint | count |
|---|---|---|
| ERROR | `security_definer_view` (`esim_offers`, `zendit_offers_cache`) | 2 |
| WARN | `authenticated_security_definer_function_executable` | 27 |
| WARN | `anon_security_definer_function_executable` | 13 |
| WARN | `function_search_path_mutable` (`process_due_notifications`) | 1 |
| WARN | `extension_in_public` (`pg_net`) | 1 |
| WARN | `auth_leaked_password_protection` disabled | 1 |
| INFO | `rls_enabled_no_policy` ×5 | 5 |

Most of the 27 `authenticated` warnings are the intended self-scoped RPCs and are fine — but
they are only fine **because each one checks `auth.uid()` internally**, and F-1 proves that
assumption is not audited anywhere. The 5 INFO rows (`esim_offers_cache`,
`offline_refill_events`, `rate_limit_buckets`, …) are the deliberate deny-all tables and are
correct. The two ERRORs are the deliberate markup-isolation views and need a written exception
in `doc/RLS_MATRIX.md`, not a fix.

> **✅ RESOLVED 2026-07-29** — migration `20260801080000_f5_process_due_notifications_search_path.sql`
> plus the exception table now written into `doc/RLS_MATRIX.md`.
>
> **The counts in the table above were stale.** Measured live at the start of this session:
> `anon_security_definer_function_executable` was **12**, not 13, and
> `authenticated_security_definer_function_executable` was **25**, not 27. Total 47 lints.
>
> | lint | level | before | after | note |
> |---|---|---|---|---|
> | `anon_security_definer_function_executable` | WARN | 12 | **0** | F-3/F-4 |
> | `function_search_path_mutable` | WARN | 1 | **0** | `SET search_path TO ''`; body was already fully `public.`-qualified, so behaviour is unchanged |
> | `authenticated_security_definer_function_executable` | WARN | 25 | **20** | the 5 that became service_role-only |
> | `security_definer_view` | ERROR | 2 | **2** | accepted exception |
> | `rls_enabled_no_policy` | INFO | 5 | **5** | accepted exception |
> | `extension_in_public` (`pg_net`) | WARN | 1 | **1** | accepted exception |
> | `auth_leaked_password_protection` | WARN | 1 | **1** | 👤 **owner** |
> | **total** | | **47** | **29** | |
>
> **It is not zero, and this review was right that it never should have been.** A4's original
> "advisor findings = 0" criterion is what let F-1 through — the lint *was* raised and read as
> noise. The replacement criterion this document proposed (§2, Phase A) is what now holds, and
> it is enforced mechanically by `supabase/tests/f0_grant_matrix_tests.sql` rather than by
> counting lints.
>
> Accepted exceptions, each with its reason recorded in `doc/RLS_MATRIX.md`:
> * **2 × `security_definer_view`** (`esim_offers`, `zendit_offers_cache`) — deliberate markup
>   isolation. They exist so a client can read retail prices without reading the wholesale cost
>   columns behind them; `security_invoker = on` would expose supplier margin. **Do not "fix".**
> * **5 × `rls_enabled_no_policy`** — deliberate deny-all tables. RLS on with zero policies *is*
>   the intended service-role-only posture; adding a policy would weaken them.
> * **20 × `authenticated_security_definer_function_executable`** — the self-scoped app RPCs.
>   Each gates on `auth.uid()` internally, and the set is now pinned by an explicit allow-list,
>   so a new one cannot appear unnoticed.
> * **`pg_net` in public** — Supabase-managed, and `purge_deleted_accounts()` calls
>   `net.http_post`. Relocating it is a schema change, not a security fix; deliberately not
>   bundled into a security lockdown.
> * **`auth_leaked_password_protection`** — 👤 **owner task**, see §7.

### F-6 · Default `GRANT ALL` was never stripped — RLS is a single point of failure

`anon` and `authenticated` hold `INSERT, UPDATE, DELETE, TRUNCATE` at table level on
`profiles`, `sim_lines`, `scheduled_topups`, `esim_orders`, `user_esims`. Writes are blocked
today **only** by RLS policies (verified: `esim_orders` and `user_esims` have zero non-SELECT
policies, so writes are denied). That is one `DROP POLICY` away from a breach, and it is
inconsistent with the column-level lockdown D5d built for `sim_lines.plan_type`. `TRUNCATE`
is not RLS-filtered at all; it is unreachable over PostgREST today, which is the only reason
this is 🟠 and not 🔴.

> **✅ RESOLVED 2026-07-29** — migration `20260801090000_f6_table_grant_lockdown.sql`.
>
> **Correction to the finding:** `sim_lines` was already partly right — D5d had column-scoped
> its UPDATE to 13 columns, so there was no table-level UPDATE on it for `anon`/`authenticated`.
> Everything else in the finding verified exactly as written.
>
> Grants re-derived from what the live policies actually permit:
>
> | table | anon | authenticated | rationale |
> |---|---|---|---|
> | `profiles` | SELECT | SELECT, INSERT, column-scoped UPDATE | no DELETE policy exists |
> | `sim_lines` | SELECT | SELECT, INSERT, DELETE, column-scoped UPDATE (D5d) | full policy set |
> | `scheduled_topups` | SELECT | SELECT, INSERT, UPDATE, DELETE | single ALL policy |
> | `esim_orders` | SELECT | SELECT | **zero** non-SELECT policies |
> | `user_esims` | SELECT | SELECT | **zero** non-SELECT policies |
>
> `TRUNCATE`, `REFERENCES` and `TRIGGER` revoked from both roles on all five. SELECT is left to
> `anon` deliberately: every policy requires `auth.uid()`, so anon already reads nothing, and
> revoking it would be churn for no gain.
>
> **The finding under-stated the risk. This was not "one `DROP POLICY` away" — it was already
> exploitable**, see 🆕 F-6a below.
>
> **The D5c risk this review flagged was real and was hit.** `ProfileRepository.updateProfile`
> sent `profile.toJson()` — the full model, including every column revoked here — so shipping
> the lockdown alone would have broken profile editing with `42501`, exactly as D5c broke SIM
> line editing. `UserProfile.toClientWritableJson()` was added
> (`lib/features/auth/model/auth_model.dart`), mirroring `SimLine`'s. **Every real write path
> was exercised before and after**: `updateSimLine`, `addSimLine`, `deleteSimLine`, scheduled
> top-up create/delete, `updateProfile` — all pass; the old full-model payload correctly now
> returns `42501`. Regression test `supabase/tests/f6_table_grant_tests.sql`, **12/12**, plus 3
> new Dart tests (`test/features/profile/update_profile_test.dart`).

> ### 🆕 F-6a · Any signed-in user could make themselves a power user — **PROVEN LIVE**
> **Not in this review. Found while verifying F-6.** This is the reason F-6 deserved 🔴.
>
> `protect_is_power_user()` — the trigger whose entire job is to stop a client setting
> `profiles.is_power_user` — opened with:
>
> ```sql
> IF current_user IN ('postgres', 'supabase_admin') OR ... THEN RETURN NEW;
> ```
>
> It is `SECURITY DEFINER`, so `current_user` is the function **owner** — always `postgres`.
> The guard returned `NEW` for every caller and **had never once fired since it shipped.** This
> is the identical defect D5c shipped and D5d fixed for the plan-tier trigger; it is the fourth
> occurrence of "`current_user` inside `SECURITY DEFINER`" in this project.
>
> Proven as `SET LOCAL ROLE authenticated` with a real JWT, rolled back:
>
> ```
> a1 profiles.is_power_user           false -> true
> a1 auth.users raw_app_meta_data     false -> true    (sync_power_user_claim propagates it)
> privilege_escalation_attempt rows   0                (the trigger never ran)
> ```
>
> `sync_power_user_claim()` copies the column into `auth.users.raw_app_meta_data`, so after the
> next token refresh the user's JWT satisfies `is_power_user(auth.uid())` — which the
> *"Allow power users full access on sim_lines"* policy honours (**read/write on every user's
> SIM lines**) and *"Users can view own or household profiles"* honours (**read every
> profile**). Table-level UPDATE on `profiles` is what made it reachable, which is why it sits
> inside F-6.
>
> Fixed in two layers, per the F-1/F-2 convention:
> * **Layer 1** — `is_power_user`, `is_suspended` and `subscription_tier` are not in
>   `authenticated`'s column-level UPDATE grant → `42501`.
> * **Layer 2** — the trigger keys on the request JWT role instead of `current_user`.
>   **Kept `SECURITY DEFINER` on purpose**: D5d's "make it `SECURITY INVOKER`" fix works for the
>   plan-tier trigger but would break here, because `security_logs` has RLS enabled with zero
>   policies — an invoker trigger could not write its own audit row and would abort the
>   statement with `42501` instead of silently reverting.
>
> Layer 2 proven alone (column grant restored in a rolled-back txn, so only the trigger can
> act): value reverted to `false`, JWT claim untouched, and `privilege_escalation_attempt`
> went `0 → 1`. `service_role` can still promote (admin path intact). Pinned by T4/T12 and
> Part B of `f6_table_grant_tests.sql`.

---

## 2. Phase-by-phase review

### Phase A — Security · verdict: **incomplete, and the gap is the F-1/F-2 hole**

| | status | what the review found |
|---|---|---|
| A1 wallet revoke | ✅ table layer | Verified live: `wallets` / `wallet_transactions` grant only `SELECT` to `anon`/`authenticated`. **But** the RPC layer was never swept — see F-1/F-2. The *stated objective* ("balance changes only through server-side calls") is currently false. |
| A2 rotation | ❌ owner | Still outstanding: Supabase legacy JWT secret, Zendit sandbox key, and the **PayPal sandbox client secret that is in git history** (`paypal_refill_simulator_screen.dart` was deleted in D4 — deletion does not remove it from history). |
| A3 backend in git | 🟡 | `servers/*.js` (8 workers) are now committed **inside the Flutter repo**. Nobody has verified the VM runs *that* code — there is no deploy step, so repo and VM can silently diverge. Add a parity check (see F6). |
| A4 advisor sweep | ✅ **2026-07-29** | Redone under the replacement criterion below. Advisors 47 → 29; the residue is documented, not counted away. `doc/RLS_MATRIX.md` rewritten with the Phase F matrix + an accepted-exceptions table, and the A4-era notes in it corrected. |

**Modification to the plan:** A4's acceptance criterion should change from "advisor findings
= 0" to *"every `SECURITY DEFINER` function is in one of three buckets — `service_role`-only,
self-scoped-and-tested, or documented exception — and a SQL test asserts the grant matrix"*.
Counting advisor lints is what let F-1 through; the lint was raised, and read as noise.

### Phase B — Money · verdict: **the strongest work in the project**, two gaps

Atomicity, idempotency (`FOR UPDATE` + unique `reference_id`), the fee model living in
`system_configs`/`payment_gateways`, the premium-vs-PAYG asymmetry documentation — all of
this is genuinely good and the reasoning in the plan (lines 714–782) is the kind of thing that
prevents future regressions. Keep it.

Gaps:
- **Nothing reconciles the ledger.** The `wallet_reconciliation` view exists; no job runs it.
  A drift between `wallets.balance` and `Σ wallet_transactions` would be invisible. → F6.
- **`system_alerts` has 3 unattended `offer_price_mismatch` rows.** The catalog drifted from
  the pinned `carrier_rules.offer_id` and nobody noticed. A trigger does dispatch these
  (`trg_notify_system_alert`) — into the same notification pipeline that currently delivers
  nothing (see below). Ops alerting is therefore also dead.

### Phase C — Product · verdict: **built, not operating**

**C1 notifications — the pipeline is sound; its reach is close to nil.**
Live `notification_deliveries`, grouped:

| channel | status | n | last | detail |
|---|---|---|---|---|
| push_onesignal | delivered | 13 | 2026-07-27 03:35 | `Delivered via OneSignal (id …, **recipients 0**)` |
| push_onesignal | failed | 18 | 2026-07-27 03:35 | `All included players are not subscribed` |
| push_fcm | skipped | 16 | 2026-07-27 03:35 | `No FCM tokens registered for this user` |
| push_fcm | delivered | 2 | **2026-07-17** | `FCM delivered to 1/1 device(s)` |
| whatsapp | skipped | 16 | 2026-07-27 03:35 | `WHATSAPP_VPS_API_KEY not configured` |
| email | — | **0 rows** | — | the branch has never executed |

**First, what is *not* wrong** (this trips up every reader of this table, including my own
first pass): a `delivered` row showing `recipients 0` is **correct**. OneSignal resolves
alias-targeted sends asynchronously, so the immediate response carries `recipients: 0` even on
a good send. C1's fix on 2026-07-17 (dispatch-alert v18) deliberately defines success as
`2xx + id + no errors[]`, **not** a recipients count — an earlier cut used the count, treated
every send as failed, fell through to FCM and double-pushed every device. **Do not reintroduce
a recipients check.** The 13 `delivered` rows are plausibly real deliveries.

What *is* wrong, and it is enough:
1. **18 of the last 31 push dispatches failed with `All included players are not subscribed`,
   fell back to FCM as designed, and FCM had no token** (`No FCM tokens registered for this
   user`, 16 of them). Those notifications reached nobody, on any channel. The fallback chain
   worked perfectly and still ended in silence.
2. `device_push_tokens` holds **1 row for the entire user base** while 8 users have push
   enabled. Token registration is not happening reliably on launch / permission-grant / login.
   Every other push problem is downstream of this one.
3. Channel defaults: `email` is `is_enabled = false` for **all 7** users, `telegram` false for
   all 7, `whatsapp` true for 1. The default channel set is push-only — so a user with a
   missing token has no second channel by construction. Email needs no device state and is the
   obvious floor; it is off.
4. The last confirmed *device* delivery in the log is `push_fcm` on **2026-07-17**. Push has
   not been end-to-end verified on a real handset in ten days.

Missing channels for "all famous": **SMS is not a channel type at all** (`notification_channels`
allows only `email|push|telegram|whatsapp`), and **iOS cannot receive push at all** — no
`ios/Runner/GoogleService-Info.plist`, no `.entitlements` file, no APNs key. The PRD promises
iOS.

**C4 offline refill — coded correctly, provisioned nowhere.** `offline_refill_events` has
**0 rows, ever**. The three contact numbers in `system_configs` are still the placeholders
`+968 24 555 0111/0112/0113`. No WABA sender, no Twilio number. Every user who taps an offline
channel today messages a number that does not belong to us. This is the single largest
gap between "the plan says done" and "a user can use it".

**C9 eSIM — one supplier, fulfilment never proven.** `esim_offers_cache` holds 50 real offers
from a single `provider`, refreshed 4 h ago (6 h cadence, healthy). But `esim_orders` has 1 row
and `user_esims` 1 row, and the C9b record itself shows `provider_order_ref = esim_go_ref_9999`
— **a fixture, not a real eSIM Go `/orders` response**. The "best offers" promise is currently
"cheapest $/GB *within one supplier's* catalog", which is not a comparison.

**Advertised-but-unbuilt:** "Baqa local calls + data operator detection" still ships as a
selling bullet at `lib/features/sim_lines/presentation/screens/sim_lines_list_screen.dart:653`
with no flow behind it. Build it or delete the line — it is the same class of problem C3 fixed.

**C7 support** is built end-to-end (tables, RLS, UI, `trg_support_ticket_messages_process`
trigger for admin replies) and has 0 tickets — fine, it is new.

### Phase D — Hardening · verdict: **accepted, with two honest asterisks**

D1–D5e are real; the D5d/D5e corrections in memory match what I see live (SECURITY INVOKER
guard, heartbeat 0.0 min, cron `check-worker-heartbeat */10`, analyze 134/0). Asterisks:

- **`analytics_events` has 0 rows.** D5d added the table, RLS and 2 call sites; nothing has
  ever been recorded. That is *probably correct behaviour* — D3 defaults tracking consent to
  `false` and no UX asks for it — but "analytics is wired" and "analytics tells you anything"
  are different claims, and only the first is true.
- **Sentry DSN is still unset** (owner), so crash reporting is inert. Unchanged from D5.
- Release bundle carries **6 fully unused dependencies**: `dartssh2` (an entire SSH client),
  `file_picker`, `cached_network_image`, `dartz`, `fl_chart`, `flutter_svg` — zero
  `package:` imports under `lib/`. `dartssh2` and `file_picker` in particular invite store
  review questions about capabilities the app does not use.
- **No CI at all** (`.github/workflows` does not exist) and no iOS build path. Every "tests
  pass / analyze clean" claim in this project's history has been a human running a command and
  reporting a number — which is precisely how "0 issues" got manufactured once already in D5.

### Phase E — Go-live · verdict: **right content, wrong entry point**

E1 assumes A–D are finished. They are not, in the operational sense above. Recommended
sequence change: **F0 (security) → F1/F3 (make notify + offline actually deliver) → owner
provisioning → E1 cutover.** Also: E1 says "retire Baileys". Baileys is *already* effectively
retired by accident (`WHATSAPP_VPS_API_KEY` unset ⇒ 16/16 skipped) — so WhatsApp notifications
are dead today and the WABA migration is not a nice-to-have, it is the only path back.

---

## 3. Credentials, accounts and APIs still needed

Answering the direct question: **yes — the app cannot be "full" on the current credential set.**
The table below is everything missing, what it unblocks, and where it belongs (per the four
homes rule in the secrets memory: Edge Function secrets · Vault · VM `.env` · `system_configs`).

### 3.1 Blocking — the objective does not work without these

| # | Credential / account | Unblocks | Where it lives | Cost | Who |
|---|---|---|---|---|---|
| 1 | **Apple Developer Program** + APNs Auth Key (`.p8`, Key ID, Team ID) + `GoogleService-Info.plist` + Push Notifications entitlement | **all** iOS notifications; iOS release at all | `.p8` → Firebase console + OneSignal; plist → `ios/Runner/` | $99/yr | Owner |
| 2 | **WhatsApp Business Platform** (Meta): WABA ID, Phone Number ID, permanent System-User token, App Secret, Verify Token, **approved templates** | offline refill via WhatsApp **and** WhatsApp notifications (replaces Baileys) | Edge Fn secrets `WABA_*` + new `WABA_ACCESS_TOKEN`, `WABA_PHONE_NUMBER_ID` | per-conversation (~$0.005–0.08) | Owner |
| 3 | **Twilio**: Account SID, Auth Token, Messaging Service SID, one voice+SMS number | offline SMS + missed-call refill; SMS notification channel | Edge Fn secret `TWILIO_AUTH_TOKEN` (+ SID); numbers → `system_configs.OFFLINE_*_NUMBER` | ~$1–2/mo + usage | Owner |
| 4 | **Resend** API key + **verified sending domain** (SPF/DKIM/DMARC on `keepsims.com`) | the only channel that needs no device state; currently 0 sends | Edge Fn secret `RESEND_API_KEY` | free 100/day → $20/mo | Owner |
| 5 | **Sentry** DSN | crash reporting (wired, inert since D5) | `--dart-define=SENTRY_DSN=` at build | free tier fine | Owner |
| 6 | **Android upload keystore** + Play App Signing | any Play release (still signed with the **debug key** per D4 note) | `android/key.properties` (never committed) | — | Owner |
| 7 | **Play Console** account | store submission | — | $25 once | Owner |
| 8 | **keepsims.com hosting** for `/privacy` + web deletion page | Play Data-Safety policy; the app already links `/privacy` | — | ~$0 (Cloudflare Pages) | Owner |

### 3.2 Required for "best offers" and go-live economics

| # | Credential | Unblocks | Notes |
|---|---|---|---|
| 9 | **Zendit production** API key | E1 — real top-ups | currently sandbox; VM `servers/.env` |
| 10 | **eSIM Go production** key + a **real `/orders` test** | eSIM fulfilment proof (today's only order used `esim_go_ref_9999`) | VM `servers/.env` |
| 11 | **Second eSIM supplier** — Airalo Partner API (`client_id`/`client_secret`) is the usual first pick; alternatives eSIM Access, Maya.net, Mobimatter | turns "best value in one catalog" into a genuine **best-offer comparison** | each needs a partner agreement; budget 1–3 weeks of business lead time |
| 12 | **DTone production** credentials | the multi-provider top-up path built in C3b-3 is sandbox-only | VM `servers/.env` |
| 13 | **Reloadly** client id/secret | E2 failover — today a single Zendit outage stops **all** refills | VM `servers/.env` |
| 14 | **PayPal live** client id/secret/webhook id + verified business account | real money | Edge Fn secrets (reuse the B3 keys' slots) |

### 3.3 Optional / later

Moyasar or Tap or MyFatoorah (mada + STC Pay, E3) · Apple Pay merchant ID · Google Pay merchant
ID · Firebase App Check (abuse protection for Edge Functions) · a Geo-IP provider key if the
CDN header path ever proves unreliable (C8 currently falls back to a free REST endpoint).

### 3.4 MCP servers — what would actually help

Being blunt: **MCP servers are agent tooling, not app runtime.** Adding one never makes the app
more complete; it makes *building* it faster. Worth connecting, in order of payoff:

| MCP server | Credential | Why it pays for itself here |
|---|---|---|
| **Supabase** | ✅ already connected | the backbone of every verification in this document |
| **Sentry** | org auth token (after #5) | read crash groups directly instead of asking the owner for screenshots — closes the loop the owner-task memory complains about |
| **GitHub** | PAT | the backend workers now live in this repo; PR/CI automation, and A3's "add a remote" |
| **Twilio** | API key/secret (after #3) | provision numbers, read message logs, and **self-verify** the offline channel end-to-end instead of a 5th "configured ✅" claim |
| **Cloudflare** | API token | host the privacy/deletion pages (#8) and verify they're live |
| Firebase / Google Cloud | service account | FCM config + VM access without SSH-by-hand |

Everything else in the registry (Stripe, Notion, Linear, …) is noise for this project. Note the
pattern the memory already records: an MCP server the agent *can* reach converts an
"owner task the agent keeps falsely claiming" into a verifiable one. Twilio and Sentry are the
two with the highest such value.

---

## 4. The four core objectives, scored on live evidence

| Objective | Coded | Operating | Evidence | Gap to close |
|---|---|---|---|---|
| **Notify — all famous channels** | 85% | **~15%** | 18 of last 31 dispatches reached nobody; 1 push token for 8 push-enabled users; email/telegram off for all; no SMS channel; no iOS push config at all | F1 + F2 + creds #1–4 |
| **Refill — online: instant / auto-mini / auto-custom** | 100% | ✅ | 26 `topup_executions`, 783 cached offers refreshed 6 min ago, atomic debit/refund proven in B2/D5b | production keys (#9, #12, #13) + F-1/F-2 lockdown |
| **Refill — offline (WhatsApp / SMS / missed call)** | 100% | **0%** | `offline_refill_events` = 0 rows ever; the 3 numbers are Oman placeholders | F3 + creds #2, #3 |
| **eSIM management + best offers** | 80% | ~20% | 50 real offers, 1 order, fulfilled with a fixture ref; **one** supplier | F5 + creds #10, #11 |
| **Offline app mode** | 70% | ✅ partially | 89 cache read/write sites, 9 cache keys, offline QR rendering works | F4 (the sync queue silently discards writes — below) |

**The offline sync queue has a data-loss bug worth calling out on its own.**
`lib/core/services/sync_queue_service.dart:117-122`: on any `PostgrestException` the operation
is logged with `print()` and **removed from the queue**. A user who edits a line offline and
hits any server-side rejection (RLS, constraint, rate limit) loses that edit permanently and is
never told. It also covers only 4 operation types (`sim_line_add/update/delete`,
`topup_schedule_save`) — alert settings, profile edits and offline-refill intents are not
queued — and has no retry budget, no backoff and no conflict resolution (last-write-wins
against a server row that may be newer).

---

## 5. Phase F — the plan, one session per item

Same conventions as `PRODUCTION_PLAN.md`: self-contained, acceptance criteria stated, hand one
at a time. 🔴 blocking · 🟠 important · 🟢 nice · ⚪ later.

### ✅ F0 — RPC grant lockdown + a grant matrix that stays locked — **COMPLETE 2026-07-29**

> **All six items below are done.** Migrations `20260801040000` … `20260801100000`, commits
> `3acec84`, `7bb72a0`, `2e4039e` (all verified on `origin/main` with `git ls-remote`).
> Acceptance met in full — see the per-item notes. One item (F0.3) was **partly wrong** and is
> annotated as such rather than silently amended.

1. `REVOKE ALL ON FUNCTION` … `FROM PUBLIC, anon, authenticated` for: both
   `debit_wallet_for_topup` overloads, `credit_wallet_for_refund`, `credit_wallet`,
   `purge_deleted_accounts`, `prune_rate_limit_data`, `check_rate_limit_health`,
   `consume_rate_limit`, `enforce_rate_limit`, `trg_fn_award_referral_points`. Grant each to
   `service_role` only. **Drop the 5-arg `debit_wallet_for_topup` overload** if unused — two
   signatures is how the grant drifted.
   *(✅ `credit_wallet_for_refund` — migration `20260801040000`, see F-1.
   ✅ both `debit_wallet_for_topup` overloads — migration `20260801050000`, and the 5-arg one
   is **dropped** by `20260801060000`; it had no callers and was actively breaking PostgREST
   overload resolution for the two that exist, see F-2.
   ✅ `purge_deleted_accounts`, `prune_rate_limit_data`, `check_rate_limit_health`,
   `consume_rate_limit`, `enforce_rate_limit`, `trg_fn_award_referral_points` — migration
   `20260801070000`.
   ⚠️ `credit_wallet` **needed no change**: it was already `{postgres, service_role}` when
   measured live on 2026-07-29. Listing it here was precautionary, not evidence-backed.
   **F0.1 is now complete.**)*
2. Add an in-body `auth.uid()` guard to `credit_wallet_for_refund` as defence in depth
   (`IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id THEN RAISE`), so a future
   re-grant is not instantly fatal. Same for the debit.
   *(✅ done for `credit_wallet_for_refund`, but **not with this predicate** — it does not
   stop the exploit, which credits the attacker's own wallet. Shipped guard keys on the
   `request.jwt.claims` role instead; use that shape for the debit too.
   ✅ **F0.2 complete** — the debit got the call-depth variant in `20260801050000`, and every
   function locked down in `20260801070000` carries an in-body guard as well. Three distinct
   shapes were needed, and picking the wrong one either ships dead code or breaks production:
   **cron-only → reject any non-`service_role` JWT; nested-caller → plpgsql call depth, with a
   `service_role` escape hatch if it also has top-level callers; self-scoped → require
   `auth.uid()` and self-ownership**.)*
3. Revoke `anon` EXECUTE on the self-scoped RPCs that must stay `authenticated`:
   `export_user_data`, `apply_referral`, `request_account_deletion`,
   `cancel_account_deletion`, `redeem_referral_points`, `is_power_user`.
   *(✅ **F0.3 complete for five of six** — migration `20260801070000`.
   ❌ **`is_power_user` was a mistake and is reverted.** Revoking `anon` broke
   `anon SELECT sim_lines` with `42501`, because the *"Allow power users full access"* policy is
   `FOR ALL TO public` and calls it, and RLS policy expressions run as the querying role.
   Migration `20260801100000` makes it `SECURITY INVOKER` — it only reads the caller's own JWT
   and never needed definer rights — and re-grants `anon`. Full write-up in §1 under
   *"F0.3 correction"*. Also fixed here: `apply_referral`'s ownership check was a no-op for
   anon, see 🆕 F-4a.)*
4. Strip default table privileges: `REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON` `profiles`,
   `sim_lines`, `scheduled_topups`, `esim_orders`, `user_esims` `FROM anon` and re-grant only
   what RLS actually needs to `authenticated` (column-scoped where D5d already set the pattern).
   *(✅ **F0.4 complete** — migration `20260801090000`. Also revoked `REFERENCES`/`TRIGGER`
   (unused, and `TRIGGER` on a client-reachable table is an escalation primitive), and dropped
   all writes on `esim_orders`/`user_esims`, which have zero non-SELECT policies. Required the
   companion Dart change `UserProfile.toClientWritableJson()` — without it the lockdown breaks
   profile editing exactly as D5c broke SIM line editing. Closed 🆕 F-6a en route.)*
5. Fix `process_due_notifications` search_path; document the 2 `security_definer_view` ERRORs
   as accepted exceptions in `doc/RLS_MATRIX.md`; enable HaveIBeenPwned in Auth settings.
   *(✅ search_path — migration `20260801080000`. ✅ exceptions written into
   `doc/RLS_MATRIX.md`, covering the 2 view ERRORs, the 5 deny-all INFOs, the 20 remaining
   authenticated RPCs and `pg_net`. Advisors 47 → **29**, reported honestly.
   👤 **HaveIBeenPwned is NOT done — it is an owner task**, Dashboard → Auth → Passwords. There
   is no API or SQL toggle, so no agent can do it. Listed in §7.)*
6. **Ship a regression test** — `supabase/tests/f0_grant_matrix_tests.sql` asserting, for every
   `SECURITY DEFINER` function in `public`, that its ACL is either service_role-only or on an
   explicit allow-list. This is the artifact that stops F-1 recurring.
   *(✅ **F0.6 complete**, 6/6. Six assertions: no anon-callable definer fn; no `PUBLIC`
   EXECUTE; no NULL `proacl` (a NULL ACL *is* EXECUTE-to-PUBLIC, which catches a brand-new
   unguarded function); every authenticated-callable fn is allow-listed; **and the reverse** —
   every allow-listed fn is still callable, which catches a lockdown that went too far, the
   D5c failure mode; `service_role` can execute everything, so workers and cron cannot be
   silently broken. Companion suites `f3_f4_rpc_grant_tests.sql` 9/9 and
   `f6_table_grant_tests.sql` 12/12.)*

**Acceptance:** the F-1 curl with a real user JWT returns `42501`; the F-2 anon curl returns
`42501`; `purge_deleted_accounts` as anon returns 401/403; the grant-matrix test passes; a real
refill and a real refund still work end-to-end (a1 fixture wallet must end at **$35.86**).

> **✅ Acceptance met, 2026-07-29.** F-1 and F-2 curls → `42501`. `purge_deleted_accounts` as
> anon → `42501` / **HTTP 401**. All 11 REST-reachable locked RPCs → `42501`. Grant-matrix test
> **6/6**. Money paths re-verified live: nested plan-fee debit `35.86 → 33.36`, `service_role`
> top-level `consume_rate_limit` still allowed, all five app write paths pass before and after.
> a1 wallet **$35.86**, **165** transactions, **zero residue**. `flutter test` **76/76**
> (73 + 3 new), `flutter analyze` **134** (baseline held).

### 🔴 F1 — Make notifications actually arrive (and prove it)

1. **Do not touch the OneSignal success condition.** `2xx + id + no errors[]` is correct and
   was verified end-to-end on 2026-07-17; a recipients-count check double-pushes every device.
   Instead, make delivery *observable*: OneSignal's async resolution means the log cannot tell
   you whether a push landed, so add a client-side delivery/open receipt (OneSignal
   notification-opened handler → `notification_deliveries.confirmed_at`) and use *that* as the
   metric.
2. **Fix token registration — this is the root cause.** `device_push_tokens` has 1 row for 8
   push-enabled users, and 16 fallbacks died on a missing token.
   `lib/features/notifications/data/repositories/device_token_repository.dart` registers on
   `onTokenRefresh` + `getToken()` — audit when that actually runs (permission grant, cold
   start, login, and after a permission change), and register the **OneSignal external id /
   alias** in the same place so the two channels target the same user.
3. **Turn email on by default** (`trg_profiles_seed_alert_settings`) and backfill existing
   users, set `RESEND_API_KEY`, verify the sending domain. Email is the only channel that
   works with zero device state — it should be the floor, not off.
4. **Add `sms` as a channel type** (`notification_channels` CHECK, `alert_settings.channels`,
   the dispatcher, the settings UI, ARB ×9) routed through Twilio. Reuse the C4 number.
5. **Replace the Baileys WhatsApp branch with the official Cloud API** (`WABA_ACCESS_TOKEN` +
   `WABA_PHONE_NUMBER_ID`), including template registration for the categories that fall
   outside the 24-hour customer-service window. This is E1's Baileys retirement, pulled
   forward, because Baileys is already dead (`WHATSAPP_VPS_API_KEY` unset ⇒ 16/16 skipped).
6. **Add an in-app inbox** backed by the existing `notifications` table so a user who has every
   external channel off still sees their alerts.

**Acceptance:** one real device receives, and the reviewer sees, a push, an email and an SMS
for the same event; `notification_deliveries` shows `delivered` with `recipients > 0`; a
deliberately-broken OneSignal call demonstrably falls back to FCM.

### 🔴 F2 — iOS parity (owner-gated, agent-executable once unblocked)

Firebase iOS app → `GoogleService-Info.plist`; APNs `.p8` uploaded to Firebase **and**
OneSignal; `Runner.entitlements` with `aps-environment`; `UIBackgroundModes: remote-notification`;
`NSFaceIDUsageDescription` is already there (D1). Then a real iPhone test of push + biometric +
eSIM install. Until this lands, **the App Store submission cannot honestly claim notifications**.

### 🔴 F3 — Offline refill go-live (the objective with the biggest coded/operating gap)

Owner provisions #2 and #3; then in-session: set the three `system_configs.OFFLINE_*_NUMBER`
to the real numbers, point the Meta and Twilio webhooks at the three deployed Edge Functions,
confirm signature verification switches from skip-with-warning to enforced once the secrets
exist, and **send a real WhatsApp message, a real SMS and a real missed call** from a phone
whose number is on a `profiles` row. Each must produce an `offline_refill_events` row and a
`topup_executions` row with the right `refill_channel` and the right per-channel fee.

**Acceptance:** 3 rows in `offline_refill_events` (one per channel) from real inbound traffic,
each with a matching priced execution; an unknown sender produces an audited rejection, not a
500. Also: confirm the app's cached `offlineContactNumber` refreshes so existing installs stop
showing the Oman placeholders.

### 🟠 F4 — Offline mode hardening

1. **Stop silently discarding writes** (`sync_queue_service.dart:117`). Classify errors:
   permanent (4xx/RLS/constraint) → move to a `failed_sync` list **surfaced in the UI** with a
   retry/discard choice; transient → keep with exponential backoff and an attempt counter.
   Replace `print` with the project's logging path (the `avoid_print` lint is on and this file
   violates it).
2. **Conflict resolution**: send `updated_at` and reject stale writes server-side rather than
   last-write-wins.
3. **Widen coverage**: queue alert-settings toggles, profile edits, and a genuinely offline
   "refill intent" that fires the instant connectivity returns (today the offline screen only
   hands off to WhatsApp/SMS).
4. **Encrypt the cache.** `LocalCacheService` stores wallet balance, transactions, profile and
   line data in `shared_preferences` — plaintext on a rooted device. `flutter_secure_storage`
   is already a dependency; use it for the wallet/profile keys at minimum.
5. **Offline eSIM QR is already correct** (`qr_flutter` renders client-side) — keep, and add
   the LPA string to the offline cache so "My eSIMs" survives a cold offline start.

### 🟠 F5 — eSIM: second supplier + a real best-offer engine

1. Generalise `esim_offers_cache` (it already has a `provider` column) and
   `esim_provider_factory.dart` behind one interface; add supplier #2 (Airalo Partner API is
   the pragmatic first choice) with its own catalog worker on the same 6 h cadence.
2. **Normalise for comparison**: $/GB, $/day, coverage set, throttle-after-quota policy,
   top-up-ability, KYC requirement. Rank across suppliers and keep the "Best Value" badge
   meaningful. Store the losing quotes too — that is what makes "we found you the best price"
   defensible.
3. **Prove fulfilment for real**: one live eSIM Go `/orders` purchase end-to-end, replacing the
   `esim_go_ref_9999` fixture as the only evidence. Then the same for supplier #2, including
   the refund path when a supplier fails.
4. Add **eSIM top-up** (recharge an existing eSIM rather than buy a new one) — a large, cheap
   win: the fulfilment worker already polls `GET /esims/{iccid}`.

### 🟠 F6 — Ops: reconciliation, alert routing, CI, deploy parity

1. Nightly `pg_cron` job over `wallet_reconciliation` → `system_alerts` on any drift.
2. Route `system_alerts` to the **owner** specifically (email + push), and build a small admin
   view; the 3 unattended `offer_price_mismatch` rows are the proof this is missing.
3. **GitHub Actions**: `flutter analyze` (fail on >134 issues or any error), `flutter test`,
   `node --test servers/`, and the SQL suites against a preview branch. Every quality claim in
   this project's history is currently a human-typed number.
4. **VM deploy parity check**: a job that diffs `servers/*.js` in the repo against what PM2 is
   running and alerts on divergence. A3 committed the code; nothing keeps it true.
5. Confirm the UptimeRobot monitor points at the **full** `/functions/v1/health` URL and has an
   alert contact attached (both flagged as unverified in the secrets memory).

### 🟢 F7 — Release diet + store submission

Remove the 6 unused dependencies (`dartssh2`, `file_picker`, `cached_network_image`, `dartz`,
`fl_chart`, `flutter_svg`) — measure the AAB before/after (currently 44.6 MB). Delete or build
the "Baqa" bullet at `sim_lines_list_screen.dart:653`. Re-run
`tool/verify_release_bundle.ps1`. Then Play + App Store submission against
`doc/OWNER_STORE_CHECKLIST.md`.

> **🆕 2026-07-29 — this was blocked outright and nobody knew.** Building feature #4
> required an actual APK, and `flutter build apk` had been failing on
> `:sentry_flutter:compileDebugKotlin` (Kotlin 2.2 refuses that plugin's hardcoded
> `languageVersion = "1.6"`). Fixed in `android/build.gradle.kts`; the write-up is under
> feature #4 in § 6. **The lesson belongs in F6's CI item:** every acceptance number this
> document tracks — analyze, tests, advisors — was green while the app could not be
> packaged at all. A CI job that does nothing but `flutter build apk --debug` on push
> would have caught it the day the toolchain moved. Also note the 44.6 MB baseline now
> includes `androidx.glance`, pulled in transitively by `home_widget`.

### ⚪ F8 — E-phase, resequenced

`E1` (Zendit + PayPal live) only after F0–F3. Then E2 (Reloadly failover), E4 (OTP tier),
E3 (local rails), E5 (fleet), E6 (helpdesk bridge).

---

## 6. Feature suggestions (with how to build each)

Ordered by value-per-effort for this specific codebase. Each says what already exists, because
most of these are 60% built already.

> **Progress (2026-07-30):** #1–#7, #9 and #10 are built. **#8 (web dashboard) was skipped
> at the owner's request and is still open**, and #4 is Android-only until the owner does the
> Xcode work in § 7 item 12. Next unbuilt features are **#8**, **#11 multi-currency display**
> and **#12 the localisation QA pass** — and #12 is now the largest accumulated debt in this
> list: nine locales fall back to English for everything G1–G10 added.
>
> *Historical note, kept because it is still true of the process:*
>
> > **Progress:** #1, #2, #3 and #4 all built 2026-07-29 (see below), though **#4 is
> Android-only until the owner does the Xcode work** in § 7 item 12. Next unbuilt feature
> is **#5, the "roam or eSIM?" calculator**. This list is independent of the Phase F plan
> in § 5 — F1 (notifications actually arriving) is still the higher-priority item overall,
> and #2 demonstrated why: its alerts are correct, consent-gated and proven, and they will
> still reach nobody until the push path works. #3 and #4 are the two that are genuinely
> whole without F1, because their value lands in the recipient's balance and on the home
> screen rather than in a notification.
>
> **A note on what #4 turned up.** Building it required an actual APK, and there was no
> actual APK: the Android build had been broken by toolchain drift in a dependency, which
> means **F7 and the store submission were blocked and nobody knew**. Features that force
> a real artifact to be produced are worth more than their feature value.

**1 · Depletion forecasting → smarter auto-custom refills** · *high value, medium effort*
~~You store `topup_executions` history and (for eSIMs) usage polls. Fit a trivial per-line
consumption rate (7/30-day rolling mean of data used ÷ days) and use it to (a) predict the
expiry/depletion date, (b) propose the auto-custom schedule instead of asking the user to
invent one, (c) fire `line_critical` earlier. Implementation: a `sim_line_usage_forecast`
materialised view + a nightly cron; the UI already has a health score to hang it on. No new
credentials.~~

> ### ✅ BUILT 2026-07-29 — migration `20260802000000_g1_depletion_forecasting.sql`
>
> All three outcomes shipped and proven on live data. No new credentials, no owner action,
> nothing left inert.
>
> **What exists now**
>
> | Object | What it is |
> |---|---|
> | `sim_line_usage_forecast` | one row per active SIM line **or** eSIM: prediction, method, confidence, and the suggested schedule. Read-own + household; **no client write path**. |
> | `esim_usage_samples` | daily `data_remaining_mb` reading per eSIM. Deny-all telemetry. |
> | `snapshot_esim_usage()` | records today's reading. |
> | `compute_usage_forecasts()` | the fit. |
> | `emit_forecast_depletion_alerts()` | outcome (c). |
> | `refresh_usage_forecasts()` | cron entry point → **`cron.job` 20, `20 2 * * *`, active**. |
> | Flutter | `UsageForecast` model + provider, `DepletionForecastCard` on the line detail screen, and a suggested-schedule prefill in `ScheduledTopupSheet`. |
>
> **Two deliberate departures from the sketch above.** Both are written up in the migration
> header; in short:
> 1. **A table, not a materialised view.** Postgres does not support RLS on a matview, so
>    `sim_line_usage_forecast` as a matview would be either world-readable through PostgREST
>    or need a `SECURITY DEFINER` view in front of it — the exact shape F0 spent three
>    sessions deleting. A table takes an ordinary read-own policy and adds nothing to the
>    perimeter. Same refresh cost.
> 2. **The job samples eSIM usage itself.** The fulfilment worker already polls
>    `data_remaining_mb` but keeps no history, and the VM is owner-gated (§ 5 of
>    PROJECT_TOPOLOGY). The nightly job records the reading it finds instead, so the burn
>    rate needs two nights but zero deploys.
>
> **The forecast is honest about what it knows.** `method` is one of `topup_history` /
> `esim_usage` (fitted from the line's own behaviour) or `carrier_rule` / `default`
> (fallback), and `confidence` grades it. The card badges these as **MEASURED** vs
> **ESTIMATE**, and the sheet says which one it is suggesting from. A default-90-days guess
> is never dressed up as a measurement.
>
> **Two real defects the live data caught, both fixed before shipping:**
> * **Retry storms poisoned the fit.** One line has five test top-ups minutes apart; the
>   first version fitted a **0.40-day** refill cycle from them, concluded the line was
>   already dead, and proposed weekly refills for a 30-day carrier window. Gaps below
>   `system_configs.FORECAST_MIN_CYCLE_DAYS` (3) are now ignored — a sub-3-day gap is a
>   retry, not a cadence. That line now correctly falls back to its carrier rule.
> * **The schedule suggestion snapped on the wrong number.** The chip labels are not the
>   execution days: `RefillScheduleMath.safetyAdjustedDelayDays` maps 90→85, 30→28, 14→13.
>   Keying the snap on labels sent a measured 28-day cycle to the 14-day chip — double the
>   refill spend for no extra protection. Thresholds are now the execution days.
>
> **Proof (live, `zwxswagokhgbuzrrbnhr`):**
> * `refresh_usage_forecasts()` → `{"esim_samples":1,"forecasts":10,"alerts":0}`. 10 of 10
>   active lines have a forecast row; 0 alerts is correct, the nearest depletion is 17 days
>   out against a 7-day lead.
> * Both fitted paths proven in a rolled-back transaction, since live data exercises neither:
>   four synthetic refills 28 days apart → `topup_history`, `high`, `28.00` days, $4.00
>   suggestion; an eSIM at 1024→524 MB over 10 days → `esim_usage`, **50.00 MB/day**,
>   depletion in 11 days.
> * Alerting proven the same way with the lead widened to 20 days: **2** `line_critical`
>   notifications with real bodies ("B1 test Zong PK runs out in 17 days (around Aug 15). A
>   top-up of about $0.50 keeps it active."), an immediate re-run emitted **0** (dedup), and
>   a third in-window line was correctly suppressed because an active auto-refill already
>   executes before its predicted depletion. All rolled back; residue re-checked at zero.
> * Security probed as a real role, not as `postgres`: signed-in user sees **6 of 10** rows
>   (own only), `UPDATE` → `42501`, `anon SELECT` → `42501`, `esim_usage_samples` →
>   `42501`. `f0_grant_matrix_tests.sql` re-run with the four new functions: **6/6 PASSED**.
>   Advisors unchanged at **29**.
> * `flutter analyze` **134** (baseline, 0 errors, none in the new files);
>   `flutter test` **85/85** (76 baseline + 9 new in
>   `test/features/sim_lines/usage_forecast_test.dart`).
>
> **Nothing is required of the owner for this feature.** It runs tonight at 02:20 UTC.
>
> **Two caveats, stated plainly:**
> * Every live forecast today reads `carrier_rule`, because the database holds **zero**
>   completed top-ups spaced more than 3 days apart. The `topup_history` path is proven but
>   unexercised in production until real refills accumulate. This is a data-maturity limit,
>   not a code gap.
> * The card and sheet strings are hardcoded English, matching the surrounding code in
>   `scheduled_topup_sheet.dart` (which is also unlocalised). Folding them into ARB belongs
>   with suggestion **#12**, the localisation QA pass.
>
> **🐛 Unrelated drift found while registering this migration — FIXED.**
> `20260801100000_f4b_is_power_user_security_invoker.sql` had **no matching row** in
> `supabase_migrations.schema_migrations`: F0 left it stamped `20260729064937`, which sorts
> *before* the `20260801*` migrations it follows, so a `supabase db push` would have tried to
> re-run it. Re-stamped to `20260801100000` (owner-approved). G1's own four MCP-stamped rows
> were likewise collapsed into a single `20260802000000` row. The registry now matches every
> repo filename from F1 through G1:
>
> ```
> 20260801040000 f1_credit_wallet_refund_grant_lockdown
> 20260801050000 f2_debit_wallet_grant_lockdown
> 20260801060000 f2b_drop_ambiguous_debit_overload
> 20260801070000 f3_f4_rpc_grant_lockdown
> 20260801080000 f5_process_due_notifications_search_path
> 20260801090000 f6_table_grant_lockdown
> 20260801100000 f4b_is_power_user_security_invoker
> 20260802000000 g1_depletion_forecasting
> ```
>
> **This is the fifth migration drift this project has hit.** `apply_migration` stamps
> *today's* date while the repo uses future-dated round timestamps, so the two disagree by
> construction on every single migration. Check `list_migrations` against the filenames after
> every `apply_migration` — it is a one-row `UPDATE`, and only expensive once it is a replay.

**2 · Price-drop / best-offer watch** · *high value, low effort*
~~`provider_offers_cache` (783 offers) and `esim_offers_cache` refresh continuously and you keep
history nowhere. Add an `offer_price_history` table written by the two catalog workers, and a
`promo`-category notification when a watched country/carrier's best $/GB drops >10%. `promo` is
already the consent-gated category from C2, so the compliance work is done.~~

> ### ✅ BUILT 2026-07-29 — migration `20260803000000_g2_offer_price_watch.sql`
>
> Both halves shipped and proven on live data. No new credentials.
> **One thing is required of a user before any alert can arrive — see the last
> section.**
>
> **What exists now**
>
> | Object | What it is |
> |---|---|
> | `offer_price_history` | append-only price log for **both** catalogs. Deny-all — it holds eSIM wholesale. |
> | Four triggers | two per cache table (INSERT + a price-guarded UPDATE) — this is what actually writes the history. |
> | `offer_price_watches` | per-user watch list. Read/write-own, but only `is_active` + `threshold_percent` are the client's. |
> | `offer_watch_metrics(days)` | current vs baseline for every watchable subject. |
> | `sync_auto_price_watches()` | keeps `origin='auto'` rows in step with the user's SIM lines. |
> | `detect_offer_price_drops()` | the `promo` notification. |
> | `prune_offer_price_history()` | 180-day retention that never orphans an offer. |
> | `refresh_offer_price_watch()` | cron entry point → **`cron.job` 21, `40 2 * * *`, active**. |
> | Flutter | `OfferPriceWatch` model + providers, `PriceWatchScreen` at `/esim/price-watch`, a watch bell on the eSIM plans screen, and an entry tile under the `promo` toggle in notification settings. |
>
> **Four deliberate departures from the sketch above**, all written up in the
> migration header:
>
> 1. **Triggers, not the two workers.** Both catalog workers live on the
>    owner-gated VM (§ 5 of PROJECT_TOPOLOGY) — the same wall G1 hit. A row
>    trigger on each cache table captures every write regardless of who made it,
>    needs no deploy, and cannot drift from the worker code. The UPDATE triggers
>    carry a `WHEN` clause on the price columns, which matters: the offers worker
>    rewrites `refreshed_at` on all 783 rows every 10 minutes, so without it the
>    table would gain ~113k rows a day of pure noise.
> 2. **"$/GB" only applies to one of the two catalogs.** eSIM bundles carry
>    `data_amount_mb`, so best $/GB per country is exactly right. Top-ups do
>    not: `provider_offers_cache` holds airtime denominations with no data
>    amount, and `send_min`/`send_max` are NULL on every FIXED offer, so there is
>    not even a local face value to divide by. A $/GB there would be a fabricated
>    number. **Top-ups are tracked per offer instead** — "a top-up that cost
>    $1.11 now costs $0.67" — which is the honest comparable and, unlike a
>    country-level minimum, does not fire merely because a cheaper denomination
>    appeared. `metric_kind` says which of the two any row is.
> 3. **Watches are seeded from the user's own SIM lines.** A watchlist nobody
>    fills in is worth nothing — on this database that would be 0 rows against 10
>    active lines. `sync_auto_price_watches()` created **10** on the first run,
>    one per (country, carrier) a user actually holds a line on. eSIM watches
>    stay explicit: a destination someone browsed is a signal, one they already
>    bought is not.
> 4. **Consent is checked before the row is written, not only before dispatch.**
>    C2's `trg_fn_dispatch_notification` already gates promo *fan-out* on
>    explicit opt-in, so the push/email compliance really was done — but it still
>    writes the `notifications` row, which would put marketing in the in-app list
>    of users who never consented. `detect_offer_price_drops()` requires an
>    enabled `alert_settings` row before inserting anything.
>
> **The baseline is honest about how far back it can see.** For each offer it is
> the last price recorded at or before the 30-day cutoff, falling back to that
> offer's first-ever sighting when it is younger than the window. The migration
> seeds one row per offer (833) so a baseline exists from night one instead of
> night thirty-one. eSIM baselines apply *today's* markup to a historical
> wholesale price on purpose: that measures supplier movement, so raising
> `ESIM_MARKUP_PERCENT` cannot look like a price drop, and lowering it cannot
> market our own margin back to the user as one.
>
> **Two real defects the live data caught, both fixed before shipping:**
> * **`to_char(…, 'FM…9')` renders "1." and "5.".** FM strips the trailing zero
>   and leaves a bare decimal point, so the first eSIM body read *"Cheapest right
>   now: 1. GB for 7 days"* and any whole-number percentage would have read
>   *"5.% less"*. `0` after the point forces the digit.
> * **The bundle label contradicted the price beside it.** Rendering 1000 MB as
>   "1.0 GB" next to a $/GB computed from 1024 reads as an arithmetic error
>   ($1.11 for "1.0 GB" but "$1.14/GB"). The label now follows
>   `EsimPlan.formattedData` exactly — MB below 1024, GB above, integer when it
>   divides evenly — so the notification matches the plan card the user is
>   looking at.
>
> **Proof (live, `zwxswagokhgbuzrrbnhr`):**
> * `refresh_offer_price_watch()` → `{"watches_synced":10,"alerts":0,"history_pruned":0}`.
>   833 history rows seeded (783 top-up + 50 eSIM); 8 of the 10 watches are
>   priced, the other 2 (`KW/STC`, `OM/Omantel`) are real lines whose pair has no
>   cached offers — the UI says so rather than showing `$0.00`. **0 alerts is
>   correct**: every baseline was recorded minutes earlier, so nothing has moved
>   yet.
> * **The trigger guard proven, not assumed** (rolled back): a `refreshed_at`-only
>   rewrite — literally what the worker does every 10 minutes — appended **0**
>   rows; a real price change appended **1**; a new offer appended **1**.
> * **Top-up path** (rolled back): cheapest Zong PK offer cut 40% → `39.64%`,
>   **1** notification, *"Zong top-ups in Pakistan just got cheaper / A top-up
>   that cost $1.11 now costs $0.67 — 39.6% less than 30 days ago."*,
>   `delivered_via = {push}` (C2's dispatcher accepted it), immediate re-run
>   emitted **0** (cooldown).
> * **eSIM path** (rolled back): DE bundle cut 30% → best $/GB `1.6282 → 1.1366`,
>   **1** notification, *"Best price for Germany is now $1.14/GB, down 30.2% from
>   $1.63/GB. Cheapest right now: 1000 MB for 7 days at $1.11."*
> * **Thresholds proven in both directions:** a 5% cut emitted **0**; exactly
>   −10% emitted **1**; a per-watch `threshold_percent` of 45 suppressed the
>   39.64% top-up drop.
> * **Consent gating proven:** with promo off the detector returned 0 **and wrote
>   0 notification rows**; flipping the same row on produced the alert.
> * Security probed as a real role, not as `postgres`:
>   `supabase/tests/g2_price_watch_tests.sql` **14/14 PASSED** — signed-in user
>   sees 4 of 10 watches (own only), writing `last_alert_at`/`last_best_usd` →
>   `42501`, `SELECT offer_price_history` → `42501`,
>   `detect_offer_price_drops()` → `42501`, a watch for another user blocked,
>   `origin` not client-insertable. `f0_grant_matrix_tests.sql` re-run: **6/6
>   PASSED**. Advisors **29 → 30**, the one addition being `offer_price_history`
>   under `rls_enabled_no_policy` (INFO) — the intended deny-all. No new WARN or
>   ERROR.
> * Residue re-checked at zero: prices restored, 0 promo notifications, 0 probe
>   rows, 10 watches all `origin='auto'`.
> * `flutter analyze` **134** (baseline, 0 errors); `flutter test` **98/98**
>   (85 baseline + 13 new in `test/features/price_watch/offer_price_watch_test.dart`).
>
> **⚠️ One thing is required before a single alert arrives — and it is a user
> action, not an owner one.** `alert_settings` shows **0 of 8 users** have
> enabled `promo`. That is correct behaviour (C2 makes it opt-in for app-store
> compliance) and it is why the count above is 0 rather than a number. The
> tracking runs regardless; delivery does not. The app now makes this one tap:
> `PriceWatchScreen` leads with *"Price alerts are switched off"* and a **Turn on
> price alerts** button that flips the row, and notification settings has an
> entry tile directly under the Offers & Promotions toggle explaining what it
> delivers. Nothing here needs the owner's console.
>
> **Three caveats, stated plainly:**
> * **A price-drop alert still depends on F1.** With promo on, delivery uses the
>   same push path that reached nobody in 18 of the last 31 dispatches. The
>   in-app notification list works today; push does not, and that is F1's job,
>   exactly as this list predicted when it said #2 depends on it.
> * **`esim_offers_cache` holds 50 bundles covering ~50 countries, and France is
>   not one of them** — which is the country `EsimPlansScreen` defaults to. So
>   the bell on a fresh install creates a watch that will read "no offers cached
>   for this one yet" until the catalog worker pulls a fuller `/catalogue`. The
>   watch is correct; the catalog is thin. Not fixed here.
> * Screen strings are hardcoded English, matching the surrounding eSIM screens.
>   Folding them into ARB belongs with suggestion **#12**.
>
> **🐛 The migration drift hit again, sixth occurrence — FIXED.** `apply_migration`
> stamped this one `20260729124132` (today's clock), which sorts *before* every
> `20260801*`/`20260802*` migration it follows, so a `supabase db push` would
> have tried to replay the whole F-and-G series. Re-stamped to `20260803000000`;
> the registry again matches every repo filename from F1 through G2. **This is
> not intermittent — it happens on every single `apply_migration` call**, because
> the tool stamps the clock while this repo uses future-dated round timestamps.
> Diff `list_migrations` against `ls supabase/migrations` after every one.
>
> **🔎 Found while building this, deliberately not fixed here.**
> `alert_settings` still carries the full default `GRANT ALL` for **both** `anon`
> and `authenticated`, `TRUNCATE` included. F6 stripped exactly this from five
> tables and simply did not list this one. `TRUNCATE` is not RLS-filtered, and
> because `trg_fn_dispatch_notification` treats a *missing* row as enabled for
> every category except `promo`, truncating it is a **mass unmute**, not just
> data loss. Fixing it needs F6's full "prove every client write path still
> works" pass — that is its own change, not a line in a feature migration.

**3 · Gift / send credit to another user** · *high value, low effort*
~~One `SECURITY DEFINER` RPC (`transfer_wallet_credit(p_recipient_email, p_amount)`) doing a debit
+ credit in one transaction with a shared `reference_id`, reusing the existing atomic helpers —
after F0 locks them down. Strong referral flywheel for the expat/family use case, and a natural
fit with the household feature.~~

> ### ✅ BUILT 2026-07-29 — migration `20260804000000_g3_gift_wallet_credit.sql`
>
> Shipped and proven on live data. No new credentials, **no owner action, and —
> unlike G2 — no user action either**: it works the moment the app ships.
>
> **What exists now**
>
> | Object | What it is |
> |---|---|
> | `transfer_wallet_credit(email, amount, ref, note)` | the whole feature. One `SECURITY DEFINER` RPC, `authenticated`-callable, debit + credit in one transaction under one shared `reference_id`. |
> | `gift_sent` / `gift_received` | two new `wallet_transactions` types, added to the type CHECK. Both halves carry a `metadata.gift` block naming the counterparty and the note. |
> | 2 partial unique indexes | `uq_wallet_txns_gift_sent_ref` / `…_received_ref`. The pre-check is the convenience; these are what make a double-submit impossible under a race. |
> | 4 `system_configs` rows | `GIFT_MIN_USD` 1.00, `GIFT_MAX_USD` 100.00, `GIFT_DAILY_MAX_USD` 250.00, `RATE_LIMIT_GIFT_CREDIT` 5/60. Read at call time — retuning is an `UPDATE`, not a migration. |
> | Flutter | `GiftTransferResult` + a `WalletTransactionGift` extension, `WalletContract.sendGift`, a **Send Credit** action on the wallet screen, `GiftCreditSheet` behind the same biometric guard as a deposit, and gift rendering in the ledger. |
>
> **Three deliberate departures from the sketch above**, all written up in the
> migration header:
>
> 1. **The credit half is inline; only the debit half reuses a helper.** The
>    sketch says "reusing the existing atomic helpers", and the debit does
>    exactly that — `debit_wallet_for_topup` carries F2's *call-depth* guard, so
>    a nested call passes, the same way `pay_plan_fee_from_wallet` already works.
>    The credit cannot: F1 gave `credit_wallet_for_refund` an **absolute** guard
>    that raises KS403 whenever `request.jwt.claims` names any role but
>    `service_role`, at any depth. **Probed on the live database before writing a
>    line of this** — a `SECURITY DEFINER` wrapper calling it under an
>    `authenticated` JWT returned *"BLOCKED [KS403] credit_wallet_for_refund is
>    not callable by role authenticated"*. Following the sketch literally would
>    have meant relaxing the strictest guard on the one function that mints
>    balance from nothing — reopening F-1 to save fifteen lines. Inlining instead
>    means **there is still no function reachable from an authenticated JWT that
>    credits a wallet without first debiting another one in the same
>    transaction.**
> 2. **A gift is not a refund, so it is not booked as one.** Even with the guard
>    relaxed, `credit_wallet_for_refund` runs
>    `total_spent = GREATEST(0, total_spent - amount)` — it reverses a spend,
>    because that is what a refund is. Crediting a gift through it would erase
>    lifetime spend the recipient really incurred, and two friends passing $20
>    back and forth would drive both counters to zero. A gift is an inflow: the
>    recipient's `total_deposited` rises, exactly as `credit_wallet_for_deposit`
>    does it.
> 3. **Only real money is giftable.** "Strong referral flywheel" cuts both ways —
>    the frictionless version is also a promo-credit laundromat (register *n*
>    accounts, collect *n* signup bonuses, funnel them into one wallet). The
>    transferable amount is capped at `LEAST(balance, deposits + gifts_received −
>    gifts_sent)`, computed **from the ledger**. Not from `wallets.total_deposited`:
>    that counter reads **0.00 for six of the eight users** who demonstrably have
>    `deposit` rows, so a rule keyed on it would lock three quarters of the user
>    base out of a feature they are entitled to. The ledger cannot drift — it is
>    what the balance is made of.
>
> **The enumeration surface is the recipient lookup, and only the recipient
> lookup.** This RPC is the one place in the app where an arbitrary email can be
> tested against the user table, so the 5/hour limiter is consumed on the line
> immediately before it — never earlier. Failed lookups land in `security_logs`
> with the address SHA-256'd. Suspended accounts and accounts with an open
> deletion request are refused on **both** sides: D3's pipeline freezes then
> drains a leaving user's wallet, so gifting into one burns the money and
> gifting out of one is the drain D3 exists to prevent.
>
> **Two real defects the live probes caught, both fixed before shipping:**
> * **The limiter was in the wrong place.** The first version consumed a token at
>   the top of the function, so a mistyped *amount* cost one of five recipient
>   lookups. The probe run locked the sender out after five typos — visible as
>   three consecutive rejections coming back "Too many transfers just now"
>   instead of "The smallest gift is $1.00". Everything above the lookup is about
>   the caller or the caller's own money and reveals nothing, so the limiter
>   moved down. The enumeration bound is identical; the UX is not. Proven: four
>   local rejections now leave **0** rows in `rate_limit_buckets`.
> * **A tautological assertion in the test suite.** T12 read
>   `x < x - 7.50 + 7.50`, which is `x < x` — it could never fail. It now
>   captures `total_deposited`/`total_spent` before the transfer and asserts the
>   exact ±7.50 delta, which is what makes departure 2 above a tested claim
>   rather than a comment.
>
> **Proof (live, `zwxswagokhgbuzrrbnhr`, every transaction rolled back):**
> * **Happy path**: $12.34 from an $85.20 wallet → sender `85.20 → 72.86`,
>   recipient `35.86 → 48.20`, **sum of all balances unchanged**. One
>   `reference_id` on both halves; ledger rows *"Gift to
>   a1-wallet-test@example.com"* / *"Gift from Speakhealth"*; both `metadata.gift`
>   blocks correct; recipient notification *"You received $12.34 / Speakhealth
>   sent you $12.34 of KeepSIMs credit. \"Happy birthday!\""* with
>   `delivered_via = {push}` — C1's dispatcher accepted it.
> * **Idempotency**: replaying the reference id returned `already_sent: true` and
>   left **1** `gift_sent` + **1** `gift_received` row, balance unmoved. The
>   indexes proven separately: a hand-inserted second row of either type on the
>   same ref → **23505**.
> * **Every rejection path**, each with its own code: self-gift, unknown
>   recipient (+ 1 `security_logs` row), malformed email, zero and negative
>   amounts, below minimum, above maximum, anon caller, suspended sender,
>   suspended recipient, sender with a frozen deletion request, recipient with an
>   open one.
> * **Giftable rule proven at the boundary**: with deposits reduced to exactly
>   $4.00, **$4.00 sends and $4.01 does not**; the next $1.00 is refused with
>   *"Available to send: $0.00"*; an all-promo balance sends nothing; and a
>   **received** gift *is* re-giftable by a user with no deposits of their own —
>   which is what makes the household case work, one person funding and the
>   credit moving on through the family.
> * **Daily cap proven in both directions**: under a $10 cap, $6.00 sent, a
>   second $6.00 refused with *"Sent in the last 24 hours: $6.00"*, then $4.00
>   landing exactly on the cap accepted.
> * **Rate limit**: 5 lookups leave 3.00 tokens after 2, and the 6th returns
>   `KS429`; the four purely-local rejections consume nothing.
> * `supabase/tests/g3_gift_credit_tests.sql` **18/18 PASSED**, probed as a real
>   `authenticated` role. `f0_grant_matrix_tests.sql` re-run **6/6 PASSED** —
>   `transfer_wallet_credit` is now an explicit allow-list entry there, which is
>   the deliberate act that file asks for, and its own auth checks are the
>   allow-list's required companion tests (T5/T15/T16/T17).
> * Residue re-checked at zero: 0 gift rows, 0 probe deposits, 0 gift
>   `security_logs`, 0 rate-limit buckets, 0 `account_deletions`, 0 suspended
>   profiles, `GIFT_DAILY_MAX_USD` back at 250.00, a1 still **$35.86**, all
>   balances summing to **$417.46**.
> * `flutter analyze` **134** (baseline, 0 errors, none in the new files);
>   `flutter test` **116/116** (98 baseline + 18 new in
>   `test/features/wallet/gift_credit_test.dart`). Advisors **30 → 31**, the one
>   addition being `transfer_wallet_credit` under
>   `authenticated_security_definer_function_executable` (WARN) — the same class
>   the other nineteen allow-listed RPCs already carry, and the point of the
>   feature. No new ERROR.
>
> **Nothing is required of the owner or of any user.** The three limits are
> `system_configs` rows the owner can retune live if 5/hour or $100/transfer
> proves wrong.
>
> **Three caveats, stated plainly:**
> * **The in-app notification works today; push is still F1's problem.** Unlike
>   G2, this does not need an opt-in — `wallet_credit` is a C1 default-ON
>   category, so the row is written and dispatched for every user. Whether the
>   push actually *lands* is the same F1 gap that affected 18 of the last 31
>   dispatches. The recipient sees the money and the notification in the app
>   regardless; the ledger is the receipt.
> * **The household quick-picks are unexercised.** `household_members` has **0
>   rows** on this database, so the chips that pre-fill a member's address render
>   nothing today. The code degrades to an ordinary email field and costs ~20
>   lines; it is correct but unproven against real data.
> * Sheet and ledger strings are hardcoded English, matching the surrounding
>   wallet screen. Folding them into ARB belongs with suggestion **#12**.
>
> **🐛 The migration drift hit again, seventh occurrence — FIXED.**
> `apply_migration` stamped this one `20260729131926`, which again sorts *before*
> every `20260801*`–`20260803*` migration it follows. Re-stamped to
> `20260804000000`. The registry matches every repo filename F1 → G3. This is not
> intermittent and it is not going to stop: the tool stamps the wall clock while
> this repo uses future-dated round timestamps, so **they disagree on every
> single call**. Diff `list_migrations` against `ls supabase/migrations`
> afterwards, every time.
>
> **🔎 Found while building this, deliberately not fixed here.**
> **`wallets.total_deposited` is wrong for six of eight users** — it reads
> `0.00` against ledgers holding $43.20–$243.20 of `deposit` rows, because those
> credits were written without going through `credit_wallet_for_deposit` (which
> is the only path that increments it). `total_spent` is off the same way. G3
> works around it by deriving everything from the ledger, so nothing here depends
> on the counters — but anything that *does* trust them is reading fiction, and a
> backfill plus a reconciliation check belongs with F6's ops pass, not in a
> feature migration. Also still open from G2: `alert_settings` retains the
> default `GRANT ALL` (incl. `TRUNCATE`) for `anon` and `authenticated`.

**4 · Home-screen widget + iOS Live Activity for data remaining** · *high perceived value*
~~Android `home_widget` + Glance, iOS WidgetKit. Feed it from the offline cache so it renders
with no network. This is the feature travellers screenshot, and it costs no backend work.~~

> ### 🟡 BUILT 2026-07-29 — Android shipped and proven on a device; iOS written but **not compiled**
>
> "Costs no backend work" was right: **zero migrations, zero Edge Functions, zero new
> credentials, nothing added to the security perimeter.** The Android half is done and
> was verified rendering live data on an emulator. The iOS half is source-complete and
> unverifiable from this workstation — there is no Mac, no Xcode and no Apple Developer
> account, so the widget-extension target does not exist in `Runner.xcodeproj` and not
> one line of the Swift has been through a compiler. **That half is an owner task**, and
> it is stated as such everywhere it appears rather than counted as delivered.
>
> **What exists now**
>
> | Object | What it is |
> |---|---|
> | `widget_snapshot.dart` | Pure Dart. Picks the subject closest to dying across SIM lines *and* eSIMs, formats it, and encodes one JSON payload. No plugin, no Riverpod, no Supabase — so every selection and formatting rule is unit-testable. |
> | `home_widget_publisher.dart` | The only file that touches the `home_widget` plugin. Best-effort throughout: a launcher failure must never reach the app. |
> | `home_widget_sync.dart` | Mounted once from the app root. Watches the same providers the dashboard does, republishes only when the payload actually changed, and routes widget taps back into the app. |
> | `usageForecastsProvider` | **New** (G1's table, all rows, disk-cached). The per-line provider was a live read for one screen; the widget needs the whole set to survive a cold offline start. |
> | `KeepSimsWidgetProvider.kt` + layout/drawables/`appwidget-provider` XML | The Android widget. RemoteViews, one responsive provider, 6-hour update period. |
> | `ios/KeepSimsWidget/*.swift`, `ios/Shared/KeepSimsActivityAttributes.swift`, `ios/Runner/LiveActivityBridge.swift` | WidgetKit widget + ActivityKit Live Activity + the MethodChannel that drives it. **Uncompiled.** |
> | `live_activity_service.dart` + `LiveActivityPinButton` | Dart bridge, and the one-tap "Pin to Lock Screen" that is the only way an activity ever starts. Renders nothing on any platform that cannot show one, Android included. |
>
> **Four deliberate departures from the sketch.**
> 1. **RemoteViews, not Glance.** Glance needs the Compose compiler plugin in the app
>    module — a build-system change on a project whose Android build was, as it turns
>    out, already broken (see below). RemoteViews needs nothing, weighs nothing, and
>    renders the same tile. Worth knowing for **F7**: `home_widget` declares
>    `androidx.glance:glance-appwidget:1.1.1` itself, so **Glance ships in the APK either
>    way** — verified, `androidx/glance/appwidget` is present in three dex files. Writing
>    the widget in Glance would have cost build risk for no size saving.
> 2. **"Data remaining" means two different things, and the widget says which.** Only
>    eSIMs have a data metric; a physical SIM line has no megabyte count anywhere in this
>    product. Lines therefore count down *validity* — which is the thing KeepSIMs actually
>    protects — sourced from G1's `predicted_depletion_at`, falling back to
>    `validity_expires_at`, then `next_topup_due`. A line with none of the three renders
>    "— / no expiry known" instead of a fabricated zero.
> 3. **The countdown is re-derived natively, not baked in.** The payload carries an
>    absolute `depletes_at_ms`, and Kotlin/Swift recompute the day count at render time.
>    This is the difference between a widget that is right for a week with the app closed
>    and one that quietly goes stale — the exact case the feature exists for. Megabytes
>    are explicitly *not* recomputed (`metric_is_countdown: false`): they cannot move
>    without a sync, and the "updated Xd ago" line is what admits that.
> 4. **Nothing sensitive is on it.** No wallet balance, no ICCID, and phone numbers are
>    masked to `•••• 4567` — a nickname if one exists, otherwise the last four digits. The
>    payload lands in a store the launcher can read and is rendered on a screen anyone
>    standing nearby can see. Signing out publishes an empty payload, so the previous
>    account's lines do not stay legible on the device. This is asserted by a test, not
>    just by intent.
>
> **Proof — Android, on a real Android 16 emulator, rendering the live database:**
> * `flutter build apk --debug` **succeeds**; `aapt2` confirms the receiver
>   (`com.keep_sims.KeepSimsWidgetProvider`, `exported=false`), all 20 widget resources,
>   and `KeepSimsWidgetProvider` in `classes16.dex`.
> * `dumpsys appwidget` shows the system parsed the provider XML:
>   `updatePeriodMillis=21600000 resizeMode=3 widgetCategory=1 initialLayout=#7f0c0274` —
>   matching the compiled `layout/keepsims_widget` id exactly.
> * **Rendered on the home screen with real rows for user `e5a56433…`**: headline
>   *"B1 test Zong PK · **17** days left · Estimated"* in amber, then *"B1 test Etisalat
>   EG — 19 days left"* and *"Zain KSA Test Line — 22 days left"* in cyan. Those are the
>   live `sim_line_usage_forecast` values (17/19/23-at-02:20-UTC), and the colours are the
>   thresholds working: ≤21 days amber, above it cyan.
> * **The app publishes it itself.** With the shared store deleted and the app launched
>   cold, `HomeWidgetPreferences.xml` came back containing
>   `{"schema":1,"signed_in":false,…,"empty_message":"Sign in to see your SIMs","subjects":[]}` —
>   written by Dart, read by Kotlin, rendered by the launcher. The signed-out tile was
>   screenshotted showing exactly that string.
> * **The native re-derivation is proven by contradiction.** A payload was seeded whose
>   *baked* text still said `"metric":"17","metric_label":"days left"` and
>   `"severity":"ok"`, but whose timestamps said 3 days, 1 day and −2 days. With the app
>   process **not running**, the widget rendered **"3 days left"**, **"1 day left"** and
>   **"0 expired"** — the last one with a red dot, because an elapsed countdown forces
>   critical regardless of what was published.
> * **The eSIM path**: a 25% bundle rendered *"512 MB · data left"* with the cyan bar
>   filled to a quarter and the subtitle *"eSIM · 5 days left"* composed natively — and
>   the megabytes were **not** recomputed even though a timestamp was present, which is
>   the rule.
> * **The tap works**: `ActivityTaskManager: START … act=es.antonborri.home_widget.action.LAUNCH
>   dat=keepsims://widget/… cmp=com.keep_sims/.MainActivity`.
> * `flutter analyze` **134** (baseline, 0 errors, none in the new files);
>   `flutter test` **139/139** (116 baseline + 23 new in
>   `test/features/home_widget/widget_snapshot_test.dart`).
>
> **🐛 The Android app did not build at all, and that is now fixed.**
> Before any of this, `flutter build apk` failed on **`:sentry_flutter:compileDebugKotlin`**:
> the plugin (8.14.2) hardcodes `languageVersion = "1.6"` in its own `android/build.gradle`,
> and the Kotlin 2.2.20 pinned in `settings.gradle.kts` refuses outright — *"Language
> version 1.6 is no longer supported"*. Isolated to that module (`./gradlew
> :sentry_flutter:compileDebugKotlin` fails on its own, with no `:app` source involved),
> so it is toolchain drift, not this feature. `android/build.gradle.kts` now raises the
> language floor to 1.8 for any subproject below it. **This blocked every APK and every
> AAB, so it blocked F7 and the store submission entirely** — and nothing in the repo
> recorded it, which suggests no Android artifact has been built here in a while.
>
> **🔎 Found while building this, deliberately not fixed here.**
> **`getUserEsims()` reads five column names the `user_esims` table does not have.** The
> repository maps `lpa_activation_code`, `qr_code_url`, `esim_order_id`, `first_activated_at`
> and `last_synced_at`; the table (and the worker that writes it) uses `lpa_string`,
> `smdp_address`/`matching_id`, `order_id` and `last_usage_check`. Every one silently
> defaults — so **`UserEsim.lpaActivationCode` is `''` for every row in production**, which
> means the eSIM QR code and the manual SM-DP+/matching-id install details are rendered
> from nothing (`smdpAddress` falls back to a hardcoded `rsp.esim-go.com`, `matchingId`
> falls back to the ICCID). This is a delivery bug in the product's eSIM path, not a widget
> bug, and it belongs with **F5** or with F4's item 5. G4 works around it by keying its
> "is this eSIM worth showing" test on `status` alone. Also still open from G2/G3:
> `alert_settings` retains the default `GRANT ALL`, and `wallets.total_deposited` is wrong
> for six of eight users.
>
> **⚠️ What is NOT done, stated plainly.** The iOS half is **written, not working**. The
> Swift compiles in nobody's Xcode yet; `Runner.xcodeproj` has no widget-extension target,
> no App Group capability, and `ios/Runner/Runner.entitlements` is a new file the project
> does not reference. Live Activities additionally need iOS 16.1+ and a real device. The
> owner steps are item 12 of § 7. Until they are done, **the App Store build has no widget
> and no Live Activity**, and this feature should be described as Android-only.

**5 · "Roam or eSIM?" calculator** · *medium value, low effort*
C8 already detects the country via IP with zero permissions. Add the roaming tariff for the
user's home carrier (a small `carrier_roaming_rates` table, seeded for your top 20 corridors)
and show "3 days roaming ≈ $42 vs this 5 GB eSIM $11". Converts the geo trigger you already
fire into a purchase.

> ## ✅ BUILT 2026-07-30 — migrations `20260805000000_g5_roam_or_esim_calculator.sql` and `20260805010000_g5b_catalog_view_write_grant_lockdown.sql`
>
> **What shipped.** `carrier_roaming_rates` (16 published products, 6 carriers),
> two `SECURITY INVOKER` RPCs — `roam_or_esim_quote()` and
> `my_roaming_carriers()` — and a Flutter calculator at
> `/esim/roam-calculator?country=XX`, reachable from the geo screen (only when
> away from home) and from a new action on the eSIM plans screen. Baselines:
> `flutter test` **160/160** (139 + 21 new in
> `test/features/roam_calculator/roam_quote_test.dart`), `flutter analyze`
> **134** (baseline, 0 errors), advisors **31** (unchanged).
>
> ### Five design decisions worth not re-deriving
>
> 1. **One row is one purchasable product, not one corridor.** Carriers don't
>    sell "a roaming rate", they sell a shelf. Zong alone publishes four Saudi
>    Arabia bundles. Keying on `(carrier, destination, product)` lets the quote
>    pick the cheapest pack that actually covers the trip, which is what a
>    person does.
> 2. **`destination_country_code = '*'` is a real value.** Gulf and US carriers
>    sell one worldwide day pass (du AED 35/day, AT&T $12/day); South Asian
>    carriers sell per-destination packs (Jazz PK→AE). Four wildcard rows are
>    what turn 16 products into **89 priced corridors** — the review asked for 20.
> 3. **A day pass is a pack with `bundle_days = 1`.** No separate shape.
>    `bundle_data_mb IS NULL` means the pass publishes no cap of its own (AT&T
>    re-uses the domestic allowance), so only the day count drives the multiplier.
> 4. **No USD figure is ever typed.** `bundle_price_usd` is a `GENERATED` column
>    over `local_price / fx_rate_to_usd`. What is stored is the carrier's own
>    currency and price next to the FX rate and the date it was taken. Refreshing
>    FX is one UPDATE; nobody can quietly edit a dollar amount.
> 5. **Nothing here is `SECURITY DEFINER`, and that was the point.** The quote
>    runs as the caller: RLS on `sim_lines` is what stops you being quoted on
>    someone else's carrier, and retail pricing comes from the `esim_offers`
>    view, so the function never sees `wholesale_price_usd`. That sidesteps the
>    `current_user`-inside-DEFINER trap this project has shipped four times
>    (D5c, D5d, F4b, F1) and is why the advisor count did not move.
>
> ### Proven live
>
> All in rolled-back transactions against real users, with hand-computed
> expected values that matched to the cent:
>
> | Case | Roaming | eSIM | Verdict |
> |---|---|---|---|
> | user `e5a56433…` → **AE**, 7 d / 1 GB | Zong *UAE IR Bundle (2 GB / 7 d)* **$7.19** | 1 GB / 7 d **$2.94** | `esim_cheaper`, saves **$4.25** |
> | user `8a07a25b…` → **DE**, 5 d / 3 GB | Orange Egypt *auto-roaming 1 GB* × 3 **$20.79** | 3 × 1 GB / 7 d **$4.77** | `esim_cheaper`, saves **$16.02** |
> | → **SA**, 10 d / 2 GB | Zong *1 GB / 90 d* × 2 **$7.18** | — | `no_esim` |
> | → **BD**, 7 d / 1 GB | — | **$4.58** | `no_roaming_rate` |
> | → **AE**, 30 d / 10 GB | Zong × 5 **$35.95** | 3 × 1 GB **$8.82** | `esim_partial` — no saving claimed |
> | → **TR**, and → **PK** on a PK SIM | — | — | `no_data` |
>
> That last row is a correctness detail worth keeping: a carrier based **in** the
> destination is excluded, because using your Pakistani SIM in Pakistan is not
> roaming. Grants were probed too — `anon` gets `42501` on both RPCs and on the
> table; `authenticated` gets `SELECT` and `42501` on INSERT/UPDATE/DELETE/TRUNCATE.
>
> **And over the real REST API**, which is where this project has been burned
> before: a deliberately misspelled function returns `404 PGRST202`, while the
> **exact parameter set the Dart provider sends** (`p_country_code`, `p_days`,
> `p_data_mb`, and an explicit `p_carrier_id: null`) returns `401 42501` — so
> PostgREST resolves the signature and only the grant stops `anon`. The
> authenticated REST leg was proved at SQL level with role + JWT-claim
> impersonation, not with a real user's token; that is the one gap in the proof.
>
> ### 🔴 Found while building this, and fixed: anon could delete the entire catalogue
>
> `esim_offers` and `zendit_offers_cache` are read-only presentation views that
> are deliberately **not** `security_invoker` — that is what keeps
> `wholesale_price_usd` away from clients. But both still carried the database's
> default `GRANT ALL` to `anon` and `authenticated`, nobody having swept views
> when F6 swept tables. A simple view over one table is auto-updatable, so
> `DELETE` on it is a real PostgREST verb, and because the view runs as its owner
> (`postgres`) the RLS on the cache tables never applied.
>
> Proven as `anon`: `DELETE FROM esim_offers` → **50 of 50** bundles gone;
> `DELETE FROM zendit_offers_cache` → **780 of 783** offers gone. With nothing
> but the publishable key that ships inside the APK. The eSIM half isn't even
> self-healing the way the 10-minute top-up refresh is — `esim_offers_cache` is
> rewritten every 6 hours, so the store would simply be empty until then.
>
> **G5b** revokes every write verb on all four public views and re-grants only
> `SELECT`. Re-probed over REST with the shipped anon key: both DELETEs now
> `401 42501`, `GET /rest/v1/esim_offers` still `200` with retail prices intact.
> `security_invoker` was deliberately left alone — flipping it would close the
> bypass but break the reads *and* undo the markup isolation; removing the write
> verb closes it without touching either.
>
> ### ⚠️ What is NOT done, stated plainly
>
> * **The seeded tariffs are published prices, not confirmed ones.** Every row
>   has `is_estimate = true` and `verified_at = NULL`, carries its `source_url`,
>   and the UI footer says so with the date. This screen's call to action is
>   "buy our eSIM", so an unqualified competitor price on it would be marketing
>   dressed as information. **Owner item 13 in § 7** is the verification pass.
> * **Only 6 of 50 carriers have any tariff at all** — Zong, Jazz, du, stc,
>   AT&T, Orange Egypt. The other 44 got nothing rather than a plausible-looking
>   invention; searching for Vodafone Egypt, Zain KSA, Omantel and STC Kuwait
>   turned up no outbound roaming price that could be attributed to a page.
>   Those users get `no_roaming_rate`, which the UI states out loud.
> * **The eSIM catalogue cannot produce the review's own example.** All 50
>   bundles are 1 GB / 7 days and they cover **4 of the 21 supported countries**
>   (AE, BD, BH, DE) — the fetch is alphabetically truncated at A–D. There is no
>   5 GB bundle to put next to "$42 of roaming", so the quote reports
>   `esim_partial` instead of scaling one up into an imaginary 5 GB. **The
>   single highest-leverage thing that would make this feature better is fixing
>   the catalogue fetch, not adding tariffs.**
> * **Quantity is capped at 3** because `request_esim_purchase` caps it at 3, and
>   the checkout sheet has no quantity control at all — so a quote needing more
>   than one bundle routes to the plans screen instead of to a sheet that would
>   silently buy a third of the trip.
> * **Strings are hardcoded English**, matching G2 and G4. This adds to
>   feature #12's backlog.
>
> ### 🔎 Also found, deliberately not fixed here
>
> **32 public tables still carry the default `GRANT ALL` for `anon` and
> `authenticated`** — including `wallets`, `wallet_transactions`,
> `notifications`, `system_configs`, `carriers`, `countries`. G2's
> `alert_settings` note was one instance of a much wider gap; F6 stripped five
> tables. Measured non-destructively with `has_table_privilege`. Unlike the view
> hole above, this one is **latent, not live**: the only privilege in that set
> RLS does not gate is `TRUNCATE`, and PostgREST has no TRUNCATE verb.
> `DELETE`/`UPDATE`/`INSERT` remain RLS-gated (re-probed on `carriers`: 0 rows).
> It deserves its own sweep with the same "prove the app still works" pass F6
> did, not a line in a feature migration. Also still open: `getUserEsims()` reads
> five columns `user_esims` does not have (G4), and `wallets.total_deposited` is
> wrong for six of eight users (G3).

**6 · Family / fleet shared wallet with spend limits** · *high value, medium effort*
`household_members` with roles already exists. Add per-member monthly caps enforced inside the
same RPCs that already enforce rate limits, and a consolidated view. This is E5 made concrete
and is the highest-ARPU segment for a SIM-protection product.

> ## ✅ BUILT 2026-07-30 — migrations `20260806000000_g6_household_spend_limits.sql` and `20260806010000_g6b_household_spend_enforcement.sql`
>
> ### ⚠️ The premise above was wrong, and it changed the shape of the work
>
> "`household_members` with roles already exists. Add per-member monthly caps"
> assumes the shared wallet exists and only needs limiting. **It did not.** A
> `manager` could already *trigger* a refill on the owner's line — but
> `request_instant_refill` booked `topup_executions.user_id = auth.uid()`, and
> `worker_instant_refill.js` debits exactly that user. The member paid from
> their own wallet. Capping how much of the owner's money a member may spend
> caps nothing while the owner's money is unreachable.
>
> So G6 is two things: it makes the wallet genuinely shared, **and** it makes
> that sharing safe. The cap is not bolted onto sharing; it is what makes
> sharing shippable.
>
> ### Six decisions worth not re-deriving
>
> 1. **The cap IS the permission.** No `can_spend` boolean beside a
>    `monthly_cap_usd` — two knobs meaning one thing drift apart. One column,
>    `NOT NULL DEFAULT 0.00`, and **0 means may not spend**. Every existing
>    manager keeps paying their own way until an owner types a number. There is
>    deliberately no way to say "unlimited".
> 2. **The payer is booked on the execution; the actor sits beside it.**
>    `topup_executions.user_id` becomes the payer, new `acting_user_id` records
>    who pressed the button. That is what lets the owner's wallet fund the
>    refill **without touching `worker_instant_refill.js`**, which lives on the
>    owner-gated VM and cannot ship from here — the same wall G1 and G2 hit. The
>    existing *"Users can view household shared topup executions"* policy
>    already keys on `user_id` being the owner, so the member does not lose
>    sight of what they created.
> 3. **Spend is derived, never counted.** No `spent_this_month` column. G3 found
>    `wallets.total_deposited` reads 0.00 for six of eight users with real
>    deposits, because a counter is only as good as every path that remembers to
>    bump it. Month-to-date spend comes from `wallet_transactions` stamped
>    `metadata->>'spent_by'`, net of refunds matched on `reference_id`.
> 4. **In-flight executions count against the cap.** Checking only committed
>    ledger rows would let a member queue twenty refills that each pass and then
>    all debit. Reservation accounting, keyed on the *absence* of a ledger row
>    rather than on status, so it cannot double-count.
> 5. **Enforced twice, and the second one is the real one** — at request time
>    for a fast, legible refusal, and inside `debit_wallet_for_topup`, the only
>    place money actually moves.
> 6. **The cap exception is never raised inside `enforce_rate_limit`.** That
>    function ends in `WHEN OTHERS THEN RAISE NOTICE` and re-raises only KS429
>    and KS403 — a cap violation raised under it would be swallowed and fail
>    **open** on a money path. This is § 8's own F0 lesson, and it applied.
>
> ### 🐛 Two bugs in this feature, caught by proving it rather than by writing it
>
> Both would have made the cap silently useless, and neither was visible in the
> code:
>
> * **`route_topup_execution()` rewrites a new `refill_instant` from `pending`
>   to `routing` in a BEFORE INSERT trigger.** The first draft counted in-flight
>   executions as `status IN ('pending','processing')` — so it counted **nothing**
>   and queue-stacking sailed through. Found by inserting one and reading the
>   row back. Now lists all four non-terminal statuses, and filters to
>   `payment_gateway_code = 'wallet'` because a card-funded refill never touches
>   the owner's balance and must not eat their cap.
> * **`tr_calculate_topup_fees` adds the app fee in another BEFORE INSERT
>   trigger, and the worker debits `amount`, not `base_cost_usd`.** A $2.50
>   offer is charged **$2.58**. Checking the offer price would have let every
>   refill overrun the cap by its fee. The cap is now checked *after* the INSERT,
>   on the post-trigger `amount` returned by `RETURNING`; the `RAISE` unwinds the
>   insert with it, same statement, same transaction, nothing left behind.
>
> A third was caught by Postgres itself: the first `CREATE OR REPLACE` dropped
> the parameter defaults (`p_description`, `p_reference_id`, `p_txn_type`) and
> failed with `42P13`. The worker calls `debit_wallet_for_topup` with five named
> arguments and never passes `p_txn_type`, and PostgREST resolves RPCs by
> parameter name — silently dropping those defaults would have broken every
> wallet-funded refill in the product.
>
> ### Proven live, in rolled-back transactions against real users
>
> Owner `8a07a25b…` ($70.40 wallet, Vodafone EG line), member `e5a56433…`
> ($35.86), cap $6.00/month, $3.00/refill:
>
> | # | Case | Result |
> |---|---|---|
> | 1–2 | member refills the owner's line twice at $2.50 | booked `payer=owner acting=member`, **$2.58** each after the fee |
> | 3 | a third $1.25 refill | `KS402 HOUSEHOLD_CAP:OVER_MONTHLY_CAP:6.00:5.16:0.84` — **queue-stacking blocked** |
> | 4 | a $3.15 refill | `OVER_PER_TXN_CAP` |
> | 9–11 | the worker's exact five-argument debit | **owner $70.40 → $67.82; member untouched at $35.86** |
> | 12 | the ledger row | `user=owner`, `metadata={"spent_by":"e5a56433…","spent_for_owner":"8a07a25b…","household":true}` |
> | 13 | spend after the debit | `committed=2.58 in_flight=0.00` — no double count |
> | 14 | owner cuts the cap to $1 *after* queueing, then the worker debits | `KS402 OVER_MONTHLY_CAP` — **layer 2 holds** |
>
> **Regression proofs, which matter more than the feature ones.** An owner
> refilling their own line books `acting=NULL` and its debit writes
> `metadata={}` — the G6 block is inert. A manager the owner has **not** funded
> refills the owner's line and **pays from their own wallet**, `acting=NULL`:
> byte-for-byte the pre-G6 behaviour. The F-2 guard still refuses a direct
> `authenticated` call to `debit_wallet_for_topup` (`42501`), and the three
> internal functions (`household_spend_mtd`, `household_spend_check`,
> `resolve_household_payer`) are `service_role`-only — `42501` for both `anon`
> and `authenticated`. `anon` is refused on all three client RPCs.
>
> The owner's consolidated view and the member's own-allowance view both render
> against seeded data; funding a `viewer` is refused with `ROLE_REQUIRED`, a
> per-refill cap above the monthly cap with `INVALID_PER_TXN_CAP`, and a member
> trying to set a cap in someone else's household gets `NOT_FOUND` (RLS, not a
> hand-rolled check).
>
> Baselines: `flutter test` **178/178** (160 + 18 new in
> `test/features/household/household_spend_test.dart`), `flutter analyze`
> **134** (baseline), advisors **31 → 33** — both additions are
> `household_spend_summary` and `my_household_allowances` joining the documented
> `authenticated_security_definer_function_executable` list, which is the
> intended shape for a self-scoped read surface.
>
> ### ⚠️ What is NOT done, stated plainly
>
> * **Nobody is using this.** `household_members` has **0 rows** on the live
>   database, so every proof above is against seeded fixtures rolled back
>   afterwards. The feature is correct and unexercised, exactly as G3's
>   household quick-picks were.
> * **eSIM purchases are deliberately not chargeable to a household wallet.** An
>   eSIM is delivered to and installed by the buyer, `user_esims` binds it to
>   them, and an `esim_orders` row has no SIM line to resolve an owner from.
>   `request_esim_purchase` is untouched. A fleet manager buying eSIMs for staff
>   is a real case and it is **not** covered here.
> * **Scheduled/automatic refills are not redirected.** Only
>   `request_instant_refill` resolves a payer. A `scheduled_topups` row still
>   belongs to, and is paid by, the line owner — which is correct today, but
>   means "the household funds this line" is a manual act, not a standing one.
> * **The month is a UTC calendar month** with no timezone preference and no
>   proration. A cap set on the 28th gives a full month's headroom for three
>   days and then resets.
> * **Strings are hardcoded English**, matching G2/G4/G5. Adds to feature #12.
>
> ### 🔎 Also found, deliberately not fixed here
>
> `check_topup_rate_limit()` enforces a 10-second per-SIM-line cooldown by
> scanning `topup_executions` for *any* `refill_instant` on that line, ignoring
> who requested it. In a household, one member's refill therefore blocks another
> member's for ten seconds on the same line. Harmless at today's volumes and
> arguably correct as a duplicate-press guard, but it is a per-line lock being
> used as a per-user one, and it will read as a bug the first time two people
> share a fleet line. Still open from earlier features: 32 tables carrying the
> default `GRANT ALL` (G5), `getUserEsims()` reading five non-existent columns
> (G4), and `wallets.total_deposited` wrong for six of eight users (G3).

**7 · Auto-rescue top-up ("SIM insurance")** · *high value, low effort*
The event name `rescue_topup_triggered` is already in the C6 activity-log canon but nothing
emits it. Rule: if a line is `n` days from expiry **and** the user is unreachable/offline, spend
the minimum viable top-up from the wallet automatically, opt-in per line. This is literally the
product's promise ("SIM Shield") and is currently manual.

> ## ✅ BUILT 2026-07-30 — migrations `20260807000000_g7_auto_rescue_topup.sql` and `20260807010000_g7b_auto_rescue_engine.sql`
>
> `rescue_topup_triggered` has been in the canon since 2026-07-22 with nothing
> emitting it. It emits now. `sim_line_rescue_policy` holds the per-line opt-in,
> `run_auto_rescue()` is the engine, `cron.job` **22** runs it hourly at **:50**
> (clear of G1's 02:20 forecast refresh, so a rescue always reads a settled
> forecast), and a `SimInsuranceCard` on the SIM line detail screen is the
> switch. Baselines: `flutter test` **190/190** (178 + 12 new), `flutter
> analyze` **134** (baseline), advisors **33 → 34**.
>
> ### ⚠️ This is the first thing in the product that spends a user's money with nobody watching
>
> The guard list is the feature. A line is rescued only when **all twelve** hold:
> `RESCUE_ENABLED` is true · the line has `max_usd > 0` · it is `active` and not
> `protection_paused` · the owner is not suspended · G1's forecast says
> `days_remaining <= lead_days` · a warning was written ≥ `RESCUE_GRACE_HOURS`
> ago · the user has not topped up since it · nothing is already in flight · the
> forecast names a live, < 24h-stale offer · no rescue inside
> `RESCUE_COOLDOWN_DAYS` · the **post-fee** charged amount is within `max_usd` ·
> the wallet covers it. Anything short of twelve returns a `skipped` row naming
> the reason.
>
> ### Four decisions worth not re-deriving
>
> 1. **"Unreachable" could not mean what the review meant.** Keying off "we
>    warned them and it did not land" is unusable here: `line_critical` has
>    fired **zero** times in this database's history, `line_entering_grace`
>    exactly once (2026-07-09, with no `sim_line_id`), and F1 is still open — 18
>    of the last 31 push dispatches reached nobody. That definition would make
>    the feature either permanently inert or universally trigger-happy. So the
>    rescue runs its **own** two-phase clock: it writes the warning itself, waits
>    24 hours, then acts. The user is always warned before money moves, and the
>    in-app row is written regardless of whether push works — the part F1 cannot
>    break.
> 2. **The cap is the permission, again** — `max_usd NOT NULL DEFAULT 0`, and 0
>    means not insured. Same idiom as G6, same reason.
> 3. **It spends through the existing pipeline, not around it.** The rescue
>    inserts a `refill_instant` execution; `route_topup_execution()` flips it to
>    `routing` and `worker_instant_refill.js` claims it. No worker change — the
>    fourth feature in a row to route around the owner-gated VM — and it
>    inherits the offer-tampering check, the wallet debit, the refund reaper and
>    the `topup_success` notification for free.
> 4. **The policy lives in its own table, not on `sim_lines`.** That table's
>    column-level UPDATE grant has broken client writes twice already (D5c, D5e).
>
> ### 🐛 One bug, found by running the lifecycle twice instead of once
>
> A rescue clears `last_warned_at`, and G1's forecast does not refresh until
> 02:20 — so on the very next hourly run the line still read "1 day left, no
> warning on record" and the **warn phase fired again**, promising a top-up in
> 24 hours that the cooldown would then refuse. No double spend (proven: exactly
> one execution), but a misleading notification an hour after the problem was
> already solved. The cooldown check now sits **above** the warn phase rather
> than below it. A single-pass test would never have caught this.
>
> ### Proven live
>
> First, the safety proof that matters most: **a real, non-dry run against
> production data right now returns 0 rows and spends nothing**, because no line
> is insured.
>
> Then the full lifecycle in rolled-back transactions, on the real Vodafone EG
> line of user `8a07a25b…` ($70.40 wallet), insured at $5:
>
> | Step | Result |
> |---|---|
> | 20 days left | not considered |
> | 4 days left | **warned**, `line_critical` written, grace clock starts |
> | run again | `skipped — warned; 4 days left, rescue at 2` |
> | 1 day left | `skipped — inside the 24-hour grace window` |
> | grace expired | **rescued** — bought `VODAFONE_EG_OPEN`, charged **$0.26** of a $5.00 limit |
> | next two runs | `skipped — rescued already within 20 days`, **silent** |
>
> Exactly **one** execution (`routing / refill_instant`, `offer_value=800`), one
> `rescue_topup_triggered` activity row, and two notifications — the
> `line_critical` warning and the `system` receipt. The $0.26 is the honest
> minimum: G1 suggested $0.20, the offer's floor is $0.25, and
> `tr_calculate_topup_fees` added a cent.
>
> Every refusal path was proved individually: cheapest top-up over the limit ·
> wallet cannot cover it · a refill already in flight · line paused · owner
> suspended · insurance switched off · `RESCUE_ENABLED=false` · dry run decides
> `rescued` and creates **0** executions. And the grants: `anon` and
> `authenticated` both get `42501` on `run_auto_rescue()` and on writing
> `sim_line_rescue_policy` directly; `anon` gets `42501` on
> `set_line_rescue_policy()`; arming someone else's line returns `NOT_FOUND`.
> The `KS403` second-layer guard fired for real during testing when a stale
> `authenticated` JWT claim was still set — which is exactly its job.
>
> ### ⚠️ What is NOT done, stated plainly
>
> * **Nobody is insured.** `sim_line_rescue_policy` has 0 rows, so the cron runs
>   hourly and does nothing until someone flips the switch. Correct, and
>   unexercised in anger.
> * **It has never completed end to end**, because the last mile is the VM
>   worker. G7 creates the execution and proves the row; whether `Zendit`
>   actually delivers the top-up is the same unproven path every other refill
>   uses (§ 3.2 item 9 — production key still outstanding).
> * **Two of the ten live lines cannot be rescued at all**: Omantel and STC
>   Kuwait have `suggested_offer_id = NULL` in the forecast, so they return
>   `no top-up offer known for this line`. That is G1's catalogue coverage, not
>   a G7 bug, but it means "SIM insurance" is unavailable for those carriers.
> * **`RESCUE_ENABLED` defaults to `true`.** The per-line opt-in is the real
>   gate and defaults to off, so nothing can fire — but if you would rather the
>   whole subsystem be dark until you have watched one rescue yourself, set it
>   to `false` (owner item 14 in § 7).
> * **The forecast is the only clock.** `sim_lines.validity_expires_at` is NULL
>   on all ten live lines, so `days_remaining` from G1 is the sole input. A wrong
>   forecast is a wrong rescue; G1's confidence is `medium` and its method
>   `carrier_rule` on every current line.
> * Strings are hardcoded English, matching G2/G4/G5/G6.
>
> ### 🔎 Also found, deliberately not fixed here
>
> Some `suggested_amount_usd` values G1 produces are below what the carrier will
> actually sell — $0.20 against a $0.25 floor on Vodafone EG, and $0.26/$0.39/
> $0.50 elsewhere. G7 clamps up to the offer's `price_min_usd`, so the rescue is
> right, but anywhere else that reads `suggested_amount_usd` directly is
> quoting a price that cannot be bought. Worth a pass over G1's suggestion
> arithmetic. Still open from earlier features: the per-line (not per-user)
> refill cooldown (G6), 32 tables with default `GRANT ALL` (G5),
> `getUserEsims()`'s five phantom columns (G4), and `wallets.total_deposited`
> wrong for six of eight users (G3).

**8 · Web dashboard (Flutter Web) for support + admin** · *medium value, medium effort*
The admin app is a separate, non-versioned Flutter project edited in place. Folding a
role-gated web target into this repo gives you ticket replies (C7 currently requires the
Supabase dashboard), the `system_alerts` view F6 needs, and `keepsims.com/delete` for free.

**9 · Offline balance check by SMS** · *medium value, low effort*
The C4 inbound plumbing already resolves sender → user. Add a `BAL` keyword that replies with
wallet + line status over the same channel. Cheap, and it makes the offline mode feel alive
rather than fire-and-forget.

> ## ✅ BUILT 2026-07-30 — migrations `20260808000000_g9`, `…010000_g9b`, `…020000_g9c`; `sms-webhook` v3 and `waba-webhook` v3 deployed
>
> `BAL` works, and the offline channel now talks back. But two of the premise's
> three clauses turned out to be wrong, and the fixes are the bigger part of
> this change.
>
> ### 🔴 "The C4 inbound plumbing already resolves sender → user." It never could.
>
> `ingest_offline_refill()` matched the sender against **`profiles.phone`
> only** — and `profiles.phone` is **NULL for all 8 users**, because nothing in
> the Flutter app ever writes it. The column is in `AuthModel` on the read side
> and nowhere else. Every inbound message that had ever arrived would have been
> rejected `unknown_sender`. § 5 blames the zero `offline_refill_events` on
> provisioning; the deeper reason is that the resolver had nothing to match
> against, and would still have had nothing the day Twilio went live.
>
> `resolve_sender_user()` now tries `profiles.phone` (exact, then last-9) and
> then **`sim_lines.phone_number`** (exact, then last-9). That column *is*
> populated — all 10 live lines, all plausible international numbers, and no
> number claimed by two users, so the "exactly one match or refuse" rule holds.
> G9c repoints `ingest_offline_refill` at the same function, because a channel
> where `BAL` resolves you and `REFILL` does not is worse than one that does
> neither.
>
> ### 🔴 Every inbound message used to queue a $10 top-up
>
> Both webhooks passed the body straight to `ingest_offline_refill`, which read
> it only through `parseAmount()` — a regex for the first number. No keyword
> check existed anywhere in the path. So "hi", "who is this", **"STOP"** and
> indeed "BAL" all returned NULL from that regex, fell through to
> `offline_refill_settings.default_refill_amount`, and **queued a $10 refill**.
>
> This is not hypothetical: the one user with a populated
> `offline_refill_settings` row has `is_enabled = true`, a target line and a
> $10 default. Texting "hi" from their own SIM number would have spent $10.
>
> `handle_inbound_command()` now classifies first. Only `REFILL` (with or
> without an amount) or a bare amount spends money — which is exactly what the
> app has always documented (`app_en.arb`: *Send REFILL 5, REFILL 10 or
> REFILL 25*), so the documented contract is untouched. And **STOP now stops**,
> which is the one thing a messaging channel is never allowed to get wrong.
>
> ### Four decisions worth not re-deriving
>
> 1. **The whole conversation lives in the database.** `handle_inbound_command`
>    classifies, acts, logs and returns the reply text; the webhooks just carry
>    it. That is what stops SMS and WhatsApp drifting into two dialects, and it
>    makes the wording testable in SQL instead of only in Deno.
> 2. **An unknown sender gets silence.** Replying would turn the number into an
>    oracle for "is this phone a KeepSIMs user?" and bill us for an SMS to a
>    stranger. Logged, not answered.
> 3. **The reply is deliberately thin** — wallet total, up to three lines with
>    days remaining, nicknames or a `****1020` mask. Never a full number, an
>    ICCID or a transaction, because SMS is plaintext and caller ID is
>    spoofable. `BAL` is gated on the same `is_enabled` consent that governs
>    spending: we do not discuss someone's money over a channel they have not
>    switched on.
> 4. **The reply rides back in the TwiML response** — no outbound API, no new
>    credentials, no per-message cost beyond the reply itself.
>
> ### Proven live, over the deployed HTTP endpoint
>
> Real `POST`s to `https://…/functions/v1/sms-webhook`, from a real registered
> SIM number:
>
> | Sent | Got back |
> |---|---|
> | `hi` | `200` + *"KeepSIMs commands: BAL for your balance, REFILL or REFILL 10 to top up, STOP to switch these off."* |
> | `BAL` | `200` + *"KeepSIMs / Wallet: $70.40 / ****1020: 18 days left / ****1090: 30 days left / ****9888: 30 days left / +3 more / Reply REFILL to top up."* |
> | `BAL` from an unregistered number | `200` + **empty TwiML** — silence |
>
> **`topup_executions` created by all three: zero.** Before G9 the first one
> alone would have queued $10. Test rows were deleted afterwards;
> `offline_command_log` is back to 0.
>
> In rolled-back transactions: the classifier is correct on all 28 shapes tried
> (including `BALLOON` → help, and `please top up my sim` → help, since neither
> *starts* with a keyword); a Twilio retry of the same `MessageSid` replays the
> identical reply rather than re-running the command; `STOP` flips
> `is_enabled` false and a following `BAL` answers `channel_disabled` with no
> financial data; and the refill path still queues correctly — `REFILL 5` → $5,
> bare `REFILL` → the $10 default clamped to the offer's $6.23 ceiling, bare
> `7` → the same clamp, all three stamped `refill_channel = 'sms'`.
>
> All four new functions are `service_role`-only: `anon` and `authenticated`
> both `false` on every one. Baselines: `flutter test` **190/190** and
> `flutter analyze` **134**, both unchanged — G9 touches no Dart. Advisors
> **34 → 35**, the single addition being `offline_command_log` joining
> `rls_enabled_no_policy`, which is the intended deny-all shape for a table
> holding raw sender phone numbers.
>
> ### ⚠️ What is NOT done, stated plainly
>
> * **No SMS has ever actually arrived**, because Twilio and WABA are still
>   unprovisioned (§ 7 owner item 1). Everything above is proved by posting the
>   provider's own payload shape at the real endpoint, not by a phone.
> * **WhatsApp classifies but cannot reply.** SMS answers for free in the TwiML
>   response; WhatsApp needs an outbound Graph API call, and
>   `WABA_ACCESS_TOKEN` / `WABA_PHONE_NUMBER_ID` do not exist. The code is
>   written and gated on their presence; until then a WhatsApp `BAL` is
>   classified correctly (so it does not spend money) and its reply is recorded
>   in `offline_command_log` and dropped. Two secrets, listed in § 7 item 15.
> * **Caller ID is not identity.** The whole channel trusts the sender's number.
>   Mitigated by the single-match rule, the opt-in, the thin reply and the
>   10/60min per-sender limit — but the real fix is an OTP-verified number at
>   capture time, and that does not exist because **the capture does not exist
>   either**. See below.
> * **Keywords are English plus two Arabic words** (`رصيد`, `شحن`). The other
>   seven supported locales fall back to English. A real gap for feature #12.
>
> ### 🔎 Also found, deliberately not fixed here
>
> **Nothing in the app collects the user's own phone number.** `profiles.phone`
> is read by `AuthModel` and written by nobody; the onboarding screen's
> `config['phone']` is a *carrier gateway* number, not the user's. Until there
> is a capture-and-verify flow, sender resolution rests entirely on the
> `sim_lines.phone_number` fallback this change added — which works, but means
> a user who has not registered the handset they are texting from cannot use
> the channel at all. That flow is its own feature: a field, an OTP round trip,
> and a `phone_verified_at` column. Still open from earlier: G1's
> `suggested_amount_usd` below carrier minimums (G7), the per-line refill
> cooldown (G6), 32 tables with default `GRANT ALL` (G5), `getUserEsims()`'s
> phantom columns (G4).

**10 · Device binding + velocity anti-fraud** · *defensive, medium effort*
Once real money flows: bind wallet top-ups to a device id, flag >N cards/accounts per device,
and add Firebase App Check on the Edge Functions. `security_logs` and `rate_limit_buckets` are
already there to build on.

> ## ✅ BUILT 2026-07-30 — migrations `20260809000000_g10` … `…040000_g10e`; `create-paypal-order` v5 and `capture-paypal-order` v3 deployed
>
> All five phases shipped. The premise held this time — `security_logs` and
> `rate_limit_buckets` really were the right things to build on, and the device
> id really did already exist. Two details of the brief's ground truth were
> wrong and are corrected below, but neither changed the design.
>
> ### What exists now
>
> | Object | What it is |
> |---|---|
> | `user_devices` | one row per (account, app install): platform, app version, `trust_state`, `attested_at`, `revoked_at`. PK `(user_id, device_id)` **plus a non-unique index on `device_id` alone** — one handset under many accounts is the signal, not a violation. Deny-all. |
> | `device_money_events` | append-only: every money attempt that reached a guarded RPC, with `assessed_decision` (what the model said) and `enforced` (whether it blocked). The source of every velocity count. Deny-all. |
> | `device_risk_allowlist` | per-user exemption, `reason NOT NULL`, optional `expires_at`. Deny-all. |
> | `normalize_device_id()` | `IMMUTABLE`, and enforced as a **CHECK constraint** so no writer — service_role included — can put attacker text in the column. |
> | `device_velocity(device, hours)` | the counters, callable by hand: "what does the model see for this device?" |
> | `assess_device_risk(user, device, action, amount)` | → `(allow \| challenge \| deny, reason, score, detail)`; writes one `security_logs` row per non-clean assessment. |
> | `guard_money_action(...)` | the single call a money path makes: touch, assess, record, return. |
> | `report_device_block(...)` | puts back the audit row that a *raised* refusal rolls back (see below). |
> | `device_risk_shadow_report(days)` / `app_check_summary(days)` | what the owner reads before turning anything on. |
> | `touch_user_device` / `my_devices` / `revoke_my_device` / `label_my_device` | the client surface. |
> | Edge Functions | `create-paypal-order` v5 verifies App Check **and** assesses device risk before it asks PayPal for an order; `capture-paypal-order` v3 verifies App Check only. |
> | Flutter | `DeviceIdentityService`, device id on all four money RPCs + both Edge calls, `firebase_app_check`, a **Your devices** screen at `/settings/devices`. |
>
> ### Nine decisions worth not re-deriving
>
> 1. **The device id was already there, and is not a UUID in secure storage.**
>    The brief said `flutter_secure_storage` and a UUID; it is **`SharedPreferences`**
>    under `keepsims_device_id`, holding 16 `Random.secure()` bytes as 32 hex
>    characters, written by `DeviceTokenRepository` since the push work. G10
>    *extracts* that generator into `DeviceIdentityService` — same key, same
>    format, so every existing install keeps the id the server already knows.
>    Change the key and you split every device in the database in two. A test
>    asserts the key string and asserts the format against the server's regex.
> 2. **`user_devices` is not `device_push_tokens`.** The push row is a delivery
>    address that gets nulled on sign-out. An anti-fraud registry that forgets a
>    device the moment its owner signs out is worthless, so this is its own
>    table.
> 3. **The four money RPCs were DROPped and recreated, not `CREATE OR REPLACE`d.**
>    Adding a parameter *overloads* rather than replaces, and two overloads is
>    `PGRST203` — the exact failure that silently broke both refill paths between
>    D5b and F2b. `p_device_id text DEFAULT NULL` is last in every signature, so
>    a shipped APK that knows nothing about it still resolves to the same
>    function.
> 4. **The guard sits after all validation and immediately before money moves.**
>    Not at the top: an attacker probing SIM line ids would otherwise fill
>    `device_money_events` with attempts that were never payments, and the
>    velocity counts would measure their probing instead of their spending.
>    Consequence: the idempotent early returns (`already_sent`, `already_paid`)
>    are *before* the guard, so a network retry replays the original answer and
>    does not log a second attempt.
> 5. **Each RPC refuses in its own existing dialect.** `request_instant_refill`
>    raises (new SQLSTATE **KS451**, no collision with KS402/KS403/KS429); the
>    other three return `{success:false, code:'DEVICE_BLOCKED'}`; the Edge
>    Function returns HTTP 403. Three shapes is not inconsistency, it is three
>    contracts left alone — which is what makes the regression proof possible.
> 6. **Nothing raises from inside `enforce_rate_limit`'s call tree.**
>    `guard_money_action` returns jsonb and the *caller* raises. `enforce_rate_limit`
>    ends in `WHEN OTHERS THEN RAISE NOTICE` and re-raises only KS429/KS403, so
>    anything thrown beneath it is swallowed and fails open on a money path.
> 7. **The score escalates with distance over a line, not with the number of
>    lines crossed.** One over the account cap is 40 (challenge); three over is
>    80 (deny). A single breach cannot deny unless it is far over, so the first
>    honest edge case is flagged, not refused.
> 8. **A missing device id costs 25 points, not zero.** An old build sends none,
>    so it must not be fatal; a script also sends none, so it must not be free.
>    Same for a brand-new device on a high-value deposit: it *scores*, and
>    deliberately cannot deny on its own — treating unknown devices as guilty
>    blocks every new customer's first deposit, and treating them as clean makes
>    rotating your device id cheaper than reusing it. That is the classic hole.
> 9. **The thresholds are hidden from clients.** `system_configs` is SELECTable
>    by every authenticated user (`USING (true …)`). Publishing "we deny at 4
>    accounts per device" to the people the control exists to stop is
>    self-defeating, so a **RESTRICTIVE** policy subtracts `DEVICE_RISK_%` from
>    that read without editing the existing permissive policies. Proven below.
>
> ### 🔴 The one thing that did not work, and what was done about it
>
> **A raised refusal rolls back its own audit row.** `request_instant_refill`
> refuses by RAISING, which aborts the transaction — and takes the
> `device_money_events` row and the `security_logs` row with it. This is not a
> hypothesis: the enforcement proof blocked all four paths and landed **3**
> event rows and **3** log rows, not four. The missing one is the refill.
>
> There is no autonomous-transaction escape here. `dblink` and `pg_background`
> are not installed; `pg_net` is, but its outbound queue is an ordinary table
> and rolls back too; `cron.schedule` writes `cron.job`, likewise. **Nothing
> written inside an aborting transaction can be made to survive it.**
>
> So `report_device_block()` re-runs the assessment in a fresh transaction, and
> the Flutter repository calls it from the `catch` that already handles KS451.
> Stated precisely: enforcement never depended on the client and still does not;
> the reason cannot be forged, because the function takes no reason argument and
> recomputes it server-side; a real user who hits a false positive leaves a
> record, which is the case § 4 of the brief cares about; and an attacker
> running a script can simply not call it — they are still blocked, and their
> ramp up to the threshold was logged the whole way by `device_risk_flag` and
> `device_risk_challenge`, which fire on paths that commit. Replays carry
> `reference_id = 'device_block_replay'` so no analysis counts them as attempts.
>
> The honest alternative was to make `request_instant_refill` return jsonb like
> its three siblings. That is a breaking change to a shipped money RPC — every
> installed APK does `return executionId as String` — and belongs behind a
> forced app update, not inside a feature whose whole regression story is "the
> ordinary path is unchanged".
>
> ### Proven live, in rolled-back transactions against the real database
>
> **The model.** Each row prints the counters `device_velocity` saw next to the
> decision, so the numbers are not taken on trust:
>
> | Scenario | accounts | cards | deposits | fails | → decision | reason | score |
> |---|---|---|---|---|---|---|---|
> | new user, new device, $10 | 1 | 0 | 0 | 0 | **allow** | clean | 0 |
> | new device, $400 deposit | 1 | 0 | 0 | 0 | **allow** | new_device_high_value | 25 |
> | 5 accounts on one handset | 5 | 0 | 0 | 0 | **challenge** | accounts_on_device | 40 |
> | 7 accounts on one handset | 7 | 0 | 0 | 0 | **deny** | accounts_on_device | 80 |
> | no device id at all | – | – | – | – | **allow** | missing_device_id | 25 |
> | `x' OR 1=1 --` as a device id | – | – | – | – | **allow** | missing_device_id | 25 |
> | 4 cards across 2 accounts (cap 3) | 2 | 5 | 0 | 0 | **challenge** | cards_on_device | 60 |
> | 6 cards across 2 accounts | 2 | 7 | 0 | 0 | **deny** | cards_on_device | 100 |
> | 11 deposit attempts / 24h (cap 8) | 2 | 0 | 11 | 0 | **challenge** | deposit_count | 60 |
> | …plus > $600 in the window | 2 | 0 | 12 | 0 | **deny** | deposit_count,deposit_total | 105 |
> | 5 failed captures (cap 4) | 2 | 0 | 0 | 5 | **allow** | failed_captures | 35 |
> | 8 failed captures | 2 | 0 | 0 | 8 | **deny** | failed_captures | 80 |
> | one row on the handset `trust_state='blocked'` | 2 | 0 | 0 | 0 | **deny** | device_blocked | 100 |
> | every row `trust_state='trusted'` | 7 | – | – | – | **allow** | device_trusted | 0 |
> | allowlisted user on a blocked handset | 8 | – | – | – | **allow** | allowlisted | 0 |
> | `DEVICE_RISK_ENABLED='false'` | 2 | 0 | 0 | 8 | **allow** | risk_disabled | 0 |
>
> **Enforcement, over the real RPCs, as the signed-in user
> `8a07a25b-…`, with `DEVICE_RISK_ENFORCE` flipped to true inside the
> transaction:**
>
> ```
> 1 request_instant_refill    SQLSTATE=KS451  MESSAGE=DEVICE_BLOCKED:accounts_on_device
> 2 transfer_wallet_credit    success=false code=DEVICE_BLOCKED reason=accounts_on_device
>                             | sender balance 70.40 -> 70.40
> 3 request_esim_purchase     success=false code=DEVICE_BLOCKED reason=accounts_on_device
> 4 pay_plan_fee_from_wallet  success=false code=DEVICE_BLOCKED reason=accounts_on_device
> 5 topup_executions created  0
> 6 esim_orders created       0
> 7 device_money_events       3 rows, 3 with enforced=true
> 8 security_logs             3 rows, types: device_risk_deny
> ```
>
> Row 7 is the finding above, in the raw output. After the Flutter catch path's
> `report_device_block`, the refill's record is back:
> `1 row(s); reference_id=device_block_replay decision=deny enforced=true reason=accounts_on_device`.
>
> **The regression proof matters more, and it passes.** As the same
> authenticated user, with the shipped config (`enforce=false`):
>
> * the **old four-argument call** — exactly what an installed APK sends —
>   resolves and returns an execution id: `faa9c859-167e-4ab2-b291-9e9696e6bca2`;
> * the **new five-argument call** produces
>   `status=routing type=refill_instant amount=4.64 base=4.5 offer=ORANGE_EG_4.5-I gw=wallet cur=USD`
>   — `routing` proves `route_topup_execution()` still fires, and `4.64` vs
>   `4.50` proves `tr_calculate_topup_fees` still fires. Both pre-G10 behaviours,
>   untouched;
> * the device event alongside it is
>   `action=instant_refill usd=4.50 decision=allow enforced=f reason=clean score=0`,
>   and **`security_logs` gained 0 rows** — a clean assessment writes nothing.
>
> **`security_logs` vocabulary**, one row per non-clean assessment, with the
> breach codes as a stable array in `metadata.reasons` and the counters beside
> them, so support answers "why was I blocked?" from a single row:
>
> ```
> device_risk_flag       "Device risk allow (new_device_high_value) on instant_refill"   reasons=["new_device_high_value"]  score=25
> device_risk_challenge  "Device risk challenge (accounts_on_device) on esim_purchase"   reasons=["accounts_on_device"]     score=60  accounts_on_device=6
> device_risk_deny       "Device risk deny (accounts_on_device) on plan_fee"             reasons=["accounts_on_device"]     score=100 accounts_on_device=8
> ```
>
> **App Check, verified against Google's live JWKS**, running the deployed
> `app_check.ts` unmodified under Node's WebCrypto (`node appcheck_proof.ts`,
> the file diffed byte-for-byte against the deployed source first):
>
> ```
> Google JWKS is live: 5 key(s), kty=RSA, alg=RS256, kid=00yavg
>
> no header at all                             missing
> not a JWT                                    invalid  {"reason":"not_a_jwt"}
> alg:"none" (alg confusion)                   invalid  {"reason":"bad_alg","alg":"none"}
> alg:HS256 (symmetric downgrade)              invalid  {"reason":"bad_alg","alg":"HS256"}
> RS256 + unknown kid                          invalid  {"reason":"unknown_kid"}
> RS256 + Google kid, junk signature           invalid  {"reason":"bad_signature"}
> attacker-signed, perfect claims              invalid  {"reason":"bad_signature"}
> [key trusted] valid token                    pass
> [key trusted] wrong iss                      invalid  {"reason":"bad_iss"}
> [key trusted] wrong aud                      invalid  {"reason":"bad_aud"}
> [key trusted] expired 10 min ago             invalid  {"reason":"expired"}
> [key trusted] no exp claim                   invalid  {"reason":"expired","exp":null}
> [key trusted] iat 10 min in future           invalid  {"reason":"issued_in_future"}
> [key trusted] 30s clock skew tolerated       pass
> [key trusted] payload tampered post-sign     invalid  {"reason":"bad_signature"}
> JWKS unreachable                             error    {"reason":"verification_error"}
> ```
>
> The last line is the one that matters operationally: "we could not tell" is
> `error`, never `invalid`, so a Google outage can never be mistaken for an
> attack. Both deployed functions were smoke-tested over HTTPS (they boot, reach
> their own auth check, and answer `401 UNAUTHORIZED: Invalid JWT token`), and
> the new CORS header list is live:
> `access-control-allow-headers: authorization, x-client-info, apikey, content-type, x-firebase-appcheck, x-keepsims-device`.
>
> **Grants, over the real REST API with the publishable key from
> `lib/core/supabase_client.dart`.** Every internal function answers `401` /
> `42501` — `guard_money_action`, `assess_device_risk`, `device_velocity`,
> `device_risk_config`, `device_risk_shadow_report`, `log_app_check_result`,
> `app_check_should_enforce`, `attach_device_money_reference` — and so do the
> four authenticated-only ones when called by `anon` (`touch_user_device`,
> `my_devices`, `revoke_my_device`, `report_device_block`). A deliberately
> misspelled name returns `404 PGRST202` instead, which is how you know
> PostgREST resolved every real signature including its argument names, rather
> than failing to find them. All four new/hardened tables answer `42501` to
> `GET`, `POST` and `DELETE`.
>
> **The thresholds are genuinely hidden.** Impersonating a signed-in user in
> SQL: 52 of 66 config rows visible, `DEVICE_RISK_*` → `<nothing — hidden>`,
> while `GIFT_MAX_USD`, `RESCUE_ENABLED` and `PAYPAL_MAX_DEPOSIT_USD` still read
> normally. The 14 rows exist; a client cannot see them.
>
> **Residue: none.** Every proof ran inside `BEGIN … ROLLBACK`. Afterwards
> `user_devices`, `device_money_events`, `device_risk_allowlist` and
> `security_logs` are all at **0 rows**, and `paypal_orders` (28),
> `topup_executions` (26) and `payment_methods` (2) are exactly where they
> started.
>
> ### The numbers, so the owner can argue with them
>
> Every threshold is a guess — no device id has ever been bound to a payment in
> this database. They are chosen so no honest user meets one by accident, and
> they live in `system_configs` so they can be retuned without a deploy.
>
> | Key | Default | Why that number |
> |---|---|---|
> | `DEVICE_RISK_ENABLED` | `true` | scoring and logging; the global brake |
> | `DEVICE_RISK_ENFORCE` | **`false`** | nothing is refused until the owner has read `device_risk_shadow_report()` |
> | `DEVICE_RISK_WINDOW_HOURS` | `24` | deposits only; accounts and cards are lifetime |
> | `DEVICE_RISK_MAX_ACCOUNTS` | `4` | a family sharing a tablet is 2–3; a shop demo device is more |
> | `DEVICE_RISK_MAX_CARDS` | `3` | distinct instruments across *all* accounts on the handset |
> | `DEVICE_RISK_MAX_DEPOSITS` | `8` | `RATE_LIMIT_PAYPAL_ORDER` is already 10/60min per user |
> | `DEVICE_RISK_MAX_DEPOSIT_USD` | `600` | above `PAYPAL_MAX_DEPOSIT_USD` (500), so one legal maximum deposit never trips it |
> | `DEVICE_RISK_MAX_FAILED_CAPTURES` | `4` | card testing's most direct fingerprint |
> | `DEVICE_RISK_NEW_DEVICE_MAX_USD` | `150` | a first deposit above this scores 25; it never denies alone |
> | `DEVICE_RISK_CHALLENGE_SCORE` / `DENY_SCORE` | `40` / `80` | one breach flags, a far-over breach or two breaches deny |
> | `DEVICE_RISK_MISSING_DEVICE_SCORE` | `25` | not fatal, not free |
> | `APP_CHECK_ENFORCE` | **`false`** | Android only, and only after the console work in § 7 |
>
> ### ⚠️ What is NOT done, stated plainly
>
> * **Nothing has ever been blocked, because nothing is enforcing.**
>   `DEVICE_RISK_ENFORCE` and `APP_CHECK_ENFORCE` both ship `false`. Turning
>   them on is § 7 item 16, deliberately, and it should follow a week of
>   `device_risk_shadow_report()`.
> * **"More than N cards per device" is unexercised and will stay that way.**
>   `payment_methods` holds **2 rows** and PayPal stores no cards here at all,
>   so this counter reads 0 in production today. It is built, it is proven
>   against synthetic rows in a rolled-back transaction, and it is currently
>   decorative. Said plainly rather than demonstrated with a staged fixture.
> * **Failed-capture velocity is retrospectively blind.** The device-linked half
>   can only see PayPal orders created after G10, and all 28 existing rows have
>   no device. The accounts-on-device half covers that, and the model takes the
>   greater of the two — but a device's first assessment inherits history rather
>   than owning it.
> * **App Check produces no tokens yet.** The client plugin is in
>   (`firebase_app_check ^0.4.5+2`, Play Integrity in release / debug provider
>   in debug), but until the owner registers the Android app in the Firebase
>   App Check console (§ 7 item 16) `activate()` yields nothing, the header is
>   absent, and every call records `missing`. That is why it ships
>   non-enforcing: switching it on while `missing` is the majority outcome
>   would lock out every user on an older build.
> * **iOS gets no attestation at all**, and cannot until the Apple Developer
>   account exists (§ 7 item 2). `app_check_should_enforce(platform)` refuses to
>   enforce for any platform not listed in `APP_CHECK_ENFORCE_PLATFORMS`
>   (default `android`), so flipping one flag cannot lock out every iPhone.
> * **`user_devices.attested_at` is written but not scored.** With enforcement
>   off the column is sparse, and scoring a sparse column would punish the
>   devices that behaved. It becomes a signal after App Check is real.
> * **A device id is still only a claim.** Someone who knows another user's
>   device id could register themselves on it and inflate that handset's
>   account count. It is a 128-bit random value that never leaves the device
>   except inside authenticated requests, and `trust_state='trusted'` plus the
>   allowlist are the remedies — but it is a property of the design, not an
>   oversight.
> * **The refill guard sees the pre-fee amount.** It runs before the insert, so
>   it assesses `base_cost_usd` ($4.50), not the charged `amount` ($4.64) that
>   `tr_calculate_topup_fees` produces. Immaterial today — refills feed no
>   monetary threshold, only deposits do — but worth knowing before adding one.
> * **Nine locales fall back to English** for the 17 new strings; Arabic is
>   translated. Same gap feature #12 exists to close.
>
> ### 🔎 Also found, deliberately fixed or reported
>
> * **`security_logs` carried the default `GRANT ALL` to `anon` and
>   `authenticated`** — one of the 32 tables F6 missed — with RLS on and zero
>   policies. Latent rather than live (RLS blocks every verb PostgREST can
>   reach, and TRUNCATE is not reachable through it), but this is now the table
>   that answers "why was I blocked?", so it has been revoked and re-granted to
>   `service_role` only. **31 tables to go.**
> * **`transfer_wallet_credit` was already a second writer to `security_logs`**
>   (`gift_recipient_not_found`), contradicting the brief's "the only writer is
>   `protect_is_power_user()`". It has never fired, which is why the table still
>   reads 0 rows.
> * **Migration registry drift, occurrence ten** — with a new cause. The MCP
>   `execute_sql` wraps a whole batch in one transaction, so a re-stamp
>   `UPDATE` issued in the same call as a `BEGIN … ROLLBACK` proof **is rolled
>   back with the proof**. `g10d` was stamped `20260730052033` until it was
>   re-issued on its own. Registry and repo filenames now match for all five
>   G10 migrations. *Always re-stamp in a call that contains nothing else.*
> * Still open from earlier: G1's `suggested_amount_usd` below carrier minimums
>   (G7), the per-line refill cooldown (G6), 31 tables with default `GRANT ALL`
>   (G5), `getUserEsims()`'s phantom columns (G4), and no phone capture flow at
>   all (G9).
>
> ### Baselines
>
> `flutter test` **190 → 206** (16 new; the id format is asserted against the
> server's regex verbatim, because if those two ever disagree every honest user
> silently scores as `missing_device_id`). `flutter analyze` **134**, unchanged.
> Advisors **35 → 43**, every addition intended and named: three new deny-all
> tables joining `rls_enabled_no_policy` (`user_devices`,
> `device_money_events`, `device_risk_allowlist`) and five new
> authenticated-callable `SECURITY DEFINER` functions (`touch_user_device`,
> `my_devices`, `revoke_my_device`, `label_my_device`, `report_device_block`) —
> the same shape as G6's `household_spend_summary()`, and the reason the tables
> can stay deny-all. **A release APK was built after adding
> `firebase_app_check`**, because G4's lesson was that a dependency can break
> the Android build silently: `√ Built build\app\outputs\flutter-apk\app-debug.apk`.

**11 · Multi-currency display** · *medium value, low effort*
Everything is USD internally (correct). Add a display-only FX layer (`profiles.display_currency`
+ a daily rates row in `system_configs`) — expats price things in home currency and this
measurably lifts conversion.

> ## ✅ BUILT 2026-07-30 — migrations `20260810000000_g11_fx_display_layer.sql` and `20260810010000_g11b_fx_refresh_engine.sql`; `refresh-fx-rates` v1 deployed
>
> The premise "everything is USD internally (correct)" held exactly, and that
> is the whole reason this was cheap. **Two of the brief's three nouns did
> not survive contact with the database**, and neither changed the design:
>
> * **`profiles.display_currency` did not need adding — `preferred_currency`
>   has been there since the first migration**, `authenticated` already held
>   column UPDATE on it (F6 kept it in the allow-list), and the onboarding
>   screen has been writing it for months. Adding a second column would have
>   created two that disagree. All 8 live profiles read `'USD'` because that is
>   the dropdown default and **nothing downstream had ever read the column** —
>   the missing piece was never the preference, it was any rate to apply to it.
> * **Rates are a table, not a `system_configs` row.** `config_value` is an
>   untyped varchar, so the suggested "daily rates row" would have put money-
>   adjacent numbers in free text where a fat-fingered `50.5` → `505` multiplies
>   every displayed price by ten with nothing to stop it. `system_configs` keeps
>   the *policy* knobs (`FX_DISPLAY_ENABLED`, `FX_MAX_AGE_HOURS`,
>   `FX_MAX_MOVE_PERCENT`, `FX_LAST_REFRESH_AT`), which is what it is good at.
>
> ### What exists now
>
> | Object | What it is |
> |---|---|
> | `fx_rates` | 14 currencies, `numeric(20,8)` + CHECKs. `authenticated` SELECT only; no write policy for anyone. |
> | `get_fx_display_context()` | The one call the client makes. Rate, symbol, digits, staleness verdict and the picker list. |
> | `refresh_fx_rates(jsonb, timestamptz, text)` | Applies a batch, one subtransaction per currency, returns a full report. `service_role` only. |
> | `tr_fx_rate_sanity` | Move-band circuit breaker (25%). |
> | `kick_fx_refresh()` + cron job 23 | 03:10 UTC daily, via the Vault shared secret. |
> | `refresh-fx-rates` (Edge Fn v1) | Fetches open.er-api.com. Validates before trusting a number. |
> | `lib/core/fx/` | `FxContext`, `FxController`, `Money.approxLocal`, `ApproxLocalText`. |
>
> ### Six things not to re-derive
>
> 1. **Nothing here may ever touch money, and the code enforces that by
>    omission.** There is deliberately **no local→USD helper anywhere**. The
>    RPC returns a *rate*, never a converted amount. The moment an input is
>    entered in EGP and divided back into dollars, rounding drift is inside the
>    money path and a $10.00 deposit becomes $9.99.
> 2. **Staleness is decided server-side and its fallback is USD.** Past
>    `FX_MAX_AGE_HOURS` (72) the RPC stops returning the currency at all and
>    answers `USD` / rate 1 / `fallback_reason`. A client deciding this would
>    disagree with the server whenever its clock was wrong. **This is the bug a
>    single pass misses** — the naive layer keeps rendering a three-week-old
>    rate as though it were today's, which is worse than not having the feature.
> 3. **A placeholder must NOT be defended by the circuit breaker.** Both halves
>    of this were load-bearing and are now *proven by real data*: TRY's seed was
>    34 and the first live quote 47.43, a **39.5% move**, so the band would have
>    refused it — and a refused UPDATE leaves `rate_source = 'seed'`, so
>    tomorrow's run would be refused identically, **forever**. Separately, the
>    provider stamps its payload ~00:02 UTC, *older* than the migration's own
>    seed timestamp, so a plain "never move the clock backwards" test skips
>    every currency on the first run. Both need the `'seed'` exemption.
> 4. **The feed may update currencies, never add them.** `refresh_fx_rates`
>    iterates over `fx_rates`, not over the payload — `display_name`, `symbol`
>    and `decimal_digits` are curated, and open.er-api.com alone would otherwise
>    inject ~160 rows into the picker overnight.
> 5. **No SECURITY DEFINER anywhere in G11** (tested for, case 1.5). After F4b's
>    four dead `current_user`-inside-DEFINER guards, the privilege boundary here
>    is a grant, which cannot rot into a no-op.
> 6. **plpgsql RAISE has no printf conversions**, and `'%%%'` parses as
>    literal-percent-then-argument — the opposite of the intended "42%". Spell
>    it `pct`.
>
> ### Fixed en route
>
> **`lib/core/utils/currency_formatter.dart` was a loaded gun**: a
> `CurrencyFormatter.format()` that relabelled a USD amount with any currency's
> symbol *without converting it*, so `format(12.50, currencyCode: 'EGP')`
> rendered "E£12.50". It was dead code — zero call sites — but it is exactly
> what a future session reaching for "make prices show EGP" would have found
> and wired up. Deleted and replaced by `Money`.
>
> **The onboarding currency dropdown offered 6 currencies** (USD/EUR/GBP/SAR/
> EGP/AED) while the country picker beside it has always listed India,
> Philippines, Pakistan and Jordan, and the app ships `tr`/`si`/`ne`/`bn`
> locales. The exact remittance corridors this feature is for had no currency to
> pick. Now 14, matching `fx_rates`.
>
> ### Proven
>
> 26/26 SQL cases (`supabase/tests/g11_fx_display_tests.sql`), 17/17 new Dart
> tests. Baselines now **flutter test 223/223**, analyze **134**, advisors
> **43** (all unchanged — the new table has an RLS policy and adds no DEFINER
> function). The refresh was run end-to-end against the live endpoint: all 13
> placeholders replaced with real quotes, and a second run correctly changed
> nothing. Pegs came back exactly as `carrier_roaming_rates` has them (AED
> 3.6725, SAR 3.75, JOD 0.709), which is a useful cross-check on both tables.
>
> ### Not done
>
> **0 of 8 users have a non-USD currency**, so in production this renders
> nothing for anybody until someone opens Settings → Preferences and picks one.
> Only 6 money surfaces are wired (wallet balance, eSIM plan list, eSIM
> checkout, PayPal deposit, and both refill sheets) out of ~88 `$x.xx` sites —
> the rest still show plain dollars, which is correct but plainer. The
> currency-picker strings are hardcoded English like the rest of G6/G7, so they
> are in scope for item #12 below.

**12 · Localisation QA pass** · *low effort, real risk reduction*
9 locales × ~10 features have been added incrementally by different sessions. Nobody has run a
pseudo-locale/RTL screenshot pass. One session with `flutter run --locale ar` over the 12 main
screens will find layout breakage that store reviewers will otherwise find first.

---

## 7. Owner checklist (nobody else can do these)

Per the "owner-account tasks: ask, don't delegate" rule — these need a login no agent has.
Ordered by what unblocks the most work:

1. **Meta WhatsApp Business + Twilio provisioning** (#2, #3) — unblocks F3 *and* half of F1.
2. **Apple Developer + APNs key + `GoogleService-Info.plist`** (#1) — unblocks F2 and the whole
   iOS half of the product.
3. **Resend API key + domain verification** (#4) — unblocks the only notification channel that
   can work today.
4. **Sentry project → DSN** (#5) — closes the last D5 gap.
5. **Android upload keystore + Play Console** (#6, #7).
6. **Rotate**: Supabase legacy JWT secret, Zendit sandbox key, **and the PayPal sandbox client
   secret that remains in git history** (A2).
7. **Host** `keepsims.com/privacy` and the web deletion page (#8).
8. **Confirm** the UptimeRobot monitor uses the full `/functions/v1/health` URL and has an
   alert contact attached.
9. **Delete** the `execute_zendit_recharge` Edge Function in the dashboard (410 tombstone; the
   MCP has no delete tool).
10. Decide on **eSIM supplier #2** (#11) — the business step behind F5, with the longest lead time.
11. 🆕 **Enable HaveIBeenPwned leaked-password protection** — Dashboard → Authentication →
    Passwords → enable the compromised-password check. *Added 2026-07-29: this is the only
    part of F0 that could not be completed, because there is no API or SQL toggle for it — it
    exists solely in the dashboard. It is the last remaining `security` advisor WARN that is
    actionable at all; everything else in that list is a documented accepted exception.
    Two minutes of clicking.*
12. 🆕 **Wire the iOS widget extension in Xcode** (feature #4). *Added 2026-07-29. Needs a
    Mac and the Apple Developer account from item 2, so it could not be done in-session.
    The Swift is written and sitting in the repo; this is wiring, not authoring. In Xcode,
    on `ios/Runner.xcworkspace`:*
    1. **File → New → Target → Widget Extension**, name it exactly **`KeepSimsWidget`**,
       untick "Include Configuration Intent", tick "Include Live Activity". Set its
       deployment target to **iOS 16.1**. Delete the placeholder `.swift` files Xcode
       generates and the `Info.plist` it creates — the repo already has both.
    2. **Add the existing files** to the new target: everything in `ios/KeepSimsWidget/`,
       and set the target's `Info.plist` to `ios/KeepSimsWidget/Info.plist` and its
       `CODE_SIGN_ENTITLEMENTS` to `ios/KeepSimsWidget/KeepSimsWidget.entitlements`.
    3. **Add `ios/Shared/KeepSimsActivityAttributes.swift` to BOTH targets** — Runner *and*
       KeepSimsWidget, one file with two checkboxes in the File Inspector. ActivityKit
       matches activities by that type; two copies in two modules are two different types
       and the Live Activity will silently never appear.
    4. **Add `ios/Runner/LiveActivityBridge.swift` to the Runner target.**
    5. **App Groups capability on both targets**, group id exactly
       **`group.com.keep_sims.widget`**. Point Runner's `CODE_SIGN_ENTITLEMENTS` at
       `ios/Runner/Runner.entitlements` (the file exists; the project does not reference it
       yet). Without this the extension reads an empty `UserDefaults` and the widget shows
       its placeholder forever — this is the single most likely thing to get wrong.
    6. **Build, and expect to fix compile errors.** None of this Swift has ever seen a
       compiler. Then on a real iPhone: add the widget to the home screen, and tap "Pin to
       Lock Screen" on a SIM line detail screen to check the Live Activity.
    *Everything else about feature #4 already works on Android and needs nothing from you.*
13. 🆕 **Verify the seeded roaming tariffs, and decide the disclosure wording**
    (feature #5). *Added 2026-07-30. Two parts, and only the first is strictly
    blocking:*
    1. **Verify.** All 16 seeded rows are prices read off a carrier's own public
       page and **never confirmed with the carrier**, so every one has
       `is_estimate = true` and `verified_at = NULL`. Open each row's
       `source_url`, check the number, then:
       ```sql
       UPDATE public.carrier_roaming_rates
          SET verified_at = CURRENT_DATE, is_estimate = false
        WHERE product_code = 'zong_ae_2gb_7d';
       ```
       The UI drops the "estimate only" caveat automatically for any row where
       `is_estimate` is false. Note Zong's and Jazz's figures are quoted
       **+ tax** on their own pages, and the seeded number does not add it.
    2. **Extend.** 44 of 50 carriers have no tariff at all — most importantly
       Vodafone Egypt, Etisalat Egypt, Zain KSA, Mobily, Etisalat (e&), Omantel
       and STC Kuwait, all of which real users hold lines on. None of them
       publishes an outbound roaming data price that could be sourced from a
       page. Anything you can get from a bill or a retail visit is worth more
       than anything findable online. Store the carrier's own currency and price
       and the FX rate — the USD column is generated from them:
       ```sql
       INSERT INTO public.carrier_roaming_rates
         (carrier_id, destination_country_code, product_code, product_name,
          bundle_data_mb, bundle_days, local_currency, local_price,
          fx_rate_to_usd, fx_rate_as_of, source_note, verified_at, is_estimate)
       SELECT ca.id, '*', 'vfeg_roam_1gb_7d', 'Roaming 1 GB / 7 days',
              1000, 7, 'EGP', 500.00, 50.50, CURRENT_DATE,
              'Read off the in-app roaming menu', CURRENT_DATE, false
         FROM public.carriers ca
         JOIN public.countries co ON co.id = ca.country_id
        WHERE co.iso_code = 'EG' AND ca.name = 'Vodafone Egypt';
       ```
    3. **A business call, not a technical one:** the screen names third-party
       carriers and prices them next to a product you sell. The current wording
       is deliberately conservative ("Roaming estimate only… confirm with your
       carrier before you travel", with a link to the carrier's own page).
       If your market has rules about comparative claims, this is the string to
       run past someone.
14. 🆕 **Decide whether auto-rescue should stay dark until you have watched one**
    (feature #7). *Added 2026-07-30. Not blocking — nothing can fire today,
    because `sim_line_rescue_policy` has 0 rows and a line is only insured once
    its owner sets a dollar ceiling. But `RESCUE_ENABLED` defaults to `true`,
    and this is the first automation in the product that spends a user's money
    with no human in the loop. If you would rather it stay inert until you have
    armed one of your own lines and watched a rescue land end to end:*
    ```sql
    UPDATE public.system_configs SET config_value = 'false' WHERE config_key = 'RESCUE_ENABLED';
    ```
    *To see what it would do without spending anything, at any time:*
    ```sql
    SELECT * FROM public.run_auto_rescue(true);   -- dry run, zero side effects
    ```
    *The other three knobs are `RESCUE_GRACE_HOURS` (24), `RESCUE_COOLDOWN_DAYS`
    (20) and `RESCUE_MAX_PER_RUN` (25), all in `system_configs`. Note the last
    mile still depends on the Zendit production key (§ 3.2 item 9) — until that
    is in place a rescue will create the execution and then fail at the
    supplier, refunding via the D5b reaper.*
15. 🆕 **Two WhatsApp secrets, so the offline channel can reply** (feature #9).
    *Added 2026-07-30. SMS already answers with no extra credentials — the reply
    rides back in the TwiML response. WhatsApp needs an outbound Graph API call:*
    * `WABA_ACCESS_TOKEN` — a permanent System User token with `whatsapp_business_messaging`
    * `WABA_PHONE_NUMBER_ID` — the numeric id of the sending number, from
      Meta Business Manager → WhatsApp → API Setup
    *Both go in Edge Function secrets alongside the `WABA_APP_SECRET` and
    `WABA_VERIFY_TOKEN` slots from item 1. Until they exist, a WhatsApp `BAL`
    is classified correctly — it will not spend money — and its reply is
    recorded in `offline_command_log` and dropped. Nothing breaks; the user
    just gets no answer on that channel.*
    *Related, and bigger: **nothing in the app asks the user for their own
    phone number.** `profiles.phone` is NULL for all 8 users and is never
    written. G9 works around it by resolving senders against
    `sim_lines.phone_number` instead, which is populated — but the proper fix
    is a capture-and-verify flow (field + OTP + `phone_verified_at`), and that
    is a feature someone has to schedule, not a secret you can paste in.*
16. 🆕 **Register Android for Firebase App Check, then decide when to enforce**
    (feature #10). *Added 2026-07-30. The server half is deployed and verifies
    every token against Google's JWKS; the app ships the plugin. What is
    missing is the console registration, which nobody but the account owner can
    do.*
    * **Play Integrity** — [console.firebase.google.com](https://console.firebase.google.com)
      → project `1679369602` → **Build ▸ App Check** → the Android app
      (`com.keepsims…`) → **Register** → provider **Play Integrity**. Requires
      the app to exist in Play Console and the Play Integrity API to be enabled
      in the linked Google Cloud project.
    * **Debug token, if you want to test on an emulator first** — run a debug
      build, copy the `DebugAppCheckProvider` token it prints to logcat, and
      paste it under **App Check ▸ Manage debug tokens**. A debug token is not
      attestation; the server treats it as a valid signature from Google and
      nothing more.
    * **iOS is blocked on item 2** (Apple Developer account →
      `GoogleService-Info.plist` → DeviceCheck/App Attest). Until then iOS
      records `missing`, which is harmless: `APP_CHECK_ENFORCE_PLATFORMS`
      defaults to `android` only.

    *Then, and only then, the two switches. Read the evidence first:*
    ```sql
    SELECT * FROM public.app_check_summary(7);          -- pass vs missing vs invalid
    SELECT * FROM public.device_risk_shadow_report(7);  -- rows with enforced=false
                                                        -- and assessed_decision='deny'
                                                        -- are who WOULD have been blocked
    ```
    *If that second query lists real customers, retune before enforcing:*
    ```sql
    UPDATE public.system_configs SET config_value = '6'
     WHERE config_key = 'DEVICE_RISK_MAX_ACCOUNTS';     -- e.g. loosen
    UPDATE public.system_configs SET config_value = 'true'
     WHERE config_key = 'DEVICE_RISK_ENFORCE';          -- the switch that refuses money
    UPDATE public.system_configs SET config_value = 'true'
     WHERE config_key = 'APP_CHECK_ENFORCE';            -- only once "missing" is rare
    ```
    *Setting `DEVICE_RISK_ENABLED = 'false'` stops the model dead at any time.
    For one customer who is wrongly caught, the 3am fix is a single row:*
    ```sql
    INSERT INTO public.device_risk_allowlist (user_id, reason)
    VALUES ('<user id>', 'ticket 1234 — confirmed legitimate shared tablet');
    ```
    *All thirteen `DEVICE_RISK_*` keys are listed with their reasoning in the
    feature #10 block in § 6. They are deliberately **not** readable by the app,
    so the Supabase dashboard (service_role) is where you edit them.*

---

## 8. Recommended next session

~~**F0.** It is the only item where the cost of waiting is unbounded: F-1 and F-2 are live,
exploitable with credentials that ship inside the APK, and every day the app is installed
anywhere is a day someone can mint or drain balance. Everything else in this document can wait
a week; that cannot.~~

> **✅ F0 was done on 2026-07-29 across three sessions** (`3acec84`, `7bb72a0`, `2e4039e`).
> Six findings closed, plus two more found during verification. **No known live security holes
> remain.**
>
> **The next session should be F1 — make notifications actually arrive.** With the money paths
> secured, delivery is now the top blocker: 18 of the last 31 push dispatches reached nobody,
> `device_push_tokens` holds 1 row for 8 users, and email has never executed once. It is also
> the item most entangled with owner provisioning (Resend key + domain), so starting it early
> surfaces those dependencies while there is still time to act on them.
>
> **Two things to carry into any future security work here** — both cost a cycle this session:
> 1. **Check for an exception catch-all before adding a guard.** `enforce_rate_limit` ends in
>    `WHEN OTHERS THEN RAISE NOTICE`, which would have swallowed the new guard *and* disabled
>    rate limiting, silently and fail-open.
> 2. **Check `pg_policies` before revoking `anon` EXECUTE from anything.** RLS policy
>    expressions run as the querying role, so a revoke can turn an empty result set into a hard
>    `42501`. That is what made F0.3's `is_power_user` item wrong.
>
> And the recurring one, now four occurrences deep (D5c, D5d, F-6a, and the F-1 guard review):
> **`current_user` is the function owner inside `SECURITY DEFINER`.** Any guard written against
> it is dead code. Guard on `request.jwt.claims`, and prove it with the grant temporarily
> restored so only the guard can be what blocks.
