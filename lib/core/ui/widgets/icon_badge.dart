import 'package:flutter/material.dart';

/// A rounded, tinted tile holding one icon — the leading mark of every
/// list row in the app.
class IconBadge extends StatelessWidget {
  const IconBadge(
    this.icon, {
    required this.color,
    this.size = 44,
    this.iconSize = 22,
    this.filled = false,
    super.key,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  /// Solid background with a white glyph (for hero surfaces).
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(
        icon,
        size: iconSize,
        color: filled ? Colors.white : color,
      ),
    );
  }
}
