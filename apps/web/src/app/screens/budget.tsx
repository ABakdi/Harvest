import { budgetStatus, evaluateAmountToMinor } from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import { PiggyBankIcon, SlidersHorizontalIcon, SmartphoneIcon } from 'lucide-react';
import { useId, useState, type FormEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { formatAmountInput, formatMoney, formatNumber } from '@/lib/format';
import { EmptyState } from '../components/bits';
import { categoryLabel } from '../components/category';
import { AmountField } from '../components/money-bits';
import { CategoryManager } from '../components/money-categories';
import { useHarvest, useHarvestDay } from '../context';
import { settingKeys } from '../data/settings';
import { readBudget } from '../data/vault';
import { useDefaultCurrency } from '../hooks';

/**
 * The budget sheet: one number, the month's budget, in the default
 * currency and in minor units under `finance.monthlyBudgetMinor`, as
 * the phone stores it. Clearing writes an empty value, which both
 * devices read as no budget at all.
 */
function BudgetDialog({ current, onClose }: { current: number; onClose: () => void }) {
  const { t } = useTranslation();
  const { settings } = useHarvest();
  const currency = useDefaultCurrency();
  const id = useId();
  const [amount, setAmount] = useState(current > 0 ? formatAmountInput(current) : '');
  const [saving, setSaving] = useState(false);
  const minor = evaluateAmountToMinor(amount);

  async function save(value: string, message: string) {
    setSaving(true);
    try {
      await settings.setString(settingKeys.monthlyBudget, value);
      toast.success(message);
      onClose();
    } catch {
      toast.error(t('common.saveFailed'));
      setSaving(false);
    }
  }

  function submit(event: FormEvent) {
    event.preventDefault();
    if (minor !== null) void save(String(minor), t('budget.saved'));
  }

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('budget.title')}</DialogTitle>
          <DialogDescription>{t('budget.explainer')}</DialogDescription>
        </DialogHeader>
        <form onSubmit={submit} className="flex flex-col gap-4" noValidate>
          <AmountField id={`${id}-amount`} label={t('budget.amountLabel')} value={amount} onChange={setAmount} currency={currency} autoFocus />
          <DialogFooter className="gap-2">
            {current > 0 && (
              <Button variant="ghost" className="text-destructive sm:me-auto" disabled={saving} onClick={() => void save('', t('budget.cleared'))}>
                {t('budget.clear')}
              </Button>
            )}
            <Button variant="outline" onClick={onClose}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" disabled={saving || minor === null}>
              {t('common.save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

const colour = { under: 'bg-success', close: 'bg-sun', over: 'bg-destructive' } as const;

/**
 * The month's budget: what is left today, what is left of the month,
 * and where the month went.
 *
 * The daily limit floats — the month's remainder spread over the days
 * that are left — so an expensive Tuesday tightens Wednesday rather
 * than failing the month ([[Finances]]). It is computed here from the
 * expenses themselves, never asked of the server (W2).
 */
export function BudgetPanel() {
  const { t } = useTranslation();
  const { db } = useHarvest();
  const today = useHarvestDay();
  const currency = useDefaultCurrency();
  const [editing, setEditing] = useState(false);
  const budget = useLiveQuery(() => readBudget(db, today), [db, today.key]);
  if (!budget) return null;

  const dialog = editing && <BudgetDialog current={budget.monthlyBudget} onClose={() => setEditing(false)} />;

  // No snapshot without a budget to measure against.
  if (budget.monthlyBudget <= 0 || budget.snapshot === null) {
    return (
      <div className="flex flex-col gap-4">
        <EmptyState
          icon={<PiggyBankIcon />}
          title={t('budget.noBudget')}
          body={t('budget.noBudgetBody')}
          action={<Button onClick={() => setEditing(true)}>{t('budget.set')}</Button>}
        />
        <CategoryManager />
        {dialog}
      </div>
    );
  }

  const { snapshot } = budget;
  const status = budgetStatus(snapshot);
  const leftToday = snapshot.floatingDailyLimit - snapshot.spentToday;
  const spentRatio = Math.min(budget.spentThisMonth / budget.monthlyBudget, 1);
  // The days the floating limit is spread over, today included.
  const daysLeft = new Date(Date.UTC(today.year, today.month, 0)).getUTCDate() - today.day + 1;
  const money = (minor: number) => formatMoney(minor, currency);
  // An amount inside a sentence keeps its own left-to-right order while
  // the sentence follows the language (an isolate, like `dir="ltr"` on
  // a span of its own).
  const inline = (minor: number) => `\u2066${money(minor)}\u2069`;

  return (
    <div className="flex flex-col gap-4">
      <section className="flex flex-col gap-2 rounded-2xl border bg-card p-5">
        <div className="flex items-center justify-between gap-2">
          <span className="text-sm font-bold text-muted-foreground">{t('budget.today')}</span>
          <Button variant="ghost" size="icon-sm" aria-label={t('budget.edit')} title={t('budget.edit')} onClick={() => setEditing(true)}>
            <SlidersHorizontalIcon />
          </Button>
        </div>
        {leftToday >= 0 ? (
          <span className="text-3xl font-extrabold tabular" dir="ltr">
            {money(leftToday)}
          </span>
        ) : (
          <span className="text-3xl font-extrabold tabular">{t('budget.overBy', { amount: inline(-leftToday) })}</span>
        )}
        <span className="text-sm text-muted-foreground tabular">
          {t('budget.ofDaily', { limit: inline(snapshot.floatingDailyLimit) })}
        </span>
        <div className="mt-1 h-2 overflow-hidden rounded-full bg-muted">
          <div className={`h-full rounded-full ${colour[status]}`} style={{ width: `${spentRatio * 100}%` }} />
        </div>
        <span className="text-sm tabular">
          {budget.spentThisMonth <= budget.monthlyBudget
            ? t('budget.monthLine', {
                spent: inline(budget.spentThisMonth),
                budget: inline(budget.monthlyBudget),
              })
            : t('budget.monthOver', {
                spent: inline(budget.spentThisMonth),
                budget: inline(budget.monthlyBudget),
                over: inline(budget.spentThisMonth - budget.monthlyBudget),
              })}
        </span>
        <span className="text-xs text-muted-foreground">
          {daysLeft > 1 ? t('budget.daysLeft', { count: daysLeft }) : t('budget.lastDay')}
        </span>
      </section>

      <section className="flex flex-col gap-2">
        <h2 className="px-1 text-sm font-extrabold text-muted-foreground">{t('budget.byCategory')}</h2>
        {budget.byCategory.length === 0 ? (
          <p className="px-1 text-sm text-muted-foreground">{t('budget.nothingYet')}</p>
        ) : (
          <ul className="flex flex-col divide-y rounded-xl border bg-card">
            {budget.byCategory.map(([category, minor]) => (
              <li key={category} className="flex items-center gap-3 px-4 py-2.5">
                <span className="flex-1 font-bold">{categoryLabel(t, category)}</span>
                <span className="text-xs text-muted-foreground tabular">
                  {formatNumber(Math.round((minor / budget.spentThisMonth) * 100))}%
                </span>
                <span className="font-extrabold tabular" dir="ltr">
                  {money(minor)}
                </span>
              </li>
            ))}
          </ul>
        )}
      </section>

      <CategoryManager />

      <p className="flex items-center gap-2 text-xs text-muted-foreground">
        <SmartphoneIcon className="size-4" aria-hidden />
        {t('budget.converted')}
      </p>
      {dialog}
    </div>
  );
}
