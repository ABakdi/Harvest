import 'dart:async';

import 'package:flutter/material.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';

/// The signature primary action: a chunky filled button that springs
/// under the finger and ticks on press — the game feel in one widget.
class BigBouncyButton extends StatefulWidget {
  const BigBouncyButton({
    required this.onPressed,
    required this.child,
    this.icon,
    super.key,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;

  @override
  State<BigBouncyButton> createState() => _BigBouncyButtonState();
}

class _BigBouncyButtonState extends State<BigBouncyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    upperBound: 0.06,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _enabled ? (_) => _controller.forward() : null,
      onTapCancel: _enabled ? _controller.reverse : null,
      onTapUp: _enabled ? (_) => _controller.reverse() : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: 1 - _controller.value,
          child: child,
        ),
        child: widget.icon == null
            ? FilledButton(
                onPressed: _enabled ? _press : null,
                child: widget.child,
              )
            : FilledButton.icon(
                onPressed: _enabled ? _press : null,
                icon: Icon(widget.icon),
                label: widget.child,
              ),
      ),
    );
  }

  void _press() {
    unawaited(HarvestHaptics.tick());
    widget.onPressed?.call();
  }
}

/// Convenience full-width variant used at the bottom of sheets.
class BigBouncySheetButton extends StatelessWidget {
  const BigBouncySheetButton({
    required this.onPressed,
    required this.child,
    super.key,
  });

  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: HarvestSpacing.xs),
      child: SizedBox(
        width: double.infinity,
        child: BigBouncyButton(onPressed: onPressed, child: child),
      ),
    );
  }
}
