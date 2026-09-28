import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useState } from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { CurrencyPicker, matchingCurrencies } from '@/app/components/currency-picker';
import { HarvestContext } from '@/app/context';
import { fallbackCurrency, readDefaultCurrency, readSetting, settingKeys } from '@/app/data/settings';
import { readRates as vaultRates } from '@/app/data/vault';
import { currencySymbol, formatAmountInput, formatMoney } from '@/lib/format';
import i18n from '@/i18n';
import { FakeServer } from './fake-server';
import { device } from './helpers';

/** Every currency (Phase 7, M7.8), on the web. */

afterEach(async () => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
  await i18n.changeLanguage('en');
});

describe('how an amount is drawn', () => {
  it('with the currency’s own sign, and never more decimals than it shows', () => {
    expect(formatMoney(3_690_050, 'DZD')).toBe('DA36,900.50');
    expect(formatMoney(2000, 'EUR')).toBe('€20');
    expect(formatMoney(123_456, 'JPY')).toBe('¥1,235');
    expect(formatMoney(-1250, 'GBP')).toBe('-£12.50');
    // A sign that is only the code is set apart from the number.
    expect(formatMoney(1250, 'KWD')).toBe('KWD 12.50');
    // A code Harvest does not know is drawn as it is.
    expect(currencySymbol('XYZ')).toBe('XYZ');
  });

  it('keeps whole units in a field for a currency with no fraction', () => {
    expect(formatAmountInput(123_456, 'JPY')).toBe('1235');
    expect(formatAmountInput(123_456, 'EUR')).toBe('1234.56');
    expect(formatAmountInput(123_400)).toBe('1234');
  });
});

describe('the default before one is chosen', () => {
  it('follows the browser’s time zone, then its languages, never the network', () => {
    // The tests run on Algiers' clock.
    expect(fallbackCurrency()).toBe('DZD');
    vi.spyOn(Intl.DateTimeFormat.prototype, 'resolvedOptions').mockReturnValue({
      timeZone: 'Europe/Paris',
    } as Intl.ResolvedDateTimeFormatOptions);
    expect(fallbackCurrency()).toBe('EUR');
    vi.spyOn(Intl.DateTimeFormat.prototype, 'resolvedOptions').mockReturnValue({
      timeZone: 'UTC',
    } as Intl.ResolvedDateTimeFormatOptions);
    vi.spyOn(navigator, 'languages', 'get').mockReturnValue(['ar-MA', 'fr']);
    expect(fallbackCurrency()).toBe('MAD');
  });

  it('is what the money reads until one is chosen, and is never written', async () => {
    const h = await device(new FakeServer());
    vi.spyOn(Intl.DateTimeFormat.prototype, 'resolvedOptions').mockReturnValue({
      timeZone: 'Asia/Tokyo',
    } as Intl.ResolvedDateTimeFormatOptions);
    expect((await vaultRates(h.db)).defaultCurrency).toBe('JPY');
    expect(await readSetting(h.db, settingKeys.defaultCurrency)).toBeNull();
    await h.settings.setDefaultCurrency('CAD');
    expect((await vaultRates(h.db)).defaultCurrency).toBe('CAD');
  });

  it('stays on the dinar for an account that logged money before choosing one', async () => {
    const h = await device(new FakeServer());
    vi.spyOn(Intl.DateTimeFormat.prototype, 'resolvedOptions').mockReturnValue({
      timeZone: 'Europe/Paris',
    } as Intl.ResolvedDateTimeFormatOptions);
    expect((await vaultRates(h.db)).defaultCurrency).toBe('EUR');
    // A 3.1 account's expense, logged on the dinar it never chose.
    await h.db.rows('expenses').put({
      uuid: 'e1',
      amountMinor: 45000,
      currency: 'DZD',
      category: 'Food',
      note: null,
      harvestDay: '2026-09-18',
      loggedAt: '2026-09-18T13:10:00.000Z',
      deletedAt: null,
      updatedAt: '2026-09-18T13:10:00.000Z',
    });
    expect((await vaultRates(h.db)).defaultCurrency).toBe('DZD');
    expect(await readDefaultCurrency(h.db)).toBe('DZD');
  });

  it('reads the fetched rates into the rules, beside the dinar’s typed ones', async () => {
    const h = await device(new FakeServer());
    await h.settings.setMany({ 'rate.perUsd': JSON.stringify({ EUR: 0.85, JPY: 147.3, BOGUS: 2 }), 'rate.dzdPerEur': '250' });
    const rates = await vaultRates(h.db);
    expect(rates.perUsd).toEqual({ EUR: 0.85, JPY: 147.3 });
    expect(rates.dzdPerEur).toBe(250);
  });
});

describe('the currency picker', () => {
  it('finds a currency by its name in either language, its code or its sign', () => {
    expect(matchingCurrencies('yen', 'en')[0]?.code).toBe('JPY');
    expect(matchingCurrencies('jpy', 'en')[0]?.code).toBe('JPY');
    expect(matchingCurrencies('£', 'en').map((c) => c.code)).toContain('GBP');
    expect(matchingCurrencies('درهم مغربي', 'ar')[0]?.code).toBe('MAD');
    expect(matchingCurrencies('nothing like it', 'en')).toEqual([]);
    // With nothing typed, the one chosen and the default lead, then every other by name.
    const all = matchingCurrencies('', 'en', ['EUR', 'DZD']);
    expect(all.slice(0, 2).map((c) => c.code)).toEqual(['EUR', 'DZD']);
    expect(all).toHaveLength(160);
  });

  function Picked() {
    const [code, setCode] = useState('DZD');
    return (
      <>
        <label htmlFor="pick">Currency</label>
        <CurrencyPicker id="pick" value={code} onChange={setCode} />
        <output>{code}</output>
      </>
    );
  }

  it('says the one chosen, and takes another from a search', async () => {
    const h = await device(new FakeServer());
    render(
      <HarvestContext.Provider value={h}>
        <Picked />
      </HarvestContext.Provider>,
    );
    const button = screen.getByRole('button', { name: 'Currency' });
    expect(button).toHaveTextContent('DA DZD');
    const user = userEvent.setup();
    await user.click(button);
    const dialog = await screen.findByRole('dialog', { name: 'Choose a currency' });
    expect(within(dialog).getByRole('option', { name: /Algerian Dinar/ })).toHaveAttribute('aria-selected', 'true');
    await user.type(within(dialog).getByRole('searchbox', { name: 'Search by name, code or sign' }), 'swiss');
    await user.click(within(dialog).getByRole('option', { name: /Swiss Franc/ }));
    expect(screen.queryByRole('dialog')).toBeNull();
    expect(screen.getByRole('status')).toHaveTextContent('CHF');
  });

  it('names every currency in Arabic on an Arabic page', async () => {
    await i18n.changeLanguage('ar');
    const h = await device(new FakeServer());
    render(
      <HarvestContext.Provider value={h}>
        <Picked />
      </HarvestContext.Provider>,
    );
    await userEvent.click(screen.getByRole('button', { name: 'Currency' }));
    const dialog = await screen.findByRole('dialog');
    expect(within(dialog).getByRole('option', { name: /دينار جزائري/ })).toBeInTheDocument();
  });
});
