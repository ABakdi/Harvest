import { Xp } from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import { PauseIcon, TimerIcon } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Link } from 'react-router';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { useHarvest } from '../context';
import {
  type PomodoroConfig,
  type PomodoroSnapshot,
  isRunning,
  readActive,
  readPomodoroConfig,
  remainingMs,
} from '../data/pomodoro';

export interface PomodoroState {
  snapshot: PomodoroSnapshot | null;
  config: PomodoroConfig;
}

/** The running timer and the lengths in force, live; undefined while they load. */
export function usePomodoroState(): PomodoroState | undefined {
  const { db } = useHarvest();
  return useLiveQuery(async () => {
    const [snapshot, config] = await Promise.all([readActive(db), readPomodoroConfig(db)]);
    return { snapshot, config };
  }, [db]);
}

/**
 * One second hand for a timer on screen, ticking only while [running]:
 * the time itself is always read from the clock, never counted.
 */
export function useNow(running: boolean): Date {
  const { clock } = useHarvest();
  const [, setTick] = useState(0);
  useEffect(() => {
    if (!running) return;
    const timer = setInterval(() => setTick((n) => n + 1), 1000);
    return () => clearInterval(timer);
  }, [running]);
  return clock();
}

/** `mm:ss`, never below zero. */
export function formatTimer(ms: number): string {
  const seconds = Math.max(Math.ceil(ms / 1000), 0);
  return `${String(Math.floor(seconds / 60)).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`;
}

/**
 * Walks the timer over a boundary the moment one passes, and says so:
 * a focus block that ends is paid and its break starts; a break that
 * ends waits for the next block. The phone buzzes and posts its
 * countdown notification; the web says it here, in the page.
 */
function useAdvance(state: PomodoroState | undefined, now: Date) {
  const { t } = useTranslation();
  const { pomodoro } = useHarvest();
  const busy = useRef(false);
  const due = state?.snapshot && isRunning(state.snapshot) && remainingMs(state.snapshot, now) <= 0;
  useEffect(() => {
    if (!due || busy.current) return;
    busy.current = true;
    void pomodoro
      .evaluate()
      .then((step) => {
        if (!step) return;
        if (step.blocks.length > 0) {
          toast.success(t('focus.blockDone', { count: Xp.pomodoroBlock * step.blocks.length }));
        } else if (step.breakOver) {
          toast(t('focus.breakOverReady'));
        }
      })
      .finally(() => {
        busy.current = false;
      });
  }, [due, pomodoro, t]);
}

/**
 * The small live countdown in the header while a session is on — proof
 * the timer is still ticking, on every screen. With no session it is
 * the way in to the timer.
 */
export function PomodoroChip() {
  const { t } = useTranslation();
  const state = usePomodoroState();
  const snapshot = state?.snapshot ?? null;
  const now = useNow(snapshot !== null && isRunning(snapshot));
  useAdvance(state, now);

  if (snapshot === null) {
    return (
      <Button asChild variant="ghost" size="icon" aria-label={t('focus.timer')} title={t('focus.timer')}>
        <Link to="/app/field/focus">
          <TimerIcon />
        </Link>
      </Button>
    );
  }

  const running = isRunning(snapshot);
  const left = formatTimer(remainingMs(snapshot, now));
  const onBreak = snapshot.phase !== 'focus';
  return (
    <Link
      to="/app/field/focus"
      aria-label={t('focus.chipLabel', { time: left })}
      className={cn(
        'inline-flex h-8 items-center gap-1 rounded-full border px-2.5 text-sm font-extrabold tabular outline-none focus-visible:ring-2 focus-visible:ring-ring',
        onBreak ? 'border-success/40 text-success' : 'border-primary/40 text-primary',
      )}
    >
      {running ? <TimerIcon className="size-4" aria-hidden /> : <PauseIcon className="size-4" aria-hidden />}
      <span aria-hidden>{left}</span>
    </Link>
  );
}
