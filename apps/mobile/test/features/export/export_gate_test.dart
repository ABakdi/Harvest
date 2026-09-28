import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/account/data/api_client.dart';
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/export/presentation/export_gate.dart';
import 'package:harvest/features/security/domain/auth_gateway.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:harvest/l10n/app_localizations_en.dart';

import '../../support/fake_auth.dart';

class _Account extends AccountController {
  _Account({required this.signedIn});

  final bool signedIn;

  @override
  Future<AccountState> build() async => AccountState(
    serverUrl: 'https://harvest.example.com',
    me: signedIn
        ? Me(
            id: 'u1',
            email: 'maya@example.com',
            syncSalt: 'the-account-salt',
            verifiedAt: DateTime.utc(2026, 9, 2),
          )
        : null,
  );
}

/// Taking my data out asks who I am first (Phase 7, M7.6).
void main() {
  final l10n = AppLocalizationsEn();

  Future<List<bool>> gate(
    WidgetTester tester, {
    required bool signedIn,
    Future<void> Function(String password)? reauth,
    AuthGateway? lock,
  }) async {
    final answers = <bool>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountControllerProvider.overrideWith(
            () => _Account(signedIn: signedIn),
          ),
          if (reauth != null) reauthProvider.overrideWithValue(reauth),
          if (lock != null) authGatewayProvider.overrideWithValue(lock),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                ref.watch(accountControllerProvider);
                return TextButton(
                  onPressed: () async =>
                      answers.add(await confirmItsMe(context, ref)),
                  child: const Text('Export'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return answers;
  }

  Future<void> typePassword(WidgetTester tester, String password) async {
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.exportConfirmPassword), findsOneWidget);
    await tester.enterText(find.byType(TextField), password);
    await tester.tap(find.text(l10n.exportAction));
    await tester.pumpAndSettle();
  }

  testWidgets('signed in, the password the server takes lets it go', (
    tester,
  ) async {
    final sent = <String>[];
    final answers = await gate(
      tester,
      signedIn: true,
      reauth: (password) async => sent.add(password),
    );
    await typePassword(tester, 'Tamarind-orchard-7');
    expect(sent, ['Tamarind-orchard-7']);
    expect(answers, [true]);
  });

  testWidgets('a wrong password, or too many, stops it and says why', (
    tester,
  ) async {
    var answer = const ApiException('forbidden', 403);
    final answers = await gate(
      tester,
      signedIn: true,
      reauth: (_) async => throw answer,
    );
    await typePassword(tester, 'not it');
    expect(answers, [false]);
    expect(find.text(l10n.syncPinWrongPassword), findsOneWidget);

    answer = const ApiException(
      'rate_limited',
      429,
      null,
      null,
      null,
      Duration(seconds: 600),
    );
    await typePassword(tester, 'again');
    expect(answers, [false, false]);
    expect(find.text(l10n.exportConfirmLimited(10)), findsOneWidget);
  });

  testWidgets('a password prompt closed is no export', (tester) async {
    var asked = 0;
    final answers = await gate(
      tester,
      signedIn: true,
      reauth: (_) async => asked++,
    );
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();
    expect(asked, 0);
    expect(answers, [false]);
  });

  testWidgets('signed out, the phone’s own lock decides', (tester) async {
    final lock = FakeAuthGateway();
    final answers = await gate(tester, signedIn: false, lock: lock);
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    expect(lock.calls, 1);

    lock.outcome = AuthOutcome.refused;
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.exportConfirmRefused), findsOneWidget);

    // No lock at all: nothing to ask with, and nothing it would protect.
    lock.available = false;
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    expect(lock.calls, 2);
    expect(answers, [true, false, true]);
  });
}
