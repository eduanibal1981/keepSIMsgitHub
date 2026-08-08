import { useI18n } from '../i18n/context';
import { fill } from '../i18n/strings';
import { useData } from '../i18n/useData';
import type { DocStatus, PlanDocument } from '../domain/types';
import { Card, Meter, Pill, SourceTag } from './components';
import type { Tone } from './components';

const STATUS_TONE: Record<DocStatus, Tone> = {
  fixed: 'info',
  done: 'ok',
  seeded: 'warn',
  pending: 'bad',
  historical: 'off',
};

export function LibraryView() {
  const { t } = useI18n();
  const { documents, personas } = useData();
  const l = t.library;
  const groups: PlanDocument['group'][] = ['governing', 'section', 'deliverable'];
  const written = documents.filter((d) => d.status !== 'pending').length;

  const groupTitle: Record<PlanDocument['group'], string> = {
    governing: l.groupGoverning,
    section: l.groupSection,
    deliverable: l.groupDeliverable,
  };
  const groupBlurb: Record<PlanDocument['group'], string> = {
    governing: l.groupGoverningBlurb,
    section: l.groupSectionBlurb,
    deliverable: l.groupDeliverableBlurb,
  };

  return (
    <div className="stack">
      <Card title={l.title} subtitle={l.sub}>
        <div className="progress-line">
          <span>{fill(l.progress, { written, total: documents.length })}</span>
          <Meter value={written} total={documents.length} tone="ok" />
        </div>
        <p className="callout">⚠ {l.duplicateNote}</p>
      </Card>

      {groups.map((g) => (
        <Card key={g} title={groupTitle[g]} subtitle={groupBlurb[g]}>
          <div className="docs">
            {documents
              .filter((d) => d.group === g)
              .map((d) => (
                <div key={d.id} className="doc">
                  <div className="doc-head">
                    <span className="doc-num">{d.number}</span>
                    <strong>{d.title}</strong>
                    <Pill tone={STATUS_TONE[d.status]}>{t.enums.docStatus[d.status]}</Pill>
                    {d.bytes > 0 && (
                      <span className="muted small">{(d.bytes / 1024).toFixed(1)} KB</span>
                    )}
                  </div>
                  <p className="muted">{d.summary}</p>
                  <SourceTag path={d.path} />
                </div>
              ))}
          </div>
        </Card>
      ))}

      <Card title={l.personasTitle} subtitle={l.personasSub}>
        <div className="personas">
          {personas.map((p) => (
            <div key={p.id} className="persona">
              <div className="persona-head">
                <span className="doc-num">{p.id}</span>
                <strong>{p.name}</strong>
                <span className="muted">{p.residence}</span>
              </div>
              <dl>
                <dt>{l.dlJtbd}</dt>
                <dd>{p.jobToBeDone}</dd>
                <dt>{l.dlTrigger}</dt>
                <dd>{p.trigger}</dd>
                <dt>{l.dlObjection}</dt>
                <dd>{p.objection}</dd>
                <dt>{l.dlPlan}</dt>
                <dd>{p.plan}</dd>
                <dt>{l.dlChannels}</dt>
                <dd>
                  <ul className="plain">
                    {p.channels.map((c) => (
                      <li key={c}>{c}</li>
                    ))}
                  </ul>
                </dd>
              </dl>
              <div className="chips">
                {p.languages.map((lg) => (
                  <span key={lg} className="chip">
                    {lg}
                  </span>
                ))}
              </div>
            </div>
          ))}
        </div>
      </Card>
    </div>
  );
}
