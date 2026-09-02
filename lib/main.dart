import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/app/app.dart';
import 'package:harvest/core/platform/day_reset.dart';
import 'package:harvest/features/onboarding/presentation/onboarding_screen.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) unawaited(DayResetJob.register());

  // Decide onboarding before the first frame so the router never flashes
  // the wrong screen.
  final container = ProviderContainer();
  final done = await container
      .read(settingsRepositoryProvider)
      .getString(OnboardingDone.key);
  container.read(onboardingDoneProvider.notifier).set(done: done == 'true');

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const HarvestApp(),
    ),
  );
}
