import {
  formatPercentTenths,
  loadFieldValue,
  restChoices,
  roundLoad,
  storedLabelGrams,
  weightIn,
  type TargetSetLike,
} from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import { Fragment, useId, useState, type ReactNode } from 'react';
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
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group';
import { formatNumber } from '@/lib/format';
import { cn } from '@/lib/utils';
import { useHarvest } from '../../context';
import { healthKeys, type WeightUnit } from '../../data/health';
import type { HarvestDB } from '../../data/db';
import { readSetting } from '../../data/settings';

/**
 * The unit as last read, per store: a dialog opened after the screen
 * has read it starts with it rather than read it again from nothing,
 * which drew kilograms for a moment under every freshly opened field.
 */
const lastUnit = new WeakMap<HarvestDB, string | null>();

function useUnitSetting(): string | null | undefined {
  const { db } = useHarvest();
  const value = useLiveQuery(() => readSetting(db, healthKeys.weightUnit), [db], lastUnit.get(db));
  if (value !== undefined) lastUnit.set(db, value);
  return value;
}

/** The unit the phone was set to: there is no separate one for the gym. */
export function useUnit(): WeightUnit {
  return useUnitSetting() === 'lb' ? 'lb' : 'kg';
}

/**
 * The unit, switched from the gym itself: the same `health.weightUnit`
 * the body weight reads, because nobody weighs themselves in kilos and
 * lifts in pounds ([[Gym]] Y8). Stored loads stay grams; only how they
 * read changes.
 */
export function UnitToggle({ className }: { className?: string }) {
  const { t } = useTranslation();
  const { settings } = useHarvest();
  const unit = useUnit();
  const id = useId();
  return (
    <div className={cn('flex items-center gap-2', className)}>
      <span id={id} className="text-sm font-bold text-muted-foreground">
        {t('gymWeb.unit')}
      </span>
      <ToggleGroup
        type="single"
        value={unit}
        aria-labelledby={id}
        aria-describedby={`${id}-hint`}
        onValueChange={(next) => next && void settings.setString(healthKeys.weightUnit, next)}
      >
        <ToggleGroupItem value="kg">{t('body.unit.kg')}</ToggleGroupItem>
        <ToggleGroupItem value="lb">{t('body.unit.lb')}</ToggleGroupItem>
      </ToggleGroup>
      <span id={`${id}-hint`} className="sr-only">
        {t('gymWeb.unitHint')}
      </span>
    </div>
  );
}

/** Whether the unit has been read yet: a sheet of numbers waits for it rather than flash kilograms. */
export function useUnitKnown(): boolean {
  return useUnitSetting() !== undefined;
}

/**
 * A load as it reads in [unit] (Y8): pounds to the quarter pound, the
 * way a pound gym loads a bar, so 60 kg set in kilos reads 132.25 lb
 * and not 132.28, and 135 lb stored from kilos reads 135. Kilos are
 * shown as stored — they were rounded when they were set.
 */
export function shownGrams(grams: number, unit: WeightUnit): number {
  return unit === 'lb' ? roundLoad(grams, 'lb') : grams;
}

/** A load as it goes into a field (`loadFieldValue`), rounded like it reads. */
export function loadField(grams: number, unit: WeightUnit): string {
  return loadFieldValue(shownGrams(grams, unit), unit);
}

/**
 * A field seeded from what is stored, in the unit on screen (Y8). The
 * unit is a setting read a moment after the field mounts, so a field
 * nobody has typed in is re-seeded when the unit arrives or changes: 60 kg
 * must never sit under an lb label as "60" and be saved back as 60 lb.
 * `set(text, false)` puts text in without counting it as typing (the
 * field showing what was kept after a save).
 */
export function useSeededField(seed: (unit: WeightUnit) => string): [string, (text: string, typed?: boolean) => void] {
  const unit = useUnit();
  const [field, setField] = useState(() => ({ text: seed(unit), unit, typed: false }));
  if (!field.typed && field.unit !== unit) setField({ text: seed(unit), unit, typed: false });
  const text = !field.typed && field.unit !== unit ? seed(unit) : field.text;
  return [text, (next, typed = true) => setField({ text: next, unit, typed })];
}

/** `82.5 kg`: trailing zeros dropped, the unit written in the language on screen. */
export function useLoad(): (grams: number) => string {
  const { t } = useTranslation();
  const unit = useUnit();
  return (grams: number) => `${formatNumber(weightIn(unit, shownGrams(grams, unit)), { maximumFractionDigits: 2 })} ${t(`body.unit.${unit}`)}`;
}

/**
 * A session's volume in the unit on screen, added up from the loads as
 * the rows show them (`shownVolume`): in pounds each done set's load is
 * rounded to its quarter first, so five sets of 132.25 lb come to
 * 661.25 lb and not the 661.5 lb the stored grams round to (Y8).
 */
export function shownVolume(sets: Iterable<{ done: boolean; weightGrams: number; reps: number }>, unit: WeightUnit): number {
  let total = 0;
  for (const set of sets) {
    if (!set.done) continue;
    // Exact quarters, not the grams of one: those read back a hair under.
    const load = unit === 'lb' ? Math.round(weightIn('lb', set.weightGrams) * 4) / 4 : weightIn(unit, set.weightGrams);
    total += load * set.reps;
  }
  return total;
}

/** [shownVolume] as text: `661.25 lb`. */
export function useVolume(): (sets: Iterable<{ done: boolean; weightGrams: number; reps: number }>) => string {
  const { t } = useTranslation();
  const unit = useUnit();
  return (sets) => `${formatNumber(shownVolume(sets, unit), { maximumFractionDigits: 2 })} ${t(`body.unit.${unit}`)}`;
}

/**
 * What one target set asks for, in the fewest words that are true
 * (`targetLabel`): a percentage with no training max shows the
 * percentage, because "75% × 5" is a real instruction.
 */
export function useTargetText(): (set: TargetSetLike, grams: number | null) => string {
  const { t } = useTranslation();
  const load = useLoad();
  return (set, grams) => {
    const reps = set.openEnded ? t('gym.openReps', { reps: set.reps ?? 1 }) : String(set.reps ?? 1);
    const weight = grams !== null ? load(grams) : set.percentTenths !== null ? formatPercentTenths(set.percentTenths) : null;
    return weight === null ? `× ${reps}` : `${weight} × ${reps}`;
  };
}

/**
 * One set as it reads — `132.25 lb × 5` — kept whole and left to right:
 * inside Arabic, a bare label is reordered by the text around it
 * (`رطل×5 132.25`) and breaks mid-set on a narrow screen.
 */
export function SetText({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <bdi dir="ltr" className={cn('whitespace-nowrap', className)}>
      {children}
    </bdi>
  );
}

/** Sets side by side, each one whole, the line free to break only between them. */
export function SetList({ labels, separator = '  ' }: { labels: ReactNode[]; separator?: string }) {
  return (
    <>
      {labels.map((label, index) => (
        <Fragment key={index}>
          {index > 0 && separator}
          <SetText>{label}</SetText>
        </Fragment>
      ))}
    </>
  );
}

/** A translated sentence with [inner] drawn where its placeholder was: `Last time: …` around sets kept whole. */
export function around(sentence: (placeholder: string) => string, inner: ReactNode): ReactNode {
  const marker = '\u2063';
  const [before, ...after] = sentence(marker).split(marker);
  return (
    <>
      {before}
      {inner}
      {after.join('')}
    </>
  );
}

/**
 * `83.25×5` from a session's stored label, in the unit on screen and
 * without the `.00` it is stored with; any other label as it is. Read
 * back in the unit on screen, so 135 lb stored as `61.23` is 135 (Y8).
 */
export function prettyStoredLabel(label: string, unit: WeightUnit): string {
  const grams = storedLabelGrams(label, unit);
  if (grams === null) return label;
  return `${formatNumber(weightIn(unit, grams), { maximumFractionDigits: 2 })}×${label.split('×').at(-1) ?? ''}`;
}

/** `1:05`, minutes and seconds, for the clock and the rest. */
export function clockText(seconds: number): string {
  const whole = Math.max(0, Math.floor(seconds));
  return `${Math.floor(whole / 60)}:${String(whole % 60).padStart(2, '0')}`;
}

/**
 * The session clock (`formatSessionClock`): `4:05`, and `1:04:05` past
 * the hour — minutes alone read a session left open for days as
 * `15977:10`.
 */
export function sessionClockText(seconds: number): string {
  const whole = Math.max(0, Math.floor(seconds));
  const hours = Math.floor(whole / 3600);
  const minutes = Math.floor((whole % 3600) / 60);
  const rest = String(whole % 60).padStart(2, '0');
  return hours === 0 ? `${minutes}:${rest}` : `${hours}:${String(minutes).padStart(2, '0')}:${rest}`;
}

// ------------------------------------------------------------------ asking

interface ConfirmAsk {
  kind: 'confirm';
  title: string;
  body?: string;
  action: string;
  destructive?: boolean;
  resolve: (ok: boolean) => void;
}

interface PromptAsk {
  kind: 'prompt';
  title: string;
  body?: string;
  label: string;
  initial?: string;
  placeholder?: string;
  action?: string;
  /** Whether an empty answer is still an answer (a skip with no reason). */
  allowEmpty?: boolean;
  inputMode?: 'text' | 'decimal';
  resolve: (text: string | null) => void;
}

type Ask = ConfirmAsk | PromptAsk;

export interface Asker {
  confirm: (ask: Omit<ConfirmAsk, 'kind' | 'resolve'>) => Promise<boolean>;
  prompt: (ask: Omit<PromptAsk, 'kind' | 'resolve'>) => Promise<string | null>;
}

/**
 * Questions as promises, so a flow that asks twice — discarding a
 * session with sets in it — reads top to bottom. Render the element
 * the hook returns once, anywhere in the screen.
 */
export function useAsker(): [Asker, ReactNode] {
  const [ask, setAsk] = useState<Ask | null>(null);
  const [asker] = useState<Asker>(() => ({
    confirm: (input) => new Promise((resolve) => setAsk({ ...input, kind: 'confirm', resolve })),
    prompt: (input) => new Promise((resolve) => setAsk({ ...input, kind: 'prompt', resolve })),
  }));
  const close = () => setAsk(null);
  const element =
    ask === null ? null : ask.kind === 'confirm' ? (
      <ConfirmView ask={ask} onClose={close} />
    ) : (
      <PromptView key={ask.title} ask={ask} onClose={close} />
    );
  return [asker, element];
}

function ConfirmView({ ask, onClose }: { ask: ConfirmAsk; onClose: () => void }) {
  const { t } = useTranslation();
  return (
    <AlertDialog
      open
      onOpenChange={(open) => {
        if (!open) {
          ask.resolve(false);
          onClose();
        }
      }}
    >
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>{ask.title}</AlertDialogTitle>
          {ask.body && <AlertDialogDescription>{ask.body}</AlertDialogDescription>}
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel>{t('common.cancel')}</AlertDialogCancel>
          <AlertDialogAction
            destructive={ask.destructive ?? false}
            onClick={() => {
              ask.resolve(true);
              onClose();
            }}
          >
            {ask.action}
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}

function PromptView({ ask, onClose }: { ask: PromptAsk; onClose: () => void }) {
  const { t } = useTranslation();
  const id = useId();
  const [text, setText] = useState(ask.initial ?? '');
  const valid = ask.allowEmpty || text.trim().length > 0;
  const finish = (value: string | null) => {
    ask.resolve(value);
    onClose();
  };
  return (
    <Dialog open onOpenChange={(open) => !open && finish(null)}>
      {/* No body, no description: the field's own label already says it, and saying it twice helps nobody. */}
      <DialogContent className="max-w-sm" {...(ask.body ? {} : { 'aria-describedby': undefined })}>
        <DialogHeader>
          <DialogTitle>{ask.title}</DialogTitle>
          {ask.body && <DialogDescription>{ask.body}</DialogDescription>}
        </DialogHeader>
        <form
          className="flex flex-col gap-3"
          onSubmit={(event) => {
            event.preventDefault();
            if (valid) finish(text);
          }}
        >
          <Label htmlFor={id}>{ask.label}</Label>
          <Input
            id={id}
            autoFocus
            value={text}
            inputMode={ask.inputMode}
            placeholder={ask.placeholder}
            onChange={(event) => setText(event.target.value)}
          />
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => finish(null)}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" disabled={!valid}>
              {ask.action ?? t('common.save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

// -------------------------------------------------------------------- rest

/**
 * The rest between sets: the six usual answers as one click each, and a
 * box for the seventh, in seconds, committed with Enter or on leaving
 * the box (`RestField`).
 */
export function RestField({ seconds, onChange }: { seconds: number | null; onChange: (seconds: number) => void }) {
  const { t } = useTranslation();
  const id = useId();
  const custom = seconds !== null && !restChoices.includes(seconds);
  const [typed, setTyped] = useState(custom ? String(seconds) : '');
  const [shown, setShown] = useState(seconds);
  if (shown !== seconds) {
    setShown(seconds);
    setTyped(custom ? String(seconds) : '');
  }
  const commit = () => {
    const value = Number(typed.trim());
    if (Number.isInteger(value) && value > 0 && value !== seconds) onChange(value);
  };
  return (
    <div className="flex flex-col gap-2">
      <div role="group" aria-label={t('gym.rest')} className="flex flex-wrap gap-1.5">
        {restChoices.map((choice) => (
          <Button
            key={choice}
            type="button"
            size="sm"
            variant={seconds === choice ? 'default' : 'outline'}
            aria-pressed={seconds === choice}
            onClick={() => onChange(choice)}
          >
            {t('gym.restSeconds', { count: choice })}
          </Button>
        ))}
      </div>
      <div className="flex items-center gap-2">
        <Label htmlFor={id} className="text-xs font-normal text-muted-foreground">
          {t('gym.restCustom')}
        </Label>
        <Input
          id={id}
          inputMode="numeric"
          className={cn('h-8 w-24 text-center', custom && 'border-primary')}
          placeholder={t('gym.restCustomHint')}
          value={typed}
          onChange={(event) => setTyped(event.target.value.replace(/\D/g, ''))}
          onBlur={commit}
          onKeyDown={(event) => {
            if (event.key === 'Enter') {
              event.preventDefault();
              commit();
            }
          }}
        />
        <span className="text-xs text-muted-foreground">{t('gym.secondsShort')}</span>
      </div>
    </div>
  );
}
