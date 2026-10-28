# Data, Backend, and Security

## Required worker fleet monitoring — Task 23, 2026-10-18 (local, undeployed)

`20261018090000_worker_fleet_monitoring.sql` keeps fleet requirements/runtime/probes/cron/observation/incidents private. Telemetry uses explicit service execution plus an in-body service check, exact lane/field validation and instance/sequence fencing. Raw queue queries and snapshots remain private; the public Edge endpoint gets only consistent aggregate status/counts, while detailed component/age/backlog/source versions use service or assert-admin APIs. Worker liveness is read fresh; financial queue aggregates are measured by the existing ten-minute cron checker and cached, with absent/15-minute-old evidence failing closed. Unknown schema/probe/run-history states never become healthy zeroes. A transaction lock and persistent incident key enforce six-hour alert cooldown across concurrency/flapping, without suppressing retries after alert-storage failure. Monitoring never releases/retries financial/provider work or enables dormant services. All 50 isolated SQL/concurrency and 137 focused worker/Edge/admin tests pass; production release and controlled runtime acceptance remain pending. See [Task 23 evidence](../docs/reviews/worker-fleet-monitoring-20261018.md).

## Source reproducibility — Task 22 (2026-10-18, local tools only)

`supabase/recovered/20261018` contains exact deployed legacy SQL/Edge evidence,
not migrations or an approved fresh baseline. Never replay it over the reviewed
forward repairs. `deployment/manifest.json` classifies every active SQL file and
keeps full fresh/upgrade gates blocked; default grants, owners, Auth/Storage/Vault/
net/cron and required configuration still need complete provisioning proof.
Three-repository source locks include dirty bytes via a separately retained,
hash-verified bundle. Only explicitly required historical SQL test dependencies
are distributed; the complete immutable archive stays preserved locally.
See `docs/reviews/source-reproducibility-20261018.md` before any baseline/history
reconciliation. No remote history repair, bulk push or deployment was performed.

## Schedule mutation boundary — Task 20 (2026-10-18, local/undeployed)

Forward `20261018070000_scheduled_pricing_boundary.sql` revokes schedule table and column mutations and replaces permissive ALL policies with owner/household SELECT RLS. Customer save/control RPCs derive owner, canonical prices, fees, tier, provider, units and engine/version, validate ownership/suspension/paid automation and check the reviewed ceiling. Internal identity/sync helpers are private; the yearly queue is a non-callable tombstone. Worker claims require validated parent/child versions and matching ownership, while NOWAIT control locks avoid worker/control lock-order deadlocks. Legacy configurations pause for review; uncertain financial/provider work remains unclaimed for reconciliation. Setup capture explicitly revalidates old parents and establishes major-currency future airtime targets from the bound provider/SKU; missing target data rolls finalization back. Admin schedule inspection uses a guarded view and immediate polling. Both copied offline queues use reminder allowlists and preserve other-account operations. Fresh live metadata still exposes the old API/grants. All 36 native SQL/concurrency/real local API scenarios, 60 customer, two admin and 62 backend tests pass locally; see [Task 20 review](../docs/reviews/scheduled-pricing-boundary-20261018.md) and the read-only scheduled-pricing preflight. No production repair was applied.

## Retail data and ownership — Task 19, 2026-10-18 (local, undeployed)

The forward `20261018060000_retail_ownership_contract.sql` closes raw supplier/catalogue and internal quote/entitlement reads. Customer fixed/range totals use canonical server pricing; customer receipts/approval routes exclude supplier cost, margin, raw CDR and provider errors. Invoker receipt views use explicit base-column grants and owner RLS. Deliberate definer catalogue/approval views expose allowlisted retail fields with verified caller predicates; guarded admin views retain supplier inspection through `assert_admin()`. No wholesale base grants are added for view compatibility. Saved return-trip prices stay fixed; legacy unknowns stay null. Both clients require coordinated release. Task 3 containment must precede newer retail bodies. Twenty-three native SQL, 81 Flutter and 18 DID backend tests pass; live exposure remains open. Schedule financial-write enforcement remains Task 20. See `docs/reviews/retail-ownership-repair-20261018.md`.

## Admin maintenance/deletion — Task 16, 2026-10-18 (local, undeployed)

`20261018030000_admin_maintenance_deletion_contract.sql` replaces the missing
prune email helper and unsupported audit/alert fields with `admin_log`'s actual
`p_after`/`p_note` contract and `system_alerts(kind,message,details)`. Retention
and its audit commit together. Rate-health checks preserve the 20-per-hour
threshold and six-hour suppression, serialized across sweeps.

Admin deletion now persists a private `account_purge_jobs` request, actor snapshot
and fenced processing lease. Only successful Storage cleanup and absent Auth,
followed by the atomic completion/audit RPC, establish completion. The Edge
handler uses supported Auth Admin deletion; the raw SQL Auth fallback is retired.
Job failure remains retryable/observable, including an audit outage after Auth
has already gone. Client mutations of deletion/email state are revoked.
Customer cancellation locks the request against the due-job producer.

Deletion stops for nonzero balances, active holds, funding lots, refunds, ledger,
top-up, eSIM, DID or call records requiring retention/provider reconciliation.
These records must not be erased simply to pass the gate. There is no new
balance-forfeiture, financial backfill or provider-retirement policy. Old
`purged`/`auth_deleted` rows are not promoted to verified completed jobs.

`send-admin-email` is a versioned intentional local replacement of captured
deployed v2, retaining `x-sync-secret`/`email_id` input and reading the persisted
envelope. SQL claim/outcome APIs fence duplicate sends. Provider acceptance uses
legacy status `sent`; it is not mailbox-delivery proof. Ambiguous sending/failed
outcomes require review and are never automatically resent. Both Edge handlers
use `verify_jwt=false` with mandatory Vault-backed handler authentication.

All 29 isolated native SQL/actual-Edge integration scenarios and 20 Edge tests
pass; the admin purge repository passes Dart analysis. Release SQL, both Edge
consumers and the admin response check together after reviewing current live
contracts. See `docs/reviews/admin-maintenance-deletion-repair-20261018.md`.

## Usage forecast repair — Task 15, 2026-10-18 (local, undeployed)

`20261018020000_usage_forecast_schema_contract.sql` replaces nonexistent
`esims`/metadata references with `user_esims`, owner/provider/bundle-matched
completed `esim_orders`, and provider/bundle-matched `esim_offers_cache`.
Stored expiry bounds the forecast; catalogue duration is advisory and never
creates expiry. Suggested historical amounts use the order's retail unit price,
never wholesale. Missing evidence stays nullable; no 30-day eSIM fallback exists.
Usage snapshots follow actual `last_usage_check` dates, not repeated job dates.
Fits reject invalid readings and reset at data increases/total changes.

The owner-only invoker `compute_usage_forecasts_internal()` supports both the
service/postgres bulk wrapper and existing owner/manager-checked manual recharge
definer. Clients cannot call the core or bulk RPCs. Physical forecasts retain
their history/cadence behavior and allowed method labels; a null recharge anchor
has no depletion date, and grace does not extend inactivity. Unexpected eSIM
failures invalidate eSIM predictions, preserve physical output and write
sanitized diagnostics/warnings. Snapshot/alert failures also preserve forecast
work. Counts in refresh output do not establish complete all-stage success.
Forecast alerts now use durable event/outbox metadata with empty delivery lists.

All 32 isolated native PostgreSQL scenarios pass. No production changes or fresh
live verification occurred. The retained `20260916080000` null-anchor source is
superseded; do not apply it unchanged. See
`docs/reviews/usage-forecast-repair-20261018.md` for schema evidence, fixture
limitations, provider/activation unknowns and release requirements.

## Notification scheduler repair — Task 14, 2026-10-18 (local, undeployed)

`20261018010000_notification_scheduler_contract.sql` repairs upcoming-refill
low-balance reminders to use `wallet_low` in insertion and deduplication, with
versioned event/template metadata and the existing notification-to-outbox
trigger. A shared transaction advisory lock enforces the rolling one-per-line
24-hour limit across direct and scheduler sweeps. Notification insertion never
establishes channel delivery. System-alert notifications now follow that rule
and supply event metadata too.

`process_due_notifications()` isolates the due-schedule, upcoming-refill,
missing-date and urgent-alert stages. A failed stage rolls back its own output,
preserves successful stages and retries naturally on the next sweep. Failures
write sanitized `system_alerts` and PostgreSQL warnings; if the diagnostic
trigger/storage also fails, a second warning remains in database logs. Job
success alone therefore does not establish that every stage succeeded.
Postgres cron and the service role remain authorized; client roles are denied
by grants and body checks. All 24 isolated native PostgreSQL scenarios pass.
No fresh live inspection or deployment was performed. See
`docs/reviews/notification-scheduler-repair-20261018.md` for release requirements
and the bounded schema/cron/delivery evidence.

## Admin credential controls (database released 2026-10-17)

`20261016205533_admin_provider_credentials.sql` adds a private allowlist/metadata
registry and admin-only replacement/completion RPCs. Values are write-only in
the admin app and encrypted in Vault; `get_internal_secret(text)` remains
service-only. The targeted migration was applied as remote version
`20261016205533` and the signed-in Mac admin credential list was verified.
No credentials were seeded or rotated. Local managed Edge consumers resolve
Vault before environment values
on every request/token acquisition and fail closed on Vault errors. The legacy
Zendit Vault alias is read only when no canonical value exists. Other VM,
Coturn and provider changes still require a scoped operational cutover.
The matching Edge consumer releases remain pending; a Vault write must not be
treated as synchronization with existing Edge/VM runtimes.
`operator_confirmed` is a version-bound human attestation of synchronization,
verification and revocation, never automatic provider verification. Each new
replacement returns to pending. The macOS admin build and exact rollout
dependencies are recorded in `docs/reviews/credential-rotation-implementation-20261016.md`.
See `docs/reviews/credential-backend-release-20261017.md` for the database release.

## Local financial remediation (2026-10-16; deployment unverified)

The `20261016010000`–`20261016060000` forward migrations contain RPC/default-grant containment, one owner-checked SIM finalizer, transactional ledger/funding allocation, claim-based atomic refund settlement, state-aware hold recovery, receipt-backed entitlements, canonical pricing and retail-only customer contracts. The funding trigger is the single writer of lots for **new completed ledger inserts**; hold/call capture must not also consume lots. `wallet_transaction_funding` records original consumption for reversals. Unknown legacy reversals require reconciliation; no historical balances or lots are automatically adjusted.

Deploy the matching `process-wallet-refund` source with the wallet migration during a controlled processing pause; the old handler writes wallet/lot rows independently and must not coexist with the new trigger. The authoritative `../backend-sync-wt/worker_instant_refill.js` now calls `begin_refill_submission` before purchase and `settle_instant_refill_execution` after confirmed delivery. Deploy it with `20261016025000` before resuming instant work or enabling recovery. Old reservations retain recovery contract version 0 and require explicit reconciliation. Do not run an unfiltered migration push across the unsafe pending October 4 pricing migration. See `docs/reviews/supabase-financial-security-remediation-20261016.md` for verification, history handling and rollout gates. Isolated SQL/concurrency results do not establish live deployment or historical reconciliation.

## Financial test production contracts — 2026-10-17

Task 6 is **COMPLETE LOCALLY; FINANCIAL RELEASE GATES REMAIN RED**. The main
financial fixture now reconstructs 42 captured public tables, 651 exact columns,
217 constraints (including the ledger type CHECK and NOT VALID positive-amount
CHECK), 76 unique indexes, API/column/EXECUTE ACLs, 64 RLS policies, 42 real
functions, 11 selected actual triggers and the live reconciliation view. Catalog
comparison and three positive safeguard blocks pass; actual pending October 16
migrations are applied unchanged. The old pre-October-4 history mode is removed.

PGlite reports 11 passing / 5 failing financial blocks. Native PostgreSQL reports
16 passing / 6 failing blocks/scenario groups, including the fixture guards.
Both financial commands exit 1. Confirmed defects are excluded `refund_payout`
and `verification_debit` discriminators and lost original funding provenance for
`esim_purchase_refund` / `call_refund`. The old permissive fixture's green results
are superseded. Tasks 7–8 must fix these contracts without weakening the fixture.

The snapshot includes a read-only reproducible export query and static live
producer/consumer fingerprints. It deliberately omits 34 trigger chains, external
policy/supplier adapters, full Supabase Auth/owner/default-ACL parity, nonunique
indexes, provider delivery and unrelated schemas. It is not a complete production
baseline. No accounting migration or production/provider state changed in Task 6.
See `docs/reviews/financial-production-contracts-20261017.md` for every allowed
type, desired accounting semantics, exact evidence and limitations.

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

Task 4 reviewed on 2026-10-17: **REPAIRED LOCALLY, NOT DEPLOYED**. See
[endpoint authentication review](../docs/reviews/endpoint-authentication-20261017.md)
and its sanitized live inventory for versions, settings, tests and release order.

- Local Telnyx CDR and liveness callbacks require a valid Ed25519 signature and
  fresh timestamp; missing/malformed verification keys fail closed.
- Local Twilio voice, liveness and SMS require signing credentials and canonical
  URL/form signatures. Forwarded host/proto cannot select the trusted URL.
- New private service-only receipt APIs serialize callbacks per resource and
  deduplicate event IDs. Abandoned processing claims require reconciliation;
  they are never automatically stolen after expiry. Deploy the matching Task 4
  migration before handlers. Existing Telnyx processed IDs remain completed.
- Local voicemail is internal-service-only and derives ownership from stored
  call/DID records, with stable recording IDs. Admin billing verifies user tokens
  through Auth and the existing `assert_admin()` contract; exact internal service
  credentials do not go through an end-user-only authentication flow.
- Local cancellation resolves an owner-scoped voice attempt and uses its stored
  provider resource. It never tries a different provider from caller input.
- Fresh deployed source still has unsafe voicemail/admin/liveness/Telnyx/Twilio
  boundaries. Gateway verification limits the admin exposure; no live forged-token
  bypass was tested. SMS v5 and WhatsApp v7 already fail closed; the old blanket
  SMS/WhatsApp fail-open claim is stale. WhatsApp entrypoint matches unchanged
  local source exactly. Signing-secret presence/validity remains unverified.
- Target config keeps external callbacks at `verify_jwt=false`, user endpoints at
  true, and changes internal voicemail from deployed false to true. Handler-level
  verification remains mandatory independently of gateway configuration.

## Wallet and ledger

### PayPal capture fulfillment — 2026-10-17

Task 5 is **REPAIRED LOCALLY, NOT DEPLOYED**; see the
[review and rollout](../docs/reviews/paypal-capture-fulfillment-20261017.md).
Client capture and the COMPLETED webhook use a single service-only
`fulfill_paypal_capture(text,jsonb)` API. Trusted Edge code retrieves completed
provider evidence, binds owner/purpose/merchant/exact USD cents, and never
substitutes an order ID for a capture ID. Capture retries share a stable provider
request ID; already-captured/timeout outcomes require authoritative retrieval.
Receipt capture/order uniqueness and locks couple wallet credit, canonical ledger
reference, one funding lot and visible captured status in one transaction.
APPROVED only initiates/adopts provider capture. Missing/inconsistent historical
funding or order-ID credits are quarantined, not backfilled or credited again.
The independent migration works with captured-live credit and pending M2 deposit
code. New order creation pins required PAYPAL_MERCHANT_ID; rollout requires that
configuration and coordinated create/capture/webhook replacement. Numeric receipt
metadata and existing legacy plan recording remain compatible. The local focused
fixture retains actual live payment-table constraints; it does not close Task 6's
broader financial harness/refund/reversal blockers. Live settings/source and
bounded aggregate checks were read-only; no current historical loss is asserted.

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

## SIM setup and instant settlement — Task 9, 2026-10-17

**REPAIRED LOCALLY; NOT DEPLOYED.** The CLI-generated forward migration
`20261016235338_sim_setup_instant_settlement.sql` completes the existing October
16 repairs. Instant submission requires a funded hold bound to the actual payer,
wallet, USD amount, purpose, execution/setup reference, owned line and current
funding allocations. The marker commits before purchase; delivery capture checks
the same binding and an identical provider identity on retries. Setup fee capture,
plan receipt and supported schedules finalize atomically; the initial refill's
existing ledger capture is adopted, never charged again. Legacy version-0 or
unproven delivered reservations require reconciliation.

The authoritative instant worker uses `fail_instant_refill_before_submission`
instead of releasing from a stale snapshot. Unknown submission/settlement states
retain their reservations and cannot downgrade already delivered work. Setup
release, cancellation and fallback serialize with submission through the setup
order/execution/wallet locks. Standard fallback still calls the pending
`membership_fee_usd` interface; free fallback retains a notify schedule.

One `finalize_sim_setup_order(uuid,uuid DEFAULT NULL)` API remains after a
RESTRICT drop of the obsolete text overload. Owner and matching line checks
precede completed/failed returns. Actual PostgREST resolution awaits authorized
rollout and schema-cache refresh. Task 18 must certify final setup/fallback
pricing; Task 10 must extend this reservation contract to scheduled refill work.
See `docs/reviews/sim-setup-instant-settlement-20261017.md` for evidence and gates.

## Scheduled-refill reservations — Task 10, 2026-10-17

**REPAIRED LOCALLY; NOT DEPLOYED.** Forward migration
`20261017164417_scheduled_refill_worker_contracts.sql` adds service-only atomic
prepare/begin/settle/stop contracts for mini/custom wallet-funded API executions.
Submission requires a bound, exact-price, active/unexpired, version-1 USD hold,
matching payer/wallet/owned line/purpose/reference and valid funding allocations.
Preparation calls canonical fees explicitly: the production fee trigger runs on
INSERT only. The supplier route and reservation snapshot commit before purchase.
Settlement revalidates that snapshot and captures once with provider identity and
PIN/serial/redemption persistence. Unsupported external/unproven prepaid funding
does not receive hold-free success. Unknown outcomes retain money for Task 11.

Both old `update_execution_status` overloads are retired with RESTRICT, but the
VM's legacy instant worker still calls them. Pause and replace it with Task 9's
compatible instant worker alongside both scheduled workers before retiring the
API. Isolated SQL, independent-session races and real PostgREST 16.4 HTTP checks
pass; production versions/cache/provider checks remain open. The existing retained
wallet-migration manifest hash differs from its already-staged source and must be
reviewed for release reproducibility; Task 10 did not edit that migration.
See `docs/reviews/scheduled-refill-holds-worker-contracts-20261017.md`.

## Supplier outcome recovery — Task 11, 2026-10-18

**REPAIRED LOCALLY; NOT DEPLOYED.** Forward migration
`20261017190000_supplier_outcome_recovery.sql` records stable supplier references
and reservation/route bindings atomically with the Tasks 9/10 submission markers.
A new authoritative background worker performs lookups only, with bounded leases,
backoff and operator quarantine. Confirmed delivery captures once and finalizes
setup without an app reopen; confirmed terminal failure releases once. Missing,
conflicting, pending or unknown evidence retains money. Calls/payouts are never
released from expiry alone. Existing executions remain recovery version 0; direct
clients cannot manufacture the trusted version/marker. Do not bulk promote legacy
rows. The reaper quarantines uncertainty in place and new submissions block
unresolved sibling supplier work on the same line under the payer wallet lock.
Reaper/expiry allow the actual postgres cron caller plus service_role; claim and
completion APIs remain service-only. Compatible workers, provider-account proof,
legacy review and coordinated release are required before activation. See
`docs/reviews/supplier-outcome-recovery-20261018.md` for evidence and gates.

## Liveness verification repair (local, undeployed — 2026-10-18)

Task 12's `20261017201740_liveness_verification_contract.sql` closes legacy
`confirm_line_verification` and `settle_line_verification_attempt` APIs. New
`begin_line_verification`, `bind_line_verification_resource` and
`settle_line_verification_event` are service-only. Attempts/allowances are
customer-read-only under existing ownership RLS; an invoker trigger prevents
client insert/update of provider verification fields, including power-user
clients. Settlement binds provider event/method/resource to the current owned
line and exact wallet hold or annual allowance; health ignores log prose.
The matching Edge/shared callback and both clients are part of the release.
The live check still permits self-confirmation and lacks the verification debit
CHECK value/new APIs. This local work does not certify deployment. Read
`docs/reviews/liveness-verification-repair-20261018.md` before activation.


## Calling budget contract — Task 13, 2026-10-18

**REPAIRED LOCALLY; NOT DEPLOYED.** Forward migration
`20261017203115_call_budget_contract.sql` adds atomic service-only call creation,
funded tariff/fee/increment/duration snapshots, durable per-leg submission markers,
provider evidence and serialized capped settlement. Wallet locks prevent distinct
calls sharing allocations; retries adopt the original call without resubmission.
Unknown terminations retain money. Late destination bridge evidence can settle
stored terminal evidence; the app leg alone cannot release a submitted destination.
Legacy calls are quarantined instead of directly debiting unreserved funds.
The live check still lacks this API/columns and required Task 4/7 migration versions.
Release with matching make-call, both call-media bundles, telnyx-cdr/media-events
and retail estimate changes after legacy/provider review. Read
`docs/reviews/call-budget-billing-20261018.md` for tests and recovery/release gates.


## eSIM actionable alerts — ESIM-05, 2026-10-28 (deployed)

Migration `20261028014938` adds private policy/cycle/event ledgers and service-only
sweep/relevance APIs. The existing notification trigger and outbox v8 restrict
`esim_*` events to push; in-app rows retain their existing owner RLS. Outbox sends
recheck current owner/cycle/authenticated observation freshness after delay, use
saved preferences/IANA quiet hours, and retain existing target outcomes. Only the
fulfillment helper/process changed on the VM. New sales remain disabled; no money
or provider action is authorized by alerts. A later recharge settlement must open
a new alert cycle atomically from proven entitlement evidence, never from byte or
expiry changes. See `docs/reviews/esimaccess-alerts-20261028.md` and its deployment
receipt. Real profile/device-delivery acceptance remains unverified (no profiles).


## eSIM installation data — ESIM-06, 2026-10-28 (client tested, unpublished)

Installation/recovery reuses the existing invoker/owner-RLS profile projection;
no migration, Edge or VM change is required. Client profile/order providers watch
account identity and fence pending old-account refreshes. Installation screens
and actions check the current owner before exposing a loaded activation payload.
A strict parser constructs only the fixed-host Apple Universal Link; no tracked
redirect, analytics event or remote QR image receives the payload. An installed
profile is not prompted to reinstall. Conditional deleted-profile recovery
requires recent confirmed active status, known future expiry and original-device
attestation, without claiming device identity was verified. Opening native setup
never updates provider/installation/financial state. See the ESIM-06 review and
source manifest; real Apple/profile acceptance remains unverified.


## eSIM recharge discovery/quotes — ESIM-07, 2026-10-28

Private cache/quote/policy tables have RLS and no client access. Three explicit
customer definer RPCs validate auth.uid(), ownership, supplier/account/state,
cache/version/price/expiry and unresolved issuance; Edge validates a user JWT
and retains customer SQL authority. Service jobs use bounded leases and the
existing account limiter. No acceptance or wallet/provider mutation API is added.
Quotes never reserve funds; ESIM-08 must atomically consume the unique acceptance
key in its future operation and extend sibling-action serialization. Expected
advisor notices for these owner-checked RPCs/private tables are documented in
`docs/reviews/esimaccess-recharge-discovery-20261028.md` with passing role denials.


### ESIM-08 settlement boundary — 28 October 2026
New owner/session-bound acceptance and checkout RPCs create durable esim_op: holds
through actual wallet primitives. A private capture context protects escrow from
legacy direct writers while allowing legitimate capture; capture locks wallet
before hold. Unknown provider outcomes retain funds; proven original-payer legacy
refunds are bounded by actual ledger evidence. Service-only receipt/settlement
RPCs use persisted intent references; customer/Admin reads redact credentials and
wholesale values. Order view invoker/barrier options are explicitly restored in
20261028042532 and tested under non-owner RLS. No new anonymous RPC execution.
All financial enablement flags remain false pending provider/wallet acceptance.
See the ESIM-08 review and final ACL/advisor evidence.


### ESIM-09 daily duration boundary — 2026-10-28
Exact duration totals are imported through a service-only verified-price RPC; no
marketing discount schedule or client price authorizes spending. Private price/
quote tables deny clients. Customer quotes bind account/owner/payer/profile, exact
variant, days, quantity, price revision and expiry. Separate daily enablement and
contract gates default false, alongside the existing disabled money gates.
Daily extension shares the existing reservation/receipt authority and captures
once; it cannot restore daily quota or installed credentials. Missing daily usage
and reset timing stay unknown and cannot drive a low-data alert. See the ESIM-09
review for migrations, deployed source hashes, permission and concurrency evidence.
