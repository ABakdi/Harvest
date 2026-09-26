import { listKinds, type ListKind } from '@harvest/contracts';
import type { TFunction } from 'i18next';
import { useId, useState, type FormEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group';
import { useHarvest } from '../context';
import { builtInOf, hasDefaultName, type ListRow } from '../data/lists';

/** A list's name as shown: a built-in one in my language while I have not renamed it ([[Lists]]). */
export function listName(list: ListRow, t: TFunction): string {
  const builtIn = builtInOf(list);
  return builtIn && hasDefaultName(list) ? t(`lists.builtIn.${builtIn.key}`) : list.name;
}

/**
 * Names a new list and picks its kind, or renames one ([list]); a
 * list's kind is chosen once, since it decides its items' fields (L2).
 */
export function ListNameDialog({
  list,
  onClose,
  onCreated,
}: {
  list: ListRow | null;
  onClose: () => void;
  onCreated?: (list: ListRow) => void;
}) {
  const { t } = useTranslation();
  const { lists } = useHarvest();
  const id = useId();
  const [name, setName] = useState(list ? listName(list, t) : '');
  const [kind, setKind] = useState<ListKind>('plain');
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!name.trim()) {
      setError(t('form.error.required'));
      return;
    }
    setSaving(true);
    try {
      if (list) {
        // Unchanged, a built-in keeps its localised name rather than taking the translation as its own.
        if (name.trim() !== listName(list, t)) await lists.renameList(list.uuid, name);
      } else {
        onCreated?.(await lists.createList({ name, kind }));
      }
    } catch {
      toast.error(t('common.saveFailed'));
      return;
    } finally {
      setSaving(false);
    }
    onClose();
  }

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{list ? t('lists.renameTitle') : t('lists.newList')}</DialogTitle>
          <DialogDescription>{list ? t('lists.renameLead') : t('lists.newListLead')}</DialogDescription>
        </DialogHeader>
        <form onSubmit={(event) => void submit(event)} className="flex flex-col gap-4" noValidate>
          <div className="flex flex-col gap-2">
            <Label htmlFor={`${id}-name`}>{t('lists.nameLabel')}</Label>
            <Input
              id={`${id}-name`}
              autoFocus
              maxLength={60}
              value={name}
              placeholder={t('lists.nameHint')}
              aria-invalid={error !== null ? true : undefined}
              onChange={(event) => setName(event.target.value)}
            />
          </div>
          {!list && (
            <div className="flex flex-col gap-2">
              <Label id={`${id}-kind`}>{t('lists.kindLabel')}</Label>
              <ToggleGroup
                type="single"
                value={kind}
                onValueChange={(value) => value && setKind(value as ListKind)}
                aria-labelledby={`${id}-kind`}
                aria-describedby={`${id}-kind-hint`}
              >
                {listKinds.map((option) => (
                  <ToggleGroupItem key={option} value={option}>
                    {t(`lists.kind.${option}`)}
                  </ToggleGroupItem>
                ))}
              </ToggleGroup>
              <p id={`${id}-kind-hint`} className="text-xs text-muted-foreground">
                {t(`lists.kindHint.${kind}`)}
              </p>
            </div>
          )}
          {error && (
            <p role="alert" className="text-sm font-semibold text-destructive">
              {error}
            </p>
          )}
          <DialogFooter>
            <Button variant="outline" onClick={onClose}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" disabled={saving}>
              {list ? t('common.save') : t('common.create')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
