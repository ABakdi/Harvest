import { type AssistAudio, maxAssistAudioBytes } from '@harvest/contracts';
import { audioEmbed } from './attachments';

/**
 * A recording on its way to the server's assist to be transcribed
 * ([[Notes]] N10), and its words on their way back into the note.
 *
 * The request is the phone's, byte for byte: the same prompt from
 * `@harvest/core` and the recording beside it as base64, which is what
 * the phone's server provider sends too.
 */

/** The types the server takes, by the extension the phone files under. */
const byExtension: Record<string, AssistAudio['mimeType']> = {
  m4a: 'audio/mp4',
  aac: 'audio/aac',
  mp3: 'audio/mpeg',
  wav: 'audio/wav',
  ogg: 'audio/ogg',
  opus: 'audio/ogg',
};

const accepted: ReadonlySet<string> = new Set(Object.values(byExtension).concat('audio/webm'));

/**
 * What the recording is, for the model: the file's own type when it
 * says one the server takes (a browser's own recording may be webm
 * under an .ogg name), else the one its extension means.
 */
export function transcribeMimeType(blob: Blob, fileName: string): AssistAudio['mimeType'] | null {
  const own = blob.type.split(';')[0]!.trim().toLowerCase();
  if (accepted.has(own)) return own as AssistAudio['mimeType'];
  const dot = fileName.lastIndexOf('.');
  return byExtension[dot > 0 ? fileName.slice(dot + 1).toLowerCase() : ''] ?? null;
}

/** Whether a recording is past what the server takes to transcribe. */
export function tooLongToTranscribe(blob: Blob): boolean {
  return blob.size > maxAssistAudioBytes;
}

/** The cap, in whole megabytes, for the line that refuses. */
export const transcribeLimitMb = Math.floor(maxAssistAudioBytes / (1024 * 1024));

/** The recording as the request carries it. */
export async function transcribeAudio(blob: Blob, mimeType: AssistAudio['mimeType']): Promise<AssistAudio> {
  const bytes = new Uint8Array(await blob.arrayBuffer());
  let binary = '';
  // In slices, so a long recording does not overflow the call stack.
  for (let at = 0; at < bytes.length; at += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(at, at + 0x8000));
  }
  return { mimeType, data: btoa(binary) };
}

/**
 * The note with a recording's words under its embed, as a quote, the
 * recording kept (N10); at the end when the embed has gone meanwhile.
 */
export function placeTranscript(body: string, fileName: string, text: string): string {
  const quote = `> ${text.trim().replaceAll('\n', '\n> ')}`;
  const embed = audioEmbed(fileName);
  const at = body.indexOf(embed);
  if (at < 0) return `${body}${body.length === 0 || body.endsWith('\n') ? '' : '\n\n'}${quote}`;
  const end = at + embed.length;
  return `${body.slice(0, end)}\n${quote}${body.slice(end)}`;
}
