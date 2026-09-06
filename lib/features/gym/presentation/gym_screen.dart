import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Programs, sessions and records.
///
/// The scaffolding is here so the tab exists and the switch works; the
/// machinery lands in M4.4 and M4.5.
class GymScreen extends ConsumerWidget {
  const GymScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navGym)),
      body: EmptyState(
        icon: Icons.fitness_center,
        title: l10n.gymComingTitle,
        body: l10n.gymComingBody,
        color: Theme.of(context).colorScheme.tertiary,
      ),
    );
  }
}
