import { useMemo } from 'react';
import { evaluateCountry, isTokenClosed } from '../domain/readiness';
import type { CountryReadiness, OverallVerdict } from '../domain/readiness';
import { CAPABILITIES } from '../domain/types';
import { useI18n } from '../i18n/context';
import { budgetEnvelopes, maxCac } from '../i18n/localize';
import { useData, useLoc } from '../i18n/useData';
import type { ConsoleApi } from '../state/useConsole';
import { Card, Meter, Pill, Stat } from './components';
import type { Tone } from './components';

const VERDICT_TONE: Record<OverallVerdict, Tone> = {
  publishable: 'ok',
  limited: 'warn',
  held: 'bad',
  forbidden: 'off',
};

export function OverviewView({ api, goTo }: { api: ConsoleApi; goTo: (v: string) => void }) {
  const { t, lang } = useI18n();
  const loc = useLoc();
  const { countries, tokens, documents, work, flags } = useData();
  const o = t.overview;

  const readiness = useMemo(
    () => countries.map((c) => evaluateCountry(c, api.closures, loc)),
    [countries, api.closures, loc],
  );

  const openTokenList = tokens.filter((x) => !isTokenClosed(x.id, api.closures));
  const liveCorridors = readiness.filter((r) => r.country.coverage === 'live');
  const publishable = liveCorridors.filter(
    (r) => r.verdict === 'publishable' || r.verdict === 'limited',
  );
  const writtenDocs = documents.filter((d) => d.status !== 'pending');
  const doneWork = work.filter((w) => api.workStatus(w.id) === 'done');

  return (
    <div className="stack">
      <Card title={o.standTitle} subtitle={o.standSub}>
        <div className="stats">
          <Stat
            label={o.statLiveCorridors}
            value={`${liveCorridors.length} / ${countries.length}`}
            hint={o.statLiveCorridorsHint}
            tone="info"
          />
          <Stat
            label={o.statOrganic}
            value={`${publishable.length}`}
            hint={o.statOrganicHint}
            tone={publishable.length > 0 ? 'ok' : 'bad'}
          />
          <Stat
            label={o.statTokens}
            value={`${openTokenList.length} / ${tokens.length}`}
            hint={o.statTokensHint}
            tone={openTokenList.length > 10 ? 'bad' : 'warn'}
          />
          <Stat
            label={o.statDocs}
            value={`${writtenDocs.length} / ${documents.length}`}
            hint={o.statDocsHint}
            tone="warn"
          />
          <Stat
            label={o.statWork}
            value={`${doneWork.length} / ${work.length}`}
            hint={o.statWorkHint}
            tone={doneWork.length === 0 ? 'bad' : 'warn'}
          />
        </div>
      </Card>

      <Card title={o.matrixTitle} subtitle={o.matrixSub}>
        <div className="table-wrap">
          <table className="matrix">
            <thead>
              <tr>
                <th>{o.colCorridor}</th>
                {CAPABILITIES.map((c) => (
                  <th key={c} className="rot">
                    {t.enums.capability[c]}
                  </th>
                ))}
                <th>{o.colVerdict}</th>
              </tr>
            </thead>
            <tbody>
              {readiness.map((r) => (
                <tr key={r.country.id} className="click" onClick={() => goTo('countries')}>
                  <td>
                    <span className="flag">{r.country.flag}</span> {r.country.name}
                  </td>
                  {r.capabilities.map((cap) => (
                    <td key={cap.capability} className="cell">
                      <span
                        className={`dot dot-${cap.state}`}
                        title={`${cap.label}: ${t.enums.capState[cap.state]}${
                          cap.blockers.length
                            ? ` — ${t.brief.waitingOn} ${cap.blockers
                                .map((b) => b.token ?? b.id)
                                .join(', ')}`
                            : ''
                        }`}
                      />
                    </td>
                  ))}
                  <td>
                    <Pill tone={VERDICT_TONE[r.verdict]}>{t.enums.verdict[r.verdict]}</Pill>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="legend">
          <span>
            <span className="dot dot-clear" /> {o.legendClear}
          </span>
          <span>
            <span className="dot dot-blocked" /> {o.legendBlocked}
          </span>
          <span>
            <span className="dot dot-forbidden" /> {o.legendForbidden}
          </span>
        </div>
      </Card>

      <div className="two-col">
        <Card title={o.holdingTitle} subtitle={o.holdingSub}>
          <ul className="plain">
            {rankTokens(readiness).map(([tokenId, count]) => (
              <li key={tokenId}>
                <span className="token-chip">{tokenId}</span> <strong>{count}</strong>{' '}
                {count === 1 ? o.heldOne : o.heldMany}
                <div className="muted">{tokens.find((x) => x.id === tokenId)?.question}</div>
              </li>
            ))}
          </ul>
          <button className="btn" onClick={() => goTo('verification')}>
            {o.openRegister}
          </button>
        </Card>

        <Card title={o.budgetTitle} subtitle={o.budgetSub}>
          {budgetEnvelopes(lang).map((e) => (
            <div key={e.use} className="envelope">
              <div className="envelope-head">
                <strong>{e.share}%</strong>
                <span>{e.use}</span>
              </div>
              <Meter value={e.share} total={100} tone="info" />
              <p className="muted small">{e.constraint}</p>
            </div>
          ))}
          <h4>{o.maxCacTitle}</h4>
          <ul className="plain small">
            {maxCac(lang).map((m) => (
              <li key={m.segment}>
                {m.segment}: <strong>{m.value}</strong>
              </li>
            ))}
          </ul>
          <p className="muted small">{o.coldPaid}</p>
        </Card>
      </div>

      <Card title={o.flagsTitle} subtitle={o.flagsSub}>
        <div className="flags">
          {flags.map((f) => (
            <div key={f.id} className="flag-item">
              <div className="flag-head">
                <span className="token-chip">{f.id}</span>
                <strong>{f.title}</strong>
              </div>
              <p className="muted">{f.body}</p>
            </div>
          ))}
        </div>
      </Card>
    </div>
  );
}

function rankTokens(readiness: CountryReadiness[]): [string, number][] {
  const counts = new Map<string, number>();
  for (const r of readiness) {
    for (const cap of r.capabilities) {
      for (const b of cap.blockers) {
        const key = b.token ?? b.id;
        counts.set(key, (counts.get(key) ?? 0) + 1);
      }
    }
  }
  return [...counts.entries()].sort((a, b) => b[1] - a[1]);
}
