import {
  formatPercentTenths,
  restChoices,
  storedLabelGrams,
  weightIn,
  type TargetSetLike,
} from '@harvest/core';
import { useId, useState, type ReactNode } from 'react';
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
import { formatNumber } from '@/lib/format';
import { cn } from '@/lib/utils';
import { healthKeys, type WeightUnit } from '../../data/health';
import { useSetting } from '../../hooks';

/** The unit the phone was set to: there is no separate one for the gym. */
export function useUnit(): WeightUnit {
  return useSetting(healthKeys.weightUnit) === 'lb' ? 'lb' : 'kg';
}

/** Whether the unit has been read yet: a sheet of numbers waits for it rather than flash kilograms. */
export function useUnitKnown(): boolean {
  return useSetting(healthKeys.weightUnit) !== undefined;
}

/** `82.5 kg`: trailing zeros dropped, the unit written in the language on screen. */
export function useLoad(): (grams: number) => string {
  const { t } = useTranslation();
  const unit = useUnit();
  return (grams: number) => `${formatNumber(weightIn(unit, grams), { maximumFractionDigits: 2 })} ${t(`body.unit.${unit}`)}`;
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
      <DialogContent className="max-w-sm">
        <DialogHeader>
          <DialogTitle>{ask.title}</DialogTitle>
          {ask.body ? <DialogDescription>{ask.body}</DialogDescription> : <DialogDescription className="sr-only">{ask.label}</DialogDescription>}
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
