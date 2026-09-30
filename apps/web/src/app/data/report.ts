import {
  reportAudioMaxBytes,
  reportAudioTypes,
  reportBodySchema,
  reportImageMaxBytes,
  reportImagesMax,
  reportMaxBytes,
  reportTextMax,
  type ReportAttachment,
  type ReportBody,
} from '@harvest/contracts';
import { appVersion } from './news';

/**
 * *Report a problem* ([[Admin]], F12-5): what is written, up to four
 * pictures and one recording, sent without the session so it carries no
 * account. A picture never leaves as it was taken: it is drawn again on
 * a canvas and saved as a new JPEG, so its metadata — the GPS position,
 * the camera, the time — stays behind.
 */

/** The longest side a picture is sent at, in pixels: enough to read a screen. */
export const reportImageMaxSide = 2048;
export const reportImageQuality = 0.85;
/** The longest a recording made here may run. */
export const reportRecordingMaxMs = 5 * 60_000;

export type AudioType = (typeof reportAudioTypes)[number];

/** A picture or a recording, ready to go: already re-encoded when a picture. */
export interface ReportFile {
  kind: 'image' | 'audio';
  type: string;
  blob: Blob;
  /** An object URL for the preview, revoked when the file is removed or sent. */
  url: string;
}

/** Turns a picture into bytes on a canvas: the browser's by default, a test's own otherwise. */
export type ImageEncoder = (file: Blob) => Promise<Blob>;

/**
 * Draws [file] on a canvas, the longest side at most [reportImageMaxSide],
 * and saves it as a JPEG: nothing of the original file but its pixels.
 * Throws when the browser cannot read the picture (a HEIC it cannot
 * decode, a file that is not one).
 */
export const encodeImage: ImageEncoder = async (file) => {
  const bitmap = await createImageBitmap(file);
  try {
    const scale = Math.min(1, reportImageMaxSide / Math.max(bitmap.width, bitmap.height));
    const width = Math.max(1, Math.round(bitmap.width * scale));
    const height = Math.max(1, Math.round(bitmap.height * scale));
    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;
    const context = canvas.getContext('2d');
    if (!context) throw new Error('No canvas to draw on');
    // A transparent PNG turned JPEG would come out black where it was clear.
    context.fillStyle = '#ffffff';
    context.fillRect(0, 0, width, height);
    context.drawImage(bitmap, 0, 0, width, height);
    return await new Promise<Blob>((resolve, reject) =>
      canvas.toBlob((blob) => (blob ? resolve(blob) : reject(new Error('The picture would not encode'))), 'image/jpeg', reportImageQuality),
    );
  } finally {
    bitmap.close();
  }
};

/**
 * The contract's name for an audio file's type: a recording made here
 * says `audio/webm;codecs=opus`, a file picked may say `audio/x-m4a`.
 * Null for one the server will not take.
 */
export function audioTypeOf(type: string): AudioType | null {
  const base = type.split(';')[0]!.trim().toLowerCase();
  const aliases: Record<string, AudioType> = {
    'audio/x-m4a': 'audio/mp4',
    'audio/m4a': 'audio/mp4',
    'audio/x-wav': 'audio/wav',
    'audio/wave': 'audio/wav',
    'audio/mp3': 'audio/mpeg',
  };
  const named = aliases[base] ?? base;
  return (reportAudioTypes as readonly string[]).includes(named) ? (named as AudioType) : null;
}

export type ReportProblem = 'text' | 'images' | 'audio' | 'tooLarge' | 'imageTooLarge' | 'audioTooLarge';

/** What is wrong with a draft before anything is read or sent, or nothing. */
export function reportProblems(text: string, files: readonly Pick<ReportFile, 'kind' | 'blob'>[]): ReportProblem[] {
  const problems: ReportProblem[] = [];
  const trimmed = text.trim();
  if (trimmed.length === 0 || trimmed.length > reportTextMax) problems.push('text');
  const images = files.filter((file) => file.kind === 'image');
  const audio = files.filter((file) => file.kind === 'audio');
  if (images.length > reportImagesMax) problems.push('images');
  if (audio.length > 1) problems.push('audio');
  if (images.some((file) => file.blob.size > reportImageMaxBytes)) problems.push('imageTooLarge');
  if (audio.some((file) => file.blob.size > reportAudioMaxBytes)) problems.push('audioTooLarge');
  if (files.reduce((sum, file) => sum + file.blob.size, 0) > reportMaxBytes) problems.push('tooLarge');
  return problems;
}

async function base64Of(blob: Blob): Promise<string> {
  const bytes = new Uint8Array(await blob.arrayBuffer());
  let binary = '';
  // In slices: a spread of millions of bytes overflows the call stack.
  for (let at = 0; at < bytes.length; at += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(at, at + 0x8000));
  }
  return btoa(binary);
}

/** The body the server takes, from what the form holds; the contract checks it once more. */
export async function reportBodyOf(text: string, files: readonly ReportFile[]): Promise<ReportBody> {
  const attachments: ReportAttachment[] = [];
  for (const file of files) {
    const data = await base64Of(file.blob);
    if (file.kind === 'image') attachments.push({ kind: 'image', type: 'image/jpeg', data });
    else attachments.push({ kind: 'audio', type: audioTypeOf(file.type) ?? 'audio/webm', data });
  }
  const body: ReportBody = { text: text.trim(), platform: 'web', appVersion, attachments };
  reportBodySchema.parse(body);
  return body;
}

/** The recording type this browser can make, in the order the server prefers; null with none. */
export function recordingType(): string | null {
  if (typeof MediaRecorder === 'undefined') return null;
  for (const type of ['audio/webm;codecs=opus', 'audio/webm', 'audio/ogg;codecs=opus', 'audio/ogg', 'audio/mp4']) {
    if (MediaRecorder.isTypeSupported(type)) return type;
  }
  return null;
}
