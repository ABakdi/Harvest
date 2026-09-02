import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/app/bootstrap.dart';
import 'package:harvest/app/router.dart';
import 'package:harvest/core/ui/theme.dart';
import 'package:harvest/features/settings/presentation/settings_controllers.dart';
import 'package:harvest/l10n/app_localizations.dart';

class HarvestApp extends ConsumerWidget {
  const HarvestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appBootstrapProvider);
    final themeMode =
        ref.watch(themeModeSettingProvider).value ?? ThemeMode.system;
    final locale = ref.watch(localeSettingProvider).value;

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      routerConfig: ref.watch(routerProvider),
      theme: HarvestTheme.light,
      darkTheme: HarvestTheme.dark,
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
