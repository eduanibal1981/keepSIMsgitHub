# Architectural Decisions and Discovery Log

This records decisions that future agents must preserve and contradictions they must not silently erase.

## Active decisions

### AD-001 — One system, two clients

**Status:** accepted / confirmed  
**Decision:** `keep_sims` and `keep_sims_admin` are clients of the same Supabase/backend domain. Any shared schema, business-rule, authentication, or workflow change must evaluate both applications.

### AD-002 — Trusted server owns money and provider spend

**Status:** accepted; current exception is a blocker  
**Decision:** Wallet mutation, payment capture, provider selection/cost, recharge/eSIM purchase, refund, and call billing are server-owned. Flutter submits intent and displays results. Stable external references and atomic ledger updates are mandatory.

### AD-003 — Feature-first client layering

**Status:** intended; partially implemented  
**Decision:** Use model/domain -> contract -> repository/data source -> controller/provider -> UI. Infrastructure does not move upward. Existing hybrid code is migrated opportunistically, not via broad speculative rewrites.

### AD-004 — Admin UI is not a trust boundary

**Status:** accepted  
**Decision:** Privileged server actions require the JWT app-metadata power-user claim and backend checks/audit. Client navigation, profile values, hidden buttons, and desktop distribution do not authorize an operation.

### AD-005 — Forward migrations and explicit grants

**Status:** accepted  
**Decision:** Never edit an applied migration. Add forward migrations. Every definer function has explicit identity checks, safe search path, revoked public access, and a minimal role allowlist validated by negative tests.

### AD-006 — Worker source and deployment authority

**Status:** accepted  
**Decision:** `C:\Users\abdal\Work\KeepSIMs\backend-sync-wt` is authoritative for Node workers. Validate JavaScript, copy approved files directly to the VM path, restart/check PM2 according to `.agents/AGENTS.md`. Do not deploy by assuming GitHub pull on the VM.

### AD-007 — Runtime claims require runtime evidence

**Status:** accepted  
**Decision:** Local source describes intent; it does not prove deployment. Record live function versions/settings, migration state, flags, and schema behavior before calling work complete.

### AD-008 — Provider contracts are evidence-driven

**Status:** accepted  
**Decision:** Provider identifiers, currency/divisors, offer kinds, response fields, and retry behavior must be verified against controlled real responses. An adapter written only from documentation remains gated.

## Contradiction ledger

| Topic | Older/intended claim | Current evidence (2026-09-06) | Resolution |
|---|---|---|---|
| Worker deployment | Topology/maps refer to `keep_sims/servers`, Git pull, or owner-only SSH | `.agents/AGENTS.md` names `backend-sync-wt` and direct copy/PM2 workflow | `.agents/AGENTS.md` wins; older instructions are `DEPRECATED`. |
| Production phase F | Topology says F-2 is top open item | Later production-review amendments say F0/grants complete | Historical status only; live `check_scheduled_jobs_health` introduced a new grant regression, so re-audit. |
| Liveness/WhatsApp deployment | Phase L says proxy functions deployed | `liveness-verification` and `send-whatsapp-alert` exist locally but not in live function inventory | Mark not deployed until proven; customer invocations are at risk. |
| Telnyx signature | Phase L says missing/invalid signatures always reject | Source continues when `TELNYX_PUBLIC_KEY` is missing | Source contradicts plan; fix to fail closed. |
| PayPal return | Local comments indicate deployment ordering/fallback changes | `paypal-return` is absent live; live `create-paypal-order` is v7; secrets are not visible | Runtime behavior `UNKNOWN`; verify secrets and deploy/source parity. |
| Function source | Local source should reproduce deployed functions | `send-admin-email` is live with no local directory | Recover and version source before relying on it. |
| Function config | `supabase/config.toml` might appear authoritative | Only four function blocks are represented; live has 24 active functions | Treat config as incomplete. |
| Primary provider routing | Local migration prioritizes `is_primary` | Matching version is absent from live history, but the live function does implement primary -> direct -> price -> priority ordering | Behavior is present; reconcile migration provenance rather than reapplying it blindly. |
| Migration history | Repository migrations imply production schema | 158 local files vs 193 live history rows and timestamp/name mismatches | Establish baseline/diff before further production migrations. |
| Grant closure | Earlier F0 tests enumerate a closed allowlist | Live has four anon definer functions and 115 authenticated definer functions | Old allowlist is stale; rebuild it from live and expected API contracts. |
| Test baseline | Structure map cites 291/291 or other smaller totals | Current customer source declares 361 cases; full suite not completed in audit | Never reuse old baseline as release evidence. |
| Schema documentation | Database docs describe about 70 objects/older domains | Live has 83 public tables and newer provider/voucher/calling/jobs domains | Live/current migrations win for current state; update prose intentionally. |
| Google services file | Structure map says `google-services.json` is untracked | Git currently tracks it | Decide repository policy and update docs; do not call it a service secret. |
| Client architecture | Rules require strict five layers/no direct backend calls in UI/controllers | Hybrid trees and at least 13 direct-access presentation/controller files | Preserve intended direction; avoid broad automatic moves. |
| Shared code | Similar paths suggest shared implementation | 79 common Dart paths; 71 differ; no shared package | Treat as forks with drift risk, not a single module. |
| Health | A health endpoint might imply fleet availability | Local health function checks DB plus one eSIM worker heartbeat | Build explicit fleet health before using it as release evidence. |

## Discoveries that must not be forgotten

- The current `wallet_reconciliation` view does not understand all modern transaction types; its drift result is not authoritative.
- Call debit can record full spend after only partial available-balance collection.
- The legacy stored-card flow generates mock tokens client-side.
- Offline fallback settings and seeded contact numbers can mask missing real infrastructure.
- The admin app's only test is the untouched counter template and references a nonexistent class.
- Android allows cleartext traffic in the main manifest.
- iOS Firebase/App Check and widget entitlement project wiring are incomplete in source.
- The authoritative worker worktree and admin repo were already dirty during the audit; those edits belong to the user.

## Audit log

### 2026-09-06 — initial AI knowledge-base audit

Inspected:

- Four authoritative context documents and `ARCHITECTURE_RULES.md`.
- Complete directory/file maps for customer/admin apps, Supabase source, tests, and authoritative workers.
- Client bootstrap, routing, dependency/state patterns, feature structures, direct Supabase usage, admin RPC/auth paths, payment mocks, release configuration, and large-file hotspots.
- Worker queue/RPC/provider patterns, environment key names, PM2 declarations, and test suites.
- Read-only live Supabase tables/counts, migration history, Edge Function inventory/settings, grants/function properties, cron/registry, configuration flags, advisors, and ledger aggregates.

Validation limits:

- Flutter analysis/tests did not complete because existing IDE/Dart/Flutter processes held the toolchain; they were stopped without killing user processes.
- SQL regression files were inspected but not executed.
- No real payment, provider purchase, call, notification, webhook, VM deploy, or app-store action was performed.
- Secret values were not read or reproduced beyond detecting that a tracked token field is nonempty.

Material changes made by this audit: `.codex` documentation only; no production code, schema, deployment, or user data changes.

### 2026-10-14 — Smart Call destination and review contract

**Status:** accepted; implemented locally in the customer app.

A call destination is resolved from raw input plus an explicitly confirmed ISO country for national numbers. Tariff rows, their phone prefixes, caller identity, location, and server quote results must not determine or mutate that country. Existing valid `+` input keeps its international identity. A maintained numbering-plan parser preserves country-specific trunk and significant-zero rules.

Selected contacts and redial pass through the shared `CallReviewSheet`. It displays the complete number, actual effective caller ID, customer rate, and relevant connection fee/billing interval. Caller-ID load failures cannot fabricate a gateway number. Local identity selection submits the exact verified ID and does not implicitly update the saved default.

Draft mutations invalidate pending quotes immediately. A final read-only preview rechecks the reviewed draft; changed price/fee/increment/identity returns to review before call creation. The existing server remains authoritative for eligibility, identity ownership, pricing, available balance and provider execution. A minimum-balance client check is not a reservation or a guarantee that the entire call is collectible.

Verification and rollout evidence: `docs/implementation-plans/smart-call-country-and-review-plan-20261014.md`. No database, worker or Edge Function deployment was required by this change.


## Free Call recipient review and manual invitations (2026-10-15)

Customer app Free Call now has its own account-scoped recipient draft/review, independent of paid pricing/CLID state. National numbers reuse the country-confirmed `CallDestination` resolver; known household/history recipients retain stable account IDs. Edit/account changes immediately clear eligibility; the final call tap rechecks identity after microphone permission and cannot silently choose a changed recipient.

`resolve_free_call_recipient(text,uuid)` is the new authenticated, quota-limited SECURITY DEFINER API with an empty search path. Phone resolution is exact canonical ownership via verified caller IDs, active owned DIDs or confirmed Auth phone. Raw SIM/carrier setup and mutable profile phones are unverified claims, and conflicting users are ambiguous. ID lookup requires an accepted household relationship or existing caller-owned call history. Self/unknown/error/unverified states cannot become a callable arbitrary account. A push token is not live presence. The legacy suffix-match API remains solely for older clients; the new review never falls back to it.

The verified caller-ID fields were client writable behind owner-only RLS. A SECURITY INVOKER trigger now denies client-manufactured verification/timestamps and clears proof on phone changes while retaining label/default edits and trusted server verification. Resolver deployment version `20261014214138`; guard version `20261014215139`. Live bodies/grants and isolated negative checks were verified after the approved Supabase update.

No-match review shows the app requirement directly below the number and separate WhatsApp/SMS invitations. They open the caller’s own app/native composer; the caller must press Send. No SMS-send permission, automatic messages, contact upload, wallet charge or signed callable link is implied. The existing marketing page has placeholder store buttons, so a real optional HTTPS install link comes from `FREE_CALL_APP_DOWNLOAD_URL`; current text does not promise that placeholder is a download. Paid fallback carries the confirmed number into the existing paid review and still requires a paid Call tap.

Android debug build installed; iOS simulator compilation passed; 23 focused checks pass. Two-device speech/background delivery and real physical-device invite composition/sending remain NOT RUN. See `docs/reviews/free-call-review-verification-20261015.md`.
