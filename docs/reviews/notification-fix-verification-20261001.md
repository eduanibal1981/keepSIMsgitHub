# Notification repair and release verification

Verified 1 October 2026. The backend repairs are deployed. Customer and Admin review builds are available. Production sign-off still needs Meta credentials and real device/provider acceptance checks.

The owner retains country-by-country selection of **Disabled, Baileys or Meta Cloud**, plus the selected provider profile. There is no automatic provider fallback. The 24 routes remain 21 Disabled, two Baileys and one Meta Cloud. No country selection was changed during the repair.

## Resulting behavior

- Every user can save notification preferences, including Email and WhatsApp, with a Standard & Premium label. A saved switch is a preference; delivery also checks the originating SIM's current entitlement, expiry, event policy, category selection and channel availability.
- Standard and Premium SIM subscriptions qualify for paid channels. A Basic SIM cannot borrow another SIM's paid plan or an account-level label. Expired carrier validity does not incorrectly remove an otherwise active subscription.
- Customer-created paid setup drafts retain their selected plan, but cannot authorize paid delivery. A server-owned confirmation marker is set when the purchase is finalized. The existing paid production SIM was retained after verifying its matching payment record. The payment trigger, expiry correction and one-time paid setup confirmation were exercised in rollback fixtures.
- Push targets each unique installation. FCM fallback is limited to a definitively rejected target. An ambiguous send never triggers a second provider send.
- Telegram requires a verified, single-use bot binding. Customer preferences cannot forge chat ownership. Text replies and Email/SMS content use safe rendering.
- WhatsApp uses the recipient phone's country route and that route's selected profile for new outbound alerts. Disabled, unready, mismatched-sender or changed routes stop delivery. Provider/profile decisions are frozen for an attempt, including retries.
- Operational inbound replies use the authenticated receiving WhatsApp provider/profile. This preserves the conversation's sender while leaving the owner's outbound country choices intact. Baileys commands use the shared, account-scoped command handler; groups and unverified sender identities are rejected.
- Meta authenticates every accepted webhook change using the receiving profile's App Secret. Missing configuration or failed receipt persistence returns an error. Unsigned requests cannot execute commands. Hosted SMS requires a configured Twilio signing secret and valid signature; the worker's internal SMS endpoint also requires authentication.
- Delivery has a durable ledger per channel and target. Provider acceptance is recorded separately from receipt-confirmed delivery. Partial failures can retry the failed targets; accepted, delivered and unknown targets are not automatically resent. Later WhatsApp receipts update the notification's delivery projection without regressing a delivered state.
- Baileys persists receipt updates across restarts and database outages, without replaying the message. Queued sends recheck current owner routing, sender, subscription and consent immediately before sending.
- Concurrent WhatsApp deactivation warnings share one SIM/cycle reservation. Routine setup confirmations and tests do not consume that critical warning reservation. Definite pre-send failures release the reservation; accepted or uncertain sends retain it.
- The scheduler locks due rows, emits one catch-up reminder and advances from the intended due date. Setup events and missing-recharge-date sweeps serialize duplicate generation. Paid weekly Email digests contain eligible paid SIM content only. Quiet hours retain local-time and DST behavior; explicit tests bypass quiet hours.

## Deployed components

| Component | Verified deployment |
| --- | --- |
| Supabase project | `zwxswagokhgbuzrrbnhr` |
| `dispatch-alert` | v36 |
| `process-alert-outbox` | v6 |
| `send-whatsapp-alert` | v3 |
| `waba-webhook` | v6 |
| `sms-webhook` | v4 |
| Baileys worker | Directly synchronized from the authoritative worker checkout; remote syntax checked and PM2 restarted |
| Worker health | HTTP 200, WhatsApp connected, queue empty at verification |
| Notification crons | Hourly reminders, weekly digest emitter, urgent alerts and minute outbox processor active |
| Outbox runtime | Actual HTTP 200 response: success, zero pending claims at verification |

Applied forward migrations:

1. `20261001030205_notification_production_delivery_contracts.sql`
2. `20261001030700_notification_scheduler_dependency_repair.sql`
3. `20261001031308_notification_delivery_maintenance_indexes.sql`
4. `20261001033220_notification_paid_line_insert_guard.sql`
5. `20261001033345_notification_setup_event_idempotency.sql`

The executor's catalog, legacy trigger repair and `sent_at` migration files were reconciled with the deployed schema/history. The old trigger repair is guarded so a later migration run cannot replace the new dispatch contract. Keep local and hosted migration versions aligned when preparing subsequent deployments.

Authoritative worker source is [backend-sync-wt](C:/Users/abdal/Work/KeepSIMs/backend-sync-wt). The deployed files are `server_baileys.js`, `durable_whatsapp_receipts.js` and `whatsapp_inbound_commands.js`. The unrelated legacy refill implementation was retained; the exposed WhatsApp handlers were changed narrowly.

## Verification evidence

| Check | Result |
| --- | --- |
| Backend/provider/worker tests | **44 passed**, no failures |
| Customer app notification and alert-clock tests | **28 passed** |
| Live database contract assertions | **36 passed**, all fixture rows rolled back |
| Remaining fixture users | **0** |
| Targeted customer and Admin source analysis | No issues |
| Customer debug APK | Built successfully; refreshed after the final settings copy change |
| Admin release web build | Built successfully |
| Unauthenticated dispatch/outbox/management endpoints | HTTP 401 |
| Unauthenticated internal worker SMS endpoint | HTTP 401 |
| Meta with missing webhook secret | HTTP 503; no command execution |
| Hosted SMS with missing signing configuration | HTTP 503; no command execution |
| Private delivery tables/claim routines | No customer access |
| Paid verification marker | Customer INSERT cannot forge it; customer UPDATE is not granted; private trigger functions are not customer-callable |

Backend tests mock external delivery providers. Live SQL fixtures exercise actual ownership policies, role grants, billing-finalization triggers, entitlement checks, queue contracts, receipt projection and event deduplication. They do not invoke a delivery provider. No manual customer notification was sent as an acceptance probe.

The new service-only delivery tables intentionally have RLS enabled without customer policies or grants. The advisor's [RLS policy information](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) is expected for these tables. The two bounded customer setup/test APIs intentionally use guarded, rate-limited privileged functions; their [authenticated SECURITY DEFINER notice](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable) was reviewed against the negative tests. The wider project still has pre-existing advisor notices; this repair is not a complete project security certification.

## Owner configuration still required

**Meta Cloud:** the existing Meta profile has no App Secret reference, and a live request confirmed that no usable webhook secret is configured. Its health is marked degraded with `webhook_secret_unconfigured`. Its country route remains selected as Meta Cloud. Sending is withheld until authenticated receipts can be supported.

In the updated Admin UI, open **WhatsApp → Meta Cloud Profiles → Edit Profile**. Enter the **Meta App Secret**, save, then run **Probe Connectivity / Validate & Probe API**. Blank credential fields preserve existing secrets. Configure the **Webhook Verify Token** when registering or changing the Meta webhook. Check the receiving Phone Number ID, WABA account, expected sender and subscribed webhook events. Confirm an approved template name, language and variable layout before an outbound test. The new default-template UI expects one text variable; the adapter also honors a configured zero-variable mapping. Existing per-event mappings are preserved.

The adapter's default Graph API version is v26.0, verified against [Meta's maintained SDK configuration](https://raw.githubusercontent.com/facebook/facebook-python-business-sdk/main/facebook_business/apiconfig.py). Explicit profile API-version overrides remain supported. Template approval and token permissions still require a real Meta acceptance test.

**SMS, if used:** set the hosted `TWILIO_AUTH_TOKEN` and correct public webhook URL for signature verification. The hosted endpoint currently rejects requests because its signing token is missing. Do not treat the authenticated worker's internal SMS endpoint as a public Twilio webhook.

**Client publication:** the customer APK is a debug review build, not a store release. The Admin ZIP is a release web build, not a published Admin site. Install/serve these for review, then use the project's normal signed app and Admin publishing process.

## Acceptance and operations

Use an owner-controlled test SIM/recipient for live acceptance. Verify Basic preferences save while paid channels skip; finalized Standard and Premium deliver; expired subscriptions skip; and one Basic line does not borrow another line's entitlement. Check the Android app in foreground, background and after restart. Confirm save failures restore the displayed switch and do not report success.

For each enabled WhatsApp country route, run a profile probe and a test using the selected provider. Confirm one provider message, the correct sender, then a receipt-confirmed delivery in Message Outbox. Test Meta and Baileys separately. Verify that a disabled country stops new alerts and that inbound authenticated replies stay with their receiving profile. Complete at least one Email, Telegram and Push delivery using real credentials/devices before production sign-off.

Use Message Outbox to distinguish `accepted`, `sent`, `delivered`, `failed`, `skipped` and `unknown`. Reconcile uncertain sends against provider records/receipts before any manual replay. Never reset an unknown attempt to pending simply to force a resend. A route/profile change cancels an old unsent attempt; it does not silently move the same message to another provider. Keep the durable worker queue and receipt files across restarts.

Monitor failed/unknown channel targets, late failed worker receipts, disabled/unready profiles, missed cron runs and `notification_setup_event_failed` system alerts. A paid notification failure does not undo a captured subscription payment. After repairing setup-event queuing, the bounded setup event API can regenerate the confirmation using the same deduplication key.

Before running the live fixture script, pause the four notification cron jobs with `cron.alter_job` and record their active states. The script rolls back its fixtures; restore each job's previous active state afterward, including on failure. Provider tests should stay mocked; do not point these fixtures at real recipient numbers.

## Review artifacts

- [Customer review APK](C:/Users/abdal/Work/KeepSIMs/keep_sims/output/notification-fix-20261001/KeepSIMs-notification-review.apk)
- [Admin release web ZIP](C:/Users/abdal/Work/KeepSIMs/keep_sims/output/notification-fix-20261001/KeepSIMs-Admin-web.zip)
- [Live database fixtures](C:/Users/abdal/Work/KeepSIMs/keep_sims/test/notification_database_contracts.sql)
- [Backend contract tests](C:/Users/abdal/Work/KeepSIMs/keep_sims/test/notification_production_contracts.test.cjs)

Source changes remain available for review in the customer, Admin and authoritative worker checkouts. Existing unrelated working-tree changes were preserved. The earlier review documents describe the pre-repair findings; this document records their repaired behavior and the remaining acceptance requirements.
