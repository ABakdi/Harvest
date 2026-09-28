import { evaluateAmountToMinor } from '@harvest/core';
import { useId, useState, type FormEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
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
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group';
import { currencies, currencySymbol, formatAmountInput, formatMoney } from '@/lib/format';
import { useHarvest, useHarvestDay } from '../context';
import type { DebtView } from '../data/vault';
import { useDefaultCurrency } from '../hooks';
import { AmountField, moneyError } from './money-bits';
import { useBusy } from './use-busy';
import { runAction } from '@/lib/actions';

/**
 * `09:05` from a time input into `9:05`, the way the phone's debt
 * sheet writes a reminder time.
 */
export function remindAtOf(value: string): string | null {
  const match = /^(\d{1,2}):(\d{2})$/.exec(value);
  return match ? `${Number(match[1])}:${match[2]}` : null;
}

/** `9:05` as stored into `09:05` for a time input. */
function timeInputOf(remindAt: string | null): string {
  const match = /^(\d{1,2}):(\d{2})$/.exec(remindAt ?? '');
  return match ? `${match[1]!.padStart(2, '0')}:${match[2]}` : '';
}

/**
 * Log a debt (`showDebtSheet`): who it is owed to, how much, in which
 * currency, and optionally a pay-off-by day, a daily reminder time and
 * a note ([[Finances]] The Vault). With [existing], the same dialog
 * corrects it or removes it, with Undo ([[Audit-v3]] G5-02): never to
 * less than has been paid, and in the currency its payments were made in.
 */
export function DebtDialog({ existing, onClose }: { existing?: DebtView | undefined; onClose: () => void }) {
  const { t } = useTranslation();
  const { vault } = useHarvest();
  const today = useHarvestDay();
  const id = useId();
  const debt = existing?.debt;
  const paid = existing?.paidMinor ?? 0;
  const [person, setPerson] = useState(debt?.person ?? '');
  const [amount, setAmount] = useState(debt ? formatAmountInput(debt.amountMinor) : '');
  const defaultCurrency = useDefaultCurrency();
  const [chosen, setCurrency] = useState<string | null>(debt?.currency ?? null);
  const currency = chosen ?? defaultCurrency;
  const [payOffBy, setPayOffBy] = useState(debt?.payOffBy ?? '');
  const [remindAt, setRemindAt] = useState(timeInputOf(debt?.remindAt ?? null));
  const [note, setNote] = useState(debt?.note ?? '');
  const [confirming, setConfirming] = useState(false);
  const [saving, once] = useBusy();
  const minor = evaluateAmountToMinor(amount);
  const belowPaid = minor !== null && minor < paid;
  const valid = person.trim() !== '' && minor !== null && !belowPaid;

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!valid) return;
    const input = {
      person,
      amountMinor: minor,
      currency,
      payOffBy: payOffBy || null,
      remindAt: remindAtOf(remindAt),
      note: note || null,
    };
    try {
      if (debt) {
        await vault.updateDebt(debt.uuid, input);
        toast.success(t('vaultWeb.debtSaved'));
      } else {
        await vault.createDebt(input);
        toast.success(t('vault.debtAdded'));
      }
      onClose();
    } catch (failure) {
      toast.error(moneyError(t, failure));
    }
  }

  /** Its payments go with it; what they took from the wallet stays spent. */
  async function remove() {
    if (!debt) return;
    try {
      await vault.deleteDebt(debt.uuid);
    } catch (failure) {
      toast.error(moneyError(t, failure));
      return;
    }
    onClose();
    toast(t('vaultWeb.debtRemoved', { person: debt.person }), {
      action: {
        label: t('common.undo'),
        onClick: () => void vault.restoreDebt(debt.uuid).catch((failure: unknown) => void toast.error(moneyError(t, failure))),
      },
    });
  }

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{debt ? t('vaultWeb.editDebt') : t('vault.addDebt')}</DialogTitle>
          <DialogDescription>{t('vaultWeb.debtLead')}</DialogDescription>
        </DialogHeader>
        <form onSubmit={(event) => runAction(() => once(() => submit(event)))} className="flex flex-col gap-4" noValidate>
          <div className="flex flex-col gap-2">
            <Label htmlFor={`${id}-person`}>{t('vault.debtPerson')}</Label>
            <Input id={`${id}-person`} autoFocus autoCapitalize="words" value={person} onChange={(event) => setPerson(event.target.value)} />
          </div>
          <AmountField id={`${id}-amount`} label={t('money.amount')} value={amount} onChange={setAmount} currency={currency} />
          {belowPaid && (
            <p role="alert" className="-mt-2 text-sm font-semibold text-destructive">
              {t('vaultWeb.debtBelowPaid', { amount: formatMoney(paid, currency) })}
            </p>
          )}
          {/* Payments were made in its currency; it stays that one. */}
          {paid === 0 && (
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
          )}
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
            {debt && (
              <Button variant="ghost" className="text-destructive sm:me-auto" disabled={saving} onClick={() => setConfirming(true)}>
                {t('common.delete')}
              </Button>
            )}
            <Button variant="outline" onClick={onClose}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" disabled={saving || !valid}>
              {t('common.save')}
            </Button>
          </DialogFooter>
        </form>
        <AlertDialog open={confirming} onOpenChange={setConfirming}>
          <AlertDialogContent>
            <AlertDialogHeader>
              <AlertDialogTitle>{t('vaultWeb.debtRemoveTitle')}</AlertDialogTitle>
              <AlertDialogDescription>{t('vaultWeb.debtRemoveBody', { person: debt?.person ?? '' })}</AlertDialogDescription>
            </AlertDialogHeader>
            <AlertDialogFooter>
              <AlertDialogCancel>{t('common.cancel')}</AlertDialogCancel>
              <AlertDialogAction onClick={() => runAction(() => once(remove))}>{t('common.delete')}</AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>
      </DialogContent>
    </Dialog>
  );
}
