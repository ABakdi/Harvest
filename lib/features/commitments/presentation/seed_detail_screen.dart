import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/app/current_day.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/core/ui/widgets/hero_card.dart';
import 'package:harvest/core/ui/widgets/icon_badge.dart';
import 'package:harvest/core/ui/widgets/section_header.dart';
import 'package:harvest/core/ui/widgets/stat_tile.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/presentation/commitment_editor_sheet.dart';
import 'package:harvest/features/commitments/presentation/seed_note_sheet.dart';
import 'package:harvest/features/commitments/presentation/seed_providers.dart';
import 'package:harvest/features/gamification/presentation/gamification_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Everything one seed has ever done: its streak, its run of days, and
/// the timeline of what I logged and wrote, newest first.
///
/// A recurring seed is only worth keeping if I can see the run behind
/// it — the field shows today, this shows the year.
class SeedDetailScreen extends ConsumerWidget {
  const SeedDetailScreen({required this.uuid, super.key});

  final String uuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final commitment = ref.watch(seedProvider(uuid)).value;
    final timeline = ref.watch(seedTimelineProvider(uuid));
    final streaks = ref.watch(commitmentStreaksProvider).value ?? const {};

    if (commitment == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.seedHistoryTitle)),
        body: EmptyState(
          icon: Icons.eco_outlined,
          title: l10n.seedGone,
          body: l10n.seedGoneBody,
        ),
      );
    }

    final done = timeline.where((d) => d.quantity > 0).toList();
    final stored = streaks[uuid];
    // The stored streak is the engine's verdict; the run of consecutive
    // days is what the history itself says. They agree for a judged
    // habit, and the run is still honest for everything else.
    final current =
        stored?.current ??
        completedDaysRun([
          for (final entry in done) entry.day,
        ]);
    final best = stored?.best ?? current;
    final total = done.fold(0, (sum, entry) => sum + entry.quantity);

    return Scaffold(
      appBar: AppBar(
        title: Text(commitment.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: l10n.seedNotesTitle,
            icon: const Icon(Icons.edit_note),
            onPressed: () => unawaited(showSeedNoteSheet(context, commitment)),
          ),
          IconButton(
            tooltip: l10n.editSeed,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => unawaited(
              showCommitmentEditor(context, existing: commitment),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          HarvestSpacing.md,
          HarvestSpacing.md,
          HarvestSpacing.md,
          HarvestSpacing.lg,
        ),
        children: [
          HeroCard(
            // Inside a Builder, so the text styles resolve against the
            // card's own white foreground rather than the page's.
            child: Builder(
              builder: (context) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const IconBadge(
                        Icons.local_fire_department,
                        color: Colors.white,
                        size: 36,
                        iconSize: 20,
                      ),
                      const SizedBox(width: HarvestSpacing.sm),
                      Text(
                        l10n.streakLabel,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: HarvestSpacing.sm),
                  Text(
                    l10n.dayCount(current),
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: HarvestSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          label: l10n.bestLabel,
                          value: l10n.dayCount(best),
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          label: l10n.daysLoggedLabel,
                          value: '${done.length}',
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          label: commitment.type == CommitmentType.project
                              ? l10n.unitsLabel
                              : l10n.checkInsLabel,
                          value: '$total',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: HarvestSpacing.md),
          _RunStrip(
            days: {for (final entry in done) entry.day},
            today: ref.watch(currentHarvestDayProvider),
          ),
          const SizedBox(height: HarvestSpacing.sm),
          SectionHeader(
            l10n.seedHistoryTitle,
            subtitle: l10n.seedHistorySubtitle(timeline.length),
          ),
          if (timeline.isEmpty)
            Card(
              child: EmptyState(
                icon: Icons.history,
                title: l10n.seedHistoryEmpty,
                body: l10n.seedHistoryEmptyBody,
                compact: true,
              ),
            )
          else
            for (final entry in timeline)
              _DayRow(entry: entry, commitment: commitment),
        ],
      ),
    );
  }
}

/// The last eight weeks as a dotted strip: filled where I showed up.
class _RunStrip extends StatelessWidget {
  const _RunStrip({required this.days, required this.today});

  final Set<HarvestDay> days;
  final HarvestDay today;

  static const _span = 56;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final start = today.addDays(-(_span - 1));

    return Semantics(
      label: l10n.runStripLabel(days.length),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(HarvestSpacing.md),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var i = 0; i < _span; i++)
                Builder(
                  builder: (context) {
                    final day = start.addDays(i);
                    final filled = days.contains(day);
                    return Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: filled
                            ? scheme.secondary
                            : scheme.onSurface.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: day == today
                            ? Border.all(color: scheme.primary, width: 1.5)
                            : null,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One day of the seed's life: what was logged, and what I wrote.
class _DayRow extends ConsumerWidget {
  const _DayRow({required this.entry, required this.commitment});

  final SeedDay entry;
  final Commitment commitment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final logged = entry.quantity > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: HarvestSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(
              logged ? Icons.check : Icons.edit_note,
              color: logged ? scheme.secondary : scheme.tertiary,
            ),
            const SizedBox(width: HarvestSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatDay(context, entry.day, weekday: true),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    logged
                        ? (commitment.type == CommitmentType.project
                              ? l10n.unitsLogged(entry.quantity)
                              : l10n.checkedIn)
                        : l10n.noteOnlyDay,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (entry.note != null) ...[
                    const SizedBox(height: 4),
                    Text(entry.note!, style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
