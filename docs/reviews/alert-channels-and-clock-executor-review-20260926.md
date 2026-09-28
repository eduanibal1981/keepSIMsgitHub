# Alert channels and Alert Clock implementation review

**Reviewed:** 2026-09-26  
**Scope:** customer app, Supabase migration/Edge Function/live database, authoritative backend workers, admin app. This is a review only; no production setting or code was changed by the reviewer.

## Verdict

**Partial implementation; hold broad release.** The executor built a clock state table, calculation function, 48-hour emitter, customer line card, admin overview, new status labels, Telegram token path, and some WhatsApp retry work. The live database already contains the clock objects and its scheduler switch is `true`; one line is currently eligible but about 180 days from the cutoff, one needs an activity date, and no 48-hour event has been emitted. These facts do not verify an end-to-end urgent delivery.

The live schema contains the new objects while `supabase_migrations.schema_migrations` does not record the corresponding migration. `dispatch-alert` remains live at version 30, the KeepSIMs email branding release; the newer local dispatcher changes have not been established as deployed.

## Findings, ordered by priority

### P0 — Public access to privileged clock and binding functions is live

`supabase/migrations/20260926120000_alert_clock_and_durable_channel_dispatch.sql:255-263,551,557-609,615-771,95-166` creates `SECURITY DEFINER` functions and grants selected roles without first revoking PostgreSQL's default `PUBLIC EXECUTE`. A live read-only privilege check confirmed that the `anon` role can execute `calculate_sim_line_alert_clock`, `sync_all_sim_line_alert_clocks`, `emit_urgent_deactivation_alerts`, `create_telegram_bind_token`, and `bind_telegram_bot_token`. The calculator checks no owner before reading a line and returns its activity/cutoff details. The global sync and emitter have no admin or service-role assertion. The Telegram binder additionally accepts any existing user UUID as a fallback token and can overwrite that user's Telegram chat binding.

**Fix:** revoke execution from `PUBLIC`/`anon` for every privileged RPC; allow only the needed role; enforce ownership inside the per-line calculator and make an internal service-only version for triggers/cron; require an admin check on admin actions. Remove the raw UUID Telegram fallback entirely, use a one-time token with atomic consumption, and recheck live grants after deploying the forward migration.

### P0 — Telegram linking cannot complete reliably and exposes a weak fallback

The customer UI at `lib/features/notifications/presentation/screens/notification_settings_screen.dart:2014-2025` receives a JSON object from `create_telegram_bind_token()` but converts the whole object to a string for the `start=bind_...` deep link. If the RPC fails, it sends the raw user UUID. The authoritative worker at `backend-sync-wt/server_tg.js:46-59` calls `bind_telegram_bot_token` with `p_token`, while the live RPC's argument is `p_token_or_uid`; PostgREST parameter matching rejects the call. The worker also logs the token on failure at line 94.

**Fix:** extract the `token` property, never fall back to a user UUID, match the RPC parameter exactly, treat `success:false` as failure, and remove raw token logging. Test a fresh link, expired link, replay, and another user's attempted link against a non-customer test account.

### P1 — WhatsApp queue/idempotency still loses or duplicates messages

The router (`supabase/functions/_shared/whatsapp_router.ts:238-280`) handles a raced insert when an attempt row is found, but if insertion fails for another reason and no row is found it continues to send with no persisted `attemptId`. At lines 324-329 it marks `whatsapp_sent_this_cycle` after a worker queue acceptance, before delivery. The worker (`backend-sync-wt/server_baileys.js:274-275`) removes a job from its backed-up queue *before* sending, so a process crash loses it. Its idempotency check at lines 499-511 searches only the in-memory pending queue; once a job is shifted, an identical request can enqueue and send again. The source has no new tests for these timeout/crash/race paths.

**Fix:** fail closed on outbox write errors; claim and persist jobs through an in-flight state; retain dedupe records after dequeue/restart; reconcile unknown sends and receipts before retry; make cycle commitment reflect the agreed send/receipt policy. Test request timeout after enqueue, crash before/after `sendMessage`, repeated idempotency key, receipt replay, and insertion conflict.

### P1 — Generic dispatch remains best-effort and delivery reporting is still inaccurate

The live `trg_fn_dispatch_notification()` still uses `net.http_post`, with no generic durable dispatch job table. The new migration only broadens `notification_deliveries.status`; it does not add a retryable outbox, worker, backoff, dead-letter state, or replay path. In `supabase/functions/dispatch-alert/index.ts:672-697`, delivery logging is best effort and a failed log still returns success. At lines 483-484, 590-591, and 659-660, Telegram, Resend email, and webhook HTTP success are recorded as **delivered** without a recipient receipt. Lines 677-695 still place provider-accepted channels in `notifications.delivered_via`. The admin card at `keep_sims_admin/lib/features/control/presentation/channels_screen.dart:225-239` still labels its aggregated `sent` metric “Delivered (30d).” Historical live rows use the old meaning of `delivered`.

**Fix:** implement a durable event/channel-attempt queue with explicit retry/unknown semantics; record provider acceptance separately from confirmed delivery; migrate or clearly label historical metrics; make test-send copy describe acceptance instead of receipt. Keep provider failures visible even when the HTTP request to the dispatcher succeeded.

### P1 — `usage_required` can produce a false cutoff; date precision is overstated

The calculator at `supabase/migrations/20260926120000_alert_clock_and_durable_channel_dispatch.sql:341-363` treats `carrier_liveness_check`, `sim_ping_success`, or a generic `is_carrier_verified` flag as qualifying outgoing call/SMS/data activity. None of the queried event types are allowed by the live `line_activity_log` event constraint, and a liveness check does not prove the carrier's usage requirement. The calculator assigns a timestamp cutoff even for self-reported, date-only recharge data (lines 418-420, 433-437). The customer card at `lib/features/sim_lines/presentation/widgets/alert_clock_card.dart:99-166` ignores `precision` and displays decimal hours and a “Safe Cutoff” from that invented time. It reads a cached state without an on-screen timer or resume refresh.

**Fix:** accept only evidenced qualifying network usage; otherwise keep `needs_qualifying_usage`. Store a date/precision and carrier time-zone policy; present date-based estimates without fractional hours. Recalculate on resume and update the visible countdown from server time. Add tests for all carrier rule types, unknown activity, time zones, and activity just before dispatch.

### P1 — The 48-hour event is not concurrency safe

`supabase/migrations/20260926120000_alert_clock_and_durable_channel_dispatch.sql:653-755` does a `NOT EXISTS` check and then inserts a notification without an urgent-event unique index or `ON CONFLICT` handling. Two concurrent scheduler runs can insert and route the same logical event twice. The predicate at line 665 compares `cs.alert_cycle_token` to itself, so that side of the condition can never help. The scheduler is live-enabled; no urgent event has yet exercised the path.

**Fix:** add a unique constraint/index for the logical urgent event key and an atomic insert/claim; remove the self-comparison; prove concurrent calls emit one event. Also cancel a queued event if the carrier rule/activity changes before dispatch.

### P2 — Several accepted product behaviors and admin workflows remain unfinished

- Quiet Hours and Weekly Digest are still stored settings; searches of the current functions and live notification trigger found no dispatch deferral or digest processor. The customer settings still promise automatic Push/Email fallback when a channel is paused (`notification_settings_screen.dart:1523`), while dispatcher `isFallbackTriggered` remains false and no such fallback is performed.
- The settings page calls a 24-hour sounding alarm “ARMED” (`notification_settings_screen.dart:1120-1157`), but `EmergencyAlarmDialog` is only opened by the preview button. Its countdown starts at a hard-coded 23h 58m (`emergency_alarm_dialog.dart:73-94`) and it claims to bypass mute/silent filters. This was not the selected 48-hour product behavior.
- The admin app adds a clock overview/table, but the carrier rule editor and operations screen were not updated for rule-quality previews, per-channel retry backlog, dead letters, scheduler pause, safe replay, or confirmed-delivery metrics. The “Recalculate All” button calls the globally executable RPC (`keep_sims_admin/lib/core/admin/admin_api.dart:523-525`). New admin code also bypasses the project's stated model → contract → repository → controller → UI layering.
- `AlertClockCard` hides database errors by returning an empty widget (`sim_line_alert_clock_provider.dart:7-24` and `alert_clock_card.dart:33-42`). On a schema or permission problem the customer gets no explanation. The `needs_qualifying_usage` action is not wired from the line detail screen.

**Fix:** either implement the behaviors and admin controls specified in the accepted prompt or remove/disable UI claims and switches until they function. Keep the selected 48-hour alert as the product behavior; make any extra alarm a separately approved feature.

### P2 — Test and deployment evidence is incomplete

The new tests cover a Dart clock-state model and an alarm preview, but there are no focused SQL tests for rule semantics, 48-hour crossing, duplicate cron runs, ownership/RPC grants, or migration drift; no new worker idempotency tests; and no admin UI tests for the new view. `node --check server_baileys.js` and `node --check server_tg.js` passed. The existing push suite ran **8/9 passed**; its dispatcher integration test now gets HTTP 500 because its fake database rejects the new `notifications` update. Update the test fixture and rerun before accepting the change. Targeted Flutter analysis produced no output and did not complete in a reasonable time, so Flutter compilation remains unverified in this review. The new local migration is not recorded in live migration history even though its tables/functions/constraint are present; establish the deployment provenance and reconcile history before applying more DDL.

## Suggested fix order

1. Restrict the live RPC privileges and remove the UUID Telegram bind path; repair the app/worker token contract.
2. Put a safety gate on further alert rollout; add atomic event deduplication and correct `usage_required`/date precision.
3. Make WhatsApp outbox and worker idempotency durable across timeout and restart.
4. Add a generic dispatch queue and truthful status model; then implement Quiet Hours, Weekly Digest, and accurate fallback copy.
5. Finish admin operational controls, focused tests, rollout evidence, and migration-history reconciliation.

## Evidence limits

Read-only live checks confirmed: the clock table/functions/triggers and status constraint exist; `ALERT_CLOCK_SCHEDULER_ENABLED=true`; the two clock states are one eligible and one needing an activity date; no `line_deactivation_imminent` events exist; the old `pg_net` trigger remains; `anon` can execute the listed functions. The live worker deployment was not inspected, and no real customer alert was sent. Because the work spans heavily modified, uncommitted checkouts, the review identifies relevant local code rather than attributing every dirty file to this executor.
