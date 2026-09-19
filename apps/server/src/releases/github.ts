import type { Release } from '@harvest/contracts';
import { z } from 'zod';
import { HttpError } from '../http/errors.js';

/** The part of GitHub's release object the download page needs. */
const githubReleaseSchema = z.object({
  tag_name: z.string(),
  name: z.string().nullable().optional(),
  published_at: z.string().nullable().optional(),
  html_url: z.string(),
  assets: z
    .array(
      z.object({
        name: z.string(),
        browser_download_url: z.string(),
        size: z.number(),
      }),
    )
    .default([]),
});

export type Fetch = typeof fetch;

export interface ReleaseSourceOptions {
  repo: string;
  token?: string | undefined;
  fetch?: Fetch;
  ttlMs?: number;
  now?: () => number;
}

/**
 * The newest APK, for the web's download page ([[Web]]), proxied from
 * GitHub's "latest release" and cached for an hour. The cache is what
 * keeps the page inside GitHub's anonymous rate limit (60 an hour per
 * address), and it is also what the page falls back on when GitHub is
 * down: an hour-old answer beats an error.
 */
export class ReleaseSource {
  private cached: { release: Release; at: number } | null = null;
  private inflight: Promise<Release> | null = null;
  private readonly fetch: Fetch;
  private readonly ttlMs: number;
  private readonly now: () => number;

  constructor(private readonly options: ReleaseSourceOptions) {
    this.fetch = options.fetch ?? globalThis.fetch;
    this.ttlMs = options.ttlMs ?? 60 * 60_000;
    this.now = options.now ?? Date.now;
  }

  async latest(): Promise<Release> {
    if (this.cached && this.now() - this.cached.at < this.ttlMs) return this.cached.release;
    // Concurrent misses share one request to GitHub.
    this.inflight ??= this.load().finally(() => {
      this.inflight = null;
    });
    return this.inflight;
  }

  private async load(): Promise<Release> {
    let response: Response;
    try {
      response = await this.fetch(`https://api.github.com/repos/${this.options.repo}/releases/latest`, {
        headers: {
          accept: 'application/vnd.github+json',
          'user-agent': 'harvest-server',
          'x-github-api-version': '2022-11-28',
          ...(this.options.token ? { authorization: `Bearer ${this.options.token}` } : {}),
        },
        signal: AbortSignal.timeout(10_000),
      });
    } catch {
      return this.stale();
    }
    if (response.status === 404) throw new HttpError('not_found', 'There is no release yet');
    if (!response.ok) return this.stale();

    const parsed = githubReleaseSchema.safeParse(await response.json().catch(() => null));
    if (!parsed.success) return this.stale();

    const apk = parsed.data.assets.find((asset) => asset.name.toLowerCase().endsWith('.apk'));
    const release: Release = {
      tag: parsed.data.tag_name,
      name: parsed.data.name ?? null,
      publishedAt: parsed.data.published_at ?? null,
      htmlUrl: parsed.data.html_url,
      apk: apk ? { name: apk.name, url: apk.browser_download_url, size: apk.size } : null,
    };
    this.cached = { release, at: this.now() };
    return release;
  }

  private stale(): Release {
    if (this.cached) return this.cached.release;
    throw new HttpError('unavailable', 'The release list is unavailable right now');
  }
}
