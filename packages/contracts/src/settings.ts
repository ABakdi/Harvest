/**
 * The settings that are *mine*, preferences that mean the same on any
 * device, as opposed to a device's own bookkeeping (which day the streak
 * engine last judged, which notifications are scheduled, whether the
 * lock is armed).
 *
 * A port of `importableSettingPrefixes` in
 * `apps/mobile/lib/core/db/portable_settings.dart`, which is the list of
 * record: the archive importer, the export and sync all read it. The
 * two are held together by the contract fixtures; a key added there and
 * not here is a setting the server refuses.
 */
export const portableSettingPrefixes = [
  'themeMode',
  'locale',
  'dailyHarvestGoal',
  'assist.',
  'cycle.',
  'features.',
  'finance.',
  'gym.',
  'health.',
  'notes.',
  'places.',
  'onboarding.done',
  'pomodoro.focusMinutes',
  'pomodoro.shortBreakMinutes',
  'pomodoro.longBreakMinutes',
  'pomodoro.blocksPerLongBreak',
  'rate.',
  'reminders.enabled',
  'reminders.morningTime',
  'reminders.eveningTime',
  'reminders.expenseTime',
  'reminders.streakNudge',
  'sleep.',
  'widget.',
] as const;

/**
 * Whether a `kv_settings` key may leave the device. A prefix match, as
 * on the phone: `features.` covers every feature switch.
 */
export function isPortableSetting(key: string): boolean {
  return portableSettingPrefixes.some((prefix) => key.startsWith(prefix));
}
