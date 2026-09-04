import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/features/security/data/screen_guard.dart';
import 'package:harvest/features/security/domain/app_lock.dart';
import 'package:harvest/features/security/domain/auth_gateway.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_screen_guard.dart';

/// The lock's rules, checked against a fake thumb (checkpoint C2-1).
void main() {
  late HarvestDatabase db;
  late FakeAuthGateway auth;
  late FakeScreenGuard guard;
  late ProviderContainer container;
  late DateTime now;

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    auth = FakeAuthGateway();
    guard = FakeScreenGuard();
    now = DateTime(2026, 9, 4, 12);
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        authGatewayProvider.overrideWithValue(auth),
        screenGuardProvider.overrideWithValue(guard),
        lockClockProvider.overrideWithValue(() => now),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  AppLock lock() => container.read(appLockProvider.notifier);
  AppLockState state() => container.read(appLockProvider);

  test('an app with the lock off is never covered', () {
    lock().start(enabled: false);
    lock().onHidden();
    lock().onShown();

    expect(state().phase, AppLockPhase.unlocked);
  });

  test('a cold start with the lock on comes up locked (rule L3)', () {
    lock().start(enabled: true);

    expect(state().phase, AppLockPhase.locked);
  });

  test('leaving the foreground raises the shield at once (rule L4)', () async {
    lock().start(enabled: true);
    await lock().unlock(reason: 'test');

    lock().onHidden();

    // The app switcher's snapshot is taken of this, not of the field.
    expect(state().phase, AppLockPhase.covered);
  });

  test('coming back inside the grace window just lifts the shield', () async {
    lock().start(enabled: true);
    await lock().unlock(reason: 'test');
    expect(state().phase, AppLockPhase.unlocked);

    lock().onHidden();
    expect(state().phase, AppLockPhase.covered);

    now = now.add(lockGrace - const Duration(seconds: 1));
    lock().onShown();

    expect(state().phase, AppLockPhase.unlocked);
  });

  test('coming back past the grace window asks again (rule L3)', () async {
    lock().start(enabled: true);
    await lock().unlock(reason: 'test');
    lock().onHidden();

    now = now.add(lockGrace + const Duration(seconds: 1));
    lock().onShown();

    expect(state().phase, AppLockPhase.locked);
  });

  test('a refused prompt leaves the app locked (rule L6)', () async {
    auth.outcome = AuthOutcome.refused;
    lock().start(enabled: true);

    await lock().unlock(reason: 'test');

    expect(state().phase, AppLockPhase.locked);
    expect(state().lastOutcome, AuthOutcome.refused);
  });

  test('the prompt is never shown twice at once', () async {
    auth.gate = true;
    lock().start(enabled: true);

    final first = lock().unlock(reason: 'test');
    await lock().unlock(reason: 'test');
    auth.release();
    await first;

    expect(auth.calls, 1);
  });

  test('lifecycle events during the prompt do not re-cover the app', () async {
    auth.gate = true;
    lock().start(enabled: true);

    final pending = lock().unlock(reason: 'test');
    // Some devices hand the foreground to the biometric prompt.
    lock()
      ..onHidden()
      ..onShown();
    auth.release();
    await pending;

    expect(state().phase, AppLockPhase.unlocked);
  });

  test('the switch refuses to arm with nothing enrolled (rule L5)', () async {
    auth.available = false;

    final took = await lock().setEnabled(value: true);

    expect(took, isFalse);
    expect(state().enabled, isFalse);
    expect(state().lastOutcome, AuthOutcome.noCredentials);
    expect(await SettingsRepository(db).getBool(SettingKeys.appLock), isNull);
  });

  test(
    'arming stores the setting without locking me out of Settings',
    () async {
      final took = await lock().setEnabled(value: true);

      expect(took, isTrue);
      expect(state().enabled, isTrue);
      expect(state().phase, AppLockPhase.unlocked);
      expect(await SettingsRepository(db).getBool(SettingKeys.appLock), isTrue);
    },
  );

  test('arming hides the app from the recents thumbnail (rule L4)', () async {
    await lock().setEnabled(value: true);
    expect(guard.secure, isTrue);

    await lock().setEnabled(value: false);
    expect(guard.secure, isFalse);
  });

  test('a locked cold start is secure before the first frame', () {
    lock().start(enabled: true);

    expect(guard.secure, isTrue);
  });

  test(
    'losing every credential disarms rather than stranding the app',
    () async {
      await lock().setEnabled(value: true);
      lock().start(enabled: true);
      auth.outcome = AuthOutcome.noCredentials;

      await lock().unlock(reason: 'test');

      expect(state().phase, AppLockPhase.unlocked);
      expect(state().enabled, isFalse);
      expect(guard.secure, isFalse);
      expect(
        await SettingsRepository(db).getBool(SettingKeys.appLock),
        isFalse,
      );
    },
  );
}
