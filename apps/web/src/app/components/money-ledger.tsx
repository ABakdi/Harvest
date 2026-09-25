import type { Rates } from '@harvest/core';
import {
  ArrowLeftRightIcon,
  CircleMinusIcon,
  CirclePlusIcon,
  FilterXIcon,
  HandCoinsIcon,
  SearchIcon,
  SearchXIcon,
  SlidersHorizontalIcon,
  Trash2Icon,
} from 'lucide-react';
import { useId, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group';
import { formatDay, formatMoney, formatNumber } from '@/lib/format';
import { cn } from '@/lib/utils';
import { LocationNote } from './location-note';
import { useHarvest } from '../context';
import type { CategoryRow } from '../data/categories';
import { type ExpenseRow, presetCategories } from '../data/money';
import { type MoveFilter, type TxnRow, activeFilters, emptyFilter, txnKinds } from '../data/vault';
import { categoryLabel } from './category';
import { ExpenseEditor } from './expense-editor';
import { CategoryIcon, conversionCaption, moneyError, useCustomCategories } from './money-bits';

/**
 * The one way to narrow a ledger (`MoveFilterBar`): the search is
 * always there, the forms and categories fold away, and the count of
 * what is switched on rides on the toggle so a folded filter can never
 * hide rows silently ([[Finances]] The Vault).
 */
export function MoveFilterBar({
  filter,
  onChange,
  matches,
  total,
}: {
  filter: MoveFilter;
  onChange: (filter: MoveFilter) => void;
  matches: number;
  total: number;
}) {
  const { t } = useTranslation();
  const customs = useCustomCategories();
  const id = useId();
  const [open, setOpen] = useState(activeFilters(filter) > 0);
  const active = activeFilters(filter);
  const categories = [...presetCategories, ...(customs ?? []).map((row) => row.name)];

  return (
    <div className="flex flex-col gap-2">
      <div className="flex items-center gap-2">
        <div className="relative flex-1">
          <SearchIcon className="pointer-events-none absolute inset-y-0 start-3 my-auto size-4 text-muted-foreground" aria-hidden />
          <Input
            type="search"
            aria-label={t('vault.searchMoves')}
            placeholder={t('vault.searchMoves')}
            className="ps-9"
            value={filter.query}
            onChange={(event) => onChange({ ...filter, query: event.target.value })}
          />
        </div>
        <Button
          variant={open ? 'secondary' : 'outline'}
          aria-expanded={open}
          aria-controls={`${id}-panel`}
          onClick={() => setOpen(!open)}
        >
          <SlidersHorizontalIcon />
          {t('vault.filter')}
          {active > 0 && (
            <span className="rounded-full bg-primary px-1.5 text-xs text-primary-foreground tabular">{formatNumber(active)}</span>
          )}
        </Button>
      </div>
      {open && (
        <div id={`${id}-panel`} className="flex flex-col gap-2 rounded-xl border bg-card p-3">
          <span id={`${id}-kinds`} className="text-xs font-bold text-muted-foreground">
            {t('vault.byKind')}
          </span>
          <ToggleGroup
            type="multiple"
            value={[...filter.kinds]}
            onValueChange={(kinds) => onChange({ ...filter, kinds })}
            aria-labelledby={`${id}-kinds`}
            className="flex-wrap justify-start"
          >
            {txnKinds.map((kind) => (
              <ToggleGroupItem key={kind} value={kind}>
                {t(`vault.kind.${kind}`)}
              </ToggleGroupItem>
            ))}
          </ToggleGroup>
          <span id={`${id}-categories`} className="text-xs font-bold text-muted-foreground">
            {t('vault.byCategory')}
          </span>
          <ToggleGroup
            type="multiple"
            value={[...filter.categories]}
            onValueChange={(chosen) => onChange({ ...filter, categories: chosen })}
            aria-labelledby={`${id}-categories`}
            className="flex-wrap justify-start"
          >
            {categories.map((key) => (
              <ToggleGroupItem key={key} value={key}>
                <CategoryIcon category={key} customs={customs} />
                {categoryLabel(t, key)}
              </ToggleGroupItem>
            ))}
          </ToggleGroup>
          {active > 0 && (
            <div className="flex items-center justify-between gap-2">
              <span className="text-xs text-muted-foreground" aria-live="polite">
                {t('vault.showing', { matches: formatNumber(matches), total: formatNumber(total) })}
              </span>
              <Button variant="ghost" size="sm" onClick={() => onChange(emptyFilter)}>
                <FilterXIcon />
                {t('vault.clearFilters')}
              </Button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

/** What a movement was, in the ledger's own words (`MoveRow`). */
export function moveTitle(t: ReturnType<typeof useTranslation>['t'], row: TxnRow): string {
  const deposit = row.deltaMinor >= 0;
  const wallet = row.account === 'wallet';
  switch (row.kind) {
    case 'transfer':
      return t(wallet ? (deposit ? 'vault.txn.fromSavings' : 'vault.txn.toSavings') : deposit ? 'vault.txn.fromWallet' : 'vault.txn.toWallet');
    case 'expense':
      return t('vault.txn.expense', { category: categoryLabel(t, row.reference ?? 'other') });
    case 'debt':
      return t('vault.debtPayment', { person: row.reference ?? '' });
    default:
      return t(wallet ? (deposit ? 'vault.txn.added' : 'vault.txn.taken') : deposit ? 'vault.txn.saved' : 'vault.txn.withdrawn');
  }
}

function MoveIcon({ row, customs }: { row: TxnRow; customs: readonly CategoryRow[] | undefined }) {
  if (row.kind === 'expense') return <CategoryIcon category={row.reference ?? 'other'} customs={customs} className="text-destructive" />;
  if (row.kind === 'debt') return <HandCoinsIcon className="size-4 shrink-0 text-sun" aria-hidden />;
  if (row.kind === 'transfer') return <ArrowLeftRightIcon className="size-4 shrink-0 text-primary" aria-hidden />;
  return row.deltaMinor >= 0 ? (
    <CirclePlusIcon className="size-4 shrink-0 text-success" aria-hidden />
  ) : (
    <CircleMinusIcon className="size-4 shrink-0 text-muted-foreground" aria-hidden />
  );
}

/**
 * Movements grouped by day (`MovesLedger`), shared by the Vault's pots
 * and the Insights page. An expense's movement opens its expense; a
 * hand-made one can be removed, with Undo.
 */
export function MovesLedger({ rows, total, rates, empty }: { rows: TxnRow[]; total: number; rates: Rates; empty: string }) {
  const { t } = useTranslation();
  const { db, vault } = useHarvest();
  const customs = useCustomCategories();
  const [editing, setEditing] = useState<ExpenseRow | null>(null);

  if (rows.length === 0) {
    if (total > 0) {
      return (
        <div className="flex flex-col items-center gap-1 rounded-xl border border-dashed p-6 text-center">
          <SearchXIcon className="size-8 text-muted-foreground" aria-hidden />
          <p className="font-extrabold">{t('vault.noMatch')}</p>
          <p className="text-sm text-muted-foreground">{t('vault.noMatchBody')}</p>
        </div>
      );
    }
    return <p className="px-1 text-sm text-muted-foreground">{empty}</p>;
  }

  async function remove(row: TxnRow) {
    try {
      if (!(await vault.removeMove(row.uuid))) return;
    } catch (failure) {
      // A deposit already spent cannot be taken back out of the pot.
      toast.error(moneyError(t, failure));
      return;
    }
    const undo = () => vault.restoreMove(row.uuid).catch((failure: unknown) => void toast.error(moneyError(t, failure)));
    toast(t('vault.moveRemoved'), { action: { label: t('common.undo'), onClick: () => void undo() } });
  }

  async function openExpense(row: TxnRow) {
    const expense = row.linkUuid ? await db.rows('expenses').get(row.linkUuid) : undefined;
    if (expense && expense.deletedAt === null) setEditing(expense);
  }

  const days = [...new Set(rows.map((row) => row.harvestDay))];
  return (
    <div className="flex flex-col gap-3">
      {days.map((day) => (
        <section key={day} className="flex flex-col gap-1">
          <h3 className="px-1 text-xs font-extrabold text-muted-foreground">{formatDay(day, { weekday: 'long', day: 'numeric', month: 'short' })}</h3>
          <ul className="flex flex-col divide-y rounded-xl border bg-card">
            {rows
              .filter((row) => row.harvestDay === day)
              .map((row) => {
                const caption = conversionCaption(rates, Math.abs(row.deltaMinor), row.currency);
                const body = (
                  <>
                    <MoveIcon row={row} customs={customs} />
                    <span className="flex min-w-0 flex-1 flex-col">
                      <span className="truncate font-bold">{moveTitle(t, row)}</span>
                      {row.note && <span className="truncate text-xs text-muted-foreground">{row.note}</span>}
                    </span>
                    <span className="flex flex-col items-end" dir="ltr">
                      <span className={cn('font-extrabold tabular', row.deltaMinor >= 0 && 'text-success')}>
                        {row.deltaMinor >= 0 ? '+' : '−'}
                        {formatMoney(Math.abs(row.deltaMinor), row.currency)}
                      </span>
                      {caption && <span className="text-xs text-muted-foreground tabular">{caption}</span>}
                    </span>
                  </>
                );
                return (
                  <li key={row.uuid} className="flex flex-wrap items-center">
                    {row.kind === 'expense' && row.linkUuid ? (
                      <button
                        type="button"
                        onClick={() => void openExpense(row)}
                        className="flex min-w-0 flex-1 items-center gap-3 px-4 py-2.5 text-start outline-none hover:bg-accent focus-visible:ring-2 focus-visible:ring-ring"
                      >
                        {body}
                      </button>
                    ) : (
                      <div className="flex min-w-0 flex-1 items-center gap-3 px-4 py-2.5">{body}</div>
                    )}
                    {row.kind === 'manual' && (
                      <Button variant="ghost" size="icon-sm" className="me-2" aria-label={t('vault.removeMove')} title={t('vault.removeMove')} onClick={() => void remove(row)}>
                        <Trash2Icon />
                      </Button>
                    )}
                    {/* A transfer's own place; an expense's shows beside the expense (PL8). */}
                    {!(row.kind === 'expense' && row.linkUuid) && (
                      <LocationNote table="money_txns" uuid={row.uuid} className="basis-full px-4 pb-1.5" />
                    )}
                  </li>
                );
              })}
          </ul>
        </section>
      ))}
      {editing && <ExpenseEditor expense={editing} onClose={() => setEditing(null)} />}
    </div>
  );
}

