import { mediaTypes, type MediaType } from '@harvest/contracts';
import { linkOf, parseToMinor } from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import { useId, useState, type FormEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { currencies, formatAmountInput } from '@/lib/format';
import { useHarvest, useHarvestDay } from '../context';
import { listOfItem, liveLists, type ListItemInput, type ListItemRow } from '../data/lists';
import { useDefaultCurrency } from '../hooks';
import { listName } from './list-bits';

/** What the add field already knew when it opened the editor: the title typed, the link pasted. */
export interface ListItemPrefill {
  title?: string;
  link?: string | null;
  mediaType?: MediaType | null;
}

/**
 * Writes an item down, or edits one, with the fields its list's kind
 * carries (L2): a title and a note always; an estimate, its currency
 * and a planned day on a shopping list — a plan, not money (L3, L5);
 * a type, a link and a creator on a media list. The list can change
 * only to another of the same kind, and the item moves as the same row.
 */
export function ListItemEditor({
  item,
  listUuid,
  prefill = {},
  onClose,
}: {
  item: ListItemRow | null;
  listUuid: string;
  prefill?: ListItemPrefill | undefined;
  onClose: () => void;
}) {
  const { t } = useTranslation();
  const { db, lists, writer } = useHarvest();
  const today = useHarvestDay();
  const defaultCurrency = useDefaultCurrency();
  const id = useId();
  const all = useLiveQuery(() => liveLists(db), [db]);
  const [target, setTarget] = useState(item ? listOfItem(item) : listUuid);
  const [title, setTitle] = useState(item?.title ?? prefill.title ?? '');
  const [note, setNote] = useState(item?.note ?? '');
  const [amount, setAmount] = useState(item !== null && item.priceMinor !== null ? formatAmountInput(item.priceMinor) : '');
  // Chosen, or the default once its setting has been read: a fallback
  // captured before then would stick.
  const [chosenCurrency, setCurrency] = useState<string | null>(item?.currency ?? null);
  const currency = chosenCurrency ?? defaultCurrency;
  const [targetDay, setTargetDay] = useState(item?.targetDay ?? '');
  const [mediaType, setMediaType] = useState<MediaType | 'none'>(item?.mediaType ?? prefill.mediaType ?? 'none');
  const [link, setLink] = useState(item?.link ?? prefill.link ?? '');
  const [creator, setCreator] = useState(item?.creator ?? '');
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const home = all?.find((list) => list.uuid === (item ? listOfItem(item) : listUuid));
  const kind = home?.kind;
  // Only lists of the same kind (L2).
  const choices = all?.filter((list) => list.kind === kind) ?? [];

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!kind) return;
    // "12,50" is twelve and a half, as the phone's sheet reads it.
    const minor = amount.trim() === '' ? null : parseToMinor(amount.trim());
    // A pasted link stands in for the title until one is typed.
    const name = title.trim() || (kind === 'media' ? link.trim() : '');
    if (!name) {
      setError(t('form.error.required'));
      return;
    }
    if (kind === 'shopping' && amount.trim() !== '' && minor === null) {
      setError(t('wishlist.estimateInvalid'));
      return;
    }
    if (kind === 'media' && link.trim() !== '' && linkOf(link) === null) {
      setError(t('lists.linkInvalid'));
      return;
    }
    const input: ListItemInput = {
      title: name,
      note: note || null,
      priceMinor: minor,
      currency,
      targetDay: targetDay || null,
      mediaType: mediaType === 'none' ? null : mediaType,
      link: link.trim() || null,
      creator: creator || null,
    };
    setSaving(true);
    try {
      if (item) {
        // The edit and the move land as one write, or not at all.
        await writer.run(async (tx) => {
          await lists.editItemIn(tx, item.uuid, input);
          if (target !== listOfItem(item)) await lists.moveItemIn(tx, item.uuid, target);
        });
      } else {
        await lists.addItem(target, input);
      }
    } catch {
      // The dialog stays open with what I typed, so I can try again.
      toast.error(t('common.saveFailed'));
      return;
    } finally {
      setSaving(false);
    }
    onClose();
  }

  const field = (name: string) => `${id}-${name}`;

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{item ? t('lists.editItem') : t('lists.newItem')}</DialogTitle>
          <DialogDescription>{kind ? t(`lists.editorLead.${kind}`) : ''}</DialogDescription>
        </DialogHeader>
        <form onSubmit={(event) => void submit(event)} className="flex flex-col gap-4" noValidate>
          <div className="flex flex-col gap-2">
            <Label htmlFor={field('title')}>{t('lists.titleLabel')}</Label>
            <Input
              id={field('title')}
              autoFocus
              maxLength={200}
              value={title}
              placeholder={kind === 'media' && link.trim() ? link.trim() : t(`lists.titleHint.${kind ?? 'plain'}`)}
              aria-invalid={error !== null ? true : undefined}
              onChange={(event) => setTitle(event.target.value)}
            />
          </div>

          {choices.length > 1 && (
            <div className="flex flex-col gap-2">
              <Label htmlFor={field('list')}>{t('lists.listLabel')}</Label>
              <Select value={target} onValueChange={setTarget}>
                <SelectTrigger id={field('list')}>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {choices.map((list) => (
                    <SelectItem key={list.uuid} value={list.uuid}>
                      {listName(list, t)}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          )}

          {kind === 'shopping' && (
            <>
              <div className="flex gap-2">
                <div className="flex flex-1 flex-col gap-2">
                  <Label htmlFor={field('estimate')}>{t('wishlist.estimateLabel')}</Label>
                  <Input
                    id={field('estimate')}
                    inputMode="decimal"
                    dir="ltr"
                    className="text-lg font-extrabold tabular"
                    value={amount}
                    placeholder={t('wishlist.estimateHint')}
                    onChange={(event) => setAmount(event.target.value)}
                  />
                </div>
                <div className="flex w-28 flex-col gap-2">
                  <Label htmlFor={field('currency')}>{t('money.currency')}</Label>
                  <Select value={currency} onValueChange={setCurrency}>
                    <SelectTrigger id={field('currency')}>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {currencies.map((code) => (
                        <SelectItem key={code} value={code}>
                          {code}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>
              <div className="flex flex-col gap-2">
                <Label htmlFor={field('day')}>{t('wishlist.targetDay')}</Label>
                <Input id={field('day')} type="date" min={today.key} value={targetDay} onChange={(event) => setTargetDay(event.target.value)} />
              </div>
            </>
          )}

          {kind === 'media' && (
            <>
              <div className="grid gap-3 sm:grid-cols-2">
                <div className="flex flex-col gap-2">
                  <Label htmlFor={field('type')}>{t('lists.mediaTypeLabel')}</Label>
                  <Select value={mediaType} onValueChange={(value) => setMediaType(value as MediaType | 'none')}>
                    <SelectTrigger id={field('type')}>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="none">{t('lists.mediaTypeNone')}</SelectItem>
                      {mediaTypes.map((type) => (
                        <SelectItem key={type} value={type}>
                          {t(`lists.mediaType.${type}`)}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="flex flex-col gap-2">
                  <Label htmlFor={field('creator')}>{t('lists.creatorLabel')}</Label>
                  <Input id={field('creator')} maxLength={120} value={creator} onChange={(event) => setCreator(event.target.value)} />
                </div>
              </div>
              <div className="flex flex-col gap-2">
                <Label htmlFor={field('link')}>{t('lists.linkLabel')}</Label>
                <Input
                  id={field('link')}
                  type="url"
                  dir="ltr"
                  inputMode="url"
                  maxLength={2000}
                  value={link}
                  placeholder="https://"
                  onChange={(event) => setLink(event.target.value)}
                />
              </div>
            </>
          )}

          <div className="flex flex-col gap-2">
            <Label htmlFor={field('note')}>{t('wishlist.noteLabel')}</Label>
            <Input id={field('note')} maxLength={500} value={note} onChange={(event) => setNote(event.target.value)} />
          </div>

          {error && (
            <p role="alert" className="text-sm font-semibold text-destructive">
              {error}
            </p>
          )}
          <DialogFooter>
            <Button variant="outline" onClick={onClose}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" disabled={saving || !kind}>
              {item ? t('common.save') : t('lists.add')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
