/**
 * Where focus goes when a dialog closes and the element it came from is
 * gone, or was never there (a dialog opened from the keyboard, with
 * nothing focused): the page's main region, so the next Tab starts from
 * the content rather than the top of the document.
 */
export function settleFocus(): void {
  setTimeout(() => {
    const current = document.activeElement;
    if (current && current !== document.body && current.isConnected) return;
    document.querySelector<HTMLElement>('main')?.focus({ preventScroll: true });
  }, 0);
}
