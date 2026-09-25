import { weightToGrams } from '@harvest/core';
import { useId, useState, type FormEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group';
import { useHarvest } from '../context';
import { type WeightRow, type WeightUnit, healthKeys, parseWeight, weightFieldValue } from '../data/health';
import { useBusy } from './use-busy';

/**
 * One number off the scale (`showWeightSheet`), in grams underneath
 * whatever the field is labelled with ([[Health]] H4). The first
 * weigh-in of a day pays +5 XP; a second is a second fact, not a
 * second payment.
 */
export function WeightEditor({ weight, unit, onClose }: { weight: WeightRow | null; unit: WeightUnit; onClose: () => void }) {
  const { t } = useTranslation();
  const { health, settings } = useHarvest();
  const id = useId();
  // What the field was filled with, to tell a note-only edit apart from
  // a new number: coming back to add a note must not re-save 82.46 kg
  // through the field's rounding as 82.5 ([[Audit-v2]] U3-19). The
  // unit it was filled in counts too: the same 82.5 read as pounds is a
  // new number.
  const [prefilled] = useState(() => ({ text: weight ? weightFieldValue(weight.grams, unit) : '', unit }));
  const [value, setValue] = useState(prefilled.text);
  const [note, setNote] = useState(weight?.note ?? '');
  const [saving, once] = useBusy();
  const entered = parseWeight(value);

  async function save() {
    if (entered === null) return;
    const unchanged = weight !== null && value.trim() === prefilled.text && unit === prefilled.unit;
    const grams = unchanged ? weight.grams : weightToGrams(unit, entered);
    try {
      if (weight) await health.updateWeight(weight.uuid, { grams, note });
      else await health.logWeight({ grams, note });
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
          <DialogTitle>{weight ? t('weightWeb.edit') : t('weightWeb.log')}</DialogTitle>
          <DialogDescription>{t('weightWeb.lead')}</DialogDescription>
        </DialogHeader>
        <form onSubmit={submit} className="flex flex-col gap-4" noValidate>
          <div className="flex items-end gap-2">
            <div className="flex flex-1 flex-col gap-2">
              <Label htmlFor={`${id}-value`}>{t('weightWeb.label', { unit: t(`body.unit.${unit}`) })}</Label>
              <Input
                id={`${id}-value`}
                autoFocus
                inputMode="decimal"
                dir="ltr"
                className="text-lg font-extrabold tabular"
                value={value}
                aria-invalid={value.trim() !== '' && entered === null ? true : undefined}
                onChange={(event) => setValue(event.target.value)}
              />
            </div>
            {/* Changing units re-reads the same number, it does not
                convert what I typed: the scale said what it said. */}
            <ToggleGroup
              type="single"
              value={unit}
              aria-label={t('weightWeb.unit')}
              onValueChange={(next) => next && void settings.setString(healthKeys.weightUnit, next)}
            >
              <ToggleGroupItem value="kg">{t('body.unit.kg')}</ToggleGroupItem>
              <ToggleGroupItem value="lb">{t('body.unit.lb')}</ToggleGroupItem>
            </ToggleGroup>
          </div>
          <div className="flex flex-col gap-2">
            <Label htmlFor={`${id}-note`}>{t('weightWeb.note')}</Label>
            <Input
              id={`${id}-note`}
              maxLength={200}
              value={note}
              placeholder={t('weightWeb.noteHint')}
              onChange={(event) => setNote(event.target.value)}
            />
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={onClose}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" disabled={entered === null || saving}>
              {t('common.save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
