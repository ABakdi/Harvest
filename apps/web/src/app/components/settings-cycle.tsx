import { type Clock, type Cycle, cycleMinutes, encodeCycle, fallbackCycle } from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import { MoonIcon, TriangleAlertIcon } from 'lucide-react';
import { useId, useState } from 'react';
import { useTranslation } from 'react-i18next';
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
import { Switch } from '@/components/ui/switch';
import { formatDate, formatNumber } from '@/lib/format';
import { cn } from '@/lib/utils';
import { useHarvest } from '../context';
import { readSleepTargets, sleepNightKey } from '../data/health';
import { type SleepClash, cycleClashes, readCycle } from '../data/settings';
import { ClockInput, SettingsRow, clockLabel } from './settings-bits';

/** Eight is the target and five the floor (`DailyCycle.recommended`, `shortest`). */
const recommendedMinutes = 8 * 60;
const shortestMinutes = 5 * 60;

/** "7" for a round night, "7.5" for half an hour more. */
function hoursText(minutes: number): string {
  return formatNumber(minutes / 60, { maximumFractionDigits: 1 });
}

/**
 * When I sleep and when I wake (`DailyCycleCard`). Changing either finds
 * the reminders the new night would swallow, names them, and moves them
 * only if I say so — each keeping its own distance from waking.
 */
export function DailyCycleCard() {
  const { t } = useTranslation();
  const { db, settings } = useHarvest();
  const id = useId();
  const cycle = useLiveQuery(() => readCycle(db), [db]) ?? fallbackCycle;
  const [asking, setAsking] = useState<SleepClash[] | null>(null);

  const change = async (next: Cycle) => {
    if (encodeCycle(next) === encodeCycle(cycle)) return;
    const current = cycle;
    await settings.writeCycle(next);
    const clashes = await cycleClashes(db, current, next);
    if (clashes.length > 0) setAsking(clashes);
  };

  const minutes = cycleMinutes(cycle);
  const short = minutes < shortestMinutes;
  return (
    <div className="flex flex-col gap-3">
      <SettingsRow label={t('settingsWeb.cycleBedTime')} htmlFor={`${id}-bed`}>
        <ClockInput id={`${id}-bed`} value={cycle.bedTime} onCommit={(bedTime) => void change({ ...cycle, bedTime })} />
      </SettingsRow>
      <SettingsRow label={t('settingsWeb.cycleWakeTime')} htmlFor={`${id}-wake`}>
        <ClockInput id={`${id}-wake`} value={cycle.wakeTime} onCommit={(wakeTime) => void change({ ...cycle, wakeTime })} />
      </SettingsRow>
      <p className={cn('flex items-start gap-2 text-sm', short ? 'font-extrabold text-destructive' : 'text-muted-foreground')}>
        {short ? <TriangleAlertIcon className="mt-0.5 size-4 shrink-0" aria-hidden /> : <MoonIcon className="mt-0.5 size-4 shrink-0" aria-hidden />}
        {short
          ? t('settingsWeb.cycleTooShort', { hours: hoursText(minutes) })
          : minutes >= recommendedMinutes
            ? t('settingsWeb.cycleGood', { hours: hoursText(minutes) })
            : t('settingsWeb.cycleBelowTarget', { hours: hoursText(minutes) })}
      </p>
      <AlertDialog open={asking !== null} onOpenChange={(open) => !open && setAsking(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>{t('settingsWeb.clashTitle', { count: asking?.length ?? 0 })}</AlertDialogTitle>
            <AlertDialogDescription>{t('settingsWeb.clashBody')}</AlertDialogDescription>
          </AlertDialogHeader>
          <ul className="flex flex-col gap-1 text-sm">
            {asking?.slice(0, 6).map((clash) => (
              <li key={`${clash.kind}-${clash.uuid}`}>
                {t('settingsWeb.clashMove', { title: clash.title, from: clockLabel(clash.at), to: clockLabel(clash.movedTo) })}
              </li>
            ))}
            {asking && asking.length > 6 && <li>{t('settingsWeb.clashMore', { count: asking.length - 6 })}</li>}
          </ul>
          <AlertDialogFooter>
            <AlertDialogCancel>{t('settingsWeb.clashKeep')}</AlertDialogCancel>
            <AlertDialogAction
              onClick={() => {
                if (asking) void settings.shiftReminders(asking);
                setAsking(null);
              }}
            >
              {t('settingsWeb.clashShift')}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}

/** Monday first, as `sleep.night.1` is. */
function weekdayName(weekday: number): string {
  // 2024-01-01 was a Monday.
  return formatDate(new Date(2024, 0, weekday), { weekday: 'long' });
}

/**
 * The weekdays that are their own night (`SleepSettingsCard`'s
 * overrides): Saturday is not Tuesday. A weekday with nothing of its own
 * follows the daily cycle; switching one off stores an empty value, as
 * the phone's clear does.
 */
export function SleepNightsCard() {
  const { t } = useTranslation();
  const { db, settings } = useHarvest();
  const targets = useLiveQuery(() => readSleepTargets(db), [db]);
  if (!targets) return null;

  const write = (weekday: number, cycle: Cycle | null) =>
    void settings.setString(sleepNightKey(weekday), cycle === null ? '' : encodeCycle(cycle));

  return (
    <ul className="flex flex-col divide-y">
      {[1, 2, 3, 4, 5, 6, 7].map((weekday) => {
        const own = targets.overrides[weekday] ?? null;
        const name = weekdayName(weekday);
        const set = (part: 'bedTime' | 'wakeTime', clock: Clock) => write(weekday, { ...(own ?? targets.cycle), [part]: clock });
        return (
          <li key={weekday} className="flex flex-wrap items-center gap-x-3 gap-y-2 py-2">
            <Switch
              checked={own !== null}
              aria-label={t('settingsWeb.ownNight', { day: name })}
              onCheckedChange={(on) => write(weekday, on ? targets.cycle : null)}
            />
            <span className="min-w-24 flex-1 text-sm font-bold">{name}</span>
            {own === null ? (
              <span className="text-sm text-muted-foreground">{t('settingsWeb.sameAsUsual')}</span>
            ) : (
              <span className="flex items-center gap-2 text-sm">
                <ClockInput
                  aria-label={t('settingsWeb.ownBed', { day: name })}
                  value={own.bedTime}
                  onCommit={(clock) => set('bedTime', clock)}
                />
                <span aria-hidden>–</span>
                <ClockInput
                  aria-label={t('settingsWeb.ownWake', { day: name })}
                  value={own.wakeTime}
                  onCommit={(clock) => set('wakeTime', clock)}
                />
              </span>
            )}
          </li>
        );
      })}
    </ul>
  );
}

