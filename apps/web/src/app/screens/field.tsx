import { useLiveQuery } from 'dexie-react-hooks';
import {
  ArchiveIcon,
  CheckIcon,
  ChevronDownIcon,
  CoinsIcon,
  EllipsisVerticalIcon,
  FlameIcon,
  PauseIcon,
  PencilIcon,
  PlayIcon,
  PlusIcon,
  SproutIcon,
  Undo2Icon,
} from 'lucide-react';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { NavLink } from 'react-router';
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
import { farmerRankForXp } from '@harvest/core';
import { formatDay, formatNumber } from '@/lib/format';
import { cn } from '@/lib/utils';
import { EmptyState, ProgressRing, StreakChip } from '../components/bits';
import { useHarvest, useHarvestDay } from '../context';
import { loadField, type FieldSeed } from '../data/field';
import { useDialogs } from '../dialogs';
import { useShortcuts } from '../shortcuts';
import { GoalsBoard } from './goals-board';

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

/** What a seed's card says under its title. */
function useSubtitle(seed: FieldSeed): string {
  const { t } = useTranslation();
  const { row, commitment } = seed;
  if (row.pausedAt !== null) return t('field.paused');
  switch (row.type) {
    case 'habit': {
      const schedule = commitment.schedule;
      if (!schedule || schedule.type === 'daily') return t('field.schedule.daily');
      if (schedule.type === 'weekly') return t('field.schedule.weekly', { count: schedule.weekdays.size });
      if (schedule.type === 'interval') return t('field.schedule.interval', { count: schedule.everyDays });
      return t('field.schedule.timesPerWeek', { count: schedule.times, done: seed.doneDaysThisWeek });
    }
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
}: {
  seed: FieldSeed;
  onCheck: (seed: FieldSeed) => void;
  onUndo: (seed: FieldSeed) => void;
  onLog: (seed: FieldSeed) => void;
  onArchive: (seed: FieldSeed) => void;
}) {
  const { t } = useTranslation();
  const { seeds } = useHarvest();
  const dialogs = useDialogs();
  const subtitle = useSubtitle(seed);
  const { row } = seed;
  const paused = row.pausedAt !== null;
  const checkLabel = seed.done
    ? t('field.undoLabel', { title: row.title })
    : row.type === 'project'
      ? t('field.logLabel', { title: row.title })
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
        <span className={cn('truncate font-bold', seed.done && row.type !== 'project' && 'text-muted-foreground line-through')}>
          {row.title}
        </span>
        <span className={cn('truncate text-xs text-muted-foreground', seed.overdue && !seed.done && 'font-bold text-destructive')}>
          {subtitle}
        </span>
        {row.note && <span className="truncate text-xs text-muted-foreground">{row.note}</span>}
      </div>
      {seed.streak !== null && <StreakChip count={seed.streak} />}
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" size="icon-sm" aria-label={t('field.options', { title: row.title })}>
            <EllipsisVerticalIcon />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
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
            <DropdownMenuItem onSelect={() => void seeds.setPaused(row.uuid, !paused)}>
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

function LogDialog({ seed, onClose }: { seed: FieldSeed; onClose: () => void }) {
  const { t } = useTranslation();
  const { checkIns } = useHarvest();
  const day = useHarvestDay();
  const [quantity, setQuantity] = useState(String(Math.min(seed.row.dailyCommitment ?? 1, Math.max(seed.room, 1))));
  const value = Number(quantity);
  const valid = Number.isInteger(value) && value >= 1;

  async function log() {
    if (!valid) return;
    const plan = await checkIns.checkIn(seed.row, day, value);
    onClose();
    if (plan.quantityLogged > 0) toast.success(t('field.xpEarned', { count: plan.xpEarned }));
    if (plan.capped) toast(t('field.capped'));
  }

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-sm">
        <DialogHeader>
          <DialogTitle>{t('field.logProgressTitle')}</DialogTitle>
          <DialogDescription>{seed.row.title}</DialogDescription>
        </DialogHeader>
        <form
          className="flex flex-col gap-3"
          onSubmit={(event) => {
            event.preventDefault();
            void log();
          }}
        >
          <Label htmlFor="log-quantity">{t('field.howMuch')}</Label>
          <Input
            id="log-quantity"
            type="number"
            min={1}
            inputMode="numeric"
            autoFocus
            value={quantity}
            onChange={(event) => setQuantity(event.target.value)}
          />
          <p className="text-sm text-muted-foreground">{t('field.remaining', { count: seed.room })}</p>
          <DialogFooter>
            <Button variant="outline" onClick={onClose}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" disabled={!valid || seed.room === 0}>
              {t('field.log')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
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
  const { db, checkIns } = useHarvest();
  const dialogs = useDialogs();
  const day = useHarvestDay();
  const view = useLiveQuery(() => loadField(db, day), [db, day.key]);
  const [undoing, setUndoing] = useState<FieldSeed | null>(null);
  const [logging, setLogging] = useState<FieldSeed | null>(null);
  const [archiving, setArchiving] = useState<FieldSeed | null>(null);

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
      const plan = await checkIns.checkIn(seed.row, day);
      if (plan.quantityLogged > 0) toast.success(t('field.xpEarned', { count: plan.xpEarned }));
      else if (plan.capped) toast(t('field.capped'));
    } catch {
      toast.error(t('field.checkInFailed'));
    }
  }

  if (!view) return null;
  const rank = farmerRankForXp(view.totalXp);

  return (
    <div className="flex flex-col gap-4">
      <section aria-label={t('field.summary')} className="flex flex-wrap items-center gap-4 rounded-2xl border bg-card p-4">
        <ProgressRing
          ratio={view.goal > 0 ? view.actions / view.goal : 0}
          size={56}
          label={t('field.goalProgress', { actions: view.actions, goal: view.goal })}
        />
        <div className="flex min-w-0 flex-1 flex-col">
          <h1 className="text-xl font-extrabold">{formatDay(day.key, { weekday: 'long', month: 'long', day: 'numeric' })}</h1>
          <p className="text-sm text-muted-foreground">{t('field.goalProgress', { actions: view.actions, goal: view.goal })}</p>
        </div>
        <dl className="flex flex-wrap gap-2 text-sm">
          <div className="flex items-center gap-1 rounded-full bg-muted px-3 py-1 font-extrabold" title={t('streak.global')}>
            <dt className="sr-only">{t('streak.global')}</dt>
            <FlameIcon className="size-4 text-primary" aria-hidden />
            <dd className="tabular">{t('streak.days', { count: view.streak.current })}</dd>
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
      </section>

      {view.today.length === 0 && view.resting.length === 0 ? (
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
            {t('field.dueToday', { count: view.today.length })}
          </h2>
          {view.today.length === 0 ? (
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
                />
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
              />
            ))}
          </ul>
        </details>
      )}

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
                if (undoing) void checkIns.undo(undoing.row, day);
              }}
            >
              {t('common.undo')}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
      {logging && <LogDialog seed={logging} onClose={() => setLogging(null)} />}
      {archiving && <ArchiveDialog seed={archiving} onClose={() => setArchiving(null)} />}
    </div>
  );
}
