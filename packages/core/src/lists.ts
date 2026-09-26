/**
 * Where a shared or pasted link lands ([[Lists]]: Saving from
 * anywhere). The phone reads the same rules from its share sheet and
 * the web from a list's add field; both are held to
 * `fixtures/share-links.json`.
 *
 * Only the host decides, and nothing is fetched (L9): a video site goes
 * to *To watch* as a video, anything else to *To read* as an article.
 */

/** The sites a link to which is a video. A subdomain counts; a host that merely ends in the name does not. */
export const videoHosts: readonly string[] = ['youtube.com', 'youtu.be', 'vimeo.com', 'dailymotion.com', 'dai.ly', 'twitch.tv', 'tiktok.com'];

export interface SharedLink {
  /** The built-in list it lands in. */
  readonly list: 'read' | 'watch';
  readonly mediaType: 'video' | 'article';
}

/** The link, when [text] is one bare http(s) URL and nothing else; otherwise null. */
export function linkOf(text: string): string | null {
  const trimmed = text.trim();
  if (!/^https?:\/\/\S+$/i.test(trimmed)) return null;
  return hostOf(trimmed) ? trimmed : null;
}

/** The host of an http(s) URL, lower-cased, without a user or a port; empty when there is none. */
function hostOf(url: string): string {
  const match = /^https?:\/\/([^/?#]*)/i.exec(url.trim());
  if (!match) return '';
  const authority = match[1]!.slice(match[1]!.lastIndexOf('@') + 1);
  return authority.replace(/:\d*$/, '').toLowerCase();
}

/** The list and type a link gets from its host alone. */
export function classifyLink(url: string): SharedLink {
  const host = hostOf(url);
  const video = videoHosts.some((site) => host === site || host.endsWith(`.${site}`));
  return video ? { list: 'watch', mediaType: 'video' } : { list: 'read', mediaType: 'article' };
}
