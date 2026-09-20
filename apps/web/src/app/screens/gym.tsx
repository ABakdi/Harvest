import { weightIn } from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import { CalendarDaysIcon, DumbbellIcon, SmartphoneIcon } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { formatDay, formatNumber } from '@/lib/format';
import { EmptyState } from '../components/bits';
import { useHarvest } from '../context';
import { useExerciseNames } from '../data/exercises';
import { readPrograms, readSessions } from '../data/gym';
import { useSetting } from '../hooks';

/** `82.5 kg`, trailing zeros dropped, in the unit the phone was set to. */
function useLoad(): (grams: number) => string {
  const { t } = useTranslation();
  const unit = useSetting('health.weightUnit') === 'lb' ? 'lb' : 'kg';
  return (grams: number) =>
    `${formatNumber(weightIn(unit, grams), { maximumFractionDigits: 2 })} ${t(`body.unit.${unit}`)}`;
}

function Programs() {
  const { t } = useTranslation();
  const { db } = useHarvest();
  const nameOf = useExerciseNames(db);
  const programs = useLiveQuery(() => readPrograms(db), [db]);
  if (!programs) return null;
  if (programs.length === 0) {
    return <EmptyState icon={<DumbbellIcon />} title={t('gym.noPrograms')} body={t('gym.noProgramsBody')} />;
  }
  return (
    <ul className="flex flex-col gap-3">
      {programs.map(({ program, days }) => (
        <li key={program.uuid} className="flex flex-col gap-2 rounded-2xl border bg-card p-4">
          <h3 className="font-extrabold">{program.name}</h3>
          {program.note && <p className="text-sm text-muted-foreground">{program.note}</p>}
          <ul className="flex flex-col gap-1.5 text-sm">
            {days.map((day) => (
              <li key={day.uuid} className="flex flex-wrap items-baseline gap-x-2">
                <span className="font-bold">{day.name}</span>
                <span className="text-muted-foreground">
                  {day.exercises.length === 0
                    ? t('gym.dayEmpty')
                    : day.exercises.map((id) => nameOf(id)).join(' · ')}
                </span>
              </li>
            ))}
          </ul>
        </li>
      ))}
    </ul>
  );
}

function History() {
  const { t } = useTranslation();
  const { db } = useHarvest();
  const nameOf = useExerciseNames(db);
  const load = useLoad();
  const sessions = useLiveQuery(() => readSessions(db), [db]);
  if (!sessions) return null;
  if (sessions.length === 0) {
    return <EmptyState icon={<CalendarDaysIcon />} title={t('gym.noSessions')} body={t('gym.noSessionsBody')} />;
  }
  return (
    <ul className="flex flex-col gap-3">
      {sessions.map(({ session, programName, dayName, exercises, doneSets, volumeGrams }) => (
        <li key={session.uuid} className="flex flex-col gap-2 rounded-2xl border bg-card p-4">
          <div className="flex flex-wrap items-baseline justify-between gap-x-3">
            <h3 className="font-extrabold">{session.title ?? dayName ?? programName ?? t('gym.session')}</h3>
            <span className="text-sm text-muted-foreground">{formatDay(session.harvestDay)}</span>
          </div>
          <p className="text-sm text-muted-foreground tabular">
            {t('gym.summary', { sets: doneSets, volume: load(volumeGrams) })}
          </p>
          <ul className="flex flex-col gap-1 text-sm">
            {exercises.map(({ row, sets }) => {
              const done = sets.filter((set) => set.done);
              return (
                <li key={row.uuid} className="flex flex-wrap items-baseline gap-x-2">
                  <span className={row.skipped ? 'text-muted-foreground line-through' : 'font-bold'}>{nameOf(row.exerciseId)}</span>
                  {row.skipped ? (
                    <span className="text-xs text-muted-foreground">
                      {row.skipReason ? t('gym.skippedBecause', { reason: row.skipReason }) : t('gym.skipped')}
                    </span>
                  ) : (
                    <span className="text-muted-foreground tabular" dir="ltr">
                      {done.map((set) => `${load(set.weightGrams)}×${set.reps}`).join('  ')}
                    </span>
                  )}
                </li>
              );
            })}
          </ul>
          {session.note && <p className="text-sm text-muted-foreground">{session.note}</p>}
        </li>
      ))}
    </ul>
  );
}

/**
 * The training half of the Body tab: what the programs ask for, and
 * what was actually done.
 *
 * A session itself stays on the phone — it is ticked one-handed
 * between sets, beside the rack, which is not where a laptop is
 * ([[Web]]).
 */
export function GymPanel() {
  const { t } = useTranslation();
  return (
    <div className="flex flex-col gap-6">
      <section className="flex flex-col gap-3">
        <h2 className="text-lg font-extrabold">{t('gym.programs')}</h2>
        <Programs />
      </section>
      <section className="flex flex-col gap-3">
        <h2 className="text-lg font-extrabold">{t('gym.history')}</h2>
        <History />
      </section>
      <p className="flex items-center gap-2 text-xs text-muted-foreground">
        <SmartphoneIcon className="size-4" aria-hidden />
        {t('gym.phoneOnly')}
      </p>
    </div>
  );
}
