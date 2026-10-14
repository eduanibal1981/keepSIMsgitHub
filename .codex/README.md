# KeepSIMs AI Knowledge Base

Purpose: persistent, AI-facing context for developing the complete KeepSIMs system without repeating repository-wide discovery.

**Last verified:** 2026-09-06 (Asia/Muscat)  
**Scope:** customer app, admin app, authoritative Node workers, local Supabase source, and read-only live Supabase metadata.  
**Not a claim of deployment:** a local source file is not considered deployed unless runtime evidence confirms it.

## Read order

1. `../.agents/AGENTS.md` — mandatory operational and deployment rules; this overrides older deployment prose.
2. [AI_AGENT_GUIDE.md](AI_AGENT_GUIDE.md) — rules before changing anything.
3. [SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md) — boundaries, layers, trust model, and workflows.
4. [PROJECT_MAP.md](PROJECT_MAP.md) — applications, features, and file locations.
5. [BUSINESS_RULES.md](BUSINESS_RULES.md) — invariants and domain rules that implementations must preserve.
6. [DATA_BACKEND_SECURITY.md](DATA_BACKEND_SECURITY.md) — database, RPCs, Edge Functions, workers, authorization, and drift.
7. [CURRENT_STATUS_AND_ROADMAP.md](CURRENT_STATUS_AND_ROADMAP.md) — actual state, blockers, unknowns, and priorities.
8. [ARCHITECTURAL_DECISIONS.md](ARCHITECTURAL_DECISIONS.md) — decisions and contradiction ledger.

For historical intent, then consult:

- `../doc/PROJECT_TOPOLOGY.md`
- `../doc/PRODUCTION_PLAN_REVIEW.md`
- `../THE_Project_Structure_map.md`
- `../ARCHITECTURE_RULES.md`

## System in one paragraph

KeepSIMs is an Android-first Flutter service that helps customers keep prepaid SIMs active. The customer app manages SIM lines, wallet funding, planned/instant refills, offline voucher recovery, eSIM purchases, international calls, alerts, household sharing, referrals, and travel tools. A separate Flutter admin app is an operational control plane. Both use one Supabase project. Privileged and financial behavior belongs in Postgres RPCs, Edge Functions, or service-role Node workers—not in either client.

## Evidence labels

Every durable statement should use one of these meanings:

| Label | Meaning |
|---|---|
| `CONFIRMED` | Verified in current source, configuration, or read-only runtime metadata on the stated date. |
| `INFERRED` | Strongly implied, but not proven end-to-end. |
| `UNKNOWN` | Requires owner, provider, secret, deployment, or runtime verification. |
| `PLANNED` | Intended by project documentation but not proven implemented/deployed. |
| `DEPRECATED` | Historical path or behavior that must not drive new work. |

## Evidence precedence

When sources disagree, do not silently choose the most convenient one. Use this order and record the discrepancy:

1. Current live behavior/metadata, when safely verified.
2. Current working-tree source in the authoritative repository.
3. Current committed source.
4. Newest dated amendment in project documentation.
5. Older plans, maps, baselines, and comments.

Runtime state can still be wrong; it wins only for describing **what exists now**, not **what should exist**.

## Current snapshot

| Area | Verified snapshot |
|---|---|
| Customer app | `keep_sims`; 348 Dart files, 233 excluding `.g.dart`/`.freezed.dart`; 19 feature directories. |
| Admin app | sibling `keep_sims_admin`; 135 Dart files, 90 excluding generated files; 9 feature directories. |
| Shared backend | One Supabase project (`zwxswagokhgbuzrrbnhr`) plus Node workers. |
| Local backend source | 158 SQL migrations, 34 SQL test files, 26 Edge Function directories. |
| Live backend | 83 public tables, 193 migration-history rows, 24 active Edge Functions, 19 active cron jobs. |
| Customer tests | 35 Dart test files; 361 declared `test`/`testWidgets` cases by source scan. Full suite was not re-run successfully during this audit. |
| Admin tests | One untouched template test that references nonexistent `MyApp`; effectively no valid automated coverage. |
| Worker tests | 79/80 passed when run in-process; one Ding bundle-filter test failed. |
| CI | No GitHub Actions, Codemagic, or Fastlane configuration found. |

Counts are discovery aids, not contractual invariants. Re-measure before using them in a release decision.

## Non-negotiable safety rule

Never put provider credentials, Supabase service-role keys, payment secrets, webhook secrets, or signing keys in Flutter clients or tracked configuration. The Supabase anon/publishable key is a public client identifier; service-role and provider credentials are not.

## Maintenance

Update this knowledge base when an architectural boundary, schema contract, deployment path, security posture, or production-readiness conclusion changes. Add date and evidence. Do not rewrite `CONFIRMED` findings into claims of completion without verification.
