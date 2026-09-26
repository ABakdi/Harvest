import { useSyncExternalStore } from 'react';

/**
 * The install button's state. `beforeinstallprompt` fires once, early,
 * and only on browsers that can install; it is caught at startup and
 * held until the button asks for it, whichever page that is on.
 */

interface BeforeInstallPromptEvent extends Event {
  prompt(): Promise<void>;
  readonly userChoice: Promise<{ outcome: 'accepted' | 'dismissed' }>;
}

let deferred: BeforeInstallPromptEvent | null = null;
let installed = false;
const listeners = new Set<() => void>();

function emit(): void {
  for (const listener of listeners) listener();
}

export function listenForInstallPrompt(): void {
  window.addEventListener('beforeinstallprompt', (event) => {
    // Keep the browser's own mini-infobar away; the page offers it.
    event.preventDefault();
    deferred = event as BeforeInstallPromptEvent;
    emit();
  });
  window.addEventListener('appinstalled', () => {
    deferred = null;
    installed = true;
    emit();
  });
}

export async function promptInstall(): Promise<boolean> {
  const event = deferred;
  if (!event) return false;
  await event.prompt();
  const choice = await event.userChoice;
  deferred = null;
  emit();
  return choice.outcome === 'accepted';
}

/** Already running as an installed app. */
export function isStandalone(): boolean {
  if (typeof window === 'undefined') return false;
  const nav = navigator as Navigator & { standalone?: boolean };
  return window.matchMedia?.('(display-mode: standalone)').matches === true || nav.standalone === true;
}

/**
 * iOS Safari: no prompt exists, so the page shows the two steps instead.
 * Other iOS browsers cannot add to the home screen at all.
 */
export function isIosSafari(): boolean {
  if (typeof navigator === 'undefined') return false;
  const agent = navigator.userAgent;
  const ios = /iPhone|iPad|iPod/.test(agent) || (agent.includes('Macintosh') && navigator.maxTouchPoints > 1);
  return ios && /Safari\//.test(agent) && !/CriOS|FxiOS|EdgiOS/.test(agent);
}

export interface InstallState {
  canPrompt: boolean;
  installed: boolean;
}

let snapshot: InstallState = { canPrompt: false, installed: false };
function getSnapshot(): InstallState {
  const next = { canPrompt: deferred !== null, installed: installed || isStandalone() };
  if (next.canPrompt !== snapshot.canPrompt || next.installed !== snapshot.installed) snapshot = next;
  return snapshot;
}

function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function useInstallState(): InstallState {
  return useSyncExternalStore(subscribe, getSnapshot, getSnapshot);
}
