import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/settings/presentation/settings_controllers.dart';
import 'package:harvest/l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode =
        ref.watch(themeModeSettingProvider).value ?? ThemeMode.system;
    final locale = ref.watch(localeSettingProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        children: [
          Text(
            l10n.settingsAppearance,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: HarvestSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(HarvestSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.settingsTheme),
                  const SizedBox(height: HarvestSpacing.sm),
                  SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text(l10n.themeSystem),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text(l10n.themeLight),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(l10n.themeDark),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (selection) {
                      unawaited(HarvestHaptics.tick());
                      unawaited(
                        ref
                            .read(themeModeSettingProvider.notifier)
                            .set(selection.first),
                      );
                    },
                  ),
                  const SizedBox(height: HarvestSpacing.lg),
                  Text(l10n.settingsLanguage),
                  const SizedBox(height: HarvestSpacing.sm),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: LocaleSetting.system,
                        label: Text(l10n.langSystem),
                      ),
                      ButtonSegment(
                        value: 'en',
                        label: Text(l10n.langEnglish),
                      ),
                      ButtonSegment(
                        value: 'ar',
                        label: Text(l10n.langArabic),
                      ),
                    ],
                    selected: {locale?.languageCode ?? LocaleSetting.system},
                    onSelectionChanged: (selection) {
                      unawaited(HarvestHaptics.tick());
                      unawaited(
                        ref
                            .read(localeSettingProvider.notifier)
                            .set(selection.first),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
