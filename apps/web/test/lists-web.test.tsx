import { buyListId, readListId, watchListId, wishListId } from '@harvest/contracts';
import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes, useLocation } from 'react-router';
import { toast, Toaster } from 'sonner';
import { afterEach, describe, expect, it } from 'vitest';
import { FeatureSwitchList } from '@/app/components/settings-bits';
import { HarvestContext } from '@/app/context';
import { DialogsProvider } from '@/app/dialogs';
import { features, type FeatureSwitches } from '@/app/data/settings';
import { GranaryScreen } from '@/app/screens/granary';
import { ListsScreen } from '@/app/screens/lists';
import { RecordsTabs, RecordsView } from '@/app/screens/records';
import { FakeServer } from './fake-server';
import { device, testUser } from './helpers';

// Radix's pieces measure themselves; jsdom has nothing to measure with.
globalThis.ResizeObserver ??= class {
  observe() {}
  unobserve() {}
  disconnect() {}
};

// Each test starts with no toast left over from the one before.
afterEach(() => {
  toast.dismiss();
});

/**
 * Records → Lists on the web ([[Lists]]): the chips, the kinds, the
 * add field that takes a pasted link, and the rules — same-kind moves
 * (L2), deleting a list with its items (L6), no buying a wish (L7), no
 * fetching (L9), and built-ins that stay (L10).
 */

type Device = Awaited<ReturnType<typeof device>>;

async function withLists(on = true): Promise<Device> {
  const h = await device(new FakeServer());
  await h.lists.ensureBuiltIns();
  if (on) await h.settings.setBool('features.lists', true);
  return h;
}

function Where() {
  return <span data-testid="where">{useLocation().pathname}</span>;
}

function show(h: Device, at = '/app/records/lists') {
  render(
    <HarvestContext.Provider value={h}>
      <MemoryRouter initialEntries={[at]}>
        <DialogsProvider>
          <Routes>
            <Route
              path="/app/records/lists/:listUuid?"
              element={
                <RecordsView feature="lists">
                  <ListsScreen />
                </RecordsView>
              }
            />
            <Route path="/app/records/:uuid" element={<p>the note</p>} />
            <Route path="/app/granary" element={<GranaryScreen />} />
          </Routes>
          <Where />
        </DialogsProvider>
      </MemoryRouter>
      <Toaster />
    </HarvestContext.Provider>,
  );
}

async function menu(name: string) {
  const user = userEvent.setup();
  (await screen.findByRole('button', { name })).focus();
  await user.keyboard('{Enter}');
  return user;
}

const items = async (h: Device) => (await h.db.rows('wishlist_items').toArray()).filter((row) => row.deletedAt === null);

describe('the lists view', () => {
  it('shows the built-in lists as chips with their localised names and open counts', async () => {
    const h = await withLists();
    await h.lists.addItem(buyListId, { title: 'Kettle', priceMinor: 85_000 });
    await h.lists.addItem(buyListId, { title: 'Winter coat', priceMinor: 1_800_000 });
    await h.lists.addItem(readListId, { title: 'Dune' });
    show(h);

    const chips = await screen.findByRole('navigation', { name: 'Lists' });
    expect(within(chips).getByRole('link', { name: 'To buy, 2 open' })).toHaveAttribute('aria-current', 'page');
    expect(within(chips).getByRole('link', { name: 'To read, 1 open' })).toBeInTheDocument();
    expect(within(chips).getByRole('link', { name: 'Wishlist, 0 open' })).toBeInTheDocument();
    expect(within(chips).getByRole('link', { name: 'To watch, 0 open' })).toBeInTheDocument();
    expect(await screen.findByText('Kettle')).toBeInTheDocument();
    expect(screen.getByText('DA18,850')).toBeInTheDocument(); // the open total, per currency
    expect(screen.queryByText('Dune')).toBeNull(); // another list's item
  });

  it('shows a renamed built-in by my name, not the localised one', async () => {
    const h = await withLists();
    await h.lists.renameList(readListId, 'Books');
    show(h, `/app/records/lists/${readListId}`);
    expect(await screen.findByRole('heading', { name: 'Books' })).toBeInTheDocument();
  });

  it('is a Records tab only while its switch is on, and says so when opened by link while off', async () => {
    const h = await withLists(false);
    show(h);
    expect(await screen.findByText('Notes, the Gallery, Places and Lists are switched off')).toBeInTheDocument();

    await h.settings.setBool('features.notes', true);
    expect(await screen.findByText('Lists are switched off')).toBeInTheDocument();
  });

  it('offers the Lists tab in Records and the switch in Extras', async () => {
    const h = await withLists();
    render(
      <HarvestContext.Provider value={h}>
        <MemoryRouter>
          <RecordsTabs />
          <FeatureSwitchList values={Object.fromEntries(features.map((f) => [f, false])) as FeatureSwitches} onChange={() => {}} />
        </MemoryRouter>
      </HarvestContext.Provider>,
    );
    expect(await screen.findByRole('link', { name: 'Lists' })).toHaveAttribute('href', '/app/records/lists');
    expect(screen.getByRole('switch', { name: 'Lists' })).not.toBeChecked();
  });
});

describe('making, renaming and deleting lists', () => {
  it('makes a list of a kind and opens it', async () => {
    const h = await withLists();
    show(h);
    const user = userEvent.setup();

    await user.click(await screen.findByRole('button', { name: 'New list' }));
    const dialog = await screen.findByRole('dialog');
    await user.type(within(dialog).getByLabelText('Name'), 'Podcasts');
    await user.click(within(dialog).getByRole('radio', { name: 'Media' }));
    await user.click(within(dialog).getByRole('button', { name: 'Create' }));

    expect(await screen.findByRole('heading', { name: 'Podcasts' })).toBeInTheDocument();
    const made = (await h.db.rows('lists').toArray()).find((row) => row.name === 'Podcasts')!;
    expect(made).toMatchObject({ kind: 'media', builtIn: null });
    expect(screen.getByTestId('where')).toHaveTextContent(`/app/records/lists/${made.uuid}`);
  });

  it('never offers to delete a built-in list (L10)', async () => {
    const h = await withLists();
    show(h);
    await menu('Options for the list “To buy”');
    expect(await screen.findByRole('menuitem', { name: 'Rename' })).toBeInTheDocument();
    expect(screen.queryByRole('menuitem', { name: 'Delete list' })).toBeNull();
    expect(screen.getByRole('menuitem', { name: 'Move earlier' })).toHaveAttribute('data-disabled');
  });

  it('deletes a list with its items, and undo brings both back (L6)', async () => {
    const h = await withLists();
    const packing = await h.lists.createList({ name: 'Packing', kind: 'plain' });
    await h.lists.addItem(packing.uuid, { title: 'Charger' });
    await h.lists.addItem(packing.uuid, { title: 'Passport' });
    show(h, `/app/records/lists/${packing.uuid}`);

    const user = await menu('Options for the list “Packing”');
    await user.click(await screen.findByRole('menuitem', { name: 'Delete list' }));
    await waitFor(async () => expect(await items(h)).toHaveLength(0));
    expect((await h.db.rows('lists').get(packing.uuid))?.deletedAt).not.toBeNull();

    // Clicked without moving the focus into the toast, as the other undo tests do.
    fireEvent.click(await screen.findByRole('button', { name: 'Undo' }));
    await waitFor(async () => expect(await items(h)).toHaveLength(2));
    expect((await h.db.rows('lists').get(packing.uuid))?.deletedAt).toBeNull();
    expect(await screen.findByText('Passport')).toBeInTheDocument();
  });

  it('moves a list later in the row', async () => {
    const h = await withLists();
    show(h);
    const user = await menu('Options for the list “To buy”');
    await user.click(await screen.findByRole('menuitem', { name: 'Move later' }));
    await waitFor(async () => expect((await h.db.rows('lists').get(buyListId))?.position).toBe(1));
    expect((await h.db.rows('lists').get(wishListId))?.position).toBe(0);
  });
});

describe('items', () => {
  it('moves only to a list of the same kind (L2)', async () => {
    const h = await withLists();
    await h.lists.addItem(buyListId, { title: 'Kettle' });
    show(h);
    const user = await menu('Options for “Kettle”');
    expect(await screen.findByRole('menuitem', { name: 'Move to Wishlist' })).toBeInTheDocument();
    expect(screen.queryByRole('menuitem', { name: 'Move to To read' })).toBeNull();
    expect(screen.queryByRole('menuitem', { name: 'Move to To watch' })).toBeNull();

    await user.click(screen.getByRole('menuitem', { name: 'Move to Wishlist' }));
    await waitFor(async () => expect((await items(h))[0]).toMatchObject({ listUuid: wishListId, list: 'wish' }));
  });

  it('gives a wish no way to be bought: it moves to To buy first (L7)', async () => {
    const h = await withLists();
    await h.lists.addItem(wishListId, { title: 'Espresso machine' });
    show(h, `/app/records/lists/${wishListId}`);
    expect(await screen.findByText('Espresso machine')).toBeInTheDocument();
    expect(screen.queryByRole('checkbox')).toBeNull();
  });

  it('reorders open items from the keyboard, and keeps the focus on the one moved', async () => {
    const h = await withLists();
    const a = await h.lists.addItem(buyListId, { title: 'Apples' });
    const b = await h.lists.addItem(buyListId, { title: 'Bread' });
    show(h);
    const apples = await screen.findByRole('button', { name: 'Apples' });
    apples.focus();
    fireEvent.keyDown(apples, { key: 'ArrowDown', altKey: true });

    await waitFor(async () => expect((await h.db.rows('wishlist_items').get(a.uuid))?.position).toBe(1));
    expect((await h.db.rows('wishlist_items').get(b.uuid))?.position).toBe(0);
    await waitFor(() => expect(screen.getByRole('button', { name: 'Apples' })).toHaveFocus());
  });

  it('ticks a plain item into the done fold, and takes it back', async () => {
    const h = await withLists();
    const ideas = await h.lists.createList({ name: 'Ideas', kind: 'plain' });
    await h.lists.addItem(ideas.uuid, { title: 'Paint the door' });
    show(h, `/app/records/lists/${ideas.uuid}`);
    const user = userEvent.setup();

    await user.click(await screen.findByRole('checkbox', { name: 'Mark “Paint the door” done' }));
    expect(await screen.findByText('1 done')).toBeInTheDocument();
    await user.click(screen.getByRole('checkbox', { name: 'Unmark “Paint the door” done' }));
    await waitFor(() => expect(screen.queryByText('1 done')).toBeNull());
  });

  it('deletes an item with undo', async () => {
    const h = await withLists();
    await h.lists.addItem(buyListId, { title: 'Kettle' });
    show(h);
    const user = await menu('Options for “Kettle”');
    await user.click(await screen.findByRole('menuitem', { name: 'Delete' }));
    await waitFor(async () => expect(await items(h)).toHaveLength(0));
    // Clicked without moving the focus into the toast, as the other undo tests do.
    fireEvent.click(await screen.findByRole('button', { name: 'Undo' }));
    await waitFor(async () => expect(await items(h)).toHaveLength(1));
  });
});

describe('a media item', () => {
  it('goes want → in progress → finished, and takes a rating', async () => {
    const h = await withLists();
    const dune = await h.lists.addItem(readListId, { title: 'Dune', mediaType: 'book', creator: 'Frank Herbert' });
    show(h, `/app/records/lists/${readListId}`);
    const user = userEvent.setup();

    expect(await screen.findByText('Book · Frank Herbert')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Start “Dune”' }));
    expect(await screen.findByText('In progress')).toBeInTheDocument();
    expect((await h.db.rows('wishlist_items').get(dune.uuid))?.startedAt).not.toBeNull();

    await user.click(screen.getByRole('button', { name: 'Finish “Dune”' }));
    const fold = await screen.findByText('1 finished');
    fold.click();
    await user.click(await screen.findByRole('button', { name: '4 stars' }));
    await waitFor(async () => expect((await h.db.rows('wishlist_items').get(dune.uuid))?.rating).toBe(4));
    await waitFor(() => expect(screen.getByRole('button', { name: '4 stars' })).toHaveAttribute('aria-pressed', 'true'));
  });

  it('opens its link only in a new tab, telling the site nothing', async () => {
    const h = await withLists();
    await h.lists.addItem(readListId, { title: 'An essay', link: 'https://example.com/essay' });
    await h.lists.addItem(readListId, { title: 'Odd', link: 'javascript:alert(1)' });
    show(h, `/app/records/lists/${readListId}`);

    const link = await screen.findByRole('link', { name: 'Open the link for “An essay” in a new tab' });
    expect(link).toHaveAttribute('href', 'https://example.com/essay');
    expect(link).toHaveAttribute('target', '_blank');
    expect(link).toHaveAttribute('rel', 'noopener noreferrer');
    // Not a web link: no way to open it at all.
    expect(screen.queryByRole('link', { name: /“Odd”/ })).toBeNull();
  });
});

describe('the add field', () => {
  it('takes a pasted video link as the link and the title, and a video as its type', async () => {
    const h = await withLists();
    show(h, `/app/records/lists/${watchListId}`);
    const user = userEvent.setup();

    const field = await screen.findByRole('textbox', { name: 'New item in To watch' });
    await user.click(field);
    await user.paste('https://youtu.be/dQw4w9WgXcQ');
    expect(field).toHaveValue('');
    expect(screen.getByText('https://youtu.be/dQw4w9WgXcQ')).toBeInTheDocument();
    await user.keyboard('{Enter}');

    await waitFor(async () => expect(await items(h)).toHaveLength(1));
    expect((await items(h))[0]).toMatchObject({
      listUuid: watchListId,
      title: 'https://youtu.be/dQw4w9WgXcQ',
      link: 'https://youtu.be/dQw4w9WgXcQ',
      mediaType: 'video',
    });
  });

  it('uses a title typed after the paste, and reads any other host as an article', async () => {
    const h = await withLists();
    show(h, `/app/records/lists/${readListId}`);
    const user = userEvent.setup();

    const field = await screen.findByRole('textbox', { name: 'New item in To read' });
    await user.click(field);
    await user.paste('https://example.com/long-read');
    await user.type(field, 'A long read{Enter}');

    await waitFor(async () => expect(await items(h)).toHaveLength(1));
    expect((await items(h))[0]).toMatchObject({ title: 'A long read', link: 'https://example.com/long-read', mediaType: 'article' });
  });

  it('reads a typed bare link as a pasted one', async () => {
    const h = await withLists();
    show(h, `/app/records/lists/${readListId}`);
    const user = userEvent.setup();
    await user.type(await screen.findByRole('textbox', { name: 'New item in To read' }), 'https://example.com/a{Enter}');
    await waitFor(async () => expect(await items(h)).toHaveLength(1));
    expect((await items(h))[0]).toMatchObject({ title: 'https://example.com/a', link: 'https://example.com/a', mediaType: 'article' });
  });

  it('on a list without links, the pasted link is the title', async () => {
    const h = await withLists();
    show(h);
    const user = userEvent.setup();
    const field = await screen.findByRole('textbox', { name: 'New item in To buy' });
    await user.click(field);
    await user.paste('https://shop.example/kettle');
    await user.keyboard('{Enter}');
    await waitFor(async () => expect(await items(h)).toHaveLength(1));
    expect((await items(h))[0]).toMatchObject({ title: 'https://shop.example/kettle', link: null, listUuid: buyListId });
  });
});

describe('tied into the rest of the app', () => {
  it('bought offers the expense sheet prefilled, and logs nothing by itself (L4)', async () => {
    const h = await withLists();
    await h.keyring.unlock('a long passphrase', testUser.syncSalt, 1);
    await h.lists.addItem(buyListId, { title: 'Kettle', priceMinor: 85_000, currency: 'DZD' });
    show(h);
    const user = userEvent.setup();

    await user.click(await screen.findByRole('checkbox', { name: 'Mark “Kettle” bought' }));
    const dialog = await screen.findByRole('dialog');
    expect(await within(dialog).findByDisplayValue('850')).toBeInTheDocument();
    expect(within(dialog).getByDisplayValue('Kettle')).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Cancel' }));

    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    expect(await h.db.rows('expenses').count()).toBe(0);
    expect((await items(h))[0]?.boughtAt).not.toBeNull();
  });

  it('plants a book as a project, links it, shows its progress and offers to finish the item', async () => {
    const h = await withLists();
    const dune = await h.lists.addItem(readListId, { title: 'Dune', mediaType: 'book' });
    show(h, `/app/records/lists/${readListId}`);

    const user = await menu('Options for “Dune”');
    await user.click(await screen.findByRole('menuitem', { name: 'Plant as a seed' }));
    const dialog = await screen.findByRole('dialog');
    expect(within(dialog).getByRole('textbox', { name: 'Title' })).toHaveValue('Dune');
    expect(within(dialog).getByRole('radio', { name: 'Project' })).toHaveAttribute('data-state', 'on');
    await user.type(within(dialog).getByLabelText('Total target (pages, minutes…)'), '300');
    await user.type(within(dialog).getByLabelText('Daily commitment'), '10');
    await user.click(within(dialog).getByRole('button', { name: 'Plant a seed' }));

    await waitFor(async () => expect((await h.db.rows('wishlist_items').get(dune.uuid))?.seedUuid).toBeTruthy());
    const seed = (await h.db.rows('commitments').toArray())[0]!;
    expect(seed).toMatchObject({ type: 'project', title: 'Dune', totalTarget: 300 });
    expect((await h.db.rows('wishlist_items').get(dune.uuid))?.seedUuid).toBe(seed.uuid);
    expect(await screen.findByText('Seed: 0 of 300')).toBeInTheDocument();

    // A month of reading later: the whole target logged.
    await h.db.rows('check_ins').put({
      uuid: 'read-it-all',
      commitmentUuid: seed.uuid,
      harvestDay: '2026-09-19',
      quantity: 300,
      loggedAt: '2026-09-19T12:00:00.000Z',
      deletedAt: null,
      updatedAt: '2026-09-19T12:00:00.000Z',
    });
    await user.click(await screen.findByRole('button', { name: 'Mark finished too' }));
    await waitFor(async () => expect((await h.db.rows('wishlist_items').get(dune.uuid))?.boughtAt).not.toBeNull());
  });

  it('writes about a media item in a note named after it, and opens that note again', async () => {
    const h = await withLists();
    await h.settings.setBool('features.notes', true);
    const dune = await h.lists.addItem(readListId, { title: 'Dune' });
    show(h, `/app/records/lists/${readListId}`);

    const user = await menu('Options for “Dune”');
    await user.click(await screen.findByRole('menuitem', { name: 'Write about it' }));
    expect(await screen.findByText('the note')).toBeInTheDocument();
    const note = (await h.db.rows('notes').toArray())[0]!;
    expect(note.title).toBe('Dune');
    expect((await h.db.rows('wishlist_items').get(dune.uuid))?.noteUuid).toBe(note.uuid);
    expect(screen.getByTestId('where')).toHaveTextContent(`/app/records/${note.uuid}`);
  });
});

describe('the Granary', () => {
  it('has no Wishlist tab, and a planned purchases line that opens To buy (L3)', async () => {
    const h = await withLists();
    await h.keyring.unlock('a long passphrase', testUser.syncSalt, 1);
    await h.lists.addItem(buyListId, { title: 'Kettle', priceMinor: 85_000, currency: 'DZD' });
    await h.lists.addItem(buyListId, { title: 'Lamp', priceMinor: 20_00, currency: 'EUR' });
    await h.lists.addItem(wishListId, { title: 'Espresso machine', priceMinor: 540_000, currency: 'DZD' });
    show(h, '/app/granary');

    const line = await screen.findByRole('link', { name: /Planned purchases/ });
    expect(line).toHaveAttribute('href', `/app/records/lists/${buyListId}`);
    expect(line).toHaveTextContent('DA850');
    expect(line).toHaveTextContent('€20');
    expect(line).not.toHaveTextContent('5,400'); // a wish is not planned
    expect(screen.queryByRole('tab', { name: 'Wishlist' })).toBeNull();
    expect(await h.db.rows('expenses').count()).toBe(0);
  });

  it('shows no line while Lists is off', async () => {
    const h = await withLists(false);
    await h.keyring.unlock('a long passphrase', testUser.syncSalt, 1);
    await h.lists.addItem(buyListId, { title: 'Kettle', priceMinor: 85_000 });
    show(h, '/app/granary');
    expect(await screen.findByRole('tab', { name: 'Expenses' })).toBeInTheDocument();
    expect(screen.queryByRole('link', { name: /Planned purchases/ })).toBeNull();
  });
});
