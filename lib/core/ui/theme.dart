import 'package:flutter/material.dart';
import 'package:harvest/core/ui/tokens.dart';

/// Light and dark [ThemeData] for the app, built from the Harvest tokens.
abstract final class HarvestTheme {
  static ThemeData get light => _base(
        ColorScheme.fromSeed(
          seedColor: HarvestColors.terracotta,
          primary: HarvestColors.terracotta,
          secondary: HarvestColors.sage,
          tertiary: HarvestColors.sun,
          surface: HarvestColors.cream,
          onSurface: HarvestColors.soil,
        ),
      );

  static ThemeData get dark => _base(
        ColorScheme.fromSeed(
          seedColor: HarvestColors.terracotta,
          brightness: Brightness.dark,
          primary: HarvestColors.terracotta,
          secondary: HarvestColors.sage,
          tertiary: HarvestColors.sun,
          surface: HarvestColors.soilDeep,
          onSurface: HarvestColors.creamMuted,
        ),
      );

  static ThemeData _base(ColorScheme scheme) {
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
