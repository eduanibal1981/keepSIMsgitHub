import type { Capability, Gate, OriginCountry, VerificationToken } from './types';
import { CAPABILITIES } from './types';
import { GATES } from '../data/gates';
import { RESIDENCE_BY_ID } from '../data/countries';
import { TOKENS, TOKEN_BY_ID } from '../data/tokens';
import type { Lang, Strings } from '../i18n/strings';
import { fill } from '../i18n/strings';
import { localizeGate, localizeResidence, localizeToken } from '../i18n/localize';

/** Residence markets are stored as ids; readers need the market's name in their language. */
function marketName(id: string, lang: Lang): string {
  const m = RESIDENCE_BY_ID[id];
  return m ? localizeResidence(m, lang).name : id;
}

/**
 * The engine takes a locale bundle rather than hard-coding English, so a corridor verdict
 * and the markdown brief exported from it read the same in either language.
 *
 * Note the country passed in is expected to be already localized (see localizeCountry) —
 * the engine only generates the connective text around it.
 */
export interface Loc {
  lang: Lang;
  t: Strings;
}

// ---------------------------------------------------------------------------
// Closure state — the only mutable thing in the console
// ---------------------------------------------------------------------------

export interface Closure {
  closed: boolean;
  /** Register rule: only real evidence closes a token. The UI enforces a non-empty note. */
  evidence: string;
  at: string; // ISO date
  by: string;
}

/** Keyed by verification-token id (V1…V20) or internal gate id (G-ATTRIB). */
export type ClosureMap = Record<string, Closure>;

export function isTokenClosed(tokenId: string, closures: ClosureMap): boolean {
  const override = closures[tokenId];
  if (override) return override.closed;
  return TOKEN_BY_ID[tokenId]?.defaultState === 'closed';
}

/** A gate is "shut" when the thing it waits on has not been evidenced. */
export function isGateShut(gate: Gate, closures: ClosureMap): boolean {
  if (gate.token) return !isTokenClosed(gate.token, closures);
  return !(closures[gate.id]?.closed ?? false);
}

export function gateAppliesTo(gate: Gate, countryId: string): boolean {
  if (gate.scope.kind === 'global') return true;
  return (gate.scope.countries ?? []).includes(countryId);
}

// ---------------------------------------------------------------------------
// Per-capability evaluation
// ---------------------------------------------------------------------------

export type CapabilityState =
  | 'clear' // may ship today, inside the stated limits
  | 'blocked' // a gate is shut; it will clear when the gate does
  | 'forbidden'; // policy says no, and no token in the register changes that

export interface CapabilityResult {
  capability: Capability;
  label: string;
  state: CapabilityState;
  blockers: Gate[];
  note: string;
}

function premiumNote(country: OriginCountry, loc: Loc): string {
  const r = loc.t.readiness;
  const carriers = country.premiumCarriers.join(loc.lang === 'ar' ? '، ' : ', ');
  switch (country.premiumPolicy) {
    case 'eligible':
      return fill(r.premiumEligible, { carriers });
    case 'eligible_partial':
      return fill(r.premiumPartial, { carriers, country: country.name });
    case 'blocked_economics':
      return r.premiumBlockedEconomics;
    case 'blocked_pending_catalog':
      return r.premiumBlockedCatalog;
    case 'not_live':
      return r.premiumNotLive;
  }
}

function applicableGates(
  country: OriginCountry,
  capability: Capability,
  closures: ClosureMap,
  loc: Loc,
): Gate[] {
  return GATES.filter(
    (g) => gateAppliesTo(g, country.id) && g.blocks.includes(capability) && isGateShut(g, closures),
  ).map((g) => localizeGate(g, loc.lang));
}

export function evaluateCapability(
  country: OriginCountry,
  capability: Capability,
  closures: ClosureMap,
  loc: Loc,
): CapabilityResult {
  const label = loc.t.enums.capability[capability];

  if (country.coverage === 'none') {
    return {
      capability,
      label,
      state: 'forbidden',
      blockers: applicableGates(country, capability, closures, loc),
      note: loc.t.readiness.coverageNone,
    };
  }

  if (
    capability === 'premium_creative' &&
    (country.premiumPolicy === 'blocked_economics' || country.premiumPolicy === 'not_live')
  ) {
    return { capability, label, state: 'forbidden', blockers: [], note: premiumNote(country, loc) };
  }

  const blockers = applicableGates(country, capability, closures, loc);

  const notes: string[] = [];
  if (capability === 'premium_creative') notes.push(premiumNote(country, loc));
  if (capability === 'organic_creative' && blockers.length === 0) {
    notes.push(fill(loc.t.readiness.organicClear, { plan: country.leadPlan }));
  }
  if (capability === 'conversion_cta' && blockers.length > 0) {
    notes.push(loc.t.readiness.conversionNote);
  }

  return {
    capability,
    label,
    state: blockers.length === 0 ? 'clear' : 'blocked',
    blockers,
    note: notes.join(' '),
  };
}

// ---------------------------------------------------------------------------
// Pre-publish data checklist
// ---------------------------------------------------------------------------

export type Severity = 'blocking' | 'before_scale' | 'advisory';

export interface DataRequirement {
  id: string;
  label: string;
  why: string;
  owner: string;
  severity: Severity;
  satisfied: boolean;
  tokenId?: string;
}

function tokenOwner(id: string, loc: Loc, fallback: string): string {
  const t = TOKEN_BY_ID[id];
  return t ? localizeToken(t, loc.lang).owner : fallback;
}

/**
 * "What do I need to know about this country before I publish?"
 *
 * Three sources feed it: the gates that apply to the corridor, the per-carrier rows that
 * carry a token, and the carrier-policy data that every row is missing (V3/V4 — all 49
 * carrier_rules rows have last_verified_at null or sandbox-dated).
 */
export function dataChecklist(
  country: OriginCountry,
  closures: ClosureMap,
  loc: Loc,
): DataRequirement[] {
  const out: DataRequirement[] = [];
  const r = loc.t.readiness;
  const sep = loc.lang === 'ar' ? '، ' : ', ';

  for (const rawGate of GATES) {
    if (!gateAppliesTo(rawGate, country.id)) continue;
    const gate = localizeGate(rawGate, loc.lang);
    const token: VerificationToken | undefined = gate.token ? TOKEN_BY_ID[gate.token] : undefined;
    out.push({
      id: gate.id,
      label: gate.label,
      why: fill(r.gateWhy, {
        caps: gate.blocks.map((b) => loc.t.enums.capability[b]).join(sep),
        interim: gate.interim,
      }),
      owner: token ? localizeToken(token, loc.lang).owner : tokenOwner('V1', loc, 'Product/eng'),
      severity: gate.blocks.includes('organic_creative') ? 'blocking' : 'before_scale',
      satisfied: !isGateShut(rawGate, closures),
      tokenId: gate.token,
    });
  }

  if (country.coverage === 'live') {
    const unverified = country.carriers.filter((c) => !c.policyVerified);
    if (unverified.length > 0) {
      out.push({
        id: `${country.id}-V3`,
        label: fill(r.v3Label, { carriers: unverified.map((c) => c.name).join(sep) }),
        why: r.v3Why,
        owner: tokenOwner('V3', loc, 'Ops'),
        severity: 'blocking',
        satisfied: isTokenClosed('V3', closures),
        tokenId: 'V3',
      });
    }

    const untested = country.carriers.filter((c) => !c.testTopupDone);
    if (untested.length > 0) {
      out.push({
        id: `${country.id}-V4`,
        label: fill(r.v4Label, { carriers: untested.map((c) => c.name).join(sep) }),
        why: r.v4Why,
        owner: tokenOwner('V4', loc, 'Ops'),
        severity: 'before_scale',
        satisfied: isTokenClosed('V4', closures),
        tokenId: 'V4',
      });
    }

    const tainted = country.carriers.filter((c) => c.catalogSource !== 'production_cache');
    if (tainted.length > 0) {
      const catalogToken = tainted.some((c) => c.tokens?.includes('V1')) ? 'V1' : 'V2';
      out.push({
        id: `${country.id}-catalog`,
        label: fill(r.catalogLabel, { carriers: tainted.map((c) => c.name).join(sep) }),
        why: r.catalogWhy,
        owner: tokenOwner(catalogToken, loc, 'Product/eng'),
        severity: country.premiumPolicy === 'blocked_pending_catalog' ? 'blocking' : 'before_scale',
        satisfied: isTokenClosed(catalogToken, closures),
        tokenId: catalogToken,
      });
    }

    const paymentRiskMarkets = country.residenceMarkets.filter((m) =>
      ['saudi', 'qatar', 'kuwait'].includes(m),
    );
    if (paymentRiskMarkets.length > 0) {
      out.push({
        id: `${country.id}-V9`,
        label: fill(r.v9Label, {
          markets: paymentRiskMarkets.map((m) => marketName(m, loc.lang)).join(sep),
        }),
        why: r.v9Why,
        owner: tokenOwner('V9', loc, 'Founder'),
        severity: 'blocking',
        satisfied: isTokenClosed('V9', closures),
        tokenId: 'V9',
      });
    }

    if (country.languages.length > 0) {
      out.push({
        id: `${country.id}-V15`,
        label: fill(r.v15Label, { languages: country.languages.join(sep) }),
        why: r.v15Why,
        owner: tokenOwner('V15', loc, 'Product'),
        severity: 'before_scale',
        satisfied: isTokenClosed('V15', closures),
        tokenId: 'V15',
      });
    }
  } else {
    out.push({
      id: `${country.id}-reentry`,
      label: r.reentryLabel,
      why: r.reentryWhy,
      owner: tokenOwner('V5', loc, 'Founder / BD'),
      severity: 'blocking',
      satisfied: isTokenClosed('V5', closures),
      tokenId: 'V5',
    });
  }

  return out;
}

// ---------------------------------------------------------------------------
// Country roll-up
// ---------------------------------------------------------------------------

export type OverallVerdict = 'publishable' | 'limited' | 'held' | 'forbidden';

export interface CountryReadiness {
  country: OriginCountry;
  verdict: OverallVerdict;
  capabilities: CapabilityResult[];
  checklist: DataRequirement[];
  clearCount: number;
  blockedCount: number;
  forbiddenCount: number;
  openBlockingItems: number;
}

export function evaluateCountry(
  country: OriginCountry,
  closures: ClosureMap,
  loc: Loc,
): CountryReadiness {
  const capabilities = CAPABILITIES.map((c) => evaluateCapability(country, c, closures, loc));
  const checklist = dataChecklist(country, closures, loc);

  const byCap = new Map(capabilities.map((c) => [c.capability, c]));
  const organic = byCap.get('organic_creative')!;
  const paid = byCap.get('paid_media')!;

  let verdict: OverallVerdict;
  if (country.coverage === 'none') verdict = 'forbidden';
  else if (organic.state !== 'clear') verdict = 'held';
  else if (paid.state === 'clear' && capabilities.every((c) => c.state !== 'blocked'))
    verdict = 'publishable';
  else verdict = 'limited';

  return {
    country,
    verdict,
    capabilities,
    checklist,
    clearCount: capabilities.filter((c) => c.state === 'clear').length,
    blockedCount: capabilities.filter((c) => c.state === 'blocked').length,
    forbiddenCount: capabilities.filter((c) => c.state === 'forbidden').length,
    openBlockingItems: checklist.filter((i) => !i.satisfied && i.severity === 'blocking').length,
  };
}

export function openTokens(closures: ClosureMap): VerificationToken[] {
  return TOKENS.filter((t) => !isTokenClosed(t.id, closures));
}

// ---------------------------------------------------------------------------
// Exportable admin brief
// ---------------------------------------------------------------------------

/** A per-country markdown brief the admin can paste into a doc or hand to a manager. */
export function buildCountryBrief(r: CountryReadiness, closures: ClosureMap, loc: Loc): string {
  const c = r.country;
  const t = loc.t;
  const b = t.brief;
  const sep = loc.lang === 'ar' ? '، ' : ', ';
  const lines: string[] = [];
  const stamp = new Date().toISOString().slice(0, 10);

  lines.push(`# ${c.flag} ${c.name} — ${b.heading} (${stamp})`);
  lines.push('');
  lines.push(`**${b.verdict}:** ${t.enums.verdict[r.verdict]}`);
  lines.push(`**${b.tier}:** ${t.enums.tier[c.tier]}`);
  lines.push(`**${b.leadPlan}:** ${c.leadPlan}`);
  lines.push(
    `**${b.residence}:** ${
      c.residenceMarkets.map((m) => marketName(m, loc.lang)).join(sep) || '—'
    }`,
  );
  lines.push(`**${b.languages}:** ${c.languages.join(sep) || '—'}`);
  lines.push('');
  lines.push(`> ${c.adminNote}`);
  lines.push('');

  lines.push(`## ${b.runToday}`);
  const clear = r.capabilities.filter((x) => x.state === 'clear');
  if (clear.length === 0) lines.push(`- ${b.nothing}`);
  for (const x of clear) lines.push(`- ${x.label}${x.note ? ` — ${x.note}` : ''}`);
  lines.push('');

  lines.push(`## ${b.heldOn}`);
  const blocked = r.capabilities.filter((x) => x.state === 'blocked');
  if (blocked.length === 0) lines.push(`- ${b.nothingHeld}`);
  for (const x of blocked) {
    lines.push(`- **${x.label}** — ${b.waitingOn} ${x.blockers.map((g) => g.token ?? g.id).join(sep)}`);
    for (const g of x.blockers) lines.push(`  - ${g.label} · ${b.interim}: ${g.interim}`);
  }
  lines.push('');

  const forbidden = r.capabilities.filter((x) => x.state === 'forbidden');
  if (forbidden.length > 0) {
    lines.push(`## ${b.notPermitted}`);
    for (const x of forbidden) lines.push(`- **${x.label}** — ${x.note}`);
    lines.push('');
  }

  if (c.approvedPromises.length > 0) {
    lines.push(`## ${b.approved}`);
    for (const p of c.approvedPromises) lines.push(`- ${p}`);
    lines.push('');
  }

  lines.push(`## ${b.neverSay}`);
  for (const p of c.corridorProhibitions) lines.push(`- ${p}`);
  lines.push('');

  if (c.carriers.length > 0) {
    const cc = t.countries;
    lines.push(`## ${b.carrierData}`);
    lines.push(
      `| ${cc.colCarrier} | ${cc.colMinDenom} (USD) | ${cc.colKeepAlive} (USD) | ${cc.colMini} | ${cc.colCatalog} | ${cc.colPolicy} | ${cc.colTestTopup} |`,
    );
    lines.push('|---|---|---|---|---|---|---|');
    for (const k of c.carriers) {
      lines.push(
        `| ${k.name} | ${k.minDenominationUsd ?? '—'} | ${k.keepAliveUsd ?? '—'} | ${
          k.miniRefillViable ? cc.viable : cc.notViable
        } | ${t.enums.catalogSource[k.catalogSource]} | ${k.policyVerified ? cc.yes : cc.no} | ${
          k.testTopupDone ? cc.yes : cc.no
        } |`,
      );
    }
    lines.push('');
  }

  lines.push(`## ${b.dataNeeded}`);
  for (const i of r.checklist) {
    lines.push(
      `- [${i.satisfied ? 'x' : ' '}] **${t.enums.severity[i.severity]}** · ${i.label}${
        i.tokenId ? ` (${i.tokenId})` : ''
      } — ${t.countries.owner}: ${i.owner}`,
    );
    lines.push(`  - ${i.why}`);
  }
  lines.push('');

  const open = openTokens(closures).map((x) => x.id);
  lines.push(fill(b.openTokensLine, { list: open.join(sep) || '—' }));
  lines.push('');
  lines.push(`_${b.generatedBy}_`);

  return lines.join('\n');
}
