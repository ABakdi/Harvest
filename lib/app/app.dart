import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/app/bootstrap.dart';
import 'package:harvest/app/router.dart';
import 'package:harvest/core/ui/theme.dart';
import 'package:harvest/core/ui/tokens.dart';
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
  ) =>
      child;

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class HarvestApp extends ConsumerWidget {
  const HarvestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appBootstrapProvider);
    final themeMode =
        ref.watch(themeModeSettingProvider).value ?? ThemeMode.system;
    final locale = ref.watch(localeSettingProvider).value;
    final preset =
        ref.watch(themePresetSettingProvider).value ?? ThemePreset.harvest;

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
