# Task 12 — liveness verification and removal of self-verification

Status: **locally repaired and verified; not deployed** (2026-10-18, Asia/Muscat).

The former customer RPC and both apps could award provider verification and a
100-point score without authenticated carrier evidence. Health calculation and
two customer detail-screen paths also accepted arbitrary activity-log wording.
The legacy settlement could charge an unsupported `verification_debit` and did
not bind its reservation/allowance tightly enough to the attempt.

## Repair

- `20261017201740_liveness_verification_contract.sql` is a forward migration.
  It retains rejecting legacy confirmation/settlement signatures and revokes
  their API grants. The new start, binding and event-settlement RPCs are service
  only; verification/allowance tables are read only for customers. Existing
  ownership RLS remains in effect, including administrator reads.
- Start serializes the customer/idempotency key and SIM line, validates ownership,
  snapshots country pricing and the destination, and creates the attempt with
  its exact wallet hold or annual allowance in one transaction. Repeated starts
  adopt the existing attempt. An unresolved attempt blocks a second dispatch.
  Allowances use the stored, unexpired paid-plan period; a missing expiry does
  not mint a rolling annual allowance. Broader paid-entitlement provenance is
  still Task 18's release dependency.
- The Edge start authenticates the user and resolves required provider settings
  before reserving. Only the winning start dispatches. It binds a Telnyx
  `call_control_id` or SMS message ID; it never substitutes a call-leg ID. A
  definitive rejection releases through checked settlement. Timeout, ambiguous
  provider response or failed binding retains the attempt/reservation for
  reconciliation. Retrying cannot dispatch again.
- Existing fail-closed Telnyx/Twilio signature verification and durable webhook
  receipts are retained. Callbacks correlate through the stored provider
  resource. SMS delivery or an observed ring/answer supplies positive evidence.
  Busy, no-answer, timeout, completed or normal-clearing alone does not verify a
  line. Multiple/foreign SMS destination records are rejected.
- Settlement locks the line/attempt, checks provider, event, method, destination,
  owner, country and exact hold/allowance identity, and atomically captures or
  releases it with the terminal outcome. Duplicate and conflicting late events
  return the stored terminal result without changing it. Wallet capture uses
  Task 7's supported discriminator, funding allocations and reconciliation.
  A failed capture rolls back verification and the attempted charge together.
- Verified fields are protected on direct insert/update by an invoker trigger,
  including client inserts and power-user clients. Changing line identity is
  blocked while an attempt is unresolved; later identity edits clear evidence
  for the old destination. Writable customer payloads and old offline queued
  payloads strip provider-verification fields.
- Health retains the established 25/25/50 verification/notification/recharge
  calculation. Only a new, terminal, successfully settled provider attempt
  matching the current line can supply verification points. Logs and manual
  reports remain history, never provider proof. Both apps' self-confirmation
  methods are removed. The already-disabled admin legacy call flow cannot
  self-award verification; supported checks start in the customer's owned-line
  flow. Number-format/allocation-only fallbacks remain pending.

## Verification

| Evidence | Current result |
| --- | --- |
| Production-shaped financial/WASM suite | 93 passed, 0 failed (includes 15 focused liveness scenarios and catalog checks) |
| Native PostgreSQL with independent sessions | 120 passed, 0 failed; simultaneous start, duplicate capture/allowance consumption, conflicting terminal events |
| Real isolated PostgREST 16.4 | 11 passed, 0 failed; named/defaulted liveness RPC calls, role denial, wrong-resource denial, retry and exactly one debit |
| Edge/provider-secret/webhook tests | 45 passed, 0 failed; signatures, owned cancellation, ambiguous dispatch, binding errors and terminal evidence |
| Focused customer Flutter tests | 11 passed, 0 failed; liveness payload, writable updates and health pillars |
| Changed customer analysis | No errors/warnings; 3 pre-existing logging info diagnostics |
| Changed admin analysis | No errors/warnings; 8 pre-existing style info diagnostics |

The fixture uses the captured production constraints and actual financial
functions/triggers. Auth, supply/risk adapters and unrelated notification trigger
chains remain bounded fixture adapters; the isolated API is not deployed
Supabase. No real telephony, customer charge, migration deployment or VM change
was performed. Machine-readable results are in
`liveness-verification-repair-20261018.json`.

Reproduce with the pinned dependencies in `tools/financial-tests/package-lock.json`:

```sh
npm run test:liveness --prefix tools/financial-tests
npm test --prefix tools/financial-tests
npm run test:concurrency --prefix tools/financial-tests
node --test test/liveness_contract.test.cjs test/endpoint_webhook_auth.test.cjs test/provider_secrets.test.cjs
flutter test --no-pub test/features/sim_lines/sim_liveness_test.dart test/features/sim_lines/update_sim_line_test.dart test/features/sim_lines/sim_line_health_test.dart
```

Existing `PGLITE_MODULE_PATH` and `EMBEDDED_POSTGRES_MODULE_PATH` cache overrides
are supported. The HTTP runner uses `test:scheduled:http`, an explicitly verified
`POSTGREST_BINARY`, and (on macOS) `POSTGREST_LIBRARY_PATH`; see the financial
runner README. It neither downloads a binary nor reads production credentials.
`supabase/tests/liveness_verification_contract_tests.sql` is a read-only catalog
check that returns zero violations after deployment.

## Coordinated release and remaining gates

1. Release only with Tasks 3/4 and the Task 7 wallet constraint/funding/ledger
   contracts, following the approved financial release sequence through Tasks
   9–11. Do not deploy this migration alone against the current ledger CHECK.
   Do not replay archived SQL or push the entire pending directory.
2. Deploy the migration with `liveness-verification`,
   `liveness-verification-webhook`, `telnyx-cdr` (shared callback consumer),
   `validate-sim-liveness`, and the matching clients. Confirm actual webhook
   settings/signing keys, gateway configuration, service-only grants, source
   versions and PostgREST cache behavior. Old settlement/confirmation callers
   intentionally fail closed.
3. The migration clears legacy verification claims and recalculates health.
   Legacy attempts remain evidence version 0; no success or log is automatically
   promoted. Review existing attempts, duplicate provider resources and money
   reservations before activation. Do not fabricate proof or consume/release a
   foreign reservation to make a legacy attempt fit the new contract.
4. Unknown dispatches stay reserved. An operator must look up the provider
   outcome using authenticated provider records and the owned stored attempt;
   bind a recovered resource only when identity is proven, then process the
   authenticated terminal event. Missing evidence is not permission to release
   or retry a purchase. No automatic provider-reconciliation worker is claimed.
5. An early callback arriving before resource binding gets a retryable response.
   Confirm provider webhook retries and recovery of failed binding in the scoped
   provider test. Out-of-order terminal events conservatively retain the first
   settled result; a hangup received before a ring can leave a check inconclusive.
6. Under separate operational authorization, exercise a scoped paid/allowance/
   zero-price check, failed delivery, cancellation ownership, provider timeout,
   duplicate events and reconciliation against the deployed release. Confirm
   actual charges and health; no broad production readiness is implied.

Read-only live verification during this task confirmed customer execution of
`confirm_line_verification` is still enabled, the live ledger CHECK still lacks
`verification_debit`, and the new event settlement/field guard are absent. These
are **release obligations**, not locally closed production findings.
