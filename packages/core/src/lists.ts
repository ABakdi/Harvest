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

/** A list, as far as *Planned purchases* needs one. */
export interface PlanList {
  readonly uuid: string;
  readonly kind: string;
  /** Which built-in list it is (`wish`, `buy`, …), null for one I made. */
  readonly builtIn: string | null;
}

/** An item, as far as *Planned purchases* needs one. */
export interface PlanItem {
  readonly listUuid: string;
  readonly priceMinor: number | null;
  readonly currency: string;
  /** Bought (or otherwise done). */
  readonly done: boolean;
}

/**
 * The Granary's *Planned purchases* line ([[Lists]] L3): per currency,
 * the open estimates of every live shopping list except the Wishlist,
 * because someday is not a purchase that is planned. [lists] are the
 * live lists; an item of a list not among them does not count. Pinned
 * by `fixtures/lists.json`, which the phone reads too.
 */
export function plannedPurchases(lists: readonly PlanList[], items: readonly PlanItem[]): Record<string, number> {
  const planned = new Set(
    lists.filter((list) => list.kind === 'shopping' && list.builtIn !== 'wish').map((l) => l.uuid),
  );
  const sums: Record<string, number> = {};
  for (const item of items) {
    if (item.done || item.priceMinor === null || !planned.has(item.listUuid)) continue;
    sums[item.currency] = (sums[item.currency] ?? 0) + item.priceMinor;
  }
  return sums;
}
