import { isPortableSetting } from '@harvest/contracts';
import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { DailyCycleCard } from '@/app/components/settings-cycle';
import { RatesCard } from '@/app/components/settings-rates';
import { HarvestContext } from '@/app/context';
import { healthKeys, sleepNightKey } from '@/app/data/health';
import { cycleClashes, featureKeys, fetchEurUsd, pomodoroSettings, rateKeys, readSetting, settingKeys } from '@/app/data/settings';
import { RecordsTabs } from '@/app/screens/records';
import { ExtrasSection, HarvestSection, MoneySection, PhoneOnlySection, PomodoroSection } from '@/app/screens/settings';
import { FakeServer } from './fake-server';
import { device } from './helpers';

/**
 * The settings the browser can change, each one a preference the phone
 * reads under the same key, and each one synced.
 */

type Device = Awaited<ReturnType<typeof device>>;

function show(h: Device, ui: React.ReactNode) {
  return render(
    <HarvestContext.Provider value={h}>
      <MemoryRouter>{ui}</MemoryRouter>
    </HarvestContext.Provider>,
  );
}

async function valueOf(h: Device, key: string) {
  return readSetting(h.db, key);
}

/** The page's own sections; sync and the account need a signed-in shell. */
function SettingsScreen() {
  return (
    <>
      <HarvestSection />
      <ExtrasSection />
      <PomodoroSection />
      <MoneySection />
      <PhoneOnlySection />
    </>
  );
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('the keys the settings write', () => {
  it('are all portable, so the server takes them and the phone reads them', () => {
    const keys = [
      ...Object.values(settingKeys),
      ...Object.values(featureKeys),
      ...pomodoroSettings.map((setting) => setting.key),
      ...Object.values(rateKeys),
      ...Object.values(healthKeys),
      ...[1, 2, 3, 4, 5, 6, 7].map(sleepNightKey),
    ];
    expect(keys.filter((key) => !isPortableSetting(key))).toEqual([]);
  });
});

describe('the settings page', () => {
  it('switches a feature on, queued for the phone', async () => {
    const h = await device(new FakeServer());
    show(h, <SettingsScreen />);

    await userEvent.click(await screen.findByRole('switch', { name: 'Health' }));
    await waitFor(async () => expect(await valueOf(h, 'features.health')).toBe('true'));
    expect((await h.db.outbox.toArray()).some((entry) => entry.key === 'features.health')).toBe(true);
  });

  it('steps the focus length by five, within the phone’s bounds', async () => {
    const h = await device(new FakeServer());
    await h.settings.setInt('pomodoro.focusMinutes', 85);
    show(h, <SettingsScreen />);

    // The stepper waits for the stored value, so a click cannot step the fallback.
    await waitFor(() => expect(screen.getByRole('button', { name: 'More: Focus length' })).toBeEnabled(), { timeout: 5000 });
    await userEvent.click(screen.getByRole('button', { name: 'More: Focus length' }));
    await waitFor(async () => expect(await valueOf(h, 'pomodoro.focusMinutes')).toBe('90'), { timeout: 5000 });
    await waitFor(() => expect(screen.getByRole('button', { name: 'More: Focus length' })).toBeDisabled(), { timeout: 5000 });
  });

  it('names what only the phone can do rather than leaving it out', async () => {
    const h = await device(new FakeServer());
    show(h, <SettingsScreen />);
    const phone = await screen.findByRole('region', { name: 'On the phone' });
    expect(within(phone).getByText('Reminders')).toBeInTheDocument();
    expect(within(phone).getByText('App lock')).toBeInTheDocument();
    expect(within(phone).getByText('Sleep alarm and wind-down')).toBeInTheDocument();
  });

  it('shows the weekdays of their own only while Health is on', async () => {
    const h = await device(new FakeServer());
    show(h, <SettingsScreen />);
    await screen.findByRole('region', { name: 'Harvest' });
    expect(screen.queryByText('Nights of their own')).not.toBeInTheDocument();

    await h.settings.setBool('features.health', true);
    expect(await screen.findByText('Nights of their own')).toBeInTheDocument();
    const [saturday] = await screen.findAllByRole('switch', { name: /Saturday has its own night/ });
    await userEvent.click(saturday!);
    // It starts as the daily cycle, written the way the phone decodes it.
    await waitFor(async () => expect(await valueOf(h, 'sleep.night.6')).toBe('23:00-07:00'));
  });
});

describe('the daily cycle', () => {
  it('finds the reminders a new night would swallow, keeping their distance from waking', async () => {
    const h = await device(new FakeServer());
    const seed = await h.seeds.plant({ type: 'habit', title: 'Run', remindAt: '06:30' });
    await h.seeds.plant({ type: 'habit', title: 'Read', remindAt: '12:00' });

    const clashes = await cycleClashes(
      h.db,
      { bedTime: { hour: 23, minute: 0 }, wakeTime: { hour: 6, minute: 0 } },
      { bedTime: { hour: 23, minute: 0 }, wakeTime: { hour: 8, minute: 0 } },
    );
    expect(clashes).toEqual([
      { kind: 'seed', uuid: seed.uuid, title: 'Run', at: { hour: 6, minute: 30 }, movedTo: { hour: 8, minute: 30 } },
    ]);
  });

  it('writes the new hours, and moves a buried reminder only when asked', async () => {
    const h = await device(new FakeServer());
    const seed = await h.seeds.plant({ type: 'habit', title: 'Run', remindAt: '07:30' });
    show(h, <DailyCycleCard />);

    const wake = await screen.findByLabelText('I wake up at');
    fireEvent.change(wake, { target: { value: '09:00' } });
    fireEvent.blur(wake);

    await waitFor(async () => expect(await valueOf(h, 'cycle.wakeTime')).toBe('09:00'));
    expect(await valueOf(h, 'cycle.bedTime')).toBe('23:00');
    const dialog = await screen.findByRole('alertdialog');
    expect(within(dialog).getByText('One reminder is now in your sleep')).toBeInTheDocument();
    await userEvent.click(within(dialog).getByRole('button', { name: 'Move them' }));

    await waitFor(async () => expect((await h.db.rows('commitments').get(seed.uuid))?.remindAt).toBe('09:30'));
  });
});

describe('exchange rates', () => {
  it('saves a typed rate, refuses nonsense, and forgets an emptied one', async () => {
    const h = await device(new FakeServer());
    show(h, <RatesCard />);

    const usd = await screen.findByLabelText('DZD per 1 USD');
    await userEvent.type(usd, '134,5');
    fireEvent.blur(usd);
    await waitFor(async () => expect(await valueOf(h, 'rate.dzdPerUsd')).toBe('134.5'));

    const eur = screen.getByLabelText('DZD per 1 EUR');
    await userEvent.type(eur, '-3');
    fireEvent.blur(eur);
    expect(await valueOf(h, 'rate.dzdPerEur')).toBeNull();

    const cleared = await screen.findByLabelText('DZD per 1 USD');
    await userEvent.clear(cleared);
    fireEvent.blur(cleared);
    await waitFor(async () => expect(await h.db.rows('kv_settings').get('rate.dzdPerUsd')).toBeUndefined());
    // The forgetting travels too.
    expect((await h.db.outbox.toArray()).some((entry) => entry.key === 'rate.dzdPerUsd' && entry.op === 'delete')).toBe(true);
  });

  it('fetches EUR to USD only when asked, and only a believable number', async () => {
    const answer = (body: unknown, status = 200) => vi.fn(() => Promise.resolve(new Response(JSON.stringify(body), { status })));
    expect(await fetchEurUsd(answer({ rates: { USD: 1.0842 } }))).toBe(1.0842);
    expect(await fetchEurUsd(answer({ rates: { USD: 7 } }))).toBeNull();
    expect(await fetchEurUsd(answer({ rates: {} }))).toBeNull();
    expect(await fetchEurUsd(answer({ rates: { USD: 1.1 } }, 500))).toBeNull();
    expect(await fetchEurUsd(vi.fn(() => Promise.reject(new TypeError('offline'))))).toBeNull();

    const h = await device(new FakeServer());
    const get = answer({ rates: { USD: 1.1 } });
    vi.stubGlobal('fetch', get);
    show(h, <RatesCard />);
    expect(get).not.toHaveBeenCalled();
    await userEvent.click(await screen.findByRole('button', { name: 'Fetch' }));
    await waitFor(async () => expect(await valueOf(h, 'rate.usdPerEur')).toBe('1.1'));
    expect(get).toHaveBeenCalledWith('https://api.frankfurter.dev/v1/latest?base=EUR&symbols=USD', expect.anything());
    expect(await valueOf(h, 'rate.usdPerEurAt')).not.toBeNull();
  });
});

describe('the Records tabs', () => {
  it('offer only the views that are switched on', async () => {
    const h = await device(new FakeServer());
    await h.settings.setMany({ 'features.notes': 'true', 'features.places': 'true' });
    show(h, <RecordsTabs />);
    expect(await screen.findByRole('link', { name: 'Notes' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Places' })).toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'Gallery' })).not.toBeInTheDocument();
  });
});
