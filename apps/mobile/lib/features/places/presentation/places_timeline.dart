import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/app/router.dart';
import 'package:harvest/core/app/current_day.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/features/finances/presentation/expense_sheet.dart';
import 'package:harvest/features/finances/presentation/money.dart';
import 'package:harvest/features/finances/presentation/moves_ledger.dart';
import 'package:harvest/features/places/data/location_gateway.dart';
import 'package:harvest/features/places/domain/place.dart';
import 'package:harvest/features/places/presentation/places_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// How much of the calendar the map shows at once.
enum PlacesRange { day, week, month }

/// A pin's colour, by what the action was.
Color geotagColor(String table, ColorScheme scheme) => switch (table) {
  'expenses' || 'money_txns' || 'debts' || 'debt_payments' => scheme.error,
  'memories' || 'albums' => scheme.tertiary,
  'notes' || 'note_attachments' || 'seed_notes' => scheme.secondary,
  _ => scheme.primary,
};

/// A pin's icon and its name, by what the action was.
({IconData icon, String label}) geotagKind(
  String table,
  AppLocalizations l10n,
) => switch (table) {
  'expenses' => (icon: Icons.payments_outlined, label: l10n.geoExpense),
  'check_ins' => (icon: Icons.eco_outlined, label: l10n.geoCheckIn),
  'memories' => (icon: Icons.photo_camera_outlined, label: l10n.geoPicture),
  'albums' => (icon: Icons.photo_library_outlined, label: l10n.geoAlbum),
  'notes' => (icon: Icons.edit_note, label: l10n.geoNote),
  'note_attachments' => (icon: Icons.mic_none, label: l10n.geoVoice),
  'commitments' => (icon: Icons.spa_outlined, label: l10n.geoSeed),
  'seed_notes' => (icon: Icons.sticky_note_2_outlined, label: l10n.geoSeedNote),
  'money_txns' => (
    icon: Icons.account_balance_wallet_outlined,
    label: l10n.geoMoney,
  ),
  'debts' => (icon: Icons.handshake_outlined, label: l10n.geoDebt),
  'debt_payments' => (
    icon: Icons.handshake_outlined,
    label: l10n.geoDebtPayment,
  ),
  'body_weights' => (
    icon: Icons.monitor_weight_outlined,
    label: l10n.geoWeight,
  ),
  'sleep_sessions' => (icon: Icons.bedtime_outlined, label: l10n.geoNight),
  'workout_sessions' => (icon: Icons.fitness_center, label: l10n.geoSession),
  'goals' => (icon: Icons.flag_outlined, label: l10n.geoGoal),
  'goal_items' => (icon: Icons.checklist, label: l10n.geoGoalItem),
  _ => (icon: Icons.place_outlined, label: table),
};

/// A pin's line on the timeline, money written as the Granary writes
/// it: "DA4 · Food", "+DA200 · Added to the wallet".
String? geotagDetailText(AppLocalizations l10n, GeotagDetail? detail) =>
    switch (detail) {
      null => null,
      GeotagGone() => null,
      GeotagText(:final text) => text,
      GeotagExpense(
        :final amountMinor,
        :final currency,
        :final category,
        :final note,
      ) =>
        '${formatMoney(amountMinor, currency)} · '
            '${note ?? categoryLabel(l10n, category)}',
      GeotagMove(:final txn) =>
        '${formatMoneySigned(txn.deltaMinor, txn.currency)} · '
            '${txn.note ?? moveTitle(l10n, txn)}',
    };

/// Where tapping a pin goes, for the actions that have a screen.
String? geotagRoute(Geotag tag) => switch (tag.targetTable) {
  'notes' => '${AppRoutes.records}/note/${tag.targetUuid}',
  'commitments' => '${AppRoutes.seed}/${tag.targetUuid}',
  'goals' => '${AppRoutes.goal}/${tag.targetUuid}',
  _ => null,
};

/// The span the map shows, and the arrows and range chips that move it.
class PlacesDateStrip extends StatelessWidget {
  const PlacesDateStrip({
    required this.label,
    required this.range,
    required this.canGoForward,
    required this.onRange,
    required this.onStep,
    required this.onPick,
    super.key,
  });

  final String label;
  final PlacesRange range;
  final bool canGoForward;
  final ValueChanged<PlacesRange> onRange;
  final ValueChanged<int> onStep;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HarvestSpacing.sm,
        vertical: HarvestSpacing.xs,
      ),
      child: Column(
        children: [
          SegmentedButton<PlacesRange>(
            segments: [
              ButtonSegment(
                value: PlacesRange.day,
                label: Text(l10n.placesDay),
              ),
              ButtonSegment(
                value: PlacesRange.week,
                label: Text(l10n.placesWeek),
              ),
              ButtonSegment(
                value: PlacesRange.month,
                label: Text(l10n.placesMonth),
              ),
            ],
            selected: {range},
            showSelectedIcon: false,
            onSelectionChanged: (s) => onRange(s.first),
          ),
          Row(
            children: [
              IconButton(
                tooltip: l10n.placesPrevious,
                icon: const Icon(Icons.chevron_left),
                onPressed: () => onStep(-1),
              ),
              Expanded(
                child: TextButton(
                  onPressed: onPick,
                  child: Text(label, textAlign: TextAlign.center),
                ),
              ),
              IconButton(
                tooltip: l10n.placesNext,
                icon: const Icon(Icons.chevron_right),
                onPressed: canGoForward ? () => onStep(1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One line on what the trail is doing right now.
class TrailStatusLine extends ConsumerWidget {
  const TrailStatusLine({required this.state, required this.today, super.key});

  final TrailState state;
  final HarvestDay today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final String? text;
    if (state.access == LocationAccess.serviceOff) {
      text = l10n.placesServiceOff;
    } else if (state.paused) {
      text = l10n.placesPausedUntil(
        TimeOfDay.fromDateTime(state.pausedUntil!).format(context),
      );
    } else if (state.running) {
      final count =
          ref
              .watch(pointsOnProvider(ref.watch(currentHarvestDayProvider)))
              .value ??
          0;
      text = l10n.placesRecording(count);
    } else {
      text = null;
    }
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: HarvestSpacing.xs),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The span as a list: stays and actions in the order they happened.
class PlacesTimeline extends ConsumerWidget {
  const PlacesTimeline({
    required this.scroll,
    required this.tags,
    required this.stays,
    required this.distanceM,
    required this.selected,
    required this.onTag,
    required this.onStay,
    super.key,
  });

  final ScrollController scroll;
  final List<Geotag> tags;
  final List<Stay> stays;
  final double distanceM;
  final String? selected;
  final ValueChanged<Geotag> onTag;
  final ValueChanged<Stay> onStay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entries = <({DateTime at, Widget tile})>[
      for (final stay in stays)
        (
          at: stay.from,
          tile: ListTile(
            leading: Icon(Icons.radio_button_checked, color: scheme.tertiary),
            title: Text(
              stay.place?.name ?? l10n.placesStay(_duration(stay.length)),
            ),
            subtitle: Text(
              '${_time(context, stay.from)}–${_time(context, stay.to)}'
              '${stay.place == null ? '' : ' · ${_duration(stay.length)}'}',
            ),
            onTap: () => onStay(stay),
          ),
        ),
      for (final tag in tags)
        (
          at: tag.at,
          tile: _GeotagTile(
            tag: tag,
            selected: tag.uuid == selected,
            onTap: () => onTag(tag),
          ),
        ),
    ]..sort((a, b) => a.at.compareTo(b.at));

    return Material(
      elevation: 3,
      color: scheme.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(HarvestRadii.sheet),
      ),
      child: ListView(
        controller: scroll,
        padding: const EdgeInsets.only(bottom: HarvestSpacing.xl),
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: HarvestSpacing.sm),
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (distanceM > 0)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: HarvestSpacing.md,
              ),
              child: Text(
                l10n.placesDistance((distanceM / 1000).toStringAsFixed(1)),
                style: theme.textTheme.titleSmall,
              ),
            ),
          if (entries.isEmpty)
            EmptyState(
              compact: true,
              icon: Icons.place_outlined,
              title: l10n.placesNothing,
              body: l10n.placesNothingBody,
            )
          else
            for (final entry in entries) entry.tile,
        ],
      ),
    );
  }

  String _time(BuildContext context, DateTime at) =>
      TimeOfDay.fromDateTime(at).format(context);

  String _duration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    return hours == 0 ? '$minutes min' : '$hours h $minutes min';
  }
}

class _GeotagTile extends ConsumerWidget {
  const _GeotagTile({
    required this.tag,
    required this.selected,
    required this.onTap,
  });

  final Geotag tag;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final kind = geotagKind(tag.targetTable, l10n);
    final detail = ref
        .watch(
          geotagDetailProvider((table: tag.targetTable, uuid: tag.targetUuid)),
        )
        .value;
    return ListTile(
      selected: selected,
      leading: Icon(
        kind.icon,
        color: tag.hasPlace
            ? geotagColor(tag.targetTable, scheme)
            : scheme.outline,
      ),
      // Named by what it was about (the seed, the note), the kind said
      // once beneath; one whose row is gone says so rather than
      // repeating its kind twice (U6-26).
      title: Text(
        geotagDetailText(l10n, detail) ??
            (detail is GeotagGone ? l10n.geoGone(kind.label) : kind.label),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${TimeOfDay.fromDateTime(tag.at).format(context)} · ${kind.label}',
      ),
      onTap: onTap,
    );
  }
}
