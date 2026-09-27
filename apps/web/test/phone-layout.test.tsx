import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Toaster } from 'sonner';
import { MemoryRouter } from 'react-router';
import { describe, expect, it } from 'vitest';
import { barTabs, barTitle, BottomBar, pushedParent, railTabs } from '@/app/app-shell';
import { keyboardUp } from '@/app/components/keyboard';
import { ArchiveScreen } from '@/app/screens/archive';
import { Fab } from '@/app/components/fab';
import { FarmerTabs } from '@/app/components/screen-tabs';
import { HarvestContext } from '@/app/context';
import { DialogsProvider } from '@/app/dialogs';
import { GranaryScreen } from '@/app/screens/granary';
import { Dialog, DialogContent, DialogTitle } from '@/components/ui/dialog';
import i18n from '@/i18n';
import { FakeServer } from './fake-server';
import { device, testUser } from './helpers';

const none = { notes: false, gallery: false, places: false, lists: false, health: false, gym: false };
const all = { notes: true, gallery: true, places: true, lists: true, health: true, gym: true };

describe('the bottom bar on a phone-width window', () => {
  it('has the phone’s tabs in the phone’s order', () => {
    expect(barTabs(all)).toEqual(['field', 'granary', 'records', 'body', 'farmer']);
  });

  it('is three tabs with nothing extra on, and never more than five', () => {
    expect(barTabs(none)).toEqual(['field', 'granary', 'farmer']);
    expect(barTabs(all)).toHaveLength(5);
  });

  it('shows Records for any one of its views, and the Body for either half', () => {
    expect(barTabs({ ...none, places: true })).toEqual(['field', 'granary', 'records', 'farmer']);
    expect(barTabs({ ...none, lists: true })).toContain('records');
    expect(barTabs({ ...none, gym: true })).toEqual(['field', 'granary', 'body', 'farmer']);
  });

  it('leaves the wide rail in the order the web has always had', () => {
    expect(railTabs(all)).toEqual(['field', 'body', 'records', 'granary', 'farmer']);
    expect(railTabs({ ...none, health: true })).toEqual(['field', 'body', 'granary', 'farmer']);
  });

  it('lights the Farmer up on Settings, which lives under it', async () => {
    const h = await device(new FakeServer());
    await h.settings.setMany({ 'features.notes': 'true', 'features.gym': 'true' });
    render(
      <HarvestContext.Provider value={h}>
        <MemoryRouter initialEntries={['/app/settings']}>
          <BottomBar />
        </MemoryRouter>
      </HarvestContext.Provider>,
    );
    const bar = screen.getByRole('navigation', { name: 'Main' });
    expect(await within(bar).findByRole('link', { name: 'Body' })).toBeInTheDocument();
    const names = within(bar)
      .getAllByRole('link')
      .map((link) => link.textContent);
    expect(names).toEqual(['Field', 'Granary', 'Records', 'Body', 'Farmer']);
    expect(within(bar).getByRole('link', { name: 'Farmer' })).toHaveAttribute('aria-current', 'page');
    expect(within(bar).getByRole('link', { name: 'Field' })).not.toHaveAttribute('aria-current');
    expect(within(bar).queryByRole('link', { name: 'Settings' })).toBeNull();
  });
});

describe('the app bar title on a phone-width window', () => {
  const t = i18n.t.bind(i18n);

  it('names the tab as the phone does', () => {
    expect(barTitle('/app/field', all, t)).toBe('Harvest');
    expect(barTitle('/app/field/goals', all, t)).toBe('Harvest');
    expect(barTitle('/app/granary', all, t)).toBe('Granary');
    expect(barTitle('/app/records/lists', all, t)).toBe('Records');
    expect(barTitle('/app/body/gym', all, t)).toBe('Body');
    expect(barTitle('/app/settings', all, t)).toBe('Farmer');
  });

  it('names the half when a paired tab has only one on', () => {
    expect(barTitle('/app/records/gallery', { ...none, gallery: true }, t)).toBe('Gallery');
    expect(barTitle('/app/body', { ...none, health: true }, t)).toBe('Health');
    expect(barTitle('/app/body/gym', { ...none, gym: true }, t)).toBe('Gym');
  });
});

describe('the farmer’s tabs', () => {
  it('lead to Progress and Settings, as on the phone', () => {
    render(
      <MemoryRouter initialEntries={['/app/farmer']}>
        <FarmerTabs />
      </MemoryRouter>,
    );
    expect(screen.getByRole('link', { name: 'Progress' })).toHaveAttribute('href', '/app/farmer');
    expect(screen.getByRole('link', { name: 'Progress' })).toHaveAttribute('aria-current', 'page');
    expect(screen.getByRole('link', { name: 'Settings' })).toHaveAttribute('href', '/app/settings');
  });
});

describe('the floating action', () => {
  it('floats on a phone and can leave a wide window to the header', () => {
    render(<Fab label="Plant a seed" wide={false} />);
    const button = screen.getByRole('button', { name: 'Plant a seed' });
    expect(button).toHaveAttribute('data-fab');
    expect(button.className).toContain('max-md:fixed');
    expect(button.className).toContain('md:hidden');
  });
});

describe('dialogs on a phone-width window', () => {
  it('are bottom sheets', () => {
    render(
      <Dialog open>
        <DialogContent aria-describedby={undefined}>
          <DialogTitle>Sheet</DialogTitle>
        </DialogContent>
      </Dialog>,
    );
    const sheet = screen.getByRole('dialog');
    expect(sheet.className).toContain('max-md:bottom-0');
    expect(sheet.className).toContain('max-md:rounded-t-[28px]');
  });

  it('stay as drawn when they say so, as the full-screen viewers do', () => {
    render(
      <Dialog open>
        <DialogContent sheet={false} aria-describedby={undefined}>
          <DialogTitle>Viewer</DialogTitle>
        </DialogContent>
      </Dialog>,
    );
    expect(screen.getByRole('dialog').className).not.toContain('max-md:bottom-0');
  });
});

describe('the Granary, laid out as the phone’s', () => {
  it('has Today, Balances and Insights, and opens on Today with the budget first', async () => {
    const h = await device(new FakeServer());
    await h.keyring.unlock('a long passphrase', testUser.syncSalt, 1);
    render(
      <HarvestContext.Provider value={h}>
        <MemoryRouter initialEntries={['/app/granary']}>
          <DialogsProvider>
            <GranaryScreen />
          </DialogsProvider>
        </MemoryRouter>
      </HarvestContext.Provider>,
    );
    expect(await screen.findByRole('tab', { name: 'Today', selected: true })).toBeInTheDocument();
    expect(screen.getAllByRole('tab').map((tab) => tab.textContent)).toEqual(['Today', 'Balances', 'Insights']);
    // The budget sits inside Today, before the spending.
    const set = await screen.findByRole('button', { name: 'Set a monthly budget' });
    const spending = screen.getByText('Nothing logged this month');
    expect(set.compareDocumentPosition(spending) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    // The categories are in Settings now, as on the phone.
    expect(screen.queryByRole('button', { name: 'New category' })).toBeNull();
  });
});

describe('pushed screens on a phone-width window', () => {
  it('lead back to the tab they were pushed over, and tabs have no back arrow', () => {
    expect(pushedParent('/app/field')).toBeNull();
    expect(pushedParent('/app/field/goals')).toBeNull();
    expect(pushedParent('/app/field/calendar')).toBe('/app/field');
    expect(pushedParent('/app/field/archive')).toBe('/app/field');
    expect(pushedParent('/app/field/seed/abc')).toBe('/app/field');
    expect(pushedParent('/app/field/goals/abc')).toBe('/app/field/goals');
    expect(pushedParent('/app/body/gym')).toBeNull();
    expect(pushedParent('/app/body/gym/programs/abc')).toBe('/app/body/gym');
    expect(pushedParent('/app/body/gym/sessions/abc')).toBe('/app/body/gym');
    expect(pushedParent('/app/records')).toBeNull();
    expect(pushedParent('/app/records/lists/abc')).toBeNull();
    expect(pushedParent('/app/records/abc')).toBe('/app/records');
    expect(pushedParent('/app/records/trash')).toBe('/app/records');
    expect(pushedParent('/app/records/gallery')).toBeNull();
    expect(pushedParent('/app/records/gallery', '?album=abc')).toBe('/app/records/gallery');
    expect(pushedParent('/app/granary')).toBeNull();
  });
});

describe('the on-screen keyboard', () => {
  it('counts as up only while a field has the focus and the viewport has shrunk', () => {
    const input = document.createElement('input');
    const box = document.createElement('input');
    box.type = 'checkbox';
    expect(keyboardUp(400, 844, input)).toBe(true);
    expect(keyboardUp(830, 844, input)).toBe(false);
    expect(keyboardUp(400, 844, box)).toBe(false);
    expect(keyboardUp(400, 844, document.body)).toBe(false);
  });
});

describe('the archive', () => {
  async function archived() {
    const h = await device(new FakeServer());
    const seed = await h.seeds.plant({ type: 'todo', title: 'Read at night' });
    await h.seeds.archive(seed.uuid, 'Done with it');
    render(
      <HarvestContext.Provider value={h}>
        <MemoryRouter>
          <ArchiveScreen />
          <Toaster />
        </MemoryRouter>
      </HarvestContext.Provider>,
    );
    return { h, uuid: seed.uuid };
  }

  it('lists what was put away, with its note, and restores it to the field', async () => {
    const { h, uuid } = await archived();
    expect(await screen.findByRole('link', { name: 'Read at night' })).toHaveAttribute('href', `/app/field/seed/${uuid}`);
    expect(screen.getByText('Done with it')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Restore' }));
    await waitFor(async () => expect((await h.db.rows('commitments').get(uuid))?.archivedAt).toBeNull());
    expect(await screen.findByText('Nothing put away yet')).toBeInTheDocument();
  });

  it('deletes one for good once asked, and sends it as purged', async () => {
    const { h, uuid } = await archived();
    await userEvent.click(await screen.findByRole('button', { name: 'Delete' }));
    const ask = await screen.findByRole('alertdialog');
    expect(ask).toHaveTextContent('Delete this seed?');
    await userEvent.click(within(ask).getByRole('button', { name: 'Delete' }));
    await waitFor(async () => expect(await h.db.rows('commitments').get(uuid)).toBeUndefined());
    const outbox = await h.db.table('outbox').toArray();
    expect(outbox.some((row: { table: string; key: string; op: string }) => row.table === 'commitments' && row.key === uuid && row.op === 'delete')).toBe(true);
  });
});
