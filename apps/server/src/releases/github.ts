import type { PublishedRelease, Release } from '@harvest/contracts';
import { z } from 'zod';
import { HttpError } from '../http/errors.js';

/** The part of GitHub's release object the download page needs. */
const githubReleaseSchema = z.object({
  tag_name: z.string(),
  name: z.string().nullable().optional(),
  published_at: z.string().nullable().optional(),
  html_url: z.string(),
  body: z.string().nullable().optional(),
  draft: z.boolean().default(false),
  prerelease: z.boolean().default(false),
  assets: z
    .array(
      z.object({
        name: z.string(),
        browser_download_url: z.string(),
        size: z.number(),
        // "sha256:<hex>", on assets uploaded since GitHub began hashing them.
        digest: z.string().nullable().optional(),
      }),
    )
    .default([]),
});

type GitHubRelease = z.infer<typeof githubReleaseSchema>;

export type Fetch = typeof fetch;

/** The hex digest out of GitHub's `sha256:<hex>`; anything else is no digest. */
function sha256Of(digest: string | null | undefined): string | null {
  const match = /^sha256:([0-9a-f]{64})$/i.exec(digest ?? '');
  return match ? match[1]!.toLowerCase() : null;
}

export interface ReleaseSourceOptions {
  repo: string;
  token?: string | undefined;
  fetch?: Fetch;
  ttlMs?: number;
  now?: () => number;
}

function published(release: GitHubRelease): PublishedRelease {
  const apk = release.assets.find((asset) => asset.name.toLowerCase().endsWith('.apk'));
  return {
    tag: release.tag_name,
    name: release.name ?? null,
    publishedAt: release.published_at ?? null,
    htmlUrl: release.html_url,
    notes: release.body?.trim() || null,
    apk: apk ? { name: apk.name, url: apk.browser_download_url, size: apk.size, sha256: sha256Of(apk.digest) } : null,
  };
}

/**
 * The newest APK, for the web's download page ([[Web]]), proxied from
 * GitHub's release list and cached for an hour: the newest release that
 * is not a pre-release (GitHub's "latest"), and the newest pre-release
 * when one came after it. One request answers both. The cache is what
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
      response = await this.fetch(`https://api.github.com/repos/${this.options.repo}/releases?per_page=20`, {
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

    const parsed = z.array(githubReleaseSchema).safeParse(await response.json().catch(() => null));
    if (!parsed.success) return this.stale();

    // Newest first, as GitHub lists them; drafts are not releases yet.
    const out = parsed.data.filter((release) => !release.draft);
    const stable = out.findIndex((release) => !release.prerelease);
    if (stable === -1) throw new HttpError('not_found', 'There is no release yet');
    const beta = out.slice(0, stable).find((release) => release.prerelease);
    const release: Release = { ...published(out[stable]!), prerelease: beta ? published(beta) : null };
    this.cached = { release, at: this.now() };
    return release;
  }

  private stale(): Release {
    if (this.cached) return this.cached.release;
    throw new HttpError('unavailable', 'The release list is unavailable right now');
  }
}
