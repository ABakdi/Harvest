import { createContext, useCallback, useContext, useMemo, useRef, useState, type ReactNode } from 'react';
import { ExpenseEditor, type ExpensePrefill } from './components/expense-editor';
import { SearchDialog } from './components/search-dialog';
import { SeedEditor, type SeedPrefill } from './components/seed-editor';
import { ListItemEditor, type ListItemPrefill } from './components/list-item-editor';
import type { ExpenseRow } from './data/money';
import type { SeedRow } from './data/seeds';
import { listOfItem, type ListItemRow } from './data/lists';

export interface Dialogs {
  plantSeed: (prefill?: SeedPrefill) => void;
  editSeed: (seed: SeedRow) => void;
  logExpense: () => void;
  editExpense: (expense: ExpenseRow) => void;
  openSearch: () => void;
  /** The expense sheet with a suggestion typed in, as a bought list item offers it ([[Lists]] L4). */
  suggestExpense: (prefill: ExpensePrefill) => void;
  addListItem: (listUuid: string, prefill?: ListItemPrefill) => void;
  editListItem: (item: ListItemRow) => void;
}

const DialogsContext = createContext<Dialogs | null>(null);

export function useDialogs(): Dialogs {
  const dialogs = useContext(DialogsContext);
  if (!dialogs) throw new Error('useDialogs outside DialogsProvider');
  return dialogs;
}

/** [request] numbers each opening, so the editor is keyed by the press that opened it. */
type SeedState = ({ mode: 'plant'; prefill: SeedPrefill } | { mode: 'edit'; seed: SeedRow }) & { request: number };
type ExpenseState = { mode: 'log'; prefill?: ExpensePrefill } | { mode: 'edit'; expense: ExpenseRow } | null;
type ListItemState = { mode: 'add'; listUuid: string; prefill: ListItemPrefill } | { mode: 'edit'; item: ListItemRow } | null;

/**
 * The editors that open from anywhere: from a button, from a goal item,
 * or from the keyboard (`N`, `E`, `/`). One of each lives here, so every
 * screen opens the same one.
 */
export function DialogsProvider({ children }: { children: ReactNode }) {
  const [seed, setSeed] = useState<SeedState | null>(null);
  const [expense, setExpense] = useState<ExpenseState>(null);
  const [listItem, setListItem] = useState<ListItemState>(null);
  const [search, setSearch] = useState(false);
  // Each opening gets a fresh editor, so no half-typed state leaks from the last one.
  const [generation, setGeneration] = useState(0);

  const seedRequests = useRef(0);
  const plantSeed = useCallback((prefill: SeedPrefill = {}) => {
    setSeed({ mode: 'plant', prefill: { ...prefill }, request: ++seedRequests.current });
  }, []);
  const editSeed = useCallback((row: SeedRow) => {
    setSeed({ mode: 'edit', seed: row, request: ++seedRequests.current });
  }, []);
  const logExpense = useCallback(() => {
    setGeneration((n) => n + 1);
    setExpense({ mode: 'log' });
  }, []);
  const editExpense = useCallback((row: ExpenseRow) => {
    setGeneration((n) => n + 1);
    setExpense({ mode: 'edit', expense: row });
  }, []);
  const openSearch = useCallback(() => setSearch(true), []);
  const suggestExpense = useCallback((prefill: ExpensePrefill) => {
    setGeneration((n) => n + 1);
    setExpense({ mode: 'log', prefill });
  }, []);
  const addListItem = useCallback((listUuid: string, prefill: ListItemPrefill = {}) => {
    setGeneration((n) => n + 1);
    setListItem({ mode: 'add', listUuid, prefill });
  }, []);
  const editListItem = useCallback((item: ListItemRow) => {
    setGeneration((n) => n + 1);
    setListItem({ mode: 'edit', item });
  }, []);

  const value = useMemo(
    () => ({ plantSeed, editSeed, logExpense, editExpense, openSearch, suggestExpense, addListItem, editListItem }),
    [plantSeed, editSeed, logExpense, editExpense, openSearch, suggestExpense, addListItem, editListItem],
  );

  return (
    <DialogsContext.Provider value={value}>
      {children}
      {seed && <SeedEditor key={`seed-${seed.request}`} state={seed} onClose={() => setSeed(null)} />}
      {expense && (
        <ExpenseEditor
          key={`expense-${generation}`}
          expense={expense.mode === 'edit' ? expense.expense : null}
          prefill={expense.mode === 'log' ? expense.prefill : undefined}
          onClose={() => setExpense(null)}
        />
      )}
      {listItem && (
        <ListItemEditor
          key={`list-item-${generation}`}
          item={listItem.mode === 'edit' ? listItem.item : null}
          listUuid={listItem.mode === 'add' ? listItem.listUuid : listOfItem(listItem.item)}
          prefill={listItem.mode === 'add' ? listItem.prefill : undefined}
          onClose={() => setListItem(null)}
        />
      )}
      <SearchDialog open={search} onOpenChange={setSearch} />
    </DialogsContext.Provider>
  );
}
