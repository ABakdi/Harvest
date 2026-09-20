import { type Cycle, cycleMinutes, decodeCycle, fallbackCycle, trendWindows, weightIn } from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import { BedIcon, FootprintsIcon, ScaleIcon, SmartphoneIcon } from 'lucide-react';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group';
import { formatDay, formatNumber } from '@/lib/format';
import { useHarvest, useHarvestDay } from '../context';
import { type StepRow, type WeightRow, readNights, readSteps, readWeights, sleepSummary, weightSummary } from '../data/health';
import { readSetting } from '../data/settings';
import { useSetting } from '../hooks';
import { GymPanel } from './gym';

/** `7h 20m`, from minutes. */
function useDuration() {
  const { t } = useTranslation();
  return (minutes: number) => t('body.duration', { hours: Math.trunc(minutes / 60), minutes: minutes % 60 });
}

/** The unit chosen on the phone; kilograms until it says otherwise. */
function useWeightUnit(): 'kg' | 'lb' {
  return useSetting('health.weightUnit') === 'lb' ? 'lb' : 'kg';
}

function Card({ icon, title, children }: { icon: React.ReactNode; title: string; children: React.ReactNode }) {
  return (
    <section className="flex flex-col gap-3 rounded-2xl border bg-card p-5">
      <h2 className="flex items-center gap-2 text-lg font-extrabold">
        <span className="text-primary [&_svg]:size-5">{icon}</span>
        {title}
      </h2>
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

/**
 * Sleep, as the phone shows it: last night, what is owed over the last
 * fourteen, and the average. Nights are written on the phone — there is
 * no editor here, because a night is written from bed ([[Health]]).
 */
function SleepCard() {
  const { t } = useTranslation();
  const duration = useDuration();
  const { db } = useHarvest();
  const data = useLiveQuery(async () => {
    const [rows, bed, wake] = await Promise.all([
      readNights(db),
      readSetting(db, 'cycle.bedTime'),
      readSetting(db, 'cycle.wakeTime'),
    ]);
    const cycle: Cycle = decodeCycle(bed && wake ? `${bed}-${wake}` : null) ?? fallbackCycle;
    return { rows, summary: sleepSummary(rows, cycleMinutes(cycle)) };
  }, [db]);
  if (!data) return null;

  const { rows, summary } = data;
  if (rows.length === 0) {
    return (
      <Card icon={<BedIcon />} title={t('body.sleepTitle')}>
        <p className="text-sm text-muted-foreground">{t('body.noNights')}</p>
      </Card>
    );
  }

  const slept = summary.last
    ? Math.round((Date.parse(summary.last.wokeAt) - Date.parse(summary.last.fellAsleepAt)) / 60_000)
    : 0;

  return (
    <Card icon={<BedIcon />} title={t('body.sleepTitle')}>
      <div className="flex flex-wrap items-baseline gap-x-4 gap-y-1">
        <span className="text-3xl font-extrabold tabular">{duration(slept)}</span>
        <span className="text-sm text-muted-foreground">
          {summary.last ? t('body.nightOf', { day: formatDay(summary.last.harvestDay) }) : ''}
        </span>
      </div>
      <div className="flex flex-col gap-1">
        <div className="flex items-baseline justify-between text-sm">
          <span className="text-muted-foreground">{t('body.debt')}</span>
          <span className="font-extrabold tabular">{duration(summary.debt.minutes)}</span>
        </div>
        {/* Fourteen nights is the window, so a debt of four nights is a full gauge. */}
        <Gauge ratio={summary.debt.nights / 4} label={t('body.debt')} />
        <p className="text-xs text-muted-foreground">{t('body.debtBody')}</p>
      </div>
      <p className="text-sm text-muted-foreground">
        {t('body.average')}: <span className="font-extrabold tabular text-foreground">{duration(summary.averageMinutes)}</span>
      </p>
      <ul className="flex flex-col divide-y text-sm">
        {rows.slice(0, 7).map((night) => (
          <li key={night.uuid} className="flex items-center justify-between gap-2 py-1.5">
            <span className="text-muted-foreground">{formatDay(night.harvestDay)}</span>
            <span className="flex items-center gap-2">
              {night.restedStars !== null && (
                <span className="text-sun" aria-label={t('body.stars', { count: night.restedStars })}>
                  {'★'.repeat(night.restedStars)}
                </span>
              )}
              <span className="font-extrabold tabular">
                {duration(Math.round((Date.parse(night.wokeAt) - Date.parse(night.fellAsleepAt)) / 60_000))}
              </span>
            </span>
          </li>
        ))}
      </ul>
    </Card>
  );
}

/** Every entry as a dot, the seven-day average as the line ([[Health]] H5). */
function WeightChart({ rows, unit, days }: { rows: WeightRow[]; unit: 'kg' | 'lb'; days: number }) {
  const { t } = useTranslation();
  const { points } = weightSummary(rows, days);
  const shown = points.slice(-days);
  const values = shown.flatMap((point) => [point.entry, point.average].filter((value): value is number => value !== null));
  if (shown.length < 2 || values.length === 0) return null;

  const low = Math.min(...values);
  const high = Math.max(...values);
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
      {shown.map((point, index) =>
        point.entry === null ? null : (
          <circle key={point.day} cx={x(index)} cy={y(point.entry)} r={2.5} className="fill-muted-foreground/60" />
        ),
      )}
      {line && <polyline points={line} fill="none" strokeWidth={2.5} className="stroke-primary" vectorEffect="non-scaling-stroke" />}
    </svg>
  );
}

function WeightCard() {
  const { t } = useTranslation();
  const { db } = useHarvest();
  const unit = useWeightUnit();
  const stored = Number(useSetting('health.trendDays') ?? 30);
  const [days, setDays] = useState(trendWindows.includes(stored as 30) ? stored : 30);
  const rows = useLiveQuery(() => readWeights(db), [db]);
  if (!rows) return null;

  const { latest, trend } = weightSummary(rows, days);
  const show = (grams: number) => `${formatNumber(weightIn(unit, grams), { maximumFractionDigits: 1 })} ${t(`body.unit.${unit}`)}`;

  return (
    <Card icon={<ScaleIcon />} title={t('body.weightTitle')}>
      {latest === null ? (
        <p className="text-sm text-muted-foreground">{t('body.noWeights')}</p>
      ) : (
        <>
          <div className="flex flex-wrap items-baseline gap-x-4 gap-y-1">
            <span className="text-3xl font-extrabold tabular">{show(latest.grams)}</span>
            <span className="text-sm text-muted-foreground">{formatDay(latest.harvestDay)}</span>
          </div>
          <ToggleGroup
            type="single"
            value={String(days)}
            onValueChange={(value) => value && setDays(Number(value))}
            aria-label={t('body.window')}
            className="self-start"
          >
            {trendWindows.map((window) => (
              <ToggleGroupItem key={window} value={String(window)}>
                {t('body.days', { count: window })}
              </ToggleGroupItem>
            ))}
          </ToggleGroup>
          <WeightChart rows={rows} unit={unit} days={days} />
          {/* The direction, never a judgement on it ([[Health]] H5). */}
          <p className="text-sm text-muted-foreground">
            {trend === null
              ? t('body.noTrend')
              : trend.gramsChanged === 0
                ? t('body.trendSteady', { days: trend.days })
                : t(trend.gramsChanged < 0 ? 'body.trendDown' : 'body.trendUp', {
                    amount: show(Math.abs(trend.gramsChanged)),
                    days: trend.days,
                  })}
          </p>
        </>
      )}
    </Card>
  );
}

/** The last thirty days as bars, today first in the numbers above them. */
function StepsCard() {
  const { t } = useTranslation();
  const { db } = useHarvest();
  const today = useHarvestDay();
  const goal = Number(useSetting('health.stepGoal') ?? 10000) || 10000;
  const rows = useLiveQuery(() => readSteps(db), [db]);
  if (!rows) return null;

  const recent: StepRow[] = rows.slice(-30);
  const todayRow = rows.find((row) => row.harvestDay === today.key);
  const steps = todayRow?.steps ?? 0;
  const most = Math.max(goal, ...recent.map((row) => row.steps), 1);

  return (
    <Card icon={<FootprintsIcon />} title={t('body.stepsTitle')}>
      <div className="flex flex-wrap items-baseline gap-x-4 gap-y-1">
        <span className="text-3xl font-extrabold tabular">{formatNumber(steps)}</span>
        <span className="text-sm text-muted-foreground">{t('body.ofGoal', { goal: formatNumber(goal) })}</span>
      </div>
      <Gauge ratio={steps / goal} label={t('body.stepsTitle')} />
      {recent.length > 1 && (
        <div className="flex h-20 items-end gap-0.5" role="img" aria-label={t('body.stepsChart', { count: recent.length })}>
          {recent.map((row) => (
            <span
              key={row.harvestDay}
              title={`${formatDay(row.harvestDay)} · ${formatNumber(row.steps)}`}
              className={row.steps >= goal ? 'flex-1 rounded-t bg-primary' : 'flex-1 rounded-t bg-muted-foreground/30'}
              style={{ height: `${Math.max((row.steps / most) * 100, 2)}%` }}
            />
          ))}
        </div>
      )}
      <p className="flex items-center gap-2 text-xs text-muted-foreground">
        <SmartphoneIcon className="size-4" aria-hidden />
        {t('body.stepsSource')}
      </p>
    </Card>
  );
}

/**
 * The Body tab: sleep, weight and steps on one side, training on the
 * other — the phone's paired screen, as a tab row ([[Web]]).
 *
 * Everything here is a view. Sleep is written from bed, a weight from
 * the scale and a session from the gym floor, all of which are places
 * the phone is and the laptop is not.
 */
export function BodyScreen() {
  const { t } = useTranslation();
  const [tab, setTab] = useState('health');
  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-2xl font-extrabold">{t('body.title')}</h1>
      <Tabs value={tab} onValueChange={setTab}>
        <TabsList>
          <TabsTrigger value="health">{t('body.health')}</TabsTrigger>
          <TabsTrigger value="gym">{t('body.gym')}</TabsTrigger>
        </TabsList>
        <TabsContent value="health" className="flex flex-col gap-4">
          <SleepCard />
          <WeightCard />
          <StepsCard />
        </TabsContent>
        <TabsContent value="gym">
          <GymPanel />
        </TabsContent>
      </Tabs>
    </div>
  );
}
