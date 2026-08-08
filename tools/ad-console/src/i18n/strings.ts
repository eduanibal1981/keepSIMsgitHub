import type {
  Capability,
  CatalogSource,
  CorridorTier,
  DocStatus,
  PremiumPolicy,
  WorkStatus,
} from '../domain/types';
import type { OverallVerdict, Severity } from '../domain/readiness';

export type Lang = 'en' | 'ar';

/**
 * The full UI dictionary. `en` and `ar` both satisfy this interface, so a missing
 * translation is a compile error rather than a blank label at runtime.
 *
 * Arabic here is Modern Standard — this is an internal admin console. It must not be
 * confused with the creative rule in creative-brief §7: consumer-facing Arabic creative is
 * Egyptian dialect, never MSA. The console says so on screen in the compliance view.
 */
export interface Strings {
  app: {
    title: string;
    subtitle: string;
    operator: string;
    exportAll: string;
    exportState: string;
    reset: string;
    resetConfirm: string;
    footer: string;
    languageLabel: string;
    languageOther: string;
  };
  tabs: {
    overview: string;
    countries: string;
    verification: string;
    work: string;
    library: string;
    compliance: string;
  };
  overview: {
    standTitle: string;
    standSub: string;
    statLiveCorridors: string;
    statLiveCorridorsHint: string;
    statOrganic: string;
    statOrganicHint: string;
    statTokens: string;
    statTokensHint: string;
    statDocs: string;
    statDocsHint: string;
    statWork: string;
    statWorkHint: string;
    matrixTitle: string;
    matrixSub: string;
    colCorridor: string;
    colVerdict: string;
    legendClear: string;
    legendBlocked: string;
    legendForbidden: string;
    holdingTitle: string;
    holdingSub: string;
    heldOne: string;
    heldMany: string;
    openRegister: string;
    budgetTitle: string;
    budgetSub: string;
    maxCacTitle: string;
    coldPaid: string;
    flagsTitle: string;
    flagsSub: string;
  };
  countries: {
    listTitle: string;
    listSub: string;
    counts: string; // {clear} {blocked} {forbidden}
    residenceTitle: string;
    residenceSub: string;
    testBed: string;
    depositRisk: string;
    outOfScope: string;
    exportBrief: string;
    capsTitle: string;
    promisesTitle: string;
    promisesSub: string;
    promisesEmpty: string;
    hooksTitle: string;
    neverTitle: string;
    neverSub: string;
    carriersTitle: string;
    carriersSub: string;
    colCarrier: string;
    colMinDenom: string;
    colKeepAlive: string;
    colMini: string;
    colCatalog: string;
    colPolicy: string;
    colTestTopup: string;
    colNotes: string;
    premiumOk: string;
    viable: string;
    notViable: string;
    yes: string;
    no: string;
    checklistTitle: string;
    checklistSub: string; // {open} {total}
    satisfied: string;
    owner: string;
    moneyTitle: string;
    moneySub: string;
    noResidence: string;
    economicsTitle: string;
    refillsLine: string; // {n} {amount}
    standardContribution: string;
    premiumContribution: string;
    premiumBlockedHere: string;
    noEconomics: string;
    whoTitle: string;
    whoSub: string;
    personasTitle: string;
    noPersona: string;
    languagesTitle: string;
    noLanguages: string;
    channelsTitle: string;
    noChannels: string;
    sourceLabel: string;
  };
  verification: {
    title: string;
    sub: string;
    filterAll: string;
    filterOpen: string;
    filterClosed: string;
    open: string;
    closed: string;
    owner: string;
    closesWhen: string;
    registerNote: string;
    heldSummary: string; // {n}
    evidence: string;
    recorded: string; // {at} {by}
    reopen: string;
    evidencePlaceholder: string;
    closeWithEvidence: string;
    closedInRegister: string;
    gateTitle: string;
    gateSub: string;
    colGate: string;
    colWaitsOn: string;
    colWithholds: string;
    colAppliesTo: string;
    colInterim: string;
    everyCorridor: string;
    internalGate: string;
    shut: string;
    opened: string;
  };
  work: {
    title: string;
    sub: string;
    progress: string; // {done} {total}
    callout: string;
    catEngineering: string;
    catOps: string;
    catLegal: string;
    catWriting: string;
    gateChip: string;
    owner: string;
    unblocks: string;
  };
  library: {
    title: string;
    sub: string;
    progress: string; // {written} {total}
    groupGoverning: string;
    groupGoverningBlurb: string;
    groupSection: string;
    groupSectionBlurb: string;
    groupDeliverable: string;
    groupDeliverableBlurb: string;
    duplicateNote: string;
    personasTitle: string;
    personasSub: string;
    dlJtbd: string;
    dlTrigger: string;
    dlObjection: string;
    dlPlan: string;
    dlChannels: string;
  };
  compliance: {
    structureTitle: string;
    structureSub: string;
    bannedTitle: string;
    bannedSub: string;
    colNeverUse: string;
    colUseInstead: string;
    extendedTitle: string;
    topUpRelative: string;
    prohibitedTitle: string;
    prohibitedSub: string;
    fixedFactsTitle: string;
    toneTitle: string;
    toneSub: string;
    tone: string[];
    corridorTitle: string;
    corridorSub: string;
    colCorridor: string;
    colNeverSay: string;
    platformTitle: string;
    platformSub: string;
    platform: string[];
    dialectWarning: string;
  };
  brief: {
    heading: string; // {country} {date}
    verdict: string;
    tier: string;
    leadPlan: string;
    residence: string;
    languages: string;
    runToday: string;
    nothing: string;
    heldOn: string;
    nothingHeld: string;
    waitingOn: string;
    interim: string;
    notPermitted: string;
    approved: string;
    neverSay: string;
    carrierData: string;
    dataNeeded: string;
    openTokensLine: string; // {list}
    generatedBy: string;
    summaryHeading: string; // {date}
    summaryTitle: string;
    colClear: string;
    colBlocked: string;
    colNotPermitted: string;
    colOpenBlocking: string;
  };
  /** Text the readiness engine generates, so verdicts and exported briefs translate too. */
  readiness: {
    premiumEligible: string;
    premiumPartial: string;
    premiumBlockedEconomics: string;
    premiumBlockedCatalog: string;
    premiumNotLive: string;
    coverageNone: string;
    organicClear: string;
    conversionNote: string;
    gateWhy: string;
    v3Label: string;
    v3Why: string;
    v4Label: string;
    v4Why: string;
    catalogLabel: string;
    catalogWhy: string;
    v9Label: string;
    v9Why: string;
    v15Label: string;
    v15Why: string;
    reentryLabel: string;
    reentryWhy: string;
  };
  enums: {
    capability: Record<Capability, string>;
    capState: Record<'clear' | 'blocked' | 'forbidden', string>;
    verdict: Record<OverallVerdict, string>;
    verdictShort: Record<OverallVerdict, string>;
    severity: Record<Severity, string>;
    docStatus: Record<DocStatus, string>;
    workStatus: Record<WorkStatus, string>;
    tier: Record<CorridorTier, string>;
    premiumPolicy: Record<PremiumPolicy, string>;
    catalogSource: Record<CatalogSource, string>;
  };
}

export const EN: Strings = {
  app: {
    title: 'KeepSIMs — Advertising Console',
    subtitle: 'Per-country publish readiness, computed from the plan documents',
    operator: 'operator',
    exportAll: 'Export all briefs',
    exportState: 'Export state',
    reset: 'Reset',
    resetConfirm: 'Reset every token closure and work status recorded in this console?',
    footer:
      'Read-only over the plan documents — this console never edits them. Closures and work status are stored in your browser only; export them if they need to reach anyone else.',
    languageLabel: 'العربية',
    languageOther: 'English',
  },
  tabs: {
    overview: 'Overview',
    countries: 'Countries',
    verification: 'Verification',
    work: 'Functionality',
    library: 'Plan library',
    compliance: 'Compliance',
  },
  overview: {
    standTitle: 'Where the advertising system stands',
    standSub:
      'Everything below is computed from doc/advertis System/docs/ — close a verification token and every verdict here moves.',
    statLiveCorridors: 'Corridors with live coverage',
    statLiveCorridorsHint: 'Nepal, Lebanon, Iraq and Syria have zero rows in production',
    statOrganic: 'Corridors that can run organic creative',
    statOrganicHint: 'Standard messaging inside the approved-promise list',
    statTokens: 'Verification tokens open',
    statTokensHint: 'Only real evidence closes one',
    statDocs: 'Plan documents written',
    statDocsHint: 'Sections 1, 2, 5, 10, 14 + creative library, video scripts, SEO plan pending',
    statWork: 'Supporting functionality done',
    statWorkHint: 'Attribution capture is the one that gates all paid spend',
    matrixTitle: 'Country × capability matrix',
    matrixSub:
      'The single screen answering “what is done for each country”. Click a row to open the corridor.',
    colCorridor: 'Corridor',
    colVerdict: 'Verdict',
    legendClear: 'clear to ship',
    legendBlocked: 'blocked by an open gate',
    legendForbidden: 'not permitted by policy',
    holdingTitle: 'What is holding the most back',
    holdingSub: 'Open tokens ranked by how many corridor capabilities they withhold',
    heldOne: 'corridor capability held',
    heldMany: 'corridor capabilities held',
    openRegister: 'Open the verification register →',
    budgetTitle: 'The budget rule',
    budgetSub: 'Under $5,000/month — apply, do not re-derive',
    maxCacTitle: 'Max CAC at 6-month payback',
    coldPaid:
      'Cold paid acquisition is structurally unaffordable at current pricing: GCC CPIs of $1.50–4.00 and 5–15% install→first-payment put cost per paying customer at $10–50 against a $2.60 ceiling.',
    flagsTitle: 'Standing concerns (flags F1–F8)',
    flagsSub: 'Logged and proceeded past — none of these reopens a fixed decision',
  },
  countries: {
    listTitle: 'Origin corridors',
    listSub: 'The promise in the ad. Ordered by tier.',
    counts: '{clear} clear · {blocked} blocked · {forbidden} not permitted',
    residenceTitle: 'Residence markets',
    residenceSub: 'Where the money is spent.',
    testBed: 'test bed',
    depositRisk: 'deposit risk V9',
    outOfScope: 'Out of scope (in the DB, is_supported = false):',
    exportBrief: 'Export brief',
    capsTitle: 'What may run today, and what is held',
    promisesTitle: 'What you may tell users here',
    promisesSub: 'Approved promises — anything outside this list needs a source before it ships',
    promisesEmpty: 'Nothing. This corridor has no approved promise of any kind.',
    hooksTitle: 'Identity hooks (creative-brief §1 — nothing invented)',
    neverTitle: 'What you may never say here',
    neverSub: 'Corridor-specific, on top of the global banned list',
    carriersTitle: 'Carrier data',
    carriersSub:
      'Keep-alive is recommended_topup_amount — an operational estimate, not carrier-verified. Internal only; never quote it to a user.',
    colCarrier: 'Carrier',
    colMinDenom: 'Min denom',
    colKeepAlive: 'Keep-alive',
    colMini: 'Mini-refill',
    colCatalog: 'Catalog source',
    colPolicy: 'Policy sourced',
    colTestTopup: 'Test top-up',
    colNotes: 'Notes',
    premiumOk: 'Premium OK',
    viable: 'viable',
    notViable: 'no',
    yes: 'yes',
    no: 'no',
    checklistTitle: 'Data needed before publishing',
    checklistSub: '{open} of {total} items still open',
    satisfied: 'Satisfied',
    owner: 'owner',
    moneyTitle: 'Where the money is spent',
    moneySub: 'Residence markets for this corridor',
    noResidence: 'None — this corridor is not advertised anywhere.',
    economicsTitle: 'Economics',
    refillsLine: '{n} refills/yr · typical refill ${amount}',
    standardContribution: 'Standard first-year contribution',
    premiumContribution: 'Premium first-year contribution',
    premiumBlockedHere: 'blocked — not sellable here',
    noEconomics: 'No economics — corridor is not live.',
    whoTitle: 'Who and how',
    whoSub: 'Personas, languages, channels',
    personasTitle: 'Personas',
    noPersona: 'No persona targets this corridor.',
    languagesTitle: 'Languages',
    noLanguages: 'None permitted.',
    channelsTitle: 'Channels',
    noChannels: 'None.',
    sourceLabel: 'Source:',
  },
  verification: {
    title: 'Verification register',
    sub: 'Closing a token here updates every corridor verdict in this console. It does not update the register file — record the evidence there too.',
    filterAll: 'all',
    filterOpen: 'open',
    filterClosed: 'closed',
    open: 'Open',
    closed: 'Closed',
    owner: 'owner',
    closesWhen: 'Closes when:',
    registerNote: 'Register note:',
    heldSummary: '{n} corridor capabilities held by this token',
    evidence: 'Evidence:',
    recorded: 'Recorded {at} by {by}',
    reopen: 'Reopen',
    evidencePlaceholder: 'Evidence that closes this — link, screenshot reference, receipt id…',
    closeWithEvidence: 'Close with evidence',
    closedInRegister: 'Closed in the register itself.',
    gateTitle: 'Gate table',
    gateSub:
      'Section 13, made executable. Gate principle: nothing ships that depends on an unclosed token.',
    colGate: 'Gate',
    colWaitsOn: 'Waits on',
    colWithholds: 'Withholds',
    colAppliesTo: 'Applies to',
    colInterim: 'Interim behaviour',
    everyCorridor: 'every corridor',
    internalGate: 'internal build gate',
    shut: 'shut',
    opened: 'open',
  },
  work: {
    title: 'Supporting functionality',
    sub: 'What the plan depends on existing. Starting status is what the documents assert as of the last session — it is not a verification against the codebase, so confirm before ticking.',
    progress: '{done} of {total} done',
    callout:
      'Marking Attribution capture live as done opens the paid-media gate for every corridor at once. That is the intended coupling — without it the kill rule and the north star are unmeasurable, so paid spend has nothing to govern it.',
    catEngineering: 'Engineering',
    catOps: 'Operations & marketing',
    catLegal: 'Legal & founder',
    catWriting: 'Writing',
    gateChip: 'gate',
    owner: 'owner',
    unblocks: 'Unblocks:',
  },
  library: {
    title: 'Plan library',
    sub: 'The advertising plan as a file tree, with what is finished and what is not.',
    progress: '{written} of {total} documents exist',
    groupGoverning: 'Governing files — fixed decisions, do not alter',
    groupGoverningBlurb:
      'Session 1 output. Every judgment in this console traces back to one of these files; changing them changes the app’s verdicts.',
    groupSection: 'Sections written',
    groupSectionBlurb:
      'Session 2 judgment-critical sections. Complete and carried through unchanged.',
    groupDeliverable: 'Still to be produced',
    groupDeliverableBlurb:
      'The remaining volume. Section 1 is written last, and the PDF assembles only after every section exists.',
    duplicateNote:
      'Seven files also sit at doc/advertis System/ root, outside docs/ — earlier manual copies, byte-identical to the docs/ versions. docs/ is canonical. Consider deleting the root copies so there is one source of truth.',
    personasTitle: 'Personas',
    personasSub:
      'Six segments. Digital nomads are deferred to Phase 2 — no creative, landing pages or targeting for them.',
    dlJtbd: 'Job to be done',
    dlTrigger: 'Trigger',
    dlObjection: 'Objection that stops payment',
    dlPlan: 'Plan',
    dlChannels: 'Two cheapest channels',
  },
  compliance: {
    structureTitle: 'Commercial structure — fixed, reproduce exactly',
    structureSub:
      'Once structured as a principal-reseller, the fastest way to lose that position is your own marketing copy. A regulator reads the ad, not the terms of service.',
    bannedTitle: 'Banned terms',
    bannedSub:
      'Verbatim, all languages. A translation that back-translates into a banned meaning is a violation.',
    colNeverUse: 'Never use',
    colUseInstead: 'Use instead',
    extendedTitle: 'Banned by extension',
    topUpRelative:
      '“Top up a relative’s number” is permitted — it is airtime delivery to a line, not funds to a person — but pair it with “airtime, not money” framing wherever family creative runs.',
    prohibitedTitle: 'Prohibited claims',
    prohibitedSub: 'All markets, all languages. Blanket — no verification token closes these.',
    fixedFactsTitle: 'Facts you may state without re-verification',
    toneTitle: 'Tone rules',
    toneSub: 'Calm, reliable, international, practical. No fear-based or exaggerated claims.',
    tone: [
      'Never imply the user has already lost their number',
      'No “last chance”, no countdown-to-deactivation mechanics',
      'No claims of guaranteed prevention',
      'No stated inactivity thresholds as fact — use “carrier rules vary — we track them for you”',
    ],
    corridorTitle: 'Per-corridor prohibitions',
    corridorSub:
      'What each corridor adds on top of the global rules — the list a copy reviewer actually needs.',
    colCorridor: 'Corridor',
    colNeverSay: 'Never say here',
    platformTitle: 'Platform and jurisdiction notes',
    platformSub: 'Ad-platform classification and data protection obligations that shape the calendar',
    platform: [
      'Meta — may require Financial Products & Services special ad category acknowledgment; expect stricter targeting limits if flagged.',
      'TikTok — financial-services policies require pre-approval/registration for money-adjacent products in several GCC markets.',
      'Snapchat — financial-services policy disclosure requirements.',
      'Google — the financial-products verification program may apply to wallet framing; airtime top-up alone usually escapes it, which is another reason banned-terms discipline matters.',
      'Saudi & UAE messaging — SMS/WhatsApp marketing requires prior opt-in and sender registration (CST, TDRA). No cold WhatsApp blasts; community seeding must be admin-invited content.',
      'Data protection — Saudi PDPL, UAE PDPL (45/2021), India DPDP Act 2023, Philippines Data Privacy Act. Every lead-gen or retargeting tactic must name its lawful basis and consent capture point. Phone numbers of other people (family lines a user adds) are personal data the user supplies — cover in the privacy notice.',
    ],
    dialectWarning:
      'This console is in Modern Standard Arabic because it is an internal tool. Consumer-facing Arabic creative is Egyptian dialect only — MSA is banned for social creative (creative-brief §7). Levantine Arabic stays deferred until Lebanon, Iraq and Syria go live.',
  },
  brief: {
    heading: 'pre-publish brief',
    verdict: 'Verdict',
    tier: 'Corridor tier',
    leadPlan: 'Lead plan',
    residence: 'Residence markets',
    languages: 'Languages',
    runToday: 'What may run today',
    nothing: 'Nothing.',
    heldOn: 'What is held, and on what',
    nothingHeld: 'Nothing held.',
    waitingOn: 'waiting on',
    interim: 'interim',
    notPermitted: 'What is not permitted at all',
    approved: 'What you may tell users (approved promises)',
    neverSay: 'What you may never say here',
    carrierData: 'Carrier data',
    dataNeeded: 'Data needed before publishing',
    openTokensLine: 'Open verification tokens at export time: {list}.',
    generatedBy:
      'Generated by the KeepSIMs advertising console from `doc/advertis System/docs/`. Closing a token in this console does not close it in the register — record the evidence there too.',
    summaryHeading: 'KeepSIMs — advertising readiness by country',
    summaryTitle: 'Summary',
    colClear: 'Clear',
    colBlocked: 'Blocked',
    colNotPermitted: 'Not permitted',
    colOpenBlocking: 'Open blocking data items',
  },
  readiness: {
    premiumEligible: 'On the 04 hard list — Premium may be named for {carriers}.',
    premiumPartial:
      'Premium may be named ONLY for {carriers}. Carrier-aware creative is mandatory; a generic {country} Premium asset is a violation.',
    premiumBlockedEconomics:
      'Minimum purchasable denomination exceeds the keep-alive amount, so the "mini" promise breaks. No token in the register reopens this — only a catalog change would.',
    premiumBlockedCatalog:
      'Blocked while the production catalog shows sandbox-scale minimums. Reopens only when V19 (DTone) closes AND 04 is re-run — not when the pricelist merely looks promising.',
    premiumNotLive: 'Corridor is not live.',
    coverageNone:
      'Zero coverage in production data — no carrier rows, no rules, no cached offers. No creative of any kind, and not "coming soon" either.',
    organicClear:
      'Ships today with {plan} messaging, inside the approved-promise list and the banned-terms rules.',
    conversionNote:
      'Awareness and community work is unaffected — only deposit-dependent CTAs are held, and only in Saudi/Qatar/Kuwait.',
    gateWhy: 'Withholds: {caps}. Interim: {interim}',
    v3Label: 'Carrier prepaid policy sourced and date-stamped for: {carriers}',
    v3Why:
      'Inactivity limit and grace period are unsourced in carrier_rules. Until sourced, no asset may state a threshold as fact — copy must say "carrier rules vary — we track them for you".',
    v4Label: 'Live end-to-end test top-up receipted for: {carriers}',
    v4Why:
      'The keep-alive amount is an operational estimate. Every fulfilment assumption inherits the Zendit test-account caveat (flags F8) until a production transaction is receipted.',
    catalogLabel: 'Production catalog pull for sandbox-tainted rows: {carriers}',
    catalogWhy:
      'These minimum denominations come from sandbox-pinned rules or a cache that looks like sandbox residue. The Premium verdict for this corridor rests on them.',
    v9Label: 'Live test deposit from {markets}',
    v9Why:
      'This corridor advertises into markets where PayPal consumer coverage is historically limited. If deposits fail there, creative quality is irrelevant (flags F2).',
    v15Label: 'App locale confirmation for: {languages}',
    v15Why:
      'Ad language must not outrun app language. Until the build locale list is known, non-English creative carries the app-language caveat.',
    reentryLabel: 'Tier 3 re-entry checklist (04) completed end to end',
    reentryWhy:
      'Coverage contracted and live with a named aggregator; carrier rows + rules + offers present in production; test top-up receipted per carrier; carrier_rules populated with sourced inactivity/grace data; min-denomination vs keep-alive computed into a Premium verdict; then organic/community first, paid only after 60 days of clean fulfilment data.',
  },
  enums: {
    capability: {
      organic_creative: 'Organic / community creative',
      paid_media: 'Paid media',
      premium_creative: 'Premium plan creative',
      non_english_scale: 'Non-English creative at scale',
      conversion_cta: 'Deposit-dependent CTAs',
      referral: 'Referral program',
      b2b_claims: 'SME / B2B claims',
    },
    capState: { clear: 'Clear', blocked: 'Blocked', forbidden: 'Not permitted' },
    verdict: {
      publishable: 'Publishable',
      limited: 'Publishable with limits',
      held: 'Held',
      forbidden: 'No creative permitted',
    },
    verdictShort: { publishable: 'go', limited: 'limits', held: 'held', forbidden: 'no ads' },
    severity: { blocking: 'Blocking', before_scale: 'Before scale', advisory: 'Advisory' },
    docStatus: {
      fixed: 'Fixed — do not alter',
      done: 'Done',
      seeded: 'Seeded — append only',
      pending: 'Not written yet',
      historical: 'Historical record',
    },
    workStatus: {
      done: 'Done',
      in_progress: 'In progress',
      not_started: 'Not started',
      blocked: 'Blocked',
    },
    tier: {
      '1-volume': 'Tier 1 — volume',
      '1-premium-proof': 'Tier 1 — Premium proof',
      '2': 'Tier 2',
      '3-not-live': 'Tier 3 — not live',
    },
    premiumPolicy: {
      eligible: 'Premium permitted (04 hard list)',
      eligible_partial: 'Premium permitted on named carriers only',
      blocked_economics: 'Premium blocked — min denomination exceeds keep-alive',
      blocked_pending_catalog: 'Premium blocked — pending production catalog',
      not_live: 'Not live',
    },
    catalogSource: {
      production_cache: 'Cached catalog',
      sandbox_pinned: 'Sandbox-pinned rule row',
      cache_suspect: 'Cache looks like sandbox residue',
    },
  },
};

export const AR: Strings = {
  app: {
    title: 'كيب‑سيمز — لوحة الإعلانات',
    subtitle: 'جاهزية النشر لكل دولة، محسوبة من مستندات الخطة',
    operator: 'المشغّل',
    exportAll: 'تصدير كل الملخّصات',
    exportState: 'تصدير الحالة',
    reset: 'إعادة تعيين',
    resetConfirm: 'إعادة تعيين كل إغلاقات الرموز وحالات العمل المسجّلة في هذه اللوحة؟',
    footer:
      'اللوحة تقرأ مستندات الخطة فقط ولا تعدّلها إطلاقًا. الإغلاقات وحالات العمل محفوظة في متصفحك وحده؛ صدّرها إن احتاج غيرك الاطّلاع عليها.',
    languageLabel: 'English',
    languageOther: 'العربية',
  },
  tabs: {
    overview: 'نظرة عامة',
    countries: 'الدول',
    verification: 'التحقّق',
    work: 'الجاهزية التقنية',
    library: 'مكتبة الخطة',
    compliance: 'الامتثال',
  },
  overview: {
    standTitle: 'أين يقف نظام الإعلانات الآن',
    standSub:
      'كل ما يلي محسوب من doc/advertis System/docs/ — أغلِق أي رمز تحقّق وستتغيّر كل الأحكام هنا.',
    statLiveCorridors: 'ممرّات ذات تغطية فعلية',
    statLiveCorridorsHint: 'نيبال ولبنان والعراق وسوريا: لا توجد أي سجلات في قاعدة الإنتاج',
    statOrganic: 'ممرّات يمكنها تشغيل محتوى مجتمعي الآن',
    statOrganicHint: 'رسائل الخطة العادية ضمن قائمة الوعود المعتمدة',
    statTokens: 'رموز تحقّق مفتوحة',
    statTokensHint: 'لا يغلقها إلا دليل حقيقي',
    statDocs: 'مستندات الخطة المكتوبة',
    statDocsHint: 'الأقسام ١ و٢ و٥ و١٠ و١٤ + مكتبة الإبداع ونصوص الفيديو وخطة السيو ما زالت معلّقة',
    statWork: 'الوظائف المساندة المنجزة',
    statWorkHint: 'التقاط مصدر الإحالة هو ما يحجب كل الإنفاق المدفوع',
    matrixTitle: 'مصفوفة الدولة × القدرة',
    matrixSub: 'الشاشة الوحيدة التي تجيب: «ما المنجَز لكل دولة؟». اضغط على صف لفتح الممرّ.',
    colCorridor: 'الممرّ',
    colVerdict: 'الحكم',
    legendClear: 'جاهز للنشر',
    legendBlocked: 'محجوب ببوّابة مفتوحة',
    legendForbidden: 'غير مسموح به بحسب السياسة',
    holdingTitle: 'ما الذي يعطّل أكثر شيء',
    holdingSub: 'الرموز المفتوحة مرتّبة حسب عدد قدرات الممرّات التي تحجبها',
    heldOne: 'قدرة ممرّ محجوبة',
    heldMany: 'قدرات ممرّات محجوبة',
    openRegister: 'افتح سجل التحقّق ←',
    budgetTitle: 'قاعدة الميزانية',
    budgetSub: 'أقل من ٥٠٠٠ دولار شهريًا — طبّقها ولا تعِد اشتقاقها',
    maxCacTitle: 'أقصى تكلفة اكتساب عند استرداد ٦ أشهر',
    coldPaid:
      'الاكتساب المدفوع البارد غير محتمل هيكليًا بالتسعير الحالي: تكلفة التثبيت في الخليج ١٫٥٠–٤٫٠٠ دولار، وتحويل التثبيت إلى أول دفعة ٥–١٥٪، أي تكلفة العميل الدافع ١٠–٥٠ دولارًا مقابل سقف قدره ٢٫٦٠ دولار.',
    flagsTitle: 'مخاوف قائمة (F1–F8)',
    flagsSub: 'مسجّلة ومضى العمل بعدها — ولا واحدة منها تعيد فتح قرار مثبَّت',
  },
  countries: {
    listTitle: 'ممرّات المنشأ',
    listSub: 'الوعد الذي يحمله الإعلان. مرتّبة حسب الطبقة.',
    counts: '{clear} جاهزة · {blocked} محجوبة · {forbidden} غير مسموح',
    residenceTitle: 'أسواق الإقامة',
    residenceSub: 'حيث يُنفق المال.',
    testBed: 'حقل اختبار',
    depositRisk: 'خطر إيداع V9',
    outOfScope: 'خارج النطاق (موجودة في قاعدة البيانات بحالة is_supported = false):',
    exportBrief: 'تصدير الملخّص',
    capsTitle: 'ما الذي يمكن تشغيله اليوم وما هو محجوب',
    promisesTitle: 'ما الذي يمكنك قوله للمستخدمين هنا',
    promisesSub: 'وعود معتمدة — وأي شيء خارج هذه القائمة يحتاج مصدرًا قبل نشره',
    promisesEmpty: 'لا شيء. هذا الممرّ ليس فيه أي وعد معتمد.',
    hooksTitle: 'روابط الهوية (موجز الإبداع §١ — بلا أي اختلاق)',
    neverTitle: 'ما الذي يُمنع قوله هنا إطلاقًا',
    neverSub: 'خاص بهذا الممرّ، فوق قائمة المحظورات العامة',
    carriersTitle: 'بيانات المشغّلين',
    carriersSub:
      'مبلغ الإبقاء هو recommended_topup_amount — تقدير تشغيلي غير موثّق من المشغّل. للاستخدام الداخلي فقط؛ لا تذكره لمستخدم أبدًا.',
    colCarrier: 'المشغّل',
    colMinDenom: 'أدنى فئة',
    colKeepAlive: 'مبلغ الإبقاء',
    colMini: 'شحنة صغيرة',
    colCatalog: 'مصدر الكتالوج',
    colPolicy: 'السياسة موثّقة',
    colTestTopup: 'شحن تجريبي',
    colNotes: 'ملاحظات',
    premiumOk: 'بريميوم مسموح',
    viable: 'ممكنة',
    notViable: 'لا',
    yes: 'نعم',
    no: 'لا',
    checklistTitle: 'البيانات المطلوبة قبل النشر',
    checklistSub: '{open} من {total} بندًا ما زالت مفتوحة',
    satisfied: 'مستوفى',
    owner: 'المسؤول',
    moneyTitle: 'أين يُنفق المال',
    moneySub: 'أسواق الإقامة لهذا الممرّ',
    noResidence: 'لا شيء — هذا الممرّ لا يُعلَن عنه في أي مكان.',
    economicsTitle: 'الاقتصاديات',
    refillsLine: '{n} شحنة سنويًا · متوسط الشحنة {amount} دولار',
    standardContribution: 'مساهمة السنة الأولى — الخطة العادية',
    premiumContribution: 'مساهمة السنة الأولى — بريميوم',
    premiumBlockedHere: 'محجوبة — غير قابلة للبيع هنا',
    noEconomics: 'لا اقتصاديات — الممرّ غير مفعّل.',
    whoTitle: 'من وكيف',
    whoSub: 'الشرائح واللغات والقنوات',
    personasTitle: 'الشرائح',
    noPersona: 'لا توجد شريحة تستهدف هذا الممرّ.',
    languagesTitle: 'اللغات',
    noLanguages: 'لا شيء مسموح.',
    channelsTitle: 'القنوات',
    noChannels: 'لا شيء.',
    sourceLabel: 'المصدر:',
  },
  verification: {
    title: 'سجل التحقّق',
    sub: 'إغلاق رمز هنا يحدّث كل أحكام الممرّات في هذه اللوحة، لكنه لا يحدّث ملف السجل — سجّل الدليل هناك أيضًا.',
    filterAll: 'الكل',
    filterOpen: 'مفتوح',
    filterClosed: 'مغلق',
    open: 'مفتوح',
    closed: 'مغلق',
    owner: 'المسؤول',
    closesWhen: 'يُغلَق عند:',
    registerNote: 'ملاحظة السجل:',
    heldSummary: '{n} قدرة ممرّ محجوبة بهذا الرمز',
    evidence: 'الدليل:',
    recorded: 'سُجّل في {at} بواسطة {by}',
    reopen: 'إعادة فتح',
    evidencePlaceholder: 'الدليل الذي يغلق هذا البند — رابط أو مرجع لقطة شاشة أو رقم إيصال…',
    closeWithEvidence: 'أغلِق بدليل',
    closedInRegister: 'مغلق في السجل نفسه.',
    gateTitle: 'جدول البوّابات',
    gateSub: 'القسم ١٣ وقد صار قابلًا للتنفيذ. المبدأ: لا يُنشر شيء يعتمد على رمز لم يُغلق.',
    colGate: 'البوّابة',
    colWaitsOn: 'تنتظر',
    colWithholds: 'تحجب',
    colAppliesTo: 'تنطبق على',
    colInterim: 'السلوك المؤقّت',
    everyCorridor: 'كل الممرّات',
    internalGate: 'بوّابة بناء داخلية',
    shut: 'مغلقة',
    opened: 'مفتوحة',
  },
  work: {
    title: 'الوظائف المساندة',
    sub: 'ما تعتمد الخطة على وجوده. الحالة الابتدائية هي ما تقرّره المستندات حتى آخر جلسة — وهي ليست تحققًا من الشيفرة، فتأكّد قبل التعليم.',
    progress: '{done} من {total} منجزة',
    callout:
      'تعليم «التقاط مصدر الإحالة» كمنجَز يفتح بوّابة الإعلانات المدفوعة لكل الممرّات دفعة واحدة. هذا الاقتران مقصود — فبدونه تصبح قاعدة الإيقاف والمؤشر النجمي غير قابلين للقياس، ولا يبقى ما يحكم الإنفاق المدفوع.',
    catEngineering: 'الهندسة',
    catOps: 'التشغيل والتسويق',
    catLegal: 'الشؤون القانونية والمؤسّس',
    catWriting: 'الكتابة',
    gateChip: 'بوّابة',
    owner: 'المسؤول',
    unblocks: 'يفتح:',
  },
  library: {
    title: 'مكتبة الخطة',
    sub: 'خطة الإعلانات كشجرة ملفات، مع ما اكتمل منها وما لم يكتمل.',
    progress: '{written} من {total} مستندًا موجودة',
    groupGoverning: 'الملفات الحاكمة — قرارات مثبّتة، لا تُعدَّل',
    groupGoverningBlurb:
      'مخرجات الجلسة الأولى. كل حكم في هذه اللوحة يعود إلى أحد هذه الملفات؛ وتغييرها يغيّر أحكام التطبيق.',
    groupSection: 'الأقسام المكتوبة',
    groupSectionBlurb: 'أقسام الجلسة الثانية الحاسمة. مكتملة ومنقولة كما هي دون تعديل.',
    groupDeliverable: 'ما زال يجب إنتاجه',
    groupDeliverableBlurb:
      'الكمّ المتبقّي. القسم الأول يُكتب في النهاية، وملف الـPDF لا يُجمَّع إلا بعد اكتمال كل الأقسام.',
    duplicateNote:
      'توجد سبعة ملفات أيضًا في جذر doc/advertis System/ خارج مجلد docs/ — نسخ يدوية أقدم مطابقة بايت ببايت لنسخ docs/. المجلد docs/ هو المرجع. يُستحسن حذف نسخ الجذر ليبقى مصدر واحد للحقيقة.',
    personasTitle: 'الشرائح',
    personasSub:
      'ست شرائح. الرحّالة الرقميون مؤجَّلون إلى المرحلة الثانية — لا إبداع ولا صفحات هبوط ولا استهداف لهم.',
    dlJtbd: 'المهمّة المطلوب إنجازها',
    dlTrigger: 'اللحظة المحفِّزة',
    dlObjection: 'الاعتراض الذي يمنع الدفع',
    dlPlan: 'الخطة',
    dlChannels: 'أرخص قناتين',
  },
  compliance: {
    structureTitle: 'الهيكل التجاري — مثبّت، يُنقل حرفيًا',
    structureSub:
      'بعد التموضع كبائع أصيل، أسرع طريقة لفقد هذا الموقع هي نصوصك التسويقية أنت. الجهة الرقابية تقرأ الإعلان لا شروط الخدمة.',
    bannedTitle: 'المصطلحات المحظورة',
    bannedSub:
      'حرفيًا وبكل اللغات. والترجمة التي تعود إلى معنى محظور تُعدّ مخالفة.',
    colNeverUse: 'لا تستخدم أبدًا',
    colUseInstead: 'استخدم بدلًا منها',
    extendedTitle: 'محظورة بالتبعية',
    topUpRelative:
      'عبارة «اشحن رقم قريبك» مسموح بها — فهي تسليم رصيد اتصال إلى خط لا تحويل أموال إلى شخص — لكن اقرنها دائمًا بإطار «رصيد اتصال، لا أموال» في أي إبداع عائلي.',
    prohibitedTitle: 'الادعاءات الممنوعة',
    prohibitedSub: 'في كل الأسواق وكل اللغات. حظر شامل لا يغلقه أي رمز تحقّق.',
    fixedFactsTitle: 'حقائق يمكن ذكرها دون إعادة تحقّق',
    toneTitle: 'قواعد النبرة',
    toneSub: 'هادئة، موثوقة، عالمية، عملية. بلا تخويف ولا مبالغة.',
    tone: [
      'لا تلمّح أبدًا إلى أن المستخدم فقد رقمه فعلًا',
      'لا «فرصة أخيرة»، ولا عدّادات تنازلية للإيقاف',
      'لا ادعاءات بضمان منع الإيقاف',
      'لا ذكر لعتبات الخمول كحقيقة — استخدم «قواعد المشغّلين تختلف، ونحن نتابعها بدلًا عنك»',
    ],
    corridorTitle: 'محظورات كل ممرّ',
    corridorSub: 'ما يضيفه كل ممرّ فوق القواعد العامة — القائمة التي يحتاجها مراجع النصوص فعليًا.',
    colCorridor: 'الممرّ',
    colNeverSay: 'لا تقل هنا أبدًا',
    platformTitle: 'ملاحظات المنصّات والاختصاصات',
    platformSub: 'تصنيفات منصّات الإعلان والتزامات حماية البيانات التي تحكم الجدول الزمني',
    platform: [
      'ميتا — قد تطلب إقرار فئة الإعلانات الخاصة بالمنتجات والخدمات المالية؛ وتوقّع قيود استهداف أشدّ عند التصنيف.',
      'تيك توك — سياسات الخدمات المالية تشترط موافقة مسبقة أو تسجيلًا للمنتجات القريبة من المال في عدة أسواق خليجية.',
      'سناب شات — متطلبات إفصاح ضمن سياسة الخدمات المالية.',
      'جوجل — قد ينطبق برنامج التحقّق للمنتجات المالية على أي تأطير للمحفظة؛ وشحن رصيد الاتصال وحده ينجو منه عادة، وهذا سبب إضافي لانضباط المصطلحات المحظورة.',
      'المراسلة في السعودية والإمارات — التسويق عبر الرسائل وواتساب يشترط موافقة مسبقة وتسجيل المرسِل (هيئة الاتصالات والفضاء والتقنية، والهيئة التنظيمية للاتصالات). لا رسائل واتساب باردة؛ والبذر المجتمعي يجب أن يكون محتوى بدعوة من المشرف.',
      'حماية البيانات — نظام حماية البيانات الشخصية السعودي، والإماراتي (٤٥/٢٠٢١)، وقانون الهند DPDP 2023، وقانون خصوصية البيانات الفلبيني. كل أسلوب لجمع العملاء أو إعادة الاستهداف يجب أن يسمّي أساسه القانوني ونقطة أخذ الموافقة. وأرقام هواتف الآخرين (خطوط العائلة التي يضيفها المستخدم) بيانات شخصية يقدّمها المستخدم — يجب تغطيتها في إشعار الخصوصية.',
    ],
    dialectWarning:
      'هذه اللوحة بالعربية الفصحى لأنها أداة داخلية. أما الإبداع العربي الموجَّه للمستهلك فباللهجة المصرية حصرًا — والفصحى محظورة في إبداع السوشيال (موجز الإبداع §٧). واللهجة الشامية تبقى مؤجَّلة حتى تُفعَّل لبنان والعراق وسوريا.',
  },
  brief: {
    heading: 'ملخّص ما قبل النشر',
    verdict: 'الحكم',
    tier: 'طبقة الممرّ',
    leadPlan: 'الخطة الرئيسية',
    residence: 'أسواق الإقامة',
    languages: 'اللغات',
    runToday: 'ما الذي يمكن تشغيله اليوم',
    nothing: 'لا شيء.',
    heldOn: 'ما هو محجوب، وعلى ماذا',
    nothingHeld: 'لا شيء محجوب.',
    waitingOn: 'ينتظر',
    interim: 'المؤقّت',
    notPermitted: 'ما هو غير مسموح به إطلاقًا',
    approved: 'ما الذي يمكن قوله للمستخدمين (وعود معتمدة)',
    neverSay: 'ما الذي يُمنع قوله هنا إطلاقًا',
    carrierData: 'بيانات المشغّلين',
    dataNeeded: 'البيانات المطلوبة قبل النشر',
    openTokensLine: 'رموز التحقّق المفتوحة وقت التصدير: {list}.',
    generatedBy:
      'أُنشئ بواسطة لوحة إعلانات كيب‑سيمز من `doc/advertis System/docs/`. إغلاق رمز في هذه اللوحة لا يغلقه في السجل — سجّل الدليل هناك أيضًا.',
    summaryHeading: 'كيب‑سيمز — جاهزية الإعلان حسب الدولة',
    summaryTitle: 'ملخّص',
    colClear: 'جاهزة',
    colBlocked: 'محجوبة',
    colNotPermitted: 'غير مسموح',
    colOpenBlocking: 'بنود بيانات حاجبة مفتوحة',
  },
  readiness: {
    premiumEligible: 'ضمن القائمة الصارمة في ملف ٠٤ — يجوز ذكر بريميوم لهؤلاء المشغّلين: {carriers}.',
    premiumPartial:
      'لا يجوز ذكر بريميوم إلا لهؤلاء المشغّلين: {carriers}. والإبداع الواعي بالمشغّل إلزامي؛ وأي أصل بريميوم عام باسم {country} يُعدّ مخالفة.',
    premiumBlockedEconomics:
      'أدنى فئة قابلة للشراء تتجاوز مبلغ الإبقاء، فينهار وعد «الشحنة الصغيرة». ولا يوجد رمز في السجل يعيد فتح هذا — تغيير الكتالوج وحده يفعل.',
    premiumBlockedCatalog:
      'محجوب ما دام كتالوج الإنتاج يُظهر حدودًا دنيا بمقاييس بيئة الاختبار. ولا يُعاد فتحه إلا بإغلاق V19 (DTone) وإعادة تشغيل ملف ٠٤ — لا لمجرد أن قائمة الأسعار تبدو واعدة.',
    premiumNotLive: 'الممرّ غير مفعّل.',
    coverageNone:
      'لا تغطية إطلاقًا في بيانات الإنتاج — لا صفوف مشغّلين ولا قواعد ولا عروض مخزّنة. ممنوع أي إبداع من أي نوع، ولا حتى «قريبًا».',
    organicClear: 'قابل للنشر اليوم برسائل {plan}، ضمن قائمة الوعود المعتمدة وقواعد المصطلحات المحظورة.',
    conversionNote:
      'التوعية والعمل المجتمعي غير متأثّرين — المحجوب فقط هو دعوات الفعل المعتمدة على الإيداع، وفي السعودية وقطر والكويت وحدها.',
    gateWhy: 'تحجب: {caps}. والسلوك المؤقّت: {interim}',
    v3Label: 'توثيق وتأريخ سياسة الدفع المسبق للمشغّلين: {carriers}',
    v3Why:
      'حدّ الخمول ومدّة المهلة غير موثّقين في carrier_rules. وحتى التوثيق، لا يجوز لأي أصل ذكر عتبة كحقيقة — ويجب أن يقول النص «قواعد المشغّلين تختلف، ونحن نتابعها بدلًا عنك».',
    v4Label: 'شحنة تجريبية حيّة موثّقة بإيصال من الطرف إلى الطرف لـ: {carriers}',
    v4Why:
      'مبلغ الإبقاء تقدير تشغيلي. وكل افتراض تنفيذي يرث تحفّظ حساب زينديت الاختباري (المخاوف F8) حتى تُوثَّق معاملة إنتاجية بإيصال.',
    catalogLabel: 'سحب كتالوج الإنتاج للصفوف الملوّثة ببيئة الاختبار: {carriers}',
    catalogWhy:
      'هذه الحدود الدنيا مصدرها قواعد مثبّتة من بيئة الاختبار أو كاش يبدو من بقاياها. وحكم بريميوم لهذا الممرّ قائم عليها.',
    v9Label: 'إيداع تجريبي حيّ من {markets}',
    v9Why:
      'هذا الممرّ يُعلن في أسواق تغطية باي‑بال للأفراد فيها محدودة تاريخيًا. وإن فشلت الإيداعات هناك، فجودة الإبداع بلا معنى (المخاوف F2).',
    v15Label: 'تأكيد لغات التطبيق لـ: {languages}',
    v15Why:
      'لا يجوز أن تسبق لغة الإعلان لغة التطبيق. وحتى تُعرف قائمة لغات البناء، يحمل الإبداع غير الإنجليزي تحفّظ لغة التطبيق.',
    reentryLabel: 'إتمام قائمة إعادة الدخول للطبقة الثالثة (ملف ٠٤) من أولها إلى آخرها',
    reentryWhy:
      'تغطية متعاقد عليها ومفعّلة مع مجمّع مسمّى؛ ووجود صفوف المشغّلين والقواعد والعروض في الإنتاج؛ وشحنة تجريبية موثّقة لكل مشغّل؛ وتعبئة carrier_rules ببيانات خمول ومهلة موثّقة؛ وحساب أدنى فئة مقابل مبلغ الإبقاء للوصول إلى حكم بريميوم؛ ثم العضوي والمجتمعي أولًا، والمدفوع بعد ٦٠ يومًا من بيانات تنفيذ نظيفة.',
  },
  enums: {
    capability: {
      organic_creative: 'إبداع عضوي / مجتمعي',
      paid_media: 'إعلانات مدفوعة',
      premium_creative: 'إبداع خطة بريميوم',
      non_english_scale: 'إبداع بغير الإنجليزية على نطاق واسع',
      conversion_cta: 'دعوات فعل تعتمد على الإيداع',
      referral: 'برنامج الإحالة',
      b2b_claims: 'وعود الشركات الصغيرة والمتوسطة',
    },
    capState: { clear: 'جاهز', blocked: 'محجوب', forbidden: 'غير مسموح' },
    verdict: {
      publishable: 'قابل للنشر',
      limited: 'قابل للنشر بحدود',
      held: 'محجوب',
      forbidden: 'لا يُسمح بأي إبداع',
    },
    verdictShort: { publishable: 'انطلق', limited: 'بحدود', held: 'محجوب', forbidden: 'لا إعلان' },
    severity: { blocking: 'حاجب', before_scale: 'قبل التوسّع', advisory: 'إرشادي' },
    docStatus: {
      fixed: 'مثبّت — لا يُعدَّل',
      done: 'منجَز',
      seeded: 'مبدوء — للإضافة فقط',
      pending: 'لم يُكتب بعد',
      historical: 'سجل تاريخي',
    },
    workStatus: {
      done: 'منجَز',
      in_progress: 'قيد العمل',
      not_started: 'لم يبدأ',
      blocked: 'محجوب',
    },
    tier: {
      '1-volume': 'الطبقة ١ — الحجم',
      '1-premium-proof': 'الطبقة ١ — إثبات بريميوم',
      '2': 'الطبقة ٢',
      '3-not-live': 'الطبقة ٣ — غير مفعّلة',
    },
    premiumPolicy: {
      eligible: 'بريميوم مسموح (القائمة الصارمة في ٠٤)',
      eligible_partial: 'بريميوم مسموح لمشغّلين محدّدين فقط',
      blocked_economics: 'بريميوم محجوب — أدنى فئة تتجاوز مبلغ الإبقاء',
      blocked_pending_catalog: 'بريميوم محجوب — بانتظار كتالوج الإنتاج',
      not_live: 'غير مفعّل',
    },
    catalogSource: {
      production_cache: 'كتالوج مخزّن',
      sandbox_pinned: 'صف قاعدة مثبّت من بيئة الاختبار',
      cache_suspect: 'الكتالوج يبدو من بقايا بيئة الاختبار',
    },
  },
};

export const STRINGS: Record<Lang, Strings> = { en: EN, ar: AR };

/** Minimal interpolation: fill(s, { n: 3 }) replaces {n}. */
export function fill(template: string, vars: Record<string, string | number>): string {
  return template.replace(/\{(\w+)\}/g, (_, k: string) => String(vars[k] ?? `{${k}}`));
}
