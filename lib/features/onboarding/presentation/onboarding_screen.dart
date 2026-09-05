import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/big_bouncy_button.dart';
import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/features/settings/domain/feature_switches.dart';
import 'package:harvest/features/settings/presentation/settings_controllers.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_screen.g.dart';

/// Whether first-run onboarding has been completed. The real value is
/// loaded before the app starts; defaulting to true protects existing
/// users from ever seeing onboarding again by accident.
@Riverpod(keepAlive: true)
class OnboardingDone extends _$OnboardingDone {
  static const key = 'onboarding.done';

  @override
  bool build() => true;

  // A named method reads better than a setter at the call sites.
  // ignore: use_setters_to_change_properties
  void set({required bool done}) => state = done;
}

/// A quick-start seed the farmer can pick during onboarding.
class _Template {
  const _Template(this.id, this.type, {this.schedule, this.total, this.daily});

  final String id;
  final CommitmentType type;
  final Schedule? schedule;
  final int? total;
  final int? daily;
}

const _templates = [
  _Template('read', CommitmentType.project, total: 300, daily: 10),
  _Template('fit', CommitmentType.habit, schedule: DailySchedule()),
  _Template('language', CommitmentType.habit, schedule: DailySchedule()),
  _Template(
    'meditate',
    CommitmentType.habit,
    schedule: TimesPerWeekSchedule(times: 3),
  ),
  _Template('journal', CommitmentType.habit, schedule: DailySchedule()),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  var _page = 0;
  final _picked = <String>{'read', 'fit'};
  var _goal = 3;
  var _remindersOn = true;
  var _notesOn = false;
  var _galleryOn = false;
  var _finishing = false;

  static const _pages = 5;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_page < _pages - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      await _finish();
    }
  }

  /// Leaves without planting anything or turning reminders on — the
  /// field starts empty and the choices stay in Settings.
  Future<void> _skip() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await _markDone();
  }

  Future<void> _markDone() async {
    await ref
        .read(settingsRepositoryProvider)
        .setString(OnboardingDone.key, 'true');
    ref.read(onboardingDoneProvider.notifier).set(done: true);
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(commitmentsRepositoryProvider);

    String title(String id) => switch (id) {
      'read' => l10n.tmplRead,
      'fit' => l10n.tmplFit,
      'language' => l10n.tmplLanguage,
      'meditate' => l10n.tmplMeditate,
      _ => l10n.tmplJournal,
    };

    for (final template in _templates) {
      if (!_picked.contains(template.id)) continue;
      await repo.create(
        type: template.type,
        title: title(template.id),
        schedule: template.schedule,
        totalTarget: template.total,
        dailyCommitment: template.daily,
      );
    }
    await ref.read(dailyGoalSettingProvider.notifier).set(_goal);
    if (_remindersOn) {
      await ref
          .read(reminderSettingsProvider.notifier)
          .setEnabled(enabled: true);
    }
    // Both default to no, and both are written either way so the
    // answer is a decision on record rather than an absent row.
    final settings = ref.read(settingsRepositoryProvider);
    await settings.setBool(FeatureKeys.notes, value: _notesOn);
    await settings.setBool(FeatureKeys.gallery, value: _galleryOn);
    await _markDone();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isLast = _page == _pages - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: _finishing ? null : _skip,
                child: Text(l10n.skip),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _page = page),
                children: [
                  _WelcomePage(l10n: l10n),
                  _TemplatesPage(
                    l10n: l10n,
                    picked: _picked,
                    onToggle: (id) => setState(() {
                      if (!_picked.add(id)) _picked.remove(id);
                    }),
                  ),
                  _GoalPage(
                    l10n: l10n,
                    goal: _goal,
                    onChanged: (goal) => setState(() => _goal = goal),
                  ),
                  _RemindersPage(
                    l10n: l10n,
                    enabled: _remindersOn,
                    onChanged: (on) => setState(() => _remindersOn = on),
                  ),
                  _ExtrasPage(
                    l10n: l10n,
                    notes: _notesOn,
                    gallery: _galleryOn,
                    onNotes: (on) => setState(() => _notesOn = on),
                    onGallery: (on) => setState(() => _galleryOn = on),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(HarvestSpacing.lg),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _pages; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.circle,
                            size: 8,
                            color: i == _page
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.2,
                                  ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: HarvestSpacing.md),
                  BigBouncySheetButton(
                    onPressed: _finishing ? null : () => unawaited(_next()),
                    child: Text(isLast ? l10n.startGrowing : l10n.next),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(HarvestSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.grass, size: 120, color: theme.colorScheme.secondary),
          const SizedBox(height: HarvestSpacing.lg),
          Text(
            l10n.obWelcomeTitle,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: HarvestSpacing.md),
          Text(
            l10n.obWelcomeBody,
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TemplatesPage extends StatelessWidget {
  const _TemplatesPage({
    required this.l10n,
    required this.picked,
    required this.onToggle,
  });

  final AppLocalizations l10n;
  final Set<String> picked;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = {
      'read': l10n.tmplRead,
      'fit': l10n.tmplFit,
      'language': l10n.tmplLanguage,
      'meditate': l10n.tmplMeditate,
      'journal': l10n.tmplJournal,
    };
    return Padding(
      padding: const EdgeInsets.all(HarvestSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.obTemplatesTitle,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: HarvestSpacing.sm),
          Text(
            l10n.obTemplatesBody,
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: HarvestSpacing.lg),
          Wrap(
            spacing: HarvestSpacing.sm,
            runSpacing: HarvestSpacing.sm,
            alignment: WrapAlignment.center,
            children: [
              for (final entry in labels.entries)
                FilterChip(
                  label: Text(entry.value),
                  selected: picked.contains(entry.key),
                  onSelected: (_) => onToggle(entry.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalPage extends StatelessWidget {
  const _GoalPage({
    required this.l10n,
    required this.goal,
    required this.onChanged,
  });

  final AppLocalizations l10n;
  final int goal;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(HarvestSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            l10n.obGoalTitle,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: HarvestSpacing.sm),
          Text(
            l10n.settingsGoalBody,
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: HarvestSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: goal > 1 ? () => onChanged(goal - 1) : null,
                icon: const Icon(Icons.remove),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: HarvestSpacing.lg,
                ),
                child: Text(
                  '$goal',
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: goal < 10 ? () => onChanged(goal + 1) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          Text(l10n.goalActions(goal), style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _RemindersPage extends StatelessWidget {
  const _RemindersPage({
    required this.l10n,
    required this.enabled,
    required this.onChanged,
  });

  final AppLocalizations l10n;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(HarvestSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_active_outlined,
            size: 96,
            color: theme.colorScheme.tertiary,
          ),
          const SizedBox(height: HarvestSpacing.lg),
          Text(
            l10n.obRemindersTitle,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: HarvestSpacing.sm),
          Text(
            l10n.obRemindersBody,
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: HarvestSpacing.lg),
          SwitchListTile(
            title: Text(l10n.remindersMaster),
            value: enabled,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// The last question: the two halves of the app that stay hidden
/// unless asked for.
///
/// Both are off under the switch, and saying no here costs nothing —
/// Settings has them forever after. Someone who came for a streak
/// tracker leaves this page with exactly the app they came for.
class _ExtrasPage extends StatelessWidget {
  const _ExtrasPage({
    required this.l10n,
    required this.notes,
    required this.gallery,
    required this.onNotes,
    required this.onGallery,
  });

  final AppLocalizations l10n;
  final bool notes;
  final bool gallery;
  final ValueChanged<bool> onNotes;
  final ValueChanged<bool> onGallery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(HarvestSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.tune,
            size: 88,
            color: theme.colorScheme.tertiary,
          ),
          const SizedBox(height: HarvestSpacing.lg),
          Text(
            l10n.obExtrasTitle,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: HarvestSpacing.sm),
          Text(
            l10n.obExtrasBody,
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: HarvestSpacing.lg),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.description_outlined),
                  title: Text(l10n.featureNotes),
                  subtitle: Text(l10n.featureNotesHint),
                  value: notes,
                  onChanged: onNotes,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.photo_library_outlined),
                  title: Text(l10n.featureGallery),
                  subtitle: Text(l10n.featureGalleryHint),
                  value: gallery,
                  onChanged: onGallery,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
