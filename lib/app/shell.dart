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
/// Notes and the Gallery have branches whether or not they are on; what
/// the switch changes is whether a tab points at one. That keeps the
/// route valid for a deep link or a reminder payload written while the
/// feature was enabled, and keeps the bar down to four for someone who
/// only came for a streak.
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
      if (ref.watch(notesEnabledProvider))
        (
          branch: ShellBranch.notes,
          icon: Icons.description_outlined,
          active: Icons.description,
          label: l10n.navNotes,
        ),
      if (ref.watch(galleryEnabledProvider))
        (
          branch: ShellBranch.gallery,
          icon: Icons.photo_library_outlined,
          active: Icons.photo_library,
          label: l10n.navGallery,
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

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: current < 0 ? 0 : current,
        onDestinationSelected: (index) {
          unawaited(HarvestHaptics.tick());
          final branch = tabs[index].branch;
          widget.navigationShell.goBranch(
            branch,
            initialLocation: branch == widget.navigationShell.currentIndex,
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
