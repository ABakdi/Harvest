import { createContext, useContext, type ReactNode } from 'react';
import { createPortal } from 'react-dom';

/** The slot in the phone-width app bar a screen may put its own actions in; null outside the shell. */
export const AppBarSlot = createContext<HTMLElement | null>(null);

/**
 * A screen's own actions in the app bar on a phone-width window, as the
 * phone puts a note's "+" and microphone up there. Nothing shows on a
 * wide window, where the screen keeps its own buttons.
 */
export function AppBarActions({ children }: { children: ReactNode }) {
  const slot = useContext(AppBarSlot);
  return slot ? createPortal(children, slot) : null;
}
