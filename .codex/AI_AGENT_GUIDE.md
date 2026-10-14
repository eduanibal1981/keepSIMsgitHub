# AI Agent Guide

This file is normative for future AI work on KeepSIMs, subordinate only to `.agents/AGENTS.md` and explicit user instructions.

## Before changing code

1. Read `../.agents/AGENTS.md` completely.
2. Read the relevant `.codex` files, especially `CURRENT_STATUS_AND_ROADMAP.md`.
3. Inspect `git status` in every repository being touched. Existing modifications belong to the user.
4. Inspect the current implementation; do not rely on a plan or old file map.
5. Classify the behavior as `CONFIRMED`, `INFERRED`, `UNKNOWN`, `PLANNED`, or `DEPRECATED`.
6. Identify affected application(s), feature(s), data objects, RPCs/Edge Functions/workers, tests, and deploy surfaces.
7. Search both Flutter apps and backend source for an existing model, service, repository, RPC, component, or business rule.
8. Identify the intended architectural layer and the current local pattern before adding files.
9. For any money, provider-purchase, authorization, webhook, or deletion path, map the trust boundary and idempotency behavior first.

## Where code belongs

The intended client flow from `ARCHITECTURE_RULES.md` is:

```text
model/domain -> contract -> repository/data source -> controller/provider -> UI
```

Rules:

- Models/domain values: parsing, invariants, value semantics; no widgets or direct network calls.
- Contracts: stable interfaces returning `Result<T>`/typed failures where the feature follows the legacy contract pattern.
- Repositories/data sources: Supabase, local cache, platform SDK, and provider interaction.
- Controllers/providers: orchestration and UI state; no raw table queries.
- UI: rendering and user intent only; no direct Supabase access.
- Cross-feature primitives: `lib/core/`, only when genuinely shared.
- Backend financial invariants: SQL functions/migrations or trusted worker/Edge Function code, never Flutter-only checks.
- Generated `.g.dart` and `.freezed.dart`: regenerate; never hand-edit.

The current code is hybrid: some features use `model/contract/repository/controller/ui`, others use `data/domain/presentation`, and at least 13 presentation/controller files directly access Supabase. Preserve working behavior, but do not copy those violations into new work. Refactor narrowly when the requested change naturally touches one.

## System-wide change checklist

- [ ] Does the change affect customer, admin, or both?
- [ ] Is there a copied counterpart in the other app? The apps have 79 common relative Dart paths; 71 currently differ.
- [ ] Does it change a database shape, enum/string discriminator, RPC signature, or JSON response?
- [ ] Does it require a forward-only migration and matching SQL test?
- [ ] Does it affect RLS, grants, `SECURITY DEFINER`, JWT claims, or service-role boundaries?
- [ ] Does it spend/credit money or buy from a provider? Verify atomicity, idempotency, retry/adoption, and refund symmetry.
- [ ] Does it introduce or change an Edge Function? Verify local source, `supabase/config.toml`, deployed `verify_jwt`, webhook authentication, and runtime version.
- [ ] Does it affect workers? Edit `../backend-sync-wt` (or `servers/` in the active workspace on Mac), not the customer repo copy, and follow `.agents/AGENTS.md` deployment instructions.
- [ ] Are provider identifiers/currencies/minor-unit divisors validated against real provider responses?
- [ ] Are logs/errors free of tokens, phone numbers, ICCIDs, wallet values, and provider payload secrets?
- [ ] Are both success and failure paths tested?
- [ ] Did the change alter architecture or an important business rule? Update `.codex`.

## Financial path rules

DO:

- Keep wallet mutation server-side and transactionally coupled to ledger entries.
- Use unique external references/idempotency keys for supplier purchases and payment capture.
- Make retry logic adopt an existing provider transaction before creating another.
- Record the amount actually debited/credited, not an intended amount that could not be collected.
- Treat timeouts and ambiguous provider responses as reconciliation states, not automatic safe failures.
- Require an authoritative offer lookup; never trust client-submitted price/cost/provider values.

DON'T:

- Call a supplier directly from Flutter.
- Create a second recharge path that bypasses queue/claim/debit/refund RPCs.
- update `wallets.balance` or write financial ledger rows directly from a client.
- assume the current `wallet_reconciliation` view understands all transaction types—it does not.
- enable a new provider because an adapter compiles; require real-response validation and passing provider tests.

## Authentication and authorization rules

- Authentication is not administration. Admin access is based on the JWT `app_metadata.is_power_user` claim and server-side `assert_admin()` checks.
- The admin router currently gates only on “signed in”; do not treat its UI banner as an authorization boundary.
- RLS enabled does not prove correct policy/grant behavior.
- A `SECURITY DEFINER` function must set a safe search path, validate identity/ownership/role in the body, and receive an explicit minimal `GRANT EXECUTE` after revoking `PUBLIC`.
- Webhooks with `verify_jwt=false` must fail closed on provider signature/secret misconfiguration.
- Never authorize from a mutable profile field alone when the backend contract uses JWT app metadata.

## MCP tools (use these first for all database verification)

A Supabase MCP server is configured for project `zwxswagokhgbuzrrbnhr`. **Always prefer these tools over requesting a Supabase branch or any external database environment.** They require no billing, no branch lifecycle, and no user approval:

| Tool | Purpose |
|---|---|
| `execute_sql` | Run any read-only or test SQL query directly against the project. Use for regression checks, grant inspection, and function-behavior verification. |
| `list_tables` | List schema tables and ownership. |
| `list_migrations` | Inspect applied migration history vs. local files. |
| `apply_migration` | Apply a forward-only migration to the project (requires explicit user authorization before use). |
| `get_advisors` | Fetch live security and performance advisor findings. |
| `get_project_url` / `get_publishable_keys` | Retrieve project endpoint metadata. |
| `generate_typescript_types` | Derive types from live schema. |
| `list_branches` | Check whether a branch already exists before ever creating one. |
| `create_branch` | **Last resort only** — create a branch solely for destructive DDL preview when `execute_sql` is insufficient **and** the user has explicitly pre-approved the branch cost ($0.01344/hr). Delete the branch immediately after. |
| `delete_branch` | Always delete a branch as soon as testing is complete. |
| `query_logs` | Inspect Edge Function, API, or Postgres logs. |
| `list_edge_functions` / `get_edge_function` | Inspect live Edge Function metadata. |

**Decision rule for SQL testing:**

1. Can the test be expressed as a `SELECT` / `DO` block that does not permanently alter schema? → use `execute_sql`.
2. Does it require applying a migration whose effect must be previewed without touching production? → use `list_branches` first (a branch may already exist), then `create_branch` only after explicit user approval, then `delete_branch` immediately.
3. **Never** cite the absence of local Docker/Postgres as a reason to request a branch when MCP `execute_sql` is available.

## Testing workflow

Use the narrowest meaningful checks first, then expand:

1. Format/regenerate affected Dart code.
2. Run focused Flutter tests for the feature.
3. Run customer/app analysis and full tests when toolchain access permits.
4. **Run SQL regression tests via MCP `execute_sql` — not via a Supabase branch.** Verify grants, function behavior, and negative cases (anon denial, authenticated denial, trusted-role success) directly against the live project using read-safe statements.
5. Run Node worker tests. On Windows, `node --test <multiple files>` may fail with sandbox `spawn EPERM`; running each test file with `node <file>` executes the suites in-process.
6. For release changes, verify actual signed artifacts and platform configuration.

Do not quote old “all tests pass” counts as current. The 2026-09-06 audit could not finish Flutter analysis/tests because the SDK/analyzer was held by existing IDE processes; the worker suite had one real failure.

For database performance work, do not implement advisor output mechanically. Capture the target query, inspect `EXPLAIN (ANALYZE, BUFFERS)` on safe representative data, check existing composite indexes, then measure the change. Foreign-key indexes matter for joins and cascade/delete locking; RLS ownership columns need indexes, and stable auth expressions should use an init-plan form such as `(select auth.uid())` where equivalent.

## Database and deployment workflow

- Database changes are forward-only migrations under `supabase/migrations/` plus tests under `supabase/tests/`.
- Do not infer deployment from a local migration filename. Live migration history currently differs from local history.
- Compare local Edge Function source with live slug/version and `verify_jwt` configuration.
- `supabase/config.toml` is currently incomplete; do not assume unspecified function settings match production.
- For workers, `backend-sync-wt` is authoritative. Run `node --check` on changed JavaScript. Deploy by the direct copy/restart procedure in `.agents/AGENTS.md`; old git-pull instructions are deprecated.
- Never execute destructive database, deploy, provider, payment, or VM actions unless explicitly requested and scoped.

## Never

- Invent architecture without reading the project rules and current code.
- Treat customer and admin apps as independent systems.
- Duplicate services, models, widgets, RPCs, or provider adapters unnecessarily.
- Move files only to satisfy a generic architecture template.
- Broadly refactor when a localized change is sufficient.
- Delete apparently unused code without tracing other UI, cron, Edge Function, worker, and admin flows.
- Treat TODOs or phase labels as current requirements without verification.
- Store secrets in tracked MCP/tool configuration.
- Modify a user-dirty file without understanding and preserving its changes.

## Definition of done

A feature is not complete merely because the Flutter screen exists. Completion requires the applicable client, database, RLS/grants, trusted execution path, provider contract, observability, tests, deployment configuration, and documentation to agree—and runtime verification when deployment is claimed.
