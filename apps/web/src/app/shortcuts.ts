import { useEffect, useRef } from 'react';

/** Whether a key press belongs to whatever is focused rather than to the app. */
export function isTyping(target: EventTarget | null): boolean {
  if (!(target instanceof HTMLElement)) return false;
  if (target.isContentEditable) return true;
  const tag = target.tagName;
  if (tag === 'TEXTAREA' || tag === 'SELECT') return true;
  if (tag === 'INPUT') {
    const type = (target as HTMLInputElement).type;
    return !['checkbox', 'radio', 'button', 'submit', 'reset'].includes(type);
  }
  return false;
}

function dialogOpen(): boolean {
  return document.querySelector('[role="dialog"], [role="alertdialog"]') !== null;
}

export type ShortcutMap = Record<string, () => void>;

/**
 * The keyboard map of [[Web]]: single keys (`n`, `e`, `/`) and two-key
 * sequences starting with `g` (`g f`). Keys are ignored while typing,
 * with a modifier held, or while a dialog has the focus.
 */
export function useShortcuts(map: ShortcutMap): void {
  const latest = useRef(map);
  useEffect(() => {
    latest.current = map;
  });

  useEffect(() => {
    let pending: string | null = null;
    let timer: ReturnType<typeof setTimeout> | undefined;
    const onKey = (event: KeyboardEvent) => {
      if (event.defaultPrevented || event.ctrlKey || event.metaKey || event.altKey) return;
      if (isTyping(event.target) || dialogOpen()) return;
      const key = event.key.length === 1 ? event.key.toLowerCase() : event.key;
      const combo = pending ? `${pending} ${key}` : key;
      const action = latest.current[combo];
      if (action) {
        event.preventDefault();
        pending = null;
        clearTimeout(timer);
        action();
        return;
      }
      if (!pending && Object.keys(latest.current).some((name) => name.startsWith(`${key} `))) {
        pending = key;
        clearTimeout(timer);
        timer = setTimeout(() => {
          pending = null;
        }, 1200);
        return;
      }
      pending = null;
    };
    window.addEventListener('keydown', onKey);
    return () => {
      window.removeEventListener('keydown', onKey);
      clearTimeout(timer);
    };
  }, []);
}
