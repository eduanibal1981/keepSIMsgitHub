import type { BudgetEnvelope, Flag, Persona, TermRule } from '../domain/types';

const P = 'doc/advertis System/docs/03-personas.md';
const F = 'doc/advertis System/docs/sections/flags.md';
const C = 'doc/advertis System/docs/12-compliance-and-claims.md';

export const PERSONAS: Persona[] = [
  {
    id: 1,
    name: 'Indian white-collar professional',
    residence: 'UAE / Saudi',
    jobToBeDone:
      'Keep the India number that anchors UPI, Aadhaar-linked services, bank OTPs, DigiLocker and tax access alive without thinking about it.',
    trigger:
      'An OTP that never arrives — bank login, UPI payment, Aadhaar update — or a recharge-validity SMS noticed too late; annual India trip planning.',
    objection:
      '"My carrier’s own app / a relative topping up already covers this — why pay a service fee?"',
    plan: 'Standard + scheduled refills. Highest ARPU via multi-line attach, not via Premium.',
    channels: [
      'Kerala/Tamil/Telugu diaspora WhatsApp and Facebook associations (Malayalam first-class)',
      'Referral from existing users',
    ],
    languages: ['English', 'Hindi', 'Malayalam', 'Tamil', 'Telugu'],
    originCountries: ['india'],
    source: P,
  },
  {
    id: 2,
    name: 'South Asian blue-collar worker',
    residence: 'Saudi / Qatar / UAE',
    jobToBeDone:
      'Keep the home number tied to bKash (BD) / Raast, JazzCash, NADRA verification (PK) and the family’s ability to reach them; spend as little as possible doing it.',
    trigger:
      'Hearing a co-worker lost his number and with it his mobile-wallet access; camp/dorm word-of-mouth; a SIM lapsed during a two-year stint without home leave.',
    objection:
      'Any upfront cost feels large; distrust of app payments; "I’ll just have my brother recharge it."',
    plan: 'Premium auto-mini-refill for PK and BD SIMs — the flagship Premium segment. Indian labour segment: Standard.',
    channels: [
      'WhatsApp community seeding via camp/compound influencers and remittance-queue promoters',
      'Exchange-house and hypermarket partnerships (poster + QR at the remittance counter)',
    ],
    languages: ['Urdu', 'Bengali'],
    originCountries: ['pakistan', 'bangladesh', 'india'],
    source: P,
  },
  {
    id: 3,
    name: 'Filipino OFW',
    residence: 'Across the GCC',
    jobToBeDone:
      'Protect the Philippine number registered under the SIM Registration Act and tied to GCash; keep the family’s reload routine organised.',
    trigger:
      'GCash locked behind an unreachable number; deregistration warnings; a fellow OFW’s horror story in a Facebook group.',
    objection:
      '"I already reload through my remittance app / sari-sari channels — what does this add?" Answer: monitoring + automation + multi-line, not the reload itself.',
    plan: 'Standard + scheduled refills + multi-line. Position scheduled refills as "set your reload day once."',
    channels: [
      'OFW Facebook groups and community organisations',
      'Referral — highest propensity of all six segments; give this segment the program first',
    ],
    languages: ['Tagalog', 'English'],
    originCountries: ['philippines'],
    source: P,
  },
  {
    id: 4,
    name: 'Egyptian professional',
    residence: 'GCC',
    jobToBeDone:
      'Keep the Egyptian number that receives bank OTPs and anchors WhatsApp identity and account recovery; recovery requires physical presence in Egypt, which may be a year away.',
    trigger:
      'Bank app re-verification fails abroad; Vodafone Cash access; a lapsed line discovered during Eid calls home.',
    objection:
      'Scepticism toward paying for something a cousin in Cairo "can just do"; sensitivity to being sold a subscription.',
    plan: 'Premium for Vodafone/Etisalat SIMs; Standard for Orange/WE. Carrier-aware creative mandatory.',
    channels: [
      'Egyptian expat Facebook groups in Saudi/Kuwait/UAE — Egyptian-dialect Arabic only',
      'Referral through workplace networks (medicine, engineering, education)',
    ],
    languages: ['Egyptian-dialect Arabic'],
    originCountries: ['egypt'],
    source: P,
  },
  {
    id: 5,
    name: 'Multi-line family manager',
    residence: 'Any residence market',
    jobToBeDone:
      'One person keeps parents’, spouse’s and relatives’ home-country numbers alive from one dashboard and one wallet.',
    trigger:
      'A parent’s number lapses because "someone forgot"; the mental load of tracking three carriers’ validity dates.',
    objection:
      '"Adding four lines = four fees" — $10/yr must be framed as less than one delivery meal for a year of the whole family’s numbers.',
    plan: 'Standard multi-line + scheduled refills; mixed-origin households get Premium only on eligible lines. The economics segment — max CAC ~$10.50.',
    channels: [
      'Upsell inside the product to every active single-line user (zero CAC)',
      'Family-framed WhatsApp shares — "who keeps your parents’ numbers alive?" referral cards',
    ],
    languages: ['Follows the origin community'],
    originCountries: ['india', 'pakistan', 'bangladesh', 'philippines', 'egypt', 'srilanka'],
    source: P,
  },
  {
    id: 6,
    name: 'SME / labour-supply and fleet SIM manager',
    residence: 'UAE / Saudi (B2B)',
    jobToBeDone:
      'Keep 10–200 staff and device SIMs active with a ledger someone can audit; stop deactivation losses across a scattered workforce.',
    trigger:
      'A batch of workforce SIMs deactivates and re-issuance costs a week of admin; finance demands receipts for airtime spend.',
    objection:
      'Procurement wants invoicing, VAT compliance, volume pricing and an SLA — none of which exists yet [V16].',
    plan: 'Standard multi-line at scale; server-side ledger visibility is the hook.',
    channels: [
      'Direct founder-led outreach to labour-supply, facilities-management and logistics firms',
      'LinkedIn organic content — no paid',
    ],
    languages: ['English'],
    originCountries: [],
    source: P,
  },
];

export const FLAGS: Flag[] = [
  {
    id: 'F1',
    title: 'Attribution is a launch gate, not a task',
    body: 'No MMP integrated; iOS ATT limits paid attribution regardless. Without week-one attribution_source capture, the kill rule and the north star are unmeasurable and section 9’s discipline is theatre.',
    source: F,
  },
  {
    id: 'F2',
    title: 'Payments may be the real bottleneck, not marketing',
    body: 'PayPal + Stripe only, and PayPal consumer coverage in Saudi/Qatar is historically limited [V9]. If live test deposits fail there, the two largest residence markets cannot convert regardless of creative quality.',
    source: F,
  },
  {
    id: 'F3',
    title: 'Single-line economics leave no margin for error',
    body: 'At $2.60/yr contribution, the community plan only works if content stays near zero marginal cost and referral credit stays ≤$1.50. If multi-line attach underperforms for two months, the honest move is a pricing conversation, not more marketing.',
    source: F,
  },
  {
    id: 'F4',
    title: 'Premium is currently unadvertisable everywhere until V11 closes',
    body: 'The corridor permissions (PK/BD/EG-partial) are necessary but not sufficient — there is no published Premium price to quote, and the blue-collar segment’s brief requires quoting the real yearly price.',
    source: F,
  },
  {
    id: 'F5',
    title: 'DTone timing risk cuts both ways',
    body: 'If DTone lands mid-quarter, India’s Premium verdict flips — but only after 04 and unit-economics are re-run. The temptation will be to pre-build India Premium assets "ready to flip on". Resist it: pre-built assets leak into distribution.',
    source: F,
  },
  {
    id: 'F6',
    title: 'Refund-rate ambiguity',
    body: 'The 14-day refund headline will mechanically raise refund requests as deposits grow. The manager needs a baseline period before treating a rising rate as an alarm, or the metric will cry wolf in month one.',
    source: F,
  },
  {
    id: 'F7',
    title: 'Community channel is unmeasurable without discipline',
    body: '45% of budget flows to a channel that only attributes via promo codes and links. The no-code-no-renewal rule must actually be enforced; expect pressure to make exceptions.',
    source: F,
  },
  {
    id: 'F8',
    title: 'Zendit test-account status',
    body: 'All current fulfilment data is from an account the owner describes as test-only. Every live top-up assumption inherits that caveat until a production transaction is receipted.',
    source: F,
  },
];

export const BUDGET_ENVELOPES: BudgetEnvelope[] = [
  {
    share: 45,
    use: 'Community seeding and micro-creators — WhatsApp/Facebook diaspora groups, Kerala/Tamil/Filipino/Egyptian associations, OFW organisations, diaspora radio, pre-departure channels',
    constraint: 'Content and creator fees, not media buys',
  },
  {
    share: 20,
    use: 'Referral incentives (wallet credit, never cash)',
    constraint: 'Target referral CAC ≤ $1.50',
  },
  {
    share: 20,
    use: 'Retargeting warm traffic only — site visitors, installers without a line, line-added without payment',
    constraint: 'Never cold audiences',
  },
  {
    share: 15,
    use: 'Creative testing in Bahrain and Oman (low CPM), promoting origin-SIM corridors',
    constraint: 'Winners graduate to organic/community distribution, not to cold scaling',
  },
];

export const MAX_CAC = [
  { segment: 'Single-line Standard (any corridor)', value: '≈ $2.60' },
  { segment: 'Single-line Premium (PK/BD/EG-partial)', value: '≈ $2.90–3.30' },
  { segment: 'Multi-line family (4 lines)', value: '≈ $10.50' },
  { segment: 'SME (15 lines)', value: '≈ $40' },
];

export const BANNED_TERMS: TermRule[] = [
  { banned: 'send money', preferred: 'top up' },
  { banned: 'transfer (of money/credit)', preferred: 'refill' },
  { banned: 'remittance', preferred: 'prepaid credit' },
  { banned: 'wallet-to-wallet', preferred: 'account balance' },
  { banned: 'e-wallet', preferred: 'fund your account' },
  { banned: 'stored value', preferred: 'prepaid credit' },
];

export const EXTENDED_BANS = [
  '"cash out"',
  '"withdraw"',
  '"pay anyone"',
  '"money for your family"',
  'any imagery of cash changing hands',
  '"money-back guarantee" — it implies more than the 14-day policy gives',
];

export const PROHIBITED_CLAIMS = [
  'Universal carrier support',
  'Guaranteed successful refill',
  'Guaranteed prevention of deactivation',
  'Carrier affiliation or endorsement',
  'Operation in any region not live in 04',
  'Describing KeepSIMs as transmitting money',
  'Describing the wallet as transferable or cash-out-able',
  'Any statement of a carrier’s inactivity threshold, grace period or reactivation rule as fact',
  '"0% fees" without the gateway-fee qualifier and IAP resolution [V7]',
];

export const COMMERCIAL_STRUCTURE = [
  'KeepSIMs acts as principal — it buys airtime from its aggregator and resells it as its own product. It is not an agent transmitting user funds to a carrier and must never be described as one, in any language, in any market.',
  'The wallet is non-transferable prepaid credit, redeemable only for KeepSIMs services. It is never cashed out, assigned, or transferred between users.',
  'User-to-user balance transfer is not offered and must never be implied — in creative, feature lists, screenshots, store copy, FAQ, or roadmap language.',
  'Refund policy: wallet balance not yet used for a refill is refundable within 14 days of deposit. After 14 days, or once used, non-refundable.',
];

export const COMPLIANCE_SOURCE = C;

export const FIXED_FACTS = [
  'Standard $2.50/line/yr',
  'Wallet refills 0% gateway fee (pending the IAP token — do not put "0% fees" in app-store copy)',
  'Refill pricing shown before purchase',
  'Unused balance refundable within 14 days of deposit',
  'Instant + scheduled + Premium auto-mini refill engines',
  'Offline fallback channels exist: SMS $0.03 / WhatsApp $0.05 / missed-call $0.02',
];
