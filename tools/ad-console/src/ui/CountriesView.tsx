import { useMemo, useState } from 'react';
import { buildCountryBrief, evaluateCountry } from '../domain/readiness';
import type { CapabilityResult, CountryReadiness, Loc, OverallVerdict } from '../domain/readiness';
import { useI18n } from '../i18n/context';
import { fill } from '../i18n/strings';
import type { Strings } from '../i18n/strings';
import { outOfScopeMarkets } from '../i18n/localize';
import { useData, useLoc } from '../i18n/useData';
import type { ConsoleApi } from '../state/useConsole';
import { Card, download, Empty, Meter, Pill, SourceTag } from './components';
import type { Tone } from './components';

const VERDICT_TONE: Record<OverallVerdict, Tone> = {
  publishable: 'ok',
  limited: 'warn',
  held: 'bad',
  forbidden: 'off',
};

function capTone(state: CapabilityResult['state']): Tone {
  if (state === 'clear') return 'ok';
  if (state === 'blocked') return 'warn';
  return 'off';
}

function CapabilityRow({ cap, t }: { cap: CapabilityResult; t: Strings }) {
  return (
    <div className="cap">
      <div className="cap-head">
        <Pill tone={capTone(cap.state)}>{t.enums.capState[cap.state]}</Pill>
        <strong>{cap.label}</strong>
        {cap.blockers.length > 0 && (
          <span className="cap-tokens">
            {cap.blockers.map((b) => (
              <span key={b.id} className="token-chip">
                {b.token ?? b.id}
              </span>
            ))}
          </span>
        )}
      </div>
      {cap.note && <p className="cap-note">{cap.note}</p>}
      {cap.blockers.map((b) => (
        <p key={b.id} className="cap-blocker">
          <strong>{b.label}.</strong> {t.verification.colInterim}: {b.interim}
        </p>
      ))}
    </div>
  );
}

function CountryDetail({ r, api, loc }: { r: CountryReadiness; api: ConsoleApi; loc: Loc }) {
  const { t } = useI18n();
  const { personas, residence } = useData();
  const c = r.country;
  const cc = t.countries;
  const mine = personas.filter((p) => c.personaIds.includes(p.id));
  const residenceById = new Map(residence.map((m) => [m.id, m]));

  return (
    <div className="detail">
      <div className="detail-head">
        <div>
          <h2>
            <span className="flag">{c.flag}</span> {c.name}
          </h2>
          <p className="muted">
            {t.enums.tier[c.tier]} · {t.brief.leadPlan}: {c.leadPlan} ·{' '}
            {t.enums.premiumPolicy[c.premiumPolicy]}
          </p>
        </div>
        <div className="detail-actions">
          <Pill tone={VERDICT_TONE[r.verdict]}>{t.enums.verdict[r.verdict]}</Pill>
          <button
            className="btn"
            onClick={() =>
              download(`${c.id}-pre-publish-brief.md`, buildCountryBrief(r, api.closures, loc))
            }
          >
            {cc.exportBrief}
          </button>
        </div>
      </div>

      <p className="admin-note">{c.adminNote}</p>

      <Card title={cc.capsTitle}>
        {r.capabilities.map((cap) => (
          <CapabilityRow key={cap.capability} cap={cap} t={t} />
        ))}
      </Card>

      <div className="two-col">
        <Card title={cc.promisesTitle} subtitle={cc.promisesSub}>
          {c.approvedPromises.length === 0 ? (
            <Empty>{cc.promisesEmpty}</Empty>
          ) : (
            <ul className="ticks">
              {c.approvedPromises.map((p) => (
                <li key={p}>{p}</li>
              ))}
            </ul>
          )}
          {c.identityHooks.length > 0 && (
            <>
              <h4>{cc.hooksTitle}</h4>
              <div className="chips">
                {c.identityHooks.map((h) => (
                  <span key={h} className="chip">
                    {h}
                  </span>
                ))}
              </div>
            </>
          )}
        </Card>

        <Card title={cc.neverTitle} subtitle={cc.neverSub}>
          <ul className="crosses">
            {c.corridorProhibitions.map((p) => (
              <li key={p}>{p}</li>
            ))}
          </ul>
        </Card>
      </div>

      {c.carriers.length > 0 && (
        <Card title={cc.carriersTitle} subtitle={cc.carriersSub}>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>{cc.colCarrier}</th>
                  <th>{cc.colMinDenom}</th>
                  <th>{cc.colKeepAlive}</th>
                  <th>{cc.colMini}</th>
                  <th>{cc.colCatalog}</th>
                  <th>{cc.colPolicy}</th>
                  <th>{cc.colTestTopup}</th>
                  <th>{cc.colNotes}</th>
                </tr>
              </thead>
              <tbody>
                {c.carriers.map((k) => (
                  <tr key={k.name}>
                    <td>
                      <strong>{k.name}</strong>
                      {c.premiumCarriers.includes(k.name) && (
                        <span className="chip sm">{cc.premiumOk}</span>
                      )}
                    </td>
                    <td className="num">${k.minDenominationUsd?.toFixed(2) ?? '—'}</td>
                    <td className="num">${k.keepAliveUsd?.toFixed(2) ?? '—'}</td>
                    <td>
                      <Pill tone={k.miniRefillViable ? 'ok' : 'off'}>
                        {k.miniRefillViable ? cc.viable : cc.notViable}
                      </Pill>
                    </td>
                    <td>
                      <Pill tone={k.catalogSource === 'production_cache' ? 'info' : 'warn'}>
                        {t.enums.catalogSource[k.catalogSource]}
                      </Pill>
                    </td>
                    <td>
                      <Pill tone={k.policyVerified ? 'ok' : 'bad'}>
                        {k.policyVerified ? cc.yes : cc.no}
                      </Pill>
                    </td>
                    <td>
                      <Pill tone={k.testTopupDone ? 'ok' : 'bad'}>
                        {k.testTopupDone ? cc.yes : cc.no}
                      </Pill>
                    </td>
                    <td className="notes">
                      {k.notes}
                      {k.tokens && k.tokens.length > 0 && (
                        <span className="cap-tokens">
                          {k.tokens.map((x) => (
                            <span key={x} className="token-chip">
                              {x}
                            </span>
                          ))}
                        </span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      )}

      <Card
        title={cc.checklistTitle}
        subtitle={fill(cc.checklistSub, {
          open: r.checklist.filter((i) => !i.satisfied).length,
          total: r.checklist.length,
        })}
      >
        <ul className="checklist">
          {r.checklist.map((i) => (
            <li key={i.id} className={i.satisfied ? 'done' : ''}>
              <span className="check">{i.satisfied ? '✓' : '○'}</span>
              <div>
                <div className="check-head">
                  <Pill tone={i.satisfied ? 'ok' : i.severity === 'blocking' ? 'bad' : 'warn'}>
                    {i.satisfied ? cc.satisfied : t.enums.severity[i.severity]}
                  </Pill>
                  <strong>{i.label}</strong>
                  {i.tokenId && <span className="token-chip">{i.tokenId}</span>}
                  <span className="muted">
                    {' '}
                    · {cc.owner}: {i.owner}
                  </span>
                </div>
                <p className="muted">{i.why}</p>
              </div>
            </li>
          ))}
        </ul>
      </Card>

      <div className="two-col">
        <Card title={cc.moneyTitle} subtitle={cc.moneySub}>
          {c.residenceMarkets.length === 0 ? (
            <Empty>{cc.noResidence}</Empty>
          ) : (
            <ul className="plain">
              {c.residenceMarkets.map((id) => {
                const m = residenceById.get(id);
                if (!m) return null;
                return (
                  <li key={id}>
                    <strong>
                      {m.flag} {m.name}
                    </strong>
                    {m.paymentRisk && <Pill tone="warn">{cc.depositRisk}</Pill>}
                    <div className="muted">{m.note}</div>
                  </li>
                );
              })}
            </ul>
          )}
          <h4>{cc.economicsTitle}</h4>
          {c.economics ? (
            <ul className="plain">
              <li>
                {fill(cc.refillsLine, {
                  n: c.economics.refillsPerYear,
                  amount: c.economics.typicalRefillUsd,
                })}
              </li>
              <li>
                {cc.standardContribution}: ${c.economics.standardContributionUsd}
              </li>
              <li>
                {cc.premiumContribution}:{' '}
                {c.economics.premiumContributionUsd
                  ? `$${c.economics.premiumContributionUsd}`
                  : cc.premiumBlockedHere}
              </li>
              <li className="muted">{c.economics.windowNote}</li>
            </ul>
          ) : (
            <Empty>{cc.noEconomics}</Empty>
          )}
        </Card>

        <Card title={cc.whoTitle} subtitle={cc.whoSub}>
          <h4>{cc.personasTitle}</h4>
          {mine.length === 0 ? (
            <Empty>{cc.noPersona}</Empty>
          ) : (
            <ul className="plain">
              {mine.map((p) => (
                <li key={p.id}>
                  <strong>
                    {p.id}. {p.name}
                  </strong>{' '}
                  <span className="muted">— {p.plan}</span>
                </li>
              ))}
            </ul>
          )}
          <h4>{cc.languagesTitle}</h4>
          <div className="chips">
            {c.languages.length === 0 ? (
              <Empty>{cc.noLanguages}</Empty>
            ) : (
              c.languages.map((l) => (
                <span key={l} className="chip">
                  {l}
                </span>
              ))
            )}
          </div>
          <h4>{cc.channelsTitle}</h4>
          {c.channels.length === 0 ? (
            <Empty>{cc.noChannels}</Empty>
          ) : (
            <ul className="plain">
              {c.channels.map((ch) => (
                <li key={ch}>{ch}</li>
              ))}
            </ul>
          )}
        </Card>
      </div>

      <p className="src-line">
        {cc.sourceLabel} <SourceTag path={c.source} />
      </p>
    </div>
  );
}

export function CountriesView({ api }: { api: ConsoleApi }) {
  const { t, lang } = useI18n();
  const loc = useLoc();
  const { countries, residence } = useData();
  const cc = t.countries;

  const readiness = useMemo(
    () => countries.map((c) => evaluateCountry(c, api.closures, loc)),
    [countries, api.closures, loc],
  );
  const [selected, setSelected] = useState<string>(readiness[0]?.country.id ?? '');
  const current = readiness.find((r) => r.country.id === selected) ?? readiness[0];

  return (
    <div className="countries">
      <aside className="country-list">
        <h3>{cc.listTitle}</h3>
        <p className="muted small">{cc.listSub}</p>
        {readiness.map((r) => (
          <button
            key={r.country.id}
            className={`country-btn${r.country.id === selected ? ' active' : ''}`}
            onClick={() => setSelected(r.country.id)}
          >
            <span className="flag">{r.country.flag}</span>
            <span className="country-btn-body">
              <span className="country-btn-name">{r.country.name}</span>
              <span className="country-btn-sub">
                {fill(cc.counts, {
                  clear: r.clearCount,
                  blocked: r.blockedCount,
                  forbidden: r.forbiddenCount,
                })}
              </span>
              <Meter
                value={r.clearCount}
                total={r.capabilities.length}
                tone={VERDICT_TONE[r.verdict]}
              />
            </span>
            <Pill tone={VERDICT_TONE[r.verdict]}>{t.enums.verdictShort[r.verdict]}</Pill>
          </button>
        ))}

        <h3>{cc.residenceTitle}</h3>
        <p className="muted small">{cc.residenceSub}</p>
        <ul className="plain small">
          {residence.map((m) => (
            <li key={m.id}>
              {m.flag} <strong>{m.name}</strong>
              {m.role === 'test_bed' && <span className="chip sm">{cc.testBed}</span>}
              {m.paymentRisk && <span className="chip sm warn">V9</span>}
              <div className="muted">{m.localCarriers}</div>
            </li>
          ))}
        </ul>
        <p className="muted small">
          {cc.outOfScope} {outOfScopeMarkets(lang).join(lang === 'ar' ? '، ' : ', ')}.
        </p>
      </aside>

      <div className="country-detail">
        {current && <CountryDetail r={current} api={api} loc={loc} />}
      </div>
    </div>
  );
}
