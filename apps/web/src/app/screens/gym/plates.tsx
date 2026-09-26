import { barIn, platesFor } from '@harvest/core';
import { InfoIcon } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { SetText, useLoad, useUnit, useUnitKnown } from './shared';

/**
 * What goes on each side of the bar (`plate_sheet.dart`): arithmetic
 * nobody should do tired, and the one place the app admits a target
 * cannot be made — a bar loads in pairs, so it comes back short and
 * says by how much rather than rounding up.
 *
 * Only ever opened for an exercise with a bar (Y9). In pounds it is a
 * pound gym: a 45 lb bar, 45 to 2.5 lb plates (Y8).
 */
export function PlatesDialog({ targetGrams, barGrams, onClose }: { targetGrams: number; barGrams: number; onClose: () => void }) {
  const { t } = useTranslation();
  const load = useLoad();
  const unit = useUnit();
  const known = useUnitKnown();
  const bar = barIn(barGrams, unit);
  const plan = platesFor(targetGrams, bar, unit);
  // Opened before the unit is read, it would draw kilograms for a frame
  // and then a different bar and plates.
  if (!known) return null;
  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-sm">
        <DialogHeader>
          <DialogTitle>{load(targetGrams)}</DialogTitle>
          <DialogDescription>{t('gym.perSide', { bar: load(bar) })}</DialogDescription>
        </DialogHeader>
        {plan.stacks.length === 0 ? (
          <p className="text-lg font-bold">{t('gym.justTheBar')}</p>
        ) : (
          <ul aria-label={t('gym.perSideList')} className="flex flex-wrap gap-2">
            {plan.stacks.map((stack) => (
              <li key={stack.grams} className="rounded-lg bg-secondary px-4 py-2 text-lg font-extrabold text-secondary-foreground tabular">
                <SetText>
                  {stack.perSide} × {load(stack.grams)}
                </SetText>
              </li>
            ))}
          </ul>
        )}
        {/* Lighter than the bar: it says by how much, rather than pretend. */}
        {plan.overGrams > 0 && (
          <p className="flex items-start gap-2 text-sm text-destructive">
            <InfoIcon className="mt-0.5 size-4 shrink-0" aria-hidden />
            {t('gym.barOver', { over: load(plan.overGrams) })}
          </p>
        )}
        {plan.shortfallGrams > 0 && (
          <p className="flex items-start gap-2 text-sm text-destructive">
            <InfoIcon className="mt-0.5 size-4 shrink-0" aria-hidden />
            {t('gym.plateShortfall', { total: load(plan.totalGrams), short: load(plan.shortfallGrams) })}
          </p>
        )}
      </DialogContent>
    </Dialog>
  );
}
