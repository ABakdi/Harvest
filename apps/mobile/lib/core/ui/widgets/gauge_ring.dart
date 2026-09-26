import 'package:flutter/material.dart';

/// A compact circular gauge: progress ring, status color, center child.
class GaugeRing extends StatelessWidget {
  const GaugeRing({
    required this.progress,
    required this.color,
    required this.child,
    this.size = 120,
    this.strokeWidth = 10,
    this.semanticsLabel,
    super.key,
  });

  /// 0..1; values beyond 1 fill the whole ring.
  final double progress;
  final Color color;
  final Widget child;
  final double size;
  final double strokeWidth;

  /// What the ring means, for screen readers.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticsLabel,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: progress.clamp(0, 1),
                strokeWidth: strokeWidth,
                strokeCap: StrokeCap.round,
                backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
