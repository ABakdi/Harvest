import { assistDoneMarker } from '@harvest/contracts';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { HarvestContext } from '@/app/context';
import { AssistError, assistStream } from '@/app/data/assist';
import { NotesScreen } from '@/app/screens/notes';
import { api } from '@/lib/api';
import { FakeServer } from './fake-server';
import { device } from './helpers';

afterEach(() => {
  vi.restoreAllMocks();
});

/** The server's answer, as it writes it: one event per chunk. */
function streaming(...lines: string[]): Response {
  return new Response(lines.map((line) => `data: ${line}\n\n`).join(''), {
    status: 200,
    headers: { 'content-type': 'text/event-stream' },
  });
}

describe('the assist stream', () => {
  it('reads the answer as it arrives, and stops at the marker', async () => {
    vi.spyOn(api, 'assist').mockResolvedValue(
      streaming(JSON.stringify({ text: 'A note ' }), JSON.stringify({ text: 'about bread.' }), assistDoneMarker),
    );
    const words: string[] = [];
    for await (const chunk of assistStream({ system: 'Be brief.', messages: [{ role: 'user', text: 'Hi' }] })) {
      words.push(chunk);
    }
    expect(words).toEqual(['A note ', 'about bread.']);
  });

  it('turns a failure sent mid-answer into one of its own', async () => {
    vi.spyOn(api, 'assist').mockResolvedValue(
      streaming(JSON.stringify({ text: 'Half ' }), JSON.stringify({ error: 'rate_limited' })),
    );
    const read = async () => {
      for await (const _ of assistStream({ system: 'x', messages: [{ role: 'user', text: 'y' }] })) {
        // drained for the error
      }
    };
    await expect(read()).rejects.toBeInstanceOf(AssistError);
  });
});

describe('the assist in a note', () => {
  async function editor(available: boolean) {
    vi.spyOn(api, 'assistStatus').mockResolvedValue({
      available,
      model: available ? 'gemini-2.5-flash' : null,
      usedToday: 0,
      dailyLimit: 50,
    });
    const h = await device(new FakeServer());
    const note = await h.notes.create({ title: 'Bread' });
    await h.notes.update(note.uuid, { body: 'Bread rises twice.' });
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(
      <QueryClientProvider client={client}>
        <MemoryRouter initialEntries={[`/app/records/${note.uuid}`]}>
          <HarvestContext.Provider value={h}>
            <Routes>
              <Route path="/app/records/:uuid" element={<NotesScreen />} />
            </Routes>
          </HarvestContext.Provider>
        </MemoryRouter>
      </QueryClientProvider>,
    );
    return h;
  }

  it('offers nothing when the server has no assist', async () => {
    await editor(false);
    await screen.findAllByText('Bread');
    expect(screen.queryByRole('button', { name: 'Assist' })).not.toBeInTheDocument();
  });

  it('says what it will send, and proposes rather than writes', async () => {
    vi.spyOn(api, 'assist').mockResolvedValue(
      streaming(JSON.stringify({ text: 'Bread rises two times.' }), assistDoneMarker),
    );
    await editor(true);
    const user = userEvent.setup();

    // The note opens on Read, since it has a body; the writing side is
    // where the assist puts anything.
    await user.click(await screen.findByRole('tab', { name: 'Write' }));
    await user.click(await screen.findByRole('button', { name: 'Assist' }));
    await user.click(await screen.findByRole('menuitem', { name: 'Rewrite' }));

    // What goes, and to whom, before anything is sent.
    expect(await screen.findByText(/this note goes to gemini-2\.5-flash/i)).toBeInTheDocument();
    expect(api.assist).not.toHaveBeenCalled();

    await user.click(screen.getByRole('button', { name: 'Send' }));
    expect(await screen.findByText('Bread rises two times.')).toBeInTheDocument();

    // The note is untouched until Replace is chosen.
    const body = screen.getByLabelText('Note') as HTMLTextAreaElement;
    expect(body.value).toBe('Bread rises twice.');
    await user.click(screen.getByRole('button', { name: 'Replace' }));
    await waitFor(() => expect((screen.getByLabelText('Note') as HTMLTextAreaElement).value).toBe('Bread rises two times.'));
  });
});
