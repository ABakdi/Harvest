import 'package:flutter/services.dart';

/// Central haptics wrapper so the "feel" of the app is tuned in one place.
abstract final class HarvestHaptics {
  /// The signature satisfying thud on a successful check-in.
  static Future<void> thud() => HapticFeedback.mediumImpact();

  /// Light tick for selections and toggles.
  static Future<void> tick() => HapticFeedback.selectionClick();
}
