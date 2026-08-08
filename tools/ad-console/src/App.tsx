import { useState } from 'react';
import { buildCountryBrief, evaluateCountry, openTokens } from './domain/readiness';
import { useI18n } from './i18n/context';
import { fill } from './i18n/strings';
import { useData, useLoc } from './i18n/useData';
import { useConsole } from './state/useConsole';
import { ComplianceView } from './ui/ComplianceView';
import { CountriesView } from './ui/CountriesView';
import { LibraryView } from './ui/LibraryView';
import { OverviewView } from './ui/OverviewView';
import { VerificationView } from './ui/VerificationView';
import { WorkView } from './ui/WorkView';
import { download } from './ui/components';

const TAB_IDS = ['overview', 'countries', 'verification', 'work', 'library', 'compliance'] as const;
type TabId = (typeof TAB_IDS)[number];

export default function App() {
  const api = useConsole();
  const { t, lang, toggle } = useI18n();
  const loc = useLoc();
  const { countries } = useData();
  const [tab, setTab] = useState<TabId>('overview');

  const tabLabel: Record<TabId, string> = {
    overview: t.tabs.overview,
    countries: t.tabs.countries,
    verification: t.tabs.verification,
    work: t.tabs.work,
    library: t.tabs.library,
    compliance: t.tabs.compliance,
  };

  function exportAll() {
    const stamp = new Date().toISOString().slice(0, 10);
    const b = t.brief;
    const sep = lang === 'ar' ? '، ' : ', ';
    const evaluated = countries.map((c) => evaluateCountry(c, api.closures, loc));
    const parts: string[] = [
      `# ${b.summaryHeading} (${stamp})`,
      '',
      b.generatedBy,
      '',
      `## ${b.summaryTitle}`,
      '',
      `| ${t.overview.colCorridor} | ${b.verdict} | ${b.colClear} | ${b.colBlocked} | ${b.colNotPermitted} | ${b.colOpenBlocking} |`,
      '|---|---|---|---|---|---|',
    ];
    for (const r of evaluated) {
      parts.push(
        `| ${r.country.flag} ${r.country.name} | ${t.enums.verdict[r.verdict]} | ${r.clearCount} | ${r.blockedCount} | ${r.forbiddenCount} | ${r.openBlockingItems} |`,
      );
    }
    parts.push(
      '',
      fill(b.openTokensLine, {
        list: openTokens(api.closures).map((x) => x.id).join(sep) || '—',
      }),
      '',
    );
    for (const r of evaluated) {
      parts.push('', '---', '', buildCountryBrief(r, api.closures, loc));
    }
    download(`keepsims-advertising-readiness-${lang}-${stamp}.md`, parts.join('\n'));
  }

  return (
    <div className="app">
      <header className="topbar">
        <div className="brand">
          <span className="logo">◎</span>
          <div>
            <h1>{t.app.title}</h1>
            <p className="muted small">{t.app.subtitle}</p>
          </div>
        </div>
        <div className="topbar-actions">
          <label className="operator">
            {t.app.operator}
            <input
              value={api.operator}
              onChange={(e) => api.setOperator(e.target.value)}
              size={10}
            />
          </label>
          <button className="btn" onClick={exportAll}>
            {t.app.exportAll}
          </button>
          <button
            className="btn ghost"
            onClick={() => download('ad-console-state.json', api.exportState(), 'application/json')}
          >
            {t.app.exportState}
          </button>
          <button
            className="btn ghost"
            onClick={() => {
              if (confirm(t.app.resetConfirm)) api.reset();
            }}
          >
            {t.app.reset}
          </button>
          {/* Language switch sits at the far end of the bar in both directions: it is the
              top-right control in LTR and mirrors to the top-left when Arabic flips the page. */}
          <button
            className="btn lang"
            onClick={toggle}
            title={lang === 'ar' ? 'Switch to English' : 'التبديل إلى العربية'}
            lang={lang === 'ar' ? 'en' : 'ar'}
          >
            <span className="globe" aria-hidden="true">
              🌐
            </span>
            {t.app.languageLabel}
          </button>
        </div>
      </header>

      <nav className="tabs">
        {TAB_IDS.map((id) => (
          <button
            key={id}
            className={`tab${tab === id ? ' active' : ''}`}
            onClick={() => setTab(id)}
          >
            {tabLabel[id]}
          </button>
        ))}
      </nav>

      <main className="main">
        {tab === 'overview' && <OverviewView api={api} goTo={(v) => setTab(v as TabId)} />}
        {tab === 'countries' && <CountriesView api={api} />}
        {tab === 'verification' && <VerificationView api={api} />}
        {tab === 'work' && <WorkView api={api} />}
        {tab === 'library' && <LibraryView />}
        {tab === 'compliance' && <ComplianceView />}
      </main>

      <footer className="foot">{t.app.footer}</footer>
    </div>
  );
}
