import { PlusIcon, XIcon } from 'lucide-react';
import { useId, useState, type FormEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group';
import { useHarvest } from '../context';
import { categoryIconKeys, categoryNameProblem } from '../data/categories';
import { IconGlyph, useCustomCategories } from './money-bits';

/**
 * A new category: a name and an icon from the registry
 * (`showCategoryCreator`). Hands the new name back so the editor that
 * opened it can select it.
 */
export function CategoryCreator({ onClose, onCreated }: { onClose: () => void; onCreated?: (name: string) => void }) {
  const { t } = useTranslation();
  const { categories } = useHarvest();
  const customs = useCustomCategories();
  const id = useId();
  const [name, setName] = useState('');
  const [icon, setIcon] = useState('coffee');
  const [problem, setProblem] = useState<'empty' | 'taken' | null>(null);
  const [saving, setSaving] = useState(false);

  async function submit(event: FormEvent) {
    event.preventDefault();
    // A portal still bubbles through React: opened from the expense
    // form, this submit must not submit that form too.
    event.stopPropagation();
    const found = categoryNameProblem(name, customs ?? []);
    setProblem(found);
    if (found) return;
    setSaving(true);
    try {
      await categories.create(name, icon);
      toast.success(t('money.categoryAdded'));
      onCreated?.(name.trim());
      onClose();
    } catch {
      toast.error(t('common.saveFailed'));
      setSaving(false);
    }
  }

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('money.newCategory')}</DialogTitle>
          <DialogDescription className="sr-only">{t('money.newCategory')}</DialogDescription>
        </DialogHeader>
        <form onSubmit={(event) => void submit(event)} className="flex flex-col gap-4" noValidate>
          <div className="flex flex-col gap-2">
            <Label htmlFor={`${id}-name`}>{t('money.categoryName')}</Label>
            <Input
              id={`${id}-name`}
              autoFocus
              maxLength={40}
              value={name}
              aria-invalid={problem !== null || undefined}
              aria-describedby={problem ? `${id}-problem` : undefined}
              onChange={(event) => {
                setName(event.target.value);
                setProblem(null);
              }}
            />
            {problem && (
              <p id={`${id}-problem`} role="alert" className="text-sm font-semibold text-destructive">
                {t(problem === 'empty' ? 'money.categoryEmpty' : 'money.categoryTaken')}
              </p>
            )}
          </div>
          <div className="flex flex-col gap-2">
            <Label id={`${id}-icon`}>{t('money.categoryIcon')}</Label>
            <ToggleGroup
              type="single"
              value={icon}
              onValueChange={(value) => value && setIcon(value)}
              aria-labelledby={`${id}-icon`}
              className="flex-wrap justify-start"
            >
              {categoryIconKeys.map((key) => (
                <ToggleGroupItem key={key} value={key} aria-label={t(`money.icon.${key}`)} title={t(`money.icon.${key}`)}>
                  <IconGlyph icon={key} />
                </ToggleGroupItem>
              ))}
            </ToggleGroup>
          </div>
          <DialogFooter className="gap-2">
            <Button variant="outline" onClick={onClose}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" disabled={saving}>
              {t('common.save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

/**
 * The custom categories, each removable with an Undo, and a way to add
 * one (`CategorySettingsCard`). The presets are built in and stay.
 */
export function CategoryManager() {
  const { t } = useTranslation();
  const { categories } = useHarvest();
  const customs = useCustomCategories();
  const [creating, setCreating] = useState(false);

  async function remove(uuid: string) {
    await categories.remove(uuid);
    toast(t('money.categoryRemoved'), {
      action: { label: t('common.undo'), onClick: () => void categories.restore(uuid) },
    });
  }

  return (
    <section className="flex flex-col gap-2 rounded-xl border bg-card p-4" aria-labelledby="custom-categories">
      <h2 id="custom-categories" className="font-extrabold">
        {t('budget.categories')}
      </h2>
      <p className="text-xs text-muted-foreground">{t('budget.categoriesBody')}</p>
      {customs && customs.length === 0 && <p className="text-sm text-muted-foreground">{t('budget.noCategories')}</p>}
      <ul className="flex flex-wrap gap-2">
        {(customs ?? []).map((row) => (
            <li key={row.uuid} className="flex items-center gap-1.5 rounded-full border bg-background py-1 ps-3 pe-1 text-sm font-bold">
              <IconGlyph icon={row.icon} className="size-4" />
              {row.name}
              <Button variant="ghost" size="icon-sm" className="size-7 rounded-full" aria-label={t('money.removeCategory', { name: row.name })} onClick={() => void remove(row.uuid)}>
                <XIcon />
              </Button>
            </li>
        ))}
        <li>
          <Button variant="outline" size="sm" className="rounded-full" onClick={() => setCreating(true)}>
            <PlusIcon />
            {t('money.newCategory')}
          </Button>
        </li>
      </ul>
      {creating && <CategoryCreator onClose={() => setCreating(false)} />}
    </section>
  );
}
