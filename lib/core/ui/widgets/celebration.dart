import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// A brief, tasteful burst of leaves rising over the tapped position —
/// the sprite moment of a check-in, no assets required.
void showCheckInBurst(
  BuildContext context,
  Offset globalPosition, {
  IconData icon = Icons.eco,
  Color? color,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _Burst(
      origin: globalPosition,
      icon: icon,
      color: color,
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _Burst extends StatefulWidget {
  const _Burst({
    required this.origin,
    required this.onDone,
    required this.icon,
    this.color,
  });

  final Offset origin;
  final VoidCallback onDone;
  final IconData icon;
  final Color? color;

  @override
  State<_Burst> createState() => _BurstState();
}

class _BurstState extends State<_Burst> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final random = Random();
    _particles = List.generate(7, (i) {
      final angle = -pi / 2 + (random.nextDouble() - 0.5) * pi * 0.9;
      return _Particle(
        angle: angle,
        distance: 60 + random.nextDouble() * 50,
        size: 14 + random.nextDouble() * 8,
        spin: (random.nextDouble() - 0.5) * 3,
      );
    });
    unawaited(
      _controller.forward().then((_) {
        if (mounted) widget.onDone();
      }),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.secondary;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(_controller.value);
          final fade = 1 - Curves.easeIn.transform(_controller.value);
          return Stack(
            children: [
              for (final p in _particles)
                Positioned(
                  left: widget.origin.dx + cos(p.angle) * p.distance * t - 8,
                  top: widget.origin.dy + sin(p.angle) * p.distance * t - 8,
                  child: Opacity(
                    opacity: fade,
                    child: Transform.rotate(
                      angle: p.spin * t,
                      child: Icon(widget.icon, size: p.size, color: color),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.spin,
  });

  final double angle;
  final double distance;
  final double size;
  final double spin;
}
