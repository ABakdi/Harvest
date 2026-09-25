import { HarvestDay, trendWindows, weightIn } from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import {
  BedIcon,
  FlagIcon,
  FootprintsIcon,
  PencilIcon,
  PlusIcon,
  ScaleIcon,
  SettingsIcon,
  SmartphoneIcon,
  Trash2Icon,
} from 'lucide-react';
import { useId, useState, type FormEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { Link } from 'react-router';
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
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group';
import { formatDate, formatDay, formatNumber } from '@/lib/format';
import { EmptyState } from '../components/bits';
import { useFeatures } from '../components/settings-bits';
import { SleepEditor } from '../components/sleep-editor';
import { WeightEditor } from '../components/weight-editor';
import { useHarvest, useHarvestDay } from '../context';
import {
  type SleepRow,
  type WeightRow,
  type WeightUnit,
  averageSteps,
  clampStride,
  defaultStrideCm,
  healthKeys,
  readNights,
  readSleepTargets,
  readSteps,
  readWeights,
  sleepSummary,
  sleptMinutesOf,
  stepGoalOf,
  stepsDistance,
  stepsHistory,
  weightSummary,
} from '../data/health';
import { useSetting } from '../hooks';
import { GymPanel } from './gym';

/** `7h 20m`, from minutes. */
function useDuration() {
  const { t } = useTranslation();
  return (minutes: number) => t('body.duration', { hours: Math.trunc(minutes / 60), minutes: minutes % 60 });
}

/** Kilograms until it is said otherwise, here or on the phone. */
function useWeightUnit(): WeightUnit {
  return useSetting(healthKeys.weightUnit) === 'lb' ? 'lb' : 'kg';
}

function useStride(): number {
  const raw = useSetting(healthKeys.strideCm);
  return raw ? clampStride(Number.parseInt(raw, 10)) : defaultStrideCm;
}

/** `6.2 km` or `3.9 mi`, one choice of units with the weight. */
function useDistance() {
  const { t } = useTranslation();
  const unit = useWeightUnit();
  const stride = useStride();
  return (steps: number) =>
    t(unit === 'kg' ? 'stepsWeb.km' : 'stepsWeb.mi', { value: stepsDistance(steps, stride, unit).toFixed(1) });
}

function Card({
  icon,
  title,
  action,
  children,
}: {
  icon: React.ReactNode;
  title: string;
  action?: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <section className="flex flex-col gap-3 rounded-2xl border bg-card p-5">
      <div className="flex flex-wrap items-center gap-2">
        <h2 className="flex flex-1 items-center gap-2 text-lg font-extrabold">
          <span className="text-primary [&_svg]:size-5">{icon}</span>
          {title}
        </h2>
        {action}
      </div>
      {children}
    </section>
  );
}

function Gauge({ ratio, label }: { ratio: number; label: string }) {
  const clamped = Math.min(Math.max(ratio, 0), 1);
  return (
    <div
      className="h-2 overflow-hidden rounded-full bg-muted"
      role="progressbar"
      aria-valuemin={0}
      aria-valuemax={100}
      aria-valuenow={Math.round(clamped * 100)}
      aria-label={label}
    >
      <div className="h-full rounded-full bg-sun transition-[width]" style={{ width: `${clamped * 100}%` }} />
    </div>
  );
}

// ---------------------------------------------------------------- sleep

type NightEditing = { day: HarvestDay; night: SleepRow | null } | null;

/**
 * Last night, and what is owed (`SleepCard`). The debt is a gauge that
 * fills rather than a number that accuses; full is three nights down.
 */
function SleepCard({ onLog }: { onLog: (editing: NonNullable<NightEditing>) => void }) {
  const { t } = useTranslation();
  const duration = useDuration();
  const { db } = useHarvest();
  const today = useHarvestDay();
  const data = useLiveQuery(async () => {
    const [rows, targets] = await Promise.all([readNights(db), readSleepTargets(db)]);
    return sleepSummary(rows, targets, today);
  }, [db, today.key]);
  if (!data) return null;

  const { last, unlogged, debt, averageMinutes, averageOver } = data;
  return (
    <Card
      icon={<BedIcon />}
      title={t('body.sleepTitle')}
      action={
        unlogged && (
          <Button size="sm" onClick={() => onLog({ day: today, night: null })}>
            <PlusIcon />
            {t('sleepWeb.logLastNight')}
          </Button>
        )
      }
    >
      <div className="flex flex-wrap items-baseline gap-x-4 gap-y-1">
        <span className={last ? 'text-3xl font-extrabold tabular' : 'text-lg font-extrabold'}>
          {last ? duration(sleptMinutesOf(last)) : t('sleepWeb.nothingYet')}
        </span>
        {last && <span className="text-sm text-muted-foreground">{t('body.nightOf', { day: formatDay(last.harvestDay) })}</span>}
      </div>
      {averageOver > 1 && (
        <p className="text-sm text-muted-foreground">
          {t('sleepWeb.average', {
            hours: Math.trunc(averageMinutes / 60),
            minutes: averageMinutes % 60,
            count: averageOver,
          })}
        </p>
      )}
      {debt.minutes > 0 && (
        <div className="flex flex-col gap-1">
          <div className="flex items-baseline justify-between text-sm">
            <span className="text-muted-foreground">{t('body.debt')}</span>
            <span className="font-extrabold tabular">{duration(debt.minutes)}</span>
          </div>
          <Gauge ratio={debt.nights / 3} label={t('body.debt')} />
          <p className="text-xs text-muted-foreground">{t('body.debtBody')}</p>
        </div>
      )}
    </Card>
  );
}

/**
 * Every night written down, newest first (`SleepNightsList`). Opening
 * one reopens its morning, because the usual reason to look is a number
 * I got wrong.
 */
function NightsCard({ onEdit }: { onEdit: (editing: NonNullable<NightEditing>) => void }) {
  const { t } = useTranslation();
  const duration = useDuration();
  const { db, health } = useHarvest();
  const rows = useLiveQuery(() => readNights(db), [db]);
  const [removing, setRemoving] = useState<SleepRow | null>(null);
  if (!rows) return null;

  return (
    <Card icon={<BedIcon />} title={t('sleepWeb.nights')}>
      {rows.length === 0 ? (
        <p className="text-sm text-muted-foreground">{t('sleepWeb.noNights')}</p>
      ) : (
        <ul className="flex flex-col divide-y text-sm">
          {rows.slice(0, 30).map((night) => {
            return (
              <li key={night.uuid} className="flex items-center gap-2 py-1.5">
                <button
                  type="button"
                  className="flex min-w-0 flex-1 items-center justify-between gap-2 rounded-md px-1 py-1 text-start outline-none hover:bg-accent focus-visible:ring-2 focus-visible:ring-ring"
                  aria-label={t('sleepWeb.editNight', { day: formatDay(night.harvestDay) })}
                  onClick={() => {
                    const parsed = HarvestDay.tryParse(night.harvestDay);
                    if (parsed) onEdit({ day: parsed, night });
                  }}
                >
                  <span className="text-muted-foreground">{formatDay(night.harvestDay)}</span>
                  <span className="flex items-center gap-2">
                    {night.restedStars !== null && (
                      <span className="text-sun" aria-label={t('body.stars', { count: night.restedStars })}>
                        {'★'.repeat(night.restedStars)}
                      </span>
                    )}
                    <span className="font-extrabold tabular">{duration(sleptMinutesOf(night))}</span>
                  </span>
                </button>
                <Button
                  variant="ghost"
                  size="icon"
                  aria-label={t('sleepWeb.deleteNightOf', { day: formatDay(night.harvestDay) })}
                  onClick={() => setRemoving(night)}
                >
                  <Trash2Icon />
                </Button>
              </li>
            );
          })}
        </ul>
      )}
      <AlertDialog open={removing !== null} onOpenChange={(open) => !open && setRemoving(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>{t('sleepWeb.deleteTitle')}</AlertDialogTitle>
            <AlertDialogDescription>{t('sleepWeb.deleteBody')}</AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>{t('common.cancel')}</AlertDialogCancel>
            <AlertDialogAction
              destructive
              onClick={() => {
                if (removing) void health.removeNight(removing.uuid);
                setRemoving(null);
              }}
            >
              {t('common.delete')}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </Card>
  );
}

// --------------------------------------------------------------- weight

/** Every entry as a dot, the seven-day average as the line ([[Health]] H5). */
function WeightChart({ rows, unit, days, target }: { rows: WeightRow[]; unit: WeightUnit; days: number; target: number | null }) {
  const { t } = useTranslation();
  const { points } = weightSummary(rows, days);
  const shown = points.slice(-days);
  const values = shown.flatMap((point) => [point.entry, point.average].filter((value): value is number => value !== null));
  if (shown.length < 2 || values.length === 0) return null;

  const low = Math.min(...values, ...(target === null ? [] : [target]));
  const high = Math.max(...values, ...(target === null ? [] : [target]));
  const pad = Math.max((high - low) * 0.15, 200);
  const top = high + pad;
  const bottom = low - pad;
  const width = 320;
  const height = 120;
  const x = (index: number) => (index / (shown.length - 1)) * width;
  const y = (grams: number) => height - ((grams - bottom) / (top - bottom)) * height;

  const line = shown
    .map((point, index) => (point.average === null ? null : `${x(index)},${y(point.average)}`))
    .filter((pair): pair is string => pair !== null)
    .join(' ');

  return (
    <svg
      viewBox={`0 0 ${width} ${height}`}
      className="h-32 w-full"
      role="img"
      aria-label={t('body.chartLabel', { from: weightIn(unit, low).toFixed(1), to: weightIn(unit, high).toFixed(1) })}
      preserveAspectRatio="none"
    >
      {target !== null && (
        <line
          x1={0}
          x2={width}
          y1={y(target)}
          y2={y(target)}
          strokeDasharray="6 4"
          strokeWidth={1.5}
          className="stroke-sun"
          vectorEffect="non-scaling-stroke"
        />
      )}
      {shown.map((point, index) =>
        point.entry === null ? null : (
          <circle key={point.day} cx={x(index)} cy={y(point.entry)} r={2.5} className="fill-muted-foreground/60" />
        ),
      )}
      {line && <polyline points={line} fill="none" strokeWidth={2.5} className="stroke-primary" vectorEffect="non-scaling-stroke" />}
    </svg>
  );
}

function useWeightText() {
  const { t } = useTranslation();
  const unit = useWeightUnit();
  return (grams: number) => `${formatNumber(weightIn(unit, grams), { maximumFractionDigits: 1 })} ${t(`body.unit.${unit}`)}`;
}

function WeightCard({ onLog }: { onLog: () => void }) {
  const { t } = useTranslation();
  const { db, settings } = useHarvest();
  const unit = useWeightUnit();
  const show = useWeightText();
  const stored = Number(useSetting(healthKeys.trendDays) ?? 30);
  const days = (trendWindows as readonly number[]).includes(stored) ? stored : 30;
  const targetText = useSetting(healthKeys.targetGrams);
  const target = targetText ? Number.parseInt(targetText, 10) || null : null;
  const rows = useLiveQuery(() => readWeights(db), [db]);
  if (!rows) return null;

  const { latest, trend } = weightSummary(rows, days);

  return (
    <Card
      icon={<ScaleIcon />}
      title={t('body.weightTitle')}
      action={
        <Button size="sm" variant="outline" onClick={onLog}>
          <PlusIcon />
          {t('weightWeb.log')}
        </Button>
      }
    >
      {latest === null ? (
        <p className="text-sm text-muted-foreground">{t('weightWeb.empty')}</p>
      ) : (
        <>
          <div className="flex flex-wrap items-baseline gap-x-4 gap-y-1">
            <span className="text-3xl font-extrabold tabular">{show(latest.grams)}</span>
            <span className="text-sm text-muted-foreground">{formatDay(latest.harvestDay)}</span>
          </div>
          {/* The direction, never a judgement on it ([[Health]] H5). */}
          <p className="text-sm font-bold text-primary">
            {trend === null
              ? t('body.noTrend')
              : trend.gramsChanged === 0
                ? t('body.trendSteady', { days: trend.days })
                : t(trend.gramsChanged < 0 ? 'body.trendDown' : 'body.trendUp', {
                    amount: show(Math.abs(trend.gramsChanged)),
                    days: trend.days,
                  })}
          </p>
          {target !== null && (
            <p className="text-xs text-muted-foreground">
              {t('weightWeb.toTarget', { amount: show(Math.abs(latest.grams - target)), target: show(target) })}
            </p>
          )}
          <WeightChart rows={rows} unit={unit} days={days} target={target} />
          <ToggleGroup
            type="single"
            value={String(days)}
            onValueChange={(value) => value && void settings.setString(healthKeys.trendDays, value)}
            aria-label={t('body.window')}
            className="self-start"
          >
            {trendWindows.map((window) => (
              <ToggleGroupItem key={window} value={String(window)}>
                {t('body.days', { count: window })}
              </ToggleGroupItem>
            ))}
          </ToggleGroup>
        </>
      )}
    </Card>
  );
}

/** Every reading, newest first, twenty of them (`_WeightRow`). */
function WeightHistory({ onEdit }: { onEdit: (weight: WeightRow) => void }) {
  const { t } = useTranslation();
  const { db, health } = useHarvest();
  const show = useWeightText();
  const rows = useLiveQuery(() => readWeights(db), [db]);
  const [removing, setRemoving] = useState<WeightRow | null>(null);
  if (!rows || rows.length === 0) return null;

  const remove = async (weight: WeightRow) => {
    await health.removeWeight(weight.uuid);
    toast(t('weightWeb.deleted'), {
      action: { label: t('common.undo'), onClick: () => void health.restoreWeight(weight.uuid) },
    });
  };

  return (
    <Card icon={<ScaleIcon />} title={t('weightWeb.history')}>
      <ul className="flex flex-col divide-y text-sm">
        {[...rows]
          .reverse()
          .slice(0, 20)
          .map((weight) => (
            <li key={weight.uuid} className="flex items-center gap-2 py-1.5">
              <div className="flex min-w-0 flex-1 flex-col">
                <span className="font-extrabold tabular">{show(weight.grams)}</span>
                <span className="truncate text-xs text-muted-foreground">
                  {[formatDay(weight.harvestDay), formatDate(weight.measuredAt, { timeStyle: 'short' }), weight.note]
                    .filter(Boolean)
                    .join(' · ')}
                </span>
              </div>
              <Button variant="ghost" size="icon" aria-label={t('weightWeb.editOf', { weight: show(weight.grams) })} onClick={() => onEdit(weight)}>
                <PencilIcon />
              </Button>
              <Button
                variant="ghost"
                size="icon"
                aria-label={t('weightWeb.deleteOf', { weight: show(weight.grams) })}
                onClick={() => setRemoving(weight)}
              >
                <Trash2Icon />
              </Button>
            </li>
          ))}
      </ul>
      <AlertDialog open={removing !== null} onOpenChange={(open) => !open && setRemoving(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>{t('weightWeb.deleteTitle')}</AlertDialogTitle>
            <AlertDialogDescription>{t('weightWeb.deleteBody')}</AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>{t('common.cancel')}</AlertDialogCancel>
            <AlertDialogAction
              destructive
              onClick={() => {
                if (removing) void remove(removing);
                setRemoving(null);
              }}
            >
              {t('common.delete')}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </Card>
  );
}

// ---------------------------------------------------------------- steps

/**
 * The goal and the stride: the two numbers about steps that are mine to
 * say (`_StepsSettingsSheet`). An empty goal is no goal. Meeting it is
 * paid by the phone, which is where the count is.
 */
function StepsSettingsDialog({ goal, stride, onClose }: { goal: number; stride: number; onClose: () => void }) {
  const { t } = useTranslation();
  const { settings } = useHarvest();
  const id = useId();
  const [goalText, setGoalText] = useState(goal > 0 ? String(goal) : '');
  const [strideText, setStrideText] = useState(String(stride));

  async function submit(event: FormEvent) {
    event.preventDefault();
    const nextGoal = Number.parseInt(goalText.trim(), 10);
    const nextStride = Number.parseInt(strideText.trim(), 10);
    const values: Record<string, string> = { [healthKeys.stepGoal]: String(Number.isFinite(nextGoal) && nextGoal > 0 ? nextGoal : 0) };
    if (Number.isFinite(nextStride) && nextStride > 0) values[healthKeys.strideCm] = String(clampStride(nextStride));
    await settings.setMany(values);
    onClose();
  }

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('stepsWeb.settings')}</DialogTitle>
          <DialogDescription className="sr-only">{t('stepsWeb.goalHint')}</DialogDescription>
        </DialogHeader>
        <form onSubmit={(event) => void submit(event)} className="flex flex-col gap-4" noValidate>
          <div className="flex flex-col gap-2">
            <Label htmlFor={`${id}-goal`}>{t('stepsWeb.goal')}</Label>
            <Input
              id={`${id}-goal`}
              inputMode="numeric"
              dir="ltr"
              value={goalText}
              placeholder={t('stepsWeb.noGoal')}
              aria-describedby={`${id}-goal-hint`}
              onChange={(event) => setGoalText(event.target.value.replace(/\D/g, ''))}
            />
            <span id={`${id}-goal-hint`} className="text-xs text-muted-foreground">
              {t('stepsWeb.goalHint')}
            </span>
          </div>
          <div className="flex flex-col gap-2">
            <Label htmlFor={`${id}-stride`}>{t('stepsWeb.stride')}</Label>
            <div className="flex items-center gap-2">
              <Input
                id={`${id}-stride`}
                inputMode="numeric"
                dir="ltr"
                value={strideText}
                aria-describedby={`${id}-stride-hint`}
                onChange={(event) => setStrideText(event.target.value.replace(/\D/g, ''))}
              />
              <span className="text-sm text-muted-foreground">{t('stepsWeb.cm')}</span>
            </div>
            <span id={`${id}-stride-hint`} className="text-xs text-muted-foreground">
              {t('stepsWeb.strideHint')}
            </span>
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={onClose}>
              {t('common.cancel')}
            </Button>
            <Button type="submit">{t('common.save')}</Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

/**
 * Today's steps, their distance, and how they sit against the goal
 * (`StepsCard`). The count itself is the phone's: a browser has no
 * step counter, and the card says where the number came from.
 */
function StepsCard() {
  const { t } = useTranslation();
  const { db } = useHarvest();
  const today = useHarvestDay();
  const distance = useDistance();
  const goal = stepGoalOf(useSetting(healthKeys.stepGoal));
  const stride = useStride();
  const [editing, setEditing] = useState(false);
  const rows = useLiveQuery(() => readSteps(db), [db]);
  if (!rows) return null;

  const steps = rows.find((row) => row.harvestDay === today.key)?.steps ?? 0;
  const weekFrom = today.addDays(-6).key;
  const average = averageSteps(rows.filter((row) => row.harvestDay >= weekFrom && row.harvestDay <= today.key));

  return (
    <Card
      icon={<FootprintsIcon />}
      title={t('stepsWeb.today')}
      action={
        <Button variant="ghost" size="icon" aria-label={t('stepsWeb.settings')} onClick={() => setEditing(true)}>
          <FlagIcon className={goal > 0 ? 'fill-current' : undefined} />
        </Button>
      }
    >
      <div className="flex flex-wrap items-end justify-between gap-x-4 gap-y-2">
        <div className="flex flex-wrap items-baseline gap-x-3">
          <span className="text-3xl font-extrabold tabular">{formatNumber(steps)}</span>
          <span className="text-sm font-extrabold text-primary">{distance(steps)}</span>
        </div>
        {average !== null && (
          <div className="flex flex-col items-end text-end">
            <span className="text-xs text-muted-foreground">{t('stepsWeb.weekAverage')}</span>
            <span className="font-bold tabular">{formatNumber(average)}</span>
            <span className="text-xs text-muted-foreground">{distance(average)}</span>
          </div>
        )}
      </div>
      {goal > 0 && (
        <>
          <Gauge ratio={steps / goal} label={t('stepsWeb.goal')} />
          <p className={steps >= goal ? 'text-xs font-bold text-primary' : 'text-xs text-muted-foreground'}>
            {steps >= goal ? t('stepsWeb.goalMet') : t('stepsWeb.ofGoal', { steps: formatNumber(steps), goal: formatNumber(goal) })}
          </p>
        </>
      )}
      <p className="flex items-center gap-2 text-xs text-muted-foreground">
        <SmartphoneIcon className="size-4 shrink-0" aria-hidden />
        {t('body.stepsSource')}
      </p>
      {editing && <StepsSettingsDialog goal={goal} stride={stride} onClose={() => setEditing(false)} />}
    </Card>
  );
}

/**
 * The last month of steps (`StepsHistory`): what it comes to, and a bar
 * a day for the last fourteen with the goal drawn dashed across them.
 */
function StepsHistoryCard() {
  const { t } = useTranslation();
  const { db } = useHarvest();
  const today = useHarvestDay();
  const distance = useDistance();
  const goal = stepGoalOf(useSetting(healthKeys.stepGoal));
  const rows = useLiveQuery(() => readSteps(db), [db]);
  if (!rows) return null;
  const history = stepsHistory(rows, today);

  if (history === null) {
    return (
      <Card icon={<FootprintsIcon />} title={t('stepsWeb.history')}>
        <p className="text-sm text-muted-foreground">{t('stepsWeb.noDays')}</p>
      </Card>
    );
  }

  const { total, average, best, bars } = history;
  const peak = Math.max(...bars.map((row) => row.steps), 0);
  const top = Math.max(peak, goal, 1) * 1.25;

  return (
    <Card icon={<FootprintsIcon />} title={t('stepsWeb.history')}>
      <span className="text-xs text-muted-foreground">{t('stepsWeb.lastDays', { count: 30 })}</span>
      <dl className="grid grid-cols-3 gap-2">
        <div className="flex flex-col">
          <dt className="order-2 truncate text-xs font-bold text-primary">{distance(total)}</dt>
          <dd className="text-xl font-extrabold tabular">{formatNumber(total)}</dd>
        </div>
        <div className="flex flex-col">
          <dt className="order-2 truncate text-xs text-muted-foreground">{t('stepsWeb.dailyAverage')}</dt>
          <dd className="text-lg font-extrabold tabular">{formatNumber(average)}</dd>
        </div>
        <div className="flex flex-col">
          <dt className="order-2 truncate text-xs text-muted-foreground">
            {t('stepsWeb.bestDay')} · {formatDay(best.harvestDay)}
          </dt>
          <dd className="text-lg font-extrabold tabular">{formatNumber(best.steps)}</dd>
        </div>
      </dl>
      <div className="relative h-36" role="img" aria-label={t('body.stepsChart', { count: bars.length })}>
        {goal > 0 && (
          <div
            className="pointer-events-none absolute inset-x-0 border-t-2 border-dashed border-sun"
            style={{ bottom: `${(goal / top) * 100}%` }}
            aria-hidden
          />
        )}
        <div className="flex h-full items-end gap-1">
          {bars.map((row) => (
            <div key={row.harvestDay} className="flex h-full flex-1 flex-col items-center justify-end gap-1">
              {row.steps > 0 && row.steps === peak && (
                <span className="text-[10px] font-extrabold tabular">{formatNumber(row.steps)}</span>
              )}
              <span
                title={`${formatDay(row.harvestDay)} · ${formatNumber(row.steps)} · ${distance(row.steps)}`}
                className={
                  goal > 0 && row.steps >= goal ? 'w-full max-w-3 rounded-t bg-primary' : 'w-full max-w-3 rounded-t bg-primary/45'
                }
                style={{ height: `${Math.max((row.steps / top) * 100, 1)}%` }}
              />
              <span className="text-[10px] text-muted-foreground">{formatDay(row.harvestDay, { weekday: 'narrow' })}</span>
            </div>
          ))}
        </div>
      </div>
    </Card>
  );
}

// ----------------------------------------------------------------- body

/** Sleep, steps and weight, in the phone's order (`HealthScreen`). */
function HealthPanel() {
  const unit = useWeightUnit();
  const [night, setNight] = useState<NightEditing>(null);
  const [weight, setWeight] = useState<{ row: WeightRow | null } | null>(null);
  return (
    <div className="flex flex-col gap-4">
      <SleepCard onLog={setNight} />
      <StepsCard />
      <WeightCard onLog={() => setWeight({ row: null })} />
      <WeightHistory onEdit={(row) => setWeight({ row })} />
      <StepsHistoryCard />
      <NightsCard onEdit={setNight} />
      {night && <SleepEditor key={night.night?.uuid ?? night.day.key} day={night.day} night={night.night} onClose={() => setNight(null)} />}
      {weight && <WeightEditor key={weight.row?.uuid ?? 'new'} weight={weight.row} unit={unit} onClose={() => setWeight(null)} />}
    </div>
  );
}

/**
 * The Body tab: sleep, weight and steps on one side, training on the
 * other — the phone's paired screen, as a tab row ([[Web]]). A half
 * that is switched off is not shown, and the tab row only appears when
 * both are on (`PairedScreen`).
 *
 * Nights and weights are written here as on the phone. Steps stay the
 * phone's: a browser has nothing to count them with.
 */
export function BodyScreen({ tab: initial = 'health' }: { tab?: 'health' | 'gym' } = {}) {
  const { t } = useTranslation();
  const switches = useFeatures();
  // `/app/body/gym` opens on the gym: where a program or a session leads back to.
  const [tab, setTab] = useState<string>(initial);
  // Followed from `/app/body` to `/app/body/gym` (or back) with this
  // screen still up: the path names the tab, not the last one shown.
  const [opened, setOpened] = useState(initial);
  if (opened !== initial) {
    setOpened(initial);
    setTab(initial);
  }
  if (!switches) return null;

  const halves = (['health', 'gym'] as const).filter((half) => switches[half]);
  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-2xl font-extrabold">{t('body.title')}</h1>
      {halves.length === 0 ? (
        <EmptyState
          icon={<SettingsIcon />}
          title={t('bodyWeb.offTitle')}
          body={t('bodyWeb.offBody')}
          action={
            <Button asChild variant="outline">
              <Link to="/app/settings">{t('bodyWeb.offAction')}</Link>
            </Button>
          }
        />
      ) : halves.length === 1 ? (
        halves[0] === 'health' ? (
          <HealthPanel />
        ) : (
          <GymPanel />
        )
      ) : (
        <Tabs value={tab} onValueChange={setTab}>
          <TabsList>
            <TabsTrigger value="health">{t('body.health')}</TabsTrigger>
            <TabsTrigger value="gym">{t('body.gym')}</TabsTrigger>
          </TabsList>
          <TabsContent value="health">
            <HealthPanel />
          </TabsContent>
          <TabsContent value="gym">
            <GymPanel />
          </TabsContent>
        </Tabs>
      )}
    </div>
  );
}
