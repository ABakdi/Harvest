import { weightToGrams } from '@harvest/core';
import { useId, useState, type FormEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { useHarvest } from '../context';
import { type WeightUnit, healthKeys, parseWeight, weightFieldValue } from '../data/health';
import { useBusy } from './use-busy';
import { runAction } from '@/lib/actions';

/**
 * The target weight (`showTargetWeightSheet`): a line on the chart and a
 * distance from it, set, changed or cleared here, in the unit on screen
 * ([[Health]], [[Audit-v3]] G5-05). Cleared is an empty value, which
 * both devices read as no target.
 */
export function TargetWeightDialog({ target, unit, onClose }: { target: number | null; unit: WeightUnit; onClose: () => void }) {
  const { t } = useTranslation();
  const { settings } = useHarvest();
  const id = useId();
  const [value, setValue] = useState(target === null ? '' : weightFieldValue(target, unit));
  const [saving, once] = useBusy();
  const entered = parseWeight(value);

  async function save(grams: number | null) {
    try {
      await settings.setString(healthKeys.targetGrams, grams === null ? '' : String(grams));
      onClose();
    } catch {
      toast.error(t('common.saveFailed'));
    }
  }

  function submit(event: FormEvent) {
    event.preventDefault();
    if (entered !== null) runAction(() => once(() => save(weightToGrams(unit, entered))));
  }

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('weightWeb.targetTitle')}</DialogTitle>
          <DialogDescription>{t('weightWeb.targetHint')}</DialogDescription>
        </DialogHeader>
        <form onSubmit={submit} className="flex flex-col gap-4" noValidate>
          <div className="flex flex-col gap-2">
            <Label htmlFor={`${id}-target`}>{t('weightWeb.target')}</Label>
            <div className="flex items-center gap-2">
              <Input
                id={`${id}-target`}
                autoFocus
                inputMode="decimal"
                dir="ltr"
                className="tabular"
                value={value}
                onChange={(event) => setValue(event.target.value)}
              />
              <span className="text-sm text-muted-foreground">{t(`body.unit.${unit}`)}</span>
            </div>
          </div>
          <DialogFooter className="gap-2">
            {target !== null && (
              <Button variant="ghost" className="text-destructive sm:me-auto" disabled={saving} onClick={() => runAction(() => once(() => save(null)))}>
                {t('weightWeb.targetClear')}
              </Button>
            )}
            <Button variant="outline" onClick={onClose}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" disabled={saving || entered === null}>
              {t('common.save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
