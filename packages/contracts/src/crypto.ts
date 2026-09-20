/**
 * The private tier's envelope ([[Sync-API]]), the same on every client.
 *
 * - The key is PBKDF2-HMAC-SHA256 over the sync passphrase, salted with
 *   the account's `syncSalt` (its UTF-8 bytes), 600,000 iterations, 32
 *   bytes. The passphrase never leaves the device, and neither does the
 *   key.
 * - A row is AES-256-GCM over the JSON of its data, with a fresh 12-byte
 *   IV and the 128-bit tag appended, as WebCrypto writes it.
 * - The additional data is `<table>/<record uuid>`, so a ciphertext
 *   moved onto another row, or another table, fails to open rather than
 *   quietly becoming that row.
 *
 * `fixtures/crypto.json` pins all of it, and the phone's tests read the
 * same file.
 */
import type { EncEnvelope } from './sync.js';

export const syncKeyIterations = 600_000;

const encoder = new TextEncoder();
const decoder = new TextDecoder();

/** The private tier's key, from the passphrase and the account's salt. */
export async function deriveSyncKey(
  passphrase: string,
  syncSalt: string,
  options: { iterations?: number; extractable?: boolean } = {},
): Promise<CryptoKey> {
  const base = await crypto.subtle.importKey('raw', encoder.encode(passphrase), 'PBKDF2', false, [
    'deriveKey',
  ]);
  return crypto.subtle.deriveKey(
    {
      name: 'PBKDF2',
      hash: 'SHA-256',
      salt: encoder.encode(syncSalt),
      iterations: options.iterations ?? syncKeyIterations,
    },
    base,
    { name: 'AES-GCM', length: 256 },
    options.extractable ?? false,
    ['encrypt', 'decrypt'],
  );
}

function additionalData(table: string, uuid: string): Uint8Array<ArrayBuffer> {
  return encoder.encode(`${table}/${uuid}`);
}

function toBase64(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function fromBase64(text: string): Uint8Array<ArrayBuffer> {
  const binary = atob(text);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

/** Seals one row's data for the wire. */
export async function sealRow(
  key: CryptoKey,
  table: string,
  uuid: string,
  data: Record<string, unknown>,
  iv: Uint8Array<ArrayBuffer> = crypto.getRandomValues(new Uint8Array(12)),
): Promise<EncEnvelope> {
  const ct = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv, additionalData: additionalData(table, uuid), tagLength: 128 },
    key,
    encoder.encode(JSON.stringify(data)),
  );
  return { v: 1, iv: toBase64(iv), ct: toBase64(new Uint8Array(ct)) };
}

/**
 * Seals a file's bytes: the same cipher and key as a row, with the
 * file's own name as the additional data, so ciphertext offered under
 * another name fails to open ([[Sync-API]], files).
 */
export async function sealFile(
  key: CryptoKey,
  sha256: string,
  bytes: Uint8Array<ArrayBuffer>,
  iv: Uint8Array<ArrayBuffer> = crypto.getRandomValues(new Uint8Array(12)),
): Promise<{ iv: string; sealed: ArrayBuffer }> {
  const sealed = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv, additionalData: encoder.encode(`file/${sha256}`), tagLength: 128 },
    key,
    bytes,
  );
  return { iv: toBase64(iv), sealed };
}

/** Opens a file's bytes, sealed by whichever device had them first. */
export async function openFile(
  key: CryptoKey,
  sha256: string,
  envelope: { iv: string; ct: ArrayBuffer },
): Promise<Uint8Array> {
  const plain = await crypto.subtle.decrypt(
    {
      name: 'AES-GCM',
      iv: fromBase64(envelope.iv),
      additionalData: encoder.encode(`file/${sha256}`),
      tagLength: 128,
    },
    key,
    envelope.ct,
  );
  return new Uint8Array(plain);
}

/** Opens one row, or throws when the key, the row or the table is wrong. */
export async function openRow(
  key: CryptoKey,
  table: string,
  uuid: string,
  envelope: EncEnvelope,
): Promise<Record<string, unknown>> {
  const plain = await crypto.subtle.decrypt(
    {
      name: 'AES-GCM',
      iv: fromBase64(envelope.iv),
      additionalData: additionalData(table, uuid),
      tagLength: 128,
    },
    key,
    fromBase64(envelope.ct),
  );
  return JSON.parse(decoder.decode(plain)) as Record<string, unknown>;
}
