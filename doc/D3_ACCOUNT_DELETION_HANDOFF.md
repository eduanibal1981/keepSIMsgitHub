# D3 — Account Deletion, Data Export & Privacy Compliance: Hand-off Brief

**Written 2026-07-25, repo @ `f840bc2` (D2), live DB `zwxswagokhgbuzrrbnhr`.**
Plan section: `doc/PRODUCTION_PLAN.md` § D3. D1 and D2 are ✅ DONE and committed.

D3 is the **first session whose primary deliverable is not a defence but a
destruction path**. Every other session added a guard; this one adds the only
endpoint in the product that is *supposed* to erase a paying customer's data,
their money trail, and their auth identity — irreversibly, on their own
unattended request. Treat it accordingly: **the danger in D3 is not that it
fails to delete, it is that it deletes too much, too fast, for the wrong
person.**

Three properties make that concrete here:

1. **The wallet holds real money.** 8 of 8 wallets are non-zero today; the a1
   fixture alone is $35.86 of tested-live balance.
2. **`ON DELETE CASCADE` already reaches the entire financial ledger.** A
   single `auth.admin.deleteUser()` today would destroy 165 `wallet_transactions`
   rows, the PayPal capture records that defend chargebacks, and the eSIM order
   history — with no undo and no accounting residue.
3. **Deletion is the highest-value target for an account-takeover.** Anyone who
   steals a session gets a one-tap button that erases the victim *and the
   evidence*. D1's biometric gate protects payments but nothing protects this.

Store compliance (Apple 5.1.1(v), Play's Data Deletion policy) is the *reason*
this session exists, but compliance is the easy half. The hard half is doing it
without becoming the app's own worst vulnerability.

---

## Verified repo + DB state you inherit (checked live 2026-07-25, trust these)

- **Baselines re-measured today.** `flutter analyze` → **0 errors, 162 issues**
  (29 warnings + 133 infos). `flutter test` → **67/67 pass**. a1 wallet
  **$35.86**. Working tree clean at `f840bc2`.
  *Note:* `PRODUCTION_PLAN.md` § D2 records "165 info/warnings" — that is wrong,
  the real figure is **162**, unchanged from D1. Correct it in your session record.
- **`delete_account` is checked in but NOT DEPLOYED.** `list_edge_functions`
  returns 9 live functions; `delete_account` is not among them. The client
  (`privacy_controller.dart:77`) invokes it on every "Delete Account" tap and
  gets a 404, which the `catch` block flattens into a generic
  `"Error deleting account: ..."`. **Users currently believe deletion is broken;
  in fact it never ran.** That is a store-review failure waiting to happen and it
  is the one behaviour you must not preserve.
- **The checked-in `delete_account/index.ts` is 67 lines and does exactly one
  thing:** `supabaseAdmin.auth.admin.deleteUser(user.id)`. No re-auth, no wallet
  check, no schedule cancellation, no in-flight drain, no storage cleanup, no
  audit row, no grace period. **Do not deploy it. Rewrite it.**
- **The FK cascade is far more complete than the plan assumes — and that is the
  problem, not the solution.** `profiles.id → auth.users(id) ON DELETE CASCADE`,
  and **26 further FKs cascade from there**. Deleting the auth user today
  silently destroys, with no explicit code anywhere:

  | Cascade class | Tables | Why it matters |
  |---|---|---|
  | **Financial (must survive, anonymised)** | `wallets`, `wallet_transactions` (165 rows), `plan_payments`, `esim_orders`, `user_esims`, `topup_executions` | tax/VAT retention, PayPal chargeback defence (**PayPal's dispute window is 180 days** — longer than any deletion SLA), supplier reconciliation with Zendit / eSIM Go |
  | **Operational (safe to delete)** | `sim_lines`, `scheduled_topups`, `alert_settings`, `notification_channels`, `notifications`, `device_push_tokens`, `notification_deliveries`, `user_preferences`, `payment_methods`, `line_activity_log`, `offline_refill_settings`, `support_tickets`, `ticket_messages` | genuinely user-owned, no retention claim |
  | **Cross-user (deletes *someone else's* record)** | `referral_points` (CASCADE on **both** `referrer_id` and `referred_user_id`), `referrals` | see the referral bug below |
  | **Already SET NULL (correct)** | `security_logs`, `offline_refill_events`, `household_members.member_id` | the C-phase precedent for what you should extend |

- **Live bug this session must fix — the referral points hole.**
  `referral_points.referred_user_id` is `ON DELETE CASCADE`. Balance is computed
  as `SUM(referral_points.points) − SUM(referral_redemptions.points_spent)`
  (`20260724000000_c5_refer_and_earn.sql:290-298`). So when a *referred friend*
  deletes their account, the **referrer's earned points vanish while their
  redemptions remain** → balance goes negative → `redeem_referral_points()`
  raises `'Insufficient points balance'` **forever**. One user's deletion
  permanently breaks a different user's paid-for benefit. Fix by `SET NULL` +
  retaining the points row, not by cascading.
- **Storage does not cascade at all.** In this project `storage.objects` has
  **no FK to `auth.users`** (only `bucket_id → storage.buckets`). Deleting the
  auth user leaves every uploaded support attachment in the bucket forever —
  photos users send to support, which in a SIM/telecom context routinely include
  **ID documents and SIM-card packaging with ICCIDs**. You must enumerate and
  remove objects explicitly. Two buckets exist:
  `ticket-attachments` (private, 10 MB — the C7 one) and **`support_attachments`
  (PUBLIC, no size limit)** — a stray. Object count is 0 today, so this is cheap
  to get right now and expensive later.
- **In-flight money is not hypothetical.** Right now there are **13
  `topup_executions` in `pending`/`routing`/`pending_payment`**. `worker_instant_refill`
  claims `routing` rows, debits, then buys from Zendit. If the owning user is
  deleted between claim and debit, the cascade removes the execution row and the
  wallet under a worker that is already committed to a supplier purchase.
- **`privacy_controller.dart` is a stub wearing production clothes:**
  - `exportData()` exports **only `user.toJson()`** — the profile object and a
    timestamp — writes it to a temp file and hands it to `share_plus`. The
    localized description already promises *"a JSON copy of your profile and
    preferences (GDPR Right to Access)"*. It ships none of: lines, wallet,
    transactions, orders, tickets, referrals, notifications.
  - `toggleTrackingConsent()` writes a `SharedPreferences` bool that **nothing
    reads**, and **defaults to `true`**. Its own comment says
    `// In a real app, you would also toggle the analytics SDK here`.
  - `deleteAccount()` has no re-auth and treats any non-2xx as a generic failure.
- **`privacy_screen.dart` has a good bone and two breaks.** The type-`DELETE`-to-
  confirm dialog exists (line 312-340) — keep that pattern. But the confirm
  button's label is a **hardcoded English `'Confirm Delete'`** (line 352) in a
  9-locale app, and the gate compares against the *localized* `deleteWord`, so
  the word a user must type changes per locale while the button never does.
  **"Read Full Privacy Policy & Terms" shows a snackbar** —
  `privacyPolicyLoaded: "Privacy Policy details loaded."` — there is no policy
  document and no URL anywhere in the repo. Both stores hard-block on that.
- **Infrastructure you should reuse, not reinvent:** `pg_cron` 1.6.4 + `pg_net`
  0.20.0 installed, 3 jobs scheduled (`process-hourly-notifications`,
  `reap-stuck-executions` */5, `refill-pipeline-health` :30).
  `check_refill_pipeline_health()` is the house alerting shape (count → one
  `system_alerts` row per `kind` per 6 h → C1 fans out to power users).
  `trg_fn_dispatch_notification` → `pg_net` → Edge Function with a **Vault**
  shared secret (`dispatch_shared_secret` via `get_internal_secret(text)`) is the
  house pattern for "cron needs to call an admin-API-capable function".
- **D2's limiter is available to you** (`enforce_rate_limit(bucket, key)` +
  `RATE_LIMIT_<BUCKET>` rows in `system_configs`) — but read the D2 review notes
  below before relying on it, because on the RPC path it does not currently
  survive its own exception.

---

## Design decisions (professional judgment — follow unless the owner overrides)

### 1. Soft-delete with a grace period. This is the whole session.

The plan's item 1 describes a synchronous purge: *"an Edge Function that cancels
schedules, zeroes the wallet, deletes rows, deletes the auth user."* Every
serious consumer app that holds money — Wise, Revolut, Uber, Google, Meta —
deliberately does **not** do that. They mark the account for deletion, sign the
user out, disable everything immediately, and **hard-purge after 14–30 days**.

Four independent reasons, all of which apply here:

- **Account-takeover containment.** A stolen session currently reaches a button
  that erases the victim *and the audit trail proving the theft*. A grace window
  plus an immediate "your account is scheduled for deletion on <date> — cancel"
  email (free: C1's dispatcher already delivers `system` category) converts an
  unrecoverable attack into a recoverable one. **This is the highest-value
  security control in D3 and it costs one column and one cron job.**
- **In-flight settlement.** The 13 queued executions, PayPal captures still in
  flight, and eSIM orders awaiting `worker_esim_fulfillment` all need to land or
  fail cleanly before the owning rows vanish.
- **Regret.** Deletion is the single most-regretted action in any app. Every
  support ticket about it is unanswerable once the purge has run.
- **Chargebacks.** A PayPal dispute can arrive up to 180 days after capture. If
  you have already destroyed `plan_payments` and `wallet_transactions`, you lose
  by default.

Grace period: **14 days**, tunable via `system_configs.ACCOUNT_DELETION_GRACE_DAYS`.
During it the account is **frozen, not functional**: signed out on all devices,
schedules paused, no new spend, and any sign-in shows a single full-screen
"Deletion scheduled for <date> — Cancel deletion / Delete now" state. Apple's
guideline requires deletion to be *offered and honoured*, not to be
*instantaneous*; a clearly-disclosed grace period with an immediate freeze passes
review and is how the apps reviewers use every day behave. Do disclose it on the
confirmation screen, verbatim.

### 2. Anonymise the money, delete the person.

GDPR Art. 17(3)(b) explicitly exempts data retained for a legal obligation, and
tax law in every market KeepSIMs targets requires 5–7 years of transaction
records (EU VAT 10y in some states, UAE FTA 5y, KSA ZATCA 6y). "Delete the user"
and "keep the books" are not in conflict — **they are reconciled by severing the
identity link, not the record.**

At purge time:

- Financial tables (`wallet_transactions`, `plan_payments`, `esim_orders`,
  `topup_executions`, `wallets`) → migrate FK from `CASCADE` to **`ON DELETE SET NULL`**,
  keep amount / currency / timestamps / gateway references / provider order refs,
  and null every column that identifies a person.
- The **only** surviving re-identification key is one row in a new
  `account_deletions` table (user id, SHA-256 of the email, requested/purged
  timestamps, wallet balance at request, actor, IP, outcome). That is your legal
  hold vault and your GDPR Art. 5(2) accountability evidence in one row.
- Everything operational is genuinely deleted.

Do the FK migration **now, at 8 users and 165 ledger rows**. At 8,000 users it is
a maintenance window.

### 3. The wallet-balance question — the owner decision the plan flags.

The plan asks "refund vs forfeit". **Neither, as a default.** Silently forfeiting
stored value is the option most likely to get the app rejected and is legally
indefensible in several target markets, where prepaid balances are a customer
liability rather than revenue. Refund-to-source is not generally possible either:
PayPal refunds are bounded to the original capture and to 180 days, and a wallet
balance is an aggregate of many captures plus referral credits.

**Recommended default (three tiers):**

| Balance at request | Behaviour |
|---|---|
| **< $1.00 ("dust")** | Deletion proceeds; the balance is forfeited **with an explicit typed consent line on the confirmation screen** stating the exact amount |
| **$1.00 – threshold** | Deletion is **blocked** with an actionable choice: *spend it* (refill / buy an eSIM) or *request a payout*, which opens a **C7 support ticket** pre-filled with the amount — the support pipeline already exists, so this costs nothing |
| **Any balance, owner override** | Power-user can settle manually and release the block |

This is defensible, honest, cheap, and reviewer-proof. Put the exact amount in
the UI in the user's own currency — never "your balance will be lost".

### 4. Re-authentication is mandatory, and biometrics are not enough.

Both stores expect a re-auth step; the ATO threat model demands it. Two paths,
because KeepSIMs has both password and Google OAuth users:

- **Password users:** `signInWithPassword` with the current email immediately
  before the request, server-side session freshness check.
- **OAuth users (no password):** Supabase's reauthentication OTP
  (`auth.reauthenticate()` → `verifyOTP(type: OtpType.recovery/email)`) — an
  emailed 6-digit code. This also gives you a free "the person controls the
  inbox" proof, which is the actual security property you want.
- **Then** layer D1's `PaymentAuthGuard` on top. Deletion is more destructive
  than any payment already behind it; it would be incoherent to gate a $2.50
  plan fee and not this. Reuse the guard, do not write a second one.

Re-auth freshness must be **enforced server-side** (reject if the JWT's `auth_time`/
last sign-in is older than ~5 minutes). A client-side re-auth that the server does
not verify is theatre.

### 5. Purge order is a state machine, not a script. Auth user goes LAST.

The current function deletes `auth.users` first and lets 26 cascades fire
implicitly. If anything fails halfway you have orphans **and no id left to find
them with**. Explicit, resumable, idempotent order:

```
requested → frozen → drained → purged → auth_deleted
```

1. **freeze** — `is_suspended = true`, `scheduled_topups.is_active = false`,
   revoke sessions, cancel `pending`/`pending_payment` executions via the
   existing `cancel_topup_execution` RPC (do **not** touch `routing` — a worker
   owns it).
2. **drain** — refuse to advance while any `topup_executions` is
   `routing`, any `esim_orders` is `pending`/`processing`, or any PayPal capture
   is unsettled. Retry next sweep. Alert to `system_alerts` if stuck > 72 h.
3. **settle** — apply the §3 wallet policy.
4. **purge** — anonymise financial rows, delete operational rows, delete storage
   objects in **both** buckets by owner, tombstone the referral code.
5. **auth_deleted** — `auth.admin.deleteUser()` **last**, and only after 1–4
   have each recorded success in `account_deletions`.

Each step writes its own timestamp so a crashed sweep resumes rather than
restarts. `purge_deleted_accounts()` on pg_cron (hourly) drives it; the auth
delete needs the admin API, so use the **house pattern**: pg_cron → `pg_net` →
Edge Function authenticated by the Vault shared secret (exactly like
`dispatch-alert`). Do not invent a new auth path and do not `DELETE FROM auth.users`
directly — that skips identity/session/MFA cleanup.

### 6. Data export: server-side, complete, signed, and rate-limited.

Replace the client-side profile dump with one `export_user_data()` RPC that
assembles every table the user owns into a single JSON document, plus the ledger
as CSV (`exportLedger` already exists — reuse its shape). Delivery: a **signed,
short-expiry Storage URL** (or emailed via Resend, already onboard from C1 —
prefer email, it doubles as an ownership proof).

Two non-obvious requirements:

- **Rate-limit it.** Export is the cheapest full-account scrape in the product.
  Add a D2 bucket `data_export`, **2 / 24 h**. Add `account_delete` **3 / 24 h**
  while you are there.
- **Export must not leak other users.** `household_members` rows where the
  requester is the *member*, and `referral_points.referred_user_id`, describe
  other people. Export the requester's side only, and redact the counterparty to
  a stable opaque id.

Coverage list (the FK audit above is the checklist): profile, sim_lines,
scheduled_topups, topup_executions, wallets + wallet_transactions, plan_payments,
esim_orders + user_esims, referrals/points/redemptions (own side), notifications,
alert_settings, notification_channels, support_tickets + ticket_messages,
line_activity_log, offline_refill_settings + events, device_push_tokens,
own `security_logs` rows, `last_country`.

### 7. Consent defaults to OFF, and it must be a record, not a preference.

`toggleTrackingConsent` defaults to `true` and persists to `SharedPreferences`.
Both are wrong. C2 already settled the house pattern with the `promo` category:
**absence of a row means no consent, and `updated_at` is the consent timestamp**.
Follow it — server-side, timestamped, default off. If D5 later adds Firebase
Analytics this column becomes load-bearing overnight; if it is still a local bool
at that point the app will be shipping undisclosed tracking.

### 8. The privacy policy is a store blocker and it is *content*, not code.

"Read Full Privacy Policy" currently shows a snackbar. Produce a real document in
`doc/PRIVACY_POLICY.md` and host it at a stable URL; the screen must open that URL.
It has to cover what this app actually does, which is more than a template will
guess:

- foreground **location / country detection** (C8, `detect-country`, `ipapi.co`)
- **phone-number processing** for WhatsApp / SMS / missed-call refills (C4)
- payment data via **PayPal** (B3) and stored wallet balances
- **push tokens** via OneSignal and Firebase (C1/C1b)
- **biometrics (D1) — state explicitly that `local_auth` never transmits or
  stores biometric data off-device.** Reviewers ask this every time.
- **eSIM ICCID and data-usage telemetry** (C9)
- **support attachments** (C7) and their retention
- the third-party processor list: Supabase, PayPal, OneSignal, Firebase/FCM,
  Resend, Zendit, eSIM Go, ipapi.co, Twilio, Meta WhatsApp Business
- retention: operational data deleted on request, financial records retained
  anonymised for the statutory period — **say the number**

### 9. Play requires a *web* deletion URL, not just the in-app button.

The most commonly missed half of Google Play's Data Deletion policy: you must
provide a deletion route reachable **without installing the app**, declared in the
Play Console Data Safety form. A static page (`doc/` → GitHub Pages, or the
marketing site) explaining the in-app steps plus an email route satisfies it.
Note it as an owner deliverable with the exact URL to be pasted into both
consoles, alongside Apple's optional Account Deletion URL field.

### 10. Deletion must not become an abuse primitive.

Delete-and-recreate can farm referral bonuses, free-tier lines, and promo credit.
Keep the SHA-256 email hash in `account_deletions` and refuse a *new* referral
bonus to a re-registering hash within a short window. Keep it narrow and disclose
it in the policy — a hash of an email is still personal data, so it needs a stated
purpose and its own retention limit.

### 11. Tombstone the referral code.

`profiles.referred_by` stores a **text code, not an FK**, so it dangles after
deletion, and the freed `referral_code` can be re-issued to a new user who then
inherits stale attribution. Move deleted codes into a small
`retired_referral_codes` table and exclude them from generation.

---

## Scope checklist

1. **Migration `20260729000000_d3_account_deletion.sql`** (house convention:
   round manual timestamp, `timestamp_phase_description`, **saved locally the
   same session**):
   - `account_deletions` table (state machine + audit + legal-hold vault; RLS
     enabled, read-own for the requester's *own pending* row only, service_role
     writes).
   - `request_account_deletion(p_reason text, p_forfeit_dust boolean)` and
     `cancel_account_deletion()` — SECURITY DEFINER, `authenticated`, self-scoped
     on `auth.uid()`, rate-limited via D2's `enforce_rate_limit`.
   - `purge_deleted_accounts()` sweep + `cron.schedule()` **in the migration**
     (see D2 review note 4 — D2 created its health functions but never scheduled
     them; do not repeat that).
   - FK migration `CASCADE → SET NULL` on the financial + referral tables listed
     in §2/§3, with the identifying columns nulled at purge.
   - `retired_referral_codes`, `system_configs` seeds
     (`ACCOUNT_DELETION_GRACE_DAYS`=14, `WALLET_DUST_FORFEIT_USD`=1.00,
     `RATE_LIMIT_ACCOUNT_DELETE`=`3/1440`, `RATE_LIMIT_DATA_EXPORT`=`2/1440`).
   - `export_user_data()` RPC.
2. **Edge Function `delete_account` — rewrite and DEPLOY** (it is currently a
   404 the client already calls). It becomes a thin, re-auth-verifying caller of
   `request_account_deletion`. Plus a new **`purge-accounts`** function holding
   the admin-API delete + storage object cleanup, invoked by pg_cron via `pg_net`
   with the Vault shared secret — same shape as `dispatch-alert`. Redeploy with
   `import_map_path: "deno.json"` and a `deno.json` (`{}`) in `files`.
3. **Flutter:**
   - Rebuild the delete flow: re-auth (password **or** OTP for OAuth users) →
     D1 `PaymentAuthGuard` → a **consequences screen that itemises what is
     deleted, what is retained and for how long, and the exact wallet balance** →
     the existing type-`DELETE` gate → scheduled-state confirmation showing the
     purge date and a **Cancel deletion** action.
   - A pending-deletion interstitial that any session lands on while frozen.
   - Real `exportData()` against the new RPC.
   - Consent default OFF, server-side, C2 pattern.
   - Privacy policy opens a real URL.
   - Fix the hardcoded `'Confirm Delete'` string; ARB keys ×9 locales.
4. **Store artifacts** (`doc/`): `PRIVACY_POLICY.md`, the Play Data Safety answer
   sheet, the Apple privacy-nutrition-label answer sheet, and the web deletion
   page — with a short owner checklist naming exactly which console field takes
   which URL.
5. **Tests:**
   - `supabase/tests/d3_account_deletion_tests.sql`, live `BEGIN..ROLLBACK`:
     request → frozen state; cancel restores; **drain refuses to purge while a
     `routing` execution exists**; dust forfeit vs blocked balance; purge
     anonymises the ledger and leaves row counts intact; **a referred user's
     deletion leaves the referrer's points balance non-negative** (the C5
     regression); storage objects enumerated; `account_deletions` audit written;
     rate limit rejects the 4th request.
   - Dart tests for the consequence/consent/state widgets.
   - **Re-run** `c3_instant_recharge_tests.sql`, `c3b2_lockdown_tests.sql`,
     `c4_offline_recharge_tests.sql`, `c5`, `d2` — FK changes are exactly what
     breaks those.
6. **Gates:** `flutter analyze` 0 errors, info baseline **162**; `flutter test`
   ≥ 67 pass; `flutter build apk --debug`; MCP `get_advisors` 0 net-new; **a1
   wallet $35.86 unchanged**; no test account actually purged (every deletion
   test inside `BEGIN..ROLLBACK`).
7. Update `PRODUCTION_PLAN.md` § D3 with the implementation record in house
   style, flip to ✅ DONE, **correct § D2's "165" to 162**, and update the memory
   status file. One commit, `feat(privacy): D3 account deletion & data export`,
   pushed to `origin/main`.

---

## Confirm with owner at session start (non-blocking — proceed with defaults)

1. **Wallet policy**: dust (< $1.00) forfeited with explicit consent; anything
   above blocks deletion and offers spend-or-payout via a C7 support ticket.
   (default: yes)
2. **14-day grace period** with immediate freeze, cancellable, disclosed on the
   confirmation screen. (default: yes)
3. **Financial records retained anonymised** rather than deleted; state the
   retention period in the policy. (default: yes — propose **7 years**, ask the
   owner to confirm against their actual jurisdictions of incorporation and VAT
   registration; this is the one number in D3 that is a legal question, not an
   engineering one)
4. **Re-auth required** (password or emailed OTP) plus D1 biometric. (default: yes)
5. Owner supplies/approves the **hosted privacy-policy URL** and the **web
   deletion URL** for the Play console. (default: agent drafts, owner hosts)

---

## Session conventions (house rules — do not deviate)

- Migration file saved locally the same session; round manual timestamp;
  `timestamp_phase_description`; `cron.schedule()` calls go **in the migration**.
- SQL tests run live via MCP inside `BEGIN..ROLLBACK` — never leave rows behind,
  and **never purge a real account, including the a1 fixture**.
- ARB keys in all 9 locales (en, ar, es, hi, tr, bn, ne, si, ur); use the Edit
  tool for non-Latin files (PowerShell 5.1 mangles UTF-8); no blanket
  `dart format` — the repo is not format-clean at HEAD.
- No new pub or npm dependency (`share_plus`/`path_provider` already present).
- Wallet **$35.86** at start and end.
- Do **not** commit build artifacts — see D2 review note 5; there is a stray
  `android/build/reports/problems/problems-report.html` in the tree to remove.
- One commit, `feat(privacy): …`, pushed to `origin/main`.

---

## D2 review notes — fold the cheap ones into D3, do not re-do D2

D2 shipped a genuinely good architecture (DB-layer bucket, `clock_timestamp()`,
config-driven limits, typed KS429). Five defects were verified live against
`zwxswagokhgbuzrrbnhr` on 2026-07-25 and are carried here because D3 touches the
same surfaces:

1. **Rejections never reach `security_logs` on the RPC path — proven.**
   `consume_rate_limit` writes the audit row, then `enforce_rate_limit` raises
   KS429, which propagates out of the RPC; PostgREST aborts the transaction and
   **the audit row rolls back with it**. Probe: direct `consume_rate_limit`
   rejection → `security_logs` 0 → 1 (committed). Then the raising
   `enforce_rate_limit` path → still 1, not 2. Consequences: no forensics for the
   5 money RPCs, and `check_rate_limit_health()` can never fire from them.
2. **The `apply_referral` enumeration limit is void for the same reason.** The
   token is consumed, then `RAISE EXCEPTION 'Invalid referral code'` rolls the
   consumption back — so **every wrong guess is free** and only successful
   referrals cost a token. The one limit D2's own brief called "an actual
   vulnerability rather than a cost risk" is unmitigated. Fix: make the
   enumeration-sensitive RPC **return** a typed result instead of raising (so the
   transaction commits the bucket and the audit), or write the bucket through an
   autonomous transaction (`dblink`).
3. **`instant_refill` is double-charged, and the offline path is throttled
   against design rule 5.** `request_instant_refill` calls
   `enforce_rate_limit('instant_refill', auth.uid())`, then its own INSERT fires
   `check_topup_rate_limit()` which calls `enforce_rate_limit('instant_refill',
   NEW.user_id)` again — 2 tokens per refill, so the configured 10/hr is really
   5/hr. Worse, the trigger keys on `NEW.user_id`, **not `auth.uid()`**, so
   `ingest_offline_refill` (service_role, C4, inserts `execution_type =
   'refill_instant'` with `user_id` set) consumes the user's bucket. A
   WhatsApp/SMS refill can now be rejected because of in-app activity — exactly
   the server-initiated throttling rule 5 forbade.
4. **`check_rate_limit_health()` and `prune_rate_limit_data()` were created but
   never scheduled.** `cron.job` still holds the same 3 pre-D2 jobs, and the
   migration contains no `cron.schedule`. Item 4 of the plan is not actually
   wired — the functions are dead code. (The session record claims the job was
   added.)
5. **The client-side 429 formatter is misdirected and its regex is broken.**
   `RateLimitErrorFormatter` is imported by exactly one screen —
   `email_auth_screen.dart`. **None of the five money RPCs it was built for use
   it**, so an eSIM-purchase or plan-fee throttle still surfaces a raw
   `PostgrestException`. And rule 1's character class is
   `[a_zA-Z0-9_]` — a typo for `[a-zA-Z0-9_]` that excludes lowercase b–y, so it
   cannot match any real bucket name (`esim_purchase`, `plan_fee`, …). It is
   masked because the unit tests feed strings with a `"Rate limit exceeded:"`
   prefix that **`enforce_rate_limit` does not actually produce** (it raises the
   bare `RATE_LIMITED:<bucket>:<n>`), so the tests validate a message format that
   does not exist and rule 2 catches them instead. In production the string falls
   through to the generic `429 → 60 seconds` branch.
6. Housekeeping: the D2 commit added **`android/build/reports/problems/problems-report.html`**
   (a Gradle artifact) to git, and changed `android/gradle.properties` to a
   machine-specific JDK path. Remove the artifact, add `android/build/` to
   `.gitignore`, and consider untracking `gradle.properties`' `org.gradle.java.home`.
7. Also noticed while auditing storage for D3: bucket **`support_attachments` is
   PUBLIC with no file-size limit**. C7's real bucket is `ticket-attachments`
   (private, 10 MB). The public one appears to be a stray — delete it or lock it
   down. Zero objects today.

**Recommended split:** items 3, 4, 6, 7 are ~30 minutes and belong in D3's
commit as drive-bys. Items 1, 2, 5 are a genuine design correction — do them as a
small **D2b** follow-up commit *before* D3's main work, since D3 will want a
working limiter and a working error formatter for its own delete/export buckets.

---

## Known residual risks to carry forward (NOT D3 work — do not fix here)

- **D1 leftovers, still unfixed** (verified today at
  `biometric_lock_overlay.dart:42`): the lock triggers on
  `AppLifecycleState.inactive` as well as `paused` — `inactive` also fires for
  the iOS app-switcher preview, the notification shade, and **the OS biometric
  dialog itself**, which can lock mid-prompt. And `PaymentAuthGuard`'s 60 s grace
  window is never cleared on background. **Exception to this section's "do not
  fix here" rule:** D3 re-uses `PaymentAuthGuard` to gate deletion (§4), so both
  belong in the **D2b** commit — fix them there, not in the D3 commit.
- C9b's "e2e purchase" used synthetic fixtures; the real eSIM Go `/orders` v2.4
  contract is still unverified. eSIM go-live, E-phase.
- No stale-`pending` sweep on `esim_orders` — **D5**.
- Dev simulators still compiled into release — **D4**, and D4 must ship before
  any store build.
- Still pending owner: A2 key rotation; C4 WABA/Twilio provisioning (three
  webhooks still accept unsigned requests); dashboard delete of the
  `execute_zendit_recharge` tombstone.

## Execution prompt for the implementing agent

See the fenced prompt handed alongside this brief (chat); **this brief is the
source of truth if they diverge.**
