# Call duration, reserved funds and billing — Task 13

Reviewed 2026-10-18 (Asia/Muscat). **REPAIRED LOCALLY; NOT DEPLOYED.**
Only Task 13 was implemented. Existing staged/unstaged work was preserved.
No production writes, real calls, provider purchases, deployments, VM operations,
customer balance repairs or legacy reservation backfills were performed.

## Findings and evidence

| Finding | Starting evidence | Result |
| --- | --- | --- |
| Five-minute hold could authorize up to an hour using posted funds | Current `make-call` and three copies of `call-media.ts` | REPAIRED LOCALLY: one atomic reservation/snapshot and provider duration derived from that budget |
| Increment and connection fee ignored during settlement | Read-only live `finish_media_call` definition; source | REPAIRED LOCALLY: one exact-decimal cost function for admission and settlement |
| Retry referenced undeclared `balance` | Current `make-call` source | REPAIRED LOCALLY: original accepted terms and current wallet summary returned; no new reservation/dial |
| Setup error could release money after ambiguous provider acceptance | Current Edge catch/release path | REPAIRED LOCALLY: committed submission markers and retained hold; retry never repeats submission |
| Either leg's hangup could release funds before complete destination evidence | Current media event handler | REPAIRED LOCALLY: destination termination and destination bridge evidence drive settlement |
| Legacy CDR path could debit unreserved money | Current non-media callback branch | REPAIRED LOCALLY: authenticated legacy evidence is retained for reconciliation, with no direct debit |
| Production rollout and provider-account behavior | Read-only catalog, no live calls | UNVERIFIED / PENDING: Task 13 API and columns absent live; provider smoke checks remain required |

The read-only project check found migration maximum `20261016205533`, no Task 7
`20261016020000`, Task 4 `20261017100000`, or Task 13 migration versions, and no
`prepare_budgeted_media_call` API. Live `finish_media_call` is service-only but
still calculates unrounded-increment, four-decimal elapsed cost and has a legacy
direct-debit fallback. Its current grant is not the duration repair. The existing
media-session column shape matches the fixture dependency. Four call records
have nonterminal statuses; zero active call-budget holds were returned. These
aggregate counts do not prove four active provider calls or historical loss.
Fresh Edge source parity was not inspected in this task. Deployment of related
repairs must not be inferred from local tests or migration filenames.

## Implemented contract

`20261017203115_call_budget_contract.sql` is CLI-generated, forward-only and
leaves historical calls at version 0. Service-only creation serializes on the
payer's wallet and atomically re-reads the server tariff, claims an owned,
unexpired media session, creates the call, reserves funded USD cents, and saves
rate, connection fee, increment, hold identity, budget and maximum duration.
The caller cannot supply the tariff or budget. Replays adopt the existing call
before rechecking current rates, available money or audio expiry. Keys bind the
destination, caller and optional SIM line. Concurrent distinct calls must obtain
distinct funded allocations; a duplicate key cannot create another call.

Initial authorization is at most 300 seconds, shortened to what available funds
can cover. Provider limits below the conservative 30-second floor are rejected.
No extension API exists. Both admission and settlement calculate:

`round(connection_fee + ceil(seconds / increment) * increment * rate / 60, 2)`

An unanswered call costs zero, including no connection fee. A confirmed
subsecond bridge uses one second before increment rounding. Current authoritative
pricing returns a zero connection fee (the existing C12 rule); nonzero-fee and
increment boundaries are covered by the same pricing function. Funds and ledger
remain in cents; rounding occurs once after applying the increment and fee.

Each leg requires a committed submission marker before its provider request.
Markers are never reset after a timeout. The destination receives the saved
`max_duration_seconds`; it never reads posted wallet funds. The app SIP leg has
a bounded additional 60 seconds for setup. It cannot create a second destination.
Resources returned by HTTP and callback paths use the same binding validation.
Late command responses cannot downgrade a connected/terminal call to ringing.
The dedicated app credential connection must continue to prohibit direct PSTN.

Authenticated provider evidence is committed separately from the financial
attempt. App hangup requests closure and waits for destination termination when
the destination was submitted. A hangup delivered before its bridge retains
money; the later destination bridge retries settlement using the original stored
end time. Definitive unanswered rejection/no-answer evidence releases once.
An ambiguous normal hangup without bridge evidence retains the hold. Missing
provider timestamps cannot become a fabricated duration. A failed hangup or
settlement returns an error for callback retry and records a reconciliation state.

Finalization locks wallet, call and hold in a consistent order and commits the
call result with its ledger/funding movement. It validates the exact hold owner,
wallet, currency, call reference, version, amount and current allocations. The
existing settlement cap remains. `total_cost_usd` is the money actually collected;
`observed_cost_usd` retains the tariff calculation. A provider duration/cost
overrun charges at most the reservation and records `provider_duration_overrun`.
No fallback debits another operation's money. Legacy contracts require review.
All new mutation functions have explicit service ACLs, safe search paths and
caller-role guards; finish remains an invoker function with a service-only ACL.

All three shipped call-media copies are identical and a parity test guards them.
The retail client adopts the accepted tariff and estimates using its fee and
increment; the settled server total remains authoritative. Existing response
fields remain compatible and the additional budget fields are additive. No
corresponding admin calling model/controller exists; no admin code was changed.

## Verification actually run

- Shared production-shaped financial suite: **107 passed, 0 failed**.
- Native PostgreSQL independent-session suite: **138 passed, 0 failed**, including
  simultaneous distinct calls, duplicate preparation/submission/settlement and
  cancellation racing submission. These counts overlap the shared suite.
- Real isolated PostgREST 16.4: **13 passed, 0 failed**, including two call-specific
  named RPC, role-denial and settlement scenarios. Void RPCs correctly return 204.
- Edge/provider/signature regressions: **62 passed, 0 failed** across
  `call_budget_endpoint`, `call_media_backend`, `endpoint_webhook_auth` and
  `provider_secrets`. Actual handlers execute against synthetic adapters.
- Focused Flutter calling tests: **12 passed**. Focused analysis: **no issues**.
- TypeScript no-emit check passed for both Edge entrypoints and their imports,
  using the existing test-only Deno/import declarations. Formatting and diff
  whitespace checks passed.

The bounded fixture keeps the captured financial CHECK/NOT NULL/FK contracts,
RLS/grants, real financial functions/triggers and ledger types. It additionally
loads the real existing `call_media_sessions` DDL from retained applied history;
that table was outside the original financial snapshot. The rest of Supabase,
Auth HTTP, realtime and Telnyx remain outside this isolated DB fixture. There
were no provider/network calls from these tests. SQL result reports are retained
in `call-budget-billing-results-20261018.json`.

## Coordinated release and recovery

1. Separately authorize the coordinated financial release. Tasks 4 and 7 are
   prerequisites and are absent from live history under their proposed versions.
   Include the reviewed wallet/recovery dependency chain used by this fixture;
   do not apply the entire active migration directory blindly.
2. Pause new outgoing calls. Run `supabase/verification/call_budget_preflight.sql`;
   inspect actual live definitions, grants, funding preflight and migration drift.
   Reconcile/drain legacy nonterminal calls against the provider. Do not fabricate
   version-1 snapshots or fund them using customer balances.
3. Apply the reviewed dependency migrations and this forward migration. Run the
   read-only `supabase/tests/call_budget_contract_tests.sql` (empty result is
   success), refresh the PostgREST schema cache and verify named service RPCs and
   customer denial. Do not deploy this migration while the old dialer remains
   active: its separately created records/holds are deliberately version 0.
4. Replace `make-call` and `telnyx-cdr` together, including both local call-media
   bundles, media-events, and Task 4 signature/receipt handling. Retain provider
   webhook signature configuration and canonical URL/account bindings. Release
   the matching retail client estimate change. Keep old media calls paused.
5. In a separately approved provider test scope, verify the actual account accepts
   the duration limits, destination bridge/termination payloads and connection
   settings, and that the provider terminates at the saved funded limit. Confirm
   timeout/retry, no-answer and an increment boundary through the full call path.
   Only then reopen outgoing calls and monitor budget overruns and unresolved
   billing states. Local tests do not certify any of these live checks.

Recovery must use provider evidence rather than age. For a version-1 call with
stored destination terminal evidence and a valid bridge or definitive unanswered
outcome, a trusted operator may replay `finish_media_call` using exactly its
stored `destination_ended_at`, `destination_terminal_status` and
`destination_terminal_payload`, after fixing the identified infrastructure issue.
It will capture/release once. A still-pending or unknown submitted leg must be
looked up and terminated through its recorded resource. Never clear submission
markers or re-dial from a timer; Telnyx command deduplication lasts only 60 seconds.
If no resource was returned, correlate the original command with the provider;
missing local evidence is not proof of non-submission. Calls whose app submission
never began can be safely cancelled through `request_media_call_termination`.
Unresolved legacy calls, conflicting evidence, unexplained funding failures and
overruns need explicit operator reconciliation. Do not release on hold expiry.
Rollback means pause dialing and fix forward while retaining the new callbacks,
snapshots and evidence until all accepted calls settle; do not restore the old
unreserved debit path.

The provider behavior assumptions were checked against [Telnyx's official SDK
contract](https://github.com/team-telnyx/telnyx-node/blob/master/src/resources/calls/calls.ts)
(`time_limit_secs` terminates a leg after answer) and its [webhook delivery
rules](https://developers.telnyx.com/docs/voice/programmable-voice/receiving-webhooks)
(duplicate, concurrent and out-of-order delivery; command deduplication window).
The shorter app/setup envelope and 300-second initial call policy are local
conservative choices, not a claim about observed production termination.

## Next task

Task 13's local acceptance checks are satisfied. Production acceptance remains
pending the separately authorized coordinated release and provider checks above.
Task 14 is independent and may be implemented next; this task did not start it.
