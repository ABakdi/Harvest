import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/features/account/data/api_client.dart'
    show ApiException, Me;
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/account/presentation/account_circle.dart';
import 'package:harvest/features/account/presentation/sync_pin_sheet.dart';
import 'package:harvest/features/sync/domain/sync_service.dart';
import 'package:harvest/features/sync/presentation/sync_controller.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:harvest/l10n/app_localizations_en.dart';

import '../../support/fake_remote.dart';

final _me = Me(
  id: 'u1',
  email: 'maya@example.com',
  syncSalt: 'salt',
  verifiedAt: DateTime.utc(2026, 9, 2),
);

class _Account extends AccountController {
  _Account([this.me]);

  Me? me;
  int logouts = 0;

  AccountState get _state =>
      AccountState(serverUrl: 'https://harvest.example.com', me: me);

  @override
  Future<AccountState> build() async => _state;

  void signIn(Me who) {
    me = who;
    state = AsyncData(_state);
  }

  /// The account read again, unchanged: what a refresh looks like.
  void touch() => state = AsyncData(_state);

  @override
  Future<void> logout() async {
    logouts++;
    me = null;
    state = AsyncData(_state);
  }

  @override
  Future<List<Map<String, Object?>>> sessions() async => [
    {
      'id': 's1',
      'client': 'mobile',
      'current': true,
      'lastSeenAt': '2026-09-26T08:00:00Z',
    },
    {
      'id': 's2',
      'client': 'web',
      'deviceName': 'Laptop',
      'lastSeenAt': '2026-09-25T08:00:00Z',
    },
  ];
}

class _Pin extends SyncPassphrase {
  _Pin({this.initial = false});

  final bool initial;
  final secrets = <String>[];

  /// Whether the next PIN opens the account's key check.
  bool opens = true;

  /// When set, the next check waits for it.
  Completer<void>? checking;

  /// When set, the next check throws it, as the platform's crypto can.
  Error? failure;

  @override
  Future<bool> build() async => initial;

  @override
  Future<void> set(String secret) async {
    secrets.add(secret);
    await checking?.future;
    if (failure case final failure?) throw failure;
    if (!opens) throw const SyncPinRefused();
    state = const AsyncData(true);
  }

  @override
  Future<void> forget() async => state = const AsyncData(false);

  final startedOver = <String>[];

  @override
  Future<void> startOver(String password) async {
    startedOver.add(password);
    state = const AsyncData(false);
  }
}

class _Sync extends SyncController {
  _Sync([this.initial = const SyncStatus()]);

  final SyncStatus initial;
  int syncs = 0;
  _Pin? pin;

  @override
  SyncStatus build() => initial;

  @override
  Future<void> syncNow() async => syncs++;
}

final _report = SyncReport(
  pulled: 0,
  pushed: 0,
  invalid: 0,
  heldBack: 0,
  at: DateTime(2026, 9, 26, 9),
);

void main() {
  final l10n = AppLocalizationsEn();

  Widget app({
    required _Account account,
    required _Pin pin,
    required _Sync sync,
    bool sealed = false,
    bool prompt = false,
    Locale? locale,
    ApiException? unreachable,
    SyncService? service,
  }) {
    sync.pin = pin;
    Widget home = Scaffold(
      appBar: AppBar(
        title: const Text('Field'),
        leading: const AccountCircle(),
      ),
      body: const SizedBox.expand(),
    );
    if (prompt) home = SyncPinPrompt(child: home);
    return ProviderScope(
      overrides: [
        accountControllerProvider.overrideWith(() => account),
        syncPassphraseProvider.overrideWith(() => pin),
        syncControllerProvider.overrideWith(() => sync),
        syncJoinPendingProvider.overrideWith(
          (ref) async => await service?.joinPending() ?? false,
        ),
        if (service != null) syncServiceProvider.overrideWithValue(service),
        // Whether the account already has a PIN is the server's answer.
        syncKeyStateProvider.overrideWith((ref) async {
          if (unreachable != null) throw unreachable;
          return SyncKeyState(
            salt: 'salt',
            epoch: 1,
            keyShare: sealed ? null : Uint8List(32),
          );
        }),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );
  }

  group('the mark', () {
    test('follows how sync stands', () {
      expect(syncMarkOf(me: null, sync: const SyncStatus()), SyncMark.none);
      expect(
        syncMarkOf(
          me: _me,
          sync: SyncStatus(last: _report),
        ),
        SyncMark.sent,
      );
      expect(
        syncMarkOf(
          me: _me,
          sync: SyncStatus(last: _report, pending: 3),
        ),
        SyncMark.pending,
      );
      expect(
        syncMarkOf(me: _me, sync: const SyncStatus()),
        SyncMark.pending,
        reason: 'never synced yet',
      );
      expect(
        syncMarkOf(
          me: const Me(id: 'u', email: 'a@b.co', syncSalt: 's'),
          sync: SyncStatus(last: _report),
        ),
        SyncMark.pending,
        reason: 'not verified yet',
      );
      expect(
        syncMarkOf(
          me: _me,
          sync: SyncStatus(last: _report, error: 'offline'),
        ),
        SyncMark.offline,
      );
      expect(
        syncMarkOf(
          me: _me,
          sync: SyncStatus(last: _report, error: 'internal'),
        ),
        SyncMark.error,
      );
    });
  });

  group('the circle', () {
    testWidgets('signed out: a person, no mark, no dot', (tester) async {
      await tester.pumpWidget(
        app(account: _Account(), pin: _Pin(), sync: _Sync()),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(find.byKey(const ValueKey('account-pin-dot')), findsNothing);
      for (final mark in SyncMark.values) {
        expect(find.byKey(ValueKey('account-mark-${mark.name}')), findsNothing);
      }
      // Labelled, and a whole 48 dp to aim at.
      expect(find.byTooltip(l10n.accountCircleLabel), findsOneWidget);
      final size = tester.getSize(
        find.byKey(const ValueKey('account-circle')),
      );
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    Future<void> expectMark(
      WidgetTester tester,
      SyncStatus status,
      SyncMark mark,
    ) async {
      // A fresh start each time: a scope keeps its first overrides.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        app(
          account: _Account(_me),
          pin: _Pin(initial: true),
          sync: _Sync(status),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('M'), findsOneWidget);
      expect(
        find.byKey(ValueKey('account-mark-${mark.name}')),
        findsOneWidget,
        reason: mark.name,
      );
      expect(find.byKey(const ValueKey('account-pin-dot')), findsNothing);
    }

    testWidgets('signed in: my initial, and the mark of the moment', (
      tester,
    ) async {
      await expectMark(tester, SyncStatus(last: _report), SyncMark.sent);
      await expectMark(
        tester,
        SyncStatus(last: _report, pending: 2),
        SyncMark.pending,
      );
      await expectMark(
        tester,
        const SyncStatus(error: 'offline'),
        SyncMark.offline,
      );
      await expectMark(
        tester,
        SyncStatus(last: _report, error: 'internal'),
        SyncMark.error,
      );
    });

    testWidgets('each state has its own shape, not only its colour (U6-39)', (
      tester,
    ) async {
      final glyphs = {
        for (final mark in SyncMark.values) AccountCircle.markGlyph(mark),
      };
      expect(glyphs, hasLength(SyncMark.values.length));
      await expectMark(tester, SyncStatus(last: _report), SyncMark.sent);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('account-mark-sent')),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a dot while the sync PIN is still to set', (tester) async {
      await tester.pumpWidget(
        app(
          account: _Account(_me),
          pin: _Pin(),
          sync: _Sync(SyncStatus(last: _report)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('account-pin-dot')), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(const ValueKey('account-circle'))),
        matchesSemantics(
          tooltip: l10n.accountCircleLabel,
          isButton: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
    });

    testWidgets('sits at the start of the bar in Arabic too', (tester) async {
      await tester.pumpWidget(
        app(
          account: _Account(_me),
          pin: _Pin(initial: true),
          sync: _Sync(SyncStatus(last: _report)),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();
      final circle = tester.getCenter(
        find.byKey(const ValueKey('account-circle')),
      );
      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(circle.dx, greaterThan(width / 2));
    });
  });

  group('the sheet', () {
    testWidgets('signed in: sync now, the PIN, devices, sign out', (
      tester,
    ) async {
      final account = _Account(_me);
      final sync = _Sync(SyncStatus(last: _report, pending: 2));
      await tester.pumpWidget(
        app(account: account, pin: _Pin(), sync: sync),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('account-circle')));
      await tester.pumpAndSettle();

      expect(find.text('maya@example.com'), findsOneWidget);
      expect(find.text(l10n.accountVerified), findsOneWidget);
      expect(find.text(l10n.accountOnline), findsOneWidget);
      expect(find.text(l10n.accountChangesWaiting), findsOneWidget);
      expect(find.text(l10n.syncPinWaiting), findsOneWidget);

      await tester.tap(find.text(l10n.accountSyncNow));
      await tester.pump();
      expect(sync.syncs, 1);

      await tester.tap(find.text(l10n.accountDevices));
      await tester.pumpAndSettle();
      expect(find.text(l10n.accountThisDevice), findsOneWidget);
      expect(find.text('Laptop'), findsOneWidget);
      // On this phone's clock, in words (Q5-27): never the raw wire.
      expect(find.textContaining('T08:00'), findsNothing);
      expect(
        find.textContaining('${l10n.accountClientWeb} · '),
        findsOneWidget,
      );
      expect(
        find.textContaining('${l10n.accountClientPhone} · '),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.syncPinTitle));
      await tester.pumpAndSettle();
      expect(find.text(l10n.syncPinChooseBody), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.accountSignOut));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, l10n.accountSignOut),
        ),
      );
      await tester.pumpAndSettle();
      expect(account.logouts, 1);
    });

    testWidgets('offline says so', (tester) async {
      await tester.pumpWidget(
        app(
          account: _Account(_me),
          pin: _Pin(initial: true),
          sync: _Sync(SyncStatus(last: _report, error: 'offline')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('account-circle')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.accountOffline), findsOneWidget);
      expect(find.text(l10n.accountOnline), findsNothing);
      expect(find.text(l10n.syncPinIsSet), findsOneWidget);
    });

    testWidgets('signed out: sign in, or create an account', (tester) async {
      await tester.pumpWidget(
        app(account: _Account(), pin: _Pin(), sync: _Sync()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('account-circle')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, l10n.accountCreate));
      await tester.pumpAndSettle();
      expect(find.byType(AccountPage), findsOneWidget);
      expect(find.text(l10n.accountHaveOne), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('account-circle')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, l10n.accountSignIn));
      await tester.pumpAndSettle();
      expect(find.byType(AccountPage), findsOneWidget);
      expect(find.text(l10n.accountNeedOne), findsOneWidget);
    });
  });

  group('the prompt', () {
    testWidgets('asks once after signing in; Later puts it off until the '
        'next start', (tester) async {
      final account = _Account();
      await tester.pumpWidget(
        app(account: account, pin: _Pin(), sync: _Sync(), prompt: true),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SyncPinSheet), findsNothing, reason: 'signed out');

      account.signIn(_me);
      await tester.pumpAndSettle();
      expect(find.byType(SyncPinSheet), findsOneWidget);

      await tester.tap(find.text(l10n.syncPinLater));
      await tester.pumpAndSettle();
      expect(find.byType(SyncPinSheet), findsNothing);

      // The account read again in the same run: no second ask.
      account.touch();
      await tester.pumpAndSettle();
      expect(find.byType(SyncPinSheet), findsNothing);
      expect(find.byKey(const ValueKey('account-pin-dot')), findsOneWidget);

      // The next start asks again.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        app(account: _Account(_me), pin: _Pin(), sync: _Sync(), prompt: true),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SyncPinSheet), findsOneWidget);
    });

    testWidgets('a session ended underneath: says so, and goes once '
        'signed out', (tester) async {
      final account = _Account(_me);
      await tester.pumpWidget(
        app(
          account: account,
          pin: _Pin(),
          sync: _Sync(),
          prompt: true,
          unreachable: const ApiException('unauthorized', 401, 'Session ended'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SyncPinSheet), findsOneWidget);
      expect(find.text(l10n.syncPinSignedOut), findsOneWidget);
      expect(find.text(l10n.accountErrorWrong), findsNothing);

      await account.logout();
      await tester.pumpAndSettle();
      expect(find.byType(SyncPinSheet), findsNothing);
    });

    testWidgets('signed in on a phone with data of its own: asks what '
        'becomes of it before anything syncs (U6-05)', (tester) async {
      final db = HarvestDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final service = SyncService(db, FakeRemote());
      await tester.runAsync(() => service.holdForJoin(hold: true));
      final sync = _Sync();
      await tester.pumpWidget(
        app(
          account: _Account(_me),
          pin: _Pin(initial: true),
          sync: sync,
          prompt: true,
          service: service,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(JoinSheet), findsOneWidget);
      expect(sync.syncs, 0);

      await tester.tap(find.text(l10n.joinBring));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.byType(JoinSheet), findsNothing);
      expect(await tester.runAsync(service.joinPending), isFalse);
      expect(sync.syncs, 1);
    });

    testWidgets('never asks with a PIN already set', (tester) async {
      await tester.pumpWidget(
        app(
          account: _Account(_me),
          pin: _Pin(initial: true),
          sync: _Sync(),
          prompt: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SyncPinSheet), findsNothing);
    });
  });

  group('the PIN sheet', () {
    Future<void> open(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('account-circle')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.syncPinTitle));
      await tester.pumpAndSettle();
    }

    testWidgets('the first device chooses it twice, and sync runs at once', (
      tester,
    ) async {
      final pin = _Pin();
      final sync = _Sync(SyncStatus(last: _report));
      await tester.pumpWidget(
        app(account: _Account(_me), pin: pin, sync: sync),
      );
      await tester.pumpAndSettle();
      await open(tester);
      // A passphrase comes first; a PIN is one tap away.
      await tester.tap(find.text(l10n.syncPinUsePin));
      await tester.pumpAndSettle();

      final fields = find.descendant(
        of: find.byType(SyncPinSheet),
        matching: find.byType(TextField),
      );
      expect(fields, findsNWidgets(2));
      final first = tester.widget<TextField>(fields.first);
      expect(first.keyboardType, TextInputType.number);
      expect(first.obscureText, isTrue);

      // Letters never reach a PIN field, and too few digits are refused.
      await tester.enterText(fields.first, '12ab');
      await tester.enterText(fields.last, '12');
      await tester.pump();
      await tester.ensureVisible(find.text(l10n.syncPinChoose));
      await tester.tap(find.text(l10n.syncPinChoose));
      await tester.pumpAndSettle();
      expect(find.text(l10n.syncPinLength), findsOneWidget);
      expect(pin.secrets, isEmpty);

      await tester.enterText(fields.first, '2468');
      await tester.enterText(fields.last, '2469');
      await tester.pumpAndSettle();
      expect(find.text(l10n.syncPinMismatch), findsOneWidget);

      await tester.enterText(fields.last, '2468');
      await tester.pump();
      await tester.ensureVisible(find.text(l10n.syncPinChoose));
      await tester.tap(find.text(l10n.syncPinChoose));
      await tester.pumpAndSettle();
      expect(pin.secrets, ['2468']);
      expect(sync.syncs, 1);
      expect(find.byType(SyncPinSheet), findsNothing);
    });

    testWidgets('an unexpected failure is said, and the PIN can be typed '
        'again', (tester) async {
      final pin = _Pin()..failure = StateError('Empty key');
      await tester.pumpWidget(
        app(account: _Account(_me), pin: pin, sync: _Sync()),
      );
      await tester.pumpAndSettle();
      await open(tester);
      final fields = find.descendant(
        of: find.byType(SyncPinSheet),
        matching: find.byType(TextField),
      );
      // Digits in the passphrase field are a PIN, all the same.
      await tester.enterText(fields.first, '739051');
      await tester.enterText(fields.last, '739051');
      await tester.pump();
      await tester.ensureVisible(find.text(l10n.syncPassphraseChoose));
      await tester.tap(find.text(l10n.syncPassphraseChoose));
      await tester.pumpAndSettle();
      expect(find.byType(SyncPinSheet), findsOneWidget);
      expect(find.text(l10n.accountErrorOther('StateError')), findsOneWidget);
      expect(find.text(l10n.syncPassphraseChoose), findsOneWidget);
    });

    testWidgets('a passphrase first: text, 8 characters, how long it would '
        'hold, and what a PIN costs beside the way to one', (tester) async {
      final pin = _Pin();
      await tester.pumpWidget(
        app(account: _Account(_me), pin: pin, sync: _Sync()),
      );
      await tester.pumpAndSettle();
      await open(tester);
      expect(find.text(l10n.syncPassphraseTitle), findsOneWidget);
      expect(find.text(l10n.syncPinUsePin), findsOneWidget);
      expect(find.text(l10n.syncPinCost), findsOneWidget);

      final fields = find.descendant(
        of: find.byType(SyncPinSheet),
        matching: find.byType(TextField),
      );
      expect(
        tester.widget<TextField>(fields.first).keyboardType,
        TextInputType.visiblePassword,
      );
      // Shown on a tap, hidden on another.
      expect(tester.widget<TextField>(fields.first).obscureText, isTrue);
      await tester.tap(find.byTooltip(l10n.syncSecretShow).first);
      await tester.pump();
      expect(tester.widget<TextField>(fields.first).obscureText, isFalse);

      await tester.enterText(fields.first, 'olive river lantern');
      await tester.pump();
      expect(find.byKey(const ValueKey('secret-strength')), findsOneWidget);
      expect(
        find.textContaining(l10n.syncSecretStrong),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('secret-strength')),
          matching: find.textContaining(l10n.syncSecretThousands),
        ),
        findsOneWidget,
      );
      await tester.enterText(fields.first, 'password');
      await tester.pump();
      expect(find.textContaining(l10n.syncSecretWeak), findsOneWidget);
      expect(find.textContaining(l10n.syncSecretUnderSecond), findsOneWidget);
      await tester.enterText(fields.first, 'short');
      await tester.enterText(fields.last, 'short');
      await tester.pump();
      await tester.ensureVisible(find.text(l10n.syncPassphraseChoose));
      await tester.tap(find.text(l10n.syncPassphraseChoose));
      await tester.pumpAndSettle();
      expect(find.text(l10n.syncPassphraseShort), findsOneWidget);

      await tester.enterText(fields.first, 'olive grove');
      await tester.enterText(fields.last, 'olive grove');
      await tester.pump();
      await tester.ensureVisible(find.text(l10n.syncPassphraseChoose));
      await tester.tap(find.text(l10n.syncPassphraseChoose));
      await tester.pumpAndSettle();
      expect(pin.secrets, ['olive grove']);
    });

    testWidgets('a later device enters it once, and a wrong one is refused '
        'on the spot', (tester) async {
      final pin = _Pin()..opens = false;
      final sync = _Sync(SyncStatus(last: _report));
      await tester.pumpWidget(
        app(account: _Account(_me), pin: pin, sync: sync, sealed: true),
      );
      await tester.pumpAndSettle();
      await open(tester);

      final fields = find.descendant(
        of: find.byType(SyncPinSheet),
        matching: find.byType(TextField),
      );
      expect(fields, findsOneWidget);
      expect(find.text(l10n.syncPinEnterBody), findsOneWidget);

      await tester.enterText(fields.first, '1357');
      await tester.pump();
      await tester.ensureVisible(find.text(l10n.syncPinEnter));
      await tester.tap(find.text(l10n.syncPinEnter));
      await tester.pumpAndSettle();
      // Refused by the key check: nothing kept, nothing synced.
      expect(sync.syncs, 0);
      expect(find.text(l10n.syncPinWrong), findsOneWidget);
      expect(find.byType(SyncPinSheet), findsOneWidget);

      // One field takes either, and an Arabic keyboard's digits are the
      // PIN they spell.
      expect(
        tester.widget<TextField>(fields.first).keyboardType,
        TextInputType.visiblePassword,
      );
      expect(find.text(l10n.syncPinUsePin), findsNothing);
      await tester.enterText(fields.first, 'olive river lantern');
      await tester.pump();
      await tester.ensureVisible(find.text(l10n.syncPinEnter));
      await tester.tap(find.text(l10n.syncPinEnter));
      await tester.pumpAndSettle();

      pin.opens = true;
      // Entering, the PIN is the one already chosen: an easy one is the
      // check's to judge, not the chooser's rule.
      await tester.enterText(fields.first, '١٢٣٤');
      await tester.pump();
      await tester.ensureVisible(find.text(l10n.syncPinEnter));
      await tester.tap(find.text(l10n.syncPinEnter));
      await tester.pumpAndSettle();
      expect(pin.secrets, ['1357', 'olive river lantern', '1234']);
      expect(sync.syncs, 1);
      expect(find.byType(SyncPinSheet), findsNothing);
    });

    testWidgets('choosing, a PIN too easy to guess is refused', (tester) async {
      final pin = _Pin();
      await tester.pumpWidget(
        app(account: _Account(_me), pin: pin, sync: _Sync()),
      );
      await tester.pumpAndSettle();
      await open(tester);
      await tester.tap(find.text(l10n.syncPinUsePin));
      await tester.pumpAndSettle();
      expect(find.text(l10n.syncPinRule), findsOneWidget);

      final fields = find.descendant(
        of: find.byType(SyncPinSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.first, '123456');
      await tester.enterText(fields.last, '123456');
      await tester.pump();
      await tester.ensureVisible(find.text(l10n.syncPinChoose));
      await tester.tap(find.text(l10n.syncPinChoose));
      await tester.pumpAndSettle();
      expect(find.text(l10n.syncPinTooSimple), findsOneWidget);
      expect(pin.secrets, isEmpty);
    });

    testWidgets('with the server out of reach it says so, and nothing is '
        'typed into a guess', (tester) async {
      await tester.pumpWidget(
        app(
          account: _Account(_me),
          pin: _Pin(),
          sync: _Sync(),
          unreachable: const ApiException('offline', 0),
        ),
      );
      await tester.pumpAndSettle();
      await open(tester);
      expect(find.text(l10n.syncPinUnreachable), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SyncPinSheet),
          matching: find.byType(TextField),
        ),
        findsNothing,
      );
    });

    testWidgets('a forgotten PIN can be started over, with the password, '
        'after saying plainly what goes', (tester) async {
      final pin = _Pin();
      await tester.pumpWidget(
        app(account: _Account(_me), pin: pin, sync: _Sync(), sealed: true),
      );
      await tester.pumpAndSettle();
      await open(tester);

      await tester.ensureVisible(find.text(l10n.syncPinForgot));
      await tester.tap(find.text(l10n.syncPinForgot));
      await tester.pumpAndSettle();
      expect(find.text(l10n.syncPinStartOverBody), findsOneWidget);
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.syncPinStartOverConfirm),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'my password',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.syncPinStartOverConfirm),
      );
      await tester.pumpAndSettle();
      expect(pin.startedOver, ['my password']);
    });

    testWidgets('a sheet checking the PIN stays until it is done, and never '
        'closes the page under it (U6-02)', (tester) async {
      final pin = _Pin()..checking = Completer<void>();
      await tester.pumpWidget(
        app(account: _Account(_me), pin: pin, sync: _Sync(), sealed: true),
      );
      await tester.pumpAndSettle();
      await open(tester);
      final fields = find.descendant(
        of: find.byType(SyncPinSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.first, '2468');
      await tester.pump();
      await tester.ensureVisible(find.text(l10n.syncPinEnter));
      await tester.tap(find.text(l10n.syncPinEnter));
      await tester.pump();

      // Back while it checks: the sheet stays.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(SyncPinSheet), findsOneWidget);

      pin.checking!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SyncPinSheet), findsNothing);
      // The account sheet under it is still there.
      expect(find.text(l10n.syncPinTitle), findsWidgets);
    });
  });
}
