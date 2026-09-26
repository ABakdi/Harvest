import { useLiveQuery } from 'dexie-react-hooks';
import { ArrowLeftIcon, PauseIcon, PlayIcon } from 'lucide-react';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Link, useNavigate, useSearchParams } from 'react-router';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { formatNumber } from '@/lib/format';
import { cn } from '@/lib/utils';
import { formatTimer, useNow, usePomodoroState } from '../components/pomodoro-timer';
import { SeedLogDialog } from '../components/seed-log-dialog';
import { useHarvest, useHarvestDay } from '../context';
import { isRunning, phaseMs, remainingMs } from '../data/pomodoro';
import type { SeedRow } from '../data/seeds';
import { useGymSeedChoice } from './gym/start';

/** A thick ring for the clock, emptying as the phase runs out. */
function ClockRing({ ratio, onBreak }: { ratio: number; onBreak: boolean }) {
  const size = 260;
  const stroke = 12;
  const radius = (size - stroke) / 2;
  const circumference = 2 * Math.PI * radius;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} aria-hidden className="absolute inset-0 size-full -rotate-90">
      <circle cx={size / 2} cy={size / 2} r={radius} fill="none" strokeWidth={stroke} className="stroke-muted" />
      <circle
        cx={size / 2}
        cy={size / 2}
        r={radius}
        fill="none"
        strokeWidth={stroke}
        strokeLinecap="round"
        strokeDasharray={circumference}
        strokeDashoffset={circumference * (1 - Math.min(Math.max(ratio, 0), 1))}
        className={cn('transition-[stroke-dashoffset] duration-1000 ease-linear', onBreak ? 'stroke-success' : 'stroke-primary')}
      />
    </svg>
  );
}

/** A dot per block in the cycle before the long break. */
function BlockDots({ done, perLong }: { done: number; perLong: number }) {
  const { t } = useTranslation();
  const cycle = Math.max(perLong, 1);
  const inCycle = done % cycle;
  const filled = inCycle === 0 && done > 0 ? cycle : inCycle;
  return (
    <div role="img" aria-label={t('focus.blocksDone', { count: done })} className="flex gap-2">
      {Array.from({ length: cycle }, (_, index) => (
        <span key={index} className={cn('size-3 rounded-full', index < filled ? 'bg-primary' : 'bg-muted')} />
      ))}
    </div>
  );
}

/**
 * The focus timer, as the phone runs it: a block of focus, a short
 * break, and a long one every few blocks. Each finished block pays XP
 * through the ledger; finishing a fruitful session attached to a seed
 * checks the seed in, and abandoning one costs nothing.
 */
export function PomodoroScreen() {
  const { t } = useTranslation();
  const { db, pomodoro, checkIns } = useHarvest();
  const navigate = useNavigate();
  const day = useHarvestDay();
  const [params] = useSearchParams();
  const state = usePomodoroState();
  const snapshot = state?.snapshot ?? null;
  const now = useNow(snapshot !== null && isRunning(snapshot));
  const [logging, setLogging] = useState<SeedRow | null>(null);
  const [busy, setBusy] = useState(false);
  const gymChoice = useGymSeedChoice({ onBare: () => void navigate('/app/field') });

  // The seed of the running session, or the one this screen opened for.
  const wanted = snapshot ? snapshot.commitmentUuid : params.get('seed');
  const attached = useLiveQuery(
    async () => {
      if (!wanted) return null;
      const row = await db.rows('commitments').get(wanted);
      return row && row.deletedAt === null && row.archivedAt === null ? row : null;
    },
    [db, wanted],
  );
  if (!state || attached === undefined) return null;

  const { config } = state;
  const phase = snapshot?.phase ?? 'focus';
  const total = phaseMs(config, phase);
  const left = snapshot === null ? total : Math.min(Math.max(remainingMs(snapshot, now), 0), total);
  const onBreak = phase !== 'focus';
  const waitingNextFocus = snapshot !== null && !isRunning(snapshot) && !onBreak && !snapshot.userPaused;
  const phaseLabel = waitingNextFocus ? t('focus.breakOverReady') : t(`focus.phase.${phase}`);

  async function act(work: () => Promise<unknown>) {
    setBusy(true);
    try {
      await work();
    } catch {
      toast.error(t('common.saveFailed'));
    } finally {
      setBusy(false);
    }
  }

  /**
   * A fruitful session attached to a habit or a to-do checks it in
   * directly; a project opens the log for how much got done, and a gym
   * seed asks what happened, as the field does (Y12).
   */
  async function finish() {
    const seedUuid = await pomodoro.finish();
    const seed = attached;
    if (seedUuid !== null && seed && seed.uuid === seedUuid) {
      if (seed.type === 'project') {
        setLogging(seed);
        return;
      }
      if (await gymChoice.ask(seed)) return;
      const plan = await checkIns.checkIn(seed, day);
      if (plan.quantityLogged > 0) toast.success(t('field.xpEarned', { count: plan.xpEarned }));
    }
    void navigate('/app/field');
  }

  return (
    <div className="flex flex-col gap-4">
      <Button asChild variant="ghost" size="sm" className="w-fit">
        <Link to="/app/field">
          <ArrowLeftIcon className="rtl:rotate-180" />
          {t('field.today')}
        </Link>
      </Button>
      <section aria-labelledby="focus-heading" className="mx-auto flex w-full max-w-md flex-col items-center gap-6 py-4 text-center">
        <div className="flex flex-col gap-1">
          <h1 id="focus-heading" className="text-2xl font-extrabold">
            {t('focus.title')}
          </h1>
          <p className="font-bold text-muted-foreground">{attached?.title ?? t('focus.free')}</p>
        </div>
        <div className="relative flex size-64 items-center justify-center sm:size-[260px]">
          <ClockRing ratio={total === 0 ? 0 : left / total} onBreak={onBreak} />
          <div className="flex flex-col items-center gap-1" role="timer" aria-live="off" aria-label={`${phaseLabel} · ${formatTimer(left)}`}>
            <span className="text-6xl font-extrabold tabular">{formatTimer(left)}</span>
            <span className="max-w-44 text-sm text-muted-foreground">{phaseLabel}</span>
          </div>
        </div>
        <BlockDots done={snapshot?.blocksDone ?? 0} perLong={config.blocksPerLongBreak} />

        <div className="flex flex-col items-center gap-2">
          {snapshot === null ? (
            <Button size="lg" disabled={busy} onClick={() => void act(() => pomodoro.start(attached?.uuid ?? null))}>
              <PlayIcon />
              {t('focus.start')}
            </Button>
          ) : isRunning(snapshot) ? (
            <Button size="lg" variant="secondary" disabled={busy} onClick={() => void act(() => pomodoro.pause())}>
              <PauseIcon />
              {t('focus.pause')}
            </Button>
          ) : (
            <Button size="lg" disabled={busy} onClick={() => void act(() => pomodoro.resume())}>
              <PlayIcon />
              {waitingNextFocus ? t('focus.start') : t('focus.resume')}
            </Button>
          )}
          {snapshot !== null && (
            <>
              <Button variant="ghost" disabled={busy} onClick={() => void act(snapshot.blocksDone > 0 ? finish : () => pomodoro.abandon())}>
                {snapshot.blocksDone > 0 ? t('focus.finish') : t('focus.abandon')}
              </Button>
              {snapshot.blocksDone === 0 && <p className="text-xs text-muted-foreground">{t('focus.abandonBody')}</p>}
            </>
          )}
        </div>
        <p className="text-xs text-muted-foreground tabular">
          {t('focus.lengths', {
            focus: formatNumber(config.focusMinutes),
            short: formatNumber(config.shortBreakMinutes),
            long: formatNumber(config.longBreakMinutes),
            every: formatNumber(config.blocksPerLongBreak),
          })}
        </p>
      </section>
      {gymChoice.dialog}
      {logging && (
        <SeedLogDialog
          seed={logging}
          onClose={() => {
            setLogging(null);
            void navigate('/app/field');
          }}
        />
      )}
    </div>
  );
}
