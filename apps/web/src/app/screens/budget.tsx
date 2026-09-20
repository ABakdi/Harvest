import { budgetStatus } from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import { PiggyBankIcon, SmartphoneIcon } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { formatMoney, formatNumber } from '@/lib/format';
import { EmptyState } from '../components/bits';
import { categoryLabel } from '../components/category';
import { useHarvest, useHarvestDay } from '../context';
import { readBudget } from '../data/vault';
import { useDefaultCurrency } from '../hooks';

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
  const budget = useLiveQuery(() => readBudget(db, today), [db, today.key]);
  if (!budget) return null;

  // No snapshot without a budget to measure against.
  if (budget.monthlyBudget <= 0 || budget.snapshot === null) {
    return (
      <EmptyState
        icon={<PiggyBankIcon />}
        title={t('budget.noBudget')}
        body={t('budget.noBudgetBody')}
      />
    );
  }

  const { snapshot } = budget;
  const status = budgetStatus(snapshot);
  const leftToday = snapshot.floatingDailyLimit - snapshot.spentToday;
  const spentRatio = Math.min(budget.spentThisMonth / budget.monthlyBudget, 1);
  // The days the floating limit is spread over, today included.
  const daysLeft = new Date(Date.UTC(today.year, today.month, 0)).getUTCDate() - today.day + 1;
  const money = (minor: number) => formatMoney(minor, currency);

  return (
    <div className="flex flex-col gap-4">
      <section className="flex flex-col gap-2 rounded-2xl border bg-card p-5">
        <span className="text-sm font-bold text-muted-foreground">{t('budget.today')}</span>
        <span className="text-3xl font-extrabold tabular" dir="ltr">
          {leftToday >= 0 ? money(leftToday) : t('budget.overBy', { amount: money(-leftToday) })}
        </span>
        <span className="text-sm text-muted-foreground tabular" dir="ltr">
          {t('budget.ofDaily', { limit: money(snapshot.floatingDailyLimit) })}
        </span>
        <div className="mt-1 h-2 overflow-hidden rounded-full bg-muted">
          <div className={`h-full rounded-full ${colour[status]}`} style={{ width: `${spentRatio * 100}%` }} />
        </div>
        <span className="text-sm tabular" dir="ltr">
          {t('budget.monthLine', {
            spent: money(budget.spentThisMonth),
            budget: money(budget.monthlyBudget),
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

      <p className="flex items-center gap-2 text-xs text-muted-foreground">
        <SmartphoneIcon className="size-4" aria-hidden />
        {t('budget.converted')}
      </p>
    </div>
  );
}
