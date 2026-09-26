import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/features/gym/data/exercise_catalogue.dart';
import 'package:harvest/features/gym/data/exercises_repository.dart';
import 'package:harvest/features/gym/domain/exercise.dart';
import 'package:harvest/features/gym/presentation/exercise_detail.dart';
import 'package:harvest/features/gym/presentation/exercise_image.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Choose an exercise.
///
/// Used to build a program, and — the case that matters — to swap one
/// mid-session because the rack is taken. That is why the filters are
/// body part and equipment rather than anything cleverer: standing in
/// front of a cable machine, "what can I do here instead" is a question
/// about equipment.
Future<Exercise?> pickExercise(BuildContext context) =>
    Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (_) => const ExercisePicker()),
    );

class ExercisePicker extends ConsumerStatefulWidget {
  const ExercisePicker({super.key});

  @override
  ConsumerState<ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends ConsumerState<ExercisePicker> {
  final _search = TextEditingController();
  String? _bodyPart;
  String? _equipment;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final catalogue = ref.watch(exerciseCatalogueProvider).value;
    final all = ref.watch(allExercisesProvider).value;

    final matches = all == null
        ? const <Exercise>[]
        : filterExercises(all, (
            search: _search.text,
            bodyPart: _bodyPart,
            equipment: _equipment,
          ));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.gymPickExercise),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  HarvestSpacing.md,
                  0,
                  HarvestSpacing.md,
                  HarvestSpacing.xs,
                ),
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l10n.gymSearchExercises,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: l10n.clearValue,
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _search.clear();
                              setState(() {});
                            },
                          ),
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: HarvestSpacing.md,
                  ),
                  children: [
                    for (final part in catalogue?.bodyParts ?? const <String>[])
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: HarvestSpacing.xs,
                        ),
                        child: FilterChip(
                          label: Text(part),
                          selected: _bodyPart == part,
                          onSelected: (on) =>
                              setState(() => _bodyPart = on ? part : null),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: all == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: HarvestSpacing.md,
                      vertical: 4,
                    ),
                    children: [
                      for (final kit
                          in catalogue?.equipment ?? const <String>[])
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            end: HarvestSpacing.xs,
                          ),
                          child: FilterChip(
                            label: Text(kit),
                            selected: _equipment == kit,
                            onSelected: (on) =>
                                setState(() => _equipment = on ? kit : null),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: HarvestSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.gymExerciseCount(matches.length),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => unawaited(_addMine(context)),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(l10n.gymMineTitle),
                      ),
                      const MediaAttribution(),
                    ],
                  ),
                ),
                Expanded(
                  child: matches.isEmpty
                      ? EmptyState(
                          icon: Icons.search_off,
                          title: l10n.gymNoExercise,
                          body: l10n.gymNoExerciseBody,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            HarvestSpacing.md,
                            HarvestSpacing.xs,
                            HarvestSpacing.md,
                            HarvestSpacing.lg,
                          ),
                          itemCount: matches.length,
                          itemBuilder: (context, index) => _ExerciseTile(
                            exercise: matches[index],
                            onTap: () =>
                                Navigator.of(context).pop(matches[index]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  /// One the catalogue is missing, named from what I was searching
  /// for, and chosen the moment it exists.
  Future<void> _addMine(BuildContext context) async {
    final navigator = Navigator.of(context);
    final created = await showHarvestSheet<Exercise>(
      context,
      builder: (_) => _MineSheet(initialName: _search.text.trim()),
    );
    if (created != null && mounted) navigator.pop(created);
  }
}

/// Adding my own exercise: a name, and — if I know them — where it
/// hits and what it needs. Stored exactly as the web stores one, so it
/// syncs both ways ([[Business-Rules]] #14).
class _MineSheet extends ConsumerStatefulWidget {
  const _MineSheet({required this.initialName});

  final String initialName;

  @override
  ConsumerState<_MineSheet> createState() => _MineSheetState();
}

class _MineSheetState extends ConsumerState<_MineSheet> {
  late final _name = TextEditingController(text: widget.initialName);
  final _bodyPart = TextEditingController();
  final _equipment = TextEditingController();
  final _target = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _bodyPart.dispose();
    _equipment.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // One exercise per press, however fast the second one comes.
    if (_busy || _name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final exercise = await ref
        .read(exercisesRepositoryProvider)
        .create(
          name: _name.text,
          bodyPart: _bodyPart.text,
          equipment: _equipment.text,
          target: _target.text,
        );
    if (mounted) navigator.pop(exercise);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return HarvestSheet(
      title: l10n.gymMineTitle,
      subtitle: l10n.gymMineBody,
      actionLabel: l10n.gymMineAdd,
      onAction: _busy || _name.text.trim().isEmpty
          ? null
          : () => unawaited(_save()),
      children: [
        TextField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l10n.gymMineName),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: HarvestSpacing.sm),
        TextField(
          controller: _bodyPart,
          decoration: InputDecoration(labelText: l10n.gymMineBodyPart),
        ),
        const SizedBox(height: HarvestSpacing.sm),
        TextField(
          controller: _equipment,
          decoration: InputDecoration(
            labelText: l10n.gymMineEquipment,
            hintText: l10n.gymMineEquipmentHint,
          ),
        ),
        const SizedBox(height: HarvestSpacing.sm),
        TextField(
          controller: _target,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: l10n.gymMineMuscle),
          onSubmitted: (_) => unawaited(_save()),
        ),
      ],
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.exercise, required this.onTap});

  final Exercise exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: HarvestSpacing.xs),
      child: InkWell(
        borderRadius: BorderRadius.circular(HarvestRadii.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(HarvestSpacing.sm),
          child: Row(
            children: [
              ExerciseImage(
                fetch: false,
                exercise: exercise,
                size: 52,
                borderRadius: BorderRadius.circular(HarvestRadii.chip),
              ),
              const SizedBox(width: HarvestSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      [
                        if (exercise.mine) l10n.gymMine,
                        ?exercise.equipment,
                        ?exercise.target,
                      ].join(' · '),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.gymHowTo,
                icon: const Icon(Icons.info_outline, size: 20),
                onPressed: () =>
                    unawaited(showExerciseDetail(context, exercise)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
