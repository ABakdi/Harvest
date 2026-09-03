import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/app/bootstrap.dart';
import 'package:harvest/app/router.dart';
import 'package:harvest/core/app/current_day.dart';
import 'package:harvest/core/ui/theme.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:harvest/features/planner/domain/notification_planner.dart';
import 'package:harvest/features/settings/presentation/settings_controllers.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Gentle bounce at list edges everywhere — never the stretch effect
/// that deforms cards (checkpoint bug B1).
class _HarvestScrollBehavior extends MaterialScrollBehavior {
  const _HarvestScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

class HarvestApp extends ConsumerStatefulWidget {
  const HarvestApp({super.key});

  @override
  ConsumerState<HarvestApp> createState() => _HarvestAppState();
}

class _HarvestAppState extends ConsumerState<HarvestApp> {
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    // Coming back to the foreground may mean a new Harvest Day: refresh
    // the clock, judge what was missed, and replan today's reminders.
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  void _onResume() {
    ref.read(currentHarvestDayProvider.notifier).refresh();
    unawaited(_catchUp());
  }

  Future<void> _catchUp() async {
    try {
      await ref.read(streakServiceProvider).reconcile();
      await ref.read(notificationPlannerProvider).planToday();
    } on Object catch (error) {
      ref.read(bootstrapStatusProvider.notifier).report('resume', error);
    }
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final booted = ref.watch(appBootstrapProvider);
    final themeMode =
        ref.watch(themeModeSettingProvider).value ?? ThemeMode.system;
    final locale = ref.watch(localeSettingProvider).value;
    final preset =
        ref.watch(themePresetSettingProvider).value ?? ThemePreset.harvest;

    // Until the day is judged, nothing is tappable: a check-in on an
    // un-reconciled streak would count against the wrong day.
    if (booted.isLoading) {
      return MaterialApp(
        theme: HarvestTheme.light(preset),
        darkTheme: HarvestTheme.dark(preset),
        themeMode: themeMode,
        debugShowCheckedModeBanner: false,
        home: const Scaffold(body: SizedBox.expand()),
      );
    }
    return MaterialApp.router(
      scrollBehavior: const _HarvestScrollBehavior(),
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      routerConfig: ref.watch(routerProvider),
      theme: HarvestTheme.light(preset),
      darkTheme: HarvestTheme.dark(preset),
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
