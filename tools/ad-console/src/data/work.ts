import type { WorkItem } from '../domain/types';

const S11 = 'doc/advertis System/docs/sections/11-analytics-events-dashboard-kpis.md';
const S13 = 'doc/advertis System/docs/sections/13-launch-plan-30-60-90.md';
const S08 = 'doc/advertis System/docs/sections/08-channel-strategy.md';

/**
 * Functionality the plan depends on, and whether it exists.
 *
 * `defaultStatus` is what the plan documents assert as of the last session — it is NOT a
 * verification against the codebase. Tick items off in the console as they land; the
 * attribution item feeds the G-ATTRIB gate directly and therefore unblocks paid media.
 */
export const WORK_ITEMS: WorkItem[] = [
  // --- Engineering: week-one launch gates ----------------------------------
  {
    id: 'G-ATTRIB',
    category: 'engineering',
    title: 'Attribution capture live (attribution_source, UTM, promo codes)',
    detail:
      'Every landing-page link carries UTM + corridor code; registration stores attribution_source from install referrer (Android) / deferred link; referral and partner promo codes attribute community and partnership sources. Without this the kill rule and the north star are both unmeasurable — flags F1 calls it a launch gate, not a task.',
    defaultStatus: 'not_started',
    owner: 'Engineering',
    unblocks: ['Paid media in every corridor'],
    source: S13,
  },
  {
    id: 'W-EVENTS',
    category: 'engineering',
    title: 'Server-side event schema implemented (16 events)',
    detail:
      'lp_view, app_install, registration_completed, line_added, deposit_started/succeeded/failed, refill_succeeded, refill_failed_refunded, scheduled_refill_enabled, premium_purchased, line_protected, line_protection_lost, deposit_refund_requested/refunded, referral_registered/converted, alert_prefs_updated. Emitted from backend/edge functions, not the client.',
    defaultStatus: 'not_started',
    owner: 'Engineering',
    unblocks: ['Weekly dashboard', 'Kill-rule enforcement'],
    source: S11,
  },
  {
    id: 'W-PROTECTED-VIEW',
    category: 'engineering',
    title: 'Protected-active-line SQL view + nightly derivation job',
    detail:
      'A line is protected when it is not Expired AND a funded mechanism covers it (scheduled refill with sufficient wallet balance, or an active Premium plan) AND the last execution is not an unrecovered failure. Keep the definition in one SQL view so "protected" cannot drift between the dashboard and the ads.',
    defaultStatus: 'not_started',
    owner: 'Engineering',
    unblocks: ['North-star metric: cost per protected active line'],
    source: S11,
  },
  {
    id: 'W-DASHBOARD',
    category: 'engineering',
    title: 'Weekly dashboard (6 panels, in order)',
    detail:
      'Header band (cost per protected line, protected lines, multi-line attach) · funnel bar with the deposit cliff emphasised · envelope table with kill-rule status · corridor split (Premium purchases should only ever show PK/BD/EG) · trust panel (deposit failure by gateway × market, 14-day refund rate) · referral panel. Layout is the requirement; the BI tool is not.',
    defaultStatus: 'not_started',
    owner: 'Engineering / analytics',
    unblocks: ['Weekly operating rhythm (section 14)'],
    source: S11,
  },
  {
    id: 'W-CONSENT',
    category: 'engineering',
    title: 'Pre-purchase consent capture + receipting + delivery evidence',
    detail:
      'Explicit acknowledgment of the 14-day refund rule and instant-delivery nature, logged with timestamp at first deposit and first refill; receipts naming amount, line, carrier, delivery status; archived aggregator delivery confirmations as the representment file; KEEPSIMS card descriptor. Required at build, not later — card schemes do not defer to "non-refundable" terms.',
    defaultStatus: 'not_started',
    owner: 'Engineering + counsel',
    unblocks: ['Chargeback defensibility'],
    source: 'doc/advertis System/docs/12-compliance-and-claims.md',
  },

  // --- Ops / marketing -----------------------------------------------------
  {
    id: 'W-COMMUNITY-MAP',
    category: 'ops',
    title: 'Community mapping doc — 20 groups per corridor',
    detail:
      'Kerala/Malayali associations, Tamil and Telugu associations, Pakistani welfare associations, Bangladeshi community groups, OFW Facebook groups per emirate/city, Filipino church and hometown associations, Egyptian professional syndicate networks. Living document. Admin outreach is value-first, no promotion at first contact.',
    defaultStatus: 'not_started',
    owner: 'Marketing',
    unblocks: ['45% community envelope'],
    source: S08,
  },
  {
    id: 'W-PLATFORM-REVIEW',
    category: 'ops',
    title: 'Submit one representative creative per platform for policy pre-review',
    detail:
      'Meta, TikTok, Snapchat, Google. Wallet + prepaid-credit language will likely trip financial-services classification. Days 1–5 activity; closes V14 per platform.',
    defaultStatus: 'not_started',
    owner: 'Marketing',
    unblocks: ['V14', 'Paid media'],
    source: S13,
  },
  {
    id: 'W-LANDING-PAGES',
    category: 'ops',
    title: 'Landing pages: SIM-protection + multi-line/family',
    detail:
      'English plus one per Tier 1 corridor language as locales allow, built to the Guide §7 order, with the 14-day-refund line at the deposit explanation.',
    defaultStatus: 'not_started',
    owner: 'Marketing',
    unblocks: ['Section 10 CRO work'],
    source: S13,
  },
  {
    id: 'W-TEST-TOPUPS',
    category: 'ops',
    title: 'Live test top-up per Tier 1 carrier, receipted',
    detail:
      'All current fulfilment data comes from an account the owner describes as test-only (flags F8). Every live top-up assumption inherits that caveat until a production transaction is receipted. Closes the V4 half of the carrier data problem.',
    defaultStatus: 'not_started',
    owner: 'Ops',
    unblocks: ['V4', 'Confidence in every keep-alive figure'],
    source: 'doc/advertis System/docs/verification-register.md',
  },
  {
    id: 'W-CARRIER-POLICY',
    category: 'ops',
    title: 'Source and date-stamp carrier prepaid policy for all 49 rules rows',
    detail:
      'Every carrier_rules row has last_verified_at null or sandbox-dated. Until sourced, no asset may state an inactivity threshold, grace period, or reactivation rule as fact.',
    defaultStatus: 'not_started',
    owner: 'Ops',
    unblocks: ['V3', 'Any copy that gets specific about carrier timing'],
    source: 'doc/advertis System/docs/verification-register.md',
  },

  // --- Legal / founder -----------------------------------------------------
  {
    id: 'W-IAP-OPINION',
    category: 'legal',
    title: 'Written position on IAP treatment of wallet deposits',
    detail:
      'Apple 3.1.1 vs the 3.1.5(a) carve-out, and the Google Play equivalent, for (a) wallet deposits (b) Premium purchase (c) base fee. If deposits are treated as IAP at 15–30%, the "0% gateway fees" positioning and the whole margin model break.',
    defaultStatus: 'not_started',
    owner: 'Counsel + founder',
    unblocks: ['V7', '"0% fees" language in store copy'],
    source: 'doc/advertis System/docs/12-compliance-and-claims.md',
  },
  {
    id: 'W-PREMIUM-PRICE',
    category: 'legal',
    title: 'Publish the Premium price card',
    detail:
      'Quietly on the critical path: the blue-collar Premium pitch requires quoting the real yearly price (creative-brief §2), so Premium creative cannot ship anywhere — including the PK/BD/EG corridors that are otherwise permitted — until this exists (flags F4).',
    defaultStatus: 'not_started',
    owner: 'Founder',
    unblocks: ['V11', 'Premium creative in PK, BD, EG-Vodafone/Etisalat'],
    source: 'doc/advertis System/docs/sections/flags.md',
  },
  {
    id: 'W-GCC-DEPOSIT-TEST',
    category: 'legal',
    title: 'Live consumer deposit test from Saudi, Qatar, Kuwait',
    detail:
      'PayPal consumer coverage in Saudi and Qatar is historically limited. If live deposits fail, the two largest residence markets cannot convert regardless of creative quality, and a local method (mada / STC Pay class) becomes a launch prerequisite (flags F2).',
    defaultStatus: 'not_started',
    owner: 'Founder',
    unblocks: ['V9', 'Deposit-dependent CTAs in KSA/QA/KW'],
    source: 'doc/advertis System/docs/sections/flags.md',
  },
  {
    id: 'W-REFERRAL-COUNSEL',
    category: 'legal',
    title: 'Referral mechanics + counsel note on wallet-credit incentives',
    detail:
      'Wallet credit is issued by KeepSIMs, never transferred between users — that distinction is what keeps the wallet outside e-money characterisation. The referrals table is currently empty.',
    defaultStatus: 'not_started',
    owner: 'Counsel + product',
    unblocks: ['V17', 'Referral launch (OFW segment first)'],
    source: 'doc/advertis System/docs/verification-register.md',
  },
];
