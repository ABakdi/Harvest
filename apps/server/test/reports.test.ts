import { adminReportsSchema } from '@harvest/contracts';
import request from 'supertest';
import { afterEach, describe, expect, it } from 'vitest';
import { bearer, expectError, harness, signUp, type Account, type Harness } from './harness.js';

const admin = 'boss@example.com';
let h: Harness;
afterEach(async () => {
  await h?.close();
});

// The smallest files that start as they should.
const jpeg = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(200, 7)]);
const m4a = Buffer.concat([Buffer.from([0, 0, 0, 0x20]), Buffer.from('ftypM4A '), Buffer.alloc(300, 3)]);
const page = Buffer.from('<html><script>alert(1)</script></html>');

const report = (extra: object = {}) => ({
  text: 'The keyboard hides the button\nwhen I change my PIN.',
  platform: 'android',
  appVersion: '3.3.0',
  ...extra,
});

async function setUp(limits: { reports?: number } = {}) {
  h = await harness({ env: { ADMIN_EMAILS: admin }, rateLimits: limits });
  return signUp(h, { email: admin });
}

const send = (body: object, headers: Record<string, string> = {}) => request(h.app).post('/v1/reports').set(headers).send(body);
const list = (boss: Account, query = '') => request(h.app).get(`/v1/admin/reports${query}`).set(bearer(boss));

describe('reporting a problem (Admin F12-5)', () => {
  it('takes text, pictures and a recording, from anyone, and keeps no one', async () => {
    const boss = await setUp();
    const someone = await signUp(h);
    const res = await send(
      report({
        attachments: [
          { kind: 'image', type: 'image/jpeg', data: jpeg.toString('base64') },
          { kind: 'audio', type: 'audio/mp4', data: m4a.toString('base64') },
        ],
      }),
      // Signed in or not, the report is not tied to the account.
      bearer(someone),
    ).expect(201);
    expect((res.body as { id: string }).id).toMatch(/^[0-9a-f]{24}$/);

    const stored = await h.db.collection('reports').findOne({});
    const text = JSON.stringify(stored);
    expect(text).not.toContain(someone.userId);
    expect(text).not.toContain(someone.email);
    expect(text).not.toMatch(/"(ip|userId|address|sessionId)"/);

    const reports = adminReportsSchema.parse((await list(boss).expect(200)).body);
    expect(reports.unread).toBe(1);
    expect(reports.reports[0]).toMatchObject({
      text: 'The keyboard hides the button\nwhen I change my PIN.',
      platform: 'android',
      appVersion: '3.3.0',
      status: 'new',
      attachments: [
        { kind: 'image', type: 'image/jpeg', bytes: jpeg.length },
        { kind: 'audio', type: 'audio/mp4', bytes: m4a.length },
      ],
    });

    // The bytes back, as exactly what they were checked to be.
    const [picture] = reports.reports[0]!.attachments;
    const file = await request(h.app)
      .get(`/v1/admin/reports/${reports.reports[0]!.id}/attachments/${picture!.id}`)
      .set(bearer(boss))
      .buffer(true)
      .parse((response, done) => {
        const chunks: Buffer[] = [];
        response.on('data', (chunk: Buffer) => chunks.push(chunk));
        response.on('end', () => done(null, Buffer.concat(chunks)));
      })
      .expect(200);
    expect(file.headers['content-type']).toBe('image/jpeg');
    expect(file.headers['x-content-type-options']).toBe('nosniff');
    expect(file.headers['content-security-policy']).toContain('sandbox');
    expect(Buffer.compare(file.body as Buffer, jpeg)).toBe(0);
  });

  it('refuses a file that is not what it says, an empty report, and extra fields', async () => {
    await setUp();
    expectError(await send(report({ attachments: [{ kind: 'image', type: 'image/png', data: page.toString('base64') }] })), 400, 'validation_failed');
    expectError(await send(report({ text: '  ' })), 400, 'validation_failed');
    expectError(await send(report({ email: 'me@example.com' })), 400, 'validation_failed');
    expect(await h.db.collection('reports').countDocuments({})).toBe(0);
    expect(await h.db.collection('report_files.files').countDocuments({})).toBe(0);
  });

  it('takes five an hour from one network', async () => {
    await setUp({ reports: 2 });
    await send(report()).expect(201);
    await send(report()).expect(201);
    expectError(await send(report()), 429, 'rate_limited');
  });

  it('is read, marked and deleted by the admin alone, its files with it', async () => {
    const boss = await setUp();
    const someone = await signUp(h);
    await send(report({ attachments: [{ kind: 'image', type: 'image/jpeg', data: jpeg.toString('base64') }] })).expect(201);
    await send(report({ text: 'Second' })).expect(201);

    expectError(await list(someone), 404, 'not_found');
    const all = adminReportsSchema.parse((await list(boss, '?limit=1').expect(200)).body);
    expect(all.reports.map((r) => r.text)).toEqual(['Second']);
    expect(all.next).not.toBeNull();
    const older = adminReportsSchema.parse((await list(boss, `?limit=1&cursor=${all.next}`).expect(200)).body);
    const first = older.reports[0]!;

    await request(h.app).patch(`/v1/admin/reports/${first.id}`).set(bearer(boss)).send({ status: 'done' }).expect(200);
    const fresh = adminReportsSchema.parse((await list(boss, '?status=new').expect(200)).body);
    expect(fresh.reports.map((r) => r.text)).toEqual(['Second']);
    expect(fresh.unread).toBe(1);

    await request(h.app).delete(`/v1/admin/reports/${first.id}`).set(bearer(boss)).expect(204);
    expect(await h.db.collection('report_files.files').countDocuments({})).toBe(0);
    expectError(await request(h.app).delete(`/v1/admin/reports/${first.id}`).set(bearer(boss)), 404, 'not_found');
  });
});
