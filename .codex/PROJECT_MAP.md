# Project Map

## Repositories and authority

| Path | Role | Authority notes |
|---|---|---|
| `C:\Users\abdal\Work\KeepSIMs\keep_sims` | Customer Flutter app; owns local Supabase migrations/functions/tests and historical worker copy. | Current working repository and home of this knowledge base. |
| `C:\Users\abdal\Work\KeepSIMs\keep_sims_admin` | Admin Flutter application. | Separate Git repository, same backend. Inspect its working tree before changes. |
| `C:\Users\abdal\Work\KeepSIMs\backend-sync-wt` | Node provider adapters/workers/services. | **Authoritative worker source per `.agents/AGENTS.md`.** |
| `keep_sims/servers` | Mirror/copy of Node backend source used by older docs and PM2 config. | `DEPRECATED` as an editing authority. Checked top-level files matched the authoritative worktree during this audit, but future drift is possible. |
| `keep_sims/supabase` | Local Postgres migrations/tests and Edge Function source. | Source intent; compare with live before claiming deployment. |
| `keep_sims_daemon`, `keep_sims_tasker`, `web_landing` | Related deployment surfaces in the parent directory. | Referenced by project topology; not deeply audited in this pass. Investigate when a change crosses into them. |

## Customer application

Key entry points:

| Concern | Path |
|---|---|
| Bootstrap | `lib/main.dart` |
| Supabase initialization | `lib/core/supabase_client.dart` |
| Routing | `lib/core/router/app_router.dart` |
| Theme/design system | `lib/core/theme/`, `lib/core/widgets/` |
| Typed failures/results | `lib/core/failure.dart`, `lib/core/result.dart` |
| Offline cache/sync | `lib/core/services/local_cache_service.dart`, `sync_queue_service.dart` |
| Localization | `lib/l10n/` and ARB inputs configured in `l10n.yaml` |

Feature inventory:

| Feature | Main responsibility | Current shape / note |
|---|---|---|
| `auth` | OAuth/email identity and session/profile loading | Legacy five-layer structure. |
| `dashboard` | Home summary and promotions | Presentation providers; promo provider calls RPC directly. |
| `sim_lines` | Lines, carrier rules, health, liveness, activity, manual refill, rescue, usage | Largest feature; hybrid data/domain/presentation; large screens; realtime access in UI. |
| `scheduled_topups` | Plans, schedules, executions, retry/cancel/reschedule | Legacy layers; controller also has direct data access. |
| `wallet` | Balance, transaction history, gifts/plan fees | Repository invokes trusted wallet Edge Function. |
| `payments` | PayPal wallet top-up and stored-method UI | PayPal path exists; stored card creation is explicitly mock. |
| `offline_recharge` | Offline events/endpoints and emergency vouchers | Two overlapping structures; contains mock settings fallback. |
| `esim` | Compare/filter/purchase/manage eSIM | New architecture; server purchase request plus worker fulfillment. Some screens query Supabase directly. |
| `calling` | Rates, calls, caller IDs | New feature; direct repository/provider pattern, no contract/typed result boundary. |
| `notifications` | Inbox, settings, delivery status | Substantial presentation/data/domain implementation. |
| `household` | Members, invitations, allowances/spend | New structure; presentation provider calls RPC directly. |
| `referrals` | Codes, points, redemption | Legacy layered repository/controller/UI. |
| `price_watch` | Offer-change tracking | Presentation provider has direct Supabase access. |
| `geo` | Country detection and line-mode behavior | Controller invokes Edge Function directly. |
| `roam_calculator` | Travel/roaming cost estimates | Presentation provider accesses data directly. |
| `home_widget` | Native widget snapshot/sync | Android implementation; iOS entitlement wiring incomplete. |
| `profile` | Profile and onboarding | Onboarding screen is 3,092 lines. |
| `settings` | Preferences, privacy, devices, biometrics | Privacy/device controllers call backend directly. |
| `support` | Tickets/help workflows | Duplicate `contract` and `domain` style families require care. |

The source contains 19 feature directories. Always inspect the router and feature folder rather than trusting this summary for individual screens.

Calling navigation (2026-10-15): `SmartCallDashboardScreen` opens `CallReviewSheet` for international number entry/review. `/calling/recent` hosts `CallHistoryScreen`; redial uses the same review. `/calling/dialer` is a compatibility redirect to history. The old `calling_screen.dart` and its standalone dialpad were removed; active-call DTMF remains in `active_call_screen.dart`.

## Admin application

Key entry points:

| Concern | Path |
|---|---|
| Bootstrap | `keep_sims_admin/lib/main.dart` |
| Routing | `keep_sims_admin/lib/core/router/app_router.dart` |
| Admin RPC facade | `keep_sims_admin/lib/core/admin/admin_api.dart` |
| Admin providers/widgets | `keep_sims_admin/lib/core/admin/admin_providers.dart`, `admin_widgets.dart` |
| Shell/navigation | `keep_sims_admin/lib/core/layout/admin_shell_screen.dart` |

Feature inventory:

| Feature | Main responsibility | Current shape / note |
|---|---|---|
| `control` | Operations, jobs, config, carriers, channels, suppliers, affiliates, email, offline, vouchers, support, audit | Primary control plane using `AdminApi`; includes current uncommitted work. |
| `admin` | Dashboard metrics/data | Older dashboard/provider layer overlaps operations view. |
| `analytics` | Operational/business charts | Currently being modified in working tree. |
| `auth` | Login/profile/session | Copied legacy structure; profile row and JWT claim have different authority roles. |
| `user_management` | List/suspend/purge users | Direct profile select; promotion intentionally unsupported; legacy permanent-ban call targets missing Edge Function. |
| `scheduled_topups` | Execution list/manual completion/failure | Older repository duplicates parts of `AdminApi`. |
| `sim_lines` | Line inspection and test/mock utilities | Forked from customer feature; not a shared package. |
| `server_management` | SSH/SFTP server operations | Powerful operator surface; requires explicit threat/operational review. |
| `testing_console` | Test data/scenario UI | Do not expose in production without strict role and build gating. |

## Shared-code reality

`CONFIRMED` The applications share concepts by copying source, not through a package:

- 79 relative Dart paths exist in both `lib` trees.
- Only 8 were byte-identical on 2026-09-06.
- 71 had diverged.

Consequences:

- A database/model/enum change may require two separate Dart updates.
- “Fixing the shared file” in one app does not update the other.
- Do not automatically overwrite one copy with the other: some divergence is role-specific.
- Before adding a shared package, first classify genuinely shared domain contracts versus customer/admin presentation differences. This is a planned architectural decision, not an authorized refactor.

## Database source map

| Concern | Location |
|---|---|
| Schema evolution | `supabase/migrations/*.sql` |
| SQL regression tests | `supabase/tests/*.sql` |
| Edge Functions | `supabase/functions/<slug>/index.ts` |
| Shared Edge code | `supabase/functions/_shared/` |
| Local function config | `supabase/config.toml` |
| Historical schema prose | `doc/DATABASE_DOCUMENTATION.md` and production review appendices; currently stale. |

Never edit an old applied migration to change live behavior. Add a forward migration and a test.

## Generated and non-product artifacts

- Never hand-edit `.g.dart`, `.freezed.dart`, generated localization Dart, `.dart_tool/`, or `build/`.
- The customer repo currently tracks tool/agent artifacts such as `mcp_config.json`, `.zcode` content, screenshots, generated reports, and large raw outputs. They are not automatically product inputs.
- `all_code.txt`, analysis/build outputs, provider response samples, and screenshots can be stale or sensitive. Verify before using and avoid expanding them in Git.
- `android/app/google-services.json` is tracked although the structure map says it is untracked. This is a documented discrepancy.

## Large files / change risk

The largest handwritten product screens include:

- `sim_line_detail_screen.dart` — 3,605 lines.
- `onboarding_screen.dart` — 3,092 lines.
- `sim_line_form_screen.dart` — 2,704 lines.
- `dashboard_screen.dart` — 2,047 lines.
- `notification_settings_screen.dart` — 1,628 lines.

Prefer local extraction backed by focused tests when modifying these files. Do not undertake wholesale restructuring incidentally.
