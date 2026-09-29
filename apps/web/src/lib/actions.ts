import { toast } from 'sonner';
import i18n from '@/i18n';

/**
 * What a failed action says, in the person's words: a money rule by
 * name, a full browser store, or else that it did not save.
 */
export function describeFailure(error: unknown): string {
  const t = i18n.t.bind(i18n);
  if (error && typeof error === 'object') {
    // Matched by name, so the rules' home need not be imported here; a
    // DOMException (a full store) is not always an Error.
    const { name, message, rule } = error as { name?: unknown; message?: unknown; rule?: unknown };
    if (name === 'MoneyRuleError' && typeof rule === 'string') return t(`vault.refused.${rule}`);
    if (name === 'QuotaExceededError' || (typeof message === 'string' && /quota/i.test(message))) return t('actions.storageFull');
  }
  return t('common.saveFailed');
}

/** Whether a failure is one nobody needs telling about: a cancelled request. */
function isQuiet(error: unknown): boolean {
  return error instanceof DOMException && error.name === 'AbortError';
}

function report(error: unknown, message?: string) {
  if (isQuiet(error)) return;
  console.error(error);
  toast.error(message ?? describeFailure(error), { id: `failed:${message ?? describeFailure(error)}` });
}

/**
 * Runs something the person asked for — a tap, a save, a menu item —
 * and says so when it fails, rather than leaving the tap to do nothing
 * ([[Web]] Q6-10). [then] follows a success; [failure] names the
 * failure when the general words are not right.
 */
export function runAction<T>(
  work: () => T | PromiseLike<T>,
  { then, failure }: { then?: (value: Awaited<T>) => void; failure?: string } = {},
): void {
  try {
    Promise.resolve(work()).then(
      (value) => then?.(value),
      (error: unknown) => report(error, failure),
    );
  } catch (error) {
    report(error, failure);
  }
}

/**
 * Starts work nobody is waiting on — a sync kick, a navigation, a
 * store asked to persist — and keeps its failure in the console rather
 * than letting it float away unseen.
 */
export function background(work: unknown): void {
  if (work && typeof (work as PromiseLike<unknown>).then === 'function') {
    (work as PromiseLike<unknown>).then(undefined, (error: unknown) => {
      if (!isQuiet(error)) console.error(error);
    });
  }
}

let listening = false;

/**
 * The last resort: a promise that failed with nobody listening is said
 * once, in words, instead of vanishing.
 */
export function listenForFailures(): void {
  if (listening || typeof window === 'undefined') return;
  listening = true;
  window.addEventListener('unhandledrejection', (event) => {
    if (isQuiet(event.reason)) return;
    toast.error(i18n.t('common.somethingWrong'), { id: 'unhandled-rejection' });
  });
}
