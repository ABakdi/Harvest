import { useLiveQuery } from 'dexie-react-hooks';
import { ChevronLeftIcon, ChevronRightIcon, PlusIcon, WalletIcon } from 'lucide-react';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Button } from '@/components/ui/button';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { formatDate, formatDay, formatMoney } from '@/lib/format';
import { EmptyState } from '../components/bits';
import { categoryLabel } from '../components/category';
import { PassphrasePrompt } from '../components/passphrase-prompt';
import { useHarvest, useHarvestDay } from '../context';
import type { ExpenseRow } from '../data/money';
import { useDialogs } from '../dialogs';
import { usePrivateKey } from '../hooks';
import { BudgetPanel } from './budget';
import { VaultPanel } from './vault';

/** Sums per currency: amounts in different currencies are never added together. */
function totals(rows: ExpenseRow[]): [string, number][] {
  const sums = new Map<string, number>();
  for (const row of rows) sums.set(row.currency, (sums.get(row.currency) ?? 0) + row.amountMinor);
  return [...sums.entries()].sort((a, b) => b[1] - a[1]);
}

function Totals({ rows, empty }: { rows: ExpenseRow[]; empty: string }) {
  const list = totals(rows);
  if (list.length === 0) return <span className="text-muted-foreground">{empty}</span>;
  return (
    <span className="flex flex-wrap gap-x-3 tabular" dir="ltr">
      {list.map(([currency, minor]) => (
        <span key={currency}>{formatMoney(minor, currency)}</span>
      ))}
    </span>
  );
}

function shiftMonth(month: string, by: number): string {
  const [year, value] = month.split('-').map(Number) as [number, number];
  const date = new Date(Date.UTC(year, value - 1 + by, 1));
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}`;
}

/** Today's spending and the month's, day by day ([[Finances]]). */
function ExpensesPanel() {
  const { t } = useTranslation();
  const { db } = useHarvest();
  const dialogs = useDialogs();
  const today = useHarvestDay();
  const current = today.key.slice(0, 7);
  const [month, setMonth] = useState(current);

  const rows = useLiveQuery(
    async () =>
      (await db.rows('expenses').toArray())
        .filter((row) => row.deletedAt === null && (row.harvestDay.startsWith(month) || row.harvestDay === today.key))
        .sort((a, b) => b.harvestDay.localeCompare(a.harvestDay) || b.loggedAt.localeCompare(a.loggedAt)),
    [db, month, today.key],
  );

  if (!rows) return null;

  const todays = rows.filter((row) => row.harvestDay === today.key);
  const monthRows = rows.filter((row) => row.harvestDay.startsWith(month));
  const days = [...new Set(monthRows.map((row) => row.harvestDay))];
  const [year, monthNumber] = month.split('-').map(Number) as [number, number];

  return (
    <div className="flex flex-col gap-4">
      <section className="grid gap-3 sm:grid-cols-2">
        <div className="flex flex-col gap-1 rounded-xl border bg-card p-4">
          <span className="text-sm font-bold text-muted-foreground">{t('money.today')}</span>
          <span className="text-2xl font-extrabold">
            <Totals rows={todays} empty={t('money.nothingToday')} />
          </span>
          <span className="text-xs text-muted-foreground">{t('money.expensesCount', { count: todays.length })}</span>
        </div>
        <div className="flex flex-col gap-1 rounded-xl border bg-card p-4">
          <div className="flex items-center gap-1">
            <Button variant="ghost" size="icon-sm" aria-label={t('money.previousMonth')} onClick={() => setMonth(shiftMonth(month, -1))}>
              <ChevronLeftIcon className="rtl:rotate-180" />
            </Button>
            <span className="flex-1 text-center text-sm font-bold text-muted-foreground" aria-live="polite">
              {formatDate(new Date(year, monthNumber - 1, 1), { month: 'long', year: 'numeric' })}
            </span>
            <Button
              variant="ghost"
              size="icon-sm"
              aria-label={t('money.nextMonth')}
              disabled={month >= current}
              onClick={() => setMonth(shiftMonth(month, 1))}
            >
              <ChevronRightIcon className="rtl:rotate-180" />
            </Button>
          </div>
          <span className="text-2xl font-extrabold">
            <Totals rows={monthRows} empty={t('money.nothingMonth')} />
          </span>
          <span className="text-xs text-muted-foreground">{t('money.expensesCount', { count: monthRows.length })}</span>
        </div>
      </section>

      {days.length === 0 ? (
        <EmptyState icon={<WalletIcon />} title={t('money.emptyTitle')} body={t('money.emptyBody')} />
      ) : (
        <div className="flex flex-col gap-4">
          {days.map((day) => {
            const entries = monthRows.filter((row) => row.harvestDay === day);
            return (
              <section key={day} aria-labelledby={`day-${day}`} className="flex flex-col gap-1">
                <div className="flex items-baseline justify-between gap-2 px-1">
                  <h2 id={`day-${day}`} className="text-sm font-extrabold text-muted-foreground">
                    {day === today.key ? t('money.todayLabel') : formatDay(day, { weekday: 'long', day: 'numeric', month: 'short' })}
                  </h2>
                  <span className="text-sm font-bold">
                    <Totals rows={entries} empty="" />
                  </span>
                </div>
                <ul className="flex flex-col divide-y rounded-xl border bg-card">
                  {entries.map((row) => (
                    <li key={row.uuid}>
                      <button
                        type="button"
                        onClick={() => dialogs.editExpense(row)}
                        className="flex w-full items-center gap-3 px-4 py-3 text-start outline-none hover:bg-accent focus-visible:ring-2 focus-visible:ring-ring"
                      >
                        <span className="flex min-w-0 flex-1 flex-col">
                          <span className="font-bold">{categoryLabel(t, row.category)}</span>
                          {row.note && <span className="truncate text-xs text-muted-foreground">{row.note}</span>}
                        </span>
                        <span className="font-extrabold tabular" dir="ltr">
                          {formatMoney(row.amountMinor, row.currency)}
                        </span>
                      </button>
                    </li>
                  ))}
                </ul>
              </section>
            );
          })}
        </div>
      )}
    </div>
  );
}

/**
 * The Granary, in three views of the same money: what I spent, what I
 * have, and what the month allows ([[Finances]]).
 *
 * The private tier is asked for once, here, because all three read
 * rows that are sealed on the wire ([[Sync-Strategy]]).
 */
export function GranaryScreen() {
  const { t } = useTranslation();
  const dialogs = useDialogs();
  const unlocked = usePrivateKey();
  const [tab, setTab] = useState('expenses');

  if (unlocked === undefined) return null;
  if (!unlocked) {
    return (
      <div className="mx-auto flex w-full max-w-lg flex-col gap-4">
        <h1 className="text-2xl font-extrabold">{t('money.granary')}</h1>
        <div className="rounded-2xl border bg-card p-5">
          <PassphrasePrompt />
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between gap-2">
        <h1 className="text-2xl font-extrabold">{t('money.granary')}</h1>
        <Button onClick={dialogs.logExpense} title={`${t('money.log')} (e)`}>
          <PlusIcon />
          {t('money.log')}
        </Button>
      </div>
      <Tabs value={tab} onValueChange={setTab}>
        <TabsList>
          <TabsTrigger value="expenses">{t('money.expenses')}</TabsTrigger>
          <TabsTrigger value="vault">{t('vault.title')}</TabsTrigger>
          <TabsTrigger value="budget">{t('budget.title')}</TabsTrigger>
        </TabsList>
        <TabsContent value="expenses">
          <ExpensesPanel />
        </TabsContent>
        <TabsContent value="vault">
          <VaultPanel />
        </TabsContent>
        <TabsContent value="budget">
          <BudgetPanel />
        </TabsContent>
      </Tabs>
    </div>
  );
}
