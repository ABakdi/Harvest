import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/features/account/data/api_client.dart';
import 'package:harvest/features/account/domain/heartbeat.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/memory_secrets.dart';

/// Once a day a signed-in phone says it is in use ([[Admin]]): its
/// platform, its version, and its streak only while sharing is on.
void main() {
  late HarvestDatabase db;
  late SettingsRepository settings;
  late List<Map<String, Object?>> sent;
  var answer = 204;

  Heartbeat heartbeatWith() {
    final tokens = TokenStore(MemorySecrets())..access = 'token';
    return Heartbeat(
      api: ApiClient(
        baseUrl: () => Uri.parse('https://harvest.example.org'),
        tokens: tokens,
        client: MockClient((request) async {
          expect(request.url.path, '/v1/me/heartbeat');
          expect(request.headers['authorization'], 'Bearer token');
          sent.add(jsonDecode(request.body) as Map<String, Object?>);
          return http.Response(
            answer == 204 ? '' : '{"error":{"code":"internal","message":"x"}}',
            answer,
          );
        }),
      ),
      settings: settings,
      streaks: StreakService(db),
      version: () async => '3.3.0',
    );
  }

  setUp(() async {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    settings = SettingsRepository(db);
    sent = [];
    answer = 204;
    await db
        .into(db.streaks)
        .insert(
          StreaksCompanion.insert(
            scope: StreakService.globalScope,
            current: const Value(4),
            best: const Value(9),
          ),
        );
  });
  tearDown(() => db.close());

  test('says the platform, the version and the streak, once a day', () async {
    final heartbeat = heartbeatWith();
    final morning = DateTime(2026, 9, 29, 9);
    await heartbeat.beat(now: morning);
    await heartbeat.beat(now: morning.add(const Duration(hours: 5)));
    expect(sent, [
      {
        'platform': 'android',
        'appVersion': '3.3.0',
        'streak': {'current': 4, 'best': 9},
      },
    ]);
    // The next Harvest Day, once more.
    await heartbeat.beat(now: morning.add(const Duration(days: 1)));
    expect(sent, hasLength(2));
  });

  test('leaves the streak out while sharing is off', () async {
    await settings.setBool(HeartbeatKeys.shareStreak, value: false);
    await heartbeatWith().beat(now: DateTime(2026, 9, 29, 9));
    expect(sent.single['streak'], isNull);
    expect(sent.single['appVersion'], '3.3.0');
  });

  test('a heartbeat that failed goes again the next time', () async {
    answer = 500;
    final heartbeat = heartbeatWith();
    final at = DateTime(2026, 9, 29, 9);
    await heartbeat.beat(now: at);
    expect(await settings.getString(HeartbeatKeys.day), isNull);
    answer = 204;
    await heartbeat.beat(now: at.add(const Duration(minutes: 1)));
    expect(sent, hasLength(2));
    expect(await settings.getString(HeartbeatKeys.day), isNotNull);
  });
}
