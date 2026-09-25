import { Blob as NodeBlob } from 'node:buffer';
import { deriveSyncKey, sealFile } from '@harvest/contracts';
import { act, renderHook, waitFor } from '@testing-library/react';
import { unzipSync } from 'fflate';
import type { ReactNode } from 'react';
import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { useMemoryUrls } from '@/app/components/gallery/memory-media';
import { HarvestContext } from '@/app/context';
import { isSafeRelative } from '@/app/data/archive';
import { attachmentFileName, voiceFileName } from '@/app/data/attachments';
import { buildArchive } from '@/app/data/export';
import { sha256Of } from '@/app/data/files';
import { useFile } from '@/app/hooks';
import { api } from '@/lib/api';
import { FakeServer } from './fake-server';
import { device, testUser } from './helpers';

type Device = Awaited<ReturnType<typeof device>>;

beforeAll(() => {
  // jsdom's Blob does not survive IndexedDB's structured clone; Node's does.
  vi.stubGlobal('Blob', NodeBlob);
  if (!URL.createObjectURL) {
    Object.assign(URL, { createObjectURL: () => 'blob:file', revokeObjectURL: () => undefined });
  }
});

afterEach(() => {
  vi.restoreAllMocks();
});

function bytesOf(length: number, seed: number): Uint8Array<ArrayBuffer> {
  const bytes = new Uint8Array(length);
  for (let i = 0; i < length; i++) bytes[i] = (i * seed + 5) % 256;
  return bytes;
}

async function note(h: Device, uuid: string, title: string) {
  await h.writer.run((tx) => tx.put('notes', { uuid, title, folder: '', body: '', createdAt: tx.now(), updatedAt: tx.now(), deletedAt: null }));
}

describe('an export of files not sent yet', () => {
  it('carries a picture and a recording made here, from this browser’s own copy', async () => {
    const h = await device(new FakeServer());
    // Locked: nothing can be sent, so both rows keep no hash.
    vi.spyOn(api, 'putFile').mockRejectedValue(new Error('offline'));
    const album = await h.gallery.createAlbum({ name: 'Face', schedule: null, remindAt: null, note: null });
    const picture = bytesOf(64, 7);
    const memory = await h.gallery.addMemory(album, { blob: new Blob([picture]), kind: 'photo', extension: '.jpg' });
    await note(h, 'n1', 'Run');
    const recording = bytesOf(32, 3);
    const attachment = await h.attachments.add({ noteUuid: 'n1', blob: new Blob([recording]), fileName: 'Voice.m4a', durationMs: 1000 });
    expect((await h.db.rows('memories').get(memory.uuid))?.fileHash).toBeNull();
    expect((await h.db.rows('note_attachments').get(attachment.uuid))?.fileHash).toBeNull();

    const archive = await buildArchive(h.db, (hash) => h.files.get(hash), { now: new Date('2026-09-19T12:00:00.000Z') });
    expect(archive.missingFiles).toBe(0);
    const entries = unzipSync(archive.bytes);
    expect(entries['gallery/Face/2026-09-19.jpg']).toEqual(picture);
    expect(entries['notes/Voice.m4a']).toEqual(recording);
  });
});

describe('a recording’s name', () => {
  const odd = ['C:\\Users\\me\\take', 'a:b', '../../etc', 'x'.repeat(600), '  ', '[[Voice]] #1 ^a|b', '.hidden', 'a/b/c'];

  it('is one the phone would store, whatever the file was called', () => {
    for (const stem of odd) {
      const name = attachmentFileName(stem, 'm4a');
      expect(name.endsWith('.m4a')).toBe(true);
      expect(name).not.toMatch(/[\\/:[\]#^|]/);
      expect(isSafeRelative(`0b7e7f3e-1111-4222-8333-444455556666/${name}`)).toBe(true);
    }
    expect(attachmentFileName('x'.repeat(600), 'm4a').length).toBeLessThanOrEqual(130);
  });

  it('counts past names already taken, and the recorder’s own are safe too', () => {
    expect(attachmentFileName('a:b', 'mp3', new Set(['a-b.mp3']))).toBe('a-b (2).mp3');
    const voice = voiceFileName(new Date(2026, 8, 19, 9, 5), new Set(), 'webm');
    expect(voice).toBe('Voice 2026-09-19 09-05.webm');
    expect(isSafeRelative(`n1/${voice}`)).toBe(true);
  });

  it('is refused when unsafe, rather than stored where the phone never looks', async () => {
    const h = await device(new FakeServer());
    await note(h, 'n1', 'Run');
    await expect(
      h.attachments.add({ noteUuid: 'n1', blob: new Blob([bytesOf(8, 1)]), fileName: 'C:\\take.m4a', durationMs: null }),
    ).rejects.toThrow();
    expect(await h.db.rows('note_attachments').count()).toBe(0);
  });
});

describe('a picture that could not be had yet', () => {
  async function sealed(bytes: Uint8Array<ArrayBuffer>) {
    const sha256 = await sha256Of(bytes.slice().buffer);
    const key = await deriveSyncKey('a long passphrase', testUser.syncSalt, { iterations: 1 });
    const box = await sealFile(key, sha256, bytes);
    return { sha256, box };
  }

  const wrapper = (h: Device) =>
    function Wrapper({ children }: { children: ReactNode }) {
      return <HarvestContext.Provider value={h}>{children}</HarvestContext.Provider>;
    };

  it('shows once the passphrase is entered', async () => {
    const h = await device(new FakeServer());
    const { sha256, box } = await sealed(bytesOf(48, 9));
    vi.spyOn(api, 'file').mockResolvedValue({ sealed: box.sealed, iv: box.iv });

    const { result } = renderHook(() => useFile(sha256), { wrapper: wrapper(h) });
    await waitFor(() => expect(result.current).toBeNull());

    await act(() => h.keyring.unlock('a long passphrase', testUser.syncSalt, 1));
    await waitFor(() => expect(typeof result.current).toBe('string'));
  });

  it('shows after a sync finishes, once the server has it', async () => {
    const h = await device(new FakeServer());
    const { sha256, box } = await sealed(bytesOf(48, 13));
    await h.keyring.unlock('a long passphrase', testUser.syncSalt, 1);
    const fetching = vi.spyOn(api, 'file').mockRejectedValueOnce(new Error('offline')).mockResolvedValue({ sealed: box.sealed, iv: box.iv });

    const { result } = renderHook(() => useFile(sha256), { wrapper: wrapper(h) });
    await waitFor(() => expect(result.current).toBeNull());

    await act(() => h.engine.sync());
    await waitFor(() => expect(typeof result.current).toBe('string'));
    expect(fetching).toHaveBeenCalledTimes(2);
  });

  it('fills the timelapse’s frames once the passphrase is entered', async () => {
    const h = await device(new FakeServer());
    const { sha256, box } = await sealed(bytesOf(48, 21));
    vi.spyOn(api, 'file').mockResolvedValue({ sealed: box.sealed, iv: box.iv });
    const memories = [
      {
        uuid: 'm1',
        albumUuid: 'a1',
        harvestDay: '2026-09-19',
        path: 'a1/m1.jpg',
        kind: 'photo' as const,
        note: null,
        fileHash: sha256,
        capturedAt: '2026-09-19T10:00:00.000Z',
        updatedAt: '2026-09-19T10:00:00.000Z',
        deletedAt: null,
      },
    ];

    const { result } = renderHook(() => useMemoryUrls(memories), { wrapper: wrapper(h) });
    await waitFor(() => expect(result.current?.get('m1')).toBeNull());

    await act(() => h.keyring.unlock('a long passphrase', testUser.syncSalt, 1));
    await waitFor(() => expect(typeof result.current?.get('m1')).toBe('string'));
  });
});
