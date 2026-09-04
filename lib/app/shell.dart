import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/features/commitments/presentation/commitment_editor_sheet.dart';
import 'package:harvest/features/finances/presentation/expense_sheet.dart';
import 'package:harvest/features/widget/domain/widget_actions.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// App shell: bottom navigation hosting the four main tabs, and the
/// place a quick action tapped on the home-screen widget lands.
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
        widget.navigationShell.goBranch(1);
        await showExpenseSheet(context);
      case WidgetAction.plantSeed:
        widget.navigationShell.goBranch(0);
        await showCommitmentEditor(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.listen(pendingWidgetActionProvider, (_, next) {
      if (next != null) unawaited(_drain());
    });

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: (index) {
          unawaited(HarvestHaptics.tick());
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          );
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.grass_outlined),
            selectedIcon: const Icon(Icons.grass),
            label: l10n.navField,
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: const Icon(Icons.account_balance_wallet),
            label: l10n.navGranary,
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights),
            label: l10n.navStats,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.navSettings,
          ),
        ],
      ),
    );
  }
}
