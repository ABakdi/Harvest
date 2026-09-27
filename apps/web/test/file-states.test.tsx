import { Blob as NodeBlob } from 'node:buffer';
import { sealFile } from '@harvest/contracts';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { CompareDialog } from '@/app/components/gallery/compare-dialog';
import { MemoryMedia } from '@/app/components/gallery/memory-media';
import { TimelapseDialog } from '@/app/components/gallery/timelapse-dialog';
import { RecordingPlayer } from '@/app/components/notes/recordings';
import { HarvestContext } from '@/app/context';
import type { AttachmentRow } from '@/app/data/attachments';
import { sha256Of } from '@/app/data/files';
import type { MemoryRow } from '@/app/data/gallery';
import { api, ApiError } from '@/lib/api';
import { FakeServer } from './fake-server';
import { device, testUser, testKey } from './helpers';

type Device = Awaited<ReturnType<typeof device>>;

const onPhone = 'Still on the phone — it arrives once your phone has your sync PIN';
const locked = 'Enter your sync PIN to see it';

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

async function unlocked(): Promise<Device> {
  const h = await device(new FakeServer());
  await h.keyring.unlock('2468', testUser.syncSalt, 1);
  return h;
}

/** A picture sealed for the server, and the name its bytes give it. */
async function sealedPicture() {
  const bytes = new Uint8Array(96).map((_, i) => (i * 11 + 3) % 256);
  const sha256 = await sha256Of(bytes.slice().buffer);
  const key = await testKey('2468');
  return { sha256, box: await sealFile(key, sha256, bytes) };
}

function memory(uuid: string, fileHash: string | null, day = '2026-09-19'): MemoryRow {
  return {
    uuid,
    albumUuid: 'a1',
    harvestDay: day,
    path: `a1/${uuid}.jpg`,
    kind: 'photo',
    note: null,
    fileHash,
    capturedAt: `${day}T10:00:00.000Z`,
    updatedAt: `${day}T10:00:00.000Z`,
    deletedAt: null,
  };
}

function show(h: Device, ui: React.ReactNode) {
  return render(<HarvestContext.Provider value={h}>{ui}</HarvestContext.Provider>);
}

describe('why a file is not here ([[Gallery]] G9)', () => {
  it('tells the three apart: no key, not on the server, and a fetch that failed', async () => {
    const h = await device(new FakeServer());
    expect(await h.files.find('a'.repeat(64))).toBe('locked');

    await h.keyring.unlock('2468', testUser.syncSalt, 1);
    vi.spyOn(api, 'file').mockRejectedValueOnce(new ApiError(404, 'not_found', 'No such file'));
    expect(await h.files.find('b'.repeat(64))).toBe('onPhone');

    vi.spyOn(api, 'file').mockRejectedValueOnce(new ApiError(0, 'network', 'Offline'));
    expect(await h.files.find('c'.repeat(64))).toBe('failed');
    expect(await h.files.get('c'.repeat(64))).toBeNull();
  });

  it('gives up on a fetch that never answers, so nothing loads for good', async () => {
    const h = await unlocked();
    h.files.timeoutMs = 20;
    vi.spyOn(api, 'file').mockReturnValue(new Promise(() => {}));
    expect(await h.files.find('d'.repeat(64))).toBe('failed');
  });

  it('says a picture with no file yet is still on the phone, in the viewer and on a tile', async () => {
    const h = await unlocked();
    const fetching = vi.spyOn(api, 'file');
    show(
      h,
      <>
        <MemoryMedia memory={memory('m1', null)} explain />
        <MemoryMedia memory={memory('m2', null)} />
      </>,
    );
    expect(await screen.findByText(onPhone)).toBeInTheDocument();
    expect(await screen.findByTitle(onPhone)).toHaveAttribute('role', 'img');
    expect(screen.queryByRole('button', { name: 'Try again' })).toBeNull();
    expect(fetching).not.toHaveBeenCalled();
  });

  it('asks for the sync PIN when the file is there but this browser cannot open it', async () => {
    const h = await device(new FakeServer());
    const { sha256, box } = await sealedPicture();
    vi.spyOn(api, 'file').mockResolvedValue({ sealed: box.sealed, iv: box.iv });
    show(h, <MemoryMedia memory={memory('m1', sha256)} explain />);

    expect(await screen.findByText(locked)).toBeInTheDocument();
    await userEvent.setup().click(screen.getByRole('button', { name: 'Enter sync PIN' }));
    const dialog = await screen.findByRole('dialog');
    expect(within(dialog).getByLabelText('Sync PIN (4 to 6 digits)')).toBeInTheDocument();

    // Entered elsewhere just as well: the picture follows on its own.
    await h.keyring.unlock('2468', testUser.syncSalt, 1);
    await waitFor(() => expect(screen.queryByText(locked)).toBeNull());
    expect(await screen.findByRole('img', { name: 'No caption' })).toHaveAttribute('src');
  });

  it('says it could not load, and tries again on the button', async () => {
    const h = await unlocked();
    const { sha256, box } = await sealedPicture();
    const fetching = vi
      .spyOn(api, 'file')
      .mockRejectedValueOnce(new ApiError(0, 'network', 'Offline'))
      .mockResolvedValue({ sealed: box.sealed, iv: box.iv });
    show(h, <MemoryMedia memory={memory('m1', sha256)} explain />);

    expect(await screen.findByText("Couldn't load")).toBeInTheDocument();
    await userEvent.setup().click(screen.getByRole('button', { name: 'Try again' }));
    expect(await screen.findByRole('img', { name: 'No caption' })).toBeInTheDocument();
    expect(fetching).toHaveBeenCalledTimes(2);
  });

  it('says why in compare and in a paused timelapse, never a blank frame', async () => {
    const h = await unlocked();
    const run = [memory('m2', null, '2026-09-19'), memory('m1', null, '2026-09-12')];
    const { unmount } = show(h, <CompareDialog title="Face" memories={run} onClose={() => {}} />);
    await waitFor(() => expect(screen.getAllByText(onPhone)).toHaveLength(2));
    unmount();

    show(h, <TimelapseDialog title="Face" memories={run} onClose={() => {}} />);
    expect(await screen.findByRole('img', { name: onPhone })).toBeInTheDocument();
    await userEvent.setup().click(screen.getByRole('button', { name: 'Pause' }));
    expect(await screen.findByText(onPhone)).toBeInTheDocument();
  });

  it('says the same of a recording', async () => {
    const h = await device(new FakeServer());
    const recording = (uuid: string, fileHash: string | null): AttachmentRow => ({
      uuid,
      noteUuid: 'n1',
      kind: 'audio',
      fileName: `${uuid}.m4a`,
      storedPath: `n1/${uuid}.m4a`,
      durationMs: 1000,
      sizeBytes: 100,
      fileHash,
      createdAt: '2026-09-19T10:00:00.000Z',
      updatedAt: '2026-09-19T10:00:00.000Z',
      deletedAt: null,
    });
    show(
      h,
      <ul>
        <RecordingPlayer attachment={recording('r1', null)} />
        <RecordingPlayer attachment={recording('r2', 'e'.repeat(64))} />
      </ul>,
    );
    expect(await screen.findByText(onPhone)).toBeInTheDocument();
    expect(await screen.findByText(locked)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Enter sync PIN' })).toBeInTheDocument();
  });
});
