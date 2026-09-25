import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/domain/vault.dart';
import 'package:harvest/features/places/domain/place.dart';
import 'package:harvest/features/places/presentation/places_screen.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// A pin's line on the Places sheet writes money as the Granary does:
/// it read "4.00 DZD · food", and a wallet movement was a bare "Money".
void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  String plain(String? text) =>
      text!.replaceAll(RegExp('[\u2066-\u2069\u200e\u200f]'), '');

  test('an expense reads its amount and its category by name', () {
    final text = geotagDetailText(
      en,
      const GeotagExpense(
        amountMinor: 400,
        currency: Currency.dzd,
        category: 'food',
      ),
    );
    expect(plain(text), 'DA4 · ${en.catFood}');
  });

  test('an expense with a note reads its note', () {
    final text = geotagDetailText(
      en,
      const GeotagExpense(
        amountMinor: 400,
        currency: Currency.dzd,
        category: 'food',
        note: 'Bread',
      ),
    );
    expect(plain(text), 'DA4 · Bread');
  });

  test('a wallet movement says what it was', () {
    final text = geotagDetailText(
      en,
      GeotagMove(
        MoneyTxn(
          uuid: 't',
          account: MoneyAccount.wallet,
          deltaMinor: 20000,
          currency: Currency.dzd,
          day: HarvestDay.parse('2026-09-25'),
          loggedAt: DateTime(2026, 9, 25),
        ),
      ),
    );
    expect(plain(text), '+DA200 · ${en.txnAdded}');
  });

  test('anything else keeps its words', () {
    expect(geotagDetailText(en, const GeotagText('Office')), 'Office');
    expect(geotagDetailText(en, null), isNull);
  });
}
