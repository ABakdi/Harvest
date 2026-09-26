import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:harvest/features/lists/domain/share_links.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'share_inbox.g.dart';

/// What *Share → Harvest* handed over, waiting for the sheet
/// ([[Lists]]: Saving from anywhere).
///
/// The activity keeps the share until asked, because on a cold start it
/// arrives before there is an engine to tell; it also nudges Dart when a
/// share lands in the app while it is open. Either way this takes it,
/// and the shell — the first place inside the navigator — opens the
/// *Save to a list* sheet, as it does for the widget's quick actions.
@Riverpod(keepAlive: true)
class ShareInbox extends _$ShareInbox {
  static const _channel = MethodChannel('harvest/share');

  @override
  SharedDraft? build() => null;

  /// Hands a share in directly — what the channel does, and what a test
  /// does instead of the channel.
  // A named method reads better than a setter at the call sites.
  // ignore: use_setters_to_change_properties
  void receive(SharedDraft draft) => state = draft;

  /// Consumes the waiting share; null when there is none.
  SharedDraft? take() {
    final draft = state;
    if (draft != null) state = null;
    return draft;
  }

  /// Starts listening for shares into a running app, and picks up the
  /// one that launched it. Android only.
  Future<void> listen() async {
    if (!Platform.isAndroid) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shared') await check();
    });
    await check();
  }

  /// Asks the activity for a share it is holding — on start, on the
  /// nudge, and on every return to the front in case the nudge was
  /// missed.
  Future<void> check() async {
    if (!Platform.isAndroid) return;
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>(
        'takeShared',
      );
      if (raw == null) return;
      final draft = SharedDraft.of(
        subject: raw['subject'] as String?,
        text: raw['text'] as String?,
      );
      if (draft.title.isEmpty && draft.link == null) return;
      state = draft;
    } on MissingPluginException {
      return;
    } on PlatformException catch (error) {
      debugPrint('[share] unavailable: ${error.code}');
    }
  }
}
