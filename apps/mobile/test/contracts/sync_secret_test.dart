import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/account/domain/sync_secret.dart';
import 'package:harvest/features/account/presentation/sync_pin_sheet.dart';
import 'package:harvest/l10n/app_localizations_en.dart';

/// The sync secret's rule ([[Accounts]] AC7) is the web's, case for case
/// (`packages/contracts/fixtures/sync-secret.json`).
void main() {
  final spec = jsonDecode(
    File(
      '../../packages/contracts/fixtures/sync-secret.json',
    ).readAsStringSync(),
  ) as Map<String, Object?>;
  final cases = [
    for (final item in spec['cases']! as List<Object?>)
      item! as Map<String, Object?>,
  ];

  test('answers every pinned case as the contract does', () {
    for (final c in cases) {
      final input = c['input']! as String;
      expect(
        syncSecretProblem(input)?.name,
        c['expected'],
        reason: jsonEncode(input),
      );
    }
  });

  test('the fixture pins every answer the rule can give', () {
    expect(cases.map((c) => c['expected']).toSet(), {
      for (final problem in SyncSecretProblem.values) problem.name,
      null,
    });
  });

  test('a PIN is 4 to 6 ASCII digits; a passphrase 8 characters', () {
    expect(syncSecretProblem('2468'), isNull);
    expect(syncSecretProblem('482913'), isNull);
    expect(syncSecretProblem('1234'), SyncSecretProblem.pinTooSimple);
    expect(syncSecretProblem('121212'), SyncSecretProblem.pinTooSimple);
    expect(syncSecretProblem('000000'), SyncSecretProblem.pinTooSimple);
    expect(syncSecretProblem('123'), SyncSecretProblem.pinTooShort);
    expect(syncSecretProblem('1234567'), SyncSecretProblem.pinTooLong);
    expect(syncSecretProblem('abcdefg'), SyncSecretProblem.passphraseTooShort);
    expect(syncSecretProblem('abcdefgh'), isNull);
    expect(syncSecretProblem(''), SyncSecretProblem.empty);
    // Other scripts' digits are characters, not PIN digits.
    expect(isSyncPin('١٢٣٤'), isFalse);
    expect(isSyncPin('0123'), isTrue);
  });

  test('says each problem in words, and nothing for an empty field', () {
    final l10n = AppLocalizationsEn();
    expect(syncSecretMessage(l10n, SyncSecretProblem.empty), isNull);
    expect(syncSecretMessage(l10n, null), isNull);
    expect(
      syncSecretMessage(l10n, SyncSecretProblem.pinTooShort),
      l10n.syncPinLength,
    );
    expect(
      syncSecretMessage(l10n, SyncSecretProblem.pinTooLong),
      l10n.syncPinLength,
    );
    expect(
      syncSecretMessage(l10n, SyncSecretProblem.passphraseTooShort),
      l10n.syncPassphraseShort,
    );
    expect(
      syncSecretMessage(l10n, SyncSecretProblem.pinTooSimple),
      l10n.syncPinTooSimple,
    );
  });

  test("a PIN field takes an Arabic keyboard's digits as the web does", () {
    expect(PinDigitsFormatter.digitsOf('١٢٣٤'), '1234');
    expect(PinDigitsFormatter.digitsOf('۱۲۳۴'), '1234');
    expect(PinDigitsFormatter.digitsOf('1٢3۴'), '1234');
    expect(PinDigitsFormatter.digitsOf('12ab -3'), '123');
    expect(PinDigitsFormatter.digitsOf('١٢٣٤٥٦٧٨'), '123456');
    // What it gives is a PIN by the shared rule.
    expect(syncSecretProblem(PinDigitsFormatter.digitsOf('٢٤٦٨')), isNull);
  });
}
