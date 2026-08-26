# KeepSIMs — Database Scenarios (SSOT)

**Single source of truth for backend auditing, RLS verification, RPC idempotency checks, edge-case debugging and performance work.**

| | |
|---|---|
| **Generated from** | live Supabase project `zwxswagokhgbuzrrbnhr`, schema `public` |
| **Schema state** | 133 migrations applied (phase `A` → `K10`), 68 base tables, 7 views, ~210 functions, 16 `pg_cron` jobs, 18 Edge Functions |
| **Date** | 2026-08-09 |
| **Money unit** | **USD everywhere.** `fx_rates` is display-only and must never be read on a money path. |

> [!IMPORTANT]
> Every fact in this document was read out of the live database (`pg_proc`, `pg_policies`, `information_schema.role_table_grants`, `pg_trigger`, `cron.job`), not from the migration files. Where a migration and the live database disagree, **the live database is what is documented here.**

---

## How to read this document

Each scenario has the same seven sections:

1. **Scenario Overview** — what triggers it.
2. **Tables & Columns Read** — with filters, joins and the index that serves them.
3. **Tables & Columns Written** — inserts / updates / deletes and the key fields.
4. **Functions, RPCs & Triggers Executed** — in fire order.
5. **RLS & Grant Lockdown** — policies evaluated, SECURITY DEFINER boundaries, revoked writes.
6. **Code Path** — client → RPC → gateway → webhook (kept minimal; the DB is the subject).
7. **Edge Cases, Security Risks & Failure Handling** — races, idempotency, rollback behaviour.

Notation used throughout:

| Symbol | Meaning |
|---|---|
| 🔒 `SECURITY DEFINER` | Function runs as its owner; RLS on tables it touches is **bypassed**. The guard inside the function *is* the security boundary. |
| 🔓 `SECURITY INVOKER` | Function runs as the caller; RLS still applies. |
| ⛔ | Write privilege **revoked** from `authenticated` / `anon` — the only write path is an RPC. |
| ⚠️ | Known gap / unfixed finding, carried here so it is not re-derived. |

---

# PART 0 — Global Invariants

These nine mechanisms appear in most scenarios. They are documented once here and referenced by name later.

## 0.1 The four-layer write model

```
Layer 1  RLS policy            ── "is this row yours?"
Layer 2  Table GRANT           ── "may this role write this table at all?"
Layer 3  SECURITY DEFINER RPC  ── "the only door; owns the guard"
Layer 4  BEFORE/AFTER trigger  ── "invariant that survives a bad caller"
```

A table is *locked down* when Layer 2 removes `INSERT/UPDATE/DELETE` from `authenticated`, leaving RLS to govern reads only. Current lockdown state of the money tables:

| Table | `anon` | `authenticated` | `service_role` |
|---|---|---|---|
| `wallets` | `SELECT` ⛔ | `SELECT` ⛔ | full |
| `wallet_transactions` | `SELECT` ⛔ | `SELECT` ⛔ | full |
| `topup_executions` | `SELECT` ⛔ | `SELECT` ⛔ | full |
| `plan_payments` | — | `SELECT` ⛔ | full |
| `paypal_orders` | — | `SELECT` ⛔ | full |
| `esim_orders` / `user_esims` | `SELECT` | `SELECT` ⛔ | full |
| `sim_lines` | `SELECT` | `SELECT, INSERT, DELETE` (**no UPDATE**) | full |
| `scheduled_topups` | `SELECT` | `SELECT, INSERT, UPDATE, DELETE` | full |
| `provider_offers` / `carrier_provider_map` / `service_providers` / `supplier_policy` | — | — (no grant at all) | full |
| `user_devices` / `device_money_events` / `admin_audit_log` / `offline_command_log` / `offer_price_history` | — | — (deny-all) | full |

> [!WARNING]
> `sim_lines` has `SELECT, INSERT, DELETE` for `authenticated` but **no UPDATE grant**, while four RLS `UPDATE` policies exist on it. Those policies are unreachable from a client — the grant is checked first. Any client feature that "updates a line" must go through an RPC or it will fail with `42501`, not with an RLS error. This has broken client writes twice historically (D5c, D5e), which is why `sim_line_rescue_policy` is a separate table.

## 0.2 Suspension is a JWT claim, not a table read

```sql
-- 🔓 SECURITY INVOKER, granted to anon + authenticated
CREATE FUNCTION is_user_suspended() RETURNS boolean AS $$
  BEGIN RETURN COALESCE((auth.jwt() -> 'app_metadata' ->> 'is_suspended')::boolean, false); END;
$$;
CREATE FUNCTION is_power_user(user_id uuid) RETURNS boolean AS $$
  BEGIN RETURN COALESCE((auth.jwt() -> 'app_metadata' ->> 'is_power_user')::boolean, false); END;
$$;
```

Both read the **JWT**, not `profiles`. They are kept in sync by two `AFTER` triggers on `profiles`:

- `on_profile_suspended_change` → `sync_suspended_claim()` 🔒
- `on_profile_power_user_change` → `sync_power_user_claim()` 🔒

`is_user_suspended()` appears in the `USING`/`WITH CHECK` clause of **~40 policies**. `is_power_user()` ignores its `user_id` argument entirely — it always answers about the *caller*.

> [!NOTE]
> **Latency of suspension.** Suspending a user updates `profiles`, which updates `auth.users.raw_app_meta_data`. The claim only takes effect on the **next token refresh** (up to 1 hour). Money RPCs therefore *also* re-check `profiles.is_suspended` directly (`request_instant_refill`, `pay_plan_fee_from_wallet`, `request_esim_purchase` all do `SELECT 1 FROM profiles WHERE id = auth.uid() AND is_suspended`). Read-only RLS is eventually consistent; the money path is immediately consistent.

## 0.3 The money guard (`guard_money_action`)

Every client-initiated debit passes through it:

```sql
guard_money_action(p_action, p_amount_usd, p_device_id, p_reference_id, p_user_id) → jsonb
```

1. Normalises the device id (`normalize_device_id`).
2. **Upserts `user_devices`** (`ON CONFLICT (user_id, device_id) DO UPDATE SET last_seen_at = now(), revoked_at = NULL`).
3. Calls `assess_device_risk()` 🔒 → `device_velocity()` over `device_money_events`.
4. **Always** inserts one row into `device_money_events` recording `assessed_decision`, `enforced`, `score`, `reason`, `detail`.
5. Returns `{decision, reason, score, enforced, blocked, event_id, detail}`.

`enforced` comes from `system_configs.DEVICE_RISK_ENFORCE`. **Shadow mode** = risk is scored and logged but `blocked` is always `false`. This is the pre-production stance: the capability ships inert, and flipping one config row makes it live.

`assess_device_risk` short-circuits on: risk disabled → `allow/risk_disabled`; user in `device_risk_allowlist` (unexpired) → `allow/allowlisted`; device `trust_state='trusted'` → `allow/device_trusted`. Otherwise it accumulates score from `accounts_on_device`, `cards_on_device`, `deposit_orders`, `deposit_usd`, `failed_captures`, `new_device_high_value`, and `device_blocked` (+100).

Callers and their action strings:

| RPC | action | Failure shape |
|---|---|---|
| `request_instant_refill` | `instant_refill` | `RAISE … ERRCODE 'KS451'`, message `DEVICE_BLOCKED:<reason>` |
| `pay_plan_fee_from_wallet` | `plan_fee` | **returns** `{success:false, code:'DEVICE_BLOCKED'}` — HTTP 200 |
| `request_esim_purchase` | `esim_purchase` | **returns** `{success:false, code:'DEVICE_BLOCKED'}` — HTTP 200 |
| `transfer_wallet_credit` | `gift` | returns `{success:false,…}` |
| `create-paypal-order` (Edge Fn) | `deposit_order` | HTTP 4xx from the function |

> [!WARNING]
> **The recurring "device_id bug".** `pay_plan_fee_from_wallet` and `request_esim_purchase` **do not raise** on a block — they return HTTP 200 with `success:false`. Any client that only checks for a thrown `PostgrestException` will read this as success. Only insufficient balance raises in `pay_plan_fee_from_wallet`; `DEVICE_BLOCKED`, suspended and unauthorized all come back as 200.

## 0.4 Rate limiting (token bucket)

```sql
enforce_rate_limit(p_bucket, p_key)          -- 🔒 raises KS429 'RATE_LIMITED:<bucket>:<retry_s>'
  └─ consume_rate_limit(bucket, key, capacity, refill_per_minute, now)  -- 🔒
```

- Capacity/window are read from `system_configs.RATE_LIMIT_<BUCKET>` in the form `"<capacity>/<minutes>"`; malformed values silently fall back to `10/60`.
- State lives in `rate_limit_buckets (bucket, key, tokens, updated_at)`, taken `FOR UPDATE` — serialised per key.
- A denial inserts a `security_logs` row (`event_type='rate_limited'`).
- **Both functions refuse to be called directly** by a non-`service_role` JWT: they inspect `GET DIAGNOSTICS … PG_CONTEXT` and raise `KS403` if the call stack depth is 1 (i.e. invoked straight from PostgREST rather than nested inside another SECURITY DEFINER RPC).
- `enforce_rate_limit` swallows *any* other exception into a `RAISE NOTICE` — a limiter fault fails **open**, deliberately, so a broken bucket never blocks a paying customer.

Buckets in use: `account_delete, admin_email, affiliate_click, apply_referral, data_export, detect_country, device_block_report, device_touch, esim_purchase, gift_credit, instant_refill, offline_command, plan_fee, referral_redeem, wallet_deduct, webhook_ip`.

## 0.5 The wallet ledger contract

Three writers, one shape. All 🔒, all `service_role`-only EXECUTE.

| Function | Direction | Wallet counters touched | Idempotency |
|---|---|---|---|
| `credit_wallet_for_deposit` | + | `balance`, `total_deposited` | unique index on `reference_id` where `type='deposit' AND reference_id LIKE 'paypal_%'` |
| `credit_wallet_for_refund` | + | `balance`, `total_spent = GREATEST(0, …)` | unique index per refund type |
| `debit_wallet_for_topup` | − | `balance`, `total_spent` | unique index per debit type |

All three take `SELECT … FROM wallets WHERE user_id = $1 FOR UPDATE` **before** computing `balance_after`. That row lock is the concurrency boundary for the whole account: two simultaneous debits serialise on it, so `balance_before`/`balance_after` in `wallet_transactions` are always a gapless chain.

Partial unique indexes are the idempotency mechanism — a duplicate reference raises `unique_violation` and the **entire** function rolls back, including the `UPDATE wallets`:

```
uq_wallet_transactions_paypal_capture   type='deposit'  AND reference_id LIKE 'paypal_%'
uq_wallet_transactions_debit_ref        type='topup_debit'
uq_wallet_transactions_plan_fee_ref     type='plan_fee_debit'
uq_wallet_transactions_refund_ref       type='refund'
uq_wallet_txns_esim_debit               type='esim_purchase_debit'
uq_wallet_txns_esim_refund_ref          type='esim_purchase_refund'
uq_wallet_txns_gift_sent_ref            type='gift_sent'
uq_wallet_txns_gift_received_ref        type='gift_received'
uq_wallet_txns_referral_credit_ref      type='referral_credit' AND reference_id LIKE 'refredeem_%'
```

Live `wallet_transactions.type` values: `deposit, topup_debit, plan_fee_debit, esim_purchase_debit, refund, referral_credit` (plus `gift_sent/gift_received/wallet_forfeit/wallet_settlement` defined but unused so far).

**Two different privilege guards** are used, and the difference matters:

```sql
-- credit_wallet_for_refund / purge_deleted_accounts / run_auto_rescue: hard refusal
IF v_jwt_role IS DISTINCT FROM 'service_role' THEN RAISE … ERRCODE='KS403'; END IF;

-- debit_wallet_for_topup / consume_rate_limit: refuse only a DIRECT call
GET DIAGNOSTICS v_ctx = PG_CONTEXT;
IF array_length(string_to_array(v_ctx, E'\n'),1) < 2 THEN RAISE … 'KS403'; END IF;
```

The second form lets `pay_plan_fee_from_wallet` (callable by `authenticated`) call `debit_wallet_for_topup` on the user's behalf, while a client calling `/rpc/debit_wallet_for_topup` directly is refused. **Stack-depth is the authorisation token.**

## 0.6 The refill cadence primitive

```sql
-- 🔓 IMMUTABLE-shaped SQL, granted to anon/authenticated/service_role
refill_interval_days(p_inactivity_limit_days int, p_override int) RETURNS int AS $$
  SELECT CASE
    WHEN p_override IS NOT NULL AND p_override > 0 THEN LEAST(365, p_override)
    WHEN p_inactivity_limit_days IS NULL OR p_inactivity_limit_days < 1 THEN NULL
    ELSE GREATEST(1, LEAST(365,
      p_inactivity_limit_days - GREATEST(7, ceil(p_inactivity_limit_days * 0.15)::integer)))
  END;
$$;
refills_per_year(...) = ceil(365 / refill_interval_days(...))
```

**The cadence comes from the carrier's deactivation window, not from the top-up's validity.** A carrier that deactivates at 90 days is refilled every `90 − max(7, 14) = 76` days. `carrier_rules.topup_validity_days` is *not* a cycle and must not be used as one.

Everything that schedules or prices a year of refills goes through this one function: `plan_price_net`, `queue_premium_refill_executions`, `compute_usage_forecasts`.

## 0.7 Carrier activity semantics (phase I7)

`carrier_rules.activity_requirement` ∈ `{recharge_ok, min_denomination, usage_required}`.

| Value | Meaning | System behaviour |
|---|---|---|
| `recharge_ok` | Any top-up resets the inactivity clock. | Normal automation. |
| `min_denomination` | Only a top-up ≥ `validity_qualifying_topup_amount` resets it. | Every price/queue path floors the amount to the qualifying value. |
| `usage_required` | Only an outgoing call/SMS/data session resets it. **Refilling cannot keep the line alive.** | Premium is **refused before charging**, with `ERRCODE = 'KS422'`. |

> [!IMPORTANT]
> `carrier_rules.minimum_topup_amount` is a **validity threshold, not a price**. It answers "how much must be sent for the carrier to count it", never "what does an offer cost". The price always comes from `provider_offers` via `carrier_refill_offer()`. Conflating the two broke premium refills on 26 of 36 carriers.

`carrier_qualifying_topup_amount(carrier_id)` returns the floor; `carrier_refill_offer(carrier_id, min_usd)` raises the caller's request to that floor before searching the shelf.

## 0.8 Notification fan-out

One insert into `notifications` is the *only* way anything reaches a user. `trg_on_notification_created` (AFTER INSERT) → `trg_fn_dispatch_notification()` 🔒:

```
channels = user's notification_channels (is_enabled)
         ∩ alert_settings[category].channels        (absent row ⇒ all channels, except category='promo' ⇒ none)
         ∩ notification_channel_catalog (is_globally_enabled)   -- operator kill switch
if protection_tier/subscription_tier = 'basic' → channels ∩ {push}
if channels empty AND 'push' allowed by category AND push globally on → channels = {push}   -- safety net
UPDATE notifications SET delivered_via = channels
if enabled AND channels ≠ ∅:
    net.http_post → <project>/functions/v1/dispatch-alert
    header x-keep-sims-secret = vault.decrypted_secrets['dispatch_shared_secret']
```

- The catalog kill switch is consulted **including by the push safety net** — an operator disabling `push` cannot have it silently re-added.
- If `notification_channel_catalog` is empty for any reason it falls back to `{push,email,telegram,whatsapp}` — fail soft, not silent.
- `promo` inverts the default: an absent `alert_settings` row means *not consented*.
- The Edge Function writes one `notification_deliveries` row per channel per attempt.

## 0.9 Cron schedule (live `cron.job`)

| Time (UTC) | Job | Calls |
|---|---|---|
| `*/5 * * * *` | reap-stuck-executions | `reap_stuck_executions()` |
| `*/10 * * * *` | check-worker-heartbeat | `check_worker_heartbeat_health()` |
| `0 * * * *` | process-hourly-notifications | `process_due_notifications()` |
| `0 * * * *` | purge-deleted-accounts-hourly | `purge_deleted_accounts()` |
| `0 * * * *` | reap-stale-esim-orders-hourly | `reap_stale_esim_orders()` |
| `30 * * * *` | refill-pipeline-health | `check_refill_pipeline_health()` |
| `30 * * * *` | check-rate-limit-health | `check_rate_limit_health()` |
| `50 * * * *` | run-auto-rescue | `run_auto_rescue()` |
| `20 2 * * *` | refresh-usage-forecasts | `refresh_usage_forecasts()` |
| `40 2 * * *` | refresh-offer-price-watch | `refresh_offer_price_watch()` |
| `55 2 * * *` | emit-carrier-self-service-advice | `emit_carrier_self_service_advice()` |
| `0 3 * * *` | prune-rate-limit-data | `prune_rate_limit_data()` |
| `10 3 * * *` | refresh-fx-rates | `kick_fx_refresh()` |
| `40 3 * * *` | sync-esim-catalogue | `kick_esim_catalogue_sync()` |
| `10 4 * * *` | sync-affiliate-network | `kick_affiliate_sync(45)` |
| `30 4 * * *` | refresh-provider-offers | `refresh_provider_offers()` |

The nightly chain is ordered on purpose: forecasts (02:20) → price watch (02:40) → advice (02:55) → FX (03:10) → eSIM catalogue (03:40) → affiliates (04:10) → **shelf rebuild (04:30)**, so `provider_offers` is rebuilt after every upstream source has landed.

## 0.10 Custom SQLSTATE vocabulary

| Code | Raised by | Meaning |
|---|---|---|
| `KS402` | `debit_wallet_for_topup`, `request_instant_refill` | Household cap exceeded (`HOUSEHOLD_CAP:<reason>:<cap>:<spent>:<remaining>`) |
| `KS403` | wallet fns, `queue_premium_refill_executions`, `purge_deleted_accounts`, `run_auto_rescue`, `trg_fn_prevent_sim_line_plan_tampering` | Role / entitlement refusal |
| `KS422` | `plan_price_net`, `queue_premium_refill_executions` | Carrier semantics make the request unfulfillable |
| `KS429` | `enforce_rate_limit` | `RATE_LIMITED:<bucket>:<retry_seconds>` |
| `KS451` | `request_instant_refill` | Device risk block |
| `KS460` | `assert_admin` | Admin access required |
| `KS462/KS463` | `refresh_fx_rates` | Bad payload / absent-or-future `as_of` |

---
# CATEGORY A — User Security, Device Risk & Account Lifecycle

---

## Scenario A1 — Authentication, Profile Bootstrap & Device Fingerprinting

### 1. Scenario Overview
A user signs in with Google OAuth or email/password. Supabase GoTrue writes `auth.users`. Everything the app needs in `public` is created by **one AFTER INSERT trigger on `auth.users`**, and the app's first authenticated call registers the install in `user_devices`.

### 2. Tables & Columns Read

| Table | Columns | Filter / Join | Index |
|---|---|---|---|
| `auth.users` | `id, email, raw_user_meta_data->>full_name/name/avatar_url/picture` | `NEW` row in trigger | pk |
| `profiles` | `id, is_suspended, is_power_user, subscription_tier, referral_code` | `id = auth.uid()` | `profiles_pkey` |
| `wallets` | `balance, currency, total_deposited, total_spent` | `user_id = auth.uid()` | `wallets_user_id_*` |
| `user_preferences` | all | `user_id = auth.uid()` | uq on `user_id` |
| `notification_channels` | `channel_type, is_enabled, config` | `user_id = auth.uid()` | uq `(user_id, channel_type)` |
| `alert_settings` | `category, is_enabled, channels` | `user_id = auth.uid()` | uq `(user_id, category)` |
| `system_configs` | `DEVICE_RISK_MAX_DEVICES_PER_USER` | `config_key = …` | pk |
| `user_devices` | `user_id, device_id` | existence probe before cap check | `user_devices_pkey (user_id, device_id)` |
| `household_members` | `member_email` | invite claim on profile insert | — |

### 3. Tables & Columns Written

`handle_new_user()` 🔒 (`AFTER INSERT ON auth.users`) writes **four rows in one transaction**:

```sql
INSERT INTO profiles (id, email, full_name, avatar_url, referral_code)   -- 'SS' || 8 hex chars
INSERT INTO wallets (user_id, currency)                                   -- balance 0.00
INSERT INTO user_preferences (user_id)                                    -- theme 'system', language 'en'
INSERT INTO notification_channels (user_id, channel_type, is_enabled)     -- ('push', TRUE)
```

That `INSERT INTO profiles` then fires **four more AFTER triggers**:

| Trigger | Function | Writes |
|---|---|---|
| `trg_profiles_seed_alert_settings` | `seed_default_alert_settings()` 🔒 | 15 `alert_settings` rows, one per category, `is_enabled = (category <> 'promo')`, `channels = {push,email,telegram,whatsapp}` |
| `on_profile_power_user_change` | `sync_power_user_claim()` 🔒 | `auth.users.raw_app_meta_data.is_power_user` |
| `on_profile_suspended_change` | `sync_suspended_claim()` 🔒 | `auth.users.raw_app_meta_data.is_suspended` |
| `trg_profiles_claim_household_invites` / `trg_profiles_after_insert_resolve_invites` | `claim_pending_household_invites()`, `resolve_pending_household_invites()` 🔒 | `household_members.member_id` for pending invites matching this email |

The 15 seeded categories: `top_up_success, top_up_failed, wallet_low, wallet_depleted, line_critical, line_entering_grace, geo_fence_triggered, welcome_home_ready, referral_reward, system, wallet_credit, promo, support, esim_low_data, carrier_action`.

Device registration — `touch_user_device(p_device_id, p_platform, p_app_version)` 🔒:

```sql
INSERT INTO user_devices (user_id, device_id, platform, app_version)
VALUES (auth.uid(), normalize_device_id($1), $2, left($3,32))
ON CONFLICT (user_id, device_id) DO UPDATE
  SET last_seen_at = now(),
      platform     = COALESCE(EXCLUDED.platform,    ud.platform),
      app_version  = COALESCE(EXCLUDED.app_version, ud.app_version),
      revoked_at   = NULL;
```

### 4. Functions, RPCs & Triggers Executed

| Order | Object | Type | Notes |
|---|---|---|---|
| 1 | `handle_new_user()` | 🔒 trigger fn | on `auth.users` |
| 2 | `protect_is_power_user()` | 🔒 BEFORE trigger | refuses a client setting `is_power_user` |
| 3 | `seed_default_alert_settings()` | 🔒 | `ON CONFLICT DO NOTHING` — safe to re-run |
| 4 | `sync_power_user_claim()` / `sync_suspended_claim()` | 🔒 | write JWT app_metadata |
| 5 | `claim_pending_household_invites()` / `resolve_pending_household_invites()` | 🔒 | |
| 6 | `touch_user_device()` | 🔒, `authenticated` | first authenticated call |
| 7 | `consume_rate_limit('device_touch', …, 30, 0.5)` | 🔒 | 30 burst, 0.5/min refill |
| 8 | `get_current_context()` | 🔓 `authenticated` | app bootstrap read |
| 9 | `apply_referral(p_referred_id, p_referral_code)` | 🔒 `authenticated` | optional, onboarding |

### 5. RLS & Grant Lockdown

| Table | Policy | Effect |
|---|---|---|
| `profiles` | `Users can view own or household profiles` (SELECT, authenticated) | own row **OR** `is_power_user(auth.uid())` **OR** an accepted `household_members` link in either direction |
| `profiles` | `Users can insert own profile` / `Users can update own profile` | `auth.uid() = id AND NOT is_user_suspended()` |
| `wallets` | `Users can view own wallet` (SELECT) | read-only; `INSERT/UPDATE/DELETE` ⛔ revoked |
| `user_devices` | **no policies at all** — deny-all | read your own only via `my_devices()` 🔒 |

> [!IMPORTANT]
> `profiles` grants `authenticated` only `SELECT, INSERT` — there is **no UPDATE grant**, despite an UPDATE policy existing. Profile edits must go through an RPC. `protect_is_power_user()` is the belt-and-braces layer: even a `service_role` mistake cannot silently promote a user without going through the admin surface.

> [!NOTE]
> **Device cap.** `touch_user_device` reads `DEVICE_RISK_MAX_DEVICES_PER_USER` (default 10). When the cap is reached the new device is **not recorded** and a `security_logs` row `device_registry_cap_reached` is written — the call still returns the normalised device id, so the app is not broken by hitting the cap. Risk scoring then sees this device as unregistered.

### 6. Code Path

```
Flutter  supabase.auth.signInWithOAuth(google)
  → GoTrue  INSERT auth.users
      → trg handle_new_user()  ⇒ profiles + wallets + user_preferences + notification_channels
          → trg seed_default_alert_settings()  ⇒ 15 alert_settings
          → trg sync_*_claim()                 ⇒ app_metadata
          → trg claim/resolve household invites
  → Flutter  rpc('touch_user_device', {device_id, platform, app_version})
  → Flutter  select profiles/wallets/sim_lines  (RLS-filtered)
```

### 7. Edge Cases, Security Risks & Failure Handling

- **Partial bootstrap is impossible.** All four inserts are in the same trigger, in the same transaction as the `auth.users` insert. If `wallets` fails, the *sign-up* fails. There is no "user with no wallet" state.
- **Referral code collision.** `referral_code` is `'SS' + 8 hex` from a UUID — a unique-violation would abort sign-up. `retired_referral_codes` holds codes released by purged accounts to prevent reuse (8 rows live).
- **`device_id` is client-supplied and unverifiable.** It is a *correlation key*, not an identity. `normalize_device_id()` is `SECURITY INVOKER` and granted to `anon` — treat any device-based conclusion as heuristic. App Check (A2) is the only attestation.
- **Race: two devices sign in simultaneously.** `ON CONFLICT (user_id, device_id)` makes `touch_user_device` idempotent; the device-cap check is *not* inside the upsert, so two concurrent first-touches can both pass the cap check and insert `cap + 1` rows. Low impact (the cap is advisory), but it is a real TOCTOU.
- **Rate limiter fails open.** If `device_touch` bucket is exhausted, `touch_user_device` returns the device id *without* recording it — deliberately, so a noisy client cannot lock itself out of the app.

---

## Scenario A2 — App Check, IP/Device Velocity & Durable Block Audit

### 1. Scenario Overview
Before any money moves, three independent checks run: **Firebase App Check** attestation (Edge Function layer), **device velocity** scoring (`assess_device_risk`), and a **durable audit** of every decision (`device_money_events`). Blocks that the client observes but the server did not record are replayed back with `report_device_block()` so the audit trail is complete.

### 2. Tables & Columns Read

`device_velocity(p_device_id, p_window_hours)` 🔒 — the single source of every velocity count:

| CTE | Table | Columns | Filter |
|---|---|---|---|
| `accounts` | `user_devices` | `user_id, first_seen_at, trust_state` | `device_id = normalize_device_id($1)` — **`idx_user_devices_device_id`** |
| `instruments` | `payment_methods` ⋈ accounts | `token`, else `provider|last_four|expiry_month|expiry_year` | distinct fingerprint per account on the device |
| `dep` | `device_money_events` | `count(*)`, `sum(amount_usd)` | `device_id = … AND action='deposit_order' AND created_at >= now() - window` — **`idx_dme_device_created`** |
| `fail_dev` | `device_money_events` ⋈ `paypal_orders` | `count(DISTINCT po.order_id)` | join on `po.order_id = e.reference_id`, `po.status='failed'` |
| `fail_usr` | `paypal_orders` | `count(*)` | `user_id IN (accounts)`, `status='failed'` |

Returns `accounts_on_device, cards_on_device, deposit_orders, deposit_usd, failed_captures (= GREATEST(dev, usr)), first_seen_at, worst_trust_state`.

`worst_trust_state` = `'blocked'` if **any** account on the device is blocked, `'trusted'` only if **all** are trusted, else `'unknown'` — deliberately pessimistic on block, optimistic only on unanimity.

`device_risk_config()` 🔒 reads the 16 `DEVICE_RISK_*` keys from `system_configs`.

### 3. Tables & Columns Written

| Table | When | Key fields |
|---|---|---|
| `device_money_events` | **every** `guard_money_action` call | `user_id, device_id, action, amount_usd, assessed_decision, enforced, reason, score, reference_id, detail` |
| `user_devices` | upsert inside `guard_money_action` | `last_seen_at = now()`, `revoked_at = NULL` |
| `user_devices` | `log_app_check_result(outcome='pass')` | `attested_at = now()` |
| `security_logs` | App Check `missing`/`invalid`/`error` | `event_type = 'app_check_' || outcome`, metadata carries `device_id`, `platform` |
| `security_logs` | rate-limit denial | `event_type='rate_limited'` |

### 4. Functions, RPCs & Triggers Executed

| Function | Grant | Role |
|---|---|---|
| `app_check_should_enforce(p_platform)` 🔒 | `service_role` | `APP_CHECK_ENFORCE='true'` **AND** platform ∈ `APP_CHECK_ENFORCE_PLATFORMS` (default `'android'`) |
| `log_app_check_result(user, outcome, device, platform, detail)` 🔒 | `service_role` | validates outcome ∈ `{pass,missing,invalid,error}`; `pass` stamps `attested_at`, everything else logs |
| `assess_device_risk(user, device, action, amount)` 🔒 | `service_role` | scoring |
| `guard_money_action(...)` 🔒 | `service_role` | orchestrator + audit writer |
| `report_device_block(action, amount, device)` 🔒 | **`authenticated`** | client replay of an observed block |
| `attach_device_money_reference(event_id, reference_id)` 🔒 | `service_role` | back-fills the PayPal order id after the order is created |
| `device_risk_shadow_report(days)` 🔒 / `app_check_summary(days)` 🔒 | `service_role` | operator readouts |

Scoring weights (from `assess_device_risk`, defaults when the config key is absent):

| Signal | Threshold key | Score added |
|---|---|---|
| device `trust_state='blocked'` | — | **+100** (forces deny) |
| accounts on device > `DEVICE_RISK_MAX_ACCOUNTS` (4) | | +40, +20 per extra (cap 3) |
| distinct cards > `DEVICE_RISK_MAX_CARDS` (3) | | +40, +20 per extra |
| deposit orders > `DEVICE_RISK_MAX_DEPOSITS` (8) | | +30, +15 per extra |
| deposit USD > `DEVICE_RISK_MAX_DEPOSIT_USD` (600) | | +30, +30 more past 2× |
| failed captures > `DEVICE_RISK_MAX_FAILED_CAPTURES` (4) | | +35, +15 per extra |
| device younger than `DEVICE_RISK_NEW_DEVICE_HOURS` (24) **and** amount > `NEW_DEVICE_MAX_USD` (150) | | +25 |
| no device id at all | `DEVICE_RISK_MISSING_DEVICE_SCORE` (25) | +25 |

Decision: `score ≥ DEVICE_RISK_DENY_SCORE (80)` → `deny`; `≥ DEVICE_RISK_CHALLENGE_SCORE (40)` → `challenge`; else `allow`.

### 5. RLS & Grant Lockdown

> [!IMPORTANT]
> **The thresholds are hidden from clients.** `system_configs` has a policy `Hide device risk thresholds from clients` for `{anon, authenticated}`:
> ```sql
> USING (config_key NOT LIKE 'DEVICE\_RISK\_%')
> ```
> A signed-in user can read every other config key but cannot learn the score at which they would be denied.

- `user_devices`, `device_money_events`, `device_risk_allowlist` — **deny-all** (RLS on, zero policies), and no grant to `authenticated`. Only `service_role` and SECURITY DEFINER functions reach them.
- A user reads their own devices only through `my_devices()` 🔒, and mutates them only through `label_my_device()` / `revoke_my_device()` 🔒.
- `device_risk_allowlist.reason` is `NOT NULL` by design — every exemption must be defensible.
- `report_device_block` is the one risk function granted to `authenticated`. It is safe because it (a) validates `p_action` against a fixed list, (b) has its own 20-token bucket, (c) forces `p_user_id = auth.uid()`, and (d) writes a `reference_id = 'device_block_replay'` marker so replayed events are distinguishable from server-observed ones.

### 6. Code Path

```
Flutter → Edge Fn (create-paypal-order)
    verify Firebase App Check token
      → rpc log_app_check_result(pass|missing|invalid|error)
      → if app_check_should_enforce(platform) and not pass ⇒ 401, stop
    → rpc guard_money_action('deposit_order', amount, device_id, null, user)
        → assess_device_risk → device_velocity → INSERT device_money_events
    → if blocked ⇒ 4xx           else ⇒ PayPal Orders API
    → rpc attach_device_money_reference(event_id, paypal_order_id)
Client-side block observed but no server event ⇒ rpc report_device_block(...)
```

### 7. Edge Cases, Security Risks & Failure Handling

- **Shadow mode is the default.** `DEVICE_RISK_ENFORCE=false` means `enforced=false` on every event and `blocked` is never true. `device_risk_shadow_report(days)` compares `assessed_decision` vs `enforced` so the deny threshold can be tuned against real traffic **before** it is armed. This is the correct pre-production stance: the test is "does flipping this change a live decision?", and today it does not.
- **The audit is written even when the decision is `allow`.** `device_money_events` is the *source of every velocity count*, so suppressing allow-events would blind the next assessment. 50 rows live.
- **`failed_captures` is deliberately double-counted.** `GREATEST(fail_dev, fail_usr)` catches both "this device failed captures" and "an account on this device failed captures elsewhere". A fraudster rotating device ids still trips the user-side count.
- **Card fingerprinting degrades gracefully.** If `payment_methods.token` is empty it falls back to `provider|last_four|expiry` — weaker, but never NULL, so `count(DISTINCT)` stays meaningful.
- ⚠️ **`assess_device_risk` returns `NOT FOUND` for an unregistered device.** In that branch only the `new_device_high_value` rule can fire — an attacker who sends a *fresh random device id per request* scores at most 25 (below the 40 challenge threshold) unless the amount is large. `DEVICE_RISK_MISSING_DEVICE_SCORE` covers a *null* device but not a *novel* one. Consider scoring "device id never seen in `device_money_events`" the same as missing.
- **App Check enforcement is per-platform.** `APP_CHECK_ENFORCE_PLATFORMS` defaults to `'android'` only — iOS/web money calls are logged but not blocked until that key is widened.

---

## Scenario A3 — Notification Preferences & Channel Catalog

### 1. Scenario Overview
Two layers of preference sit between an event and a message: the **user's** switches (`notification_channels` = which transports, `alert_settings` = which categories on which transports), and the **operator's** catalog (`notification_channel_catalog` = which transports exist at all). Category B of `dispatch-alert` resolves them at insert time.

### 2. Tables & Columns Read

| Table | Columns | Filter |
|---|---|---|
| `notification_channel_catalog` | `channel_key, is_globally_enabled, min_tier, user_configurable, monthly_quota, sort_order` | full scan of 5 rows, ordered by `sort_order` |
| `notification_channels` | `channel_type, is_enabled` | `user_id = NEW.user_id AND is_enabled` |
| `alert_settings` | `is_enabled, channels` | `user_id = NEW.user_id AND category = NEW.category` |
| `sim_lines` | `protection_tier` | `id = NEW.sim_line_id` (when the notification is line-scoped) |
| `profiles` | `subscription_tier` | fallback when no line |
| `vault.decrypted_secrets` | `decrypted_secret` | `name = 'dispatch_shared_secret'` |

Live catalog (5 rows): `push, email, telegram, whatsapp, sms`. Live `notification_channels`: 29 rows across 8 users. Live `alert_settings`: 120 rows (8 users × 15 categories).

### 3. Tables & Columns Written

| Table | Write | By |
|---|---|---|
| `alert_settings` | user toggles `is_enabled`, edits `channels[]` | direct client write (RLS `ALL` policy) |
| `notification_channels` | user enables/disables a transport, stores `config` jsonb (e.g. telegram chat id) | direct client write |
| `notifications.delivered_via` | `UPDATE … SET delivered_via = <resolved channels>` | `trg_fn_dispatch_notification()` 🔒 |
| `notification_deliveries` | one row per channel attempt: `status, detail, provider_status` | `dispatch-alert` Edge Fn (`service_role`) |
| `notification_channel_catalog` | `is_globally_enabled`, `credential_status`, `min_tier` … | **admin only**, `admin_update_channel()` 🔒 |

### 4. Functions, RPCs & Triggers Executed

| Object | Notes |
|---|---|
| `seed_default_alert_settings()` 🔒 | AFTER INSERT on `profiles`; 15 rows, `ON CONFLICT DO NOTHING` |
| `trg_fn_dispatch_notification()` 🔒 | AFTER INSERT on `notifications` — see §0.8 |
| `bind_telegram_bot(user, chat_id)` 🔒 | `service_role`; called by the Telegram server when a user links |
| `admin_list_channels()` 🔒 | operator view: `users_enabled, sent_30d, failed_30d, skipped_30d, last_delivery_at` per channel |
| `admin_update_channel(key, patch, note)` 🔒 | writes catalog + `admin_audit_log` |
| `admin_notification_health(days)` 🔒 | `channel × status` rollup from `notification_deliveries` |
| `process_due_notifications()` 🔒 | hourly cron; drains delayed notifications queued by `schedule_delayed_notification()` |

### 5. RLS & Grant Lockdown

| Table | Policy | Grant |
|---|---|---|
| `alert_settings` | `Users can manage own alert settings` — `ALL`, `auth.uid()=user_id AND NOT is_user_suspended()` | full CRUD for `authenticated` |
| `notification_channels` | `Users can manage own notification channels` — `ALL`, same predicate | full CRUD |
| `notification_channel_catalog` | `Anyone signed in can read the channel catalog` — SELECT `true` | **`SELECT` only** ⛔ |
| `notifications` | own-row SELECT/INSERT/UPDATE/DELETE, all `AND NOT is_user_suspended()` | full CRUD |
| `notification_deliveries` | `deliveries_select_own` — SELECT only | grant is full CRUD ⚠️ |

> [!WARNING]
> ⚠️ `notification_deliveries` has an own-row SELECT policy but `authenticated` still holds `INSERT/UPDATE/DELETE`. With no INSERT/UPDATE policies those writes are blocked by RLS today, but the grant is broader than intended — a future permissive policy would open a delivery-log forgery path. Same shape on `notifications` (users *can* insert their own notifications, which is intentional for local reminders but means `delivered_via` can be set by a client on a self-authored row).

> [!NOTE]
> `notification_channel_catalog.credential_status` is **maintained by hand**. The database cannot read Edge Function secrets, so a computed value would be a lie. Treat it as an operator assertion, not a health check.

### 6. Code Path

```
Settings screen → upsert alert_settings / notification_channels (direct, RLS-guarded)
Any event      → INSERT notifications
                  → trg_fn_dispatch_notification  (resolve channels, stamp delivered_via)
                    → net.http_post dispatch-alert  (x-keep-sims-secret from Vault)
                      → FCM / Resend / Telegram / WhatsApp  → INSERT notification_deliveries
```

### 7. Edge Cases, Security Risks & Failure Handling

- **Default-on vs default-off.** No `alert_settings` row ⇒ enabled, *except* `promo` ⇒ disabled. Marketing needs explicit opt-in; operational alerts must not be lost to a missing row.
- **Tier narrowing is per-line, not per-account.** `protection_tier` of the *line* wins over `subscription_tier` of the *profile*. A `basic` line on a premium account is still push-only.
- **The push safety net respects the kill switch.** If the user has switched every channel off, push is re-added — but only if `push` is in the category's channel list *and* globally enabled. Turning `push` off in the catalog genuinely turns it off.
- **Empty catalog fallback.** If `notification_channel_catalog` were truncated, dispatch reverts to the pre-H4 behaviour (`{push,email,telegram,whatsapp}`) rather than muting the product.
- **`net.http_post` is fire-and-forget.** A failure to reach `dispatch-alert` leaves the `notifications` row written and `delivered_via` stamped, with **no** `notification_deliveries` row. Reconcile with `admin_notification_health(days)`: notifications with `delivered_via ≠ '{}'` and zero deliveries are lost dispatches.
- **Secret rotation.** `dispatch_shared_secret` lives in Vault and is read on *every* notification insert. Rotating it requires updating Vault and the Edge Function secret together, or every alert 401s silently.

---

## Scenario A4 — GDPR Account Deletion & Scheduled Purge Pipeline

### 1. Scenario Overview
Deletion is a **two-phase, grace-period pipeline**: the user requests it (account is frozen immediately), and an hourly cron purges after the grace window — but only once nothing is in flight. Financial rows are never deleted; they are **de-identified** (`user_id → NULL`) so the ledger stays auditable.

State machine: `requested → frozen → draining → purged`, with `cancelled` reachable only from `requested`/`frozen`.

### 2. Tables & Columns Read

**`request_account_deletion(p_reason, p_forfeit_dust)`** 🔒 (`authenticated`):

| Table | Columns | Filter |
|---|---|---|
| `account_deletions` | `status` | `user_id = auth.uid() AND status IN ('requested','frozen','draining')` — early-return if found |
| `auth.users` | `email` | `id = auth.uid()`; hashed to `sha256(lower(trim(email)))` hex |
| `wallets` | `balance` | `user_id = auth.uid()` |
| `system_configs` | `ACCOUNT_DELETION_GRACE_DAYS` (14), `WALLET_DUST_FORFEIT_USD` (1.00) | |

**`purge_deleted_accounts()`** 🔒 (`service_role`, hourly):

| Table | Purpose |
|---|---|
| `account_deletions` | rows with `status IN ('frozen','draining')` |
| `topup_executions` | `count(*) WHERE user_id = … AND status='routing'` — **in-flight money** |
| `esim_orders` | `count(*) WHERE status IN ('pending','processing')` — in-flight fulfilment |
| `profiles.referral_code` | to retire the code |
| `wallets` | per-wallet balance to zero out |

### 3. Tables & Columns Written

**Phase 1 — request:**

```sql
INSERT INTO account_deletions (user_id, email_hash, status='requested',
        wallet_balance_at_request, dust_forfeited, reason, actor_id, scheduled_purge_at);
UPDATE profiles       SET is_suspended = true      WHERE id = auth.uid();
UPDATE scheduled_topups SET is_active = false      WHERE sim_line_id IN (user's lines);
PERFORM cancel_topup_execution(id) FROM topup_executions
        WHERE user_id = auth.uid() AND status IN ('pending','pending_payment');
```

**Phase 2 — purge**, per account, in this exact order:

| Step | Table | Operation |
|---|---|---|
| 1 | `account_deletions` | `requested → frozen` where `scheduled_purge_at <= now()` |
| 2 | `account_deletions` | `→ draining`, stamp `drained_at` |
| 3 | `retired_referral_codes` | `INSERT … ON CONFLICT DO NOTHING` |
| 4 | `wallet_transactions` | one closing row per non-zero wallet: `type = 'wallet_forfeit'` or `'wallet_settlement'`, `balance_after = 0.00`, `reference_id = 'purge_<deletion_id>'` |
| 5 | `wallets` | `balance = 0.00, user_id = NULL` (**row survives, ownership severed**) |
| 6 | `referral_points` | `sim_line_id = NULL` |
| 7 | **De-identify** | `wallet_transactions`, `plan_payments`, `esim_orders`, `user_esims`, `topup_executions` → `user_id = NULL` |
| 8 | **Delete** | `line_activity_log` (by line), `scheduled_topups` (by line), `offline_refill_settings`, `sim_lines`, `ticket_messages`, `support_tickets`, `alert_settings`, `notification_channels`, `notifications`, `device_push_tokens`, `user_consents` |
| 9 | `account_deletions` | `→ purged`, stamp `purged_at` |
| 10 | Edge Fn | `net.http_post → /functions/v1/purge-accounts` with `{user_id}` and the Vault shared secret — deletes the `auth.users` row |

If in-flight work exists, the account is **skipped** and retried next hour. If it has been stuck >72 h past `scheduled_purge_at`, a `system_alerts` row `account_purge_stuck` is written (which itself fires `trg_notify_system_alert`).

### 4. Functions, RPCs & Triggers Executed

| Object | Grant | Notes |
|---|---|---|
| `request_account_deletion(reason, forfeit_dust)` 🔒 | `authenticated` | rate bucket `account_delete` |
| `cancel_account_deletion()` 🔒 | `authenticated` | only from `requested`/`frozen`, only before `scheduled_purge_at`; un-suspends the profile |
| `export_user_data()` 🔒 | `authenticated` | GDPR portability; rate bucket `data_export` |
| `cancel_topup_execution(id)` 🔒 | `authenticated` | cancels each pending execution |
| `purge_deleted_accounts()` 🔒 | `service_role` **only** (hard `KS403` guard) | hourly cron |
| `delete_auth_user_by_id(uuid)` 🔒 / `check_auth_user_exists(uuid)` 🔒 | `service_role` | used by the `purge-accounts` Edge Fn |
| `trg_fn_notify_system_alert()` 🔒 | | AFTER INSERT on `system_alerts` |

### 5. RLS & Grant Lockdown

- `account_deletions` — one policy: `account_deletions_select_own` (SELECT, `auth.uid() = user_id`). ⚠️ **The grant is still full CRUD for `anon` and `authenticated`.** No INSERT/UPDATE policy exists, so writes are blocked by RLS — but this table is a security-relevant record and should be `REVOKE INSERT, UPDATE, DELETE`d to match the wallet tables.
- `purge_deleted_accounts()` has the **hard** role guard (raises `KS403` for any non-`service_role` JWT), not the stack-depth guard — it must never be reachable from PostgREST.
- `wallets.user_id` is nullable *because* of step 5. FK cascade behaviour was corrected in `d3b_fix_wallets_fk_cascade` so a purge does not cascade-delete the ledger.

### 6. Code Path

```
Settings → Delete account
  → rpc export_user_data()              (optional, user downloads JSON)
  → rpc request_account_deletion(reason, forfeit_dust)
      account frozen, schedules cancelled, executions cancelled
  ... up to 14 days ...  (user may call cancel_account_deletion())
  → cron hourly: purge_deleted_accounts()
      → skip while topup_executions.status='routing' or esim_orders pending/processing
      → de-identify + delete + net.http_post /purge-accounts
        → Edge Fn deletes auth.users
```

### 7. Edge Cases, Security Risks & Failure Handling

- **Money never blocks on a deletion.** The purge waits for `routing` executions rather than cancelling them, because a `routing` execution may already be with the provider. Cancelling it would risk delivering a top-up nobody paid for.
- **Dust policy.** Balance ≥ `WALLET_DUST_FORFEIT_USD` (1.00) → deletion is **refused** with `WALLET_BALANCE_EXCEEDS_DUST_LIMIT`; the user must spend or contact support. Balance in `(0, 1.00)` → the user must pass `p_forfeit_dust = true`, and `dust_forfeited` records the consent.
- **The freeze is immediate, the JWT is not.** `is_suspended` is set at request time but the *claim* only lands on the next token refresh (§0.2). The money RPCs re-read `profiles` directly, so a frozen account cannot spend even with a stale token.
- **Idempotency.** Every phase is guarded by the `status` predicate, so a re-run of `purge_deleted_accounts()` is a no-op on already-purged rows. The `retired_referral_codes` insert is `ON CONFLICT DO NOTHING`. The closing `wallet_transactions` row uses `reference_id = 'purge_<id>'`, which is unique per deletion.
- ⚠️ **The closing ledger row has no partial unique index.** `wallet_forfeit` / `wallet_settlement` are not covered by any `uq_wallet_transactions_*` index. If step 4 succeeded and step 5 failed (they are in the same transaction, so this needs a crash between loop iterations), a re-run would write a **second** closing row. The `UPDATE wallets SET balance = 0` in step 5 makes the second row a `0.00` no-op in practice, but the ledger would show a duplicate. Adding `uq_wallet_txns_purge_ref ON (reference_id) WHERE type IN ('wallet_forfeit','wallet_settlement')` would close it.
- **Auth deletion is asynchronous and unconfirmed.** `net.http_post` to `purge-accounts` is fire-and-forget; `account_deletions.auth_deleted_at` exists but nothing in `purge_deleted_accounts()` sets it. A `auth.users` row can survive a `purged` deletion record. Reconcile with `check_auth_user_exists()`.
- **`email_hash` not email.** The deletion record keeps only `sha256(email)`, so support can confirm "this address was deleted" without retaining the address.

---
# CATEGORY B — SIM Line & Carrier Activity Semantics

---

## Scenario B1 — Adding a Mobile Line & Linking the Carrier Deactivation Rule

### 1. Scenario Overview
The user enters a phone number, picks a country and carrier, and the line is inserted. The **carrier rule** (`carrier_rules`, exactly one row per carrier since H3b) is what turns a phone number into a protectable asset: it carries `inactivity_limit_days` (when the carrier deactivates), `activity_requirement` (what counts as activity), and the qualifying amount.

### 2. Tables & Columns Read

| Table | Columns | Filter | Index |
|---|---|---|---|
| `countries` | `id, iso_code, name, is_supported, flag_emoji` | `is_supported` | pk / uq `iso_code` |
| `carriers` | `id, name, logo_url, is_supported, fulfillment_gateway, default_refill_amount, gateway_phone_number` (Offline & Manual Top-Up Gateway Support) | `country_id = $1 AND is_supported` | fk index |
| `carrier_rules` | `id, inactivity_limit_days, grace_period_days, minimum_topup_amount, topup_validity_days, recommended_topup_amount, activity_requirement, validity_qualifying_topup_amount, refill_interval_days_override, balance_validity_days, inapp_pricing, rule_source_url, last_verified_at` | `carrier_id = $1` (**unique** since H3b) | uq `carrier_id` |
| `carrier_supplier_routing` (view) | `provider_code, is_routable, priority` | `carrier_id = $1 AND is_routable` | via `idx_carrier_provider_map_lookup` |
| `sim_lines` | `count(*)` | `user_id = auth.uid() AND plan_type='free'` — the free-tier check | `idx_sim_lines_user_id` |
| `carrier_self_service` | `app_name, android_url, ios_url, web_topup_url, ussd_code, verified_at` | `carrier_id = $1` — shown when automation is not the right answer |

Live counts: 21 countries, 67 carriers, **67 carrier rules** (one per carrier), 106 `carrier_provider_map` rows, 29 `carrier_self_service` rows.

### 3. Tables & Columns Written

```sql
INSERT INTO sim_lines (
  user_id, phone_number, nickname, avatar_icon,
  country_id, carrier_id, carrier_rule_id,     -- rule is pinned at insert time
  status, verification_status, plan_type, is_home_mode
) VALUES (auth.uid(), …, 'unverified', 'unverified', 'free', false);
```

Defaults applied by the table: `health_score = 100`, `protection_tier = 'standard'`, `plan_type = 'free'`, `protection_paused = false`, `requires_protection_at_home = false`.

Optionally, in the same flow:
- `scheduled_topups` — one row per `schedule_type` (`notify` or `refill_mini`), unique on `(sim_line_id, schedule_type)`.
- `line_activity_log` — a `line_added` row (client-written; non-financial event types only).
- `sim_line_rescue_policy` — only via `set_line_rescue_policy()` 🔒.

### 4. Functions, RPCs & Triggers Executed

| Order | Object | Effect |
|---|---|---|
| 1 | `check_free_lines_limit()` 🔓 BEFORE INSERT/UPDATE | raises if a second `plan_type='free'` line exists for the user |
| 2 | `trg_prevent_sim_line_plan_tampering` (BEFORE UPDATE only) | see B‑note below |
| 3 | `trg_update_line_health` BEFORE UPDATE OF `last_topup_at, validity_expires_at` → `update_line_health()` → `calculate_health_score()` 🔒 | |
| — | `list_refill_offers(p_sim_line_id)` 🔒 (`authenticated`) | the offers the user may pick from |
| — | `carrier_qualifying_topup_amount(carrier_id)` 🔒 | `COALESCE(validity_qualifying_topup_amount, minimum_topup_amount)` |
| — | `quote_plan_price(sim_line, plan, gateway, rule)` 🔒 (`authenticated`) | shown on the plan selector |

**Health score** (`calculate_health_score`) is a flat 0–100:

| Component | Points | Condition |
|---|---|---|
| Auto-refill armed | 50 | `EXISTS scheduled_topups WHERE sim_line_id = $1 AND status='active'` |
| Line active | 25 | `status = 'active'` (lifecycle status, **not** `verification_status`) |
| Recently refilled | 25 | `last_topup_at >= now() - 80 days` |

> [!WARNING]
> The 80-day recency window is **hard-coded** and carrier-agnostic. A carrier with a 30-day inactivity limit shows "healthy" 79 days after its last refill — i.e. 49 days after it died. This predates `refill_interval_days()` and should be re-based on the carrier's own window: `last_topup_at >= now() - refill_interval_days(...)`.

### 5. RLS & Grant Lockdown

| Table | Policies | Grants for `authenticated` |
|---|---|---|
| `sim_lines` | INSERT/DELETE own (`auth.uid()=user_id AND NOT is_user_suspended()`); SELECT own **or** accepted household member; UPDATE own **or** household `role='manager'`; plus `Allow power users full access` (`ALL`) | `SELECT, INSERT, DELETE` — **no UPDATE** (§0.1) |
| `carriers` | `Anyone can read carriers` (SELECT true) | `SELECT` only ⛔ |
| `carrier_rules` | `Anyone can read carrier rules` (SELECT true) | ⚠️ **full CRUD grant** |
| `carrier_self_service` | SELECT true for `authenticated` | `SELECT` only ⛔ |
| `countries` | SELECT true; UPDATE for power users | ⚠️ full CRUD grant |

> [!WARNING]
> ⚠️ **`carrier_rules` and `countries` still carry `INSERT/UPDATE/DELETE` for `anon` and `authenticated`.** `carrier_rules` has only a SELECT policy, so RLS blocks writes today — but this is the table that decides *how often we spend the user's money*, and it is one permissive policy away from being writable by any signed-in user. `admin_upsert_carrier_rule` was already revoked from `public` in `i8c`; the table grant should follow. Same for `carrier_ussd_suggestions`, `system_configs`, `support_tickets`, `ticket_messages`, `notifications`, `payment_methods`, `analytics_events`, `test_cases` — all hold blanket CRUD grants and rely on RLS alone.

### 6. Code Path

```
Add Line screen
  → select countries (is_supported)
  → select carriers where country_id
  → select carrier_rules where carrier_id       (drives the copy: "deactivates after N days")
  → rpc list_refill_offers / quote_plan_price   (plan selector)
  → insert sim_lines {…, carrier_rule_id}
      → trg check_free_lines_limit
  → (premium) rpc pay_plan_fee_from_wallet → rpc queue_premium_refill_executions   [see E1]
```

### 7. Edge Cases, Security Risks & Failure Handling

- **The rule is pinned, not looked up.** `sim_lines.carrier_rule_id` snapshots which rule applied at insert. Every consumer (`plan_price_net`, `queue_premium_refill_executions`, `compute_usage_forecasts`) uses the pattern `COALESCE(sl.carrier_rule_id, latest rule for sl.carrier_id)` so a line survives a rule being replaced.
- **Free-tier enforcement is a trigger, not a policy.** `check_free_lines_limit()` is `SECURITY INVOKER` and fires on INSERT *and* on any UPDATE that sets `plan_type='free'`. It counts `id <> NEW.id`, so an update of the existing free line is not self-blocking.
- **Race on the free-line limit.** Two concurrent inserts both see zero existing free lines and both succeed — the count is not serialised. A partial unique index `ON sim_lines (user_id) WHERE plan_type = 'free'` would make the invariant structural.
- **Duplicate lines** are prevented by `sim_lines_user_id_phone_number_key` — the same number can be added by two *different* users (a shared family handset), which is intentional.
- **`carrier_rules.last_verified_at` is the trust signal.** A rule with a stale or NULL `last_verified_at` is a rule nobody has confirmed against the operator's terms. `rule_source_url` exists so the claim is auditable.
- **`carrier_self_service` URLs ship NULL on purpose.** An unverified store link for a prepaid telecom app points at a clone as often as not; `verified_at IS NULL` means the client must render a *search*, not a link.

---

## Scenario B2 — Carrier Rule Semantics Resolution

### 1. Scenario Overview
Every pricing, queuing and forecasting path must answer three questions about a carrier: *can refilling keep this line alive?*, *how much must be sent for the carrier to count it?*, and *how often?* The answers come from three columns and two functions, and getting them wrong is the single most expensive class of bug in this system.

### 2. Tables & Columns Read

| Table | Columns | Consumed by |
|---|---|---|
| `carrier_rules` | `activity_requirement`, `validity_qualifying_topup_amount`, `minimum_topup_amount`, `inactivity_limit_days`, `refill_interval_days_override`, `grace_period_days`, `topup_validity_days`, `balance_validity_days`, `inapp_pricing` | `plan_price_net`, `queue_premium_refill_executions`, `compute_usage_forecasts`, `carrier_qualifying_topup_amount`, `run_auto_rescue` |
| `provider_offers` | `offer_code, source_price_type, effective_price_usd, source_price_min/max_usd, source_send_min/max, override_price_usd, source_refreshed_at` | `carrier_refill_offer` |
| `carrier_supplier_routing` (view) | `is_routable, priority` | `carrier_refill_offer` |

### 3. Tables & Columns Written
None — this scenario is pure resolution. Writes happen in the callers (D2, D4, E1).

### 4. Functions, RPCs & Triggers Executed

**`carrier_qualifying_topup_amount(carrier_id)`** 🔒 — the floor:

```sql
SELECT COALESCE(cr.validity_qualifying_topup_amount, cr.minimum_topup_amount)
FROM carrier_rules cr WHERE cr.carrier_id = p_carrier_id
ORDER BY cr.updated_at DESC NULLS LAST LIMIT 1;
```

**`carrier_refill_offer(carrier_id, min_usd)`** 🔒 — the shelf query. It raises the caller's request to the qualifying floor, then picks the cheapest **routable** offer that can reach it:

```sql
WITH floored AS (
  SELECT NULLIF(GREATEST(COALESCE(p_min_usd,0),
                COALESCE(carrier_qualifying_topup_amount(p_carrier_id),0)), 0) AS min_usd
)
SELECT o.provider_code, o.offer_code, o.source_price_type,
       CASE WHEN o.source_price_type='RANGE'
            THEN GREATEST(o.source_price_min_usd,
                          LEAST(o.source_price_max_usd, COALESCE(f.min_usd, o.source_price_min_usd)))
            ELSE o.effective_price_usd END        AS price_usd,
       o.source_price_usd                          AS supplier_cost_usd,
       <interpolated offer_value for RANGE>,
       (o.override_price_usd IS NOT NULL)          AS is_overridden,
       (o.source_refreshed_at < now() - '24h')     AS is_stale
FROM provider_offers o CROSS JOIN floored f
JOIN carrier_supplier_routing r ON r.carrier_id = o.carrier_id AND r.provider_code = o.provider_code
WHERE o.offer_kind='topup' AND o.carrier_id = $1 AND o.is_active AND r.is_routable
  AND (f.min_usd IS NULL
       OR (o.source_price_type='RANGE' AND o.source_price_max_usd >= f.min_usd)
       OR (o.source_price_type='FIXED' AND o.effective_price_usd  >= f.min_usd))
ORDER BY price_usd ASC, r.priority ASC, o.offer_code ASC
LIMIT 1;
```

`NULLIF(…, 0)` is load-bearing: it preserves "no constraint at all" as distinct from "a floor of zero".

**`is_routable`** is computed in the `carrier_supplier_routing` view as:
```sql
m.is_enabled AND sp.is_active AND sp.supports_topup AND COALESCE(pol.is_globally_enabled, false)
```
— four independent switches (carrier mapping, provider record, provider capability, supplier policy) all of which must be on. A missing `supplier_policy` row is `false`, i.e. **fail-closed**.

### 5. RLS & Grant Lockdown

- `provider_offers`, `carrier_provider_map`, `service_providers`, `supplier_policy` have **no grant at all** for `anon`/`authenticated`. Clients never see the shelf directly; they see it through `list_carrier_offers()` / `list_refill_offers()` / `carrier_refill_offer()`, all 🔒.
- `carrier_supplier_routing` is a view owned by the definer — `service_role` only.
- `trg_carrier_map_provider_sells_topup` (BEFORE INSERT/UPDATE on `carrier_provider_map`) 🔒 refuses to map a carrier to a provider whose `service_providers.supports_topup` is false — the dialect/capability invariant from K8.

### 6. Code Path

```
plan_price_net / queue_premium_refill_executions / ingest_offline_refill / run_auto_rescue
  → carrier_rules  (activity_requirement gate)
  → carrier_qualifying_topup_amount  (floor)
  → carrier_refill_offer(carrier, floor)
      → provider_offers ⋈ carrier_supplier_routing (is_routable)
  → refill_interval_days(inactivity_limit_days, override)  (cadence)
```

### 7. Edge Cases, Security Risks & Failure Handling

- **`usage_required` must be refused *before* charging.** `plan_price_net` raises `KS422` before any wallet call. Some carriers cannot be kept alive by refilling at all; discovering that on the RPC after the debit would mean a paid line that can never be protected.
- **`min_denomination` with an inconsistent rule is also `KS422`.** If `minimum_topup_amount < validity_qualifying_topup_amount`, the rule refills an amount the carrier will not count. Both `plan_price_net` and `queue_premium_refill_executions` refuse rather than silently topping up the wrong amount.
- ⚠️ **`carrier_qualifying_topup_amount` and `plan_price_net` resolve the rule differently.** The former takes `ORDER BY cr.updated_at DESC LIMIT 1` for the *carrier*; the latter prefers `sim_lines.carrier_rule_id`. Since H3b enforces one rule per carrier these agree today, but the divergence is a latent inconsistency if the one-rule constraint is ever relaxed.
- **Staleness is reported, not enforced, here.** `carrier_refill_offer` returns `is_stale` but still returns the row. `request_instant_refill` and `supplier_candidates` are the ones that *reject* offers older than 24 h. A premium queue built from a stale offer is priced from stale data — acceptable, because the queue is re-priced at execution.
- **RANGE offers are interpolated, not rounded.** `offer_value` for a RANGE is a linear interpolation between `send_min/send_max` — a floating conversion into the destination currency's minor unit. FX rounding error here means the recipient gets a fraction of a unit less than quoted; `source_send_divisor` (default 100) is what turns it back into a display amount.

---

## Scenario B3 — Home Mode / Travel Mode Dynamic Protection

### 1. Scenario Overview
Phase B5 split one boolean into three, because the old single flag was killing lines:

| Column | Meaning | Set by |
|---|---|---|
| `is_home_mode` | **Location fact only.** The user is currently in **this SIM's** country — not their profile's `home_country_code`. | geo detection (§6); no UI control writes it |
| `protection_paused` | **Intent.** Auto-refill protection is paused. | derived on entering home mode, *unless* the line opts out |
| `requires_protection_at_home` | This line must stay protected even at home (a resident's dormant second SIM). | user setting |

> [!IMPORTANT]
> The bug this fixed: *"A resident's dormant second SIM used to be permanently home → permanently unprotected → shown healthy while it died."* Location must never imply intent. `is_home_mode` alone no longer pauses anything.

### 2. Tables & Columns Read

| Table | Columns | Filter |
|---|---|---|
| `sim_lines` | `is_home_mode, protection_paused, requires_protection_at_home, country_id, status` | `user_id = auth.uid()` |
| `countries` | `iso_code` | to compare detected country against the line's home |
| `profiles` | `home_country_code, last_country` | geo baseline |
| `user_preferences` | `travel_mode_enabled` | user's global travel switch |
| `system_configs` | `GEO_FLAP_GUARD_HOURS` | anti-flapping window |
| `carrier_roaming_rates` | roaming products for the destination | feeds G5 (`roam_or_esim_quote`) |

### 3. Tables & Columns Written

```sql
UPDATE sim_lines SET protection_paused = <bool>, is_home_mode = <bool>, updated_at = now()
  WHERE id = $1;                       -- via RPC; the client has no UPDATE grant
UPDATE user_preferences SET travel_mode_enabled = <bool> WHERE user_id = auth.uid();
INSERT INTO line_activity_log (event_type = 'home_mode_on' | 'protection_paused' | …);
INSERT INTO notifications (category = 'geo_fence_triggered' | 'welcome_home_ready');
```

The backfill applied at migration time was `UPDATE sim_lines SET protection_paused = true WHERE is_home_mode` — every line then in home mode kept its old (implicitly unprotected) behaviour, so the split changed no live decision on the day it shipped.

### 4. Functions, RPCs & Triggers Executed

| Object | Notes |
|---|---|
| `detect-country` Edge Fn | rate bucket `detect_country`; writes `profiles.last_country` |
| `trg_update_line_health` → `update_line_health()` → `calculate_health_score()` | recomputes `health_score` on `last_topup_at` / `validity_expires_at` change |
| `run_auto_rescue()` 🔒 | **skips lines where `protection_paused = true`** — this is where the flag is honoured on the money path |
| `emit_carrier_self_service_advice()` 🔒 | nudges lines with no paid automation |
| `get_current_context()` 🔓 | returns the app's geo/currency context |

### 5. RLS & Grant Lockdown

- `sim_lines` UPDATE policies exist for own-row and household `manager`, but `authenticated` has **no UPDATE grant** (§0.1) — every home/travel toggle must be an RPC or a `service_role` write.
- `carrier_roaming_rates` — `SELECT` only for `authenticated`, filtered by `is_active`. Writes are `service_role`. `bundle_price_usd` is a **generated column** (`local_price / fx_rate_to_usd`) so no dollar figure is ever hand-typed.
- `user_preferences` — full own-row CRUD.

### 6. Code Path

```
App resume → Edge Fn detect-country → profiles.last_country
  → compare with each line's country_id            ← GeoController._syncLineModes
  → sets is_home_mode; sets protection_paused unless requires_protection_at_home
  → INSERT notifications('geo_fence_triggered' | 'welcome_home_ready')
Hourly → run_auto_rescue() skips protection_paused lines
```

> [!WARNING]
> **Line 2 of that path did not exist until 2026-08-12.** `detect-country` wrote
> `profiles.last_country` and posted a notification; *nothing* ever compared it to a line's
> `country_id`, and no code outside the UI wrote `is_home_mode`. The only writers were two
> switches on the Protection Console, so a line kept whatever the user last tapped. Found live: a
> Saudi (+966) line reading `is_home_mode = true, protection_paused = true` — and therefore skipped
> by `run_auto_rescue` — while its owner sat in Oman with a profile home country of Egypt. Three
> countries were in play and the code compared the wrong pair: `is_home_mode` means *the user is in
> **this SIM's** country*, never `profiles.home_country_code`.
>
> The sync now lives in `GeoController._syncLineModes` over the pure
> `resolveLineMode` (`lib/features/geo/domain/line_mode_resolver.dart`), and it:
> * runs on **every resolved detection**, not only `status = 'updated'` — `'noop'` (country
>   unchanged) and `'suppressed'` (flap guard) say nothing about whether the *lines* agree, and
>   keying on `'updated'` leaves a user who was already abroad stuck forever;
> * writes nothing when the location did not resolve. `detect-country` used to answer `"US"` for a
>   loopback/private IP or an ipapi.co outage, indistinguishable from a real US visitor; it now
>   returns `resolved:false` + `confidence`, and an unresolved answer updates neither
>   `last_country` nor any line;
> * is gated by `system_configs.GEO_LINE_MODE_SYNC_ENABLED`, **off by default** — enabling it
>   un-pauses protection for every line whose country the user is not in, which resumes schedules
>   and re-arms auto-rescue.
>
> Two adjacent defects went with it: entering travel mode stamped `last_topup_at = now()`
> ("treat as recent refill"), fabricating a top-up that fed `calculate_health_score()`; and the
> bulk freeze/resume compared each line against `profiles.home_country_code` rather than the
> detected country, with an `orElse` that handed a line with an unmatched `country_id` an
> arbitrary foreign country and froze it on that basis.

### 7. Edge Cases, Security Risks & Failure Handling

- **Flapping.** A user near a border, or on a VPN, can toggle home mode repeatedly. `GEO_FLAP_GUARD_HOURS` is the debounce; without it every crossing writes a `sim_lines` update, a `line_activity_log` row and a notification.
- **The dangerous default.** `requires_protection_at_home` defaults to `false`, so entering home mode pauses protection by default. That is correct for a traveller's foreign SIM and wrong for a resident's dormant SIM — which is exactly why the opt-out column exists and must be surfaced prominently in the UI.
- **Paused ≠ cancelled.** `protection_paused` does not cancel `scheduled_topups` or queued `topup_executions`; it only makes `run_auto_rescue` skip the line. A premium line with 5 pre-paid queued refills will still execute them while paused. If pausing is meant to stop *all* spend, the queue must be cancelled too — currently it is not. ⚠️
- **Health score ignores pausing.** A paused line still scores 50 points for having an active schedule. A paused-and-dying line can therefore still read as reasonably healthy.

---

## Scenario B4 — Deactivating / Removing a Mobile Line

### 1. Scenario Overview
Deleting a `sim_lines` row triggers a cascade that must cancel future spend, keep the financial record intact, and not violate its own foreign keys on the way out. Phase I6 exists entirely because it used to violate them.

### 2. Tables & Columns Read

| Table | Purpose |
|---|---|
| `sim_lines` | the row being deleted; RLS `Users can delete own sim lines` |
| `scheduled_topups` | rows cascading by `sim_line_id` |
| `topup_executions` | rows with `status IN ('pending','pending_payment')` under those schedules |
| `sim_lines` (again, `EXISTS` probe) | inside every cascade trigger — see below |

### 3. Tables & Columns Written

| Order | Table | Operation |
|---|---|---|
| 1 | `topup_executions` | `status='cancelled', completed_at=now()` for `pending`/`pending_payment` under the deleted schedules |
| 2 | `scheduled_topups` | deleted by FK cascade |
| 3 | `line_activity_log` | **suppressed** — see the I6 guard |
| 4 | `sim_lines` | row deleted |
| 5 | `sim_line_rescue_policy`, `sim_line_usage_forecast`, `offer_price_watches (origin='auto')` | cascade / next nightly sync |

Financial rows are **not** deleted: `topup_executions` and `wallet_transactions` keep `sim_line_id` pointing at a now-absent line, which is why `trg_fn_log_topup_activity` must check for existence.

### 4. Functions, RPCs & Triggers Executed

Fire order on `DELETE FROM sim_lines`:

```
BEFORE DELETE ON scheduled_topups  (cascade)
  → trg_cancel_executions_on_schedule_delete → trg_fn_cancel_executions_on_schedule_delete() 🔒
       UPDATE topup_executions SET status='cancelled', completed_at=now()
       WHERE scheduled_topup_id = OLD.id AND status IN ('pending','pending_payment')
         → AFTER UPDATE OF status ON topup_executions
             → trg_topup_executions_activity → trg_fn_log_topup_activity() 🔒
                  ⇢ RETURNS EARLY: sim_line_id no longer exists in sim_lines
             → trg_notify_topup_result → trg_fn_notify_topup_result() 🔒
             → trg_supplier_failover  (no-op: status is 'cancelled', not 'failed')
             → trigger_update_sim_line_last_topup (no-op: status is not 'success')
  → trg_sync_health_on_topup → trg_scheduled_topup_health_sync() 🔒
       UPDATE sim_lines SET updated_at=now() ONLY IF EXISTS(sim_lines WHERE id = OLD.sim_line_id)
```

> [!IMPORTANT]
> **The I6 guard.** Three cascade triggers begin with an `EXISTS (SELECT 1 FROM sim_lines WHERE id = …)` probe:
> ```sql
> IF NEW.sim_line_id IS NOT NULL AND NOT EXISTS (
>      SELECT 1 FROM public.sim_lines WHERE id = NEW.sim_line_id) THEN
>   RETURN NEW;   -- the line is mid-delete; do not write a child row
> END IF;
> ```
> Without it, cancelling an execution during a line delete inserts into `line_activity_log`, which violates `line_activity_log_sim_line_id_fkey` against the row being deleted in the outer statement — the delete fails with a foreign-key error the user cannot act on.

### 5. RLS & Grant Lockdown

| Table | Delete path |
|---|---|
| `sim_lines` | `Users can delete own sim lines` — `auth.uid()=user_id AND NOT is_user_suspended()`; `DELETE` **is** granted |
| `scheduled_topups` | `Users can manage own scheduled topups` (ALL) + household-manager ALL; `DELETE` granted |
| `topup_executions` | `SELECT` only ⛔ — cancellation happens **only** through triggers or `cancel_topup_execution()` 🔒 |
| `line_activity_log` | users may delete **non-financial** events only: `event_type <> ALL ('topup_requested','topup_success','topup_failed','topup_refunded','topup_cancelled','topup_retry_queued')` |

> [!NOTE]
> The `line_activity_log` DELETE policy is the model for immutable audit inside a user-owned table: the user owns the row and can tidy their timeline, but the six financial event types are carved out in the policy predicate itself, not in application code.

### 6. Code Path

```
Line detail → Delete
  → (guard) DestructiveActionGuard, NOT PaymentAuthGuard
  → delete sim_lines where id = $1
      → FK cascade scheduled_topups → cancel pending executions → (child writes suppressed)
  → realtime: lines controller re-reads
```

> [!WARNING]
> Use `DestructiveActionGuard` for deletion, not `PaymentAuthGuard`. The payment guard has a 60-second grace window, so a delete seconds after a refill would prompt for nothing at all.

### 7. Edge Cases, Security Risks & Failure Handling

- **A `routing` execution is not cancelled.** `trg_fn_cancel_executions_on_schedule_delete` only touches `pending`/`pending_payment`. An execution already handed to a provider keeps running and will settle against a deleted line — deliberately, since the money has left. `trg_fn_log_topup_activity` will then silently skip its log row (the EXISTS guard), so **the settlement of an in-flight refill for a deleted line leaves no line-activity trace**. The `topup_executions` row itself survives.
- **Pre-paid premium refunds are not automatic.** Deleting a premium line with 5 queued refills cancels the queue but issues **no refund** for the unused portion of the annual fee. That is currently a support action (`admin_adjust_wallet`), not a database behaviour.
- **Idempotency.** Every cancel is `WHERE status IN ('pending','pending_payment')`, so replays are no-ops.
- **Deadlock shape to watch.** The delete takes locks in the order `scheduled_topups → topup_executions → sim_lines`, while `update_sim_line_last_topup_at()` (on a successful refill) takes `topup_executions → sim_lines → scheduled_topups`. A delete racing a settlement on the same line is a lock-order inversion. It has not been observed at current volume, but it is the most likely first deadlock in this schema.
- **Orphaned auto price watches.** `offer_price_watches` rows with `origin='auto'` are reconciled to active lines only by the nightly `sync_auto_price_watches()`; between the delete and 02:40 UTC the user can still receive a price-drop alert for a carrier they no longer track.

---
# CATEGORY C — Wallet Transactions, FX Engine & Idempotency

---

## Scenario C1 — Depositing Funds via PayPal (Quote → Approve → Capture → Credit)

### 1. Scenario Overview
A deposit is a **four-hop asynchronous flow** across three Edge Functions and two PayPal webhooks. The database's job is to (a) record the intended amount before the user leaves for PayPal, (b) credit exactly once when the capture webhook lands, and (c) make a webhook retry a no-op.

`paypal_orders.kind` ∈ `{deposit, plan}` — the same rail carries wallet top-ups and direct plan purchases, and the webhook branches on it.

### 2. Tables & Columns Read

| Step | Table | Columns | Filter |
|---|---|---|---|
| create-order | `system_configs` | `PAYPAL_MIN_DEPOSIT_USD`, `PAYPAL_MAX_DEPOSIT_USD` | bounds check |
| create-order | `profiles` | `id, is_suspended` | caller |
| create-order | *(guard)* `device_money_events`, `user_devices`, `payment_methods`, `paypal_orders` | via `device_velocity` | §0.3 |
| webhook | `paypal_orders` | `amount_usd, user_id, kind, sim_line_id, status` | `order_id = <supplementary_data.related_ids.order_id>` — **`paypal_orders_pkey`** |
| credit | `wallets` | `id, balance` | `user_id = $1` **`FOR UPDATE`** |

### 3. Tables & Columns Written

| Hop | Table | Write |
|---|---|---|
| 1. quote | `paypal_orders` | `INSERT (order_id, user_id, kind, plan, sim_line_id, amount_usd, status='created')` |
| 1. guard | `device_money_events` | one row, `action='deposit_order'`, later back-filled with `reference_id = order_id` via `attach_device_money_reference()` |
| 2. approved | `paypal_orders` | `status = 'approved'` → server-side capture is fired |
| 2. capture fail | `paypal_orders` | `status = 'failed'` + `system_alerts('paypal_server_capture_failed')` |
| 3. captured (`kind='deposit'`) | `wallets` | `balance += gross`, `total_deposited += gross` |
| 3. captured (`kind='deposit'`) | `wallet_transactions` | `type='deposit'`, `reference_id = 'paypal_' \|\| capture_id`, `metadata.paypal_capture_id` |
| 3. captured (`kind='plan'`) | `plan_payments` | `INSERT (capture_id, order_id, kind='plan', gross_usd, paypal_fee_usd, net_usd, sim_line_id, metadata)` |
| 4. trigger | `notifications` | `trg_notify_wallet_credit` fires **only** for `type='deposit'` → category `wallet_credit`, `delivered_via = {push}` |
| 4. trigger | `sim_lines`, `referral_points` | `trg_apply_plan_tier_on_payment`, `trg_award_referral_paypal` (see E1) |

### 4. Functions, RPCs & Triggers Executed

| Object | Type | Notes |
|---|---|---|
| `guard_money_action('deposit_order', …)` 🔒 | RPC | §0.3 |
| `attach_device_money_reference(event_id, order_id)` 🔒 | RPC | links the risk event to the PayPal order so `device_velocity.failed_captures` can join |
| `credit_wallet_for_deposit(user, amount, description, 'paypal_<capture>', metadata)` 🔒 | RPC | `service_role` only |
| `trg_notify_wallet_credit` (AFTER INSERT ON `wallet_transactions` WHEN `type='deposit'`) | trigger | inserts the notification, which fires §0.8 |
| `trg_apply_plan_tier_on_payment` (AFTER INSERT ON `plan_payments`) | trigger | applies the tier |
| `trg_award_referral_paypal` (AFTER INSERT ON `plan_payments` WHEN `kind='plan' AND sim_line_id IS NOT NULL`) | trigger | referral points |

### 5. RLS & Grant Lockdown

| Table | Client access |
|---|---|
| `paypal_orders` | `SELECT` own (two duplicate policies: `paypal_orders_select_own` and `select_own_paypal_orders` — identical predicates, harmless but should be de-duplicated) ⛔ writes |
| `plan_payments` | `SELECT` own only ⛔ |
| `wallets` / `wallet_transactions` | `SELECT` own only ⛔ |

> [!IMPORTANT]
> **Nothing on the deposit path is reachable from a client.** `credit_wallet_for_deposit` is `service_role`-EXECUTE only, `paypal_orders` and `wallet_transactions` are write-revoked, and the webhook authenticates with the service key. The client's entire role is: ask for an order, go to PayPal, come back and poll `wallets`.

### 6. Code Path

```
Flutter  → Edge Fn create-paypal-order  {amount, kind, sim_line_id?, device_id}
              App Check → guard_money_action → INSERT paypal_orders(status='created')
              → PayPal /v2/checkout/orders  → approve_url
           (user approves on PayPal)
PayPal  → Edge Fn paypal-webhook  CHECKOUT.ORDER.APPROVED
              UPDATE paypal_orders status='approved'
              → PayPal /v2/checkout/orders/{id}/capture      (server-side capture)
PayPal  → Edge Fn paypal-webhook  PAYMENT.CAPTURE.COMPLETED
              assert currency = USD
              assert gross == paypal_orders.amount_usd       (else system_alert, stop)
              kind='deposit' → rpc credit_wallet_for_deposit
              kind='plan'    → INSERT plan_payments
              else           → system_alert('paypal_unhandled_kind'), not credited
```

### 7. Edge Cases, Security Risks & Failure Handling

> [!WARNING]
> **"Payment Confirmed" is not "balance credited".** The two events are *different webhooks*. `CHECKOUT.ORDER.APPROVED` can arrive up to ~11 seconds before `PAYMENT.CAPTURE.COMPLETED` lands and the balance rises. Any flow that sleeps a fixed interval and then assumes funds are present will occasionally create a paid artefact for free. **Wait on the balance (or on the `wallet_transactions` row), never on a timer.**

- **Idempotency is structural, not procedural.** `uq_wallet_transactions_paypal_capture` on `reference_id WHERE type='deposit' AND reference_id LIKE 'paypal_%'` means a duplicate `PAYMENT.CAPTURE.COMPLETED` raises `unique_violation` **after** the `UPDATE wallets`, and the whole function rolls back — balance included. The webhook detects the duplicate error code and logs "already credited — webhook retry, ignoring". `plan_payments.capture_id` has the same protection via `plan_payments_capture_id_key`.
- **Amount tampering.** The webhook asserts the captured gross equals `paypal_orders.amount_usd` before crediting; a mismatch writes `system_alerts` and does **not** credit. This is the defence against a modified approve URL.
- **Currency.** A non-USD capture is refused outright (`system_alert`, not credited) — the ledger is USD-only and there is no conversion path on ingest.
- **Unknown `custom_id`.** `parseCustomId` accepts `{u,k,s}` JSON or a bare UUID; anything else yields `userId = null` and the capture is alerted, not credited. Money then sits at PayPal until reconciled by hand.
- **`kind` with no handler** → `paypal_unhandled_kind` alert. This is the fail-closed branch that catches a future `kind` shipped in the client before the webhook knows it.
- ⚠️ **PayPal fee absorption.** Buying a plan through a *deposit* means KeepSIMs absorbs the gateway cut, because the deposit credits the net while the plan price was quoted gross. J8b fixed the direct path by making the fallback a `kind:'plan'` charge; `plan_payments.paypal_fee_usd` / `net_usd` exist so the difference is visible per capture.
- **Deadlock avoidance.** `credit_wallet_for_deposit` takes exactly one row lock (`wallets`) and holds it for the duration. Because every wallet writer locks the same row first and in the same order, wallet operations cannot deadlock against each other.

---

## Scenario C2 — Strict Wallet Credit / Debit under Financial Lockdown

### 1. Scenario Overview
Every balance change in the system is one of three functions (§0.5). This scenario documents their internals, the two privilege-guard styles, and the household hook that lives inside the debit.

### 2. Tables & Columns Read

| Function | Reads |
|---|---|
| all three | `wallets (id, balance)` `WHERE user_id = $1` **`FOR UPDATE`** |
| `debit_wallet_for_topup` | `topup_executions.acting_user_id` when `reference_id ~ '^exec_<uuid>$'` |
| `debit_wallet_for_topup` | `household_spend_check(payer, actor, amount, exclude_execution_id)` → `household_members`, `topup_executions` |
| `credit_wallet_for_refund` | `request.jwt.claims ->> 'role'` |

### 3. Tables & Columns Written

```sql
UPDATE wallets SET balance = <after>,
       total_deposited = total_deposited + amt      -- credit_wallet_for_deposit
    or total_spent     = total_spent     + amt      -- debit_wallet_for_topup
    or total_spent     = GREATEST(0, total_spent - amt)  -- credit_wallet_for_refund
 WHERE id = <locked wallet>;

INSERT INTO wallet_transactions (
  wallet_id, user_id, type, amount, balance_before, balance_after,
  description, reference_id, sim_line_id, status, metadata)
VALUES (…, 'completed', <metadata>);
```

When a household manager spends the owner's money, `debit_wallet_for_topup` stamps:

```json
{"spent_by": "<actor uuid>", "spent_for_owner": "<payer uuid>", "household": true}
```

### 4. Functions, RPCs & Triggers Executed

The debit's full order of operations:

```
1. privilege guard      (stack-depth: refuse a direct PostgREST call)     → KS403
2. amount > 0
3. if reference_id matches 'exec_<uuid>' → read topup_executions.acting_user_id
4. if acting_user_id <> payer → household_spend_check(...)                → KS402 on refusal
5. SELECT ... FROM wallets FOR UPDATE                                     ← concurrency boundary
6. balance sufficiency                                                    → 'Insufficient wallet balance'
7. UPDATE wallets
8. INSERT wallet_transactions                                             → unique_violation = idempotent replay
```

Triggers that fire off the ledger insert:

| Trigger | Condition | Effect |
|---|---|---|
| `trg_notify_wallet_credit` | `type='deposit'` | notification `wallet_credit` |
| `trg_award_referral_wallet` | `type='plan_fee_debit' AND sim_line_id IS NOT NULL` | `trg_fn_award_referral_points()` 🔒 |

### 5. RLS & Grant Lockdown

> [!IMPORTANT]
> **Two guard styles, deliberately different.**
> ```sql
> -- HARD: credit_wallet_for_refund, purge_deleted_accounts, run_auto_rescue
> IF jwt.role IS DISTINCT FROM 'service_role' THEN RAISE KS403;
>
> -- STACK-DEPTH: debit_wallet_for_topup, consume_rate_limit, enforce_rate_limit
> GET DIAGNOSTICS v_ctx = PG_CONTEXT;
> IF array_length(string_to_array(v_ctx, E'\n'), 1) < 2 THEN RAISE KS403;
> ```
> The hard guard means "no user-facing path may ever reach this". The stack-depth guard means "only reachable *through* another SECURITY DEFINER function" — which is how `pay_plan_fee_from_wallet` (granted to `authenticated`) legitimately debits a wallet while `/rpc/debit_wallet_for_topup` from a client is refused.

- `credit_wallet(user, amount, type, description, reference_id)` 🔒 is the **legacy** general-purpose credit. It has **no privilege guard and no idempotency index** — it is `service_role`-EXECUTE only, which is the only thing protecting it. Prefer the two specific credit functions; treat `credit_wallet` as deprecated surface. ⚠️
- `wallets` grants `authenticated` only `SELECT` — but there **is** an UPDATE policy `Users can update own wallet auto-fund settings`. As with `sim_lines`, the policy is unreachable without an UPDATE grant, so auto-fund settings currently cannot be changed by a client. ⚠️

### 6. Code Path

```
authenticated RPC (pay_plan_fee_from_wallet | request_esim_purchase | request_instant_refill worker)
   → debit_wallet_for_topup   [stack depth ≥ 2 ⇒ allowed]
        → household_spend_check (only if acting_user_id set)
        → wallets FOR UPDATE → UPDATE → INSERT wallet_transactions
service_role only
   → credit_wallet_for_deposit  (PayPal webhook)
   → credit_wallet_for_refund   (worker refund, admin_fail_refill)
```

### 7. Edge Cases, Security Risks & Failure Handling

- **Concurrency.** `FOR UPDATE` on the wallet row serialises all balance changes per user. Two simultaneous refills cannot both read the same `balance_before`. The trade-off is that a slow provider call *inside* the same transaction would hold the lock — which is why provider calls happen **outside** the debit, in the worker.
- **Insufficient balance raises, and only that raises,** in `pay_plan_fee_from_wallet` (§0.3 warning).
- ⚠️ **`wallet_reconciliation` is out of date.** The view sums only `deposit, refund, referral_credit, auto_fund` as credits and `topup_debit, welcome_home_debit` as debits. It **ignores** `plan_fee_debit`, `esim_purchase_debit`, `gift_sent`, `gift_received`, `admin_adjustment`, `wallet_forfeit`, `wallet_settlement`. Any account that has bought a plan or an eSIM will show non-zero `drift` that is not real drift. Fix before using it as an alarm: `plan_fee_debit` and `esim_purchase_debit` alone account for 12+ live rows.
- **`total_spent` clamp.** `credit_wallet_for_refund` uses `GREATEST(0, total_spent - amount)`, so a refund larger than lifetime spend cannot drive the counter negative — but it *does* silently lose the excess. `total_spent` is a display counter, not a ledger; the ledger is `wallet_transactions`.
- **Reference-id shape is load-bearing.** `debit_wallet_for_topup` recognises household spend only when `reference_id` matches `^exec_<uuid>$`. A caller that passes a differently-shaped reference silently skips the household cap check. Any new debit path must either use the `exec_` form or perform its own `household_spend_check`.

---

## Scenario C3 — Multi-Currency Display & FX Refresh

### 1. Scenario Overview
FX in KeepSIMs is **render-time only**. Every charge, cap, ledger row and offer price is USD. `fx_rates` exists so a user in Muscat sees `ر.ع.` next to a number — nothing more.

> [!WARNING]
> `fx_rates` must **never** be read on a money path. `local = usd × usd_to_local`, one direction, at render time. There is no reverse conversion and no FX-denominated storage anywhere in the schema.

### 2. Tables & Columns Read

`get_fx_display_context()` 🔓 (`authenticated`) — one call per app session:

| Table | Columns | Filter |
|---|---|---|
| `system_configs` | `FX_DISPLAY_ENABLED` (default true), `FX_MAX_AGE_HOURS` (default 72) | |
| `profiles` | `preferred_currency` | `id = auth.uid()`, upper-cased, default `'USD'` |
| `fx_rates` | `currency_code, display_name, symbol, decimal_digits, usd_to_local, rate_as_of` | `is_enabled OR currency_code='USD'` — 15 rows live |

Returns `{enabled, currency, requested_currency, rate, symbol, decimal_digits, as_of, age_hours, stale, fallback_reason, max_age_hours, available[]}`.

**Fallback ladder** — any of these returns `currency='USD', rate=1` with a named reason:

| `fallback_reason` | Cause |
|---|---|
| `disabled` | `FX_DISPLAY_ENABLED = false` |
| `base` | user's preference is already USD |
| `unknown_currency` | no enabled `fx_rates` row for the preference |
| `stale` | `age_hours > FX_MAX_AGE_HOURS` |

### 3. Tables & Columns Written

`refresh_fx_rates(p_rates jsonb, p_as_of, p_source)` 🔓 (`service_role` EXECUTE):

```sql
UPDATE fx_rates SET usd_to_local = <new>, rate_as_of = p_as_of, rate_source = p_source
 WHERE currency_code = <code>;
-- then, always:
INSERT INTO system_configs (config_key, config_value, updated_at)
VALUES ('FX_LAST_REFRESH_AT', to_jsonb(now())::text, now())
ON CONFLICT (config_key) DO UPDATE SET config_value = EXCLUDED.config_value, updated_at = now();
```

Returns a per-currency audit: `{as_of, source, applied_count, refused_count, skipped_count, applied[], refused[], skipped[]}`.

### 4. Functions, RPCs & Triggers Executed

| Object | Role |
|---|---|
| `kick_fx_refresh()` 🔓 (`service_role`) | daily 03:10 cron; `net.http_post` → `/functions/v1/refresh-fx-rates` with the Vault shared secret |
| `refresh-fx-rates` Edge Fn | fetches quotes, calls `refresh_fx_rates(rates, as_of, source)` |
| `refresh_fx_rates()` | per-currency loop, skip / apply / refuse |
| **`tr_fx_rate_sanity()`** 🔓 BEFORE UPDATE ON `fx_rates` | the circuit breaker |
| `get_fx_display_context()` 🔓 | client read |
| `fx_rates_for_costing` (view) | separate, stricter lens used for *costing* provenance, not display |

**The sanity trigger** — the most important 20 lines in this scenario:

```sql
NEW.updated_at := now();
IF NEW.rate_source = 'manual' THEN RETURN NEW; END IF;   -- deliberate operator override
IF OLD.rate_source = 'seed'   THEN RETURN NEW; END IF;   -- first real quote replaces a seed
IF NEW.usd_to_local = OLD.usd_to_local THEN RETURN NEW; END IF;
v_move_pct := abs(NEW.usd_to_local - OLD.usd_to_local) / OLD.usd_to_local * 100;
IF v_move_pct > COALESCE(FX_MAX_MOVE_PERCENT, 25) THEN
  RAISE EXCEPTION 'KS460: FX rate for % moved % pct … Refusing …' USING ERRCODE='check_violation';
END IF;
```

A refused currency is caught by the per-currency `EXCEPTION` block in `refresh_fx_rates` and lands in the `refused[]` array — **the other currencies still apply**. The stale rate then trips the `stale` fallback in `get_fx_display_context`, so the user sees USD rather than a wrong local number.

`refresh_fx_rates` also refuses the whole payload on two conditions: not a jsonb object (`KS462`) and an absent or >1 h future `as_of` (`KS463`). And it skips any currency whose stored quote is newer than the payload (`p_as_of <= rec.rate_as_of AND rate_source <> 'seed'`) — **out-of-order refreshes cannot regress a rate**.

### 5. RLS & Grant Lockdown

| Table | Policy | Grant |
|---|---|---|
| `fx_rates` | `Anyone signed in may read enabled FX rates` — `is_enabled AND NOT is_user_suspended()` | `SELECT` only for `authenticated` ⛔ |
| `fx_rates_for_costing` (view) | — | `service_role` only |
| `system_configs.FX_LAST_REFRESH_AT` | `system_config_meta.is_readonly = true` | an admin editing it would be lying to the code that reads it |

### 6. Code Path

```
03:10 cron → kick_fx_refresh() → net.http_post /functions/v1/refresh-fx-rates
   → Edge Fn fetches quotes → rpc refresh_fx_rates({USD→local map}, as_of, source)
       per currency: skip (absent | older) | apply | refuse (tr_fx_rate_sanity)
   → system_configs.FX_LAST_REFRESH_AT = now()
App start → rpc get_fx_display_context() → {rate, symbol, decimal_digits, stale, fallback_reason}
   → client renders local = usd * rate   (never the other way)
```

### 7. Edge Cases, Security Risks & Failure Handling

- **Rounding.** Display conversion is a single multiply, rounded to `decimal_digits`. Because it never feeds back into a charge, rounding error is cosmetic by construction. This is the entire reason FX is display-only.
- **Pegged currencies.** `fx_rates_for_costing` treats `rate_source='peg'` specially: a peg is allowed to be old, but not older than `FX_PEG_MAX_AGE_DAYS` (90), after which `unusable_reason = 'pegged rate has not been reviewed in months'`. OMR (added in K7) is a pegged rate.
- **The 25 % band can block a real devaluation.** A genuine currency collapse looks exactly like bad data. The escape hatch is `rate_source = 'manual'`, which bypasses the trigger — a deliberate, auditable human act.
- **Stale is safe, wrong is not.** The design chooses "show USD" over "show a stale local number". `age_hours` and `fallback_reason` are returned to the client so the UI can explain itself rather than silently switching currency.
- **A failed refresh is invisible without monitoring.** `kick_fx_refresh` is fire-and-forget; if the Edge Function is down, nothing raises. `FX_LAST_REFRESH_AT` is the only signal — alert on it exceeding `FX_MAX_AGE_HOURS`.
- **`refresh_fx_rates` is SECURITY INVOKER.** It is protected only by its `service_role` EXECUTE grant — which is sufficient, but note it does **not** carry the internal `KS403` role guard that the wallet functions do.

---

## Scenario C4 — Admin Gifting, Support Credits & Peer Transfers

### 1. Scenario Overview
Three distinct paths put money into a wallet without a payment: **support adjustment** (`admin_adjust_wallet`), **peer gift** (`transfer_wallet_credit`), and **refund** (`credit_wallet_for_refund`). They differ in who may call them, what caps apply, and how they are audited.

### 2. Tables & Columns Read

**`admin_adjust_wallet(p_user_id, p_amount, p_reason)`** 🔒 (`authenticated`, gated by `assert_admin()`):

| Table | Columns | Purpose |
|---|---|---|
| JWT claims | `role`, `auth.uid()` | `assert_admin()` |
| `profiles` | `is_power_user` (via JWT), `email` of the actor | authorisation + audit |
| `system_configs` | `ADMIN_WALLET_ADJUST_MAX_USD` (default 50) | hard cap |
| `wallets` | `id, balance` `FOR UPDATE` | target |

**`transfer_wallet_credit(p_recipient_email, p_amount, p_reference_id, p_note, p_device_id)`** 🔒 (`authenticated`):

| Table | Purpose |
|---|---|
| `wallet_transactions` | idempotency probe on `(reference_id, type='gift_sent', user_id=sender)` |
| `system_configs` | `GIFT_MIN_USD` (1.00), `GIFT_MAX_USD` (100.00), `GIFT_DAILY_MAX_USD` (250.00) |
| `profiles` | resolve recipient by email; reject suspended sender/recipient |
| `wallet_transactions` | sum of today's `gift_sent` for the daily cap |
| `wallets` | both wallets, locked |

### 3. Tables & Columns Written

| Path | Writes |
|---|---|
| `admin_adjust_wallet` | `wallets.balance`; `wallet_transactions (type='admin_adjustment', amount = abs(x), reference_id = 'adminadj_<uuid-hex>', metadata{adjusted_by, adjusted_by_email, direction, reason})`; `admin_audit_log` via `admin_log('wallet.adjust','user',…)`; `notifications (category='wallet_credit')` |
| `transfer_wallet_credit` | two ledger rows — `gift_sent` (sender, debit) and `gift_received` (recipient, credit) — plus both `wallets.balance`; `notifications` for the recipient |
| `credit_wallet_for_refund` | `wallets.balance`, `total_spent` clamp; `wallet_transactions (type = COALESCE(p_type,'refund'))` |

> [!NOTE]
> **Direction is carried by `balance_before`/`balance_after`, never by a negative amount.** `wallet_transactions.amount` has a positive CHECK, so `admin_adjust_wallet` stores `abs(amount)` and records `direction` in metadata. Every reader of the ledger must derive sign from the balance pair, not from `amount`.

### 4. Functions, RPCs & Triggers Executed

| Object | Guard |
|---|---|
| `assert_admin()` 🔓 | `service_role` ⇒ pass; else requires `auth.uid()` **and** `is_power_user()` **and** `NOT is_user_suspended()`; raises `KS460` |
| `admin_adjust_wallet` 🔒 | reason ≥ 5 chars (`KS464`); amount ≠ 0 (`KS466`); `abs(amount) ≤ ADMIN_WALLET_ADJUST_MAX_USD` (`KS466`); **cannot adjust own wallet** (`KS466`); resulting balance ≥ 0 (`KS466`) |
| `admin_log(action, target_type, target_id, before, after, note)` 🔒 | `service_role` EXECUTE only — reachable **only** from inside another admin RPC; actor comes from the JWT, never from a parameter |
| `transfer_wallet_credit` 🔒 | rate bucket `gift_credit`; `guard_money_action('gift', …)`; min/max/daily caps; suspension checks both sides |
| `credit_wallet_for_refund` 🔒 | hard `service_role` guard |

### 5. RLS & Grant Lockdown

- `admin_audit_log` — **deny-all** (RLS on, zero policies), no grant to `authenticated`. Read only through `admin_list_audit()` 🔒.
- Every `admin_*` function is `SECURITY DEFINER` **and** granted to `authenticated`. The privilege boundary is therefore entirely `assert_admin()` — which reads `is_power_user()` from the **JWT**, and `is_power_user` is `SECURITY INVOKER` (changed in `f4b`) precisely so it evaluates the *caller's* token even when called from inside a definer function.

> [!IMPORTANT]
> **The admin surface is `authenticated`-callable by design.** There is no separate admin role in Postgres. `keep_sims_admin` is a desktop app signing in as a normal user whose `app_metadata.is_power_user = true`. Every admin write therefore goes through an `admin_*` RPC, never a table — because the tables give `authenticated` nothing.

- `is_power_user` is granted to `anon` as well; it returns `false` for an anonymous JWT, so this is safe, but it means the function is publicly probeable.

### 6. Code Path

```
Admin desktop → rpc admin_adjust_wallet(user, ±amount, reason)
   assert_admin() → cap checks → wallets FOR UPDATE → UPDATE
   → INSERT wallet_transactions(type='admin_adjustment')
   → admin_log('wallet.adjust', …)            → admin_audit_log
   → INSERT notifications(category='wallet_credit')  → §0.8 dispatch

User → rpc transfer_wallet_credit(recipient_email, amount, ref, note, device_id)
   idempotency probe → caps → guard_money_action → two ledger rows → notification
```

### 7. Edge Cases, Security Risks & Failure Handling

- **Self-adjustment is blocked.** `p_user_id = v_actor` raises. Combined with the `ADMIN_WALLET_ADJUST_MAX_USD` cap (50) and the mandatory reason, a compromised admin session can leak at most $50 per call and every call is attributable.
- **The reason is not optional and not cosmetic.** It is stored in the ledger description (`left(reason,160)`), in the metadata, and in `admin_audit_log`. `KS464` if shorter than 5 characters.
- **`admin_adjustment` has no idempotency index** — but it also has no external retry path (it is a synchronous admin click, and `reference_id` is a fresh UUID per call). A double-click creates two rows; that is visible in the audit log and correctable, which is the accepted trade-off.
- **Gift idempotency** is on `(reference_id, type='gift_sent', user_id)`, and a repeat returns `{already_sent:true}` with the original transaction — a safe client retry.
- **Gift caps stack**: per-transaction min/max **and** a rolling daily total. Both read `system_configs` at call time, so tightening them is immediate.
- ⚠️ **Two-sided gift atomicity.** `transfer_wallet_credit` writes the sender debit and the recipient credit in one transaction, so it is atomic — but it locks two wallet rows. Lock order is sender-then-recipient; two users gifting each other simultaneously is a textbook deadlock. Ordering the two `FOR UPDATE`s by `wallet_id` would remove the possibility entirely.
- **Refund path.** `credit_wallet_for_refund` accepts `p_type` so a refund can be typed as `refund` or `esim_purchase_refund` — each has its own unique index, so a worker retry after a provider failure is idempotent per type.

---
# CATEGORY D — Auto-Refill Engine, Forecasting & Auto-Rescue

---

## Scenario D1 — Depletion Forecasting

### 1. Scenario Overview
Nightly at **02:20 UTC**, `refresh_usage_forecasts()` 🔒 runs three phases in one transaction and returns a receipt:

```sql
v_samples   := snapshot_esim_usage();          -- today's eSIM data-remaining sample
v_forecasts := compute_usage_forecasts();      -- one row per active SIM line + active eSIM
v_alerts    := emit_forecast_depletion_alerts();
RETURN jsonb_build_object('esim_samples', …, 'forecasts', …, 'alerts', …, 'ran_at', NOW());
```

### 2. Tables & Columns Read

**Phase 1 — `snapshot_esim_usage()`**: `user_esims (id, data_remaining_mb, data_total_mb)` where `status='active' AND data_remaining_mb IS NOT NULL`.

**Phase 2 — `compute_usage_forecasts()`**, SIM-line branch, five CTEs:

| CTE | Source | Logic |
|---|---|---|
| `ok_exec` | `topup_executions` | `status IN ('success','completed')` and `COALESCE(completed_at, execution_time, executed_at, created_at) >= now() - 365 days` |
| `gaps` | `ok_exec` | `LAG()` window per line → inter-refill gap in days |
| `hist` | `gaps` | `count(*)` and `AVG(gap_days)` for gaps `>= FORECAST_MIN_CYCLE_DAYS` (3) |
| `money` | `ok_exec` | **`PERCENTILE_CONT(0.5)` of `amount`** (`median_amount`), plus the most recent non-null `offer_id` |
| `rule` | `sim_lines ⋈ carrier_rules` | `DISTINCT ON (sl.id)`, preferring `cr.id = sl.carrier_rule_id`, else `cr.carrier_id = sl.carrier_id`, ordered by `cr.updated_at DESC` — and **`refill_interval_days(cr.inactivity_limit_days, cr.refill_interval_days_override) AS carrier_cycle_days`** |

Configs: `FORECAST_DEFAULT_VALIDITY_DAYS` (90), `FORECAST_ALERT_LEAD_DAYS` (7), `FORECAST_MIN_CYCLE_DAYS` (3).

**Phase 2 — eSIM branch**: `esim_usage_samples` window functions → `mb_per_day = (first_mb − last_mb) / span_days` (only when `span_days >= 1` and consumption is positive); depletion = `NOW() + remaining/mb_per_day`, then `LEAST(data_out_at, expires_at)`.

### 3. Tables & Columns Written

`sim_line_usage_forecast`, upserted on two partial unique indexes: `sim_line_usage_forecast_line_uq (sim_line_id) WHERE sim_line_id IS NOT NULL` and `…_esim_uq (esim_id) …`.

| Column | SIM line | eSIM |
|---|---|---|
| `subject_kind` | `'sim_line'` | `'esim'` |
| `method` | `topup_history` \| `carrier_rule` \| `default` | `esim_usage` \| `default` |
| `confidence` | `high` (≥3 gaps) \| `medium` (≥1 gap, or a carrier rule exists) \| `low` | `high` (≥7 samples) \| `medium` \| `low` |
| `observed_interval_days` | `mean_gap` | — |
| `effective_validity_days` | `cycle_days` | — |
| `predicted_depletion_at` | `LEAST(anchor + cycle_days, anchor + carrier_deadline_days)` | `LEAST(data_out_at, expires_at)` |
| `suggested_frequency_days` | see below | — |
| `suggested_amount_usd` | `COALESCE(median_amount, recommended_topup_amount, minimum_topup_amount)` | — |
| `suggested_offer_id` | `COALESCE(last_offer_id, rule_offer_id)` | — |

`anchor = COALESCE(sl.last_topup_at, sl.created_at, NOW())`; `cycle_days = COALESCE(observed_days, carrier_cycle_days, carrier_deadline_days, 90)`; `carrier_deadline_days = inactivity_limit_days + grace_period_days` (or `carrier_cycle_days + grace` when the limit is absent).

> [!IMPORTANT]
> **The 85/28/13 snap is now a fallback, not the rule.** `suggested_frequency_days` is:
> ```sql
> CASE WHEN carrier_cycle_days IS NOT NULL THEN carrier_cycle_days   -- ← i7d: the real cadence
>      WHEN cycle_days >= 85 THEN 90
>      WHEN cycle_days >= 28 THEN 30
>      WHEN cycle_days >= 13 THEN 14
>      ELSE 7 END
> ```
> The 90/30/14/7 snap survives **only for lines whose carrier has no usable rule**. Everything with a rule gets `refill_interval_days()`.

Phase 3 writes `notifications (category='line_critical', delivered_via={push})` and a `line_activity_log` row, then stamps `sim_line_usage_forecast.last_alert_at`.

### 4. Functions, RPCs & Triggers Executed

| Object | Role |
|---|---|
| `refresh_usage_forecasts()` 🔒 | 02:20 cron orchestrator |
| `snapshot_esim_usage()` 🔒 | idempotent per `(esim_id, sampled_on)` — safe to re-run same day |
| `compute_usage_forecasts()` 🔒 | the two upserts |
| **`trg_floor_forecast_suggestion`** BEFORE INSERT/UPDATE → `trg_fn_floor_forecast_suggestion()` 🔒 | raises `suggested_amount_usd` to `carrier_qualifying_topup_amount(carrier_id)` when it falls short |
| `emit_forecast_depletion_alerts()` 🔒 | alerting |
| `refill_interval_days()` 🔓 | cadence primitive |

**The flooring trigger is a correctness guard, not a nicety.** A median of past top-ups can easily be *below* the carrier's qualifying amount (users under-top-up). Suggesting that amount would tell someone to spend money that keeps their line no more alive. Raising is the only safe direction.

### 5. RLS & Grant Lockdown

| Table | Access |
|---|---|
| `sim_line_usage_forecast` | `SELECT` for `authenticated`; policy = own rows **or** accepted household member, `AND NOT is_user_suspended()`. Written **only** by `compute_usage_forecasts()` 🔒 |
| `esim_usage_samples` | **deny-all** (RLS on, zero policies), `service_role` grant only |

Indexes serving this scenario: `sim_line_usage_forecast_due_idx (predicted_depletion_at) WHERE NOT NULL` for the alert sweep; `sim_line_usage_forecast_user_idx` for the client read; `idx_topup_executions_sim_line_id` + `idx_topup_executions_status` for `ok_exec`.

### 6. Code Path

```
02:20 cron → refresh_usage_forecasts()
   → snapshot_esim_usage()                      → esim_usage_samples (upsert by day)
   → compute_usage_forecasts()
        SIM lines: gaps → median → carrier rule → refill_interval_days → upsert
                   → trg_fn_floor_forecast_suggestion raises the amount
        eSIMs:     sample regression → upsert
   → emit_forecast_depletion_alerts()           → notifications + line_activity_log
Client → select sim_line_usage_forecast (RLS)   → "runs out in N days" chip
```

### 7. Edge Cases, Security Risks & Failure Handling

- **Alert suppression is the important half.** `emit_forecast_depletion_alerts` skips a line when an active `scheduled_topups` row (`refill_custom` or `refill_mini`) has `next_execution_at <= predicted_depletion_at`. A protected line is *not* nagged. It also skips `protection_paused` lines and non-`active` lines.
- **Alert cooldown** is `last_alert_at < NOW() - alert_lead_days` — so a 7-day lead means at most one alert per 7 days per line.
- **A single-refill line has no observed cadence.** `gaps` needs two successful executions to produce one gap; with `gap_count = 0` the method falls to `carrier_rule` and confidence to `medium`.
- **`median_amount` is robust by design.** `PERCENTILE_CONT(0.5)` ignores a one-off large emergency top-up that a mean would let dominate.
- **Whole-run atomicity.** All three phases run in one transaction. If `emit_forecast_depletion_alerts` raises, **the forecasts are rolled back too** — the run is all-or-nothing. Given the notification insert fires `net.http_post`, a dispatch failure does not raise (it is fire-and-forget), so this is mostly theoretical, but it means a bad `notifications` CHECK would silently cost a night of forecasts.
- **eSIM regression needs a *falling* series.** `first_mb > last_mb` and `span_days >= 1`; a top-up mid-window (remaining goes up) yields no rate and the forecast falls back to `expires_at` only.
- ⚠️ **`compute_usage_forecasts` only considers `sl.status = 'active'`.** A line in any other status gets **no forecast row**, and `run_auto_rescue` skips lines with no forecast — so a mis-statused line is silently unprotected.

---

## Scenario D2 — Queue Ingestion & Deactivation-Window Scheduling

### 1. Scenario Overview
KeepSIMs has **one execution queue** (`topup_executions`) fed by three schedule shapes. `scheduled_topups.schedule_type` ∈ `{notify, refill_mini, refill_custom}`, unique per `(sim_line_id, schedule_type)`.

| `schedule_type` | Meaning | Queue behaviour |
|---|---|---|
| `notify` | Reminder only, no spend | no executions |
| `refill_mini` | Premium pre-paid year | **the whole year is materialised up front** by `queue_premium_refill_executions()` |
| `refill_custom` | User-defined recurring refill | **one row at a time**, the next queued on success |

`topup_executions.execution_type` mirrors this: `refill_mini`, `refill_custom`, `refill_instant`.

### 2. Tables & Columns Read

| Path | Reads |
|---|---|
| `queue_premium_refill_executions` | `sim_lines (user_id, carrier_id, carrier_rule_id, plan_expires_at)` with an ownership/household-manager predicate; `scheduled_topups` (must be the line's `refill_mini` row); `carrier_rules`; `carrier_refill_offer()`; `has_paid_premium_entitlement()` |
| `trg_fn_sync_custom_refill_queue` | `topup_executions` (dedupe probe on `scheduled_topup_id, status='pending', execution_time, amount, offer_id`) |
| `claim_due_executions` | `topup_executions` ⋈ `scheduled_topups.is_active` |

### 3. Tables & Columns Written

**Premium (`refill_mini`)** — `queue_premium_refill_executions(sim_line, scheduled_topup, plan_expires_at, start_at)` 🔒:

```sql
-- cancel any existing queue first (idempotent re-queue)
UPDATE topup_executions SET status='cancelled', completed_at=now()
 WHERE scheduled_topup_id = $2 AND status IN ('pending','pending_payment');

v_step    := refill_interval_days(inactivity_limit_days, refill_interval_days_override);
v_expires := LEAST(COALESCE(plan_expires_at, start+365d), COALESCE($3, ∞), start + 370 days);
v_t := start_at;
WHILE v_t < v_expires AND v_count < 400 LOOP
  INSERT INTO topup_executions (
    sim_line_id, user_id, amount, base_cost_usd, currency, status='pending',
    execution_type='refill_mini', execution_time = v_t,
    offer_id = <offer.offer_code>, offer_value, scheduled_topup_id, api_provider = <offer.provider_code>);
  v_t := v_t + v_step days;
END LOOP;
```

**Custom (`refill_custom`)** — `trg_fn_sync_custom_refill_queue()` 🔒 (AFTER INSERT OR UPDATE ON `scheduled_topups`): early-returns unless one of `amount, currency, next_execution_at, is_active, offer_id, offer_value` actually changed; then cancels the outstanding pending rows and inserts exactly one new `pending` execution at `next_execution_at`. If `is_active` is false it only cancels.

**Claiming** — `claim_due_executions(execution_type, limit)` 🔓 (`service_role`):

```sql
UPDATE topup_executions SET status='processing', processing_since=NOW(), pre_processing_status='pending'
WHERE id IN (
  SELECT t.id FROM topup_executions t
   WHERE t.status='pending' AND t.execution_type = $1 AND t.execution_time <= NOW()
     AND (t.scheduled_topup_id IS NULL
          OR EXISTS (SELECT 1 FROM scheduled_topups st WHERE st.id = t.scheduled_topup_id AND st.is_active))
   ORDER BY t.execution_time ASC
   LIMIT $2
   FOR UPDATE SKIP LOCKED)        -- ← the concurrency primitive
RETURNING *;
```

`claim_instant_executions` is the same shape for `status='routing'`, ordered by `created_at`, with `pre_processing_status='routing'`.

### 4. Functions, RPCs & Triggers Executed

BEFORE INSERT on `topup_executions`, in fire order:

| Trigger | Function | Effect |
|---|---|---|
| `on_topup_insert_rate_limit` | `check_topup_rate_limit()` 🔒 | per-user execution-creation throttle |
| `tr_calculate_topup_fees` | `calculate_topup_fees()` 🔒 | fills `gateway_fee_usd`, `app_fee_usd`, `message_fee_usd` from `system_configs` and `payment_gateways` |
| `trigger_route_topup_execution` | `route_topup_execution()` 🔓 | see D3 |

AFTER: `trg_topup_executions_activity`, `trg_notify_topup_result`, `trigger_update_sim_line_last_topup`, `trg_supplier_failover`.

### 5. RLS & Grant Lockdown

| Table | Client |
|---|---|
| `scheduled_topups` | `SELECT/INSERT/UPDATE/DELETE` granted; policies: own rows, **or** household `role='manager'` for ALL, **or** accepted member for SELECT — all `AND NOT is_user_suspended()` |
| `topup_executions` | `SELECT` only ⛔ — the client can watch the queue but never write it |

> [!IMPORTANT]
> A user *can* write `scheduled_topups` directly, and that write **synthesises an execution row** through `trg_fn_sync_custom_refill_queue`. The dedupe probe and the cancel-then-insert shape are what keep that safe: a client cannot accumulate duplicate pending executions by re-saving the same schedule, because an identical `(scheduled_topup_id, status, execution_time, amount, offer_id)` short-circuits.

> [!NOTE]
> `queue_premium_refill_executions` is granted to `authenticated`, so it carries its own authorisation: the caller must own the line or be an accepted household **manager**, the schedule must belong to the line and be `refill_mini`, and — unless the JWT role is `service_role` — `has_paid_premium_entitlement(sim_line)` must be true or it raises `KS403`.

### 6. Code Path

```
Premium purchase  → rpc pay_plan_fee_from_wallet   (or PayPal kind='plan')
                  → rpc queue_premium_refill_executions(line, schedule, expires, start)
                        → N pending rows, spaced refill_interval_days apart
Custom schedule   → upsert scheduled_topups(schedule_type='refill_custom', next_execution_at, amount)
                        → trg_fn_sync_custom_refill_queue → 1 pending row
Worker (node)     → rpc claim_due_executions('refill_mini' | 'refill_custom', N)   [FOR UPDATE SKIP LOCKED]
                  → rpc claim_instant_executions('refill_instant', N)
```

### 7. Edge Cases, Security Risks & Failure Handling

- **`FOR UPDATE SKIP LOCKED` is the whole concurrency story.** Multiple worker instances can call `claim_due_executions` simultaneously; each gets a disjoint set. There is no advisory lock and no leader election — horizontal scaling is safe by construction.
- **The claim honours a paused schedule.** `EXISTS (… st.is_active)` means deactivating a schedule stops future claims without needing to cancel the already-queued rows.
- **Queue caps.** `v_count < 400` and `start + 370 days` are hard stops. A carrier with a 1-day `refill_interval_days_override` would otherwise materialise 365 rows; the cap bounds the blast radius of a bad rule.
- **Re-queue is idempotent by cancellation.** Calling `queue_premium_refill_executions` twice cancels the first queue before building the second. This is how a plan renewal or a rule change is applied.
- ⚠️ **The premium queue is priced once, at queue time.** All N rows carry the offer price observed on purchase day. If the supplier's price rises mid-year, the executions carry a stale `base_cost_usd` and `amount`. The wallet debit at execution uses the row's amount, so KeepSIMs absorbs the difference. This is the intended economics of a pre-paid year (`plan_price_net` builds the margin in), but it means a large supplier price move should trigger a re-queue.
- **`pre_processing_status` is the reaper's memory.** `claim_*` stores which status the row came from so `reap_stuck_executions` can put it back exactly there (`pending` vs `routing`) rather than guessing.
- ⚠️ **`unique_sim_line_schedule_type` allows only one schedule per type per line.** A user cannot have two different custom refills on one line. That is probably intended, but it also means switching a line from `refill_custom` to `refill_mini` requires deleting the old row — which cancels its executions via `trg_cancel_executions_on_schedule_delete`.

---

## Scenario D3 — Multi-Provider Routing & Supplier Selection

### 1. Scenario Overview
Two independent decisions, often confused:

1. **Fulfilment gateway** — *how* is this executed? `API` (a supplier), `TASKER_SCRIPT` (an Android runner driving the carrier's own app), or `MANUAL`. Decided by `route_topup_execution()` at INSERT.
2. **Supplier** — *which* API supplier? `zendit`, `dtone`, `ding`, `reloadly`. Decided by `choose_supplier_for_offer()`.

### 2. Tables & Columns Read

**`route_topup_execution()`** 🔓 BEFORE INSERT:

| Table | Columns | Filter |
|---|---|---|
| `sim_lines ⋈ carriers` | `carriers.fulfillment_gateway` | `sl.id = NEW.sim_line_id` |
| `carrier_provider_map` | `provider` | `LEFT JOIN … AND m.is_primary` — **`uq_carrier_provider_map_primary`** |
| `system_configs` | `ACTIVE_FULFILLMENT_METHOD` | fallback when the carrier has none |
| `refill_scripts` | `is_enabled, allowed_execution_types` | to confirm a `TASKER_SCRIPT` route is real |

**`supplier_candidates(sim_line, offer_id, exclude[])`** 🔒 — the candidate set:

```sql
FROM sim_lines sl
JOIN carrier_provider_map m   ON m.carrier_id = sl.carrier_id AND m.is_enabled
JOIN supplier_policy      sp  ON sp.provider = m.provider AND sp.is_globally_enabled
JOIN provider_offers_cache poc ON poc.api_provider = m.provider
                              AND poc.country_code = m.provider_country_code
                              AND poc.carrier_code = m.provider_carrier_code
                              AND poc.offer_id     = p_offer_id
WHERE sl.id = p_sim_line_id
  AND poc.refreshed_at >= now() - interval '24 hours'      -- ← stale offers are excluded here
  AND (p_exclude IS NULL OR NOT (poc.api_provider = ANY (p_exclude)))
```

Returns `(provider, base, eff, incumbent, prio)` where `eff = supplier_effective_cost(provider, base)`:

```sql
round(base * (1 + risk_premium_percent/100.0) + flat_penalty_usd, 4)
```

### 3. Tables & Columns Written

| Field on `topup_executions` | Set by |
|---|---|
| `fulfillment_gateway` | `route_topup_execution()` |
| `api_provider` | `COALESCE(NEW.api_provider, <primary provider>)` |
| `status` | `pending → routing` when `execution_type='refill_instant'` |
| `attempted_providers[]` | `request_instant_refill` seeds `ARRAY[picked]`; `retry_execution_at_next_supplier` appends |
| `gateway_fee_usd`, `app_fee_usd`, `message_fee_usd` | `calculate_topup_fees()` |

`refill_scripts.runner_id`, `last_heartbeat_at` are written by `script_claim_next_execution()`.

### 4. Functions, RPCs & Triggers Executed

**Gateway routing logic**, exactly as it runs:

```sql
IF status IN ('pending','pending_payment','routing') AND fulfillment_gateway IS NULL THEN
  gateway := carriers.fulfillment_gateway
  IF gateway IS NULL THEN gateway := system_configs.ACTIVE_FULFILLMENT_METHOD ELSE … END
  IF gateway IS NULL THEN gateway := 'MANUAL' END                       -- ← final fallback
  IF gateway='TASKER_SCRIPT' AND execution_type='refill_instant' THEN gateway := 'API' END
  IF gateway='TASKER_SCRIPT' AND NOT EXISTS(enabled refill_scripts for this carrier
                                            allowing this execution_type) THEN gateway := 'API' END
  NEW.fulfillment_gateway := gateway
  NEW.api_provider := COALESCE(NEW.api_provider, <primary provider from carrier_provider_map>)
  IF execution_type='refill_instant' AND status='pending' THEN NEW.status := 'routing' END
END IF
```

**Supplier selection** — `choose_supplier_for_offer(line, offer, exclude[])` 🔒, mode from `SUPPLIER_SELECTION_MODE` (default `margin_aware`):

| Mode | Behaviour | `chosen_reason` |
|---|---|---|
| `cheapest` | lowest `eff`, ties by `prio` then `provider` | `cheapest` |
| `margin_aware` | keep the incumbent (`is_primary`) unless the challenger beats it by **both** `SUPPLIER_SWITCH_MIN_SAVING_USD` (0.05) **and** `SUPPLIER_SWITCH_MIN_SAVING_PERCENT` (2.0 %) | `incumbent_is_cheapest` \| `challenger_beat_threshold` \| `saving_below_threshold` \| `no_incumbent` |

`script_claim_next_execution(runner_id, max)` 🔒 (`service_role` only, raises `KS403` otherwise) claims `TASKER_SCRIPT` work with `FOR UPDATE OF te SKIP LOCKED`, enforcing `rs.max_daily_executions` by counting today's `processing_since` rows for that carrier. `script_complete_execution(exec, success, provider_ref, note)` 🔒 closes the loop.

### 5. RLS & Grant Lockdown

- `carrier_provider_map`, `supplier_policy`, `service_providers`, `provider_offers`, `refill_scripts` — **no grants to `authenticated` at all**. Routing is invisible to clients.
- `provider_offers_cache` — `SELECT` for `authenticated` (policy `Authenticated can read provider offers cache`, `USING true`). This is the one supplier-side table clients can read; it holds no cost data beyond prices already shown in the app. 780 rows live.
- `refill_scripts` carries a CHECK (`refill_scripts_no_instant`) making `refill_instant` unrepresentable in `allowed_execution_types` — scripted fulfilment is scheduled-only, and the router's `TASKER_SCRIPT + refill_instant → API` rule is the belt to that braces.
- `trg_carrier_map_provider_sells_topup` 🔒 refuses a mapping to a provider whose `supports_topup` is false.

### 6. Code Path

```
INSERT topup_executions
  → BEFORE trg route_topup_execution   → fulfillment_gateway, api_provider, status
Worker picks it up:
  gateway='API'            → claim_due_executions / claim_instant_executions
                             → choose_supplier_for_offer → provider SDK (Zendit / DT One / …)
  gateway='TASKER_SCRIPT'  → runner polls script_claim_next_execution(runner_id)
                             → drives the carrier app → script_complete_execution(...)
  gateway='MANUAL'         → admin_complete_manual_refill / admin_fail_refill
```

### 7. Edge Cases, Security Risks & Failure Handling

- **Fail-safe defaults to `MANUAL`.** If a carrier has no gateway and `ACTIVE_FULFILLMENT_METHOD` is unset, the execution parks as `MANUAL` and waits for a human. It never silently picks an API.
- **`is_routable` fail-closed.** A provider with no `supplier_policy` row is `COALESCE(pol.is_globally_enabled, false)` = **not routable**. Adding a supplier requires an explicit policy row — you cannot accidentally route to a half-configured provider.
- **24-hour staleness is enforced at selection, not at display.** `supplier_candidates` excludes cache rows older than 24 h, so an outage in the offers-cache worker degrades to "no candidates" (a clear failure) rather than "charge the wrong price" (a silent one).
- ⚠️ **`supplier_candidates` reads `provider_offers_cache` while `carrier_refill_offer` reads `provider_offers`.** These are two different shelves — the raw per-supplier cache and the curated K2 shelf with the admin override layer. **An admin price override in `provider_offers` is therefore invisible to instant-refill supplier selection.** Premium queuing (via `carrier_refill_offer`) honours overrides; instant refill does not. This is the most significant unresolved inconsistency in the routing layer.
- **DT One history.** The DT One adapter once fabricated catalogues, product ids, purchases *and* poll results — a "successful" refill delivered nothing, and the fake rows are still in the database. Any reconciliation against DT One must treat pre-fix rows as untrusted.
- **Margin-aware hysteresis prevents flapping.** Requiring *both* an absolute and a relative saving means a supplier that is $0.01 cheaper does not cause a switch, so the incumbent relationship (and its volume pricing) is stable.

---

## Scenario D4 — Successful Auto-Refill Execution

### 1. Scenario Overview
A worker claims a `pending` execution, debits the wallet, calls the supplier, and marks it `success`. The `status → 'success'` transition is the pivot: **four AFTER triggers fire off it**, and together they update the line, chain the next cycle, write the immutable log, and notify.

### 2. Tables & Columns Read

| Step | Table | Purpose |
|---|---|---|
| claim | `topup_executions ⋈ scheduled_topups` | `claim_due_executions` |
| debit | `wallets` `FOR UPDATE` | balance |
| debit | `topup_executions.acting_user_id` | household detection via `reference_id = 'exec_<uuid>'` |
| chain | `scheduled_topups.frequency_days` | `WHERE id = NEW.scheduled_topup_id AND is_active` |

### 3. Tables & Columns Written

| Order | Table | Write |
|---|---|---|
| 1 | `topup_executions` | `status='processing', processing_since=NOW(), pre_processing_status=<prior>` |
| 2 | `wallets` + `wallet_transactions` | `debit_wallet_for_topup(user, line, amount, desc, 'exec_<id>', 'topup_debit')` |
| 3 | `topup_executions` | `status='success', reloadly_transaction_id=<provider ref>, completed_at=now()` |
| 4a | `sim_lines` | `last_topup_at = COALESCE(completed_at, now()), updated_at = now()` |
| 4b | `topup_executions` | **next `refill_custom` row** at `completed_at + frequency_days` (see below) |
| 4c | `scheduled_topups` | `next_execution_at`, `last_execution_at` |
| 4d | `line_activity_log` | `event_type='topup_success'` with `{amount, execution_id, execution_type, provider, transaction_id, refill_channel}` |
| 4e | `notifications` | `top_up_success` |

**The chaining rule** — `update_sim_line_last_topup_at()` 🔒 (AFTER INSERT OR UPDATE OF status):

```sql
IF NEW.status='success' AND (TG_OP='INSERT' OR OLD.status IS DISTINCT FROM 'success') THEN
  UPDATE sim_lines SET last_topup_at = COALESCE(NEW.completed_at, now()), updated_at = now()
   WHERE id = NEW.sim_line_id;
  IF NEW.execution_type = 'refill_custom' AND NEW.scheduled_topup_id IS NOT NULL THEN
     SELECT frequency_days INTO v_freq FROM scheduled_topups WHERE id = NEW.scheduled_topup_id AND is_active;
     IF v_freq > 0 THEN
        INSERT INTO topup_executions (… execution_time = COALESCE(NEW.completed_at, now()) + v_freq days,
                                      execution_type='refill_custom', offer_id, offer_value, base_cost_usd …);
        UPDATE scheduled_topups SET next_execution_at = …, last_execution_at = …;
     END IF;
  END IF;
END IF;
```

> [!NOTE]
> **Only `refill_custom` chains.** `refill_mini` does not — its whole year was materialised at purchase (D2). `refill_instant` does not chain by definition. This is why the trigger tests `execution_type` explicitly.

### 4. Functions, RPCs & Triggers Executed

AFTER `status → 'success'`, all four fire on the same row:

| Trigger | Function | Writes |
|---|---|---|
| `trigger_update_sim_line_last_topup` | `update_sim_line_last_topup_at()` 🔒 | `sim_lines`, next execution, `scheduled_topups` |
| `trg_topup_executions_activity` | `trg_fn_log_topup_activity()` 🔒 | `line_activity_log` (guarded by the I6 EXISTS probe) |
| `trg_notify_topup_result` | `trg_fn_notify_topup_result()` 🔒 | `notifications` |
| `trg_supplier_failover` | `trg_fn_supplier_failover()` 🔒 | no-op (only acts on `→ failed`) |

Then `sim_lines.last_topup_at` changing fires `trg_update_line_health` → `calculate_health_score()`.

`line_activity_log` is capped by `trg_line_activity_log_prune` → `trg_fn_prune_line_activity_log()` 🔒 (AFTER INSERT).

### 5. RLS & Grant Lockdown

- Everything here runs as `service_role` (worker) or inside SECURITY DEFINER triggers. `topup_executions` is `SELECT`-only for clients, so the user sees the state machine advance in realtime but cannot touch it.
- `update_execution_status(id, status, reloadly_transaction_id)` 🔒 and `update_execution_failed(id, reason)` 🔒 are `service_role`-only — the worker's write API.
- `line_activity_log` financial event types are undeletable by the user (policy predicate, §B4).

> [!IMPORTANT]
> **Trigger functions are not client-callable.** `c1_revoke_trigger_fn_execute`, `c3b2_revoke_fee_trigger_execute` and `h5c_revoke_trigger_fn_execute` exist to strip EXECUTE from `trg_fn_*` for `authenticated`. Verified live: every `trg_fn_*` shows `service_role` only, except four `SECURITY INVOKER` ones (`trg_fn_affiliate_offer_normalise`, `trg_fn_esim_offer_country_count`, `tr_fx_rate_sanity`) which are harmless because they only manipulate `NEW`.

### 6. Code Path

```
worker_auto_mini_refill.js / worker_auto_custom_refill.js
  → rpc claim_due_executions(type, N)                    [FOR UPDATE SKIP LOCKED]
  → rpc debit_wallet_for_topup(user, line, amount, 'exec_<id>', 'topup_debit')
  → provider SDK (Zendit / DT One)  ← outside any DB transaction
  → rpc update_execution_status(id, 'success', providerRef)
       → 4 AFTER triggers: sim_lines / next execution / activity log / notification
  → realtime: lines controller wakes on topup_executions and re-reads
```

### 7. Edge Cases, Security Risks & Failure Handling

- **The provider call is outside the transaction — deliberately.** Holding the `wallets` row lock across a network call to a supplier would serialise the whole account behind provider latency. The cost is a window where the wallet is debited and the provider call has not returned; `reap_stuck_executions` (every 5 min) is what closes it.
- **Debit-then-call, not call-then-debit.** A provider success with a failed debit would be free money out; a debit with a failed provider call is refundable. The order chosen is the recoverable one.
- **`status='success'` is guarded against replay** by `OLD.status IS DISTINCT FROM 'success'` — re-writing `success` over `success` does **not** re-chain the next execution or re-stamp `last_topup_at`.
- ⚠️ **The UI does not always see the write.** The lines controller is woken by realtime on `topup_executions`; a card that reads its own cached state can say "No refill yet" over a refill the database has recorded. Any screen showing refill state must subscribe, not poll once.
- **Household attribution.** When `acting_user_id` is set, the ledger row carries `metadata.spent_by / spent_for_owner / household`, and `household_spend_mtd` counts it against the manager's cap — see E3.
- **Fees.** `calculate_topup_fees()` fills `gateway_fee_usd`, `app_fee_usd`, `message_fee_usd` at INSERT, but the **wallet debit uses `amount`**. Verify that `amount` already includes the fees for every insert path; a path that sets `amount = base_cost_usd` only would under-charge.

---

## Scenario D5 — Failure, Supplier Failover, Reaping & Auto-Rescue

### 1. Scenario Overview
Three independent recovery mechanisms, each with a different trigger:

| Mechanism | Trigger | Guard |
|---|---|---|
| **Supplier failover** | `topup_executions.status → 'failed'` | `SUPPLIER_RETRY_ENABLED` |
| **Reaper** | execution stuck in `processing` | every 5 min, `reap_stuck_executions()` |
| **Auto-rescue ("SIM Shield")** | forecast says the line dies soon and the user has not acted | hourly, `run_auto_rescue()` |

### 2. Tables & Columns Read

**Failover** — `trg_fn_supplier_failover()` 🔒: `system_configs.SUPPLIER_RETRY_ENABLED`, `SUPPLIER_RETRY_SKIP_REASONS` (comma-separated substrings matched case-insensitively against `failure_reason`).

**`retry_execution_at_next_supplier(exec_id)`** 🔒: the failed `topup_executions` row, `SUPPLIER_RETRY_MAX_ATTEMPTS` (2, clamped 1–5), `SUPPLIER_RETRY_SAME_COST_TOLERANCE_USD` (0.01), then `choose_supplier_for_offer(line, offer, attempted_providers)`.

**Reaper**: `topup_executions WHERE status='processing' AND COALESCE(processing_since, created_at) < now() - p_stuck_after_minutes` `FOR UPDATE SKIP LOCKED`.

**Auto-rescue**: `sim_line_rescue_policy ⋈ sim_lines ⋈ profiles LEFT JOIN sim_line_usage_forecast LEFT JOIN wallets`, filtered `p.max_usd > 0 AND sl.status='active' AND sl.protection_paused=false AND NOT pr.is_suspended`, ordered by `days_remaining NULLS LAST`. Configs: `RESCUE_ENABLED`, `RESCUE_GRACE_HOURS` (24), `RESCUE_COOLDOWN_DAYS` (20), `RESCUE_MAX_PER_RUN` (25).

### 3. Tables & Columns Written

**Failover** → a **new** `topup_executions` row:
```sql
INSERT INTO topup_executions (…, status='pending', execution_time=now(),
    api_provider = <new provider>,
    attempted_providers = old.attempted_providers || <new provider>,
    retry_of = <failed execution id>, scheduled_topup_id = <inherited>,
    amount = base_cost_usd = <new supplier's price>);
```
If `abs(new_cost − old_cost) > SUPPLIER_RETRY_SAME_COST_TOLERANCE_USD`, a `notifications` row (`category='system'`) tells the user the price changed. The new row's INSERT fires `trg_fn_log_topup_activity` with `event_type='topup_retry_queued'` (because `retry_of IS NOT NULL`).

**Reaper**, in one statement with three CTEs:
```sql
stuck   := processing rows older than p_stuck_after_minutes   FOR UPDATE SKIP LOCKED
dead    := UPDATE … SET status='failed', failure_reason='Dead-lettered by reaper: …', completed_at=now()
             WHERE reaper_retries >= p_max_retries
requeue  := UPDATE … SET status = pre_processing_status, reaper_retries += 1, processing_since = NULL
             WHERE reaper_retries <  p_max_retries
```
Dead-lettering writes `system_alerts('execution_dead_lettered')`.

**Auto-rescue** per rescued line:
```sql
INSERT topup_executions (…, payment_gateway_code='wallet', status='pending',
                          execution_type='refill_instant', offer from carrier_refill_offer);
IF charged > policy.max_usd  THEN RAISE 'RESCUE_OVER_CAP:…'  KS402;   -- post-insert, in-transaction
IF charged > wallet.balance  THEN RAISE 'RESCUE_NO_FUNDS:…'  KS402;
INSERT line_activity_log ('rescue_topup_triggered', {execution_id, offer_id, provider, charged_usd, max_usd, days_remaining, warned_at, grace_hours});
INSERT notifications      ('SIM Shield rescued <label>');
UPDATE sim_line_rescue_policy SET last_rescue_at=now(), last_rescue_execution_id=…, rescue_count+=1, last_warned_at=NULL;
```

### 4. Functions, RPCs & Triggers Executed

```
topup_executions.status → 'failed'
  ├─ trg_supplier_failover → trg_fn_supplier_failover()
  │     if SUPPLIER_RETRY_ENABLED <> 'true' → return
  │     if failure_reason contains any SUPPLIER_RETRY_SKIP_REASONS substring → return
  │     retry_execution_at_next_supplier(NEW.id)
  │       exceptions are caught → system_alerts('supplier_failover_failed')
  ├─ trg_topup_executions_activity → line_activity_log('topup_failed')
  └─ trg_notify_topup_result       → notifications('top_up_failed')
```

`run_auto_rescue(p_dry_run)` 🔒 has a hard `service_role` guard (`KS403`) and returns a per-line table of `action ∈ {skipped, reset, warned, rescued}` with the reason — so a dry run is a full explanation of what it *would* do.

`admin_fail_refill(exec, reason, refund)` 🔒 and `admin_complete_manual_refill(exec, note)` 🔒 are the human overrides; `admin_switch_gateway_to_manual(exec, note)` moves a stuck API execution to the manual desk.

### 5. RLS & Grant Lockdown

- `run_auto_rescue`, `reap_stuck_executions`, `retry_execution_at_next_supplier` — `service_role` EXECUTE only.
- `sim_line_rescue_policy` — `SELECT` own for `authenticated`; written **only** by `set_line_rescue_policy()` 🔒. It is a separate table from `sim_lines` precisely because that table's column-level UPDATE grant has broken client writes twice.
- **`max_usd = 0` is the fail-closed default** — a line is not insured until someone deliberately sets a cap. Zero rows live today, i.e. the feature ships inert.
- `retry_topup_execution(exec)` 🔒 is granted to `authenticated` for a user-initiated retry; `retry_execution_at_next_supplier` (the automatic one) is not.

### 6. Code Path

```
failure   → UPDATE topup_executions SET status='failed', failure_reason=…
              → trg_fn_supplier_failover → retry_execution_at_next_supplier
                 → new pending row on the next-best supplier (+ price-change notice)
stuck     → */5 cron reap_stuck_executions()
              → requeue to pre_processing_status, or dead-letter + system_alert
dying line→ :50 cron run_auto_rescue()
              → warn (first pass) → wait RESCUE_GRACE_HOURS → rescue (second pass)
              → INSERT topup_executions('refill_instant', gateway='wallet')
```

### 7. Edge Cases, Security Risks & Failure Handling

- **Failover must not retry a business refusal.** `SUPPLIER_RETRY_SKIP_REASONS` is a substring blacklist — "invalid number", "unsupported denomination" etc. Retrying those at another supplier fails identically and burns money on fees. The match is `position(lower(pattern) in lower(failure_reason)) > 0`, so patterns must be specific enough not to over-match.
- **Failover cannot loop.** `attempted_providers[]` accumulates and is passed as `p_exclude`; `SUPPLIER_RETRY_MAX_ATTEMPTS` caps the chain. A retry with no remaining supplier returns `{retried:false, reason:'no_alternative_supplier'}`.
- **Failover exceptions are swallowed into an alert.** `trg_fn_supplier_failover` wraps the retry in `BEGIN … EXCEPTION WHEN OTHERS` → `system_alerts('supplier_failover_failed')`. A broken failover therefore never prevents an execution from being marked failed — correct, but it means failover health must be watched via `system_alerts`.
- ⚠️ **The retry does not re-debit or refund.** `retry_execution_at_next_supplier` inserts a new execution at the new supplier's price but performs **no wallet movement**. Whether the original debit was refunded depends on the worker's failure handler calling `credit_wallet_for_refund`. If a retry succeeds at a higher price, the *second* debit is what the user pays; the first must have been refunded. **This is the highest-value invariant to verify with a reconciliation query before go-live:** for every `retry_of` chain, exactly one net debit should remain.
- **Reaper races the worker.** A worker that is merely slow (not dead) can have its row requeued and claimed by another worker, producing a double provider call. `p_stuck_after_minutes` must exceed the worst-case provider timeout. `reaper_retries` bounds the damage at `p_max_retries` before dead-lettering.
- **Auto-rescue is two-pass by design.** It warns first, waits `RESCUE_GRACE_HOURS`, and only then spends — so the user always gets a chance to act. `last_warned_at` is cleared if the user tops up themselves (`reset`), and `RESCUE_COOLDOWN_DAYS` prevents repeated rescues.
- ⚠️ **The rescue cap is checked *after* the INSERT.** `INSERT … RETURNING amount INTO v_charged;` then `IF v_charged > r.max_usd THEN RAISE`. The `RAISE` is inside a per-line `BEGIN…EXCEPTION WHEN OTHERS` block, so it rolls back to the savepoint and the row is discarded — correct behaviour, but it relies on the exception block. Checking `carrier_refill_offer`'s price against `max_usd` *before* the insert would be clearer and would avoid burning execution ids.
- **Per-line exception isolation.** Every rescue iteration is wrapped so one bad line (no offer, no funds, over cap) returns `action='skipped'` with the SQLSTATE and message, and the loop continues. One broken carrier cannot stop the rescue run.

---
# CATEGORY E — Subscriptions, Plan Tiers & Household Spend

---

## Scenario E1 — Upgrading to Premium (Wallet or PayPal)

### 1. Scenario Overview
A premium line is a **pre-paid year of refills**. The user pays one annual fee; the system then materialises the whole year's executions and pays for each one out of the margin built into that fee. Two rails reach the same state, and **both must actually debit** — J8 exists because one of them did not.

| Rail | Charge | Records the payment in |
|---|---|---|
| Wallet | `pay_plan_fee_from_wallet()` 🔒 | `wallet_transactions (type='plan_fee_debit')` |
| PayPal | `create-paypal-order {kind:'plan'}` → webhook | `plan_payments (kind='plan')` |

### 2. Tables & Columns Read

**Pricing** — `plan_price_net(plan, sim_line_id, carrier_rule_id)` 🔒:

| Table | Columns | Use |
|---|---|---|
| `system_configs` | `BASE_SERVICE_FEE_USD` (2.50), `APP_FEE_PERCENT` (3.0), `PREMIUM_MARGIN_PERCENT` (5.0), `PREMIUM_MARGIN_PER_REFILL_USD` (0.324) | fee model |
| `carrier_rules` | `carrier_id, minimum_topup_amount, inactivity_limit_days, refill_interval_days_override, inapp_pricing, activity_requirement, validity_qualifying_topup_amount` | resolved by `COALESCE($3, sim_lines.carrier_rule_id, latest rule for the carrier)` |
| `provider_offers` ⋈ `carrier_supplier_routing` | via `carrier_refill_offer(carrier, qualifying)` | the real supplier price |

`quote_plan_price(line, plan, gateway, rule)` 🔒 wraps it with the gateway gross-up, reading `payment_gateways (fee_percentage, fee_fixed) WHERE code = $3 AND is_active`:

```sql
gross = round((net + fee_fixed) / (1 - fee_percentage/100.0), 2)
```

### 3. The price model, exactly

```sql
IF plan = 'standard' THEN RETURN BASE_SERVICE_FEE_USD; END IF;      -- 2.50
-- premium:
v_step      := refill_interval_days(inactivity_limit_days, refill_interval_days_override);
v_refills   := ceil(365.0 / v_step);                                -- ← the queue's own cadence
v_qualifying:= COALESCE(validity_qualifying_topup_amount, minimum_topup_amount);
v_offer     := carrier_refill_offer(carrier_id, v_qualifying);
v_from_cost := v_offer.price_usd * (1 + (APP_FEE_PERCENT + PREMIUM_MARGIN_PERCENT)/100.0)
               + PREMIUM_MARGIN_PER_REFILL_USD;
v_per_refill:= GREATEST(COALESCE(inapp_pricing, 0), v_from_cost);
RETURN BASE_SERVICE_FEE_USD + (v_per_refill * v_refills);
```

> [!IMPORTANT]
> **`plan_price_net` is the single price behind both rails, and its `v_refills` is computed from the *same* `refill_interval_days()` the queue uses.** Before J8, `quote_plan_price` billed 13 refills where the queue laid 5 — the price and the queue disagreed because they derived cadence differently. They now share one primitive; **any change to `refill_interval_days` changes both the price and the queue, and must not be made to one alone.**

> [!NOTE]
> **Client-Side UI Synchronization & Carrier Scoping (Migration K12):** The Flutter application (`PlanPayment.fetchQuotedPlanPrice` & `quotedPlanPriceProvider`) queries `quote_plan_price` directly via RPC to preview plan costs in `SimLineFormScreen`. Migration K12 enforces that `inapp_pricing` is strictly ignored for API-fulfilled carriers (`fulfillment_gateway = 'API'`), deriving pricing dynamically from live supplier catalog offers (`provider_offers`), while preserving `inapp_pricing` for MANUAL and TASKER_SCRIPT carriers. This guarantees 100% agreement between card previews, PayPal fee breakdown modals, and PayPal checkout charges.

Refusals, before any money moves: `usage_required` → `KS422`; inconsistent `min_denomination` rule → `KS422`; no rule / no price → `22023`; no supplier offer reaching the qualifying amount → `KS422`.

### 4. Tables & Columns Written

**Wallet rail** — `pay_plan_fee_from_wallet(reference_id, sim_line_id, device_id, plan, carrier_rule_id)` 🔒 (`authenticated`):

```
1. auth.uid() present                              → {success:false, error:'UNAUTHORIZED'}
2. profiles.is_suspended = false                   → {success:false, error:'Account is suspended.'}
3. sim_line belongs to caller                      → RAISE
4. enforce_rate_limit('plan_fee', uid)             → KS429
5. idempotency probe: wallet_transactions
     WHERE reference_id = $1 AND type='plan_fee_debit'
       → returns {success:true, already_paid:true, transaction_id, amount}
6. v_fee := round(plan_price_net(...), 2)
7. wallets.balance >= v_fee                        → RAISE (the ONLY raising failure)
8. guard_money_action('plan_fee', fee, device, ref, uid)
       → blocked ⇒ {success:false, code:'DEVICE_BLOCKED'}        ← HTTP 200
9. debit_wallet_for_topup(uid, line, fee, 'Annual Plan Fee Debit (premium)', ref, 'plan_fee_debit')
10. UPDATE sim_lines SET plan_expires_at = clock_timestamp() + 365 days WHERE id AND user_id
```

**PayPal rail**: `plan_payments` INSERT → `trg_apply_plan_tier_on_payment` → `trg_fn_apply_plan_tier_from_payment()` 🔒:

```sql
IF NEW.kind='plan' AND NEW.sim_line_id IS NOT NULL THEN
  v_plan := NEW.metadata ->> 'plan';
  IF v_plan IN ('standard','premium','basic','free') THEN               -- whitelist
    SELECT user_id INTO v_owner FROM sim_lines WHERE id = NEW.sim_line_id;
    IF v_owner IS NOT NULL AND (NEW.user_id IS NULL OR v_owner = NEW.user_id) THEN
      UPDATE sim_lines SET plan_type = v_plan, plan_expires_at = NOW() + 1 year, updated_at = NOW()
       WHERE id = NEW.sim_line_id;    -- wrapped in EXCEPTION → system_alerts('plan_tier_update_failed')
```

Then `queue_premium_refill_executions()` lays the year (D2).

### 5. Functions, RPCs & Triggers Executed

| Object | Notes |
|---|---|
| `quote_plan_price` 🔒 (`authenticated`) | ownership-checked (`42501` if the line is not the caller's) |
| `plan_price_net` 🔒 (**`service_role` only**) | the client can only reach it through `quote_plan_price` |
| `pay_plan_fee_from_wallet` 🔒 (`authenticated`) | |
| `has_paid_premium_entitlement(line)` 🔒 | the I2 guard |
| `queue_premium_refill_executions` 🔒 (`authenticated`) | |
| `trg_fn_apply_plan_tier_from_payment` 🔒 | AFTER INSERT `plan_payments` |
| `trg_award_referral_paypal` / `trg_award_referral_wallet` | referral points on either rail |
| `trg_fn_prevent_sim_line_plan_tampering` 🔓 | BEFORE UPDATE on `sim_lines` |

### 6. RLS & Grant Lockdown

> [!WARNING]
> **The I2b hole, proven live on 2026-08-04 and the reason `has_paid_premium_entitlement` exists.**
> `trg_prevent_sim_line_plan_tampering` is **BEFORE UPDATE only**, and `authenticated` held column-level INSERT on `plan_type` and `plan_expires_at`. So a signed-in user could:
> 1. `INSERT sim_lines (…, plan_type='premium', plan_expires_at = now() + 365 days)` — **accepted**;
> 2. insert a `scheduled_topups` row with `schedule_type='refill_mini'` (the client already does this);
> 3. call `queue_premium_refill_executions` — granted to `authenticated`, and it verified **ownership only, never payment**;
> 4. get up to 400 `refill_mini` executions with `payment_gateway_code = NULL`, so `calculate_topup_fees()` added nothing;
> 5. `worker_auto_mini_refill.js` executed them and **contained no wallet debit at all**.
>
> Net effect: a free year of airtime bought at KeepSIMs' expense, reachable with the anon key that ships in the APK plus a sign-up.
>
> **A second, independent hole in the same function:** `v_expires` trusted a caller-supplied `p_plan_expires_at`. Even a genuinely paid user could pass `now() + 10 years` and queue all 400 executions instead of the ~12 their plan bought — roughly $1,000 of airtime per line at a $2.50 minimum.

**Both are now closed:**

```sql
-- 1. payment is verified, not assumed
IF v_role IS DISTINCT FROM 'service_role' THEN
  IF NOT has_paid_premium_entitlement(p_sim_line_id) THEN
    RAISE EXCEPTION '… no paid, unexpired premium plan …' USING ERRCODE = 'KS403';
  END IF;
END IF;

-- 2. the horizon parameter NARROWS only
v_expires := COALESCE(v_line.plan_expires_at, p_start_at + 365 days);
IF p_plan_expires_at IS NOT NULL AND p_plan_expires_at < v_expires THEN v_expires := p_plan_expires_at; END IF;
IF v_expires > p_start_at + 370 days THEN v_expires := p_start_at + 370 days; END IF;
```

`has_paid_premium_entitlement(line)` 🔒 returns true only when the line is `plan_type='premium'`, `plan_expires_at > now()`, **and** one of: a `premium_entitlement_grandfather` row, a `plan_payments (kind='plan')` row, or a `wallet_transactions (type='plan_fee_debit')` row — either dated within `plan_expires_at − 366 days`.

`premium_entitlement_grandfather` is deny-all with a `service_role`-only grant; adding a row is a deliberate act with a mandatory `reason` and there is no client path.

### 7. Edge Cases, Security Risks & Failure Handling

- **Idempotency of the wallet rail** is the `reference_id` probe *plus* `uq_wallet_transactions_plan_fee_ref`. A retry with the same reference returns `{already_paid:true}` and does not double-charge; a concurrent duplicate hits the unique index and rolls back.
- ⚠️ **`pay_plan_fee_from_wallet` sets `plan_expires_at` but not `plan_type`.** It relies on the line having been inserted as `premium`. Combined with the I2b lesson, this means the *label* and the *payment* are set by different statements — `has_paid_premium_entitlement` is what re-couples them, and it must stay in every path that spends on a premium line's behalf.
- **The PayPal rail's tier update is exception-wrapped.** A failure writes `system_alerts('plan_tier_update_failed')` and the payment still records. The user is charged and the line is not upgraded — recoverable, and visible.
- ⚠️ **The J8 saga: charged-but-no-line.** The root cause was in Flutter, not SQL: `builder: (context)` shadowed `State.context`, so a post-pop `ScaffoldMessenger.of()` threw *between* the plan debit and the line insert. `State.mounted` never guards another element's context. The database was correct throughout; every money path with a subsequent write must be treated as needing a server-side transaction or an idempotent resume, not a client-side sequence.
- **J8b: gateway fee absorption.** Buying premium through a *deposit* makes KeepSIMs absorb the PayPal cut, because the checkout opened for the net while the button quoted the gross. The fallback is now a `kind:'plan'` charge, and `quote_plan_price` grosses up with the real `payment_gateways` rates.
- **One unpaid premium line is still live** (owner decision, grandfathered).
- **`plan_price_net` is `service_role`-only on purpose.** It reveals the margin model (`PREMIUM_MARGIN_PERCENT`, `PREMIUM_MARGIN_PER_REFILL_USD`, supplier cost). Clients get only `quote_plan_price`, which returns a single number.

---

## Scenario E2 — Server-Enforced Plan Tiers & Channel Entitlement

### 1. Scenario Overview
"Plan tier" is enforced in four independent places, none of which trusts the client:

| Enforcement | Where | Mechanism |
|---|---|---|
| One free line per account | `sim_lines` BEFORE INSERT/UPDATE | `check_free_lines_limit()` |
| `plan_type` / `plan_expires_at` immutability | `sim_lines` BEFORE UPDATE | `trg_fn_prevent_sim_line_plan_tampering()` |
| Tier set only by a payment | `plan_payments` AFTER INSERT | `trg_fn_apply_plan_tier_from_payment()` |
| Channel entitlement (WhatsApp / Telegram / SMS) | `notifications` AFTER INSERT | `trg_fn_dispatch_notification()` + `notification_channel_catalog.min_tier` |

### 2. Tables & Columns Read

| Guard | Reads |
|---|---|
| free-line | `sim_lines count(*) WHERE user_id = NEW.user_id AND plan_type='free' AND id <> NEW.id` |
| tamper | `current_user` (the Postgres role, **not** the JWT role) |
| tier-from-payment | `plan_payments.metadata->>'plan'`, `sim_lines.user_id` |
| channel | `sim_lines.protection_tier` else `profiles.subscription_tier`; `notification_channel_catalog (is_globally_enabled, min_tier)`; `alert_settings.channels`; `notification_channels.is_enabled` |
| premium queue | `has_paid_premium_entitlement()` → `sim_lines`, `premium_entitlement_grandfather`, `plan_payments`, `wallet_transactions` |

### 3. Tables & Columns Written
`sim_lines.plan_type`, `plan_expires_at` (by trigger or `pay_plan_fee_from_wallet` only); `notifications.delivered_via` (narrowed channel list); `system_alerts` on a failed tier update.

### 4. Functions & Triggers Executed

```sql
-- The tamper guard, verbatim
IF (NEW.plan_type IS DISTINCT FROM OLD.plan_type
    OR NEW.plan_expires_at IS DISTINCT FROM OLD.plan_expires_at) THEN
  IF current_user NOT IN ('service_role', 'postgres', 'supabase_admin') THEN
    RAISE EXCEPTION 'Direct modification of plan_type or plan_expires_at is forbidden.'
      USING ERRCODE = 'KS403';
  END IF;
END IF;
```

> [!IMPORTANT]
> This trigger is `SECURITY INVOKER` and tests **`current_user`**, the Postgres role — which is exactly right, because inside a `SECURITY DEFINER` function `current_user` becomes the definer (`postgres`), so `pay_plan_fee_from_wallet` can legitimately set `plan_expires_at` while a direct PostgREST `UPDATE` as `authenticated` cannot. Had it tested the JWT role instead, the RPC would have been blocked too.

**Channel narrowing** (from §0.8): a `basic` tier collapses the channel set to `{push}` regardless of what the user has enabled. `notification_channel_catalog.min_tier` records the intended floor per channel (WhatsApp/SMS are the paid ones), and `monthly_quota` bounds volume.

### 5. RLS & Grant Lockdown

| Surface | State |
|---|---|
| `sim_lines` UPDATE | **no grant** for `authenticated` (§0.1) — so the tamper trigger is a second line of defence, not the only one |
| `sim_lines` INSERT | granted, and **this is the column-level hole I2b exploited**; the mitigation is `has_paid_premium_entitlement`, not the grant |
| `plan_payments` | `SELECT` own only ⛔ |
| `notification_channel_catalog` | `SELECT` only; `admin_update_channel()` 🔒 is the write path |
| `premium_entitlement_grandfather` | deny-all, `service_role` grant only |

> [!WARNING]
> ⚠️ **The insert-side gap is still structurally open.** `authenticated` can still `INSERT` a `sim_lines` row claiming `plan_type='premium'`. Nothing *spends* on that claim any more (the entitlement guard), and nothing else reads `plan_type` as an authorisation, but the label itself is still user-writable. The clean fix is a `BEFORE INSERT` arm on `trg_fn_prevent_sim_line_plan_tampering` forcing `plan_type='free'` for non-privileged `current_user`, or revoking column-level INSERT on those two columns.

### 6. Code Path

```
client insert sim_lines           → check_free_lines_limit (free-tier cap)
client update sim_lines plan_*    → 42501 (no grant) → and KS403 if it ever gets a grant
payment (either rail)             → plan_type / plan_expires_at set server-side
queue_premium_refill_executions   → has_paid_premium_entitlement or KS403
notification insert               → tier narrows channels → dispatch-alert
```

### 7. Edge Cases, Security Risks & Failure Handling

- **The dead-guard lesson.** This project has shipped a security guard as dead code five times. The patterns to check for any new guard: (1) it tests the wrong role (`current_user` vs JWT role); (2) it is `BEFORE UPDATE` when the attack is an INSERT (exactly I2b); (3) the table grant makes it unreachable so nobody notices it never fires; (4) it is `SECURITY DEFINER` so the identity it reads is the definer's; (5) the RPC that bypasses it is granted to `authenticated`. **Read this list before writing a new guard.**
- **Grandfathering must be explicit.** `premium_entitlement_grandfather` exists so that lines predating the guard keep working, with a written `reason` per row — rather than weakening the guard for everyone.
- **Expiry is a read, not a job.** `has_paid_premium_entitlement` checks `plan_expires_at > now()` at call time. There is no cron that downgrades expired premium lines; they simply stop being able to queue. A line can therefore read as `plan_type='premium'` while being functionally expired — the UI must use the entitlement, not the label.
- **A tier change does not re-dispatch past notifications.** `delivered_via` is stamped at insert; upgrading mid-flight does not resend.

---

## Scenario E3 — Household Groups & Monthly Spend Caps

### 1. Scenario Overview
A household lets a **manager** spend the **owner's** wallet on the owner's lines, within a monthly and optional per-transaction cap. The design decision that makes it safe: the cap is checked against **committed + in-flight** spend, so two concurrent refills cannot both fit under the same remaining balance.

Roles: `viewer` (read-only) and `manager` (may act). `invite_status` ∈ `{pending, accepted, declined}`.

### 2. Tables & Columns Read

**`household_spend_mtd(owner, member, exclude_execution_id)`** 🔒 — three CTEs:

| CTE | Source | Logic |
|---|---|---|
| `debits` | `wallet_transactions ⋈ wallets` | `w.user_id = owner`, `status='completed'`, `created_at >= date_trunc('month', now() AT TIME ZONE 'UTC')`, **`metadata->>'spent_by' = member`**, `type IN ('topup_debit','welcome_home_debit','plan_fee_debit')` |
| `refunds` | `wallet_transactions` | `type IN ('refund','esim_purchase_refund')` whose `reference_id` matches one of the debits |
| `in_flight` | `topup_executions` | `acting_user_id = member AND user_id = owner`, this month, `status IN ('pending','pending_payment','routing','processing')`, `payment_gateway_code='wallet'`, **and no completed `wallet_transactions` with `reference_id = 'exec_' || te.id`** |

Returns `(committed_usd, in_flight_usd, total_usd)`, with `committed = GREATEST(debits − refunds, 0)`.

Served by `topup_executions_acting_user_month_idx (acting_user_id, user_id, created_at) WHERE acting_user_id IS NOT NULL`.

**`household_spend_check(owner, member, amount, exclude_execution)`** 🔒 returns `(allowed, reason, monthly_cap, per_txn_cap, spent_mtd, remaining_usd)` with ordered refusals:

```
NOT_A_MEMBER → INVITE_NOT_ACCEPTED → NOT_A_MANAGER → NO_CAP_SET
             → OVER_PER_TXN_CAP → OVER_MONTHLY_CAP → OK
```

### 3. Tables & Columns Written

| Action | Write |
|---|---|
| invite | `household_members (owner_id, member_email, role, invite_status='pending')` `ON CONFLICT (owner_id, member_email) DO NOTHING`; `notifications` to the invitee if they already have an account |
| respond | `invite_status`, `member_id = auth.uid()`, `accepted_at`; `notifications` back to the owner |
| set cap | `monthly_cap_usd, per_txn_cap_usd, cap_updated_at, cap_updated_by` |
| leave | `leave_household(membership_id)` 🔒 |
| spend | `wallet_transactions.metadata = {spent_by, spent_for_owner, household:true}` |

### 4. Functions, RPCs & Triggers Executed

| Object | Grant | Notes |
|---|---|---|
| `invite_household_member(email, role)` 🔒 | `authenticated` | email regex, role whitelist, self-invite refused, suspension check |
| `respond_to_household_invite(invite_id, accept)` 🔒 | `authenticated` | `FOR UPDATE`, matches on `member_id` **or** `lower(member_email) = lower(jwt.email)` |
| `set_household_member_cap(row, monthly, per_txn)` **🔓 SECURITY INVOKER** | `authenticated` | so RLS decides which rows it may touch |
| `leave_household(id)` 🔒 | `authenticated` | |
| `household_spend_summary()` 🔒 / `my_household_allowances()` 🔒 | `authenticated` | owner-side and member-side views |
| `resolve_household_payer(actor, line_owner)` 🔒 | `service_role` | who pays |
| `household_spend_check` / `household_spend_mtd` 🔒 | `service_role` | enforcement |
| `trg_household_cap_requires_manager` 🔓 BEFORE INSERT/UPDATE OF `monthly_cap_usd, role` | | `KS402` if `monthly_cap_usd > 0 AND role <> 'manager'` |
| `trg_household_member_id_matches_email` 🔓 BEFORE INSERT/UPDATE | | `member_id` must match the profile behind `member_email` |
| `handle_new_household_member()` 🔒 BEFORE INSERT | | resolves an existing account to `member_id` |
| `claim_pending_household_invites` / `resolve_pending_household_invites` 🔒 | | AFTER INSERT on `profiles` — a later sign-up claims its pending invites |

**`resolve_household_payer`** is the pivot that decides whose wallet is charged:

```sql
CASE WHEN actor = line_owner THEN actor
     WHEN EXISTS (accepted manager row for (line_owner, actor) with monthly_cap_usd > 0)
          THEN line_owner            -- ← the owner pays
     ELSE actor END                  -- ← fall back to the actor's own wallet
```

**Enforcement is doubled.** `request_instant_refill` calls `household_spend_check` **after** inserting the execution (excluding itself), and `debit_wallet_for_topup` calls it again at debit time (also excluding the execution being paid for). Both raise `KS402` with `HOUSEHOLD_CAP:<reason>:<cap>:<spent>:<remaining>`.

### 5. RLS & Grant Lockdown

| Table | Policies |
|---|---|
| `household_members` | `Owners can manage household members` — `ALL`, `auth.uid() = owner_id AND NOT is_user_suspended()`; `Members can view their invites` — SELECT, `member_id = auth.uid() OR lower(member_email) = lower(jwt.email)` |
| `sim_lines` | SELECT for accepted members; UPDATE only for accepted **managers** |
| `scheduled_topups` | SELECT for accepted members; ALL for accepted **managers** |
| `topup_executions` | SELECT for accepted members |
| `line_activity_log` | SELECT for accepted members |
| `sim_line_usage_forecast` | SELECT for accepted members |

> [!IMPORTANT]
> `set_household_member_cap` is deliberately **SECURITY INVOKER** — the `UPDATE household_members WHERE id = $1` is filtered by the owner-only RLS policy, so a member cannot raise their own cap even though the function is granted to `authenticated`. Making it `SECURITY DEFINER` would bypass that policy and require re-implementing the ownership check by hand. This is the correct pattern for "the RLS policy already says the right thing".

The cap trigger's `KS402` is caught by `set_household_member_cap`'s exception handler and converted into a readable `ROLE_REQUIRED` response.

### 6. Code Path

```
Owner  → rpc invite_household_member(email, 'manager')      → household_members(pending) + notification
Member → rpc respond_to_household_invite(id, true)          → accepted, member_id bound
Owner  → rpc set_household_member_cap(row, 100.00, 25.00)   → RLS-filtered UPDATE (+ manager-role trigger)
Member → rpc request_instant_refill(owner's line, …)
           resolve_household_payer → owner pays
           INSERT topup_executions (user_id = owner, acting_user_id = member)
           household_spend_check(owner, member, amount, exclude=this execution)  → KS402 or OK
Worker → debit_wallet_for_topup(owner, …, 'exec_<id>')
           re-runs household_spend_check → metadata{spent_by, spent_for_owner}
```

### 7. Edge Cases, Security Risks & Failure Handling

- **In-flight accounting is the race defence.** `in_flight` counts wallet-funded executions that have **no completed debit yet** — so two managers refilling simultaneously both see the other's pending execution in `total_usd` and the second is refused. `p_exclude_execution_id` prevents an execution from counting against itself.
- **The double check is not redundant.** The first (in `request_instant_refill`) fails fast, before the provider is involved; the second (in `debit_wallet_for_topup`) catches a cap that was *lowered* between queueing and execution — which matters for `refill_mini` rows queued months earlier.
- ⚠️ **`request_instant_refill` checks the cap *after* the INSERT and raises `KS402`.** The `RAISE` aborts the whole RPC transaction, so the execution row is rolled back — correct, but it means execution ids are consumed on refusal, and `in_flight` briefly counts a row that will not survive. In a concurrent burst this makes the check slightly *stricter* than the true remaining balance, which is the safe direction.
- **`monthly_cap_usd = 0` means "no spending", not "unlimited".** `household_spend_check` returns `NO_CAP_SET` and refuses, and `resolve_household_payer` falls back to the *actor's own* wallet — so a capless manager spends their own money rather than the owner's. Fail-closed on the owner's funds.
- **Month boundary is UTC.** `date_trunc('month', now() AT TIME ZONE 'UTC')`. A user in UTC+8 sees their cap reset at 08:00 local on the 1st. Document it or convert to the owner's timezone.
- **Refunds reduce committed spend** only when the refund's `reference_id` matches a debit's — which holds for the `exec_<uuid>` convention. A refund issued with a different reference will not restore the manager's headroom.
- **Email-based invites are claimable later.** An invite to an address with no account sits `pending` until that address signs up, at which point `claim_pending_household_invites` binds `member_id`. The `trg_household_member_id_matches_email` trigger prevents binding a `member_id` whose profile email does not match — closing the "invite `alice@x` then bind Bob's uuid" attack.

---
# CATEGORY F — Instant, Offline & Inbound-Command Top-Ups

---

## Scenario F1 — Instant Manual Top-Up from the App

### 1. Scenario Overview
The user opens a line, picks an offer, and taps refill. `request_instant_refill()` 🔒 is the single entry point: it authorises, prices, risk-checks, routes and enqueues — **without moving money**. The debit happens later, in the worker.

### 2. Tables & Columns Read

| Step | Table | Filter |
|---|---|---|
| 1 | `profiles` | `id = auth.uid() AND is_suspended` |
| 2 | `system_configs` | `RATE_LIMIT_INSTANT_REFILL` |
| 3 | `sim_lines` ⋈ `household_members` | line is the caller's, **or** the caller is an accepted `manager` on the owner |
| 4 | `supplier_candidates()` → `carrier_provider_map ⋈ supplier_policy ⋈ provider_offers_cache` | `is_enabled`, `is_globally_enabled`, `refreshed_at >= now() - 24h` |
| 5 | `provider_offers_cache` | `(api_provider, country_code, carrier_code, offer_id)` — **`provider_offers_cache_pkey`** and `idx_provider_offers_cache_catalog` |
| 6 | risk | `user_devices`, `device_money_events`, `payment_methods`, `paypal_orders` |
| 7 | `household_members`, `topup_executions`, `wallet_transactions` | `household_spend_check` |

Client-facing offer list: `list_refill_offers(sim_line_id)` 🔒 (`authenticated`) returns `provider, offer_id, offer_name, price_type, price_fixed_usd, price_min/max_usd, send_min/max, send_currency, send_currency_divisor, refreshed_at, is_stale`.

### 3. Tables & Columns Written

```sql
INSERT INTO topup_executions (
  sim_line_id, user_id, acting_user_id, amount, base_cost_usd, payment_gateway_code,
  currency='USD', status='pending', execution_type='refill_instant', execution_time=now(),
  offer_id, offer_value, api_provider, attempted_providers = ARRAY[<picked provider>]
) RETURNING id, amount;
```

`user_id` is the **payer** (`resolve_household_payer`), `acting_user_id` is the manager when they differ. `route_topup_execution()` then flips `status → 'routing'` in the same BEFORE trigger, and `calculate_topup_fees()` fills the fee columns.

Also written: `device_money_events` (one row, always), `line_activity_log ('topup_requested')`, and `rate_limit_buckets`.

### 4. Functions, RPCs & Triggers Executed

Order inside `request_instant_refill(sim_line, offer_id, gateway_code, amount_usd, device_id)`:

```
1.  auth.uid() NOT NULL                       → 'Authentication required'
2.  profiles.is_suspended = false             → 'Account is suspended. Refills are disabled.'
3.  enforce_rate_limit('instant_refill', uid) → KS429
4.  ownership OR accepted household manager   → 'Not authorized to refill this SIM line'
5.  choose_supplier_for_offer(line, offer, NULL)
       NOT FOUND → distinguish 'no online top-up catalog' from 'offer not available'
6.  read the offer from provider_offers_cache for the CHOSEN provider
7.  refreshed_at >= now() - 24h               → 'Offer pricing is temporarily unavailable'
8.  FIXED  → base = price_fixed_usd
    RANGE  → require p_amount_usd, clamp to [min-0.01, max+0.01],
             offer_value = interpolate_offer_value(send_min, send_max, price_min, price_max, base)
9.  guard_money_action('instant_refill', base, device, NULL, uid)
       blocked → RAISE KS451 'DEVICE_BLOCKED:<reason>'
10. resolve_household_payer(uid, line_owner)  → payer, acting
11. INSERT topup_executions                   → BEFORE triggers: rate limit, fees, routing
12. IF acting IS NOT NULL → household_spend_check(payer, acting, charged, this execution)
       not allowed → RAISE KS402 'HOUSEHOLD_CAP:…'
13. RETURN execution_id
```

Then the worker (`worker_instant_refill.js`) claims it with `claim_instant_executions('refill_instant', N)` and follows D4.

### 5. RLS & Grant Lockdown

- `request_instant_refill` 🔒 is granted to `authenticated` — the entire authorisation model lives inside it (steps 1–4, 9, 12).
- `topup_executions` is `SELECT`-only for clients, so the RPC is the only way a refill can be created.
- `provider_offers_cache` is `SELECT`able by `authenticated`, which is how the client renders the offer list; it holds no margin data.
- `interpolate_offer_value` 🔓 is `service_role`-EXECUTE only — a client cannot probe the send-value mapping.

### 6. Code Path

```
Line detail → rpc list_refill_offers(line)
            → user picks offer (+ amount for RANGE)
            → PaymentAuthGuard (biometric / PIN)
            → rpc request_instant_refill(line, offer, gateway, amount, device_id)
                 → execution_id, status='routing'
            → realtime subscribe topup_executions
worker_instant_refill.js
            → claim_instant_executions → debit_wallet_for_topup → provider → update_execution_status
```

### 7. Edge Cases, Security Risks & Failure Handling

- **Queue-then-pay, not pay-then-queue.** The RPC returns before any money moves. The user sees "queued", and a failure at the debit stage surfaces as a failed execution with a reason — not as a silent charge.
- ⚠️ **The cap check runs after the INSERT** (see E3) — the `RAISE` rolls the RPC back, so no execution survives a `KS402`, but the id is consumed.
- **Two error shapes for the same class of problem.** `KS451` (device) and `KS402` (household) both `RAISE`, while `pay_plan_fee_from_wallet` *returns* its device block. Client code must handle both shapes.
- **The 24-hour staleness check uses the offer row for the chosen provider,** which was already filtered on `refreshed_at` inside `supplier_candidates`. The second check is defence in depth against a cache row expiring between the two reads.
- **RANGE tolerance is ±0.01** to absorb client-side rounding. `interpolate_offer_value` then converts USD to the destination's minor unit; `send_currency_divisor` (default 100) is applied at display, so a 1-unit rounding difference is possible between the quote and the delivered value.
- ⚠️ **Admin price overrides do not apply here** — `supplier_candidates` reads `provider_offers_cache`, not the curated `provider_offers` shelf (see D3).
- **`payment_gateway_code` is caller-supplied** and stored unvalidated. It affects `calculate_topup_fees()`. A client passing an unexpected code could alter the computed fees; validating it against `payment_gateways.code` inside the RPC would close that.

---

## Scenario F2 — Inbound SMS / WhatsApp Command Router

### 1. Scenario Overview
A user with no data can text `BAL` or `REFILL 10` to a KeepSIMs number. The webhook hands the raw message to `handle_inbound_command()` 🔒, which classifies it, resolves the sender to an account **by phone number alone**, and either answers or queues a top-up. Every inbound message and every reply is logged.

Supported channels: `whatsapp`, `sms`, `missed_call`.

### 2. Tables & Columns Read

| Table | Purpose | Index |
|---|---|---|
| `offline_command_log` | duplicate probe on `(provider, provider_msg_id)` | **`offline_command_log_provider_msg_unique`** |
| `profiles.phone` | sender resolution, pass 1 & 2 | seq scan on 8 rows today ⚠️ |
| `sim_lines.phone_number` | sender resolution, pass 3 & 4 | seq scan ⚠️ |
| `offline_refill_settings` | `is_enabled, target_sim_line_id, default_refill_amount` | `user_id` |
| `wallets`, `sim_lines`, `sim_line_usage_forecast` | `build_balance_reply` | |
| `offline_refill_endpoints` | which numbers to publish to the app | `is_active` |

**`resolve_sender_user(phone)`** 🔒 — four passes, each requiring a **unique** match:

```
normalise to digits; reject if < 9 digits
1. profiles.phone   exact digits            → 1 match ⇒ user; >1 ⇒ NULL (ambiguous, refuse)
2. profiles.phone   last-9 digits           → 1 match ⇒ user; >1 ⇒ NULL
3. sim_lines.phone_number exact digits      → 1 match ⇒ user; >1 ⇒ NULL
4. sim_lines.phone_number last-9 digits     → 1 match ⇒ user
otherwise NULL
```

**`classify_inbound_command(body)`** 🔓 — English + Arabic, plus a bare-amount shortcut:

| Pattern | Command |
|---|---|
| empty | `help` |
| `^(STOP\|UNSUBSCRIBE\|CANCEL\|QUIT\|END)\M` | `stop` |
| `^(BAL\|BALANCE\|STATUS\|INFO)\M` or `رصيد%` | `balance` |
| `^(REFILL\|TOPUP\|TOP UP\|RECHARGE)\M` or `شحن%` or `^\$?\d+(\.\d{1,2})?$` | `refill` |
| anything else | `help` |

### 3. Tables & Columns Written

| Table | Row |
|---|---|
| `offline_command_log` | **always** — `(provider, provider_msg_id, channel, sender_phone, command, user_id, reply_text, outcome)` |
| `offline_refill_events` | one per refill attempt — `(provider, provider_msg_id, channel, sender_phone, raw, user_id, sim_line_id, status, reject_reason, execution_id)` |
| `offline_refill_settings` | `is_enabled = false` on `STOP` |
| `topup_executions` | the queued refill (`refill_channel` records the origin) |
| `rate_limit_buckets` | `offline_command` bucket: capacity 10, refill 10/60 per minute |

`outcome` ∈ `{unknown_sender, rate_limited, stopped, channel_disabled, answered, queued, duplicate, …}`.

### 4. Functions & Triggers Executed

```
webhook (sms-webhook | waba-webhook | twilio-voice-webhook)
 → handle_inbound_command(provider, msg_id, sender, channel, body, raw)
      channel whitelist                        → RAISE on unknown channel
      duplicate probe on (provider, msg_id)    → {status:'duplicate', replays the SAME reply}
      classify_inbound_command(body)
      resolve_sender_user(sender)              → NULL ⇒ log 'unknown_sender', reply nothing
      consume_rate_limit('offline_command', user, 10, 10/60)
      STOP      → offline_refill_settings.is_enabled = false
      disabled  → "Enable Offline Refill in the app"
      BAL       → build_balance_reply(user)
      REFILL    → ingest_offline_refill(...)
 → INSERT offline_command_log(reply_text, outcome)
```

**`ingest_offline_refill()`** 🔒 in turn: dedupes on `offline_refill_events (provider, provider_msg_id)`; rejects `no_sender`, `unknown_sender`, `disabled`, `no_target`, `no_offer`; resolves the target line (explicit `target_sim_line_id`, else the user's **single** active line, else reject); floors the amount through `carrier_refill_offer(carrier, requested)`; and queues the execution.

**`build_balance_reply()`** 🔒 composes an SMS-shaped answer: wallet balance, the **three** lines closest to depletion (masked as `****1234` when there is no nickname), a `+N more` suffix, and `Reply REFILL to top up.`

### 5. RLS & Grant Lockdown

| Table | State |
|---|---|
| `offline_command_log` | **deny-all** (RLS on, zero policies), `service_role` grant only — it holds raw sender phone numbers |
| `offline_refill_events` | `service_role` only |
| `offline_refill_settings` | own-row SELECT/INSERT/UPDATE for `authenticated` |
| `offline_refill_endpoints` | `SELECT` where `is_active` for `authenticated`; writes via `admin_upsert_offline_endpoint()` 🔒 |

`handle_inbound_command`, `ingest_offline_refill`, `resolve_sender_user`, `build_balance_reply` are all `service_role`-EXECUTE — only a webhook can reach them.

> [!NOTE]
> `trg_offline_endpoints_sync` is a **statement-level** AFTER trigger → `sync_offline_endpoint_configs()` 🔒, which mirrors the primary row per channel into the matching `system_configs` key (`OFFLINE_SMS_NUMBER`, `OFFLINE_WHATSAPP_NUMBER`, `OFFLINE_IVR_NUMBER`). The offline screen reads that key through a **local cache** — which is the whole point of that screen (it must work with no data) and must not be broken by moving the data.

### 6. Code Path

```
User texts "REFILL 10"
 → Twilio / WABA → Edge Fn sms-webhook | waba-webhook
      (rate bucket webhook_ip)
 → rpc handle_inbound_command(provider, msg_id, from, channel, body, raw)
      → classify → resolve → ingest_offline_refill → topup_executions('pending')
      → returns reply_text
 → webhook sends the reply SMS/WhatsApp
 → worker executes the queued refill (D4)
```

### 7. Edge Cases, Security Risks & Failure Handling

> [!WARNING]
> **Caller ID is the only authentication on this channel.** SMS sender numbers are spoofable. The mitigations are: (1) the sender must resolve to **exactly one** account — any ambiguity returns NULL and the message is ignored; (2) offline commands are **off by default** (`offline_refill_settings.is_enabled = false`); (3) the amount is capped (`> 500` is discarded and the default is used); (4) the target line must already belong to that account; (5) a 10-message bucket per user. A spoofer can therefore, at most, cause a legitimate user's own line to be topped up from that user's own wallet — annoying, not extractive. **Do not add any command that moves money to a new destination on this channel.**

- **Idempotency is provider-message-scoped.** `(provider, provider_msg_id)` is unique, so a provider retry **replays the same stored reply** rather than re-running the command. This is why `reply_text` is stored, not just the outcome.
- **Two dedupe layers.** `offline_command_log` dedupes the *command*; `offline_refill_events` dedupes the *refill*. Both keyed on the same provider message id.
- **`STOP` works even when the channel is disabled** — it is evaluated before the `is_enabled` check, which is required by SMS regulations.
- **Ambiguous numbers fail closed.** Two profiles sharing a phone number resolve to NULL, and the user gets no reply at all. That is deliberate (replying would confirm the number is registered), but it is also indistinguishable from "not a user" — support needs `offline_command_log.outcome = 'unknown_sender'` to diagnose it.
- **Last-9-digit matching is a heuristic.** It exists because users text from `+968…` while their profile stores `00968…`. It can theoretically match a different country's subscriber; the uniqueness requirement is what makes that safe.
- ⚠️ **No index supports sender resolution.** All four passes are sequential scans with `regexp_replace` per row. At 8 profiles this is free; at scale it is four full scans per inbound message. Add expression indexes: `ON profiles ((regexp_replace(phone,'\D','','g')))` and the same on `sim_lines.phone_number`, plus `right(...,9)` variants.
- **Missed-call channel has no body,** so it classifies as `help` unless the router special-cases it — verify before enabling `missed_call` in production.

---

# CATEGORY G — eSIM Catalogue, Purchase & Affiliate Rail

---

## Scenario G1 — Browsing the eSIM Catalogue & the Roam-vs-eSIM Calculator

### 1. Scenario Overview
Two read paths. `compare_esim_offers()` 🔒 merges **owned inventory** (`esim_offers_cache`, marked up) with **affiliate offers** (`affiliate_offers`, retail) into one ranked list. `roam_or_esim_quote()` 🔓 answers a different question: *is my own carrier's roaming pass cheaper than buying an eSIM?*

### 2. Tables & Columns Read

**`compare_esim_offers(country, coverage, min_data_mb, min_days, max_price, unlimited_only, speed_tiers[], sort, limit, offset)`** 🔒:

| Table | Columns | Index |
|---|---|---|
| `esim_offers_cache` | `provider, bundle_name, countries[], roaming_enabled[], data_amount_mb, duration_days, wholesale_price_usd, is_unlimited, speed_tier, region, country_count, is_active` | **`idx_esim_offers_cache_countries` (GIN)**, `idx_esim_offers_cache_active_price` |
| `affiliate_offers ⋈ affiliate_partners ⋈ affiliate_networks` | `price_usd, list_price_usd, coupon_code, landing_url, countries[], is_active, price_checked_at` | |
| `system_configs` | `ESIM_MARKUP_PERCENT` (30.0), `AFFILIATE_ENABLED`, `AFFILIATE_PRICE_MAX_AGE_DAYS` | |

Returned rows carry `action` (`purchase` for owned, `click` for affiliate), `price_is_stale`, and `disclosure_required`. 5 412 rows in `esim_offers_cache`.

**`roam_or_esim_quote(country, days, data_mb, carrier_id)`** 🔓 reads `carrier_roaming_rates` (16 rows; `destination_country_code = '*'` is a worldwide pass) and `esim_offers_cache`, returning both totals, `savings_usd` and a `verdict`. `my_roaming_carriers(country)` 🔓 lists the user's own carriers and whether a rate exists.

### 3. Tables & Columns Written
Browsing writes nothing. The **catalogue sync** writes `esim_offers_cache`, which fires two AFTER triggers:

| Trigger | Effect |
|---|---|
| `trg_esim_offer_country_count` (BEFORE INSERT/UPDATE OF `countries, roaming_enabled, data_amount_mb`) 🔓 | maintains `country_count` |
| `trg_esim_offers_price_history_ins` / `_upd` 🔒 | appends to `offer_price_history` when `wholesale_price_usd`, `data_amount_mb` or `duration_days` change |

```sql
INSERT INTO offer_price_history (source='esim', offer_key = provider||'|'||bundle_name,
    countries, data_amount_mb, duration_days, price_usd = wholesale_price_usd);
```

Sync state lives in `esim_suppliers (last_sync_at, last_sync_status, last_sync_count, last_sync_error)`.

### 4. Functions & Triggers Executed

| Object | Grant |
|---|---|
| `compare_esim_offers` 🔒 | `authenticated` |
| `roam_or_esim_quote` 🔓, `my_roaming_carriers` 🔓 | `authenticated` |
| `kick_esim_catalogue_sync()` 🔒 | `service_role`; 03:40 cron → `net.http_post /functions/v1/sync-esim-catalogue` |
| `admin_sync_esim_catalogue(note)` 🔒 | manual trigger + audit |
| `refresh_provider_offers()` 🔒 | 04:30 cron; rebuilds the curated `provider_offers` shelf from every source |
| `prune_offer_price_history()` 🔒 | keeps `PRICE_HISTORY_RETENTION_DAYS` |

### 5. RLS & Grant Lockdown

| Table | Access |
|---|---|
| `esim_offers_cache` | ⚠️ **full CRUD grant** to `anon` and `authenticated`, with **no policies at all** — RLS denies everything, so reads go through `compare_esim_offers` 🔒 and the `esim_offers` view |
| `esim_offers` (view) | `SELECT` for `anon` + `authenticated` — the public lens (no wholesale price) |
| `offer_price_history` | **deny-all**, `service_role` only — it holds wholesale eSIM prices |
| `carrier_roaming_rates` | `SELECT` where `is_active` for `authenticated`; `bundle_price_usd` is a generated column |
| `esim_suppliers` | `service_role` only |

> [!IMPORTANT]
> **Wholesale price is the crown jewel here.** `esim_offers_cache.wholesale_price_usd` and `offer_price_history` reveal supplier cost and therefore margin. Both are unreachable by clients: the cache has no RLS policy (deny-all despite the grant), and the history table is `service_role`-only. Everything the client sees is post-markup, computed inside a SECURITY DEFINER function.

> [!WARNING]
> ⚠️ `esim_offers_cache` still carries `INSERT/UPDATE/DELETE` grants for `anon`/`authenticated`. Zero policies means RLS blocks them today, but this is a table whose prices feed both the retail calculation and the price-drop alerts. Revoke the grants.

### 6. Code Path

```
03:40 cron → kick_esim_catalogue_sync() → Edge Fn sync-esim-catalogue
               → upsert esim_offers_cache  → country_count trigger + price-history trigger
               → esim_suppliers.last_sync_*
04:30 cron → refresh_provider_offers()     → rebuild provider_offers (source_* only; override_* untouched)
App        → rpc compare_esim_offers(country, filters…)  → merged owned + affiliate list
App        → rpc roam_or_esim_quote(country, days, mb)   → verdict + savings
```

### 7. Edge Cases, Security Risks & Failure Handling

- **The override layer is sacred.** `refresh_provider_offers()` rewrites only `source_*` columns; `override_name`, `override_price_usd`, `override_is_active`, `override_note`, `overridden_by`, `overridden_at` are never touched by the nightly sync. `effective_*` is what callers read. This is what lets an operator correct a supplier's bad price without the fix being erased at 04:30.
- **Affiliate staleness is surfaced, not hidden.** `price_is_stale` is computed from `price_checked_at` against `AFFILIATE_PRICE_MAX_AGE_DAYS`; the client is expected to render it. An affiliate price nobody has verified in weeks is a customer-service incident waiting to happen.
- **GIN on `countries[]` is what makes country filtering viable** at 5 412 rows × multi-country arrays. Any new filter that cannot use it (e.g. a `LIKE` on `bundle_name`) will scan.
- **Markup is read at query time**, so changing `ESIM_MARKUP_PERCENT` re-prices the entire catalogue instantly — including `offer_watch_metrics`, which uses the same key to compute retail `$/GB` for price-drop alerts. Changing it will fire price-drop alerts as a side effect.
- **`roam_or_esim_quote` is `SECURITY INVOKER`,** so it sees only rows the caller may read — `carrier_roaming_rates` filtered by `is_active`, and `esim_offers_cache` via RLS. Verify it can actually read the cache; with zero policies on that table an INVOKER function returns nothing. ⚠️ **This is a likely dead-read: `roam_or_esim_quote` may be returning eSIM columns as NULL for every caller.** Test it against a real user JWT before relying on the verdict.

---

## Scenario G2 — Purchasing an eSIM & Provisioning the QR

### 1. Scenario Overview
`request_esim_purchase()` 🔒 creates an order and debits the wallet **synchronously**, then a worker fulfils it with the supplier and writes the eSIM profile. If fulfilment never happens, an hourly reaper refunds.

`esim_orders.status`: `pending → processing → completed | failed`.

### 2. Tables & Columns Read

| Step | Table | Filter |
|---|---|---|
| 1 | `profiles` | `id = auth.uid() AND is_suspended` |
| 2 | rate limit | bucket `esim_purchase` |
| 3 | `esim_offers_cache` | `bundle_name = p_offer_id AND is_active` `LIMIT 1` |
| 4 | `system_configs` | `ESIM_MARKUP_PERCENT` (fallback 30.0 on any error) |
| 5 | `wallets` | `balance` (pre-check, before the guard) |
| 6 | risk | `guard_money_action('esim_purchase', total, device, NULL, uid)` |

### 3. Tables & Columns Written

```sql
retail = round(wholesale_price_usd * (1 + markup/100.0), 2);
total  = retail * quantity;                                   -- quantity ∈ [1,3]

INSERT INTO esim_orders (user_id, offer_id, bundle_name, provider, quantity,
        wholesale_price_usd, retail_price_usd, markup_percent, total_amount_usd, status='pending')
  RETURNING id;

debit_wallet_for_topup(uid, NULL, total, 'eSIM Purchase: <bundle>',
                       'esim_' || order_id, 'esim_purchase_debit');
```

Fulfilment (worker) writes `esim_orders (status='completed', provider_order_ref)` and one `user_esims` row per unit: `iccid, smdp_address, matching_id, lpa_string, bundle_name, provider, status='active', data_total_mb, data_remaining_mb, expires_at`.

Nightly, `snapshot_esim_usage()` appends to `esim_usage_samples`, which drives the eSIM half of D1.

### 4. Functions & Triggers Executed

| Object | Notes |
|---|---|
| `request_esim_purchase(offer_id, quantity, device_id)` 🔒 | `authenticated` |
| `enforce_rate_limit('esim_purchase', uid)` 🔒 | |
| `guard_money_action('esim_purchase', …)` 🔒 | returns `{success:false, code:'DEVICE_BLOCKED'}` — **HTTP 200** |
| `debit_wallet_for_topup(… 'esim_purchase_debit')` 🔒 | reached via stack-depth guard |
| `reap_stale_esim_orders()` 🔒 | hourly cron |
| `credit_wallet_for_refund(… 'esim_refund_<order>', … 'esim_purchase_refund')` 🔒 | the reaper's refund |

**`reap_stale_esim_orders()`**, per order, `FOR UPDATE SKIP LOCKED`:

```sql
FOR orders WHERE status='pending' AND provider_order_ref IS NULL
                 AND created_at < now() - ESIM_STALE_ORDER_HOURS (3):
   IF a refund already exists for 'esim_refund_<id>' THEN CONTINUE;         -- idempotent
   find the completed debit 'esim_<id>' of type 'esim_purchase_debit'
   IF no debit found:
       esim_orders → failed, error_message='stale_unpaid_order_reaped'
       system_alerts('stale_esim_order_unpaid')                              -- ← paid-nothing anomaly
   ELSE:
       esim_orders → failed, error_message='stale_timeout_reaped'
       credit_wallet_for_refund(user, debit_amount, 'esim_refund_<id>', …, 'esim_purchase_refund')
```

### 5. RLS & Grant Lockdown

| Table | Policy | Grant |
|---|---|---|
| `esim_orders` | `Users can read own esim orders` (SELECT) | `SELECT` only ⛔ |
| `user_esims` | `Users can read own user esims` (SELECT) | `SELECT` only ⛔ |
| `esim_usage_samples` | deny-all | `service_role` |

> [!IMPORTANT]
> The user can **see** their orders and eSIM profiles but cannot create, modify or delete them. `lpa_string`, `matching_id` and `smdp_address` are the activation secrets — a write grant here would let a user forge a provisioned eSIM.

### 6. Code Path

```
Catalogue → rpc compare_esim_offers → user picks
          → PaymentAuthGuard
          → rpc request_esim_purchase(bundle_name, qty, device_id)
               order + wallet debit, status='pending'
worker_esim_fulfillment.js
          → supplier order → esim_orders(status='completed', provider_order_ref)
          → INSERT user_esims (lpa_string → QR)
          → heartbeat WORKER_ESIM_FULFILLMENT_HEARTBEAT (watched by check_worker_heartbeat_health)
hourly    → reap_stale_esim_orders() → refund anything still pending after 3h
```

### 7. Edge Cases, Security Risks & Failure Handling

- **Order-then-debit, in one transaction.** Both the `esim_orders` INSERT and the debit are in the RPC's transaction, so there is no "order with no payment". If the debit raises, the order disappears.
- **The refund path is doubly idempotent**: the `esim_refund_<id>` probe at the top of the loop, and `uq_wallet_txns_esim_refund_ref` underneath it.
- **`stale_esim_order_unpaid` is the anomaly alarm.** An order that reached `pending` with no completed debit should be impossible given the transaction above; if it fires, something wrote `esim_orders` outside the RPC.
- **Quantity is capped at 3** — a blunt but effective bound on the blast radius of a compromised session.
- ⚠️ **`p_offer_id` is matched against `bundle_name`, not a stable id.** `esim_offers_cache`'s PK is `(provider, bundle_name)`, and the lookup is `WHERE bundle_name = $1 AND is_active LIMIT 1` **without a provider filter**. Two suppliers shipping the same bundle name would make the purchase non-deterministic — `LIMIT 1` with no `ORDER BY` picks arbitrarily. Add the provider to the parameter or order the lookup.
- **Markup failure is silent-safe.** Any error reading `ESIM_MARKUP_PERCENT` falls back to 30.0 rather than raising — the sale completes at the default margin instead of failing.
- **Worker liveness matters here more than anywhere.** A dead fulfilment worker means every purchase is refunded 3 hours later. `check_worker_heartbeat_health()` (every 10 min) watches `WORKER_ESIM_FULFILLMENT_HEARTBEAT`.

---

## Scenario G3 — Affiliate Rail: Comparison & Click Tracking

### 1. Scenario Overview
Where KeepSIMs does not own inventory, it earns commission. `compare_esim_offers` blends affiliate rows into the same list with `action='click'`; tapping one calls `record_affiliate_click()` 🔒, which **builds the tracking URL server-side** and returns it.

Live: 3 networks, 2 partners, 0 offers, 0 clicks — the rail is wired and inert (`AFFILIATE_ENABLED` gates it).

### 2. Tables & Columns Read

`record_affiliate_click(offer_id, country_code, device_id)` 🔒:

| Table | Columns |
|---|---|
| `system_configs` | `AFFILIATE_ENABLED` → `{success:false, code:'AFFILIATE_DISABLED'}` |
| `affiliate_offers` | `id, landing_url, partner_id`, `WHERE id = $1 AND is_active` |
| `affiliate_partners` | `default_tracking_url, is_active` |
| `affiliate_networks` | `click_param, deeplink_param, is_active` |

### 3. Tables & Columns Written

```sql
v_click_id := gen_random_uuid();
v_url := default_tracking_url || ('?' or '&') || click_param || '=' || v_click_id
         [ || '&' || deeplink_param || '=' || url_encode(landing_url) ];

INSERT INTO affiliate_clicks (id = v_click_id, user_id, partner_id, offer_id,
        country_code = upper(nullif(trim(p_country_code),'')), device_id, target_url);
RETURN {success:true, click_id, url};
```

`affiliate_conversions` is written by the `sync-affiliate-network` Edge Function when the network reports a conversion, joined back on `click_id`.

`trg_affiliate_offer_normalise` 🔓 (BEFORE INSERT/UPDATE on `affiliate_offers`) normalises `countries[]` and derives `country_count`.

### 4. Functions & Triggers Executed

| Object | Grant |
|---|---|
| `record_affiliate_click` 🔒 | `authenticated`; rate bucket `affiliate_click` |
| `compare_esim_offers` 🔒 | `authenticated` |
| `url_encode(text)` 🔓 | `authenticated` |
| `kick_affiliate_sync(since_days)` 🔒 | `service_role`; 04:10 cron with `45` |
| `admin_sync_affiliate_network` / `admin_upsert_affiliate_partner` / `admin_upsert_affiliate_offer` / `admin_delete_affiliate_offer` / `admin_affiliate_overview` 🔒 | all `assert_admin()`-gated, all audited |

Refusal ladder: `UNAUTHORIZED` → `AFFILIATE_DISABLED` → `OFFER_NOT_FOUND` → `PARTNER_INACTIVE` → `NO_TRACKING_URL` → success.

### 5. RLS & Grant Lockdown

`affiliate_networks`, `affiliate_partners`, `affiliate_offers`, `affiliate_clicks`, `affiliate_conversions` — **no grants to `anon`/`authenticated` at all**. Everything the client sees comes through `compare_esim_offers` and `record_affiliate_click`.

> [!IMPORTANT]
> **The client never composes the tracking URL.** The click id is minted server-side, the URL is built from `affiliate_networks.click_param` / `deeplink_param`, and `landing_url` is `url_encode`d before being appended. A client that could build its own URL could attribute clicks to arbitrary ids — or inject a parameter into the partner's redirect.

`disclosure_required` on `affiliate_partners` flows through `compare_esim_offers` so the UI can render the required advertising disclosure. That is a legal obligation, not a nicety.

### 6. Code Path

```
Catalogue → rpc compare_esim_offers(country, …)   → rows with action='click'
User taps → rpc record_affiliate_click(offer_id, country, device_id)
              → INSERT affiliate_clicks, RETURN {url}
          → app opens the returned URL in a browser
04:10 cron → kick_affiliate_sync(45) → Edge Fn sync-affiliate-network
              → affiliate_conversions (joined on click_id), affiliate_offers refresh
```

### 7. Edge Cases, Security Risks & Failure Handling

- **The rail ships inert.** `AFFILIATE_ENABLED` defaults false; `record_affiliate_click` returns `AFFILIATE_DISABLED` before touching anything. Flipping one config row is the entire activation.
- **Click inflation** is bounded by the `affiliate_click` rate bucket and by the fact that clicks are attributed to `auth.uid()` — a network disputing volume can be answered from `affiliate_clicks` with per-user distribution.
- **`country_code` is normalised** (`upper(nullif(trim(…),''))`) so analytics do not split on `'om'` vs `'OM'` vs `' OM '`.
- **`target_url` is stored** with each click, so a later change to `default_tracking_url` does not invalidate the audit trail of what was actually opened.
- ⚠️ **No unique constraint on `affiliate_clicks`.** Double-taps create two rows and two click ids. That is arguably correct (each is a real navigation) but means conversion joins must be tolerant of the user having several open click ids for one offer.
- **Conversion reconciliation is one-directional.** The sync pulls conversions from the network; there is no local mechanism to detect a conversion the network failed to report. `admin_affiliate_overview(days)` is the review surface.

---
# CATEGORY H — Price Watch, Support Desk & Notification Dispatch

---

## Scenario H1 — Offer Price Watch & Price-Drop Alerts

### 1. Scenario Overview
Nightly at **02:40 UTC**, `refresh_offer_price_watch()` 🔒 runs three phases:

```sql
v_synced := sync_auto_price_watches();     -- keep 'auto' watches in step with live SIM lines
v_alerts := detect_offer_price_drops();    -- compare current vs baseline, notify
v_pruned := prune_offer_price_history();   -- retention
RETURN jsonb_build_object('watches_synced', …, 'alerts', …, 'history_pruned', …, 'ran_at', NOW());
```

Two watch origins: `auto` (derived from the user's active SIM lines) and `user` (created in the app, including eSIM destinations).

### 2. Tables & Columns Read

**Price history is written by triggers, not by a job:**

| Trigger | Table | Fires when |
|---|---|---|
| `trg_provider_offers_price_history_ins` / `_upd` 🔒 | `provider_offers_cache` | INSERT, or UPDATE where `price_fixed_usd`, `price_min_usd` or `price_max_usd` changed |
| `trg_esim_offers_price_history_ins` / `_upd` 🔒 | `esim_offers_cache` | INSERT, or UPDATE where `wholesale_price_usd`, `data_amount_mb` or `duration_days` changed |

Both append to `offer_price_history (source, offer_key, country_code, carrier_code, countries[], data_amount_mb, duration_days, price_usd, recorded_at)`. `offer_key` is `provider||'|'||offer_id` for top-ups and `provider||'|'||bundle_name` for eSIM. 6 198 rows live.

**`offer_watch_metrics(baseline_days)`** 🔒 computes the comparison:

| CTE | Logic |
|---|---|
| `hist_before` | `DISTINCT ON (source, offer_key)` the newest row **at or before** `now() - baseline_days` |
| `hist_first` | `DISTINCT ON (source, offer_key)` the **oldest** row overall |
| `baseline` | `hist_before`, plus `hist_first` for any offer with no pre-cutoff history — so a young offer still has a baseline |
| `topup_now` | current `provider_offers_cache` price = `COALESCE(price_fixed_usd, price_min_usd)` |
| `topup_best` | `DISTINCT ON (country_code, carrier_code)` ordered by `drop_percent DESC` — the best drop per subject |
| `esim_priced` | retail `$/GB` = `wholesale × (1 + ESIM_MARKUP_PERCENT/100) / (data_amount_mb/1024)` |

> [!NOTE]
> **Top-up watches compare a single offer's USD price; eSIM watches compare retail `$/GB` across the destination.** They are different metrics with different units, which is why `offer_price_watches.last_best_usd` is documented as *retail* for eSIM. Do not compare the two columns across sources.

### 3. Tables & Columns Written

**`sync_auto_price_watches()`** 🔒 — a two-statement reconciliation against live lines:

```sql
-- live := DISTINCT (sl.user_id, m.provider_country_code, m.provider_carrier_code)
--         FROM sim_lines sl JOIN carrier_provider_map m ON m.carrier_id = sl.carrier_id AND m.is_enabled
--         WHERE sl.status = 'active'
INSERT INTO offer_price_watches (user_id, source='topup', country_code, carrier_code, origin='auto')
SELECT … FROM live WHERE carrier_code IS NOT NULL AND country_code IS NOT NULL
ON CONFLICT DO NOTHING;                                    -- offer_price_watches_subject_uq

DELETE FROM offer_price_watches w
 WHERE w.origin = 'auto' AND NOT EXISTS (matching live row);
RETURN added + removed;
```

**`detect_offer_price_drops()`** 🔒 — first a bulk refresh of every active watch's current/baseline figures, then the alert loop:

```sql
UPDATE offer_price_watches w
   SET last_best_usd = m.current_metric, last_baseline_usd = m.baseline_metric, last_checked_at = NOW()
  FROM offer_watch_metrics(PRICE_WATCH_BASELINE_DAYS) m
 WHERE w.is_active AND m.source = w.source AND m.country_code = w.country_code
   AND COALESCE(m.carrier_code,'') = COALESCE(w.carrier_code,'');
```

Alert predicate — **all five must hold**:

```
m.drop_percent >= COALESCE(w.threshold_percent, PRICE_DROP_THRESHOLD_PERCENT)   -- default 10 %
AND (w.last_alert_at IS NULL OR w.last_alert_at < NOW() - PRICE_WATCH_COOLDOWN_DAYS)  -- default 7 d
AND (w.last_alerted_best_usd IS NULL OR m.current_metric < w.last_alerted_best_usd)   -- must beat the last alert
AND EXISTS (alert_settings WHERE user_id AND category='promo' AND is_enabled)         -- explicit opt-in
AND NOT profiles.is_suspended
```

Writes `notifications (category='promo', …)` and stamps `last_alert_at`, `last_alerted_best_usd`.

### 4. Functions & Triggers Executed

| Object | Grant |
|---|---|
| `refresh_offer_price_watch()` 🔒 | `service_role`, 02:40 cron |
| `sync_auto_price_watches()` / `detect_offer_price_drops()` / `offer_watch_metrics()` / `prune_offer_price_history()` 🔒 | `service_role` |
| `trg_fn_record_topup_price_history()` / `trg_fn_record_esim_price_history()` 🔒 | trigger-only |
| `update_updated_at()` 🔓 | `trg_offer_price_watches_updated_at` |

### 5. RLS & Grant Lockdown

| Table | Policies | Grant |
|---|---|---|
| `offer_price_watches` | SELECT/UPDATE/DELETE own; **INSERT requires `origin = 'user'`** | `SELECT, DELETE` only — **no INSERT/UPDATE grant** ⚠️ |
| `offer_price_history` | **deny-all** | `service_role` |

> [!WARNING]
> ⚠️ **The INSERT policy on `offer_price_watches` is unreachable.** The policy `Users can create own price watches` requires `origin='user'` — a well-designed guard preventing a client from forging an `auto` watch — but `authenticated` is granted only `SELECT, DELETE`. The grant is checked first, so **users cannot create price watches at all today**. Either grant `INSERT` (and let the policy do its job) or add a `create_price_watch()` RPC. Two `user`-origin rows exist, presumably created by `service_role`.

### 6. Code Path

```
Any price change  → BEFORE the row settles: price-history AFTER trigger → offer_price_history
02:40 cron        → refresh_offer_price_watch()
                       sync_auto_price_watches()   (reconcile 'auto' watches to live lines)
                       detect_offer_price_drops()  (bulk refresh, then alert loop)
                          → notifications('promo') → §0.8 dispatch
                       prune_offer_price_history() (PRICE_HISTORY_RETENTION_DAYS)
App               → select offer_price_watches (own)  → "watching Oman · Omantel"
```

### 7. Edge Cases, Security Risks & Failure Handling

- **`last_alerted_best_usd` is the anti-nag ratchet.** Without it, a price oscillating around the threshold would alert every cooldown period. The rule "must be cheaper than the last thing we alerted about" means each alert is strictly better news than the previous one.
- **`promo` opt-in is checked here *and* in the dispatcher.** `detect_offer_price_drops` skips users without an enabled `promo` `alert_settings` row, and `trg_fn_dispatch_notification` independently defaults `promo` to off when the row is absent. Marketing consent is enforced twice.
- **Baseline fallback prevents a cold start.** A brand-new offer has no history before the cutoff, so `hist_first` supplies the baseline. This means a first-day price *is* its own baseline (drop = 0), not a divide-by-NULL.
- **`DISTINCT ON` per `(country, carrier)`** means the user is alerted about the *best* drop in their subject, not about every offer that moved — one notification per subject per cooldown.
- **Deleting a line does not immediately remove its watch** — reconciliation is nightly (see B4).
- ⚠️ **`sync_auto_price_watches` returns `added + removed` as one number,** so a run that added 5 and removed 5 is indistinguishable from one that added 10. Fine for a heartbeat, useless for diagnosis; split the counters if this is ever alarmed on.
- **Price history grows with every price change on 780 + 5 412 cached offers.** `prune_offer_price_history()` and `offer_price_history_time_idx (recorded_at)` are what keep the nightly comparison viable.

---

## Scenario H2 — Support Tickets, Admin Replies & Dedupe

### 1. Scenario Overview
A ticket is a thread: `support_tickets` (the subject/status) plus `ticket_messages` (the turns). **Inserting a message is what drives everything else** — status transitions and the user notification are both trigger-owned.

`support_tickets.status`: `open` (awaiting admin) → `pending` (awaiting user) → `resolved` / `closed`.

### 2. Tables & Columns Read

| Actor | Table | Filter |
|---|---|---|
| User | `support_tickets` | `user_id = auth.uid()` |
| User | `ticket_messages` | `EXISTS (support_tickets st WHERE st.id = ticket_id AND st.user_id = auth.uid())` |
| Admin | `admin_list_tickets(status, limit)` 🔒 | joins `profiles` for `user_email/user_name`, aggregates `message_count, last_message_at, last_sender, awaiting_reply` |
| Admin | `admin_get_ticket(id)` 🔒 | the full thread |
| Trigger | `support_tickets.user_id` | the **owner**, for `v_ticket_owner` |

### 3. Tables & Columns Written

| Action | Writes |
|---|---|
| User creates a ticket | `support_tickets (user_id, subject, description, category, sim_line_id, attachment_url, status='open', priority='medium')` — direct client INSERT |
| User replies | `ticket_messages (ticket_id, user_id = auth.uid(), sender='user', message, attachments)` — direct client INSERT |
| Trigger on a `user` message | `support_tickets SET status='open', updated_at = clock_timestamp()` |
| Admin replies | `ticket_messages (ticket_id, user_id = **ticket owner**, sender='admin', message)` via `admin_reply_ticket()` 🔒 |
| Trigger on an `admin` message | `support_tickets SET status='pending'`; **`INSERT notifications (category='support', title='New reply on support ticket', body = first 117 chars + '…', action_url='/support/<id>')`** |
| Admin | `support_tickets SET status = COALESCE(p_new_status, status)`; `admin_audit_log` via `admin_log('ticket.reply', …)` |

### 4. Functions & Triggers Executed

`trg_support_ticket_messages_process` (AFTER INSERT ON `ticket_messages`) → `trg_fn_support_ticket_messages_process()` 🔒:

```sql
SELECT user_id INTO v_ticket_owner FROM support_tickets WHERE id = NEW.ticket_id;
IF v_ticket_owner IS NULL THEN RETURN NEW; END IF;
IF NEW.sender = 'admin' THEN
   UPDATE support_tickets SET status='pending', updated_at=clock_timestamp() WHERE id = NEW.ticket_id;
   INSERT INTO notifications (…, category='support', …);          -- ← the trigger owns this
ELSIF NEW.sender = 'user' THEN
   UPDATE support_tickets SET status='open', updated_at=clock_timestamp() WHERE id = NEW.ticket_id;
END IF;
```

> [!IMPORTANT]
> **H7d — the double-notification defect, found by running the code rather than reading it.**
> C7's trigger already inserted the `support` notification on a `sender='admin'` row. `admin_reply_ticket` inserted a **second** one, so a single support reply queued **two** dispatches — proven live: `net.http_request_queue` went 0 → 2 on one reply. This is the C1 dedupe loop repeating: one user action, two pushes.
>
> **The rule: the trigger owns the notification; the RPC must not.** The comment now sits inline in `admin_reply_ticket` so the second INSERT is not re-added.
>
> The status `UPDATE` in the RPC *stays* — it runs after the trigger has already moved the ticket to `pending`, so `COALESCE(p_new_status, status)` either honours the agent's explicit choice or leaves the trigger's `pending` in place.

`admin_reply_ticket` also takes `SELECT … FOR UPDATE` on the ticket, requires a message of ≥ 2 characters (`KS464`), validates `p_new_status` against `{open, pending, resolved, closed}` (`KS466`), and raises `KS461` if the ticket does not exist.

> [!NOTE]
> **`ticket_messages.user_id` is the ticket OWNER, not the author.** `sender` is what distinguishes them, and the user's SELECT policy joins through `support_tickets` on the owner. Writing the agent's id would hide the reply from the person it is addressed to.

### 5. RLS & Grant Lockdown

| Table | Policies |
|---|---|
| `support_tickets` | INSERT own (**two duplicate policies**: `Users can create own support tickets` and `Users can insert their own tickets`); SELECT own (also duplicated); UPDATE own **restricted to `status IN ('open','closed')`** in `WITH CHECK` |
| `ticket_messages` | INSERT requires `sender='user' AND user_id = auth.uid() AND EXISTS(own ticket)`; SELECT joins through `support_tickets` |

> [!IMPORTANT]
> The `ticket_messages` INSERT policy pins `sender = 'user'` in the `WITH CHECK`. **A client cannot author an `admin` message** — which matters, because `sender='admin'` is what fires the notification and moves the ticket to `pending`. Impersonating support is structurally impossible from the client.
>
> Similarly, the `support_tickets` UPDATE policy's `WITH CHECK` allows only `status IN ('open','closed')` — a user can close or reopen their ticket but cannot mark it `resolved`.

⚠️ Both tables carry blanket `INSERT/UPDATE/DELETE/…` grants for `anon` and `authenticated`; RLS is doing all the work. The duplicate policies (two INSERT, two SELECT on `support_tickets`) are permissive-OR'd, so they are harmless but should be consolidated — duplicated policies are exactly how an over-permissive one gets missed in review.

### 6. Code Path

```
User  → insert support_tickets           (RLS: own row)
      → insert ticket_messages(sender='user')
           → trigger: ticket → 'open'
Admin → rpc admin_list_tickets('open')
      → rpc admin_get_ticket(id)
      → rpc admin_reply_ticket(id, message, new_status?)
           assert_admin → FOR UPDATE → insert ticket_messages(sender='admin', user_id=owner)
              → trigger: ticket → 'pending'  +  notifications('support')  ← the only notification
           → UPDATE support_tickets status
           → admin_log('ticket.reply', …)
User  → push/email → deep link '/support/<id>'
```

### 7. Edge Cases, Security Risks & Failure Handling

- **The trigger is the single notification owner.** Any future reply path (an email-in gateway, a bulk-close job) gets user notification for free by inserting a `sender='admin'` message — and must **not** add its own `notifications` INSERT.
- **Body truncation** at 117 characters + `…` keeps push payloads within FCM limits; the full message is only in `ticket_messages`.
- **`FOR UPDATE` on the ticket** serialises two agents replying simultaneously, so the status transitions are ordered.
- **Deleting a user cascades the thread.** `purge_deleted_accounts` deletes `ticket_messages` (by `user_id` **or** by `ticket_id` of the user's tickets) and then `support_tickets` — so an agent's replies vanish with the ticket, which is correct for GDPR but means support history is not retained post-purge.
- ⚠️ **No rate limit on ticket creation.** `support_tickets` INSERT is a direct client write with no bucket. A script could create unbounded tickets. Add an `enforce_rate_limit('support_ticket', uid)` behind a create RPC, or a partial index-backed cap.
- **`attachment_url` / `attachments` jsonb are unvalidated.** They are rendered by the admin desktop app; treat them as untrusted input at render time.

---

## Scenario H3 — Multi-Channel Notification Dispatch

### 1. Scenario Overview
Everything in this system that talks to a user does so by inserting one row into `notifications`. §0.8 describes the channel resolution; this scenario documents the delivery half — what `dispatch-alert` does with the resolved list and what it records.

### 2. Tables & Columns Read

| Table | Purpose |
|---|---|
| `notification_channel_catalog` | all channels + `is_globally_enabled` (operator kill switch) |
| `notification_channels` | the user's per-transport switches, and `config` jsonb (e.g. Telegram chat id) |
| `alert_settings` | per-category `is_enabled` + `channels[]` |
| `sim_lines.protection_tier` / `profiles.subscription_tier` | tier narrowing |
| `device_push_tokens.fcm_token` | `WHERE user_id = $1 AND fcm_token IS NOT NULL` |
| `vault.decrypted_secrets` | `dispatch_shared_secret` |

### 3. Tables & Columns Written

| Table | Write |
|---|---|
| `notifications.delivered_via` | the resolved channel array, stamped by the trigger **before** dispatch |
| `notification_deliveries` | **one row per attempt**: `notification_id, user_id, channel, status ∈ {delivered, failed, skipped}, detail, provider_status` |

226 delivery rows against 129 notifications live — i.e. multiple channels per notification, as expected.

Note the channel labels written by the Edge Function are more granular than the resolved list: `push` fans out to `push_onesignal` and/or `push_fcm`, so `notification_deliveries.channel` is the *transport actually used*, not the requested channel.

### 4. Functions & Triggers Executed

```
INSERT notifications
 → trg_on_notification_created (AFTER INSERT) → trg_fn_dispatch_notification() 🔒
      resolve channels  (user ∩ category ∩ catalog, tier-narrowed, push safety net)
      UPDATE notifications SET delivered_via = channels
      if enabled and channels ≠ ∅:
         net.http_post → /functions/v1/dispatch-alert
             headers: x-keep-sims-secret = vault dispatch_shared_secret
             body:    {notification_id, user_id, category, title, body, action_url, sim_line_id, channels}
```

Inside `dispatch-alert`:

| Channel | Behaviour |
|---|---|
| `push` | try OneSignal; on non-delivery **fall back to FCM HTTP v1** using `device_push_tokens.fcm_token`; log `push_onesignal` and/or `push_fcm` separately |
| `telegram` | read `notification_channels.config` for the chat id |
| `whatsapp` | may **push additional channels onto the loop mid-iteration** (the `for…of` is deliberate, so a WhatsApp fallback can append) |
| `email` | Resend |
| all | `logDelivery(channel, status, detail, provider_status)` → `notification_deliveries` |

Missing credentials produce `status='skipped'` with an explanatory `detail` (e.g. `FCM_SERVICE_ACCOUNT_JSON not configured`), never a silent drop.

`schedule_delayed_notification(user, category, title, body, delay_minutes)` 🔒 is a different shape entirely: it **creates a one-shot `pg_cron` job** whose command inserts the notification and then `cron.unschedule`s itself.

`process_due_notifications()` 🔒 (hourly) drives `schedule_type='notify'` reminders: for each due schedule it inserts a `line_critical` notification, a `reminder_sent` activity row, and advances `next_execution_at` by `frequency_days` (or 1 hour when `frequency_days = 0`).

### 5. RLS & Grant Lockdown

| Table | Policy | Grant |
|---|---|---|
| `notifications` | own-row SELECT/INSERT/UPDATE/DELETE, all `AND NOT is_user_suspended()` | full CRUD ⚠️ |
| `notification_deliveries` | `deliveries_select_own` (SELECT) | full CRUD ⚠️ (no write policy, so RLS blocks) |
| `device_push_tokens` | own-row SELECT/INSERT/UPDATE/DELETE | full CRUD — intentional, the client registers its own token |
| `notification_channel_catalog` | SELECT true | `SELECT` only ⛔ |

- The Edge Function authenticates with `x-keep-sims-secret` from Vault **and** uses the service key for its own reads/writes. The shared secret is what stops an unauthenticated caller from making the function send arbitrary pushes.
- `trg_fn_dispatch_notification` is `service_role`-EXECUTE only (`c1_revoke_trigger_fn_execute`).

> [!WARNING]
> ⚠️ **Users can insert their own `notifications` rows** (policy `Users can insert own notifications`), and every insert fires the dispatcher. That is intended for local reminders, but it means a client can cause the system to send itself pushes/emails at will — a cost and abuse surface with no rate limit. Consider restricting the client-writable categories, or adding a bucket on self-authored notifications.

### 6. Code Path

```
<any event> → INSERT notifications
   → trg_fn_dispatch_notification: resolve → stamp delivered_via → net.http_post
      → dispatch-alert (Deno)
          push  → OneSignal → (fallback) FCM v1 via device_push_tokens
          email → Resend
          telegram → Bot API (chat id from notification_channels.config)
          whatsapp → WABA / Baileys server (server_ww.js / server_baileys.js)
          each attempt → INSERT notification_deliveries
   → client realtime on notifications → in-app badge
```

### 7. Edge Cases, Security Risks & Failure Handling

- **Fire-and-forget dispatch.** `net.http_post` does not block the inserting transaction and its failure is not visible to it. The reconciliation query for a lost dispatch is: `notifications` with `delivered_via <> '{}'` and **no** `notification_deliveries` rows.
- **`skipped` is a first-class outcome**, distinct from `failed`. Missing credentials, no registered token, and a globally-disabled channel are all `skipped` — so `admin_notification_health(days)` can separate "we chose not to send" from "we tried and it broke".
- **Push has a real fallback chain**; the other channels do not. A Telegram or WhatsApp failure is terminal for that notification.
- **The `for…of` loop is load-bearing.** WhatsApp can append channels mid-iteration; converting it to `for…of` over a frozen copy, or to `Promise.all`, would silently break the fallback.
- **`schedule_delayed_notification` writes to `cron.job`.** Each call creates a durable, self-unscheduling job. If the job's SQL ever fails, the job is **not** unscheduled and will retry every year at that minute. Audit `cron.job` for orphaned `delayed_alert_%` entries.
- **Quiet hours are not enforced in the database.** `user_preferences.quiet_hours_start/end` exist but no dispatch path reads them. Either the Edge Function must honour them or the column is misleading. ⚠️
- **Secret rotation is a two-place change** (Vault + Edge Function env), and getting it wrong silently 401s every alert in the system.

---

# APPENDICES

## A. Cron → Function → Tables written

| Schedule | Function | Writes |
|---|---|---|
| `*/5 * * * *` | `reap_stuck_executions` | `topup_executions`, `system_alerts` |
| `*/10 * * * *` | `check_worker_heartbeat_health` | `system_alerts` |
| `0 * * * *` | `process_due_notifications` | `notifications`, `line_activity_log`, `scheduled_topups` |
| `0 * * * *` | `purge_deleted_accounts` | 20+ tables (see A4) |
| `0 * * * *` | `reap_stale_esim_orders` | `esim_orders`, `wallets`, `wallet_transactions`, `system_alerts` |
| `30 * * * *` | `check_refill_pipeline_health` | `system_alerts` |
| `30 * * * *` | `check_rate_limit_health` | `system_alerts` |
| `50 * * * *` | `run_auto_rescue` | `topup_executions`, `line_activity_log`, `notifications`, `sim_line_rescue_policy` |
| `20 2 * * *` | `refresh_usage_forecasts` | `esim_usage_samples`, `sim_line_usage_forecast`, `notifications`, `line_activity_log` |
| `40 2 * * *` | `refresh_offer_price_watch` | `offer_price_watches`, `notifications`, `offer_price_history` (prune) |
| `55 2 * * *` | `emit_carrier_self_service_advice` | `notifications` |
| `0 3 * * *` | `prune_rate_limit_data` | `rate_limit_buckets` |
| `10 3 * * *` | `kick_fx_refresh` | → Edge Fn → `fx_rates`, `system_configs` |
| `40 3 * * *` | `kick_esim_catalogue_sync` | → Edge Fn → `esim_offers_cache`, `esim_suppliers`, `offer_price_history` |
| `10 4 * * *` | `kick_affiliate_sync(45)` | → Edge Fn → `affiliate_offers`, `affiliate_conversions` |
| `30 4 * * *` | `refresh_provider_offers` | `provider_offers` (`source_*` only) |

## B. Client-callable RPC surface (`authenticated` EXECUTE)

| Domain | RPCs |
|---|---|
| Identity / device | `touch_user_device`, `my_devices`, `label_my_device`, `revoke_my_device`, `report_device_block`, `get_current_context`, `get_fx_display_context` |
| Lines / offers | `list_refill_offers`, `list_carrier_offers`, `pick_best_refill_offer`, `calculate_health_score`, `reschedule_mini_refill`, `reset_mini_refill_to_default`, `update_mini_refill_dates`, `set_line_rescue_policy` |
| Money | `request_instant_refill`, `pay_plan_fee_from_wallet`, `quote_plan_price`, `queue_premium_refill_executions`, `transfer_wallet_credit`, `request_esim_purchase`, `cancel_topup_execution`, `retry_topup_execution`, `get_wallet_forecast` |
| Household | `invite_household_member`, `respond_to_household_invite`, `set_household_member_cap`, `leave_household`, `household_spend_summary`, `my_household_allowances` |
| Catalogue | `compare_esim_offers`, `roam_or_esim_quote`, `my_roaming_carriers`, `record_affiliate_click` |
| Lifecycle | `request_account_deletion`, `cancel_account_deletion`, `export_user_data`, `apply_referral`, `redeem_referral_points`, `get_active_promos`, `dismiss_promo` |
| Admin (gated by `assert_admin()`) | all 50 `admin_*` functions |

Everything else — including `plan_price_net`, `debit_wallet_for_topup`, `credit_wallet_*`, `guard_money_action`, `assess_device_risk`, `carrier_refill_offer`, `choose_supplier_for_offer`, `household_spend_check`, `run_auto_rescue`, and every `trg_fn_*` — is `service_role` only.

## C. Idempotency register

| Mechanism | Protects |
|---|---|
| `uq_wallet_transactions_paypal_capture` | duplicate PayPal capture webhook |
| `uq_wallet_transactions_debit_ref` / `_plan_fee_ref` / `_refund_ref` | worker retries, plan double-pay, double refund |
| `uq_wallet_txns_esim_debit` / `_esim_refund_ref` | eSIM purchase / reaper refund |
| `uq_wallet_txns_gift_sent_ref` / `_gift_received_ref` | gift replay |
| `plan_payments_capture_id_key` | duplicate plan capture |
| `offline_command_log_provider_msg_unique` | SMS/WhatsApp provider retry (replays the stored reply) |
| `offline_refill_events (provider, provider_msg_id)` | duplicate offline refill |
| `sim_line_usage_forecast_line_uq` / `_esim_uq` | nightly forecast upsert |
| `esim_usage_samples (esim_id, sampled_on)` | same-day re-snapshot |
| `offer_price_watches_subject_uq` | auto-watch reconciliation |
| `unique_sim_line_schedule_type` | one schedule per type per line |
| `uq_carrier_provider_map_primary` | one primary supplier per carrier |
| `uq_provider_offers_identity` | shelf rebuild |
| `FOR UPDATE SKIP LOCKED` | `claim_due_executions`, `claim_instant_executions`, `script_claim_next_execution`, `reap_stuck_executions`, `reap_stale_esim_orders` |
| Status predicates (`WHERE status IN (…)`) | every cancel / reap / purge phase |

## D. Open findings, ranked

| # | Finding | Where |
|---|---|---|
| 1 | **Retry-vs-refund invariant unverified** — `retry_execution_at_next_supplier` moves no money; whether the original debit was refunded depends on the worker. Reconcile every `retry_of` chain to exactly one net debit. | D5 |
| 2 | **Admin price overrides are invisible to instant refill** — `supplier_candidates` reads `provider_offers_cache`, `carrier_refill_offer` reads `provider_offers`. | D3, F1 |
| 3 | **`wallet_reconciliation` omits 7 transaction types** — reports false drift on any account that bought a plan or eSIM. | C2 |
| 4 | **`offer_price_watches` INSERT policy unreachable** (no INSERT grant) — users cannot create price watches. | H1 |
| 5 | **`sim_lines` `plan_type` still client-writable on INSERT** — no longer exploitable for spend, but the label is forgeable. | E2 |
| 6 | **Blanket CRUD grants on RLS-only tables** — `carrier_rules`, `countries`, `system_configs`, `esim_offers_cache`, `support_tickets`, `ticket_messages`, `notifications`, `notification_deliveries`, `account_deletions`, `payment_methods`, `analytics_events`, `carrier_ussd_suggestions`, `test_cases`. | B1, A3, A4, G1, H2 |
| 7 | **`roam_or_esim_quote` is SECURITY INVOKER over a deny-all table** — likely returning NULL eSIM columns for every caller. | G1 |
| 8 | **Self-authored notifications are unlimited** — a client can make the system push/email itself at will. | H3 |
| 9 | **`health_score`'s 80-day window is carrier-agnostic** — a 30-day carrier reads healthy 49 days after it died. | B1 |
| 10 | **No index supports `resolve_sender_user`** — four sequential scans with `regexp_replace` per inbound message. | F2 |
| 11 | **`protection_paused` does not cancel a queued premium year** — a paused line still spends. | B3 |
| 12 | **Quiet hours are never read** by any dispatch path. | H3 |
| 13 | **`purge_deleted_accounts` never sets `auth_deleted_at`** — a purged record can outlive its `auth.users` row deletion, unconfirmed. | A4 |
| 14 | **Novel (vs missing) device ids score only 25** — below the challenge threshold; rotating device ids evades velocity. | A2 |
| 15 | **No rate limit on ticket creation.** | H2 |
| 16 | **Lock-order inversion** between line delete (`scheduled_topups → topup_executions → sim_lines`) and refill settlement (`topup_executions → sim_lines → scheduled_topups`). | B4 |
| 17 | **`transfer_wallet_credit` locks two wallets in caller order** — mutual gifts can deadlock; order by `wallet_id`. | C4 |
| 18 | **Duplicate RLS policies** on `support_tickets` (2× INSERT, 2× SELECT) and `paypal_orders` (2× SELECT). | H2, C1 |
| 19 | **No unique index on purge closing ledger rows** (`wallet_forfeit` / `wallet_settlement`). | A4 |
| 20 | **`request_esim_purchase` matches `bundle_name` without a provider** — `LIMIT 1` with no `ORDER BY`. | G2 |

## E. Conventions to preserve

1. **USD is the only money unit.** FX is render-time, one-directional, never on a money path.
2. **The trigger owns the notification.** An RPC that also inserts one creates a double push (H7d).
3. **Cadence comes from `refill_interval_days()`**, and the price and the queue must both derive from it (J8).
4. **`minimum_topup_amount` is a threshold, not a price.**
5. **Direction lives in `balance_before`/`balance_after`**, never in a negative `amount`.
6. **Guards fail closed**: missing `supplier_policy` ⇒ not routable; `max_usd = 0` ⇒ not insured; absent `promo` opt-in ⇒ no marketing.
7. **New capability ships inert behind a DB flag.** The test is "does applying this change a live decision?", not "is the flag off?".
8. **Before writing a new guard, read the dead-guard checklist** (§E2): wrong role, wrong timing, unreachable grant, definer identity, bypassing RPC.

