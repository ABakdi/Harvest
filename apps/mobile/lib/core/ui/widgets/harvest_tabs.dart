import 'package:flutter/material.dart';
import 'package:harvest/core/platform/haptics.dart';

/// One tab of a paired screen.
typedef HarvestTab = ({IconData icon, String label});

/// The tabs under a screen's title.
///
/// There used to be two ways of splitting a screen: the Granary's tabs
/// at the top, and a segmented switch at the bottom for the tabs that
/// hold two features. The bottom switch read as a second navigation
/// bar sitting on the real one, fought the floating button for the
/// same corner, and the title above never matched the half on show
/// ([[Checkpoint-6]]). So there is one way now, and this is it: the
/// title names the tab, the row under it names the halves, and the
/// thumb learns one place to look.
///
/// It slots into `AppBar.bottom`, which is why each half's own
/// scaffold builds it in rather than a parent wrapping them: the notes
/// screen keeps its drawer and the gallery keeps its trash button.
class HarvestTabs extends StatelessWidget implements PreferredSizeWidget {
  const HarvestTabs({required this.controller, required this.tabs, super.key});

  final TabController controller;
  final List<HarvestTab> tabs;

  @override
  Size get preferredSize => const Size.fromHeight(kTextTabBarHeight);

  /// Narrower than this per tab, the row scrolls rather than squeezing
  /// its labels until one clips or two overlap (U6-12).
  static const double _minTabWidth = 112;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final squeezed =
          constraints.maxWidth.isFinite &&
          constraints.maxWidth / tabs.length < _minTabWidth;
      return _bar(scrolls: squeezed);
    },
  );

  Widget _bar({required bool scrolls}) => TabBar(
    controller: controller,
    isScrollable: scrolls,
    tabAlignment: scrolls ? TabAlignment.start : null,
    onTap: (_) => HarvestHaptics.tick().ignore(),
    tabs: [
      for (final tab in tabs)
        Tab(
          height: kTextTabBarHeight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tab.icon, size: 18),
              const SizedBox(width: 6),
              Text(tab.label),
            ],
          ),
        ),
    ],
  );
}
