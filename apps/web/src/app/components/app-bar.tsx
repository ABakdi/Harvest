import { createContext, useContext, type ReactNode } from 'react';
import { createPortal } from 'react-dom';

/** The slot in the phone-width app bar a screen may put its own actions in; null outside the shell. */
export const AppBarSlot = createContext<HTMLElement | null>(null);

/** The slot after the account circle, where Notes puts the button that opens its drawer. */
export const AppBarLeadingSlot = createContext<HTMLElement | null>(null);

/** The slot for a title of the screen's own, such as the open note's; the tab's title shows while it is empty. */
export const AppBarTitleSlot = createContext<HTMLElement | null>(null);

/**
 * A screen's own actions in the app bar on a phone-width window, as the
 * phone puts a note's "+" and microphone up there. Nothing shows on a
 * wide window, where the screen keeps its own buttons.
 */
export function AppBarActions({ children }: { children: ReactNode }) {
  const slot = useContext(AppBarSlot);
  return slot ? createPortal(children, slot) : null;
}

/** A control at the start of the phone-width app bar, after the account circle. */
export function AppBarLeading({ children }: { children: ReactNode }) {
  const slot = useContext(AppBarLeadingSlot);
  return slot ? createPortal(children, slot) : null;
}

/** The phone-width app bar's title, in place of the tab's. */
export function AppBarTitle({ children }: { children: ReactNode }) {
  const slot = useContext(AppBarTitleSlot);
  return slot ? createPortal(children, slot) : null;
}
