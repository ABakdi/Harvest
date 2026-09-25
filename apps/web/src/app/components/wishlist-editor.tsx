import { parseToMinor } from '@harvest/core';
import { useId, useState, type FormEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group';
import { currencies, formatAmountInput } from '@/lib/format';
import { useHarvest, useHarvestDay } from '../context';
import type { WishlistList, WishlistRow } from '../data/wishlist';
import { useDefaultCurrency } from '../hooks';

/**
 * Writes an item down, or edits one: the title, which list it answers
 * to, an optional estimated price in its currency, a note, and an
 * optional planned purchase day. An estimate is a plan, not money
 * (W2): nothing here moves the wallet.
 */
export function WishlistEditor({
  item,
  list,
  onClose,
}: {
  item: WishlistRow | null;
  list: WishlistList;
  onClose: () => void;
}) {
  const { t } = useTranslation();
  const { wishlist } = useHarvest();
  const today = useHarvestDay();
  const defaultCurrency = useDefaultCurrency();
  const id = useId();
  const [title, setTitle] = useState(item?.title ?? '');
  const [segment, setSegment] = useState(item?.list ?? list);
  const [amount, setAmount] = useState(
    item !== null && item.priceMinor !== null ? formatAmountInput(item.priceMinor) : '',
  );
  // Chosen, or the default once its setting has been read: a fallback
  // captured before then would stick.
  const [chosenCurrency, setCurrency] = useState<string | null>(item?.currency ?? null);
  const currency = chosenCurrency ?? defaultCurrency;
  const [note, setNote] = useState(item?.note ?? '');
  const [targetDay, setTargetDay] = useState(item?.targetDay ?? '');
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  async function submit(event: FormEvent) {
    event.preventDefault();
    // "12,50" is twelve and a half, as the phone's sheet reads it.
    const minor = amount.trim() === '' ? null : parseToMinor(amount.trim());
    if (!title.trim()) {
      setError(t('form.error.required'));
      return;
    }
    if (amount.trim() !== '' && minor === null) {
      setError(t('wishlist.estimateInvalid'));
      return;
    }
    setSaving(true);
    const input = {
      title,
      priceMinor: minor,
      currency,
      note: note || null,
      targetDay: targetDay || null,
    };
    try {
      if (item) {
        await wishlist.edit(item.uuid, input, segment);
      } else {
        await wishlist.add({ list: segment, ...input });
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

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{item ? t('wishlist.editItem') : t('wishlist.new')}</DialogTitle>
          <DialogDescription>{t('wishlist.editorLead')}</DialogDescription>
        </DialogHeader>
        <form onSubmit={(event) => void submit(event)} className="flex flex-col gap-4" noValidate>
          <div className="flex flex-col gap-2">
            <Label htmlFor={`${id}-title`}>{t('wishlist.itemLabel')}</Label>
            <Input
              id={`${id}-title`}
              autoFocus
              maxLength={120}
              value={title}
              placeholder={t('wishlist.titleHint')}
              aria-invalid={error !== null ? true : undefined}
              onChange={(event) => setTitle(event.target.value)}
            />
          </div>

          <div className="flex flex-col gap-2">
            <Label id={`${id}-list`}>{t('wishlist.lists')}</Label>
            <ToggleGroup
              type="single"
              value={segment}
              onValueChange={(value) => value && setSegment(value as WishlistList)}
              aria-labelledby={`${id}-list`}
            >
              <ToggleGroupItem value="buy">{t('wishlist.buyList')}</ToggleGroupItem>
              <ToggleGroupItem value="wish">{t('wishlist.wishlist')}</ToggleGroupItem>
            </ToggleGroup>
          </div>

          <div className="flex gap-2">
            <div className="flex flex-1 flex-col gap-2">
              <Label htmlFor={`${id}-estimate`}>{t('wishlist.estimateLabel')}</Label>
              <Input
                id={`${id}-estimate`}
                inputMode="decimal"
                dir="ltr"
                className="text-lg font-extrabold tabular"
                value={amount}
                placeholder={t('wishlist.estimateHint')}
                onChange={(event) => setAmount(event.target.value)}
              />
            </div>
            <div className="flex w-28 flex-col gap-2">
              <Label htmlFor={`${id}-currency`}>{t('money.currency')}</Label>
              <Select value={currency} onValueChange={setCurrency}>
                <SelectTrigger id={`${id}-currency`}>
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

          <div className="grid gap-3 sm:grid-cols-2">
            <div className="flex flex-col gap-2">
              <Label htmlFor={`${id}-note`}>{t('wishlist.noteLabel')}</Label>
              <Input id={`${id}-note`} maxLength={200} value={note} placeholder={t('wishlist.noteHint')} onChange={(event) => setNote(event.target.value)} />
            </div>
            <div className="flex flex-col gap-2">
              <Label htmlFor={`${id}-day`}>{t('wishlist.targetDay')}</Label>
              <Input id={`${id}-day`} type="date" min={today.key} value={targetDay} onChange={(event) => setTargetDay(event.target.value)} />
            </div>
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
            <Button type="submit" disabled={saving}>
              {item ? t('common.save') : t('wishlist.add')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}