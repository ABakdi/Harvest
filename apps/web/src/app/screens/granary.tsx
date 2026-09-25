import { useLiveQuery } from 'dexie-react-hooks';
import { CalendarClockIcon, ChevronLeftIcon, ChevronRightIcon, PlusIcon, RepeatIcon, WalletIcon } from 'lucide-react';
import { useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { formatDate, formatDay, formatMoney } from '@/lib/format';
import { EmptyState } from '../components/bits';
import { categoryLabel } from '../components/category';
import { LocationNote } from '../components/location-note';
import { PassphrasePrompt } from '../components/passphrase-prompt';
import { useHarvest, useHarvestDay } from '../context';
import { type ExpenseRow, readRepeatSuggestion } from '../data/money';
import { useDialogs } from '../dialogs';
import { usePrivateKey } from '../hooks';
import { BudgetPanel } from './budget';
import { InsightsPanel } from './insights';
import { VaultPanel } from './vault';
import { WishlistPanel } from './wishlist';

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

/**
 * Day four of the same thing three days running, as a one-tap card
 * ([[Finances]] Smart repeats). Like the phone's, the tap logs the
 * expense and nothing else: where the money came from is a question
 * for the editor.
 */
function RepeatCard() {
  const { t } = useTranslation();
  const { db, money } = useHarvest();
  const today = useHarvestDay();
  const suggestion = useLiveQuery(() => readRepeatSuggestion(db, today), [db, today.key]);
  // One tap, one expense: a second click while the first is still
  // writing is not a second coffee.
  const busy = useRef(false);
  const [logging, setLogging] = useState(false);
  if (!suggestion) return null;
  const amount = formatMoney(suggestion.amountMinor, suggestion.currency);

  async function log() {
    if (!suggestion || busy.current) return;
    busy.current = true;
    setLogging(true);
    try {
      await money.log({ ...suggestion, day: today.key, fromWallet: false });
      toast.success(t('money.repeatLogged', { amount }));
    } catch {
      toast.error(t('common.saveFailed'));
    } finally {
      busy.current = false;
      setLogging(false);
    }
  }

  return (
    <section className="flex items-center gap-3 rounded-xl border border-success/40 bg-success/5 p-4" aria-label={t('money.repeatTitle')}>
      <RepeatIcon className="size-5 shrink-0 text-success" aria-hidden />
      <div className="flex min-w-0 flex-1 flex-col">
        <span className="truncate font-extrabold">
          <span dir="ltr" className="tabular">
            {amount}
          </span>
          {' · '}
          {categoryLabel(t, suggestion.category)}
        </span>
        <span className="text-xs text-muted-foreground">{t('money.repeatTitle')}</span>
      </div>
      <Button disabled={logging} onClick={() => void log()}>
        {t('money.logIt')}
      </Button>
    </section>
  );
}

/**
 * Expenses grouped under their days, each one a tap from its editor.
 * [label] names a day's heading; the month's list and the upcoming one
 * share it.
 */
function DayGroups({ rows, label, idPrefix, nested = false }: { rows: ExpenseRow[]; label: (day: string) => string; idPrefix: string; nested?: boolean }) {
  const Heading = nested ? 'h3' : 'h2';
  const dialogs = useDialogs();
  const { t } = useTranslation();
  const days = [...new Set(rows.map((row) => row.harvestDay))];
  return (
    <div className="flex flex-col gap-4">
      {days.map((day) => {
        const entries = rows.filter((row) => row.harvestDay === day);
        return (
          <section key={day} aria-labelledby={`${idPrefix}-${day}`} className="flex flex-col gap-1">
            <div className="flex items-baseline justify-between gap-2 px-1">
              <Heading id={`${idPrefix}-${day}`} className="text-sm font-extrabold text-muted-foreground">
                {label(day)}
              </Heading>
              <span className="text-sm font-bold">
                <Totals rows={entries} empty="" />
              </span>
            </div>
            <ul className="flex flex-col divide-y rounded-xl border bg-card">
              {entries.map((row) => (
                <li key={row.uuid} className="flex flex-col">
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
                  <LocationNote table="expenses" uuid={row.uuid} className="px-4 pb-1.5" />
                </li>
              ))}
            </ul>
          </section>
        );
      })}
    </div>
  );
}

/**
 * Today's spending and the month's, day by day ([[Finances]]). The
 * month counts up to today; an expense logged ahead waits for its day
 * under Upcoming, where it can still be opened, changed or removed.
 */
function ExpensesPanel() {
  const { t } = useTranslation();
  const { db } = useHarvest();
  const today = useHarvestDay();
  const current = today.key.slice(0, 7);
  const [month, setMonth] = useState(current);

  const rows = useLiveQuery(
    async () =>
      (await db.rows('expenses').toArray())
        .filter((row) => row.deletedAt === null && (row.harvestDay.startsWith(month) || row.harvestDay >= today.key))
        .sort((a, b) => b.harvestDay.localeCompare(a.harvestDay) || b.loggedAt.localeCompare(a.loggedAt)),
    [db, month, today.key],
  );

  if (!rows) return null;

  const todays = rows.filter((row) => row.harvestDay === today.key);
  const monthRows = rows.filter((row) => row.harvestDay.startsWith(month) && row.harvestDay <= today.key);
  // Soonest first: what comes next is what I want to see.
  const upcoming = rows
    .filter((row) => row.harvestDay > today.key)
    .sort((a, b) => a.harvestDay.localeCompare(b.harvestDay) || b.loggedAt.localeCompare(a.loggedAt));
  const [year, monthNumber] = month.split('-').map(Number) as [number, number];
  const dayLabel = (day: string) => (day === today.key ? t('money.todayLabel') : formatDay(day, { weekday: 'long', day: 'numeric', month: 'short' }));

  return (
    <div className="flex flex-col gap-4">
      <RepeatCard />
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

      {upcoming.length > 0 && (
        <section aria-labelledby="expenses-upcoming" className="flex flex-col gap-2">
          <div className="flex flex-col px-1">
            <h2 id="expenses-upcoming" className="flex items-center gap-1.5 text-base font-extrabold">
              <CalendarClockIcon className="size-4 text-muted-foreground" aria-hidden />
              {t('moneyWeb.upcoming')}
            </h2>
            <p className="text-xs text-muted-foreground">{t('moneyWeb.upcomingBody', { count: upcoming.length })}</p>
          </div>
          <DayGroups rows={upcoming} label={dayLabel} idPrefix="ahead" nested />
        </section>
      )}

      {monthRows.length === 0 ? (
        <EmptyState icon={<WalletIcon />} title={t('money.emptyTitle')} body={t('money.emptyBody')} />
      ) : (
        <DayGroups rows={monthRows} label={dayLabel} idPrefix="day" />
      )}
    </div>
  );
}

/**
 * The Granary, in four views of the same home: what I spent, what I
 * have, what the month allows — and the Wishlist, what I plan to buy
 * ([[Finances]], [[Wishlist]]).
 *
 * The private tier is asked for once, here, because the three money
 * tabs read rows that are sealed on the wire ([[Sync-Strategy]]). The
 * wishlist is a plain table, so it renders even while the passphrase
 * is missing.
 */
export function GranaryScreen() {
  const { t } = useTranslation();
  const dialogs = useDialogs();
  const unlocked = usePrivateKey();
  const [tab, setTab] = useState('expenses');

  if (unlocked === undefined) return null;

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between gap-2">
        <h1 className="text-2xl font-extrabold">{t('money.granary')}</h1>
        {unlocked && (
          <Button onClick={dialogs.logExpense} title={`${t('money.log')} (e)`}>
            <PlusIcon />
            {t('money.log')}
          </Button>
        )}
      </div>
      <Tabs value={tab} onValueChange={setTab}>
        <TabsList className="max-w-full justify-start overflow-x-auto">
          <TabsTrigger value="expenses">{t('money.expenses')}</TabsTrigger>
          <TabsTrigger value="vault">{t('vault.title')}</TabsTrigger>
          <TabsTrigger value="insights">{t('insights.title')}</TabsTrigger>
          <TabsTrigger value="budget">{t('budget.title')}</TabsTrigger>
          <TabsTrigger value="wishlist">{t('wishlist.title')}</TabsTrigger>
        </TabsList>
        <TabsContent value="wishlist">
          <WishlistPanel />
        </TabsContent>
        {unlocked ? (
          <>
            <TabsContent value="expenses">
              <ExpensesPanel />
            </TabsContent>
            <TabsContent value="vault">
              <VaultPanel />
            </TabsContent>
            <TabsContent value="insights">
              <InsightsPanel />
            </TabsContent>
            <TabsContent value="budget">
              <BudgetPanel />
            </TabsContent>
          </>
        ) : (
          tab !== 'wishlist' && (
            <div className="rounded-2xl border bg-card p-5">
              <PassphrasePrompt />
            </div>
          )
        )}
      </Tabs>
    </div>
  );
}
