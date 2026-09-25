import { Blob as NodeBlob } from 'node:buffer';
import { deriveSyncKey, maxFileBytes, openFile } from '@harvest/contracts';
import { HarvestDay } from '@harvest/core';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router';
import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { HarvestContext } from '@/app/context';
import { FileTooLargeError, sha256Of } from '@/app/data/files';
import { memoryPath } from '@/app/data/gallery';
import { GalleryScreen } from '@/app/screens/gallery';
import { ApiError, api } from '@/lib/api';
import { FakeServer } from './fake-server';
import { device, testUser } from './helpers';

beforeAll(() => {
  // jsdom's Blob does not survive IndexedDB's structured clone; Node's
  // does, as a browser's does.
  vi.stubGlobal('Blob', NodeBlob);
  // jsdom has no object URLs; a picture only needs to be named.
  if (!URL.createObjectURL) {
    Object.assign(URL, { createObjectURL: () => 'blob:picture', revokeObjectURL: () => undefined });
  }
});

afterEach(() => {
  vi.restoreAllMocks();
});

const today = HarvestDay.of(new Date('2026-09-19T12:00:00.000Z'));

function picture(seed = 7): Blob {
  const bytes = new Uint8Array(256);
  for (let i = 0; i < bytes.length; i++) bytes[i] = (i * seed) % 256;
  return new Blob([bytes], { type: 'image/jpeg' });
}

async function xpOf(h: Awaited<ReturnType<typeof device>>): Promise<number> {
  return (await h.db.rows('ledger').toArray()).filter((row) => row.kind === 'xp').reduce((sum, row) => sum + row.delta, 0);
}

describe('albums and memories (G3, G5)', () => {
  it('pays the first picture of a day in a scheduled album, and only the first', async () => {
    const h = await device(new FakeServer());
    const album = await h.gallery.createAlbum({ name: ' Face ', schedule: { type: 'daily' }, remindAt: '20:00', note: null });
    expect(album.name).toBe('Face');
    expect(album.scheduleJson).toBe('{"type":"daily"}');

    const first = await h.gallery.addMemory(album, { blob: picture(), kind: 'photo', extension: '.jpg', note: ' day one ' });
    expect(first.path).toBe(memoryPath(album.uuid, today.key, first.uuid, '.jpg'));
    expect(first.path).toMatch(new RegExp(`^${album.uuid}/2026-09-19-[0-9a-f]{8}\\.jpg$`));
    expect(first.note).toBe('day one');
    expect(first.fileHash).toBeNull();
    expect(await xpOf(h)).toBe(10);
    expect((await h.db.rows('streaks').get(album.uuid))?.current).toBe(1);

    const second = await h.gallery.addMemory(album, { blob: picture(3), kind: 'photo', extension: '.jpg' });
    expect(await xpOf(h)).toBe(10);

    // One of two gone: the day is still earned.
    await h.gallery.removeMemory(second.uuid);
    expect(await xpOf(h)).toBe(10);
    // The last one gone: the day is taken back with a mirror row.
    await h.gallery.removeMemory(first.uuid);
    expect(await xpOf(h)).toBe(0);
    expect((await h.db.rows('ledger').where('reason').equals(`memory-undo:${first.uuid}`).toArray())[0]?.delta).toBe(-10);
    expect((await h.db.rows('streaks').get(album.uuid))?.current).toBe(0);

    // Restored as the only one of its day: paid again.
    await h.gallery.restoreMemory(first.uuid);
    expect(await xpOf(h)).toBe(10);
    expect((await h.db.rows('streaks').get(album.uuid))?.current).toBe(1);
  });

  it('pays nothing for a shoebox album', async () => {
    const h = await device(new FakeServer());
    const album = await h.gallery.createAlbum({ name: 'Flat', schedule: null, remindAt: '08:00', note: '  ' });
    expect(album.remindAt).toBeNull();
    expect(album.note).toBeNull();
    await h.gallery.addMemory(album, { blob: picture(), kind: 'photo', extension: '.jpg' });
    expect(await xpOf(h)).toBe(0);
  });

  it('empties the trash for good: rows purged, this browser’s copy gone', async () => {
    const h = await device(new FakeServer());
    const album = await h.gallery.createAlbum({ name: 'Gym', schedule: null, remindAt: null, note: null });
    const memory = await h.gallery.addMemory(album, { blob: picture(), kind: 'photo', extension: '.jpg' });
    const hash = await h.files.localHash(memory.uuid);
    expect(await h.db.files.get(hash!)).toBeDefined();

    await h.gallery.removeMemory(memory.uuid);
    expect(await h.gallery.emptyTrash()).toBe(1);
    expect(await h.db.rows('memories').get(memory.uuid)).toBeUndefined();
    expect(await h.db.files.get(hash!)).toBeUndefined();
    expect(await h.db.outbox.where('[table+key]').equals(['memories', memory.uuid]).last()).toMatchObject({ op: 'delete' });
  });
});

describe('file upload ([[Sync-API]], files)', () => {
  it('refuses a file past 25 MB before keeping it', async () => {
    const h = await device(new FakeServer());
    await expect(h.files.keep(new Blob([new Uint8Array(maxFileBytes + 1)]))).rejects.toBeInstanceOf(FileTooLargeError);
    expect(await h.db.files.count()).toBe(0);
  });

  it('sends nothing before the passphrase is set', async () => {
    const h = await device(new FakeServer());
    const asking = vi.spyOn(api, 'filesMissing');
    const album = await h.gallery.createAlbum({ name: 'Gym', schedule: null, remindAt: null, note: null });
    await h.gallery.addMemory(album, { blob: picture(), kind: 'photo', extension: '.jpg' });
    const report = await h.files.upload();
    expect(report.waiting).toBe(1);
    expect(asking).not.toHaveBeenCalled();
  });

  it('asks what is missing, sends it sealed under its name, and stamps the row', async () => {
    const h = await device(new FakeServer());
    const key = await deriveSyncKey('a long passphrase', testUser.syncSalt, { iterations: 1 });
    const blob = picture();
    const sha256 = await sha256Of(await blob.arrayBuffer());
    const missing = vi.spyOn(api, 'filesMissing').mockResolvedValue({ missing: [sha256], usedBytes: 0, quotaBytes: 1 });
    const sent: { sha: string; sealed: ArrayBuffer; iv: string; plain: number }[] = [];
    vi.spyOn(api, 'putFile').mockImplementation((sha, sealed, iv, plain) => {
      sent.push({ sha, sealed, iv, plain });
      return Promise.resolve({ sha256: sha, bytes: sealed.byteLength, had: false });
    });

    const album = await h.gallery.createAlbum({ name: 'Gym', schedule: null, remindAt: null, note: null });
    // Kept while locked; the passphrase is what lets it leave.
    const memory = await h.gallery.addMemory(album, { blob, kind: 'photo', extension: '.jpg' });
    // The pass the add started finds no key and sends nothing.
    expect((await h.files.upload()).uploaded).toBe(0);
    await h.keyring.unlock('a long passphrase', testUser.syncSalt, 1);
    const report = await h.files.upload();

    expect(missing).toHaveBeenCalledWith([sha256]);
    expect(report).toMatchObject({ uploaded: 1, stamped: 1, waiting: 0, quotaExceeded: false });
    expect(sent).toHaveLength(1);
    expect(sent[0]!.sha).toBe(sha256);
    expect(sent[0]!.plain).toBe(256);
    // Sealed with the private tier's key, the file's name as its additional data.
    const opened = await openFile(key, sha256, { iv: sent[0]!.iv, ct: sent[0]!.sealed });
    expect(new Uint8Array(opened)).toEqual(new Uint8Array(await blob.arrayBuffer()));

    const row = await h.db.rows('memories').get(memory.uuid);
    expect(row?.fileHash).toBe(sha256);
    expect(row!.updatedAt >= memory.updatedAt).toBe(true);
    expect(await h.files.localHash(memory.uuid)).toBeNull();
  });

  it('stamps without sending when the server already has the bytes', async () => {
    const h = await device(new FakeServer());
    await h.keyring.unlock('a long passphrase', testUser.syncSalt, 1);
    vi.spyOn(api, 'filesMissing').mockResolvedValue({ missing: [], usedBytes: 0, quotaBytes: 1 });
    const put = vi.spyOn(api, 'putFile');
    const album = await h.gallery.createAlbum({ name: 'Gym', schedule: null, remindAt: null, note: null });
    const memory = await h.gallery.addMemory(album, { blob: picture(), kind: 'photo', extension: '.jpg' });
    await h.files.upload();
    expect(put).not.toHaveBeenCalled();
    expect((await h.db.rows('memories').get(memory.uuid))?.fileHash).not.toBeNull();
  });

  it('keeps the file here and says so when the account is full (507)', async () => {
    const h = await device(new FakeServer());
    const album = await h.gallery.createAlbum({ name: 'Gym', schedule: null, remindAt: null, note: null });
    vi.spyOn(api, 'filesMissing').mockImplementation((hashes) => Promise.resolve({ missing: hashes, usedBytes: 0, quotaBytes: 1 }));
    vi.spyOn(api, 'putFile').mockRejectedValue(new ApiError(507, 'quota_exceeded', 'No room'));

    const memory = await h.gallery.addMemory(album, { blob: picture(), kind: 'photo', extension: '.jpg' });
    // The pass the add started finds no key and sends nothing.
    expect((await h.files.upload()).uploaded).toBe(0);
    await h.keyring.unlock('a long passphrase', testUser.syncSalt, 1);
    const report = await h.files.upload();
    expect(report.quotaExceeded).toBe(true);
    expect(h.files.problem).toBe('quota');
    expect((await h.db.rows('memories').get(memory.uuid))?.fileHash).toBeNull();
    expect(await h.files.localHash(memory.uuid)).not.toBeNull();

    render(
      <MemoryRouter initialEntries={['/app/records/gallery']}>
        <HarvestContext.Provider value={h}>
          <GalleryScreen />
        </HarvestContext.Provider>
      </MemoryRouter>,
    );
    expect(await screen.findByRole('alert')).toHaveTextContent(/no room left/i);
  });
});

describe('the gallery screen', () => {
  function renderGallery(h: Awaited<ReturnType<typeof device>>) {
    return render(
      <MemoryRouter initialEntries={['/app/records/gallery']}>
        <HarvestContext.Provider value={h}>
          <GalleryScreen />
        </HarvestContext.Provider>
      </MemoryRouter>,
    );
  }

  it('makes a scheduled album, adds a picture from a file, and shows its streak', async () => {
    const h = await device(new FakeServer());
    const user = userEvent.setup();
    renderGallery(h);

    await user.click(await screen.findByRole('button', { name: 'New album' }));
    await user.type(screen.getByLabelText('Album'), 'Face');
    await user.click(screen.getByRole('radio', { name: 'Daily' }));
    await user.click(screen.getByRole('button', { name: 'Create album' }));

    // Straight into the new album.
    expect(await screen.findByRole('heading', { name: 'Face' })).toBeInTheDocument();
    const album = (await h.db.rows('albums').toArray())[0]!;
    expect(album.scheduleJson).toBe('{"type":"daily"}');

    await user.click(screen.getByRole('button', { name: 'Add' }));
    const dialog = await screen.findByRole('dialog');
    await user.type(within(dialog).getByLabelText('Note'), 'After the run');
    await user.upload(within(dialog).getByTestId('capture-pickPhoto'), new File([picture()], 'IMG_0001.HEIC', { type: 'image/heic' }));

    await waitFor(async () => expect(await h.db.rows('memories').count()).toBe(1));
    const memory = (await h.db.rows('memories').toArray())[0]!;
    // Not decodable here, so kept as it came, extension and all.
    expect(memory.path.endsWith('.heic')).toBe(true);
    expect(memory.note).toBe('After the run');
    expect(await xpOf(h)).toBe(10);
    expect(await screen.findByRole('button', { name: /^Photo · / })).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Back to the albums' }));
    expect(await screen.findByText(/^1 picture · a seed on the field/)).toBeInTheDocument();
    expect(screen.getByText('Done')).toBeInTheDocument();
  });

  it('edits a memory’s note in the viewer, trashes it, and puts it back from the trash', async () => {
    const h = await device(new FakeServer());
    const album = await h.gallery.createAlbum({ name: 'Gym', schedule: null, remindAt: null, note: null });
    const memory = await h.gallery.addMemory(album, { blob: picture(), kind: 'photo', extension: '.jpg' });
    const user = userEvent.setup();
    renderGallery(h);

    await user.click(await screen.findByRole('button', { name: /^Gym/ }));
    await user.click(await screen.findByRole('button', { name: /^Photo · / }));
    const viewer = await screen.findByRole('dialog');
    await user.click(within(viewer).getByRole('button', { name: 'Note' }));
    await user.type(within(viewer).getByRole('textbox', { name: 'Note' }), 'Week one');
    await user.click(within(viewer).getByRole('button', { name: 'Save' }));
    await waitFor(async () => expect((await h.db.rows('memories').get(memory.uuid))?.note).toBe('Week one'));

    await user.click(within(viewer).getByRole('button', { name: 'Delete' }));
    await waitFor(async () => expect((await h.db.rows('memories').get(memory.uuid))?.deletedAt).not.toBeNull());

    await user.click(screen.getByRole('button', { name: 'Back to the albums' }));
    await user.click(await screen.findByRole('button', { name: 'Trash (1)' }));
    await user.click(await screen.findByRole('button', { name: 'Put it back' }));
    await waitFor(async () => expect((await h.db.rows('memories').get(memory.uuid))?.deletedAt).toBeNull());
  });

  it('deletes an album into the trash with everything in it', async () => {
    const h = await device(new FakeServer());
    const album = await h.gallery.createAlbum({ name: 'Flat', schedule: null, remindAt: null, note: null });
    const user = userEvent.setup();
    renderGallery(h);
    await user.click(await screen.findByRole('button', { name: /Flat/ }));
    (await screen.findByRole('button', { name: 'Album options' })).focus();
    await user.keyboard('{Enter}');
    await user.click(await screen.findByRole('menuitem', { name: 'Delete' }));
    await user.click(await screen.findByRole('button', { name: 'Delete' }));
    await waitFor(async () => expect((await h.db.rows('albums').get(album.uuid))?.deletedAt).not.toBeNull());
    expect(await screen.findByRole('button', { name: 'New album' })).toBeInTheDocument();
  });
});
