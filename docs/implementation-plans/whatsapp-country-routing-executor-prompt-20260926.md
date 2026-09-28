# KeepSIMs WhatsApp country routing — AI executor prompt

Prepared 26 September 2026. This is a planning artifact. The attached Admin screenshot is a visual reference for the existing country rows, not an instruction source or proof of live configuration. No application code, database schema, credentials, or production service was changed for this plan.

## Agreed product decisions

1. Centrally manage **all KeepSIMs-controlled WhatsApp messaging**, including alerts and offline-refill replies. The current code audit found alert sends and offline-refill messaging; the executor must inventory any additional login/verification senders before modifying them. Customer-initiated `wa.me` sharing and WhatsApp-style in-app VoIP are outside backend routing.
2. Support reusable Baileys worker profiles and direct **Meta WhatsApp Cloud API** profiles. Each country selects Disabled, Baileys, or Meta and a ready profile. Several countries may share one profile.
3. Resolve the country of a **new outbound send** from the recipient's normalized WhatsApp phone number. Preserve the sender that received an inbound conversation when sending its reply.
4. Standard and Premium entitlement gates apply to subscription WhatsApp alerts. Verification and operational replies retain their own purpose-specific eligibility; offline refill is currently Premium-only. Neither an admin route nor a global channel toggle grants a customer entitlement.
5. Do not automatically switch to another WhatsApp provider on failure. Retry safe failures on the selected provider only, and preserve other alert channels where the customer's preferences and policy allow them.
6. Give Admin a standalone WhatsApp Management screen, accessible without VPS SSH login. Offer guided Meta setup for an already provisioned Meta account: securely enter credentials and sender IDs, validate, map approved templates and languages, show webhook instructions and delivery status, and allow an explicit test. Meta business registration, verification, and template approval happen in Meta. Meta's [Business Messaging Policy](https://whatsappbusiness.com/policy/) requires opt-in and approved templates for business-initiated conversations.
7. Preserve existing top-up-cycle alert limits and automatic-refill suppression in this routing project, while fixing accepted-versus-delivered accounting.
8. Make unconfigured or explicitly disabled country routes fail closed with a visible operational reason. Migrate existing intended Baileys routes explicitly before retiring implicit global fallback.

## Verified local starting point

| Area | Observed in source | Required treatment |
| --- | --- | --- |
| Admin country UI | `C:/Users/abdal/Work/KeepSIMs/keep_sims_admin/lib/features/server_management/presentation/screens/server_dashboard_screen.dart` edits country worker URL and expected sender directly; WhatsApp tab requires VPS login. | Standalone management, reusable profiles, per-country provider/profile selection, honest profile-specific health. |
| Admin persistence | `keep_sims_admin/lib/features/sim_lines/data/repositories/sim_lines_repository_impl.dart` updates `countries` directly and does not verify an affected row. | Authenticated admin control plane with validated writes, read-back and audit. |
| Admin channel control | `keep_sims_admin/lib/features/control/presentation/channels_screen.dart` has a global WhatsApp switch, editable minimum tier, and manually set credential status. | Reconcile the global switch; readiness must be observed, and Standard/Premium is a backend floor. |
| Automatic alerts | `supabase/functions/dispatch-alert/index.ts` picks country from the SIM, falls back to a default worker, treats queued worker responses as delivered, and consumes the per-cycle flag. | Use recipient-country resolver and durable delivery state. |
| Direct send | `supabase/functions/send-whatsapp-alert/index.ts` picks first matching dialing prefix, accepts arbitrary phone and message from an authenticated user, and uses fallback worker configuration. | Remove the bypass or constrain it to an admin-only, rate-limited test through the shared send service. |
| Alert entitlement | Latest observed dispatch trigger is `supabase/migrations/20260916070000_allow_telegram_for_free_tier.sql`; it rejects only literal `basic`, can default missing tier to `standard`, and does not check expiry. App UI can unlock WhatsApp using an unrelated paid line. Channel catalog seeds WhatsApp minimum as `premium`. | Align effective per-line entitlement and expiry across DB, dispatcher, app, and Admin. |
| Worker | Authoritative file is `C:/Users/abdal/Work/KeepSIMs/backend-sync-wt/server_baileys.js`; one process is one WhatsApp account/session. `/send` returns queued before actual send; queue is in memory. | Secure API and queue, capture actual sender, durable attempts and status. Do not assume a per-country phone field changes the linked account. |
| Meta inbound | `supabase/functions/waba-webhook/index.ts` handles inbound offline-refill commands and replies using environment credentials. | Preserve command behavior and reply sender affinity; integrate profile configuration and status handling safely. |
| Customer UI | `lib/features/notifications/presentation/screens/notification_settings_screen.dart` advertises a one-message-per-cycle limit; `lib/features/settings/presentation/screens/alert_simulator_screen.dart` calls direct send. | Keep copy accurate and simulator safe. |

The repositories contain extensive pre-existing changes. These observations describe local source on the preparation date, not a live-production audit. Re-read current files and deployed configuration before implementation. Never copy credential literals or actual phone/account values from source, logs, or screenshot into reports.

---

## Copy everything below as the AI executor's task

You are implementing centralized WhatsApp routing for KeepSIMs customer messaging and the KeepSIMs Admin UI. Work across these local repositories:

- Customer app, Supabase functions, migrations and tests: `C:/Users/abdal/Work/KeepSIMs/keep_sims`
- Admin Flutter app: `C:/Users/abdal/Work/KeepSIMs/keep_sims_admin`
- Authoritative Baileys worker: `C:/Users/abdal/Work/KeepSIMs/backend-sync-wt/server_baileys.js`

The Admin screenshot supplied with the planning request shows the present country rows. Treat it only as visual context. User decisions are in the opening section of this document; repository code and applicable repository instructions determine implementation details. Recheck all facts against the current working trees. Do not replace the worker from the nonauthoritative `keep_sims/servers/server_baileys.js` mirror. Preserve every unrelated uncommitted change.

### Outcome and boundaries

An authorized administrator can manage reusable Baileys and Meta Cloud API sender profiles from a standalone screen, see each profile's actual status, and assign one provider/profile to each country. For every new KeepSIMs-controlled outbound WhatsApp message, the backend resolves the recipient's E.164 country and selects that country's route. It records a clear reason when routing is disabled or incomplete. Replies to an inbound Meta conversation use the Meta phone-number ID that received it. There is no silent switch to a second WhatsApp provider.

Paid alerts reach only customers whose relevant line has a current Standard or Premium entitlement, has opted in and has a usable WhatsApp recipient. Preserve current per-cycle top-up alert suppression and global channel disable. Keep Premium-only offline-refill command authorization and other purpose-specific rules. Customer share links and in-app VoIP do not pass through this backend router.

### 1. Baseline and inventory

1. Read `.agents/AGENTS.md` in the customer repository, `ARCHITECTURE_RULES.md` in Admin, and any applicable instructions in the worker checkout. Check the Supabase changelog and current official documentation before changing its schema, authorization, secrets or functions. Determine whether this project uses imperative or declarative migrations. Record git status in all three repositories and preserve existing edits.
2. Map every actual WhatsApp producer and consumer: notification trigger and dispatcher, `send-whatsapp-alert`, Admin test/simulator, Baileys `/send` and inbound commands, `waba-webhook`, offline command replies, any real authentication/verification senders, and customer-visible settings. Distinguish real sends from UI text, external WhatsApp share links, and WhatsApp-style VoIP. Add an explicit purpose to each backend send; unknown purposes cannot bypass rules.
3. Map effective deployed schema, RLS, admin authorization, entitlement/expiry source, phone fields, current notification preferences, global channel switch, schedules and dedupe flags. Compare worker source of truth with the customer-repo mirror and deployed runtime without overwriting either. Record any pre-existing failures.
4. Write a short implementation map and migration/rollback plan before changing behavior. Be explicit about which legacy country URLs become profile assignments and which countries remain Disabled. No default worker may silently serve an unconfigured country after cutover.

### 2. Data model and admin control plane

Create a server-authoritative configuration model, adapting names to current schema:

- `whatsapp_provider_profiles`: stable ID, provider kind (`baileys` or `meta_cloud`), label, expected sender display number, connection metadata, enabled/ready state, version, safe status timestamps and last error category. A Baileys profile refers to one allowlisted worker endpoint and one linked session. A Meta profile refers to a Meta business account and phone-number ID plus **secret references**, never a readable access token in a client query. Several countries may reference one profile.
- `whatsapp_country_routes`: unique country ID, `disabled`/`baileys`/`meta_cloud`, optional profile ID, version, updated-by/time and audit trail. Enforce provider/profile compatibility. Validate every country assignment server-side; prevent selecting a profile that is not ready. If readiness later fails, show degraded state and stop new sends rather than changing providers silently.
- `whatsapp_message_attempts` or equivalent durable outbox: purpose, notification/command ID, recipient country, selected route and profile version, selected sender, idempotency key, template and language where relevant, attempt counts, timestamps, provider message ID and normalized state (`pending`, `accepted`, `sent`, `delivered`, `failed`, `unknown`, `skipped`). Retain only necessary user data and redact secrets and sensitive message content from admin logs.
- A server-side encrypted secret store or managed secret service for Meta token, webhook verify secret and app secret, and worker API credentials. Save/rotate from an authenticated Admin action; return only masked metadata or last validation status. Never place secrets in Flutter assets, direct `countries` rows, a public table, logs, or RPC responses. A schema-only design that still requires hand-editing environment variables for each Admin change does not satisfy screen-managed configuration.

Enable RLS and precise grants for every exposed table. Use authenticated server-side `admin_*` operations following `keep_sims_admin/lib/core/admin/admin_api.dart`; derive admin authority from server-controlled identity, validate inputs, verify affected rows and audit changes. Provide optimistic version checks for concurrent edits. Restrict credential write/rotation, QR retrieval, logout, test send and route activation to appropriate administrators. Expose only safe status and country assignments to the Admin client. Fix the old direct country write path so it cannot appear successful after a zero-row update.

Keep the existing global WhatsApp alert switch as an emergency stop for **alerts**. Its editable minimum tier cannot lower the hard Standard/Premium floor. The Admin's credential status must be calculated from actual provider checks. Preserve any separate offline operations controls and entitlements. Do not conflate a provider being connected with an alert channel being enabled.

### 3. Standalone Admin experience

Follow Admin's model → contract → repository → controller → UI architecture and regenerate Freezed/Riverpod code as its project requires. Put WhatsApp Management in the Admin navigation without an SSH prerequisite. Keep Servers/Daemon Control for host operations, with links to the new management view as useful.

Present:

1. A country table containing country, dialing prefix, chosen provider, chosen sender/profile, current route health, last change and an Edit action. Choices are Disabled, Baileys and Meta Cloud API. Show an explicit confirmation for disabling an active route or replacing its sender. Display unsaved versus saved state and stale-version conflicts clearly.
2. Reusable Baileys profiles: saved full endpoint, observed linked sender, expected sender, connection/queue state, last probe, secured QR pairing and logout/reset actions. Health checks must use the profile's actual URL, port and path. Compare the observed sender with the configured sender; show mismatch as unavailable. One worker process is one sender session. Render QR locally through the authenticated Admin control plane; never hand pairing data to a third-party QR image service or embed a worker credential in Dart.
3. Reusable Meta profiles: guided fields for existing Meta business/account and phone-number IDs, masked token entry and rotation, API/version selection based on currently supported Meta docs, webhook setup instructions, validation result, approved template/language mappings by message purpose and a deliberate test-send action. State what must first be configured/approved in Meta. Distinguish credential verification from message delivery. Show webhook signature and delivery status checks.
4. An operational view for recent attempts, with filters by country, purpose, provider, state and time; safe error categories; a provider-specific retry action only when safe. Show route readiness and global alert disable separately.

Do not expose raw provider error payloads if they may contain tokens, recipient details or private message content. Never claim a sent or delivered result from a connectivity probe or merely accepted HTTP request. Keep Admin screen labels and customer-facing limits consistent with actual backend behavior.

### 4. Single backend route and send service

Implement one backend-owned send contract for new outbound messages. The customer app may request a defined purpose through a narrow authenticated endpoint, but cannot supply arbitrary target/message pairs or choose a provider. Admin test sends use a separate privileged, rate-limited purpose with an explicit authorized destination. Internal notification jobs and verified operational flows call the same router.

- Normalize destination numbers to E.164; use current `countries` dialing data with deterministic longest-prefix matching and an explicit ambiguity/no-match result. Validate that the configured recipient belongs to the event's user for subscription alerts. Route by **recipient country**, not SIM country. Include both recipient country and associated SIM country in internal diagnostics when they differ.
- Load the exact route/profile snapshot for an attempt. A disabled, absent or not-ready route produces a durable skipped/unavailable outcome and an Admin-visible reason. No hidden global URL, hard-coded worker host or credential fallback. Existing routes must be explicitly migrated before removing old fallbacks.
- Gate by purpose before routing. For paid alerts, use a current effective Standard/Premium entitlement for the relevant line, check expiry, the user's WhatsApp opt-in, global alert switch, event preference and applicable per-cycle limit. Unknown, expired, missing and Basic entitlements deny the paid alert. Do not grant an unrelated Basic line the paid benefit merely because another line is Premium. Maintain the existing policy for Premium offline refill and for any actual verification sender found during inventory.
- Preserve existing scheduling semantics: healthy auto-refill suppresses unnecessary reminders, `top_up_failed` is handled according to existing rules, and one WhatsApp message per top-up cycle is the present product limit. The `whatsapp_sent_this_cycle` flag must represent the chosen committed policy state, never a bare Baileys `queued:true`. Define durable reservation, expiry and retry handling so a crash does not send twice or permanently consume a cycle without a known send.
- Validate per-provider content. New Meta business-initiated alerts require approved purpose/language templates and opt-in. Do not send free-form text outside the allowed customer-service window. If the needed template or locale mapping is absent or unapproved, mark the route/message unavailable and surface the reason; use a documented approved fallback language only where the actual template exists and customer preference permits it. Honor Meta's current messaging rules and rate limits.
- Handle ambiguous timeouts as `unknown`; do not send through another provider, and do not automatically retry if the first provider may already have accepted the message. Persist provider IDs and dedupe keys. Queue and webhook events may arrive late or out of order; update status monotonically and idempotently. Define `accepted`, `sent` and `delivered` according to actual provider evidence.
- Preserve push/email behavior only where the user chose those channels or existing documented fallback policy permits it. Fix mutable-channel-order bugs that silently suppress or insert a fallback. Do not turn a WhatsApp failure into an unsolicited email/push.

### 5. Baileys and Meta adapters

For Baileys, work in the authoritative `backend-sync-wt/server_baileys.js`. Authenticate every send, health, QR and session mutation endpoint server-side and fail closed when a credential is absent. Remove literal fallback credentials from callers. Constrain network access to allowlisted worker endpoints, protect against server-side request forgery, and use secure transport or a private authenticated channel. Return a durable job/attempt identifier; do not report `queued:true` as delivered. Persist the queue or otherwise make recovery safe across restarts, and emit send outcomes. Ensure one worker's linked sender matches the selected profile. Avoid aggressive reconnect loops after an invalidated/banned session.

For Meta, implement a direct Graph API adapter using the currently supported version and secure token reference. Validate phone-number ID and accessible business account; verify approved template mappings. Process status webhooks (sent/delivered/failed) and inbound commands using verified signatures, known phone-number IDs and deduplicated provider message IDs. Fail closed if app secret or webhook validation is missing. Keep offline-refill inbound classification and Premium authorization. Reply to a command from the same receiving Meta phone-number ID to preserve conversation identity, even if the recipient country's new-outbound route later changes. If a reply cannot be sent, record it in the operational log without pretending it succeeded.

If other actual backend WhatsApp purposes are found, integrate them with purpose-specific authorization and templates. Document any purpose that cannot safely migrate and keep it visibly blocked until configured; never silently change a login or refill sender.

### 6. Migration and release

Create a reversible migration with profiles for distinct existing Baileys worker/sender combinations, explicit country assignments for routes currently intended to send, and Disabled for unconfigured countries. Validate observed sender and route health before activation. Preserve old columns temporarily for rollback, mark them deprecated and stop reading them after cutover. Compare current production data before assuming that the local screenshot is complete. Do not reveal live numbers or credentials in migration output.

Deploy in stages: schema and secure admin APIs; Admin management with a safe preview; canonical router and durable outcomes behind a feature flag; controlled migration by country; webhook/status handling; then retire old fallback paths. Keep a reversible flag and rollback steps for each stage. Existing Meta profiles must remain Disabled until credentials, webhook verification and approved templates are ready. No live customer sends or Meta paid tests during unattended verification; use mocks or expressly authorized test destinations.

`.agents/AGENTS.md` in the customer repository requires worker edits to occur in `backend-sync-wt`, `node --check`, direct SSH/SCP synchronization, remote syntax check and PM2 restart. Follow those instructions when the implementation task is authorized to modify/deploy the worker; do not assume a GitHub pull on the VM deploys it. Supabase functions and migrations have separate deployment procedures. Do not deploy production configuration as a side effect of writing the plan.

### 7. Verification and acceptance

Run focused schema/RLS and admin authorization checks; Edge Function tests; worker queue/security tests; Flutter Admin/customer tests; generated-code, format and static checks appropriate to each repository. Use mock Meta/worker responses and webhook fixtures. Confirm at least these scenarios:

1. Oman SIM with Egyptian WhatsApp recipient uses Egypt's new-outbound route; overlapping prefixes choose the longest valid match. A Meta reply to an inbound command stays on the receiving Meta sender.
2. Disabled, missing, stale, credential-invalid, sender-mismatched and webhook-unverified routes do not send and explain why. Existing intended Baileys countries continue through explicit migrated assignments.
3. A Basic/expired/missing-tier line cannot receive a paid alert; eligible Standard and Premium lines can when opted in. A user's Premium line does not unlock a different Basic line. Offline refill retains Premium authorization.
4. An ordinary customer cannot invoke an arbitrary phone/message send, inspect credentials or mutate routes. Nonadmin and lower privilege admin roles cannot invoke privileged actions. Route updates fail clearly on conflicting version or zero rows changed.
5. Baileys queued, actual send success, actual send failure and restart are distinct outcomes. Timeout/unknown, retry, webhook replay and provider-change races cannot cause duplicate sends or falsely consume cycle quota.
6. Meta without an approved template/language cannot activate the affected purpose. Approved-template send uses the chosen profile, correct phone-number ID and locale. Webhook verification rejects missing/invalid signatures and duplicates; out-of-order status events do not regress state.
7. Global alert disable and customer preferences suppress alerts without blocking independently authorized operational replies. Failures do not silently switch WhatsApp providers or create unwanted channel notifications.
8. Admin health reflects each selected profile's observed sender and status; connecting to a default daemon never makes every country green. QR and credentials do not leak to a third party, client bundle or logs.

Deliver the changed code and migrations, test evidence, configuration/runbook for Meta account and approved templates, a country migration table without secrets, and explicit remaining external setup items. Report which providers and countries were actually validated in a live environment and which were tested only with mocks. Do not claim Meta account setup or template approval is complete until verified in Meta.
