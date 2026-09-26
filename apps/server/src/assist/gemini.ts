import type { AssistRequest } from '@harvest/contracts';
import { HttpError } from '../http/errors.js';

export type Fetch = typeof fetch;

export interface UpstreamOptions {
  apiKey: string;
  model: string;
  fetch?: Fetch;
}

/**
 * The model the server holds a key for ([[ADR-013-Assist-Providers]]).
 *
 * The same endpoint the phone calls with its own key, and the same
 * shape of request: what differs is whose key it is, and whose quota
 * it spends. The answer is relayed as it arrives rather than
 * collected, so the first words reach the writer while the rest are
 * still being written.
 */
export class GeminiUpstream {
  constructor(private readonly options: UpstreamOptions) {}

  get model(): string {
    return this.options.model;
  }

  /** The answer's text, chunk by chunk. */
  async *stream(request: AssistRequest): AsyncGenerator<string> {
    const send = this.options.fetch ?? fetch;
    const url = new URL(
      `https://generativelanguage.googleapis.com/v1beta/models/${this.options.model}:streamGenerateContent`,
    );
    url.searchParams.set('alt', 'sse');

    let response: Response;
    try {
      response = await send(url, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-goog-api-key': this.options.apiKey,
        },
        body: JSON.stringify(bodyOf(request)),
      });
    } catch {
      throw new HttpError('unavailable', 'The model could not be reached');
    }

    if (!response.ok || !response.body) {
      // The provider's own words are not passed on: they are about the
      // server's key, which is the server's business.
      throw new HttpError(
        response.status === 429 ? 'rate_limited' : 'unavailable',
        response.status === 429 ? 'The model is busy' : 'The model refused the request',
      );
    }

    const decoder = new TextDecoder();
    let buffer = '';
    for await (const part of response.body as unknown as AsyncIterable<Uint8Array>) {
      buffer += decoder.decode(part, { stream: true });
      let newline = buffer.indexOf('\n');
      while (newline !== -1) {
        const line = buffer.slice(0, newline).trim();
        buffer = buffer.slice(newline + 1);
        newline = buffer.indexOf('\n');
        if (!line.startsWith('data:')) continue;
        const text = textOf(line.slice(5).trim());
        if (text) yield text;
      }
    }
  }
}

/** The request, as the Generative Language API wants it. */
function bodyOf(request: AssistRequest): Record<string, unknown> {
  return {
    systemInstruction: { parts: [{ text: request.system }] },
    contents: request.messages.map((message, index) => ({
      role: message.role,
      parts: [
        { text: message.text },
        ...(index === request.messages.length - 1 && request.audio
          ? [{ inlineData: { mimeType: request.audio.mimeType, data: request.audio.data } }]
          : []),
      ],
    })),
  };
}

/** The words out of one SSE line, or none if it carries no text. */
function textOf(payload: string): string {
  if (payload.length === 0 || payload === '[DONE]') return '';
  try {
    const parsed = JSON.parse(payload) as {
      candidates?: { content?: { parts?: { text?: string }[] } }[];
    };
    return (
      parsed.candidates
        ?.flatMap((candidate) => candidate.content?.parts ?? [])
        .map((part) => part.text ?? '')
        .join('') ?? ''
    );
  } catch {
    return '';
  }
}
