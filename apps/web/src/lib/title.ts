import { useEffect } from 'react';

const app = 'Harvest';
const active = new Map<symbol, { title: string; weight: number; at: number }>();
let tick = 0;

function apply() {
  let best: { title: string; weight: number; at: number } | null = null;
  for (const entry of active.values()) {
    if (!best || entry.weight > best.weight || (entry.weight === best.weight && entry.at > best.at)) best = entry;
  }
  document.title = best && best.title && best.title !== app ? `${best.title} · ${app}` : app;
}

/**
 * The tab's title, so tabs, history and screen readers can tell one
 * page from another (WCAG 2.4.2, W6-11). A screen's own title (a
 * note's, a seed's) outweighs the one the shell gives its route.
 */
export function useDocumentTitle(title: string | null | undefined, weight = 1): void {
  useEffect(() => {
    if (title === undefined) return;
    const id = Symbol('title');
    active.set(id, { title: title ?? '', weight, at: tick++ });
    apply();
    return () => {
      active.delete(id);
      apply();
    };
  }, [title, weight]);
}
