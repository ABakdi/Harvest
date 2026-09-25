import { assistDoneMarker } from '@harvest/contracts';
import request from 'supertest';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { bearer, expectError, harness, password, signUp, type Harness } from './harness.js';

/** The model, as the server sees it: server-sent events of candidates. */
function modelSaying(...words: string[]): typeof fetch {
  const body = words
    .map((text) => `data: ${JSON.stringify({ candidates: [{ content: { parts: [{ text }] } }] })}\n\n`)
    .join('');
  return vi.fn(() =>
    Promise.resolve(new Response(body, { status: 200, headers: { 'content-type': 'text/event-stream' } })),
  );
}

const ask = { system: 'Be brief.', messages: [{ role: 'user' as const, text: 'Summarise this note.' }] };

let h: Harness;
afterEach(async () => {
  await h.close();
});

describe('the server assist', () => {
  let model: typeof fetch;
  beforeEach(async () => {
    model = modelSaying('A note ', 'about bread.');
    h = await harness({
      env: { ASSIST_API_KEY: 'a-server-key', ASSIST_DAILY_LIMIT: '2' },
      assistFetch: model,
    });
  });

  it('relays the model, word by word, and says it is available', async () => {
    const account = await signUp(h);

    const status = await request(h.app).get('/v1/assist/status').set(bearer(account)).expect(200);
    expect(status.body).toMatchObject({ available: true, model: 'gemini-2.5-flash', usedToday: 0, dailyLimit: 2 });

    const answer = await request(h.app).post('/v1/assist').set(bearer(account)).send(ask).expect(200);
    expect(answer.headers['content-type']).toContain('text/event-stream');
    expect(answer.text).toBe(
      `data: {"text":"A note "}\n\ndata: {"text":"about bread."}\n\ndata: ${assistDoneMarker}\n\n`,
    );

    const after = await request(h.app).get('/v1/assist/status').set(bearer(account)).expect(200);
    expect(after.body).toMatchObject({ usedToday: 1 });
  });

  it('stops an account at its daily limit', async () => {
    const account = await signUp(h);
    await request(h.app).post('/v1/assist').set(bearer(account)).send(ask).expect(200);
    await request(h.app).post('/v1/assist').set(bearer(account)).send(ask).expect(200);
    expectError(await request(h.app).post('/v1/assist').set(bearer(account)).send(ask), 429, 'rate_limited');

    // One account's spending is not another's.
    const other = await signUp(h);
    await request(h.app).post('/v1/assist').set(bearer(other)).send(ask).expect(200);
  });

  it('keeps the question out of anything it stores', async () => {
    const account = await signUp(h);
    await request(h.app).post('/v1/assist').set(bearer(account)).send(ask).expect(200);
    const rows = await h.db.collection('assist_usage').find({}).toArray();
    expect(rows).toHaveLength(1);
    expect(Object.keys(rows[0]!).sort()).toEqual(['_id', 'count', 'day', 'lastAt', 'userId']);
  });

  it('takes the count with the account', async () => {
    const account = await signUp(h);
    await request(h.app).post('/v1/assist').set(bearer(account)).send(ask).expect(200);
    await request(h.app).delete('/v1/me').set(bearer(account)).send({ password }).expect(204);
    expect(await h.db.collection('assist_usage').countDocuments({})).toBe(0);
  });

  it('takes a recording larger than the general body limit, up to its own cap', async () => {
    const account = await signUp(h);
    // Six megabytes of recording: past the 5 MB every other route takes.
    const data = Buffer.alloc(6 * 1024 * 1024, 7).toString('base64');
    const transcribe = {
      system: 'Transcribe.',
      messages: [{ role: 'user' as const, text: 'Transcribe this recording.' }],
      audio: { mimeType: 'audio/mp4' as const, data },
    };
    await request(h.app).post('/v1/assist').set(bearer(account)).send(transcribe).expect(200);
    const sent = JSON.parse(vi.mocked(model).mock.calls[0]![1]!.body as string) as {
      contents: { parts: { inlineData?: { mimeType: string; data: string } }[] }[];
    };
    const inline = sent.contents.at(-1)!.parts.find((part) => part.inlineData)!.inlineData!;
    expect(inline.mimeType).toBe('audio/mp4');
    expect(inline.data).toHaveLength(data.length);
  });

  it('refuses an unverified account and a malformed ask', async () => {
    const unverified = await signUp(h, { verify: false });
    expectError(await request(h.app).post('/v1/assist').set(bearer(unverified)).send(ask), 403, 'forbidden');

    const account = await signUp(h);
    expectError(
      await request(h.app).post('/v1/assist').set(bearer(account)).send({ system: '', messages: [] }),
      400,
      'validation_failed',
    );
  });
});

describe('a server with no key', () => {
  beforeEach(async () => {
    h = await harness();
  });

  it('says it has no assist rather than failing at the sheet', async () => {
    const account = await signUp(h);
    const status = await request(h.app).get('/v1/assist/status').set(bearer(account)).expect(200);
    expect(status.body).toMatchObject({ available: false, model: null });
    expectError(await request(h.app).post('/v1/assist').set(bearer(account)).send(ask), 503, 'unavailable');
  });
});

describe('when the model itself fails', () => {
  it('says so in the stream, because the status has already gone', async () => {
    h = await harness({
      env: { ASSIST_API_KEY: 'a-server-key' },
      assistFetch: vi.fn(() => Promise.resolve(new Response('busy', { status: 429 }))),
    });
    const account = await signUp(h);
    const answer = await request(h.app).post('/v1/assist').set(bearer(account)).send(ask).expect(200);
    expect(answer.text).toBe('data: {"error":"rate_limited"}\n\n');
  });
});
