import { evaluateAmountToMinor } from '@harvest/core';
import { useId, useState, type FormEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group';
import { currencies, currencySymbol } from '@/lib/format';
import { useHarvest, useHarvestDay } from '../context';
import { useDefaultCurrency } from '../hooks';
import { AmountField, moneyError } from './money-bits';
import { useBusy } from './use-busy';

/**
 * `09:05` from a time input into `9:05`, the way the phone's debt
 * sheet writes a reminder time.
 */
export function remindAtOf(value: string): string | null {
  const match = /^(\d{1,2}):(\d{2})$/.exec(value);
  return match ? `${Number(match[1])}:${match[2]}` : null;
}

/**
 * Log a debt (`showDebtSheet`): who it is owed to, how much, in which
 * currency, and optionally a pay-off-by day, a daily reminder time and
 * a note ([[Finances]] The Vault).
 */
export function DebtDialog({ onClose }: { onClose: () => void }) {
  const { t } = useTranslation();
  const { vault } = useHarvest();
  const today = useHarvestDay();
  const id = useId();
  const [person, setPerson] = useState('');
  const [amount, setAmount] = useState('');
  const defaultCurrency = useDefaultCurrency();
  const [chosen, setCurrency] = useState<string | null>(null);
  const currency = chosen ?? defaultCurrency;
  const [payOffBy, setPayOffBy] = useState('');
  const [remindAt, setRemindAt] = useState('');
  const [note, setNote] = useState('');
  const [saving, once] = useBusy();
  const minor = evaluateAmountToMinor(amount);
  const valid = person.trim() !== '' && minor !== null;

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!valid) return;
    try {
      await vault.createDebt({
        person,
        amountMinor: minor,
        currency,
        payOffBy: payOffBy || null,
        remindAt: remindAtOf(remindAt),
        note: note || null,
      });
      toast.success(t('vault.debtAdded'));
      onClose();
    } catch (failure) {
      toast.error(moneyError(t, failure));
    }
  }

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('vault.addDebt')}</DialogTitle>
          <DialogDescription>{t('vaultWeb.debtLead')}</DialogDescription>
        </DialogHeader>
        <form onSubmit={(event) => void once(() => submit(event))} className="flex flex-col gap-4" noValidate>
          <div className="flex flex-col gap-2">
            <Label htmlFor={`${id}-person`}>{t('vault.debtPerson')}</Label>
            <Input id={`${id}-person`} autoFocus autoCapitalize="words" value={person} onChange={(event) => setPerson(event.target.value)} />
          </div>
          <AmountField id={`${id}-amount`} label={t('money.amount')} value={amount} onChange={setAmount} currency={currency} />
          <div className="flex flex-col gap-2">
            <Label id={`${id}-currency`}>{t('money.currency')}</Label>
            <ToggleGroup type="single" value={currency} onValueChange={(value) => value && setCurrency(value)} aria-labelledby={`${id}-currency`}>
              {currencies.map((code) => (
                <ToggleGroupItem key={code} value={code} aria-label={code}>
                  {currencySymbol(code)}
                </ToggleGroupItem>
              ))}
            </ToggleGroup>
          </div>
          <div className="grid gap-3 sm:grid-cols-2">
            <div className="flex flex-col gap-2">
              <Label htmlFor={`${id}-by`}>{t('vault.debtPayOffBy')}</Label>
              <Input id={`${id}-by`} type="date" min={today.key} value={payOffBy} onChange={(event) => setPayOffBy(event.target.value)} />
            </div>
            <div className="flex flex-col gap-2">
              <Label htmlFor={`${id}-remind`}>{t('vault.debtRemindAt')}</Label>
              <Input
                id={`${id}-remind`}
                type="time"
                value={remindAt}
                aria-describedby={`${id}-remind-hint`}
                onChange={(event) => setRemindAt(event.target.value)}
              />
            </div>
          </div>
          <p id={`${id}-remind-hint`} className="-mt-2 text-xs text-muted-foreground">
            {t('vault.debtRemindHint')}
          </p>
          <div className="flex flex-col gap-2">
            <Label htmlFor={`${id}-note`}>{t('money.note')}</Label>
            <Input id={`${id}-note`} value={note} maxLength={200} onChange={(event) => setNote(event.target.value)} />
          </div>
          <DialogFooter className="gap-2">
            <Button variant="outline" onClick={onClose}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" disabled={saving || !valid}>
              {t('common.save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
