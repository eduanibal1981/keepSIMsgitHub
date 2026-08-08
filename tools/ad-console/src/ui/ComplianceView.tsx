import { COMPLIANCE_SOURCE } from '../data/plan';
import { useI18n } from '../i18n/context';
import {
  bannedTerms,
  commercialStructure,
  extendedBans,
  fixedFacts,
  prohibitedClaims,
} from '../i18n/localize';
import { useData } from '../i18n/useData';
import { Card, SourceTag } from './components';

export function ComplianceView() {
  const { t, lang } = useI18n();
  const { countries } = useData();
  const c = t.compliance;

  return (
    <div className="stack">
      {lang === 'ar' && <p className="callout">{c.dialectWarning}</p>}

      <Card title={c.structureTitle} subtitle={c.structureSub}>
        <ol className="numbered">
          {commercialStructure(lang).map((s) => (
            <li key={s}>{s}</li>
          ))}
        </ol>
        <SourceTag path={COMPLIANCE_SOURCE} />
      </Card>

      <div className="two-col">
        <Card title={c.bannedTitle} subtitle={c.bannedSub}>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>{c.colNeverUse}</th>
                  <th>{c.colUseInstead}</th>
                </tr>
              </thead>
              <tbody>
                {bannedTerms(lang).map((term) => (
                  <tr key={term.banned}>
                    <td className="banned">{term.banned}</td>
                    <td className="preferred">{term.preferred}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <h4>{c.extendedTitle}</h4>
          <ul className="crosses">
            {extendedBans(lang).map((b) => (
              <li key={b}>{b}</li>
            ))}
          </ul>
          <p className="muted small">{c.topUpRelative}</p>
        </Card>

        <Card title={c.prohibitedTitle} subtitle={c.prohibitedSub}>
          <ul className="crosses">
            {prohibitedClaims(lang).map((p) => (
              <li key={p}>{p}</li>
            ))}
          </ul>
          <h4>{c.fixedFactsTitle}</h4>
          <ul className="ticks">
            {fixedFacts(lang).map((f) => (
              <li key={f}>{f}</li>
            ))}
          </ul>
        </Card>
      </div>

      <Card title={c.toneTitle} subtitle={c.toneSub}>
        <ul className="crosses">
          {c.tone.map((x) => (
            <li key={x}>{x}</li>
          ))}
        </ul>
      </Card>

      <Card title={c.corridorTitle} subtitle={c.corridorSub}>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>{c.colCorridor}</th>
                <th>{c.colNeverSay}</th>
              </tr>
            </thead>
            <tbody>
              {countries.map((country) => (
                <tr key={country.id}>
                  <td>
                    <span className="flag">{country.flag}</span> <strong>{country.name}</strong>
                  </td>
                  <td>
                    <ul className="crosses tight">
                      {country.corridorProhibitions.map((p) => (
                        <li key={p}>{p}</li>
                      ))}
                    </ul>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      <Card title={c.platformTitle} subtitle={c.platformSub}>
        <ul className="plain">
          {c.platform.map((p) => (
            <li key={p}>{p}</li>
          ))}
        </ul>
        <SourceTag path={COMPLIANCE_SOURCE} />
      </Card>
    </div>
  );
}
