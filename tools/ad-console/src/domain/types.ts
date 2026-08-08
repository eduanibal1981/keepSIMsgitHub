/**
 * Domain types for the KeepSIMs advertising console.
 *
 * Every value in `src/data` traces back to a file under `doc/advertis System/docs/`.
 * The `source` field on each record names that file so nothing here is unattributable.
 */

/** Path to the markdown file a record was transcribed from. */
export type SourceRef = string;

// ---------------------------------------------------------------------------
// Verification tokens (verification-register.md)
// ---------------------------------------------------------------------------

export type TokenState = 'open' | 'closed';

export interface VerificationToken {
  id: string; // V1 … V20
  question: string;
  owner: string;
  closedBy: string; // the evidence that is allowed to close it
  /** Baseline from the register as written. The admin can close it in-app with evidence. */
  defaultState: TokenState;
  /** Pre-existing closure note recorded in the register itself. */
  registerNote?: string;
  source: SourceRef;
}

// ---------------------------------------------------------------------------
// Capabilities and gates (13-launch-plan-30-60-90.md gate table)
// ---------------------------------------------------------------------------

/** The distinct things the advertising system can be permitted (or not) to do. */
export type Capability =
  | 'organic_creative' // community/organic assets in the origin corridor
  | 'paid_media' // any paid spend on any platform
  | 'premium_creative' // assets that sell the Premium auto-mini-refill plan
  | 'non_english_scale' // non-English creative beyond a caveated pilot
  | 'conversion_cta' // deposit-dependent calls to action
  | 'referral' // referral program promotion
  | 'b2b_claims'; // SME / fleet promises

export const CAPABILITIES: Capability[] = [
  'organic_creative',
  'paid_media',
  'premium_creative',
  'non_english_scale',
  'conversion_cta',
  'referral',
  'b2b_claims',
];

export interface GateScope {
  /** 'global' applies to every corridor; otherwise the listed origin-country ids. */
  kind: 'global' | 'countries';
  countries?: string[];
}

export interface Gate {
  id: string;
  label: string;
  /** Verification-register token this gate waits on, when there is one. */
  token?: string;
  /** Gates with no token are internal build gates (e.g. attribution capture). */
  internal?: boolean;
  blocks: Capability[];
  scope: GateScope;
  /** What the plan permits while the gate is still shut. */
  interim: string;
  source: SourceRef;
}

// ---------------------------------------------------------------------------
// Coverage (04-corridors-and-coverage.md)
// ---------------------------------------------------------------------------

export type CatalogSource = 'production_cache' | 'sandbox_pinned' | 'cache_suspect';

export interface Carrier {
  name: string;
  live: boolean;
  /** Lowest purchasable retail price in USD. */
  minDenominationUsd: number | null;
  /** `recommended_topup_amount` from carrier_rules — operational estimate, not carrier-verified. */
  keepAliveUsd: number | null;
  /** min denomination <= keep-alive. Drives the Premium verdict. */
  miniRefillViable: boolean;
  catalogSource: CatalogSource;
  /** Carrier prepaid policy sourced and date-stamped (V3). */
  policyVerified: boolean;
  /** One live end-to-end test top-up receipted (V4). */
  testTopupDone: boolean;
  notes?: string;
  /** Token ids that specifically encumber this carrier row. */
  tokens?: string[];
}

export type PremiumPolicy =
  | 'eligible' // 04 hard list: advertise Premium here
  | 'eligible_partial' // some carriers only
  | 'blocked_economics' // min denomination exceeds keep-alive; the mini promise breaks
  | 'blocked_pending_catalog' // reopens if/when the catalog changes (India / DTone)
  | 'not_live';

export type CoverageState = 'live' | 'none';

export type CorridorTier = '1-volume' | '1-premium-proof' | '2' | '3-not-live';

export interface CorridorEconomics {
  refillsPerYear: number;
  typicalRefillUsd: string;
  standardContributionUsd: string;
  premiumContributionUsd: string | null;
  /** Inactivity window as operated today — never state to users as fact (V3). */
  windowNote: string;
}

export interface OriginCountry {
  id: string;
  name: string;
  flag: string;
  coverage: CoverageState;
  tier: CorridorTier;
  premiumPolicy: PremiumPolicy;
  /** Carriers on which Premium may be named, when premiumPolicy is partial. */
  premiumCarriers: string[];
  carriers: Carrier[];
  economics: CorridorEconomics | null;
  /** What the number unlocks — creative-brief §1. Nothing outside this list may be claimed. */
  identityHooks: string[];
  /** Residence markets where this corridor's ads run. */
  residenceMarkets: string[];
  personaIds: number[];
  languages: string[];
  leadPlan: string;
  /** Channels this corridor actually uses (08-channel-strategy). */
  channels: string[];
  /** Things that are true and shippable today for this corridor. */
  approvedPromises: string[];
  /** Corridor-specific prohibitions on top of the global banned list. */
  corridorProhibitions: string[];
  /** Free-text situation note for the admin. */
  adminNote: string;
  source: SourceRef;
}

export interface ResidenceMarket {
  id: string;
  name: string;
  flag: string;
  role: 'primary' | 'test_bed';
  localCarriers: string;
  localSimPromiseAllowed: boolean;
  paymentRisk: boolean; // V9 — PayPal/Stripe consumer availability
  note: string;
  source: SourceRef;
}

// ---------------------------------------------------------------------------
// Plan artefacts
// ---------------------------------------------------------------------------

export type DocStatus = 'fixed' | 'done' | 'seeded' | 'pending' | 'historical';

export interface PlanDocument {
  id: string;
  group: 'governing' | 'section' | 'deliverable';
  number: string;
  title: string;
  path: string;
  status: DocStatus;
  summary: string;
  /** Bytes on disk; 0 for documents that do not exist yet. */
  bytes: number;
}

export type WorkStatus = 'done' | 'in_progress' | 'not_started' | 'blocked';

export interface WorkItem {
  id: string;
  category: 'writing' | 'engineering' | 'ops' | 'legal';
  title: string;
  detail: string;
  defaultStatus: WorkStatus;
  owner: string;
  /** Gate ids or token ids this item unblocks when finished. */
  unblocks: string[];
  source: SourceRef;
}

export interface Persona {
  id: number;
  name: string;
  residence: string;
  jobToBeDone: string;
  trigger: string;
  objection: string;
  plan: string;
  channels: string[];
  languages: string[];
  originCountries: string[];
  source: SourceRef;
}

export interface Flag {
  id: string;
  title: string;
  body: string;
  source: SourceRef;
}

export interface BudgetEnvelope {
  share: number;
  use: string;
  constraint: string;
}

export interface TermRule {
  banned: string;
  preferred: string;
}
