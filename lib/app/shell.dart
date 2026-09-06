import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harvest/app/router.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/features/commitments/presentation/commitment_editor_sheet.dart';
import 'package:harvest/features/finances/presentation/expense_sheet.dart';
import 'package:harvest/features/settings/domain/feature_switches.dart';
import 'package:harvest/features/widget/domain/widget_actions.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// One entry in the bottom bar, and the shell branch it opens.
typedef _Tab = ({int branch, IconData icon, IconData active, String label});

/// App shell: bottom navigation hosting the main tabs, and the place a
/// quick action tapped on the home-screen widget lands.
///
/// Records has a branch whether or not it is on; what the switches
/// change is whether a tab points at it. That keeps the route valid for
/// a deep link or a reminder payload written while the feature was
/// enabled, and keeps the bar down to four for someone who only came
/// for a streak — five with the extras, never six.
///
/// The bar hides itself while the keyboard is up: on a note that is the
/// difference between a toolbar sitting on the keyboard and a toolbar
/// sitting on a navigation bar sitting on the keyboard.
class HarvestShell extends ConsumerStatefulWidget {
  const HarvestShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<HarvestShell> createState() => _HarvestShellState();
}

class _HarvestShellState extends ConsumerState<HarvestShell> {
  @override
  void initState() {
    super.initState();
    // A widget button that fired while the app was closed is already
    // waiting by the time the shell exists.
    WidgetsBinding.instance.addPostFrameCallback((_) => _drain());
  }

  /// Carries out whatever the widget asked for: the shell is the first
  /// thing under the navigator, so it is the first place that *can*.
  Future<void> _drain() async {
    final action = ref.read(pendingWidgetActionProvider.notifier).take();
    if (action == null || !mounted) return;
    switch (action) {
      case WidgetAction.logExpense:
        widget.navigationShell.goBranch(ShellBranch.finances);
        await showExpenseSheet(context);
      case WidgetAction.plantSeed:
        widget.navigationShell.goBranch(ShellBranch.field);
        await showCommitmentEditor(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.listen(pendingWidgetActionProvider, (_, next) {
      if (next != null) unawaited(_drain());
    });

    final tabs = <_Tab>[
      (
        branch: ShellBranch.field,
        icon: Icons.grass_outlined,
        active: Icons.grass,
        label: l10n.navField,
      ),
      // Notes and the Gallery share one tab: they are the same
      // instinct kept two ways, and five tabs is already the ceiling.
      if (ref.watch(notesEnabledProvider) || ref.watch(galleryEnabledProvider))
        (
          branch: ShellBranch.records,
          icon: Icons.auto_stories_outlined,
          active: Icons.auto_stories,
          label: l10n.navRecords,
        ),
      (
        branch: ShellBranch.finances,
        icon: Icons.account_balance_wallet_outlined,
        active: Icons.account_balance_wallet,
        label: l10n.navGranary,
      ),
      (
        branch: ShellBranch.stats,
        icon: Icons.insights_outlined,
        active: Icons.insights,
        label: l10n.navStats,
      ),
      (
        branch: ShellBranch.settings,
        icon: Icons.settings_outlined,
        active: Icons.settings,
        label: l10n.navSettings,
      ),
    ];

    // A branch with no tab — a note opened from a link after the switch
    // was turned off — leaves nothing selected rather than lighting up
    // the wrong icon.
    final current = tabs.indexWhere(
      (tab) => tab.branch == widget.navigationShell.currentIndex,
    );

    // With the keyboard up the bar goes — but the Scaffold stays, or
    // the whole subtree remounts, the field loses focus and the
    // keyboard shuts the instant it opens.
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: typing
          ? null
          : NavigationBar(
              selectedIndex: current < 0 ? 0 : current,
              onDestinationSelected: (index) {
                unawaited(HarvestHaptics.tick());
                final branch = tabs[index].branch;
                widget.navigationShell.goBranch(
                  branch,
                  initialLocation:
                      branch == widget.navigationShell.currentIndex,
                );
              },
              destinations: [
                for (final tab in tabs)
                  NavigationDestination(
                    icon: Icon(tab.icon),
                    selectedIcon: Icon(tab.active),
                    label: tab.label,
                  ),
              ],
            ),
    );
  }
}
