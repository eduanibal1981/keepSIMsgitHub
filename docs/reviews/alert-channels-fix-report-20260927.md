# Alert channels and Alert Clock fix report

**Date:** 2026-09-27  
**Scope:** customer Flutter app, Supabase, WhatsApp/Telegram workers, and admin Flutter app.

## Current result

The in-app Alert Clock and one-time 48-hour urgent event are implemented. The
live scheduler is enabled. A live run on 2026-09-27 found **zero current
48-hour candidates**, so no customer received an urgent warning during this
work. One active line has a sourced, verified clock about 180 days from its
estimated cutoff; another needs an activity date. Ineligible lines do not get
an invented countdown or urgent event.

The live dispatch outbox had **22 complete jobs, zero failed, and zero unknown**
at the final check. Completion means the dispatcher handled the logical job;
provider acceptance remains distinct from confirmed delivery. No provider
receipt was available to prove end-user delivery of an urgent alert.

## Changes and deployment

| Area | Result | Deployment |
| --- | --- | --- |
| Alert Clock database | Owner-scoped clock read, qualifying activity and date precision, source freshness gate, atomic urgent event key, stale job cancellation, audited scheduler control | Live |
| Scheduler | Enabled; hourly notification job and a dedicated monitored run at minute 5 | Live |
| Generic alert dispatch | Transactional outbox, lease/unknown handling, bounded retry, quiet-hours deferral, stale-event checks | Live |
| Quiet Hours and digest | IANA time zones; urgent 48-hour exception; digest Sunday 09:00 local after explicit consent | Live backend; app UI local |
| Telegram and WhatsApp | One-time Telegram link token; durable WhatsApp worker queue and idempotency history | Live VM workers |
| Edge Functions | `dispatch-alert` v33 and `process-alert-outbox` v4 | Live |
| Customer app | Real in-app countdown, honest unavailable states, explicit digest consent, timezone bridge; removed fake 24-hour alarm | Local source; no store release |
| Admin app | Queue incidents and safe retry, scheduler status/control, carrier source and activity editor with impact preview, operations health summary | Local source; web build verified, not deployed |

The live baseline Alert Clock migration was initially missing from Supabase's
history even though its objects were present. After checking the tables,
functions, triggers, and setting, version `20260926120000` was marked applied.
Subsequent local Alert Clock migration filenames now match their live version
numbers. A comment-only marker represents the earlier duplicate application
of notification preferences; the later migration contains the full idempotent
SQL for a fresh rebuild.

## Verification

- Live privilege checks: anonymous and authenticated roles cannot execute the
  internal secret lookup or privileged clock/dispatch RPCs.
- Live clock dry run and enabled run: zero candidates and zero emitted events.
- Rolled-back transaction: two scheduler calls produced one urgent logical
  event and one queued job; no test warning persisted or reached a customer.
- Rolled-back carrier-rule check: unrelated edits preserved verification,
  policy edits invalidated it, and explicit source verification restored it.
- Customer Flutter targeted analysis: no issues. Alert Clock model: 5 tests
  passed. Push and quiet-hours tests: 12 passed, including DST transitions.
- WhatsApp queue: 4 tests passed; deployed worker syntax checks and PM2
  restart succeeded.
- Admin targeted analysis: no errors or warnings; three pre-existing style
  infos in edited files. Admin web build succeeded.
- Live cron: hourly notifications, minute outbox processing, and digest jobs
  succeeded at their latest observed runs. The dedicated Alert Clock run was
  scheduled after the latest hourly boundary and has not yet produced a run
  record.

## Remaining release limits

1. The customer mobile app and admin web app still need their normal release
   process. No deployment workflow for the admin web app was documented in its
   repository.
2. There was no consented test identity inside a genuine 48-hour window. The
   urgent path passed a rolled-back database test, but end-to-end recipient
   receipt remains unproven. Use a controlled test identity with verified
   carrier evidence before treating real delivery as proven.
3. The system can record provider acceptance but cannot claim inbox or device
   delivery without a receipt. Unknown WhatsApp or dispatch outcomes require
   reconciliation; the admin safe-retry action refuses those jobs.
4. Carrier policy sources need continuing review. At this check, 65 of 105
   rules had a current source and verification; 29 had a verification date but
   no source URL. The source gate prevents an unsupported 48-hour claim.
5. The admin alert additions extend the existing `AdminApi`/provider screens.
   They have not been moved into the separate model, contract, repository,
   controller, and UI layers requested by `ARCHITECTURE_RULES.md`.

## Operating and rollback notes

The admin Notification channels screen shows pending, failed, unknown, and
completed jobs; the operations dashboard has a short queue summary. The
carrier editor now previews active-line impact before a deactivation policy
change. Recheck the dedicated scheduler's last run in the admin screen after
its first minute-5 execution.

To stop **new** 48-hour events, switch off the Alert Clock scheduler in the
admin Notification channels screen. This does not delete history or cancel an
already queued alert. Review pending urgent jobs separately before restarting
the outbox if a policy issue is found. The source verification and stale-event
checks continue to block unsupported alerts while the scheduler is enabled.
