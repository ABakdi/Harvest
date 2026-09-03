# Code Quality Audit

*Taken 2026-09-03 on the round-5 tree, before any remediation. Two passes over the whole codebase; generated files ignored. Fix status lives in [[Audit-Home]].*

The bar: correct across the 3 AM boundary and DST, atomic wherever money or streaks move, no swallowed errors, no duplicated helpers, no dead code, and every important rule under test.

# Part 1 — core, productivity, planner, pomodoro, calendar, onboarding

Tooling results (run today):
- `flutter analyze` → **No issues found** (3.5 s).
- `dart format --output=none --set-exit-if-changed lib test` → **exit 1, 37 of 119 files would change** (30 under `lib/`, 7 under `test/`). In scope: `lib/app/app.dart`, `lib/app/router.dart`, `lib/core/domain/harvest_day.dart`, `lib/core/l10n_loader.dart`, `lib/core/ui/widgets/{big_bouncy_button,crop_card,deadline_countdown}.dart`, `lib/features/calendar/presentation/calendar_screen.dart`, all of `lib/features/commitments/**` (6 files), `lib/features/gamification/**` (3), `lib/features/onboarding/presentation/onboarding_screen.dart`, `lib/features/planner/presentation/planner_screen.dart`, `lib/features/pomodoro/**` (3), and `test/features/{commitments/check_in_service_test,commitments/today_field_test,commitments/vacation_mode_test,gamification/streak_service_test,planner/prime_time_test}.dart`. The diff pattern (`=>` continuation indents, `..cascade` placement) is the Dart ≥3.7 "tall style" formatter vs. code formatted with an older SDK; a single `dart format .` commit fixes it.
- In-scope tests: **65 passed**, but with 5× `notification cancel failed: LateInitializationError` printed from `prime_time_test.dart` (see Q-31).

---

## A. Core: Harvest Day, time, day boundary

**Q-01 · High · Day-keyed providers cache `HarvestDay.today()` forever; nothing re-runs at 3 AM or on resume**
`lib/features/commitments/presentation/field_providers.dart:13-15` `watchLoggedOn(HarvestDay.today())`, `:22-24` `watchDoneDaysThisWeek(HarvestDay.today())`, `:33` `final today = HarvestDay.today();` (inside `todayField`); `lib/features/planner/presentation/planner_screen.dart:20`; `lib/features/gamification/data/gamification_repository.dart:134-139,146-149`. These are autoDispose, but `FieldScreen` is a `StatefulShellRoute.indexedStack` branch root so it is mounted for the whole process lifetime and keeps them alive. There is no `WidgetsBindingObserver`/`AppLifecycleListener` anywhere (grep: none), and `appBootstrap` (`lib/app/bootstrap.dart:37-38`) runs `reconcile()`/`planToday()` once per process. An Android process that survives overnight shows yesterday's field at 7 AM; a check-in then writes today's key (`CheckInService` calls `HarvestDay.today()` fresh) but `loggedToday` still streams yesterday, the card stays unchecked, the second tap returns `CheckInCapped(0)` which `_onTap` ignores (`field_screen.dart:311`). Fix: a `currentHarvestDay` Notifier that arms a `Timer` to `today.next.startsAt` and also refreshes on `AppLifecycleState.resumed`; make every day-keyed provider `ref.watch` it; on resume also re-run `reconcile()` and `planToday()`.

**Q-02 · High (latent outside DZ; crashes debug builds in DST zones) · `HarvestDay` does calendar arithmetic with absolute `Duration`s**
`lib/core/domain/harvest_day.dart:19` `local.subtract(const Duration(hours: boundaryHour))`; `:54` `DateTime(y,m,d).add(hours: 3)`; `:61` `_date.subtract(Duration(days: weekday - 1))`; `:63-65` `add/subtract(days: 1)`; `:68-69` `difference(_date).inDays`. On a DST-change day a 24 h "day" is 23 h/25 h, so `next`/`previous`/`weekStart` yield 23:00 or 01:00 — which trips `assert(_date.hour == 0 …)` at `:11-14` in debug and silently produces a wrong `key` in release; `daysUntil` truncates 23 h to 0 days, shifting `IntervalSchedule.isDueOn` (`schedule.dart:96`); `of()` maps 03:00–03:59 on spring-forward day to the previous day; `startsAt` becomes 04:00. Algeria has no DST today, but the app is bilingual and this is the app's rule #1. Fix: pure calendar math — `DateTime(year, month, day + 1)` (Dart normalises overflow), `DateTime(year, month, day - (weekday - 1))`, `of()` = `local.hour < boundaryHour ? DateTime(y,m,d-1) : DateTime(y,m,d)`, `startsAt = DateTime(year, month, day, boundaryHour)`, `daysUntil` via `DateTime.utc(...)` differences. Add tests for 2026-03-29/2026-10-25 in a DST zone.

**Q-03 · Medium · Planner mixes calendar day and Harvest Day between midnight and 3 AM**
`lib/features/planner/domain/notification_planner.dart:370-371` `_todayAt` uses `now.year/month/day`, while `:86` `goalMet = _goalMetToday(at)` and `:123` `_expensesLoggedToday(at)` use `HarvestDay.of(at)`. A `planToday` at 01:30 (app open, or the 6-hourly job) evaluates "goal met" for *yesterday's* Harvest Day and then suppresses prime-time/streak-risk reminders that fire at 23:00 of the *new* day. Self-heals only if the next background run happens. Fix: derive `plannedDay = at.hour < boundaryHour ? HarvestDay.of(at).next : HarvestDay.of(at)` and use it for both the schedule times and the "done today" checks; better, run the job at 3 AM (Q-04).

**Q-04 · Low · "3 AM day-reset job" is a 6-hourly periodic task with no phase**
`lib/core/platform/day_reset.dart:7` doc says 3 AM; `:20` `frequency: const Duration(hours: 6)` with no `initialDelay`. Reconcile is idempotent so this is a doc/behaviour mismatch, but reminders are planned up to 6 h late when the app is not opened. Fix: `initialDelay: nextThreeAm.difference(now)` + `frequency: 24h`, or keep 6 h and document it.

**Q-05 · Low · `HarvestDay.parse` trusts stored strings**
`harvest_day.dart:33-34` `key.split('-').map(int.parse)` — a corrupt `dueDay`/`deadline`/`lastEarnedDay` row throws inside `_toDomain` (`commitments_repository.dart:169,173`) and errors the `watchActive` stream; the field then renders empty via `.value ?? const []` (`field_providers.dart:29`) with no log. Fix: `tryParse` variant used at the repository boundary; skip and log bad rows.

---

## B. Streaks and check-ins

**Q-06 · High · Editing a to-do silently moves its planned day**
`lib/features/commitments/presentation/commitment_editor_sheet.dart:81-82` sets `_dueToday = existing.dueDay <= today` but never sets `_customDueDay = existing.dueDay`; `:120-121` `_todoDueDay => _customDueDay ?? (_dueToday ? today : today.next)`; `:206-207` `_saveEdit` always writes `dueDay: _todoDueDay`. Renaming a to-do planted for next Friday rewrites its `dueDay` to **tomorrow**; an overdue one becomes **today**. Fix: in `initState`, `if (existing.dueDay case final d? when d != today && d != today.next) _customDueDay = d;`.

**Q-07 · Medium · Habit/to-do check-in read-then-write is not atomic → double tap double-logs**
`lib/features/commitments/domain/check_in_service.dart:64-70` `_loggedOn` is awaited *outside* the `transaction` at `:82`. Two fast taps both read 0, both insert: two check-in rows and 20 XP for one habit. `CheckInController` (`check_in_controller.dart:18-30`) and `_CropTile._onTap` (`field_screen.dart:271-328`) add no in-flight guard. Fix: move the `_loggedOn`/cap computation inside the transaction; give `CheckInController` real `AsyncValue` state so the tile disables while pending (also Q-24).

**Q-08 · Medium · Check-ins are hard-deleted although the schema and every reader use soft-delete**
`check_in_service.dart:130-134` `_db.delete(_db.checkIns)` / `_db.delete(_db.ledger)`, then `:135-141` appends an outbox `delete` for a row that no longer exists. `database.dart:48` calls `check_ins` "Append-only", `:60` has `deletedAt`, and all 9 readers filter `deletedAt.isNull()`. A future sync client cannot read the deleted row's `updatedAt`/contents. Fix: `write(CheckInsCompanion(deletedAt: Value(now)))` and mark the ledger row rather than deleting it (keep XP history honest: insert a negative `xp` entry with reason `undo:<uuid>`).

**Q-09 · Medium · Pausing after the fact rescues a streak that was already missed**
`lib/features/gamification/domain/streak_service.dart:286-294` `_activeHabits` excludes `pausedAt.isNotNull()` at reconcile time regardless of the day being judged; `:209` fetches it once for all days. Miss Mon–Wed, open app Thu, pause, unpause → Mon–Wed are never judged (lastJudged advances at `:218`). `vacation_mode_test.dart` only covers pause-before-miss. Fix: judge all habits and skip only when `habit.pausedAt != null && habit.pausedAt!.isBefore(day.next.startsAt)`; same for `archivedAt`.

**Q-10 · Medium · `buyFreeze` checks the balance outside the transaction and the button is not disabled while pending**
`streak_service.dart:158-163` reads the coin sum, `:165-182` writes in a transaction without re-checking; `lib/features/gamification/presentation/streak_sheet.dart:109-128` `onPressed` is an async closure with no pending flag. Two taps with a 150-coin balance → two freezes, balance −50. Fix: compute the balance inside the transaction and return `false` if short; disable the button while the future is in flight.

**Q-11 · Medium · `undo` rewrites `lastEarnedDay` to a day that may not have been earned**
`streak_service.dart:111` and `:142` `lastEarnedDay: day.previous.key` after an undo, even when the streak is now 0 (previous day was not earned). `_judgeGlobal` `:223-226` and `_judgeHabit` `:263-264` treat `lastEarnedDay >= day` as "already earned", so a later reconcile of that previous day is skipped. Fix: store the true previous earned day (keep the old value if `current` was 0) or model `earnedDays` instead of a single marker.

**Q-12 · Low · UI is interactive before `reconcile()` finishes**
`lib/app/app.dart:43` `ref.watch(appBootstrapProvider)` is not awaited/gated; `bootstrap.dart:37` `await reconcile()`. A check-in tapped before reconcile completes runs `onCheckIn` (`streak_service.dart:86-101`) against the un-judged streak, then `_judgeHabit` sees `lastEarnedDay == today >= missedDay` and never breaks it. Small window, grows with history (Q-13). Fix: gate the field on `appBootstrapProvider` being `AsyncData`, or run reconcile inside a DB transaction keyed by day.

**Q-13 · Low · Reconcile does O(days × habits) queries after a long absence**
`streak_service.dart:211-217` loops every missed day with 3–4 queries each on the main isolate, awaited at startup. Fix: when no check-ins exist in `(lastJudged, today)`, break all non-zero streaks in one pass and jump to today.

**Q-14 · Low · `productiveActions` counts check-ins on archived/deleted commitments**
`streak_service.dart:68-70` selects by uuid with no `archivedAt/deletedAt` filter. Arguably intended (effort was real) — document it or filter.

---

## C. Notifications and planner

**Q-15 · Medium · `appBootstrap` has no error handling; a single bad row disables reminders and reconcile for the session**
`bootstrap.dart:37-38`; failure sources: `streak_service.dart:206` `jsonDecode(...) as String`, `:259-261` `Schedule.fromJson(jsonDecode(habit.scheduleJson!))` (throws `ArgumentError` at `schedule.dart:23` for an unknown type), `notification_planner.dart:266-268`. The FutureProvider errors, `app.dart:43` discards the `AsyncValue`, nothing is logged, nothing is shown. Fix: run each step in its own `try/catch`, log, and expose a "last bootstrap error" for Settings.

**Q-16 · Medium · All notification failures are swallowed with `on Object` + `debugPrint`**
`lib/core/platform/notifications.dart:159,183,200,211,271,316,324,332`, `reminder_actions.dart:140`. `requestPermission()` returns `false` both for "denied" and "plugin threw"; `schedule()` silently drops the reminder the user just set. Fix: catch `PlatformException`/`MissingPluginException` specifically, use a logger, and return a tri-state from `requestPermission`; put a `NotificationGateway` interface behind the service so tests use a fake instead of relying on the swallow (Q-31).

**Q-17 · Medium · Task reminders ignore the week quota and overdue to-dos**
`notification_planner.dart:266-268` `Schedule.fromJson(...).isDueOn(today)` is called without `doneDaysThisWeek`, so `TimesPerWeekSchedule.isDueOn` (`schedule.dart:122-123`) is always true → a 3×/week habit keeps nagging after its 3 days; `:270` `row.dueDay == today.key` excludes overdue to-dos that the field still shows (`field_providers.dart:55-58`). Fix: reuse the field's visibility rule (extract `isDueOn(commitment, today, weekDone, totals)` into domain and call it from both).

**Q-18 · Medium · Debt reminder body hand-formats money and shows the original amount**
`notification_planner.dart:206-208` `'${row.currency} ${row.amountMinor ~/ 100}'` drops minor units, bypasses `formatAmount`/locale, and ignores `DebtPayments` (remaining balance). Fix: compute remaining via the finances repository and format with the shared money formatter.

**Q-19 · Medium · Every commitment update re-requests OS permissions**
`lib/features/commitments/presentation/check_in_controller.dart:43-47,109-112` `_afterWrite(remindAt: commitment.remindAt)` → `requestPermission()` on each edit of any seed that has a reminder; on Android 12+ `requestExactAlarmsPermission()` opens a system settings page. Fix: request only when `remindAt` transitions null→set, after checking `canScheduleExact()`.

**Q-20 · Low · Channel id is used as the user-visible channel name**
`notifications.dart:248-249` `AndroidNotificationDetails(channelId, channelId, …)` → "reminders_alarm" appears in Android settings. Fix: pass localized names (`l10n` is already loaded by the planner).

**Q-21 · Low · Stored-snooze shape is encoded three times**
`notifications.dart:57-95` (`ReminderPayload.encode/decode`), `reminder_actions.dart:61-70` (map literal), `:112-128` (`_schedule` re-parses). Fix: persist `{when, payload: ReminderPayload.encode()}` and decode with the one decoder.

**Q-22 · Low · Unbounded id ranges; route strings duplicated**
`notification_planner.dart:193` debts from 3100, `:261` tasks from 2100 with no upper bound (doc at `reminder_actions.dart:21-22` says "21xx/31xx"); 1000+ task reminders would collide with debts, and a snoozed debt index 901 → `5000+3901 = 8901`… fine, but index 3901 → 9001 = pomodoro timer id. Route literals `'planner'|'finances'|'field'` at `notification_planner.dart:119,138,210` and `bootstrap.dart:45-49`. Fix: `ReminderIds.taskBase/taskMax` with a clamp, and a `ReminderRoutes` constant set.

**Q-23 · Low · Background job may lack plugin registration; failure would be invisible**
`day_reset.dart:26-41` `_dispatcher` never calls `DartPluginRegistrant.ensureInitialized()` (the snooze isolate does, `reminder_actions.dart:136`) before `NotificationService().schedule` → `FlutterLocalNotificationsPlugin`. If workmanager does not auto-register on this setup, every background `schedule` throws and is swallowed (Q-16). Verify on device; add the call.

---

## D. Riverpod

**Q-24 · Medium · Method-bag `AsyncNotifier`s with empty `build()` and no state**
`check_in_controller.dart:13-16` and `:36-39` `Future<void> build() async {}`; nothing reads their `AsyncValue`, so the UI cannot disable buttons or show errors (Q-07, Q-10, Q-27). Fix: either make them plain services (`@Riverpod(keepAlive: true) CheckInActions …`) or give them real state (`AsyncValue<void>` with `state = const AsyncLoading()` → `AsyncValue.guard`).

**Q-25 · Medium · `PomodoroController` reads config with `ref.read(...).value ?? default` at build time**
`lib/features/pomodoro/presentation/pomodoro_controller.dart:26-27`. On cold start the settings stream has not emitted, so `_advance` in `build()` (`:33`) computes catch-up boundaries with 25/5/15/4 even if the user set 50/10/20/2; later the getter reads a different value mid-session. Fix: `final config = await ref.watch(pomodoroConfigSettingProvider.future)` in `build()` and pass it explicitly to `_advance`.

**Q-26 · Medium · UI-facing providers live in the data layer; presentation imports data directly**
`gamification_repository.dart:117-149` defines `xpTotal`, `globalStreak`, `coinTotal`, `dailyActivity`, `weeklyXp` next to the repository; `field_providers.dart:2`, `check_in_controller.dart:4`, `streak_sheet.dart:7`, `field_screen.dart:28`, `onboarding_screen.dart:9` import `…/data/…` (onboarding bypasses `CommitmentEditor`, so its seeds skip `_afterWrite`). Fix: move the `@riverpod` view providers to `gamification/presentation/gamification_providers.dart`; onboarding calls `CommitmentEditor`.

**Q-27 · Medium · The signature check-in awaits `reevaluate()` before the UI celebrates**
`check_in_controller.dart:25-28` `await HarvestHaptics.thud(); await reevaluate();` — `reevaluate` does 2 aggregate queries, loads l10n from DB, cancels and re-schedules every task reminder (`notification_planner.dart:305-317`), and only then does `field_screen.dart:311-327` show the burst. Fix: return the result first and `unawaited(reevaluate())`.

**Q-28 · Low · Provider side effects and reads in build**
`bootstrap.dart:18-42` a `FutureProvider` mutates a singleton and navigates; `pomodoro_controller.dart:36-38` `build()` posts a notification; `router.dart:31` `redirect` uses `ref.read(onboardingDoneProvider)` with no `refreshListenable` (works only because onboarding calls `router.go` by hand); `crop_options_sheet.dart:36` and `pomodoro_screen.dart:47` read notifiers inside `build`. Acceptable today; document or move the navigation into a listener.

---

## E. Pomodoro

**Q-29 · Medium · Two 1 Hz tickers call `evaluate()` concurrently → duplicate XP possible**
`lib/features/pomodoro/presentation/pomodoro_screen.dart:30-33` and `lib/features/pomodoro/presentation/mini_timer_chip.dart:26-29` both run `Timer.periodic(1s)` and both are alive when the timer screen is pushed over the field (IndexedStack keeps `FieldScreen` mounted). `_advance` (`pomodoro_controller.dart:111-150`) is not guarded: two calls that read the same stale `state.value` past a focus boundary both run `completeBlock` (`:119`) → two `+5 XP` ledger rows. Fix: a single `Future? _inFlight` guard in the controller (`return _inFlight ??= _advance(...).whenComplete(() => _inFlight = null)`), and one clock source (a `Stream.periodic` provider) instead of per-widget timers; start the ticker only while `snapshot.isRunning`.

**Q-30 · Medium · Returning to the timer via the chip loses the attached crop**
`pomodoro_screen.dart:74` title and `:217` `_finish` use `widget.commitment` from `state.extra` (`router.dart:55`); `mini_timer_chip.dart:47,76` push without `extra`. A habit session resumed through the chip shows "Free session" and, on finish, never checks the habit in, even though `snapshot.commitmentUuid` is persisted. Fix: resolve the commitment from `snapshot.commitmentUuid` via `activeCommitmentsProvider`; drop the route `extra`.

**Q-31 · Low · Ongoing-notification title says "Short break" during a long break; resume label wrong after a pause**
`pomodoro_controller.dart:158-160` binary phase check; `pomodoro_screen.dart:181-183` shows `startFocus` for any paused snapshot with `blocksDone > 0`, although `waitingNextFocus` (`:57-60`) already distinguishes the cases. Fix: `switch` on all three phases; reuse `waitingNextFocus`.

**Q-32 · Low · Mini chip and timer screen rebuild every second even with no session**
`mini_timer_chip.dart:27` `setState` before checking `snapshot`; `pomodoro_screen.dart:31-32` same. The field's app bar rebuilds at 1 Hz forever. Fix: only tick while a snapshot exists and is running.

---

## F. Field, calendar, editor, onboarding

**Q-33 · Medium · "Skip" onboarding still plants two seeds and turns reminders on**
`lib/features/onboarding/presentation/onboarding_screen.dart:67` `_picked = {'read','fit'}`, `:69` `_remindersOn = true`, `:141-144` Skip → `_finish` which iterates `_picked` (`:107-116`) and enables reminders (`:118-122`). Fix: `_skip()` that only writes `OnboardingDone`.

**Q-34 · Medium · No failure feedback; pending flags stick**
`commitment_editor_sheet.dart:138` `setState(() => _saving = true)` with no `try/finally`; `onboarding_screen.dart:93` `_finishing`; `field_screen.dart:271-328` `_onTap` handles only `CheckInSuccess` (a capped/no-op tap gives nothing); `_showQuantitySheet` `:383-420` same. Any DB exception leaves a disabled button and an unhandled-zone error. Fix: `AsyncValue.guard` in the controllers (Q-24) + SnackBar on error + `finally { _saving = false }`.

**Q-35 · Medium · A habit row without a schedule crashes the field (`schedule!` ×3, `scheduleJson!` ×2)**
`commitment.dart:24-27` asserts in debug; `commitments_repository.dart:162-166` builds from DB regardless; `field_providers.dart:48`, `planner_screen.dart:28`, `calendar_screen.dart:55`, `streak_service.dart:260`, `notification_planner.dart:267`. Fix: model `HabitCommitment` with a non-null `Schedule` (sealed `Commitment` subtypes), validate at the repository boundary, fall back to `DailySchedule` with a log.

**Q-36 · Low · Calendar recomputes every visible day's entries per frame**
`calendar_screen.dart:114-120` `eventLoader` calls `_entriesFor` for each of 42 cells on every build and allocates `List<void>.filled(n, null)` to carry a count; `:102` `lastDay: DateTime.now()...` per build; `:109` `_focused = focused` mutates state without `setState`. Fix: memoize `Map<HarvestDay, int>` for the visible month in `build` (or a provider keyed by month).

**Q-37 · Low · Magic numbers / dates**
`commitment_editor_sheet.dart:354` `DateTime(2026, 9, 7)` "a Monday"; `:470,:526` and `calendar_screen.dart:102` `365 * 3`; `calendar_screen.dart:101` `DateTime(2024)`; `field_screen.dart:95` `96` FAB clearance; `pomodoro_screen.dart:82-83,93` `260/12`; `streak_service.dart:109,140` `.clamp(0, 1 << 31)` (use `math.max(0, …)`); `gamification_repository.dart:137` `182` days; `commitment_editor_sheet.dart:111-113` writes `"7:30"` while docs promise `"HH:mm"` (`database.dart:33`, `commitment.dart:52`). Fix: named constants; use `DateFormat.E().dateSymbols.STANDALONESHORTWEEKDAYS` for weekday chips; zero-pad the hour.

**Q-38 · Low · `Commitment.copyWith` cannot clear `dueDay`/`schedule`; editor relies on null = keep**
`commitment.dart:71-99` vs `commitment_editor_sheet.dart:203,206-207` `schedule: … ? schedule : null`. Works by accident; a future "convert type" path would silently keep stale fields. Fix: `clearDueDay`/`clearSchedule` flags or a `freezed` model.

---

## G. Structure, duplication, dead code

**Q-39 · Medium · Layering inversions**
`notification_planner.dart:4` domain imports `flutter/material.dart` (for `TimeOfDay`); `pomodoro_service.dart:7` domain imports `settings/data/settings_repository.dart`; `check_in_service.dart:6` ↔ `streak_service.dart:7-8` make `commitments` ⇄ `gamification` circular; `core/platform/day_reset.dart:3-4` (core) imports features; `field_screen.dart:26` imports `granary_screen.dart` for `budgetColor`. Fix: a `LocalTime(hour, minute)` value in domain; a `SettingsReader` interface in core consumed by both; move `budgetColor` to a finances domain/ui helper; move `DayResetJob` under `features/…/platform` or inject the job body.

**Q-40 · Medium · "Read a kv setting" is hand-rolled six times**
`streak_service.dart:41-49`, `notification_planner.dart:373-395` (two variants), `pomodoro_service.dart:140-147`, `l10n_loader.dart:9-16`, `reminder_actions.dart:24-31`, while `SettingsRepository.getString/watchString/watchAll` exist. `_boolSetting` (`notification_planner.dart:379-380`) accepts both JSON `true` and the string `'true'` because writers disagree on encoding. Fix: one typed `KvSettings` accessor with `getBool/getInt/getTime/getJson` and one encoding.

**Q-41 · Medium · 21 unused l10n keys** (`app_en.arb`, no usage anywhere in `lib/`): `todoOverdue`, `currencyLabel`, `remindersExpense`, `savingsLabel`, `expenseCurrencyLabel`, `savingsIn`, `amountPrompt`, `yes`, `no`, `debtsTitle`, `debtPayAmount`, `debtRemaining`, `recentMoves`, `txnWallet`, `txnSavings`, `nothingInVault`, `walletEmptyTitle`, `walletEmptyBody`, `savingsEmptyTitle`, `savingsEmptyBody`, `swipeToRemove`. Remove (in both arb files) or wire up (`todoOverdue` and `remindersExpense` look like intended features).

**Q-42 · Low · Duplicated helpers and oversized files**
"7 day keys from weekStart": `commitments_repository.dart:48-54` (O(49) nested loop) and `streak_service.dart:309-315` → add `HarvestDay.addDays(n)`/`weekDays`. `"HH:mm"` parsing appears in `notification_planner.dart:195-197,274-277,389-393` and `commitment_editor_sheet.dart:72-78` → one `LocalTime.tryParse`. `field_screen.dart` (573 lines: screen, header, crop tile, quantity sheet, celebration, tomorrow card, empty state) and `commitment_editor_sheet.dart` (575) mix concerns; `features/field/field_screen.dart` and `features/stats/stats_screen.dart` skip the `presentation/` folder every other feature uses. Stale comments: `shell.dart:8` "three main tabs" (there are four); `test/core/migration_test.dart:7-9` "matches schema v1".

**Q-43 · Low · Daily-quest remnants**: only the parked `Quests` table (`database.dart:97-110`, intentionally kept, documented). No l10n keys, providers or widgets remain — clean.

---

## H. Performance

**Q-44 · Medium · Lifetime aggregates are computed in Dart over the whole `check_ins` table on every write**
`commitments_repository.dart:38-42` `watchTotals()` selects every row ever and sums per commitment (`:68-78`); `watchLoggedOn` (`:31-35`) and `watchDoneDaysThisWeek` (`:55-65`) also fetch rows instead of aggregates; Drift re-runs all three on any `check_ins` change, and `todayField` (`field_providers.dart:28-71`) re-sorts on each. `gamification_repository.dart:63-77` loads 6 months of rows for the heat-map. Fix: `selectOnly` + `sum()/countDistinct` grouped by `commitmentUuid` in SQL; keep the field's list keyed (`_CropTile` uses no `key`, so the `flutter_animate` fade at `field_screen.dart:103-105` replays on reorder — add `key: ValueKey(uuid)`).

---

## I. Accessibility, theming, l10n

**Q-45 · Medium · Hard-coded English strings reach users of the Arabic locale**
`lib/core/ui/widgets/streak_flame.dart:19` `Semantics(label: 'Streak: $days days')`; `deadline_countdown.dart:21-23` `'5d 14h'`, `'14h 32m'`; `xp_bar.dart:35` `'$xp XP'`; `calendar_screen.dart:112` `'month'`. Fix: pass labels from `AppLocalizations` (`streakCurrent(days)` already exists); add plural-aware keys for the countdown units.

**Q-46 · Medium · Icon buttons without tooltips / no semantics on custom controls**
`field_screen.dart:53-56` (calendar), `mini_timer_chip.dart:44-47`, `planner_screen.dart:111-118` (close), `commitment_editor_sheet.dart:440-443,460-463` `IconButton`s have no `tooltip`; `CropCard` (`crop_card.dart:42-95`) exposes no "done/undone" or "long-press for options" semantics; `BigBouncyButton` (`big_bouncy_button.dart:58-108`) wraps `InkWell` in a `GestureDetector` with no `Semantics(button: true, enabled: …)`. Fix: tooltips everywhere; `Semantics(button: true, label: …, onLongPressHint: …)` on `CropCard`; `MergeSemantics` on the button.

**Q-47 · Low · Hard-coded white and low-alpha text**
`calendar_screen.dart:140` `Colors.white` on `colorScheme.primary` (use `onPrimary`); `big_bouncy_button.dart:53,95`, `hero_card.dart:33`, `icon_badge.dart:35` white on gradients — with the `orchard` preset (`tokens.dart:65` primary `#1FB25A`) white text is ≈2.6:1. Subtitles at `onSurface.withValues(alpha: 0.6)` (`crop_card.dart:78`, `theme.dart:216`, `field_screen.dart:163` 0.55, `field_screen.dart:193` 0.4) on `#FBF4E4` land near 4:1 for 12 sp text. Fix: `onSurfaceVariant`/`onPrimary`, alpha ≥0.7, verify the five presets with a contrast check in the golden test.

**Q-48 · Low · Small tap target**: streak flame in the app bar is icon 28 + 4 dp padding ≈ 36 dp (`field_screen.dart:60-67`). Wrap in a 48 dp `SizedBox`/`IconButton`.

---

## J. Tests

**Q-49 · High · Planner test asserts nothing; the whole scheduling engine is untested**
`test/features/planner/prime_time_test.dart:48-59` ends with `await planner.planToday(now: now);` and no `expect` (the comment admits it). `_primeTime` (median − 30 min, 7-day threshold, "today doesn't teach"), `_planRituals` on/off + goal-met suppression, `reevaluate` cancellations, `_planTaskReminders` due rules, `_planDebtReminders`, `_timeSetting` parsing — zero assertions. Fix: introduce a `NotificationGateway` interface with a recording fake; assert `(id, when, channel)` tuples.

**Q-50 · Medium · Pomodoro state machine has no tests**
Only `PomodoroService` persistence is covered (`test/features/pomodoro/pomodoro_service_test.dart`). Untested: `PomodoroController._advance` multi-boundary catch-up (focus→break→waiting), long-break cadence via `blocksPerLongBreak`, `pause` with negative remaining, `resume`, `finish` returning the commitment only when `blocksDone > 0`, `PomodoroSnapshot.remaining`. Fix: make `_advance` a pure function `advance(snapshot, config, now) → (snapshot, events)` and unit-test it.

**Q-51 · Medium · Other important logic without tests**
`StreakService.buyFreeze` (short balance / full shed / success), `_judgeHabit` `TimesPerWeekSchedule` Sunday branch, `onUndo` for habits, milestones 30/100, `productiveActions` project rule with `dailyCommitment` unmet; `CheckInService` to-do path and partial-cap XP; `todayField` visibility for habits (quota, paused, interval), completed projects, sort order; `tomorrowPlan`; `Commitment.copyWith` clear flags; `FieldItem.isDone/projectProgress`; `SnoozeStore.reapply` re-schedule count; `ReminderPayload.decode` with malformed `snooze` list; `HarvestDay.weekStart` across year boundary; `localizationsFromSettings`; router redirect.

**Q-52 · Medium · Brittle / wall-clock tests and private-key poking**
`test/features/commitments/today_field_test.dart:17` and `prime_time_test.dart:41-42` use `HarvestDay.today()`/`DateTime.now()` (and `todayField` cannot be injected — Q-01 fix solves both); `streak_service_test.dart:161` `expect(global!.freezesStored, 1 - 1)`; `vacation_mode_test.dart:26-32` and `streak_service_test.dart:69-75` duplicate `setLastJudged` and hard-code the private `'streak.lastJudgedDay'` (`streak_service.dart:37`). Fix: expose `StreakService.setLastJudgedForTest`/make the key public; share a test helper.

**Q-53 · Medium · Golden failure artifacts are committed**
`test/goldens/failures/*.png` (16 files) are tracked (`git ls-files`), `.gitignore` has no `failures` entry. Fix: `git rm -r test/goldens/failures`, add `test/**/failures/` to `.gitignore`.

**Q-54 · Low · Unit tests hit the real notifications plugin**
`prime_time_test.dart:16`, `snooze_store_test.dart:15` construct `NotificationService()`; output shows 5× `LateInitializationError` swallowed by Q-16. Same fix as Q-49.

---

## What is solid

- `HarvestDay` as a value type with the key computed at write time, `fromDate` vs `of` separation, and the boundary tests in `test/core/harvest_day_test.dart` — the rule is applied consistently across all tables.
- Ledger-as-source-of-truth for XP/coins (`database.dart:82-95`, `gamification_repository.dart:31-46`): no drifting counters.
- `StreakService.reconcile` is genuinely idempotent per day (two concurrent runs from the app and the background isolate converge), the freeze rule is implemented and tested, and `_judgeGlobal`'s "already earned live" guard prevents double-extension — `streak_service_test.dart` covers the key paths.
- `CheckInService` over-log cap (2× daily) with clear `CheckInSuccess/CheckInCapped` results and thorough tests; outbox rows appended in the same transaction.
- Pomodoro time is persisted as wall-clock instants (`PomodoroSnapshot`), so process death cannot corrupt a session; the ongoing notification uses the system chronometer instead of polling.
- Snooze design (`ReminderPayload` travelling in the notification payload, `SnoozeStore` on its own id range, re-applied after each replan) with tests, including the legacy route-only payload.
- Schema migrations v1→v7 all verified by `test/core/migration_test.dart`; the "just created" guards in `database.dart:283-284,297,305` are correct.
- Async-gap hygiene is good: `ScaffoldMessenger`/`Navigator`/`GoRouter` are captured before `await`s, `context.mounted` is checked where context is reused, `unawaited` is used deliberately, and timers/controllers are disposed.
- Theming through tokens + `ThemeExtension` (`HarvestGradients`), RTL-aware `EdgeInsetsDirectional`/`PositionedDirectional`, and goldens across light/dark × LTR/RTL.
- `very_good_analysis` with only three rules relaxed, and the analyzer is clean.


# Part 2 — finances, settings, stats, shared UI, l10n

Scope read in full: `lib/features/finances/**`, `lib/features/settings/**`, `lib/features/stats/**`, `lib/core/ui/**`, both ARB files, `test/features/finances/*`. Generated files ignored.

## Correctness

**F-01 · High · `lib/features/finances/data/vault_repository.dart:167-186` — debt cards go stale after a partial payment**
```dart
return query.watch().asyncMap((rows) async {
  final paid = await _paidByDebt();
```
A Drift select stream re-emits only for its own table (`select.dart`: `watchedTables => {table}`), i.e. `debts`. `payDebt` (253-300) writes to `debts` only when the debt settles (288-298). A partial payment inserts into `debt_payments`/`money_txns`/`outbox` and never touches `debts`, so `debtsProvider` does not re-emit: `paidMinor`, `remainingMinor`, the progress bar and `vaultTotals.owed` stay stale until something else updates the `debts` table. `vault_test.dart:115-136` passes only because each assertion re-subscribes (`watchDebts().first`).
Fix: one query with a LEFT JOIN on a `GROUP BY debt_uuid` subquery, or `customSelect(..., readsFrom: {debts, debtPayments})`, or combine `watchDebts` with `watchDebtPayments` (StreamZip). Add a regression test that keeps a single subscription open across two payments.

**F-02 · High · `lib/features/finances/presentation/expense_sheet.dart:190-207`, `granary_screen.dart:201`, `vault_tab.dart:472-487` — wallet-funded expenses are unlinked and non-atomic**
`repo.log(...)` followed by a separate `vaultRepositoryProvider.move(kind: TxnKind.expense, reference: _category)`. Two transactions; if the second fails the expense exists but the wallet was not debited. Worse: `remove(expense.uuid)` (swipe-delete) and `updateExpense` (expense_sheet.dart:182) never touch the money txn — deleting or editing a wallet-funded expense leaves the wallet permanently reduced by the old amount. `reference` stores the category, not the expense uuid, so the link cannot be recovered. Same shape in `_withdraw` (vault_tab.dart:472-487: `vault.move` then `financesRepository.log`).
Fix: `FinancesRepository.log({fromWallet})` writing both rows in one transaction with `reference: expenseUuid` (or a real `expenseUuid` column, schema v7); `remove` soft-deletes the linked txn; `updateExpense` adjusts it. Same for withdraw-as-expense.

**F-03 · High · `expense_sheet.dart:175-210`, `debt_sheet.dart:64-79` — `ref` used after the sheet is popped**
```dart
Navigator.of(context).pop();
final repo = ref.read(financesRepositoryProvider);
...
await repo.log(...);
if (fromWallet) { await ref.read(vaultRepositoryProvider).move(...) }   // line 197
await HarvestHaptics.thud();
await ref.read(notificationPlannerProvider).reevaluate();               // line 210
```
Riverpod 3.4.2 `WidgetRef.read` calls `_assertNotDisposed()` and throws `StateError` once `!context.mounted` (`flutter_riverpod/lib/src/core/consumer.dart:468-476`). The sheet is unmounted when its ~200 ms exit animation ends; any await that outlasts it makes the *next* `ref.read` throw — the wallet move is skipped silently (uncaught async error, no UI feedback). `debt_sheet.dart:78-79` has the same pattern after `await createDebt`.
Fix: resolve every provider into locals before `pop()`, or pop after the writes, or move the flow into a notifier/service (see F-36).

**F-04 · Medium · `finance_providers.dart:22-32, 226, 275` — day-bound providers never roll over**
`watchDay(HarvestDay.today())`, `watchMonth(HarvestDay.today())`, `watchWeek(HarvestDay.today().weekStart)` capture the day when the provider builds. They are kept alive by the Today tab and by `field_screen.dart:44` (`budgetSnapshotProvider`). No `invalidate`, `refresh`, or `didChangeAppLifecycleState` exists anywhere in `lib/` (grep). An app left open across 03:00 shows yesterday's log, gauge and repeat suggestion.
Fix: a keepAlive `currentDayProvider` (timer to `today.next.startsAt` + resume hook) that these providers watch.

**F-05 · Medium · `vault_tab.dart:244-258, 649-679`, `expense_sheet.dart:141-151` — wallet can go negative silently**
`_walletMove(deposit: false)` opens `showMoneySheet` with no `maxMinor`; the debt "pay from wallet" and expense "take from wallet" choices show the balance only as a `hint`. `VaultRepository.move` has no guard. Negative balances then render as `DA-1,500` (`money.dart:16` NumberFormat uses ASCII minus after the symbol, unlike `formatSigned`'s U+2212).
Fix: either pass `maxMinor: balances` (as savings already does) or model overdraft explicitly and format with `formatSigned`.

**F-06 · Medium · `vault_repository.dart:253-300` — `payDebt` validates nothing**
Accepts zero/negative amounts, overpayments (hidden by `vault.dart:85` `remainingMinor => (amountMinor - paidMinor).clamp(0, amountMinor)` and `paidFraction` clamp), and payments on already-settled debts (only `settledAt == null` gates the settle write). `getSingle()` at 261-263 ignores `deletedAt`. Always stamps `HarvestDay.today()` (271) — no `day` param, unlike `move`.
Fix: throw on `amountMinor <= 0`, reject (or clamp) beyond remaining, reject settled/deleted, add `day`.

**F-07 · Medium · `lib/features/finances/domain/expense.dart:131-135`, `granary_screen.dart:274-277` — limit-0 status is wrong**
```dart
if (spentToday >= 0.85 * floatingDailyLimit) return BudgetStatus.close;
```
With `floatingDailyLimit == 0` and `spentToday == 0` this returns `close` (yellow) though the month is overspent; the gauge forces `progress: 1` (full ring) even with nothing spent today. `finances_test.dart:41-50` only checks `spentToday: 500`.
Fix: when the limit is 0 return `over` if `spentThisMonth > monthlyBudget` else `under`; add the test.

**F-08 · Low · `lib/features/finances/presentation/money.dart`**
- `:12` `NumberFormat('#,##0.##')` → 1250 renders `DA12.5`, while `formatMinor(1250)` is `12.50`; inconsistent money display.
- `:5-10` `formatMinor(-50)` → `"0.50"` (sign lost: `-50 ~/ 100 == 0`, `-50 % 100 == 50`). Not reachable today; a trap.
- `:28-45` `parseToMinor`: `"+5"` → 500 (int.tryParse accepts the sign), `"1,5"` → 150 (comma treated as decimal, so `"1,234"` and `"1.234"` are rejected), Arabic-Indic digits rejected (Arabic keyboards can emit them), `major * 100` unchecked overflow. `"1e3"`, `".5"`, `"12."` correctly rejected.
Fix: use `'#,##0.00'` (strip only `.00`), normalize Arabic digits, reject a leading `+`, cap magnitude, and test each case.

**F-09 · Low · `lib/features/finances/domain/currency.dart:43,58`** — `(minor * factor).round()` throws `UnsupportedError` for Infinity/NaN; `1 / usdPerEur!` yields Infinity for a stored `0`. `rates_card._saveManual` guards `<= 0` (rates_card.dart:47) but `ratesProvider` (finance_providers.dart:160-162) and the fetched rate (rates_service.dart:31-33) are stored unvalidated. Treat `<= 0`/non-finite as `null` inside `Rates`.

**F-10 · Low · `finances_repository.dart:129`** — `notes[key] = row.note;` last row of an unordered 4-day query wins, so the suggested note may be today's or three days old. Order by `loggedAt` desc or take the note from `days[0]`.

**F-11 · Low · 9× `const Rates(defaultCurrency: Currency.dzd)`** (e.g. `finance_providers.dart:197`, `vault_tab.dart:158`) — if the default is USD and the rates stream has not emitted yet, sums convert into DZD and `conversionCaption` compares against the wrong currency for a frame. Seed `ratesProvider` from `financeSettingsProvider`, or expose one `ratesOrDefault` derived provider.

**F-12 · Low · `settings_repository.dart:27 vs 44`** — `watchString` does `jsonDecode(...) as String` while `watchAll` does `.toString()`; a non-string value crashes one path and not the other.

**F-13 · Low · `finances_repository.dart:34`** — `harvestDay.like('$prefix%')` is correct but defeats the index; use `>= 'yyyy-MM-01' & < next-month`.

Verified OK: `_transfer` **is** atomic — Drift ≥2.0 turns nested `transaction()` calls into savepoints (`drift/lib/src/runtime/api/connection_user.dart:460-501`), so both legs plus both outbox rows commit or roll back together.

## Error handling

**F-14 · Medium · presentation writes are never guarded** — scope has 1 `try` (rates_service) and 0 `catch` in widgets. `granary_screen.dart:201` `unawaited(ref.read(financesRepositoryProvider).remove(expense.uuid))` fires after the row is already gone; `_walletMove`, `_deposit`, `_withdraw`, `_pay`, `_RepeatCard.onPressed` (granary 558-568) all `await` repository writes with no handler. A failure is an uncaught async error while the UI has already moved on. Fix: one `runGuarded(context, future)` helper that surfaces a snackbar; for the Dismissible use `confirmDismiss` and await the delete.

**F-15 · Low · `rates_service.dart:26-41`** — `http.get` is a static call (not injectable, untestable); `on Object { return null; }` maps JSON-shape errors and the DB write failure to "fetch failed" with no logging. Inject `http.Client`, catch `SocketException`/`TimeoutException`/`FormatException`, log the rest.

**F-16 · Low · `rates_card.dart:45-49, 113-115, 128-130`** — `_saveManual` silently ignores invalid text; `onTapOutside` writes on every outside tap; there is no way to clear a manual rate.

## Riverpod

**F-17 · Medium · `settings_screen.dart:339`** — `final notifier = ref.read(pomodoroConfigSettingProvider.notifier);` inside `build`. Move into the callbacks.

**F-18 · Medium · `rates_card.dart:14-21` and `finance_providers.dart:153-155`** — two providers stream the same keys, and `ratesProvider` uses string literals `'rate.dzdPerUsd'` … instead of `RateKeys.*`. Two sources of truth; use the constants and one provider.

**F-19 · Low · `expense_sheet.dart:254, 269`** — `ref.watch(financeSettingsProvider)` twice inline in `build`, plus `ref.read` of the same at 139 and 179 (the `currency` expression is computed twice in `_log`). Compute once.

**F-20 · Low · `finance_providers.dart:250-255, 123-129, 263-265`, `granary_screen.dart:105-110`** — `savingsHealth` re-implements `accountBalancesProvider(savings)` filtering inline; the "convert or face value" sum loop appears three times. Add `Rates.toDefaultOrFace` and `sumInDefault`.

**F-21 · Low · `finance_charts.dart:40-45`** — conditional watch of week/month providers disposes and re-queries the other on every toggle. `granary_screen.dart:516` `_RepeatCard` re-watches `customCategoriesProvider` although `_TodayTab` already holds `customs`.

**F-22 · Low · `rates_card.dart:71-75`** — controllers seeded inside `build` behind a `_seeded` flag (side effect in build). Use `ref.listen` or `initState` + `ref.read`.

## Duplication

**F-23 · Medium** — `ref.watch(financeSettingsProvider).value?.defaultCurrency ?? Currency.dzd` ×12 and `const Rates(defaultCurrency: Currency.dzd)` ×9 across scope. Add `defaultCurrencyProvider` and `ratesOrDefaultProvider`.

**F-24 · Medium** — bottom-sheet scaffolding copied 4× (`money_sheet.dart:100-115`, `debt_sheet.dart:88-104`, `expense_sheet.dart:224-239`, `granary_screen.dart:428-445`): identical `EdgeInsets.only(left: lg, right: lg, bottom: viewInsets + lg)` + `Text(title, headlineSmall w800)` + `BigBouncySheetButton`. Extract `HarvestSheet(title, children, action)`.

**F-25 · Medium** — `SegmentedButton<Currency>` copied 4× (`money_sheet.dart:155-165`, `debt_sheet.dart:129-137`, `expense_sheet.dart:259-276`, `granary_screen.dart:470-481`). Extract `CurrencyPicker`.

**F-26 · Medium** — `IntrinsicHeight(Row(Expanded(StatTile)×3))` copied in `vault_tab.dart:72-110`, `stats_screen.dart:57-89`, `finance_charts.dart:77-100` → `StatTileRow`. Category breakdown implemented three ways: `stats_screen._SpendingBreakdown` (281-344), `finance_charts._CategoryDonut` (244-335), `_WeeklyReportCard` top-category loop (379-386).

**F-27 · Low** — `DateTime(d.year, d.month, d.day)` ×5 (`debt_sheet.dart:145-149`, `vault_tab.dart:732`, `ledger_row.dart:145`, `stats_screen.dart:373`, `finance_charts.dart:208`) → `HarvestDay.toDateTime()`. `Localizations.localeOf(context).toString()` ×8, `DateFormat.jm(locale).format(...)` ×3 → `formatTime(context, dt)`. `'${hour}:${minute.padLeft(2,'0')}'` duplicated `debt_sheet.dart:74-75` / `settings_controllers.dart:112`.

**F-28 · Low** — `totalsByDay`/`totalsByCategory` (`finance_providers.dart:171-192`) plus four near-identical providers (195-216) → one `_totalsBy(expenses, rates, keyOf)`. Reminder defaults duplicated `settings_screen.dart:31-36` vs `settings_controllers.dart:82-89`; `?? 3` at `settings_screen.dart:23` and `stats_screen.dart:31` instead of `StreakService.defaultGoal`.

**F-29 · Low · `vault_tab.dart:166-224, 286-351, 534-574`** — three hero headers with the same IconBadge + Eyebrow + `_Balances` + `_HeroAction` layout → `_PotHero`.

## Dead code

**F-30 · Low · `finance_providers.dart:88-90`** — `recentTxnsProvider` has zero consumers; `VaultRepository.watchRecentTxns` (59-60) is used only by it and `vault_test.dart:64`.

**F-31 · Low · `finance_providers.dart:17-18`** — `FinanceKeys.savingsFor` is a pre-vault leftover with no callers.

**F-32 · Low · `finance_charts.dart:253`** — `final List<dynamic> customs;` on `_CategoryDonut` is never read (and typed `dynamic`). Drop it and the argument at 134.

**F-33 · Low** — `InsightsTab` (`granary_screen.dart:620-625`) is a pass-through for `FinanceInsights`; `IconBadge.filled` (`icon_badge.dart:11`) is never set (the only `filled: true` hit is `InputDecorationTheme`, theme.dart:97); `LedgerRow.onLongPress` (`ledger_row.dart:20`) and `HeroCard.gradient` (`hero_card.dart:10`) are never passed; `SavingsHealth.healthy`/`unknown` are never distinguished (only `== low` at `vault_tab.dart:60, 281`); `export … show showDebtSheet` (`vault_tab.dart:27-28`) has no external consumer.

**F-34 · Low · unused l10n keys (present in both ARBs, zero references in non-generated `lib/`)** — 19: `todoOverdue`, `currencyLabel`, `remindersExpense`, `savingsLabel`, `expenseCurrencyLabel`, `savingsIn`, `amountPrompt`, `debtsTitle`, `debtPayAmount`, `debtRemaining`, `recentMoves`, `txnWallet`, `txnSavings`, `nothingInVault`, `walletEmptyTitle`, `walletEmptyBody`, `savingsEmptyTitle`, `savingsEmptyBody`, `swipeToRemove`. EN and AR key sets are identical (292 each); no key is used but missing from either file.

**F-35 · Low** — `l10n.avgPerDay('')` (`finance_charts.dart:94`) passes an empty placeholder to `"{amount} / day"` (renders `" / day"`); `stats_screen.dart:137-146` does `projectSubtitle(...).split('·').first.trim()` — breaks the moment a translator changes the separator. Add dedicated keys.

## Structure

**F-36 · Medium** — money flows live in widgets: `vault_tab.dart` `_deposit` (365-423), `_withdraw` (426-490), `_pay` (634-681); `expense_sheet.dart` `_log` (126-211) orchestrates two repositories, the planner and haptics. `vault_tab.dart` is 1071 lines, `granary_screen.dart` 625 (hosts `_BudgetSheet` and `_ManageCategories`). Introduce a `FinanceActions`/service with `logExpense(fromWallet)`, `withdrawAsExpense`, `payDebt(fromWallet)` each as one transaction (also fixes F-02/F-03); split `vault_tab.dart` into `wallet_section.dart`, `savings_section.dart`, `debts_section.dart`, `vault_widgets.dart`; move `_BudgetSheet` to `budget_sheet.dart`.

**F-37 · Low** — presentation imports data directly (`granary_screen.dart:14`, `vault_tab.dart:13-14`, `expense_sheet.dart:9-10`, `debt_sheet.dart:10`, `rates_card.dart:6`, `stats_screen.dart:15`) because provider definitions live in the data files. Tolerable now; once F-36 exists, widgets should import only the service.

**F-38 · Low · naming/placement** — `budgetColor` is a public top-level in `granary_screen.dart:26` consumed by `field_screen.dart:175`; `parseToMinor`/`Rates` display helpers in `presentation/money.dart` are domain logic; `presetCategoryKeys` (`expense.dart:19-20`) is a mutable global `final List`.

## UI code quality

**F-39 · Medium · `granary_screen.dart:188-208`** — `Dismissible` deletes immediately: no `confirmDismiss`, the snackbar is 1 s (`duration: Duration(seconds: 1)`) and has no Undo. Add an Undo action (clear `deletedAt`) or confirm.

**F-40 · Medium · RTL / i18n** — `Icons.chevron_right` (`choice_sheet.dart:93`) does not mirror in Arabic (use `Icons.arrow_forward_ios`, which has `matchTextDirection`). `_DailyBars` orders Mon→Sun left-to-right regardless of direction (`finance_charts.dart:166-178`, fl_chart does not mirror); `_HeatMap` `reverse: true` (`stats_screen.dart:227`) flips its origin under RTL. Word order hard-coded in Dart: `money_sheet.dart:149` `'${l10n.amountLabel} ≤ …'`, `vault_tab.dart:787` `'${l10n.debtPayments} · ${payments.length}'`, `vault_tab.dart:1048`, `granary_screen.dart:301-303`; `formatAmount` always prefixes the symbol (`DA1,080`) even in Arabic. The four sheets use `EdgeInsets.only(left:, right:)` (symmetric, so harmless — but write `symmetric(horizontal:)`).

**F-41 · Medium · accessibility** — a single `Semantics(` in scope (`streak_flame.dart:18`, with an untranslated `'Streak: $days days'`). `StatTile` acts as a tab selector (`vault_tab.dart:77-106`) with no `selected`/button semantics; `_HeroAction` disabled state is `Opacity(opacity: onTap == null ? 0.45 : 1)` only (`vault_tab.dart:918`); `GaugeRing` and every `LinearProgressIndicator` lack `semanticsLabel`; `_PresetSwatch` (`settings_screen.dart:380`) has no selected label. Low-contrast text: hint at alpha 0.25 (`money_sheet.dart:141`), affordance icons at 0.4 (`choice_sheet.dart:95`, `granary_screen.dart:327`).

**F-42 · Low · tokens bypassed / magic numbers** — `Colors.white` at `vault_tab.dart:174, 917` while `HeroCard` already injects the foreground via `IconTheme`/`DefaultTextStyle`. 71 `withValues(alpha:` literals in scope (0.6 ×11, 0.65 ×5, 0.55 ×4, 0.08 ×7) with no `HarvestAlpha.muted/subtle/track` tokens; token arithmetic `HarvestSpacing.sm + 4` etc. ×10 (`ledger_row.dart:49,53`, `vault_tab.dart:592,716`, …). Raw sizes: 120 bottom padding (`granary_screen.dart:116`, `finance_charts.dart:56`), 92/9 gauge (`granary 278-279`), 280 (`expense_sheet.dart:343`), 88 (`stats_screen.dart:309`), 140/180 (`finance_charts.dart:119,275`), 14/1.5/4 heat cells (`stats 235-240`). `Opacity` widgets on hot paths (`vault_tab.dart:880, 918`) — prefer color alpha.

**F-43 · Low** — `_HeatMap` doc says "Ten weeks" (`stats_screen.dart:197`) but spans 181 days (:210). `_Empty` takes `l10n`/`theme` via constructor (`stats_screen.dart:261-265`). `deadline_countdown.dart:58-61` cancels and recreates a periodic `Timer` on every tick.

**F-44 · Low · missing keys** — `for (final debt in open) Padding(child: _DebtCard(...))` (`vault_tab.dart:590-604`) and rows from `groupByDay` (`ledger_row.dart:152-168`) have no `ValueKey`; safe today because the rows are stateless, fragile if that changes.

## Tests

**F-45 · Medium · logic without any test** — `formatGrouped`, `formatAmount`, `formatSigned`, `conversionCaption`; `parseToMinor` edge cases (F-08); `Rates._factor` cross-rate via DZD when the default is USD/EUR and `usdPerEur` is absent, non-finite inputs; `BudgetSnapshot.status` at limit 0 and at the exact 85 % boundary with rounding; `budgetSnapshotProvider` before/today split; `savingsHealth`; `vaultTotals`; `accountBalances` zero-dropping; `transferWalletToSavings`; `_transfer` rollback when the second leg throws; `payDebt` overpay/negative/settled/deleted and `fromWallet` currency; `watchDebts` re-emission on partial pay (F-01); `deleteCategory`; `updateExpense` outbox op; `repeatSuggestion` note choice; `RatesService.fetchEurUsd` (needs client injection); `ReminderSettings` time parsing; `SettingsRepository.watchAll` with non-string JSON; `_elapsedDays`; `_WeeklyReportCard` best/worst; `_HeatMap` grid. No widget tests for any sheet.

**F-46 · Low · brittleness** — `payDebt` (`vault_repository.dart:271`) and transfers (via `move`'s default at :98) stamp `HarvestDay.today()`, so tests cannot pin the day; `vault_test.dart:106` `[-200, 500]` depends on same-second `loggedAt` and the `rowId` tiebreak; `expense_update_test.dart:46` hard-codes "Monday 2026-08-31"; `currency_test.dart:47` `contains(r'$8')` would also match `$80`.

## What is solid

- Money is integer minor units end to end; `Rates.toDefault` returns `null` on unknown rates and every aggregate documents its face-value fallback.
- `HarvestDay` is a proper value type (3 AM boundary, `startsAt`, `weekStart`, stable `key`), and week/month range queries are built from it correctly (`watchWeek` enumerates exactly seven keys).
- `_transfer` and `payDebt` are genuinely atomic (Drift savepoints), and every write appends its outbox row inside the same transaction.
- Soft-delete is honoured on every read path (`deletedAt.isNull()` in all selects and in `_paidByDebt`); XP is idempotent per day via the `expenses:<day>` ledger reason.
- `money_sheet` enforces per-currency caps (`maxMinor`) and locks the currency where it must; `_paidByDebt` is recomputed inside the transaction after the insert, so settlement is computed on committed data.
- Theme is fully token-driven (`HarvestPalette`, `HarvestGradients` extension, radii/spacing tokens); directional alignment/insets are used almost everywhere (0 `TextAlign.left/right`, 1 unmirrored icon).
- EN/AR ARBs are in sync; `const` constructors are used consistently; `Dismissible` and section switches are keyed; repository logic has real in-memory-DB tests.
