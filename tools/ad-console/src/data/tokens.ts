import type { VerificationToken } from '../domain/types';

const SRC = 'doc/advertis System/docs/verification-register.md';

/**
 * V1–V20 transcribed from the verification register.
 *
 * Register rule, carried into this app: "No session or asset may close a token — only
 * real evidence does." The UI therefore refuses to mark a token closed without an
 * evidence note, and records who closed it and when.
 */
export const TOKENS: VerificationToken[] = [
  {
    id: 'V1',
    question:
      'Production Zendit catalog for India — are small denominations (₹10–99 equiv.) available? Cache shows sandbox-pinned rows: Jio $17 min, Airtel $9 min.',
    owner: 'Product/eng (abdalla)',
    closedBy:
      'Production API pull of /offers for IN; refreshed zendit_offers_cache; if small denoms exist, re-run the 04 India verdict.',
    defaultState: 'open',
    source: SRC,
  },
  {
    id: 'V2',
    question:
      'All sandbox-pinned carrier_rules rows (notes contain "pinned from Zendit sandbox catalog"): VODAFONEIDEA_IN_7_FEE, ZONG_PK_OPEN, ETISALAT_EG_001, plus US/TR rows.',
    owner: 'Product/eng',
    closedBy: 'Same production pull; last_verified_at updated.',
    defaultState: 'open',
    source: SRC,
  },
  {
    id: 'V3',
    question:
      'Every carrier inactivity_limit_days / grace_period_days in carrier_rules — all 49 rows have last_verified_at null or sandbox-dated.',
    owner: 'Ops',
    closedBy: 'Archived link/screenshot of the carrier policy per row; date-stamped.',
    defaultState: 'open',
    source: SRC,
  },
  {
    id: 'V4',
    question:
      'Keep-alive amount per carrier — does the minimum reactivating top-up equal recommended_topup_amount?',
    owner: 'Ops',
    closedBy: 'Same as V3; also one live test top-up per Tier 1 carrier.',
    defaultState: 'open',
    source: SRC,
  },
  {
    id: 'V5',
    question: 'Coverage via any aggregator for Lebanon, Nepal, Iraq, Syria.',
    owner: 'Founder / BD',
    closedBy:
      'Signed aggregator scope + carriers/rules/offers rows live in production DB (04 re-entry checklist).',
    defaultState: 'open',
    source: SRC,
  },
  {
    id: 'V6',
    question: 'App-store live regions — exact Apple + Google storefronts.',
    owner: 'Founder',
    closedBy:
      'App Store Connect / Play Console screenshots; ad geo-targeting limited to this list.',
    defaultState: 'open',
    source: SRC,
  },
  {
    id: 'V7',
    question:
      'Apple/Google IAP treatment of (a) wallet deposits (b) Premium purchase (c) base fee.',
    owner: 'Counsel + founder',
    closedBy:
      'Written counsel opinion or App Review correspondence; until closed, no "0% fees" in store copy.',
    defaultState: 'open',
    source: SRC,
  },
  {
    id: 'V8',
    question:
      'Who bears deposit gateway fees (PayPal 3.4%+$0.49 / Stripe 4.5%+$0.30) — user or KeepSIMs?',
    owner: 'Product',
    closedBy: 'Pricing engine config + checkout screenshot; unit-economics adjusts if absorbed.',
    defaultState: 'open',
    source: SRC,
  },
  {
    id: 'V9',
    question:
      'PayPal and Stripe consumer availability/acceptance in Saudi Arabia, Qatar, Kuwait — PayPal consumer coverage there is historically limited.',
    owner: 'Founder',
    closedBy:
      'Successful live deposit from each market or gateway documentation; if blocked, add a local method (mada, STC Pay…) before advertising that market.',
    defaultState: 'open',
    source: SRC,
  },
  {
    id: 'V10',
    question: 'BASE_SERVICE_FEE_USD conflict between PRD and system_configs.',
    owner: 'Founder',
    closedBy: 'Done.',
    defaultState: 'closed',
    registerNote: 'CLOSED 2026-07-19: owner reset system_configs to $2.50; PRD and DB now agree.',
    source: SRC,
  },
  {
    id: 'V11',
    question: 'Premium plan retail price per corridor — derived, not yet a published price.',
    owner: 'Founder',
    closedBy: 'Published price card; unit-economics Premium rows re-checked.',
    defaultState: 'open',
    source: SRC,
  },
  {
    id: 'V12',
    question:
      'Egypt Vodafone rule row — 86-day validity, 0-day grace, no keep-alive amount — anomalous vs other EG carriers.',
    owner: 'Ops',
    closedBy: 'Carrier policy source; corrected row.',
    defaultState: 'open',
    source: SRC,
  },
  {
    id: 'V13',
    question: 'Syria SST (State Sponsor of Terrorism) designation status.',
    owner: 'Counsel',
    closedBy: 'Current designation list citation; 12-compliance updated.',
    defaultState: 'open',
    source: SRC,
  },
  {
    id: 'V14',
    question:
      'Financial-services ad category rulings for actual KeepSIMs creative on Meta, TikTok, Snapchat, Google.',
    owner: 'Marketing',
    closedBy: 'Platform pre-review outcomes per platform.',
    defaultState: 'open',
    source: SRC,
  },
  {
    id: 'V15',
    question: 'In-app locale support — which of the creative-brief languages the app ships.',
    owner: 'Product',
    closedBy: 'Build locale list; language matrix trimmed or expectation-set.',
    defaultState: 'open',
    source: SRC,
  },
  {
    id: 'V16',
    question:
      'B2B invoicing, VAT compliance, volume pricing exist before any SME promise ships.',
    owner: 'Founder',
    closedBy: 'Working invoice flow, or removal of B2B claims from launch assets.',
    defaultState: 'open',
    source: SRC,
  },
  {
    id: 'V17',
    question:
      'Referral program mechanics + wallet-credit incentive legality under the wallet non-transferability rule.',
    owner: 'Counsel + product',
    closedBy: 'Counsel note + implemented referral flow (referrals table currently empty).',
    defaultState: 'open',
    source: SRC,
  },
  {
    id: 'V18',
    question:
      'Saudi-Zain, Saudi-Mobily, Kuwait (3 carriers), Oman (2 carriers) — configured but zero offers; fulfillable or not?',
    owner: 'Product/eng',
    closedBy: 'Production catalog pull; 04 residence-market table updated.',
    defaultState: 'open',
    source: SRC,
  },
  {
    id: 'V19',
    question:
      'DTone integration live — Zendit is a test account and DTone will be added; DT Shop pricelist shows India 10 INR top-ups at ~$0.12 cost, which would flip India’s Premium verdict.',
    owner: 'Product/eng (abdalla)',
    closedBy:
      'dt_country/dt_carrier mapped in carriers, DTone offers cached, DTone wallet funded, one live test top-up per Indian carrier; then re-run 04 and unit-economics for India.',
    defaultState: 'open',
    source: SRC,
  },
  {
    id: 'V20',
    question:
      'DTone pricelist export (CSV) for all 10 origin markets — interim evidence ahead of full integration; includes MTNL India, absent from the current carriers table.',
    owner: 'Founder',
    closedBy: 'CSV uploaded and the 04 matrix rebuilt with a DTone column.',
    defaultState: 'open',
    source: SRC,
  },
];

export const TOKEN_BY_ID: Record<string, VerificationToken> = Object.fromEntries(
  TOKENS.map((t) => [t.id, t]),
);
