import { useEffect } from 'react';

/** Whether an element takes typing: a text field, a text area or an editable block. */
export function takesTyping(element: Element | null): boolean {
  if (!element) return false;
  if (element instanceof HTMLTextAreaElement) return !element.readOnly;
  if (element instanceof HTMLInputElement) {
    return !element.readOnly && !['button', 'checkbox', 'color', 'file', 'hidden', 'image', 'radio', 'range', 'reset', 'submit'].includes(element.type);
  }
  return element instanceof HTMLElement && element.isContentEditable === true;
}

/**
 * Whether the on-screen keyboard is up: something that takes typing has
 * the focus and the visual viewport has lost a good part of the window
 * to something below it.
 */
export function keyboardUp(viewportHeight: number, windowHeight: number, focused: Element | null): boolean {
  return takesTyping(focused) && windowHeight - viewportHeight > Math.min(150, windowHeight * 0.2);
}

/**
 * Marks the page with `data-keyboard` while the on-screen keyboard is
 * up, so the bottom bar and the floating action step out of its way, as
 * the phone's do ([[Web]]).
 */
export function useKeyboardMark(): void {
  useEffect(() => {
    const viewport = window.visualViewport;
    if (!viewport) return;
    const root = document.documentElement;
    const update = () => {
      if (keyboardUp(viewport.height, window.innerHeight, document.activeElement)) root.dataset.keyboard = '';
      else delete root.dataset.keyboard;
    };
    viewport.addEventListener('resize', update);
    document.addEventListener('focusin', update);
    document.addEventListener('focusout', update);
    return () => {
      viewport.removeEventListener('resize', update);
      document.removeEventListener('focusin', update);
      document.removeEventListener('focusout', update);
      delete root.dataset.keyboard;
    };
  }, []);
}
