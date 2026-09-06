import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/core/ui/widgets/icon_badge.dart';
import 'package:harvest/features/health/data/sleep_repository.dart';
import 'package:harvest/features/health/domain/sleep.dart';
import 'package:harvest/features/health/presentation/sleep_providers.dart';
import 'package:harvest/features/health/presentation/sleep_sheet.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Last night, and what is owed.
///
/// The debt is a gauge rather than a number in red, and the words are
/// about soil, because the point of showing it is that it can be paid
/// back — a person who is four hours down and told they have failed
/// simply stops opening the card.
class SleepCard extends ConsumerWidget {
  const SleepCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final nights = ref.watch(sleepNightsProvider).value ?? const <SleepNight>[];
    final debt = ref.watch(sleepDebtNowProvider).value;
    final unlogged = ref.watch(sleepUnloggedProvider).value ?? false;
    final last = nights.isEmpty ? null : nights.first;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(HarvestRadii.card),
        onTap: () => unawaited(showSleepSheet(context)),
        child: Padding(
          padding: const EdgeInsets.all(HarvestSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconBadge(Icons.bedtime_outlined, color: scheme.tertiary),
                  const SizedBox(width: HarvestSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.sleepLastNight,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        // A duration is short and gets the big type; the
                        // sentence that stands in for it when there is
                        // none would wrap into the button beside it.
                        Text(
                          last == null
                              ? l10n.sleepNothingYet
                              : l10n.sleepLength(
                                  last.slept.inHours,
                                  last.slept.inMinutes % 60,
                                ),
                          style:
                              (last == null
                                      ? theme.textTheme.titleMedium
                                      : theme.textTheme.headlineSmall)
                                  ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  if (unlogged)
                    FilledButton(
                      onPressed: () => unawaited(showSleepSheet(context)),
                      child: Text(l10n.sleepLogIt),
                    ),
                ],
              ),
              if (nights.length > 1) ...[
                const SizedBox(height: HarvestSpacing.sm),
                Text(
                  l10n.sleepAverage(
                    averageSleep(nights).inHours,
                    averageSleep(nights).inMinutes % 60,
                    nights.length,
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (debt != null && debt.minutes > 0) ...[
                const SizedBox(height: HarvestSpacing.md),
                _DebtGauge(debt: debt),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// How far behind, as a bar that fills rather than a number that
/// accuses. Full is three nights down, past which the exact figure has
/// stopped being useful and the point has been made.
class _DebtGauge extends StatelessWidget {
  const _DebtGauge({required this.debt});

  final SleepDebt debt;

  static const _full = 3.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hours = debt.minutes ~/ 60;
    final minutes = debt.minutes % 60;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.sleepDebtLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              l10n.sleepLength(hours, minutes),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.tertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: HarvestSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: (debt.nights / _full).clamp(0.0, 1.0),
            minHeight: 8,
            color: scheme.tertiary,
            backgroundColor: scheme.tertiary.withValues(alpha: 0.15),
          ),
        ),
        const SizedBox(height: HarvestSpacing.xs),
        Text(
          l10n.sleepDebtBody,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Every night written down, newest first.
///
/// Tapping one reopens the morning it belongs to, because the usual
/// reason to look at this list is that I got a number wrong.
class SleepNightsList extends ConsumerWidget {
  const SleepNightsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final nights = ref.watch(sleepNightsProvider).value ?? const <SleepNight>[];

    if (nights.isEmpty) {
      return Card(
        child: EmptyState(
          icon: Icons.bedtime_outlined,
          title: l10n.sleepNoNights,
          body: l10n.sleepNoNightsBody,
          compact: true,
          color: scheme.tertiary,
        ),
      );
    }

    return Column(
      children: [
        for (final night in nights)
          Card(
            margin: const EdgeInsets.only(bottom: HarvestSpacing.sm),
            child: ListTile(
              title: Text(
                l10n.sleepLength(
                  night.slept.inHours,
                  night.slept.inMinutes % 60,
                ),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                [
                  formatDay(context, night.day),
                  if (night.restedStars != null)
                    l10n.sleepStars(night.restedStars!),
                ].join(' · '),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => unawaited(_remove(context, ref, night)),
              ),
              onTap: () =>
                  unawaited(showSleepSheet(context, forDay: night.day)),
            ),
          ),
      ],
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    SleepNight night,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirm(
      context,
      title: l10n.sleepDeleteNight,
      body: l10n.sleepDeleteNightBody,
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(sleepRepositoryProvider).remove(night.uuid);
  }
}
