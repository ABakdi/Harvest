import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from 'react';
import { ExpenseEditor } from './components/expense-editor';
import { SearchDialog } from './components/search-dialog';
import { SeedEditor, type SeedPrefill } from './components/seed-editor';
import { WishlistEditor } from './components/wishlist-editor';
import type { ExpenseRow } from './data/money';
import type { SeedRow } from './data/seeds';
import type { WishlistList, WishlistRow } from './data/wishlist';

export interface Dialogs {
  plantSeed: (prefill?: SeedPrefill) => void;
  editSeed: (seed: SeedRow) => void;
  logExpense: () => void;
  editExpense: (expense: ExpenseRow) => void;
  openSearch: () => void;
  addWishlistItem: (list: WishlistList) => void;
  editWishlistItem: (item: WishlistRow) => void;
}

const DialogsContext = createContext<Dialogs | null>(null);

export function useDialogs(): Dialogs {
  const dialogs = useContext(DialogsContext);
  if (!dialogs) throw new Error('useDialogs outside DialogsProvider');
  return dialogs;
}

type SeedState = { mode: 'plant'; prefill: SeedPrefill } | { mode: 'edit'; seed: SeedRow } | null;
type ExpenseState = { mode: 'log' } | { mode: 'edit'; expense: ExpenseRow } | null;
type WishlistState = { mode: 'add'; list: WishlistList } | { mode: 'edit'; item: WishlistRow } | null;

/**
 * The editors that open from anywhere: from a button, from a goal item,
 * or from the keyboard (`N`, `E`, `/`). One of each lives here, so every
 * screen opens the same one.
 */
export function DialogsProvider({ children }: { children: ReactNode }) {
  const [seed, setSeed] = useState<SeedState>(null);
  const [expense, setExpense] = useState<ExpenseState>(null);
  const [wishlist, setWishlist] = useState<WishlistState>(null);
  const [search, setSearch] = useState(false);
  // Each opening gets a fresh editor, so no half-typed state leaks from the last one.
  const [generation, setGeneration] = useState(0);

  const plantSeed = useCallback((prefill: SeedPrefill = {}) => {
    setGeneration((n) => n + 1);
    setSeed({ mode: 'plant', prefill });
  }, []);
  const editSeed = useCallback((row: SeedRow) => {
    setGeneration((n) => n + 1);
    setSeed({ mode: 'edit', seed: row });
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
  const addWishlistItem = useCallback((list: WishlistList) => {
    setGeneration((n) => n + 1);
    setWishlist({ mode: 'add', list });
  }, []);
  const editWishlistItem = useCallback((item: WishlistRow) => {
    setGeneration((n) => n + 1);
    setWishlist({ mode: 'edit', item });
  }, []);

  const value = useMemo(
    () => ({ plantSeed, editSeed, logExpense, editExpense, openSearch, addWishlistItem, editWishlistItem }),
    [plantSeed, editSeed, logExpense, editExpense, openSearch, addWishlistItem, editWishlistItem],
  );

  return (
    <DialogsContext.Provider value={value}>
      {children}
      {seed && <SeedEditor key={`seed-${generation}`} state={seed} onClose={() => setSeed(null)} />}
      {expense && (
        <ExpenseEditor
          key={`expense-${generation}`}
          expense={expense.mode === 'edit' ? expense.expense : null}
          onClose={() => setExpense(null)}
        />
      )}
      {wishlist && (
        <WishlistEditor
          key={`wishlist-${generation}`}
          item={wishlist.mode === 'edit' ? wishlist.item : null}
          list={wishlist.mode === 'add' ? wishlist.list : wishlist.item.list}
          onClose={() => setWishlist(null)}
        />
      )}
      <SearchDialog open={search} onOpenChange={setSearch} />
    </DialogsContext.Provider>
  );
}
