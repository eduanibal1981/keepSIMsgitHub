---
name: keepsims-memory
description: >-
  On-demand index and router for KeepSIMs project memory, architectural rules,
  business invariants, database/security contracts, implementation plans, and
  cross-machine handoff state (Windows <-> Mac). Activate this skill whenever
  starting a task, resuming from a handoff, or needing domain/architecture context.
---

# KeepSIMs Project Memory & Knowledge Router

Instead of loading all project documentation into `AGENTS.md` on every turn, use `view_file` to load **only the specific document(s) relevant to your current task** from the index below.

---

## 1. Cross-Machine Handoff State (Windows ↔️ Mac)

* **[`.agents/memory/ACTIVE_HANDOFF.md`](../../memory/ACTIVE_HANDOFF.md)**
  * **When to read**: Whenever the user says `"Resume from @.agents/memory/ACTIVE_HANDOFF.md"`, or at the start of a new session after switching machines.
  * **When to update**: Whenever the user says `"Save handoff state"` (or before switching between Windows and Mac), update this file with current progress, modified/untracked files, and exact next steps.

---

## 2. Core Authoritative Knowledge Base (`.codex/`)

Read these selectively based on the domain you are modifying:

| File | When to Load |
| :--- | :--- |
| **[`.codex/AI_AGENT_GUIDE.md`](../../../.codex/AI_AGENT_GUIDE.md)** | Mandatory pre-flight checklist before modifying code, financial paths, auth/RLS, or running SQL tests via MCP. |
| **[`.codex/SYSTEM_ARCHITECTURE.md`](../../../.codex/SYSTEM_ARCHITECTURE.md)** | Understanding client/server boundaries, trust model, Edge Functions, and Node worker workflows. |
| **[`.codex/BUSINESS_RULES.md`](../../../.codex/BUSINESS_RULES.md)** | Modifying SIM protection, carrier intervals, tier pricing, refills, wallet debits/credits, calling, or alerts. |
| **[`.codex/DATA_BACKEND_SECURITY.md`](../../../.codex/DATA_BACKEND_SECURITY.md)** | Writing SQL migrations, `SECURITY DEFINER` RPCs, RLS policies, grants, or Edge Function authentication. |
| **[`.codex/PROJECT_MAP.md`](../../../.codex/PROJECT_MAP.md)** | Locating features, shared files between `keep_sims` and `keep_sims_admin`, and backend entrypoints. |
| **[`.codex/CURRENT_STATUS_AND_ROADMAP.md`](../../../.codex/CURRENT_STATUS_AND_ROADMAP.md)** | Checking verified implementation status, known drift, or production readiness blockers. |
| **[`.codex/ARCHITECTURAL_DECISIONS.md`](../../../.codex/ARCHITECTURAL_DECISIONS.md)** | Resolving contradictions between legacy plans and current production architecture. |

---

## 3. Distilled Task Memories (`.agents/memory/`)

Extracted from prior Antigravity sessions so you never need `~/.gemini/antigravity/brain/` across machines:

* **[`2026-09-26_phase0_baseline_and_contract_map.md`](../../memory/2026-09-26_phase0_baseline_and_contract_map.md)** — Live DB schema drift audit, carrier rules telemetry, notification delivery states, and WhatsApp routing baseline.
* **[`2026-09-24_virtual_numbers_and_mmi_divert_walkthrough.md`](../../memory/2026-09-24_virtual_numbers_and_mmi_divert_walkthrough.md)** — Virtual DID purchasing (`manage-dids`), `intelcallfee` markup, and real-carrier MMI call forwarding codes across 22 countries.
* **[`2026-09-24_virtual_numbers_and_mmi_divert_plan.md`](../../memory/2026-09-24_virtual_numbers_and_mmi_divert_plan.md)** — Implementation plan for Virtual Numbers & Smart Call setup.
* **[`2026-09-24_app_to_app_voice_calling_walkthrough.md`](../../memory/2026-09-24_app_to_app_voice_calling_walkthrough.md)** — Production-grade App-to-App WebRTC/VoIP voice calling architecture and fixes.
* **[`2026-09-23_smart_calling_restructure_walkthrough.md`](../../memory/2026-09-23_smart_calling_restructure_walkthrough.md)** — Smart Calling 3-page restructure and remediation details.

---

## 4. Feature Implementation Plans & Reviews (`docs/`)

* **Implementation Plans**: `docs/implementation-plans/` (alert channels, auto-refill resilience, multi-currency display, WhatsApp country routing, smart calling, notification readiness).
* **Code & Architecture Reviews**: `docs/reviews/` (verification reports and reproduction scripts).
* **QA Checklists**: `docs/qa/00_EXECUTIVE_INDEX.md` through `13_auth_notifications.md`.
