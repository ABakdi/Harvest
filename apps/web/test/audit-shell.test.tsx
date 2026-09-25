import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { act, fireEvent, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useState } from 'react';
import { MemoryRouter, Route, Routes } from 'react-router';
import { Toaster } from 'sonner';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { Dialog, DialogContent, DialogDescription, DialogTitle } from '@/components/ui/dialog';
import { HarvestContext } from '@/app/context';
import type { Writer } from '@/app/data/writer';
import { NotesScreen } from '@/app/screens/notes';
import type { SyncEngine } from '@/app/sync/engine';
import { startSyncTriggers, syncChannelName } from '@/app/sync/triggers';
import { api } from '@/lib/api';
import { FakeServer } from './fake-server';
import { device } from './helpers';

function setVisibility(state: 'visible' | 'hidden') {
  Object.defineProperty(document, 'visibilityState', { configurable: true, get: () => state });
  document.dispatchEvent(new Event('visibilitychange'));
}

afterEach(() => {
  vi.useRealTimers();
  vi.restoreAllMocks();
  Object.defineProperty(document, 'visibilityState', { configurable: true, get: () => 'visible' });
});

async function openRecords(at: string, setup: (h: Awaited<ReturnType<typeof device>>) => Promise<void>) {
  vi.spyOn(api, 'assistStatus').mockResolvedValue({ available: false, model: null, usedToday: 0, dailyLimit: 50 });
  const h = await device(new FakeServer());
  await setup(h);
  render(
    <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
      <MemoryRouter initialEntries={[at]}>
        <HarvestContext.Provider value={h}>
          <Routes>
            <Route path="/app/records" element={<NotesScreen />} />
            <Route path="/app/records/trash" element={<NotesScreen trash />} />
            <Route path="/app/records/:uuid" element={<NotesScreen />} />
          </Routes>
          <Toaster />
        </HarvestContext.Provider>
      </MemoryRouter>
    </QueryClientProvider>,
  );
  return h;
}

describe('records with all three views off', () => {
  it('says they are switched off, as the Body does, instead of opening Notes', async () => {
    await openRecords('/app/records', async (h) => {
      await h.notes.create({ title: 'Kept anyway' });
    });
    expect(await screen.findByText('Notes, the Gallery and Places are switched off')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Open Settings' })).toHaveAttribute('href', '/app/settings');
    expect(screen.queryByText('Kept anyway')).toBeNull();
  });

  it('opens Notes while any one of them is on', async () => {
    await openRecords('/app/records', async (h) => {
      await h.settings.setString('features.places', 'true');
      await h.notes.create({ title: 'Kept anyway' });
    });
    expect(await screen.findByText('Kept anyway')).toBeInTheDocument();
  });
});

describe('restoring a note', () => {
  it('says it is back, with a way to open it', async () => {
    let uuid = '';
    const h = await openRecords('/app/records/trash', async (h) => {
      await h.settings.setString('features.notes', 'true');
      uuid = (await h.notes.create({ title: 'Lost list' })).uuid;
      await h.notes.remove(uuid);
    });
    fireEvent.click(await screen.findByRole('button', { name: /Restore/ }));
    expect(await screen.findByText('“Lost list” is back in your notes')).toBeInTheDocument();
    await waitFor(async () => expect((await h.db.rows('notes').get(uuid))?.deletedAt).toBeNull());
  });
});

describe('focus after a dialog', () => {
  it('lands on the main region when the dialog was opened with nothing focused', async () => {
    function Page() {
      const [open, setOpen] = useState(true);
      return (
        <main tabIndex={-1} data-testid="main">
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogContent>
              <DialogTitle>Search</DialogTitle>
              <DialogDescription>Type to search</DialogDescription>
            </DialogContent>
          </Dialog>
        </main>
      );
    }
    render(<Page />);
    await screen.findByRole('dialog');
    await userEvent.keyboard('{Escape}');
    await waitFor(() => expect(document.activeElement).toBe(screen.getByTestId('main')));
  });
});

describe('sync triggers', () => {
  function fakes() {
    const engine = { sync: vi.fn(() => Promise.resolve()), refreshCounts: vi.fn(() => Promise.resolve()) };
    const writer = { onWrite: () => () => undefined };
    return { engine, writer, start: () => startSyncTriggers(engine as unknown as SyncEngine, writer as unknown as Writer) };
  }

  it('pulls every minute while the page is visible, and not while hidden', async () => {
    vi.useFakeTimers();
    const { engine, start } = fakes();
    const stop = start();
    expect(engine.sync).toHaveBeenCalledTimes(1);
    await act(() => vi.advanceTimersByTimeAsync(60_000));
    expect(engine.sync).toHaveBeenCalledTimes(2);
    setVisibility('hidden');
    await act(() => vi.advanceTimersByTimeAsync(5 * 60_000));
    expect(engine.sync).toHaveBeenCalledTimes(2);
    // Shown again: a pull at once.
    setVisibility('visible');
    expect(engine.sync).toHaveBeenCalledTimes(3);
    stop();
  });

  it('recounts when another tab of this browser says it wrote, without asking the server', async () => {
    const { engine, start } = fakes();
    const stop = start();
    engine.sync.mockClear();
    const other = new BroadcastChannel(syncChannelName);
    other.postMessage('changed');
    await waitFor(() => expect(engine.refreshCounts).toHaveBeenCalled());
    expect(engine.sync).not.toHaveBeenCalled();
    other.close();
    stop();
  });
});
