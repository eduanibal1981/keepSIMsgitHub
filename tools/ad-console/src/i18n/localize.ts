import type {
  Carrier,
  Flag,
  Gate,
  OriginCountry,
  Persona,
  PlanDocument,
  ResidenceMarket,
  TermRule,
  VerificationToken,
  WorkItem,
} from '../domain/types';
import { OUT_OF_SCOPE_MARKETS } from '../data/countries';
import {
  BANNED_TERMS,
  BUDGET_ENVELOPES,
  COMMERCIAL_STRUCTURE,
  EXTENDED_BANS,
  FIXED_FACTS,
  MAX_CAC,
  PROHIBITED_CLAIMS,
} from '../data/plan';
import type { BudgetEnvelope } from '../domain/types';
import {
  BANNED_TERMS_AR,
  BUDGET_ENVELOPES_AR,
  COMMERCIAL_STRUCTURE_AR,
  COUNTRY_AR,
  DOCUMENT_AR,
  EXTENDED_BANS_AR,
  FIXED_FACTS_AR,
  FLAG_AR,
  GATE_AR,
  MAX_CAC_AR,
  OUT_OF_SCOPE_AR,
  PERSONA_AR,
  PROHIBITED_CLAIMS_AR,
  RESIDENCE_AR,
  TOKEN_AR,
  WORK_AR,
} from './contentAr';
import type { Lang } from './strings';

/**
 * Swaps English content for Arabic at the data layer, so views and the readiness engine
 * stay language-agnostic. Anything without an Arabic entry falls back to English rather
 * than rendering blank — a missing translation should degrade, not hide information.
 */

export function localizeCarrier(c: Carrier, lang: Lang, countryId: string): Carrier {
  if (lang === 'en') return c;
  const ar = COUNTRY_AR[countryId];
  if (!ar) return c;
  return {
    ...c,
    name: ar.carrierNames?.[c.name] ?? c.name,
    notes: ar.carrierNotes?.[c.name] ?? c.notes,
  };
}

export function localizeCountry(c: OriginCountry, lang: Lang): OriginCountry {
  if (lang === 'en') return c;
  const ar = COUNTRY_AR[c.id];
  if (!ar) return c;
  return {
    ...c,
    name: ar.name,
    leadPlan: ar.leadPlan,
    adminNote: ar.adminNote,
    approvedPromises: ar.approvedPromises,
    corridorProhibitions: ar.corridorProhibitions,
    identityHooks: ar.identityHooks,
    channels: ar.channels,
    languages: ar.languages,
    carriers: c.carriers.map((k) => localizeCarrier(k, lang, c.id)),
    premiumCarriers: c.premiumCarriers.map((n) => ar.carrierNames?.[n] ?? n),
    economics: c.economics
      ? { ...c.economics, windowNote: ar.windowNote ?? c.economics.windowNote }
      : null,
  };
}

export function localizeResidence(m: ResidenceMarket, lang: Lang): ResidenceMarket {
  if (lang === 'en') return m;
  const ar = RESIDENCE_AR[m.id];
  if (!ar) return m;
  return { ...m, name: ar.name, localCarriers: ar.localCarriers, note: ar.note };
}

export function localizeToken(t: VerificationToken, lang: Lang): VerificationToken {
  if (lang === 'en') return t;
  const ar = TOKEN_AR[t.id];
  if (!ar) return t;
  return {
    ...t,
    question: ar.question,
    owner: ar.owner,
    closedBy: ar.closedBy,
    registerNote: ar.registerNote ?? t.registerNote,
  };
}

export function localizeGate(g: Gate, lang: Lang): Gate {
  if (lang === 'en') return g;
  const ar = GATE_AR[g.id];
  if (!ar) return g;
  return { ...g, label: ar.label, interim: ar.interim };
}

export function localizePersona(p: Persona, lang: Lang): Persona {
  if (lang === 'en') return p;
  const ar = PERSONA_AR[p.id];
  if (!ar) return p;
  return { ...p, ...ar };
}

export function localizeFlag(f: Flag, lang: Lang): Flag {
  if (lang === 'en') return f;
  const ar = FLAG_AR[f.id];
  if (!ar) return f;
  return { ...f, title: ar.title, body: ar.body };
}

export function localizeDocument(d: PlanDocument, lang: Lang): PlanDocument {
  if (lang === 'en') return d;
  const ar = DOCUMENT_AR[d.id];
  if (!ar) return d;
  return { ...d, title: ar.title, summary: ar.summary };
}

export function localizeWork(w: WorkItem, lang: Lang): WorkItem {
  if (lang === 'en') return w;
  const ar = WORK_AR[w.id];
  if (!ar) return w;
  return { ...w, title: ar.title, detail: ar.detail, owner: ar.owner, unblocks: ar.unblocks };
}

export function bannedTerms(lang: Lang): TermRule[] {
  return lang === 'ar' ? BANNED_TERMS_AR : BANNED_TERMS;
}

export function extendedBans(lang: Lang): string[] {
  return lang === 'ar' ? EXTENDED_BANS_AR : EXTENDED_BANS;
}

export function prohibitedClaims(lang: Lang): string[] {
  return lang === 'ar' ? PROHIBITED_CLAIMS_AR : PROHIBITED_CLAIMS;
}

export function commercialStructure(lang: Lang): string[] {
  return lang === 'ar' ? COMMERCIAL_STRUCTURE_AR : COMMERCIAL_STRUCTURE;
}

export function fixedFacts(lang: Lang): string[] {
  return lang === 'ar' ? FIXED_FACTS_AR : FIXED_FACTS;
}

export function outOfScopeMarkets(lang: Lang): string[] {
  return lang === 'ar' ? OUT_OF_SCOPE_AR : OUT_OF_SCOPE_MARKETS;
}

export function budgetEnvelopes(lang: Lang): BudgetEnvelope[] {
  if (lang === 'en') return BUDGET_ENVELOPES;
  return BUDGET_ENVELOPES.map((e, i) => ({
    ...e,
    use: BUDGET_ENVELOPES_AR[i]?.use ?? e.use,
    constraint: BUDGET_ENVELOPES_AR[i]?.constraint ?? e.constraint,
  }));
}

export function maxCac(lang: Lang): { segment: string; value: string }[] {
  if (lang === 'en') return MAX_CAC;
  return MAX_CAC.map((m) => ({ ...m, segment: MAX_CAC_AR[m.segment] ?? m.segment }));
}
