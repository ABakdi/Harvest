/**
 * Money that is not one currency, and a budget that floats.
 *
 * Ported from the phone: `Rates` in
 * `apps/mobile/lib/features/finances/domain/currency.dart`,
 * `BudgetSnapshot` in `.../domain/expense.dart`, and the
 * `budgetSnapshot` provider in `.../presentation/finance_providers.dart`,
 * which is the rule that turns a month of day totals into today's
 * picture. `fixtures/money.json` holds the numbers.
 */

import type { HarvestDay } from './harvest-day.js';

export const currencies = ['DZD', 'USD', 'EUR'] as const;
export type CurrencyCode = (typeof currencies)[number];

export function currencyOf(code: string | null | undefined): CurrencyCode {
  return (currencies as readonly string[]).includes(code ?? '') ? (code as CurrencyCode) : 'DZD';
}

/**
 * The rates as the settings hold them: the DZD legs typed by hand, the
 * EUR→USD one fetched. A rate that is not finite and positive is no
 * rate at all, exactly as `Rates._sane` decides it.
 */
export interface Rates {
  readonly defaultCurrency: CurrencyCode;
  readonly dzdPerUsd?: number | null;
  readonly dzdPerEur?: number | null;
  readonly usdPerEur?: number | null;
}

function sane(value: number | null | undefined): number | null {
  return value !== null && value !== undefined && Number.isFinite(value) && value > 0 ? value : null;
}

/** Dart's `double.round()`: halves go away from zero, not towards +∞. */
function dartRound(value: number): number {
  return Math.sign(value) * Math.round(Math.abs(value));
}

function factor(rates: Rates, from: CurrencyCode, to: CurrencyCode): number | null {
  const usdPerEur = sane(rates.usdPerEur);
  if (from === 'EUR' && to === 'USD' && usdPerEur !== null) return usdPerEur;
  if (from === 'USD' && to === 'EUR' && usdPerEur !== null) return 1 / usdPerEur;
  const viaDzd = (currency: CurrencyCode): number | null =>
    currency === 'DZD' ? 1 : currency === 'USD' ? sane(rates.dzdPerUsd) : sane(rates.dzdPerEur);
  const fromDzd = viaDzd(from);
  const toDzd = viaDzd(to);
  if (fromDzd === null || toDzd === null) return null;
  return fromDzd / toDzd;
}

/** [minor] units of [from] in the default currency; null when a rate is missing. */
export function toDefault(rates: Rates, minor: number, from: CurrencyCode): number | null {
  if (from === rates.defaultCurrency) return minor;
  const rate = factor(rates, from, rates.defaultCurrency);
  if (rate === null || !Number.isFinite(rate)) return null;
  return dartRound(minor * rate);
}

/**
 * [toDefault] with the face value as the fallback. The app never blocks
 * on a missing rate; it only stops pretending the number was converted.
 */
export function toDefaultOrFace(rates: Rates, minor: number, from: CurrencyCode): number {
  return toDefault(rates, minor, from) ?? minor;
}

/** Sums per-currency amounts into the default currency. */
export function sumInDefault(rates: Rates, amounts: Iterable<readonly [CurrencyCode, number]>): number {
  let total = 0;
  for (const [currency, minor] of amounts) total += toDefaultOrFace(rates, minor, currency);
  return total;
}

// ------------------------------------------------------------- budget

export type BudgetStatus = 'under' | 'close' | 'over';

export interface BudgetSnapshot {
  readonly monthlyBudget: number;
  readonly spentThisMonth: number;
  readonly spentToday: number;
  /**
   * What is left of the budget — today's own spending excluded —
   * divided across today and the days still to come, so overspending
   * early in the month visibly tightens the tap.
   */
  readonly floatingDailyLimit: number;
}

export interface BudgetInput {
  readonly monthlyBudget: number;
  readonly spentBeforeToday: number;
  readonly spentToday: number;
  readonly day: HarvestDay;
}

/** `BudgetSnapshot.compute`. */
export function computeBudget({ monthlyBudget, spentBeforeToday, spentToday, day }: BudgetInput): BudgetSnapshot {
  const daysInMonth = new Date(Date.UTC(day.year, day.month, 0)).getUTCDate();
  const remainingDays = daysInMonth - day.day + 1;
  const remainingBudget = Math.min(Math.max(monthlyBudget - spentBeforeToday, 0), monthlyBudget);
  return {
    monthlyBudget,
    spentThisMonth: spentBeforeToday + spentToday,
    spentToday,
    floatingDailyLimit: Math.trunc(remainingBudget / remainingDays),
  };
}

/**
 * Green under the day's share, amber within 15% of it, red past it.
 * With no share left, the verdict comes from the month rather than
 * from a division by zero (`BudgetSnapshot.status`).
 */
export function budgetStatus(snapshot: BudgetSnapshot): BudgetStatus {
  if (snapshot.floatingDailyLimit <= 0) {
    return snapshot.spentThisMonth > snapshot.monthlyBudget ? 'over' : 'under';
  }
  if (snapshot.spentToday > snapshot.floatingDailyLimit) return 'over';
  if (snapshot.spentToday >= 0.85 * snapshot.floatingDailyLimit) return 'close';
  return 'under';
}

/**
 * The `budgetSnapshot` provider: the month's totals per Harvest Day
 * (already in the default currency) split into what was spent before
 * today and what was spent today. No budget, or a budget of nothing,
 * means no picture at all rather than an empty gauge.
 */
export function budgetSnapshotFor(
  totalsByDay: Iterable<readonly [string, number]>,
  monthlyBudget: number | null,
  today: HarvestDay,
): BudgetSnapshot | null {
  if (monthlyBudget === null || monthlyBudget <= 0) return null;
  let spentBeforeToday = 0;
  let spentToday = 0;
  for (const [key, amount] of totalsByDay) {
    if (key === today.key) spentToday += amount;
    else if (key < today.key) spentBeforeToday += amount;
  }
  return computeBudget({ monthlyBudget, spentBeforeToday, spentToday, day: today });
}
