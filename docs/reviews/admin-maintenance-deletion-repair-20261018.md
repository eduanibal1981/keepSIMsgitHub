# Task 16: admin maintenance, account deletion and audit records

Status: **REPAIRED LOCALLY; NOT DEPLOYED**, 2026-10-18 (Asia/Muscat).

The supplied production schema and stored live catalog confirm the three SQL
defects. Original pruning fails on missing `current_user_email()`; original
admin purge references unsupported deletion columns and omits required fields;
rate-health's threshold branch inserts unsupported alert columns. All three
failures were reproduced using actual captured definitions in isolated PostgreSQL.
The earlier Task 3 prune repair changed `details` to `after_value` but still
retained the missing email helper. This task completes that repair forward.

## Maintenance and audit contracts

[`20261018030000_admin_maintenance_deletion_contract.sql`](../../supabase/migrations/20261018030000_admin_maintenance_deletion_contract.sql)
uses the existing `assert_admin()` and `admin_log(p_action,p_target_type,
p_target_id,p_before,p_after,p_note)` contracts. The latter derives the actor's
email from the profile and writes supported `after_value`/`note` fields. Pruning
and its audit are transactional; an audit failure rolls back deletions. Retention
minimums remain three cron days and seven alert days. Null/unsafe arguments are
rejected, with a 36,500-day maximum to bound interval construction.

The checked admin facade and postgres/service cron facade share an owner-only
invoker core. Client roles cannot invoke the core or service facade. Rate-health
uses `system_alerts(kind,message,details)`, preserving the threshold of 20
`rate_limited` events in one hour and six-hour suppression. A transaction advisory
lock serializes concurrent checks. Severity belongs in details under this schema.

## Deletion state and irreversible operations

The new private `account_purge_jobs` table retains target ID, authorized actor
ID/email, request reason, state, claim token, lease, attempts and outcome. It has
no Auth foreign key that would erase these snapshots. API roles, including the
service role, have no direct table access; trusted RPCs own transitions.

The existing admin RPC retains its signature, admin check and typed UUID
challenge. It requires a named administrator, rejects self-purge, fills actual
`account_deletions` fields (`email_hash`, `scheduled_purge_at`, `reason`,
`actor_id`), suspends the target and pauses schedules. Its return is `queued`,
`processing`, `completed`, or a failed request; enqueueing no longer sets purge
or Auth-deletion timestamps. Requests dispatch only a stored job ID. Repeated
requests reuse the job. Explicit retries of failed jobs record the new requesting
admin and reset the bounded attempt budget; active jobs retain their original
actor. The admin repository now checks this response and surfaces rejected work.

The hourly postgres producer preserves the grace period and queues due
requested/frozen/draining/drained records. `purged_count` remains zero at this
asynchronous step; `queued_count` reports dispatched work. It no longer fabricates
wallet settlement or marks an account completed before the external operations.
Customer cancellation locks its request against the due-job producer.

The service claim RPC validates the due persisted request, locks/fences the job
and changes it to processing with a ten-minute lease. Five attempts require
explicit admin review/requeue. Expired processing leases can be redispatched;
new tokens reject stale completion. Auth deletion and removal of the same
Storage paths are idempotent operations when a crashed attempt is retried.

[`purge-accounts`](../../supabase/functions/purge-accounts/index.ts) requires the
Vault-backed `x-keep-sims-secret`, checks secret lookup errors and accepts only
`job_id`. Legacy raw `user_id/admin_purge/confirm_user_id` requests are rejected.
The target comes from the claimed database job. It enumerates both existing
attachment buckets (`ticket-attachments`, `support_attachments`) under the stored
target UUID, paginates and walks nested folders before removing file batches.
Current customer upload sources use that UUID prefix. Malformed paths, excessive
enumeration, permission/list/remove errors fail the job before Auth deletion.
A 404 absent bucket is treated as empty; other Storage errors are retained.

The supported Auth Admin API runs after successful cleanup. A specifically
absent Auth user is idempotent success; other Auth errors fail. The old direct
SQL Auth deletion fallback is revoked and its body refuses execution.

Completion calls `finish_account_purge_job` with the actual `p_note` parameter.
This replaces the incompatible generic `admin_log(p_reason=>...)` Edge call.
The completion RPC verifies the claim token and independently checks Auth
absence, then updates deletion state/timestamps and writes the success audit
atomically. It uses the stored authorized actor instead of attributing a service
callback to `service_role`. For self-requested deletion, a removed actor's UUID
is retained in the audit's `authorized_actor_id` snapshot while the nullable
foreign-key actor is null. Successful duplicate completion audits once.

Storage/Auth failures persist sanitized failure codes and an audit. If the
completion audit itself fails after irreversible Auth deletion, the handler
returns an error and leaves recoverable processing state. It never reports a
completed job whose completion audit could not commit. Diagnostic logging excludes
raw exceptions, credentials and customer/provider payloads.

## Retention and provider reconciliation gate

Final deletion is deliberately gated for nonzero wallet balances, active holds,
funding lots, refund requests, wallet ledger rows, top-up executions, user eSIMs,
virtual DIDs or call records. This includes consumed historical funding lots and
terminal provider history, not just currently active money. These relationships
include Auth/line cascades and pending financial immutability contracts; silently
deleting or detaching them would require an additional reviewed retention and
settlement policy.

Such jobs return `review_required` with
`retention_or_funding_review_required` and persisted failure evidence. An account
without these blockers can complete the tested Storage/Auth path. Do not erase
history or release funds simply to satisfy the gate. Financial settlement,
retained evidence de-identification and supplier resource retirement remain
operational prerequisites for affected accounts. This task creates no balance
zeroing, forfeiture, refund, paid-resource cancellation or historical backfill.

Legacy `purged`/`auth_deleted` rows are not automatically adopted as verified
completed jobs. A stored status does not prove either external operation ran.
Review historical evidence separately; an administrator can requeue an existing
Auth target through the checked request path.

## Versioned email replacement

The captured read-only Edge inventory confirms **deployed `send-admin-email`
v2, active, `verify_jwt=false`**, with entrypoint SHA-256
`d3a1e606df3b39280a6d2cd8b559b4dac11eaaf09da4aa00cea97d08d4552589`.
The captured bundle SHA-256 is
`9d18ac3541ab3df67c8cdf2baeee9aa80f2558c9363bb9c397077a58a97c55d6`.
Its observed authentication contract is `x-sync-secret` using
`get_internal_secret`. The source was unavailable locally; its existence is not
disputed, and this work does not claim to have recovered it.

[`send-admin-email`](../../supabase/functions/send-admin-email/index.ts) is an
**intentional source-controlled replacement**, retaining the `email_id` and
secret-header contract. `kick_admin_email` validates a queued stored email,
resolves its existing Vault secret and dispatches only the ID. The existing
checked `admin_send_email` continues to validate sender/recipients and record the
request. Client mutations of `admin_emails` are explicitly revoked.

The replacement claims a queued row through service-only SQL, sends the persisted
envelope through the already-used Resend provider with `RESEND_API_KEY`, and
records a fenced outcome. It ignores request-supplied recipients/content. The
provider request uses `Idempotency-Key: admin-email-<UUID>`; Resend documents a
24-hour key lifetime, so the database claim remains the long-term duplicate-send
boundary. See [Resend's idempotency contract](https://resend.com/changelog/idempotency-keys).

The existing `sent` state means provider acceptance, not mailbox delivery.
The handler returns `accepted_by_provider`. Timeouts, malformed success payloads,
408/409 and server errors retain `provider_outcome_unknown`. A failed or sending
row is never automatically reclaimed/resubmitted; operator/provider review is
required. A persistence failure returns an error rather than success. The
replacement requires a configured Resend key and verified allowed sender; no
existing provider credential was read, changed or tested against a live provider.

## Verification performed

```sh
EMBEDDED_POSTGRES_MODULE_PATH=/tmp/keepsims-financial-tests/node_modules/embedded-postgres/dist/index.js node tools/financial-tests/maintenance.mjs
node --test test/admin_maintenance_endpoints.test.cjs
```

- **29 native SQL/integration scenarios passed.** These cover the three original
  failures; admin/non-admin pruning; bounds and audit rollback; threshold/cadence;
  queued deletion fields and confirmations; request/claim/failure/completion;
  duplicate and stale tokens; actor preservation; grace/cancellation; review
  gates; private tables and function grants; actual service calls; email
  claim/outcome; and independent-session claim concurrency. Three scenarios run
  the actual Edge handlers against exact named SQL RPCs, including success,
  audit failure after isolated Auth removal, and synthetic email acceptance.
- **20 Edge adapter tests passed.** These exercise secret/configuration denial,
  malformed input, legacy bypass denial, nested/paginated cleanup, Storage/Auth
  failures, absent resources, completion/audit error handling, persisted email
  envelope, provider idempotency, ambiguity and duplicate suppression.
- **Dart analysis passed** for the modified sibling admin repository file:
  `lib/features/user_management/data/repositories/user_management_repository.dart`.
- JavaScript/Python/package syntax and targeted whitespace checks passed. The
  capture script's existing notification/forecast outputs remain byte-identical.

The SQL fixture extends the notification baseline with eleven complete captured
table shapes and fourteen function bodies verified against independent live
catalog SHA-256 fingerprints. Extension constraints/keys/foreign keys/indexes are
retained. The base fixture's excluded payment-gateway FK remains excluded.
Vault/pg_net/cron relations are local stand-ins, with a transactional request
recorder that performs no HTTP call. The Auth row deletion is only in the temporary
database; Storage and provider adapters use synthetic data. Unrelated triggers,
full table ACL/RLS parity, Supabase Auth lifecycle internals, deployed cron/Edge
behavior and real delivery are outside this evidence. No current Supabase tools
were available for a fresh live check. No production account was deleted and no
real email was sent.

Supporting files: [SQL scenarios](../../tools/financial-tests/maintenance.mjs),
[Edge tests](../../test/admin_maintenance_endpoints.test.cjs),
[read-only catalog assertions](../../supabase/tests/admin_maintenance_contract_tests.sql),
[fixture manifest](../../supabase/tests/fixtures/admin_maintenance_baseline.json).

## Coordinated release requirements

1. Recheck current definitions/grants, table constraints, Auth cascades, all
   attachment bucket paths and deployed `purge-accounts`/email inventory. Resolve
   live drift and classify financial/provider blockers before allowing deletion.
   Confirm privileged function ownership remains postgres, as captured.
2. Review this targeted migration after any Task 3 containment release. Task 3's
   old prune-body fingerprint rejects this newer implementation if applied later;
   do not bypass that check or bulk-push the pending queue.
3. Pause deletion dispatch and admin email submission during the coordinated
   SQL/Edge transition. Release this migration, both matching handlers with the
   explicit `verify_jwt=false` configuration, and the matching admin response
   check. The old raw purge payload and SQL Auth fallback are retired. Reconcile
   existing pg_net requests and old sending/completed-looking rows manually.
4. Verify both Vault secret names, the replacement's existing Resend environment
   key and sender configuration through scoped operational checks. Do not infer
   email-source parity: this release intentionally replaces the pinned v2.
5. Run the read-only catalog check and inspect queued/failed/processing job and
   audit evidence. Observe scheduled dispatch without creating a real deletion
   or email test. Production deletion/provider/email tests require their own
   explicitly scoped authorization.

Task 16's local repair and isolated acceptance checks are complete. Deployment,
current live behavior, and affected-account retention/provider reconciliation
remain pending. Task 17 was not started; its DID lifecycle work may be required
before affected accounts can pass the deletion gate.
