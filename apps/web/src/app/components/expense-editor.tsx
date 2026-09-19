import { useLiveQuery } from 'dexie-react-hooks';
import { useId, useState, type FormEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Switch } from '@/components/ui/switch';
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group';
import { currencies, formatAmountInput, formatMoney, parseAmount } from '@/lib/format';
import { useHarvest, useHarvestDay } from '../context';
import { presetCategories, type ExpenseRow } from '../data/money';
import { useDefaultCurrency, usePrivateKey } from '../hooks';
import { categoryLabel } from './category';
import { PassphrasePrompt } from './passphrase-prompt';

/**
 * Log or edit an expense: the amount in the currency it was paid in,
 * a category, a note, the day it counts for, and whether it came out of
 * the wallet. Without the passphrase this browser cannot keep money
 * rows in step with the other devices, so it asks for it first.
 */
export function ExpenseEditor({ expense, onClose }: { expense: ExpenseRow | null; onClose: () => void }) {
  const { t } = useTranslation();
  const unlocked = usePrivateKey();
  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{expense ? t('money.editTitle') : t('money.log')}</DialogTitle>
          <DialogDescription>{t('money.editorLead')}</DialogDescription>
        </DialogHeader>
        {unlocked === false && <PassphrasePrompt />}
        {unlocked === true && <ExpenseForm expense={expense} onClose={onClose} />}
      </DialogContent>
    </Dialog>
  );
}

function ExpenseForm({ expense, onClose }: { expense: ExpenseRow | null; onClose: () => void }) {
  const { t } = useTranslation();
  const { db, money } = useHarvest();
  const today = useHarvestDay();
  const defaultCurrency = useDefaultCurrency();
  const id = useId();
  const [amount, setAmount] = useState(expense ? formatAmountInput(expense.amountMinor) : '');
  const [currency, setCurrency] = useState<string | null>(expense?.currency ?? null);
  const [category, setCategory] = useState(expense?.category ?? 'food');
  const [note, setNote] = useState(expense?.note ?? '');
  const [day, setDay] = useState(expense?.harvestDay ?? today.key);
  const [fromWallet, setFromWallet] = useState<boolean | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const chosenCurrency = currency ?? defaultCurrency;

  const custom = useLiveQuery(
    async () =>
      (await db.rows('expense_categories').toArray())
        .filter((row) => row.deletedAt === null)
        .sort((a, b) => a.updatedAt.localeCompare(b.updatedAt)),
    [db],
  );
  const wallet = useLiveQuery(async () => {
    const moves = await db.rows('money_txns').where('account').equals('wallet').toArray();
    const balance = moves
      .filter((move) => move.deletedAt === null && move.currency === chosenCurrency && move.linkUuid !== expense?.uuid)
      .reduce((sum, move) => sum + move.deltaMinor, 0);
    const linked = expense ? moves.some((move) => move.linkUuid === expense.uuid && move.deletedAt === null) : false;
    return { balance, linked };
  }, [db, chosenCurrency, expense?.uuid]);

  const minor = parseAmount(amount);
  // On by default when the wallet can cover it, as on the phone.
  const walletDefault = expense ? (wallet?.linked ?? false) : minor !== null && (wallet?.balance ?? 0) >= minor;
  const paidFromWallet = fromWallet ?? walletDefault;

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (minor === null) {
      setError(t('money.error.amount'));
      return;
    }
    if (!day) {
      setError(t('money.error.day'));
      return;
    }
    setSaving(true);
    const input = {
      amountMinor: minor,
      currency: chosenCurrency,
      category,
      note: note || null,
      day,
      fromWallet: paidFromWallet,
    };
    try {
      if (expense) {
        await money.update(expense.uuid, input);
        toast.success(t('money.saved'));
      } else {
        await money.log(input);
        toast.success(t('money.logged', { amount: formatMoney(minor, chosenCurrency) }));
      }
      onClose();
    } catch {
      toast.error(t('common.saveFailed'));
      setSaving(false);
    }
  }

  async function remove() {
    if (!expense) return;
    await money.remove(expense.uuid);
    onClose();
    toast(t('money.removed'), {
      action: { label: t('common.undo'), onClick: () => void money.restore(expense.uuid) },
    });
  }

  const categories = [...presetCategories, ...(custom ?? []).map((row) => row.name)];
  if (!categories.includes(category)) categories.push(category);

  return (
    <form onSubmit={(event) => void submit(event)} className="flex flex-col gap-4" noValidate>
      <div className="flex gap-2">
        <div className="flex flex-1 flex-col gap-2">
          <Label htmlFor={`${id}-amount`}>{t('money.amount')}</Label>
          <Input
            id={`${id}-amount`}
            inputMode="decimal"
            autoFocus
            dir="ltr"
            className="text-lg font-extrabold tabular"
            value={amount}
            aria-invalid={error && minor === null ? true : undefined}
            onChange={(event) => setAmount(event.target.value)}
          />
        </div>
        <div className="flex w-28 flex-col gap-2">
          <Label htmlFor={`${id}-currency`}>{t('money.currency')}</Label>
          <Select value={chosenCurrency} onValueChange={setCurrency}>
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

      <div className="flex flex-col gap-2">
        <Label id={`${id}-category`}>{t('money.category')}</Label>
        <ToggleGroup type="single" value={category} onValueChange={(value) => value && setCategory(value)} aria-labelledby={`${id}-category`}>
          {categories.map((key) => (
            <ToggleGroupItem key={key} value={key}>
              {categoryLabel(t, key)}
            </ToggleGroupItem>
          ))}
        </ToggleGroup>
      </div>

      <div className="grid gap-3 sm:grid-cols-2">
        <div className="flex flex-col gap-2">
          <Label htmlFor={`${id}-note`}>{t('money.note')}</Label>
          <Input id={`${id}-note`} value={note} onChange={(event) => setNote(event.target.value)} />
        </div>
        <div className="flex flex-col gap-2">
          <Label htmlFor={`${id}-day`}>{t('money.day')}</Label>
          <Input id={`${id}-day`} type="date" value={day} max={today.key} onChange={(event) => setDay(event.target.value)} />
        </div>
      </div>

      <div className="flex items-center justify-between gap-3 rounded-lg bg-muted/60 p-3">
        <div className="flex flex-col">
          <Label htmlFor={`${id}-wallet`}>{t('money.fromWallet')}</Label>
          <span className="text-xs text-muted-foreground tabular">
            {t('money.walletHas', { amount: formatMoney(wallet?.balance ?? 0, chosenCurrency) })}
          </span>
        </div>
        <Switch id={`${id}-wallet`} checked={paidFromWallet} onCheckedChange={setFromWallet} />
      </div>

      {error && (
        <p role="alert" className="text-sm font-semibold text-destructive">
          {error}
        </p>
      )}
      <DialogFooter className="gap-2">
        {expense && (
          <Button variant="ghost" className="text-destructive sm:me-auto" onClick={() => void remove()}>
            {t('common.remove')}
          </Button>
        )}
        <Button variant="outline" onClick={onClose}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" disabled={saving}>
          {expense ? t('common.save') : t('money.logIt')}
        </Button>
      </DialogFooter>
    </form>
  );
}
