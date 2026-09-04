import 'package:flutter/material.dart';

/// The five Harvest looks (checkpoint gap G7). Each carries a light and
/// a dark palette plus its signature gradient.
enum ThemePreset { harvest, sunrise, ocean, orchard, dusk }

class HarvestPalette {
  const HarvestPalette({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.surfaceLight,
    required this.onSurfaceLight,
    required this.surfaceDark,
    required this.onSurfaceDark,
    required this.gradient,
  });

  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color surfaceLight;
  final Color onSurfaceLight;
  final Color surfaceDark;
  final Color onSurfaceDark;

  /// Signature gradient: primary actions, XP fill, accents.
  final List<Color> gradient;
}

/// Vibrant palettes — earthy roots, more chroma than the v0 look.
const harvestPalettes = <ThemePreset, HarvestPalette>{
  ThemePreset.harvest: HarvestPalette(
    primary: Color(0xFFE85D3A),
    secondary: Color(0xFF3DA576),
    tertiary: Color(0xFFFFB13D),
    surfaceLight: Color(0xFFFBF4E4),
    onSurfaceLight: Color(0xFF32355C),
    surfaceDark: Color(0xFF262941),
    onSurfaceDark: Color(0xFFF0EBDA),
    gradient: [Color(0xFFE85D3A), Color(0xFFFFB13D)],
  ),
  ThemePreset.sunrise: HarvestPalette(
    primary: Color(0xFFFF4F6D),
    secondary: Color(0xFFFF8E53),
    tertiary: Color(0xFFFFC93C),
    surfaceLight: Color(0xFFFFF4EC),
    onSurfaceLight: Color(0xFF43273B),
    surfaceDark: Color(0xFF2C1B32),
    onSurfaceDark: Color(0xFFFFE9DC),
    gradient: [Color(0xFFFF4F6D), Color(0xFFFFC93C)],
  ),
  ThemePreset.ocean: HarvestPalette(
    primary: Color(0xFF0E9DE9),
    secondary: Color(0xFF10BFA5),
    tertiary: Color(0xFF7C6FF0),
    surfaceLight: Color(0xFFEDF7FD),
    onSurfaceLight: Color(0xFF16324A),
    surfaceDark: Color(0xFF102839),
    onSurfaceDark: Color(0xFFDDF0FB),
    gradient: [Color(0xFF0E9DE9), Color(0xFF10BFA5)],
  ),
  ThemePreset.orchard: HarvestPalette(
    primary: Color(0xFF1FB25A),
    secondary: Color(0xFF8BC926),
    tertiary: Color(0xFFF7C948),
    surfaceLight: Color(0xFFF2FBEC),
    onSurfaceLight: Color(0xFF1C3325),
    surfaceDark: Color(0xFF16281D),
    onSurfaceDark: Color(0xFFE4F5DE),
    gradient: [Color(0xFF1FB25A), Color(0xFFF7C948)],
  ),
  ThemePreset.dusk: HarvestPalette(
    primary: Color(0xFF8B5CF6),
    secondary: Color(0xFFEC4899),
    tertiary: Color(0xFF38BDF8),
    surfaceLight: Color(0xFFF6F1FF),
    onSurfaceLight: Color(0xFF2C2350),
    surfaceDark: Color(0xFF211A38),
    onSurfaceDark: Color(0xFFEDE7FD),
    gradient: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
  ),
};

/// Theme extension carrying the preset gradient into widget code.
@immutable
class HarvestGradients extends ThemeExtension<HarvestGradients> {
  const HarvestGradients({required this.primary});

  final LinearGradient primary;

  @override
  HarvestGradients copyWith({LinearGradient? primary}) =>
      HarvestGradients(primary: primary ?? this.primary);

  @override
  HarvestGradients lerp(HarvestGradients? other, double t) {
    if (other == null) return this;
    return HarvestGradients(
      primary: LinearGradient.lerp(primary, other.primary, t)!,
    );
  }
}

extension HarvestThemeX on ThemeData {
  LinearGradient get primaryGradient =>
      extension<HarvestGradients>()?.primary ??
      LinearGradient(colors: [colorScheme.primary, colorScheme.tertiary]);
}

/// The brand green, straight off the launcher icon.
///
/// The five presets recolour the app; they do not recolour Harvest
/// itself. The icon, the splash and the home-screen widget all wear
/// this one gradient so the app looks like itself before any of its
/// settings have been read.
abstract final class HarvestBrand {
  static const deep = Color(0xFF1F8A46);
  static const mid = Color(0xFF4FB54C);
  static const light = Color(0xFF8AD84E);

  /// The olive's own dark green — fruit on the splash tree.
  static const olive = Color(0xFF17492C);

  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [deep, mid, light],
    stops: [0, 0.55, 1],
  );
}

abstract final class HarvestSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

abstract final class HarvestRadii {
  static const double chip = 12;
  static const double button = 16;
  static const double card = 20;
  static const double sheet = 28;
}
