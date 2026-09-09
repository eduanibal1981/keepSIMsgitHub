# System Architecture

## Context and boundaries

```text
Customer Flutter app ------------------+
                                         | anon/authenticated JWT
Admin Flutter app ----------------------+--------------------+
                                                              |
                                                Supabase project
                                      Auth | Postgres | RLS | RPCs
                                      Realtime | Edge Functions | Cron
                                                              |
                                service-role / signed webhooks |
                                                              |
                 Node workers on VM ---------------------------+
                    |        |          |          |
                 top-up    eSIM     vouchers    offer cache
                    |        |          |          |
                 Zendit / DT One / Ding / Reloadly / eSIM Go / eSIM Access

External inbound: PayPal, Twilio, Telnyx, WhatsApp webhooks
External outbound: push/email/WhatsApp/SMS, supplier purchases, phone calls
```

The customer and admin apps are separate clients over the same backend, schema, identity system, feature vocabulary, and operational workflows. They are not independent products and do not share a compiled Dart package today.

## Intended architecture

`ARCHITECTURE_RULES.md` defines a five-layer, feature-first client architecture:

```text
model/domain -> contract -> repository -> controller/provider -> UI
```

Supporting intentions:

- Riverpod is the dependency/state mechanism.
- Freezed/json serialization is used for immutable models.
- Repositories convert infrastructure exceptions to typed `Result`/failure values.
- Only `lib/core/supabase_client.dart` initializes Supabase.
- UI and controllers do not perform direct Supabase queries.
- Business invariants, authorization, financial mutation, and provider secrets stay server-side.
- SQL migrations are forward-only and secure-by-default.
- Admin mutations use audited `admin_*` RPCs guarded by `assert_admin()`.

## Current implementation

`CONFIRMED` The architecture is hybrid rather than uniformly five-layer:

- Older features commonly use `model/contract/repository/controller/ui`.
- Newer features commonly use `data/domain/presentation`.
- Some repositories return `Result<T>`; others return raw values and throw.
- Riverpod code generation and handwritten providers coexist.
- At least 13 customer presentation/controller/provider files access Supabase directly.
- `calling_repository.dart` creates/exports its provider and returns raw types rather than using a contract/typed failure boundary.
- Several very large screens contain orchestration and business behavior (for example the 3,605-line SIM detail screen).

This is technical debt, not permission to add a third style. New work should use the intended dependency direction while remaining localized.

## Application roles

### Customer app (`keep_sims`)

Primary responsibilities:

- Account authentication, onboarding, profile, device/privacy settings.
- SIM-line registration, ownership, health, liveness verification, activity, usage forecasts, and rescue policy.
- Wallet display and trusted server-side financial actions.
- Scheduled, instant, manual, and offline refill experiences.
- PayPal wallet funding.
- eSIM catalogue comparison, purchase request, installation details, and usage.
- International calling and caller-ID management.
- Notifications, household sharing, referrals, price watch, roaming estimates, and home-screen widget.

The app is Android-first. iOS and other Flutter platform folders exist but are not equally production-configured.

### Admin app (`keep_sims_admin`)

Primary responsibilities:

- Operational overview, health, configuration, scheduled jobs, audit.
- Supplier/carrier routing and offer catalogue control.
- Manual refill, notification channel, eSIM, affiliate, email, offline endpoint, voucher, support, and user operations.
- Analytics and test-console surfaces.
- VM/server administration over SSH/SFTP.

The strongest admin pattern is `core/admin/admin_api.dart`: a central wrapper over audited `admin_*` RPCs. Legacy feature repositories and screens still contain direct table access.

Security boundary: the admin app is an untrusted client. The route currently requires only an authenticated profile. A banner warns when the JWT lacks the power-user claim, but routes remain visible. Actual privileged mutations depend on backend `assert_admin()`; direct reads depend on RLS/table grants. A route-level power-user gate is still required for defense in depth and correct UX.

### Trusted Node workers (`backend-sync-wt`)

Authoritative source: `C:\Users\abdal\Work\KeepSIMs\backend-sync-wt`.

Workers hold the Supabase service role and provider credentials. Major processes:

| Worker | Responsibility |
|---|---|
| `worker_instant_refill.js` | Claims immediate executions, validates an authoritative offer, debits, purchases, records status, refunds failures. |
| `worker_auto_mini_refill.js` | Claims due scheduled mini-refills and executes provider purchase/refund flow. |
| `worker_auto_custom_refill.js` | Claims due custom scheduled refills and executes provider purchase/refund flow. |
| `worker_offers_cache.js` | Polls enabled supplier/carrier pairs into provider offer cache and refreshes materialized offers. |
| `worker_esim_catalog.js` | Imports eSIM catalogues from eSIM Go, Zendit, and eSIM Access. |
| `worker_esim_fulfillment.js` | Fulfills queued eSIM orders, records eSIMs, polls usage, and refunds failures. |
| `worker_voucher_stock.js` | Claims Ding voucher stock jobs and records returned PINs. |

Also present: WhatsApp/Baileys, Telegram, web service, and SIM liveness service processes. The checked-in PM2 config in the customer repo declares only five queue/eSIM workers and uses `./servers/...` paths; it does not cover every authoritative worker. Deployment/process inventory therefore needs reconciliation.

## Core business workflows

### Wallet funding

```text
Customer -> create-paypal-order -> PayPal approval
         -> capture-paypal-order / paypal-webhook
         -> idempotent server-side wallet credit + ledger entry
```

The UI must never trust an amount merely because the browser returned success. Payment capture/webhook state is authoritative. The legacy “payment methods” feature is mock metadata, not a real card vault.

### Refill

```text
Customer request/RPC -> topup_executions row
  -> worker atomically claims row
  -> server-selected carrier/provider/offer
  -> wallet debit RPC
  -> supplier purchase with stable external reference
  -> completion OR explicit failure + refund RPC + alert
```

Direct client-to-supplier purchase violates this architecture. The still-active `execute_zendit_recharge` Edge Function is an alternate path and is a production blocker until removed or redesigned.

### Scheduled refill

Cron and database scheduling create/queue executions; workers claim them. Recovery jobs reap stuck executions. Client retry/cancel/reschedule actions call server RPCs; the historical mock retry flow is deprecated.

### Offline recovery

Two concepts coexist:

- Offline request/event configuration and communication endpoints.
- Pre-purchased voucher inventory/grants, primarily Ding PINs.

The client repository currently supplies fallback mock phone/SMS values when configuration cannot be fetched. Seeded offline endpoint values are documented as nonfunctional placeholders. Do not market this as operational until endpoints and voucher supply are verified.

### eSIM

Customer compares server catalogue -> `request_esim_purchase` -> wallet/order transaction -> trusted fulfillment worker buys provider bundle -> `user_esims` and order status updated -> refund/alert on failure. Catalogue and fulfillment support multiple providers but live credential/response validation varies.

### International calling

Customer obtains rate/caller-ID data and invokes `make-call`; Telnyx/Twilio webhooks update call state/CDRs; `debit_wallet_for_call` charges by call reference. Current preflight checks a small minimum balance but does not reserve the maximum call cost. The debit function can record the full cost while clamping the wallet at zero, so collection and ledger semantics require redesign before material usage.

### Notifications

Database jobs produce notification rows; dispatch Edge Functions fan out to delivery channels and record attempts. Client push registration uses OneSignal and Firebase. Some webhook/proxy source and deployment state diverge; see `DATA_BACKEND_SECURITY.md`.

## Configuration and environment

- Customer app Supabase URL/anon key are compiled client configuration in `core/supabase_client.dart`.
- Worker secrets come from untracked VM/server environment variables; `.env.example` documents names only.
- Edge secrets are held in Supabase secrets and are not inspectable from source.
- Feature flags live in `system_configs` and are read by backend/admin surfaces.
- Customer Sentry DSN and OneSignal app ID currently have hardcoded defaults/values; treat them as environment-specific operational configuration even though they are not service-role secrets.
- Local `supabase/config.toml` declares only a small subset of function settings and cannot be treated as a deployment manifest.

## Error handling and validation

Strengths:

- Many legacy repositories translate PostgREST/network failures to `AppFailure` and `Result`.
- Server money paths use explicit RPCs and several provider adapters use adopt-on-retry behavior.
- Database constraints/RLS/RPC validation cover significant business rules.

Gaps:

- Newer repositories often throw raw exceptions.
- Some UI/controller layers own parsing/network error decisions.
- Provider contract validation is uneven; one current worker safety test fails.
- Several webhook handlers fail open when their verification secret is absent.
- Offline mock fallbacks can make unconfigured infrastructure appear usable.
