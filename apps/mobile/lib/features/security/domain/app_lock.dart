import 'dart:async';

import 'package:harvest/features/security/data/screen_guard.dart';
import 'package:harvest/features/security/domain/auth_gateway.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_lock.g.dart';

/// How long the app may sit in the background before it asks again.
///
/// Short enough that a phone left on a table re-locks, long enough that
/// glancing at a notification or grabbing a photo does not (rule L3).
const lockGrace = Duration(seconds: 30);

/// Where the shield is.
enum AppLockPhase {
  /// Open for business.
  unlocked,

  /// The app left the foreground, so the shield is up for the app
  /// switcher's snapshot (rule L4) — but it lifts by itself if we come
  /// back inside [lockGrace].
  covered,

  /// The prompt is owed before anything else happens.
  locked,
}

/// The lock as the UI needs it: whether it is armed at all, where the
/// shield is, and why the last attempt did not open it.
typedef AppLockState = ({
  bool enabled,
  AppLockPhase phase,
  AuthOutcome? lastOutcome,
  bool prompting,
});

/// The clock the grace window is measured against; overridden in tests.
@Riverpod(keepAlive: true)
DateTime Function() lockClock(Ref ref) => DateTime.now;

/// The app lock's phase machine.
///
/// It deliberately knows nothing about widgets or plugins: lifecycle
/// events and the device's answer come in, a phase comes out. That is
/// what makes rules L3, L4 and L6 testable without a real thumb.
@Riverpod(keepAlive: true)
class AppLock extends _$AppLock {
  /// When the app last left the foreground; null while it is showing.
  DateTime? _hiddenAt;

  /// True while the device's own prompt is on screen. The prompt takes
  /// the foreground away from us on some devices, and reacting to that
  /// would re-cover the app underneath its own dialog.
  var _prompting = false;

  @override
  AppLockState build() => (
    enabled: false,
    phase: AppLockPhase.unlocked,
    lastOutcome: null,
    prompting: false,
  );

  /// Seeds the lock from the stored setting before the first frame, so
  /// a locked app never flashes its contents on the way up.
  void start({required bool enabled}) {
    state = (
      enabled: enabled,
      phase: enabled ? AppLockPhase.locked : AppLockPhase.unlocked,
      lastOutcome: null,
      prompting: false,
    );
    unawaited(_guard(enabled));
  }

  /// Keeps the platform's secure-window flag in step with the switch.
  Future<void> _guard(bool secure) =>
      ref.read(screenGuardProvider).setSecure(secure: secure);

  /// Turns the lock on or off, asking the device first.
  ///
  /// Returns false when the device has nothing to check against, in
  /// which case nothing is stored and the switch stays off (rule L5).
  Future<bool> setEnabled({required bool value}) async {
    if (value && !await ref.read(authGatewayProvider).canAuthenticate()) {
      state = (
        enabled: false,
        phase: AppLockPhase.unlocked,
        lastOutcome: AuthOutcome.noCredentials,
        prompting: false,
      );
      return false;
    }
    await ref
        .read(settingsRepositoryProvider)
        .setBool(SettingKeys.appLock, value: value);
    await _guard(value);
    state = (
      enabled: value,
      // Turning it on must not lock me out of the screen I turned it on
      // from; the next cold start is the first time it asks.
      phase: AppLockPhase.unlocked,
      lastOutcome: null,
      prompting: false,
    );
    return true;
  }

  /// The app left the foreground: raise the shield and start the clock.
  void onHidden() {
    if (!state.enabled || _prompting) return;
    _hiddenAt = ref.read(lockClockProvider)();
    if (state.phase == AppLockPhase.unlocked) {
      state = (
        enabled: true,
        phase: AppLockPhase.covered,
        lastOutcome: null,
        prompting: false,
      );
    }
  }

  /// The app is back. Inside the grace window the shield simply lifts;
  /// past it, the prompt is owed.
  void onShown() {
    if (!state.enabled || _prompting) return;
    if (state.phase != AppLockPhase.covered) return;
    final hiddenAt = _hiddenAt;
    final away = hiddenAt == null
        ? lockGrace
        : ref.read(lockClockProvider)().difference(hiddenAt);
    _hiddenAt = null;
    state = (
      enabled: true,
      phase: away < lockGrace ? AppLockPhase.unlocked : AppLockPhase.locked,
      lastOutcome: null,
      prompting: false,
    );
  }

  /// Shows the device's prompt and opens up if it says yes.
  ///
  /// [reason] is the localized line the OS shows; the domain has no
  /// business knowing the app's strings, so the gate passes it in.
  Future<void> unlock({required String reason}) async {
    if (_prompting || state.phase != AppLockPhase.locked) return;
    _prompting = true;
    state = (
      enabled: state.enabled,
      phase: AppLockPhase.locked,
      lastOutcome: null,
      prompting: true,
    );
    try {
      final outcome = await ref
          .read(authGatewayProvider)
          .authenticate(reason: reason);
      // A device that has lost every credential while the lock was on
      // would otherwise be a locked door with no key: disarm instead.
      final disarm = outcome == AuthOutcome.noCredentials;
      if (disarm) {
        await ref
            .read(settingsRepositoryProvider)
            .setBool(SettingKeys.appLock, value: false);
        await _guard(false);
      }
      state = (
        enabled: !disarm && state.enabled,
        phase: outcome == AuthOutcome.unlocked || disarm
            ? AppLockPhase.unlocked
            : AppLockPhase.locked,
        lastOutcome: outcome == AuthOutcome.unlocked ? null : outcome,
        prompting: false,
      );
    } finally {
      _prompting = false;
    }
  }
}
