import { useTranslation } from 'react-i18next';
import { modeIcon } from '@/components/prefs-controls';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group';
import { setPrefs, themeModes, themePresets, usePrefs, type ThemeMode, type ThemePreset } from '@/lib/prefs';
import { cn } from '@/lib/utils';

/*
 * The fuller preference controls for Settings. They live with the app,
 * not the site header, so the public pages do not carry their menus.
 */

export function ThemeModePicker() {
  const { t } = useTranslation();
  const { themeMode } = usePrefs();
  return (
    <ToggleGroup
      type="single"
      value={themeMode}
      onValueChange={(value) => value && setPrefs({ themeMode: value as ThemeMode })}
      aria-label={t('prefs.theme')}
    >
      {themeModes.map((mode) => {
        const Icon = modeIcon[mode];
        return (
          <ToggleGroupItem key={mode} value={mode}>
            <Icon className="size-4" />
            {t(`prefs.mode.${mode}`)}
          </ToggleGroupItem>
        );
      })}
    </ToggleGroup>
  );
}

const presetSwatch: Record<ThemePreset, [string, string]> = {
  harvest: ['#e85d3a', '#ffb13d'],
  sunrise: ['#ff4f6d', '#ffc93c'],
  ocean: ['#0e9de9', '#10bfa5'],
  orchard: ['#1fb25a', '#f7c948'],
  dusk: ['#8b5cf6', '#ec4899'],
};

export function PresetPicker() {
  const { t } = useTranslation();
  const { themePreset } = usePrefs();
  return (
    <div role="radiogroup" aria-label={t('prefs.style')} className="flex flex-wrap gap-2">
      {themePresets.map((preset) => {
        const [from, to] = presetSwatch[preset];
        const selected = preset === themePreset;
        return (
          <button
            key={preset}
            type="button"
            role="radio"
            aria-checked={selected}
            onClick={() => setPrefs({ themePreset: preset })}
            className={cn(
              'flex items-center gap-2 rounded-lg bg-input px-3 py-2 text-sm font-bold outline-none focus-visible:ring-2 focus-visible:ring-ring',
              selected && 'ring-2 ring-primary',
            )}
          >
            <span className="size-5 rounded-full" style={{ backgroundImage: `linear-gradient(135deg, ${from}, ${to})` }} />
            {t(`prefs.preset.${preset}`)}
          </button>
        );
      })}
    </div>
  );
}

export function LanguageSelect({ id }: { id?: string }) {
  const { t } = useTranslation();
  const { locale } = usePrefs();
  return (
    <Select
      value={locale ?? 'system'}
      onValueChange={(value) => setPrefs({ locale: value === 'system' ? null : (value as 'en' | 'ar') })}
    >
      <SelectTrigger id={id} className="w-full sm:w-60">
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        <SelectItem value="system">{t('prefs.langSystem')}</SelectItem>
        <SelectItem value="en">English</SelectItem>
        <SelectItem value="ar">العربية</SelectItem>
      </SelectContent>
    </Select>
  );
}
