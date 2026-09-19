/// The settings that are *mine* — preferences that mean the same on any
/// phone — as opposed to the app's own bookkeeping.
///
/// One list, read by three things: the archive importer (what an
/// archive may set), the export (what it writes), and sync (what the
/// outbox records and another device may receive).
///
/// The rest of `kv_settings` is the app's own bookkeeping — which
/// day the streak engine last judged, which notification ids are
/// scheduled, whether the lock is armed, the pomodoro that was
/// running — and none of it means anything on another phone. An
/// archive is data, never instructions ([[Audit-v2-Beta]] S2-04):
/// a zip must not be able to arm the lock, resurrect a timer, or tell
/// `reconcile` the past is already judged (B-02).
const importableSettingPrefixes = [
  'themeMode',
  'locale',
  'dailyHarvestGoal',
  // The assist's provider and model; its key lives in the keystore.
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
];

bool isImportableSetting(String key) =>
    importableSettingPrefixes.any(key.startsWith);
