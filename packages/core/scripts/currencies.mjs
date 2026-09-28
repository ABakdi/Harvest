/* global console, URL */
// Writes `fixtures/currencies.json` ([[Finances]], Phase 7 M7.8): every
// currency in circulation, with its minor units, its symbol and its name
// in English and Arabic, from the ICU data Node ships; the country each
// one is the local currency of; and the country of every time zone, from
// the system's zone.tab. Both apps read the file: the web through
// `currencies.ts` and the module this writes beside it, the phone
// through the Dart the phone's own script makes from it. Run from the package: node scripts/currencies.mjs
import { readFileSync, writeFileSync } from 'node:fs';

// Not money anyone spends: metals, drawing rights, funds, test codes,
// units of account.
const notMoney = new Set([
  'XAG', 'XAU', 'XPD', 'XPT', 'XDR', 'XSU', 'XUA', 'XBA', 'XBB', 'XBC', 'XBD', 'XTS', 'XXX',
  'BOV', 'CHE', 'CHW', 'CLF', 'COU', 'MXV', 'USN', 'UYI', 'UYW', 'VED',
]);

// The symbol a person there writes, where ICU's narrow one is only the
// code; and the dinar as Harvest has always written it.
const symbols = { DZD: 'DA', MAD: 'DH', TND: 'DT', AED: 'AED', SAR: 'SR', EGP: 'E£', CHF: 'CHF' };

const en = new Intl.DisplayNames(['en'], { type: 'currency' });
const ar = new Intl.DisplayNames(['ar'], { type: 'currency' });
const currencies = Intl.supportedValuesOf('currency')
  .filter((code) => !notMoney.has(code))
  .map((code) => {
    const format = new Intl.NumberFormat('en', { style: 'currency', currency: code, currencyDisplay: 'narrowSymbol' });
    const narrow = format.formatToParts(1).find((part) => part.type === 'currency')?.value ?? code;
    return {
      code,
      minorUnits: format.resolvedOptions().maximumFractionDigits,
      symbol: symbols[code] ?? narrow,
      en: en.of(code),
      ar: ar.of(code),
    };
  });
const known = new Set(currencies.map((c) => c.code));

// ISO 3166-1 alpha-2 → the currency in everyday use there.
const byCountry = {
  AD: 'EUR', AE: 'AED', AF: 'AFN', AG: 'XCD', AI: 'XCD', AL: 'ALL', AM: 'AMD', AO: 'AOA', AR: 'ARS', AS: 'USD',
  AT: 'EUR', AU: 'AUD', AW: 'AWG', AX: 'EUR', AZ: 'AZN', BA: 'BAM', BB: 'BBD', BD: 'BDT', BE: 'EUR', BF: 'XOF',
  BG: 'BGN', BH: 'BHD', BI: 'BIF', BJ: 'XOF', BL: 'EUR', BM: 'BMD', BN: 'BND', BO: 'BOB', BQ: 'USD', BR: 'BRL',
  BS: 'BSD', BT: 'BTN', BV: 'NOK', BW: 'BWP', BY: 'BYN', BZ: 'BZD', CA: 'CAD', CC: 'AUD', CD: 'CDF', CF: 'XAF',
  CG: 'XAF', CH: 'CHF', CI: 'XOF', CK: 'NZD', CL: 'CLP', CM: 'XAF', CN: 'CNY', CO: 'COP', CR: 'CRC', CU: 'CUP',
  CV: 'CVE', CW: 'ANG', CX: 'AUD', CY: 'EUR', CZ: 'CZK', DE: 'EUR', DJ: 'DJF', DK: 'DKK', DM: 'XCD', DO: 'DOP',
  DZ: 'DZD', EC: 'USD', EE: 'EUR', EG: 'EGP', EH: 'MAD', ER: 'ERN', ES: 'EUR', ET: 'ETB', FI: 'EUR', FJ: 'FJD',
  FK: 'FKP', FM: 'USD', FO: 'DKK', FR: 'EUR', GA: 'XAF', GB: 'GBP', GD: 'XCD', GE: 'GEL', GF: 'EUR', GG: 'GBP',
  GH: 'GHS', GI: 'GIP', GL: 'DKK', GM: 'GMD', GN: 'GNF', GP: 'EUR', GQ: 'XAF', GR: 'EUR', GS: 'GBP', GT: 'GTQ',
  GU: 'USD', GW: 'XOF', GY: 'GYD', HK: 'HKD', HM: 'AUD', HN: 'HNL', HR: 'EUR', HT: 'HTG', HU: 'HUF', ID: 'IDR',
  IE: 'EUR', IL: 'ILS', IM: 'GBP', IN: 'INR', IO: 'USD', IQ: 'IQD', IR: 'IRR', IS: 'ISK', IT: 'EUR', JE: 'GBP',
  JM: 'JMD', JO: 'JOD', JP: 'JPY', KE: 'KES', KG: 'KGS', KH: 'KHR', KI: 'AUD', KM: 'KMF', KN: 'XCD', KP: 'KPW',
  KR: 'KRW', KW: 'KWD', KY: 'KYD', KZ: 'KZT', LA: 'LAK', LB: 'LBP', LC: 'XCD', LI: 'CHF', LK: 'LKR', LR: 'LRD',
  LS: 'LSL', LT: 'EUR', LU: 'EUR', LV: 'EUR', LY: 'LYD', MA: 'MAD', MC: 'EUR', MD: 'MDL', ME: 'EUR', MF: 'EUR',
  MG: 'MGA', MH: 'USD', MK: 'MKD', ML: 'XOF', MM: 'MMK', MN: 'MNT', MO: 'MOP', MP: 'USD', MQ: 'EUR', MR: 'MRU',
  MS: 'XCD', MT: 'EUR', MU: 'MUR', MV: 'MVR', MW: 'MWK', MX: 'MXN', MY: 'MYR', MZ: 'MZN', NA: 'NAD', NC: 'XPF',
  NE: 'XOF', NF: 'AUD', NG: 'NGN', NI: 'NIO', NL: 'EUR', NO: 'NOK', NP: 'NPR', NR: 'AUD', NU: 'NZD', NZ: 'NZD',
  OM: 'OMR', PA: 'PAB', PE: 'PEN', PF: 'XPF', PG: 'PGK', PH: 'PHP', PK: 'PKR', PL: 'PLN', PM: 'EUR', PN: 'NZD',
  PR: 'USD', PS: 'ILS', PT: 'EUR', PW: 'USD', PY: 'PYG', QA: 'QAR', RE: 'EUR', RO: 'RON', RS: 'RSD', RU: 'RUB',
  RW: 'RWF', SA: 'SAR', SB: 'SBD', SC: 'SCR', SD: 'SDG', SE: 'SEK', SG: 'SGD', SH: 'SHP', SI: 'EUR', SJ: 'NOK',
  SK: 'EUR', SL: 'SLE', SM: 'EUR', SN: 'XOF', SO: 'SOS', SR: 'SRD', SS: 'SSP', ST: 'STN', SV: 'USD', SX: 'ANG',
  SY: 'SYP', SZ: 'SZL', TC: 'USD', TD: 'XAF', TF: 'EUR', TG: 'XOF', TH: 'THB', TJ: 'TJS', TK: 'NZD', TL: 'USD',
  TM: 'TMT', TN: 'TND', TO: 'TOP', TR: 'TRY', TT: 'TTD', TV: 'AUD', TW: 'TWD', TZ: 'TZS', UA: 'UAH', UG: 'UGX',
  UM: 'USD', US: 'USD', UY: 'UYU', UZ: 'UZS', VA: 'EUR', VC: 'XCD', VE: 'VES', VG: 'USD', VI: 'USD', VN: 'VND',
  VU: 'VUV', WF: 'XPF', WS: 'WST', YE: 'YER', YT: 'EUR', ZA: 'ZAR', ZM: 'ZMW', ZW: 'ZWG', XK: 'EUR',
};
const unknown = Object.entries(byCountry).filter(([, code]) => !known.has(code));
if (unknown.length > 0) throw new Error(`Countries naming a currency not listed: ${JSON.stringify(unknown)}`);

// Time zone → country, from zone.tab (every zone, with the aliases that
// still name one country), for a browser that says only its zone.
const zones = {};
for (const line of readFileSync('/usr/share/zoneinfo/zone.tab', 'utf8').split('\n')) {
  if (line.startsWith('#') || line.trim() === '') continue;
  const [country, , zone] = line.split('\t');
  zones[zone] = country;
}
// Old names browsers still report.
Object.assign(zones, {
  'Asia/Calcutta': 'IN', 'Asia/Saigon': 'VN', 'Asia/Katmandu': 'NP', 'Asia/Rangoon': 'MM', 'Europe/Kiev': 'UA',
  'America/Buenos_Aires': 'AR', 'Africa/Asmera': 'ER', 'Atlantic/Faeroe': 'FO', 'Pacific/Truk': 'FM',
});

const out = {
  about:
    'Every currency in circulation (ISO 4217; metals, funds and units of account left out), from ICU: code, minor units, the symbol written there, and the name in English and Arabic. ' +
    'byCountry: ISO 3166-1 alpha-2 to the currency in everyday use. zones: IANA time zone to country, from zone.tab. Made by packages/core/scripts/currencies.mjs; do not edit by hand.',
  currencies,
  byCountry: Object.fromEntries(Object.entries(byCountry).sort()),
  zones: Object.fromEntries(Object.entries(zones).sort()),
};
writeFileSync(new URL('../fixtures/currencies.json', import.meta.url), `${JSON.stringify(out, null, 1)}\n`);
// The same data as a module, since the package builds from src alone.
writeFileSync(
  new URL('../src/currency-data.ts', import.meta.url),
  [
    '// Made by scripts/currencies.mjs from ICU and zone.tab; do not edit by hand.',
    '// fixtures/currencies.json is the same data, for the phone and the tests.',
    '',
    `export const currencyData = ${JSON.stringify(currencies, null, 2)} as const;`,
    '',
    `export const countryCurrencies: Readonly<Record<string, string>> = ${JSON.stringify(out.byCountry, null, 2)};`,
    '',
    `export const zoneCountries: Readonly<Record<string, string>> = ${JSON.stringify(out.zones, null, 2)};`,
    '',
  ].join('\n'),
);
console.log(`${currencies.length} currencies, ${Object.keys(byCountry).length} countries, ${Object.keys(zones).length} zones`);
