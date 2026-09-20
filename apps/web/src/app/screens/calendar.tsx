import { HarvestDay } from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import { CameraIcon, ChevronLeftIcon, ChevronRightIcon, CoinsIcon, DumbbellIcon, FlagIcon } from 'lucide-react';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Link } from 'react-router';
import { Button } from '@/components/ui/button';
import { formatDate, formatDay, formatNumber } from '@/lib/format';
import { cn } from '@/lib/utils';
import { useHarvest, useHarvestDay } from '../context';
import { FieldTabs } from './field';
import { type CalendarDay, readMonth } from '../data/calendar';

/** Monday first, in the language on screen. */
function weekdayNames(locale: string): string[] {
  const format = new Intl.DateTimeFormat(locale, { weekday: 'short' });
  // 2026-01-05 is a Monday.
  return Array.from({ length: 7 }, (_, index) => format.format(new Date(2026, 0, 5 + index)));
}

function Cell({
  day,
  selected,
  today,
  onPick,
}: {
  day: CalendarDay;
  selected: boolean;
  today: boolean;
  onPick: () => void;
}) {
  const { t } = useTranslation();
  const due = day.entries.filter((entry) => !entry.deadline);
  const ratio = due.length === 0 ? 0 : day.doneCount / due.length;
  return (
    <button
      type="button"
      onClick={onPick}
      aria-pressed={selected}
      aria-label={t('calendar.cell', { day: formatDay(day.day.key), count: due.length })}
      className={cn(
        'flex min-h-16 flex-col items-center gap-1 rounded-lg border p-1 outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring',
        selected ? 'border-primary bg-card' : 'border-transparent bg-card/50 hover:bg-card',
      )}
    >
      <span className={cn('text-sm font-extrabold tabular', today && 'rounded-full bg-primary px-1.5 text-primary-foreground')}>
        {formatNumber(day.day.day)}
      </span>
      {due.length > 0 && (
        <span className="flex items-center gap-1 text-[10px] font-bold text-muted-foreground tabular">
          <span
            className={cn(
              'size-2 rounded-full',
              ratio === 1 ? 'bg-success' : ratio > 0 ? 'bg-sun' : 'bg-muted-foreground/40',
            )}
            aria-hidden
          />
          {day.doneCount}/{due.length}
        </span>
      )}
      <span className="flex items-center gap-0.5 text-muted-foreground [&_svg]:size-3">
        {day.entries.some((entry) => entry.deadline) && <FlagIcon />}
        {day.sessions > 0 && <DumbbellIcon />}
        {day.memories > 0 && <CameraIcon />}
        {day.expenses > 0 && <CoinsIcon />}
      </span>
    </button>
  );
}

/**
 * The month: habits due, to-dos planned, deadlines set — and a mark
 * for the day's other traces, a session, a picture, an expense.
 *
 * Projects are implicitly daily and stay off the grid, as they do on
 * the phone: every square carrying every project would make the count
 * meaningless.
 */
export function CalendarScreen() {
  const { t, i18n } = useTranslation();
  const { db } = useHarvest();
  const today = useHarvestDay();
  const [selectedKey, setSelectedKey] = useState(today.key);
  const selected = HarvestDay.tryParse(selectedKey) ?? today;
  const month = useLiveQuery(() => readMonth(db, selected), [db, `${selected.year}-${selected.month}`]);

  const first = selected.addDays(1 - selected.day);
  const blanks = first.weekday - 1;
  const names = weekdayNames(i18n.language === 'ar' ? 'ar' : 'en');
  const day = month?.get(selected.key);

  return (
    <div className="flex flex-col gap-4">
      <FieldTabs />
      <div className="flex items-center gap-1">
        <h1 className="me-auto text-2xl font-extrabold">{t('calendar.title')}</h1>
        <Button variant="ghost" size="icon-sm" aria-label={t('calendar.previous')} onClick={() => setSelectedKey(first.addDays(-1).key)}>
          <ChevronLeftIcon className="rtl:rotate-180" />
        </Button>
        <span className="min-w-36 text-center text-sm font-bold" aria-live="polite">
          {formatDate(first.toDate(), { month: 'long', year: 'numeric' })}
        </span>
        <Button
          variant="ghost"
          size="icon-sm"
          aria-label={t('calendar.next')}
          onClick={() => setSelectedKey(first.addDays(32).addDays(1 - first.addDays(32).day).key)}
        >
          <ChevronRightIcon className="rtl:rotate-180" />
        </Button>
      </div>

      <div className="grid grid-cols-7 gap-1">
        {names.map((name) => (
          <span key={name} className="pb-1 text-center text-[11px] font-extrabold text-muted-foreground">
            {name}
          </span>
        ))}
        {Array.from({ length: blanks }, (_, index) => (
          <span key={`blank-${index}`} />
        ))}
        {month &&
          [...month.values()].map((cell) => (
            <Cell
              key={cell.day.key}
              day={cell}
              today={cell.day.key === today.key}
              selected={cell.day.key === selected.key}
              onPick={() => setSelectedKey(cell.day.key)}
            />
          ))}
      </div>

      <section className="flex flex-col gap-2" aria-live="polite">
        <h2 className="text-sm font-extrabold text-muted-foreground">
          {selected.key === today.key ? t('calendar.todayLabel') : formatDay(selected.key, { weekday: 'long', day: 'numeric', month: 'long' })}
        </h2>
        {!day || day.entries.length === 0 ? (
          <p className="text-sm text-muted-foreground">{t('calendar.nothingDue')}</p>
        ) : (
          <ul className="flex flex-col divide-y rounded-xl border bg-card">
            {day.entries.map((entry) => (
              <li key={`${entry.row.uuid}-${entry.deadline ? 'deadline' : 'due'}`}>
                <Link
                  to={`/app/field`}
                  className="flex items-center gap-3 px-4 py-3 outline-none hover:bg-accent focus-visible:ring-2 focus-visible:ring-ring"
                >
                  <span className="flex min-w-0 flex-1 flex-col">
                    <span className={cn('font-bold', entry.done && 'text-muted-foreground line-through')}>{entry.row.title}</span>
                    {entry.deadline && <span className="text-xs text-muted-foreground">{t('calendar.deadline')}</span>}
                  </span>
                  {entry.deadline && <FlagIcon className="size-4 text-destructive" aria-hidden />}
                </Link>
              </li>
            ))}
          </ul>
        )}
        {day && (day.sessions > 0 || day.memories > 0 || day.expenses > 0) && (
          <p className="flex flex-wrap gap-x-4 px-1 text-xs text-muted-foreground">
            {day.sessions > 0 && <span>{t('calendar.sessions', { count: day.sessions })}</span>}
            {day.memories > 0 && <span>{t('calendar.memories', { count: day.memories })}</span>}
            {day.expenses > 0 && <span>{t('calendar.expenses', { count: day.expenses })}</span>}
          </p>
        )}
      </section>
    </div>
  );
}
