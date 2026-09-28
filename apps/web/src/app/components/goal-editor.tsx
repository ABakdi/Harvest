import { useId, useState, type FormEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { useHarvest, useHarvestDay } from '../context';
import type { GoalRow } from '../data/goals';
import { useBusy } from './use-busy';
import { runAction } from '@/lib/actions';

/** A goal is a title, a *why* and an optional target day; nothing more ([[Goals]]). */
export function GoalEditor({ goal, onClose, onCreated }: { goal: GoalRow | null; onClose: () => void; onCreated?: (uuid: string) => void }) {
  const { t } = useTranslation();
  const { goals } = useHarvest();
  const today = useHarvestDay();
  const id = useId();
  const [title, setTitle] = useState(goal?.title ?? '');
  const [why, setWhy] = useState(goal?.why ?? '');
  const [targetDay, setTargetDay] = useState(goal?.targetDay ?? '');
  const [error, setError] = useState(false);
  const [saving, once] = useBusy();
  const past = targetDay !== '' && targetDay < today.key && targetDay !== goal?.targetDay;

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!title.trim()) {
      setError(true);
      return;
    }
    if (goal) {
      await goals.update(goal.uuid, { title, why, targetDay: targetDay || null });
    } else {
      const created = await goals.create({ title, why, targetDay: targetDay || null });
      onCreated?.(created.uuid);
    }
    onClose();
  }

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{goal ? t('goals.editTitle') : t('goals.new')}</DialogTitle>
          <DialogDescription>{t('goals.editorLead')}</DialogDescription>
        </DialogHeader>
        <form onSubmit={(event) => runAction(() => once(() => submit(event)))} className="flex flex-col gap-4" noValidate>
          <div className="flex flex-col gap-2">
            <Label htmlFor={`${id}-title`}>{t('goals.title')}</Label>
            <Input
              id={`${id}-title`}
              autoFocus
              value={title}
              placeholder={t('goals.titleHint')}
              aria-invalid={error ? true : undefined}
              onChange={(event) => setTitle(event.target.value)}
            />
            {error && (
              <p role="alert" className="text-sm font-semibold text-destructive">
                {t('form.error.required')}
              </p>
            )}
          </div>
          <div className="flex flex-col gap-2">
            <Label htmlFor={`${id}-why`}>{t('goals.why')}</Label>
            <Textarea id={`${id}-why`} rows={3} value={why} placeholder={t('goals.whyHint')} onChange={(event) => setWhy(event.target.value)} />
          </div>
          <div className="flex flex-col gap-2">
            <Label htmlFor={`${id}-target`}>{t('goals.targetDay')}</Label>
            <Input
              id={`${id}-target`}
              type="date"
              className="w-full sm:w-56"
              value={targetDay}
              aria-describedby={past ? `${id}-past` : undefined}
              onChange={(event) => setTargetDay(event.target.value)}
            />
            {/* Allowed (an old goal keeps its day), but said: 2020 is rarely what was meant (W6-37). */}
            {past && (
              <p id={`${id}-past`} className="text-xs font-semibold text-destructive">
                {t('goals.targetPast')}
              </p>
            )}
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={onClose}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" disabled={saving}>{goal ? t('common.save') : t('goals.create')}</Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
