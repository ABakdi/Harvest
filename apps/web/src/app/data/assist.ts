import { assistDoneMarker, type AssistRequest, type AssistStatus } from '@harvest/contracts';
import { api } from '@/lib/api';

/**
 * The server's assist, as the web uses it
 * ([[ADR-013-Assist-Providers]]).
 *
 * The browser has no key of its own to paste — a key in a browser is a
 * key in everyone's browser — so this is the only provider here, and it
 * needs nothing but a signed-in account. What comes back is read as it
 * arrives, because the point of a stream is the first sentence.
 */
export async function assistStatus(): Promise<AssistStatus | null> {
  try {
    return await api.assistStatus();
  } catch {
    return null;
  }
}

export class AssistError extends Error {
  constructor(readonly code: string) {
    super(code);
  }
  override readonly name = 'AssistError';
}

/** The answer, chunk by chunk. Throws [AssistError] when it stops. */
export async function* assistStream(
  request: AssistRequest,
  signal?: AbortSignal,
): AsyncGenerator<string> {
  const response = await api.assist(request, signal);
  const body = response.body;
  if (!body) throw new AssistError('internal');

  const reader = body.pipeThrough(new TextDecoderStream()).getReader();
  let buffer = '';
  try {
    for (;;) {
      const { value, done } = await reader.read();
      if (done) return;
      buffer += value;
      let newline = buffer.indexOf('\n');
      while (newline !== -1) {
        const line = buffer.slice(0, newline).trim();
        buffer = buffer.slice(newline + 1);
        newline = buffer.indexOf('\n');
        if (!line.startsWith('data:')) continue;
        const payload = line.slice(5).trim();
        if (payload === assistDoneMarker) return;
        const chunk = JSON.parse(payload) as { text?: string; error?: string };
        // A failure after the first byte travels as a line, the status
        // having already gone ([[Sync-API]]).
        if (chunk.error) throw new AssistError(chunk.error);
        if (chunk.text) yield chunk.text;
      }
    }
  } finally {
    await reader.cancel().catch(() => undefined);
  }
}
