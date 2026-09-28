import { HarvestDay, type CurrencyCode } from '@harvest/core';
import i18n from '@/i18n';

/**
 * Formatting that follows the language but keeps Western digits, as the
 * phone does: amounts and counts must line up in both languages
 * ([[Finances]]).
 */
function locale(): string {
  return i18n.language === 'ar' ? 'ar-u-nu-latn' : 'en';
}

export function formatNumber(value: number, options?: Intl.NumberFormatOptions): string {
  return new Intl.NumberFormat(locale(), options).format(value);
}

// The currencies are the shared rule's ([[Finances]]); only how each is drawn lives here.
export { currencies, type CurrencyCode } from '@harvest/core';

const symbols: Partial<Record<CurrencyCode, string>> = { DZD: 'DA', USD: '$', EUR: '€' };

export function currencySymbol(code: string): string {
  return symbols[code as CurrencyCode] ?? code;
}

/** `DA36,900.50`: the symbol first, grouped, cents only when there are some. */
export function formatMoney(minor: number, currency: string): string {
  const sign = minor < 0 ? '-' : '';
  const abs = Math.abs(minor);
  const whole = Math.trunc(abs / 100);
  const cents = abs % 100;
  const body = new Intl.NumberFormat('en').format(whole) + (cents ? `.${String(cents).padStart(2, '0')}` : '');
  return `${sign}${currencySymbol(currency)}${body}`;
}

export function formatAmountInput(minor: number): string {
  const whole = Math.trunc(minor / 100);
  const cents = minor % 100;
  return cents ? `${whole}.${String(cents).padStart(2, '0')}` : String(whole);
}

export function formatDate(value: string | Date, options: Intl.DateTimeFormatOptions = { dateStyle: 'medium' }): string {
  const date = typeof value === 'string' ? new Date(value) : value;
  return new Intl.DateTimeFormat(locale(), options).format(date);
}

/** A Harvest Day, labelled by its calendar date. */
export function formatDay(key: string, options: Intl.DateTimeFormatOptions = { weekday: 'short', month: 'short', day: 'numeric' }): string {
  const day = HarvestDay.tryParse(key);
  return day ? formatDate(day.toDate(), options) : key;
}

export function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${formatNumber(bytes / 1024, { maximumFractionDigits: 1 })} KB`;
  return `${formatNumber(bytes / (1024 * 1024), { maximumFractionDigits: 1 })} MB`;
}

/** A name short enough to quote in a toast: about [max] characters, then an ellipsis (W6-29). */
export function shortName(text: string, max = 40): string {
  const chars = Array.from(text.trim());
  return chars.length <= max ? chars.join('') : `${chars.slice(0, max - 1).join('').trimEnd()}…`;
}
