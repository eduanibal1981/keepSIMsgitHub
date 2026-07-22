# KeepSIMs Core — Full Advertising Plan: Document Index

Working folder for the two-session advertising plan. Session 1 (strategy, Claude Fable 5) is complete; Session 2 (volume generation, Claude Opus 4.8) picks up from `sections/00-HANDOFF-README.md`. All facts are grounded in the production database (simSaveDB) as of 2026-07-19.

## Session 1 — governing files (fixed decisions; Session 2 must not alter)

| File | What it is |
|---|---|
| `00-inputs-required.md` | The original missing-facts list, with a status header showing which items were closed by pulling the production DB and which remain open as V-tokens. Historical record — the verification register supersedes it. |
| `03-personas.md` | The six target segments (Indian professional, South Asian blue-collar, Filipino OFW, Egyptian professional, multi-line family manager, SME/fleet) with job-to-be-done, trigger, objection, plan assignment, and two cheapest channels each. Digital nomads deferred to Phase 2. |
| `04-corridors-and-coverage.md` | The coverage ground truth: corridor tiers rebuilt from the live DB, the full carrier matrix (min denomination vs keep-alive → mini-refill viability), the Premium hard-constraint list, and the Tier 3 re-entry checklist. The plan's single most decision-heavy file. |
| `unit-economics.md` | First-year value per segment, max CAC at 6-month payback (~$2.60 single-line), the verdict that cold paid social is unaffordable, and the <$5k/month budget rule (45/20/20/15) every other file obeys. |
| `12-compliance-and-claims.md` | Principal-reseller structure, banned/preferred terms, Syria current position, wallet characterization (UAE/KSA), chargeback requirements, app-store IAP risk, ad-platform classification, data-protection notes, prohibited claims. |
| `creative-brief.md` | **The contract for all creative.** Messaging spine ("your number is your key"), per-segment angle/plan/language assignments, Premium permission list, banned terms verbatim, tone rules, 14-day refund as conversion asset, language matrix, budget rule. |
| `verification-register.md` | All open [VERIFY] tokens (V1–V20) with owner and closing evidence, including the DTone integration gate (V19/V20). No session or asset may close a token — only real evidence does. |

## sections/ — Session 2 build (judgment-critical sections done; volume sections pending)

| File | What it is |
|---|---|
| `sections/00-HANDOFF-README.md` | **Read first in any new session.** What's done, what remains (sections 1, 2, 5, 10, 14, creative library, video scripts, SEO plan, PDF assembly), and the inherited non-negotiables. |
| `sections/06-competitor-and-alternative-positioning.md` | Positioning against the seven real alternatives (doing nothing, family top-ups, carrier apps, top-up sites, remittance add-ons, eSIMs, roaming) with banned-terms-safe counter-lines and a reusable positioning matrix. |
| `sections/07-full-funnel.md` | Awareness → referral funnel; names the first-deposit cliff as the central conversion problem and threads multi-line attach (the economic engine) through every stage. |
| `sections/08-channel-strategy.md` | The channel plan weighted per the economics: community seeding and micro-creators (45%) get the depth; Meta/Google/TikTok/Snap are retargeting-scoped only; Bahrain–Oman as creative test beds; channel × persona map. |
| `sections/09-campaign-structure-budget-testing.md` | Campaign architecture, naming convention, envelope budgets at $5k, the testing protocol, and the operationalized kill rule (2× max CAC for two weeks = stopped). |
| `sections/11-analytics-events-dashboard-kpis.md` | Precise "protected active line" definition, the full server-side event schema an engineer can implement, KPI set, weekly dashboard layout, and the attribution dependency flag. |
| `sections/13-launch-plan-30-60-90.md` | The 90-day plan sequenced as a gate table against open V-tokens — nothing ships that depends on an unclosed token; tracking is a week-one gate for all paid spend. |
| `sections/flags.md` | Running concerns log (F1–F8: attribution gate, GCC payments risk, thin single-line economics, Premium price gap V11, DTone timing, refund-rate baseline, community measurability, Zendit test-account caveat). Append-only. |

## Still to be produced (by the Session 2 agent)

Sections 1 (exec summary — written last), 2 (product overview), 5 (messaging framework), 10 (landing pages/CRO), 14 (weekly checklist), plus `creative-library.md`, `video-scripts.md`, `seo-plan.md`, `flags.md` additions, and final PDF assembly.

---
*Note: the seven files at the folder root (outside `docs/`) are earlier manual copies, byte-identical to the `docs/` versions at time of indexing. Treat `docs/` as canonical going forward.*
