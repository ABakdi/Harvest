import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/platform/notifications.dart';
import 'package:harvest/features/account/data/api_client.dart';
import 'package:harvest/features/news/data/news_providers.dart';
import 'package:harvest/features/news/domain/news.dart';
import 'package:harvest/features/news/presentation/news_popups.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/memory_secrets.dart';

/// News from Harvest ([[Admin]]): each push notified once, each pop-up
/// shown once, remembered on the phone; nothing asked while it is off.
void main() {
  late HarvestDatabase db;
  late SettingsRepository settings;
  late List<Announcement> notified;
  late List<http.Request> asked;
  late List<Map<String, Object?>> news;

  Map<String, Object?> piece(
    String id, {
    bool push = false,
    bool popup = false,
    String? link,
  }) => {
    'id': id,
    'title': 'Title $id',
    'body': 'Body $id',
    'link': link,
    'push': push,
    'popup': popup,
    'audience': 'everyone',
    'startsAt': '2026-09-29T00:00:00.000Z',
    'endsAt': null,
    'createdAt': '2026-09-29T00:00:00.000Z',
  };

  NewsService service({String? access}) {
    final tokens = TokenStore(MemorySecrets())..access = access;
    return NewsService(
      api: ApiClient(
        baseUrl: () => Uri.parse('https://harvest.example.org'),
        tokens: tokens,
        client: MockClient((request) async {
          asked.add(request);
          return http.Response(
            jsonEncode({'announcements': news}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
      settings: settings,
      notify: (announcement) async => notified.add(announcement),
    );
  }

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    settings = SettingsRepository(db);
    notified = [];
    asked = [];
    news = [];
  });
  tearDown(() => db.close());

  test(
    'notifies a push once, and answers a pop-up until it is shown',
    () async {
      news = [
        piece('b2', popup: true),
        piece('a1', push: true, popup: true),
      ];
      final news1 = service();
      final at = DateTime(2026, 9, 29, 9);
      final popups = await news1.check(signedIn: false, now: at);
      expect(notified.map((n) => n.id), ['a1']);
      // Oldest first: the server answers newest first.
      expect(popups.map((n) => n.id), ['a1', 'b2']);

      await news1.markShown('a1');
      final again = await news1.check(
        signedIn: false,
        force: true,
        now: at.add(const Duration(hours: 1)),
      );
      expect(notified, hasLength(1), reason: 'a push is notified once');
      expect(again.map((n) => n.id), ['b2']);
    },
  );

  test(
    'asks without a session in the background, with it when signed in',
    () async {
      final at = DateTime(2026, 9, 29, 9);
      await service(access: 'token').check(signedIn: false, now: at);
      expect(asked.single.headers['authorization'], isNull);
      await service(access: 'token').check(
        signedIn: true,
        force: true,
        now: at,
      );
      expect(asked.last.headers['authorization'], 'Bearer token');
    },
  );

  test('asks at most every quarter of an hour, unless forced', () async {
    final news1 = service();
    final at = DateTime(2026, 9, 29, 9);
    await news1.check(signedIn: false, now: at);
    await news1.check(signedIn: false, now: at.add(const Duration(minutes: 5)));
    expect(asked, hasLength(1));
    await news1.check(
      signedIn: false,
      now: at.add(const Duration(minutes: 16)),
    );
    expect(asked, hasLength(2));
  });

  test('turned off, asks nothing and says nothing', () async {
    await settings.setBool(NewsKeys.enabled, value: false);
    news = [piece('a1', push: true, popup: true)];
    final popups = await service().check(signedIn: false, force: true);
    expect(asked, isEmpty);
    expect(notified, isEmpty);
    expect(popups, isEmpty);
  });

  test('keeps only an https link, and leaves out what is not news', () {
    expect(
      Announcement.fromJson(piece('a', link: 'https://x.org'))?.link,
      'https://x.org',
    );
    expect(
      Announcement.fromJson(piece('a', link: 'http://x.org'))?.link,
      isNull,
    );
    expect(
      Announcement.fromJson(piece('a', link: 'javascript:alert(1)'))?.link,
      isNull,
    );
    expect(Announcement.fromJson({'id': 1}), isNull);
    expect(Announcement.fromJson('nonsense'), isNull);
  });

  test('a notification id is stable and clear of the reminders', () {
    final id = LocalNewsNotifier.idOf('66f9a1b2c3d4e5f6a7b8c9d0');
    expect(id, LocalNewsNotifier.idOf('66f9a1b2c3d4e5f6a7b8c9d0'));
    expect(id, greaterThanOrEqualTo(0x10000000));
    expect(id, lessThan(0x20000000));
  });

  test('a news route carries its link, and only a news route does', () {
    expect(ReminderRoutes.newsLink('news:https://x.org/a'), 'https://x.org/a');
    expect(ReminderRoutes.newsLink('news'), isNull);
    expect(ReminderRoutes.newsLink('planner'), isNull);
  });

  testWidgets('a pop-up shows its title, body and link, and goes', (
    tester,
  ) async {
    final announcement = Announcement.fromJson(
      piece('a1', popup: true, link: 'https://harvest.abakdi.com/download'),
    )!;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showNewsDialog(context, announcement),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Title a1'), findsOneWidget);
    expect(find.text('Body a1'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('Title a1'), findsNothing);
  });
}
