/**
 * Every currency, and which one is mine by default ([[Finances]],
 * Phase 7 M7.8). The data is ICU's and zone.tab's, made into
 * `currency-data.ts` and `fixtures/currencies.json` by
 * `scripts/currencies.mjs`; the phone reads the same file.
 *
 * Amounts stay in hundredths of the currency, whatever the currency:
 * the unit every row has always been written in, so nothing stored
 * changes. A currency's own minor units only say how many decimals are
 * shown — none for the yen, two for the dinar and for the Kuwaiti dinar,
 * whose thousandths no budget of mine needs.
 */
import { countryCurrencies, currencyData, zoneCountries } from './currency-data.js';
import { currencyOf, isCurrencyCode, type CurrencyCode } from './money.js';

export interface CurrencyInfo {
  readonly code: CurrencyCode;
  /** ISO 4217's minor units: 0 for the yen, 2 for most, 3 for the Gulf dinars. */
  readonly minorUnits: number;
  /** What is written beside an amount there; the code where there is no sign of its own. */
  readonly symbol: string;
  readonly en: string;
  readonly ar: string;
}

const byCode = new Map<string, CurrencyInfo>(currencyData.map((currency) => [currency.code, currency]));

/** Everything known of [code]; the dinar's for a code Harvest does not know. */
export function currencyInfo(code: string): CurrencyInfo {
  return byCode.get(currencyOf(code))!;
}

/** Every currency, sorted by its name in [language], for a picker. */
export function currenciesByName(language: 'en' | 'ar'): CurrencyInfo[] {
  return [...byCode.values()].sort((a, b) => a[language].localeCompare(b[language], language));
}

/** How many decimals an amount of [code] is shown with: its minor units, and never more than the two kept. */
export function displayDecimals(code: string): number {
  return Math.min(currencyInfo(code).minorUnits, 2);
}

/** The currency in everyday use in [country] (ISO 3166-1 alpha-2), or null. */
export function currencyOfCountry(country: string | null | undefined): CurrencyCode | null {
  const code = country ? countryCurrencies[country.toUpperCase()] : undefined;
  return code !== undefined && isCurrencyCode(code) ? code : null;
}

/** The country an IANA time zone is in, or null for one that is no country's (UTC, Etc/…). */
export function countryOfZone(zone: string | null | undefined): string | null {
  return (zone && zoneCountries[zone]) || null;
}

/** The region of a BCP 47 locale (`ar-DZ`, `fr_FR`, `en-Latn-GB`), or null. */
export function regionOfLocale(locale: string | null | undefined): string | null {
  if (!locale) return null;
  const parts = locale.replaceAll('_', '-').split('-').slice(1);
  const region = parts.find((part) => /^[A-Za-z]{2}$/.test(part) || /^\d{3}$/.test(part));
  return region && /^[A-Za-z]{2}$/.test(region) ? region.toUpperCase() : null;
}

/**
 * The currency a new install starts with: where the device says it is.
 * In order, the first that names a country with a currency:
 * - [countries], what the device knows best (on the phone its SIM's and
 *   its network's country);
 * - the time zone, which follows me more closely than the language does;
 * - each of [locales]' regions.
 * With none of them, the dinar, as before. Always changeable in Settings,
 * and never read again once chosen.
 */
export function defaultCurrencyFor(where: {
  countries?: readonly (string | null | undefined)[];
  timeZone?: string | null;
  locales?: readonly (string | null | undefined)[];
}): CurrencyCode {
  const candidates = [
    ...(where.countries ?? []),
    countryOfZone(where.timeZone),
    ...(where.locales ?? []).map(regionOfLocale),
  ];
  for (const country of candidates) {
    const currency = currencyOfCountry(country);
    if (currency) return currency;
  }
  return 'DZD';
}
