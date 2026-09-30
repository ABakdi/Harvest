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
        download_count: z.number().default(0),
        // "sha256:<hex>", on assets uploaded since GitHub began hashing them.
        digest: z.string().nullable().optional(),
      }),
    )
    .default([]),
});

type GitHubRelease = z.infer<typeof githubReleaseSchema>;

export type Fetch = typeof fetch;

/** APK downloads, all told and per release, newest first. */
export interface Downloads {
  total: number;
  releases: { tag: string; name: string; publishedAt: string; downloads: number }[];
}

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

/** The APK for older 32-bit phones, beside the 64-bit one: `harvest-3.3.1-armv7.apk`. */
const legacyApkName = /-armv7\.apk$/i;

function apkOf(asset: GitHubRelease['assets'][number] | undefined): PublishedRelease['apk'] {
  return asset ? { name: asset.name, url: asset.browser_download_url, size: asset.size, sha256: sha256Of(asset.digest) } : null;
}

/**
 * Since v3.3.1 a release carries one APK per kind of phone instead of one
 * for every kind (a 135 MB file, which phones struggled to finish): the
 * plain name is the 64-bit ARM one, `-armv7` the 32-bit one. An older
 * release's single APK is the plain one.
 */
function published(release: GitHubRelease): PublishedRelease {
  const apks = release.assets.filter((asset) => asset.name.toLowerCase().endsWith('.apk'));
  const apk = apks.find((asset) => !legacyApkName.test(asset.name));
  const legacy = apks.find((asset) => legacyApkName.test(asset.name));
  return {
    tag: release.tag_name,
    name: release.name ?? null,
    publishedAt: release.published_at ?? null,
    htmlUrl: release.html_url,
    notes: release.body?.trim() || null,
    apk: apkOf(apk),
    legacyApk: apkOf(legacy),
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

  private counted: { downloads: Downloads; at: number } | null = null;

  /**
   * How many times each release's APK was downloaded, by GitHub's own
   * count, newest release first ([[Admin]]: people without an account
   * are downloads, never users). Cached ten minutes; null when GitHub
   * cannot be asked and nothing was counted before.
   */
  async downloads(): Promise<Downloads | null> {
    if (this.counted && this.now() - this.counted.at < 10 * 60_000) return this.counted.downloads;
    try {
      const response = await this.fetch(`https://api.github.com/repos/${this.options.repo}/releases?per_page=100`, {
        headers: {
          accept: 'application/vnd.github+json',
          'user-agent': 'harvest-server',
          'x-github-api-version': '2022-11-28',
          ...(this.options.token ? { authorization: `Bearer ${this.options.token}` } : {}),
        },
        signal: AbortSignal.timeout(10_000),
      });
      if (!response.ok) return this.counted?.downloads ?? null;
      const parsed = z.array(githubReleaseSchema).safeParse(await response.json().catch(() => null));
      if (!parsed.success) return this.counted?.downloads ?? null;
      const releases = parsed.data
        .filter((release) => !release.draft)
        .map((release) => ({
          tag: release.tag_name,
          name: release.name ?? release.tag_name,
          publishedAt: release.published_at ?? new Date(0).toISOString(),
          downloads: release.assets
            .filter((asset) => asset.name.toLowerCase().endsWith('.apk'))
            .reduce((sum, asset) => sum + asset.download_count, 0),
        }));
      const downloads = { total: releases.reduce((sum, release) => sum + release.downloads, 0), releases };
      this.counted = { downloads, at: this.now() };
      return downloads;
    } catch {
      return this.counted?.downloads ?? null;
    }
  }

  private stale(): Release {
    if (this.cached) return this.cached.release;
    throw new HttpError('unavailable', 'The release list is unavailable right now');
  }
}
