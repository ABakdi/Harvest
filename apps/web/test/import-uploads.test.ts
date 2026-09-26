import { Blob as NodeBlob } from 'node:buffer';
import { maxFileBytes } from '@harvest/contracts';
import { waitFor } from '@testing-library/react';
import { zipSync } from 'fflate';
import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { buildWorkbook, ExportSheet, type CellValue } from '@/app/data/archive-xlsx';
import { sha256Of } from '@/app/data/files';
import { applyImport, openArchive } from '@/app/data/import';
import { api } from '@/lib/api';
import { FakeServer } from './fake-server';
import { device, testUser } from './helpers';

/**
 * What an archive brings in reaches the server like a picture taken
 * here: into the same upload queue, sent sealed, and its row stamped
 * only once the server has the bytes ([[Sync-API]], files).
 */

beforeAll(() => {
  // jsdom's Blob does not survive IndexedDB's structured clone; Node's does.
  vi.stubGlobal('Blob', NodeBlob);
});

afterEach(() => {
  vi.restoreAllMocks();
});

function bytesOf(length: number, seed: number): Uint8Array<ArrayBuffer> {
  const bytes = new Uint8Array(length);
  for (let i = 0; i < length; i++) bytes[i] = (i * seed + 3) % 256;
  return bytes;
}

function archive(sheets: Record<string, CellValue[][]>, files: Record<string, Uint8Array>): Uint8Array {
  const workbook = buildWorkbook(
    Object.entries(sheets).map(([name, [headers, ...rows]]) => new ExportSheet({ name, headers: headers as string[], rows })),
  );
  return zipSync({ 'harvest.xlsx': workbook, ...files }, { level: 0 });
}

const stamp = '2026-09-05T10:00:00Z';

/** A picture and a recording, neither of them named by its row. */
async function withFiles(pictureHash: string | null = null) {
  const picture = bytesOf(96, 11);
  const recording = bytesOf(40, 17);
  const bundle = openArchive(
    archive(
      {
        Albums: [
          ['Uuid', 'Name', 'UpdatedAt'],
          ['a1', 'Face', stamp],
        ],
        Memories: [
          ['Uuid', 'AlbumUuid', 'HarvestDay', 'File', 'FileHash', 'UpdatedAt'],
          ['m1', 'a1', '2026-09-05', 'gallery/Face/2026-09-05.jpg', pictureHash, stamp],
        ],
        Notes: [
          ['Uuid', 'Title', 'Body', 'UpdatedAt'],
          ['n1', 'Run', 'body', stamp],
        ],
        NoteAttachments: [
          ['Uuid', 'NoteUuid', 'FileName', 'File', 'UpdatedAt'],
          ['r1', 'n1', 'run.m4a', 'notes/run.m4a', stamp],
        ],
      },
      { 'gallery/Face/2026-09-05.jpg': picture, 'notes/run.m4a': recording },
    ),
  );
  return {
    bundle,
    pictureHash: await sha256Of(picture.slice().buffer),
    recordingHash: await sha256Of(recording.slice().buffer),
  };
}

function fakeFileServer(has: string[] = []) {
  const held = new Set(has);
  const put = vi.spyOn(api, 'putFile').mockImplementation((sha, sealed) => {
    held.add(sha);
    return Promise.resolve({ sha256: sha, bytes: sealed.byteLength, had: false });
  });
  const missing = vi
    .spyOn(api, 'filesMissing')
    .mockImplementation((hashes) => Promise.resolve({ missing: hashes.filter((hash) => !held.has(hash)), usedBytes: 0, quotaBytes: 1 }));
  return { put, missing };
}

describe('files an archive brings in', () => {
  it('wait unnamed in the upload queue, then are sent sealed and their rows stamped', async () => {
    const h = await device(new FakeServer());
    const { put } = fakeFileServer();
    const { bundle, pictureHash, recordingHash } = await withFiles();

    await applyImport(h.writer, bundle, { files: h.files });
    // Nothing leaves before the passphrase, and no row names a file the server lacks.
    expect((await h.db.rows('memories').get('m1'))!.fileHash).toBeNull();
    expect((await h.db.rows('note_attachments').get('r1'))!.fileHash).toBeNull();
    expect(await h.files.localHashes()).toEqual(
      new Map([
        ['m1', pictureHash],
        ['r1', recordingHash],
      ]),
    );
    expect(put).not.toHaveBeenCalled();

    await h.keyring.unlock('a long passphrase', testUser.syncSalt, 1);
    const report = await h.files.upload();
    expect(report).toMatchObject({ uploaded: 2, stamped: 2, waiting: 0 });
    expect(put.mock.calls.map(([sha]) => sha).sort()).toEqual([pictureHash, recordingHash].sort());
    expect((await h.db.rows('memories').get('m1'))!.fileHash).toBe(pictureHash);
    expect((await h.db.rows('note_attachments').get('r1'))!.fileHash).toBe(recordingHash);
    // Stamped rows travel again, so the other devices learn the names.
    expect(await h.db.outbox.where('[table+key]').equals(['memories', 'm1']).count()).toBeGreaterThan(1);
  });

  it('starts a pass on its own once the import is done, when the passphrase is set', async () => {
    const h = await device(new FakeServer());
    await h.keyring.unlock('a long passphrase', testUser.syncSalt, 1);
    const { put } = fakeFileServer();
    const { bundle, pictureHash } = await withFiles();

    await applyImport(h.writer, bundle, { files: h.files });
    await waitFor(async () => expect((await h.db.rows('memories').get('m1'))!.fileHash).toBe(pictureHash));
    expect(put).toHaveBeenCalledTimes(2);
  });

  it('sends a file its row already names when the server lacks it, and leaves the row alone', async () => {
    const h = await device(new FakeServer());
    await h.keyring.unlock('a long passphrase', testUser.syncSalt, 1);
    const { pictureHash, recordingHash } = await withFiles();
    // The recording is there already; the picture is not.
    const { put } = fakeFileServer([recordingHash]);
    const { bundle } = await withFiles(pictureHash);

    await applyImport(h.writer, bundle, { files: h.files });
    const before = (await h.db.rows('memories').get('m1'))!;
    expect(before.fileHash).toBe(pictureHash);
    await waitFor(async () => expect(await h.files.localHashes()).toEqual(new Map()));

    expect(put.mock.calls.map(([sha]) => sha)).toEqual([pictureHash]);
    // Named already: not stamped again, so it does not travel for nothing.
    expect((await h.db.rows('memories').get('m1'))!.updatedAt).toBe(before.updatedAt);
    // Unnamed, and the server had it: stamped without sending.
    expect((await h.db.rows('note_attachments').get('r1'))!.fileHash).toBe(recordingHash);
  });

  it('keeps a file past 25 MB here, and never sends it', async () => {
    const h = await device(new FakeServer());
    await h.keyring.unlock('a long passphrase', testUser.syncSalt, 1);
    const { put, missing } = fakeFileServer();
    const big = new Uint8Array(maxFileBytes + 1);
    const bundle = openArchive(
      archive(
        {
          Albums: [
            ['Uuid', 'Name', 'UpdatedAt'],
            ['a1', 'Face', stamp],
          ],
          Memories: [
            ['Uuid', 'AlbumUuid', 'HarvestDay', 'File', 'UpdatedAt'],
            ['m1', 'a1', '2026-09-05', 'gallery/Face/big.mp4', stamp],
          ],
        },
        { 'gallery/Face/big.mp4': big },
      ),
    );
    await applyImport(h.writer, bundle, { files: h.files });
    const report = await h.files.upload();
    expect(report).toMatchObject({ uploaded: 0, stamped: 0, waiting: 1 });
    expect(missing).not.toHaveBeenCalled();
    expect(put).not.toHaveBeenCalled();
    expect((await h.db.rows('memories').get('m1'))!.fileHash).toBeNull();
    // Still shown here, from this browser's copy.
    expect(await h.files.localHash('m1')).not.toBeNull();
  });
});
