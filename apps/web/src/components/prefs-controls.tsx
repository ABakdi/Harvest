import { LanguagesIcon, MonitorIcon, MoonIcon, SunIcon } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { Button } from '@/components/ui/button';
import { resolveLocale } from '@/i18n';
import { setPrefs, themeModes, usePrefs } from '@/lib/prefs';

export const modeIcon = { system: MonitorIcon, light: SunIcon, dark: MoonIcon } as const;

/** One button that walks system → light → dark, for the site header. */
export function ThemeCycleButton() {
  const { t } = useTranslation();
  const { themeMode } = usePrefs();
  const Icon = modeIcon[themeMode];
  const next = themeModes[(themeModes.indexOf(themeMode) + 1) % themeModes.length]!;
  return (
    <Button
      variant="ghost"
      size="icon"
      aria-label={t('prefs.themeNow', { mode: t(`prefs.mode.${themeMode}`), next: t(`prefs.mode.${next}`) })}
      onClick={() => setPrefs({ themeMode: next })}
    >
      <Icon />
    </Button>
  );
}

/** Switches between the two languages, for the site header. */
export function LanguageToggleButton() {
  const { t } = useTranslation();
  usePrefs();
  const other = resolveLocale() === 'ar' ? 'en' : 'ar';
  return (
    <Button
      variant="ghost"
      size="sm"
      lang={other}
      aria-label={t('prefs.switchLanguage')}
      onClick={() => setPrefs({ locale: other })}
    >
      <LanguagesIcon />
      <span className="hidden sm:inline">{other === 'ar' ? 'العربية' : 'English'}</span>
    </Button>
  );
}
