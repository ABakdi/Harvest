import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import { getPrefs, subscribePrefs, type Locale } from '@/lib/prefs';
import ar from './ar.json';
import en from './en.json';

export const resources = { en: { translation: en }, ar: { translation: ar } } as const;

/** The browser's language when none was chosen: Arabic if it asks for it. */
export function resolveLocale(): Locale {
  const chosen = getPrefs().locale;
  if (chosen) return chosen;
  const asked = typeof navigator !== 'undefined' ? navigator.language : 'en';
  return asked.toLowerCase().startsWith('ar') ? 'ar' : 'en';
}

function applyDirection(locale: string): void {
  if (typeof document === 'undefined') return;
  document.documentElement.lang = locale;
  document.documentElement.dir = locale === 'ar' ? 'rtl' : 'ltr';
}

void i18n.use(initReactI18next).init({
  resources,
  lng: resolveLocale(),
  fallbackLng: 'en',
  interpolation: { escapeValue: false },
  returnNull: false,
});

applyDirection(i18n.language);
i18n.on('languageChanged', applyDirection);
subscribePrefs(() => {
  const next = resolveLocale();
  if (next !== i18n.language) void i18n.changeLanguage(next);
});

export default i18n;
