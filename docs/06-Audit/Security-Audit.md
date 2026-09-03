# Security Audit

*Taken 2026-09-03 on the round-5 tree (v0.9.4 beta + the reminder fix), before any remediation. A read-only review of the Android app. Fix status lives in [[Audit-Home]].*

The question I asked: does the app keep the promise in [[Finances]] — money data never leaves the device in plaintext — and is the attack surface as small as a local-first app can make it?

Scope: `/home/abakdi/Dev-Home/Harvest` at commit `0f929f3` (main, clean tree). All line numbers refer to the current files. 

## Findings (ordered by severity)

### S-01 — High — Financial database is included in Android Auto Backup / `adb backup`
**Files:** `android/app/src/main/AndroidManifest.xml:12-15` (`<application>` has no `android:allowBackup`, `android:fullBackupContent`, or `android:dataExtractionRules`); `android/app/src/main/res/xml/` does not exist; `lib/core/db/database.dart:312` (`driftDatabase(name: 'harvest')`).

`drift_flutter` 0.3.1 places the file at `getApplicationDocumentsDirectory()/harvest.sqlite` (`~/.pub-cache/.../drift_flutter-0.3.1/lib/src/native.dart:36-50`), i.e. `/data/data/com.harvest.app/app_flutter/harvest.sqlite`. With `allowBackup` defaulting to `true` and no exclusion rules, Android Auto Backup uploads the whole app data directory (everything except `cache/`, `code_cache/`, `no_backup/`) to the user's Google Drive, and on devices running Android 8–11 (`minSdk = 26`) `adb backup` can extract it from any unlocked phone plugged into a computer, no root required. The same applies to the `shared_prefs/scheduled_notifications.xml` file written by `flutter_local_notifications` (see S-03), which contains reminder titles/bodies such as "Debt to {person}".

The spec (`docs/01-Specification/Finances.md:84-86`) says financial data "never leaves the device in plaintext"; today the SQLite file with expenses, wallet/savings balances, debts and creditor names leaves the device on every nightly backup.

**Fix (manifest):**
```xml
<application
    android:label="Harvest"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher"
    android:allowBackup="false"
    android:fullBackupContent="false"
    android:dataExtractionRules="@xml/data_extraction_rules">
```
`res/xml/data_extraction_rules.xml` (API 31+; `fullBackupContent="false"` covers API 26-30):
```xml
<data-extraction-rules>
  <cloud-backup disableIfNoEncryptionCapabilities="true">
    <exclude domain="root" path="." />
    <exclude domain="file" path="." />
    <exclude domain="database" path="." />
    <exclude domain="sharedpref" path="." />
  </cloud-backup>
  <device-transfer>
    <exclude domain="root" path="." />
    <exclude domain="file" path="." />
    <exclude domain="database" path="." />
    <exclude domain="sharedpref" path="." />
  </device-transfer>
</data-extraction-rules>
```
If you later want device-to-device transfer, keep only the `<device-transfer>` excludes for `sharedpref` and rely on S-04's encryption for the DB. Simplest correct option today: `android:allowBackup="false"` alone.

### S-02 — High — The whole app is usable over the lock screen after any alarm reminder fires
**Files:** `android/app/src/main/AndroidManifest.xml:19-20`
```xml
android:showWhenLocked="true"
android:turnScreenOn="true"
```
`lib/core/platform/notifications.dart:254-255` (`visibility: NotificationVisibility.public, fullScreenIntent: alarm`), default `alarm = true` at `:227`; debt reminders at `lib/features/planner/domain/notification_planner.dart:202-211` use the default and set `route: 'finances'`; `lib/app/bootstrap.dart:41-42` navigates to that route on launch.

`showWhenLocked` applies to `MainActivity` — the only activity — for *every* launch, not only the alarm one. When a reminder fires on a locked phone (debt reminders default to 19:00 daily, morning ritual 07:00), the plugin's full-screen `PendingIntent` starts `MainActivity`, Android displays it on top of the keyguard, `appBootstrap` reads `launchRoute()` and `go()`s to `/finances`. Whoever is holding the phone sees wallet/savings balances, every debt with the creditor's name, and can tap through every tab, log, edit or delete data — with the device still locked. Because the activity stays above the keyguard, the exposure lasts until the user presses back/home.

**Fix:** remove `android:showWhenLocked` and `android:turnScreenOn` from `MainActivity`. If the over-the-lock-screen alarm UX is wanted, do it with a dedicated activity that hosts only a "Dismiss / Snooze" surface (or use `setShowWhenLocked(true)` from Kotlin only when the launching intent carries an alarm extra, and call `KeyguardManager.requestDismissKeyguard()` before routing to `/finances`). At minimum, never full-screen a notification whose route lands on financial data:
```dart
// notification_planner.dart:202
await _notifications.schedule(
  id: id,
  channelId: NotificationChannels.reminders,
  title: l10n.notifDebtTitle(row.person),
  body: ...,
  when: when,
  route: 'finances',
  alarm: false,            // no full-screen intent for finance content
);
```

### S-03 — Medium — Debt reminders put creditor name and amount on the lock screen (and in plaintext SharedPreferences)
**Files:** `lib/features/planner/domain/notification_planner.dart:205-208`
```dart
title: l10n.notifDebtTitle(row.person),
body: l10n.notifDebtBody('${row.currency} ${row.amountMinor ~/ 100}'),
```
`lib/l10n/app_en.arb:477,485` ("Debt to {person}", "{amount} still owed…"); `lib/core/platform/notifications.dart:253` `visibility: NotificationVisibility.public`.

`public` forces the full text onto the lock screen regardless of the user's "sensitive notification content" setting. The title/body/payload are also persisted by the plugin in `shared_prefs/scheduled_notifications.xml` (`FlutterLocalNotificationsPlugin.java:539-556`) and, for snoozed copies, in `kv_settings` under `reminders.snoozes` (`lib/core/platform/reminder_actions.dart:61-71`). Per-seed reminders use the seed title as the notification title (`notification_planner.dart:285`), which can also be personal.

**Fix:** make visibility a parameter and use `NotificationVisibility.private` for anything carrying user content (the OS then shows "Harvest: content hidden" until unlocked, or full content if the user allowed it in Settings). Keep the body generic for debts:
```dart
// notifications.dart schedule(): add `NotificationVisibility visibility = NotificationVisibility.private`
// notification_planner.dart: title: l10n.notifDebtTitleGeneric  // "A debt reminder"
//                            body: l10n.notifDebtBodyGeneric    // no name, no amount
```
If you want the name after unlock, the plugin has no `publicVersion` support, so private visibility with a neutral title is the practical option.

### S-04 — Medium — Financial data at rest is an unencrypted SQLite file
**Files:** `lib/core/db/database.dart:270-312`; `pubspec.yaml:11` (`drift_flutter`); `pubspec.lock:893-900` (`sqlcipher_flutter_libs 0.7.0+eol` is a no-op placeholder pulled by `drift_flutter`, not an encrypted build).

Tables `expenses`, `money_txns`, `debts` (with `person`), `debt_payments`, `expense_categories` and the snooze/notification copies in `kv_settings` are stored in plaintext. Android's file-based encryption protects the file only while the device is locked-at-boot; it does not protect against backups (S-01), rooted devices, `adb backup` on API 26-30, or forensic extraction. Given the spec's "never leaves the device in plaintext", S-01 is the urgent half; encryption is defence in depth.

**Fix:** switch the connection to SQLCipher and keep the key in an Android-Keystore-backed secret. With `sqlite3` 3.x (hooks-based, which this project already uses via `jni`) drift documents a SQLCipher build option; then:
```dart
static QueryExecutor _openConnection() => driftDatabase(
  name: 'harvest',
  native: DriftNativeOptions(
    setup: (db) => db.execute("PRAGMA key = '${keyFromKeystore()}'"),
  ),
);
```
where `keyFromKeystore()` reads a 32-byte random key generated once and stored with `flutter_secure_storage` (AES key wrapped by the Android Keystore). Also add a lightweight migration path: open plaintext DB, `ATTACH` encrypted, `sqlcipher_export`, delete the old file. Both background isolates (`reminder_actions.dart:137`, `day_reset.dart:31`) construct `HarvestDatabase()` directly and would need the same key.

### S-05 — Medium — Exchange-rate values are stored and used without validation (crash and integrity)
**Files:** `lib/features/finances/data/rates_service.dart:30-33`
```dart
final body = jsonDecode(response.body) as Map<String, dynamic>;
final rate = ((body['rates'] as Map<String, dynamic>)['USD'] as num).toDouble();
await _settings.setString(RateKeys.usdPerEur, '$rate');
```
`lib/features/settings/presentation/rates_card.dart:46-48`
```dart
final value = double.tryParse(raw.replaceAll(',', '.'));
if (value == null || value <= 0) return;
```
`lib/features/finances/presentation/finance_providers.dart:160-162` (`double.tryParse(...)` on read); `lib/features/finances/domain/currency.dart:43,58` (`(minor * factor).round()`, `1 / usdPerEur!`).

- Manual path: Dart's `double.tryParse` accepts `"NaN"`, `"Infinity"`, `"-Infinity"`. `NaN <= 0` is `false`, `Infinity <= 0` is `false`, so both are saved. `Rates.toDefault` then calls `.round()` on NaN/Infinity, which throws `UnsupportedError`, and every widget rendering a conversion caption (`money.dart:49-58`) throws — the Granary tab becomes unusable until the setting is corrected.
- Network path: a `0`, negative, or absurd `USD` value from the server is stored verbatim; `0` makes `1 / usdPerEur` infinite with the same crash; a wrong rate silently mis-converts amounts. `jsonDecode` of a non-object body throws a `TypeError` caught by `on Object` (fine), but there is no body-size cap (`http.get` buffers the entire response in memory) and `Uri.parse` is fine.

**Fix:**
```dart
bool _saneRate(double v) => v.isFinite && v > 0 && v < 1e6;

// rates_service.dart
if (response.contentLength != null && response.contentLength! > 64 * 1024) return null;
final rate = ...;
if (!_saneRate(rate) || rate < 0.5 || rate > 2.0) return null; // EUR/USD band

// rates_card.dart
if (value == null || !value.isFinite || value <= 0) return;

// currency.dart toDefault()
if (factor == null || !factor.isFinite) return null;
```
Also consider clamping with `factor.isFinite` before `.round()` as the last line of defence.

### S-06 — Medium — Release build is signed with the debug key; no signing config, no Dart obfuscation
**Files:** `android/app/build.gradle.kts:34-39`
```kotlin
release {
    // TODO: Add your own signing config for the release build.
    signingConfig = signingConfigs.getByName("debug")
}
```
`~/.android/debug.keystore` uses the well-known password `android`, has no backup, and is regenerated on any new machine; any APK installed from this config is upgrade-locked to that file, and a copy of the file lets anyone build an "update" that Android will install over Harvest and read its data directory. Play/F-Droid also reject debug-signed builds. `.gitignore` already covers `key.properties`, `*.jks`, `*.keystore` (`.gitignore` tail) and none are tracked (`git ls-files` check), so adding a real config is safe. No `--obfuscate --split-debug-info` build flags are documented anywhere (`README.md`, no `Makefile`/CI), so Dart symbols ship in release; R8 for the Java side is Flutter's default and there is no `proguard-rules.pro` to break it.

**Fix:**
```kotlin
val keystoreProperties = java.util.Properties().apply {
    val f = rootProject.file("key.properties"); if (f.exists()) load(f.inputStream())
}
signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String?
        keyPassword = keystoreProperties["keyPassword"] as String?
        storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
        storePassword = keystoreProperties["storePassword"] as String?
    }
}
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
    }
}
```
and build with `flutter build apk --release --obfuscate --split-debug-info=build/symbols`.

### S-07 — Low — Money parsing has no upper bound; 64-bit wraparound can accept a garbage amount
**Files:** `lib/features/finances/presentation/money.dart:28-45`
```dart
final major = int.tryParse(parts[0]);
if (major == null || major < 0) return null;
...
final total = major * 100 + cents;
return total > 0 ? total : null;
```
Dart VM ints wrap silently. `"184467440737095517"` parses (it is < 2^63), `* 100` wraps to `84`, and the expense is stored as 0.84. Balances are `sum()`s over signed deltas (`vault_repository.dart:32-36`, `:213`) and can likewise overflow with absurd inputs. Not exploitable by a third party, but it corrupts the user's own ledger, and `formatGrouped` (`money.dart:16`) converts to `double`, losing precision above 2^53.

**Fix:**
```dart
const _maxMajor = 1000000000000; // 10^12 in major units
if (major == null || major < 0 || major > _maxMajor) return null;
```
Add the same cap in `money_sheet.dart:80`, `debt_sheet.dart:58`, `granary_screen.dart:413-415` implicitly via `parseToMinor`.

### S-08 — Low — Free-text inputs have no length limit and reach notifications / DB unbounded
**Files:** `lib/features/finances/presentation/debt_sheet.dart:106-107` (`_personController`), `:180-181` (note); `expense_sheet.dart:306-307` (note), `:336-337` (category name, only `trim().isEmpty` checked at `:378-379`); `money_sheet.dart:178-179`. Grep for `maxLength|LengthLimiting|inputFormatters` across `lib/` returns nothing. The debt `person` string becomes the notification title (`notification_planner.dart:205`) and the category name doubles as the stored key (`database.dart:220-221`), so a custom category named like a preset silently merges with it.

**Fix:** `maxLength: 40` on person/category, `maxLength: 200` on notes (with `maxLengthEnforcement: MaxLengthEnforcement.enforced`), and in `createCategory` reject names that match a preset or an existing non-deleted custom category (case-insensitive).

### S-09 — Low — Payload/snooze JSON parsing throws on shape mismatches outside the `FormatException` guard
**Files:** `lib/core/platform/notifications.dart:70-88`
```dart
try {
  final map = jsonDecode(raw);
  if (map is Map<String, dynamic>) {
    return ReminderPayload(
      title: map['title'] as String? ?? '',
      ...
      (pair[0] as String, pair[1] as String),
```
`} on FormatException {` only covers non-JSON. A JSON payload whose `title`, `route` or snooze pair elements are not strings raises `TypeError`, which escapes `_onResponse` (`:145`) into the plugin callback (uncaught in the foreground), and `SnoozeStore.reapply` (`reminder_actions.dart:91`) does `int.parse(entry.key)` / `DateTime.parse(item['when'] as String)` (`:121`) on stored data. All of these inputs originate from Harvest itself (the three receivers are `exported="false"`, `AndroidManifest.xml:44-58`, so no other app can inject a `NotificationResponse`), which is why this is Low; the risk is a wedged reminder pipeline after a bad write or a future schema change.

**Fix:** widen the guard to `on Object` in `decode`, use `is String` checks instead of casts, and in `reapply` skip entries where `int.tryParse(entry.key) == null` or `DateTime.tryParse(...) == null` rather than throwing.

### S-10 — Low — Soft-deleted finance rows are never purged; outbox will queue finance PII for sync
**Files:** `lib/features/finances/data/finances_repository.dart:217-226` (`remove` sets `deletedAt`), `vault_repository.dart` (no delete path at all for `money_txns`/`debts`); outbox appends at `finances_repository.dart:228-236` and `vault_repository.dart:302-310` for tables `expenses`, `expense_categories`, `money_txns`, `debts`, `debt_payments`; `docs/02-Architecture/Sync-Strategy.md:35-41` lists only "Expenses" in the encrypted tier.

"Delete" keeps amount, category, note (and for debts the creditor's name) forever. The `outbox` records only `(table, uuid, op)` — no PII itself — but it marks every finance table for upload. Debts contain third-party names, which are not covered by the privacy-tier table.

**Fix:** (a) add a periodic hard-delete of rows with `deletedAt < now - 30d` once they are acknowledged (or immediately while sync does not exist); (b) update `Sync-Strategy.md` so `money_txns`, `debts`, `debt_payments`, `expense_categories` share the "E2E encrypted or local-only" tier with expenses, and gate `_appendOutbox` on a `syncFinances` setting defaulting to `false`.

### S-11 — Info — Manifest declares both `SCHEDULE_EXACT_ALARM` and `USE_EXACT_ALARM`
**File:** `android/app/src/main/AndroidManifest.xml:7-8`. Google Play limits `USE_EXACT_ALARM` to alarm/timer/calendar apps; declaring both means Android 13+ auto-grants exact alarms and the `requestExactAlarmsPermission()` call at `notifications.dart:178-181` is dead code there. This is a policy/least-privilege point, not a vulnerability: decide which one the app is (reminders-as-alarms suggests `USE_EXACT_ALARM` only, with `SCHEDULE_EXACT_ALARM` kept `android:maxSdkVersion="32"`). Every other permission (`INTERNET` for the single rate fetch, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED` for the plugin/WorkManager boot receivers, `USE_FULL_SCREEN_INTENT`, `VIBRATE`, `WAKE_LOCK`) is used.

### S-12 — Info — Silent failure paths hide dropped reminders and failed rate fetches
**Files:** `notifications.dart:271-276` (schedule failures only `debugPrint`ed), `rates_service.dart:39-41` (`on Object { return null; }`), `day_reset.dart:28-40` (no try/catch around `reconcile()`/`planToday()`; an exception fails the WorkManager run, which then retries with backoff, and `_dispatcher` does not check `task == DayResetJob.taskName`). No sensitive data is printed — the messages are `'notification schedule failed: $error'` etc. — and `debugPrint` does run in release builds, so keep it free of payloads as it is now. Consider surfacing "exact alarms not permitted" to the user instead of swallowing it.

### S-13 — Info — SDK/toolchain not pinned
**File:** `pubspec.yaml:7` `sdk: ^3.13.2` (caret, not exact), no `.fvmrc`/`.tool-versions`, Flutter version unpinned. Reproducible security builds benefit from pinning; low priority.

## Checked and found acceptable

- **Exported components / intent filters:** only `MainActivity` is exported (required for `MAIN/LAUNCHER`); all three notification receivers are `exported="false"` (`AndroidManifest.xml:44-58`); no `VIEW`/scheme/app-link intent filters, so **no deep links** (`lib/app/router.dart`) and the only external entry is the whitelist in `bootstrap.dart:45-49` (`'planner'`, `'finances'`, everything else → `/field`). `android:taskAffinity=""` blocks task hijacking.
- **Cleartext / debuggable / network config:** neither `usesCleartextTraffic` nor `debuggable` is set → defaults are safe for `targetSdk ≥ 28`. The single URL is HTTPS (`rates_service.dart:27`), 10 s timeout, status check. No certificate pinning; acceptable for a public keyless rate API whose value only drives a display caption (after S-05 validation).
- **SQL injection:** no `customStatement`/`customSelect`/raw SQL anywhere in `lib/`; every query uses drift's typed builder with bound parameters. The only `like()` (`finances_repository.dart:34`) binds `'$prefix%'` where `prefix` is derived from `HarvestDay.key` (`yyyy-MM`), not user text.
- **Secrets:** repo-wide grep (excluding `build/`, `.dart_tool/`, `.git/`) for API keys, tokens, passwords, private keys, credentialed URLs found nothing; `key.properties`, `*.jks`, `*.keystore`, `local.properties` are git-ignored and untracked.
- **Logging:** only seven `debugPrint` sites, all error-message-only, no amounts/names/payloads.
- **Notification IDs:** rituals 101-105, tasks 2100+, debts 3100+, snoozes `5000 + original` (re-snooze keeps the id), pomodoro 9001 — no realistic collision (would need >1000 tasks). Previously scheduled task/debt ids are persisted and cancelled before replanning (`notification_planner.dart:176-184, 230-238`).
- **Background handler / WorkManager / boot:** `reminderBackgroundHandler` only acts on `snooze:` actions, opens and closes its own DB (`reminder_actions.dart:134-145`); the periodic job is idempotent and reads no untrusted input; boot receivers belong to the plugin and are not exported.
- **Input handling elsewhere:** `parseToMinor` rejects negatives, >2 decimals, empty, and non-numeric; `MoneyAccount.values.byName` / `Currency.fromCode` only see locally written values; `remindAt` strings are `tryParse`d with fallbacks.
- **Dependencies:** `http 1.6.0`, `drift 2.34.3`, `flutter_local_notifications 22.3.0`, `workmanager 0.10.9`, `go_router 18.0.0`, `sqlite3 3.5.2`, `uuid 4.6.0` are current; no known vulnerable ranges among them. `sqlite3_flutter_libs 0.6.0+eol` / `sqlcipher_flutter_libs 0.7.0+eol` are inert EOL placeholders required by `drift_flutter` (`drift_flutter-0.3.1/pubspec.yaml`), not a risk.

## Suggested order of remediation
1. S-01 (backup exclusion) and S-02 (remove `showWhenLocked`/`turnScreenOn`) — both are one-line manifest changes with the biggest impact on the "finances never leave the device" promise.
2. S-03 (private visibility, generic debt text) and S-05 (rate validation).
3. S-06 (real signing config + obfuscation) before any distribution.
4. S-04 (SQLCipher) as the next milestone, then S-07 to S-10 hardening.
