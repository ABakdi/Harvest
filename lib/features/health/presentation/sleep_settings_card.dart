import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/platform/notifications.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/health/domain/sleep.dart';
import 'package:harvest/features/health/presentation/sleep_providers.dart';
import 'package:harvest/features/planner/domain/notification_planner.dart';
import 'package:harvest/features/settings/domain/daily_cycle.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// The alarm, the wind-down, and the weekdays that are their own night.
///
/// No bedtime or wake time here: those are the daily cycle's, one
/// screen up. Sleep reads the hours the app already bends the day
/// around rather than keeping a second set that can disagree with them.
class SleepSettingsCard extends ConsumerWidget {
  const SleepSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final alarm = ref.watch(sleepAlarmOnProvider).value ?? false;
    final windDown = ref.watch(sleepWindDownOnProvider).value ?? false;
    final targets = ref.watch(sleepTargetsProvider).value;

    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.alarm),
            title: Text(l10n.sleepAlarm),
            subtitle: Text(
              targets == null
                  ? l10n.sleepAlarmBody
                  : '${_clock(context, targets.cycle.wakeTime)} · '
                        '${l10n.sleepAlarmBody}',
            ),
            value: alarm,
            onChanged: (value) => unawaited(
              _setAlarm(context, ref, on: value),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.nights_stay_outlined),
            title: Text(l10n.sleepWindDown),
            subtitle: Text(l10n.sleepWindDownBody),
            value: windDown,
            onChanged: (value) => unawaited(
              _setWindDown(ref, on: value),
            ),
          ),
          const Divider(height: 1),
          // Seven tiles is a lot of screen for something most weeks
          // nobody touches, so it opens rather than sits there.
          ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            leading: const Icon(Icons.calendar_view_week_outlined),
            title: Text(
              l10n.sleepOverrides,
              style: theme.textTheme.titleMedium,
            ),
            subtitle: Text(
              targets != null && targets.hasOverrides
                  ? l10n.sleepOverrideCount(targets.overrides.length)
                  : l10n.sleepOverridesBody,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            children: [
              for (var weekday = 1; weekday <= 7; weekday++)
                _WeekdayTile(weekday: weekday, targets: targets),
              const SizedBox(height: HarvestSpacing.sm),
            ],
          ),
        ],
      ),
    );
  }

  static String _clock(BuildContext context, (int, int) time) =>
      TimeOfDay(hour: time.$1, minute: time.$2).format(context);

  /// Switching the alarm on is also where the exact-alarm permission
  /// gets asked for, because it is the only moment the answer means
  /// anything to anybody.
  Future<void> _setAlarm(
    BuildContext context,
    WidgetRef ref, {
    required bool on,
  }) async {
    await ref.read(sleepAlarmOnProvider.notifier).set(on: on);
    if (on) {
      final notifications = ref.read(notificationServiceProvider);
      await notifications.requestPermission();
      if (!await notifications.canScheduleExact() && context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).sleepAlarmExactBody),
            ),
          );
      }
    }
    await ref.read(notificationPlannerProvider).planToday();
  }

  Future<void> _setWindDown(WidgetRef ref, {required bool on}) async {
    await ref.read(sleepWindDownOnProvider.notifier).set(on: on);
    await ref.read(notificationPlannerProvider).planToday();
  }
}

class _WeekdayTile extends ConsumerWidget {
  const _WeekdayTile({required this.weekday, required this.targets});

  final int weekday;
  final SleepTargets? targets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final override = ref.watch(sleepNightOverrideProvider(weekday)).value;
    final names = DateFormat.EEEE(
      Localizations.localeOf(context).toLanguageTag(),
    ).dateSymbols.WEEKDAYS;
    // Dart weekdays run Monday..Sunday; the symbol list starts Sunday.
    final name = names[weekday % 7];

    return ListTile(
      dense: true,
      title: Text(name),
      subtitle: Text(
        override == null
            ? l10n.sleepSameAsUsual
            : l10n.sleepNightOf(
                _clock(context, override.bedTime),
                _clock(context, override.wakeTime),
              ),
      ),
      trailing: override == null
          ? const Icon(Icons.add, size: 20)
          : IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => unawaited(_clear(ref)),
            ),
      onTap: () => unawaited(_edit(context, ref, override)),
    );
  }

  static String _clock(BuildContext context, (int, int) time) =>
      TimeOfDay(hour: time.$1, minute: time.$2).format(context);

  Future<void> _clear(WidgetRef ref) async {
    await ref.read(sleepNightOverrideProvider(weekday).notifier).set(null);
    await ref.read(notificationPlannerProvider).planToday();
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    DailyCycle? current,
  ) async {
    final base = current ?? targets?.cycle ?? DailyCycle.fallback;
    final bed = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: base.bedTime.$1, minute: base.bedTime.$2),
      helpText: AppLocalizations.of(context).cycleBedTime,
    );
    if (bed == null || !context.mounted) return;
    final wake = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: base.wakeTime.$1, minute: base.wakeTime.$2),
      helpText: AppLocalizations.of(context).cycleWakeTime,
    );
    if (wake == null) return;

    await ref
        .read(sleepNightOverrideProvider(weekday).notifier)
        .set(
          DailyCycle(
            bedTime: (bed.hour, bed.minute),
            wakeTime: (wake.hour, wake.minute),
          ),
        );
    await ref.read(notificationPlannerProvider).planToday();
  }
}
