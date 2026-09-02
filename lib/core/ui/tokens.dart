import 'package:flutter/material.dart';

/// The Harvest palette — warm, earthy tones.
///
/// These raw values live only here; feature code uses the semantic roles
/// exposed through the theme's color scheme.
abstract final class HarvestColors {
  static const terracotta = Color(0xFFE07A5F);
  static const sage = Color(0xFF81B29A);
  static const soil = Color(0xFF3D405B);
  static const cream = Color(0xFFF4F1DE);
  static const sun = Color(0xFFF2CC8F);

  // Dark-theme derivatives of the same family.
  static const soilDeep = Color(0xFF2A2C42);
  static const soilNight = Color(0xFF20222F);
  static const creamMuted = Color(0xFFE8E4D4);
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
