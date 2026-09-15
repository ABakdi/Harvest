import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/widgets/harvest_tabs.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';

/// One half of a paired screen: what it is, how it is drawn in the
/// tab row, and whether it is switched on at all.
typedef PairedHalf<T> = ({T value, IconData icon, String label, bool on});

/// What a half's own screen is built from: the pair's title and tab
/// row when there is a pair, or nothing when it stands alone.
typedef PairedBuilder<T> = Widget Function(
  T current,
  String? title,
  PreferredSizeWidget? tabs,
);

/// Two features sharing one tab of the bottom bar.
///
/// Body, Records and the farmer's tab are all this shape, and until
/// [[Audit-v2-Beta]] Q2-09 each carried its own copy of the rule:
/// a `TabController`, the tabs shown only while both halves are on,
/// the title naming the pair when there are tabs and the half when
/// there are not, and a switched-off half never left on screen. Now
/// the rule lives here once and the three screens are a list of halves
/// and a builder.
class PairedScreen<T extends Enum> extends ConsumerStatefulWidget {
  const PairedScreen({
    required this.title,
    required this.halves,
    required this.builder,
    this.initial,
    this.rememberKey,
    super.key,
  });

  /// The bottom tab's name, shown above the tab row.
  final String title;

  /// In tab order. Exactly the enum's values, each with its switch.
  final List<PairedHalf<T>> halves;

  final PairedBuilder<T> builder;

  /// Which half to open on; the remembered one, or the first, otherwise.
  final T? initial;

  /// A setting key to remember the half under, so the tab opens where
  /// it was last left rather than always on its first half
  /// ([[Checkpoint-7]]). An explicit [initial] still wins.
  final String? rememberKey;

  @override
  ConsumerState<PairedScreen<T>> createState() => _PairedScreenState<T>();
}

class _PairedScreenState<T extends Enum> extends ConsumerState<PairedScreen<T>>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: widget.halves.length,
    initialIndex: widget.initial == null
        ? 0
        : widget.halves.indexWhere((half) => half.value == widget.initial),
    vsync: this,
  )..addListener(_onTab);

  /// Set once the user has picked a half themselves; the remembered one
  /// arriving late must not then pull the tab out from under them.
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    final key = widget.rememberKey;
    if (key != null && widget.initial == null) unawaited(_recall(key));
  }

  Future<void> _recall(String key) async {
    final name = await ref.read(settingsRepositoryProvider).getString(key);
    if (!mounted || _touched || name == null) return;
    final index = widget.halves.indexWhere((half) => half.value.name == name);
    if (index >= 0 && index != _tabs.index) _tabs.index = index;
  }

  void _onTab() {
    setState(() {});
    if (_tabs.indexIsChanging) return;
    final key = widget.rememberKey;
    if (key == null) return;
    _touched = true;
    unawaited(
      ref
          .read(settingsRepositoryProvider)
          .setString(key, widget.halves[_tabs.index].value.name),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.halves.where((half) => half.on).toList();

    // The tabs follow what is on: turning one half off while looking
    // at it lands on the other, not on a blank screen.
    final current = switch (on.length) {
      1 => on.single.value,
      _ => widget.halves[_tabs.index].value,
    };

    final tabs = on.length > 1
        ? HarvestTabs(
            controller: _tabs,
            tabs: [
              for (final half in widget.halves)
                (icon: half.icon, label: half.label),
            ],
          )
        : null;

    return widget.builder(current, tabs == null ? null : widget.title, tabs);
  }
}
