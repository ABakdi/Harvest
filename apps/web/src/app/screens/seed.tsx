import type { HarvestDay } from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import { ArrowLeftIcon, CheckIcon, FlameIcon, HistoryIcon, NotebookPenIcon, PencilIcon, SproutIcon, TimerIcon } from 'lucide-react';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Link, useParams } from 'react-router';
import { Button } from '@/components/ui/button';
import { formatDay, formatNumber } from '@/lib/format';
import { cn } from '@/lib/utils';
import { EmptyState } from '../components/bits';
import { CheckInLocationNote } from '../components/location-note';
import { SeedNoteDialog } from '../components/seed-note-dialog';
import { useHarvest, useHarvestDay } from '../context';
import { readSeedStory, type SeedDay } from '../data/seed-notes';
import type { SeedRow } from '../data/seeds';
import { useDialogs } from '../dialogs';

/** How far back the strip looks: eight weeks. */
const stripSpan = 56;

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col">
      <dt className="text-xs font-bold opacity-80">{label}</dt>
      <dd className="text-lg font-extrabold tabular">{value}</dd>
    </div>
  );
}

/** The last eight weeks as a dotted strip: filled where I showed up. */
function RunStrip({ days, today }: { days: Set<string>; today: HarvestDay }) {
  const { t } = useTranslation();
  const start = today.addDays(-(stripSpan - 1));
  const shown = Array.from({ length: stripSpan }, (_, index) => start.addDays(index));
  const active = shown.filter((day) => days.has(day.key)).length;
  return (
    <div role="img" aria-label={t('seedDetail.runStrip', { count: active })} className="flex flex-wrap gap-1 rounded-xl border bg-card p-4">
      {shown.map((day) => (
        <span
          key={day.key}
          title={formatDay(day.key)}
          className={cn(
            'size-3 rounded-[4px]',
            days.has(day.key) ? 'bg-success' : 'bg-muted',
            day.key === today.key && 'ring-2 ring-primary ring-offset-1 ring-offset-card',
          )}
        />
      ))}
    </div>
  );
}

/** One day of the seed's life: what was logged, and what I wrote. */
function DayRow({ entry, seed }: { entry: SeedDay; seed: SeedRow }) {
  const { t } = useTranslation();
  const logged = entry.quantity > 0;
  return (
    <li className="flex items-start gap-3 rounded-xl border bg-card p-3">
      <span
        className={cn(
          'flex size-9 shrink-0 items-center justify-center rounded-full [&_svg]:size-4',
          logged ? 'bg-success/15 text-success' : 'bg-secondary text-muted-foreground',
        )}
        aria-hidden
      >
        {logged ? <CheckIcon /> : <NotebookPenIcon />}
      </span>
      <div className="flex min-w-0 flex-1 flex-col gap-0.5">
        <span className="font-extrabold">{formatDay(entry.day.key, { weekday: 'long', month: 'short', day: 'numeric' })}</span>
        <span className="text-xs text-muted-foreground">
          {logged
            ? seed.type === 'project'
              ? t('seedDetail.unitsLogged', { count: entry.quantity })
              : t('seedDetail.checkedIn')
            : t('seedDetail.noteOnly')}
        </span>
        {entry.note !== null && <p className="text-sm whitespace-pre-wrap">{entry.note}</p>}
        {/* Where the watering happened, if Places was there to say ([[Places]]). */}
        {logged && <CheckInLocationNote seedUuid={seed.uuid} day={entry.day.key} />}
      </div>
    </li>
  );
}

/**
 * Everything one seed has ever done: its streak, its run of days, and
 * the timeline of what I logged and wrote, newest first. The field
 * shows today; this shows the year.
 */
export function SeedScreen() {
  const { t } = useTranslation();
  const { uuid = '' } = useParams();
  const { db } = useHarvest();
  const dialogs = useDialogs();
  const today = useHarvestDay();
  const story = useLiveQuery(() => readSeedStory(db, uuid), [db, uuid]);
  const [writing, setWriting] = useState(false);
  if (!story) return null;

  const back = (
    <Button asChild variant="ghost" size="sm" className="w-fit">
      <Link to="/app/field">
        <ArrowLeftIcon className="rtl:rotate-180" />
        {t('field.today')}
      </Link>
    </Button>
  );

  const { seed } = story;
  if (!seed) {
    return (
      <div className="flex flex-col gap-4">
        {back}
        <EmptyState icon={<SproutIcon />} title={t('seedDetail.gone')} body={t('seedDetail.goneBody')} />
      </div>
    );
  }

  const logged = new Set(story.timeline.filter((entry) => entry.quantity > 0).map((entry) => entry.day.key));

  return (
    <div className="flex flex-col gap-4">
      {back}
      <div className="flex flex-wrap items-center gap-2">
        <h1 className="me-auto min-w-0 truncate text-2xl font-extrabold">{seed.title}</h1>
        <Button variant="outline" size="sm" onClick={() => setWriting(true)}>
          <NotebookPenIcon />
          {t('seedDetail.notesTitle')}
        </Button>
        {seed.archivedAt === null && (
          <Button asChild variant="outline" size="sm">
            <Link to={`/app/field/focus?seed=${seed.uuid}`}>
              <TimerIcon />
              {t('focus.timer')}
            </Link>
          </Button>
        )}
        <Button variant="outline" size="sm" onClick={() => dialogs.editSeed(seed)}>
          <PencilIcon />
          {t('common.edit')}
        </Button>
      </div>

      <section aria-label={t('seedDetail.streak')} className="bg-harvest-gradient flex flex-col gap-3 rounded-2xl p-5 text-white">
        <div className="flex items-center gap-2">
          <FlameIcon className="size-6" aria-hidden />
          <h2 className="text-base font-extrabold">{t('seedDetail.streak')}</h2>
        </div>
        <p className="text-4xl font-extrabold tabular">{t('seedDetail.dayCount', { count: story.current })}</p>
        <dl className="grid grid-cols-3 gap-2">
          <Stat label={t('seedDetail.best')} value={t('seedDetail.dayCount', { count: story.best })} />
          <Stat label={t('seedDetail.daysLogged')} value={formatNumber(story.daysLogged)} />
          <Stat
            label={seed.type === 'project' ? t('seedDetail.units') : t('seedDetail.checkIns')}
            value={formatNumber(story.total)}
          />
        </dl>
      </section>

      <RunStrip days={logged} today={today} />

      <section aria-labelledby="seed-history" className="flex flex-col gap-2">
        <div className="flex items-baseline gap-2">
          <h2 id="seed-history" className="text-lg font-extrabold">
            {t('seedDetail.history')}
          </h2>
          <span className="text-xs text-muted-foreground">{t('seedDetail.historyCount', { count: story.timeline.length })}</span>
        </div>
        {story.timeline.length === 0 ? (
          <EmptyState icon={<HistoryIcon />} title={t('seedDetail.historyEmpty')} body={t('seedDetail.historyEmptyBody')} />
        ) : (
          <ul className="flex flex-col gap-2">
            {story.timeline.map((entry) => (
              <DayRow key={entry.day.key} entry={entry} seed={seed} />
            ))}
          </ul>
        )}
      </section>
      {writing && <SeedNoteDialog seed={seed} onClose={() => setWriting(false)} />}
    </div>
  );
}
