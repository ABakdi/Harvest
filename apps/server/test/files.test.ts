import { createHash, randomBytes } from 'node:crypto';
import { request as httpRequest } from 'node:http';
import {
  fileIvHeader,
  fileKeyEpochHeader,
  filePlainBytesHeader,
  maxFileBytes,
  maxFileStoreBytes,
  tierOf,
} from '@harvest/contracts';
import { Binary, ObjectId } from 'mongodb';
import request from 'supertest';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { fileTables } from '../src/db/records.js';
import { FileSweeper, unnamedFileGraceMs } from '../src/sync/file-sweep.js';
import { KeyedMutex } from '../src/sync/mutex.js';
import { appOrigin, bearer, expectError, harness, password, signUp, type Account, type Harness } from './harness.js';

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
    .set(fileKeyEpochHeader, '1')
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

describe('the tables that name files (SV-12)', () => {
  it('are every table with a fileHash, and each is plain, so the sweep can read the names', () => {
    expect(fileTables).toEqual(expect.arrayContaining(['memories', 'note_attachments']));
    for (const table of fileTables) expect(tierOf(table)).toBe('plain');
  });
});

describe('room (audit S5-08, Q5-23)', () => {
  const counterOf = async (account: Account) =>
    (await h.db.collection('counters').findOne({ _id: new ObjectId(account.userId) }))?.fileBytes as number | undefined;

  it('charges the room before the bytes land, so two uploads cannot share the last of it', async () => {
    const account = await signUp(h);
    const a = randomBytes(1000);
    const b = randomBytes(1000);
    await h.db
      .collection('counters')
      .updateOne(
        { _id: new ObjectId(account.userId) },
        { $set: { fileBytes: maxFileStoreBytes - 1500 } },
        { upsert: true },
      );
    const answers = await Promise.all([upload(account, nameOf(a), a), upload(account, nameOf(b), b)]);
    expect(answers.map((res) => res.status).sort()).toEqual([201, 507]);
    expect(await counterOf(account)).toBe(maxFileStoreBytes - 500);
  });

  it('fills in the room used by an account from before it was kept', async () => {
    const account = await signUp(h);
    const a = randomBytes(300);
    await upload(account, nameOf(a), a).expect(201);
    await h.db.collection('counters').updateOne({ _id: new ObjectId(account.userId) }, { $unset: { fileBytes: '' } });
    const b = randomBytes(200);
    await upload(account, nameOf(b), b).expect(201);
    expect(await counterOf(account)).toBe(500);
  });

  /** Moves a file's upload and claim back past the grace, as time would. */
  const age = (account: Account, sha256: string) => {
    const long = new Date(Date.now() - unnamedFileGraceMs - 60_000);
    return h.db
      .collection('files')
      .updateOne({ userId: new ObjectId(account.userId), sha256 }, { $set: { uploadedAt: long, claimedAt: long } });
  };

  it('lets a file go, and gives its room back', async () => {
    const account = await signUp(h);
    const bytes = randomBytes(256);
    const sha256 = nameOf(bytes);
    await upload(account, sha256, bytes).expect(201);
    expect(await counterOf(account)).toBe(256);
    await age(account, sha256);

    await request(h.app).delete(`/v1/files/${sha256}`).set(bearer(account)).expect(204);
    expectError(await request(h.app).get(`/v1/files/${sha256}`).set(bearer(account)), 404, 'not_found');
    expect(await counterOf(account)).toBe(0);
    // Gone already is gone.
    await request(h.app).delete(`/v1/files/${sha256}`).set(bearer(account)).expect(204);
    expect(await counterOf(account)).toBe(0);
  });

  it('keeps a file a row names, live or in the trash, and one sent or asked about lately', async () => {
    const account = await signUp(h);
    const at = new Date().toISOString();
    const memory = (uuid: string, hash: string, deletedAt: string | null) => ({
      table: 'memories',
      uuid,
      updatedAt: at,
      deletedAt,
      data: {
        uuid, albumUuid: 'album', harvestDay: at.slice(0, 10), path: `${uuid}.jpg`, kind: 'photo',
        note: null, fileHash: hash, capturedAt: at, updatedAt: at, deletedAt,
      },
    });
    const live = randomBytes(64);
    const trashed = randomBytes(64);
    const recent = randomBytes(64);
    for (const bytes of [live, trashed, recent]) await upload(account, nameOf(bytes), bytes).expect(201);
    await request(h.app)
      .post('/v1/sync/push')
      .set(bearer(account))
      .send({ deviceId: 'phone', records: [memory('m1', nameOf(live), null), memory('m2', nameOf(trashed), at)] })
      .expect(200);
    await age(account, nameOf(live));
    await age(account, nameOf(trashed));

    const del = (bytes: Buffer) => request(h.app).delete(`/v1/files/${nameOf(bytes)}`).set(bearer(account));
    for (const bytes of [live, trashed, recent]) {
      const res = await del(bytes);
      expectError(res, 409, 'conflict');
    }
    expect(await counterOf(account)).toBe(192);

    // A "missing?" answer that said the server has it starts the grace again.
    const asked = randomBytes(64);
    await upload(account, nameOf(asked), asked).expect(201);
    await age(account, nameOf(asked));
    await request(h.app).post('/v1/files/missing').set(bearer(account)).send({ hashes: [nameOf(asked)] }).expect(200);
    expectError(await del(asked), 409, 'conflict');
  });

  it('lets only the owner delete', async () => {
    const mine = await signUp(h);
    const theirs = await signUp(h);
    const bytes = randomBytes(64);
    await upload(mine, nameOf(bytes), bytes).expect(201);
    await request(h.app).delete(`/v1/files/${nameOf(bytes)}`).set(bearer(theirs)).expect(204);
    await request(h.app).get(`/v1/files/${nameOf(bytes)}`).set(bearer(mine)).expect(200);
  });

  it('sweeps the files no row names, and only once they have been unnamed a while', async () => {
    let clock = Date.now();
    const now = () => new Date(clock);
    const timed = await harness({ now });
    try {
      const account = await signUp(timed);
      const put = (bytes: Buffer) =>
        request(timed.app)
          .put(`/v1/files/${nameOf(bytes)}`)
          .set(bearer(account))
          .set('Content-Type', 'application/octet-stream')
          .set(fileIvHeader, iv)
          .set(filePlainBytesHeader, String(bytes.length))
          .set(fileKeyEpochHeader, '1')
          .send(bytes)
          .expect(201);
      const memory = (uuid: string, hash: string, fields: { deletedAt?: string | null } = {}) => {
        const at = new Date(clock).toISOString();
        return {
          table: 'memories',
          uuid,
          updatedAt: at,
          deletedAt: fields.deletedAt ?? null,
          data: {
            uuid,
            albumUuid: 'album',
            harvestDay: at.slice(0, 10),
            path: `${uuid}.jpg`,
            kind: 'photo',
            note: null,
            fileHash: hash,
            capturedAt: at,
            updatedAt: at,
            deletedAt: fields.deletedAt ?? null,
          },
        };
      };
      const pushRows = (records: unknown[]) =>
        request(timed.app).post('/v1/sync/push').set(bearer(account)).send({ deviceId: 'phone', records }).expect(200);

      const kept = randomBytes(100);
      const trashed = randomBytes(100);
      const purged = randomBytes(100);
      const unnamed = randomBytes(100);
      for (const bytes of [kept, trashed, purged, unnamed]) await put(bytes);
      const deletedAt = new Date(clock).toISOString();
      await pushRows([
        memory('m-kept', nameOf(kept)),
        memory('m-trashed', nameOf(trashed), { deletedAt }),
        memory('m-purged', nameOf(purged)),
      ]);
      clock += 1000;
      await pushRows([
        { table: 'memories', uuid: 'm-purged', updatedAt: new Date(clock).toISOString(), deletedAt, purged: true },
      ]);

      const sweeper = new FileSweeper(timed.repos, new KeyedMutex(), now);
      const userId = new ObjectId(account.userId);
      // Too soon: a device may be about to name them.
      expect(await sweeper.sweep(userId)).toBe(0);

      clock += unnamedFileGraceMs + 60_000;
      // One claimed just now by a "missing?" stays for another while.
      expect(await timed.repos.files.missing(userId, [nameOf(unnamed)], now())).toEqual([]);
      expect(await sweeper.sweep(userId)).toBe(1);
      expect((await timed.repos.files.get(userId, nameOf(purged))) === null).toBe(true);
      for (const bytes of [kept, trashed, unnamed]) {
        expect(await timed.repos.files.get(userId, nameOf(bytes))).not.toBeNull();
      }
      expect((await timed.db.collection('counters').findOne({ _id: userId }))!.fileBytes).toBe(300);

      clock += unnamedFileGraceMs + 60_000;
      expect(await sweeper.sweepAll()).toBe(1);
      expect(await timed.repos.files.get(userId, nameOf(unnamed))).toBeNull();
    } finally {
      await timed.close();
    }
  });

  it('limits file requests per account', async () => {
    const limited = await harness({ rateLimits: { fileRequests: 1 } });
    try {
      const account = await signUp(limited);
      const ask = () => request(limited.app).post('/v1/files/missing').set(bearer(account)).send({ hashes: [] });
      await ask().expect(200);
      expectError(await ask(), 429, 'rate_limited');
    } finally {
      await limited.close();
    }
  });

  it('lets a browser on another origin upload, if the server lists it', async () => {
    const preflight = await request(h.app)
      .options('/v1/files/abc')
      .set('Origin', appOrigin)
      .set('Access-Control-Request-Method', 'PUT')
      .set('Access-Control-Request-Headers', `authorization,content-type,${fileIvHeader},${filePlainBytesHeader}`);
    expect(preflight.status).toBe(204);
    expect(preflight.headers['access-control-allow-methods']).toContain('PUT');
    expect(preflight.headers['access-control-allow-headers']).toContain(fileIvHeader);
    expect(preflight.headers['access-control-allow-headers']).toContain(filePlainBytesHeader);
  });
});

describe('big files (Q6-01, P6-05)', () => {
  it('takes a file of nearly 25 MB and hands the same bytes back, in chunks', async () => {
    const account = await signUp(h);
    const sealed = randomBytes(Math.floor(24.9 * 1024 * 1024));
    const sha256 = nameOf(sealed);
    await upload(account, sha256, sealed, sealed.length - 16).expect(201);
    const got = await request(h.app)
      .get(`/v1/files/${sha256}`)
      .set(bearer(account))
      .buffer(true)
      .parse((res, done) => {
        const parts: Buffer[] = [];
        res.on('data', (part: Buffer) => parts.push(part));
        res.on('end', () => done(null, Buffer.concat(parts)));
      })
      .expect(200);
    expect(got.headers['content-length']).toBe(String(sealed.length));
    expect(got.headers['cache-control']).toBe('no-store');
    expect((got.body as Buffer).equals(sealed)).toBe(true);
    // In GridFS, not in one document of the files collection.
    const doc = await h.db.collection('files').findOne({ sha256 });
    expect(doc!.blob).toBeUndefined();
    expect(await h.db.collection('file_blobs.chunks').countDocuments({ files_id: doc!.gridId })).toBeGreaterThan(1);
    const counted = (await h.db.collection('counters').findOne({ _id: new ObjectId(account.userId) }))!.fileBytes as number;
    expect(counted).toBe(sealed.length);
  });

  it('still hands back a file stored before GridFS', async () => {
    const account = await signUp(h);
    const bytes = randomBytes(1000);
    await h.db.collection('files').insertOne({
      userId: new ObjectId(account.userId),
      sha256: nameOf(bytes),
      bytes: bytes.length,
      iv,
      plainBytes: 984,
      blob: new Binary(bytes),
      uploadedAt: new Date(),
    });
    const got = await request(h.app).get(`/v1/files/${nameOf(bytes)}`).set(bearer(account)).expect(200);
    expect(Buffer.from(got.body as Buffer).equals(bytes)).toBe(true);
  });

  it('writes nothing for an account deleted while the bytes were on their way (Q6-02)', async () => {
    const account = await signUp(h);
    const bytes = randomBytes(200_000);
    const server = h.app.listen(0);
    try {
      const port = (server.address() as { port: number }).port;
      const status = await new Promise<number>((resolve, reject) => {
        const req = httpRequest(
          {
            port,
            method: 'PUT',
            path: `/v1/files/${nameOf(bytes)}`,
            headers: {
              authorization: `Bearer ${account.accessToken}`,
              'content-type': 'application/octet-stream',
              'content-length': bytes.length,
              [fileIvHeader]: iv,
              [filePlainBytesHeader]: String(bytes.length - 16),
              [fileKeyEpochHeader]: '1',
            },
          },
          (res) => {
            res.resume();
            res.on('end', () => resolve(res.statusCode ?? 0));
          },
        );
        req.on('error', reject);
        req.write(bytes.subarray(0, 1000));
        setTimeout(() => {
          void request(h.app)
            .delete('/v1/me')
            .set(bearer(account))
            .send({ password })
            .then(() => req.end(bytes.subarray(1000)));
        }, 100);
      });
      expect(status).toBe(401);
      expect(await h.db.collection('files').countDocuments({})).toBe(0);
      expect(await h.db.collection('file_blobs.files').countDocuments({})).toBe(0);
    } finally {
      server.close();
    }
  });
});
