import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

/// Gentle bounce at list edges everywhere — never the stretch effect
/// that deforms cards (checkpoint bug B1).
///
/// Except inside a text field. A field keeps its own small scroll view
/// for text longer than its lines, and an always-scrollable one there
/// claimed every drag that started on the text even when it had nothing
/// to scroll: a long note, or a sheet with a note field in it, could
/// only be moved by dragging the caret. A field scrolls only when its
/// text overflows it; otherwise the drag goes to the page around it.
class HarvestScrollBehavior extends MaterialScrollBehavior {
  const HarvestScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      context.findAncestorStateOfType<EditableTextState>() != null
      ? const ClampingScrollPhysics()
      : const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
