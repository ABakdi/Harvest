import { weightIn } from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import { Trash2Icon } from 'lucide-react';
import { useState, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { formatDay } from '@/lib/format';
import { useHarvest } from '../../context';
import { useExercise } from '../../data/exercises';
import { exerciseHistory, exerciseRecords, type ExerciseOuting } from '../../data/gym';
import { SetList, SetText, useAsker, useLoad, useUnit } from './shared';

function Stat({ label, value, hint }: { label: string; value: ReactNode; hint?: string }) {
  return (
    <div className="flex min-w-0 flex-col">
      <dt className="text-xs text-muted-foreground">{label}</dt>
      <dd className="text-lg font-extrabold text-primary tabular">{value}</dd>
      {hint && <dd className="text-xs text-muted-foreground">{hint}</dd>}
    </div>
  );
}

/**
 * The run of the exercise: the estimated single each time, or each
 * session's volume. Oldest first, so it reads like a calendar — from
 * the start in either direction of writing.
 */
function HistoryChart({ history }: { history: ExerciseOuting[] }) {
  const { t } = useTranslation();
  const unit = useUnit();
  const load = useLoad();
  const [volume, setVolume] = useState(false);
  const outings = [...history].reverse();
  const points = outings
    .map((outing, index) => ({ index, grams: volume ? outing.volumeGrams : outing.bestEstimate }))
    .filter((point): point is { index: number; grams: number } => point.grams !== null && point.grams > 0);
  if (points.length < 2) return null;

  const values = points.map((point) => weightIn(unit, point.grams));
  const low = Math.min(...values);
  const high = Math.max(...values);
  const pad = Math.min(Math.max((high - low) * 0.15, 0.5), 20);
  const bottom = low - pad;
  const top = high + pad;
  const width = 320;
  const height = 120;
  const x = (index: number) => (outings.length === 1 ? 0 : (index / (outings.length - 1)) * width);
  const y = (value: number) => height - ((value - bottom) / (top - bottom)) * height;
  const line = points.map((point, i) => `${x(point.index)},${y(values[i]!)}`).join(' ');
  const low2 = Math.min(...points.map((point) => point.grams));
  const high2 = Math.max(...points.map((point) => point.grams));

  return (
    <div className="flex flex-col gap-2">
      <div role="group" aria-label={t('gym.chartKind')} className="flex gap-1.5">
        <Button size="sm" variant={volume ? 'outline' : 'default'} aria-pressed={!volume} onClick={() => setVolume(false)}>
          {t('gym.chartEstimate')}
        </Button>
        <Button size="sm" variant={volume ? 'default' : 'outline'} aria-pressed={volume} onClick={() => setVolume(true)}>
          {t('gym.chartVolume')}
        </Button>
      </div>
      <svg
        viewBox={`0 0 ${width} ${height}`}
        className="h-32 w-full"
        role="img"
        aria-label={t('gym.chartLabel', { from: load(low2), to: load(high2) })}
        preserveAspectRatio="none"
      >
        <polyline
          points={line}
          fill="none"
          strokeWidth={2.5}
          className={volume ? 'stroke-sun' : 'stroke-primary'}
          vectorEffect="non-scaling-stroke"
        />
        {points.length < 12 &&
          points.map((point, i) => (
            <circle key={point.index} cx={x(point.index)} cy={y(values[i]!)} r={3} className={volume ? 'fill-sun' : 'fill-primary'} />
          ))}
      </svg>
      <div className="flex justify-between text-xs text-muted-foreground" dir="ltr">
        <span>{formatDay(outings[0]!.day, { month: 'short', day: 'numeric' })}</span>
        <span>{formatDay(outings[outings.length - 1]!.day, { month: 'short', day: 'numeric' })}</span>
      </div>
    </div>
  );
}

/**
 * What it is and what I have done on it (`exercise_detail.dart`): the
 * muscles, the steps, the three records and their history. The
 * estimate says it is one, with the formula named (Y6).
 */
export function ExerciseDetailDialog({ exerciseId, onClose }: { exerciseId: string; onClose: () => void }) {
  const { t } = useTranslation();
  const { db, exercises } = useHarvest();
  const load = useLoad();
  const exercise = useExercise(db, exerciseId);
  const records = useLiveQuery(() => exerciseRecords(db, exerciseId), [db, exerciseId]);
  const history = useLiveQuery(() => exerciseHistory(db, exerciseId), [db, exerciseId]);
  const [asker, asking] = useAsker();
  const name = exercise?.name ?? t('gym.unknownExercise');

  async function remove() {
    const ok = await asker.confirm({
      title: t('gym.mineRemoveTitle', { name }),
      body: t('gym.mineRemoveBody'),
      action: t('common.remove'),
      destructive: true,
    });
    if (!ok) return;
    await exercises.remove(exerciseId);
    toast(t('gym.mineRemoved'));
    onClose();
  }

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-h-[90dvh] max-w-lg overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{name}</DialogTitle>
          <DialogDescription>
            {[exercise?.mine ? t('gym.mine') : null, exercise?.bodyPart, exercise?.equipment].filter(Boolean).join(' · ') || t('gym.exercise')}
          </DialogDescription>
        </DialogHeader>
        {exercise && (exercise.target || exercise.secondary.length > 0) && (
          <ul aria-label={t('gym.muscles')} className="flex flex-wrap gap-1.5 text-xs">
            {exercise.target && <li className="rounded-full bg-primary/15 px-2.5 py-1 font-bold text-primary">{exercise.target}</li>}
            {exercise.secondary.map((muscle) => (
              <li key={muscle} className="rounded-full bg-muted px-2.5 py-1">
                {muscle}
              </li>
            ))}
          </ul>
        )}
        {exercise && !exercise.mine && (
          exercise.steps.length === 0 ? (
            <p className="text-sm text-muted-foreground">{t('gym.noInstructions')}</p>
          ) : (
            <ol className="flex list-decimal flex-col gap-2 ps-5 text-sm marker:font-extrabold marker:text-primary">
              {exercise.steps.map((step) => (
                <li key={step}>{step}</li>
              ))}
            </ol>
          )
        )}
        <section aria-labelledby="exercise-records" className="flex flex-col gap-3">
          <h3 id="exercise-records" className="font-extrabold">
            {t('gym.records')}
          </h3>
          {!history || history.length === 0 || !records ? (
            <p className="text-sm text-muted-foreground">{t('gym.noRecords')}</p>
          ) : (
            <>
              <dl className="grid grid-cols-1 gap-3 sm:grid-cols-3">
                {records.heaviest && <Stat label={t('gym.heaviestLabel')} value={<SetText>{`${load(records.heaviest.weightGrams)}×${records.heaviest.reps}`}</SetText>} />}
                {records.bestSetEstimate !== null && (
                  <Stat label={t('gym.estimatedLabel')} value={load(records.bestSetEstimate)} hint={t('gym.estimatedHint')} />
                )}
                {records.bestSessionVolumeGrams > 0 && (
                  <Stat label={t('gym.bestVolumeLabel')} value={load(records.bestSessionVolumeGrams)} hint={t('gym.bestVolumeHint')} />
                )}
              </dl>
              {history.length > 1 && <HistoryChart history={history} />}
              <h3 className="font-extrabold">{t('gym.history')}</h3>
              <ul className="flex flex-col gap-1.5 text-sm">
                {history.slice(0, 8).map((outing, index) => (
                  <li key={`${outing.day}-${index}`} className="flex items-baseline gap-3">
                    <span className="w-20 shrink-0 text-muted-foreground">{formatDay(outing.day)}</span>
                    <span className="min-w-0 flex-1 tabular" dir="ltr">
                      <SetList labels={outing.sets.map((set) => `${load(set.weightGrams)}×${set.reps}`)} />
                    </span>
                    {outing.bestEstimate !== null && (
                      <span className="font-bold text-primary tabular" title={t('gym.estimatedLabel')}>
                        {load(outing.bestEstimate)}
                      </span>
                    )}
                  </li>
                ))}
              </ul>
            </>
          )}
        </section>
        {exercise?.mine && (
          <Button variant="ghost" className="self-start text-destructive" onClick={() => void remove()}>
            <Trash2Icon />
            {t('gym.mineRemove')}
          </Button>
        )}
        {asking}
      </DialogContent>
    </Dialog>
  );
}

