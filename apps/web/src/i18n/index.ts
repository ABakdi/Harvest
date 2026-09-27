import i18n, { type BackendModule, type ResourceKey } from 'i18next';
import { initReactI18next } from 'react-i18next';
import { getPrefs, subscribePrefs, type Locale } from '@/lib/prefs';

/**
 * Each language is its own chunk, fetched when it is first needed: the
 * public pages carry neither in their first bundle, and a reader in
 * English never downloads the Arabic ([[Audit-v3]] Q5-30). English is
 * the fallback, so it comes along with Arabic.
 */
const loaders: Record<string, () => Promise<{ default: ResourceKey }>> = {
  en: () => import('./en.json'),
  ar: () => import('./ar.json'),
};

const lazyLocales: BackendModule = {
  type: 'backend',
  init: () => undefined,
  read(language, _namespace, callback) {
    const load = loaders[language];
    if (!load) {
      callback(null, {});
      return;
    }
    load().then(
      (module) => callback(null, module.default),
      (error: unknown) => callback(error instanceof Error ? error : new Error(String(error)), null),
    );
  },
};

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
  document.documentElement.dir = locale.startsWith('ar') ? 'rtl' : 'ltr';
}

// Awaited here, so nothing renders before the words it needs are in.
await i18n.use(lazyLocales).use(initReactI18next).init({
  lng: resolveLocale(),
  supportedLngs: ['en', 'ar'],
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
