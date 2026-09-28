import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import {
  countryOfZone,
  currenciesByName,
  currencies,
  currencyInfo,
  currencyOf,
  currencyOfCountry,
  defaultCurrencyFor,
  displayDecimals,
  regionOfLocale,
  toDefault,
  type Rates,
} from '../src/index.js';

const read = <T>(name: string) => JSON.parse(readFileSync(new URL(`../fixtures/${name}`, import.meta.url), 'utf8')) as T;
const data = read<{
  currencies: { code: string; minorUnits: number; symbol: string; en: string; ar: string }[];
  byCountry: Record<string, string>;
  zones: Record<string, string>;
}>('currencies.json');
const defaults = read<{
  cases: { why: string; countries: (string | null)[]; timeZone: string | null; locales: string[]; currency: string }[];
  decimals: Record<string, number>;
}>('currency-defaults.json');

describe('every currency (fixtures/currencies.json)', () => {
  it('is the list the module knows, well over a hundred of them, with the first three still there', () => {
    expect(currencies).toEqual(data.currencies.map((c) => c.code));
    expect(currencies.length).toBeGreaterThan(150);
    for (const code of ['DZD', 'USD', 'EUR', 'GBP', 'JPY', 'MAD', 'TND', 'SAR', 'CNY', 'INR']) {
      expect(currencies).toContain(code);
    }
    expect(currencies).not.toContain('XAU');
  });

  it('names each in English and Arabic, and gives it a symbol', () => {
    for (const currency of data.currencies) {
      expect(currency.en.length).toBeGreaterThan(0);
      expect(currency.ar.length).toBeGreaterThan(0);
      expect(currency.symbol.length).toBeGreaterThan(0);
      expect(currencyInfo(currency.code)).toEqual(currency);
    }
    expect(currencyInfo('DZD').symbol).toBe('DA');
    expect(currencyInfo('EUR').ar).toBe('يورو');
  });

  it('gives every country a currency it knows', () => {
    for (const code of Object.values(data.byCountry)) expect(currencies).toContain(code);
    expect(currencyOfCountry('dz')).toBe('DZD');
    expect(currencyOfCountry('ZZ')).toBeNull();
  });

  it('sorts by name in either language', () => {
    expect(currenciesByName('en').map((c) => c.code)).toHaveLength(currencies.length);
    expect(currenciesByName('ar')[0]!.ar.localeCompare(currenciesByName('ar')[1]!.ar, 'ar')).toBeLessThanOrEqual(0);
  });

  it('falls back to the dinar only for a code it does not know', () => {
    expect(currencyOf('JPY')).toBe('JPY');
    expect(currencyOf('XYZ')).toBe('DZD');
    expect(currencyOf(null, 'EUR')).toBe('EUR');
  });
});

describe('the default currency (fixtures/currency-defaults.json)', () => {
  it.each(defaults.cases)('$why', ({ countries, timeZone, locales, currency }) => {
    expect(defaultCurrencyFor({ countries, timeZone, locales })).toBe(currency);
  });

  it.each(Object.entries(defaults.decimals))('shows %s with %d decimals', (code, decimals) => {
    expect(displayDecimals(code)).toBe(decimals);
  });

  it('reads regions and zones', () => {
    expect(regionOfLocale('ar_DZ')).toBe('DZ');
    expect(regionOfLocale('en')).toBeNull();
    expect(countryOfZone('Africa/Algiers')).toBe('DZ');
    expect(countryOfZone('Etc/UTC')).toBeNull();
  });
});

describe('rates for every currency', () => {
  const perUsd = { EUR: 0.9, GBP: 0.8, JPY: 150, DZD: 135 };

  it('converts any two through what a dollar buys', () => {
    const rates: Rates = { defaultCurrency: 'JPY', perUsd };
    expect(toDefault(rates, 1000, 'GBP')).toBe(187_500);
    expect(toDefault({ defaultCurrency: 'GBP', perUsd }, 187_500, 'JPY')).toBe(1000);
  });

  it('takes the dinar’s parallel rate, typed by hand, over the fetched one', () => {
    const rates: Rates = { defaultCurrency: 'DZD', perUsd, dzdPerEur: 250 };
    // A pound through the euro's parallel leg: 1 GBP = 1/0.8 USD; 1 USD = 250 × 0.9 DZD.
    expect(toDefault(rates, 100, 'GBP')).toBe(Math.round((100 / 0.8) * 250 * 0.9));
    // A euro, straight across the hand-typed leg, as 3.1 did.
    expect(toDefault(rates, 100, 'EUR')).toBe(25_000);
    // Without it, the official rate.
    expect(toDefault({ defaultCurrency: 'DZD', perUsd }, 100, 'EUR')).toBe(15_000);
  });

  it('says nothing without a rate', () => {
    expect(toDefault({ defaultCurrency: 'EUR', perUsd }, 100, 'THB')).toBeNull();
  });
});
