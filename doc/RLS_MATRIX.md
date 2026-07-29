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
> ² **Still false as of 2026-07-29** — the 6-arg overload
> `debit_wallet_for_topup(uuid,uuid,numeric,text,text,text)` is `EXECUTE` to **PUBLIC**
> (anon included). Review finding **F-2**, open. Only the 5-arg overload is service-role only.

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

## Documented exceptions (remaining advisor findings)

| Finding | Level | Status |
|---|---|---|
| `security_logs` RLS enabled, no policy | INFO | Intentional: deny-all for clients, service-role writes |
| `pg_net` extension in public schema | WARN | Cannot fix: pg_net 0.20.0 does not support `SET SCHEMA` (platform limitation) |
| `is_power_user` executable by anon | WARN | Required: used in RLS policies evaluated as `anon` |
| 6 × SECURITY DEFINER RPCs executable by authenticated | WARN | Intentional app RPCs; ownership enforced inside the function (see above) |
| Leaked password protection disabled | WARN | **User action:** Dashboard → Auth → Passwords → enable HaveIBeenPwned check (no API/SQL toggle) |
