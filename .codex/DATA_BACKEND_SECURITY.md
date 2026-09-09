# Data, Backend, and Security

## Verified backend snapshot

Read-only inspection of Supabase project `zwxswagokhgbuzrrbnhr` on 2026-09-06 found:

| Item | Live | Local source | Meaning |
|---|---:|---:|---|
| Public tables | 83 | — | All 83 reported RLS enabled. Policy correctness was not implied. |
| Migration history rows/files | 193 | 158 | Material history/source drift; names and timestamps do not line up one-to-one. |
| Edge Functions | 24 active | 26 directories | Both local-only and live-only functions exist. |
| Cron jobs | 19 active | migration-defined | Registry contains 18 rows; health-check job is unregistered. |
| SQL regression files | — | 34 | Good breadth through phase N1, but recent K/L/calling/operations changes lack equivalent named suites. |

Selected live row counts are recorded only to establish exercised domains, not product analytics: 8 profiles/wallets, 1 SIM line, 341 wallet transactions, 5 top-up executions, 12 plan payments, 1 eSIM order, 1 offline voucher request, 29 call records, 4,405 provider cache rows, 9,315 materialized provider offers, and 13,851 eSIM cache rows. Counts are volatile.

## Domain map

Representative table families in the current schema:

| Domain | Core objects / contracts |
|---|---|
| Identity | `profiles`, JWT `app_metadata`, device/risk data, account deletion requests. |
| SIM lifecycle | `sim_lines`, countries, carriers, carrier rules, liveness/verification state, activity logs, usage forecasts. |
| Wallet/billing | `wallets`, `wallet_transactions`, plan payments, payment/order records, referrals/gifts/household allowances. |
| Refills | schedules, `topup_executions`, refill settings, provider routing, offers/caches, retry/reaper functions. |
| Supplier catalogue | `service_providers`, `carrier_provider_map`, `supplier_policy`, `provider_offers_cache`, `provider_offers`, effective/catalogue views. |
| Offline/voucher | offline endpoints/events, voucher inventory, grants, requests, purchase jobs, carrier redemption instructions. |
| eSIM | `esim_suppliers`, `esim_offers_cache`, `esim_orders`, `user_esims`. |
| Calling | `call_rates`, `call_records`, `user_caller_ids` and call debit/RPC contracts. |
| Notifications | notifications, deliveries, preferences/channels, templates, system alerts. |
| Operations | `system_configs`, `admin_audit_log`, `scheduled_job_registry`, cron history/health surfaces. |

`doc/DATABASE_DOCUMENTATION.md` predates several of these families and is not a complete current schema reference.

## Trust and authorization model

| Actor | Credential | Allowed role |
|---|---|---|
| Customer Flutter | anon/authenticated JWT | Own/read-public data and narrowly granted self-service RPCs/Edge Functions. |
| Admin Flutter | authenticated JWT containing `app_metadata.is_power_user=true` | Audited `admin_*` APIs; still an untrusted client. |
| Cron/Edge Functions | function environment/service role or explicit webhook signature | Narrow scheduled/integration operations. |
| Node workers | Supabase service role + provider secrets | Claim queues, mutate authoritative execution state, purchase/refund, update catalogues. |
| External provider | Signed webhook/provider API | Only the provider-specific endpoint after fail-closed verification. |

Admin server authorization is based on the JWT app-metadata claim checked by `is_power_user()`/`assert_admin()`, not on the client-rendered profile value. Promotion is deliberately not available as a client table update.

## Security findings

### Live database advisors

Supabase advisors returned 159 security findings: 3 errors, 124 warnings, and 32 informational notices.

Confirmed high-signal items:

- Three `security_definer_view` errors: `esim_offers`, `zendit_offers_cache`, and `provider_offers_effective`.
- Mutable `search_path` warnings on three trigger functions: `trg_scheduled_topup_health_sync`, `trg_fn_log_topup_activity`, and `trg_fn_notify_topup_result`.
- `pg_net` installed in `public` warning.
- Leaked-password protection is not enabled.
- Four functions were found executable by `anon` while `SECURITY DEFINER`:
  - `check_scheduled_jobs_health()` — no auth/admin guard and can insert alerts. **LOCALLY FIXED, NOT DEPLOYED (2026-09-06):** a forward migration revokes `PUBLIC`, `anon`, `authenticated`, and `service_role`, granting only the actual pg_cron username `postgres`.
  - `confirm_line_verification(uuid,text,text)` — source contains self/auth checks, but public grant is broader than necessary.
  - `list_refill_offers(uuid)` — source contains self/auth checks, but public grant is broader than necessary.
  - `get_call_rate_for_number(text)` — public catalogue behavior appears intentional, but definer privilege should be justified/minimized.
- 115 `SECURITY DEFINER` functions are executable by `authenticated`; many are intentional guarded client/admin APIs, but the historical allowlist/test baseline is stale and needs re-audit.
- Related grant regression found while rebuilding the allowlist: `prune_database_logs(integer,integer)` is live as `SECURITY DEFINER`, is executable by `authenticated`, has no client authorization guard, and can delete cron history and system alerts. It remains deliberately unallowlisted so the global grant test flags it; fix it in a separate forward migration.

Live table ACLs grant broad table privileges on `system_alerts` and `scheduled_job_registry` to API roles, with RLS providing the effective write boundary. The focused P0 test proves `anon` and ordinary `authenticated` inserts into `system_alerts` are denied; reducing the underlying table grants is a separate defense-in-depth review.

RLS is enabled on all public tables, but function execution grants can bypass table RLS. Keep function grants in the security matrix.

### Performance advisors

Supabase returned 186 performance findings: 116 warnings and 70 informational notices, including 39 unindexed foreign keys, 84 auth/RLS init-plan warnings, 31 unused-index notices, and 32 multiple-permissive-policy notices. Some may be accepted tradeoffs. Triage with query evidence; do not mechanically add/drop indexes or policies.

Postgres review rules for that triage:

- Index the referencing side of foreign keys that participate in joins/deletes, but check whether a suitable leading composite index already covers it.
- For frequently filtered/joined columns, use `EXPLAIN (ANALYZE, BUFFERS)` in a safe environment before and after a change; advisor presence alone does not prove production impact.
- Rewrite RLS expressions such as `auth.uid()` to `(select auth.uid())` where semantically safe so the value is initialized once, and index ownership/policy lookup columns.
- Consolidate overlapping permissive policies only after proving the resulting boolean access rule is equivalent.
- Do not remove an “unused” index solely from a short observation window; include rare reconciliation, purge, and incident queries.

Positive concurrency patterns already exist: queue-claim migrations use `FOR UPDATE SKIP LOCKED`, and provider-offer refresh uses a transaction-scoped advisory try-lock for single-flight behavior. Preserve these patterns when extending worker queues or refresh jobs.

## Edge Function inventory and drift

Local function directories:

```text
capture-paypal-order, create-paypal-order, delete_account, detect-country,
dispatch-alert, execute_zendit_recharge, fetch_zendit_offers, health,
liveness-verification, make-call, manage-caller-id, paypal-return,
paypal-webhook, purge-accounts, refresh-fx-rates, send-sim-otp,
send-whatsapp-alert, sms-webhook, sync-affiliate-network,
sync-esim-catalogue, telnyx-cdr, twilio-voice-webhook,
validate-sim-liveness, verify-sim-otp, waba-webhook, wallet_transact
```

Deployment mismatches:

| Status | Functions | Consequence |
|---|---|---|
| Local source, absent live | `paypal-return`, `liveness-verification`, `send-whatsapp-alert` | Customer code invokes the latter two; those flows are expected to fail unless another routing layer exists. PayPal fallback behavior may differ from local intent. |
| Live, source absent locally | `send-admin-email` | Cannot reproduce, review, or roll back the deployed implementation from this repository. |
| Live and local, dangerous divergence/behavior | `execute_zendit_recharge` | Active v6 path directly purchases supplier airtime from client input without the authoritative queue/debit/refund workflow. |

`execute_zendit_recharge` is still active with JWT verification. Local code authenticates a user, accepts phone/country/amount, chooses a close Zendit offer, and purchases it; it does not debit the wallet or use the trusted worker queue. Treat it as P0 even if intended only for sandbox testing.

`supabase/config.toml` explicitly records settings for only four functions. It is not a complete source of truth for live `verify_jwt` behavior.

## Webhook verification

Confirmed local behavior:

- `telnyx-cdr` verifies Ed25519 signatures only when `TELNYX_PUBLIC_KEY` is configured; otherwise it logs a warning and proceeds.
- `sms-webhook` and `twilio-voice-webhook` skip Twilio signature verification when `TWILIO_AUTH_TOKEN` is absent.
- These live functions have JWT verification disabled, as expected for provider webhooks, which makes signature verification the primary boundary.

Therefore the handlers fail open under secret misconfiguration. The production review's claim that missing/invalid Telnyx signatures are always rejected is not supported by current source. Secret existence could not be inspected; fix code to fail closed rather than relying on a deployment promise.

## Wallet and ledger

### Intended invariant

Every wallet mutation should be atomic, idempotent, server-side, and paired with an immutable transaction entry whose signed amount matches the actual balance delta. Supplier purchase and refund state must be reconcilable.

### Current reconciliation gap

The live `wallet_reconciliation` view recognizes only a historical subset of transaction types. It omits newer types such as plan fees, eSIM, gifts, vouchers, calls, admin adjustment, settlement, and forfeiture. Its reported drift cannot be treated as an authoritative audit.

Read-only transaction checks found:

- All completed transaction rows individually had a `balance_after - balance_before` delta consistent with their own signed amount.
- Ordering snapshots per wallet found 20 chain breaks, with a maximum discontinuity of 10,000.
- Five wallets' current balances differed from their latest transaction snapshot by up to 2.
- A separate initial-snapshot model found six mismatches, but fixtures, direct corrections, and chronology may contribute.

`UNKNOWN` The discrepancies require an owner-reviewed ledger audit. Do not infer fraud or silently “correct” balances. First rebuild reconciliation to encode every current transaction type and valid non-ledger initialization/correction event.

### Calling charge gap

The server-side `debit_wallet_for_call` clamps a wallet to zero but records the full call cost and adds the full cost to total spent. Preflight checks only a small minimum balance; it does not reserve the call's maximum duration/cost. This can record more debit/spend than was actually collectible. Add reservation/maximum-duration behavior or explicitly model partial collection/receivable before material call volume.

## Supplier/provider rules

- Clients never choose or assert supplier cost as authoritative.
- `carrier_provider_map` holds each supplier's identifier dialect and primary/priority routing.
- `provider_offers_cache` is raw normalized supplier data; `provider_offers` is the materialized business catalogue.
- Currency and minor-unit conversions require provenance; DT One/Ding settlement can be OMR rather than USD.
- Provider purchase must use a stable external ID and adopt the original transaction on retry when supported.
- Direct airtime and PIN/voucher delivery are different offer kinds and must not be ranked as interchangeable.

The authoritative worker suite currently fails the test that ensures Ding data/content bundles are excluded from plain airtime selection. Ding code comments also state that live provider validation is incomplete. Do not enable Ding background routing until real-response validation and the safety test pass.

## Migration and runtime drift

Local and live history are not aligned:

- 158 local files versus 193 live history rows.
- Recent live versions use timestamps such as `20260903230250` through `20260904002950`, while corresponding local files use rounded names `20260904010000` through `20260904060000`.
- Several local 2026-08-25 through 2026-08-31 changes are absent under matching version/name even though some resulting objects exist live, implying manual SQL/stamping or renamed-history drift.
- Local `20260904000000_carrier_refill_offer_prefer_primary.sql` is not represented in live history, but the live function **does** implement the same primary -> direct -> price -> priority ordering. This proves object behavior can be present without matching migration provenance.

Do not resolve this by editing history. Build a schema/object diff, establish an accepted baseline, then add forward migrations for missing behavior.

## Cron and health

Live has 19 active cron jobs. `scheduled_job_registry` has 18 entries. The unregistered job is `check-scheduled-jobs-health` itself. Its health function is anon/authenticated executable and has no identity guard.

Local P0 issue 3 review (not deployed): live metadata confirms the job runs `SELECT public.check_scheduled_jobs_health()` as `postgres`, so the new ACL is exactly postgres-only. The function retains `SECURITY DEFINER` and `SET search_path TO ''`: the empty path is safe, all referenced objects are qualified, and an ACL-only migration avoids overwriting the materially different live function body. An in-body `current_user` check would be ineffective under `SECURITY DEFINER`; rewriting the body solely to add a `session_user` guard would add drift risk without expanding protection beyond the exact role ACL. The registry remains unchanged because an internal job cannot alert when its own scheduler invocation never occurs; registering it would report the currently running invocation, not provide an independent watchdog. Monitor the checker externally instead.

The local health Edge Function checks database connectivity and the eSIM fulfillment heartbeat, not the entire worker fleet. A green response is not proof that refill, offers, voucher, messaging, or every eSIM process is healthy.

## Feature flags verified live

On 2026-09-06:

| Flag | Value |
|---|---|
| `APP_CHECK_ENFORCE` | `false` |
| `DEVICE_RISK_ENFORCE` | `false` |
| `CARRIER_ADVICE_ENABLED` | `false` |

Expected supplier-failover/auto-rescue flag names were not returned under the names checked. Treat them as `UNKNOWN` (missing, renamed, or separately configured), not false.

## Secret and repository hygiene

- `mcp_config.json` is tracked and contains a nonempty `PAYPAL_ACCESS_TOKEN`. The value is intentionally not reproduced here. Rotate/revoke it if valid, remove it from tracked configuration/history, and use user/environment secret storage.
- Older documentation records a previously committed sandbox PayPal secret; rotation/history review remains an owner action.
- Worker `.env` is ignored; `.env.example` contains names only.
- Android `key.properties`/keystore material is ignored and release builds include a guard against accidental debug signing.
- `android/app/google-services.json` is tracked, contradicting the structure map. Firebase client configuration is not equivalent to a service credential, but repository policy should be explicit.

## Backend change checklist

- [ ] Current live definition/grants/policies inspected.
- [ ] Forward migration written; old migrations untouched.
- [ ] `SECURITY DEFINER` has safe search path, in-body authorization, `REVOKE PUBLIC`, minimal explicit grants.
- [ ] RLS/table grants/function grants all reviewed.
- [ ] SQL regression added, including negative anon/cross-user/admin tests.
- [ ] Edge `verify_jwt` and webhook signature mode documented.
- [ ] Local function source and deploy inventory agree.
- [ ] Money/provider idempotency and ambiguous timeout behavior tested.
- [ ] Migration history/source drift considered before deployment.
