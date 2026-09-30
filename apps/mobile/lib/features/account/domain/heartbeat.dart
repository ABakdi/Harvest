import 'package:flutter/foundation.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/account/data/api_client.dart';
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'heartbeat.g.dart';

/// This phone's own settings for what it tells the server about itself
/// ([[Admin]]): kept here, never synced (`account.` is not a portable
/// prefix).
abstract final class HeartbeatKeys {
  /// The Harvest Day of the last heartbeat that landed.
  static const day = 'account.heartbeatDay';

  /// *Share my streak*: on unless turned off.
  static const shareStreak = 'account.shareStreak';
}

/// The version this build calls itself; its own provider so a test
/// needs no platform channel.
@Riverpod(keepAlive: true)
Future<String> appVersion(Ref ref) async =>
    (await PackageInfo.fromPlatform()).version;

/// Tells the server once a day that this phone is in use: the platform,
/// the app's version, and — only while *Share my streak* is on — the
/// global streak, now and at its longest ([[Admin]] AD3). Only for a
/// signed-in phone; one without an account is never counted (AD2).
/// A heartbeat that fails is simply sent the next time it is asked for.
class Heartbeat {
  Heartbeat({
    required this.api,
    required this.settings,
    required this.streaks,
    required this.version,
  });

  final ApiClient api;
  final SettingsRepository settings;
  final StreakService streaks;
  final Future<String> Function() version;

  Future<void>? _sending;

  /// Sends today's heartbeat unless it already went. [now] for tests.
  Future<void> beat({DateTime? now}) =>
      _sending ??= _beat(now ?? DateTime.now()).whenComplete(
        () => _sending = null,
      );

  Future<void> _beat(DateTime now) async {
    final today = HarvestDay.of(now).key;
    if (await settings.getString(HeartbeatKeys.day) == today) return;
    try {
      final share = await settings.getBool(HeartbeatKeys.shareStreak) ?? true;
      final streak = share ? await streaks.global() : null;
      await api.post('/v1/me/heartbeat', {
        'platform': 'android',
        'appVersion': await version(),
        'streak': streak == null
            ? null
            : {'current': streak.current, 'best': streak.best},
      });
      await settings.setString(HeartbeatKeys.day, today);
    } on ApiException catch (error) {
      // Offline, or a server from before it: tomorrow, or the next start.
      debugPrint('[heartbeat] not sent: ${error.code}');
    } on Object catch (error) {
      debugPrint('[heartbeat] not sent: ${error.runtimeType}');
    }
  }
}

@Riverpod(keepAlive: true)
Heartbeat heartbeat(Ref ref) => Heartbeat(
  api: ref.watch(apiClientProvider),
  settings: ref.watch(settingsRepositoryProvider),
  streaks: ref.watch(streakServiceProvider),
  version: () => ref.read(appVersionProvider.future),
);
