import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/account/data/api_client.dart' show Me;
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/account/presentation/account_card.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:harvest/l10n/app_localizations_en.dart';

class _Account extends AccountController {
  final ended = <String>[];

  @override
  Future<AccountState> build() async => const AccountState(
    serverUrl: 'https://harvest.example.com',
    me: Me(id: 'u1', email: 'maya@example.com', syncSalt: 'salt'),
  );

  @override
  Future<List<Map<String, Object?>>> sessions() async => [
    {'id': 'me', 'client': 'mobile', 'current': true},
    for (final id in ['a', 'b'])
      if (!ended.contains(id))
        {
          'id': id,
          'client': 'web',
          'deviceName': 'Chrome on Linux',
          'createdAt': '2026-09-20T10:00:00.000Z',
          'lastSeenAt': '2026-09-26T10:00:00.000Z',
        },
  ];

  @override
  Future<void> endSession(String id) async => ended.add(id);
}

void main() {
  final l10n = AppLocalizationsEn();

  testWidgets('every other device can be signed out at once, after asking '
      '(U6-18)', (tester) async {
    final account = _Account();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [accountControllerProvider.overrideWith(() => account)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: AccountDevices())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('end-other-sessions')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.accountEndOthersTitle), findsOneWidget);
    expect(account.ended, isEmpty, reason: 'asked first');

    await tester.tap(find.text(l10n.accountEndOthers).last);
    await tester.pumpAndSettle();
    expect(account.ended, ['a', 'b']);
    expect(find.text(l10n.accountOthersEnded(2)), findsOneWidget);
    // Only this phone is left: nothing more to sign out.
    expect(find.byKey(const ValueKey('end-other-sessions')), findsNothing);
  });
}
