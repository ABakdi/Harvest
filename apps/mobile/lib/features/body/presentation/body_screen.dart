import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/widgets/paired_screen.dart';
import 'package:harvest/features/gym/presentation/gym_screen.dart';
import 'package:harvest/features/health/presentation/health_screen.dart';
import 'package:harvest/features/settings/domain/feature_switches.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Which half of the body I am looking at.
enum BodyTab { health, gym }

/// Sleep, steps and weight on one side; training on the other.
///
/// Both are about the same thing — what the body did — and neither
/// earns a tab of its own on a bar that already holds four. Same
/// arrangement as [[Records]], for the same reason, and the same
/// [PairedScreen] holding the rules ([[Checkpoint-6]]).
class BodyScreen extends ConsumerWidget {
  const BodyScreen({this.initial, super.key});

  final BodyTab? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PairedScreen<BodyTab>(
      title: l10n.navBody,
      initial: initial,
      halves: [
        (
          value: BodyTab.health,
          icon: Icons.monitor_heart_outlined,
          label: l10n.navHealth,
          on: ref.watch(healthEnabledProvider),
        ),
        (
          value: BodyTab.gym,
          icon: Icons.fitness_center,
          label: l10n.navGym,
          on: ref.watch(gymEnabledProvider),
        ),
      ],
      builder: (current, title, tabs) => switch (current) {
        BodyTab.health => HealthScreen(title: title, tabs: tabs),
        BodyTab.gym => GymScreen(title: title, tabs: tabs),
      },
    );
  }
}
