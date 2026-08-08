import type { Gate } from '../domain/types';

const GATE_SRC = 'doc/advertis System/docs/sections/13-launch-plan-30-60-90.md';

/**
 * The section-13 gate table, made executable.
 *
 * Gate principle, verbatim from 13: "nothing ships that depends on an unclosed V-token."
 * Each gate names the capabilities it withholds and the interim behaviour the plan allows
 * while it is shut. `G-ATTRIB` has no token — it is the week-one engineering gate that
 * flags.md F1 calls a launch gate rather than a task.
 */
export const GATES: Gate[] = [
  {
    id: 'G-ATTRIB',
    label: 'Attribution capture live (attribution_source on registration, UTM + promo plumbing)',
    internal: true,
    blocks: ['paid_media'],
    scope: { kind: 'global' },
    interim:
      'Community / organic only. Without it the kill rule and the north star are both unmeasurable.',
    source: GATE_SRC,
  },
  {
    id: 'G-V14',
    label: 'Platform pre-approval for financial-services ad classification',
    token: 'V14',
    blocks: ['paid_media'],
    scope: { kind: 'global' },
    interim: 'Submit one representative creative per platform on days 1–5.',
    source: GATE_SRC,
  },
  {
    id: 'G-V6',
    label: 'App-store live regions confirmed (ad geo-targeting list)',
    token: 'V6',
    blocks: ['paid_media'],
    scope: { kind: 'global' },
    interim: 'No geo assumed live until screenshot evidence exists.',
    source: GATE_SRC,
  },
  {
    id: 'G-V9',
    label: 'Payment-method availability in Saudi, Qatar, Kuwait',
    token: 'V9',
    blocks: ['conversion_cta'],
    scope: { kind: 'global' },
    interim:
      'Awareness and community work is fine; deposit-dependent CTAs are held for KSA/QA/KW and deposit_failed is monitored from day one.',
    source: GATE_SRC,
  },
  {
    id: 'G-V11',
    label: 'Published Premium price card',
    token: 'V11',
    blocks: ['premium_creative'],
    scope: { kind: 'global' },
    interim:
      'Premium messaging held until a real price is quotable. Premium copy may be drafted with a [PRICE — V11] placeholder — never an invented number.',
    source: GATE_SRC,
  },
  {
    id: 'G-V19',
    label: 'DTone live in production + 04 re-run (India Premium)',
    token: 'V19',
    blocks: ['premium_creative'],
    scope: { kind: 'countries', countries: ['india'] },
    interim:
      'Standard-only India creative. Do not pre-build India Premium assets "ready to flip on" (flags F5).',
    source: GATE_SRC,
  },
  {
    id: 'G-V15',
    label: 'App locale list confirmed',
    token: 'V15',
    blocks: ['non_english_scale'],
    scope: { kind: 'global' },
    interim: 'Ship non-English creative with the app-language caveat line.',
    source: GATE_SRC,
  },
  {
    id: 'G-V17',
    label: 'Referral counsel note + built flow',
    token: 'V17',
    blocks: ['referral'],
    scope: { kind: 'global' },
    interim: 'Referral copy drafted, not live.',
    source: GATE_SRC,
  },
  {
    id: 'G-V16',
    label: 'B2B invoicing / VAT capability',
    token: 'V16',
    blocks: ['b2b_claims'],
    scope: { kind: 'global' },
    interim: 'Founder outreach only, no public B2B claims.',
    source: GATE_SRC,
  },
  {
    id: 'G-V5',
    label: 'Coverage for Nepal, Lebanon, Iraq, Syria + 04 re-entry checklist',
    token: 'V5',
    blocks: [
      'organic_creative',
      'paid_media',
      'premium_creative',
      'non_english_scale',
      'conversion_cta',
      'referral',
      'b2b_claims',
    ],
    scope: { kind: 'countries', countries: ['nepal', 'lebanon', 'iraq', 'syria'] },
    interim: 'Nothing. Not "coming soon" either.',
    source: GATE_SRC,
  },
  {
    id: 'G-V13',
    label: 'Syria SST designation status + counterparty screening sign-off',
    token: 'V13',
    blocks: ['organic_creative', 'paid_media'],
    scope: { kind: 'countries', countries: ['syria'] },
    interim:
      'Not supported, not advertised, no promise of support. Even after coverage lands, hold Syria from paid acquisition for commercial reasons.',
    source: 'doc/advertis System/docs/12-compliance-and-claims.md',
  },
];

export const GATE_BY_ID: Record<string, Gate> = Object.fromEntries(GATES.map((g) => [g.id, g]));
