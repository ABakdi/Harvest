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
import { currencyData } from './currency-data.js';
import { westernDigits } from './digits.js';

/**
 * A currency, by its ISO 4217 code: any of [currencies], every one in
 * circulation since Phase 7 ([[Finances]], M7.8), where 3.1 knew three.
 */
export type CurrencyCode = string;

/** Every currency Harvest knows, by code ([[currencyInfo]] has the rest). */
export const currencies: readonly CurrencyCode[] = currencyData.map((currency) => currency.code);
const known = new Set<string>(currencies);

export function isCurrencyCode(code: string | null | undefined): code is CurrencyCode {
  return code !== null && code !== undefined && known.has(code);
}

/** [code] when Harvest knows it, else [fallback] (the dinar, as it always was). */
export function currencyOf(code: string | null | undefined, fallback: CurrencyCode = 'DZD'): CurrencyCode {
  return isCurrencyCode(code) ? code : fallback;
}

/**
 * The rates as the settings hold them:
 * - `perUsd`, what one US dollar buys of every currency, fetched by the
 *   device and cached with its day ([[Finances]], M7.8);
 * - the dinar's parallel market, typed by hand (`dzdPerUsd`,
 *   `dzdPerEur`), which wins over any fetched rate for a leg through the
 *   dinar — the official one is not what a euro buys in Algiers;
 * - `usdPerEur`, what 3.1 fetched, still read when `perUsd` is not there.
 * A rate that is not finite and positive is no rate at all, exactly as
 * `Rates._sane` decides it.
 */
export interface Rates {
  readonly defaultCurrency: CurrencyCode;
  readonly perUsd?: Readonly<Record<string, number>> | null;
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

const firstThree = new Set(['DZD', 'USD', 'EUR']);

/** How 3.1 converted between the dinar, the dollar and the euro, unchanged. */
function firstThreeFactor(rates: Rates, from: CurrencyCode, to: CurrencyCode): number | null {
  const usdPerEur = sane(rates.usdPerEur) ?? fetchedUsdPerEur(rates);
  if (from === 'EUR' && to === 'USD' && usdPerEur !== null) return usdPerEur;
  if (from === 'USD' && to === 'EUR' && usdPerEur !== null) return 1 / usdPerEur;
  const viaDzd = (currency: CurrencyCode): number | null =>
    currency === 'DZD' ? 1 : currency === 'USD' ? sane(rates.dzdPerUsd) : sane(rates.dzdPerEur);
  const fromDzd = viaDzd(from);
  const toDzd = viaDzd(to);
  if (fromDzd === null || toDzd === null) return null;
  return fromDzd / toDzd;
}

function fetchedUsdPerEur(rates: Rates): number | null {
  const eur = sane(rates.perUsd?.EUR);
  return eur === null ? null : 1 / eur;
}

/**
 * What one US dollar buys of [currency]: fetched, except for the dinar
 * when its parallel rate was typed, straight or through the euro.
 */
function unitsPerUsd(rates: Rates, currency: CurrencyCode): number | null {
  if (currency === 'USD') return 1;
  if (currency === 'DZD') {
    const byHand = sane(rates.dzdPerUsd);
    if (byHand !== null) return byHand;
    const perEur = sane(rates.dzdPerEur);
    const eur = unitsPerUsd(rates, 'EUR');
    if (perEur !== null && eur !== null) return perEur * eur;
  }
  const fetched = sane(rates.perUsd?.[currency]);
  if (fetched !== null) return fetched;
  if (currency === 'EUR') {
    const usdPerEur = sane(rates.usdPerEur);
    return usdPerEur === null ? null : 1 / usdPerEur;
  }
  return null;
}

function factor(rates: Rates, from: CurrencyCode, to: CurrencyCode): number | null {
  if (from === to) return 1;
  if (firstThree.has(from) && firstThree.has(to)) {
    const old = firstThreeFactor(rates, from, to);
    if (old !== null) return old;
  }
  const fromUnits = unitsPerUsd(rates, from);
  const toUnits = unitsPerUsd(rates, to);
  if (fromUnits === null || toUnits === null) return null;
  return toUnits / fromUnits;
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

/**
 * A budget of [budget] minor units of [from] as a budget in [to]
 * (`convertBudget`): the budget is a sum in the default currency, so
 * switching that currency must carry it across — DA50,000 becomes its
 * worth in euros, not €50,000 ([[Audit-v3]] G5-04). Without a rate it
 * keeps its number, the way every sum falls back to face value; it never
 * drops below one minor unit.
 */
export function convertBudget(budget: number, from: CurrencyCode, to: CurrencyCode, rates: Rates): number {
  if (from === to) return budget;
  const converted = toDefault({ ...rates, defaultCurrency: to }, budget, from);
  if (converted === null) return budget;
  return converted < 1 ? 1 : converted;
}

/** How the savings stand against the budget (`SavingsHealth`). */
export type SavingsHealth = 'unknown' | 'healthy' | 'low';

/**
 * Savings below a tenth of the monthly budget, all converted into the
 * default currency (face value where a rate is missing), are low
 * (`savingsHealth`, [[Finances]] The Vault). With no savings or no
 * budget there is nothing to say. One rule for both apps (Q6-20).
 */
export function savingsHealth(
  savings: Iterable<readonly [CurrencyCode, number]>,
  monthlyBudget: number | null | undefined,
  rates: Rates,
): SavingsHealth {
  const held = [...savings].filter(([, minor]) => minor !== 0);
  if (held.length === 0 || !monthlyBudget || monthlyBudget <= 0) return 'unknown';
  return sumInDefault(rates, held) < Math.trunc(monthlyBudget / 10) ? 'low' : 'healthy';
}

/**
 * What a span averages per day (`averagePerDay`): the total over the
 * days gone, truncated, and in whole dinars for the dinar, which is
 * written in whole units everywhere else — DA71.42 a day was the one
 * fractional dinar on the screen (U6-34). No days gone is nothing.
 */
export function averagePerDay(total: number, elapsedDays: number, currency: CurrencyCode): number {
  if (elapsedDays <= 0) return 0;
  const average = Math.trunc(total / elapsedDays);
  return currency === 'DZD' ? Math.round(average / 100) * 100 : average;
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

/**
 * The most an amount can plausibly be (`plausibleMaxMinor`), in minor
 * units of its own currency: 1,000,000,000 — DA10,000,000, or
 * €10,000,000. Above it an entry is still allowed, but only once I have
 * said yes to it: DA99,999,999,999 typed by a slipped finger would
 * otherwise dominate every total ([[Finances]], W6-15).
 */
export const plausibleMaxMinor = 1_000_000_000;

/** Whether [minor] can be logged without asking first (`isPlausibleAmount`). */
export function isPlausibleAmount(minor: number): boolean {
  return Number.isSafeInteger(minor) && minor > 0 && minor <= plausibleMaxMinor;
}

/** Dart's `int.tryParse` without a radix, as `harvest-day.ts` has it. */
function parseDartInt(raw: string): number | null {
  const match = /^([+-]?)(?:0x([0-9a-f]+)|(\d+))$/i.exec(raw.trim());
  if (!match) return null;
  const [, sign, hex, decimal] = match;
  const magnitude = hex !== undefined ? parseInt(hex, 16) : Number(decimal);
  return sign === '-' ? -magnitude : magnitude;
}

/**
 * `parseToMinor`: "12", "12.5", "12,50", "1,234" into minor units; null
 * for anything that is not a positive amount within [maxMajorUnits]. A
 * comma is a thousands separator when three digits follow it, and a
 * decimal point otherwise.
 */
export function parseToMinor(input: string): number | null {
  let text = westernDigits(input).trim();
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
    // Cents go two digits deep, inside a sum as in a plain number:
    // `12.345+0` is the same typo as `12.345` ([[Audit-v3]] Q5-66).
    const point = raw.indexOf('.');
    if (point >= 0 && raw.length - point - 1 > 2) return null;
    return Number(raw);
  }
}
