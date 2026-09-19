import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/app/app.dart';
import 'package:harvest/core/platform/day_reset.dart';
import 'package:harvest/features/onboarding/presentation/onboarding_screen.dart';
import 'package:harvest/features/security/domain/app_lock.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) unawaited(DayResetJob.register());

  // Decide onboarding and the app lock before the first frame, so the
  // router never flashes the wrong screen and a locked app never
  // flashes its contents on the way up.
  final container = ProviderContainer();
  final settings = container.read(settingsRepositoryProvider);
  final done = await settings.getString(OnboardingDone.key);
  container.read(onboardingDoneProvider.notifier).set(done: done == 'true');
  final locked = await settings.getBool(SettingKeys.appLock) ?? false;
  container.read(appLockProvider.notifier).start(enabled: locked);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const HarvestApp(),
    ),
  );
}
