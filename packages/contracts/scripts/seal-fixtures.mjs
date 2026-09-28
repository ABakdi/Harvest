/* global Buffer, console, crypto, URL, TextEncoder */
// Seals the contract fixtures the way Phase 7 sends every row, and pins
// the file names and the padding in `fixtures/crypto-v3.json`. Run after
// a build (`pnpm --filter @harvest/contracts build`), from the package:
//   node scripts/seal-fixtures.mjs
// A table whose record still carries `data` has it moved to
// `private-data/` and sealed; one already sealed is left as it is.
import { createHash } from 'node:crypto';
import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
import {
  fileNameKeyOf,
  fileNameOf,
  paddedLength,
  rowAadV2,
  sealFileV3,
  sealRowV2,
  syncKeyFromBits,
  trailKeyOf,
} from '../dist/index.js';

const here = (path) => new URL(`../fixtures/${path}`, import.meta.url);
const readJson = (path) => JSON.parse(readFileSync(here(path), 'utf8'));
const writeJson = (path, value) => writeFileSync(here(path), `${JSON.stringify(value, null, 2)}\n`);
const hex = (bytes) => Buffer.from(bytes).toString('hex');
const ivFor = (label) => new Uint8Array(createHash('sha256').update(`iv/${label}`).digest().subarray(0, 12));

const v2 = readJson('crypto-v2.json');
const keyBits = new Uint8Array(Buffer.from(v2.keyHex, 'hex'));
const key = await syncKeyFromBits(keyBits);
const nameKey = await fileNameKeyOf(keyBits, { extractable: true });

// The trail's day (Phase 7, M7.3), keyed by the name key's hash of its day.
try {
  readFileSync(here('records/trail_days.json'));
} catch {
  const day = '2026-09-17';
  const at = '2026-09-17T18:00:00.000Z';
  const key = await trailKeyOf(nameKey, day);
  const point = (uuid, recordedAt, latitude, longitude, extra = {}) => ({
    uuid,
    recordedAt,
    latitude,
    longitude,
    accuracyM: 8.5,
    speedMps: null,
    altitudeM: 12,
    updatedAt: recordedAt,
    deletedAt: null,
    ...extra,
  });
  writeJson('records/trail_days.json', {
    table: 'trail_days',
    uuid: key,
    updatedAt: at,
    deletedAt: null,
    data: {
      key,
      harvestDay: day,
      points: [
        point('7c1e4b9a-2d6f-4a3e-8b5c-1f9d7e3a6c42', '2026-09-17T08:12:30.000Z', 36.7538, 3.0588),
        point('3a8f2d6c-9b1e-4c7a-a5d3-6e2b8f4c1a97', '2026-09-17T08:27:05.000Z', 36.7612, 3.0476, {
          updatedAt: '2026-09-17T17:40:00.000Z',
          deletedAt: '2026-09-17T17:40:00.000Z',
        }),
      ],
      updatedAt: at,
    },
  });
}

for (const file of readdirSync(here('records')).filter((f) => f.endsWith('.json')).sort()) {
  const record = readJson(`records/${file}`);
  if (record.data === undefined) continue;
  const { data, ...rest } = record;
  writeJson(`private-data/${file}`, data);
  const clocks = { updatedAt: record.updatedAt, deletedAt: record.deletedAt };
  const sealed = { ...rest, enc: await sealRowV2(key, record.table, record.uuid, clocks, data, ivFor(record.table)) };
  if (typeof data.fileHash === 'string') sealed.file = await fileNameOf(nameKey, data.fileHash);
  writeJson(`records/${file}`, sealed);
}

const hashes = ['', 'harvest', 'a picture of the sea'].map((text) => createHash('sha256').update(text).digest('hex'));
const row = readJson('private-data/notes.json');
const rowRecord = readJson('records/notes.json');
const fileBytes = new TextEncoder().encode('Not really a picture, but bytes all the same.');
const fileName = await fileNameOf(nameKey, createHash('sha256').update(fileBytes).digest('hex'));
const fileIv = ivFor('file');
const file = await sealFileV3(key, fileName, fileBytes, fileIv);

writeJson('crypto-v3.json', {
  about:
    'What Phase 7 adds to the private tier (Sync-API; Phase-7-Privacy-and-Currencies M7.2), on top of crypto-v2.json, whose key it uses. ' +
    'nameKey = HKDF-SHA256(ikm = the sync key\'s 32 bytes, salt = 32 zero bytes, info = utf8("harvest/file-name/v1"), 32 bytes), an HMAC-SHA256 key. ' +
    'A file\'s name on the server = lowercase hex of HMAC-SHA256(nameKey, utf8(lowercase hex SHA-256 of the plaintext)). ' +
    'paddedLength(n, min = 256) = min when n <= min, else Padmé: E = floor(log2 n), S = floor(log2 E) + 1, step = 2^(E - S), n rounded up to a multiple of step. ' +
    'A row is sealed as in version 2, its JSON followed by spaces (0x20) up to paddedLength(its length); openers change nothing, since JSON ignores the spaces. ' +
    'A file is sealed as its bytes, then 0x80, then zeros up to paddedLength(length + 1), with the additional data utf8("file/v3/<name>"); ' +
    'the plain-bytes header carries the padded length. A file sealed before Phase 7 (aad "file/<name>", no padding) still opens. ' +
    'A day of the trail (trail_days) is keyed by the first 16 bytes, in hex, of HMAC-SHA256(nameKey, utf8("trail/<harvest day>")); trailKeys pins two. ' +
    'records/*.json are sealed with this key and the nonce the first 12 bytes of SHA-256("iv/<table>"), and carry `file` where their row names one.',
  keyHex: v2.keyHex,
  trailKeys: await Promise.all(
    ['2026-09-17', '2026-12-31'].map(async (day) => ({ day, key: await trailKeyOf(nameKey, day) })),
  ),
  nameKeyHex: hex(new Uint8Array(await crypto.subtle.exportKey('raw', nameKey))),
  names: await Promise.all(hashes.map(async (sha256) => ({ sha256, name: await fileNameOf(nameKey, sha256) }))),
  padding: [0, 1, 255, 256, 257, 300, 1000, 4097, 65_537, 1_000_000, 25 * 1024 * 1024 + 1].map((n) => ({
    n,
    padded: paddedLength(n),
  })),
  row: {
    table: rowRecord.table,
    uuid: rowRecord.uuid,
    updatedAt: rowRecord.updatedAt,
    deletedAt: rowRecord.deletedAt,
    aad: rowAadV2(rowRecord.table, rowRecord.uuid, rowRecord),
    plaintext: JSON.stringify(row),
    enc: rowRecord.enc,
  },
  file: {
    plaintextBase64: Buffer.from(fileBytes).toString('base64'),
    name: fileName,
    aad: `file/v3/${fileName}`,
    iv: file.iv,
    sealedBase64: Buffer.from(file.sealed).toString('base64'),
  },
});
console.log('sealed the fixtures');
