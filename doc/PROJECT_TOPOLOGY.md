# KeepSIMs — how the pieces connect

Onboarding map for an agent that has never seen this project. Read this before touching
anything. It answers: *where does each thing live, who is allowed to change it, and how do I
prove a change landed?*

**Verified live on 2026-07-29** unless a line says "per project records" — those come from
earlier sessions and should be re-checked before you rely on them.

---

## 1. What this is

A Flutter mobile app (Android-first) that keeps prepaid SIM lines from expiring: it schedules
and executes mobile top-ups through wholesale suppliers, funded from an in-app USD wallet, and
also resells eSIMs. Money is real. **Every balance-moving path is server-side by design — the
client is never trusted with a price or a debit.**

Scale today: 8 users, 10 SIM lines, 165 wallet transactions. It is pre-launch, but the wallet
and supplier accounts are live, so treat all data as production.

---

## 2. Local project folder

`C:\Users\abdal\Work\KeepSIMs\keep_sims` — the Flutter app **and** the worker source and the
SQL, all in one repo.

| path | what it is |
|---|---|
| `lib/` | Flutter app. Feature-first: `lib/features/<feature>/{data,domain,presentation}`, shared code in `lib/core/`. Riverpod for state. |
| `lib/core/supabase_client.dart` | Supabase URL + anon key (compile-time overridable). The anon key ships in the APK — **treat it as public**. |
| `supabase/migrations/*.sql` | Schema history. Naming convention: `<timestamp>_<phase>_<description>.sql` with **round manual timestamps**. |
| `supabase/functions/<slug>/index.ts` | Edge Function sources (Deno). |
| `supabase/tests/*.sql` | Live SQL test suites. Each is `BEGIN … ROLLBACK`. |
| `servers/` | Node workers that run on the GCE VM (see §5) + `providers/{zendit,dtone}.js` + `offer_validation.js`. |
| `ecosystem.config.js` | pm2 process list. ⚠️ Lists **5** apps; the VM reportedly runs **7** (adds `worker-offers-cache`, plus an unmanaged Baileys process). Trust the VM's `pm2 list`, not this file. |
| `doc/` | The real documentation. Start with `PRODUCTION_PLAN.md` (the phase-by-phase plan, sessions A1→E6) and `PRODUCTION_PLAN_REVIEW.md` (an independent audit + the Phase F plan). |
| `doc/RLS_MATRIX.md` | Intended table/function privileges. **It has been wrong before** — verify against `pg_proc.proacl` / `information_schema` rather than believing it. |
| `test/` | Flutter unit tests (73 passing). |
| `tool/` | Dev scripts incl. `verify_release_bundle.dart`. Not covered by its own scanner. |
| `android/` | `app/build.gradle.kts` release signing (fails loud without `key.properties`). `google-services.json` is **untracked by owner choice** — a fresh clone will not build without it. |
| `.mcp.json` | Declares the Supabase MCP server for this project. |

**Root-level clutter to ignore:** `all_code.txt`, `analyze_output.txt`, `build_verbose.txt`,
`test_*.js`, `*.py`, `keep_sims.rar`, the `KeepSIMs_*Dashboard*.html/png` mockups,
`admin_dashboard.html`. These are historical scratch files, not part of the build.

**Sibling repo, separate folder:** `C:\Users\abdal\Work\KeepSIMs\keep_sims_admin` (admin Flutter
app, `github.com/eduanibal1981/keepsims_admin`). *Moved off `G:\` — corrected 2026-08-04; the old
`G:\KeepSIMs` path no longer exists.* `keep_sims_daemon` beside it is an empty `dart create`
skeleton, **not** a worker or a task-script runner.

---

## 3. GitHub

| repo | remote | local clone |
|---|---|---|
| App (this one) | `https://github.com/eduanibal1981/keepSIMsgitHub.git` | yes |
| Backend | `github.com/eduanibal1981/keepsims-backend` | **none on this machine** — the VM (`/home/abdal/keepsims_backend`) and GitHub are canonical. Push from the VM via a git bundle. |
| Admin | `github.com/eduanibal1981/keepsims_admin` | `G:\KeepSIMs\keep_sims_admin` |

Branch is `main`; this project commits directly to it.

**Pushing works as of 2026-07-29.** The owner ran `gh auth login` + `gh auth setup-git`, which
put an absolute-path credential helper in global git config, so plain `git push` works from an
agent shell with no PATH tricks. (`gh` itself may not be on PATH — use
`C:\Program Files\GitHub CLI\gh.exe` for direct `gh` calls.)

**🚨 Verify every push independently.** This project has a documented history of agents
reporting commit hashes that do not exist and pushes that never happened. Rules:

```bash
git cat-file -t <hash>              # does the commit exist at all?
git ls-remote --heads origin main   # what does the REMOTE actually have?
```

Never claim a push based on `git log`. A second source (`gh api repos/eduanibal1981/keepSIMsgitHub/commits/main`) is cheap.

---

## 4. Supabase — the backend

Project ref **`zwxswagokhgbuzrrbnhr`**, URL `https://zwxswagokhgbuzrrbnhr.supabase.co`.

Access is via the **Supabase MCP server** (declared in `.mcp.json`). Tools you will use:
`list_tables`, `execute_sql`, `apply_migration`, `list_migrations`, `list_edge_functions`,
`deploy_edge_function`, `get_logs`, `get_advisors`. MCP connects as **`postgres`** with no JWT
claims — so it bypasses RLS and every `auth.uid()`-based guard. To test as a real user you must
either impersonate in-transaction (`SET LOCAL ROLE authenticated` + `set_config('request.jwt.claims', …)`)
or go over HTTP with a real JWT.

⚠️ **The local Supabase CLI is logged into a DIFFERENT account** and cannot see this project.
You cannot set Edge Function secrets or delete functions from here — those are owner tasks.

**What lives where:**

- **Tables + RLS** — the money tables (`wallets`, `wallet_transactions`, `topup_executions`,
  `esim_orders`, `plan_payments`, `paypal_orders`) are read-own, client-write-denied.
- **SECURITY DEFINER RPCs** — every write to money goes through one. This is the security
  perimeter, and it is where the bugs have been: a `GRANT` to `anon`/`authenticated` on one of
  these is an immediate money hole. Supabase blanket-grants `EXECUTE` on new public functions,
  and `GRANT … TO service_role` does **not** remove that — you must `REVOKE`.
- **14 Edge Functions**, all ACTIVE. `verify_jwt: false` ones are the webhooks/health endpoints
  (they do their own signature or secret check): `dispatch-alert`, `paypal-webhook` v10,
  `waba-webhook`, `sms-webhook`, `twilio-voice-webhook`, `purge-accounts` v8, `health` v2.
  `verify_jwt: true`: `create-paypal-order` v4, `capture-paypal-order` v2, `wallet_transact`,
  `fetch_zendit_offers`, `detect-country`, `delete_account`, `execute_zendit_recharge` v6
  (a 410 tombstone the owner still needs to delete in the dashboard).
- **8 pg_cron jobs**: hourly notifications, `reap-stuck-executions` (*/5), refill pipeline
  health (:30), `purge-deleted-accounts-hourly`, `check-rate-limit-health` (:30),
  `prune-rate-limit-data` (3am), `reap-stale-esim-orders-hourly`, `check-worker-heartbeat` (*/10).
- **Vault** — secrets read by DB functions (`dispatch_shared_secret`, via `get_internal_secret()`).
- **Edge Function secrets** — dashboard-only (owner). PayPal, FCM, OneSignal, Resend, WABA, Twilio.
- **`system_configs` table** — non-secret tunable business values (fee percentages, offline
  numbers, markup). Deliberately DB-editable so prices change without an app release. Columns
  are `config_key` / `config_value`.

**Migration discipline (learned the hard way — 4 separate drifts):** if you change schema, ship
a `.sql` file in `supabase/migrations/` **and** register it. `apply_migration` stamps the
version with *today's* date, but this repo uses future-dated round timestamps — check that the
registered version sorts **after** the migration you are correcting, or a replay will undo your
fix. Verify with `list_migrations`.

---

## 5. Google Cloud VM — the workers

GCE instance **`keepsims-staging`**, zone `europe-west3-a`, project dir
`/home/abdal/keepsims_backend`, Node v22, processes under **pm2**.

*Per project records: `gcloud compute ssh` used to work from this workstation, but **gcloud is
not on PATH as of 2026-07-29** — treat VM access as unavailable until you prove otherwise, and
route VM work to the owner.*

| pm2 name | script | job |
|---|---|---|
| `queue-instant-refill` | `worker_instant_refill.js` | claims `refill_instant`, debits the wallet, buys from the supplier, refunds on failure |
| `queue-auto-mini-refill` | `worker_auto_mini_refill.js` | premium scheduled micro-refills (**no wallet debit** — the yearly plan pre-paid them) |
| `queue-auto-custom-refill` | `worker_auto_custom_refill.js` | user-scheduled refills |
| `worker-offers-cache` | `worker_offers_cache.js` | refreshes `zendit_offers_cache` (~780 rows / 50 catalogs) every 10 min |
| `worker-esim-catalog` | `worker_esim_catalog.js` | refreshes `esim_offers_cache` (50 rows) every 6h |
| `worker-esim-fulfillment` | `worker_esim_fulfillment.js` | places eSIM orders, writes ICCID/LPA, refunds on failure, writes a heartbeat |

All workers authenticate with **`SUPABASE_SERVICE_ROLE_KEY`** from `servers/.env` on the VM —
that file also holds `ZENDIT_API_KEY`, `DTONE_API_KEY`/`DTONE_API_SECRET`, `ESIM_GO_API_KEY`
and the DB connection. It is **not** in git. (dotenv v17 prints a banner to stdout — strip line
1 before parsing any script output as JSON.)

Workers are the **only** component that spends money at a supplier, which is why supplier-price
validation lives in `servers/offer_validation.js` and not in the app.

Liveness: `worker-esim-fulfillment` writes `system_configs.WORKER_ESIM_FULFILLMENT_HEARTBEAT`;
the `health` Edge Function returns **503** when it is >15 min stale; UptimeRobot polls that URL
every 5 min. So `curl https://zwxswagokhgbuzrrbnhr.supabase.co/functions/v1/health` is a
one-command check on both the Edge runtime and the fulfilment worker.

---

## 6. External services

**PayPal** — the only way money enters. Sandbox today.
`create-paypal-order` (prices server-side via the `quote_plan_price` RPC — **never trust a
client-supplied amount**) → user approves → `paypal-webhook` (signature-verified against webhook
id `5FA85715EA0979031` on the "KeepSIMs us" REST app, *not* the "KeepSIMs" app) captures on
`CHECKOUT.ORDER.APPROVED` and credits on `PAYMENT.CAPTURE.COMPLETED`. `paypal_orders` tracks
state; `custom_id` carries `{u:user, k:kind, l:line}` where kind `deposit` credits the wallet
and `plan` records a subscription payment instead. Credentials are Edge Function secrets.
*A sandbox client secret was once hardcoded in the app and is still in git history — rotation is an owner task.*

**Zendit** — primary mobile top-up supplier, 49 of 50 carriers. Offers cached in
`zendit_offers_cache`. Purchases keyed `z_<execution_id>` for idempotency.

**DTOne** — second top-up supplier, **1 carrier so far**, preprod endpoint
(`preprod-dvs-api.dtone.com/v1`). Selection is per-carrier: `carriers.api_provider` is
`'zendit'` (default) or `'dtone'`, and the carrier code column differs (`zen_carrier` vs
`dt_carrier`). Both are wired into all three refill workers via `servers/providers/`.

**eSIM Go** — eSIM supplier, v2.4 `POST /orders`. ⚠️ The only order ever placed used a
**fixture** reference — the live order contract is unverified.

**Notifications** — OneSignal (push, primary) with an FCM HTTP-v1 fallback, Resend (email),
Telegram, and a WhatsApp VPS channel (currently disabled — its key is unset). All fan out from
one DB trigger → `dispatch-alert`. Per the review, delivery is weak in practice: 1 device token
for 8 users.

**Twilio + WhatsApp Business (Meta)** — inbound webhooks for offline refill (SMS / missed call /
WhatsApp) so a user with no data can still top up. Built and deployed, but **0 events ever** —
the phone numbers in `system_configs` are still placeholders. Owner-gated.

**UptimeRobot** (owner's account) and **Sentry** (DSN not yet provisioned — crash reporting is
wired but inert).

---

## 7. Rules of engagement

These are not style preferences; each one is a bug this project actually shipped.

1. **Verify, don't report.** Never state that something is deployed, granted, pushed, or fixed
   without a command output proving it. Check Edge Function `version` + `updated_at` via
   `list_edge_functions` — "deployed" has been claimed for code that only existed in git.
2. **Probes must assert the specific error code**, not "an exception was raised". A dead guard
   passes a `catch-anything` probe. `42501` (permission denied) and `KS403` (an app guard
   fired) mean completely different things.
3. **Run a SQL suite as ONE call.** MCP `execute_sql` makes each call its own transaction, so a
   split file never pairs `BEGIN` with `ROLLBACK` and your fixtures **commit**. This has leaked
   fake users into production three times.
4. **Leave no residue.** Prefer the existing fixture account
   (`a1-wallet-test@example.com`, wallet must end at **$35.86**) over creating users. Check your
   own footprint before finishing.
5. **`current_user` is useless inside `SECURITY DEFINER`** — it is the owner. Guard on the
   `request.jwt.claims` role instead, and make it fail *closed*.
6. **Never hardcode a price, fee, or gateway rate.** `system_configs` and `payment_gateways` are
   the sources of truth so the owner can change them without an app release.
7. **Windows/PowerShell:** don't edit Dart files with `Get-Content`/`Set-Content` (mangles UTF-8
   into mojibake) — use the editing tools. PS 5.1 has no `&&`.
8. **Don't blanket-run `dart format`** — the repo is not format-clean at HEAD and it buries the
   real diff.

**Baseline to preserve:** `flutter analyze` 134 issues / **0 errors**, `flutter test` **73/73**,
a1 fixture wallet **$35.86**.

---

## 8. What an agent cannot do — route these to the owner

Anything needing a third-party login. Do not put these in an executor prompt and do not accept
a "configured ✅" claim for one: Supabase **dashboard** (Edge Function secrets, deleting a
function, Auth settings), PayPal developer console, Meta/WhatsApp + Twilio consoles, Sentry,
UptimeRobot, Google Play Console, the domain/hosting, and generating the upload keystore.

Known open owner items are listed at the end of `doc/PRODUCTION_PLAN_REVIEW.md` (§7).

---

## 9. Where to start reading

1. `doc/PRODUCTION_PLAN_REVIEW.md` — current state, honestly audited, plus the Phase F backlog.
   **The top open item is F-2:** the 6-arg `debit_wallet_for_topup` is `EXECUTE` to PUBLIC, so
   anyone holding the APK's anon key can drain any wallet. F-1 (the sibling minting hole) was
   closed on 2026-07-29 by migration `20260801040000` — read that migration and its test
   (`supabase/tests/f1_wallet_refund_grant_tests.sql`) as the worked example of how a fix,
   its two layers, and its proof are expected to look.
2. `doc/PRODUCTION_PLAN.md` — the plan and what each phase already delivered.
3. `ARCHITECTURE_RULES.md`, `doc/RLS_MATRIX.md` (with the scepticism noted above).
