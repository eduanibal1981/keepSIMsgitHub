# RLS & Privilege Matrix — audited 2026-07-16 (Phase A4)

Live project `zwxswagokhgbuzrrbnhr`. Produced by the A4 security sweep
(`supabase/migrations/20260716010000_a4_security_sweep.sql`). All 26 public
tables have RLS **enabled**. `service_role` bypasses RLS everywhere (workers +
Edge Functions).

## Table matrix

| Table | SELECT | INSERT | UPDATE | DELETE | Notes |
|---|---|---|---|---|---|
| alert_settings | own | own | own | own | single ALL policy, `auth.uid() = user_id` |
| carrier_rules | everyone | — | — | — | public catalog |
| carrier_ussd_suggestions | authenticated | — | — | — | |
| carriers | everyone | — | — | — | public catalog |
| countries | everyone | — | power user | — | |
| household_members | owner or member | owner | owner; member (invite status) | owner | |
| line_activity_log | own + household | own | — | own | |
| notification_channels | own | own | own | own | single ALL policy |
| notifications | own | own | own | own | |
| offline_refill_settings | own | own | own | — | |
| payment_gateways | everyone | — | — | — | catalog |
| payment_methods | own | own | own | own | single ALL policy |
| profiles | own + household counterpart + power user | own | own | — | **tightened in A4** — was `USING (true)` (any user could read all profiles/phones) |
| referrals | referrer or referred | referred (self) | — | — | credits happen in `apply_referral` (service-role only) |
| refill_requests | own (via line) + power user | own line or power user | power user | — | `amount > 0`, status/source CHECKs pre-existing |
| scheduled_topups | own + household | own + household manager | own + household manager | own + household manager | **A4:** `CHECK (amount > 0)` added |
| security_logs | — (deny all) | — | — | — | RLS on, zero policies: intentional, server-side writes only |
| sim_lines | own + household; power user ALL | own | own + household manager | own | |
| support_tickets | own | own | — | — | admin replies via dashboard (service role) |
| system_alerts | power user | — | — | — | inserts from DB safety-net jobs |
| system_configs | authenticated | power user | power user | — | |
| test_cases | power user | power user | power user | power user | **tightened in A4** — was any authenticated user |
| topup_executions | own + household; power user | own | own; power user | — | **A4:** client DELETE policy dropped (audit trail); `CHECK (amount > 0)` added. ⚠️ Known gap: app still UPDATEs `status` client-side — close in C3 by moving behind RPC and revoking client UPDATE |
| user_preferences | own | own | own | — | |
| wallet_transactions | own | — | — | — | **A1:** client writes revoked; ledger written only by SECURITY DEFINER RPCs. **A4:** `CHECK (amount > 0) NOT VALID` (one legacy $0 simulated row `d41a37a3` predates it) |
| wallets | own | — | own, **columns `auto_fund_*` only** | — | **A1:** table-level write grants revoked; balance moves only via `wallet_transact` Edge Function → `credit_wallet` / `debit_wallet_for_topup` / `credit_wallet_for_refund` |

## Function privileges (public schema)

**Service-role only** (clients get `permission denied` / function hidden):
`apply_referral`, `bind_telegram_bot`, `check_refill_pipeline_health`,
`claim_due_executions`, `claim_instant_executions`, `credit_wallet`,
`credit_wallet_for_refund`¹, `debit_wallet_for_topup`², `deduct_wallet_atomic`,
`refund_wallet_atomic`, `reap_stuck_executions`, `update_execution_failed`,
`update_execution_status`, `process_due_notifications`,
`schedule_delayed_notification`.

> ¹ **This line was aspirational, not true, between D5b and 2026-07-29.**
> `20260801010000_d5b_…` re-granted `EXECUTE` on `credit_wallet_for_refund` to
> `authenticated` — review finding **F-1**, an unlimited wallet-minting hole. Closed by
> `20260801040000_f1_credit_wallet_refund_grant_lockdown.sql` (revoke + an in-body
> `request.jwt.claims` role guard raising `KS403`), and now held by
> `supabase/tests/f1_wallet_refund_grant_tests.sql` so the doc and the ACL cannot drift
> apart again silently.
>
> ² **Was false between D5b and 2026-07-29.** The 6-arg overload
> `debit_wallet_for_topup(uuid,uuid,numeric,text,text,text)` was `EXECUTE` to **PUBLIC** (anon
> included) — review finding **F-2**, a drain-any-wallet hole, since the anon key ships in the
> APK. Closed by `20260801050000_f2_debit_wallet_grant_lockdown.sql` (revoke + a call-depth
> guard raising `KS403` on any direct client call, while still permitting the nested calls from
> `request_esim_purchase` / `pay_plan_fee_from_wallet`). The redundant 5-arg overload was
> dropped by `20260801060000` — **`debit_wallet_for_topup` now has exactly one signature**, and
> `supabase/tests/f2_debit_wallet_grant_tests.sql` pins that.

**Authenticated only** (anon revoked in A4): `calculate_health_score`,
`calculate_topup_fees`, `get_current_context`, `get_wallet_forecast`,
`reschedule_mini_refill`, `reset_mini_refill_to_default`.

**Ownership enforced inside the function (A4)** — callers with a JWT may only
act on their own rows; service-role calls (no JWT) unrestricted:
- `get_wallet_forecast(p_user_id)` — was readable for any user id (IDOR).
- `reschedule_mini_refill` / `reset_mini_refill_to_default(p_sim_line_id)` —
  any signed-in user could move any line's refill schedule (IDOR). Now owner
  or accepted household manager only.
- `apply_referral(p_referred_id, code)` — defense in depth.

**Trigger-only functions** — EXECUTE revoked from anon+authenticated (triggers
still fire; firing does not require EXECUTE for the DML user):
`check_free_lines_limit`, `check_topup_rate_limit`,
`handle_new_household_member`, `handle_new_user`, `protect_is_power_user`,
`resolve_pending_household_invites`, `route_topup_execution`,
`sync_power_user_claim`, `sync_suspended_claim`,
`trg_fn_dispatch_notification`, `trg_scheduled_topup_health_sync`,
`update_line_health`, `update_sim_line_last_topup_at`,
`update_test_cases_updated_at`, `update_updated_at`.

**Kept executable by anon + authenticated** (referenced inside RLS policy
expressions, which evaluate as the querying role): `is_user_suspended()`,
`is_power_user(uuid)`.

All flagged functions now have `search_path` pinned (`'public'` or `''`).

## Views

- `sim_line_details_view`: switched to `security_invoker = on` (A4) — was
  SECURITY DEFINER (advisor ERROR). Not referenced by the Flutter app.

## Storage

- Bucket `support_attachments` (public=true, 0 objects at audit time):
  - Broad `SELECT USING (bucket_id = ...)` policy **dropped** (allowed listing
    every file in the bucket).
  - INSERT + SELECT now scoped to the caller's folder:
    `(storage.foldername(name))[1] = auth.uid()::text` — matches the app's
    `<user_id>/<file>` upload path in `support_repository.dart`.
  - Objects remain publicly fetchable by exact URL (bucket is public);
    revisit in C7 (private bucket + signed URLs) if attachments are sensitive.

---

# Phase F grant lockdown — updated 2026-07-29

Sessions F1–F6 rebuilt the privilege layer after the A4 audit above was found to
have swept tables but never functions. Four live holes came out of that gap
(F-1 wallet minting, F-2 wallet draining, F-3 free unauthenticated compute, F-4
rate-limit DoS + an unauthenticated write to any user's profile), plus two
found while verifying them. Migrations `20260801040000` … `20260801100000`.

**The rule now enforced by `supabase/tests/f0_grant_matrix_tests.sql`:** every
`SECURITY DEFINER` function in `public` is either `service_role`-only or on an
explicit allow-list. Nothing is callable by `anon` or `PUBLIC`. Run that test
before believing any table below.

## Client-facing table privileges (F-6, migration `20260801090000`)

Table-level `GRANT ALL` was never stripped after A4, so RLS was the *only* thing
stopping writes. Re-derived from what the live policies actually permit:

| Table | anon | authenticated | why |
|---|---|---|---|
| `profiles` | SELECT | SELECT, INSERT, **column-scoped UPDATE** | no DELETE policy exists |
| `sim_lines` | SELECT | SELECT, INSERT, DELETE, **column-scoped UPDATE** (13 cols, D5d) | full policy set |
| `scheduled_topups` | SELECT | SELECT, INSERT, UPDATE, DELETE | single ALL policy |
| `esim_orders` | SELECT | SELECT | **zero** non-SELECT policies; written by `request_esim_purchase` + the fulfilment worker |
| `user_esims` | SELECT | SELECT | as above |

`TRUNCATE`, `REFERENCES` and `TRIGGER` are revoked from `anon` and
`authenticated` on all five. `TRUNCATE` is not RLS-filtered at all, and
`TRIGGER` on a client-reachable table is an escalation primitive.

`profiles` columns **not** granted to `authenticated`: `id`, `email`,
`created_at` (immutable); `is_power_user`, `is_suspended` (privilege /
moderation); `subscription_tier` (entitlement, set by
`trg_fn_apply_plan_tier_from_payment`); `referral_code`, `referred_by` (set only
by `apply_referral()`).

> ⚠️ Column-scoping `profiles.UPDATE` required an app change — `updateProfile`
> sent the full model. `UserProfile.toClientWritableJson()` is the client-side
> half; changing one without the other breaks profile editing with `42501`
> (this is what D5c did to SIM line editing). Same coupling as
> `SimLine.toClientWritableJson()`.

## Accepted exceptions (verified 2026-07-29, will NOT be "fixed")

Live `get_advisors(security)`: **29 findings**, down from 47. `anon`
SECURITY DEFINER warnings went 12 → **0**; `function_search_path_mutable` 1 → 0;
`authenticated` SECURITY DEFINER warnings 25 → 20. The remainder are deliberate:

| Finding | Level | n | Why it stays |
|---|---|---|---|
| `security_definer_view` — `esim_offers`, `zendit_offers_cache` | ERROR | 2 | **Deliberate markup isolation.** These views exist so a client can read retail prices without reading the wholesale cost columns behind them. `security_invoker = on` would expose supplier margin. Do not "fix". |
| `rls_enabled_no_policy` — `esim_offers_cache`, `offline_refill_events`, `rate_limit_buckets`, `retired_referral_codes`, `security_logs` | INFO | 5 | **Deliberate deny-all.** RLS on with zero policies *is* the intended service-role-only posture. Adding a policy would weaken them. |
| `authenticated_security_definer_function_executable` | WARN | 20 | The self-scoped app RPCs. Each gates on `auth.uid()` internally; the set is pinned by the allow-list in `f0_grant_matrix_tests.sql`, so a new one cannot appear silently. |
| `extension_in_public` — `pg_net` | WARN | 1 | Supabase-managed, and `purge_deleted_accounts()` calls `net.http_post`. Relocating it is a schema change, not a security fix. |
| `auth_leaked_password_protection` | WARN | 1 | **Owner action:** Dashboard → Auth → Passwords → enable the HaveIBeenPwned check. No API or SQL toggle exists. |

## Corrections to the A4-era notes above

* ~~"`is_power_user` executable by anon — Required: used in RLS policies
  evaluated as `anon`"~~ — the *requirement* was real and this session verified
  it the hard way: revoking `anon` made `anon SELECT sim_lines` fail with
  `42501`, because the `"Allow power users full access on sim_lines"` policy is
  `FOR ALL TO public` and its `USING` clause calls the function, and RLS policy
  expressions run as the querying role. But the framing was wrong — it never
  needed `SECURITY DEFINER`. Migration `20260801100000` made it
  `SECURITY INVOKER` (it only reads the caller's own JWT and ignores its
  `user_id` argument) and re-granted `anon`. It is therefore no longer part of
  the SECURITY DEFINER perimeter, and the "0 anon-callable" count above is
  honest rather than a carve-out.
* "6 × SECURITY DEFINER RPCs executable by authenticated" was already stale — it
  is 20, enumerated in the allow-list.
* `protect_is_power_user()` was **dead code** from the day it shipped: it is
  `SECURITY DEFINER` and gated on `current_user IN ('postgres','supabase_admin')`,
  and under `SECURITY DEFINER` `current_user` is always the owner. A signed-in
  user could set their own `is_power_user`, which `sync_power_user_claim()`
  copies into `auth.users.raw_app_meta_data` and thence into their JWT. Fixed in
  `20260801090000` by keying on the request JWT role instead.
