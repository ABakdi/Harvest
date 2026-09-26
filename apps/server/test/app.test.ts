import type { Release } from '@harvest/contracts';
import request from 'supertest';
import { afterEach, describe, expect, it } from 'vitest';
import { loadConfig } from '../src/config.js';
import { ReleaseSource, type Fetch } from '../src/releases/github.js';
import { appOrigin, expectError, harness, type Harness } from './harness.js';

let h: Harness | undefined;
afterEach(async () => {
  await h?.close();
  h = undefined;
});

describe('the app', () => {
  it('answers health', async () => {
    h = await harness();
    const res = await request(h.app).get('/v1/health').expect(200);
    expect(res.body).toEqual({ status: 'ok' });
  });

  it('answers an unknown route with the envelope', async () => {
    h = await harness();
    expectError(await request(h.app).get('/v1/nope'), 404, 'not_found');
    expectError(await request(h.app).get('/'), 404, 'not_found');
  });

  it('answers malformed JSON with 400 and an oversized body with 413', async () => {
    h = await harness({ env: { BODY_LIMIT: '1kb' } });
    expectError(
      await request(h.app).post('/v1/auth/login').set('Content-Type', 'application/json').send('{"email":'),
      400,
      'validation_failed',
    );
    expectError(
      await request(h.app).post('/v1/auth/login').send({ email: 'a@b.co', password: 'x'.repeat(2000) }),
      413,
      'payload_too_large',
    );
  });

  it('allows only the listed origins, with credentials', async () => {
    h = await harness();
    const allowed = await request(h.app).get('/v1/health').set('Origin', appOrigin);
    expect(allowed.headers['access-control-allow-origin']).toBe(appOrigin);
    expect(allowed.headers['access-control-allow-credentials']).toBe('true');

    const preflight = await request(h.app)
      .options('/v1/sync/push')
      .set('Origin', appOrigin)
      .set('Access-Control-Request-Method', 'POST')
      .set('Access-Control-Request-Headers', 'authorization,content-type');
    expect(preflight.status).toBe(204);
    expect(preflight.headers['access-control-allow-headers']).toMatch(/authorization/i);

    const denied = await request(h.app).get('/v1/health').set('Origin', 'https://evil.example');
    expect(denied.headers['access-control-allow-origin']).toBeUndefined();
  });

  it('sends the hardening headers and no framework banner', async () => {
    h = await harness();
    const res = await request(h.app).get('/v1/health');
    expect(res.headers['x-content-type-options']).toBe('nosniff');
    expect(res.headers['strict-transport-security']).toBeDefined();
    expect(res.headers['x-powered-by']).toBeUndefined();
  });
});

describe('config', () => {
  it('reads a variable set to nothing as not set, as a blank line in .env means', async () => {
    const config = await loadConfig({ NODE_ENV: 'development', ASSIST_API_KEY: '', SMTP_HOST: ' ', GITHUB_TOKEN: '' });
    expect(config.assist.apiKey).toBeNull();
    expect(config.smtp).toBeNull();
  });

  it('makes a key pair outside production, and refuses to start production without one', async () => {
    const dev = await loadConfig({ NODE_ENV: 'development' });
    expect(dev.jwt.privateKey).toBeDefined();
    expect(dev.cookieSecure).toBe(false);
    expect(dev.githubRepo).toBe('ABakdi/Harvest');
    await expect(loadConfig({ NODE_ENV: 'production', MONGO_URL: 'mongodb://db/harvest' })).rejects.toThrow(/JWT/);
  });

  it('reads PEM keys, lists and flags', async () => {
    const { generateKeyPairSync } = await import('node:crypto');
    const { privateKey, publicKey } = generateKeyPairSync('ed25519');
    const config = await loadConfig({
      NODE_ENV: 'production',
      MONGO_URL: 'mongodb://db/harvest',
      JWT_PRIVATE_KEY: privateKey.export({ type: 'pkcs8', format: 'pem' }).toString().replace(/\n/g, '\\n'),
      JWT_PUBLIC_KEY: publicKey.export({ type: 'spki', format: 'pem' }).toString(),
      SMTP_HOST: 'smtp.example',
      CORS_ORIGINS: 'https://a.example, https://b.example',
      APP_URL: 'https://harvest.example/',
    });
    expect(config.corsOrigins).toEqual(['https://a.example', 'https://b.example']);
    expect(config.cookieSecure).toBe(true);
    expect(config.appUrl).toBe('https://harvest.example');
    expect(config.smtp).toMatchObject({ host: 'smtp.example', port: 587 });
  });

  it('names what is wrong', async () => {
    await expect(loadConfig({ PORT: 'eighty' })).rejects.toThrow(/PORT/);
  });
});

describe('the latest release', () => {
  const github = {
    tag_name: 'v2.0.0',
    name: 'Harvest 2.0.0',
    published_at: '2026-09-15T12:00:00Z',
    html_url: 'https://github.com/ABakdi/Harvest/releases/tag/v2.0.0',
    body: 'Phase 4, closed.\n',
    assets: [
      { name: 'checksums.txt', browser_download_url: 'https://example/checksums.txt', size: 120 },
      {
        name: 'harvest-2.0.0.apk',
        browser_download_url: 'https://example/harvest-2.0.0.apk',
        size: 48_000_000,
        digest: `sha256:${'AB'.repeat(32)}`,
      },
    ],
  };

  function fakeGitHub(responses: (() => Response | Promise<Response>)[]) {
    const calls: string[] = [];
    const fetch: Fetch = (input) => {
      calls.push(input instanceof Request ? input.url : input.toString());
      const next = responses.shift();
      if (!next) throw new Error('unexpected fetch');
      return Promise.resolve(next());
    };
    return { fetch, calls };
  }

  const ok = () => Response.json([github]);

  it('answers with the APK, and asks GitHub once an hour', async () => {
    const gh = fakeGitHub([ok]);
    h = await harness({ fetch: gh.fetch });
    const res = await request(h.app).get('/v1/releases/latest').expect(200);
    expect(res.body as Release).toEqual({
      tag: 'v2.0.0',
      name: 'Harvest 2.0.0',
      publishedAt: '2026-09-15T12:00:00Z',
      htmlUrl: 'https://github.com/ABakdi/Harvest/releases/tag/v2.0.0',
      notes: 'Phase 4, closed.',
      apk: {
        name: 'harvest-2.0.0.apk',
        url: 'https://example/harvest-2.0.0.apk',
        size: 48_000_000,
        sha256: 'ab'.repeat(32),
      },
      prerelease: null,
    });
    await request(h.app).get('/v1/releases/latest').expect(200);
    expect(gh.calls).toEqual(['https://api.github.com/repos/ABakdi/Harvest/releases?per_page=20']);
  });

  it('names the newest beta beside the latest release, and never a draft or an older beta', async () => {
    const release = (tag: string, flags: { prerelease?: boolean; draft?: boolean } = {}) => ({
      ...github,
      tag_name: tag,
      name: `Harvest ${tag}`,
      html_url: `https://github.com/ABakdi/Harvest/releases/tag/${tag}`,
      assets: [{ name: `harvest-${tag}.apk`, browser_download_url: `https://example/harvest-${tag}.apk`, size: 1 }],
      ...flags,
    });
    const list = [
      release('v3.0.0-beta.3', { draft: true, prerelease: true }),
      release('v3.0.0-beta.2', { prerelease: true }),
      release('v3.0.0-beta.1', { prerelease: true }),
      release('v2.0.0'),
      release('v2.0.0-beta.4', { prerelease: true }),
    ];
    const source = new ReleaseSource({ repo: 'ABakdi/Harvest', fetch: fakeGitHub([() => Response.json(list)]).fetch });
    const latest = await source.latest();
    expect(latest.tag).toBe('v2.0.0');
    expect(latest.prerelease?.tag).toBe('v3.0.0-beta.2');
    expect(latest.prerelease?.apk?.url).toBe('https://example/harvest-v3.0.0-beta.2.apk');

    const none = new ReleaseSource({ repo: 'ABakdi/Harvest', fetch: fakeGitHub([() => Response.json([release('v2.0.0'), release('v2.0.0-beta.4', { prerelease: true })])]).fetch });
    expect((await none.latest()).prerelease).toBeNull();

    const onlyBetas = new ReleaseSource({ repo: 'ABakdi/Harvest', fetch: fakeGitHub([() => Response.json([release('v1.0.0-beta.1', { prerelease: true })])]).fetch });
    await expect(onlyBetas.latest()).rejects.toMatchObject({ code: 'not_found' });
  });

  it('asks again after the hour, and serves the old answer if GitHub is down', async () => {
    let now = 0;
    const gh = fakeGitHub([ok, () => new Response('down', { status: 502 }), () => Promise.reject(new Error('offline'))]);
    const source = new ReleaseSource({ repo: 'ABakdi/Harvest', fetch: gh.fetch, now: () => now });
    expect((await source.latest()).tag).toBe('v2.0.0');
    now += 61 * 60_000;
    expect((await source.latest()).tag).toBe('v2.0.0');
    now += 61 * 60_000;
    expect((await source.latest()).tag).toBe('v2.0.0');
    expect(gh.calls).toHaveLength(3);
  });

  it('says so when there is no release, or no answer at all', async () => {
    h = await harness({ fetch: fakeGitHub([() => new Response('{}', { status: 404 })]).fetch });
    expectError(await request(h.app).get('/v1/releases/latest'), 404, 'not_found');
    await h.close();

    h = await harness({ fetch: fakeGitHub([() => Promise.reject(new Error('offline'))]).fetch });
    expectError(await request(h.app).get('/v1/releases/latest'), 503, 'unavailable');
  });

  it('shares one request among concurrent misses', async () => {
    const gh = fakeGitHub([ok]);
    const source = new ReleaseSource({ repo: 'ABakdi/Harvest', fetch: gh.fetch });
    await Promise.all([source.latest(), source.latest(), source.latest()]);
    expect(gh.calls).toHaveLength(1);
  });
});
