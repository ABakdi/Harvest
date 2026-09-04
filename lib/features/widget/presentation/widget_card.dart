import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/features/widget/domain/widget_service.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'widget_card.g.dart';

/// The three switchable sections, live.
@riverpod
Stream<Map<String, bool>> widgetSections(Ref ref) => ref
    .watch(settingsRepositoryProvider)
    .watchAll(WidgetKeys.defaults.keys.toList())
    .map(
      (values) => {
        for (final entry in WidgetKeys.defaults.entries)
          entry.key: switch (values[entry.key]) {
            'true' => true,
            'false' => false,
            _ => entry.value,
          },
      },
    );

/// Explains the home-screen widget and decides what it shows.
///
/// The streak is on the list but not switchable — it is the app, and a
/// widget that can be configured into showing nothing is a widget with
/// a bug in it. Everything else is mine to turn off.
class WidgetCard extends ConsumerWidget {
  const WidgetCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sections =
        ref.watch(widgetSectionsProvider).value ?? WidgetKeys.defaults;

    Future<void> toggle(String key, {required bool value}) async {
      await ref.read(settingsRepositoryProvider).setBool(key, value: value);
      await ref.read(widgetServiceProvider).refresh();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.widgets_outlined),
                const SizedBox(width: HarvestSpacing.md),
                Expanded(child: Text(l10n.widgetTitle)),
              ],
            ),
            const SizedBox(height: HarvestSpacing.xs),
            Text(l10n.widgetBody, style: theme.textTheme.bodySmall),
            const SizedBox(height: HarvestSpacing.sm),
            Text(
              l10n.widgetSections,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.widgetSectionStreak),
              subtitle: Text(l10n.widgetSectionStreakBody),
              value: true,
              // Not a choice, and the disabled switch says so better
              // than leaving it off the list would.
              onChanged: null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.widgetSectionMoney),
              subtitle: Text(l10n.widgetSectionMoneyBody),
              value: sections[WidgetKeys.money] ?? true,
              onChanged: (value) =>
                  unawaited(toggle(WidgetKeys.money, value: value)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.widgetSectionTasks),
              subtitle: Text(l10n.widgetSectionTasksBody),
              value: sections[WidgetKeys.tasks] ?? true,
              onChanged: (value) =>
                  unawaited(toggle(WidgetKeys.tasks, value: value)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.widgetSectionActions),
              subtitle: Text(l10n.widgetSectionActionsBody),
              value: sections[WidgetKeys.actions] ?? true,
              onChanged: (value) =>
                  unawaited(toggle(WidgetKeys.actions, value: value)),
            ),
            const SizedBox(height: HarvestSpacing.sm),
            OutlinedButton.icon(
              onPressed: () =>
                  unawaited(ref.read(widgetServiceProvider).refresh()),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.widgetRefresh),
            ),
          ],
        ),
      ),
    );
  }
}
