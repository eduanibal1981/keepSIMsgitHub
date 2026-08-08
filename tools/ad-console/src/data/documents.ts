import type { PlanDocument } from '../domain/types';

const DOCS = 'doc/advertis System/docs';

/**
 * The plan as a file tree, with what is finished and what is not.
 *
 * Note on the duplicate tree: seven files also sit at `doc/advertis System/` root, outside
 * `docs/`. They are earlier manual copies, byte-identical to the `docs/` versions.
 * `docs/` is canonical (INDEX.md). This console reads the canonical paths only.
 */
export const PLAN_DOCUMENTS: PlanDocument[] = [
  // --- Governing files (Session 1; fixed decisions) -------------------------
  {
    id: 'index',
    group: 'governing',
    number: '—',
    title: 'Document index',
    path: `${DOCS}/INDEX.md`,
    status: 'fixed',
    summary: 'Map of the whole folder and the Session 1 / Session 2 split.',
    bytes: 4753,
  },
  {
    id: 'd00',
    group: 'governing',
    number: '00',
    title: 'Inputs required',
    path: `${DOCS}/00-inputs-required.md`,
    status: 'historical',
    summary:
      'The original missing-facts list. Items 1, 2, 3, 5, 8, 9, 13 were closed by pulling the production DB; 4 (budget) by the owner; the rest became V-tokens. Superseded by the verification register — kept for the record.',
    bytes: 4209,
  },
  {
    id: 'd03',
    group: 'governing',
    number: '03',
    title: 'Personas',
    path: `${DOCS}/03-personas.md`,
    status: 'fixed',
    summary:
      'Six segments with job-to-be-done, trigger, objection, plan assignment and two cheapest channels each. Digital nomads deferred to Phase 2.',
    bytes: 6727,
  },
  {
    id: 'd04',
    group: 'governing',
    number: '04',
    title: 'Corridors and coverage',
    path: `${DOCS}/04-corridors-and-coverage.md`,
    status: 'fixed',
    summary:
      'The coverage ground truth: corridor tiers from the live DB, the carrier matrix (min denomination vs keep-alive), the Premium hard-constraint list, and the Tier 3 re-entry checklist. Everything in the Countries view derives from this file.',
    bytes: 8746,
  },
  {
    id: 'd12',
    group: 'governing',
    number: '12',
    title: 'Compliance and claims',
    path: `${DOCS}/12-compliance-and-claims.md`,
    status: 'fixed',
    summary:
      'Principal-reseller structure, banned/preferred terms, Syria position, wallet characterisation (UAE/KSA), chargeback requirements, app-store IAP risk, ad-platform classification, data protection, prohibited claims.',
    bytes: 8562,
  },
  {
    id: 'brief',
    group: 'governing',
    number: '—',
    title: 'Creative brief',
    path: `${DOCS}/creative-brief.md`,
    status: 'fixed',
    summary:
      'The contract for all creative: messaging spine, per-segment angle/plan/language, Premium permission list, banned terms verbatim, tone rules, the 14-day refund as a conversion asset, language matrix, budget rule.',
    bytes: 7034,
  },
  {
    id: 'econ',
    group: 'governing',
    number: '—',
    title: 'Unit economics',
    path: `${DOCS}/unit-economics.md`,
    status: 'fixed',
    summary:
      'First-year value per segment, max CAC at 6-month payback (~$2.60 single-line), the verdict that cold paid social is unaffordable, and the <$5k/month budget rule.',
    bytes: 4218,
  },
  {
    id: 'register',
    group: 'governing',
    number: '—',
    title: 'Verification register',
    path: `${DOCS}/verification-register.md`,
    status: 'fixed',
    summary:
      'V1–V20 with owner and closing evidence. No session or asset may close a token — only real evidence does.',
    bytes: 5901,
  },

  // --- Sections written (Session 2, judgment-critical) ----------------------
  {
    id: 's00',
    group: 'section',
    number: '00',
    title: 'Handoff README',
    path: `${DOCS}/sections/00-HANDOFF-README.md`,
    status: 'done',
    summary: 'Read first in any new session: what is done, what remains, inherited non-negotiables.',
    bytes: 3496,
  },
  {
    id: 's06',
    group: 'section',
    number: '06',
    title: 'Competitor and alternative positioning',
    path: `${DOCS}/sections/06-competitor-and-alternative-positioning.md`,
    status: 'done',
    summary:
      'The seven real alternatives — doing nothing, family top-ups, carrier apps, top-up sites, remittance add-ons, eSIMs, roaming — with banned-terms-safe counter-lines and a reusable positioning matrix.',
    bytes: 5105,
  },
  {
    id: 's07',
    group: 'section',
    number: '07',
    title: 'Full funnel',
    path: `${DOCS}/sections/07-full-funnel.md`,
    status: 'done',
    summary:
      'Awareness → referral. Names the first-deposit cliff as the central conversion problem and threads multi-line attach through every stage.',
    bytes: 6494,
  },
  {
    id: 's08',
    group: 'section',
    number: '08',
    title: 'Channel strategy',
    path: `${DOCS}/sections/08-channel-strategy.md`,
    status: 'done',
    summary:
      'Community seeding and micro-creators get the depth (45%); Meta/Google/TikTok/Snap are retargeting-scoped only; Bahrain–Oman as creative test beds; channel × persona map.',
    bytes: 6604,
  },
  {
    id: 's09',
    group: 'section',
    number: '09',
    title: 'Campaign structure, budget, testing',
    path: `${DOCS}/sections/09-campaign-structure-budget-testing.md`,
    status: 'done',
    summary:
      'Campaign architecture, naming convention, envelope budgets at $5k, testing protocol, and the operationalised kill rule.',
    bytes: 4343,
  },
  {
    id: 's11',
    group: 'section',
    number: '11',
    title: 'Analytics, events, dashboard, KPIs',
    path: `${DOCS}/sections/11-analytics-events-dashboard-kpis.md`,
    status: 'done',
    summary:
      'The "protected active line" definition, a server-side event schema an engineer can implement, the KPI set, the weekly dashboard layout, and the attribution dependency.',
    bytes: 6841,
  },
  {
    id: 's13',
    group: 'section',
    number: '13',
    title: '30/60/90-day launch plan',
    path: `${DOCS}/sections/13-launch-plan-30-60-90.md`,
    status: 'done',
    summary:
      'The 90-day plan sequenced as a gate table against open V-tokens. This console’s gate engine is a direct transcription of that table.',
    bytes: 5342,
  },
  {
    id: 'flags',
    group: 'section',
    number: '—',
    title: 'Flags — concerns log',
    path: `${DOCS}/sections/flags.md`,
    status: 'seeded',
    summary: 'F1–F8 seeded. Append-only, below the marked line. Nothing here reopens a Session 1 decision.',
    bytes: 3119,
  },

  // --- Not written yet -----------------------------------------------------
  {
    id: 's01',
    group: 'deliverable',
    number: '01',
    title: 'Executive summary',
    path: `${DOCS}/sections/01-executive-summary.md`,
    status: 'pending',
    summary: 'Written LAST, leading with the economics reality.',
    bytes: 0,
  },
  {
    id: 's02',
    group: 'deliverable',
    number: '02',
    title: 'Product overview & value proposition',
    path: `${DOCS}/sections/02-product-overview.md`,
    status: 'pending',
    summary: 'PRD facts; pricing per creative-brief §9.',
    bytes: 0,
  },
  {
    id: 's05',
    group: 'deliverable',
    number: '05',
    title: 'Brand positioning & messaging framework',
    path: `${DOCS}/sections/05-messaging-framework.md`,
    status: 'pending',
    summary:
      'Expand creative-brief §1; reuse section 6’s positioning matrix without contradicting it.',
    bytes: 0,
  },
  {
    id: 's10',
    group: 'deliverable',
    number: '10',
    title: 'Landing-page strategy & CRO',
    path: `${DOCS}/sections/10-landing-pages-cro.md`,
    status: 'pending',
    summary:
      'First deposit is the optimisation target; cliff mechanics are defined in section 7 — build page-level detail on top, do not redefine them.',
    bytes: 0,
  },
  {
    id: 's14',
    group: 'deliverable',
    number: '14',
    title: 'Weekly operating checklist',
    path: `${DOCS}/sections/14-weekly-checklist.md`,
    status: 'pending',
    summary:
      'One page; must reference the section 9 test log, the kill-rule review, and the section 11 dashboard panels.',
    bytes: 0,
  },
  {
    id: 'creative-library',
    group: 'deliverable',
    number: '—',
    title: 'Creative library',
    path: `${DOCS}/creative-library.md`,
    status: 'pending',
    summary:
      '6 personas × (10 headlines, 10 primary texts, 5 CTAs, 5 image concepts, 5 carousel concepts, 5 video concepts) + 2 retargeting sets. Counts stated at the end of each persona block.',
    bytes: 0,
  },
  {
    id: 'video-scripts',
    group: 'deliverable',
    number: '—',
    title: 'Video scripts',
    path: `${DOCS}/video-scripts.md`,
    status: 'pending',
    summary: '≥3 scripts × 6 audience/language groups, with full production fields.',
    bytes: 0,
  },
  {
    id: 'seo-plan',
    group: 'deliverable',
    number: '—',
    title: 'SEO plan',
    path: `${DOCS}/seo-plan.md`,
    status: 'pending',
    summary: '12-month corridor-clustered calendar including Malayalam and Tagalog tracks.',
    bytes: 0,
  },
  {
    id: 'pdf',
    group: 'deliverable',
    number: '—',
    title: 'PDF assembly',
    path: `${DOCS}/KeepSIMs-Advertising-Plan.pdf`,
    status: 'pending',
    summary: 'Per the FORMAT spec, only after every section exists.',
    bytes: 0,
  },
];

/** Sections 3 and 4 in the numbering are the governing files 03/04; there is no gap. */
export const DUPLICATE_TREE_NOTE =
  'Seven files also sit at `doc/advertis System/` root, outside `docs/` — earlier manual copies, byte-identical to the `docs/` versions. `docs/` is canonical. Consider deleting the root copies so there is one source of truth.';
