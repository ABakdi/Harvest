import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harvest/app/router.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/features/commitments/presentation/commitment_editor_sheet.dart';
import 'package:harvest/features/finances/presentation/expense_sheet.dart';
import 'package:harvest/features/lists/data/share_inbox.dart';
import 'package:harvest/features/lists/presentation/share_flow.dart';
import 'package:harvest/features/settings/domain/feature_switches.dart';
import 'package:harvest/features/widget/domain/widget_actions.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// One entry in the bottom bar, and the shell branch it opens.
typedef _Tab = ({int branch, IconData icon, IconData active, String label});

/// App shell: bottom navigation hosting the main tabs, and the place a
/// quick action tapped on the home-screen widget lands.
///
/// Records and the Body have branches whether or not they are on; what
/// the switches change is whether a tab points at one. That keeps the
/// route valid for a deep link or a reminder payload written while the
/// feature was enabled, and keeps the bar down to three for someone who
/// only came for a streak — five with everything, never six.
///
/// Settings does not have a tab of its own any more. It lives in the
/// farmer's tab beside progress, which is where it belonged: both are
/// about me rather than about anything I track, and merging them is
/// what freed the slot the body needed.
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
  void didUpdateWidget(HarvestShell old) {
    super.didUpdateWidget(old);
    // A snack bar belongs to the tab it was said on: "Moved to the
    // trash · Undo" followed me to the next tab and sat over its
    // buttons. Cleared after the frame, since the messenger is an
    // ancestor mid-build.
    if (old.navigationShell.currentIndex !=
        widget.navigationShell.currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
      });
    }
  }

  /// Back closes what is open first — a drawer, a sheet, a pushed
  /// screen, all of which the branch's own navigator pops before this
  /// is asked — then goes home to the field, and only from the field
  /// leaves the app. Every tab but the field was a way out in one tap.
  void _onBack(bool didPop, Object? _) {
    if (didPop) return;
    unawaited(HarvestHaptics.tick());
    widget.navigationShell.goBranch(ShellBranch.field);
  }

  @override
  void initState() {
    super.initState();
    // A widget button that fired while the app was closed is already
    // waiting by the time the shell exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_drain());
      unawaited(_drainShare());
    });
  }

  /// Opens *Save to a list* for what another app shared ([[Lists]]),
  /// whether it launched the app or arrived while it was open.
  Future<void> _drainShare() async {
    final draft = ref.read(shareInboxProvider.notifier).take();
    if (draft == null || !mounted) return;
    await saveShared(context, ref, draft);
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
    ref
      ..listen(pendingWidgetActionProvider, (_, next) {
        if (next != null) unawaited(_drain());
      })
      ..listen(shareInboxProvider, (_, next) {
        if (next != null) unawaited(_drainShare());
      });

    // Five, and five is the ceiling. Four optional features fit under
    // two tabs: notes and pictures share Records, sleep and training
    // share the Body — and progress and settings were always one idea
    // wearing two labels.
    final tabs = <_Tab>[
      (
        branch: ShellBranch.field,
        icon: Icons.grass_outlined,
        active: Icons.grass,
        label: l10n.navField,
      ),
      (
        branch: ShellBranch.finances,
        icon: Icons.account_balance_wallet_outlined,
        active: Icons.account_balance_wallet,
        label: l10n.navGranary,
      ),
      if (ref.watch(notesEnabledProvider) ||
          ref.watch(galleryEnabledProvider) ||
          ref.watch(placesEnabledProvider) ||
          ref.watch(listsEnabledProvider))
        (
          branch: ShellBranch.records,
          icon: Icons.auto_stories_outlined,
          active: Icons.auto_stories,
          label: l10n.navRecords,
        ),
      if (ref.watch(healthEnabledProvider) || ref.watch(gymEnabledProvider))
        (
          branch: ShellBranch.body,
          icon: Icons.monitor_heart_outlined,
          active: Icons.monitor_heart,
          label: l10n.navBody,
        ),
      (
        branch: ShellBranch.stats,
        icon: Icons.person_outline,
        active: Icons.person,
        label: l10n.navFarmer,
      ),
    ];

    // Settings shares the farmer's tab but keeps its own branch, so a
    // deep link to it must still light that tab up.
    final branch = widget.navigationShell.currentIndex == ShellBranch.settings
        ? ShellBranch.stats
        : widget.navigationShell.currentIndex;

    // A branch with no tab — a note opened from a link after the switch
    // was turned off — leaves nothing selected rather than lighting up
    // the wrong icon.
    final current = tabs.indexWhere((tab) => tab.branch == branch);

    // With the keyboard up the bar goes — but the Scaffold stays, or
    // the whole subtree remounts, the field loses focus and the
    // keyboard shuts the instant it opens.
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;

    return PopScope(
      canPop: widget.navigationShell.currentIndex == ShellBranch.field,
      onPopInvokedWithResult: _onBack,
      child: Scaffold(
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
      ),
    );
  }
}
