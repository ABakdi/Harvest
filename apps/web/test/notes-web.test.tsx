import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Blob as NodeBlob } from 'node:buffer';
import { MemoryRouter, Route, Routes } from 'react-router';
import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { addTableColumn, addTableRow, insertTable, starterTable, tableAt } from '@/app/components/notes/markdown-actions';
import { speechLanguageOf, speechParagraphs } from '@/app/components/notes/voice';
import { HarvestContext } from '@/app/context';
import { audioEmbedsIn, audioExtensionOf, voiceFileName } from '@/app/data/attachments';
import { decodeFolders } from '@/app/data/notes';
import { settingKeys, settingText } from '@/app/data/settings';
import { NotesScreen } from '@/app/screens/notes';
import { api } from '@/lib/api';
import { Markdown } from '@/lib/markdown';
import { FakeServer } from './fake-server';
import { device } from './helpers';

beforeAll(() => {
  // Node's Blob survives IndexedDB's structured clone, as a browser's does.
  vi.stubGlobal('Blob', NodeBlob);
  if (!URL.createObjectURL) {
    Object.assign(URL, { createObjectURL: () => 'blob:recording', revokeObjectURL: () => undefined });
  }
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe('table edits (the phone’s markdown actions)', () => {
  it('inserts a starter table on its own line, the first header selected', () => {
    const at = insertTable({ text: 'Plan', start: 4, end: 4 });
    expect(at.text).toBe(`Plan\n${starterTable}\n`);
    expect(at.text.slice(at.start, at.end)).toBe('Column');
    expect(insertTable({ text: '', start: 0, end: 0 }).text).toBe(`${starterTable}\n`);
  });

  it('adds a row and a column only inside a table, the divider staying a divider', () => {
    const text = '| A | B |\n| --- | --- |\n| 1 | 2 |\n\nafter';
    expect(tableAt({ text, start: text.length, end: text.length })).toBeNull();
    const row = addTableRow({ text, start: 2, end: 2 })!;
    expect(row.text).toBe('| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |\n\nafter');
    const column = addTableColumn({ text: '| A |\n| --- |\n|  |', start: 2, end: 2 })!;
    expect(column.text).toBe('| A |   |\n| --- | --- |\n|  |   |');
    expect(addTableRow({ text: 'no table', start: 1, end: 1 })).toBeNull();
  });
});

describe('what is read aloud (N10)', () => {
  it('drops the markdown and the embeds, and splits paragraphs', () => {
    const body = '# Title\n\n**Bold** and [[Other|a link]].\n![[Voice 2026-09-19 14-32.m4a]]\n\n| A | B |\n| --- | --- |\n| 1 | 2 |\n\n```\ncode\n```';
    // The divider reads as nothing, so a table's head and body part, as on the phone.
    expect(speechParagraphs(body)).toEqual(['Title', 'Bold and a link.', 'A, B', '1, 2']);
  });

  it('picks Arabic when most letters are', () => {
    expect(speechLanguageOf('مرحبا بالعالم', 'en')).toBe('ar');
    expect(speechLanguageOf('Hello world', 'ar')).toBe('ar');
    expect(speechLanguageOf('Hello world', 'en')).toBe('en');
  });
});

describe('recordings (N7)', () => {
  it('names a recording by its minute, with a counter when taken', () => {
    const at = new Date(2026, 8, 19, 14, 32);
    expect(voiceFileName(at)).toBe('Voice 2026-09-19 14-32.m4a');
    expect(voiceFileName(at, new Set(['Voice 2026-09-19 14-32.m4a']))).toBe('Voice 2026-09-19 14-32 (2).m4a');
    expect(voiceFileName(at, new Set(), 'ogg')).toBe('Voice 2026-09-19 14-32.ogg');
  });

  it('counts only audio embeds, and files an upload by an extension the phone keeps', () => {
    expect(audioEmbedsIn('![[a.m4a]] ![[picture.png]] ![[b.OGG]]')).toEqual(['a.m4a', 'b.OGG']);
    expect(audioExtensionOf({ name: 'memo.mp3', type: '' })).toBe('mp3');
    expect(audioExtensionOf({ name: 'memo', type: 'audio/x-m4a' })).toBe('m4a');
    expect(audioExtensionOf({ name: 'clip.webm', type: 'video/webm' })).toBeNull();
  });

  it('files a recording beside its note and trashes it when its line goes', async () => {
    const h = await device(new FakeServer());
    const note = await h.notes.create({ title: 'Walk' });
    const row = await h.attachments.add({
      noteUuid: note.uuid,
      blob: new Blob([new Uint8Array([1, 2, 3])], { type: 'audio/mp4' }),
      fileName: 'Voice 2026-09-19 14-32.m4a',
      durationMs: 4200,
    });
    expect(row).toMatchObject({ kind: 'audio', storedPath: `${note.uuid}/Voice 2026-09-19 14-32.m4a`, sizeBytes: 3, fileHash: null });
    expect(await h.files.localHash(row.uuid)).not.toBeNull();

    await h.attachments.reconcile(note.uuid, 'no embed any more');
    expect((await h.db.rows('note_attachments').get(row.uuid))?.deletedAt).not.toBeNull();
    await h.attachments.reconcile(note.uuid, '![[voice 2026-09-19 14-32.M4A]]');
    expect((await h.db.rows('note_attachments').get(row.uuid))?.deletedAt).toBeNull();
  });
});

describe('folders from the sidebar', () => {
  it('trashes a folder and its subfolders’ notes, and the undo brings back exactly those', async () => {
    const h = await device(new FakeServer());
    const a = await h.notes.create({ title: 'A', folder: 'Health' });
    const b = await h.notes.create({ title: 'B', folder: 'Health/Sleep' });
    const c = await h.notes.create({ title: 'C', folder: 'Work' });
    await h.notes.addFolder('Health/Empty');
    const trashed = await h.notes.trashFolder('Health');
    expect(trashed.sort()).toEqual([a.uuid, b.uuid].sort());
    expect((await h.db.rows('notes').get(c.uuid))?.deletedAt).toBeNull();
    const declared = async () => decodeFolders(settingText((await h.db.rows('kv_settings').get(settingKeys.noteFolders))?.valueJson));
    expect(await declared()).toEqual([]);

    await h.notes.restoreFolder('Health', trashed);
    expect((await h.db.rows('notes').get(a.uuid))?.deletedAt).toBeNull();
    expect((await h.db.rows('notes').get(b.uuid))?.deletedAt).toBeNull();
    expect(await declared()).toEqual(['Health']);
  });
});

describe('the notes screen', () => {
  async function open(path: string, setup?: (h: Awaited<ReturnType<typeof device>>) => Promise<void>) {
    vi.spyOn(api, 'assistStatus').mockResolvedValue({ available: false, model: null, usedToday: 0, dailyLimit: 50 });
    const h = await device(new FakeServer());
    await h.settings.setString('features.notes', 'true');
    await setup?.(h);
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(
      <QueryClientProvider client={client}>
        <MemoryRouter initialEntries={[path]}>
          <HarvestContext.Provider value={h}>
            <Routes>
              <Route path="/app/records" element={<NotesScreen />} />
              <Route path="/app/records/:uuid" element={<NotesScreen />} />
            </Routes>
          </HarvestContext.Provider>
        </MemoryRouter>
      </QueryClientProvider>,
    );
    return h;
  }

  it('renames a folder from its menu, taking its notes along', async () => {
    let note = '';
    const h = await open('/app/records', async (h) => {
      note = (await h.notes.create({ title: 'Sleep log', folder: 'Health/Sleep' })).uuid;
    });
    const user = userEvent.setup();
    (await screen.findByRole('button', { name: 'Folder options: Health' })).focus();
    await user.keyboard('{Enter}');
    await user.click(await screen.findByRole('menuitem', { name: 'Rename folder' }));
    const dialog = await screen.findByRole('dialog');
    const name = within(dialog).getByLabelText('Folder name');
    await user.clear(name);
    await user.type(name, 'Body');
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    await waitFor(async () => expect((await h.db.rows('notes').get(note))?.folder).toBe('Body/Sleep'));
  });

  it('makes a new note inside a folder from its menu', async () => {
    const h = await open('/app/records', async (h) => {
      await h.notes.addFolder('Reading');
    });
    const user = userEvent.setup();
    (await screen.findByRole('button', { name: 'Folder options: Reading' })).focus();
    await user.keyboard('{Enter}');
    await user.click(await screen.findByRole('menuitem', { name: 'New note here' }));
    await waitFor(async () => expect((await h.db.rows('notes').toArray()).map((row) => row.folder)).toEqual(['Reading']));
  });

  it('inserts a table from the toolbar, then offers a row inside it', async () => {
    let uuid = '';
    const h = await open('/app/records', async (h) => {
      uuid = (await h.notes.create({ title: 'Plan' })).uuid;
    });
    const user = userEvent.setup();
    await user.click(await screen.findByRole('link', { name: /Plan/ }));
    // An empty note opens on Write.
    await user.click(await screen.findByRole('button', { name: 'Table' }));
    expect(screen.getByLabelText('Note')).toHaveValue(`${starterTable}\n`);
    await user.click(await screen.findByRole('button', { name: /Add a row/ }));
    expect(screen.getByLabelText('Note')).toHaveValue(`${starterTable}\n|  |  |  |\n`);
    await waitFor(async () => expect((await h.db.rows('notes').get(uuid))?.body).toContain('| Column |'), { timeout: 3000 });
  });

  it('attaches a recording file, embeds it at the caret and lists it', async () => {
    let uuid = '';
    const h = await open('/app/records', async (h) => {
      uuid = (await h.notes.create({ title: 'Walk' })).uuid;
    });
    const user = userEvent.setup();
    await user.click(await screen.findByRole('link', { name: /Walk/ }));
    await user.upload(screen.getByTestId('attach-recording'), new File([new Uint8Array([9, 9, 9])], 'River.mp3', { type: 'audio/mpeg' }));

    await waitFor(async () => expect(await h.db.rows('note_attachments').count()).toBe(1));
    expect(await screen.findByRole('heading', { name: 'Recordings' })).toBeInTheDocument();
    expect(await screen.findByLabelText('Download River.mp3')).toBeInTheDocument();
    await waitFor(async () => expect((await h.db.rows('notes').get(uuid))?.body).toBe('![[River.mp3]]\n'), { timeout: 3000 });
  });

  it('puts only the note on the page for print, named for the PDF', async () => {
    // What the print dialog would see, at the moment it opens.
    const seen: { page: HTMLElement | null; title: string }[] = [];
    vi.stubGlobal(
      'print',
      vi.fn(() => {
        const page = document.querySelector<HTMLElement>('[data-testid="note-print"]');
        seen.push({ page: page ? (page.cloneNode(true) as HTMLElement) : null, title: document.title });
      }),
    );
    await open('/app/records', async (h) => {
      await h.notes.update((await h.notes.create({ title: 'Bread / notes' })).uuid, { body: '# Rise\n\n| A | B |\n| --- | --- |\n| 1 | 2 |' });
    });
    const user = userEvent.setup();
    await user.click(await screen.findByRole('link', { name: /Bread/ }));
    (await screen.findByRole('button', { name: 'More' })).focus();
    await user.keyboard('{Enter}');
    await user.click(await screen.findByRole('menuitem', { name: 'Print or save as PDF' }));
    await waitFor(() => expect(seen).toHaveLength(1));
    const { page, title } = seen[0]!;
    expect(page).not.toBeNull();
    expect(within(page!).getByRole('heading', { name: 'Bread / notes', hidden: true })).toBeTruthy();
    expect(within(page!).getByRole('table', { hidden: true })).toBeTruthy();
    expect(title).not.toContain('/');
    // Gone again once the dialog closes.
    await waitFor(() => expect(screen.queryByTestId('note-print')).not.toBeInTheDocument());
  });

  it('hides dictation and read aloud where the browser cannot do them on this computer', async () => {
    await open('/app/records', async (h) => {
      await h.notes.create({ title: 'Quiet' });
    });
    const user = userEvent.setup();
    await user.click(await screen.findByRole('link', { name: /Quiet/ }));
    await screen.findByRole('toolbar', { name: 'Formatting' });
    expect(screen.queryByRole('button', { name: 'Dictate' })).not.toBeInTheDocument();
    (await screen.findByRole('button', { name: 'More' })).focus();
    await user.keyboard('{Enter}');
    await screen.findByRole('menuitem', { name: 'Print or save as PDF' });
    expect(screen.queryByRole('menuitem', { name: 'Read aloud' })).not.toBeInTheDocument();
  });
});

describe('the renderer', () => {
  it('draws a table and an embed without raw markup', () => {
    render(<Markdown source={'| Day | Weight |\n| --- | --- |\n| Mon | **80** |\n\n![[Voice.m4a]]'} />);
    expect(screen.getByRole('columnheader', { name: 'Weight' })).toBeInTheDocument();
    expect(screen.getByRole('cell', { name: '80' })).toBeInTheDocument();
    expect(screen.getByText('Voice.m4a')).toBeInTheDocument();
    expect(screen.queryByText(/!\[\[/)).not.toBeInTheDocument();
  });
});
