import { sealFile, sealFileV3 } from '@harvest/contracts';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { HarvestContext } from '@/app/context';
import { sha256Of } from '@/app/data/files';
import { GalleryScreen } from '@/app/screens/gallery';
import { ApiError, api } from '@/lib/api';
import { FakeServer } from './fake-server';
import { device, testFileName, testUser, testKey } from './helpers';

afterEach(() => {
  vi.restoreAllMocks();
});

/** A picture, and the name its own bytes give it. */
async function picture(): Promise<{ bytes: Uint8Array<ArrayBuffer>; sha256: string }> {
  const bytes = new Uint8Array(512);
  for (let i = 0; i < bytes.length; i++) bytes[i] = (i * 13) % 256;
  return { bytes, sha256: await sha256Of(bytes.slice().buffer) };
}

describe('files on the web', () => {
  it('fetches a picture by its name on the server, opens it and keeps it', async () => {
    const h = await device(new FakeServer());
    const { bytes, sha256 } = await picture();
    const key = await testKey('a long passphrase');
    await h.keyring.unlock('a long passphrase', testUser.syncSalt, 1);
    const name = await testFileName(sha256, 'a long passphrase');
    expect(name).not.toBe(sha256);
    const sealed = await sealFileV3(key, name, bytes);
    const fetching = vi.spyOn(api, 'file').mockResolvedValue({ sealed: sealed.sealed, iv: sealed.iv });

    const first = await h.files.get(sha256);
    expect(first).not.toBeNull();
    expect(new Uint8Array(await first!.arrayBuffer())).toEqual(bytes);
    // Asked for by its keyed name: the server never hears the hash.
    expect(fetching).toHaveBeenCalledWith(name);

    // Kept: a second ask does not go to the server.
    const again = await h.files.get(sha256);
    expect(again).not.toBeNull();
    expect(fetching).toHaveBeenCalledTimes(1);
  });

  it('still fetches a picture stored under its plain hash before Phase 7', async () => {
    const h = await device(new FakeServer());
    const { bytes, sha256 } = await picture();
    const key = await testKey('a long passphrase');
    await h.keyring.unlock('a long passphrase', testUser.syncSalt, 1);
    const name = await testFileName(sha256, 'a long passphrase');
    const old = await sealFile(key, sha256, bytes);
    const fetching = vi.spyOn(api, 'file').mockImplementation((asked) =>
      asked === sha256
        ? Promise.resolve({ sealed: old.sealed, iv: old.iv })
        : Promise.reject(new ApiError(404, 'not_found', 'No such file')),
    );

    const found = await h.files.get(sha256);
    expect(new Uint8Array(await found!.arrayBuffer())).toEqual(bytes);
    expect(fetching.mock.calls.map(([asked]) => asked)).toEqual([name, sha256]);
  });

  it('throws away bytes that do not hash to the name they came under', async () => {
    const h = await device(new FakeServer());
    const { sha256 } = await picture();
    const key = await testKey('a long passphrase');
    await h.keyring.unlock('a long passphrase', testUser.syncSalt, 1);
    // Sealed correctly for that name, but the bytes are something else.
    const lie = await sealFileV3(key, await testFileName(sha256, 'a long passphrase'), new Uint8Array([1, 2, 3]));
    vi.spyOn(api, 'file').mockResolvedValue({ sealed: lie.sealed, iv: lie.iv });

    expect(await h.files.get(sha256)).toBeNull();
    expect(await h.db.files.count()).toBe(0);
  });

  it('asks for the sync PIN on a picture this browser cannot open yet (G9)', async () => {
    const h = await device(new FakeServer());
    await h.db.rows('albums').put({
      uuid: 'a1',
      name: 'Gym',
      scheduleJson: null,
      remindAt: null,
      note: null,
      createdAt: '',
      updatedAt: '',
      deletedAt: null,
    });
    await h.db.rows('memories').put({
      uuid: 'm1',
      albumUuid: 'a1',
      harvestDay: '2026-09-19',
      path: 'gallery/m1.jpg',
      kind: 'photo',
      note: 'After the session',
      fileHash: 'b'.repeat(64),
      capturedAt: '2026-09-19T18:00:00.000Z',
      updatedAt: '',
      deletedAt: null,
    });

    render(
      <MemoryRouter initialEntries={['/app/records/gallery']}>
        <HarvestContext.Provider value={h}>
          <GalleryScreen />
        </HarvestContext.Provider>
      </MemoryRouter>,
    );
    await screen.findByText('Gym');
    await screen.findByRole('button', { name: /gym/i }).then((button) => button.click());
    expect(await screen.findByTitle('Enter your sync PIN to see it')).toBeInTheDocument();
  });
});
