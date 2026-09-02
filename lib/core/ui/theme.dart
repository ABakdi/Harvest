import 'package:flutter/material.dart';
import 'package:harvest/core/ui/tokens.dart';

/// Light and dark [ThemeData] for any [ThemePreset].
abstract final class HarvestTheme {
  static ThemeData light(ThemePreset preset) {
    final palette = harvestPalettes[preset]!;
    return _base(
      palette,
      ColorScheme.fromSeed(
        seedColor: palette.primary,
        primary: palette.primary,
        secondary: palette.secondary,
        tertiary: palette.tertiary,
        surface: palette.surfaceLight,
        onSurface: palette.onSurfaceLight,
      ),
    );
  }

  static ThemeData dark(ThemePreset preset) {
    final palette = harvestPalettes[preset]!;
    return _base(
      palette,
      ColorScheme.fromSeed(
        seedColor: palette.primary,
        brightness: Brightness.dark,
        primary: palette.primary,
        secondary: palette.secondary,
        tertiary: palette.tertiary,
        surface: palette.surfaceDark,
        onSurface: palette.onSurfaceDark,
      ),
    );
  }

  static ThemeData _base(HarvestPalette palette, ColorScheme scheme) {
    // Bundled fonts — no runtime fetching, the app is complete offline.
    // Nunito carries Latin; the Arabic companion fills in for RTL text.
    final textTheme =
        ThemeData(brightness: scheme.brightness).textTheme.apply(
              fontFamily: 'Nunito',
              fontFamilyFallback: const ['IBMPlexSansArabic'],
              bodyColor: scheme.onSurface,
              displayColor: scheme.onSurface,
            );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      extensions: [
        HarvestGradients(
          primary: LinearGradient(
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
            colors: palette.gradient,
          ),
        ),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HarvestRadii.card),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HarvestRadii.button),
          ),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondary.withValues(alpha: 0.25),
      ),
    );
  }
}
