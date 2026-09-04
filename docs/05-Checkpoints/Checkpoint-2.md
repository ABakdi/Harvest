# Checkpoint 2 — Locking the vault, and getting my data out

*Taken 2026-09-04, on the post-audit tree (v0.9.4).*

The [[Audit-Home|audit]] closed with two admissions. The first: the
database sits on disk in plaintext (S-04), and I deferred encryption
because it needs a keystore-backed key and a migration. The second: all
of this data lives in exactly one place — my phone — and the
[[Sync-Strategy|sync strategy]] that would give it a second home is
Phase 5, which is a long way off.

Both of those are about the same thing. The money tab knows what I earn,
what I owe, and who I owe it to. Right now anyone who picks up my
unlocked phone can read it, and a lost phone takes the lot with it.

This checkpoint closes the gap from both ends: **a lock on the front
door**, and **a way to get everything out as a spreadsheet**.

## C2-1 — App lock

### The ask

Lock the app behind whatever the device already trusts: fingerprint,
face, PIN, pattern, password. Not a password of my own — I do not want
another secret to remember, and a home-grown PIN screen would be a
worse-protected copy of one the OS already ships.

### Rules

| # | Rule |
| :- | :--- |
| L1 | The lock is **off by default**. Turning it on is a deliberate choice in Settings → Privacy. |
| L2 | It uses the device's own prompt — biometrics *and* device credentials. Anything the phone accepts to unlock itself, it accepts here. |
| L3 | It asks on every **cold start**, and again on returning from the background after a **30-second grace window**. Glancing at a notification or grabbing a photo does not make me authenticate again; leaving the app and coming back later does. |
| L4 | The **app switcher** never shows the money tab. |
| L5 | If the device has **no** biometrics and no PIN configured, the switch refuses to turn on and says why. A lock that cannot lock is worse than no lock. |
| L6 | A failed or cancelled prompt leaves the app locked with a **Try again** button. There is no way past the shield, and no unlock-by-restart: a cold start is exactly the case that always asks. |
| L7 | The lock is a **shield, not encryption**. It stops the person holding my phone; it does not stop someone with the file. That is still S-04's job, and this checkpoint does not pretend otherwise. |

### Shape

- `AuthGateway` is an interface over `local_auth`, the same way
  `NotificationGateway` wraps the notifications plugin — so the lock
  logic is testable against a fake and never needs a real thumb.
- `AppLockController` owns one phase: `unlocked` / `covered` / `locked`.
  `covered` is the app-switcher shield that lifts by itself inside the
  grace window; `locked` demands the prompt.
- `LockGate` sits in `MaterialApp.router`'s `builder`, above the
  navigator — so it covers sheets, dialogs and every route at once.
- Android needs `FlutterFragmentActivity` (the biometric prompt is a
  fragment) and the `USE_BIOMETRIC` permission.
- `ScreenGuard` is a method channel to `MainActivity` that arms
  `FLAG_SECURE` while the lock is on — see the correction below.

## C2-2 — Export as a spreadsheet

### The ask

One file with everything in it, that opens in Google Sheets with the
formulas already live — not a dead CSV dump. And it should be the thing
a future "sync to a Google Sheet" feature writes, so the shape has to be
worth committing to now.

### Rules

| # | Rule |
| :- | :--- |
| X1 | One **`.xlsx` workbook**, because that is the format Google Sheets imports with formulas intact. |
| X2 | One sheet per table — nothing summarised away, nothing dropped. If it is in the database it is in the file. |
| X3 | A **Summary** sheet whose every number is a **formula over the other sheets** (`SUMIFS`, `COUNTIFS`, …), not a value I computed in Dart. Edit a row and the totals move, exactly like a sheet I built by hand. |
| X4 | Money is stored twice: the **minor units** the app actually keeps, and a **major-unit formula** (`=E2/100`) beside it. The integer is the truth; the decimal is for reading. |
| X5 | Headers and sheet names are **English and fixed**, in both app languages. This file is a data contract for the future sync, and a contract that changes with the UI language is not a contract. |
| X6 | It saves straight to **Downloads**, named `harvest-<yyyy-MM-dd-HHmm>.xlsx`. On Android 10+ that is MediaStore and needs no permission at all; only 8.0–9.0 needs the legacy write permission, capped at `maxSdkVersion="28"`. |
| X7 | Soft-deleted rows are exported with their `deletedAt` intact rather than hidden. A backup that quietly drops rows is not a backup. |

### The workbook

| Sheet | Contents |
| :--- | :--- |
| `Summary` | Generated-at stamp, row counts, XP/coin totals, per-currency wallet and savings balances, outstanding debt, spend by category and by month — all formulas |
| `Seeds` | Commitments: type, title, schedule JSON, targets, planned day, note, reminder, deadline, paused/archived/deleted stamps |
| `CheckIns` | Every logged action with its Harvest Day and quantity |
| `Expenses` | Amount (minor + formula), currency, category, note, day |
| `Money` | Wallet/savings movements: signed delta, kind, reference, link |
| `Debts` | Person, amount, currency, pay-off day, settled stamp |
| `DebtPayments` | Partial pay-offs against a debt |
| `Focus` | Pomodoro sessions with their blocks and attached seed |
| `Ledger` | XP and coin movements with their reasons |
| `Streaks` | Current, best, freezes, last-earned day |
| `Settings` | The key-value store, so a restore knows my goal, times and rates |

### Shape

- `WorkbookBuilder` is **pure Dart** — rows in, bytes out. No plugins, no
  platform, so the whole formula layout is unit-testable.
- `ExportRepository` reads every table into plain records.
- `DownloadsGateway` is a small method channel to `MainActivity`. A
  plugin for one file write would be a dependency I have to keep;
  forty lines of Kotlin I can read is not.

## Decisions

- **`local_auth` over a home-grown PIN.** The OS prompt is better
  protected than anything I would build, and it already knows every
  method the device offers (rule L2).
- **`excel` (pure Dart) over `syncfusion_flutter_xlsio`.** Formula
  support is all I need and it carries no licence question.
- **A method channel over a MediaStore plugin.** One call, one file,
  no dependency to maintain (rule X6).
- **No `share_plus`.** Downloads is the destination I picked; the share
  sheet would be a second half-path to maintain.
- **No new tables.** Both features are settings-only: schema stays at
  **v8**.

## What the device corrected

### L4 needed a window flag, not a widget

I built the shield as a phase the app paints over itself the moment
Flutter reports it has gone to the background, and it did not work: the
app switcher still showed my field, in full.

Flutter's `onHide` fires on the way to `paused`, and Android has already
taken the recents thumbnail by then. A shield drawn in Dart is always one
frame too late — there is no arrangement of lifecycle callbacks that
gets there first.

The fix is `FLAG_SECURE`, set on the window from Kotlin while the lock is
armed and cleared when it is turned off. That makes the recents card a
blank rectangle with only the launcher icon. It also blocks screenshots
inside the app, which is the trade the lock switch is now making — worth
saying out loud, because it is a real cost and it is why the flag follows
the switch rather than being on all the time.

The `covered` phase stayed anyway: it is what keeps the contents from
being painted between coming back and the phase resolving, and it is
where the grace window is decided.

### The grace window took two goes to measure

My first attempt said the lock never re-asked after a long absence. It
did — my script had raced the PIN entry against the prompt appearing, so
the app had never been unlocked in the first place and was sitting in
`locked` the whole time. Tracing the real lifecycle stream settled it:

```
[lock] onHidden enabled=true phase=unlocked   → covered
[lock] onShown  enabled=true phase=covered    → unlocked   (5s away)
[lock] onShown  enabled=true phase=covered    → locked     (40s away)
```

A measurement that disagrees with the code is worth one more look before
it is worth a fix.

## Done when

- [x] The lock turns on, survives a cold start, respects the grace
      window, shields the app switcher, and refuses to turn on with no
      credentials enrolled
- [x] The workbook opens in a spreadsheet with live formulas and every
      table present
- [x] Analyzer clean, format clean, tests green — 179, up from 145, with
      13 new cases on the lock's phase machine and 21 on the workbook
- [x] Verified by hand on the emulator
- [x] Docs updated: this page, [[Sync-Strategy]],
      [[ADR-006-Export-Format]], [[Business-Rules]] and the audit's
      status board

## Everything that changed

| Area | Change |
| :--- | :--- |
| Dependencies | `local_auth ^3.0.2`, `excel ^4.0.6` added. `excel` pins `xml` to 6.x, which nothing else here minds. No `share_plus`. |
| Schema | **None.** Both features are settings-only; the database stays at **v8**. |
| Settings store | One new key, `security.appLock`, on `SettingKeys`. |
| `lib/features/security/` | `domain/auth_gateway.dart` (interface + `local_auth`), `domain/app_lock.dart` (the phase machine and `lockClock`), `data/screen_guard.dart` (`FLAG_SECURE` channel), `presentation/lock_gate.dart` (the shield), `presentation/app_lock_card.dart` (the switch). |
| `lib/features/export/` | `domain/workbook.dart` (generic sheets → `.xlsx`), `domain/harvest_workbook.dart` (this app's layout and formulas), `domain/export_service.dart` (service + status controller), `data/export_repository.dart` (every table → flat rows), `data/downloads_gateway.dart` (Downloads channel), `presentation/export_card.dart`. |
| `lib/main.dart` | Reads the lock setting alongside the onboarding flag before the first frame, so a locked app never flashes its contents on the way up. |
| `lib/app/app.dart` | `AppLifecycleListener` gained `onHide`/`onShow` for the grace window; `MaterialApp.router` gained a `builder` that wraps the navigator in `LockGate`. |
| Settings screen | Two new sections between Money and Appearance: **Privacy** (the lock switch) and **My data** (the export card). |
| `MainActivity.kt` | Now a `FlutterFragmentActivity` — the biometric prompt is a fragment and will not host on a plain `FlutterActivity`. Two method channels: `harvest/downloads` (MediaStore on API 29+, a plain file write below it) and `harvest/security` (`FLAG_SECURE`). |
| `AndroidManifest.xml` | `USE_BIOMETRIC`; `WRITE_EXTERNAL_STORAGE` capped at `maxSdkVersion="28"`, since Android 10+ needs no permission for MediaStore. |
| Strings | 20 new keys in English and Arabic. The workbook's own headers stay English by rule X5. |
| Tests | `test/features/security/app_lock_test.dart` (13), `test/features/export/workbook_test.dart` (16) and `export_service_test.dart` (5), plus three fakes in `test/support`. 145 → 179. |

## Release signing — the key changed

v0.9.5-beta is the first build signed with a **real upload key**.
Everything up to and including v0.9.4-beta went out on the debug
keystore, which [[Security-Audit]] S-06 called out: `~/.android/debug.keystore`
uses the well-known password `android`, is regenerated on any new
machine, and a copy of it lets anyone build an "update" Android will
install over Harvest and read its data directory.

The new key is RSA 4096, valid to 2053, held at
`~/keystores/harvest-upload.jks` and pointed at by `android/key.properties`
(git-ignored, never committed). Certificate:

```
CN=Harvest, O=Abderrahmane Bakdi, C=DZ
SHA-256  61:DD:B3:5C:1D:C3:E1:0D:FF:E9:48:C9:A7:C7:88:01:
         90:3E:DF:6D:4B:42:B0:DF:0B:6E:B3:38:7B:BD:89:94
```

**The cost, stated plainly.** Android refuses to install an APK over one
signed by a different key. v0.9.5 therefore cannot update v0.9.4-beta in
place: the old build has to be uninstalled first, and uninstalling takes
the database with it — `allowBackup="false"` means there is no copy to
restore from either (S-01, and that is working as intended).

**The way through, on a phone that already holds data.** The export
landed in this very checkpoint, so the order matters:

1. Install a build signed with the **old debug key** over v0.9.4-beta —
   it updates in place, and carries the new export with it.
2. Run **Settings → My data → Export to Downloads** and put the
   spreadsheet somewhere safe.
3. Uninstall, then install v0.9.5-beta properly signed.

The spreadsheet is a readable record, not a restore — there is no
importer yet. That is the real price of having shipped four releases on
a debug key, paid once.

**Lose the keystore and Harvest can never be updated again.** It is
backed up off this machine, and the password lives in a password
manager, not in the repo.

## Verified on the emulator

| Rule | What I did | What happened |
| :- | :--- | :--- |
| L5 | Flipped the switch with no PIN enrolled | Refused, with "Set a fingerprint, PIN or password on this device first." |
| L2 | `locksettings set-pin 1234`, flipped it again | Armed, and I stayed on the Settings screen |
| L3 | Force-stopped and relaunched | The device's PIN prompt, before any content |
| L3 | Home, back after 5s | Straight in, no prompt |
| L3 | Home, back after 40s | Prompt again |
| L4 | Recents, with the lock on | A blank card — only the launcher icon |
| L4 | Turned the lock off | `SECURE` gone from the window flags; screenshots work again |
| X1–X7 | Tapped Export | `Download/harvest-2026-09-04-0500.xlsx`, 11 sheets, 19 live formulas on Summary alone, `=E2/100` on every amount, `$A21`-style references resolved to the row each formula sits on |

The workbook was pulled off the device and its XML read directly rather
than trusting the button's own snackbar.
