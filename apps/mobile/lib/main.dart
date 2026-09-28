import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/app/app.dart';
import 'package:harvest/core/platform/day_reset.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/features/onboarding/presentation/onboarding_screen.dart';
import 'package:harvest/features/security/domain/app_lock.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  useWesternDigits();
  if (Platform.isAndroid) unawaited(DayResetJob.register());
  await start();
}

/// Opens the data and the app. When the data cannot be opened — the
/// Keystore did not answer — it says so, with *Try again*, and never
/// starts empty over a file a later read may open (S6-05).
@visibleForTesting
Future<void> start() async {
  // A first frame at once, in the launch window's own green, so nothing
  // waits on the Keystore or the file to draw (P6-13). The app itself
  // follows once onboarding and the app lock are known, so the router
  // never flashes the wrong screen and a locked app never flashes its
  // contents on the way up.
  runApp(const StartingApp());
  final container = ProviderContainer();
  final bool done;
  final bool locked;
  try {
    final settings = container.read(settingsRepositoryProvider);
    done = await settings.getString(OnboardingDone.key) == 'true';
    locked = await settings.getBool(SettingKeys.appLock) ?? false;
  } on Object catch (error) {
    debugPrint('[db] could not open the data: ${error.runtimeType}');
    container.dispose();
    runApp(DataUnavailableApp(onRetry: () => unawaited(start())));
    return;
  }
  container.read(onboardingDoneProvider.notifier).set(done: done);
  container.read(appLockProvider.notifier).start(enabled: locked);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const HarvestApp(),
    ),
  );
}

/// The first frame, drawn before the data is open: the colour the
/// launch window and the splash begin on, and nothing else.
class StartingApp extends StatelessWidget {
  const StartingApp({super.key});

  /// `@color/launch_background` on Android.
  static const color = Color(0xFF1F8A46);

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: color, child: SizedBox.expand());
}

/// What the app shows when its data cannot be opened right now.
class DataUnavailableApp extends StatelessWidget {
  const DataUnavailableApp({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_clock_outlined, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      l10n.dataUnavailableTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.dataUnavailableBody, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: onRetry,
                      child: Text(l10n.galleryFileRetry),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
