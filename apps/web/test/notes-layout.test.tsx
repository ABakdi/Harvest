import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { useState, type ReactNode } from 'react';
import { MemoryRouter, Route, Routes, useLocation } from 'react-router';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { fillsViewport } from '@/app/app-shell';
import { AppBarLeadingSlot, AppBarSlot, AppBarTitleSlot } from '@/app/components/app-bar';
import { NavTabs } from '@/app/components/screen-tabs';
import { HarvestContext } from '@/app/context';
import { NotesScreen } from '@/app/screens/notes';
import { linksOnLine, offsetOfLine } from '@/app/screens/notes/editor';
import { noteToReopen } from '@/app/screens/notes/vault';
import { TabsList, Tabs } from '@/components/ui/tabs';
import { api } from '@/lib/api';
import { parseBlocks } from '@/lib/markdown';
import { FileTextIcon } from 'lucide-react';
import { FakeServer } from './fake-server';
import { device } from './helpers';

type Device = Awaited<ReturnType<typeof device>>;

/** The shell's app bar, with the slots a screen puts its title and actions in. */
function Bar({ children }: { children: ReactNode }) {
  const [leading, setLeading] = useState<HTMLElement | null>(null);
  const [title, setTitle] = useState<HTMLElement | null>(null);
  const [actions, setActions] = useState<HTMLElement | null>(null);
  return (
    <>
      <header data-testid="bar">
        <div ref={setLeading} />
        <div ref={setTitle} data-testid="bar-title" />
        <div ref={setActions} />
      </header>
      <AppBarLeadingSlot.Provider value={leading}>
        <AppBarTitleSlot.Provider value={title}>
          <AppBarSlot.Provider value={actions}>{children}</AppBarSlot.Provider>
        </AppBarTitleSlot.Provider>
      </AppBarLeadingSlot.Provider>
    </>
  );
}

function Where() {
  const location = useLocation();
  return <p data-testid="where">{location.pathname}</p>;
}

function phoneWidth() {
  vi.spyOn(window, 'matchMedia').mockImplementation(
    (query: string) =>
      ({
        matches: query.includes('48rem'),
        media: query,
        onchange: null,
        addEventListener: () => {},
        removeEventListener: () => {},
        addListener: () => {},
        removeListener: () => {},
        dispatchEvent: () => false,
      }),
  );
}

async function show(at: string, setup: (h: Device) => Promise<void> = async () => {}) {
  vi.spyOn(api, 'assistStatus').mockResolvedValue({ available: false, model: null, usedToday: 0, dailyLimit: 50 });
  const h = await device(new FakeServer());
  await h.settings.setString('features.notes', 'true');
  await setup(h);
  render(
    <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
      <MemoryRouter initialEntries={[at]}>
        <HarvestContext.Provider value={h}>
          <Bar>
            <Routes>
              <Route path="/app/records" element={<NotesScreen />} />
              <Route path="/app/records/trash" element={<NotesScreen trash />} />
              <Route path="/app/records/:uuid" element={<NotesScreen />} />
            </Routes>
            <Where />
          </Bar>
        </HarvestContext.Provider>
      </MemoryRouter>
    </QueryClientProvider>,
  );
  return h;
}

beforeEach(() => localStorage.clear());
afterEach(() => vi.restoreAllMocks());

describe('the notes page fills the window', () => {
  it('holds for Notes, a note and the trash, and for no other screen', () => {
    expect(fillsViewport('/app/records')).toBe(true);
    expect(fillsViewport('/app/records/0f4e2a1c-0000-4000-8000-000000000000')).toBe(true);
    expect(fillsViewport('/app/records/trash')).toBe(true);
    for (const path of ['/app/records/lists', '/app/records/lists/abc', '/app/records/gallery', '/app/records/places', '/app/field', '/app/granary']) {
      expect(fillsViewport(path)).toBe(false);
    }
  });

  it('scrolls the note and the tree inside themselves, each on its own', async () => {
    let uuid = '';
    await show('/app/records', async (h) => {
      uuid = (await h.notes.create({ title: 'Long' })).uuid;
    });
    await userEvent.click(await screen.findByRole('link', { name: 'Long' }));
    await waitFor(() => expect(screen.getByTestId('where')).toHaveTextContent(uuid));
    const pane = document.querySelector('[data-note-scroller]')!;
    expect(pane).toHaveClass('overflow-y-auto', 'min-h-0', 'flex-1');
    expect(screen.getByRole('navigation', { name: 'Folders' })).toHaveClass('overflow-y-auto', 'min-h-0', 'flex-1');
    // The note grows rather than scroll inside itself.
    expect(screen.getByLabelText('Note')).toHaveClass('note-source');
  });
});

describe('the vault as a tree (wide window)', () => {
  it('folds and unfolds folders with their notes, remembers it, and marks the open note', async () => {
    let sleep = '';
    await show('/app/records', async (h) => {
      sleep = (await h.notes.create({ title: 'Sleep log', folder: 'Health/Sleep' })).uuid;
      await h.notes.create({ title: 'Top', folder: '' });
    });
    const health = await screen.findByRole('button', { name: 'Health' });
    expect(health).toHaveAttribute('aria-expanded', 'true');
    expect(screen.getByRole('link', { name: 'Sleep log' })).toBeInTheDocument();

    await userEvent.click(health);
    expect(health).toHaveAttribute('aria-expanded', 'false');
    expect(screen.queryByRole('link', { name: 'Sleep log' })).not.toBeInTheDocument();
    expect(JSON.parse(localStorage.getItem('harvest.notes.folded') ?? '[]')).toEqual(['Health']);

    await userEvent.click(health);
    await userEvent.click(await screen.findByRole('link', { name: 'Sleep log' }));
    await waitFor(() => expect(screen.getByTestId('where')).toHaveTextContent(sleep));
    expect(screen.getByRole('link', { name: 'Sleep log' })).toHaveAttribute('aria-current', 'page');
    expect(screen.getByTestId('note-path')).toHaveTextContent('Health/Sleep/Sleep log');

    await userEvent.click(screen.getByRole('button', { name: 'Collapse all folders' }));
    expect(screen.queryByRole('link', { name: 'Sleep log' })).not.toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Top' })).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Expand all folders' }));
    expect(screen.getByRole('link', { name: 'Sleep log' })).toBeInTheDocument();
  });

  it('searches titles and text into a flat list', async () => {
    await show('/app/records', async (h) => {
      await h.notes.create({ title: 'Bread', body: 'flour and water', folder: 'Kitchen' });
      await h.notes.create({ title: 'Run', body: 'five kilometres' });
    });
    await userEvent.type(await screen.findByLabelText('Search titles and text'), 'flour');
    const list = screen.getByRole('list', { name: 'Notes' });
    expect(within(list).getAllByRole('link').map((link) => link.textContent)).toEqual(['Breadflour and water']);
    await userEvent.type(screen.getByLabelText('Search titles and text'), 'zzz');
    expect(screen.getByText('Nothing matches that')).toBeInTheDocument();
  });

  it('keeps the hidden labels of the formatting bar inside it, so they cannot widen the page', async () => {
    await show('/app/records', async (h) => {
      await h.notes.create({ title: 'Plan' });
    });
    await userEvent.click(await screen.findByRole('link', { name: 'Plan' }));
    expect(await screen.findByRole('toolbar', { name: 'Formatting' })).toHaveClass('relative', 'overflow-x-auto', 'no-scrollbar');
  });

  it('drops a new note left empty once I leave it (U6-08)', async () => {
    const h = await show('/app/records', async (h) => {
      await h.notes.create({ title: 'Kept' });
    });
    await userEvent.click((await screen.findAllByRole('button', { name: 'New note' }))[0]!);
    await waitFor(async () => expect(await h.db.rows('notes').count()).toBe(2));
    await userEvent.click(screen.getByRole('link', { name: 'Kept' }));
    await waitFor(async () => expect((await h.db.rows('notes').toArray()).map((row) => row.title)).toEqual(['Kept']));
  });
});

describe('Notes on a phone-width window, as on the phone', () => {
  beforeEach(phoneWidth);

  it('opens on the note I was last in, and on the latest when that one is gone', async () => {
    let older = '';
    await show('/app/records', async (h) => {
      older = (await h.notes.create({ title: 'Older' })).uuid;
      h.clock.advance(60_000);
      await h.notes.create({ title: 'Newer' });
      localStorage.setItem('harvest.notes.last', older);
    });
    await waitFor(() => expect(screen.getByTestId('where')).toHaveTextContent(older));
    // The app bar carries the note's title and its actions.
    expect(within(screen.getByTestId('bar-title')).getByText('Older')).toBeInTheDocument();
    expect(within(screen.getByTestId('bar')).getByRole('button', { name: 'More' })).toBeInTheDocument();
    expect(within(screen.getByTestId('bar')).getByRole('button', { name: 'New note' })).toBeInTheDocument();
  });

  it('opens on the list when I closed the note on purpose, with the drawer a tap away', async () => {
    await show('/app/records', async (h) => {
      await h.notes.create({ title: 'Walk', folder: 'Days' });
      localStorage.setItem('harvest.notes.last', '');
    });
    expect(await screen.findByText('Pick a note')).toBeInTheDocument();
    expect(screen.getByTestId('where')).toHaveTextContent(/^\/app\/records$/);
    // The button on the page; the app bar has one too, where the phone's menu is.
    expect(screen.getAllByRole('button', { name: 'Show notes' })).toHaveLength(2);
    await userEvent.click(screen.getAllByRole('button', { name: 'Show notes' }).at(-1)!);
    const drawer = await screen.findByRole('dialog', { name: 'Notes' });
    // Folded, as the phone's drawer starts; a tap unfolds it.
    await userEvent.click(within(drawer).getByRole('button', { name: 'Days' }));
    await userEvent.click(within(drawer).getByRole('link', { name: 'Walk' }));
    await waitFor(() => expect(screen.queryByRole('dialog', { name: 'Notes' })).not.toBeInTheDocument());
    expect(screen.getByTestId('where')).toHaveTextContent(/\/app\/records\/.+/);
  });

  it('says there are none yet and offers the floating New note', async () => {
    const h = await show('/app/records');
    expect(await screen.findByText('No notes yet')).toBeInTheDocument();
    expect(screen.getByText('Tap + to keep what you thought about the day.')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'New note' }));
    await waitFor(async () => expect(await h.db.rows('notes').count()).toBe(1));
  });

  it('writes where I tap: the rendered note gives way to its markdown, the caret on that line', async () => {
    const body = '# Plan\n\nFirst paragraph.\n\n- one\n- two see [[Walk]]';
    await show('/app/records', async (h) => {
      await h.notes.create({ title: 'Walk' });
      await h.notes.update((await h.notes.create({ title: 'Plan' })).uuid, { body });
      localStorage.setItem('harvest.notes.last', (await h.db.rows('notes').toArray()).find((row) => row.title === 'Plan')!.uuid);
    });
    const rendered = await screen.findByTestId('note-rendered');
    expect(screen.queryByLabelText('Note', { selector: 'textarea' })).not.toBeInTheDocument();
    await userEvent.click(within(rendered).getByText('one'));
    const field = await screen.findByLabelText<HTMLTextAreaElement>('Note', { selector: 'textarea' });
    await waitFor(() => expect(field).toHaveFocus());
    expect(field.selectionStart).toBe(body.indexOf('- one'));
    // The bar on the keyboard, while writing.
    expect(screen.getByRole('toolbar', { name: 'Formatting' })).toBeInTheDocument();
    // A link on the caret's line is a chip to follow.
    field.setSelectionRange(body.length, body.length);
    fireEvent.keyUp(field);
    expect(await screen.findByRole('button', { name: 'Walk' })).toBeInTheDocument();
  });

  it('asks before deleting a note, then opens the latest one', async () => {
    let doomed = '';
    let other = '';
    const h = await show('/app/records', async (h) => {
      other = (await h.notes.create({ title: 'Stays' })).uuid;
      h.clock.advance(60_000);
      doomed = (await h.notes.create({ title: 'Goes' })).uuid;
    });
    await waitFor(() => expect(screen.getByTestId('where')).toHaveTextContent(doomed));
    within(screen.getByTestId('bar')).getByRole('button', { name: 'More' }).focus();
    await userEvent.keyboard('{Enter}');
    await userEvent.click(await screen.findByRole('menuitem', { name: 'Delete' }));
    const ask = await screen.findByRole('alertdialog', { name: 'Delete this note?' });
    expect((await h.db.rows('notes').get(doomed))?.deletedAt).toBeNull();
    await userEvent.click(within(ask).getByRole('button', { name: 'Delete' }));
    await waitFor(async () => expect((await h.db.rows('notes').get(doomed))?.deletedAt).not.toBeNull());
    await waitFor(() => expect(screen.getByTestId('where')).toHaveTextContent(other));
  });

  it('moves a note to a folder from its menu', async () => {
    let uuid = '';
    const h = await show('/app/records', async (h) => {
      await h.notes.addFolder('Health');
      uuid = (await h.notes.create({ title: 'Sleep' })).uuid;
    });
    await waitFor(() => expect(screen.getByTestId('where')).toHaveTextContent(uuid));
    within(screen.getByTestId('bar')).getByRole('button', { name: 'More' }).focus();
    await userEvent.keyboard('{Enter}');
    await userEvent.click(await screen.findByRole('menuitem', { name: 'Move to folder' }));
    await userEvent.click(within(await screen.findByRole('dialog', { name: 'Move to folder' })).getByRole('button', { name: 'Health' }));
    await waitFor(async () => expect((await h.db.rows('notes').get(uuid))?.folder).toBe('Health'), { timeout: 3000 });
    expect(within(screen.getByTestId('bar-title')).getByText('Health')).toBeInTheDocument();
  });

  it('asks before letting a note in the trash go for good', async () => {
    let uuid = '';
    const h = await show('/app/records/trash', async (h) => {
      uuid = (await h.notes.create({ title: 'Old' })).uuid;
      await h.notes.remove(uuid);
    });
    await userEvent.click(await screen.findByRole('button', { name: 'Delete “Old” for good' }));
    const ask = await screen.findByRole('alertdialog', { name: 'Delete this for good?' });
    expect(await h.db.rows('notes').get(uuid)).toBeDefined();
    await userEvent.click(within(ask).getByRole('button', { name: 'Delete for good' }));
    await waitFor(async () => expect(await h.db.rows('notes').get(uuid)).toBeUndefined());
  });
});

describe('the pieces under it', () => {
  it('knows the line each rendered block starts on', () => {
    const source = 'Intro\n\n## Head\n- a\n- b\n\n```\ncode\n```\n> quote';
    expect(parseBlocks(source).map((block) => [block.kind, block.line])).toEqual([
      ['paragraph', 0],
      ['heading', 2],
      ['list', 3],
      ['code', 6],
      ['quote', 9],
    ]);
    expect(offsetOfLine(source, 3)).toBe(source.indexOf('- a'));
    expect(offsetOfLine(source, 99)).toBe(source.length);
  });

  it('finds the links on the caret line only', () => {
    const text = 'see [[One]]\nand [[Two]] and [[Two]] and [[Three]]';
    expect(linksOnLine(text, 3)).toEqual(['One']);
    expect(linksOnLine(text, text.length)).toEqual(['Two', 'Three']);
  });

  it('reopens the remembered note, the latest without one, and none after a close', () => {
    const at = (uuid: string, updatedAt: string) => ({ uuid, updatedAt }) as never;
    const notes = [at('a', '2026-09-01T00:00:00Z'), at('b', '2026-09-02T00:00:00Z')];
    expect(noteToReopen(notes, 'a')).toMatchObject({ uuid: 'a' });
    expect(noteToReopen(notes, null)).toMatchObject({ uuid: 'b' });
    expect(noteToReopen(notes, 'gone')).toMatchObject({ uuid: 'b' });
    expect(noteToReopen(notes, '')).toBeNull();
    expect(noteToReopen([], null)).toBeNull();
  });
});

describe('scrollbars', () => {
  const css = readFileSync(resolve(__dirname, '../src/index.css'), 'utf8');

  it('are thin, themed, arrowless and shown on hover, in Chrome and in Firefox', () => {
    expect(css).toMatch(/@supports not selector\(::-webkit-scrollbar\)[\s\S]*scrollbar-width: thin[\s\S]*scrollbar-color: transparent transparent[\s\S]*\*:hover \{\s*scrollbar-color: var\(--scrollbar-thumb\) transparent/);
    expect(css).toMatch(/::-webkit-scrollbar-button \{[^}]*display: none/);
    expect(css).toMatch(/:hover::-webkit-scrollbar-thumb[\s\S]*background-color: var\(--scrollbar-thumb\)/);
    // Both themes name the thumb's colour.
    expect(css.match(/--scrollbar-thumb:/g)).toHaveLength(2);
    expect(css).toMatch(/@utility no-scrollbar \{\s*scrollbar-width: none;[\s\S]*::-webkit-scrollbar \{\s*display: none/);
  });

  it('are hidden on the strips of tabs that scroll by swipe', () => {
    render(
      <MemoryRouter>
        <NavTabs label="Records" tabs={[{ to: '/a', label: 'A', icon: FileTextIcon }]} />
        <Tabs>
          <TabsList aria-label="Kinds" />
        </Tabs>
      </MemoryRouter>,
    );
    expect(screen.getByRole('navigation', { name: 'Records' })).toHaveClass('no-scrollbar');
    expect(screen.getByRole('tablist', { name: 'Kinds' })).toHaveClass('no-scrollbar');
  });
});
