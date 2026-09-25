import { type HarvestDay, cycleMinutes, formatClock, parseClock } from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import { StarIcon } from 'lucide-react';
import { useId, useState, type FormEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Label } from '@/components/ui/label';
import { formatDay } from '@/lib/format';
import { cn } from '@/lib/utils';
import { useHarvest } from '../context';
import { type SleepRow, type SleepTargets, atMinutes, cycleForMorning, defaultNight, readSleepTargets } from '../data/health';
import { clockOfMinutes } from '../data/settings';
import { useBusy } from './use-busy';

/**
 * Where the two times sit around the morning's midnight, within the
 * ranges the phone's sliders allow: falling asleep from eight in the
 * evening before to eleven in the morning, waking from eight in the
 * evening before to three in the afternoon. A clock typed into a box
 * has no side of midnight of its own, so the earlier reading that
 * still comes before waking is the one meant. Null when the two do
 * not make a night.
 */
export function nightFromClocks(asleepText: string, wokeText: string): { asleep: number; woke: number } | null {
  const asleepClock = parseClock(asleepText);
  const wokeClock = parseClock(wokeText);
  if (!asleepClock || !wokeClock) return null;
  const wokeAt = wokeClock.hour * 60 + wokeClock.minute;
  const woke = wokeAt <= 15 * 60 ? wokeAt : wokeAt >= 20 * 60 ? wokeAt - 24 * 60 : null;
  if (woke === null) return null;
  const at = asleepClock.hour * 60 + asleepClock.minute;
  const asleep = [at, at - 24 * 60].find((minutes) => minutes < woke && minutes >= -4 * 60 && minutes <= 11 * 60);
  return asleep === undefined ? null : { asleep, woke };
}

function localClock(moment: string): string {
  const date = new Date(moment);
  return formatClock({ hour: date.getHours(), minute: date.getMinutes() });
}

/**
 * The morning retrospective (`showSleepSheet`): two times and a
 * feeling, pre-filled with the night the settings expect, so a normal
 * night is open, tap the stars, done. Writing it down pays +15 XP the
 * first time ([[Health]] H6); correcting it pays nothing more.
 */
export function SleepEditor({ day, night, onClose }: { day: HarvestDay; night: SleepRow | null; onClose: () => void }) {
  const { db } = useHarvest();
  const targets = useLiveQuery(() => readSleepTargets(db), [db]);
  if (!targets) return null;
  return <SleepForm day={day} night={night} targets={targets} onClose={onClose} />;
}

function SleepForm({
  day,
  night,
  targets,
  onClose,
}: {
  day: HarvestDay;
  night: SleepRow | null;
  targets: SleepTargets;
  onClose: () => void;
}) {
  const { t } = useTranslation();
  const { health } = useHarvest();
  const id = useId();
  const [asleep, setAsleep] = useState(() =>
    night ? localClock(night.fellAsleepAt) : formatClock(clockOfMinutes(defaultNight(targets, day).asleep)),
  );
  const [woke, setWoke] = useState(() =>
    night ? localClock(night.wokeAt) : formatClock(clockOfMinutes(defaultNight(targets, day).woke)),
  );
  const [stars, setStars] = useState<number | null>(night?.restedStars ?? null);
  const [saving, once] = useBusy();

  const span = nightFromClocks(asleep, woke);
  // The two instants the save writes, and the time between them: on a
  // night the clocks change, that is an hour off the two faces' gap.
  const fellAsleepAt = span ? atMinutes(day, span.asleep) : null;
  const wokeAt = span ? atMinutes(day, span.woke) : null;
  const slept = fellAsleepAt && wokeAt ? Math.round((wokeAt.getTime() - fellAsleepAt.getTime()) / 60_000) : 0;

  async function save() {
    if (!fellAsleepAt || !wokeAt || slept <= 0) return;
    try {
      const paid = await health.logNight({
        day,
        fellAsleepAt,
        wokeAt,
        // The target is copied in as of this night (Business rule 3).
        targetMinutes: night?.targetMinutes ?? cycleMinutes(cycleForMorning(targets, day)),
        restedStars: stars,
      });
      if (paid) toast.success(t('sleepWeb.paid'));
      onClose();
    } catch {
      toast.error(t('common.saveFailed'));
    }
  }

  function submit(event: FormEvent) {
    event.preventDefault();
    void once(save);
  }

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('sleepWeb.title', { day: formatDay(day.key) })}</DialogTitle>
          <DialogDescription>{t('sleepWeb.lead')}</DialogDescription>
        </DialogHeader>
        <form onSubmit={submit} className="flex flex-col gap-4" noValidate>
          <p className="text-center text-4xl font-extrabold tabular text-primary" aria-live="polite">
            {span ? t('body.duration', { hours: Math.trunc(slept / 60), minutes: slept % 60 }) : '—'}
          </p>
          <div className="grid grid-cols-2 gap-3">
            <div className="flex flex-col gap-2">
              <Label htmlFor={`${id}-asleep`}>{t('sleepWeb.fellAsleep')}</Label>
              <input
                id={`${id}-asleep`}
                type="time"
                dir="ltr"
                required
                value={asleep}
                onChange={(event) => setAsleep(event.target.value)}
                className="h-10 rounded-md border bg-transparent px-3 text-lg font-extrabold tabular outline-none focus-visible:ring-2 focus-visible:ring-ring"
              />
            </div>
            <div className="flex flex-col gap-2">
              <Label htmlFor={`${id}-woke`}>{t('sleepWeb.woke')}</Label>
              <input
                id={`${id}-woke`}
                type="time"
                dir="ltr"
                required
                value={woke}
                onChange={(event) => setWoke(event.target.value)}
                className="h-10 rounded-md border bg-transparent px-3 text-lg font-extrabold tabular outline-none focus-visible:ring-2 focus-visible:ring-ring"
              />
            </div>
          </div>
          {!span && (
            <p role="alert" className="text-sm font-semibold text-destructive">
              {t('sleepWeb.notANight')}
            </p>
          )}
          <div className="flex flex-col gap-2">
            <span id={`${id}-rested`} className="text-sm font-bold">
              {t('sleepWeb.rested')}
            </span>
            <div role="group" aria-labelledby={`${id}-rested`} className="flex justify-between gap-1">
              {[1, 2, 3, 4, 5].map((star) => {
                const lit = stars !== null && star <= stars;
                return (
                  <Button
                    key={star}
                    type="button"
                    variant="ghost"
                    size="icon"
                    aria-pressed={stars === star}
                    aria-label={t('body.stars', { count: star })}
                    // Tapping the chosen star takes it back: "I would
                    // rather not say" stays reachable.
                    onClick={() => setStars(stars === star ? null : star)}
                    className="size-11"
                  >
                    <StarIcon className={cn('size-8', lit ? 'fill-sun text-sun' : 'text-muted-foreground')} />
                  </Button>
                );
              })}
            </div>
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={onClose}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" disabled={!span || slept <= 0 || saving}>
              {t('sleepWeb.save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
