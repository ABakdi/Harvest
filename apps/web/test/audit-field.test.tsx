import { HarvestDay } from '@harvest/core';
import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes, useParams } from 'react-router';
import { Toaster } from 'sonner';
import { describe, expect, it } from 'vitest';
import { SearchDialog } from '@/app/components/search-dialog';
import { SeedEditor } from '@/app/components/seed-editor';
import { SeedLogDialog } from '@/app/components/seed-log-dialog';
import { HarvestContext, type Harvest } from '@/app/context';
import type { SealedRow } from '@/app/data/db';
import { loadField } from '@/app/data/field';
import { weekReport, firstSeedDay } from '@/app/data/stats';
import { DialogsProvider } from '@/app/dialogs';
import { FarmerScreen } from '@/app/screens/farmer';
import { FieldScreen } from '@/app/screens/field';
import { FakeServer } from './fake-server';
import { device, testUser } from './helpers';

const today = HarvestDay.parse('2026-09-19');

function renderIn(h: Harvest, children: React.ReactNode, at = '/app/field') {
  render(
    <HarvestContext.Provider value={h}>
      <MemoryRouter initialEntries={[at]}>
        <DialogsProvider>{children}</DialogsProvider>
        <Toaster />
      </MemoryRouter>
    </HarvestContext.Provider>,
  );
}

describe('the budget line without the passphrase', () => {
  it('shows no number while this browser cannot read the spending', async () => {
    const h = await device(new FakeServer());
    await h.settings.setString('finance.monthlyBudgetMinor', '1200000');
    renderIn(h, <FieldScreen tab="today" />);
    const hint = await screen.findByRole('link', { name: /budget is locked/ }, { timeout: 5000 });
    expect(hint).toHaveAttribute('href', '/app/granary');
    expect(screen.queryByText(/left today/)).toBeNull();
  });

  it('stays locked with a key that leaves expenses sealed', async () => {
    const h = await device(new FakeServer());
    await h.settings.setString('finance.monthlyBudgetMinor', '1200000');
    await h.keyring.unlock('a long passphrase', testUser.syncSalt, 1);
    await h.db.sealed.put({
      table: 'expenses',
      uuid: crypto.randomUUID(),
      updatedAt: '2026-09-19T10:00:00.000Z',
      deletedAt: null,
      enc: {} as SealedRow['enc'],
    });
    renderIn(h, <FieldScreen tab="today" />);
    expect(await screen.findByRole('link', { name: /budget is locked/ }, { timeout: 5000 })).toBeInTheDocument();
    expect(screen.queryByText(/left today/)).toBeNull();
  });
});

describe('the field card', () => {
  it('draws a note’s markdown instead of showing its markers', async () => {
    const h = await device(new FakeServer());
    const seed = await h.seeds.plant({ type: 'habit', title: 'Walk', schedule: { type: 'daily' }, note: '**Bold** start' });
    await h.seedNotes.write(seed.uuid, today, 'went *far* today');
    renderIn(h, <FieldScreen tab="today" />);
    const bold = await screen.findByText('Bold');
    expect(bold.tagName).toBe('STRONG');
    expect(screen.queryByText(/\*\*Bold\*\*/)).toBeNull();
    expect(screen.getByText('far').tagName).toBe('EM');
  });

  it('says +XP after a check-in', async () => {
    const h = await device(new FakeServer());
    await h.seeds.plant({ type: 'habit', title: 'Walk', schedule: { type: 'daily' } });
    renderIn(h, <FieldScreen tab="today" />);
    await userEvent.click(await screen.findByRole('button', { name: /Check in.*Walk|Walk/ , pressed: false }));
    expect(await screen.findByText('+10 XP')).toBeInTheDocument();
  });

  it('confirms a pause with an undo, and a paused seed is not counted as due', async () => {
    const h = await device(new FakeServer());
    const walk = await h.seeds.plant({ type: 'habit', title: 'Walk', schedule: { type: 'daily' } });
    await h.seeds.plant({ type: 'habit', title: 'Read', schedule: { type: 'daily' } });
    // Checked in, then paused: it stays in view for the check-in it had.
    await h.checkIns.checkIn(walk, today);
    renderIn(h, <FieldScreen tab="today" />);
    expect(await screen.findByText('2 seeds today')).toBeInTheDocument();
    const user = userEvent.setup();
    screen.getByRole('button', { name: 'Options for “Walk”' }).focus();
    await user.keyboard('{Enter}');
    await user.click(await screen.findByRole('menuitem', { name: /Pause/ }));
    expect(await screen.findByText('“Walk” is paused')).toBeInTheDocument();
    expect(await screen.findByText('1 seed today')).toBeInTheDocument();
    // A plain click: jsdom has no pointer capture for the toast's swipe.
    fireEvent.click(screen.getByRole('button', { name: 'Undo' }));
    await waitFor(async () => expect((await h.db.rows('commitments').get(walk.uuid))?.pausedAt).toBeNull());
  });
});

describe('a project and its target', () => {
  it('refuses a daily commitment larger than the whole target', async () => {
    const h = await device(new FakeServer());
    renderIn(h, <SeedEditor state={{ mode: 'plant', prefill: { type: 'project', title: 'Read' } }} onClose={() => {}} />);
    const dialog = await screen.findByRole('dialog');
    const user = userEvent.setup();
    await user.type(within(dialog).getByLabelText(/Total target/), '50');
    await user.type(within(dialog).getByLabelText('Daily commitment'), '80');
    await user.click(within(dialog).getByRole('button', { name: 'Plant a seed' }));
    expect(await within(dialog).findByText('A day’s commitment can’t be more than the whole target')).toBeInTheDocument();
    expect(await h.db.rows('commitments').count()).toBe(0);
  });

  it('logs no more than what is left of the target, whatever the daily cap allows', async () => {
    const h = await device(new FakeServer());
    const seed = await h.seeds.plant({ type: 'project', title: 'Read', totalTarget: 50, dailyCommitment: 40 });
    await h.checkIns.checkIn(seed, today.addDays(-1), 30);
    // Today's cap is 80; only 20 are left of the 50.
    const plan = await h.checkIns.checkIn(seed, today, 80);
    expect(plan).toMatchObject({ quantityLogged: 20, capped: true });
    expect((await h.checkIns.checkIn(seed, today, 5)).quantityLogged).toBe(0);
    const field = await loadField(h.db, today);
    expect([...field.today, ...field.resting].find((row) => row.row.uuid === seed.uuid)?.room).toBe(0);
  });

  it('offers the room left of the target in the log dialog', async () => {
    const h = await device(new FakeServer());
    const seed = await h.seeds.plant({ type: 'project', title: 'Read', totalTarget: 50, dailyCommitment: 40 });
    await h.checkIns.checkIn(seed, today.addDays(-1), 45);
    renderIn(h, <SeedLogDialog seed={seed} onClose={() => {}} />);
    const box = await screen.findByLabelText('How much did you get done?');
    await waitFor(() => expect(box).toHaveValue(5));
    expect(screen.getByText(/5/, { selector: 'p' })).toBeInTheDocument();
  });
});

describe('the farmer’s numbers', () => {
  it('counts check-ins and days in the plural each takes', async () => {
    const h = await device(new FakeServer());
    const seed = await h.seeds.plant({ type: 'project', title: 'Read', totalTarget: 300, dailyCommitment: 10 });
    for (let i = 0; i < 6; i++) await h.checkIns.checkIn(seed, today, 1);
    renderIn(h, <FarmerScreen />, '/app/farmer');
    expect(await screen.findByText('6 check-ins over 1 day')).toBeInTheDocument();
  });

  it('finds the quietest day only among the days since the first seed', () => {
    // Planted on Thursday: Monday to Wednesday were not quiet, they were not yet.
    const since = firstSeedDay([{ createdAt: '2026-09-17T09:00:00.000Z' }], []);
    expect(since?.key).toBe('2026-09-17');
    const checkIns = [
      { commitmentUuid: 'a', harvestDay: '2026-09-17', deletedAt: null },
      { commitmentUuid: 'a', harvestDay: '2026-09-19', deletedAt: null },
    ];
    const report = weekReport(today, checkIns, [], [], { defaultCurrency: 'DZD' }, since);
    expect(report.worst?.key).toBe('2026-09-18');
    // Planted today: one day, nothing to compare.
    expect(weekReport(today, [], [], [], { defaultCurrency: 'DZD' }, today).worst).toBeNull();
  });
});

describe('search', () => {
  it('opens a seed’s own page, not the field', async () => {
    const h = await device(new FakeServer());
    const seed = await h.seeds.plant({ type: 'habit', title: 'Walk the dog', schedule: { type: 'daily' } });
    function SeedPage() {
      return <p>seed {useParams().uuid}</p>;
    }
    render(
      <HarvestContext.Provider value={h}>
        <MemoryRouter initialEntries={['/app/farmer']}>
          <SearchDialog open onOpenChange={() => {}} />
          <Routes>
            <Route path="/app/field/seed/:uuid" element={<SeedPage />} />
            <Route path="*" element={null} />
          </Routes>
        </MemoryRouter>
      </HarvestContext.Provider>,
    );
    const user = userEvent.setup();
    await user.type(await screen.findByRole('combobox'), 'dog');
    await user.click(await screen.findByRole('option', { name: /Walk the dog/ }));
    expect(await screen.findByText(`seed ${seed.uuid}`)).toBeInTheDocument();
  });
});
