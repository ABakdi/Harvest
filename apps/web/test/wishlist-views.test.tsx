import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router';
import { describe, expect, it, vi } from 'vitest';
import { HarvestContext } from '@/app/context';
import type { WishlistRow } from '@/app/data/wishlist';
import { DialogsProvider } from '@/app/dialogs';
import { WishlistEditor } from '@/app/components/wishlist-editor';
import { WishlistPanel } from '@/app/screens/wishlist';
import { formatDay } from '@/lib/format';
import { FakeServer } from './fake-server';
import { device } from './helpers';

function item(uuid: string, list: 'buy' | 'wish', title: string, priceMinor: number | null = null, extra: Partial<WishlistRow> = {}): WishlistRow {
  return {
    uuid,
    list,
    title,
    priceMinor,
    currency: 'DZD',
    note: null,
    targetDay: null,
    boughtAt: null,
    position: 0,
    createdAt: '2026-09-01T10:00:00.000Z',
    updatedAt: '2026-09-01T10:00:00.000Z',
    deletedAt: null,
    ...extra,
  };
}

async function withWishlist() {
  const h = await device(new FakeServer());
  await h.db.rows('wishlist_items').bulkPut([
    item('coat', 'buy', 'Winter coat', 1_800_000, { targetDay: '2026-10-15' }),
    item('kettle', 'buy', 'Kettle', 85_000),
    item('espresso', 'wish', 'Espresso machine', 540_000),
  ]);
  return h;
}

function renderPanel(h: Awaited<ReturnType<typeof withWishlist>>) {
  render(
    <HarvestContext.Provider value={h}>
      <MemoryRouter>
        <DialogsProvider>
          <WishlistPanel />
        </DialogsProvider>
      </MemoryRouter>
    </HarvestContext.Provider>,
  );
}

describe('the wishlist', () => {
  it('shows the buy list with estimates, their total, and the planned day', async () => {
    const h = await withWishlist();
    renderPanel(h);

    expect(await screen.findByText('Winter coat')).toBeInTheDocument();
    expect(screen.getByText('Kettle')).toBeInTheDocument();
    expect(screen.queryByText('Espresso machine')).not.toBeInTheDocument(); // the wish segment stays on its side
    expect(screen.getByText('In 26 days')).toBeInTheDocument();
    expect(screen.getByText('DA18,000')).toBeInTheDocument(); // the coat's own estimate
    expect(screen.getByText('DA850')).toBeInTheDocument(); // the kettle's own estimate
    expect(screen.getByText('DA18,850')).toBeInTheDocument(); // the open total per currency
    expect(screen.getByRole('checkbox', { name: 'Mark “Winter coat” bought' })).toBeInTheDocument();
  });

  it('buying checks the item off into the bought fold, and un-buying brings it back (W3)', async () => {
    const h = await withWishlist();
    renderPanel(h);
    const user = userEvent.setup();

    await user.click(await screen.findByRole('checkbox', { name: 'Mark “Kettle” bought' }));
    await waitFor(() => expect(screen.queryByRole('checkbox', { name: 'Mark “Kettle” bought' })).not.toBeInTheDocument());
    await screen.findByRole('checkbox', { name: 'Unmark “Kettle” bought' });
    expect(screen.getByText('1 bought')).toBeInTheDocument();

    // Open the fold and take the purchase back (W3).
    screen.getByText('1 bought').click();
    await user.click(screen.getByRole('checkbox', { name: 'Unmark “Kettle” bought' }));
    await waitFor(() => expect(screen.getByRole('checkbox', { name: 'Mark “Kettle” bought' })).toBeInTheDocument());
    expect(screen.getByText('Kettle')).toBeInTheDocument();
  });

  it('the wish segment has no buy checkbox — a wish is meant, not bought', async () => {
    const h = await withWishlist();
    renderPanel(h);

    await userEvent.setup().click(await screen.findByRole('radio', { name: 'Wishlist' }));
    expect(await screen.findByText('Espresso machine')).toBeInTheDocument();
    expect(screen.queryByRole('checkbox')).not.toBeInTheDocument();
    expect(screen.getAllByText('DA5,400').length).toBeGreaterThan(0); // its estimate, and the open total
  });

  it('a row shows its planned day and its note together', async () => {
    const h = await device(new FakeServer());
    await h.db.rows('wishlist_items').put(item('coat', 'buy', 'Winter coat', null, { targetDay: '2026-10-15', note: 'Wool, dark grey' }));
    renderPanel(h);

    expect(await screen.findByText('In 26 days · Wool, dark grey')).toBeInTheDocument();
  });

  it('a bought wish item stays in view, with no bought fold (W7)', async () => {
    const h = await device(new FakeServer());
    await h.db.rows('wishlist_items').put(item('espresso', 'wish', 'Espresso machine', null, { boughtAt: '2026-09-10T10:00:00.000Z' }));
    renderPanel(h);

    await userEvent.setup().click(await screen.findByRole('radio', { name: 'Wishlist' }));
    expect(await screen.findByText('Espresso machine')).toBeInTheDocument();
    expect(screen.queryByText(/bought/)).not.toBeInTheDocument();
    expect(screen.queryByRole('checkbox')).not.toBeInTheDocument();
  });

  it('says a purchase made after midnight belongs to the Harvest Day before', async () => {
    const h = await device(new FakeServer());
    // 01:30 local time is still the 17th's Harvest Day (the day turns at 3 AM).
    const boughtAt = new Date(2026, 8, 18, 1, 30).toISOString();
    await h.db.rows('wishlist_items').put(item('kettle', 'buy', 'Kettle', null, { boughtAt }));
    renderPanel(h);

    await screen.findByText('1 bought');
    expect(screen.getByText(`Bought on ${formatDay('2026-09-17', { dateStyle: 'medium' })}`)).toBeInTheDocument();
  });

  it('a failed save keeps the editor open and ready to try again', async () => {
    const h = await device(new FakeServer());
    const add = vi.spyOn(h.wishlist, 'add').mockRejectedValue(new Error('disk full'));
    const onClose = vi.fn();
    render(
      <HarvestContext.Provider value={h}>
        <WishlistEditor item={null} list="buy" onClose={onClose} />
      </HarvestContext.Provider>,
    );
    const user = userEvent.setup();

    await user.type(screen.getByLabelText('What'), 'Kettle');
    await user.click(screen.getByRole('button', { name: 'Add' }));

    await waitFor(() => expect(add).toHaveBeenCalled());
    await waitFor(() => expect(screen.getByRole('button', { name: 'Add' })).toBeEnabled());
    expect(onClose).not.toHaveBeenCalled();
  });
});
