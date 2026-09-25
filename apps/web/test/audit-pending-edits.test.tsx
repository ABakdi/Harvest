import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { HarvestContext } from '@/app/context';
import { NotesScreen } from '@/app/screens/notes';
import { api } from '@/lib/api';
import { registerPendingEdit } from '@/lib/pending-edits';
import { FakeServer } from './fake-server';
import { device } from './helpers';

/** Leaving the page (a close, a reload, a switch away) saves what was typed. */

function hide() {
  Object.defineProperty(document, 'visibilityState', { configurable: true, get: () => 'hidden' });
  document.dispatchEvent(new Event('visibilitychange'));
}

afterEach(() => {
  Object.defineProperty(document, 'visibilityState', { configurable: true, get: () => 'visible' });
  vi.restoreAllMocks();
});

describe('pending edits on the way out', () => {
  it('flushes when the tab goes hidden, and on pagehide', () => {
    const flush = vi.fn();
    const off = registerPendingEdit(flush);
    document.dispatchEvent(new Event('visibilitychange'));
    expect(flush).not.toHaveBeenCalled();
    hide();
    expect(flush).toHaveBeenCalledTimes(1);
    window.dispatchEvent(new Event('pagehide'));
    expect(flush).toHaveBeenCalledTimes(2);
    off();
    window.dispatchEvent(new Event('pagehide'));
    expect(flush).toHaveBeenCalledTimes(2);
  });

  it('writes a note typed a moment before the tab goes hidden', async () => {
    vi.spyOn(api, 'assistStatus').mockResolvedValue({ available: false, model: null, usedToday: 0, dailyLimit: 50 });
    const h = await device(new FakeServer());
    await h.settings.setString('features.notes', 'true');
    const { uuid } = await h.notes.create({ title: 'Walk' });
    render(
      <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
        <MemoryRouter initialEntries={[`/app/records/${uuid}`]}>
          <HarvestContext.Provider value={h}>
            <Routes>
              <Route path="/app/records/:uuid" element={<NotesScreen />} />
            </Routes>
          </HarvestContext.Provider>
        </MemoryRouter>
      </QueryClientProvider>,
    );
    const user = userEvent.setup();
    await user.type(await screen.findByLabelText('Note'), 'By the river');
    // Well inside the debounce: nothing written yet.
    expect((await h.db.rows('notes').get(uuid))?.body).toBe('');
    fireEvent(window, new Event('pagehide'));
    await waitFor(async () => expect((await h.db.rows('notes').get(uuid))?.body).toBe('By the river'), { timeout: 400 });
  });
});
