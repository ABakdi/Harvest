import { formatClock, parseClock, type Clock } from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import { DumbbellIcon, FileTextIcon, HeartPulseIcon, ImagesIcon, ListChecksIcon, MapIcon, MinusIcon, PlusIcon, type LucideIcon } from 'lucide-react';
import { useId, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { Button } from '@/components/ui/button';
import { Label } from '@/components/ui/label';
import { Switch } from '@/components/ui/switch';
import { formatDate } from '@/lib/format';
import { useHarvest } from '../context';
import { type Feature, type FeatureSwitches, features, readFeatures } from '../data/settings';

const allOff: FeatureSwitches = { notes: false, gallery: false, health: false, gym: false, places: false, lists: false };

/**
 * Which optional features are on, live (`featureSwitchesProvider`).
 * Undefined while it is read, so a tab never flickers out and back in.
 */
export function useFeatures(): FeatureSwitches | undefined {
  const { db } = useHarvest();
  return useLiveQuery(() => readFeatures(db), [db]);
}

/** The switches, read as off until they have been read at all. */
export function useFeaturesOrOff(): FeatureSwitches {
  return useFeatures() ?? allOff;
}

const featureIcons: Record<Feature, LucideIcon> = {
  notes: FileTextIcon,
  gallery: ImagesIcon,
  health: HeartPulseIcon,
  gym: DumbbellIcon,
  places: MapIcon,
  lists: ListChecksIcon,
};

/**
 * The six switches, as the Extras card and the last onboarding page
 * both show them: a name, what it is, and a switch that hides a tab
 * and never deletes a thing (N1, G1, H1, Y1, PL1).
 */
export function FeatureSwitchList({
  values,
  onChange,
}: {
  values: FeatureSwitches;
  onChange: (feature: Feature, on: boolean) => void;
}) {
  const { t } = useTranslation();
  const id = useId();
  return (
    <ul className="flex flex-col divide-y">
      {features.map((feature) => {
        const Icon = featureIcons[feature];
        return (
          <li key={feature} className="flex items-start gap-3 py-3 first:pt-0 last:pb-0">
            <Icon className="mt-0.5 size-5 shrink-0 text-muted-foreground" aria-hidden />
            <div className="flex min-w-0 flex-1 flex-col">
              <Label htmlFor={`${id}-${feature}`}>{t(`settingsWeb.feature.${feature}`)}</Label>
              <span id={`${id}-${feature}-hint`} className="text-xs text-muted-foreground">
                {t(`settingsWeb.feature.${feature}Hint`)}
              </span>
            </div>
            <Switch
              id={`${id}-${feature}`}
              checked={values[feature]}
              aria-describedby={`${id}-${feature}-hint`}
              onCheckedChange={(on) => onChange(feature, on)}
            />
          </li>
        );
      })}
    </ul>
  );
}

/** A minus and a plus with a bounded value between them (`_Stepper`). */
export function Stepper({
  value,
  min,
  max,
  step = 1,
  label,
  disabled = false,
  onChange,
}: {
  value: number;
  min: number;
  max: number;
  step?: number;
  /** What is being changed, for the two buttons' names. */
  label: string;
  /** While the stored value is still loading: a step from the fallback would overwrite it. */
  disabled?: boolean;
  onChange: (next: number) => void;
}) {
  const { t } = useTranslation();
  return (
    <div className="flex items-center gap-1">
      <Button
        variant="secondary"
        size="icon"
        aria-label={t('settingsWeb.less', { what: label })}
        disabled={disabled || value <= min}
        onClick={() => onChange(Math.max(min, value - step))}
      >
        <MinusIcon />
      </Button>
      <Button
        variant="secondary"
        size="icon"
        aria-label={t('settingsWeb.more', { what: label })}
        disabled={disabled || value >= max}
        onClick={() => onChange(Math.min(max, value + step))}
      >
        <PlusIcon />
      </Button>
    </div>
  );
}

/** `23:30` or `11:30 PM`, as the language writes a time. */
export function clockLabel(clock: Clock): string {
  return formatDate(new Date(2000, 0, 1, clock.hour, clock.minute), { timeStyle: 'short' });
}

/**
 * A time of day, kept to itself until it is left or entered, so a half
 * typed `2` on the way to `23:30` is never saved as two in the morning.
 */
export function ClockInput({
  id,
  value,
  onCommit,
  className,
  'aria-label': ariaLabel,
}: {
  id?: string;
  value: Clock;
  onCommit: (clock: Clock) => void;
  className?: string;
  'aria-label'?: string;
}) {
  const commit = (raw: string) => {
    const clock = parseClock(raw);
    if (clock && formatClock(clock) !== formatClock(value)) onCommit(clock);
  };
  return (
    <input
      id={id}
      key={formatClock(value)}
      type="time"
      dir="ltr"
      aria-label={ariaLabel}
      defaultValue={formatClock(value)}
      onBlur={(event) => commit(event.target.value)}
      onKeyDown={(event) => {
        if (event.key === 'Enter') commit(event.currentTarget.value);
      }}
      className={
        className ??
        'h-9 rounded-md border bg-transparent px-3 text-sm font-bold tabular outline-none focus-visible:ring-2 focus-visible:ring-ring'
      }
    />
  );
}

export function SettingsSection({ title, children, id, lead }: { title: string; children: ReactNode; id: string; lead?: string }) {
  return (
    <section aria-labelledby={id} className="flex flex-col gap-4 rounded-2xl border bg-card p-5">
      <div className="flex flex-col gap-1">
        <h2 id={id} className="text-lg font-extrabold">
          {title}
        </h2>
        {lead && <p className="text-sm text-muted-foreground">{lead}</p>}
      </div>
      {children}
    </section>
  );
}

export function SettingsRow({
  label,
  hint,
  children,
  htmlFor,
}: {
  label: string;
  hint?: string | undefined;
  children: ReactNode;
  htmlFor?: string;
}) {
  return (
    <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
      <div className="flex flex-col">
        <Label htmlFor={htmlFor}>{label}</Label>
        {hint && <span className="text-xs text-muted-foreground">{hint}</span>}
      </div>
      {children}
    </div>
  );
}
