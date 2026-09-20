import { deriveSyncKey, sealFile } from '@harvest/contracts';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { HarvestContext } from '@/app/context';
import { sha256Of } from '@/app/data/files';
import { GalleryScreen } from '@/app/screens/gallery';
import { api } from '@/lib/api';
import { FakeServer } from './fake-server';
import { device, testUser } from './helpers';

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
  it('fetches a picture by its name, opens it and keeps it', async () => {
    const h = await device(new FakeServer());
    const { bytes, sha256 } = await picture();
    const key = await deriveSyncKey('a long passphrase', testUser.syncSalt, { iterations: 1 });
    await h.keyring.unlock('a long passphrase', testUser.syncSalt, 1);
    const sealed = await sealFile(key, sha256, bytes);
    const fetching = vi.spyOn(api, 'file').mockResolvedValue({ sealed: sealed.sealed, iv: sealed.iv });

    const first = await h.files.get(sha256);
    expect(first).not.toBeNull();
    expect(new Uint8Array(await first!.arrayBuffer())).toEqual(bytes);

    // Kept: a second ask does not go to the server.
    const again = await h.files.get(sha256);
    expect(again).not.toBeNull();
    expect(fetching).toHaveBeenCalledTimes(1);
  });

  it('throws away bytes that do not hash to the name they came under', async () => {
    const h = await device(new FakeServer());
    const { sha256 } = await picture();
    const key = await deriveSyncKey('a long passphrase', testUser.syncSalt, { iterations: 1 });
    await h.keyring.unlock('a long passphrase', testUser.syncSalt, 1);
    // Sealed correctly for that name, but the bytes are something else.
    const lie = await sealFile(key, sha256, new Uint8Array([1, 2, 3]) as Uint8Array<ArrayBuffer>);
    vi.spyOn(api, 'file').mockResolvedValue({ sealed: lie.sealed, iv: lie.iv });

    expect(await h.files.get(sha256)).toBeNull();
    expect(await h.db.files.count()).toBe(0);
  });

  it('says a picture is on the phone when there is no passphrase', async () => {
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
    expect(await screen.findByTitle('Still on the phone')).toBeInTheDocument();
  });
});
