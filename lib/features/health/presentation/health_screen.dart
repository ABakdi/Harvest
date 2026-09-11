import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/core/ui/widgets/harvest_fab.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/core/ui/widgets/icon_badge.dart';
import 'package:harvest/core/ui/widgets/section_header.dart';
import 'package:harvest/features/health/data/health_repository.dart';
import 'package:harvest/features/health/data/steps_source.dart';
import 'package:harvest/features/health/domain/body_weight.dart';
import 'package:harvest/features/health/domain/steps.dart';
import 'package:harvest/features/health/domain/steps_sync.dart';
import 'package:harvest/features/health/presentation/health_providers.dart';
import 'package:harvest/features/health/presentation/sleep_card.dart';
import 'package:harvest/features/health/presentation/weight_chart.dart';
import 'package:harvest/features/health/presentation/weight_sheet.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// Sleep, steps and weight.
///
/// Three numbers with one thing in common: none of them is a target to
/// hit every day, and all of them are a line to look at. Sleep is
/// first because it is the only one of the three I have to write down
/// myself, and the moment to do it is this morning.
class HealthScreen extends ConsumerStatefulWidget {
  const HealthScreen({this.title, this.tabs, super.key});

  /// The title and tabs of the paired screen this is half of, when it
  /// is one ([[Checkpoint-6]]); on its own it names itself.
  final String? title;
  final PreferredSizeWidget? tabs;

  @override
  ConsumerState<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends ConsumerState<HealthScreen> {
  @override
  void initState() {
    super.initState();
    // Looking at the number is the moment to ask the phone for it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(stepsPullProvider.notifier).refresh());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final weights =
        ref.watch(bodyWeightsProvider).value ?? const <BodyWeight>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? l10n.navHealth),
        bottom: widget.tabs,
      ),
      floatingActionButton: HarvestFab(
        onPressed: () => showWeightSheet(context).ignore(),
        icon: Icons.monitor_weight_outlined,
        label: l10n.weightLog,
      ),
      body: ListView(
        // Clearance for the floating action *and* the switch under
        // the screen, which the tab adds below this list.
        padding: const EdgeInsets.fromLTRB(
          HarvestSpacing.md,
          HarvestSpacing.sm,
          HarvestSpacing.md,
          120,
        ),
        children: [
          const SleepCard(),
          const _StepsCard(),
          SectionHeader(l10n.weightTitle),
          if (weights.isEmpty)
            Card(
              child: EmptyState(
                icon: Icons.monitor_weight_outlined,
                title: l10n.weightEmpty,
                body: l10n.weightEmptyBody,
                compact: true,
                color: Theme.of(context).colorScheme.tertiary,
              ),
            )
          else
            _WeightCard(weights: weights),
          if (weights.isNotEmpty) ...[
            SectionHeader(l10n.weightHistory),
            for (final weight in weights.reversed.take(20))
              _WeightRow(weight: weight),
          ],
          SectionHeader(l10n.sleepNights),
          const SleepNightsList(),
        ],
      ),
    );
  }
}

/// Today's steps, and the week around them.
///
/// Three states, because a zero is three different facts: nothing
/// counted yet, not allowed to look, or nowhere to look. The card says
/// which, and offers the one tap that changes it.
class _StepsCard extends ConsumerWidget {
  const _StepsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = ref.watch(stepsTodayProvider).value;
    final week = ref.watch(recentStepsProvider(7)).value ?? const <StepDay>[];
    final goal = ref.watch(stepGoalProvider).value ?? 0;
    final pull = ref.watch(stepsPullProvider).value;
    final stride = ref.watch(strideSettingProvider).value ?? defaultStrideCm;
    final unit = ref.watch(weightUnitSettingProvider).value ?? WeightUnit.kg;
    final steps = today?.steps ?? 0;
    final average = averageSteps(week);
    final numbers = NumberFormat.decimalPattern(localeTag(context));

    // Kilometres beside kilograms, miles beside pounds: one choice of
    // units, made once.
    String distance(int count) {
      final metres = stepsToMetres(count, strideCm: stride);
      final value = unit == WeightUnit.kg ? metres / 1000 : metres / 1609.344;
      final text = value.toStringAsFixed(1);
      return unit == WeightUnit.kg
          ? l10n.stepsDistanceKm(text)
          : l10n.stepsDistanceMi(text);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(
                  Icons.directions_walk,
                  color: scheme.secondary,
                ),
                const SizedBox(width: HarvestSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.stepsToday,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            numbers.format(steps),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: HarvestSpacing.sm),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              distance(steps),
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: scheme.secondary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (average != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        l10n.stepsWeekAverage,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        numbers.format(average),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        distance(average),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                IconButton(
                  tooltip: l10n.stepsSettings,
                  icon: Icon(
                    goal > 0 ? Icons.flag : Icons.flag_outlined,
                    size: 20,
                  ),
                  onPressed: () => unawaited(
                    showStepsSettings(context, goal: goal, strideCm: stride),
                  ),
                ),
              ],
            ),
            if (goal > 0) ...[
              const SizedBox(height: HarvestSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (steps / goal).clamp(0, 1),
                  minHeight: 8,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                steps >= goal
                    ? l10n.stepsGoalMet
                    : l10n.stepsOfGoal(steps, goal),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: steps >= goal
                      ? scheme.secondary
                      : scheme.onSurfaceVariant,
                  fontWeight: steps >= goal ? FontWeight.w700 : null,
                ),
              ),
            ],
            const SizedBox(height: HarvestSpacing.sm),
            _StepsSourceRow(pull: pull),
          ],
        ),
      ),
    );
  }
}

/// The goal and the stride: the two numbers that are mine to say.
Future<void> showStepsSettings(
  BuildContext context, {
  required int goal,
  required int strideCm,
}) => showHarvestSheet<void>(
  context,
  builder: (_) => _StepsSettingsSheet(goal: goal, strideCm: strideCm),
);

class _StepsSettingsSheet extends ConsumerStatefulWidget {
  const _StepsSettingsSheet({required this.goal, required this.strideCm});

  final int goal;
  final int strideCm;

  @override
  ConsumerState<_StepsSettingsSheet> createState() =>
      _StepsSettingsSheetState();
}

class _StepsSettingsSheetState extends ConsumerState<_StepsSettingsSheet> {
  late final TextEditingController _goal = TextEditingController(
    text: widget.goal > 0 ? '${widget.goal}' : '',
  );
  late final TextEditingController _stride = TextEditingController(
    text: '${widget.strideCm}',
  );

  @override
  void dispose() {
    _goal.dispose();
    _stride.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final goal = int.tryParse(_goal.text.trim()) ?? 0;
    final stride = int.tryParse(_stride.text.trim());
    await ref.read(stepGoalProvider.notifier).set(goal < 0 ? 0 : goal);
    if (stride != null && stride > 0) {
      await ref.read(strideSettingProvider.notifier).set(stride);
    }
    // A goal set after the walk still counts for today.
    await ref.read(stepsPullProvider.notifier).refresh();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return HarvestSheet(
      title: l10n.stepsSettings,
      actionLabel: l10n.save,
      onAction: _save,
      children: [
        TextField(
          controller: _goal,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: l10n.stepsGoal,
            helperText: l10n.stepsGoalHint,
            helperMaxLines: 3,
          ),
        ),
        const SizedBox(height: HarvestSpacing.md),
        TextField(
          controller: _stride,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: l10n.stepsStride,
            suffixText: 'cm',
            helperText: l10n.stepsStrideHint,
            helperMaxLines: 3,
          ),
        ),
        const SizedBox(height: HarvestSpacing.sm),
      ],
    );
  }
}

/// The line under the number that says where it came from — or what
/// stands between the card and a number.
class _StepsSourceRow extends ConsumerWidget {
  const _StepsSourceRow({required this.pull});

  final StepsState? pull;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hint = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final pull = this.pull;
    if (pull == null) return Text(l10n.stepsPassive, style: hint);

    final notifier = ref.read(stepsPullProvider.notifier);
    final source = ref.read(stepsSourceProvider);
    final healthConnect = pull.status.backend == StepsBackend.healthConnect;

    switch (pull.outcome) {
      case StepsSyncOutcome.synced:
        return Row(
          children: [
            Expanded(
              child: Text(
                healthConnect
                    ? l10n.stepsFromHealthConnect
                    : l10n.stepsFromSensor,
                style: hint,
              ),
            ),
            IconButton(
              tooltip: l10n.stepsRefresh,
              icon: const Icon(Icons.refresh, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: () => unawaited(notifier.refresh()),
            ),
          ],
        );
      case StepsSyncOutcome.needsPermission:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              healthConnect
                  ? l10n.stepsConnectBody
                  : l10n.stepsConnectSensorBody,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: HarvestSpacing.sm),
            Wrap(
              spacing: HarvestSpacing.sm,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => unawaited(_connect(context, notifier)),
                  icon: const Icon(Icons.link, size: 18),
                  label: Text(l10n.stepsConnect),
                ),
                if (healthConnect)
                  TextButton(
                    onPressed: () => unawaited(source.openHealthConnect()),
                    child: Text(l10n.stepsOpenHealthConnect),
                  ),
              ],
            ),
          ],
        );
      case StepsSyncOutcome.unavailable:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.stepsUnavailable, style: hint),
            if (pull.status.installable) ...[
              const SizedBox(height: HarvestSpacing.sm),
              FilledButton.tonalIcon(
                onPressed: () => unawaited(source.openHealthConnect()),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: Text(l10n.stepsInstallHealthConnect),
              ),
            ],
          ],
        );
    }
  }

  Future<void> _connect(BuildContext context, StepsPull notifier) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await notifier.connect();
    if (ok) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.stepsDenied)));
  }
}

/// The chart, the sentence, and the window the sentence reads over.
class _WeightCard extends ConsumerWidget {
  const _WeightCard({required this.weights});

  final List<BodyWeight> weights;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unit = ref.watch(weightUnitSettingProvider).value ?? WeightUnit.kg;
    final target = ref.watch(targetWeightProvider).value;
    final days = ref.watch(trendDaysProvider).value ?? 30;

    final latest = weights.last;
    final points = weightSeries(weights);
    final trend = weightTrend(weights, days: days);

    String amount(int grams) =>
        '${unit.from(grams.abs()).toStringAsFixed(1)} ${unit.suffix}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  unit.from(latest.grams).toStringAsFixed(1),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    unit.suffix,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  formatDay(context, latest.day),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            // Direction, amount, window — and not a word about whether
            // that is good ([[Health]] rule H5).
            Text(
              trend == null
                  ? l10n.weightNoTrendYet
                  : trend.gramsChanged == 0
                  ? l10n.weightSteady(trend.days)
                  : trend.gramsChanged < 0
                  ? l10n.weightDown(amount(trend.gramsChanged), trend.days)
                  : l10n.weightUp(amount(trend.gramsChanged), trend.days),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
            if (target != null) ...[
              const SizedBox(height: 2),
              Text(
                l10n.weightToTarget(
                  amount(latest.grams - target),
                  '${unit.from(target).toStringAsFixed(1)} ${unit.suffix}',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: HarvestSpacing.md),
            WeightChart(points: points, unit: unit, targetGrams: target),
            const SizedBox(height: HarvestSpacing.sm),
            WeightChartLegend(
              entriesLabel: l10n.weightLegendEntries,
              trendLabel: l10n.weightLegendTrend,
              targetLabel: target == null ? null : l10n.weightLegendTarget,
            ),
            const Divider(height: HarvestSpacing.lg),
            Row(
              children: [
                Text(
                  l10n.weightWindow,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: HarvestSpacing.sm),
                Expanded(
                  child: Wrap(
                    spacing: HarvestSpacing.xs,
                    children: [
                      for (final window in trendWindows)
                        ChoiceChip(
                          label: Text(l10n.weightDays(window)),
                          selected: days == window,
                          onSelected: (_) => ref
                              .read(trendDaysProvider.notifier)
                              .set(window)
                              .ignore(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightRow extends ConsumerWidget {
  const _WeightRow({required this.weight});

  final BodyWeight weight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final unit = ref.watch(weightUnitSettingProvider).value ?? WeightUnit.kg;

    return Card(
      margin: const EdgeInsets.only(bottom: HarvestSpacing.xs),
      child: ListTile(
        dense: true,
        title: Text(
          '${unit.from(weight.grams).toStringAsFixed(1)} ${unit.suffix}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          [
            formatDay(context, weight.day),
            formatTime(context, weight.measuredAt),
            if ((weight.note ?? '').isNotEmpty) weight.note!,
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => showWeightSheet(context, existing: weight).ignore(),
        trailing: IconButton(
          tooltip: l10n.deleteAction,
          icon: const Icon(Icons.delete_outline),
          onPressed: () => unawaited(_remove(context, ref)),
        ),
      ),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(healthRepositoryProvider);
    final ok = await confirm(
      context,
      title: l10n.weightDeleteTitle,
      body: l10n.weightDeleteBody,
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );
    if (!ok) return;
    await repository.removeWeight(weight.uuid);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.deleted),
        action: SnackBarAction(
          label: l10n.undoAction,
          onPressed: () => repository.restoreWeight(weight.uuid).ignore(),
        ),
      ),
    );
  }
}
