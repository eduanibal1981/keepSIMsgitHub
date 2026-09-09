# Current Status and Roadmap

## Executive assessment

KeepSIMs has substantial product and backend implementation: both clients are broad, the database has mature domain coverage, financial actions are mostly server-side, and provider/queue/idempotency work is more advanced than a prototype. It is **not ready for an unrestricted production money launch**. Security grant regression, a live alternate supplier-spend path, ledger/reconciliation ambiguity, deployment/source drift, fail-open webhooks, missing admin authorization UX, a failing provider safety test, and absent current release gates are blocking evidence.

Recommended posture: closed/internal testing with real-money/provider actions disabled or tightly allowlisted until P0 items close. Do not infer that every historical phase marked “complete” remains secure after later migrations.

## Intended vs current vs gap

| Area | Intended | Current implementation | Gap / direction |
|---|---|---|---|
| Client architecture | Uniform five-layer feature flow and typed failures | Hybrid legacy/new structures; direct Supabase in presentation/controllers; raw exceptions in newer features | Adopt intended dependency direction for new/touched code; refactor locally with tests. |
| System boundary | Customer and admin are clients of one trusted backend | Correct conceptually, but Dart code is copied and diverged | Define shared domain/schema contracts; do not merge UIs blindly. |
| Money safety | Only trusted atomic RPC/worker paths mutate/spend money | Most paths follow this; active `execute_zendit_recharge` bypasses wallet/queue; reconciliation is stale | Disable/redesign bypass and restore authoritative reconciliation. |
| Admin security | JWT power-user claim + server `assert_admin`; audited operations | RPC facade is strong; router gates only authentication; legacy direct table reads remain | Gate routes/queries by claim, refresh token after promotion, consolidate on audited APIs. |
| Database security | Explicit least-privilege grants and RLS | All public tables have RLS; grant regression and advisor errors remain | Rebuild current grant allowlist and negative tests. |
| Edge deployment | Local source/config reproduces live functions | Local-only and live-only functions; incomplete config; comments/plans disagree with live | Establish versioned deployment inventory and reconcile source. |
| Worker operations | Authoritative workers, idempotent provider calls, observable health | Authoritative worktree exists; PM2 config incomplete; health covers only one worker heartbeat; one test fails | Reconcile process manifest, implement fleet health, pass safety suites. |
| Offline rescue | Working endpoints and verified voucher supply | UI/backend schema exists; endpoint seeds and client fallback are placeholders; provider mapping unverified | Keep feature gated until endpoints, stock, instructions, and E2E recovery are proven. |
| Payments | PayPal funding plus production payment-method behavior | PayPal server flow exists; stored cards are mock tokens written by client | Hide/remove mock production surface or integrate a compliant vault/provider. |
| Calling | Preflight, verified caller IDs, signed CDRs, exact charging | Feature is live in source/runtime; no reservation; debit can exceed collectible balance; webhook can fail open | Add reservation/cap/partial-charge model and fail-closed signatures. |
| Release engineering | Repeatable analysis/tests/build/sign/deploy | No CI; stale baselines; admin template test broken; platform configs incomplete | Add deterministic CI/release gates and platform checklist. |

## What is implemented

`CONFIRMED` in source/runtime:

- Customer authentication/onboarding, profile, routing, localization, theming, offline cache, and biometric overlay.
- SIM-line CRUD/health/rules/liveness, schedules/executions, wallet/ledger, PayPal order/capture/webhook source, notifications, household, referrals, travel tools, eSIM, offline vouchers, price watch, and calling UI/backend objects.
- Multi-provider refill adapters and offer normalization for Zendit, DT One, Ding, and Reloadly.
- eSIM catalogue/fulfillment adapters for eSIM Go, Zendit, and eSIM Access.
- Queue claim/status/refund patterns and provider external-reference retry logic.
- Admin operational RPC facade covering configuration, suppliers, carriers, jobs, channels, eSIM, affiliates, email, offline/vouchers, support, users, audit, and wallet adjustment.
- RLS enabled on every live public table.
- 19 active scheduled jobs and substantial notification/offer data.

Implementation does not imply production verification. Provider credentials, webhook secrets, app-store setup, notification endpoints, and E2E external transactions were not exercised in this analysis.

## Critical issues

### P0 — critical/blocking

1. **Remove or redesign the live `execute_zendit_recharge` path.** It can purchase from Zendit without the authoritative wallet debit/queue/refund path.
2. **Rotate and remove the tracked PayPal access token.** `mcp_config.json` is tracked with a nonempty token; review Git history and secret storage.
3. **Fix the `check_scheduled_jobs_health()` grant regression.** **LOCALLY FIXED, NOT DEPLOYED (2026-09-06):** forward migration `20260906125518_harden_scheduled_jobs_health_authorization.sql` revokes `PUBLIC`, `anon`, `authenticated`, and `service_role`, retaining only the live pg_cron caller (`postgres`). Focused SQL coverage and an exact postgres-only grant bucket were added; isolated runtime execution remains required before release.
4. **Rebuild and audit wallet reconciliation before broad real-money use.** The current view omits modern transaction types; observed chain/snapshot discrepancies require owner-reviewed explanation.
5. **Make webhook verification fail closed.** Telnyx/Twilio handlers must reject requests when verification keys/tokens are missing or invalid.
6. **Resolve provider selection safety.** The current worker suite fails the test excluding Ding content bundles from plain airtime ranking. Keep Ding routing disabled until real-response validation and tests pass.
7. **Reconcile live/local migration and Edge Function drift.** Missing deployed source (`send-admin-email`), local-but-absent functions, runtime behavior without matching migration history, and mismatched histories prevent reproducible releases.
8. **Add an actual release gate.** No current clean Flutter test/analyze/build evidence or CI exists; the admin's only test does not compile as written.

### P1 — high priority

1. Add route-level admin power-user enforcement and eliminate/guard legacy direct reads; retain server `assert_admin()` as authority.
2. Redesign call charging with balance reservation, maximum duration, or explicit partial collection; align wallet/ledger/total-spent semantics.
3. Reconcile all deployed Edge Function `verify_jwt` values with source/config and record a versioned manifest.
4. Deploy or remove customer calls to missing `liveness-verification` and `send-whatsapp-alert`; resolve PayPal return fallback and local `paypal-return` status.
5. Reconcile carrier primary-provider migration provenance: behavior is live, but its matching local version is absent from live migration history. Do not reapply blindly.
6. Fix three security-definer views and mutable-search-path trigger functions; re-run advisors.
7. Build full worker-fleet heartbeat/health coverage and a complete PM2/process manifest, including voucher and messaging services as applicable.
8. Replace/hide client-generated mock payment methods and placeholder offline endpoints in production builds.
9. Disable Android cleartext traffic for release or scope an explicit network security configuration.
10. Complete platform release setup: iOS Firebase config/App Check/push/widget entitlement wiring and valid bundle identifiers; admin release signing/distribution decision.

### P2 — important

1. Add SQL suites for post-N1 migrations: provider routing/pin fallback, international calling, line confirmation/liveness, scheduled job operations, realtime publication, retention, and primary preference.
2. Add meaningful admin widget/controller/repository tests and negative authorization tests.
3. Reduce direct Supabase access in client UI/controllers, starting with payments, admin user reads, SIM realtime, privacy/devices, and scheduled top-ups.
4. Define a shared schema/domain contract strategy for the 71 divergent common Dart paths.
5. Split the largest screens along existing feature boundaries while preserving behavior and adding focused tests.
6. Triage performance advisors using query plans: unindexed FKs, RLS init plans, policy overlap, then unused indexes.
7. Add structured redaction and correlation IDs across client, Edge, worker, payment, and provider logs.
8. Clarify lifecycle and exposure of admin SSH/SFTP and test-console capabilities; gate them by build and role.

### P3 — nice to have

1. Clean generated/tool artifacts and large stale outputs from product source after retention/history review.
2. Consolidate overlapping admin dashboard/operations and legacy/new feature structures.
3. Replace stale top-level `README.md` with a human onboarding pointer to authoritative docs and `.codex`.
4. Automate documentation freshness checks for counts, function inventory, migration parity, and grant allowlists.

## Testing and verification status

| Area | Result on 2026-09-06 | Interpretation |
|---|---|---|
| Customer Flutter | Source scan: 35 files / 361 declared tests. Full analysis/test commands did not complete because existing IDE/Dart/Flutter processes held the SDK/analyzer. | **Unknown current pass status.** Older 291-test/73-test baselines are stale. |
| Admin Flutter | One template counter test imports `main.dart` and references nonexistent `MyApp`. | Known invalid test; no meaningful automated coverage. |
| Node workers | Run each file in-process: offer validation 34/35, voucher 23/23, eSIM catalogue 12/12, fulfillment 10/10. | 79/80 pass; Ding bundle exclusion fails. Multi-file Node runner itself hit Windows sandbox `spawn EPERM`, not a product failure. |
| SQL | 34 regression files inspected, not executed in this audit. | Historical breadth is good; current runtime and recent migration coverage need re-baselining. |
| CI | No supported configuration found. | No automatic merge/release gate. |

## Production-readiness matrix

| Dimension | Assessment | Evidence |
|---|---|---|
| Product breadth | Advanced | Broad customer/admin feature surface and live domain objects. |
| Architecture consistency | Needs work | Hybrid layering, direct infrastructure access, divergent copies. |
| Financial integrity | Blocking review | Bypass function, stale reconciliation, calling collection semantics. |
| Authorization/security | Blocking review | Grant regression, advisor errors, fail-open webhooks, admin route gap. |
| Provider reliability | Not proven | One safety test failing; several adapters/comments say live validation incomplete. |
| Deployment reproducibility | Not ready | Local/live function and migration drift; incomplete process/config manifest. |
| Automated quality gates | Not ready | No CI, admin test invalid, current Flutter baseline unavailable. |
| Android release | Partially prepared | Signing guard exists; cleartext enabled; E2E release not verified. |
| iOS release | Not ready | Missing Firebase plist/App Check setup and entitlement project wiring; identifier needs validation. |
| Operations/observability | Partial | Alerts/cron/admin surfaces exist; fleet health and configuration truth are incomplete. |

## Open questions and unknowns

### Confirmed

- Both apps share one backend and must evolve together.
- `backend-sync-wt` is the current worker editing/deployment authority.
- Live/local migration and Edge inventories differ.
- Enforcement flags checked are false.
- The admin route checks authentication, not power-user status.
- Payment-method token creation is mock behavior.

### Inferred

- Some migration drift resulted from manual SQL execution and later history stamping/renaming.
- Missing live liveness/WhatsApp proxy functions will cause invoked customer flows to fail unless an undocumented gateway handles them.
- Existing wallet chain discontinuities may include fixtures or historical direct corrections, but need proof.
- Admin SSH/test-console surfaces are likely internal-only, but no build/distribution gate proves that.

### Unknown — verify before acting

- Which Supabase project/environment is production versus staging, and whether a safe staging branch exists.
- Which provider credentials are live, sandbox, absent, or financially enabled.
- Whether `TELNYX_PUBLIC_KEY`, `TWILIO_AUTH_TOKEN`, PayPal return URLs, Firebase/App Check, OneSignal, email, and WhatsApp secrets are correctly configured.
- Whether the tracked PayPal token is still valid and whether history copies were revoked.
- The intended disposition of `execute_zendit_recharge`: delete, sandbox-only gate, or redesign.
- The accepted source-of-truth migration baseline and how to reconcile 193 live entries with 158 local files.
- Whether `send-admin-email` deployed source can be recovered exactly.
- Which offline SMS/WhatsApp endpoints and voucher suppliers have passed a real disaster-recovery drill.
- Whether Ding, Reloadly, DT One, Zendit, eSIM Go, and eSIM Access have passed controlled real-account contract tests.
- Whether current app-store identifiers/accounts, privacy disclosures, payment/legal obligations, and telecom compliance are approved.
- Whether the observed wallet discrepancies are test data, prior manual repair, or an accounting defect.

### Do not assume

- A phase marked complete is still secure after later migrations.
- A local function/migration is deployed.
- A live function has matching local source.
- RLS enabled means all RPC grants are safe.
- A green `/health` response means all workers are alive.
- A visible admin screen means the user is authorized.
- A TODO is approved scope.
- “Unused” copied code is safe to delete.

## Practical next development sequence

1. Freeze external spend to an allowlisted test cohort; rotate the tracked token and close the direct Zendit/grant/webhook P0s.
2. Establish a reproducible live baseline: schema/function/grant diff, Edge source/version manifest, migration reconciliation, and full process inventory.
3. Repair provider test failure and run controlled provider-contract tests without broad customer exposure.
4. Rebuild wallet reconciliation and investigate every unexplained chain/current-balance discrepancy with an owner-approved ledger policy.
5. Add call reservation/limit semantics and E2E webhook/billing tests.
6. Gate the admin app by power-user claim; retire direct privileged reads and unsafe/missing actions.
7. Restore clean Flutter analysis/tests/builds; replace admin template test; add CI for both apps, SQL, Node, secret scanning, and generated-code drift.
8. Verify Android release and complete iOS only if iOS is an intended launch target.
9. Enable enforcement flags and external providers incrementally, with rollback, alerting, reconciliation, and kill switches validated first.
