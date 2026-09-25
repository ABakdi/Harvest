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

// ------------------------------------------------------------- amounts

/**
 * The largest amount the app will accept, in major units. Beyond this
 * an entry is a typo (`maxMajorUnits` in `presentation/money.dart`).
 */
export const maxMajorUnits = 1_000_000_000_000;

/** Dart's `int.tryParse` without a radix, as `harvest-day.ts` has it. */
function parseDartInt(raw: string): number | null {
  const match = /^([+-]?)(?:0x([0-9a-f]+)|(\d+))$/i.exec(raw.trim());
  if (!match) return null;
  const [, sign, hex, decimal] = match;
  const magnitude = hex !== undefined ? parseInt(hex, 16) : Number(decimal);
  return sign === '-' ? -magnitude : magnitude;
}

/** Arabic-Indic and extended Arabic-Indic digits → ASCII. */
function latinDigits(input: string): string {
  return input.replace(/[٠-٩۰-۹]/g, (digit) => {
    const code = digit.charCodeAt(0);
    return String(code - (code >= 0x06f0 ? 0x06f0 : 0x0660));
  });
}

/**
 * `parseToMinor`: "12", "12.5", "12,50", "1,234" into minor units; null
 * for anything that is not a positive amount within [maxMajorUnits]. A
 * comma is a thousands separator when three digits follow it, and a
 * decimal point otherwise.
 */
export function parseToMinor(input: string): number | null {
  let text = latinDigits(input).trim();
  if (text === '' || text.startsWith('+') || text.startsWith('-')) return null;
  text = /^\d{1,3}(,\d{3})+(\.\d+)?$/.test(text) ? text.replaceAll(',', '') : text.replaceAll(',', '.');
  const parts = text.split('.');
  if (parts.length > 2) return null;
  const major = parseDartInt(parts[0]!);
  if (major === null || major < 0 || major > maxMajorUnits) return null;
  let cents = 0;
  if (parts.length === 2) {
    const fraction = parts[1]!;
    if (fraction === '' || fraction.length > 2) return null;
    const parsed = parseDartInt(fraction);
    if (parsed === null) return null;
    cents = fraction.length === 1 ? parsed * 10 : parsed;
  }
  const total = major * 100 + cents;
  return total > 0 ? total : null;
}

/** The characters an amount may be typed with (`amountCharacters`). */
export const amountCharacters = /[\d.,+\-*/×÷() ]/;

/** Whether [input] is a sum rather than a number: it has an operator or a bracket. */
export function isAmountExpression(input: string): boolean {
  return /[+\-*/×÷()]/.test(input);
}

/**
 * `evaluateAmountToMinor` (`domain/amount_expression.dart`): `12+3.5*2`
 * → 1900. A receipt is three things and a coffee, so the amount box
 * takes a sum and shows what it comes to ([[Finances]] Quick-log).
 * Plain numbers go through [parseToMinor], which knows grouping commas;
 * inside a sum a comma is a decimal point, because `1,5+2` is not a
 * thousand and a half. Anything that does not parse, divides by zero,
 * or comes to zero or less is null.
 */
export function evaluateAmountToMinor(input: string): number | null {
  if (!isAmountExpression(input)) return parseToMinor(input);
  const result = new AmountParser(input).parse();
  if (result === null || !Number.isFinite(result) || result <= 0) return null;
  const minor = Math.round(result * 100);
  return minor > maxMajorUnits * 100 ? null : minor;
}

/**
 * Recursive descent over `expr := term (('+'|'-') term)*`,
 * `term := factor (('*'|'/') factor)*`,
 * `factor := number | '(' expr ')' | '-' factor`.
 */
class AmountParser {
  private readonly text: string;
  private at = 0;

  constructor(input: string) {
    this.text = input.replaceAll('×', '*').replaceAll('÷', '/').replaceAll(',', '.').replaceAll(' ', '');
  }

  parse(): number | null {
    const value = this.expression();
    return value === null || this.at !== this.text.length ? null : value;
  }

  private peek(): string | null {
    return this.at < this.text.length ? this.text[this.at]! : null;
  }

  private expression(): number | null {
    let left = this.term();
    if (left === null) return null;
    while (this.peek() === '+' || this.peek() === '-') {
      const op = this.text[this.at++];
      const right = this.term();
      if (right === null) return null;
      left = op === '+' ? left + right : left - right;
    }
    return left;
  }

  private term(): number | null {
    let left = this.factor();
    if (left === null) return null;
    while (this.peek() === '*' || this.peek() === '/') {
      const op = this.text[this.at++];
      const right = this.factor();
      if (right === null) return null;
      if (op === '/' && right === 0) return null;
      left = op === '*' ? left * right : left / right;
    }
    return left;
  }

  private factor(): number | null {
    if (this.peek() === '-') {
      this.at++;
      const value = this.factor();
      return value === null ? null : -value;
    }
    if (this.peek() === '(') {
      this.at++;
      const value = this.expression();
      if (value === null || this.peek() !== ')') return null;
      this.at++;
      return value;
    }
    const start = this.at;
    while (/[\d.]/.test(this.peek() ?? '')) this.at++;
    if (start === this.at) return null;
    // Dart's `double.tryParse` over digits and points: one point at most.
    const raw = this.text.slice(start, this.at);
    if (!/^(\d+\.?\d*|\.\d+)$/.test(raw)) return null;
    return Number(raw);
  }
}
