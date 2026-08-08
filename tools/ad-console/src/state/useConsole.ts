import { useCallback, useMemo, useState } from 'react';
import type { WorkStatus } from '../domain/types';
import type { Closure, ClosureMap } from '../domain/readiness';
import { WORK_ITEMS } from '../data/work';

const STORAGE_KEY = 'keepsims-ad-console.v1';

interface Persisted {
  tokenClosures: ClosureMap;
  workStatus: Record<string, WorkStatus>;
  operator: string;
}

const EMPTY: Persisted = { tokenClosures: {}, workStatus: {}, operator: 'admin' };

function load(): Persisted {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return EMPTY;
    const parsed = JSON.parse(raw) as Partial<Persisted>;
    return {
      tokenClosures: parsed.tokenClosures ?? {},
      workStatus: parsed.workStatus ?? {},
      operator: parsed.operator ?? 'admin',
    };
  } catch {
    return EMPTY;
  }
}

function save(state: Persisted) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  } catch {
    /* storage full or blocked — the console still works, it just will not persist */
  }
}

export interface ConsoleApi {
  operator: string;
  setOperator: (name: string) => void;
  /** Token closures plus the internal gates derived from completed work items. */
  closures: ClosureMap;
  tokenClosures: ClosureMap;
  closeToken: (tokenId: string, evidence: string) => void;
  reopenToken: (tokenId: string) => void;
  workStatus: (id: string) => WorkStatus;
  setWorkStatus: (id: string, status: WorkStatus) => void;
  reset: () => void;
  exportState: () => string;
}

export function useConsole(): ConsoleApi {
  const [state, setState] = useState<Persisted>(load);

  const update = useCallback((next: Persisted) => {
    setState(next);
    save(next);
  }, []);

  const workStatus = useCallback(
    (id: string): WorkStatus =>
      state.workStatus[id] ?? WORK_ITEMS.find((w) => w.id === id)?.defaultStatus ?? 'not_started',
    [state.workStatus],
  );

  /**
   * Internal gates (no verification token behind them) are considered evidenced when the
   * work item that carries the same id is marked done. That keeps one truth for, say,
   * G-ATTRIB instead of asking the admin to tick it in two places.
   */
  const closures = useMemo<ClosureMap>(() => {
    const derived: ClosureMap = { ...state.tokenClosures };
    for (const item of WORK_ITEMS) {
      if (!item.id.startsWith('G-')) continue;
      const status = state.workStatus[item.id] ?? item.defaultStatus;
      if (status === 'done') {
        derived[item.id] = {
          closed: true,
          evidence: `Work item "${item.title}" marked done in the console.`,
          at: new Date().toISOString().slice(0, 10),
          by: state.operator,
        };
      }
    }
    return derived;
  }, [state.tokenClosures, state.workStatus, state.operator]);

  const closeToken = useCallback(
    (tokenId: string, evidence: string) => {
      const trimmed = evidence.trim();
      if (!trimmed) return; // register rule: only real evidence closes a token
      const closure: Closure = {
        closed: true,
        evidence: trimmed,
        at: new Date().toISOString().slice(0, 10),
        by: state.operator,
      };
      update({ ...state, tokenClosures: { ...state.tokenClosures, [tokenId]: closure } });
    },
    [state, update],
  );

  const reopenToken = useCallback(
    (tokenId: string) => {
      const next = { ...state.tokenClosures };
      delete next[tokenId];
      update({ ...state, tokenClosures: next });
    },
    [state, update],
  );

  const setWorkStatus = useCallback(
    (id: string, status: WorkStatus) => {
      update({ ...state, workStatus: { ...state.workStatus, [id]: status } });
    },
    [state, update],
  );

  const setOperator = useCallback(
    (name: string) => update({ ...state, operator: name }),
    [state, update],
  );

  const reset = useCallback(() => update(EMPTY), [update]);

  const exportState = useCallback(() => JSON.stringify(state, null, 2), [state]);

  return {
    operator: state.operator,
    setOperator,
    closures,
    tokenClosures: state.tokenClosures,
    closeToken,
    reopenToken,
    workStatus,
    setWorkStatus,
    reset,
    exportState,
  };
}
