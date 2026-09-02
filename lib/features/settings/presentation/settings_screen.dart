import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/planner/domain/notification_planner.dart';
import 'package:harvest/features/pomodoro/domain/pomodoro_service.dart';
import 'package:harvest/features/settings/presentation/rates_card.dart';
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
    final preset =
        ref.watch(themePresetSettingProvider).value ?? ThemePreset.harvest;
    final pomodoro = ref.watch(pomodoroConfigSettingProvider).value ??
        const PomodoroConfig();
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
            l10n.exchangeRates,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: HarvestSpacing.sm),
          const RatesCard(),
          const SizedBox(height: HarvestSpacing.lg),
          Text(
            l10n.settingsPomodoro,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: HarvestSpacing.sm),
          Card(
            child: Column(
              children: [
                _PomodoroRow(
                  label: l10n.pomodoroFocusLen,
                  value: l10n.minutesValue(pomodoro.focusMinutes),
                  settingKey: PomodoroKeys.focus,
                  current: pomodoro.focusMinutes,
                  min: 10,
                  max: 90,
                  step: 5,
                ),
                _PomodoroRow(
                  label: l10n.pomodoroShortLen,
                  value: l10n.minutesValue(pomodoro.shortBreakMinutes),
                  settingKey: PomodoroKeys.shortBreak,
                  current: pomodoro.shortBreakMinutes,
                  min: 1,
                  max: 20,
                  step: 1,
                ),
                _PomodoroRow(
                  label: l10n.pomodoroLongLen,
                  value: l10n.minutesValue(pomodoro.longBreakMinutes),
                  settingKey: PomodoroKeys.longBreak,
                  current: pomodoro.longBreakMinutes,
                  min: 5,
                  max: 45,
                  step: 5,
                ),
                _PomodoroRow(
                  label: l10n.pomodoroBlocks,
                  value: '${pomodoro.blocksPerLongBreak}',
                  settingKey: PomodoroKeys.blocksPerLong,
                  current: pomodoro.blocksPerLongBreak,
                  min: 2,
                  max: 8,
                  step: 1,
                ),
              ],
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
                  Text(l10n.settingsStyle),
                  const SizedBox(height: HarvestSpacing.sm),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final option in ThemePreset.values)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              end: HarvestSpacing.sm,
                            ),
                            child: _PresetSwatch(
                              preset: option,
                              selected: option == preset,
                              label: switch (option) {
                                ThemePreset.harvest => l10n.presetHarvest,
                                ThemePreset.sunrise => l10n.presetSunrise,
                                ThemePreset.ocean => l10n.presetOcean,
                                ThemePreset.orchard => l10n.presetOrchard,
                                ThemePreset.dusk => l10n.presetDusk,
                              },
                            ),
                          ),
                      ],
                    ),
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


class _PomodoroRow extends ConsumerWidget {
  const _PomodoroRow({
    required this.label,
    required this.value,
    required this.settingKey,
    required this.current,
    required this.min,
    required this.max,
    required this.step,
  });

  final String label;
  final String value;
  final String settingKey;
  final int current;
  final int min;
  final int max;
  final int step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(pomodoroConfigSettingProvider.notifier);
    return ListTile(
      title: Text(label),
      subtitle: Text(value),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(
            onPressed: current > min
                ? () => unawaited(notifier.set(settingKey, current - step))
                : null,
            icon: const Icon(Icons.remove),
          ),
          const SizedBox(width: HarvestSpacing.xs),
          IconButton.filledTonal(
            onPressed: current < max
                ? () => unawaited(notifier.set(settingKey, current + step))
                : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}


class _PresetSwatch extends ConsumerWidget {
  const _PresetSwatch({
    required this.preset,
    required this.selected,
    required this.label,
  });

  final ThemePreset preset;
  final bool selected;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = harvestPalettes[preset]!;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(HarvestRadii.button),
      onTap: () {
        unawaited(HarvestHaptics.tick());
        unawaited(
          ref.read(themePresetSettingProvider.notifier).set(preset),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(HarvestSpacing.xs),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: palette.gradient),
                border: Border.all(
                  color: selected ? scheme.onSurface : Colors.transparent,
                  width: 3,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: HarvestSpacing.xs),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}
