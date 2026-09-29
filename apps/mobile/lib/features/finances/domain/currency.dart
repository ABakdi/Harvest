// Rates keeps its raw values private and sanitises on read, so the
// named constructor parameters cannot be initializing formals.
// ignore_for_file: prefer_initializing_formals

import 'dart:math' as math;

import 'package:harvest/features/finances/domain/currency_data.g.dart';
import 'package:meta/meta.dart';

/// A currency, any of the 160 in circulation ([[Finances]], Phase 7 M7.8),
/// where 3.1 knew three. The table is made from
/// `packages/core/fixtures/currencies.json` by `tool/currencies.dart`, so
/// the phone and the web know the same ones.
///
/// Amounts stay in hundredths of the currency, whatever the currency: the
/// unit every row has always been written in, so nothing stored changes.
/// [minorUnits] only says how many decimals are shown ([displayDecimals]).
@immutable
class Currency {
  const Currency(this.code, this.minorUnits, this.symbol, this.en, this.ar);

  /// ISO 4217.
  final String code;

  /// ISO 4217's minor units: 0 for the yen, 2 for most, 3 for the Gulf
  /// dinars.
  final int minorUnits;

  /// What is written beside an amount there; the code where there is no
  /// sign of its own.
  final String symbol;
  final String en;
  final String ar;

  static const dzd = Currency('DZD', 2, 'DA', 'Algerian Dinar', 'دينار جزائري');
  static const usd = Currency('USD', 2, r'$', 'US Dollar', 'دولار أمريكي');
  static const eur = Currency('EUR', 2, '€', 'Euro', 'يورو');

  /// Every currency, in code order.
  static List<Currency> get values => currencyTable;

  static final Map<String, Currency> _byCode = {
    for (final currency in currencyTable) currency.code: currency,
  };

  /// [code]'s currency, or the dinar for a code Harvest does not know, as
  /// it always was.
  static Currency fromCode(String? code) => _byCode[code] ?? dzd;

  /// [code]'s currency, or null for a code Harvest does not know.
  static Currency? tryCode(String? code) => _byCode[code];

  /// How many decimals an amount is shown with: the minor units, and
  /// never more than the two kept.
  int get displayDecimals => math.min(minorUnits, 2);

  /// The name in [language] (`en` or `ar`).
  String nameIn(String language) => language == 'ar' ? ar : en;

  @override
  bool operator ==(Object other) => other is Currency && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => code;
}

/// The currency in everyday use in [country] (ISO 3166-1 alpha-2), or null.
Currency? currencyOfCountry(String? country) => country == null
    ? null
    : Currency.tryCode(countryCurrencies[country.toUpperCase()]);

/// The country an IANA time zone is in, or null for one that is no
/// country's (UTC, Etc/…).
String? countryOfZone(String? zone) =>
    zone == null ? null : zoneCountries[zone];

final _alpha2 = RegExp(r'^[A-Za-z]{2}$');
final _numeric = RegExp(r'^\d{3}$');

/// The region of a locale (`ar-DZ`, `fr_FR`, `en-Latn-GB`), or null.
String? regionOfLocale(String? locale) {
  if (locale == null) return null;
  final parts = locale.replaceAll('_', '-').split('-').skip(1);
  for (final part in parts) {
    if (_alpha2.hasMatch(part)) return part.toUpperCase();
    if (_numeric.hasMatch(part)) return null;
  }
  return null;
}

/// The currency a new install starts with, where the phone says it is
/// (`defaultCurrencyFor` in `packages/core`). In order, the first that
/// names a country with a currency: [countries] (the SIM's and the
/// network's), the time zone, then each of [locales]' regions. With none
/// of them, the dinar, as before. Always changeable in Settings, and never
/// read again once chosen.
Currency defaultCurrencyFor({
  Iterable<String?> countries = const [],
  String? timeZone,
  Iterable<String?> locales = const [],
}) {
  final candidates = [
    ...countries,
    countryOfZone(timeZone),
    ...locales.map(regionOfLocale),
  ];
  for (final country in candidates) {
    final currency = currencyOfCountry(country);
    if (currency != null) return currency;
  }
  return Currency.dzd;
}

/// Exchange rates, as `Rates` in `packages/core/src/money.ts`:
/// - [perUsd], what one US dollar buys of every currency, fetched by the
///   phone and kept with its day;
/// - the dinar's parallel market, typed by hand ([dzdPerUsd],
///   [dzdPerEur]), which wins over any fetched rate for a leg through the
///   dinar — the official one is not what a euro buys in Algiers;
/// - [usdPerEur], what 3.1 fetched, still read when [perUsd] is not there.
///
/// All conversion is best-effort: a missing rate yields null and the UI
/// simply omits the conversion.
@immutable
class Rates {
  const Rates({
    required this.defaultCurrency,
    Map<String, double>? perUsd,
    double? dzdPerUsd,
    double? dzdPerEur,
    double? usdPerEur,
  }) : _perUsd = perUsd,
       _dzdPerUsd = dzdPerUsd,
       _dzdPerEur = dzdPerEur,
       _usdPerEur = usdPerEur;

  final Currency defaultCurrency;
  final Map<String, double>? _perUsd;
  final double? _dzdPerUsd;
  final double? _dzdPerEur;
  final double? _usdPerEur;

  /// A rate that is not finite and positive is no rate at all.
  static double? _sane(double? value) =>
      value != null && value.isFinite && value > 0 ? value : null;

  double? get dzdPerUsd => _sane(_dzdPerUsd);
  double? get dzdPerEur => _sane(_dzdPerEur);
  double? get usdPerEur => _sane(_usdPerEur);

  /// The same rates, converting into [currency] instead.
  Rates withDefault(Currency currency) => Rates(
    defaultCurrency: currency,
    perUsd: _perUsd,
    dzdPerUsd: _dzdPerUsd,
    dzdPerEur: _dzdPerEur,
    usdPerEur: _usdPerEur,
  );

  /// What one US dollar buys of [code], as fetched, or null.
  double? perUsd(String code) => _sane(_perUsd?[code]);

  /// [toDefault], but falling back to the face value when the rate is
  /// unknown — the app never blocks on a missing rate, it just stops
  /// pretending the number was converted.
  int toDefaultOrFace(int minor, Currency from) =>
      toDefault(minor, from) ?? minor;

  /// Sums per-currency amounts into the default currency.
  int sumInDefault(Map<Currency, int> amounts) {
    var total = 0;
    amounts.forEach((currency, minor) {
      total += toDefaultOrFace(minor, currency);
    });
    return total;
  }

  /// Converts [minor] units of [from] into the default currency;
  /// null when the needed rate is unknown.
  int? toDefault(int minor, Currency from) {
    if (from == defaultCurrency) return minor;
    final factor = _factor(from.code, defaultCurrency.code);
    if (factor == null || !factor.isFinite) return null;
    return (minor * factor).round();
  }

  static const _firstThree = {'DZD', 'USD', 'EUR'};

  double? _factor(String from, String to) {
    if (from == to) return 1;
    if (_firstThree.contains(from) && _firstThree.contains(to)) {
      final old = _firstThreeFactor(from, to);
      if (old != null) return old;
    }
    final fromUnits = _unitsPerUsd(from);
    final toUnits = _unitsPerUsd(to);
    if (fromUnits == null || toUnits == null) return null;
    return toUnits / fromUnits;
  }

  /// How 3.1 converted between the dinar, the dollar and the euro,
  /// unchanged.
  double? _firstThreeFactor(String from, String to) {
    final eur = perUsd('EUR');
    final usdPerEur = this.usdPerEur ?? (eur == null ? null : 1 / eur);
    if (from == 'EUR' && to == 'USD' && usdPerEur != null) return usdPerEur;
    if (from == 'USD' && to == 'EUR' && usdPerEur != null) {
      return 1 / usdPerEur;
    }
    double? viaDzd(String code) => switch (code) {
      'DZD' => 1,
      'USD' => dzdPerUsd,
      _ => dzdPerEur,
    };
    final fromDzd = viaDzd(from);
    final toDzd = viaDzd(to);
    if (fromDzd == null || toDzd == null) return null;
    return fromDzd / toDzd;
  }

  /// What one US dollar buys of [code]: fetched, except for the dinar
  /// when its parallel rate was typed, straight or through the euro.
  double? _unitsPerUsd(String code) {
    if (code == 'USD') return 1;
    if (code == 'DZD') {
      final byHand = dzdPerUsd;
      if (byHand != null) return byHand;
      final perEur = dzdPerEur;
      final eur = _unitsPerUsd('EUR');
      if (perEur != null && eur != null) return perEur * eur;
    }
    final fetched = perUsd(code);
    if (fetched != null) return fetched;
    if (code == 'EUR') {
      final usdPerEur = this.usdPerEur;
      return usdPerEur == null ? null : 1 / usdPerEur;
    }
    return null;
  }
}
