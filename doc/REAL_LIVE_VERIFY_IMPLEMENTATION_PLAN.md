# Real live verify — implementation plan for the AI executor

Prepared: 8 September 2026. Status: planning only; no application, database, or provider changes have been made for this request.

## 1. Objective and confirmed requirements

Implement this feature across the customer app at `C:\Users\abdal\Work\KeepSIMs\keep_sims` and the admin app at `C:\Users\abdal\Work\KeepSIMs\keep_sims_admin`, using their shared Supabase backend.

The owner requested:

1. Separate the last recharge date and its **Update** button from live SMS/call verification.
2. Replace **Check Call** with **Real live verify**. Clicking it opens the method-selection dialog, without initiating or charging for a verification.
3. Charge Free-plan SIMs according to their country and selected method. Add `sms_verify_cost` and `call_verify_cost` to the existing `countries` table. The owner enters these USD prices manually in the admin UI. NULL means zero.
4. Standard and Premium each include **one free verification per paid SIM per subscription year**. The owner explicitly confirmed the per-SIM scope. SMS and voice share that one allowance: using either consumes it; there are never separate free SMS and voice allowances.

The screenshots are visual references for the existing screen and dialog. Text inside them describes the old UI; it is not an instruction to preserve misleading labels or existing implementation behavior.

## 2. Recommended product decisions

These are implementation defaults proposed by this plan, rather than additional requirements stated by the owner. Keep them centralized and documented so the owner can change them without redesigning the feature.

| Topic | Recommended default |
|---|---|
| Additional Standard/Premium checks | After the annual allowance is used, apply the same country/method retail price as Free. |
| Charge timing | Reserve wallet funds at dispatch; capture only on a successful verification result. An unsuccessful result releases the hold. KeepSIMs absorbs any provider expense for unsuccessful attempts. |
| Allowance timing | Reserve the one allowance at dispatch; consume on success; release on definite failure. |
| Zero country price | Charge USD 0.00 for every supported request. Do not consume the paid SIM's annual allowance for a method already priced at zero. |
| Subscription year | Use the actual paid subscription period, not January–December and not 365 days after the first verification. Existing purchase code uses 365-day periods; preserve that billing behavior. |
| Carryover | None. An unused allowance expires with its subscription period. |
| Upgrade | Standard → Premium within the same period does not create another allowance. |
| Expiry/downgrade | New requests no longer receive a paid-plan benefit. Existing reservations settle using their recorded eligibility and price. |
| Payer and access | Initially only the SIM owner may initiate live verification and spend their wallet. Household viewers/managers may see the permitted result; preserve existing manager rights for manual recharge recording. Delegated spending needs an explicit separate policy. |
| Method names | **Verify via SMS** and **Verify via missed call**. Keep provider names and `verifySMS0` out of customer copy. |
| Unsupported method | Disable it with a reason. NULL/zero price does not imply provider availability. |

Do not silently change to charging for every attempt. If the owner later selects that model, revise both settlement rules and the displayed charge explanation together.

## 3. Findings from the current source

These are local-source observations, not proof of production deployment. Recheck the current working tree and live schema before implementing; several relevant files and September 8 migrations already contain uncommitted work.

| Existing location, relative to customer app unless marked Admin | Finding and required treatment |
|---|---|
| `lib/features/sim_lines/presentation/screens/sim_line_detail_screen.dart`, combined status bar around lines 726–916 | Recharge and reachability share one conditional row. The date can be truncated. Check Call is hidden for a carrier-confirmed line. Replace this with independent panels and keep verification available independently of recharge status. |
| `lib/features/sim_lines/presentation/widgets/manual_recharge_dialog.dart` and `sim_line_detail_controller.dart` | Reuse the existing manual recharge dialog/controller flow. Its Update action should remain free and should record an external recharge. |
| `supabase/migrations/20260826000000_sms_patterns_and_manual_recharge.sql` | `record_manual_external_recharge` inserts a `manual_external` topup execution and updates `last_topup_at`. Audit downstream triggers so this cannot create live-verification evidence. |
| `number_verification_dialog.dart` and `line_verification_controller.dart` under the same presentation tree | Method selection immediately dispatches today. The controller polls providers and confirms success from the client. Replace with quote → start → server-owned status. |
| `lib/features/sim_lines/data/repositories/sim_lines_repository_impl.dart` | `checkCallStatus` accepts busy/no-answer as success. `confirmLineVerification` falls back to direct client updates of verification and health. Remove these authority paths. |
| `supabase/functions/liveness-verification/index.ts` | Authenticates callers but accepts arbitrary phone numbers and provider IDs. It has no per-line ownership, pricing, quota, or wallet orchestration. Replace these actions with attempt-scoped operations. |
| Same Edge Function / SMS controller | The SMS is a normal text payload. The UI calls it Silent SMS, and the controller treats `sent` after four seconds as success. Use truthful SMS copy and require delivery evidence. |
| `supabase/migrations/20260831100000_confirm_line_verification_rpc.sql` | The old RPC lets an owner assert success without provider evidence and sets health to 100. Replace/restrict it; never use it as proof of a paid check. |
| `supabase/functions/validate-sim-liveness/index.ts`, `carrier_liveness_badge.dart` | Carrier lookup/BSS checks are a separate concept. Do not route them into the annual SMS/voice allowance. |
| September 8 setup migrations, including the latest `20260908220000_auto_notify_schedule_and_instant_activation.sql` | Setup activation also writes generic verification fields. Latest local setup code uses `carrier_status='active'`, while the detail screen checks `'confirmed'`. Do not derive new live-check evidence or recharge provenance from these overloaded fields. |
| `supabase/migrations/20260907100000_wallet_holds_lots_and_refunds.sql` | Reuse `wallet_holds`, `wallet_transactions`, funding allocations, and reserve/capture/release functions. Zero-value holds are invalid, and the hold order-type allowlist needs an explicit verification type. |
| `lib/features/sim_lines/data/models/sim_line_model.dart` and `has_paid_premium_entitlement` in the September 8 migration | Plans belong to SIMs. `plan_type` is authoritative over legacy `protection_tier` and account subscription labels. Existing paid-entitlement evidence must be checked for Standard as well as Premium. |
| Admin: `lib/core/admin/admin_api.dart` and `admin_providers.dart` | The existing admin control plane uses privileged `admin_*` RPCs and `admin_audit_log`. Extend it; do not copy the older direct country-update pattern. |
| Admin: `lib/features/server_management/presentation/screens/server_dashboard_screen.dart` | Existing country routing list manages WhatsApp routing. Add a clear pricing destination instead of hiding retail prices among server connection settings. |

## 4. Customer UI specification

### 4.1 Protection Console

Use two stacked compact panels under SIM identity, each with its own icon, title, date/status, and action. Suggested layout:

```text
Last recharge                         [Update]
08 Sep 2026 · Today
Recorded by you / Confirmed recharge

Live verification              [Real live verify]
Last successful check: 08 Sep 2026, 14:30
SMS delivery confirmed
1 free verification available this subscription year
```

The example dates are illustrative only. Display the recorded recharge source independently of the live-check method. Use **No recharge recorded** when `last_topup_at` is absent. Show **Not checked yet** when no trusted live-check record exists.

Allow text to wrap on small phones and at large text scales. Use usable touch targets rather than the existing tiny inline buttons. Support light/dark themes and existing localization/RTL conventions.

The Update button only opens `ManualRechargeDialog`. A live check never changes `last_topup_at`, `next_topup_due`, validity, refill schedules, rescue timers, recharge provenance, or carrier-confirmed recharge state. A manual recharge never changes live-check status/date/method or allowance use. Preserve legitimate recharge scheduling behavior within the recharge flow.

A recharge performed through KeepSIMs must not hide Real live verify. Opening/closing the verification dialog must not send SMS, start a call, reserve money, or reserve an allowance.

### 4.2 Method dialog and confirmation

Title: **Real live verify**. Show the SIM number and country, then **Check whether your number can receive an SMS or a call. This does not recharge your SIM.**

Fetch a fresh server quote when the dialog opens. Show a loading state first; never temporarily display USD 0.00 because a request failed or a cache is empty.

| State | SMS button example | Call button example | Supporting copy |
|---|---|---|---|
| Free, prices configured | Verify via SMS · USD 0.05 | Verify via missed call · USD 0.12 | Price depends on this SIM's country. |
| Paid, allowance available | Verify via SMS · Free (USD 0.00) | Verify via missed call · Free (USD 0.00) | One free verification this subscription year. Choose SMS or call; using either uses the allowance. |
| Paid, allowance used | Verify via SMS · USD 0.05 | Verify via missed call · USD 0.12 | Annual free verification used. Next allowance starts [server date], subject to renewal. |
| Country method price zero/NULL | Verify via SMS · Free (USD 0.00) | Price for call independently | This method is free for this country. |

Prices above are examples, not seeds or proposed production rates. If a zero-priced method preserves the annual allowance, explain this in supporting text instead of showing it as annual-benefit consumption.

Selecting a method opens an inline confirmation showing the number, method, exact USD amount, wallet availability, and annual allowance impact. Buttons: **Start verification** and **Back**. Paid copy: **We'll reserve USD X.XX and charge it only if verification succeeds.** Included copy: **This uses your one free verification for this subscription year if successful.** No automatic SMS→call fallback: a second method always needs a new user choice and quote.

For insufficient funds, show **Add funds** using the existing wallet flow. After returning, reload the quote and require Start again. Do not automatically dispatch after funding.

While running, disable new starts and show honest progress: Sending SMS / Waiting for delivery / Calling your number / Checking result. The user may close the dialog; server completion, call termination, and settlement must continue. Reopening resumes the existing attempt rather than starting another one.

Show success, unsuccessful check, and still-pending states distinctly. A short UI polling timeout is not a failed verification and must not release money or allowance. After settlement, refresh the live result, allowance, and wallet. An unsuccessful new attempt should not erase the timestamp of a previous success; show both latest attempt outcome and last successful check where appropriate.

## 5. Shared data model

Use forward migrations in `keep_sims/supabase/migrations`. Discover the CLI and migration workflow at execution time. Never edit applied migrations or assume local migration files are already deployed.

### 5.1 Country retail prices

Extend `public.countries`; do not create a duplicate country catalog:

| Column | Proposed definition | Meaning |
|---|---|---|
| `sms_verify_cost` | `numeric(12,2)`, nullable, default `0` | Customer price in USD for one successful SMS verification. |
| `call_verify_cost` | `numeric(12,2)`, nullable, default `0` | Customer price in USD for one successful missed-call verification. |
| `verification_price_version` | integer/bigint, not null, default `1` | Version used for stale-quote checks and concurrent admin editing. |

Require finite, non-negative prices; explicitly reject NaN/infinity and excess decimal precision before assignment rather than silently rounding input. Recommended initial precision is cents, matching displayed USD wallet amounts. Add database comments stating that these are retail USD prices, independent of `countries.currency_code` and provider wholesale costs.

All pricing reads use `COALESCE(column, 0)`. Blank admin inputs save zero. Existing NULLs remain valid and read as zero. A missing country row or failed network query is an error, not a zero price. Resolve country from the SIM's trusted country mapping, not current GPS/travel country, user profile, device locale, or client-supplied country. Reject inconsistent number/country mappings; shared dialing prefixes must not pick an arbitrary cheapest country.

### 5.2 Annual allowance records

Proposed `line_verification_allowances`:

- `id`, `sim_line_id`, immutable subscription-period reference or key, `period_start`, `period_end`, originating paid purchase/reference, and timestamps.
- One nullable `reserved_attempt_id` and one nullable `consumed_attempt_id`, with reservation/consumption timestamps.
- Unique `(sim_line_id, subscription_period_key)`; one shared slot for SMS and voice. Validate nonempty period and incompatible reservation/consumption states.
- Index SIM/period and reserved attempt. Use transactional row locks when reserving or settling.

The current SIM model exposes `plan_expires_at`, but no stable subscription-period identifier. The executor must establish that identity from successful paid setup/purchase/renewal records. Reuse an authoritative period table if one exists live; otherwise add a minimal durable paid-period record and connect each activation/renewal path to it. Do not use mutable `plan_expires_at`, `updated_at`, the current month, or a new verification timestamp as the allowance key.

Period rules:

1. A successful initial paid activation creates one period and allowance. A successful renewal creates the next period; early payment does not activate its allowance before the new period starts.
2. Upgrades within a running period retain the period identity and consumed/reserved slot, even if the purchase code currently moves expiry. Do not introduce an allowance reset by calling an existing upgrade path.
3. Pausing protection or entering Travel/Home Mode does not create or stop a subscription year. Renewal cancellation leaves benefits available until the existing paid term ends.
4. Failed payments, refunded/revoked entitlements, expired plans, or merely changing `plan_type` must not mint a free allowance. Validate trusted paid evidence on the server for Standard and Premium.
5. Existing paid SIMs receive one allowance for their current remaining paid period on rollout. Reconstruct period boundaries from trusted purchase/activation records. If inconsistent, report affected SIMs for repair; do not invent a fresh year from deployment time.
6. Historical checks lacking a trusted attempt record do not silently consume the new allowance. Retain their history but label it as legacy if surfaced.
7. Line deletion/recreation must not reset a still-active subscription period. Preserve a stable subscription identity and an auditable number/owner relationship. A legitimately purchased new subscription can create a new period. Do not cascade-delete financial/consumption evidence just to support line deletion.

### 5.3 Verification attempts, quotes, and events

Proposed `line_verification_attempts` stores:

- UUID, `sim_line_id`, requesting actor, owner/payer, country ID, normalized destination snapshot, method (`sms` or `voice`), provider, and creation/update timestamps.
- Unique `(actor_user_id, idempotency_key)`, request fingerprint, quote reference, country price/version snapshot, effective retail price, currency, and `funding_kind` (`annual_allowance`, `wallet`, `country_zero`).
- Subscription-period/allowance reference, `wallet_hold_id`, captured transaction reference, and provider resource ID with a provider-scoped unique constraint when non-null.
- Dispatch state, verification result, settlement state, evidence event/time, deadline, completion time, failure code, and reconciliation timestamps. Keep verification outcome separate from financial settlement so capture failures remain recoverable.
- Suggested dispatch states: `reserved`, `dispatching`, `pending`, `terminal`, `reconciliation_required`. Result: `pending`, `succeeded`, `failed`, `inconclusive`. Settlement: `reserved`, `captured`, `consumed`, `released`, `no_charge`, `reconciliation_required`.

Use a unique partial constraint/index to allow only one unresolved attempt per SIM across both methods, plus a database-enforced allowance reservation. A different request key must not bypass an in-progress attempt.

Store short-lived, server-owned `line_verification_quotes`, or an equivalent tamper-proof server token backed by server validation. Bind quote to owner/actor, SIM, normalized phone, country, both method prices, eligibility/period, price version, and expiration. A two-minute quote TTL is a recommended starting value. These records never reserve money or allowance.

Store a minimal deduplicated provider event inbox with provider/event ID, linked attempt, verified event time, normalized result, and processing state. Retain only necessary payload details under existing retention rules. Provider credentials never enter these records or customer responses.

For the detail screen, expose last successful attempt/method/time and the latest attempt result through an authorized RPC/read model. Optional cached `last_live_verified_at`, `last_live_verification_method`, and `last_live_verification_attempt_id` on `sim_lines` must be server-written projections of the attempt ledger. Never backfill them from generic `verification_status`, `carrier_status`, or `health_score`.

### 5.4 Wallet and activity integration

Add a `line_verification` order type to the existing wallet-hold allowlist, preserving all other types. In `20260907100000_wallet_holds_lots_and_refunds.sql`, `wallet_holds.order_type` has an explicit CHECK constraint; the new migration must alter this constraint:
```sql
ALTER TABLE public.wallet_holds DROP CONSTRAINT IF EXISTS wallet_holds_order_type_check;
ALTER TABLE public.wallet_holds ADD CONSTRAINT wallet_holds_order_type_check
  CHECK (order_type IN ('refill_instant', 'refill_scheduled', 'plan_fee', 'esim_purchase', 'call_budget', 'offline_voucher', 'refund_request', 'line_verification'));
```
Use the attempt UUID as the stable order reference. Add an explicit `verification_debit` transaction type if needed by the current transaction constraints and all wallet/admin renderers. Inspect capture function allowlists and metadata conventions before selecting the exact type.

Reuse existing atomic reservation/capture/release and funding-lot accounting. Do not directly subtract from `wallets.balance`. Available funds must subtract all active holds across features. Free/annual requests create no zero-value holds or fake zero-value debits; their attempt records provide the audit history.

Record verification activity independently from recharge history. Do not create `topup_executions` to represent SMS or voice checks. Optional provider cost is a separate internal field; it never replaces the country retail charge.

## 6. Backend API and execution flow

Proposed names below are new contracts. The executor may adjust names consistently with repository conventions, preserving their guarantees.

| Contract | Inputs | Required behavior/response |
|---|---|---|
| `quote_line_verification` | `sim_line_id` | Authenticate/authorize; read trusted country and paid period; return quote ID/expiry, method availability, base/effective USD prices, benefit reason, remaining allowance, period end, wallet availability, existing pending attempt. No provider calls or reservations. |
| `liveness-verification`, action `start` | `sim_line_id`, `method`, `quote_id`, `idempotency_key` | Revalidate quote and entitlement, atomically reserve attempt plus allowance or funds, dispatch through server adapter, return attempt ID and server state. Never accept authoritative price, tier, user ID, phone, or provider ID from the client. |
| `get_line_verification_status` / status action | `attempt_id` | Authorize attempt access; return stored outcome/settlement and relevant display data. Resume-safe and free to read. |
| Internal reserve/finalize/reconcile functions | Attempt reference and trusted evidence | Restricted to backend service. Atomic, idempotent settlement; no arbitrary client claim of success. |
| `admin_list_country_verification_prices` | Search/pagination | Authorized list including zero/NULL effective prices and price versions. |
| `admin_update_country_verification_prices` | Country ID, both prices, expected version | Validate admin claim and inputs; lock row; update only pricing columns/version; write before/after audit; return saved row. Reject stale edits. |
| `admin_list_line_verification_attempts` | Date/country/method/outcome filters | Read-only operational support view including settlement state and correlation ID. No broad raw-provider-data exposure. |

Start sequence:

1. Validate session, owner, SIM eligibility, method availability, destination-country consistency, rate limits, and request shape.
2. Look up the idempotency key first. Same key and identical input returns the existing attempt even if its quote has since expired; same key with different input is a conflict.
3. Begin a short database transaction. Lock records in one documented, consistent order: SIM/paid period, allowance, then wallet as required by existing wallet functions. Check for an unresolved attempt and validate current quote price/version/eligibility.
4. If the price increased, country/number changed, quote expired, or free eligibility changed, return `QUOTE_CHANGED` with a fresh quote. Never silently change Free to paid, charge a higher amount, or switch methods.
5. Reserve the shared allowance if a positive-priced method is included; otherwise reserve the quoted wallet amount or record `country_zero`. Write the attempt and dispatch job in the same transaction. Commit before contacting the provider.
6. A durable dispatch worker claims the job once, calls the provider with a supported idempotency mechanism where available, and records the resource ID. An Edge Function may perform an immediate claimed dispatch, but the durable job must survive process termination.
7. If submission definitely failed before acceptance, release the reservation once. A transport timeout after submission is ambiguous: reconcile rather than automatically resending or releasing.
8. A signed callback or trusted server-side provider lookup validates evidence, associates it with the stored destination/resource ID, and performs settlement in a transaction. Successful paid checks capture exactly once; included checks consume exactly once. Definite failures release exactly once.
9. Refresh the server read model and append activity. Wallet/allowance settlement retries must never redispatch a provider request.

Use stable error codes such as `UNAUTHORIZED`, `LINE_NOT_FOUND`, `OWNER_REQUIRED`, `METHOD_UNAVAILABLE`, `COUNTRY_UNRESOLVED`, `QUOTE_CHANGED`, `INSUFFICIENT_FUNDS`, `ATTEMPT_IN_PROGRESS`, `RATE_LIMITED`, `PROVIDER_UNAVAILABLE`, and `RECONCILIATION_PENDING`. Convert them into localized messages; do not expose raw exception/provider payloads.

## 7. Provider evidence and reliability

SMS success requires carrier delivery confirmation, not provider acceptance, queued, sending, or sent status. Telnyx distinguishes `message.sent` from terminal `message.finalized` and distinguishes delivered from failed/unconfirmed delivery. Specifically, the backend must require `message.finalized` with `to[0].status = 'delivered'`. Naive client assumption of success after 4 seconds is abolished. Because telecom carrier delivery receipts (DLR) typically take 5 to 25 seconds, the customer UI must display a clear, non-blocking stage ("Awaiting telecom carrier handshake..."). If the user closes or backgrounds the dialog, verification processing, webhook receipt, and financial settlement proceed asynchronously without cancellation or double-charging. [Telnyx messaging webhooks](https://developers.telnyx.com/docs/messaging/messages/receiving-webhooks)

For missed calls, configure Twilio call dispatch with explicit `StatusCallbackEvent: ['ringing', 'answered', 'completed']` pointing to the dedicated verification webhook. A verified `ringing` event is authoritative evidence that the cellular tower paged and attached to the handset, yielding **Call reached your number**. To protect customer privacy and eliminate unnecessary provider costs, as soon as the server validates the `ringing` event callback, it immediately issues a Twilio call cancellation (`Status = 'canceled'`). Busy, no-answer, or a generic completed callback without a prior verified ringing event must not be treated as successful evidence. A later cancellation following a verified ringing event must never undo the recorded reachability success. [Twilio Call resource and status callbacks](https://www.twilio.com/docs/voice/api/call-resource)

Move all call and SMS termination logic strictly to the backend. App backgrounding or closing must not leave telephony sessions dangling or release valid reservations prematurely. Do not promise a fixed number of rings across international mobile operators.

Use purpose-specific callback handlers for live verification, or explicitly route existing handlers by verified provider resource ID. The existing SMS/voice webhooks serve other workflows; do not assume they are outbound verification callbacks. Every relevant handler must reject missing signature configuration, invalid signatures, and unrecognized resource/destination associations. Deduplicate and tolerate out-of-order delivery. Respond promptly after durable event receipt and process settlement reliably.

A durable reconciliation task must cover abandoned reserved attempts, provider submission ambiguity, missing callbacks, stale holds, failed capture, and interrupted call termination. Check current provider APIs/SDKs before relying on request idempotency: a local UUID alone does not make provider submission exactly-once. If provider acceptance cannot be established safely, keep `reconciliation_required` and avoid resending.

Recommended initial controls: one unresolved attempt per SIM, 60-second retry cooldown, and 10 dispatch attempts per SIM per UTC day, with additional account/IP limits. Apply limits equally to free, zero-priced, and failed requests to bound provider expense. Keep these defaults configurable on the server.

Define provider-specific deadlines from tested behavior, rather than the old 15/24-second client timers. Protect unresolved dispatched holds from the generic wallet expiry sweeper. At a bounded reconciliation deadline, do a final provider check; if still inconclusive, release the customer reservation and record terminal no-charge inconclusive. Persist that settlement decision: a late success can append evidence but must not create a surprise charge or take a newly reused allowance. Late events for a SIM whose number changed must not update its current live-status projection.

## 8. Authorization and bypass closure

Enable RLS and explicit grants on new exposed tables. Customer reads are limited to permitted SIM/attempt records; financial writes, allowance mutations, quote writes, provider-event insertion, and success projection updates are backend-owned. Put internal privileged functions in a non-exposed schema where practical; use safe search paths, explicit role checks, and revoked PUBLIC/anon execution. [Supabase RLS guidance](https://supabase.com/docs/guides/database/postgres/row-level-security)

Validate Edge Function sessions on the server and enforce ownership separately from authentication. Admin writes use the existing trusted `app_metadata.is_power_user` check, suspension check, and audit conventions. Never authorize with user-editable metadata or a hidden admin button. [Supabase Edge Function authentication](https://supabase.com/docs/guides/functions/auth)

Mandatory cutover work:

- Reject or retire legacy arbitrary-phone `twilio_trigger_call` / `telnyx_send_sms` actions. Old app builds must receive an update-required response, not an unpriced fallback.
- Replace provider-ID-only status/cancel actions with attempt ownership checks.
- Remove `confirmLineVerification`'s direct-write fallback and public ability to assert live verification without trusted evidence.
- Explicitly revoke the dangerous column grant granted in `20260831100000_confirm_line_verification_rpc.sql`:
  ```sql
  REVOKE UPDATE (verification_status, health_score) ON public.sim_lines FROM authenticated;
  ```
  Verification status and health score must only be modified by backend service-role executions upon validated provider evidence.
- Audit effective table-level AND column-level grants. Revoking a column grant does not defeat an existing table UPDATE grant. Protect server-owned projections and legacy success fields through the effective grant/RPC/trigger model while preserving legitimate SIM edits and onboarding workflows.
- Keep SIM setup activation, OTP/ownership verification, BSS lookups, ordinary app calling, recharge processing, and the six-month `free_line_grants` program separate from this annual live-check benefit. Audit each for accidental calls into the retired endpoint.

## 9. Customer app implementation work package

Paths below are relative to `C:\Users\abdal\Work\KeepSIMs\keep_sims`.

1. Extract `last_recharge_panel.dart` and `live_verification_panel.dart` under `lib/features/sim_lines/presentation/widgets/`; integrate them in `sim_line_detail_screen.dart`.
2. Extend `number_verification_dialog.dart` with server quote, confirmation, wallet-required, resume, and settlement states. Keep Real live verify capitalization exactly as requested for the action label.
3. Replace provider-centric behavior in `line_verification_controller.dart` and adapt `line_verification_state.dart`. Timer disposal stops local polling only; backend jobs keep running. Do not overlap async polling calls or write state after disposal.
4. Add typed quote/attempt/allowance response models and a verification contract/repository, following feature layering. Update `sim_lines_repository.dart` / `sim_lines_repository_impl.dart` call sites consistently; remove obsolete direct dispatch/confirmation paths. The existing Telnyx/Twilio datasource files must no longer expose unpriced bypasses.
5. Add the two country fields and price version to `data/models/country_model.dart` if countries are displayed/cached by the customer app. Treat them as reference data; executable prices always come from the fresh server quote. Update explicit select lists, fallback mappers, and cache compatibility.
6. Add server-derived live-verification read fields or a dedicated provider. Generic `verification_status` must not drive the new panel. Recharge source must come from verified execution provenance; if legacy source is unclear, show the date without inventing confirmation.
7. Update wallet transaction presentation for verification debits, and invalidate the existing wallet controller after settlement.
8. Add strings to localization sources under `lib/l10n`; regenerate localization/Freezed/Riverpod outputs with existing tooling. Do not hand-edit generated Dart.

## 10. Admin app implementation work package

All paths in this section are relative to `C:\Users\abdal\Work\KeepSIMs\keep_sims_admin`.

### 10.1 Country pricing screen

Add **Verification pricing** to the admin navigation, route `/verification-pricing`, near Carriers. Use a searchable, paginated country list with columns:

**Country | ISO | SMS verification (USD) | Call verification (USD) | Edit**

Include all countries, with supported status visible/filterable. Show NULL as USD 0.00. Provide a zero-price filter so the owner can quickly find unconfigured prices. Do not silently initialize prices from supplier tariffs, carrier recharge pricing, or country currency.

The Edit dialog has two numeric fields labeled **SMS verification cost (USD)** and **Call verification cost (USD)**, with help text **Leave blank for USD 0.00. This is the customer price for a successful verification.** Show **Standard and Premium include one SMS or call per SIM per subscription year. Additional verifications use these prices.**

Validate non-negative finite numbers and at most two decimals. Submit both fields atomically through the pricing RPC. Disable duplicate saves, retain entries on failure, close only on success, and invalidate/reload server state. On an optimistic-version conflict, show the new saved prices and require the admin to review their edit. Updating country pricing must not overwrite WhatsApp routing or other country fields.

### 10.2 Integration points

- Extend `lib/core/admin/admin_api.dart` with the new pricing list/update and attempt-list RPC wrappers. Follow `AdminError` mapping and existing power-user/audit behavior.
- Add models/contracts/repository/controller in a focused `lib/features/verification_pricing/` feature following `ARCHITECTURE_RULES.md`: typed data, Result handling, Riverpod AsyncValue, no Supabase calls in widgets. The repository may delegate to AdminApi as the established control-plane transport.
- Register dependencies in `lib/core/providers.dart` and/or the established `lib/core/admin/admin_providers.dart` composition point; keep the new widget-to-controller-to-repository boundaries clear.
- Add `lib/features/verification_pricing/ui/verification_pricing_screen.dart` and a focused edit widget.
- Update `lib/core/router/app_router.dart` and `lib/core/layout/admin_shell_screen.dart` for the destination and existing auth guard.
- Extend `lib/features/sim_lines/data/models/country_model.dart` and relevant country readers/caches with nullable/default-safe pricing fields; regenerate its `.freezed.dart` and `.g.dart` files.
- Reuse `lib/features/control/presentation/audit_screen.dart` to expose price changes, including actor, country, old/new prices, timestamp, and correlation ID. Add event rendering only where its existing generic view is insufficient.
- Provide a read-only verification-attempt list linked from Verification pricing or existing Operations/Support: SIM/owner reference, method, country, amount, annual/zero/wallet reason, outcome, settlement status, and time. Include reconciliation-needed filtering. Do not add an unrestricted “Mark verified” button.

Acceptance example: the admin sets Egypt SMS to USD 0.05 and call to USD 0.12, saves, reloads, and sees those values persist. A new Free-SIM quote uses those exact prices. Clearing SMS to blank saves zero. Neither operation changes WhatsApp settings or previously reserved verification prices.

## 11. Execution sequence and rollout

1. **Inventory and baseline:** Read current repository instructions in both apps and inspect uncommitted changes. Record deployed migrations, function versions/configuration, paid-entitlement sources, wallet constraints/sweepers, grants, and callback capabilities. Preserve unrelated work. Local documents describe context, not authorization for unrelated deployments.
2. **Finalize contracts:** Keep the owner-confirmed per-SIM annual rule. Record the recommended defaults from section 2 in tests and documentation. Identify all purchase/renewal/upgrade paths and establish stable period identity before implementing quota logic.
3. **Backend foundation:** Add country columns, durable period/allowance/quote/attempt/event/dispatch structures, wallet integration, internal transaction functions, admin RPCs, and grants/RLS. Backfill paid periods with a reviewed exception report. Test locally/staging.
4. **Provider orchestration:** Implement start/status adapters, authenticated callback handling, safe call termination, dispatch recovery, and reconciliation. Use sandbox/mocked provider responses before controlled live tests. Verify that signatures, delivery evidence, and country availability work on the actual configured provider accounts.
5. **Admin client:** Implement country pricing editing, audit rendering, and operational attempt visibility. Populate intended country prices manually; all NULLs remain zero by design.
6. **Customer client:** Split panels, implement quoted confirmation and result UI, update models/localizations/wallet presentation, and remove legacy client success assertions.
7. **Staging end-to-end:** Run the acceptance matrix below with Free, Standard, Premium, expired, household, zero-price, concurrency, and failure cases. Test both Flutter apps and the real wallet integration with controlled balances.
8. **Release order:** Deploy additive schema and protected backend contracts first behind an enforced dispatch-enable setting; deploy callbacks/reconciliation; deploy admin pricing UI and configure prices; release the customer app; enable new dispatch and reject old unpriced endpoints as one coordinated cutover. Fail closed for legacy builds rather than leaving a billing bypass. Status/callback processing remains active while new starts are disabled.
9. **Verify rollout:** Record actual deployed versions/migrations, controlled provider results, quota behavior, debit/hold reconciliation, UI screenshots, and admin audit entries. Runtime evidence is required before calling deployment complete.

Rollback: disable new dispatch, keep existing callbacks/reconciliation/status running until all attempts settle, and hide/disable the new action if needed. Do not restore unpriced legacy dispatch or client-authored verification. Retain prices, attempts, period usage, and financial history; reverse mistakes with audited corrections rather than dropping tables.

Operational architecture decision: To eliminate server operational overhead and avoid VM synchronization complexity on Google Cloud VM `34.185.194.90`, do NOT introduce a new Node.js server daemon. Instead, implement verification dispatch and telephony webhook callbacks entirely via Supabase Edge Functions (`liveness-verification` and a dedicated `liveness-verification-webhook`), backed by PostgreSQL transactions and a `pg_cron` reconciliation sweeper for unresolved or stale holds. This keeps all verification ledger, hold settlement, and webhook ingestion consolidated within Supabase.

## 12. Required acceptance tests

| Area | Cases and expected result |
|---|---|
| Separation | Update changes recharge history only; SMS/call success changes live-check history only. Check trigger side effects, due dates, rescue timers, health and validity. Both panels remain visible after provider recharge. |
| Free pricing | SMS and call use their distinct country amounts; zero and NULL both yield USD 0.00. Missing country/query failure blocks dispatch. Travel location does not alter the price country. |
| Paid annual allowance | Standard and Premium each get one per paid SIM/period. SMS then call, or call then SMS: only the first successful positive-priced method is included. A different paid SIM has its own slot. |
| Zero pricing | A zero-priced method works without wallet funds and preserves the paid annual allowance. Unsupported zero-priced methods remain disabled. |
| Subscription lifecycle | Renewal, early renewal, mid-period upgrade, downgrade, expiry, failed/refunded payment, protection pause, number edit, and line recreation follow period rules. No reset on app reinstall, midnight, January 1, or changed device clock. |
| Boundaries | At exact period end old eligibility expires; queued future benefit activates only with the new paid period. Pending old-period attempt settles against its original reservation, never the new slot. |
| Concurrency | Simultaneous SMS/call requests from two devices cannot both take the allowance or overspend the wallet. Different request keys do not evade one unresolved attempt per SIM. Test concurrent spend from other wallet features too. |
| Idempotency | Double tap, network retry, repeated key after expired quote, repeated callback, and repeated settlement produce one provider action and at most one debit/consumption. Key reuse with changed inputs rejects. |
| Quote integrity | Tampered price/tier/phone/country, stale price version, admin edit during confirmation, changed SIM owner/number, and lost allowance require a new quote/confirmation. No automatic higher charge. |
| Wallet | Insufficient available funds causes no provider call; success captures exact held price; definite failure releases exact hold; annual/zero creates no hold. Capture retries preserve funding-lot accounting. |
| Provider truth | SMS sent/queued is pending; delivered succeeds; undelivered/unconfirmed is not success. Busy/no-answer without positive call evidence is not success. Ringing then server cancel remains a successful reachability check. |
| Recovery | Process crash before/after submission, lost provider response, delayed callback, missing callback, callback-before-response, closed app, offline phone, interrupted cancellation, and capture failure settle or enter a visible reconciliation state without duplicates. |
| Late evidence | A terminal no-charge release is not later billed by an old callback; reused/new-period allowance is untouched. Old-number result does not verify a newly edited number. |
| Security | Anonymous, another owner, household viewer/manager, forged admin metadata, arbitrary provider ID, direct success-field update, old confirmation RPC, missing callback key, invalid/replayed signatures, and legacy dispatch all reject unauthorized actions. |
| Admin | Save/reload values, blank→zero, negative/NaN/infinity/excess precision rejection, search/filter, concurrent edits, audit actor/before/after, and unchanged unrelated country fields. |
| UI | Opening/closing never dispatches. Price loading/error never looks free. Large text/narrow phone/RTL/themes do not clip dates or prices. Pending dialog resumes; wallet return does not auto-start. |
| Regression | SIM setup activation, manual recharge, recurring refill, OTP/ownership verification, carrier BSS checks, ordinary calling, wallet refunds and existing free protection grants continue independently. |

Implement meaningful SQL tests under `supabase/tests/` for prices, entitlement periods, grants, reservation/settlement, and cross-feature wallet concurrency. Add provider-adapter/handler tests for callback ordering, evidence and dispatch uncertainty; Flutter controller/widget tests for quote confirmation and separated panels; admin tests for pricing edits. Run affected suites plus relevant existing wallet/grant/refill suites. Run code generation, formatting, analyzer, and appropriate app builds in both repositories. Record pre-existing failures separately rather than hiding them.

## 13. Executor handoff and definition of done

Give the executor this document with the instruction:

> Implement this plan across keep_sims, keep_sims_admin, and the shared backend. The confirmed benefit is one SMS OR voice verification per paid SIM per subscription year. Preserve existing uncommitted work and existing recharge behavior. Complete the server pricing/allowance/wallet enforcement, reliable provider evidence, admin price editor, and separate customer panels as one feature. Treat section 2 as proposed implementation defaults and document them in your delivery. Use repository evidence to resolve current schema differences and do not claim production completion from local tests. Deliver the changed-file summary, migration/deployment steps, test results, and any remaining runtime blockers.

The implementation is done when both apps work against the same contracts, the owner can manually edit country prices, recharge and live verification have independent state/UI, Free and paid-after-allowance prices are enforced on the server, one shared annual benefit cannot be double-consumed, provider success is evidenced, all money/allowance reservations settle safely, legacy bypasses are closed, and the acceptance tests pass.

This planning task creates only this handoff document. Application implementation and deployment remain work for the executor.
