# D2 — Rate Limiting (Auth, Money RPCs, Edge Functions): Hand-off Brief

**Written 2026-07-25, repo @ `b4fe0e8` (D1), live DB `zwxswagokhgbuzrrbnhr`.**
Plan section: `doc/PRODUCTION_PLAN.md` § D2. D1 is ✅ DONE and committed. D2 is
the **first server-side hardening session since C3b-2** — it takes a migration,
touches deployed Edge Functions, and adds one client-visible error path. It does
**not** move money and does **not** add a vendor.

D1 put a *user-presence* gate in front of spending. D2 puts a *rate* gate behind
it. They defend different things and neither substitutes for the other: a rooted
device skips the biometric prompt entirely, and the server has no idea whether a
prompt was ever shown. **Every limit in D2 must hold with the client deleted.**

## Verified repo state you inherit (checked live against DB + source 2026-07-25)

- **Baselines, re-measured today — the plan file is WRONG, trust these:**
  `flutter analyze` → **0 errors, 29 warnings, 133 infos = 162 issues**
  (`PRODUCTION_PLAN.md` § D1 records "184 infos"; that number is a typo — fix it
  to 162 in your session record). `flutter test` → **62/62 pass**.
  a1 wallet **35.86** (verified live today). Working tree clean except
  untracked `.agents/`.
- **`pg_cron` 1.6.4 and `pg_net` 0.20.0 are installed.** Three cron jobs already
  run: `process-hourly-notifications`, `reap-stuck-executions` (*/5),
  `refill-pipeline-health` (:30). **`check_refill_pipeline_health()` is the
  template for D2 item 4** — it counts, then inserts a `system_alerts` row only
  if no alert of the same `kind` exists in the last 6 hours, and C1 fans
  `system_alerts` out to power users automatically. Copy that shape; do not
  invent a new alerting path.
- **The real spend surface is 5 SECURITY DEFINER RPCs, not the Edge Functions.**
  Client-callable, all `GRANT EXECUTE ... authenticated`, all self-scoped on
  `auth.uid()`:
  1. `request_esim_purchase(p_offer_id, p_quantity)` — **the worst gap. No
     throttle of any kind.** Caps quantity at 3 *per order*; nothing caps
     orders. A loop debits the wallet and queues real eSIM Go `/orders` calls
     (real supplier money, C9b). Also carries a **needless `anon` EXECUTE
     grant** — revoke it.
  2. `request_instant_refill(line, offer, gateway, amount_usd)` — throttled only
     indirectly, by the `topup_executions` BEFORE INSERT trigger
     `check_topup_rate_limit()` (10 s, **per SIM line**). A user with 10 lines
     gets 10× the throughput. No per-user ceiling.
  3. `pay_plan_fee_from_wallet(p_reference_id, p_sim_line_id)` — idempotent per
     reference, but **the client generates the reference**
     (`planfee_<uid8>_<micros>`, `wallet_repository.dart`). A loop mints fresh
     references and re-debits $2.50 each time. Idempotency is not a rate limit.
  4. `redeem_referral_points()` — no throttle. Bounded by points earned
     (`REFERRAL_DAILY_POINT_CAP`=10), so the blast radius is small, but it is a
     wallet-credit path and belongs in the same net. Carries **PUBLIC and `anon`
     EXECUTE grants** — revoke both.
  5. `apply_referral(p_referred_id, p_referral_code)` — **an enumeration
     surface**: unlimited guesses at other users' referral codes. This is the
     one limit whose absence is an actual vulnerability rather than a cost risk.
  Both RPCs that carry stray `anon`/PUBLIC grants do guard on
  `auth.uid() IS NULL` and raise — harmless in outcome, but an unauthenticated
  caller still gets a free DB round-trip per request. Revoking costs nothing.
- **`check_topup_rate_limit()` is the anti-pattern to learn from, and to keep.**
  It works (C3 fixed it — it had tested `'instant'` against a pipeline that
  writes `'refill_instant'`, so it never fired), but it
  `RAISE EXCEPTION 'Rate limit exceeded: Please wait 10 seconds…'` — a raw
  English Postgres string that reaches the user's screen untranslated. **Do not
  delete or retime it**: `c3_instant_recharge_tests.sql`,
  `c3b2_lockdown_tests.sql` and `c4_offline_recharge_tests.sql` all assert
  around its exact behaviour (they backdate `created_at` or use separate lines
  to route around it). Layer a per-user bucket *on top*; leave the per-line
  trigger alone.
- **Edge Functions live** (10 deployed, `supabase/functions/`):
  | slug | verify_jwt | who calls it | D2 exposure |
  |---|---|---|---|
  | `wallet_transact` v5 | ✅ on | client | `deduct` action, any amount ≤ 10000, own wallet |
  | `detect-country` v1 | ✅ on | client (app open/resume) | **calls out to `ipapi.co` — free tier ~1000/day for the whole project.** One abusive client blinds C8 geo for every user |
  | `fetch_zendit_offers` v11 | ✅ on | client | read-only |
  | `execute_zendit_recharge` v6 | ✅ on | nobody | 410 tombstone (C3). Owner still needs to delete it in the dashboard |
  | `paypal-webhook` v7 | ❌ off | PayPal | signature-verified against webhook id `5FA85715EA0979031` |
  | `waba-webhook` / `sms-webhook` / `twilio-voice-webhook` v1 | ❌ off | Meta / Twilio | **signature checks are skipped until the owner sets the secrets** (still pending, see C4) — today they are open, unauthenticated, billable endpoints |
  | `dispatch-alert` v19 | ❌ off | DB trigger via pg_net | shared secret from Vault, checked first thing (cached module-level); rejects with 401 |
  | `delete_account` | — | client `privacy_controller.dart:77` | **exists in the repo, is NOT deployed.** The client calls a function that isn't there. D3's problem, not yours — but do not "fix" it by deploying it: that file deletes the auth user with no wallet/schedule cascade, which is exactly what D3 is scoped to design |
- **`security_logs` exists and has 0 rows since A-phase** (`user_id`,
  `event_type`, `description`, `metadata jsonb`, `created_at`; RLS enabled with
  **no policy** = service_role only, same deliberate pattern as
  `offline_refill_events`). This is the right home for rejection forensics — it
  is not dead code, it is unfilled.
- **`system_configs` is the house tuning surface** (columns are
  `config_key`/`config_value`, 16 rows; authenticated SELECT, power-user
  UPDATE). Precedent set by `APP_FEE_PERCENT`: the owner's standing requirement
  is **"change it in the DB, no redeploy."** Limits are business values.
- **Auth surfaces in the client** (`auth_repository.dart`): email+password
  `signUp` / `signInWithPassword`, email OTP `verifyOTP`, `resend` confirmation,
  Google OAuth. **`email_auth_screen.dart:227` has a resend button with no
  cooldown at all** — it is only disabled while `isLoading`, so a user can tap
  it as fast as the network returns and will hit Supabase's own limit with a
  raw provider error.
- **Supabase Auth rate limits cannot be read or set from this machine.** The
  local Supabase CLI is logged into a *different account* with no access to
  `zwxswagokhgbuzrrbnhr`, and there is no MCP tool for auth config. Dashboard →
  Authentication → Rate Limits is **an owner task**. Prepare the exact numbers,
  hand them over, then verify by probing.
- **No `_shared/` directory exists under `supabase/functions/`.** Each function
  is standalone. Two of them (`detect-country`, `paypal-webhook`) ship a
  `deno.json`; MCP redeploys of an existing function fail with "import map path
  does not exist" unless you pass `import_map_path: "deno.json"` **and** include
  a `deno.json` file (content `{}`) in `files`.

## Design decisions (professional judgment — follow unless owner overrides)

1. **Limit at the database, not at the edge. This is the whole session.**
   The plan's item 2 says "Edge Functions … token bucket". Taken literally that
   is a limiter you can walk around: `request_esim_purchase`,
   `request_instant_refill`, `pay_plan_fee_from_wallet`,
   `redeem_referral_points` and `apply_referral` are reachable **directly over
   PostgREST with the anon key and any user JWT** — no Edge Function in the
   path. A curl loop bypasses an edge limiter completely. Put the bucket
   *inside the RPC*, in the same transaction as the debit, so the limit and the
   money commit or roll back together. The Edge Function limiter still gets
   built (item 2), but for the endpoints that genuinely are HTTP-only:
   `detect-country`, `wallet_transact`, and the four unauthenticated webhooks.
2. **One primitive, used everywhere.** Build exactly one thing:
   ```
   consume_rate_limit(p_bucket text, p_key text, p_capacity int,
                      p_refill_per_minute numeric, p_now timestamptz DEFAULT clock_timestamp())
     RETURNS TABLE (allowed boolean, retry_after_seconds int)
   ```
   Lazy token bucket over one table `rate_limit_buckets(bucket, key, tokens
   numeric, updated_at timestamptz, PRIMARY KEY (bucket, key))`, refill computed
   from elapsed time inside a single `INSERT … ON CONFLICT (bucket, key) DO
   UPDATE` so it is atomic without an advisory lock and without a row-lock
   convoy. RLS enabled, **no policy** (service_role only), like `security_logs`.
   Do not write five bespoke throttles.
3. **`clock_timestamp()`, never `now()`. Non-negotiable, and it is the trap that
   will eat your afternoon.** The SQL suites run live inside `BEGIN..ROLLBACK`
   (that is the house technique — see `b4_money_path_tests.sql` onward), and
   `now()` is **frozen for the whole transaction**. A bucket keyed on `now()`
   never refills in a test and every C3b2/C4 suite already carries comments
   about working around exactly this with `check_topup_rate_limit`.
   `clock_timestamp()` advances inside a transaction. Take `p_now` as a
   defaulted parameter so tests can drive time explicitly.
4. **Typed, translatable rejection — this is what makes it feel professional.**
   Raise with a **custom SQLSTATE** (use `ERRCODE = 'KS429'`) and a stable
   machine-readable `MESSAGE` of the form `RATE_LIMITED:<bucket>:<seconds>`.
   Edge Functions return HTTP **429** with a real **`Retry-After`** header and
   `{"code":"rate_limited","bucket":…,"retry_after":…}`. The Flutter side maps
   both to one localized string with the seconds interpolated. Today
   `check_topup_rate_limit`'s raw English sentence is what the user sees — treat
   fixing that presentation (without changing the trigger's logic) as part of
   the deliverable.
5. **Server-initiated paths are exempt, by construction.** Key every
   authenticated bucket on `auth.uid()` and **skip the check entirely when
   `auth.uid()` IS NULL** (service_role: the PM2 workers, pg_cron,
   `ingest_offline_refill` from the webhooks). This mirrors D1's rule exactly —
   biometrics gated user-initiated spend and left background debits to RLS. Same
   story, same boundary. A limiter that throttles `worker_instant_refill` would
   silently stall the refill queue and page the owner at 3am.
6. **Fail-open for money, fail-closed for cost.** The money RPCs already have
   hard economic bounds (wallet balance, ownership, idempotency, C3b-1 offer
   validation). Their bucket is anti-abuse, not anti-fraud — **it must never be
   the reason a legitimate payment fails.** The cost surfaces (`detect-country`
   → a metered third-party quota; the unauthenticated webhooks → billable
   invocations; auth email → a finite Resend allowance) have *no* economic
   bound, so they fail closed. Write this rule in a comment at the top of the
   migration; the next person will otherwise "make it consistent" and get it
   backwards.
7. **Postgres, not Upstash.** The plan offers either. Choose Postgres and say
   why in the record: no new vendor, no new secret to rotate (A2 rotation is
   *still* outstanding), and — decisively — **only the in-database bucket is
   atomic with the debit**. Redis would reintroduce the check-then-act window
   that C3b-1 and B1's double-debit work spent two sessions closing. At current
   volume (8 users) the performance argument for Redis does not exist.
8. **Limits live in `system_configs`, one row per bucket.** Key
   `RATE_LIMIT_<BUCKET>`, value `"<capacity>/<per_minutes>"` (e.g. `"5/60"`),
   parsed with a hardcoded fallback exactly like `APP_FEE_PERCENT` does on
   garbage input. The owner can then loosen a limit that annoys real users from
   the dashboard, mid-incident, without an app release.
9. **Log rejections only — never allows.** One `security_logs` row per rejection
   (`event_type = 'rate_limited'`, `metadata = {bucket, key_kind, retry_after}`).
   Logging allows would write a row per request and turn the limiter into the
   load. Add a pg_cron nightly prune: `security_logs` older than 90 days,
   `rate_limit_buckets` untouched for 7 days.
10. **Item 3's "DB backstop trigger" is already satisfied — do not build a
    second one.** The plan asks for a trigger rejecting > N `topup_executions`
    inserts per user per minute. `check_topup_rate_limit` is that trigger; it
    needs a *per-user* clause added alongside the existing per-line one, not a
    rival trigger. One trigger, two windows.
11. **Client cooperates, server enforces.** Add a countdown-disabled state to
    the auth resend button and to any CTA that just got a 429 (button shows
    "Try again in 12s"). Never auto-retry an auth/OTP send, and never
    auto-retry a payment. This is UI politeness sitting on top of a real limit —
    it is not, and must not be described as, the limit.
12. **Do not touch the OTP/signup limits yourself.** You cannot; the CLI account
    is wrong. Produce the exact table of recommended values and hand it to the
    owner, then verify the *effect* by probing (3 rapid `resend` calls → expect
    a 429 from GoTrue) rather than by reading config you have no access to.

### Recommended starting limits (all DB-tunable; defend or adjust, don't just copy)

| Bucket | Key | Capacity / window | Rationale |
|---|---|---|---|
| `esim_purchase` | user | 5 / 60 min | real supplier money + provider API |
| `instant_refill` | user | 10 / 60 min | on top of the surviving 10 s per-line trigger |
| `plan_fee` | user | 10 / 60 min | client-minted reference defeats idempotency |
| `referral_redeem` | user | 5 / 60 min | wallet credit path |
| `apply_referral` | user | 5 / 60 min | **enumeration** — the tightest of the RPC set |
| `detect_country` | user | 12 / 60 min | C8's flap guard is 1 h; more calls buy nothing and burn the ipapi.co quota |
| `wallet_deduct` | user | 20 / 60 min | `wallet_transact` `deduct` |
| `webhook_ip` | IP | 60 / 1 min | cost cap only — the signature check is the real gate |

Auth (owner, dashboard): tighten OTP/confirmation email sends and per-IP signup.
Bring exact recommended numbers; the current values are unknown from here.

**On IPs:** Supabase Edge Functions sit behind a proxy — take the **first**
entry of `x-forwarded-for` and nothing else, and treat it as best-effort. It is
spoofable. For the webhooks it caps cost; it never authenticates. Say so in the
code comment so nobody later mistakes it for a security control.

## Scope checklist

1. Migration `20260728000000_d2_rate_limiting.sql` (house convention: round
   manual timestamp, `timestamp_phase_description`) —
   `rate_limit_buckets` table + `consume_rate_limit()` + `RATE_LIMIT_*` seeds in
   `system_configs` + the `security_logs` rejection helper.
   **Save the `.sql` file locally the same session** — the C3b-2 migrations were
   applied via MCP and lost for weeks; the recovery took a whole cleanup commit.
2. Wire the bucket into the 5 money RPCs by `CREATE OR REPLACE` — preserve every
   existing guard byte-for-byte (ownership, balance, idempotency, C3b-1 offer
   validation). Add the per-user window to `check_topup_rate_limit`; leave its
   per-line window untouched.
3. `REVOKE EXECUTE … FROM anon, PUBLIC` on `request_esim_purchase` and
   `redeem_referral_points`.
4. Edge Functions: shared limiter helper (inline it per function — there is no
   `_shared/`, and introducing one is a bigger refactor than D2 should carry),
   applied to `detect-country`, `wallet_transact`, and the four
   unauthenticated webhooks. 429 + `Retry-After`. Redeploy with
   `import_map_path: "deno.json"` where one exists.
5. pg_cron `check_rate_limit_health()` on the `check_refill_pipeline_health`
   pattern: sustained rejections → one `system_alerts` row per kind per 6 h.
   Plus the nightly prune job.
6. Flutter: map SQLSTATE `KS429` and HTTP 429 to one localized message with the
   retry seconds; countdown-disable the auth resend button and any 429'd CTA.
   ARB keys ×9 locales.
7. Tests: `supabase/tests/d2_rate_limiting_tests.sql`, live `BEGIN..ROLLBACK`,
   asserting — bucket allows to capacity then rejects; refills over
   `clock_timestamp()`; `auth.uid()` NULL bypasses; the per-line trigger still
   behaves exactly as C3/C3b2/C4 assert; a rejection lands in `security_logs`.
   Dart tests for the 429 → localized-message mapping. **All 62 existing Flutter
   tests stay green** and every pre-existing SQL suite still passes — re-run
   `c3_instant_recharge_tests.sql`, `c3b2_lockdown_tests.sql` and
   `c4_offline_recharge_tests.sql`, they are the ones a bad limiter breaks.
8. `flutter analyze` 0 errors, info baseline **162**; `flutter test` ≥ 62 pass;
   `flutter build apk --debug`; MCP `get_advisors` 0 net-new; wallet **35.86**
   unchanged.
9. Update `doc/PRODUCTION_PLAN.md` § D2 with an implementation record in house
   style (deviations included), flip D2 to ✅ DONE, **and correct § D1's "184
   infos" to 162.** Update the memory status file. One commit,
   `feat(security): D2 rate limiting`, pushed to `origin/main`.

## Confirm with owner at session start (non-blocking — proceed with defaults)

1. Starting limits per the table above — OK to ship and tune from the DB?
   (default: yes)
2. Fail-open on money RPCs if the limiter itself errors, fail-closed on
   `detect-country` and the webhooks — confirm. (default: yes)
3. Postgres token bucket, no Upstash/Redis. (default: yes)
4. Auth rate limits are yours to set in the dashboard; agent supplies the
   numbers and probes the result. (default: yes)
5. `security_logs` retention 90 days. (default: yes)

## Session conventions (house rules — do not deviate)

- Migration file saved locally the same session, round manual timestamp,
  `timestamp_phase_description`.
- SQL tests run live via MCP inside `BEGIN..ROLLBACK` — never leave rows behind.
- ARB keys in all 9 locales (en, ar, es, hi, tr, bn, ne, si, ur); use the Edit
  tool for non-Latin files (PowerShell 5.1 mangles UTF-8); no blanket
  `dart format` — the repo is not format-clean at HEAD and a blanket format
  buries the real diff.
- No new pub or npm dependency. No wallet movement: **35.86** at start and end.
- Backend/worker changes (if any) follow `.agents/AGENTS.md`: local → GitHub
  `keepsims-backend` → SSH VM → `pm2 restart`. D2 should need none.
- One commit, `feat(security): …`, pushed to `origin/main`.

## Known residual risks to carry forward (NOT D2 work — do not fix here)

- **D1 leftovers worth one small follow-up commit** (see the review notes handed
  with this brief): the payment grace window is never cleared when the app is
  backgrounded, and `didChangeAppLifecycleState` locks on `inactive` as well as
  `paused` — `inactive` also fires for the iOS app-switcher preview, the
  notification shade, and the OS biometric dialog itself.
- `delete_account` is called by the client but not deployed. **D3.**
- C9b's "e2e purchase" used synthetic fixtures (`esim_go_ref_9999`, ICCID
  `8988210000000000001`); the real eSIM Go `/orders` v2.4 contract is still
  unverified. eSIM go-live, E-phase.
- No stale-`pending` sweep on `esim_orders` — **D5** (already recorded there).
- Still pending owner: A2 key rotation; C4 WABA/Twilio provisioning (until then
  three webhooks accept unsigned requests — D2's IP bucket caps the cost but is
  **not** a substitute for the signature check); dashboard delete of the
  `execute_zendit_recharge` tombstone.

## Execution prompt for the implementing agent

See the fenced prompt handed alongside this brief (chat); this brief is the
source of truth if they diverge.
