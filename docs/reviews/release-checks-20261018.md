# Task 24 — test repairs and release checks

2026-10-18, Asia/Muscat. **TEST REPAIRS IMPLEMENTED LOCALLY; CLEAN RELEASE GATE
STILL BLOCKED. Nothing deployed or financially activated.**

The task's test failures are repaired. Its acceptance condition that every required
release gate passes has **not** been met. Task 25's activation prerequisites remain
unsatisfied. Existing work in all three repositories was preserved. Fleet/source/
rollout preparation changed concurrently; the final suites include the resulting
fleet contracts rather than claiming the initial snapshot still applies.

## Findings and repairs

| Finding | Status and evidence |
| --- | --- |
| Customer full suite initially 879 passing / 11 failures | REPAIRED LOCALLY. Final full suite: **893 passing / 0 failures**. A previously uncompilable file contributes four tests once it compiles. |
| Removed Premium pricing methods referenced by checkout tests | STALE contract assumptions, corrected locally. Tests consume a validated server quote; no retired client pricing or authorization was restored. Native pricing/setup acceptance still passes. |
| Currency-symbol fixture disagreed with its own expectations | REPAIRED LOCALLY. The fixture supplies `E£` consistently; production conversion/rounding was not changed. |
| Upgrade and onboarding currency tests assumed a local Premium estimate | STALE assumptions. The widget test supplies the current quote provider. Without a Premium quote, only the actual Standard amount has a local conversion; checkout continues to fetch an authoritative quote. |
| Call-controller disposal reads notifier state during `onDispose` | OPEN IN INITIAL SOURCE; REPAIRED LOCALLY. A notifier listener retains the cleanup call ID while state is usable; disposal cancels native event listening before asynchronous cleanup. Both biometric widget regressions now pass without masking exceptions. |
| Notification readiness/editor test expected obsolete email setup | STALE assumptions. It now asserts the shared preference status, retains the account address, requires confirmation for its unauthenticated fixture, and waits for the bounded status lookup before closing. HTTP and platform storage are isolated. |
| Credential-rotation tests predate newer webhook/payment/DID contracts | REPAIRED LOCALLY. Fixtures supply the complete signature envelope/event/merchant, verified-event claim/finish RPCs, pilot allowlist and settled commerce tier. Old-token rejection, Vault outage and no-provider-write assertions remain. |
| Native DID tests require an optional cache override despite installed dependencies | REPAIRED LOCALLY. Native mode falls back to the installed locked package; its 19 scenarios, including separate-session renewal races, pass without the override. |
| Synthetic maintenance credentials and function digest flagged by scanner | REPAIRED LOCALLY. Synthetic credentials use explicit test placeholders; only structurally identified function SHA-256 metadata is exempted from assignment matching. Provider-key signatures remain unconditional. Regression tests prove digest-looking credentials outside that structure and provider-shaped literals still fail. |
| Admin analyzer excluded all tests and all SIM-line source | OPEN IN CURRENT SOURCE after removing those exclusions. Full analysis exposes **53 errors** in copied customer UI referencing absent household/wallet/schedule/payment-simulator modules. They were not recreated as unauthorized financial paths or hidden again. |

Mechanical analyzer fixes remove obsolete imports/dead declarations and migrate
supported widget APIs without blanket dependency upgrades. Cache writes now await
inside their `try` so asynchronous storage errors reach the existing failure
handler. Async loading uses Riverpod's public state setter, which carries prior
data, rather than calling an internal method. Admin declares its already locked
`collection` dependency directly. The existing review-only VoIP probe's mock now
returns its required subscription result; those historical behavioral probes are
not part of the normal Flutter test suite and are not claimed to pass.

## Actual verification

Saved results and logs: [release evidence](release-checks-20261018/summary.json).
Counts are scenario/test counts, not unique assertions. SQL scenarios repeat
across sequential/native/API modes and must not be added into a unique total.

| Check | Actual result |
| --- | --- |
| Customer full Flutter tests | **893 passed**, no skipped failures |
| Admin full Flutter tests, including fleet panel | **32 passed** |
| Edge contract adapters | **232 passed**, no skipped/todo tests |
| Authoritative worker suite | **206 passed**, no skipped/todo tests; syntax checks pass |
| Database release profile | **20 suites passed**: production-shaped financial fixture, sequential contracts, native concurrency, credentials, privileges, payment/webhook retries, notification/forecast/maintenance, DID/pricing/retail/schedule/voucher/fleet/source recovery and real localhost PostgREST |
| Native money concurrency | **138 blocks passed**; separate sessions, service-role money RPC races and submission/settlement crash boundaries |
| Native pricing/setup acceptance | **40 scenarios passed**, including setup/fallback and upgrade races |
| Real localhost API | Worker/recovery/liveness API suite **13 passed**; schedule suite includes **7 HTTP cases** within its **36 scenarios**. Named/defaulted calls, overload rejection, anonymous/foreign-role denial and protected financial fields are covered. |
| Strict customer analysis | **FAIL: 33 info diagnostics**, zero errors/warnings; default fatal-info behavior retained |
| Strict admin analysis | **FAIL: 196 diagnostics**, including 53 errors in previously excluded copies |
| Customer Android release bundle | **BLOCKED/FAIL** at the existing signing guard: `android/key.properties` absent. No debug signing bypass used. |
| Customer iOS release compilation | **PASS** with `--no-codesign`: `Runner.app`, approximately 66.9 MB. This is not an archive, signature, entitlement or distribution certification. |
| Admin macOS release compilation | **PASS**, approximately 63.4 MB. Distribution/notarization not certified. |
| Admin web release compilation | **PASS** |
| Active-source secret scan | **PASS**, zero active findings; one known archived credential-shaped literal remains inventoried, without printing its value |
| Archive and deployment/source manifests | Verified after refreshing the reviewed working-tree snapshot; complete platform provisioning and deployment evidence remain separately blocked |
| Edge runtime check | **BLOCKED/FAIL**: local Deno is unavailable and reviewed per-function `deno.lock` files are absent. Node handler adapters are not Deno deployment evidence. |
| Remote CI/provider sandbox/live smoke | **UNVERIFIED**. Workflow files were parsed locally; no hosted CI run, provider call or production mutation occurred. |

The iOS build refreshed CocoaPods project metadata and aligned the Sentry Cocoa
Swift-package resolution to the plugin required by the existing Dart lock. This
was a build reconciliation, not a blanket dependency update. Both Dart lockfiles
remain enforced by the runner. Missing signing material was not invented.

## Repeatable checks and CI

[Toolchain pins](../../deployment/release-toolchains.json) select Flutter 3.47.7
at its exact framework revision, Dart 3.13.5 and Node 26.11.1. Database dependencies
are installed with the committed npm lock. Local Python 3.9.6 is recorded;
CI selects Python 3.12.8, with a Python 3.9 minimum for the standard-library runner.
Deno 2.5.6 is a candidate check-tool pin, not a claim of local or Supabase runtime
verification. macOS 27.0.1 was observed locally; CI uses `macos-15`. OS images,
Xcode/CocoaPods/JDK/Android SDK and installed VM runtime equivalence remain open
platform reproducibility obligations.

Run from the customer root, with a **new** evidence directory for each run:

```sh
npm ci --prefix tools/financial-tests
python3 tools/release_checks.py source --output /private/tmp/release-source
python3 tools/release_checks.py unit --output /private/tmp/release-unit
POSTGREST_BINARY=/absolute/path/to/verified/postgrest \
  python3 tools/release_checks.py database --output /private/tmp/release-database
python3 tools/release_checks.py apps --output /private/tmp/release-apps
python3 tools/release_checks.py builds --output /private/tmp/release-builds
python3 tools/release_checks.py edge-runtime --output /private/tmp/release-edge
```

On macOS, supply `POSTGREST_LIBRARY_PATH` for the embedded PostgreSQL `native/lib`
directory when required. It is scoped only to PostgREST, not Node/initdb. The
[installer](../../tools/install_release_postgrest.py) downloads an official 16.4
archive selected by OS/architecture and verifies its committed SHA-256 before
writing the executable. A mismatch, unsafe archive or existing output fails.

`release_checks.py release` selects all profiles plus the deployment-evidence
check. Toolchain mismatch, absent companion source, missing API executable,
missing Edge locks, command failure or timeout is a failure, not a skip. Each
selected command records its exit code, log digest and duration; independent
checks continue after failures. A profile pass never grants rollout approval.

[The workflow](../../.github/workflows/release-checks.yml) runs source/security,
unit, database, strict app analysis/tests, Edge runtime checks and compilation.
Companion repositories are checked out at exact recorded SHA values, with
credentials not persisted. Private companion access requires a read-only
`RELEASE_SOURCE_READ_TOKEN` repository secret. No environment/provider secret or
deployment capability is passed to tests. The Android signing guard remains a
required failure until signing is provisioned in a separately scoped protected
release process. No job is allowed to ignore a failure for release readiness.

The source lock currently records **dirty working-tree bytes**, not remotely
fetchable repaired commits. The deterministic bundle preserves those bytes.
Hosted CI fetching older companion SHAs will correctly fail source consistency
until all intended changes are committed, the companion pins updated and the
source lock reviewed/refreshed. Workflow installation, private-repository access
and branch protection still need an actual hosted run; local YAML parsing is not
proof of them.

The source bundle excludes environments/signing keys/dependency caches and
unrequired historical SQL. It is a test-source snapshot, not a complete Supabase
baseline or credential backup. Before adding dependencies to an isolated bundle
checkout, verify it with Task 22's `--checkout` procedure; then run the unit,
database and app profiles using the sibling layout and pinned dependencies.
The source/security profile expects Git working copies for its tracked-file scan.

## Release obligations and next-task readiness

**Task 24 remains incomplete as a clean release gate.** Resolve the customer
analysis advisories and admin copied-source errors without disabling diagnostics;
provision and verify actual signed release artifacts; lock/check the Edge import
graph; prove hosted CI against committed versions; and satisfy Task 22's complete
clean/upgrade, managed-platform/configuration and runtime source parity gates.
The known archived credential inventory still requires its separately scoped
revocation/history treatment; an active-source pass is not a history-clean claim.

Task 23's local fleet evidence is now exercised in this gate, but deployed fleet
health/version proof is not established here. Controlled provider sandbox and
live smoke evidence remain absent. Customer balances were not repaired, supplier
spend was not attempted, and no migrations, Edge functions or workers were
deployed/restarted. **Task 25 rollout/activation prerequisites are not satisfied.**

CI structure follows [GitHub workflow documentation](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows).
Edge dependency checks follow [Supabase dependency guidance](https://supabase.com/docs/guides/functions/dependencies)
and [Deno check documentation](https://docs.deno.com/runtime/reference/cli/check/).
