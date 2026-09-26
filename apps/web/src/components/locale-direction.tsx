import { Direction } from 'radix-ui';
import type { ReactNode } from 'react';
import { useTranslation } from 'react-i18next';

/** The reading direction of a language: Arabic runs right to left. */
export function directionOf(language: string): 'ltr' | 'rtl' {
  return language.startsWith('ar') ? 'rtl' : 'ltr';
}

/**
 * Tells every Radix part (tabs, menus, toggle groups, selects) which way
 * the page reads. They default to left to right whatever `<html dir>`
 * says, so without this an Arabic page lays its tabs and menus out
 * backwards. Follows a language change as it happens.
 */
export function LocaleDirection({ children }: { children: ReactNode }) {
  const { i18n } = useTranslation();
  return <Direction.Provider dir={directionOf(i18n.language)}>{children}</Direction.Provider>;
}
