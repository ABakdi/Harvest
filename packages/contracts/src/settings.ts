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
 *
 * Nothing that names where a request goes travels (S5-01):
 * not the assist's provider, model or base URL, and not the
 * map's style URL. A row anyone with write access to the account could
 * push would otherwise decide where this phone sends its API key and
 * which map server learns where I look.
 */
export const portableSettingPrefixes = [
  'themeMode',
  'locale',
  'dailyHarvestGoal',
  'cycle.',
  'features.',
  'finance.',
  'gym.',
  'health.',
  'notes.',
  'places.trail',
  'places.pausedUntil',
  'places.highAccuracy',
  'places.mapBase',
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

/**
 * Keys 3.0.0 synced and nothing does any more (S5-01): the assist's
 * provider, model and base URL, and every `places.` key, the map's
 * style URL among them. A 3.0.0 phone still pushes them, so the server
 * takes them rather than answer `invalid` for ever; current clients
 * never push them and ignore them on a pull.
 */
export const legacySettingPrefixes = ['assist.', 'places.'] as const;

/** Whether [key] is one only an old client sends: stored, never applied. */
export function isLegacySetting(key: string): boolean {
  return !isPortableSetting(key) && legacySettingPrefixes.some((prefix) => key.startsWith(prefix));
}
