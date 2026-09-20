import { createHash, randomBytes } from 'node:crypto';
import { fileIvHeader, filePlainBytesHeader, maxFileBytes } from '@harvest/contracts';
import request from 'supertest';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { bearer, expectError, harness, password, signUp, type Account, type Harness } from './harness.js';

let h: Harness;
beforeEach(async () => {
  h = await harness();
});
afterEach(async () => {
  await h.close();
});

/** The nonce is twelve bytes, as the envelope's is. */
const iv = randomBytes(12).toString('base64');

function nameOf(bytes: Buffer): string {
  return createHash('sha256').update(bytes).digest('hex');
}

function upload(account: Account, sha256: string, body: Buffer, plainBytes = body.length) {
  return request(h.app)
    .put(`/v1/files/${sha256}`)
    .set(bearer(account))
    .set('Content-Type', 'application/octet-stream')
    .set(fileIvHeader, iv)
    .set(filePlainBytesHeader, String(plainBytes))
    .send(body);
}

describe('files', () => {
  it('takes a file once and hands the same bytes back', async () => {
    const account = await signUp(h);
    const plain = randomBytes(2048);
    const sealed = Buffer.concat([plain, randomBytes(16)]);
    const sha256 = nameOf(plain);

    const first = await upload(account, sha256, sealed, plain.length).expect(201);
    expect(first.body).toMatchObject({ sha256, had: false });

    // The name is the contents, so a second upload is the same file.
    const again = await upload(account, sha256, sealed, plain.length).expect(200);
    expect(again.body).toMatchObject({ had: true });

    const got = await request(h.app).get(`/v1/files/${sha256}`).set(bearer(account)).expect(200);
    expect(Buffer.from(got.body as Buffer).equals(sealed)).toBe(true);
    expect(got.get(fileIvHeader)).toBe(iv);
    expect(got.get(filePlainBytesHeader)).toBe(String(plain.length));
  });

  it('says which of a list it does not have', async () => {
    const account = await signUp(h);
    const held = randomBytes(64);
    const heldName = nameOf(held);
    const wantedName = nameOf(randomBytes(64));
    await upload(account, heldName, held).expect(201);

    const res = await request(h.app)
      .post('/v1/files/missing')
      .set(bearer(account))
      .send({ hashes: [heldName, wantedName] })
      .expect(200);
    expect(res.body).toMatchObject({ missing: [wantedName], usedBytes: held.length });
  });

  it('keeps one account out of another account\'s files', async () => {
    const mine = await signUp(h);
    const theirs = await signUp(h);
    const bytes = randomBytes(32);
    const sha256 = nameOf(bytes);
    await upload(mine, sha256, bytes).expect(201);

    expectError(await request(h.app).get(`/v1/files/${sha256}`).set(bearer(theirs)), 404, 'not_found');
    const res = await request(h.app)
      .post('/v1/files/missing')
      .set(bearer(theirs))
      .send({ hashes: [sha256] })
      .expect(200);
    expect(res.body).toMatchObject({ missing: [sha256], usedBytes: 0 });
  });

  it('refuses a file over the cap, and a name that is not a hash', async () => {
    const account = await signUp(h);
    const bytes = randomBytes(64);
    expectError(await upload(account, 'not-a-hash', bytes), 400, 'validation_failed');

    const huge = Buffer.alloc(maxFileBytes + 8192);
    expectError(await upload(account, nameOf(huge), huge), 413, 'payload_too_large');
  });

  it('refuses an unverified account, and a stranger', async () => {
    const unverified = await signUp(h, { verify: false });
    const bytes = randomBytes(16);
    expectError(await upload(unverified, nameOf(bytes), bytes), 403, 'forbidden');
    expectError(await request(h.app).get(`/v1/files/${nameOf(bytes)}`), 401, 'unauthorized');
  });

  it('takes the files with the account', async () => {
    const account = await signUp(h);
    const bytes = randomBytes(128);
    const sha256 = nameOf(bytes);
    await upload(account, sha256, bytes).expect(201);

    await request(h.app)
      .delete('/v1/me')
      .set(bearer(account))
      .send({ password })
      .expect(204);
    expect(await h.repos.files.usedBytes(account.userId as never)).toBe(0);
  });
});
