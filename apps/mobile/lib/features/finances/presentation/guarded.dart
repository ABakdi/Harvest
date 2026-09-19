import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Awaits a write and, if it fails, says so instead of leaving the
/// screen looking as though it worked. A successful money move gets the
/// signature thud.
Future<bool> runGuarded(
  BuildContext context,
  Future<void> future, {
  bool haptic = true,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  try {
    await future;
    if (haptic) await HarvestHaptics.thud();
    return true;
    // A refused write (an over-payment, say) reports the same way as a
    // failed one: the user hears about it instead of guessing.
    // ignore: avoid_catching_errors
  } on ArgumentError catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.saveFailed)));
    return false;
  } on PlatformException catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.saveFailed)));
    return false;
  } on Exception catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.saveFailed)));
    return false;
  }
}
