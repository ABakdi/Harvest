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

/// Two or more features sharing one tab of the bottom bar.
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
    this.recallable,
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

  /// Whether the remembered half may be landed on now. A half that says
  /// no is passed over for the first one, and stays a tap away.
  final Future<bool> Function(T half)? recallable;

  @override
  ConsumerState<PairedScreen<T>> createState() => _PairedScreenState<T>();
}

class _PairedScreenState<T extends Enum> extends ConsumerState<PairedScreen<T>>
    with TickerProviderStateMixin {
  /// The halves that are on, in tab order; the tab row is exactly these.
  late List<PairedHalf<T>> _on = _enabled();

  late TabController _tabs = _controllerFor(
    _on,
    widget.initial ?? _on.firstOrNull?.value,
  );

  /// Set once the user has picked a half themselves; the remembered one
  /// arriving late must not then pull the tab out from under them.
  bool _touched = false;

  List<PairedHalf<T>> _enabled() =>
      widget.halves.where((half) => half.on).toList();

  TabController _controllerFor(List<PairedHalf<T>> on, T? current) {
    final index = on.indexWhere((half) => half.value == current);
    return TabController(
      length: on.isEmpty ? 1 : on.length,
      initialIndex: index < 0 ? 0 : index,
      vsync: this,
    )..addListener(_onTab);
  }

  @override
  void initState() {
    super.initState();
    final key = widget.rememberKey;
    if (key != null && widget.initial == null) unawaited(_recall(key));
  }

  @override
  void didUpdateWidget(PairedScreen<T> old) {
    super.didUpdateWidget(old);
    final on = _enabled();
    if (on.map((h) => h.value).join() == _on.map((h) => h.value).join()) {
      _on = on;
      return;
    }
    // A half was switched on or off: rebuild the tab row around what is
    // on, staying on the half I was looking at when it survives.
    final current = _current;
    final old_ = _tabs;
    _on = on;
    _tabs = _controllerFor(on, current);
    WidgetsBinding.instance.addPostFrameCallback((_) => old_.dispose());
  }

  T? get _current => _on.isEmpty
      ? null
      : _on[_tabs.index.clamp(0, _on.length - 1)].value;

  Future<void> _recall(String key) async {
    final name = await ref.read(settingsRepositoryProvider).getString(key);
    if (!mounted || _touched || name == null) return;
    final index = _on.indexWhere((half) => half.value.name == name);
    if (index < 0 || index == _tabs.index) return;
    final recallable = widget.recallable;
    if (recallable != null && !await recallable(_on[index].value)) return;
    if (!mounted || _touched) return;
    final now = _on.indexWhere((half) => half.value.name == name);
    if (now >= 0 && now != _tabs.index) _tabs.index = now;
  }

  void _onTab() {
    setState(() {});
    if (_tabs.indexIsChanging) return;
    final key = widget.rememberKey;
    final current = _current;
    if (key == null || current == null) return;
    _touched = true;
    unawaited(
      ref.read(settingsRepositoryProvider).setString(key, current.name),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = _on;
    // Nothing on at all: the shell hides the tab, but a stale route can
    // still land here; show the first half rather than nothing.
    final current = _current ?? widget.halves.first.value;

    final tabs = on.length > 1
        ? HarvestTabs(
            controller: _tabs,
            tabs: [for (final half in on) (icon: half.icon, label: half.label)],
          )
        : null;

    return widget.builder(current, tabs == null ? null : widget.title, tabs);
  }
}
