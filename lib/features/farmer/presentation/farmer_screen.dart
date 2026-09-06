import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/widgets/feature_switcher.dart';
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
/// what frees the fifth slot for the body.
class FarmerScreen extends ConsumerStatefulWidget {
  const FarmerScreen({this.initial = FarmerTab.progress, super.key});

  final FarmerTab initial;

  @override
  ConsumerState<FarmerScreen> createState() => _FarmerScreenState();
}

class _FarmerScreenState extends ConsumerState<FarmerScreen> {
  late FarmerTab _tab = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Expanded(
          child: _tab == FarmerTab.progress
              ? const StatsScreen()
              : const SettingsScreen(),
        ),
        FeatureSwitcher<FarmerTab>(
          current: _tab,
          halves: [
            (
              value: FarmerTab.progress,
              icon: Icons.insights_outlined,
              label: l10n.navProgress,
            ),
            (
              value: FarmerTab.settings,
              icon: Icons.settings_outlined,
              label: l10n.navSettings,
            ),
          ],
          onChanged: (tab) => setState(() => _tab = tab),
        ),
      ],
    );
  }
}
