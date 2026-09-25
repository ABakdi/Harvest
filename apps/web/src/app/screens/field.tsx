import { useLiveQuery } from 'dexie-react-hooks';
import {
  ArchiveIcon,
  BedIcon,
  CameraIcon,
  CheckIcon,
  ChevronDownIcon,
  ChevronRightIcon,
  CoinsIcon,
  EllipsisVerticalIcon,
  FlameIcon,
  HistoryIcon,
  LockIcon,
  MoonIcon,
  NotebookPenIcon,
  PauseIcon,
  PencilIcon,
  PlayIcon,
  PlusIcon,
  SproutIcon,
  TimerIcon,
  Undo2Icon,
  WalletIcon,
  XIcon,
} from 'lucide-react';
import { useState } from 'react';
import type { TFunction } from 'i18next';
import { useTranslation } from 'react-i18next';
import { Link, NavLink, useNavigate } from 'react-router';
import { toast } from 'sonner';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { farmerRankForXp, type Schedule } from '@harvest/core';
import { formatDay, formatMoney, formatNumber } from '@/lib/format';
import { renderInline } from '@/lib/markdown';
import { cn } from '@/lib/utils';
import { EmptyState, ProgressRing, StreakChip } from '../components/bits';
import { SeedLogDialog } from '../components/seed-log-dialog';
import { SeedNoteDialog } from '../components/seed-note-dialog';
import { StreakDialog } from './farmer';
import { useHarvest, useHarvestDay } from '../context';
import { loadField, readFieldGauges, readMoneySealed, readTomorrow, type FieldSeed } from '../data/field';
import { notePreview } from '../data/notes';
import { notesOn } from '../data/seed-notes';
import type { SeedRow } from '../data/seeds';
import { useDefaultCurrency, usePrivateKey } from '../hooks';
import { useDialogs } from '../dialogs';
import { useShortcuts } from '../shortcuts';
import { GoalsBoard } from './goals-board';
import { useGymSeedChoice, useGymSeeds } from './gym/start';
import { CaptureDialog } from '../components/gallery/capture-dialog';
import { useFeaturesOrOff } from '../components/settings-bits';
import { readAlbumsDue, type AlbumDue } from '../data/gallery';

export function FieldTabs() {
  const { t } = useTranslation();
  const tab = ({ isActive }: { isActive: boolean }) =>
    cn(
      'rounded-md px-3 py-1.5 text-sm font-extrabold outline-none focus-visible:ring-2 focus-visible:ring-ring',
      isActive ? 'bg-card text-foreground shadow-sm' : 'text-muted-foreground hover:text-foreground',
    );
  return (
    <nav aria-label={t('field.tabs')} className="flex w-fit gap-1 rounded-lg bg-muted p-1">
      <NavLink to="/app/field" end className={tab}>
        {t('field.today')}
      </NavLink>
      <NavLink to="/app/field/goals" className={tab}>
        {t('field.goals')}
      </NavLink>
      <NavLink to="/app/field/calendar" className={tab}>
        {t('calendar.title')}
      </NavLink>
    </nav>
  );
}

export function FieldScreen({ tab }: { tab: 'today' | 'goals' }) {
  return (
    <div className="flex flex-col gap-4">
      <FieldTabs />
      {tab === 'today' ? <TodayView /> : <GoalsBoard />}
    </div>
  );
}

/** A schedule in a few words, for a habit or a scheduled album. */
function scheduleLine(t: TFunction, schedule: Schedule | null, doneDaysThisWeek: number): string {
  if (!schedule || schedule.type === 'daily') return t('field.schedule.daily');
  if (schedule.type === 'weekly') return t('field.schedule.weekly', { count: schedule.weekdays.size });
  if (schedule.type === 'interval') return t('field.schedule.interval', { count: schedule.everyDays });
  return t('field.schedule.timesPerWeek', { count: schedule.times, done: doneDaysThisWeek });
}

/** What a seed's card says under its title. */
function useSubtitle(seed: FieldSeed): string {
  const { t } = useTranslation();
  const { row, commitment } = seed;
  if (row.pausedAt !== null) return t('field.paused');
  switch (row.type) {
    case 'habit':
      return scheduleLine(t, commitment.schedule, seed.doneDaysThisWeek);
    case 'project':
      return t('field.projectProgress', {
        done: formatNumber(seed.total),
        total: formatNumber(row.totalTarget ?? 0),
        today: formatNumber(seed.today),
        daily: formatNumber(row.dailyCommitment ?? 0),
      });
    case 'todo':
      if (seed.overdue && row.dueDay) return t('field.overdue', { date: formatDay(row.dueDay) });
      return row.dueDay ? t('field.plannedFor', { date: formatDay(row.dueDay) }) : t('field.anytime');
  }
}

function SeedCard({
  seed,
  onCheck,
  onUndo,
  onLog,
  onArchive,
  onNote,
  dayNote,
}: {
  seed: FieldSeed;
  onCheck: (seed: FieldSeed) => void;
  onUndo: (seed: FieldSeed) => void;
  onLog: (seed: FieldSeed) => void;
  onArchive: (seed: FieldSeed) => void;
  onNote: (seed: FieldSeed) => void;
  /** What I wrote on this seed today, under its title. */
  dayNote: string | undefined;
}) {
  const { t } = useTranslation();
  const { seeds } = useHarvest();
  const dialogs = useDialogs();
  const navigate = useNavigate();
  const subtitle = useSubtitle(seed);
  const { row } = seed;
  const paused = row.pausedAt !== null;
  // A project's button always logs, done for today or not: it never
  // undoes, so it is never called "Undo".
  const checkLabel =
    row.type === 'project'
      ? t('field.logLabel', { title: row.title })
      : seed.done
        ? t('field.undoLabel', { title: row.title })
        : t('field.checkLabel', { title: row.title });

  return (
    <li
      className={cn(
        'flex items-center gap-3 rounded-xl border bg-card p-3 transition-colors',
        seed.overdue && !seed.done && 'border-destructive/60',
      )}
    >
      <button
        type="button"
        data-field-check
        aria-label={checkLabel}
        aria-pressed={row.type === 'project' ? undefined : seed.done}
        disabled={paused}
        onClick={() => (seed.done && row.type !== 'project' ? onUndo(seed) : row.type === 'project' ? onLog(seed) : onCheck(seed))}
        className={cn(
          'flex size-11 shrink-0 items-center justify-center rounded-full border-2 outline-none transition-[transform,background-color] focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background active:scale-95 disabled:opacity-40',
          seed.done ? 'border-success bg-success text-white' : 'border-muted-foreground/40 hover:border-success',
        )}
      >
        {seed.done ? (
          <CheckIcon className="size-5" strokeWidth={3} />
        ) : row.type === 'project' ? (
          <PlusIcon className="size-5" />
        ) : null}
      </button>
      <div className="flex min-w-0 flex-1 flex-col">
        <Link
          to={`/app/field/seed/${row.uuid}`}
          className={cn(
            'truncate rounded-sm font-bold outline-none hover:underline focus-visible:ring-2 focus-visible:ring-ring',
            seed.done && row.type !== 'project' && 'text-muted-foreground line-through',
          )}
        >
          {row.title}
        </Link>
        <span className={cn('truncate text-xs text-muted-foreground', seed.overdue && !seed.done && 'font-bold text-destructive')}>
          {subtitle}
        </span>
        {row.note && <span className="truncate text-xs text-muted-foreground">{renderInline(notePreview(row.note))}</span>}
        {dayNote && (
          <span className="flex items-center gap-1 truncate text-xs text-foreground/80">
            <NotebookPenIcon className="size-3 shrink-0" aria-label={t('seedDetail.todaysNote')} />
            <span className="truncate">{renderInline(notePreview(dayNote))}</span>
          </span>
        )}
      </div>
      {seed.streak !== null && <StreakChip count={seed.streak} />}
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" size="icon-sm" aria-label={t('field.options', { title: row.title })}>
            <EllipsisVerticalIcon />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem onSelect={() => void navigate(`/app/field/focus?seed=${row.uuid}`)}>
            <TimerIcon />
            {t('focus.timer')}
          </DropdownMenuItem>
          <DropdownMenuItem onSelect={() => onNote(seed)}>
            <NotebookPenIcon />
            {t('seedDetail.notesTitle')}
          </DropdownMenuItem>
          <DropdownMenuItem onSelect={() => void navigate(`/app/field/seed/${row.uuid}`)}>
            <HistoryIcon />
            {t('seedDetail.history')}
          </DropdownMenuItem>
          <DropdownMenuItem onSelect={() => dialogs.editSeed(row)}>
            <PencilIcon />
            {t('common.edit')}
          </DropdownMenuItem>
          {row.type === 'project' && (
            <DropdownMenuItem onSelect={() => onLog(seed)} disabled={seed.room === 0}>
              <PlusIcon />
              {t('field.logProgress')}
            </DropdownMenuItem>
          )}
          {seed.today > 0 && (
            <DropdownMenuItem onSelect={() => onUndo(seed)}>
              <Undo2Icon />
              {t('field.undoToday')}
            </DropdownMenuItem>
          )}
          {row.type === 'habit' && (
            <DropdownMenuItem
              onSelect={() =>
                void seeds.setPaused(row.uuid, !paused).then(() =>
                  toast(paused ? t('field.resumedToast', { title: row.title }) : t('field.pausedToast', { title: row.title }), {
                    action: { label: t('common.undo'), onClick: () => void seeds.setPaused(row.uuid, paused) },
                  }),
                )
              }
            >
              {paused ? <PlayIcon /> : <PauseIcon />}
              {paused ? t('field.resume') : t('field.pause')}
            </DropdownMenuItem>
          )}
          <DropdownMenuSeparator />
          <DropdownMenuItem onSelect={() => onArchive(seed)}>
            <ArchiveIcon />
            {t('field.archive')}
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </li>
  );
}

/**
 * A scheduled album, on the field, as a crop (`AlbumCropTile`, G3): due
 * like a habit, wearing the same card, and its check-in is the picture —
 * the round button opens the capture instead of ticking anything. Once
 * today has its picture, the button leads to the album.
 */
function AlbumCard({ entry, onCapture }: { entry: AlbumDue; onCapture: (entry: AlbumDue) => void }) {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const { album, done } = entry;
  const to = `/app/records/gallery?album=${album.uuid}`;
  return (
    <li className="flex items-center gap-3 rounded-xl border bg-card p-3">
      <button
        type="button"
        data-field-check
        aria-label={done ? t('field.albumOpen', { name: album.name }) : t('field.albumAdd', { name: album.name })}
        onClick={() => (done ? void navigate(to) : onCapture(entry))}
        className={cn(
          'flex size-11 shrink-0 items-center justify-center rounded-full border-2 outline-none transition-[transform,background-color] focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background active:scale-95',
          done ? 'border-success bg-success text-white' : 'border-muted-foreground/40 text-muted-foreground hover:border-success',
        )}
      >
        {done ? <CheckIcon className="size-5" strokeWidth={3} /> : <CameraIcon className="size-5" />}
      </button>
      <div className="flex min-w-0 flex-1 flex-col">
        <Link
          to={to}
          className={cn(
            'truncate rounded-sm font-bold outline-none hover:underline focus-visible:ring-2 focus-visible:ring-ring',
            done && 'text-muted-foreground line-through',
          )}
        >
          {album.name}
        </Link>
        <span className="truncate text-xs text-muted-foreground">
          {t('field.albumKind')} · {scheduleLine(t, entry.schedule, entry.doneDaysThisWeek)}
        </span>
        {album.note && <span className="truncate text-xs text-muted-foreground">{album.note}</span>}
      </div>
      {entry.streak > 0 && <StreakChip count={entry.streak} />}
    </li>
  );
}

function ArchiveDialog({ seed, onClose }: { seed: FieldSeed; onClose: () => void }) {
  const { t } = useTranslation();
  const { seeds } = useHarvest();
  const [note, setNote] = useState('');
  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>{t('field.archiveTitle')}</DialogTitle>
          <DialogDescription>{t('field.archiveBody', { title: seed.row.title })}</DialogDescription>
        </DialogHeader>
        <div className="flex flex-col gap-2">
          <Label htmlFor="archive-note">{t('field.archiveNote')}</Label>
          <Textarea id="archive-note" value={note} rows={3} onChange={(event) => setNote(event.target.value)} />
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            {t('common.cancel')}
          </Button>
          <Button
            onClick={() => {
              void seeds.archive(seed.row.uuid, note).then(() => {
                onClose();
                toast(t('field.archived'), {
                  action: { label: t('common.undo'), onClick: () => void seeds.restore(seed.row.uuid) },
                });
              });
            }}
          >
            <ArchiveIcon />
            {t('field.archive')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function TodayView() {
  const { t } = useTranslation();
  const { db, checkIns, sessions } = useHarvest();
  const dialogs = useDialogs();
  const day = useHarvestDay();
  const view = useLiveQuery(() => loadField(db, day), [db, day.key]);
  const dayNotes = useLiveQuery(() => notesOn(db, day), [db, day.key]);
  const [undoing, setUndoing] = useState<FieldSeed | null>(null);
  const [logging, setLogging] = useState<FieldSeed | null>(null);
  const [archiving, setArchiving] = useState<FieldSeed | null>(null);
  const gymSeeds = useGymSeeds();
  const gymChoice = useGymSeedChoice();
  // Scheduled albums are seeds too (G3), but only with the gallery on.
  const galleryOn = useFeaturesOrOff().gallery;
  const albums = useLiveQuery(() => (galleryOn ? readAlbumsDue(db, day) : []), [db, day.key, galleryOn]) ?? [];
  const [capturing, setCapturing] = useState<AlbumDue | null>(null);
  const [noting, setNoting] = useState<SeedRow | null>(null);
  const [streakOpen, setStreakOpen] = useState(false);

  // J and K walk the field; Space on a focused seed checks it in, as
  // any focused button does.
  const move = (step: number) => {
    const buttons = [...document.querySelectorAll<HTMLButtonElement>('[data-field-check]')];
    if (buttons.length === 0) return;
    const index = buttons.indexOf(document.activeElement as HTMLButtonElement);
    const next = index === -1 ? (step > 0 ? 0 : buttons.length - 1) : Math.min(Math.max(index + step, 0), buttons.length - 1);
    buttons[next]?.focus();
  };
  useShortcuts({ j: () => move(1), k: () => move(-1) });

  async function check(seed: FieldSeed) {
    try {
      // A gym seed is checked in by a session, never a bare tick (Y12).
      if (await gymChoice.ask(seed.row)) return;
      const plan = await checkIns.checkIn(seed.row, day);
      if (plan.quantityLogged > 0) toast.success(t('field.xpEarned', { count: plan.xpEarned }));
      else if (plan.capped) toast(t('field.capped'));
    } catch {
      toast.error(t('field.checkInFailed'));
    }
  }

  if (!view) return null;
  const rank = farmerRankForXp(view.totalXp);
  // Past the goal it is met, not "4 of 3": the count stays, the fraction goes.
  const goalLine =
    view.goal > 0 && view.actions >= view.goal
      ? t('field.goalMet', { count: view.actions })
      : t('field.goalProgress', { actions: view.actions, goal: view.goal });

  return (
    <div className="flex flex-col gap-4">
      <section aria-label={t('field.summary')} className="flex flex-wrap items-center gap-4 rounded-2xl border bg-card p-4">
        <ProgressRing
          ratio={view.goal > 0 ? view.actions / view.goal : 0}
          size={56}
          label={goalLine}
        />
        <div className="flex min-w-0 flex-1 flex-col">
          <h1 className="text-xl font-extrabold">{formatDay(day.key, { weekday: 'long', month: 'long', day: 'numeric' })}</h1>
          <p className="text-sm text-muted-foreground">{goalLine}</p>
        </div>
        <dl className="flex flex-wrap gap-2 text-sm">
          <div className="flex items-center rounded-full bg-muted font-extrabold">
            <dt className="sr-only">{t('streak.global')}</dt>
            <dd>
              <button
                type="button"
                onClick={() => setStreakOpen(true)}
                title={t('streak.sheetTitle')}
                aria-label={`${t('streak.sheetTitle')}: ${t('streak.days', { count: view.streak.current })}`}
                className="flex items-center gap-1 rounded-full px-3 py-1 outline-none hover:bg-accent focus-visible:ring-2 focus-visible:ring-ring"
              >
                <FlameIcon className="size-4 text-primary" aria-hidden />
                <span className="tabular">{t('streak.days', { count: view.streak.current })}</span>
              </button>
            </dd>
          </div>
          <div className="flex items-center gap-1 rounded-full bg-muted px-3 py-1 font-extrabold">
            <dt className="sr-only">{t('field.dayXp')}</dt>
            <dd className="tabular">{t('field.xpToday', { count: view.dayXp })}</dd>
          </div>
          <div className="flex items-center gap-1 rounded-full bg-muted px-3 py-1 font-extrabold">
            <dt className="sr-only">{t('farmer.coins')}</dt>
            <CoinsIcon className="size-4 text-sun" aria-hidden />
            <dd className="tabular">{formatNumber(view.coins)}</dd>
          </div>
          <div className="flex items-center gap-1 rounded-full bg-secondary px-3 py-1 font-extrabold">
            <dt className="sr-only">{t('farmer.rank')}</dt>
            <dd>{t(`farmer.ranks.${rank}`)}</dd>
          </div>
        </dl>
        <Gauges />
      </section>

      {view.today.length === 0 && view.resting.length === 0 && albums.length === 0 ? (
        <EmptyState
          icon={<SproutIcon />}
          title={t('field.emptyTitle')}
          body={t('field.emptyBody')}
          action={
            <Button onClick={() => dialogs.plantSeed()}>
              <PlusIcon />
              {t('seed.plant')}
            </Button>
          }
        />
      ) : (
        <section aria-labelledby="today-heading" className="flex flex-col gap-2">
          <h2 id="today-heading" className="text-sm font-extrabold text-muted-foreground">
            {/* A paused habit shown for a check-in it already had is resting, not due. */}
            {t('field.dueToday', { count: view.today.filter((seed) => seed.row.pausedAt === null).length + albums.length })}
          </h2>
          {view.today.length === 0 && albums.length === 0 ? (
            <p className="rounded-xl bg-muted p-4 text-sm">{t('field.nothingDue')}</p>
          ) : (
            <ul className="flex flex-col gap-2">
              {view.today.map((seed) => (
                <SeedCard
                  key={seed.row.uuid}
                  seed={seed}
                  onCheck={(s) => void check(s)}
                  onUndo={setUndoing}
                  onLog={setLogging}
                  onArchive={setArchiving}
                  onNote={(s) => setNoting(s.row)}
                  dayNote={dayNotes?.get(seed.row.uuid)}
                />
              ))}
              {albums.map((entry) => (
                <AlbumCard key={`album:${entry.album.uuid}`} entry={entry} onCapture={setCapturing} />
              ))}
            </ul>
          )}
          <p className="hidden text-xs text-muted-foreground md:block">{t('field.keysHint')}</p>
        </section>
      )}

      {view.resting.length > 0 && (
        <details className="group rounded-xl">
          <summary className="flex cursor-pointer items-center gap-2 rounded-lg py-1 text-sm font-extrabold text-muted-foreground outline-none focus-visible:ring-2 focus-visible:ring-ring">
            <ChevronDownIcon className="size-4 transition-transform group-open:rotate-180" aria-hidden />
            {t('field.resting', { count: view.resting.length })}
          </summary>
          <ul className="mt-2 flex flex-col gap-2">
            {view.resting.map((seed) => (
              <SeedCard
                key={seed.row.uuid}
                seed={seed}
                onCheck={(s) => void check(s)}
                onUndo={setUndoing}
                onLog={setLogging}
                onArchive={setArchiving}
                onNote={(s) => setNoting(s.row)}
                dayNote={dayNotes?.get(seed.row.uuid)}
              />
            ))}
          </ul>
        </details>
      )}

      <TomorrowCard />

      <AlertDialog open={undoing !== null} onOpenChange={(open) => !open && setUndoing(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>{t('field.undoTitle')}</AlertDialogTitle>
            <AlertDialogDescription>{t('field.undoBody', { title: undoing?.row.title ?? '' })}</AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>{t('common.cancel')}</AlertDialogCancel>
            <AlertDialogAction
              onClick={() => {
                if (!undoing) return;
                // A hand tick of a gym seed wrote an empty session; it goes with the tick.
                const program = gymSeeds?.get(undoing.row.uuid);
                void checkIns.undo(undoing.row, day).then(() => program && sessions.discardBareOn(program.program.uuid, day.key));
              }}
            >
              {t('common.undo')}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
      {logging && <SeedLogDialog seed={logging.row} onClose={() => setLogging(null)} />}
      {noting && <SeedNoteDialog seed={noting} onClose={() => setNoting(null)} />}
      {streakOpen && <StreakDialog onClose={() => setStreakOpen(false)} />}
      {archiving && <ArchiveDialog seed={archiving} onClose={() => setArchiving(null)} />}
      {gymChoice.dialog}
      {capturing && <CaptureDialog album={capturing.album} onClose={() => setCapturing(null)} />}
    </div>
  );
}

/**
 * The field header's two lines, as on the phone: what is left to spend
 * today, and what is owed in sleep. Each leads to its own screen.
 */
function Gauges() {
  const { t } = useTranslation();
  const { db } = useHarvest();
  const day = useHarvestDay();
  const currency = useDefaultCurrency();
  const gauges = useLiveQuery(() => readFieldGauges(db, day), [db, day.key]);
  const sealed = useLiveQuery(() => readMoneySealed(db), [db]);
  const unlocked = usePrivateKey();
  if (!gauges || (gauges.budgetLeft === null && gauges.sleepOwed === null)) return null;
  // Without the passphrase this browser holds only part of the spending:
  // no number rather than a wrong one.
  const locked = unlocked === false || sealed === true;
  if (unlocked === undefined || sealed === undefined) return null;
  const line =
    'flex items-center gap-2 rounded-lg px-2 py-1.5 text-sm font-extrabold outline-none hover:bg-accent focus-visible:ring-2 focus-visible:ring-ring';
  return (
    <div className="flex w-full flex-col gap-1 border-t pt-2">
      {gauges.budgetLeft !== null && locked && (
        <Link to="/app/granary" className={cn(line, 'font-semibold text-muted-foreground')}>
          <LockIcon className="size-4" aria-hidden />
          <span className="flex-1">{t('field.budgetLocked')}</span>
          <ChevronRightIcon className="size-4 rtl:rotate-180" aria-hidden />
        </Link>
      )}
      {gauges.budgetLeft !== null && !locked && (
        <Link to="/app/granary" className={line}>
          <WalletIcon className={cn('size-4', gauges.budgetLeft >= 0 ? 'text-success' : 'text-destructive')} aria-hidden />
          <span className="flex-1">
            {gauges.budgetLeft >= 0
              ? t('field.budgetLeftToday', { amount: formatMoney(gauges.budgetLeft, currency) })
              : t('field.budgetOverToday', { amount: formatMoney(-gauges.budgetLeft, currency) })}
          </span>
          <ChevronRightIcon className="size-4 text-muted-foreground rtl:rotate-180" aria-hidden />
        </Link>
      )}
      {gauges.sleepOwed !== null && (
        <Link to="/app/body" className={line}>
          <BedIcon className="size-4 text-muted-foreground" aria-hidden />
          <span className="flex-1">
            {t('field.sleepOwed', { hours: Math.trunc(gauges.sleepOwed / 60), minutes: gauges.sleepOwed % 60 })}
          </span>
          <ChevronRightIcon className="size-4 text-muted-foreground rtl:rotate-180" aria-hidden />
        </Link>
      )}
    </div>
  );
}

/**
 * Tomorrow at a glance, and the way into the evening plan — a card at
 * the foot of the field, as on the phone.
 */
function TomorrowCard() {
  const { t } = useTranslation();
  const { db } = useHarvest();
  const day = useHarvestDay();
  const plan = useLiveQuery(() => readTomorrow(db, day), [db, day.key]);
  const [open, setOpen] = useState(false);
  if (!plan) return null;
  const summary =
    plan.habits.length === 0 && plan.todos.length === 0
      ? t('planner.nothing')
      : `${t('planner.habits', { count: plan.habits.length })} · ${t('planner.todos', { count: plan.todos.length })}`;
  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="flex items-center gap-3 rounded-xl border bg-card p-4 text-start outline-none hover:bg-accent focus-visible:ring-2 focus-visible:ring-ring"
      >
        <span className="flex size-10 shrink-0 items-center justify-center rounded-full bg-secondary text-muted-foreground" aria-hidden>
          <MoonIcon className="size-5" />
        </span>
        <span className="flex min-w-0 flex-1 flex-col">
          <span className="font-extrabold">
            {t('planner.tomorrow')} · {formatDay(plan.day.key, { weekday: 'long', month: 'short', day: 'numeric' })}
          </span>
          <span className="text-xs text-muted-foreground">{summary}</span>
        </span>
        <span className="flex items-center text-sm font-extrabold text-primary">
          {t('planner.plan')}
          <ChevronRightIcon className="size-4 rtl:rotate-180" aria-hidden />
        </span>
      </button>
      {open && <PlannerDialog onClose={() => setOpen(false)} />}
    </>
  );
}

/**
 * The evening ritual: tomorrow's to-dos set before sleep. A to-do
 * planted here is due tomorrow; removing one archives it, as the
 * phone's planner does, so nothing written is ever lost.
 */
function PlannerDialog({ onClose }: { onClose: () => void }) {
  const { t } = useTranslation();
  const { db, seeds } = useHarvest();
  const day = useHarvestDay();
  const plan = useLiveQuery(() => readTomorrow(db, day), [db, day.key]);
  const [title, setTitle] = useState('');

  async function add() {
    const trimmed = title.trim();
    if (trimmed === '') return;
    setTitle('');
    await seeds.plant({ type: 'todo', title: trimmed, dueDay: day.next.key });
  }

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>{t('planner.title')}</DialogTitle>
          <DialogDescription>{formatDay(day.next.key, { weekday: 'long', month: 'long', day: 'numeric' })}</DialogDescription>
        </DialogHeader>
        <form
          className="flex gap-2"
          onSubmit={(event) => {
            event.preventDefault();
            void add();
          }}
        >
          <Label htmlFor="planner-add" className="sr-only">
            {t('planner.addHint')}
          </Label>
          <Input
            id="planner-add"
            autoFocus
            placeholder={t('planner.addHint')}
            value={title}
            onChange={(event) => setTitle(event.target.value)}
          />
          <Button type="submit" size="icon" aria-label={t('planner.add')} disabled={title.trim() === ''}>
            <PlusIcon />
          </Button>
        </form>
        {plan && plan.todos.length === 0 && plan.habits.length === 0 && (
          <p className="py-4 text-center text-sm text-muted-foreground">{t('planner.empty')}</p>
        )}
        {plan && plan.todos.length > 0 && (
          <section aria-labelledby="planner-todos" className="flex flex-col gap-2">
            <h3 id="planner-todos" className="text-sm font-extrabold">
              {t('planner.todosTitle')}
            </h3>
            <ul className="flex flex-col divide-y rounded-xl border">
              {plan.todos.map((todo) => (
                <li key={todo.uuid} className="flex items-center gap-2 px-3 py-2">
                  <CheckIcon className="size-4 text-muted-foreground" aria-hidden />
                  <span className="min-w-0 flex-1 truncate">{todo.title}</span>
                  <Button
                    variant="ghost"
                    size="icon-sm"
                    aria-label={t('planner.remove', { title: todo.title })}
                    onClick={() => void seeds.archive(todo.uuid, null)}
                  >
                    <XIcon />
                  </Button>
                </li>
              ))}
            </ul>
          </section>
        )}
        {plan && plan.habits.length > 0 && (
          <section aria-labelledby="planner-habits" className="flex flex-col gap-2">
            <h3 id="planner-habits" className="text-sm font-extrabold">
              {t('planner.habitsTitle')}
            </h3>
            <ul className="flex flex-col divide-y rounded-xl border">
              {plan.habits.map((habit) => (
                <li key={habit.uuid} className="px-3 py-2">
                  {habit.title}
                </li>
              ))}
            </ul>
          </section>
        )}
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            {t('common.close')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
