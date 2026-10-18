# Task 4 — endpoint authentication and webhook verification

Reviewed 2026-10-17 (Asia/Muscat). **REPAIRED LOCALLY; NOT DEPLOYED.**

Scope: Task 4 in [the executor plan](audit-executor-plan-20261016.md). Existing
credential, financial, client, configuration and staged work was preserved.
No production writes, provider calls, deployments, rotations or VM actions were
performed. The native concurrency suite used a disposable local PostgreSQL server.

## Finding status and evidence

Read-only Supabase MCP retrieved all eight deployed function bundles and their
current gateway settings. [Sanitized inventory](endpoint-authentication-live-20261017.json)
records deployed bundle hashes, versions, settings and local entrypoint hashes;
bundle hashes and individual source hashes measure different artifacts.

| Surface | Deployed evidence | Local status |
| --- | --- | --- |
| `process-voicemail` v2, JWT off | Header presence only; supplied `user_id` drives privileged insert/push | REPAIRED LOCALLY: exact internal service credential, stored call/DID ownership, recording deduplication. Gateway JWT is now configured on. |
| `admin-telnyx-billing` v4, JWT on | Decoded unsigned claims/service role and mutable-profile fallback | REPAIRED LOCALLY: Supabase Auth verifies user tokens, then existing `assert_admin()` validates the caller's JWT and suspension. Internal service credentials use exact comparison without an end-user Auth flow. Gateway verification already limits the deployed exposure; no live forged-token bypass is asserted. |
| Liveness callback v6, JWT off | No provider signature checks | REPAIRED LOCALLY: Twilio HMAC and Telnyx Ed25519 checks before claims/actions, stored provider-resource binding and checked settlement. |
| Liveness endpoint v8, JWT on | Provider cancellation accepts a supplied call ID without an owned attempt | REPAIRED LOCALLY: owner-scoped voice attempt, stored provider/ID only, no cross-provider fallback. |
| Telnyx CDR v8, JWT off | Verification conditional on public-key availability; deduplication checks/inserts race | REPAIRED LOCALLY: missing/malformed key rejected; strict timestamp/signature check; durable event/resource claims. |
| Twilio voice v3, JWT off | Signing token optional; invalid signature acknowledged; failed persistence acknowledged | REPAIRED LOCALLY: required credential, canonical signed URL, authentication before rate-limit mutation, durable deduplication and retryable persistence errors. Earlier Task 2 local missing-credential protection was retained. |
| SMS v5, JWT off | Already rejects absent signing configuration and bad signatures | Blanket fail-open claim is STALE. Protection preserved; local URL construction now ignores forwarded host/proto, verifies all form fields and authenticates before rate-limit mutation. |
| WhatsApp v7, JWT off | Existing signature/profile-secret controls | VERIFIED DEPLOYED source protection: entrypoint exactly matches unchanged local source. Regression tests added. Actual provider credentials/runtime delivery remain UNVERIFIED. |

The new receipt table/functions and voicemail recording column are absent live.
Live `assert_admin()` is authenticated-callable and checks identity, trusted
power-user claims and suspension. Live verification settlement locks its attempt
and returns an existing terminal result; call debit adopts its stable call
reference on retry. Their underlying pricing/ledger/outcome correctness remains
assigned to the later financial/verification tasks.

## Implementation and boundaries

Shared helpers implement authentication, provider signature verification, durable
claims and provider-resource-based liveness handling. No caller can authorize
itself by decoding a JWT. Voicemail accepts internal services only; ordinary user
JWTs cannot author recordings even for their own account. A supplied legacy
`user_id` is checked for consistency and never selects the owner. If both call and
DID are supplied, their owner and destination number must agree. The owner comes
from the stored call or DID; caller number comes from the call when available.

The forward migration is
`supabase/migrations/20261017100000_endpoint_webhook_authentication.sql`.
It creates a private RLS-enabled receipt table with service-only definer APIs,
empty search paths, explicit grants and an in-body service-role gate. Existing
Telnyx processed-event IDs are preserved as completed receipts. Voicemail gains
a unique optional source recording ID; existing NULL rows remain compatible.
No wallet, verification-outcome, price or balance migration is included.

Receipts bind scope/event ID to a canonical payload hash and resource. Telnyx hashes authenticated event data, excluding changing delivery metadata; form field ordering does not alter a Twilio event identity. Concurrent events
for the same resource serialize; unrelated resources can proceed. Explicit
failures permit retry with a new token. Only the matching claim token can finish
an attempt. Completed events do not repeat actions, and altered payloads cannot
reuse the same event ID. Telnyx CDR uses the resolved stored call ID to serialize
both call legs. Both Telnyx liveness ingress paths use the same receipt scope.

A crashed invocation retains its processing claim. There is deliberately no
age-based takeover while a provider outcome may be ambiguous. This favors
avoiding duplicate effects and requires operator reconciliation for abandoned
claims; it is not a background reconciliation worker. Review provider state and
existing SQL effects before an operator marks a claim completed or failed. Keep
receipt identities across retries; do not install a time-based deletion job for
Twilio receipts, whose signatures have no freshness timestamp. Signed provider
retries still need signature validation before duplicate lookup.

Twilio signature input includes the exact configured external URL/query and all
form fields. Forwarded host/proto never select the trusted URL. Telnyx verifies
the raw body with Ed25519 over `timestamp|body`, rejects malformed timestamps and
uses a five-minute replay window. Raw base64, exact Ed25519 SPKI and hex public
keys are accepted. Secret retrieval preserves Task 2's Vault-first behavior and
controlled failures. Provider cancellation and settlement errors return retryable
responses rather than acknowledging incomplete work. Voicemail push remains
best-effort, only after the first recording insert; notification recovery is not
an exactly-once delivery guarantee.

## Tests actually run

- `node --test test/endpoint_webhook_auth.test.cjs test/sms_notification_auth.test.cjs test/provider_secrets.test.cjs`: **38 passed**. Actual Edge modules run with isolated Auth/DB/provider adapters and real HMAC/Ed25519 cryptography. Includes forged/expired JWTs, ordinary/suspended admins, exact internal service authentication, foreign targets, missing credentials/keys, invalid/stale signatures, provider canonical example, signed URL queries, resource mismatch, concurrent/replayed delivery, persistence/provider errors, and SMS/WhatsApp regressions. The Auth adapter verifies synthetic JWT signatures/expiry; this is not a live Supabase Auth exercise.
- `PGLITE_MODULE_PATH=/tmp/keepsims-financial-tests/node_modules/@electric-sql/pglite/dist/index.js npm run test:webhooks --prefix tools/financial-tests`: **12 passed**. Actual forward SQL checks service/API permissions, unsafe defaults, identity/hash conflicts, claim tokens, legacy receipts, recording uniqueness, abandoned claims and the release catalog query. The fixture represents only objects needed by this migration; it is not a financial or complete Supabase schema fixture.
- `EMBEDDED_POSTGRES_MODULE_PATH=/tmp/keepsims-financial-tests/node_modules/embedded-postgres/dist/index.js npm run test:webhooks:concurrency --prefix tools/financial-tests`: **3 passed**, independent native PostgreSQL sessions. Initial sandbox run failed on shared-memory permissions; the authorized local test rerun passed and removed its temporary server/data.
- TypeScript `tsc --noEmit` passed for the seven changed entrypoints and imported local helpers, using temporary declarations for Deno environment/remote serve/Supabase imports. Deno is unavailable here; remote dependency/runtime validation remains a release check.
- `git diff --check` passed. Live read-only inventory, source inspection and relevant SQL definitions were checked. The read-only release catalog query returned the five expected missing migration objects before deployment. All eight declared gateway settings and entrypoint paths were also checked. No Flutter changes were needed; no Flutter build/full suite or production callback/provider transaction was run.

## Compatibility and separate release procedure

1. Recheck the relevant live bundles, schema and existing processed-event IDs.
   Coordinate Task 2 credentials before enforcing these handlers. Configure
   `TELNYX_PUBLIC_KEY`; preserve usable Vault/environment Twilio/Telnyx credentials
   and the `get_internal_secret` service grant. Credential values/validity were
   not inspected or changed in this task.
2. Prepare the internal voicemail producer to send a stable provider
   `recording_id`, HTTPS `audio_url`, and stored `call_record_id` or `did_id` using
   the actual service credential. No producer was found in either Flutter app or
   the authoritative worker repository. This external integration remains a
   release prerequisite; the old user-ID-only payload is intentionally rejected.
   Customer voicemail reads/mark-as-read remain compatible. Admin billing keeps
   its response contract and the existing admin caller needs no payload change.
3. Under separately scoped deployment authorization, apply only the reviewed
   Task 4 migration, then deploy its Edge sources with all imported helpers.
   Coordinate with the independent Task 3 containment release and never run an
   unfiltered migration push over unrelated pending repairs. No dependency on
   pending wallet migrations is introduced by the receipt schema.
4. Apply the exact `supabase/config.toml` gateway settings. User endpoints and
   internal voicemail retain JWT verification; external provider callbacks use
   `verify_jwt=false` with mandatory handler signatures. Voicemail changes from
   the deployed false setting to true. Legacy service-role JWTs satisfy this
   additional gateway check; they are not sent to the end-user-only Auth API.
5. Standard project URLs are derived from `SUPABASE_URL`. For a custom public
   origin/path configure per-function `TWILIO_VOICE_WEBHOOK_URL`,
   `LIVENESS_WEBHOOK_URL`, and `TWILIO_SMS_WEBHOOK_URL` to match the provider's
   external URL exactly. SMS retains `PUBLIC_FUNCTION_URL` compatibility;
   voice/liveness use their scoped variables to avoid a shared global URL
   accidentally selecting another endpoint. Queries are signed; a configured
   fixed query must equal the received query. Unsupported callback media types
   return 415; non-POST provider requests are rejected.
6. Run `supabase/tests/endpoint_webhook_authentication_tests.sql` read-only;
   require zero rows. Re-fetch deployed source/settings and verify scoped valid,
   invalid, foreign-target, duplicate and retry behavior with approved synthetic
   records/provider callbacks. Inspect abandoned processing claims and confirm
   legitimate voicemail/admin callers. Record evidence before marking VERIFIED
   DEPLOYED. Reverting handlers alone would restore unsafe behavior; retain the
   fail-closed boundary if a release needs operational containment.

Unresolved production risks are the undeployed repair, unknown signing/provider
configuration and external voicemail producer, operator recovery of abandoned
claims, and later tasks' financial settlement/outcome rules and client table-write
bypasses. Task 5 (PayPal capture identity) can be implemented independently; its
implementation prerequisites are satisfied. Production safety and payment
correctness are not certified by these tests. No next task was started.

Provider references consulted: [Twilio request signing](https://www.twilio.com/docs/usage/security),
[Twilio webhook parameter and URL rules](https://www.twilio.com/docs/usage/webhooks/webhooks-security),
[Telnyx verification/deduplication contract](https://developers.telnyx.com/docs/development/api-fundamentals/webhooks/receiving-webhooks),
and [Telnyx SDK signature verification](https://github.com/team-telnyx/telnyx-node/blob/master/src/lib/webhooks.ts).
