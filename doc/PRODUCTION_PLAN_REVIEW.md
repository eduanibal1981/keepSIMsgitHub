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
> **F-2 through F-6 below are still open** — this session closed F-1 only.

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

### F-6 · Default `GRANT ALL` was never stripped — RLS is a single point of failure

`anon` and `authenticated` hold `INSERT, UPDATE, DELETE, TRUNCATE` at table level on
`profiles`, `sim_lines`, `scheduled_topups`, `esim_orders`, `user_esims`. Writes are blocked
today **only** by RLS policies (verified: `esim_orders` and `user_esims` have zero non-SELECT
policies, so writes are denied). That is one `DROP POLICY` away from a breach, and it is
inconsistent with the column-level lockdown D5d built for `sim_lines.plan_type`. `TRUNCATE`
is not RLS-filtered at all; it is unreachable over PostgREST today, which is the only reason
this is 🟠 and not 🔴.

---

## 2. Phase-by-phase review

### Phase A — Security · verdict: **incomplete, and the gap is the F-1/F-2 hole**

| | status | what the review found |
|---|---|---|
| A1 wallet revoke | ✅ table layer | Verified live: `wallets` / `wallet_transactions` grant only `SELECT` to `anon`/`authenticated`. **But** the RPC layer was never swept — see F-1/F-2. The *stated objective* ("balance changes only through server-side calls") is currently false. |
| A2 rotation | ❌ owner | Still outstanding: Supabase legacy JWT secret, Zendit sandbox key, and the **PayPal sandbox client secret that is in git history** (`paypal_refill_simulator_screen.dart` was deleted in D4 — deletion does not remove it from history). |
| A3 backend in git | 🟡 | `servers/*.js` (8 workers) are now committed **inside the Flutter repo**. Nobody has verified the VM runs *that* code — there is no deploy step, so repo and VM can silently diverge. Add a parity check (see F6). |
| A4 advisor sweep | ❌ | See F-5. `doc/RLS_MATRIX.md` exists but predates C7/C8/C9/D3 tables. |

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

### 🔴 F0 — RPC grant lockdown + a grant matrix that stays locked

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
   Still open: `credit_wallet`, `purge_deleted_accounts`, `prune_rate_limit_data`,
   `check_rate_limit_health`, `consume_rate_limit`, `enforce_rate_limit`,
   `trg_fn_award_referral_points`.)*
2. Add an in-body `auth.uid()` guard to `credit_wallet_for_refund` as defence in depth
   (`IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id THEN RAISE`), so a future
   re-grant is not instantly fatal. Same for the debit.
   *(✅ done for `credit_wallet_for_refund`, but **not with this predicate** — it does not
   stop the exploit, which credits the attacker's own wallet. Shipped guard keys on the
   `request.jwt.claims` role instead; use that shape for the debit too.)*
3. Revoke `anon` EXECUTE on the self-scoped RPCs that must stay `authenticated`:
   `export_user_data`, `apply_referral`, `request_account_deletion`,
   `cancel_account_deletion`, `redeem_referral_points`, `is_power_user`.
4. Strip default table privileges: `REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON` `profiles`,
   `sim_lines`, `scheduled_topups`, `esim_orders`, `user_esims` `FROM anon` and re-grant only
   what RLS actually needs to `authenticated` (column-scoped where D5d already set the pattern).
5. Fix `process_due_notifications` search_path; document the 2 `security_definer_view` ERRORs
   as accepted exceptions in `doc/RLS_MATRIX.md`; enable HaveIBeenPwned in Auth settings.
6. **Ship a regression test** — `supabase/tests/f0_grant_matrix_tests.sql` asserting, for every
   `SECURITY DEFINER` function in `public`, that its ACL is either service_role-only or on an
   explicit allow-list. This is the artifact that stops F-1 recurring.

**Acceptance:** the F-1 curl with a real user JWT returns `42501`; the F-2 anon curl returns
`42501`; `purge_deleted_accounts` as anon returns 401/403; the grant-matrix test passes; a real
refill and a real refund still work end-to-end (a1 fixture wallet must end at **$35.86**).

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

**1 · Depletion forecasting → smarter auto-custom refills** · *high value, medium effort*
You store `topup_executions` history and (for eSIMs) usage polls. Fit a trivial per-line
consumption rate (7/30-day rolling mean of data used ÷ days) and use it to (a) predict the
expiry/depletion date, (b) propose the auto-custom schedule instead of asking the user to
invent one, (c) fire `line_critical` earlier. Implementation: a `sim_line_usage_forecast`
materialised view + a nightly cron; the UI already has a health score to hang it on. No new
credentials.

**2 · Price-drop / best-offer watch** · *high value, low effort*
`provider_offers_cache` (783 offers) and `esim_offers_cache` refresh continuously and you keep
history nowhere. Add an `offer_price_history` table written by the two catalog workers, and a
`promo`-category notification when a watched country/carrier's best $/GB drops >10%. `promo` is
already the consent-gated category from C2, so the compliance work is done.

**3 · Gift / send credit to another user** · *high value, low effort*
One `SECURITY DEFINER` RPC (`transfer_wallet_credit(p_recipient_email, p_amount)`) doing a debit
+ credit in one transaction with a shared `reference_id`, reusing the existing atomic helpers —
after F0 locks them down. Strong referral flywheel for the expat/family use case, and a natural
fit with the household feature.

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

---

## 8. Recommended next session

**F0.** It is the only item where the cost of waiting is unbounded: F-1 and F-2 are live,
exploitable with credentials that ship inside the APK, and every day the app is installed
anywhere is a day someone can mint or drain balance. Everything else in this document can wait
a week; that cannot.
