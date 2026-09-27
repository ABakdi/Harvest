import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { classifyLink, linkOf, plannedPurchases, videoHosts, type PlanItem, type PlanList } from '../src/index.js';

/** `fixtures/share-links.json`, which the phone's share sheet is held to as well. */
const data = JSON.parse(readFileSync(new URL('../fixtures/share-links.json', import.meta.url), 'utf8')) as {
  videoHosts: string[];
  linkOf: { text: string; link: string | null; why?: string }[];
  classify: { url: string; list: string; mediaType: string; why?: string }[];
};

describe('share-links.json', () => {
  it('names the same video sites', () => {
    expect([...videoHosts]).toEqual(data.videoHosts);
  });

  it.each(data.linkOf)('linkOf($text) is $link', ({ text, link }) => {
    expect(linkOf(text)).toBe(link);
  });

  it.each(data.classify)('$url lands in $list as $mediaType', ({ url, list, mediaType }) => {
    expect(classifyLink(url)).toEqual({ list, mediaType });
  });
});

/** `fixtures/lists.json`, which the phone's Granary line is held to as well. */
const plan = JSON.parse(readFileSync(new URL('../fixtures/lists.json', import.meta.url), 'utf8')) as {
  lists: PlanList[];
  plannedPurchases: { why: string; items: PlanItem[]; sums: Record<string, number> }[];
};

describe('lists.json', () => {
  it.each(plan.plannedPurchases)('plannedPurchases: $why', ({ items, sums }) => {
    expect(plannedPurchases(plan.lists, items)).toEqual(sums);
  });
});
