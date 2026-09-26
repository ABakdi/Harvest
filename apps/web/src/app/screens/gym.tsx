import { useLiveQuery } from 'dexie-react-hooks';
import { BookOpenIcon, CalendarDaysIcon, ChevronRightIcon, DumbbellIcon, ListIcon, PlayIcon, PlusIcon } from 'lucide-react';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Link, useNavigate } from 'react-router';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { formatDay, formatNumber } from '@/lib/format';
import { EmptyState } from '../components/bits';
import { LocationNote } from '../components/location-note';
import { useHarvest } from '../context';
import { catalogueSize, useExerciseNames } from '../data/exercises';
import { nextDayOf, readPrograms, readRunning, readSessions } from '../data/gym';
import { ExerciseDetailDialog } from './gym/exercise-detail';
import { ExercisePicker } from './gym/exercise-picker';
import { usePictureOffer } from './gym/picture-offer';
import { SetList, UnitToggle, useAsker, useLoad, useVolume } from './gym/shared';
import { StartDialog, useStartSession } from './gym/start';

/**
 * The session left running — here, or on the phone and synced — is the
 * loudest thing on the screen: picking it back up is one click.
 */
function Running() {
  const { t } = useTranslation();
  const { db } = useHarvest();
  const running = useLiveQuery(() => readRunning(db), [db]);
  if (!running) return null;
  return (
    <Link
      to={`/app/body/gym/sessions/${running.session.uuid}`}
      className="flex items-center gap-3 rounded-2xl bg-secondary p-4 text-secondary-foreground outline-none hover:brightness-95 focus-visible:ring-2 focus-visible:ring-ring"
    >
      <DumbbellIcon className="size-6 shrink-0" aria-hidden />
      <span className="flex min-w-0 flex-1 flex-col">
        <span className="truncate font-extrabold">{running.session.title ?? t('gym.runningSession')}</span>
        <span className="text-sm">{t('gym.runningSessionBody', { done: running.doneSets, total: running.totalSets })}</span>
      </span>
      <span className="font-extrabold">{t('gym.resume')}</span>
      <ChevronRightIcon className="size-5 rtl:rotate-180" aria-hidden />
    </Link>
  );
}

function Programs() {
  const { t } = useTranslation();
  const { db, programs } = useHarvest();
  const navigate = useNavigate();
  const [asker, asking] = useAsker();
  const list = useLiveQuery(async () => {
    const trees = await readPrograms(db);
    return Promise.all(trees.map(async (tree) => ({ tree, next: await nextDayOf(db, tree) })));
  }, [db]);

  async function create() {
    const name = await asker.prompt({
      title: t('gym.newProgram'),
      label: t('gym.programName'),
      placeholder: t('gym.programNameHint'),
      action: t('common.create'),
    });
    if (!name?.trim()) return;
    const row = await programs.createProgram(name);
    void navigate(`/app/body/gym/programs/${row.uuid}`);
  }

  return (
    <section aria-labelledby="gym-programs" className="flex flex-col gap-3">
      <div className="flex items-center justify-between gap-2">
        <h2 id="gym-programs" className="text-lg font-extrabold">
          {t('gym.programs')}
        </h2>
        <Button variant="outline" size="sm" onClick={() => void create()}>
          <PlusIcon />
          {t('gym.newProgram')}
        </Button>
      </div>
      {list?.length === 0 && (
        <EmptyState
          icon={<ListIcon />}
          title={t('gym.noPrograms')}
          body={t('gym.noProgramsBody')}
          action={
            <Button onClick={() => void create()}>
              <PlusIcon />
              {t('gym.newProgram')}
            </Button>
          }
        />
      )}
      {list && list.length > 0 && (
        <ul className="flex flex-col gap-2">
          {list.map(({ tree, next }) => {
            const summary = t('gym.programSummary', {
              days: t('gym.dayCount', { count: tree.days.length }),
              sets: t('gym.setCount', { count: tree.days.reduce((sum, day) => sum + day.totalSets, 0) }),
            });
            return (
              <li key={tree.program.uuid}>
                <Link
                  to={`/app/body/gym/programs/${tree.program.uuid}`}
                  className="flex items-center gap-3 rounded-2xl border bg-card p-4 outline-none hover:bg-accent/50 focus-visible:ring-2 focus-visible:ring-ring"
                >
                  <ListIcon className="size-5 shrink-0 text-muted-foreground" aria-hidden />
                  <span className="flex min-w-0 flex-1 flex-col">
                    <span className="truncate font-extrabold">{tree.program.name}</span>
                    <span className="text-sm text-muted-foreground">{next ? `${summary} · ${t('gym.nextDay', { day: next.row.name })}` : summary}</span>
                  </span>
                  <ChevronRightIcon className="size-5 text-muted-foreground rtl:rotate-180" aria-hidden />
                </Link>
              </li>
            );
          })}
        </ul>
      )}
      {asking}
    </section>
  );
}

function History() {
  const { t } = useTranslation();
  const { db } = useHarvest();
  const nameOf = useExerciseNames(db);
  const load = useLoad();
  const volume = useVolume();
  const sessions = useLiveQuery(() => readSessions(db), [db]);
  const [detail, setDetail] = useState<string | null>(null);
  if (!sessions) return null;
  return (
    <section aria-labelledby="gym-history" className="flex flex-col gap-3">
      <h2 id="gym-history" className="text-lg font-extrabold">
        {t('gym.history')}
      </h2>
      {sessions.length === 0 ? (
        <EmptyState icon={<CalendarDaysIcon />} title={t('gym.noSessions')} body={t('gym.noSessionsBody')} />
      ) : (
        <ul className="flex flex-col gap-3">
          {sessions.map(({ session, programName, dayName, exercises, doneSets }) => (
            <li key={session.uuid} className="flex flex-col gap-2 rounded-2xl border bg-card p-4">
              <div className="flex flex-wrap items-baseline justify-between gap-x-3">
                <h3 className="font-extrabold">{session.title ?? dayName ?? programName ?? t('gym.session')}</h3>
                <span className="text-sm text-muted-foreground">{formatDay(session.harvestDay)}</span>
              </div>
              <p className="text-sm text-muted-foreground tabular">
                {exercises.length === 0 ? t('gym.noSetsLogged') : t('gym.summary', { count: doneSets, volume: volume(exercises.flatMap((exercise) => exercise.sets)) })}
              </p>
              <LocationNote table="workout_sessions" uuid={session.uuid} />
              <ul className="flex flex-col gap-1 text-sm">
                {exercises.map(({ row, sets }) => {
                  const done = sets.filter((set) => set.done);
                  return (
                    <li key={row.uuid} className="flex flex-wrap items-baseline gap-x-2">
                      <button
                        type="button"
                        onClick={() => setDetail(row.exerciseId)}
                        className={
                          row.skipped
                            ? 'rounded text-muted-foreground line-through outline-none hover:underline focus-visible:ring-2 focus-visible:ring-ring'
                            : 'rounded font-bold outline-none hover:underline focus-visible:ring-2 focus-visible:ring-ring'
                        }
                      >
                        {nameOf(row.exerciseId)}
                      </button>
                      {row.skipped ? (
                        <span className="text-xs text-muted-foreground">
                          {row.skipReason ? t('gym.skippedBecause', { reason: row.skipReason }) : t('gym.skipped')}
                        </span>
                      ) : (
                        <span className="text-muted-foreground tabular" dir="ltr">
                          <SetList labels={done.map((set) => `${load(set.weightGrams)}×${set.reps}`)} />
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
      )}
      {detail && <ExerciseDetailDialog exerciseId={detail} onClose={() => setDetail(null)} />}
    </section>
  );
}

/**
 * The training half of the Body tab (`gym_screen.dart`): the running
 * session first, then the programs and what they made, and the
 * catalogue last — a reference book does not go ahead of the training.
 */
export function GymPanel() {
  const { t } = useTranslation();
  const startSession = useStartSession();
  const [picking, setPicking] = useState(false);
  const [browsing, setBrowsing] = useState(false);
  // The picture after a session, when its program asks for one then.
  const picture = usePictureOffer();

  async function start() {
    const outcome = await startSession();
    if (outcome === 'pick') setPicking(true);
    if (outcome === 'none') toast(t('gym.noProgramToStartBody'));
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-3">
        <Running />
        <div className="flex flex-wrap items-center justify-between gap-3">
          <Button onClick={() => void start()}>
            <PlayIcon />
            {t('gym.start')}
          </Button>
          <UnitToggle />
        </div>
      </div>
      <Programs />
      <History />
      <section aria-labelledby="gym-exercises" className="flex flex-col gap-3">
        <h2 id="gym-exercises" className="text-lg font-extrabold">
          {t('gym.exercisesTitle')}
        </h2>
        <button
          type="button"
          onClick={() => setBrowsing(true)}
          className="flex items-center gap-3 rounded-2xl border bg-card p-4 text-start outline-none hover:bg-accent/50 focus-visible:ring-2 focus-visible:ring-ring"
        >
          <BookOpenIcon className="size-5 shrink-0 text-muted-foreground" aria-hidden />
          <span className="flex min-w-0 flex-1 flex-col">
            <span className="font-extrabold">{t('gym.exerciseCount', { count: catalogueSize, replace: { count: formatNumber(catalogueSize) } })}</span>
            <span className="text-sm text-muted-foreground">{t('gym.catalogueHint')}</span>
          </span>
          <ChevronRightIcon className="size-5 text-muted-foreground rtl:rotate-180" aria-hidden />
        </button>
      </section>
      {picking && <StartDialog onClose={() => setPicking(false)} />}
      {browsing && <ExercisePicker title={t('gym.exercisesTitle')} onClose={() => setBrowsing(false)} />}
      {picture}
    </div>
  );
}
