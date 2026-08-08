import { useMemo, useState } from 'react';
import { evaluateCountry, isGateShut, isTokenClosed } from '../domain/readiness';
import { useI18n } from '../i18n/context';
import { fill } from '../i18n/strings';
import { useData, useLoc } from '../i18n/useData';
import { GATES } from '../data/gates';
import type { ConsoleApi } from '../state/useConsole';
import { Card, Pill, SourceTag } from './components';

/**
 * The register, made operable. Closing a token here recomputes every corridor verdict —
 * and the UI refuses to close one without an evidence note, mirroring the register's own
 * rule that no session or asset may close a token, only real evidence.
 */
export function VerificationView({ api }: { api: ConsoleApi }) {
  const { t, lang } = useI18n();
  const loc = useLoc();
  const { countries, tokens, gates } = useData();
  const v = t.verification;
  const [drafts, setDrafts] = useState<Record<string, string>>({});
  const [filter, setFilter] = useState<'all' | 'open' | 'closed'>('all');

  const impact = useMemo(() => {
    const map = new Map<string, Set<string>>();
    for (const c of countries) {
      const r = evaluateCountry(c, api.closures, loc);
      for (const cap of r.capabilities) {
        for (const b of cap.blockers) {
          const key = b.token ?? b.id;
          if (!map.has(key)) map.set(key, new Set());
          map.get(key)!.add(`${c.name}: ${cap.label}`);
        }
      }
    }
    return map;
  }, [countries, api.closures, loc]);

  const rows = tokens.filter((x) => {
    const closed = isTokenClosed(x.id, api.closures);
    return filter === 'all' || (filter === 'closed') === closed;
  });

  const filterLabels: Record<'all' | 'open' | 'closed', string> = {
    all: v.filterAll,
    open: v.filterOpen,
    closed: v.filterClosed,
  };

  return (
    <div className="stack">
      <Card
        title={v.title}
        subtitle={v.sub}
        right={
          <div className="filters">
            {(['all', 'open', 'closed'] as const).map((f) => (
              <button
                key={f}
                className={`chipbtn${filter === f ? ' active' : ''}`}
                onClick={() => setFilter(f)}
              >
                {filterLabels[f]}
              </button>
            ))}
          </div>
        }
      >
        <div className="tokens">
          {rows.map((token) => {
            const closed = isTokenClosed(token.id, api.closures);
            const closure = api.tokenClosures[token.id];
            const held = [...(impact.get(token.id) ?? [])];
            const draft = drafts[token.id] ?? '';
            return (
              <div key={token.id} className={`token${closed ? ' token-closed' : ''}`}>
                <div className="token-head">
                  <span className="token-chip lg">{token.id}</span>
                  <Pill tone={closed ? 'ok' : 'warn'}>{closed ? v.closed : v.open}</Pill>
                  <span className="muted">
                    {v.owner}: {token.owner}
                  </span>
                </div>
                <p className="token-q">{token.question}</p>
                <p className="muted small">
                  <strong>{v.closesWhen}</strong> {token.closedBy}
                </p>
                {token.registerNote && (
                  <p className="muted small">
                    {v.registerNote} {token.registerNote}
                  </p>
                )}

                {held.length > 0 && (
                  <details className="held">
                    <summary>{fill(v.heldSummary, { n: held.length })}</summary>
                    <ul className="plain small">
                      {held.map((h) => (
                        <li key={h}>{h}</li>
                      ))}
                    </ul>
                  </details>
                )}

                {closed ? (
                  <div className="token-closure">
                    {closure ? (
                      <>
                        <p className="small">
                          <strong>{v.evidence}</strong> {closure.evidence}
                        </p>
                        <p className="muted small">
                          {fill(v.recorded, { at: closure.at, by: closure.by })}
                        </p>
                        <button className="btn ghost" onClick={() => api.reopenToken(token.id)}>
                          {v.reopen}
                        </button>
                      </>
                    ) : (
                      <p className="muted small">{v.closedInRegister}</p>
                    )}
                  </div>
                ) : (
                  <div className="token-close-form">
                    <input
                      placeholder={v.evidencePlaceholder}
                      value={draft}
                      onChange={(e) => setDrafts({ ...drafts, [token.id]: e.target.value })}
                    />
                    <button
                      className="btn"
                      disabled={draft.trim().length === 0}
                      onClick={() => {
                        api.closeToken(token.id, draft);
                        setDrafts({ ...drafts, [token.id]: '' });
                      }}
                    >
                      {v.closeWithEvidence}
                    </button>
                  </div>
                )}
                <p className="src-line">
                  <SourceTag path={token.source} />
                </p>
              </div>
            );
          })}
        </div>
      </Card>

      <Card title={v.gateTitle} subtitle={v.gateSub}>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>{v.colGate}</th>
                <th>{v.colWaitsOn}</th>
                <th>{v.colWithholds}</th>
                <th>{v.colAppliesTo}</th>
                <th>{v.colInterim}</th>
              </tr>
            </thead>
            <tbody>
              {gates.map((g, i) => {
                const raw = GATES[i]!;
                const shut = isGateShut(raw, api.closures);
                const scopeText =
                  g.scope.kind === 'global'
                    ? v.everyCorridor
                    : (g.scope.countries ?? [])
                        .map((id) => countries.find((c) => c.id === id)?.name ?? id)
                        .join(lang === 'ar' ? '، ' : ', ');
                return (
                  <tr key={g.id}>
                    <td>
                      <Pill tone={shut ? 'bad' : 'ok'}>{shut ? v.shut : v.opened}</Pill> {g.label}
                    </td>
                    <td>
                      <span className="token-chip">{g.token ?? v.internalGate}</span>
                    </td>
                    <td className="small">
                      {g.blocks
                        .map((b) => t.enums.capability[b])
                        .join(lang === 'ar' ? '، ' : ', ')}
                    </td>
                    <td className="small">{scopeText}</td>
                    <td className="small muted">{g.interim}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </Card>
    </div>
  );
}
