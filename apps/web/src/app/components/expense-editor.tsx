import { evaluateAmountToMinor } from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import { PlusIcon } from 'lucide-react';
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
import { currencies, formatAmountInput, formatMoney } from '@/lib/format';
import { useHarvest, useHarvestDay } from '../context';
import { presetCategories, type ExpenseRow } from '../data/money';
import { useDefaultCurrency, usePrivateKey } from '../hooks';
import { categoryLabel } from './category';
import { AmountField, CategoryIcon, SwitchRow, useCustomCategories } from './money-bits';
import { CategoryCreator } from './money-categories';
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
  const [creating, setCreating] = useState(false);
  const chosenCurrency = currency ?? defaultCurrency;

  const custom = useCustomCategories();
  const wallet = useLiveQuery(async () => {
    const moves = await db.rows('money_txns').where('account').equals('wallet').toArray();
    const balance = moves
      .filter((move) => move.deletedAt === null && move.currency === chosenCurrency && move.linkUuid !== expense?.uuid)
      .reduce((sum, move) => sum + move.deltaMinor, 0);
    const linked = expense ? moves.some((move) => move.linkUuid === expense.uuid && move.deletedAt === null) : false;
    return { balance, linked };
  }, [db, chosenCurrency, expense?.uuid]);

  // A number or a sum: `120+30` logs 150 ([[Finances]] Quick-log).
  const minor = evaluateAmountToMinor(amount);
  const walletCanCover = minor !== null && (wallet?.balance ?? 0) >= minor;
  // On by default when the wallet can cover it, and kept on for an
  // expense that was already paid from it, as on the phone; a wallet
  // that cannot cover the amount is never paid from, whatever was
  // chosen before, so it cannot go below zero.
  // The balance above already has this expense's own movement given
  // back, so an edit compares against what the wallet would hold.
  const walletChoice = fromWallet ?? (expense ? (wallet?.linked ?? false) : null);
  const paidFromWallet = walletCanCover && (walletChoice ?? true);

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
    <>
      <form onSubmit={(event) => void submit(event)} className="flex flex-col gap-4" noValidate>
        <div className="flex gap-2">
          <AmountField
            id={`${id}-amount`}
            label={t('money.amount')}
            value={amount}
            onChange={setAmount}
            currency={chosenCurrency}
            autoFocus
            invalid={error !== null && minor === null}
            className="flex-1"
          />
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
                <CategoryIcon category={key} customs={custom} />
                {categoryLabel(t, key)}
              </ToggleGroupItem>
            ))}
          </ToggleGroup>
          <Button variant="outline" size="sm" className="w-fit" onClick={() => setCreating(true)}>
            <PlusIcon />
            {t('money.newCategory')}
          </Button>
        </div>

        <div className="grid gap-3 sm:grid-cols-2">
          <div className="flex flex-col gap-2">
            <Label htmlFor={`${id}-note`}>{t('money.note')}</Label>
            <Input id={`${id}-note`} value={note} maxLength={200} onChange={(event) => setNote(event.target.value)} />
          </div>
          <div className="flex flex-col gap-2">
            <Label htmlFor={`${id}-day`}>{t('money.day')}</Label>
            <Input id={`${id}-day`} type="date" value={day} min={today.addDays(-365).key} max={today.addDays(365).key} onChange={(event) => setDay(event.target.value)} />
          </div>
        </div>

        <SwitchRow>
          <div className="flex flex-col">
            <Label htmlFor={`${id}-wallet`}>{t('money.fromWallet')}</Label>
            <span className="text-xs text-muted-foreground tabular">
              {minor !== null && !walletCanCover
                ? t('vault.walletShort')
                : t('money.walletHas', { amount: formatMoney(wallet?.balance ?? 0, chosenCurrency) })}
            </span>
          </div>
          <Switch id={`${id}-wallet`} checked={paidFromWallet} disabled={!walletCanCover} onCheckedChange={setFromWallet} />
        </SwitchRow>

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
      {/* Outside the form: its own submit must not log the expense. */}
      {creating && <CategoryCreator onClose={() => setCreating(false)} onCreated={setCategory} />}
    </>
  );
}
