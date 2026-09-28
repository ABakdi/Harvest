import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/ui/theme.dart';
import 'package:harvest/core/ui/tokens.dart';

/// Text in the brand colours reads at WCAG AA on every look, light and
/// dark; the look itself keeps its hues ([[Audit-v3]] U6-09, U6-29).
void main() {
  for (final preset in ThemePreset.values) {
    for (final (name, theme) in [
      ('light', HarvestTheme.light(preset)),
      ('dark', HarvestTheme.dark(preset)),
    ]) {
      final scheme = theme.colorScheme;
      test('${preset.name} $name: brand text reads at 4.5:1', () {
        for (final color in [
          scheme.primaryText,
          scheme.secondaryText,
          scheme.tertiaryText,
        ]) {
          expect(
            contrastRatio(color, scheme.surface),
            greaterThanOrEqualTo(4.5),
          );
        }
        expect(
          contrastRatio(theme.tabBarTheme.labelColor!, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('${preset.name} $name: labels on the gradient read at 4.5:1', () {
        for (final end in theme.primaryGradient.colors) {
          expect(
            contrastRatio(theme.onPrimaryGradient, end),
            greaterThanOrEqualTo(4.5),
          );
        }
      });
    }
  }

  test('a readable colour keeps its hue', () {
    const amber = Color(0xFFFFB13D);
    final text = readableOn(amber, const Color(0xFFFBF4E4));
    expect(contrastRatio(text, const Color(0xFFFBF4E4)), greaterThan(4.5));
    expect(
      (HSLColor.fromColor(text).hue - HSLColor.fromColor(amber).hue).abs(),
      lessThan(2),
    );
  });

  test('dark cards are tints of the page, not of the seed', () {
    final scheme = HarvestTheme.dark(ThemePreset.harvest).colorScheme;
    final page = HSLColor.fromColor(scheme.surface).hue;
    final card = HSLColor.fromColor(scheme.surfaceContainerHigh).hue;
    expect((page - card).abs(), lessThan(15));
  });

  test('a selected segment is the page ink, not orange on green', () {
    final theme = HarvestTheme.light(ThemePreset.harvest);
    final fg = theme.segmentedButtonTheme.style!.foregroundColor!.resolve({
      WidgetState.selected,
    });
    expect(fg, theme.colorScheme.onSurface);
  });
}
