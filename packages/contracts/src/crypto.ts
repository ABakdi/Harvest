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
 *
 * That is version 1, as 3.0.0 wrote it. Version 2 (below, pinned by
 * `fixtures/crypto-v2.json`) adds the account's key share to the key and
 * the row's clocks to the additional data.
 */
import type { EncEnvelope } from './sync.js';
import { hasColumn, tables, type SyncedTable } from './tables.js';
import { instantMicros, sameInstant } from './time.js';

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

// ------------------------------------------------------------ version 2

/**
 * Version 2 of the private tier ([[Sync-API]]):
 *
 * - the key is HKDF-SHA256 over the version 1 key (PBKDF2 of the secret
 *   and the salt, unchanged), salted with the account's `keyShare`, the
 *   32 random bytes the server hands only to a signed-in session, with
 *   the info `harvest/sync-key/v2`. The salt and the ciphertext alone,
 *   from a copy of the database, are no longer enough to try PINs.
 * - the envelope says `v: 2`;
 * - a row's additional data is
 *   `row/<table>/<uuid>/<updatedAt micros>/<deletedAt micros or "">`, so
 *   an older ciphertext offered under a newer clock fails to open, and a
 *   deleted version cannot be replayed as a live one;
 * - files are sealed as before (`file/<sha256>`), with the version 2 key;
 * - the account's key check is the text `harvest-key-check` sealed with
 *   the additional data `key-check`: a secret is the account's secret
 *   exactly when its key opens it.
 */
export const syncKeyInfoV2 = 'harvest/sync-key/v2';
export const keyCheckPlaintext = 'harvest-key-check';
export const keyCheckAad = 'key-check';

/** The clocks a record carries in the clear, which a version 2 row binds. */
export interface RowClocks {
  updatedAt: string;
  deletedAt: string | null;
}

/** A sealed row this key cannot read: another key, another row or clock, or version 1. */
export class UnreadableRowError extends Error {
  constructor(message = 'This row cannot be opened with this key') {
    super(message);
    this.name = 'UnreadableRowError';
  }
}

function bytesOf(value: string | Uint8Array): Uint8Array<ArrayBuffer> {
  if (typeof value === 'string') return fromBase64(value);
  const copy = new Uint8Array(value.length);
  copy.set(value);
  return copy;
}

/**
 * The secret's base: PBKDF2-HMAC-SHA256 of the secret with the account's
 * salt, 32 bytes. Both the PIN proof and the key are drawn from it, so a
 * device runs the slow part once.
 */
export async function deriveSyncBase(
  secret: string,
  syncSalt: string,
  options: { iterations?: number } = {},
): Promise<Uint8Array<ArrayBuffer>> {
  const password = await crypto.subtle.importKey('raw', encoder.encode(secret), 'PBKDF2', false, [
    'deriveBits',
  ]);
  const base = await crypto.subtle.deriveBits(
    {
      name: 'PBKDF2',
      hash: 'SHA-256',
      salt: encoder.encode(syncSalt),
      iterations: options.iterations ?? syncKeyIterations,
    },
    password,
    256,
  );
  return new Uint8Array(base);
}

/**
 * The PIN proof's HKDF info. The proof is what a device shows the server
 * to be handed the key share (`POST /v1/me/sync-key/unlock`); it is not
 * the key, and the key cannot be had from it.
 */
export const syncPinProofInfo = 'harvest/sync-pin-proof/v1';

/** The PIN proof, 32 bytes: HKDF-SHA256 over the base, empty salt. */
export async function pinProofOf(base: Uint8Array): Promise<Uint8Array<ArrayBuffer>> {
  const ikm = await crypto.subtle.importKey('raw', bytesOf(base), 'HKDF', false, ['deriveBits']);
  const bits = await crypto.subtle.deriveBits(
    { name: 'HKDF', hash: 'SHA-256', salt: new Uint8Array(0), info: encoder.encode(syncPinProofInfo) },
    ikm,
    256,
  );
  return new Uint8Array(bits);
}

/** The PIN proof straight from the secret, base64, as the unlock body carries it. */
export async function derivePinProof(
  secret: string,
  syncSalt: string,
  options: { iterations?: number } = {},
): Promise<string> {
  return toBase64(await pinProofOf(await deriveSyncBase(secret, syncSalt, options)));
}

/**
 * What the server keeps instead of the proof: SHA-256 of its bytes, hex.
 * The first device sends it with the key check.
 */
export async function pinVerifierOf(proof: string | Uint8Array): Promise<string> {
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', bytesOf(proof)));
  return Array.from(digest, (byte) => byte.toString(16).padStart(2, '0')).join('');
}

/** The version 2 key from a base already derived ([[deriveSyncBase]]). */
export async function syncKeyOf(
  base: Uint8Array,
  keyShare: string | Uint8Array,
  options: { extractable?: boolean } = {},
): Promise<CryptoKey> {
  const ikm = await crypto.subtle.importKey('raw', bytesOf(base), 'HKDF', false, ['deriveKey']);
  return crypto.subtle.deriveKey(
    { name: 'HKDF', hash: 'SHA-256', salt: bytesOf(keyShare), info: encoder.encode(syncKeyInfoV2) },
    ikm,
    { name: 'AES-GCM', length: 256 },
    options.extractable ?? false,
    ['encrypt', 'decrypt'],
  );
}

/**
 * The version 2 key, from the secret, the account's salt and its key
 * share (base64, as the server hands it out, or the bytes).
 */
export async function deriveSyncKeyV2(
  secret: string,
  syncSalt: string,
  keyShare: string | Uint8Array,
  options: { iterations?: number; extractable?: boolean } = {},
): Promise<CryptoKey> {
  const base = await deriveSyncBase(secret, syncSalt, options);
  const ikm = await crypto.subtle.importKey('raw', base, 'HKDF', false, ['deriveKey']);
  return crypto.subtle.deriveKey(
    { name: 'HKDF', hash: 'SHA-256', salt: bytesOf(keyShare), info: encoder.encode(syncKeyInfoV2) },
    ikm,
    { name: 'AES-GCM', length: 256 },
    options.extractable ?? false,
    ['encrypt', 'decrypt'],
  );
}

/** A version 2 row's additional data: the table, the key and both clocks. */
export function rowAadV2(table: string, uuid: string, clocks: RowClocks): string {
  const deleted = clocks.deletedAt === null ? '' : String(instantMicros(clocks.deletedAt));
  return `row/${table}/${uuid}/${instantMicros(clocks.updatedAt)}/${deleted}`;
}

/** Seals one row's data for the wire, bound to the clocks it travels with. */
export async function sealRowV2(
  key: CryptoKey,
  table: string,
  uuid: string,
  clocks: RowClocks,
  data: Record<string, unknown>,
  iv: Uint8Array<ArrayBuffer> = crypto.getRandomValues(new Uint8Array(12)),
): Promise<EncEnvelope> {
  const ct = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv, additionalData: encoder.encode(rowAadV2(table, uuid, clocks)), tagLength: 128 },
    key,
    padRowText(encoder.encode(JSON.stringify(data))),
  );
  return { v: 2, iv: toBase64(iv), ct: toBase64(new Uint8Array(ct)) };
}

/**
 * Opens one version 2 row, or throws [UnreadableRowError]: a version 1
 * envelope, another key, another row, or clocks other than the ones it
 * was sealed with. The row's own `updatedAt`/`deletedAt`, where its
 * table has them, must also be the record's.
 */
export async function openRowV2(
  key: CryptoKey,
  table: string,
  uuid: string,
  clocks: RowClocks,
  envelope: { v: number; iv: string; ct: string },
): Promise<Record<string, unknown>> {
  if (envelope.v !== 2) throw new UnreadableRowError('A version 1 envelope');
  let plain: ArrayBuffer;
  try {
    plain = await crypto.subtle.decrypt(
      {
        name: 'AES-GCM',
        iv: fromBase64(envelope.iv),
        additionalData: encoder.encode(rowAadV2(table, uuid, clocks)),
        tagLength: 128,
      },
      key,
      fromBase64(envelope.ct),
    );
  } catch {
    throw new UnreadableRowError();
  }
  const data = JSON.parse(decoder.decode(plain)) as Record<string, unknown>;
  if (!clocksMatch(table, clocks, data)) throw new UnreadableRowError("The row's clocks are not the record's");
  return data;
}

/** Whether an opened row's own clocks are the record's, where its table keeps them. */
export function clocksMatch(table: string, clocks: RowClocks, data: Record<string, unknown>): boolean {
  if (!Object.hasOwn(tables, table)) return false;
  const synced = table as SyncedTable;
  const same = (value: unknown, expected: string | null): boolean => {
    if (value !== null && typeof value !== 'string') return false;
    try {
      return sameInstant(value, expected);
    } catch {
      return false;
    }
  };
  if (hasColumn(synced, 'updatedAt') && !same(data.updatedAt ?? null, clocks.updatedAt)) return false;
  if (hasColumn(synced, 'deletedAt') && !same(data.deletedAt ?? null, clocks.deletedAt)) return false;
  return true;
}

/** Seals the account's key check under [key]: what the first device stores. */
export async function sealKeyCheck(
  key: CryptoKey,
  iv: Uint8Array<ArrayBuffer> = crypto.getRandomValues(new Uint8Array(12)),
): Promise<EncEnvelope> {
  const ct = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv, additionalData: encoder.encode(keyCheckAad), tagLength: 128 },
    key,
    encoder.encode(keyCheckPlaintext),
  );
  return { v: 2, iv: toBase64(iv), ct: toBase64(new Uint8Array(ct)) };
}

/** Whether [key] opens the account's key check: whether it is the account's key. */
export async function opensKeyCheck(
  key: CryptoKey,
  check: { v: number; iv: string; ct: string },
): Promise<boolean> {
  if (check.v !== 2) return false;
  try {
    const plain = await crypto.subtle.decrypt(
      {
        name: 'AES-GCM',
        iv: fromBase64(check.iv),
        additionalData: encoder.encode(keyCheckAad),
        tagLength: 128,
      },
      key,
      fromBase64(check.ct),
    );
    return decoder.decode(plain) === keyCheckPlaintext;
  } catch {
    return false;
  }
}

// ------------------------------------------------ Phase 7: names, sizes

/**
 * What Phase 7 adds ([[Phase-7-Privacy-and-Currencies]], M7.2), pinned by
 * `fixtures/crypto-v3.json`:
 *
 * - **A file's name on the server** is HMAC-SHA256 of its plaintext's
 *   SHA-256 (the lowercase hex, as UTF-8) under the *name key*, in
 *   lowercase hex. Two devices with the same key agree on it; a server
 *   holding a known picture cannot tell whether an account has it.
 * - The name key is HKDF-SHA256 over the sync key's 32 bytes, with the
 *   empty salt spelled as 32 zero bytes and the info
 *   `harvest/file-name/v1`.
 * - **Sizes are padded** before sealing ([[paddedLength]]): a row's JSON
 *   with trailing spaces, which JSON ignores, so nothing changes for a
 *   reader; a file's bytes with `0x80` and then zeros (ISO/IEC 7816-4),
 *   sealed with the additional data `file/v3/<name>`. A file sealed
 *   before, under `file/<name>` and unpadded, still opens ([[openFileAny]]).
 */
export const fileNameInfo = 'harvest/file-name/v1';

/** The smallest a sealed row's plaintext is: below it, every row looks the same. */
export const minPaddedRowBytes = 256;

/**
 * The length [n] bytes are padded to: at least [minimum], and above it
 * the Padmé rule (Nikitin et al., 2019), which rounds to a number with
 * few significant bits, costs at most about 12% and leaves only
 * O(log log n) bits of the length to be read.
 */
export function paddedLength(n: number, minimum = minPaddedRowBytes): number {
  if (n <= minimum) return minimum;
  if (n < 4) return n;
  const e = Math.floor(Math.log2(n));
  const s = Math.floor(Math.log2(e)) + 1;
  const lastBits = e - s;
  const mask = 2 ** lastBits - 1;
  // Math, not bitwise: a length past 2^31 still rounds right.
  return Math.ceil(n / (mask + 1)) * (mask + 1);
}

/** A row's JSON, padded with spaces to [paddedLength]. */
export function padRowText(json: Uint8Array): Uint8Array<ArrayBuffer> {
  const padded = new Uint8Array(paddedLength(json.length)).fill(0x20);
  padded.set(json);
  return padded;
}

/** A file's bytes, `0x80` and zeros after them, to [paddedLength] of one byte more. */
export function padFileBytes(bytes: Uint8Array): Uint8Array<ArrayBuffer> {
  const padded = new Uint8Array(paddedLength(bytes.length + 1));
  padded.set(bytes);
  padded[bytes.length] = 0x80;
  return padded;
}

/** The bytes [padFileBytes] padded, or throws when the padding is not there. */
export function unpadFileBytes(padded: Uint8Array): Uint8Array {
  let end = padded.length - 1;
  while (end >= 0 && padded[end] === 0) end--;
  if (end < 0 || padded[end] !== 0x80) throw new UnreadableRowError('A file without its padding');
  return padded.subarray(0, end);
}

/**
 * The most a sealed file may be, in bytes: the biggest file padded,
 * with the tag.
 */
export function maxSealedBytes(maxPlainBytes: number): number {
  return paddedLength(maxPlainBytes + 1) + 16;
}

/** The sync key's 32 bytes, from a base and the account's key share ([[syncKeyOf]] as bits). */
export async function syncKeyBitsOf(base: Uint8Array, keyShare: string | Uint8Array): Promise<Uint8Array<ArrayBuffer>> {
  const ikm = await crypto.subtle.importKey('raw', bytesOf(base), 'HKDF', false, ['deriveBits']);
  const bits = await crypto.subtle.deriveBits(
    { name: 'HKDF', hash: 'SHA-256', salt: bytesOf(keyShare), info: encoder.encode(syncKeyInfoV2) },
    ikm,
    256,
  );
  return new Uint8Array(bits);
}

/** The sync key itself from its bytes, as a non-extractable AES-GCM key unless asked. */
export function syncKeyFromBits(bits: Uint8Array, options: { extractable?: boolean } = {}): Promise<CryptoKey> {
  return crypto.subtle.importKey('raw', bytesOf(bits), { name: 'AES-GCM', length: 256 }, options.extractable ?? false, [
    'encrypt',
    'decrypt',
  ]);
}

/** The name key, from the sync key's bytes: an HMAC-SHA256 key that only signs. */
export async function fileNameKeyOf(
  keyBits: Uint8Array,
  options: { extractable?: boolean } = {},
): Promise<CryptoKey> {
  const ikm = await crypto.subtle.importKey('raw', bytesOf(keyBits), 'HKDF', false, ['deriveBits']);
  const bits = await crypto.subtle.deriveBits(
    { name: 'HKDF', hash: 'SHA-256', salt: new Uint8Array(32), info: encoder.encode(fileNameInfo) },
    ikm,
    256,
  );
  return crypto.subtle.importKey('raw', bits, { name: 'HMAC', hash: 'SHA-256' }, options.extractable ?? false, [
    'sign',
  ]);
}

/** A file's name on the server, from its plaintext's SHA-256. */
export async function fileNameOf(nameKey: CryptoKey, sha256: string): Promise<string> {
  const mac = new Uint8Array(await crypto.subtle.sign('HMAC', nameKey, encoder.encode(sha256)));
  return Array.from(mac, (byte) => byte.toString(16).padStart(2, '0')).join('');
}

/** Seals a file's bytes, padded, under its server name. */
export async function sealFileV3(
  key: CryptoKey,
  name: string,
  bytes: Uint8Array,
  iv: Uint8Array<ArrayBuffer> = crypto.getRandomValues(new Uint8Array(12)),
): Promise<{ iv: string; sealed: ArrayBuffer }> {
  const sealed = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv, additionalData: encoder.encode(`file/v3/${name}`), tagLength: 128 },
    key,
    padFileBytes(bytes),
  );
  return { iv: toBase64(iv), sealed };
}

/**
 * Opens a file's bytes under its server name, whichever way it was
 * sealed: padded under `file/v3/<name>`, or as before Phase 7.
 */
export async function openFileAny(
  key: CryptoKey,
  name: string,
  envelope: { iv: string; ct: ArrayBuffer },
): Promise<Uint8Array> {
  const iv = fromBase64(envelope.iv);
  try {
    const plain = await crypto.subtle.decrypt(
      { name: 'AES-GCM', iv, additionalData: encoder.encode(`file/v3/${name}`), tagLength: 128 },
      key,
      envelope.ct,
    );
    return unpadFileBytes(new Uint8Array(plain));
  } catch (error) {
    if (error instanceof UnreadableRowError) throw error;
    return openFile(key, name, envelope);
  }
}

/**
 * The record key of a day of the trail (`trail_days`): the name key's
 * HMAC of `trail/<harvest day>`, the first 16 bytes in hex, so two
 * devices agree on it and the server cannot tell which day it is.
 */
export async function trailKeyOf(nameKey: CryptoKey, harvestDay: string): Promise<string> {
  const mac = new Uint8Array(await crypto.subtle.sign('HMAC', nameKey, encoder.encode(`trail/${harvestDay}`)));
  return Array.from(mac.subarray(0, 16), (byte) => byte.toString(16).padStart(2, '0')).join('');
}
