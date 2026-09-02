import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/planner/domain/notification_planner.dart';
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
    final goal = ref.watch(dailyGoalSettingProvider).value ?? 3;
    final reminders = ref.watch(reminderSettingsProvider).value ??
        (
          enabled: false,
          morning: const TimeOfDay(hour: 7, minute: 0),
          evening: const TimeOfDay(hour: 21, minute: 30),
          streakNudge: true,
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        children: [
          Text(
            l10n.settingsHarvest,
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
                  Text(l10n.settingsGoalTitle),
                  const SizedBox(height: HarvestSpacing.xs),
                  Text(
                    l10n.settingsGoalBody,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: HarvestSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.goalActions(goal),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Row(
                        children: [
                          IconButton.filledTonal(
                            onPressed: goal > 1
                                ? () {
                                    unawaited(HarvestHaptics.tick());
                                    unawaited(
                                      ref
                                          .read(dailyGoalSettingProvider
                                              .notifier)
                                          .set(goal - 1),
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.remove),
                          ),
                          const SizedBox(width: HarvestSpacing.xs),
                          IconButton.filledTonal(
                            onPressed: goal < 10
                                ? () {
                                    unawaited(HarvestHaptics.tick());
                                    unawaited(
                                      ref
                                          .read(dailyGoalSettingProvider
                                              .notifier)
                                          .set(goal + 1),
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: HarvestSpacing.lg),
          Text(
            l10n.settingsReminders,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: HarvestSpacing.sm),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(l10n.remindersMaster),
                  value: reminders.enabled,
                  onChanged: (value) => unawaited(
                    ref
                        .read(reminderSettingsProvider.notifier)
                        .setEnabled(enabled: value),
                  ),
                ),
                ListTile(
                  enabled: reminders.enabled,
                  title: Text(l10n.remindersMorning),
                  trailing: Text(reminders.morning.format(context)),
                  onTap: () => unawaited(
                    _pickTime(
                      context,
                      ref,
                      ReminderKeys.morningTime,
                      reminders.morning,
                    ),
                  ),
                ),
                ListTile(
                  enabled: reminders.enabled,
                  title: Text(l10n.remindersEvening),
                  trailing: Text(reminders.evening.format(context)),
                  onTap: () => unawaited(
                    _pickTime(
                      context,
                      ref,
                      ReminderKeys.eveningTime,
                      reminders.evening,
                    ),
                  ),
                ),
                SwitchListTile(
                  title: Text(l10n.remindersStreak),
                  value: reminders.streakNudge,
                  onChanged: reminders.enabled
                      ? (value) => unawaited(
                            ref
                                .read(reminderSettingsProvider.notifier)
                                .setStreakNudge(enabled: value),
                          )
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: HarvestSpacing.lg),
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

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref,
    String key,
    TimeOfDay current,
  ) async {
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked != null) {
      await ref.read(reminderSettingsProvider.notifier).setTime(key, picked);
    }
  }
}
