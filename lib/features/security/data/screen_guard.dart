import 'dart:io';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'screen_guard.g.dart';

/// Keeps the app's contents out of the recents thumbnail.
///
/// Behind an interface for the same reason the rest of the lock is: the
/// phase machine's tests must not need a window.
// ignore: one_member_abstracts — an interface for a fake, not a callback.
abstract interface class ScreenGuard {
  /// Arms or disarms the platform's secure-window flag.
  Future<void> setSecure({required bool secure});
}

/// `FLAG_SECURE`, through `MainActivity`.
///
/// Flutter's lifecycle callbacks arrive after Android has taken the
/// recents snapshot, so a shield painted in Dart is always a frame too
/// late (checkpoint rule L4). This is the only thing that gets there
/// first — at the cost of blocking screenshots while the lock is on,
/// which is the trade the lock switch is making.
class PlatformScreenGuard implements ScreenGuard {
  const PlatformScreenGuard();

  static const _channel = MethodChannel('harvest/security');

  @override
  Future<void> setSecure({required bool secure}) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setSecure', secure);
    } on PlatformException {
      // A window that will not take the flag is not a reason to refuse
      // the lock; the prompt is still the thing doing the work.
    } on MissingPluginException {
      // Not running against MainActivity — tests, or another platform.
    }
  }
}

@Riverpod(keepAlive: true)
ScreenGuard screenGuard(Ref ref) => const PlatformScreenGuard();
