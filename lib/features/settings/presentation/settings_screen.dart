import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/app/bootstrap.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/platform/notifications.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/section_header.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/presentation/category_settings.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
import 'package:harvest/features/planner/domain/notification_planner.dart';
import 'package:harvest/features/pomodoro/domain/pomodoro_service.dart';
import 'package:harvest/features/settings/presentation/rates_card.dart';
import 'package:harvest/features/settings/presentation/settings_controllers.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Settings, in the order they matter: the goal, the reminders, the
/// focus timer, money, then looks. A startup problem, if any, sits at
/// the very bottom so it is never missed and never in the way.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final goal = ref.watch(dailyGoalSettingProvider).value ?? 3;
    final pomodoro =
        ref.watch(pomodoroConfigSettingProvider).value ??
        const PomodoroConfig();
    final startupProblem = ref.watch(bootstrapStatusProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        children: [
          SectionHeader(
            l10n.settingsHarvest,
            padding: const EdgeInsets.only(bottom: HarvestSpacing.sm),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(HarvestSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.settingsGoalTitle),
                  const SizedBox(height: HarvestSpacing.xs),
                  Text(l10n.settingsGoalBody, style: theme.textTheme.bodySmall),
                  const SizedBox(height: HarvestSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.goalActions(goal),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      _Stepper(
                        value: goal,
                        min: 1,
                        max: 10,
                        onChanged: (value) => unawaited(
                          ref
                              .read(dailyGoalSettingProvider.notifier)
                              .set(value),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SectionHeader(l10n.settingsReminders),
          const _RemindersCard(),
          SectionHeader(l10n.settingsPomodoro),
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
          SectionHeader(l10n.settingsMoney),
          const _DefaultCurrencyCard(),
          const SizedBox(height: HarvestSpacing.sm),
          const CategorySettingsCard(),
          const SizedBox(height: HarvestSpacing.sm),
          const RatesCard(),
          SectionHeader(l10n.settingsAppearance),
          const _AppearanceCard(),
          if (startupProblem != null) ...[
            const SizedBox(height: HarvestSpacing.lg),
            Card(
              color: theme.colorScheme.errorContainer,
              child: ListTile(
                leading: Icon(
                  Icons.warning_amber_rounded,
                  color: theme.colorScheme.onErrorContainer,
                ),
                title: Text(
                  l10n.startupProblem(startupProblem),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: HarvestSpacing.xl),
        ],
      ),
    );
  }
}

/// A minus / plus pair with tooltips and a bounded value.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });

  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    void change(int next) {
      unawaited(HarvestHaptics.tick());
      onChanged(next);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: l10n.decrease,
          onPressed: value > min ? () => change(value - step) : null,
          icon: const Icon(Icons.remove),
        ),
        const SizedBox(width: HarvestSpacing.xs),
        IconButton.filledTonal(
          tooltip: l10n.increase,
          onPressed: value < max ? () => change(value + step) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class _RemindersCard extends ConsumerWidget {
  const _RemindersCard();

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final reminders =
        ref.watch(reminderSettingsProvider).value ??
        (
          enabled: false,
          morning: const TimeOfDay(hour: 7, minute: 0),
          evening: const TimeOfDay(hour: 21, minute: 30),
          expense: const TimeOfDay(hour: 20, minute: 0),
          streakNudge: true,
        );
    final streakAt = TimeOfDay(
      hour: ReminderDefaults.streakRisk.$1,
      minute: ReminderDefaults.streakRisk.$2,
    ).format(context);

    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: Text(l10n.remindersMaster),
            value: reminders.enabled,
            onChanged: (value) async {
              final messenger = ScaffoldMessenger.of(context);
              final permission = await ref
                  .read(reminderSettingsProvider.notifier)
                  .setEnabled(enabled: value);
              if (value && permission == ReminderPermission.denied) {
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.remindersDenied)),
                );
              }
            },
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
          ListTile(
            enabled: reminders.enabled,
            title: Text(l10n.remindersExpense),
            trailing: Text(reminders.expense.format(context)),
            onTap: () => unawaited(
              _pickTime(
                context,
                ref,
                ReminderKeys.expenseTime,
                reminders.expense,
              ),
            ),
          ),
          SwitchListTile(
            title: Text(l10n.remindersStreak),
            subtitle: Text(l10n.remindersStreakHint(streakAt)),
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
    );
  }
}

class _DefaultCurrencyCard extends ConsumerWidget {
  const _DefaultCurrencyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(defaultCurrencyProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.defaultCurrencyLabel),
            const SizedBox(height: HarvestSpacing.sm),
            SegmentedButton<Currency>(
              segments: [
                for (final currency in Currency.values)
                  ButtonSegment(
                    value: currency,
                    label: Text(currency.symbol),
                    tooltip: currency.code,
                  ),
              ],
              selected: {current},
              onSelectionChanged: (selection) {
                unawaited(HarvestHaptics.tick());
                unawaited(
                  ref
                      .read(financeSettingsProvider.notifier)
                      .setDefaultCurrency(selection.first),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode =
        ref.watch(themeModeSettingProvider).value ?? ThemeMode.system;
    final locale = ref.watch(localeSettingProvider).value;
    final preset =
        ref.watch(themePresetSettingProvider).value ?? ThemePreset.harvest;

    return Card(
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
                ButtonSegment(value: 'en', label: Text(l10n.langEnglish)),
                ButtonSegment(value: 'ar', label: Text(l10n.langArabic)),
              ],
              selected: {locale?.languageCode ?? LocaleSetting.system},
              onSelectionChanged: (selection) {
                unawaited(HarvestHaptics.tick());
                unawaited(
                  ref.read(localeSettingProvider.notifier).set(selection.first),
                );
              },
            ),
          ],
        ),
      ),
    );
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
    return ListTile(
      title: Text(label),
      subtitle: Text(value),
      trailing: _Stepper(
        value: current,
        min: min,
        max: max,
        step: step,
        onChanged: (next) => unawaited(
          ref
              .read(pomodoroConfigSettingProvider.notifier)
              .set(settingKey, next),
        ),
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
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(HarvestRadii.button),
        onTap: () {
          unawaited(HarvestHaptics.tick());
          unawaited(ref.read(themePresetSettingProvider.notifier).set(preset));
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
                    ? ExcludeSemantics(
                        child: Icon(Icons.check, color: scheme.onPrimary),
                      )
                    : null,
              ),
              const SizedBox(height: HarvestSpacing.xs),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}
