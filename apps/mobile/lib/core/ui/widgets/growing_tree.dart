import 'dart:math' as math;

import 'package:flutter/material.dart';

/// An olive tree growing from nothing: trunk, branches, leaves, blossom,
/// fruit — the whole metaphor the app is named after, in about a second
/// and a half.
///
/// The tree is generated once from a fixed seed, so it is the same tree
/// every launch; only [progress] moves. Everything is drawn, not
/// animated frame by frame, so it costs one repaint and no assets.
class GrowingOliveTree extends StatelessWidget {
  const GrowingOliveTree({
    required this.progress,
    required this.wood,
    required this.foliage,
    required this.blossom,
    required this.fruit,
    super.key,
  });

  /// 0 = bare soil, 1 = a tree in fruit.
  final double progress;
  final Color wood;
  final Color foliage;
  final Color blossom;
  final Color fruit;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _TreePainter(
      progress: progress.clamp(0, 1).toDouble(),
      wood: wood,
      foliage: foliage,
      blossom: blossom,
      fruit: fruit,
    ),
    size: Size.infinite,
  );
}

/// One limb of the tree, in a unit square with the ground at y = 1.
class _Limb {
  const _Limb({
    required this.from,
    required this.to,
    required this.width,
    required this.depth,
    required this.start,
    required this.span,
  });

  final Offset from;
  final Offset to;
  final double width;
  final int depth;

  /// When this limb starts and how long it takes, as fractions of the
  /// trunk-and-branch phase.
  final double start;
  final double span;

  Offset at(double t) => Offset.lerp(from, to, t)!;
  double get angle => math.atan2(to.dy - from.dy, to.dx - from.dx);
}

/// The phases, as fractions of the whole animation. They overlap on
/// purpose: leaves start opening before the last twig has finished.
const _woodPhase = (0.0, 0.52);
const _leafPhase = (0.38, 0.74);
const _blossomPhase = (0.60, 0.84);
const _fruitPhase = (0.74, 1.0);

double _phase(double p, (double, double) window) {
  final (from, to) = window;
  if (p <= from) return 0;
  if (p >= to) return 1;
  return (p - from) / (to - from);
}

class _TreePainter extends CustomPainter {
  _TreePainter({
    required this.progress,
    required this.wood,
    required this.foliage,
    required this.blossom,
    required this.fruit,
  });

  final double progress;
  final Color wood;
  final Color foliage;
  final Color blossom;
  final Color fruit;

  static final List<_Limb> _limbs = _grow();
  static final List<_Limb> _leafAnchors = _limbs
      .where((limb) => limb.depth >= 2)
      .toList();

  /// The tree itself: a trunk that forks three times, each fork a
  /// little shorter and thinner, leaning by a fixed pseudo-random wobble
  /// so it looks grown rather than drawn with a compass.
  static List<_Limb> _grow() {
    final random = math.Random(7);
    final limbs = <_Limb>[];

    void branch({
      required Offset from,
      required double angle,
      required double length,
      required double width,
      required int depth,
      required double start,
      required double span,
    }) {
      final to = from + Offset(math.cos(angle), math.sin(angle)) * length;
      limbs.add(
        _Limb(
          from: from,
          to: to,
          width: width,
          depth: depth,
          start: start,
          span: span,
        ),
      );
      if (depth == 3) return;
      final spread = 0.50 + random.nextDouble() * 0.18;
      for (final side in [-1, 1]) {
        // Each fork is pulled back towards the sky before it is spread,
        // which is what stops the third generation from growing
        // sideways and turning the tree into a shrub.
        final upright = angle * 0.62 + (-math.pi / 2) * 0.38;
        branch(
          from: to,
          angle: upright + side * spread + (random.nextDouble() - 0.5) * 0.2,
          length: length * (0.76 + random.nextDouble() * 0.1),
          width: width * 0.6,
          depth: depth + 1,
          start: start + span * 0.8,
          span: span * 0.72,
        );
      }
    }

    branch(
      from: const Offset(0.5, 0.98),
      angle: -math.pi / 2,
      length: 0.30,
      width: 0.055,
      depth: 0,
      start: 0,
      span: 0.42,
    );
    return _fit(limbs);
  }

  /// Scales the grown tree about its base so the canopy always sits
  /// inside the square it is painted in, whatever the random wobble did.
  static List<_Limb> _fit(List<_Limb> limbs) {
    const base = Offset(0.5, 0.98);
    var reachX = 0.0;
    var reachY = 0.0;
    for (final limb in limbs) {
      reachX = math.max(reachX, (limb.to.dx - base.dx).abs() + limb.width);
      reachY = math.max(reachY, (base.dy - limb.to.dy) + limb.width);
    }
    // Room for the leaves, which stick out past the twigs they hang on.
    final factor = math.min(0.38 / reachX, 0.86 / reachY);
    Offset scaled(Offset p) => base + (p - base) * factor;
    return [
      for (final limb in limbs)
        _Limb(
          from: scaled(limb.from),
          to: scaled(limb.to),
          width: limb.width * factor,
          depth: limb.depth,
          start: limb.start,
          span: limb.span,
        ),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height);
    final origin = Offset((size.width - scale) / 2, size.height - scale);
    Offset place(Offset unit) =>
        origin + Offset(unit.dx * scale, unit.dy * scale);

    _paintGround(canvas, size, scale);
    _paintWood(canvas, place, scale);
    _paintFoliage(canvas, place, scale);
  }

  /// A low mound of soil, so the tree stands on something.
  void _paintGround(Canvas canvas, Size size, double scale) {
    final grown = _phase(progress, _woodPhase);
    if (grown <= 0) return;
    final width = size.width * (0.25 + 0.35 * grown);
    final centre = Offset(size.width / 2, size.height - 0.01 * scale);
    canvas.drawOval(
      Rect.fromCenter(center: centre, width: width, height: 0.045 * scale),
      Paint()..color = wood.withValues(alpha: 0.28),
    );
  }

  void _paintWood(Canvas canvas, Offset Function(Offset) place, double scale) {
    final grown = _phase(progress, _woodPhase);
    final paint = Paint()
      ..color = wood
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final limb in _limbs) {
      final t = ((grown - limb.start) / limb.span).clamp(0, 1).toDouble();
      if (t <= 0) continue;
      paint
        ..strokeWidth = limb.width * scale
        ..color = wood;
      canvas.drawLine(place(limb.from), place(limb.at(t)), paint);
    }
  }

  void _paintFoliage(
    Canvas canvas,
    Offset Function(Offset) place,
    double scale,
  ) {
    final leafT = _phase(progress, _leafPhase);
    final blossomT = _phase(progress, _blossomPhase);
    final fruitT = _phase(progress, _fruitPhase);
    if (leafT <= 0) return;

    final random = math.Random(19);
    final leaf = Paint()..color = foliage;
    final flower = Paint()..color = blossom;
    final olive = Paint()..color = fruit;

    for (var i = 0; i < _leafAnchors.length; i++) {
      final limb = _leafAnchors[i];
      // Each leaf opens a little after the one before it.
      final stagger = i / _leafAnchors.length * 0.45;
      final open = ((leafT - stagger) / (1 - stagger)).clamp(0, 1).toDouble();
      if (open <= 0) continue;

      // Two leaves a twig, spaced along it and opening to opposite
      // sides. Three, clustered, merged into a star — in a silhouette
      // the gaps between the leaves are what makes them leaves.
      for (var n = 0; n < 2; n++) {
        final side = n.isEven ? -1.0 : 1.0;
        final along = 0.42 + n * 0.42;
        final centre = place(limb.at(along));
        final angle = limb.angle + side * (0.95 + random.nextDouble() * 0.2);
        final length = (0.115 + random.nextDouble() * 0.02) * scale * open;
        _drawLeaf(canvas, centre, angle, length, length * 0.46, leaf);
      }

      // Fruit sits among the leaves, not out past them: every other
      // twig carries one, back from the tip.
      if (limb.depth < 3 || i.isOdd) continue;
      final tip = place(limb.at(0.72));
      final bloom = ((blossomT - stagger * 0.6) / (1 - stagger * 0.6))
          .clamp(0, 1)
          .toDouble();
      final ripe = ((fruitT - stagger * 0.6) / (1 - stagger * 0.6))
          .clamp(0, 1)
          .toDouble();

      // Blossom swells, then gives way to the fruit it becomes.
      if (bloom > 0 && ripe < 1) {
        final petal = 0.019 * scale * bloom * (1 - ripe);
        for (var p = 0; p < 5; p++) {
          final a = p * math.pi * 2 / 5;
          canvas.drawCircle(
            tip + Offset(math.cos(a), math.sin(a)) * petal,
            petal * 0.85,
            flower,
          );
        }
      }
      if (ripe > 0) {
        canvas.drawOval(
          Rect.fromCenter(
            center: tip,
            width: 0.042 * scale * ripe,
            height: 0.052 * scale * ripe,
          ),
          olive,
        );
      }
    }
  }

  /// A pointed olive leaf: two arcs meeting at both ends.
  void _drawLeaf(
    Canvas canvas,
    Offset centre,
    double angle,
    double length,
    double width,
    Paint paint,
  ) {
    final half = length / 2;
    final path = Path()
      ..moveTo(-half, 0)
      ..quadraticBezierTo(0, -width / 2, half, 0)
      ..quadraticBezierTo(0, width / 2, -half, 0)
      ..close();
    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..rotate(angle)
      ..drawPath(path, paint)
      ..restore();
  }

  @override
  bool shouldRepaint(_TreePainter old) =>
      old.progress != progress ||
      old.wood != wood ||
      old.foliage != foliage ||
      old.blossom != blossom ||
      old.fruit != fruit;
}
