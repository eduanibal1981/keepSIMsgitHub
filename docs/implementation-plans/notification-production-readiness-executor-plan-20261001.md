# KeepSIMs notification repair and production-readiness executor plan

Prepared **1 October 2026, Asia/Muscat**. This is a planning and audit artifact, not an implementation or deployment. The audit used customer app source, local migrations and Edge Functions, the sibling Admin and authoritative worker repositories, read-only Supabase queries, deployed function source, and existing mock/local tests. No production preferences, country routes, subscriptions, messages, or services were changed.

## 1. Product contract — the owner's current request is authoritative

Implement the following behavior end to end:

1. **Every authenticated, non-suspended user can configure and enable alert preferences**, including WhatsApp and Email, regardless of their current subscription. Persist the actual user choice. Enabling a preference does not purchase or grant delivery entitlement.
2. Label paid channels clearly: **“Standard & Premium SIMs”** and **“You can enable this now. Alerts are sent only for SIMs with an active Standard or Premium subscription.”** An optional upgrade action may be offered separately. Tapping the switch must not force an upgrade sheet.
3. Determine paid delivery eligibility for the **specific SIM number associated with the event**. A Premium account or another paid line must not unlock a Basic line. A Standard line must receive allowed WhatsApp alerts when consent, recipient setup, event policy, and the selected country route permit sending.
4. Keep the existing Admin country-routing design: each recipient country chooses **Disabled, Baileys, or Meta Cloud API**, with its assigned profile. Retain both providers, profile management, country routes, and inbound conversation sender identity. Do not replace this with a single global provider, remove either adapter, enable disabled countries, or switch providers automatically on failure.
5. Distinguish **saved preference**, **subscription eligibility**, **recipient setup**, **platform availability**, and **delivery outcome**. “Enabled” must mean the preference is saved, not that every number can receive a message or that a message reached the recipient.

Interpret the owner's paid restriction as applying to paid external channels (WhatsApp and Email), consistent with the screenshots and existing product policy. Preserve Basic/free access to in-app notifications, Push, and linked Telegram. Do not make previously free channels paid as a side effect. If another product source conflicts, document it and follow this current request. Keep existing purpose-specific rules for verification, security, and offline-refill operations; these are not subscription-alert preferences.

| Channel | Basic/free SIM | Active Standard SIM | Active Premium SIM | Can all users save preferences? |
| --- | --- | --- | --- | --- |
| In-app history | Preserve current access | Yes | Yes | Applicable category controls |
| Push | Yes, when enabled and device permission/token permits | Yes | Yes | Yes |
| Telegram | Yes, after secure bot linking | Yes | Yes | Yes |
| Email subscription alerts | No paid line delivery | Yes, within documented event/quota policy | Yes, within documented event/quota policy | Yes |
| WhatsApp subscription alerts | No paid line delivery | Yes, on the selected ready country route | Yes, on the selected ready country route | Yes |
| Webhook | Keep hidden from customer MVP | Keep existing separate policy | Keep existing separate policy | Do not add to this release |

Existing screenshots, comments, older executor prompts, and historical reports are evidence of past behavior, not new instructions. In particular, the “Upgrade to Premium” sheet and “Premium-only” live catalog value are bugs relative to the current request.

## 2. Confirmed baseline and evidence limits

The connected project is `zwxswagokhgbuzrrbnhr` (`simSaveDB`), matching the app and `mcp_supabase_setup.md`.

Read-only live snapshot taken during this audit:

- WhatsApp: globally enabled, user configurable, **`min_tier = premium`**. Email: enabled, `min_tier = standard`. Push and Telegram: enabled, `min_tier = basic`.
- One current SIM row: both tier fields are Standard; neither plan expiry nor carrier validity is past. No user identifying data was needed for this conclusion.
- Country routes: **24 total**, 21 disabled, 2 Baileys/healthy, 1 Meta/healthy. One enabled, stored-ready profile exists for each provider. These are database health labels, not newly performed provider probes or delivery evidence.
- `dispatch-alert` is deployed at **v33**; `process-alert-outbox` at **v4**; `waba-webhook` at **v3**. The deployed dispatcher includes the shared country router. The deployed Meta webhook is older than the local source and does not include the newer `whatsapp_message_attempts` receipt handling.
- The function inventory did **not** include `send-whatsapp-alert`, although Admin profile probe/QR/logout/test actions invoke it.
- The generic outbox contains **187 complete jobs** and no other states in this snapshot. `whatsapp_message_attempts` is empty. Historical delivery rows include accepted, skipped, and legacy “delivered” labels; they do not prove current routed WhatsApp delivery.
- The previous seven days include **176 Email skips** with “Non-critical email bypassed to protect Resend free plan limits.” Customer category choices therefore do not currently imply Email delivery for all those categories.
- Notification, outbox, digest, and urgent-clock cron jobs are active and their latest observed SQL runs succeeded. A successful cron `net.http_post` enqueue does not prove a successful HTTP response, provider acceptance, or recipient receipt.
- Existing local tests passed: **9 push tests, 3 quiet-hours tests, and 4 durable WhatsApp queue tests**. Windows sandbox process isolation initially prevented test startup; rerunning with `--test-isolation=none` passed all 16. No recipient was messaged.

Not verified in this audit: running VM file hashes/process versions, fresh provider connectivity, actual Meta template approvals, store/mobile build installed on the screenshot device, end-to-end delivery to an authorized test identity, production-load behavior, or a full Flutter/SQL suite. Do not turn this plan into a claim that the system is already production ready.

## 3. Current system map

```text
Customer category settings + global channel preferences + per-line Auto-Notify
                              |
Client actions / recharge workers / scheduled reminders / urgent clock / digest
                              |
                       notifications row
                              |
               trg_fn_dispatch_notification()
          category + user channel + catalog + current tier gate
                              |
                 notification_dispatch_jobs
                              |
                process-alert-outbox cron/worker
     rechecks preferences, event freshness, tier and quiet hours
                              |
                       dispatch-alert
                 /         |          \
               Push      Email      Telegram
          OneSignal/FCM   Resend     linked bot
                              |
                         WhatsApp router
                    recipient-country route
                     /                 \
              Baileys profile      Meta Cloud profile
              durable VM queue     approved template send
                     \                 /
                attempts, receipts, reconciliation
                              |
                  customer/Admin delivery status
```

Audit all producers as part of implementation; a correct settings page cannot repair a producer that omits its line ID or emits duplicate events. The urgent Alert Clock and ordinary schedule are separate producers and must have distinct event semantics and dedupe keys.

## 4. Findings to fix, in priority order

| Priority | Finding and evidence | Required result |
| --- | --- | --- |
| P1 | **Confirmed Standard lock:** live WhatsApp `min_tier=premium`; customer `notification_settings_screen.dart:1233-1256` derives `isLocked` from that catalog. `1307` forces a false display and `1379` disables changes. | All users can save the preference. Paid delivery for Standard and Premium follows the owner's contract; migrate and constrain the catalog accordingly. |
| P1 | **Wrong expiry source:** UI, live dispatch trigger, live outbox, and shared WhatsApp router gate with `validity_expires_at`. `plan_expires_at` exists separately. | Use verified subscription entitlement/plan expiry for paid access. Carrier validity belongs to risk/event calculation and must not itself remove paid warnings. |
| P1 | **Different tier authority:** UI accepts either tier; SQL/outbox prefer `protection_tier`; `SimLineEntitlement` widens from both; Email defaults to Standard and may borrow account tier. | One server-owned entitlement rule. Canonical paid line state, expiry, ownership and evidence; no default-paid or unrelated-profile fallback. |
| P0 investigation → repair before release | **Customer-created external send surface:** live notification INSERT policy checks only `auth.uid() = user_id` and suspension. It does not require the referenced SIM to belong to that user; the only live notification trigger is dispatch. Clients can supply category/title/body/line ID. Channel config is owner writable, including Telegram binding fields. | Prove exploit prevention with negative tests, then replace broad event creation/config writes with narrow, rate-limited, server-rendered contracts. Preserve read/read-state/delete UX. Never authorize sending by client-supplied entitlement or event text. |
| P1 | **Job completion masks channel failure:** dispatcher returns `success:true` after persisting failed/skipped delivery rows; outbox marks that job complete. This is deployed behavior. | Persist per-channel/per-target outcomes and retry only safe failed targets. Logical handling and delivery success must be separate metrics. |
| P1 | **WhatsApp operational deployment gap:** Admin invokes missing `send-whatsapp-alert`; its local action code uses `provider_type`, top-level endpoint and `metadata`, while the live schema uses `provider_kind` and `connection_metadata`. Admin has direct probe fallbacks. | Align the contract and deploy a secured management endpoint. Remove browser/direct-worker and global-host fallbacks. Admin actions must work against the selected profile. |
| P1 / P0 when secret absent | **Meta webhook drift/security:** live v3 lacks current attempt receipts and skips signature verification if `WABA_APP_SECRET` is missing. Local source has the same fail-open branch. Actual secret presence was not inspected. | Verified signature required before command/receipt processing; secret absence rejects. Deploy the reviewed handler and test sender/profile identity and receipt correlation. |
| P1 | **Baileys receipt contract mismatch:** authoritative local worker PATCHes `sent_at`, absent from the live attempt table. State sync is fire-and-forget; local durable queue completion occurs before database acknowledgement. | Align schema/API, persist a receipt-sync backlog, reconcile after failure/restart, and prove sent/delivered state eventually reaches the database without resending. VM version remains unverified. |
| P1 | **Router readiness and retry gaps:** loads but does not enforce `ready_state` or observed/expected sender match. Failed-attempt retries reload and overwrite the provider/profile without atomic failed-state claim. Adapter secrets/endpoints have environment fallbacks. | Enforce purpose-specific readiness; freeze provider/sender route snapshot; atomic retry claim; no cross-provider retry, wrong-secret fallback, or duplicate race. |
| P1 | **Cycle logic uses ambiguous schedules:** router uses `.maybeSingle()` for all schedules of a line, but schema permits notify and refill schedules together. It checks `schedule_type='refill'`, while current schedule provisioning uses `refill_mini`/`refill_custom`. Cycle quota read/update is not atomic. | Select relevant schedule types deliberately, handle multiple schedules, assess actual refill health, and reserve one logical cycle send atomically. |
| P1 | **Ordinary scheduler dedupe weakness:** `process_due_notifications()` loops due rows without an atomic schedule claim/event-cycle key, unlike the newer urgent event path. | Concurrent scheduler runs emit one logical reminder per due cycle; advance from intended schedule time under a documented catch-up policy. |
| P2 | **Misleading success/settings states:** channel controller catches update errors and invalidates without propagating failure; Save still displays success. Catalog read errors return `{}` and UI treats missing catalog as globally enabled. Missing-channel read performs inserts. | Visible errors, acknowledged save state, reliable concurrent initialization, explicit unavailable capability state; never fake successful save or globally enabled status. |
| P2 | **Channel-policy/copy mismatch:** per-category controls offer only Push/Email; WhatsApp/Telegram are global; fixed Email allowlist skips many selections. Weekly digest emits `system` with no line and mixes all active lines, but paid gate uses profile tier. | Document event/channel matrix and reason codes. Define line-free paid aggregation explicitly, filter paid line contents, and show real supported categories/quota behavior. |
| P2 | **Status propagation is incomplete:** WhatsApp receipts update its attempt table but do not consistently update generic delivery/history metrics. Legacy “delivered” rows coexist with provider-accepted rows. | A single truthful projection of accepted/sent/delivered/failed/unknown; preserve and label uncertain historical evidence. |

Treat the P0 surface as a concrete security review, not a proven exploit report: this audit inspected grants, policies and trigger metadata without performing customer writes. Inspect all relevant guards before making the repair, and prove the final restrictions in an isolated database.

## 5. Executor setup and authoritative files

Use these checkouts:

- Customer and Supabase: `C:/Users/abdal/Work/KeepSIMs/keep_sims`.
- Admin: `C:/Users/abdal/Work/KeepSIMs/keep_sims_admin`.
- Authoritative worker source: `C:/Users/abdal/Work/KeepSIMs/backend-sync-wt`. Do not implement worker changes only in the customer repository's `servers/` copies.

Read applicable instructions in each checkout, including customer `.agents/AGENTS.md`, `ARCHITECTURE_RULES.md`, and Supabase skill/documentation. Preserve current uncommitted dashboard, calling, localization and asset work. Record initial status and keep this change scoped. Follow model → contract → repository → controller → UI for new capabilities. Regenerate generated Dart files; do not hand-edit them.

Primary repair locations:

| Area | Files/functions |
| --- | --- |
| Customer configuration | `lib/features/notifications/presentation/screens/notification_settings_screen.dart`; corresponding controllers, repository contract/implementation, alert/preference models |
| Entitlements | `lib/features/sim_lines/data/models/sim_line_model.dart`; server billing/payment entitlement helpers; `sim_lines.plan_type`, `plan_expires_at`, protected legacy tier fields |
| Event and navigation | `notification_event_catalog.dart`, notification navigation service, foreground push service, notifications screen, SIM Auto-Notify schedule controls |
| Dispatch | `supabase/functions/dispatch-alert/index.ts`, `push_delivery.ts`, `process-alert-outbox/index.ts`, `quiet_hours.ts` |
| WhatsApp | `supabase/functions/_shared/whatsapp_router.ts`, `send-whatsapp-alert/index.ts`, `waba-webhook/index.ts` |
| Database | Forward migrations for catalog constraints, canonical capability/policy functions, owner checks, attempt/job claims, cycle reservations, delivery projection and scheduler dedupe |
| Admin | `lib/features/whatsapp_management/{model,contract,repository,controller,ui}`; `lib/core/admin/admin_api.dart`; notification channel/incident screens |
| Workers | `server_baileys.js`, `durable_whatsapp_queue.js`, `server_tg.js` and focused worker tests in `backend-sync-wt` |

Review earlier 26–27 September plans/reports as historical context. Preserve working Alert Clock source accuracy, timezone handling, one-time Telegram tokens and durable queue logic; do not rebuild those features blindly.

## 6. Phase A — establish one entitlement and capability contract

Deliver this phase before UI-only changes are considered complete.

1. Inventory every event producer, scheduled job, send endpoint, provider adapter and operational reply path. Classify event scope as line-specific, account operational, digest/aggregate, verification/security or Admin test. Produce a checked-in event × channel policy table with defaults, opt-in, urgency, quota, expiry and dedupe rules.
2. Trace billing/payment proof and existing entitlement functions. `plan_type` is the documented current source; verify the live server write paths. Build one server-owned effective entitlement resolver that validates line ownership, canonical tier, subscription expiry and trusted paid evidence. Normalize `free/basic` consistently. Do not use `max(plan_type, protection_tier)` as authorization: that can retain a revoked or expired legacy privilege.
3. Handle legacy paid rows with no subscription expiry explicitly. Use audited billing evidence/backfill; report unresolved rows and fail closed for paid delivery without silently deleting preferences or downgrading data. Do not fabricate expiry dates from carrier-validity dates.
4. For line events: resolve only the event line, enforce `sim_lines.user_id == notification.user_id`, and validate required ownership/capabilities for household roles. A paid line belonging to another user or another line in the same account cannot confer access.
5. Carrier expiry must remain available to the alert clock/event policy. An active paid subscription can still need an expiry/grace warning after carrier validity passes. Do not blanket-cancel all events for every non-active line status; define which warning/status events remain valid. Paused/deleted lines and suspended users need explicit policies.
6. Return an owner-scoped capability response containing saved channel opt-in, paid restriction label, eligible line count, recipient readiness, global availability, per-line effective entitlement and safe reason codes. Do not expose provider credentials/endpoints. Use this response for UI hints and delivery policy diagnostics; the UI is not the authorization boundary.
7. Move Standard/Premium delivery policy into a constrained server policy/catalog contract. Forward-migrate WhatsApp from Premium-only to Standard as required. Prevent Admin from reintroducing a Premium-only subscription-alert restriction through the generic minimum-tier field for this feature. Keep Admin emergency/global enable and country-provider controls. Preserve unrelated webhook restrictions.
8. Reuse the resolver at event enqueue, outbox processing, dispatcher, routed WhatsApp send and retries. Test consistent decisions across all layers. A missing catalog/DB error must not make paid delivery allowed.
9. Define account events rather than using an arbitrary `profiles.subscription_tier` fallback. Paid line aggregates may use only qualifying lines and explicit account preferences; exclude Basic/expired line content from paid subscription digests. Security/transactional account events retain their own independently documented delivery policy.

Acceptance: Standard and Premium fixtures are eligible by the same server decision; Basic, expired, unknown, foreign and revoked entitlement fixtures are denied paid line delivery. Configuration remains allowed for each non-suspended owner fixture.

## 7. Phase B — configurable customer UI with honest delivery hints

1. Remove subscription-based disabling/forced-false state from channel switches. Display persisted opt-in even when no number currently qualifies or the platform is paused. Keep controls usable for saving preference under a pause, with a clear “Temporarily unavailable” delivery status.
2. Remove the forced upsell tap path and subscription-gated config editor. Show the static Standard/Premium label and contextual messages: “No eligible SIMs yet”, “Eligible for 1 SIM”, “Setup required”, “Country route unavailable”, or “Channel temporarily paused”. Keep saved choice, setup status and eligibility visually distinguishable and accessible.
3. For a Standard user, turning WhatsApp on opens/retains its number configuration and saves normally. For a Basic user, the same action saves normally while showing the paid delivery hint. Upgrade is a separate optional action, targeted to a SIM; no contradictory Premium-only benefit copy.
4. Validate destination format and consent. WhatsApp input must be explicit E.164; do not infer an international number solely from the user's home country for an ambiguous local number. Remember that the recipient WhatsApp number may differ from the protected SIM. Preserve the user's intended recipient and record appropriate opt-in evidence. Email alternate destinations need a verified/authorized destination flow before sensitive SIM content is sent.
5. Adopt one canonical config key per destination, with controlled migration of `phone`/`phone_number` and `email`/`email_address`. Prevent stale key precedence from sending to an old number/address after an edit.
6. Make channel mutations return acknowledged success/failure. Prevent concurrent switch/save races and duplicate taps; preserve user drafts on failure; show success only after server acknowledgement. Ensure state refresh does not overwrite newer unsaved text.
7. Make channel initialization idempotent and server seeded. Avoid racing client-side inserts during reads. Render catalog/settings loading and errors explicitly; retry safely without inventing availability.
8. Keep secure Telegram linking usable for free users. Bind/unbind through narrow server APIs; user config writes must not let clients replace `chat_id` directly. Prove token expiry, single use, ownership and accurate bound/unbound refresh.
9. Explain existing per-category/global intersections. Display category restrictions where relevant. Keep Email's real event/quota limitations visible; never describe every category selection as guaranteed Email delivery. Localize changed copy in all supported ARB locales and regenerate localization files without erasing unrelated translations.
10. Refresh capability hints on upgrade/downgrade, app resume, line changes and configuration changes. The backend independently rechecks paid delivery immediately before sending.

Suggested final copy:

> WhatsApp Alerts · Standard & Premium SIMs  
> Enable alerts for your eligible SIMs. You can save this preference now; WhatsApp delivery requires an active Standard or Premium subscription and an available country route.

Acceptance: reproduce all three customer screenshots with Basic, Standard, Premium and mixed-plan fixtures. Standard WhatsApp switches on without an upgrade modal; Basic can also save an enabled preference but receives no paid alert for its Basic line.

## 8. Phase C — secure events and reliable delivery

### Event integrity and preferences

- Restrict external-send-producing notification inserts to trusted producers or narrow validated RPCs. Client actions send identifiers/allowed event intent; server verifies ownership, renders text, fixes category/urgency and dedupe key, and rate-limits. Move customer simulator to safe test-only/Admin behavior. Update client `emitEvent`, `sendNotification` and delayed simulation paths before revoking old writes.
- Preserve client read, mark-read and delete behavior with column-scoped update permissions. Clients must not change event identity, ownership, line ID, delivery claims, expiry or schedule to bypass gates.
- Protect entitlement fields on INSERT as well as UPDATE and inspect existing guards. Audit `profiles.subscription_tier` and both line tier fields. Do not rely on owner RLS alone to protect server-owned fields.
- Preserve opt-in and category intersections. Global pause/revocation/recipient change cancels or defers unsent work with explicit reason. Decide pending-job behavior: newly enabled channels do not backfill old events by default; newly upgraded lines get future alerts and any fresh, deliberately re-evaluated urgent event, not a replay of history.
- Keep in-app event history even when external delivery is ineligible, under the established category/history policy. Do not fabricate external “delivered” states from history creation.

### Per-channel attempts and replay

- Extend the existing durable outbox rather than discarding it. Persist a stable logical event key and unique channel/recipient/device attempt keys, attempt/lease token, provider snapshot, bounded attempt budget, next retry, expiry and structured reason.
- Claim attempts atomically with compare-and-set/locking and lease fencing. A stale worker cannot finish or overwrite a newer lease. Accepted targets are never replayed because another channel/device failed.
- Return structured outcomes from `dispatch-alert`. Distinguish logical handling complete, channel pending/accepted, partial failure, policy skip and unknown. Admin queue summaries must expose failed channels even if the parent dispatch was handled.
- Retry definite pre-send or definite provider-rejection failures using documented provider semantics, backoff/jitter and `Retry-After`. Preserve idempotency key and exact payload/destination snapshot. Do not automatically replay timeout/network ambiguity after a possible send. Reconcile provider/worker evidence first.
- Set bounded deadlines on Email/Telegram and database/worker calls so processing fits leases/runtime limits. Mixed push-device outcomes require per-device persistence; one device failure must not resend an accepted device.
- Persist provider IDs and normalize receipt updates through one authorized monotonic transition contract. Maintain separate provider message ID and worker job ID. Idempotent receipts must update generic attempt metrics and customer history without lost updates.
- Never write `accepted` or `sent` over a previously delivered receipt. Delivered followed by an old sent/failed webhook does not regress. An asynchronous database receipt-write failure must enter a durable reconciliation backlog rather than only a log message.

### Provider requirements

- Push: retain existing OneSignal idempotency and FCM fallback only for definitively rejected devices. Test foreground/background/terminated navigation, Android channel behavior, iOS permission behavior, token rotation/pruning and logout/relogin isolation. Do not change incoming-call payload behavior while repairing alerts; check it for regressions because the dispatcher also handles VoIP.
- Email: replace hard-coded free-plan skips with a documented, configurable event/quota policy, or faithfully preserve the guarded policy and expose it. Store provider response ID; send a stable Resend idempotency key; escape server-rendered HTML; verify domain/authentication setup and bounced/complained destination suppression. Signed webhooks are required before claiming recipient delivery. A quota limit is an observable reason, not successful delivery.
- Telegram: use only server-established chat bindings. Telegram API acceptance does not establish user receipt. Ambiguous sends require reconciliation/duplicate-safe policy; bot blocking and revoked bindings must be visible and actionable. Protect bot tokens and prevent arbitrary customer chat targeting.

Acceptance: mixed successful and failed channels leave an accurate partial result; only the safe failed channel retries. Timeout/restart/log-write/late-lease cases cannot silently duplicate sends or report a false delivery.

## 9. Phase D — preserve and harden both WhatsApp routes

### Country/profile contract

1. Keep the country route selected in Admin. Resolve a **new outbound** recipient country from normalized recipient number using deterministic prefix rules. Handle ambiguous shared calling codes explicitly; a disabled/unknown route does not use SIM country or a global fallback.
2. Check route/profile kind compatibility, enabled state, readiness freshness, observed/expected sender match, required credentials and selected-purpose template/webhook requirements. Expired health information must not display fresh health.
3. Freeze country, route version, profile/version, sender and destination in a persisted attempt. A failed attempt stays on its original provider/profile. A route change governs new attempts; disabling a selected route blocks unsent work. Credential rotation on the same profile is permitted under documented policy; reassignment requires a separate audited action after proving no prior acceptance.
4. Remove implicit environment endpoint/token/phone-ID substitution for profiles. Secure profile secrets server side; no raw credentials in customer/Admin bundles, QR URLs or logs. Protect worker endpoints through authenticated TLS/private access and explicit destination allowlisting.
5. Repair and deploy `send-whatsapp-alert` or a replacement with a matching Admin API contract. Use actual `provider_kind`/`connection_metadata` fields. Verify Admin role authorization, rate limits, input validation, safe error messages, saved-version conflicts, and zero-row update failures. Remove direct host-probe fallback and hard-coded host defaults from Admin.

### Cycle/schedule policy

- Select notify/refill schedules explicitly; multiple schedules must not become a swallowed `.maybeSingle()` error. Use current `refill_mini`/`refill_custom` types and actual execution health before suppressing reminders.
- Create an atomic reservation unique to line + logical notification cycle + channel. Two different events in one cycle cannot both win. Accepted/sent quota, delivery evidence, and failed-before-send release must be distinct.
- Define critical failure/48-hour behavior relative to the existing one-per-cycle cap and healthy-refill suppression. Preserve current accepted intent; do not let a routine event accidentally consume the only critical warning without an explicit documented rule.
- Reset quotas against a stable cycle identifier, not an unguarded boolean reset on each cron run. Retain preference on downgrade and re-enable effective delivery on a verified future upgrade without manual preference loss.

### Baileys

- Retain `DurableWhatsAppQueue` and its restart quarantine tests. Fix the live schema/`sent_at` mismatch and separate worker job ID from the actual WhatsApp message ID. Persist receipt sync/reconciliation work across restart; do not resubmit message text to repair a failed receipt write.
- Recheck unsent queued alert eligibility/preferences/route disable immediately before send, including jobs delayed by worker backlog. Honor original provider snapshot. Decide cancellation acknowledgements and stale queued content rules.
- Persist authenticated send acceptance only after durable enqueue. Crash during actual send becomes unknown. Protect QR/health/logout/send routes, verify sender identity and expose queue pressure safely.
- Review inbound status/offline-refill commands for requester ownership, dedupe and current purpose-specific entitlement. The local worker's `/status` path reads all `sim_cards`, and its refill path uses account Premium and direct writes; treat these as production blockers for enabling those commands until authorization and trusted operation paths are established. Do not change financial business rules casually within this alert repair.
- Preserve replies on the Baileys sender that received the conversation. Operational replies have separate consent/entitlement rules from paid alert switches; do not route them through a different country provider after a configuration change.

### Meta Cloud API

- Validate supported Graph API version from current Meta documentation; do not rely on the local default `v20.0`. Map approved purpose/event templates and locale-specific parameter schemas. Do not truncate the whole alert into one invented parameter; use the approved template's required parameter contract.
- Verify opted-in recipient and approved template for business-initiated alerts. Check actual template status before enabling the affected purpose. Connectivity alone must not mark every purpose ready.
- Require a valid `x-hub-signature-256` signature with the correct configured app secret before processing any POST. Missing secret fails closed. Match incoming phone-number ID to a known profile; do not let an untrusted payload select arbitrary credentials.
- Route inbound replies from the receiving Meta phone-number ID/profile, before country routing for new outbound sends. Merely overriding phone-number ID after selecting a Baileys country profile does not preserve Meta conversation identity. Enforce the valid reply window and command dedupe.
- Deploy the reviewed webhook; update attempts by provider ID plus profile/sender context. Validate replay, delayed/duplicate/out-of-order status events and webhook-before-send-response races. Propagate confirmed delivery into generic attempt/history projections.

Acceptance: an Oman SIM with Egyptian WhatsApp destination uses Egypt's assigned route. Baileys and Meta each pass their own mocked adapter and receipt tests. A Meta inbound conversation stays on its receiving Meta profile even if that recipient country's new-outbound route is Baileys or Disabled.

## 10. Phase E — scheduler, quiet hours, digest and operations

1. Atomic due-schedule claiming and unique cycle events for ordinary Auto-Notify; retain urgent-clock atomic keys, verified carrier evidence, date precision and stale-event suppression. Test concurrent ordinary/urgent cron runs, edited activity/rules, disabled Auto-Notify, healthy/failed refill, and catch-up after outage.
2. Define quiet-hours urgency from the canonical event policy. Current worker bypasses `line_critical`/urgent clock, while dispatcher has a broader urgency list. Decide and test consistent behavior for due reminders, failures, wallet warnings and 48-hour threats. Missing/invalid timezone and overnight/equal-hour schedules need explicit handling; preserve existing tested DST behavior.
3. Digest is currently emitted **Sunday 09:00–11:59 local** despite an obsolete “Monday” comment. Make UI, documentation and scheduler agree with the supported schedule. Preserve explicit consent, unique weekly key and absence of promo content. Paginate beyond the current first 1,000 preferences so users are not starved. Use paid-line aggregate policy from Phase A and Email policy from Phase C.
4. Add Admin filters/metrics for logical jobs and channel attempts: pending, leased, deferred, accepted, sent, confirmed delivered, failed, policy skipped, canceled, unknown and reconciliation overdue. Show safe reason, attempt count, next retry, oldest backlog, route/profile and affected purpose.
5. Retry actions operate on safe failed attempts and recheck current policy; unknown outcomes require evidence/reconciliation. Record actor, reason and resulting transition. Keep global alerts pause separate from provider/offline-operation control.
6. Monitor actual cron-to-HTTP-to-worker progress, not only SQL cron success. Track stale leases, backlog age, provider errors, consent/setup failures, quota suppression and receipt lag. Establish thresholds/owners; proposed targets are outbox pickup within two minutes under expected load, incident on urgent backlog over five minutes, and investigation of unknown outcomes immediately. Confirm achievable service targets through a staging load test before publishing a guarantee.
7. Add retention/cleanup for attempts and notification history without deleting idempotency evidence while replay remains possible. Bound the Baileys durable history/queue and sensitive logs; preserve audit evidence for unknown outcomes. Document backup/recovery behavior.

## 11. Required verification matrix

Use isolated fixture users/lines and mocked providers first. Avoid real customer sends. Controlled live acceptance requires an expressly authorized test destination and explicit execution scope.

| Test | Expected result |
| --- | --- |
| Basic user enables WhatsApp/Email | Preference persists after relaunch; paid label visible; Basic line sends neither paid channel |
| Standard user enables WhatsApp | No upsell block; valid destination saves; allowed event reaches selected adapter |
| Premium user | Same paid channel behavior with applicable extra operational features preserved |
| Paid + Basic line on same user | Paid event eligible; Basic event ineligible; neither borrows the other's tier |
| Basic line under paid profile | No paid line entitlement from account field |
| Expired paid plan, fresh carrier validity | Paid delivery denied; preferences retained |
| Active paid plan, expired carrier validity | Relevant expiry/grace warning remains eligible under event policy |
| Null/unknown/inconsistent entitlement | No default-paid grant; audited legacy migration behavior |
| Foreign line ID/customer-crafted event | Rejected before queue or provider; no data leakage or quota use |
| Category off / channel off / platform paused | Unsatisfied route suppressed with reason; saved choice preserved |
| Missing catalog or policy lookup failure | Visible/configurable retry state; paid send fails closed |
| Destination changed with both legacy keys present | Only verified canonical destination used; old keys do not win |
| Preference persistence/network/zero-row failure | UI displays error and preserves draft; no false success |
| Telegram token fresh/expired/replayed/foreign | Only valid one-time link succeeds; direct chat binding edit denied |
| Authorized paid account digest | Only qualifying line scope included; consent/Email policy obeyed |
| Notify + refill schedules for one line | Correct explicit selection; no swallowed multiple-row error |
| Concurrent scheduler/cycle reservations | One logical event and one allowed WhatsApp cycle reservation |
| Healthy versus failed Auto-Refill | Documented suppression/critical exception is correctly applied |
| Partial push/device/channel failure | Accepted targets stay accepted; only safe failed target retries |
| Provider timeout/crash/receipt-log failure | Unknown/reconciliation; no automatic duplicate send |
| Lease expiration and stale worker completion | Fencing prevents overwriting newer job/attempt state |
| Country mismatch and shared prefix | Recipient-country routing or explicit ambiguity; no implicit fallback |
| Disabled/unready/wrong-sender country profile | No send; accurate route/setup reason |
| Admin route/profile changed during queued retry | Same attempt never changes provider; new send uses current route |
| Meta template missing/wrong locale/wrong params | No unsupported message; purpose readiness shows the problem |
| Meta missing/invalid signature or unknown sender | No command, receipt mutation or reply |
| Meta received conversation, country routes elsewhere | Reply remains on the receiving Meta sender/profile |
| Baileys sent-state PATCH/schema failure and restart | Durable receipt reconciliation, no message resend |
| Receipt duplicate/out of order/before HTTP response | Idempotent monotonic state; delivered does not regress |
| Concurrent receipts for different channels | History/metrics retain both; no overwritten delivered channel |
| Quiet hours Muscat and DST | Local-time deferral and critical exceptions match policy |
| >1,000 users due for digest / burst urgent load | No starvation; measured backlog/lease/provider budgets |
| App background/terminated/resume/logout | Correct alert navigation and token isolation; no cross-user notification |
| Unauthorized Admin/worker/QR/test endpoints | Rejected; secrets absent from responses and bundles |

Run and extend existing SQL preference/tier/dispatch tests, Dart settings/controller/navigation tests, push/quiet-hours tests and worker queue tests. Add meaningful server policy, partial-failure, ownership, routing and contract tests; do not stop at screenshot tests or analyzer success. Validate migration replay from a clean test database and upgrade from the actual live schema.

Existing reproducible local commands (no live sends):

```powershell
node --test --test-isolation=none test/push_delivery.test.cjs test/quiet_hours.test.cjs
node --test --test-isolation=none C:/Users/abdal/Work/KeepSIMs/backend-sync-wt/test/durable_whatsapp_queue_test.js
```

Discover Flutter, Supabase CLI and Deno commands from installed versions/help; record exact runtime versions and commands in the implementation report. Re-run appropriate generation, format, static checks and relevant customer/Admin builds after changes. Inspect Supabase RLS/privilege/security advisors. Test denial with authenticated nonadmin/foreign-owner roles, not only service role.

## 12. Rollout, rollback and completion gates

This request authorizes the plan/audit. It does not authorize implementation, production migration, provider tests, credential rotation, worker restart, or sending messages. The executor must follow its actual subsequent authorized scope.

Once implementation is authorized:

1. Record pre-change catalog, routes/profile versions, deployed functions, relevant schema/migration history, worker hashes and client/Admin versions. Export only safe metadata; keep secrets outside reports.
2. Build/test forward, additive schema/API changes in an isolated environment. Do not edit already applied historical migrations or blindly apply the older duplicate notification migrations. Backfill canonical entitlement/configuration with explicit counts and unresolved cases.
3. Deploy compatible server contracts and reviewed management/webhook handlers, then worker changes and Admin/customer app changes. Gate new dispatch behavior until the schema, receipt API and worker contract agree. Coordinate sender/schema changes so queued attempts retain a valid contract.
4. For authorized VM worker deployment, follow `.agents/AGENTS.md`: authoritative `backend-sync-wt` edit/test, direct SSH/SCP synchronization, remote syntax checks and targeted PM2 restart. Do not assume a GitHub pull deploys these workers. Preserve existing sessions and queues; verify hashes and receipt backlog after restart.
5. Apply the Standard/Premium WhatsApp catalog policy only with the consistent server gates deployed. Keep all existing country assignments, including Disabled countries. An upgrade/configuration fix does not authorize backfilling old notifications or sending to customers.
6. Release customer/Admin UI with compatible APIs and localized copy. Record the build actually tested on-device; screenshots alone cannot establish deployed source version.
7. Run controlled acceptance for both providers on expressly authorized test identities and selected routes. Prove saved settings, enqueue, provider acceptance, receipt where available, Admin visibility and absence of duplicates. Keep provider acceptance distinct from user receipt. If a provider/template/webhook prerequisite is unresolved, report that route as unavailable and readiness conditional.
8. Roll back through explicit dispatch flags/global alert pause, old compatible builds and additive-schema compatibility. Pause before reverting workers; inspect pending/accepted/unknown attempts and receipt backlog. Never replay unknown jobs during rollback. Do not restore Premium-only WhatsApp eligibility as the default product policy; it contradicts this request.

Required executor outputs:

- Scoped code/migrations across the customer, Admin and authoritative worker repositories, with generated files and deployment manifest.
- Event/channel policy table and canonical entitlement contract, including account-event/digest and legacy data decisions.
- Safe before/after catalog and country-route comparison proving both WhatsApp providers and existing country assignments remain.
- Automated test results plus controlled live evidence per channel/provider, with unverified items clearly identified.
- Admin/operator runbook: setup, consent, pause, safe retry, unknown reconciliation, receipt backlog, quota, cron health, retention and rollback.
- Final release assessment listing unresolved external setup, P0/P1 defects and conditional routes. Do not call the entire notification system production ready while any relevant P0/P1 failure remains or both selected WhatsApp paths lack the required evidence.

## Documentation references for implementation

Use current primary documentation at execution time; local API defaults may be stale.

- [Supabase Edge Function authentication](https://supabase.com/docs/guides/functions/auth): authenticate internal jobs and external webhooks deliberately; disabled platform JWT verification still requires handler authentication.
- [Supabase Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security): owner row policies are only part of authorization; protect server-owned fields and privileged functions.
- [Resend idempotency keys](https://resend.com/docs/dashboard/emails/idempotency-keys): current provider dedupe window is 24 hours; retain application-level evidence beyond it.
- [WhatsApp Business Messaging Policy](https://whatsappbusiness.com/policy/): check current consent and approved-template requirements for business-initiated messages.

The Supabase changelog markdown fetch was unavailable in this audit (web content-type failure and restricted shell network); the executor should check it before choosing implementation APIs. No speculative API/version upgrade is mandated by this plan.
