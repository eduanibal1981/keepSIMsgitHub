# Review of the 25 audit tasks

Reviewed 2026-10-18, Asia/Muscat. This is an implementation and release review,
not authorization to deploy or operate providers.

## Opinion

The repairs are substantial and the current local functional suites pass. I
would accept much of Tasks 3–21 as **locally implemented**, with the documented
fixture and provider limits. I would not mark the whole audit complete or approve
the current rollout candidate. Tasks 22 and 24 have unmet acceptance conditions;
Task 25 is preparation rather than an executed rollout. Most repaired production
surfaces still run their older versions.

This review found additional issues in the release tests, Windows authentication
coverage and the packaged Mac artifact. These are listed separately from the
already documented deployment prerequisites so an executor does not repeat fixes
that have already passed their local contract tests.

Production access was read-only: project/catalog/cron metadata, selected deployed
Edge source and aggregate accounting diagnostics, plus sanitized SSH process,
version and file-hash checks. No migration, provider request, key rotation,
customer balance repair, worker restart or destructive live test was performed.
Local tests used synthetic data and disposable databases. A test-generated
fixture and generated visual artifacts were restored to their original bytes.

Evidence: [verification summary](audit-rereview-20261018/verification-summary.json),
[live catalog and deployment facts](audit-rereview-20261018/live-verification.json),
[worker inventory](audit-rereview-20261018/vm-workers.json),
[ordered follow-up tasks](audit-followup-executor-plan-20261018.md).

## Findings that still need work

### 1. P1 — urgent security repairs remain absent from production

The live database still gives anonymous EXECUTE to
`finalize_sim_setup_order(uuid,text)`, `confirm_line_verification(uuid,text,text)`,
`reap_stuck_executions(integer,integer)` and `check_scheduled_jobs_health()`.
The raw pruning helper remains authenticated-callable. These are precisely the
boundaries Task 3 is intended to restrict. EXECUTE alone is not proof every
function is exploitable; the unsafe finalizer and self-verification semantics
were established by the source/contract reviews. No exploit was attempted here.

Fresh source retrieval also confirms that production still has:

- `process-voicemail` v2, gateway JWT disabled, checking header presence before
  using a supplied user ID for privileged work.
- `liveness-verification-webhook` v6, gateway JWT disabled, with no provider
  signature-verification references in its entrypoint.
- `capture-paypal-order` v5, including `captureObj?.id || orderId` at deployed
  source line 221. The v11 webhook uses the capture identity; neither entrypoint
  uses the new atomic fulfillment contract. The duplicate-credit repair is local.

Live history contains **239 migrations**, with only `admin_provider_credentials`
(`20261016205533`) from the audit-era release. Task 3's six existing-body guards
still match the allowed live bodies; this supports preparing its independent
containment release, not bypassing its remaining release checks or approval.
Broad financial rollout should not be the only route to urgent containment.

### 2. P1 — the application release gates are still red

Fresh full analysis reports:

| App | Errors | Warnings | Info |
| --- | ---: | ---: | ---: |
| Customer | 0 | 0 | 33 |
| Admin | 53 | 19 | 124 |

The admin errors include missing scheduled-topup, household, wallet and other
modules referenced by copied SIM-line screens/controllers. For example,
`keep_sims_admin/lib/features/sim_lines/presentation/controllers/sim_line_detail_controller.dart:6`
imports a missing controller. A tree-shaken build of the selected app routes can
compile while full source analysis fails. Passing widget tests do not close this.
Keep the analysis exclusions removed; resolve actual reachability/contracts
instead of suppressing the errors or rebuilding retired client-side money paths.

The customer diagnostics fail the existing fatal-info gate even though there are
no customer errors or warnings. Both sets require resolution before a clean gate
claim. Full logs are retained in the evidence directory.

### 3. P2 — the database test profile changes the locked source

`tools/financial-tests/vouchers.mjs:64` creates a grant without a fixed fixture ID,
and line 100 overwrites `test/fixtures/offline_voucher_state_payloads.json` after
each successful run. The generated grant ID therefore changes on each run.

Reproduced sequence: source profile passed; all 20 database suites passed;
`reproducible_sources.py verify` then failed on that fixture. The only changed
JSON field was `revealed.lines[0].grant.id`. The expected SHA-256 was
`21078d07…4815a1`; the fresh generated file was `19570709…397b91`.
[Exact digests and mutation evidence](audit-rereview-20261018/fixture-mutation.json)
are retained. I restored the exact locked original from the verified source
bundle and reran source verification successfully.

Use deterministic fixture identities or make regeneration an explicit operation
that writes to a separate output. Normal verification must not rewrite locked
inputs. Verify source consistency again after all release checks, not only in a
parallel source job before tests mutate files.

### 4. P2 — CI silently omits the fleet's independent-session race

`tools/release_checks.py:51` enables native DID and pricing modes but does not
enable `FLEET_NATIVE`. `tools/financial-tests/fleet.mjs:230` runs the independent
sweep race only when its native server exists. The normal database profile
therefore reports **49 passing** fleet scenarios and does not run that race.

I explicitly ran native fleet mode: **50 passed**, including two independent
PostgreSQL sessions. The SQL is not shown broken by this result; the missing
required CI invocation is the defect. Add the native fleet mode to the release
profile and assert the required scenario/environment in release-tool tests so it
cannot silently disappear while the profile stays green.

### 5. P2 — Windows Google login still has no supported implementation path

The Mac-specific repair works through `ASWebAuthenticationSession`. Windows
falls through `keep_sims_admin/lib/features/auth/repository/auth_repository.dart:76`
to `GoogleSignIn.initialize()` / `authenticate()`. The locked `google_sign_in`
7.2.0 platform manifest provides Android, iOS, macOS and web implementations,
with no Windows implementation; no Windows replacement is registered here.

This is a source-confirmed unsupported path, not a Windows runtime test. Because
the admin app was described as Windows-first, support cannot be inferred from
the Mac/web builds. Implement and validate a Windows desktop OAuth path or
explicitly revise the supported-target scope. Preserve cryptographic session
verification and the backend admin claim boundary.

### 6. P2 — the downloadable Mac ZIP is older than the current tested build

The current local `.app` passes deep/strict signature verification. However, both
its native executable and Dart `App.framework` hash differ from the files in
`KeepSIMs-Admin-macOS.zip`. The ZIP was last modified at 2026-10-16 20:38 UTC
(2026-10-17 00:38 Asia/Muscat), before the October 18 fleet/release changes.

This does not show that the older Google-login fix failed. It shows that the
existing download cannot stand in for the current tested source. Once remaining
source issues are fixed and frozen, rebuild/package from that exact source,
verify embedded code and archive hashes, and record which source and contract
versions the distributed artifact contains. Developer ID/notarization and
customer signing remain separate incomplete release requirements.

### 7. P1 release blocker — the complete upgrade and runtime release are unproven

All 20 database suites passed, including production-shaped constraints, native
money races and local HTTP RPC calls. They bootstrap bounded, separate subsystem
fixtures. They do not apply the complete 26-file coordinated release together
against a complete copy of the current platform shape, nor establish clean
Auth/Storage/Vault/net/cron provisioning.

The current base deployment evidence gate still reports missing complete-baseline,
complete-upgrade, configuration/cron seed, ownership/history, Edge and installed
runtime proof. The historical 23 remote-only statements remain a reported gap;
do not fabricate their history or blindly replay archived SQL.

The coordinated candidate additionally fails its current hash check for six
pins: `server_baileys.js`, `worker_esim_catalog.js`, `deployment/manifest.json`,
`deployment/source-lock.json`, the fleet migration and `tools/release_checks.py`.
The newer base source check can pass while the older rollout envelope is stale.
Review and issue a successor candidate after fixes; do not just update hashes
to make an obsolete approval appear current.

Other concrete release gaps remain:

- No per-function `deno.lock` files; the Edge runtime profile fails because Deno
  is unavailable. Node handler adapters do not verify Deno imports/runtime.
- Desired gateway settings remain null for `get-turn-credentials` and
  `validate-sim-liveness` in the base manifest.
- Customer Android signing material is absent. Existing iOS compilation without
  codesigning is not a signed distribution artifact.
- Companion repository pins refer to committed HEADs while the repaired source
  lock includes dirty working-tree bytes. Hosted checkout of those HEADs cannot
  reconstruct those uncommitted repairs. Hosted CI acceptance is unverified.
- The VM uses Node 22.23.1; the local check toolchain uses Node 26.11.1. Package
  hashes and selected installed versions were read, but full supported-runtime
  and clean dependency-install equivalence are not established.

### 8. P1 operational gap — recovery, credential cutover and reconciliation remain

Eight VM services are online. All three checked refill worker hashes differ from
the repaired local sources. `worker_supplier_reconciliation.js`, `worker_health.js`
and `worker-fleet.json` are absent at the intended server paths. The new fleet
database APIs are also undeployed. PM2 online status and the old health endpoint
do not prove completion of required work or reconciliation.

The credential backend has 13 registry entries, **zero recorded replacements**
and **zero operator-confirmed versions**. This does not prove no provider owner
rotated anything externally; it means the new workflow contains no cutover or
revocation evidence. The source scan passes, but the known archived exposure
and existing deployed/binary/config copies still need their scoped disposition.

Fresh aggregate diagnostics report one wallet-versus-signed-ledger difference and
one expired active `plan_fee` hold. The sampled metrics show no wallet/funding-lot
or allocation mismatch and no nonterminal refund items. These are different
invariants. The ledger difference is not proof of customer loss; the expired
legacy hold's false submission flag is not proof it is safe to release. Preserve
them for evidence-based operator reconciliation rather than inventing balances
or funding. The usage-forecast cron also failed on 2026-10-18 at 06:20 Asia/Muscat
because the old function references a missing eSIM relation.

## Status of every requested step

“Local pass” means the reviewed implementation and applicable bounded tests pass;
it does not mean provider behavior, complete platform integration or deployment
has been certified. The later accounting repairs supersede Task 6's historical
red tests; those old failures are not being reported as current code failures.

| Step | Local implementation / evidence | What remains |
| ---: | --- | --- |
| 1 | Baseline and finding register implemented; live identity, history, selected grants/Edge sources, cron and VM refreshed here. | Complete runtime/configuration parity and closure evidence remain bounded/incomplete. |
| 2 | Source cleanup, scanning, Mac controls and credential APIs implemented; credential database release verified. | Matching consumer rollout, real Vault provisioning, external revocation and historical/build-copy disposition. |
| 3 | Privilege allowlist, unsafe-default/path containment and role tests pass locally. | Urgent independent production containment; unsafe effective grants remain. |
| 4 | Endpoint/service/ownership/signature/replay contracts pass locally. | Coordinated Edge/schema release and legitimate external caller/signature smoke checks. |
| 5 | Canonical PayPal capture adoption and atomic receipt/funding tests pass. | Old production capture/webhook paths remain; merchant configuration and scoped provider validation. |
| 6 | Production-shaped financial fixture and constraints now pass. | Complete platform/current-shape replay is a separate Task 22 obligation. |
| 7 | Funding, provenance, signed transactions and concurrency regressions pass. | Matching release; disposition of the one historical signed-ledger difference. |
| 8 | Atomic refund claims/settlement and ambiguous-outcome regressions pass. | Coordinated processor/SQL replacement; approved provider recovery/smoke proof. |
| 9 | SIM setup/instant submission, reservation, finalization and settlement tests pass. | Matching SQL/worker/client cutover; current instant VM source differs. |
| 10 | Scheduled holds/worker RPCs and real local HTTP contracts pass. | Compatible worker/SQL release and legacy schedule/reservation dispositions. |
| 11 | Supplier reconciliation and conservative hold recovery implemented/tested. | Required reconciler absent on VM; legacy evidence and operational acceptance remain. |
| 12 | Provider-backed liveness and self-verification denial implemented/tested. | Legacy confirmation remains callable live; release and real provider callback checks. |
| 13 | Atomic call budget, duration and charge contracts pass locally. | Matching dialer/callback release, old call disposition and provider limits verification. |
| 14 | Notification SQL/scheduler cases pass with constrained fixtures. | Migration/caller release and actual channel-delivery smoke evidence. |
| 15 | Actual eSIM schema mapping/forecast tests pass locally. | Live cron still fails; targeted rollout and observed successful job run. |
| 16 | Maintenance, deletion jobs and audit rollback tests pass. | SQL/Edge release, dependency verification and separately scoped deletion acceptance. |
| 17 | DID purchase/renewal funding, ambiguity and pilot gates pass locally. | Disabled/pilot scope retained; provider recurring-liability and lifecycle acceptance. |
| 18 | Shared server pricing, upgrade credits and paid evidence tests pass. | Effective production policy/configuration, coordinated client/server deployment. |
| 19 | Retail projections, grants and owner checks pass locally. | Production wholesale/ownership exposure remains until migration/client release. |
| 20 | Validated schedule mutations and legacy queue retirement pass locally. | Production still has old contracts; accepted-price migration and old-client policy. |
| 21 | Open/terminal voucher state and client parsing pass. | Deploy state fix; also repair the nondeterministic fixture writer found here. |
| 22 | Archive/source tools and current source gate pass after fixture restoration. | Complete clean/upgrade proof, managed dependencies, seeds, runtime parity and committed reproducibility incomplete. |
| 23 | Fleet reporter/probes/UI implemented; explicit native review run 50/50. | Not deployed; reconciler/monitor absent live; native race missing from normal release profile. |
| 24 | Fresh functional suites pass. | Analysis remains red, Edge locks/runtime missing, Windows auth/target gap, signing/CI proof and current artifact packaging incomplete. |
| 25 | A blocked runbook/manifest/preflight is prepared. | Candidate hashes stale; restore/containment/reconciliation and scoped approval missing; rollout not executed. Deferring activation is appropriate. |

## Fresh verification and limits

| Check run during this review | Result |
| --- | --- |
| Source/archive/scanner/tool gate | Passed; post-database fixture mutation reproduced, original restored, source lock reverified. |
| Customer full Flutter suite | 893 passed. Existing generated visual review artifacts restored. |
| Admin full Flutter suite | 32 passed. |
| Edge adapter tests | 232 passed; no skipped/todo failures. |
| Authoritative worker tests and syntax | 218 passed; syntax checks passed. |
| Database profile | All 20 suites passed; native financial races and actual local PostgREST included. |
| Explicit native fleet follow-up | 50 passed; normal release profile ran 49. |
| Full app analysis | Customer failed: 33 info; admin failed: 53 errors, 19 warnings, 124 info. |
| Edge runtime profile | Failed; Deno unavailable and zero per-function locks. |
| Base deployment readiness gate | Blocked. |
| Coordinated rollout candidate hash gate | Failed on six stale pins. |
| Current Mac app deep/strict signature | Passed locally; distribution signing/notarization not certified. |
| Packaged ZIP versus current build | Both executable comparisons differ. |

Provider sandbox/live behavior, a full combined migration replay, signed target
releases, a hosted CI run and restored-platform recovery were not certified by
this review. No new release build was made. The follow-up plan identifies the
remaining work without authorizing production changes or provider spending.
