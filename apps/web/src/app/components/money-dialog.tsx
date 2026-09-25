import { evaluateAmountToMinor } from '@harvest/core';
import { useId, useState, type FormEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Switch } from '@/components/ui/switch';
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group';
import { currencies, currencySymbol, formatAmountInput, formatMoney } from '@/lib/format';
import { AmountField, SwitchRow, moneyError } from './money-bits';

/** What a money dialog hands back (`MoneyEntry`). */
export interface MoneyEntry {
  minor: number;
  currency: string;
  note: string | null;
  fromWallet: boolean;
}

/**
 * The one way the Vault asks for an amount (`showMoneySheet`): the
 * amount (a sum is fine), the currency, an optional note and, where it
 * applies, whether the money comes out of the wallet.
 *
 * [maxMinor] caps the amount per currency — a pot cannot go below
 * zero, a debt cannot be overpaid. [walletBalances] shows the wallet
 * switch, on while untouched whenever the wallet can cover the amount,
 * and unavailable when it cannot.
 */
export function MoneyDialog({
  title,
  description,
  initialCurrency,
  lockCurrency = false,
  initialMinor,
  maxMinor,
  walletBalances,
  onSubmit,
  onClose,
}: {
  title: string;
  description?: string | undefined;
  initialCurrency: string;
  lockCurrency?: boolean;
  initialMinor?: number;
  maxMinor?: Record<string, number> | undefined;
  walletBalances?: Record<string, number> | undefined;
  onSubmit: (entry: MoneyEntry) => Promise<unknown>;
  onClose: () => void;
}) {
  const { t } = useTranslation();
  const id = useId();
  const [amount, setAmount] = useState(initialMinor ? formatAmountInput(initialMinor) : '');
  const [currency, setCurrency] = useState(initialCurrency);
  const [note, setNote] = useState('');
  const [walletChoice, setWalletChoice] = useState<boolean | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const minor = evaluateAmountToMinor(amount);
  const cap = maxMinor ? (maxMinor[currency] ?? 0) : null;
  const overCap = minor !== null && cap !== null && minor > cap;
  const walletBalance = walletBalances?.[currency] ?? 0;
  const walletCanCover = minor !== null && walletBalance >= minor;
  const useWallet = walletBalances !== undefined && (walletChoice ?? walletCanCover) && walletCanCover;

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (minor === null) {
      setError(t('money.error.amount'));
      return;
    }
    if (overCap) return;
    setSaving(true);
    try {
      await onSubmit({ minor, currency, note: note.trim() || null, fromWallet: useWallet });
      onClose();
    } catch (failure) {
      toast.error(moneyError(t, failure));
      setSaving(false);
    }
  }

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      {/* No lead, no description: a hidden copy of the title would only be read twice. */}
      <DialogContent {...(description ? {} : { 'aria-describedby': undefined })}>
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
          {description && <DialogDescription>{description}</DialogDescription>}
        </DialogHeader>
        <form onSubmit={(event) => void submit(event)} className="flex flex-col gap-4" noValidate>
          <AmountField
            id={`${id}-amount`}
            label={t('money.amount')}
            value={amount}
            onChange={(value) => {
              setAmount(value);
              setError(null);
            }}
            currency={currency}
            autoFocus
            invalid={overCap || (error !== null && minor === null)}
            describedBy={`${id}-cap`}
          />
          {cap !== null && (
            <p id={`${id}-cap`} className={overCap ? 'text-sm font-semibold text-destructive' : 'text-xs font-bold text-muted-foreground'} dir="auto">
              {overCap ? t('vault.overCap', { amount: formatMoney(cap, currency) }) : t('vault.atMost', { amount: formatMoney(cap, currency) })}
            </p>
          )}
          {!lockCurrency && (
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
          {walletBalances !== undefined && (
            <SwitchRow>
              <div className="flex flex-col">
                <Label htmlFor={`${id}-wallet`}>{t('money.fromWallet')}</Label>
                <span className="text-xs text-muted-foreground tabular">
                  {minor !== null && !walletCanCover ? t('vault.walletShort') : t('money.walletHas', { amount: formatMoney(walletBalance, currency) })}
                </span>
              </div>
              <Switch id={`${id}-wallet`} checked={useWallet} disabled={!walletCanCover} onCheckedChange={setWalletChoice} />
            </SwitchRow>
          )}
          <div className="flex flex-col gap-2">
            <Label htmlFor={`${id}-note`}>{t('money.note')}</Label>
            <Input id={`${id}-note`} value={note} maxLength={200} onChange={(event) => setNote(event.target.value)} />
          </div>
          {error && (
            <p role="alert" className="text-sm font-semibold text-destructive">
              {error}
            </p>
          )}
          <DialogFooter className="gap-2">
            <Button variant="outline" onClick={onClose}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" disabled={saving || overCap}>
              {t('common.save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
