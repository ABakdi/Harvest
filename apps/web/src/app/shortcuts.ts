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

/** The printable keys a code stands for on a US layout, unshifted and shifted. */
const codeKeys: Record<string, [string, string]> = {
  Slash: ['/', '?'],
  Period: ['.', '>'],
  Comma: [',', '<'],
  Semicolon: [';', ':'],
  Quote: ["'", '"'],
  BracketLeft: ['[', '{'],
  BracketRight: [']', '}'],
  Minus: ['-', '_'],
  Equal: ['=', '+'],
  Backquote: ['`', '~'],
};

/**
 * The key a shortcut is named by. A Latin key is itself; any other
 * printable key (an Arabic layout's letters, say) is read from its
 * place on the keyboard, so N is N whatever layout is active
 * ([[Audit-v3]] Q5-37).
 */
export function shortcutKey(event: Pick<KeyboardEvent, 'key' | 'code' | 'shiftKey'>): string {
  if (event.key.length !== 1) return event.key;
  if (/^[\x20-\x7e]$/.test(event.key)) return event.key.toLowerCase();
  const letter = /^Key([A-Z])$/.exec(event.code);
  if (letter) return letter[1]!.toLowerCase();
  const digit = /^Digit([0-9])$/.exec(event.code);
  if (digit) return digit[1]!;
  const mark = codeKeys[event.code];
  if (mark) return event.shiftKey ? mark[1] : mark[0];
  return event.key.toLowerCase();
}

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
      const key = shortcutKey(event);
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
