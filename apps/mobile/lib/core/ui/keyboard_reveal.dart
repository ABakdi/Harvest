import 'dart:async';

import 'package:flutter/material.dart';

/// Brings the field being typed into back into view once the keyboard
/// has finished opening, for every sheet, dialog and screen of the app
/// ([[Checkpoint-12]] B12-01).
///
/// A field asks to be scrolled into view the moment it takes focus —
/// while the keyboard is still on its way up and the view has not
/// shrunk yet — so the ask comes too early and nothing moves; only the
/// next keystroke asked again. This asks once more when the keyboard's
/// height stops changing, with room under the field for what follows
/// it (the next field, the hint, the start of the button row).
///
/// It acts only when the keyboard grows, once per opening: scrolling
/// by hand afterwards is never undone.
class KeyboardReveal extends StatefulWidget {
  const KeyboardReveal({
    required this.child,
    this.settle = const Duration(milliseconds: 120),
    super.key,
  });

  final Widget child;

  /// How long the keyboard's height must hold still to count as open.
  final Duration settle;

  /// Room kept under the field, and above it.
  static const below = 96.0;
  static const above = 16.0;

  @override
  State<KeyboardReveal> createState() => _KeyboardRevealState();
}

class _KeyboardRevealState extends State<KeyboardReveal>
    with WidgetsBindingObserver {
  Timer? _settling;

  /// The keyboard's height when it last held still.
  double _settled = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settling?.cancel();
    super.dispose();
  }

  double get _inset {
    final view = View.maybeOf(context);
    if (view == null) return 0;
    return view.viewInsets.bottom / view.devicePixelRatio;
  }

  @override
  void didChangeMetrics() {
    _settling?.cancel();
    _settling = Timer(widget.settle, _onSettled);
  }

  void _onSettled() {
    if (!mounted) return;
    final inset = _inset;
    final grew = inset > _settled + 1;
    _settled = inset;
    if (!grew) return;
    // The frame that lays the smaller view out comes first.
    WidgetsBinding.instance.addPostFrameCallback((_) => revealFocusedField());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Scrolls the focused text field into view, with room around it;
/// nothing when no text field has focus.
void revealFocusedField() {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null || !focused.mounted) return;
  final editable = focused.findAncestorStateOfType<EditableTextState>();
  if (editable == null && focused.widget is! EditableText) return;
  // The whole field, its label and border included, not only the line
  // being typed into.
  var target = editable?.context ?? focused;
  target.visitAncestorElements((element) {
    if (element.widget is TextField) {
      target = element;
      return false;
    }
    return true;
  });
  final box = target.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return;
  box.showOnScreen(
    rect: Rect.fromLTRB(
      0,
      -KeyboardReveal.above,
      box.size.width,
      box.size.height + KeyboardReveal.below,
    ),
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOutCubic,
  );
}
