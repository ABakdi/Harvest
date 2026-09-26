import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/gallery/presentation/memory_view.dart';
import 'package:harvest/features/health/domain/steps.dart';

/// [[Audit-v2]] wave 4: what comes from outside, and what a picture
/// costs to draw.
void main() {
  group('S3-06: an imported stride', () {
    test('is clamped to a leg, and a missing one is the default', () {
      expect(clampStride(null), defaultStrideCm);
      expect(clampStride(0), minStrideCm);
      expect(clampStride(-40), minStrideCm);
      expect(clampStride(99999), maxStrideCm);
      expect(clampStride(78), 78);
    });

    test('so the distance stays a distance', () {
      expect(stepsToMetres(10000, strideCm: clampStride(99999)), 15000);
      expect(stepsToMetres(10000, strideCm: clampStride(0)), 3000);
    });
  });

  group('U3-05: a picture is decoded at the size it is drawn', () {
    testWidgets('device pixels, not layout pixels', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 3),
          child: Builder(
            builder: (inner) {
              context = inner;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(MemoryView.decodeWidth(context, 120), 360);
      expect(MemoryView.decodeWidth(context, 44), 132);
    });

    testWidgets('an unbounded width decodes whole rather than at a pixel', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        Builder(
          builder: (inner) {
            context = inner;
            return const SizedBox();
          },
        ),
      );
      expect(MemoryView.decodeWidth(context, double.infinity), isNull);
      expect(MemoryView.decodeWidth(context, 0), isNull);
    });
  });
}
