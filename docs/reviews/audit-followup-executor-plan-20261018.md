# Remaining audit work — sequential executor tasks

Based on the [October 18 implementation review](audit-implementation-rereview-20261018.md).
Run one task at a time and return its evidence before beginning the next.

The current financial, Edge-adapter and worker functional suites pass. Preserve
those repairs and production-shaped constraints. Existing user changes in all
three repositories must be preserved. This plan is not deployment, credential,
provider-spend, account-deletion or customer-balance-repair authorization.

## 1. Prepare urgent independent security containment

Priority: P1. Original Tasks 3–4; preparation can proceed before the broad rollout.

Refresh effective grants and the existing-body guards for the separate Task 3
migration. Validate its full explicit allowlist, table/default privileges and
required customer/admin/service/postgres cron callers against the current live
catalog. The October 18 review found the six guarded bodies still match, but
anonymous execution of the unsafe text finalizer, legacy confirmation, reaper
and scheduled-health helper remains live. Read-only verification is permitted;
production destructive permission tests are not part of this work.

Prepare the exact narrow migration/recovery evidence and proposed release scope.
For endpoint containment, identify legitimate voicemail producers and provider
signing configuration before changing gateway/authentication behavior. Retain the
compatible RPC/schema dependencies. Use the existing fixes rather than a competing
authorization layer. Request explicit deployment approval only after the exact
candidate is reviewable; apply it only if that approval is supplied.

Acceptance: deny/allow tests pass, original-body and dependency guards hold,
required cron/admin flows remain available, and production status is explicitly
recorded as either verified deployed or still pending. No provider spend or
credential rotation is included.

## 2. Repair the remaining application analysis failures

Priority: P1. Original Task 24.

Start from the retained analyzer logs. Resolve the admin's 53 errors, 19 warnings
and 124 information diagnostics. Trace the SIM-line controller/screens/widgets
that import missing schedule, household, wallet and subscription modules; connect
them to the intended admin architecture or retire proven unreachable copies with
their callers. Preserve the server-side financial and admin-claim boundaries.
Resolve the customer's 33 information diagnostics under the existing strict gate.

Acceptance: full `flutter analyze --no-pub` passes in both repositories, with no
blanket exclusions/fatality reductions; full customer/admin tests still pass.
Retired client pricing/payment simulation must not return as a shortcut.

## 3. Make the verification pipeline deterministic and complete

Priority: P2. Original Tasks 21–24; concrete new findings from this review.

Fix `tools/financial-tests/vouchers.mjs` so routine verification does not rewrite
the locked `offline_voucher_state_payloads.json` with a random grant ID. Seed a
stable synthetic grant identity and/or separate explicit fixture regeneration
from verification. Keep the Dart tests consuming the actual supported projection.

Add native fleet execution to `tools/release_checks.py` and its regression tests.
Require the independent-session sweep race in `fleet.mjs` to execute in the
database/release profile. The reviewed default ran 49 scenarios; explicit native
mode ran 50 and passed. Missing native prerequisites must fail the required check.

Add an end-of-pipeline source-consistency check. Run source → unit/database/apps
→ source verification on an isolated frozen checkout and prove the bytes remain
unchanged. Preserve generated visual review artifacts during local verification.

Acceptance: the same candidate remains hash-identical after all profiles, and
required native fleet evidence is present in local and hosted release results.

## 4. Close Windows authentication and target coverage

Priority: P2. Original Mac/admin work and Task 24 platform acceptance.

The Windows admin Google path currently reaches the native `google_sign_in`
plugin, which has no Windows implementation in the locked version. Retain the
working macOS authentication-session flow and implement the intended Windows
desktop OAuth callback/PKCE session path, or obtain an explicit supported-target
decision before dropping the Windows-first requirement. Use public OAuth client
identifiers only in clients; preserve the backend's trusted power-user checks.

Acceptance: actual Windows and Mac sign-in, return-to-app, cancellation/retry and
ordinary-versus-admin behavior are verified on their target systems. Required
Windows compilation/runtime checks appear in the supported-target release matrix.

## 5. Prove the complete database upgrade and clean baseline

Priority: P1 release blocker. Original Tasks 6 and 22.

Keep the now-passing production-shaped subsystem tests, including their CHECKs,
triggers, grants and independent money races. Add a complete ordered upgrade test
for the entire selected release against the actual current shape, covering the
Task 3 containment order and later replacements together. Include managed-platform
dependency contracts, owners/default grants, cron exclusion and required effective
configuration, rather than filling gaps with permissive stubs.

Produce and validate the supported fresh provisioning path with separately
provisioned secrets. Document irretrievable original history honestly and compare
current contracts; archive replay or fabricated migration history is not a baseline.
Use isolated infrastructure for migrations/data-changing tests; live review stays
read-only until its scoped release is authorized.

Acceptance: complete current-shape upgrade and supported clean provisioning both
pass with reviewed omissions made explicit, then all subsystem/API/concurrency
regressions pass on the resulting combined schema.

## 6. Verify Edge imports, runtime dependencies and actual release builds

Priority: P1 release blocker. Original Tasks 22–24.

Install the approved Deno check tool and review/pin the actual per-function import
graphs. Supply frozen dependency locks and pass the real Edge runtime/type checks.
Resolve the null desired gateway modes for `get-turn-credentials` and
`validate-sim-liveness` from their intended callers. Preserve Firsty/recovery's
disabled/deferred scope. Verify the worker package installation and tests under
the supported deployed Node runtime; current VM Node 22.23.1 differs from the
Node 26.11.1 local test toolchain.

Provision signing through the approved private release process. Verify supported
customer/admin target artifacts, actual entitlements/signatures, and distribution
requirements. Rebuild the Mac ZIP with the reproducible packaging script after
the source freeze; its current executable/framework hashes differ from the local
build. Record artifact digest, source lock and supported client/contract versions.

Acceptance: frozen Edge checks, clean installed-runtime checks, supported platform
build/signing checks and artifact/source comparisons pass. Source compilation is
recorded separately from distribution signing/notarization.

## 7. Freeze a reproducible successor candidate and prove hosted CI

Priority: P1 release blocker. Original Tasks 22, 24 and 25.

Review and commit the intended repairs in all three repositories while preserving
unrelated user work. Pin fetchable companion revisions, rebuild the source lock
and deterministic bundle, and verify an isolated checkout. Run hosted CI with the
required read-only companion checkout access and retain its actual results.

Issue a successor coordinated manifest/runbook/envelope for that exact source.
The current candidate fails six pins even though the newer base source gate
passes. Update obsolete Task 23/24 dependency evidence as reviewed facts; retain
old candidates for comparison. A hash-only refresh is not a substitute for
reviewing changed sources and rerunning the full combined gate.

Acceptance: committed checkout, retained bundle, source lock, complete migration
order, runtime files, artifact digests, CI evidence and candidate digest all agree.

## 8. Prepare evidence-based operational reconciliation and credential cutover

Priority: P1 before financial activation. Original Tasks 2, 7–13, 17 and 23.

Refresh aggregate diagnostics under a role that can see the relevant rows. The
October 18 review found one signed-ledger difference and one expired legacy
`plan_fee` hold; neither is permission to overwrite balances or release funds.
Privately identify their opening balance, original payment/debit/allocation and
supplier evidence, and propose bounded dispositions with operator ownership.
Retain unresolved uncertainty behind a proven exclusion. Payout/submission
timeouts must not authorize duplicate external actions.

Complete the provider/account/environment and consumer inventory, including
legacy environment/plaintext readers, webhook validators, VM workers and Coturn.
The credential registry has no recorded replacement/completion evidence. Prepare
the exact transition to protected Vault values, compatible consumers, recovery
checks and old-key revocation; keep actual changes under separately scoped
authorization. Include the required supplier-reconciliation process and full
fleet instrumentation in the compatible runtime package.

Acceptance: each legacy case and exposed credential has evidence, an accountable
owner and a reviewed disposition. Real provider operations occur only within
explicitly approved accounts/actions/exposure limits, and no uncertain funds or
submissions are classified safe from expiry or an old false marker alone.

## 9. Perform the coordinated rollout only when its prerequisites and approval exist

Priority: release execution. Original Task 25.

Use the corrected frozen runbook, after the preceding acceptance checks pass.
Obtain authorization for the exact candidate digest, targets, operators, window,
pauses/restarts, permitted provider accounts/actions and exposure limits. Prove
backups/restore recovery, per-entry financial containment, in-flight drain and
exclusion of newly installed cron during intermediate commits.

Deploy only the approved SQL/Edge/worker/client set with the existing direct VM
copy/hash/syntax procedure. Preserve private configuration and message/session
state. Verify live grants/definitions, callback authentication, source/runtime
parity, completed forecast jobs, supplier reconciliation, lane/backlog/cron health
and supported client contracts. Use the scoped pilot and observation/abort limits
before expansion. Credential migration `20261016205533` is already applied.

Acceptance: retained deployment and non-spending/scoped pilot evidence establish
the exact live release. Keep any unresolved operator cases explicitly quarantined;
mark the audit closed only for findings whose deployed behavior is verified.
