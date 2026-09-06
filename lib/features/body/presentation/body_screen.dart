import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/widgets/feature_switcher.dart';
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
/// arrangement as [[Records]], for the same reason.
class BodyScreen extends ConsumerStatefulWidget {
  const BodyScreen({this.initial, super.key});

  final BodyTab? initial;

  @override
  ConsumerState<BodyScreen> createState() => _BodyScreenState();
}

class _BodyScreenState extends ConsumerState<BodyScreen> {
  BodyTab? _tab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final health = ref.watch(healthEnabledProvider);
    final gym = ref.watch(gymEnabledProvider);

    // The switch follows what is on: turning health off while looking
    // at it should land on the gym, not on a blank screen.
    final current = switch ((health, gym)) {
      (true, false) => BodyTab.health,
      (false, true) => BodyTab.gym,
      _ => _tab ?? widget.initial ?? BodyTab.health,
    };

    final body = current == BodyTab.health
        ? const HealthScreen()
        : const GymScreen();

    return Column(
      children: [
        Expanded(child: body),
        if (health && gym)
          FeatureSwitcher<BodyTab>(
            current: current,
            halves: [
              (
                value: BodyTab.health,
                icon: Icons.monitor_heart_outlined,
                label: l10n.navHealth,
              ),
              (
                value: BodyTab.gym,
                icon: Icons.fitness_center,
                label: l10n.navGym,
              ),
            ],
            onChanged: (tab) => setState(() => _tab = tab),
          )
        else
          const SizedBox.shrink(),
      ],
    );
  }
}
