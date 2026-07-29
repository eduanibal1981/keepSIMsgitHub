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

### ⚪ F8 — E-phase, resequenced

`E1` (Zendit + PayPal live) only after F0–F3. Then E2 (Reloadly failover), E4 (OTP tier),
E3 (local rails), E5 (fleet), E6 (helpdesk bridge).

---

## 6. Feature suggestions (with how to build each)

Ordered by value-per-effort for this specific codebase. Each says what already exists, because
most of these are 60% built already.

> **Progress:** #1, #2 and #3 all built 2026-07-29 (see below). Next unbuilt feature is **#4,
> the home-screen widget**. This list is independent of the Phase F plan in § 5 — F1
> (notifications actually arriving) is still the higher-priority item overall, and #2
> demonstrated why: its alerts are correct, consent-gated and proven, and they will still
> reach nobody until the push path works. #3 is the first of the three that is genuinely
> whole without F1, because its value lands in the recipient's balance rather than in a
> notification.

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
Android `home_widget` + Glance, iOS WidgetKit. Feed it from the offline cache so it renders
with no network. This is the feature travellers screenshot, and it costs no backend work.

**5 · "Roam or eSIM?" calculator** · *medium value, low effort*
C8 already detects the country via IP with zero permissions. Add the roaming tariff for the
user's home carrier (a small `carrier_roaming_rates` table, seeded for your top 20 corridors)
and show "3 days roaming ≈ $42 vs this 5 GB eSIM $11". Converts the geo trigger you already
fire into a purchase.

**6 · Family / fleet shared wallet with spend limits** · *high value, medium effort*
`household_members` with roles already exists. Add per-member monthly caps enforced inside the
same RPCs that already enforce rate limits, and a consolidated view. This is E5 made concrete
and is the highest-ARPU segment for a SIM-protection product.

**7 · Auto-rescue top-up ("SIM insurance")** · *high value, low effort*
The event name `rescue_topup_triggered` is already in the C6 activity-log canon but nothing
emits it. Rule: if a line is `n` days from expiry **and** the user is unreachable/offline, spend
the minimum viable top-up from the wallet automatically, opt-in per line. This is literally the
product's promise ("SIM Shield") and is currently manual.

**8 · Web dashboard (Flutter Web) for support + admin** · *medium value, medium effort*
The admin app is a separate, non-versioned Flutter project edited in place. Folding a
role-gated web target into this repo gives you ticket replies (C7 currently requires the
Supabase dashboard), the `system_alerts` view F6 needs, and `keepsims.com/delete` for free.

**9 · Offline balance check by SMS** · *medium value, low effort*
The C4 inbound plumbing already resolves sender → user. Add a `BAL` keyword that replies with
wallet + line status over the same channel. Cheap, and it makes the offline mode feel alive
rather than fire-and-forget.

**10 · Device binding + velocity anti-fraud** · *defensive, medium effort*
Once real money flows: bind wallet top-ups to a device id, flag >N cards/accounts per device,
and add Firebase App Check on the Edge Functions. `security_logs` and `rate_limit_buckets` are
already there to build on.

**11 · Multi-currency display** · *medium value, low effort*
Everything is USD internally (correct). Add a display-only FX layer (`profiles.display_currency`
+ a daily rates row in `system_configs`) — expats price things in home currency and this
measurably lifts conversion.

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
