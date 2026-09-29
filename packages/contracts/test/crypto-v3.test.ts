import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import {
  fileNameKeyOf,
  fileNameOf,
  maxSealedBytes,
  openFile,
  openFileAny,
  openRowV2,
  padFileBytes,
  paddedLength,
  sealFile,
  sealFileV3,
  sealRowV2,
  syncKeyBitsOf,
  syncKeyFromBits,
  syncKeyOf,
  unpadFileBytes,
  deriveSyncBase,
  trailKeyOf,
} from '../src/crypto.js';
import { maxFileBytes, maxSealedFileBytes } from '../src/files.js';

interface Envelope {
  v: number;
  iv: string;
  ct: string;
}

const spec = JSON.parse(readFileSync(new URL('../fixtures/crypto-v3.json', import.meta.url), 'utf8')) as {
  keyHex: string;
  nameKeyHex: string;
  trailKeys: { day: string; key: string }[];
  names: { sha256: string; name: string }[];
  padding: { n: number; padded: number }[];
  row: { table: string; uuid: string; updatedAt: string; deletedAt: string | null; plaintext: string; enc: Envelope };
  file: { plaintextBase64: string; name: string; iv: string; sealedBase64: string };
};
const v2 = JSON.parse(readFileSync(new URL('../fixtures/crypto-v2.json', import.meta.url), 'utf8')) as {
  secret: string;
  syncSalt: string;
  keyShare: string;
  keyHex: string;
};

const bits = new Uint8Array(Buffer.from(spec.keyHex, 'hex'));
const key = () => syncKeyFromBits(bits);
const bytesOf = (b64: string) => new Uint8Array(Buffer.from(b64, 'base64'));

describe('the key as bits (fixtures/crypto-v3.json)', () => {
  it('is the version 2 key, byte for byte', async () => {
    expect(v2.keyHex).toBe(spec.keyHex);
    const base = await deriveSyncBase(v2.secret, v2.syncSalt);
    expect(Buffer.from(await syncKeyBitsOf(base, v2.keyShare)).toString('hex')).toBe(spec.keyHex);
    const derived = await syncKeyOf(base, v2.keyShare, { extractable: true });
    expect(Buffer.from(await crypto.subtle.exportKey('raw', derived)).toString('hex')).toBe(spec.keyHex);
  });

  it('never lets the imported key out', async () => {
    await expect(crypto.subtle.exportKey('raw', await key())).rejects.toThrow();
  });
});

describe('file names', () => {
  it('derives the pinned name key, which only signs', async () => {
    const nameKey = await fileNameKeyOf(bits, { extractable: true });
    expect(Buffer.from(await crypto.subtle.exportKey('raw', nameKey)).toString('hex')).toBe(spec.nameKeyHex);
    expect((await fileNameKeyOf(bits)).usages).toEqual(['sign']);
  });

  it.each(spec.names)('names $sha256 as pinned', async ({ sha256, name }) => {
    expect(await fileNameOf(await fileNameKeyOf(bits), sha256)).toBe(name);
    expect(name).toMatch(/^[0-9a-f]{64}$/);
    expect(name).not.toBe(sha256);
  });

  it('names the same file differently under another key', async () => {
    const other = new Uint8Array(32).fill(7);
    const hash = spec.names[1]!.sha256;
    expect(await fileNameOf(await fileNameKeyOf(other), hash)).not.toBe(spec.names[1]!.name);
  });
});

describe('the trail’s day keys', () => {
  it.each(spec.trailKeys)('keys $day as pinned', async ({ day, key }) => {
    expect(await trailKeyOf(await fileNameKeyOf(bits), day)).toBe(key);
    expect(key).toMatch(/^[0-9a-f]{32}$/);
  });
});

describe('padding', () => {
  it.each(spec.padding)('pads $n to $padded', ({ n, padded }) => {
    expect(paddedLength(n)).toBe(padded);
  });

  it('never shrinks, and costs at most an eighth above the minimum', () => {
    for (let n = 1; n < 5_000_000; n = Math.ceil(n * 1.37) + 1) {
      const padded = paddedLength(n);
      expect(padded).toBeGreaterThanOrEqual(n);
      if (n > 256) expect(padded / n).toBeLessThanOrEqual(1.125);
    }
  });

  it('gives a note and a place of close lengths the same size', async () => {
    const k = await key();
    const clocks = { updatedAt: '2026-09-19T10:00:00Z', deletedAt: null };
    const a = await sealRowV2(k, 'notes', 'a', clocks, { body: 'x'.repeat(20) });
    const b = await sealRowV2(k, 'saved_places', 'b', clocks, { name: 'Home', latitude: 36.75, longitude: 3.05 });
    expect(a.ct.length).toBe(b.ct.length);
  });

  it('round-trips a file’s bytes, and refuses bytes that were never padded', () => {
    for (const length of [0, 1, 255, 256, 1000, 70_000]) {
      const bytes = new Uint8Array(length).map((_, i) => (i * 31) % 256);
      const padded = padFileBytes(bytes);
      expect(padded.length).toBe(paddedLength(length + 1));
      expect(unpadFileBytes(padded)).toEqual(bytes);
    }
    expect(() => unpadFileBytes(new Uint8Array(16))).toThrow();
    expect(() => unpadFileBytes(new Uint8Array([1, 2, 3]))).toThrow();
  });

  it('bounds the biggest sealed file', () => {
    expect(maxSealedFileBytes).toBe(maxSealedBytes(maxFileBytes));
    expect(maxSealedFileBytes).toBe(paddedLength(maxFileBytes + 1) + 16);
    expect(maxSealedFileBytes).toBeLessThan(maxFileBytes * 1.05);
  });
});

describe('rows, padded', () => {
  it('opens the pinned sealed row to its plaintext', async () => {
    const { row } = spec;
    const opened = await openRowV2(await key(), row.table, row.uuid, row, row.enc);
    expect(opened).toEqual(JSON.parse(row.plaintext));
  });

  it('seals the pinned row to the same bytes with the same nonce', async () => {
    const { row } = spec;
    const data = JSON.parse(row.plaintext) as Record<string, unknown>;
    expect(await sealRowV2(await key(), row.table, row.uuid, row, data, bytesOf(row.enc.iv))).toEqual(row.enc);
  });
});

describe('files, version 3', () => {
  it('opens the pinned file to its bytes', async () => {
    const { file } = spec;
    const opened = await openFileAny(await key(), file.name, {
      iv: file.iv,
      ct: bytesOf(file.sealedBase64).buffer,
    });
    expect(Buffer.from(opened).toString('base64')).toBe(file.plaintextBase64);
  });

  it('seals the pinned file to the same bytes with the same nonce', async () => {
    const { file } = spec;
    const sealed = await sealFileV3(await key(), file.name, bytesOf(file.plaintextBase64), bytesOf(file.iv));
    expect(Buffer.from(sealed.sealed).toString('base64')).toBe(file.sealedBase64);
  });

  it('still opens a file sealed before Phase 7, and refuses one under another name', async () => {
    const k = await key();
    const bytes = new TextEncoder().encode('an old picture');
    const old = await sealFile(k, 'abc', bytes);
    expect(await openFileAny(k, 'abc', { iv: old.iv, ct: old.sealed })).toEqual(bytes);
    expect(await openFile(k, 'abc', { iv: old.iv, ct: old.sealed })).toEqual(bytes);
    const fresh = await sealFileV3(k, 'abc', bytes);
    await expect(openFileAny(k, 'abd', { iv: fresh.iv, ct: fresh.sealed })).rejects.toThrow();
  });
});
