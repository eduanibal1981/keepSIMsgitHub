import { useI18n } from '../i18n/context';
import { fill } from '../i18n/strings';
import { useData } from '../i18n/useData';
import type { WorkItem, WorkStatus } from '../domain/types';
import type { ConsoleApi } from '../state/useConsole';
import { Card, Meter, Pill, SourceTag } from './components';
import type { Tone } from './components';

const STATUS_TONE: Record<WorkStatus, Tone> = {
  done: 'ok',
  in_progress: 'warn',
  not_started: 'bad',
  blocked: 'off',
};

const ORDER: WorkItem['category'][] = ['engineering', 'ops', 'legal', 'writing'];
const STATUSES: WorkStatus[] = ['not_started', 'in_progress', 'done', 'blocked'];

export function WorkView({ api }: { api: ConsoleApi }) {
  const { t } = useI18n();
  const { work } = useData();
  const w = t.work;
  const done = work.filter((x) => api.workStatus(x.id) === 'done').length;

  const categoryTitle: Record<WorkItem['category'], string> = {
    engineering: w.catEngineering,
    ops: w.catOps,
    legal: w.catLegal,
    writing: w.catWriting,
  };

  return (
    <div className="stack">
      <Card title={w.title} subtitle={w.sub}>
        <div className="progress-line">
          <span>{fill(w.progress, { done, total: work.length })}</span>
          <Meter value={done} total={work.length} tone={done === 0 ? 'bad' : 'ok'} />
        </div>
        <p className="callout">{w.callout}</p>
      </Card>

      {ORDER.map((cat) => {
        const items = work.filter((x) => x.category === cat);
        if (items.length === 0) return null;
        return (
          <Card key={cat} title={categoryTitle[cat]}>
            <div className="work-items">
              {items.map((item) => {
                const status = api.workStatus(item.id);
                return (
                  <div key={item.id} className={`work-item work-${status}`}>
                    <div className="work-head">
                      <Pill tone={STATUS_TONE[status]}>{t.enums.workStatus[status]}</Pill>
                      <strong>{item.title}</strong>
                      {item.id.startsWith('G-') && (
                        <span className="chip sm warn">{w.gateChip}</span>
                      )}
                      <span className="muted small">
                        {w.owner}: {item.owner}
                      </span>
                    </div>
                    <p className="muted">{item.detail}</p>
                    <div className="work-foot">
                      <div className="unblocks">
                        {w.unblocks}{' '}
                        {item.unblocks.map((u) => (
                          <span key={u} className="chip sm">
                            {u}
                          </span>
                        ))}
                      </div>
                      <div className="statusbtns">
                        {STATUSES.map((s) => (
                          <button
                            key={s}
                            className={`chipbtn${status === s ? ' active' : ''}`}
                            onClick={() => api.setWorkStatus(item.id, s)}
                          >
                            {t.enums.workStatus[s]}
                          </button>
                        ))}
                      </div>
                    </div>
                    <SourceTag path={item.source} />
                  </div>
                );
              })}
            </div>
          </Card>
        );
      })}
    </div>
  );
}
