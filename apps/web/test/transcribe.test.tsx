import { assistDoneMarker, maxAssistAudioBytes } from '@harvest/contracts';
import { assistPrompt } from '@harvest/core';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router';
import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { HarvestContext } from '@/app/context';
import { placeTranscript, transcribeAudio, transcribeMimeType } from '@/app/data/transcribe';
import { NotesScreen } from '@/app/screens/notes';
import { api } from '@/lib/api';
import { FakeServer } from './fake-server';
import { device } from './helpers';

beforeAll(() => {
  // jsdom has no object URLs; the player only needs one to exist.
  if (!URL.createObjectURL) {
    Object.assign(URL, { createObjectURL: () => 'blob:recording', revokeObjectURL: () => undefined });
  }
});

afterEach(() => {
  vi.restoreAllMocks();
});

function streaming(...lines: string[]): Response {
  return new Response(lines.map((line) => `data: ${line}\n\n`).join(''), {
    status: 200,
    headers: { 'content-type': 'text/event-stream' },
  });
}

const fileName = 'Voice 2026-09-19 14-32.m4a';

describe('a transcript in the note', () => {
  it('goes under its recording as a quote, the recording kept (N10)', () => {
    const body = `Before\n![[${fileName}]]\nAfter`;
    expect(placeTranscript(body, fileName, 'Buy flour.\nAnd yeast.\n')).toBe(
      `Before\n![[${fileName}]]\n> Buy flour.\n> And yeast.\nAfter`,
    );
  });

  it('goes at the end when the embed is gone', () => {
    expect(placeTranscript('Just words', fileName, 'Hello')).toBe('Just words\n\n> Hello');
  });

  it('names the recording by its own type, else by its extension', () => {
    expect(transcribeMimeType(new Blob([], { type: 'audio/webm;codecs=opus' }), 'a.ogg')).toBe('audio/webm');
    expect(transcribeMimeType(new Blob([]), 'a.m4a')).toBe('audio/mp4');
    expect(transcribeMimeType(new Blob([]), 'a.opus')).toBe('audio/ogg');
    expect(transcribeMimeType(new Blob([]), 'a.flac')).toBeNull();
  });

  it('carries the recording as base64', async () => {
    const audio = await transcribeAudio(new Blob([new Uint8Array([1, 2, 3])]), 'audio/mp4');
    expect(audio).toEqual({ mimeType: 'audio/mp4', data: 'AQID' });
  });
});

describe('Transcribe on a recording', () => {
  async function editor({ available = true, usedToday = 0, size = 3 } = {}) {
    vi.spyOn(api, 'assistStatus').mockResolvedValue({
      available,
      model: available ? 'gemini-2.5-flash' : null,
      usedToday,
      dailyLimit: 50,
    });
    const h = await device(new FakeServer());
    const note = await h.notes.create({ title: 'Groceries' });
    const bytes = new Uint8Array(size);
    bytes.set([1, 2, 3].slice(0, size));
    const blob = new Blob([bytes], { type: 'audio/mp4' });
    await h.attachments.add({ noteUuid: note.uuid, blob, fileName, durationMs: 4200 });
    // The test database keeps a copy that is no longer a Blob; the
    // browser's keeps the file itself.
    vi.spyOn(h.files, 'get').mockResolvedValue(blob);
    await h.notes.update(note.uuid, { body: `Shopping\n![[${fileName}]]\nThat is all.` });
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
    await screen.findByText('Recordings', {}, { timeout: 5000 });
    return h;
  }

  it('is not offered when the server has no assist', async () => {
    await editor({ available: false });
    await screen.findByLabelText(fileName);
    expect(screen.queryByRole('button', { name: `Transcribe ${fileName}` })).not.toBeInTheDocument();
  });

  it('says what goes and to whom, sends only on Send, and proposes the words', async () => {
    const assist = vi
      .spyOn(api, 'assist')
      .mockResolvedValue(streaming(JSON.stringify({ text: 'Buy flour ' }), JSON.stringify({ text: 'and yeast.' }), assistDoneMarker));
    await editor();
    const user = userEvent.setup();

    await user.click(await screen.findByRole('button', { name: `Transcribe ${fileName}` }));
    expect(await screen.findByText(`The recording ${fileName} goes to gemini-2.5-flash, and nothing else.`)).toBeInTheDocument();
    expect(assist).not.toHaveBeenCalled();

    await user.click(screen.getByRole('button', { name: 'Send' }));
    expect(await screen.findByText('Buy flour and yeast.')).toBeInTheDocument();

    // The phone's request, recording and all.
    const prompt = assistPrompt('transcribe');
    expect(assist).toHaveBeenCalledTimes(1);
    expect(assist.mock.calls[0]![0]).toEqual({
      system: prompt.system,
      messages: prompt.messages,
      audio: { mimeType: 'audio/mp4', data: 'AQID' },
    });

    // A transcript replaces nothing; Insert puts it under the recording.
    expect(screen.queryByRole('button', { name: 'Replace' })).not.toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Insert' }));
    await user.click(screen.getByRole('tab', { name: 'Write' }));
    await waitFor(() =>
      expect(screen.getByLabelText<HTMLTextAreaElement>('Note').value).toBe(
        `Shopping\n![[${fileName}]]\n> Buy flour and yeast.\nThat is all.`,
      ),
    );
  });

  it('refuses a recording past the server cap before anything goes', async () => {
    const assist = vi.spyOn(api, 'assist');
    await editor({ size: maxAssistAudioBytes + 1 });
    const user = userEvent.setup();

    await user.click(await screen.findByRole('button', { name: `Transcribe ${fileName}` }));
    expect(await screen.findByRole('alert')).toHaveTextContent('too long to transcribe');
    expect(screen.getByRole('button', { name: 'Send' })).toBeDisabled();
    expect(assist).not.toHaveBeenCalled();
  });

  it('holds Send when the day is used up', async () => {
    const assist = vi.spyOn(api, 'assist');
    await editor({ usedToday: 50 });
    const user = userEvent.setup();

    await user.click(await screen.findByRole('button', { name: `Transcribe ${fileName}` }));
    expect(await screen.findByRole('alert')).toHaveTextContent('That is all the assist this account has today.');
    expect(screen.getByRole('button', { name: 'Send' })).toBeDisabled();
    expect(assist).not.toHaveBeenCalled();
  });
});
