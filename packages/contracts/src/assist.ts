import { z } from 'zod';

/**
 * The server-held assist ([[ADR-013-Assist-Providers]]).
 *
 * The same shape the phone already sends its own provider: how to
 * behave, the turns so far, and optionally one recording. What comes
 * back is text as it arrives, which is why the answer is a stream
 * rather than a body.
 *
 * Nothing here is stored. The server relays the words to the model and
 * the model's words back, and keeps only the count ([[Notes]] N8).
 */
export const assistMessageSchema = z.strictObject({
  role: z.enum(['user', 'model']),
  text: z.string().min(1).max(100_000),
});
export type AssistMessage = z.infer<typeof assistMessageSchema>;

/** A minute of speech is about 1 MB at the phone's bitrate. */
export const maxAssistAudioBytes = 8 * 1024 * 1024;

export const assistAudioSchema = z.strictObject({
  mimeType: z.enum(['audio/mp4', 'audio/aac', 'audio/mpeg', 'audio/ogg', 'audio/wav', 'audio/webm']),
  /** Base64, because the request itself is JSON. */
  data: z.base64().max(Math.ceil((maxAssistAudioBytes * 4) / 3)),
});
export type AssistAudio = z.infer<typeof assistAudioSchema>;

export const maxAssistMessages = 20;

export const assistRequestSchema = z.strictObject({
  system: z.string().min(1).max(8_000),
  messages: z.array(assistMessageSchema).min(1).max(maxAssistMessages),
  audio: assistAudioSchema.optional(),
});
export type AssistRequest = z.infer<typeof assistRequestSchema>;

/**
 * One line of the answer, as server-sent events: `data: {"text": "…"}`
 * until `data: [DONE]`. An error before the first line is an ordinary
 * error body; one after it arrives as `data: {"error": "<code>"}`,
 * because the status has already been sent.
 */
export const assistChunkSchema = z.union([
  z.strictObject({ text: z.string() }),
  z.strictObject({ error: z.string() }),
]);
export type AssistChunk = z.infer<typeof assistChunkSchema>;

export const assistDoneMarker = '[DONE]';

/** Whether the server offers an assist at all, and what is left today. */
export const assistStatusSchema = z.object({
  available: z.boolean(),
  /** The model's own name, for the sheet that says where the words go. */
  model: z.string().nullable(),
  usedToday: z.int().nonnegative(),
  dailyLimit: z.int().nonnegative(),
});
export type AssistStatus = z.infer<typeof assistStatusSchema>;
