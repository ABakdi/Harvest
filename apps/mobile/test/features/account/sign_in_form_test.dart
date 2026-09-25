import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/account/presentation/account_card.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:harvest/l10n/app_localizations_en.dart';

/// Signed out, with a server set; counts the calls that would reach it.
class _Account extends AccountController {
  int calls = 0;

  @override
  Future<AccountState> build() async =>
      const AccountState(serverUrl: 'https://harvest.example.com');

  @override
  Future<void> login({required String email, required String password}) async {
    calls++;
  }

  @override
  Future<void> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    calls++;
  }
}

void main() {
  final l10n = AppLocalizationsEn();

  group('signInProblem', () {
    String? problem({
      String server = 'https://harvest.example.com',
      String email = 'me@example.com',
      String password = 'correct horse',
      bool creating = false,
    }) => signInProblem(
      l10n,
      server: server,
      email: email,
      password: password,
      creating: creating,
    );

    test('lets a complete form through', () {
      expect(problem(), isNull);
      expect(problem(creating: true), isNull);
    });

    test('names what is missing or malformed, before any request', () {
      expect(problem(server: ''), l10n.accountServerInvalid);
      expect(problem(server: 'harvest.example.com'), l10n.accountServerInvalid);
      expect(problem(email: ''), l10n.accountEmailMissing);
      expect(problem(email: 'me@'), l10n.accountEmailInvalid);
      expect(problem(password: ''), l10n.accountPasswordMissing);
    });

    test('holds a new password to the policy, but not a sign-in', () {
      expect(problem(password: 'short'), isNull);
      expect(
        problem(password: 'short', creating: true),
        l10n.accountPasswordShort,
      );
    });
  });

  testWidgets('an empty sign-in says what is missing, and a switch of '
      'form forgets it', (tester) async {
    final account = _Account();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [accountControllerProvider.overrideWith(() => account)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: AccountCard())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The server field shows an example without being focused.
    expect(find.textContaining('harvest.example.com'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, l10n.accountSignIn));
    await tester.pump();
    expect(find.text(l10n.accountEmailMissing), findsOneWidget);
    expect(find.textContaining('Something went wrong'), findsNothing);
    expect(account.calls, 0);

    await tester.tap(find.text(l10n.accountNeedOne));
    await tester.pump();
    expect(find.text(l10n.accountEmailMissing), findsNothing);
  });
}
