import 'package:flutter/material.dart';
import 'package:harvest/core/ui/widgets/paired_screen.dart';
import 'package:harvest/features/settings/presentation/settings_screen.dart';
import 'package:harvest/features/stats/stats_screen.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// How I am doing, and how the app is set up.
enum FarmerTab { progress, settings }

/// The farmer's own tab.
///
/// Stats and Settings were two tabs holding one idea between them —
/// *me*, rather than any of the things I track. Progress is the record
/// of the farmer and settings are the farmer's preferences, and the app
/// has called the user a farmer since the first rank. Merging them is
/// what frees the fifth slot for the body. Both halves are always on,
/// so the tabs are always there ([[Checkpoint-6]]).
class FarmerScreen extends StatelessWidget {
  const FarmerScreen({this.initial = FarmerTab.progress, super.key});

  final FarmerTab initial;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PairedScreen<FarmerTab>(
      title: l10n.navFarmer,
      initial: initial,
      halves: [
        (
          value: FarmerTab.progress,
          icon: Icons.insights_outlined,
          label: l10n.navProgress,
          on: true,
        ),
        (
          value: FarmerTab.settings,
          icon: Icons.settings_outlined,
          label: l10n.navSettings,
          on: true,
        ),
      ],
      builder: (current, title, tabs) => switch (current) {
        FarmerTab.progress => StatsScreen(title: title, tabs: tabs),
        FarmerTab.settings => SettingsScreen(title: title, tabs: tabs),
      },
    );
  }
}
