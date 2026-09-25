import {
  defaultRestSeconds,
  estimatedOneRepMax,
  finishQuestion,
  loadFieldValue,
  recordsBeatenBy,
  roundLoad,
  sessionElapsedSeconds,
  usesBar,
  weightToGrams,
  type ExerciseRecords,
} from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import {
  ArrowLeftIcon,
  CheckIcon,
  EllipsisVerticalIcon,
  FlagIcon,
  PauseIcon,
  PlayIcon,
  PlusIcon,
  TimerIcon,
  TrophyIcon,
  XIcon,
} from 'lucide-react';
import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Link, useNavigate, useParams } from 'react-router';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Input } from '@/components/ui/input';
import { cn } from '@/lib/utils';
import { EmptyState } from '../../components/bits';
import { useHarvest } from '../../context';
import { useExercise } from '../../data/exercises';
import { albumForPicture, exerciseRecords, lastTime, readSession, type ExerciseInSession, type SessionRow, type SetRow } from '../../data/gym';
import { ExerciseDetailDialog } from './exercise-detail';
import { ExercisePicker } from './exercise-picker';
import { usePictureOffer, type PictureState } from './picture-offer';
import { PlatesDialog } from './plates';
import { SetBadge } from './program-editor';
import { RestField, clockText, prettyStoredLabel, useAsker, useLoad, useUnit, type Asker } from './shared';

// -------------------------------------------------------------------- rest

interface RestTimer {
  endsAt: number | null;
  total: number;
  start: (seconds: number) => void;
  extend: (seconds: number) => void;
  stop: () => void;
}

/**
 * The rest, counted down (`RestTimerController`). It starts itself when
 * a set is ticked; at zero the bar buzzes where the device can and a
 * toast says so. It lives with the screen: a laptop is not in a pocket.
 */
function useRestTimer(clock: () => Date): RestTimer {
  const { t } = useTranslation();
  const [endsAt, setEndsAt] = useState<number | null>(null);
  const [total, setTotal] = useState(0);
  useEffect(() => {
    if (endsAt === null) return;
    const left = endsAt - clock().getTime();
    const timer = setTimeout(
      () => {
        setEndsAt(null);
        navigator.vibrate?.(300);
        toast(t('gym.restOverTitle'), { description: t('gym.restOverBody') });
      },
      Math.max(left, 0),
    );
    return () => clearTimeout(timer);
  }, [endsAt, clock, t]);
  return {
    endsAt,
    total,
    start: (seconds) => {
      if (seconds <= 0) return;
      setTotal(seconds);
      setEndsAt(clock().getTime() + seconds * 1000);
    },
    extend: (seconds) => {
      if (endsAt === null) return;
      setTotal((n) => n + seconds);
      setEndsAt(endsAt + seconds * 1000);
    },
    stop: () => setEndsAt(null),
  };
}

/** Re-renders every [ms] while [on]: the second hand and nothing else. */
function useTick(on: boolean, ms = 1000): void {
  const [, setTick] = useState(0);
  useEffect(() => {
    if (!on) return;
    const timer = setInterval(() => setTick((n) => n + 1), ms);
    return () => clearInterval(timer);
  }, [on, ms]);
}

function RestBar({ rest }: { rest: RestTimer }) {
  const { t } = useTranslation();
  const { clock } = useHarvest();
  useTick(rest.endsAt !== null, 250);
  if (rest.endsAt === null) return null;
  const left = Math.max(0, Math.ceil((rest.endsAt - clock().getTime()) / 1000));
  const fraction = rest.total === 0 ? 0 : Math.min(1, Math.max(0, 1 - left / rest.total));
  return (
    <div className="flex items-center gap-3 rounded-xl bg-secondary px-3 py-2 text-secondary-foreground">
      <TimerIcon className="size-5 shrink-0" aria-hidden />
      <span role="timer" aria-label={t('gym.resting')} className="text-2xl font-extrabold tabular">
        {clockText(left)}
      </span>
      <div
        role="progressbar"
        aria-label={t('gym.resting')}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={Math.round(fraction * 100)}
        className="h-1.5 min-w-8 flex-1 overflow-hidden rounded-full bg-secondary-foreground/20"
      >
        <div className="h-full rounded-full bg-primary transition-[width]" style={{ width: `${fraction * 100}%` }} />
      </div>
      <Button size="sm" variant="ghost" onClick={() => rest.extend(30)}>
        {t('gym.restPlus', { seconds: 30 })}
      </Button>
      <Button size="icon-sm" variant="ghost" aria-label={t('gym.restSkip')} title={t('gym.restSkip')} onClick={rest.stop}>
        <XIcon />
      </Button>
    </div>
  );
}

/** The clock, which is also the pause button: a queue for the rack is not training. */
function ClockButton({ session, onToggle }: { session: SessionRow; onToggle: () => void }) {
  const { t } = useTranslation();
  const { clock } = useHarvest();
  const paused = session.pausedAt !== null;
  useTick(!paused);
  const seconds = sessionElapsedSeconds(session, clock());
  return (
    <button
      type="button"
      onClick={onToggle}
      aria-label={paused ? t('gym.resumeClock') : t('gym.pause')}
      title={paused ? t('gym.resumeClock') : t('gym.pause')}
      className={cn(
        'flex min-h-10 items-center gap-2 rounded-full px-3 outline-none focus-visible:ring-2 focus-visible:ring-ring',
        paused ? 'bg-sun/20 text-foreground' : 'hover:bg-accent',
      )}
    >
      {paused ? <PlayIcon className="size-5" aria-hidden /> : <PauseIcon className="size-5 text-muted-foreground" aria-hidden />}
      <span className="text-xl font-extrabold tabular" aria-live="off">
        {clockText(seconds)}
      </span>
      {paused && <span className="text-xs font-extrabold">{t('gym.paused')}</span>}
    </button>
  );
}

// -------------------------------------------------------------------- sets

function parseLoad(text: string, unit: 'kg' | 'lb'): number {
  const value = Number(text.trim().replace(',', '.'));
  return text.trim() === '' || !Number.isFinite(value) || value <= 0 ? 0 : roundLoad(weightToGrams(unit, value), unit);
}

function parseReps(text: string): number {
  const value = Number.parseInt(text.trim(), 10);
  return Number.isFinite(value) && value > 0 ? value : 0;
}

/**
 * One row of the session (`SetRow`). The weight and the reps are
 * already filled in from the target, so a set that went to plan is one
 * click on the tick; a set that did not is a number and a click.
 */
function SetLine({
  set,
  exercise,
  barred,
  asker,
  onTicked,
  onPlates,
}: {
  set: SetRow;
  exercise: ExerciseInSession;
  barred: boolean;
  asker: Asker;
  onTicked: () => void;
  onPlates: (grams: number) => void;
}) {
  const { t } = useTranslation();
  const { db, sessions } = useHarvest();
  const unit = useUnit();
  const load = useLoad();
  const fieldOf = (grams: number) => (grams === 0 ? '' : loadFieldValue(grams, unit));
  const [weight, setWeight] = useState(fieldOf(set.weightGrams));
  const [reps, setReps] = useState(set.reps === 0 ? '' : String(set.reps));
  // The store is the truth, but it must not fight the keyboard: a field
  // is re-read only when its row changed somewhere else and it still
  // holds what the row said before.
  const [seen, setSeen] = useState({ weightGrams: set.weightGrams, reps: set.reps, unit });
  if (seen.weightGrams !== set.weightGrams || seen.unit !== unit || seen.reps !== set.reps) {
    // A field still showing the row is re-read from the row, not from its
    // two decimals: 135 lb shown first as 61.24 kg stays 135 lb (Y8).
    const untouched = weight === (seen.weightGrams === 0 ? '' : loadFieldValue(seen.weightGrams, seen.unit));
    if (seen.unit !== unit) setWeight(fieldOf(untouched ? set.weightGrams : parseLoad(weight, seen.unit)));
    else if (seen.weightGrams !== set.weightGrams && weight === (seen.weightGrams === 0 ? '' : loadFieldValue(seen.weightGrams, unit))) {
      setWeight(fieldOf(set.weightGrams));
    }
    if (seen.reps !== set.reps && reps === (seen.reps === 0 ? '' : String(seen.reps))) setReps(set.reps === 0 ? '' : String(set.reps));
    // One update for both: two spreads of the same stale value would lose whichever ran first.
    setSeen({ weightGrams: set.weightGrams, reps: set.reps, unit });
  }
  const [celebrating, setCelebrating] = useState(false);
  useEffect(() => {
    if (!celebrating) return;
    const timer = setTimeout(() => setCelebrating(false), 1500);
    return () => clearTimeout(timer);
  }, [celebrating]);

  const grams = parseLoad(weight, unit);
  const count = parseReps(reps);
  const number = set.position + 1;

  async function toggle() {
    if (set.done) {
      await sessions.logSet(set.uuid, { weightGrams: grams, reps: count, done: false });
      return;
    }
    // The records as they stood *before* this set, so it cannot beat itself.
    const before = await exerciseRecords(db, exercise.row.exerciseId);
    await sessions.logSet(set.uuid, { weightGrams: grams, reps: count, done: true });
    onTicked();
    const beaten = recordsBeatenBy({ weightGrams: grams, reps: count, done: true }, before);
    if (beaten.length === 0) return;
    // The moment the feature exists for: said where the click was, and
    // left up long enough to read between sets.
    setCelebrating(true);
    toast.success(
      beaten.includes('heaviest')
        ? t('gym.recordHeaviest', { load: load(grams) })
        : t('gym.recordEstimated', { load: load(estimatedOneRepMax(grams, count) ?? grams) }),
      { icon: <TrophyIcon className="size-4 text-sun" />, duration: 6000 },
    );
  }

  async function drop() {
    const ok = await asker.confirm({ title: t('gym.dropSet'), body: t('gym.dropSetBody'), action: t('gym.dropSet'), destructive: true });
    if (!ok) return;
    await sessions.removeSet(set.uuid);
    toast(t('gym.setDropped'));
  }

  const target = set.targetLabel === null ? '—' : prettyStoredLabel(set.targetLabel, unit);
  return (
    <li className="grid grid-cols-[2rem_minmax(0,1fr)_4.5rem_3.5rem_2.75rem] items-center gap-1.5">
      {/* Dropping asks first, so a click at speed is never one slip from losing a row. */}
      <button
        type="button"
        onClick={() => void drop()}
        aria-label={t('gym.dropSetNamed', { set: number })}
        title={t('gym.dropSet')}
        className="rounded-full outline-none focus-visible:ring-2 focus-visible:ring-ring"
      >
        <SetBadge position={set.position} openEnded={set.openEnded} />
      </button>
      {barred && grams > 0 ? (
        <button
          type="button"
          onClick={() => onPlates(grams)}
          aria-label={t('gym.platesFor', { load: load(grams) })}
          className="truncate rounded-md px-1 text-start text-sm text-muted-foreground underline decoration-dotted underline-offset-4 outline-none hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring"
          dir="ltr"
        >
          {target}
        </button>
      ) : (
        <span className="truncate px-1 text-sm text-muted-foreground" dir="ltr">
          {target}
        </span>
      )}
      <Input
        aria-label={t('gym.weightOfSet', { set: number, unit: t(`body.unit.${unit}`) })}
        inputMode="decimal"
        disabled={set.done}
        value={weight}
        onChange={(event) => setWeight(event.target.value.replace(/[^\d.,]/g, ''))}
        className={cn('h-9 px-1 text-center font-bold tabular', set.done && 'bg-primary/10 disabled:opacity-100')}
      />
      <Input
        aria-label={t('gym.repsOfSet', { set: number })}
        inputMode="numeric"
        disabled={set.done}
        placeholder={set.openEnded ? '1+' : undefined}
        value={reps}
        onChange={(event) => setReps(event.target.value.replace(/[^\d]/g, ''))}
        className={cn('h-9 px-1 text-center font-bold tabular', set.done && 'bg-primary/10 disabled:opacity-100')}
      />
      <span className="relative flex justify-center">
        {celebrating && <span className="absolute inset-0 rounded-full bg-sun/60 motion-safe:animate-ping" aria-hidden />}
        <button
          type="button"
          onClick={() => void toggle()}
          aria-pressed={set.done}
          aria-label={set.done ? t('gym.untickNamed', { set: number }) : t('gym.tickNamed', { set: number })}
          className={cn(
            'relative flex size-10 items-center justify-center rounded-full border-2 outline-none transition-[transform,background-color] focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 active:scale-95',
            set.done ? 'border-primary bg-primary text-primary-foreground' : 'border-muted-foreground/40 hover:border-primary',
          )}
        >
          <CheckIcon className="size-5" strokeWidth={3} />
        </button>
      </span>
    </li>
  );
}

// --------------------------------------------------------------- exercises

/** `Best: 100 kg×5 · est. 116.75 kg` — the estimate named as one (Y6), rounded like a load (Y8). */
function useRecordsLine(): (records: ExerciseRecords<SetRow>) => string {
  const { t } = useTranslation();
  const load = useLoad();
  const unit = useUnit();
  return (records) => {
    const heaviest = records.heaviest!;
    const parts = [`${load(heaviest.weightGrams)}×${heaviest.reps}`];
    if (records.bestSetEstimate !== null) parts.push(t('gym.bestEstimate', { weight: load(roundLoad(records.bestSetEstimate, unit)) }));
    return t('gym.bestLine', { sets: parts.join(' · ') });
  };
}

function ExerciseCard({ exercise, number, rest, asker }: { exercise: ExerciseInSession; number: number; rest: RestTimer; asker: Asker }) {
  const { t } = useTranslation();
  const { db, sessions } = useHarvest();
  const load = useLoad();
  const unit = useUnit();
  const recordsLine = useRecordsLine();
  const { row } = exercise;
  const named = useExercise(db, row.exerciseId);
  const replaced = row.plannedExerciseId !== null && row.plannedExerciseId !== row.exerciseId;
  const planned = useExercise(db, replaced ? row.plannedExerciseId : null);
  const last = useLiveQuery(() => lastTime(db, row.exerciseId), [db, row.exerciseId]);
  const records = useLiveQuery(() => exerciseRecords(db, row.exerciseId), [db, row.exerciseId]);
  const [swapping, setSwapping] = useState(false);
  const [restEditing, setRestEditing] = useState(false);
  const [detail, setDetail] = useState(false);
  const [plates, setPlates] = useState<number | null>(null);
  const name = named?.name ?? t('gym.unknownExercise');
  const barred = named ? usesBar(named) : false;
  const startRest = () => rest.start(row.restSeconds ?? defaultRestSeconds);

  async function skip() {
    if (row.skipped) {
      await sessions.skipExercise(row.uuid, false);
      return;
    }
    // Asked, never required: a skip with no reason is still a skip.
    const reason = await asker.prompt({
      title: t('gym.skipWhy'),
      label: t('gym.skipReason'),
      placeholder: t('gym.skipHint'),
      initial: row.skipReason ?? '',
      action: t('gym.skip'),
      allowEmpty: true,
    });
    if (reason !== null) await sessions.skipExercise(row.uuid, true, reason);
  }

  async function note() {
    const text = await asker.prompt({ title: t('gym.note'), label: t('gym.note'), initial: row.note ?? '', allowEmpty: true });
    if (text !== null) await sessions.setExerciseNote(row.uuid, text);
  }

  return (
    <li className="flex flex-col gap-2 rounded-2xl border bg-card p-3">
      <div className="flex items-start gap-2">
        <span className="pt-0.5 text-lg font-extrabold text-muted-foreground tabular">{number}</span>
        <div className="flex min-w-0 flex-1 flex-col">
          <button
            type="button"
            onClick={() => setDetail(true)}
            className={cn(
              'self-start rounded-md text-start text-lg font-extrabold outline-none hover:underline focus-visible:ring-2 focus-visible:ring-ring',
              row.skipped ? 'text-muted-foreground line-through' : 'text-primary',
            )}
          >
            {name}
          </button>
          {/* History must be able to say what the day was meant to be (Y7). */}
          {replaced && <span className="text-xs text-muted-foreground">{t('gym.insteadOf', { name: planned?.name ?? t('gym.unknownExercise') })}</span>}
          {last && last.length > 0 && (
            <span className="truncate text-xs text-muted-foreground" dir="auto">
              {t('gym.lastTime', { sets: last.map((set) => `${load(set.weightGrams)}×${set.reps}`).join('  ') })}
            </span>
          )}
          {records?.heaviest && <span className="truncate text-xs font-bold text-primary">{recordsLine(records)}</span>}
        </div>
        <Button variant="ghost" size="icon" aria-label={t('gym.startRest')} title={t('gym.startRest')} onClick={startRest}>
          <TimerIcon />
        </Button>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon" aria-label={t('gym.exerciseOptions', { name })}>
              <EllipsisVerticalIcon />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuItem onSelect={() => void sessions.addSet(row.uuid)}>{t('gym.addSet')}</DropdownMenuItem>
            <DropdownMenuItem onSelect={() => setSwapping(true)}>{t('gym.swap')}</DropdownMenuItem>
            <DropdownMenuItem onSelect={() => void skip()}>{row.skipped ? t('gym.unskip') : t('gym.skip')}</DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem onSelect={() => setRestEditing(true)}>{t('gym.rest')}</DropdownMenuItem>
            <DropdownMenuItem onSelect={() => void note()}>{t('gym.note')}</DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
      {row.skipped && row.skipReason && <p className="text-xs text-muted-foreground">{t('gym.skippedBecause', { reason: row.skipReason })}</p>}
      {row.note && <p className="text-xs text-muted-foreground">{row.note}</p>}
      {!row.skipped && (
        <>
          <div className="grid grid-cols-[2rem_minmax(0,1fr)_4.5rem_3.5rem_2.75rem] gap-1.5 border-t pt-2 text-center text-xs text-muted-foreground" aria-hidden>
            <span>{t('gym.setColumn')}</span>
            <span className="text-start">{t('gym.targetColumn')}</span>
            <span>{t(`body.unit.${unit}`)}</span>
            <span>{t('gym.repsColumn')}</span>
            <span />
          </div>
          <ul className="flex flex-col gap-1.5">
            {exercise.sets.map((set) => (
              <SetLine key={set.uuid} set={set} exercise={exercise} barred={barred} asker={asker} onTicked={startRest} onPlates={setPlates} />
            ))}
          </ul>
          <Button variant="ghost" size="sm" className="self-start" onClick={() => void sessions.addSet(row.uuid)}>
            <PlusIcon />
            {t('gym.addSet')}
          </Button>
        </>
      )}
      {swapping && (
        <ExercisePicker
          title={t('gym.swapTitle', { name })}
          onClose={() => setSwapping(false)}
          onPick={(picked) => {
            setSwapping(false);
            void sessions.replaceExercise(row.uuid, picked.id);
          }}
        />
      )}
      {restEditing && (
        <Dialog open onOpenChange={(open) => !open && setRestEditing(false)}>
          <DialogContent className="max-w-sm">
            <DialogHeader>
              <DialogTitle>{t('gym.rest')}</DialogTitle>
              <DialogDescription>{t('gym.restToday')}</DialogDescription>
            </DialogHeader>
            <RestField
              seconds={row.restSeconds ?? defaultRestSeconds}
              onChange={(seconds) => {
                setRestEditing(false);
                void sessions.setExerciseRest(row.uuid, seconds);
              }}
            />
          </DialogContent>
        </Dialog>
      )}
      {detail && <ExerciseDetailDialog exerciseId={row.exerciseId} onClose={() => setDetail(false)} />}
      {plates !== null && <PlatesDialog targetGrams={plates} barGrams={row.barGrams} onClose={() => setPlates(null)} />}
    </li>
  );
}

// ------------------------------------------------------------------ screen

/**
 * The workout, in progress (`session_screen.dart`), in a browser. Every
 * set is written the moment it is ticked (Y3), so leaving is not
 * discarding: the gym offers the session back, here or on the phone.
 */
export function SessionScreen() {
  const { t } = useTranslation();
  const { uuid = '' } = useParams();
  const navigate = useNavigate();
  const { db, sessions, clock } = useHarvest();
  const tree = useLiveQuery(async () => (await readSession(db, uuid)) ?? null, [db, uuid]);
  const rest = useRestTimer(clock);
  const [asker, asking] = useAsker();
  const [adding, setAdding] = useState(false);
  // The picture before the first set, when the program asks for one then.
  const picture = usePictureOffer();

  const back = (
    <Button asChild variant="ghost" size="sm" className="self-start">
      <Link to="/app/body/gym">
        <ArrowLeftIcon className="rtl:rotate-180" />
        {t('gym.backToGym')}
      </Link>
    </Button>
  );
  if (tree === undefined) return null;
  if (tree === null || tree.session.deletedAt !== null) {
    return (
      <div className="flex flex-col gap-4">
        {back}
        <EmptyState icon={<FlagIcon />} title={t('gym.sessionGone')} />
      </div>
    );
  }
  const { session } = tree;
  if (session.endedAt !== null) {
    return (
      <div className="flex flex-col gap-4">
        {back}
        <EmptyState icon={<FlagIcon />} title={t('gym.sessionFinished')} body={t('gym.sessionFinishedBody')} />
      </div>
    );
  }

  async function finish() {
    const question = finishQuestion(tree!.exercises.map((exercise) => ({ skipped: exercise.row.skipped, sets: exercise.sets })));
    if (question.kind === 'empty') {
      const ok = await asker.confirm({ title: t('gym.finishEmptyTitle'), body: t('gym.finishEmptyBody'), action: t('gym.finish') });
      if (!ok) return;
    } else if (question.kind === 'incomplete') {
      // Finish is the check-in, so leaving sets behind is chosen with the eyes open (Y10).
      const ok = await asker.confirm({
        title: t('gym.finishIncompleteTitle'),
        body: t('gym.finishIncompleteBody', { left: question.left, total: question.planned }),
        action: t('gym.finish'),
      });
      if (!ok) return;
    }
    rest.stop();
    const outcome = await sessions.finish(uuid);
    if (outcome.xpEarned > 0) toast.success(t('gym.checkedIn', { xp: outcome.xpEarned }));
    // The picture on the way out is offered by the gym, once this screen has gone.
    const album = await albumForPicture(db, outcome.albumUuid);
    void navigate('/app/body/gym', album ? { state: { gymPicture: album } satisfies PictureState } : undefined);
  }

  async function discard() {
    const ok = await asker.confirm({
      title: t('gym.discardSession'),
      body: t('gym.discardBody', { count: tree!.doneSets }),
      action: t('gym.discardSession'),
      destructive: true,
    });
    if (!ok) return;
    // Asked twice, but only when there is something to lose.
    if (tree!.doneSets > 0) {
      const sure = await asker.confirm({
        title: t('gym.discardAgain'),
        body: t('gym.discardAgainBody', { count: tree!.doneSets }),
        action: t('gym.discardSession'),
        destructive: true,
      });
      if (!sure) return;
    }
    rest.stop();
    await sessions.discard(uuid);
    void navigate('/app/body/gym');
  }

  async function sessionNote() {
    const text = await asker.prompt({
      title: t('gym.sessionNote'),
      label: t('gym.sessionNote'),
      initial: session.note ?? '',
      placeholder: t('gym.sessionNoteHint'),
      allowEmpty: true,
    });
    if (text !== null) await sessions.setSessionNote(uuid, text);
  }

  return (
    <div className="flex flex-col gap-3">
      {back}
      <div className="flex items-start gap-2">
        <div className="flex min-w-0 flex-1 flex-col">
          <h1 className="truncate text-2xl font-extrabold">{session.title ?? t('gym.session')}</h1>
          <p className="text-sm text-muted-foreground" aria-live="polite">
            {t('gym.sessionProgress', { done: tree.doneSets, total: tree.totalSets })}
          </p>
        </div>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon" aria-label={t('gym.sessionOptions')}>
              <EllipsisVerticalIcon />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuItem onSelect={() => void sessionNote()}>{t('gym.sessionNote')}</DropdownMenuItem>
            <DropdownMenuItem onSelect={() => setAdding(true)}>{t('gym.addExercise')}</DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem onSelect={() => void discard()} className="text-destructive">
              {t('gym.discardSession')}
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
      {session.note && <p className="text-sm text-muted-foreground">{session.note}</p>}
      <ul className="flex flex-col gap-3">
        {tree.exercises.map((exercise, index) => (
          <ExerciseCard key={exercise.row.uuid} exercise={exercise} number={index + 1} rest={rest} asker={asker} />
        ))}
      </ul>
      <Button variant="outline" className="self-start" onClick={() => setAdding(true)}>
        <PlusIcon />
        {t('gym.addExercise')}
      </Button>
      {/* The rest, the clock and Finish, where the hand is between sets. */}
      <div className="sticky bottom-24 z-20 flex flex-col gap-2 rounded-2xl border bg-background/95 p-2 shadow-lg backdrop-blur md:bottom-4">
        <RestBar rest={rest} />
        <div className="flex items-center justify-between gap-2">
          <ClockButton session={session} onToggle={() => void (session.pausedAt === null ? sessions.pause(uuid) : sessions.resume(uuid))} />
          <Button onClick={() => void finish()}>
            <FlagIcon />
            {t('gym.finish')}
          </Button>
        </div>
      </div>
      {adding && (
        <ExercisePicker
          onClose={() => setAdding(false)}
          onPick={(picked) => {
            setAdding(false);
            void sessions.addExercise(uuid, picked.id);
          }}
        />
      )}
      {asking}
      {picture}
    </div>
  );
}
