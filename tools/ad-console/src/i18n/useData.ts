import { useMemo } from 'react';
import { ORIGIN_COUNTRIES, RESIDENCE_MARKETS } from '../data/countries';
import { PLAN_DOCUMENTS } from '../data/documents';
import { GATES } from '../data/gates';
import { FLAGS, PERSONAS } from '../data/plan';
import { TOKENS } from '../data/tokens';
import { WORK_ITEMS } from '../data/work';
import type { Loc } from '../domain/readiness';
import { useI18n } from './context';
import {
  localizeCountry,
  localizeDocument,
  localizeFlag,
  localizeGate,
  localizePersona,
  localizeResidence,
  localizeToken,
  localizeWork,
} from './localize';

/** Every dataset, rendered in the active language. */
export function useData() {
  const { lang } = useI18n();
  return useMemo(
    () => ({
      countries: ORIGIN_COUNTRIES.map((c) => localizeCountry(c, lang)),
      residence: RESIDENCE_MARKETS.map((m) => localizeResidence(m, lang)),
      tokens: TOKENS.map((t) => localizeToken(t, lang)),
      gates: GATES.map((g) => localizeGate(g, lang)),
      personas: PERSONAS.map((p) => localizePersona(p, lang)),
      flags: FLAGS.map((f) => localizeFlag(f, lang)),
      documents: PLAN_DOCUMENTS.map((d) => localizeDocument(d, lang)),
      work: WORK_ITEMS.map((w) => localizeWork(w, lang)),
    }),
    [lang],
  );
}

/** The bundle the readiness engine needs to generate text in the active language. */
export function useLoc(): Loc {
  const { lang, t } = useI18n();
  return useMemo(() => ({ lang, t }), [lang, t]);
}
