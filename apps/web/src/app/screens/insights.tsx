import { HarvestDay } from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import { ChartColumnIcon } from 'lucide-react';
import { useId, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group';
import { formatDay, formatMoney, formatNumber } from '@/lib/format';
import { cn } from '@/lib/utils';
import { categoryLabel } from '../components/category';
import { CategoryIcon, useCustomCategories } from '../components/money-bits';
import { MoveFilterBar, MovesLedger } from '../components/money-ledger';
import { useHarvest, useHarvestDay } from '../context';
import {
  type DayRange,
  type MoveFilter,
  type RangeKind,
  elapsedDays,
  emptyFilter,
  matchesFilter,
  monthRange,
  rangeDays,
  readInsights,
  weekRange,
} from '../data/vault';
import { useDefaultCurrency } from '../hooks';

/** Above this many bars, a label on each one is a smear (`_DailyBars`). */
const labelLimit = 10;

/** The slices' colours, in order of size. */
const strokes = ['stroke-primary', 'stroke-success', 'stroke-sun', 'stroke-destructive', 'stroke-brand-olive', 'stroke-brand-mid', 'stroke-muted-foreground'];
const swatches = ['bg-primary', 'bg-success', 'bg-sun', 'bg-destructive', 'bg-brand-olive', 'bg-brand-mid', 'bg-muted-foreground'];

/**
 * Daily bars with the amount written above each one; on a long range
 * only the peak is written, and every bar still answers on hover or
 * focus ([[Finances]] Layout).
 */
function DailyBars({ range, totals, currency, today }: { range: DayRange; totals: Map<string, number>; currency: string; today: HarvestDay }) {
  const { t } = useTranslation();
  const days = rangeDays(range);
  const labelEvery = days.length <= labelLimit;
  const values = days.map((day) => totals.get(day.key) ?? 0);
  const peak = Math.max(0, ...values);
  const top = Math.max(peak * 1.15, 1);
  return (
    <div
      role="img"
      aria-label={t('insights.chartLabel', { from: formatDay(range.from.key), to: formatDay(range.to.key), amount: formatMoney(peak, currency) })}
      className="flex h-52 items-end gap-0.5 sm:gap-1"
      dir="ltr"
    >
      {days.map((day, index) => {
        const amount = values[index]!;
        const label = amount > 0 && (labelEvery || amount === peak);
        const tick = labelEvery || day.day === 1 || day.day % 7 === 0;
        return (
          <div
            key={day.key}
            className="group flex h-full min-w-0 flex-1 flex-col items-center justify-end gap-1"
            title={t('insights.bar', { day: formatDay(day.key), amount: formatMoney(amount, currency) })}
          >
            <span className={cn('max-w-full truncate text-[10px] font-extrabold tabular', label ? '' : 'invisible group-hover:visible')}>
              {amount > 0 ? formatMoney(amount, currency) : ''}
            </span>
            <div
              className={cn('w-full max-w-6 rounded-t', day.equals(today) ? 'bg-primary' : 'bg-primary/55')}
              style={{ height: `${(amount / top) * 100}%`, minHeight: amount > 0 ? 2 : 0 }}
            />
            <span className="h-4 text-[10px] text-muted-foreground">
              {tick ? (labelEvery ? formatDay(day.key, { weekday: 'short' }) : formatNumber(day.day)) : ''}
            </span>
          </div>
        );
      })}
    </div>
  );
}

/** The category split: each slice with its share and what it is worth. */
function CategoryDonut({ entries, currency }: { entries: [string, number][]; currency: string }) {
  const { t } = useTranslation();
  const customs = useCustomCategories();
  const total = entries.reduce((sum, [, minor]) => sum + minor, 0);
  const size = 130;
  const stroke = 30;
  const radius = (size - stroke) / 2;
  const circumference = 2 * Math.PI * radius;
  const lengths = entries.map(([, minor]) => (minor / total) * circumference);
  const starts = lengths.map((_, index) => lengths.slice(0, index).reduce((sum, length) => sum + length, 0));
  return (
    <div className="flex flex-col items-center gap-4 sm:flex-row sm:items-start">
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} role="img" aria-label={t('insights.donutLabel')} className="shrink-0 -rotate-90">
        {entries.map(([category, minor], index) => (
            <circle
              key={category}
              cx={size / 2}
              cy={size / 2}
              r={radius}
              fill="none"
              strokeWidth={stroke}
              strokeDasharray={`${Math.max(lengths[index]! - 2, 0.5)} ${circumference}`}
              strokeDashoffset={-starts[index]!}
              className={strokes[index % strokes.length]}
            >
              <title>{`${categoryLabel(t, category)}: ${formatMoney(minor, currency)}`}</title>
            </circle>
        ))}
      </svg>
      <ul className="flex w-full min-w-0 flex-1 flex-col gap-2">
        {entries.map(([category, minor], index) => (
          <li key={category} className="flex items-start gap-2">
            <span className={cn('mt-1.5 size-2.5 shrink-0 rounded-full', swatches[index % swatches.length])} aria-hidden />
            <CategoryIcon category={category} customs={customs} className="mt-0.5 text-muted-foreground" />
            <span className="flex min-w-0 flex-col">
              <span className="truncate text-sm">{categoryLabel(t, category)}</span>
              <span className="text-xs font-extrabold text-muted-foreground tabular" dir="ltr">
                {t('insights.share', { percent: formatNumber(Math.round((minor * 100) / total)), amount: formatMoney(minor, currency) })}
              </span>
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
}

/**
 * Insights ([[Finances]] Layout): one span — this week, this month, or
 * any two dates — and everything on the page reads from it: the total,
 * the per-day average over the days that have actually elapsed, the
 * daily bars, the category split, and the moves the span contains.
 */
export function InsightsPanel() {
  const { t } = useTranslation();
  const { db } = useHarvest();
  const today = useHarvestDay();
  const currency = useDefaultCurrency();
  const id = useId();
  const [kind, setKind] = useState<RangeKind>('week');
  const [custom, setCustom] = useState<{ from: string; to: string }>(() => ({ from: today.addDays(-13).key, to: today.key }));
  const [filter, setFilter] = useState<MoveFilter>(emptyFilter);

  const customFrom = HarvestDay.tryParse(custom.from);
  const customTo = HarvestDay.tryParse(custom.to);
  const customValid = customFrom !== null && customTo !== null && customFrom.compareTo(customTo) <= 0;
  const range: DayRange =
    kind === 'month'
      ? monthRange(today)
      : kind === 'custom' && customValid
        ? { kind: 'custom', from: customFrom, to: customTo }
        : weekRange(today);

  const view = useLiveQuery(() => readInsights(db, range), [db, range.from.key, range.to.key]);
  const elapsed = elapsedDays(range, today);

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-col gap-2">
        <ToggleGroup type="single" value={kind} onValueChange={(value) => value && setKind(value as RangeKind)} aria-label={t('insights.range')}>
          {(['week', 'month', 'custom'] as const).map((option) => (
            <ToggleGroupItem key={option} value={option}>
              {t(`insights.${option}`)}
            </ToggleGroupItem>
          ))}
        </ToggleGroup>
        {kind === 'custom' && (
          <div className="grid grid-cols-2 gap-3 sm:max-w-md">
            <div className="flex flex-col gap-1">
              <Label htmlFor={`${id}-from`}>{t('insights.from')}</Label>
              <Input id={`${id}-from`} type="date" value={custom.from} onChange={(event) => setCustom({ ...custom, from: event.target.value })} />
            </div>
            <div className="flex flex-col gap-1">
              <Label htmlFor={`${id}-to`}>{t('insights.to')}</Label>
              <Input id={`${id}-to`} type="date" value={custom.to} onChange={(event) => setCustom({ ...custom, to: event.target.value })} />
            </div>
            {!customValid && (
              <p role="alert" className="col-span-2 text-sm font-semibold text-destructive">
                {t('insights.badRange')}
              </p>
            )}
          </div>
        )}
        {/* Whatever the segments say, the dates are spelled out. */}
        <p className="text-xs text-muted-foreground" aria-live="polite">
          {t('insights.rangeOf', { from: formatDay(range.from.key), to: formatDay(range.to.key) })}
        </p>
      </div>

      {view && (
        <>
          <div className="grid grid-cols-2 gap-2">
            <div className="flex flex-col gap-1 rounded-xl border bg-card p-4">
              <span className="text-sm font-bold text-muted-foreground">{t('insights.total')}</span>
              <span className="text-xl font-extrabold tabular" dir="ltr">
                {formatMoney(view.total, currency)}
              </span>
            </div>
            <div className="flex flex-col gap-1 rounded-xl border bg-card p-4">
              <span className="text-sm font-bold text-muted-foreground">{t('insights.perDay')}</span>
              <span className="text-xl font-extrabold tabular" dir="ltr">
                {formatMoney(elapsed === 0 ? 0 : Math.trunc(view.total / elapsed), currency)}
              </span>
            </div>
          </div>

          {view.total === 0 ? (
            <div className="flex flex-col items-center gap-2 rounded-xl border border-dashed p-6 text-center text-muted-foreground">
              <ChartColumnIcon className="size-8" aria-hidden />
              <p className="text-sm font-bold">{t('insights.noSpending')}</p>
            </div>
          ) : (
            <>
              <section className="flex flex-col gap-2" aria-labelledby={`${id}-daily`}>
                <h2 id={`${id}-daily`} className="px-1 text-sm font-extrabold text-muted-foreground">
                  {t('insights.daily')}
                </h2>
                <div className="rounded-xl border bg-card p-4">
                  <DailyBars range={range} totals={view.dayTotals} currency={currency} today={today} />
                </div>
              </section>
              <section className="flex flex-col gap-2" aria-labelledby={`${id}-split`}>
                <h2 id={`${id}-split`} className="px-1 text-sm font-extrabold text-muted-foreground">
                  {t('insights.byCategory')}
                </h2>
                <div className="rounded-xl border bg-card p-4">
                  <CategoryDonut entries={view.byCategory} currency={currency} />
                </div>
              </section>
            </>
          )}

          <Moves view={view} filter={filter} onFilter={setFilter} />
        </>
      )}
    </div>
  );
}

function Moves({ view, filter, onFilter }: { view: NonNullable<Awaited<ReturnType<typeof readInsights>>>; filter: MoveFilter; onFilter: (filter: MoveFilter) => void }) {
  const { t } = useTranslation();
  const shown = view.moves.filter((row) => matchesFilter(filter, row));
  return (
    <section className="flex flex-col gap-2" aria-labelledby="insights-moves">
      <div className="flex items-baseline justify-between gap-2 px-1">
        <h2 id="insights-moves" className="text-sm font-extrabold text-muted-foreground">
          {t('insights.moves')}
        </h2>
        <span className="text-xs text-muted-foreground">{t('insights.movesCount', { count: shown.length })}</span>
      </div>
      <MoveFilterBar filter={filter} onChange={onFilter} matches={shown.length} total={view.moves.length} />
      <MovesLedger rows={shown} total={view.moves.length} rates={view.rates} empty={t('vault.noMovements')} />
    </section>
  );
}
