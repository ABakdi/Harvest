// Rates keeps its raw values private and sanitises on read, so the
// named constructor parameters cannot be initializing formals.
// ignore_for_file: prefer_initializing_formals

import 'package:meta/meta.dart';

/// The currencies Harvest speaks for now (checkpoint P4).
enum Currency {
  dzd('DZD', 'DA'),
  usd('USD', r'$'),
  eur('EUR', '€');

  const Currency(this.code, this.symbol);

  final String code;
  final String symbol;

  static Currency fromCode(String? code) => Currency.values.firstWhere(
    (currency) => currency.code == code,
    orElse: () => Currency.dzd,
  );
}

/// Exchange rates (checkpoint P5). DZD legs are entered by hand;
/// EUR→USD comes from the internet. All conversion is best-effort:
/// a missing rate yields null and the UI simply omits the conversion.
@immutable
class Rates {
  const Rates({
    required this.defaultCurrency,
    double? dzdPerUsd,
    double? dzdPerEur,
    double? usdPerEur,
  }) : _dzdPerUsd = dzdPerUsd,
       _dzdPerEur = dzdPerEur,
       _usdPerEur = usdPerEur;

  final Currency defaultCurrency;
  final double? _dzdPerUsd;
  final double? _dzdPerEur;
  final double? _usdPerEur;

  /// A rate that is not finite and positive is no rate at all.
  static double? _sane(double? value) =>
      value != null && value.isFinite && value > 0 ? value : null;

  double? get dzdPerUsd => _sane(_dzdPerUsd);
  double? get dzdPerEur => _sane(_dzdPerEur);
  double? get usdPerEur => _sane(_usdPerEur);

  /// Converts [minor] units of [from] into the default currency;
  /// null when the needed rate is unknown.
  int? toDefault(int minor, Currency from) {
    if (from == defaultCurrency) return minor;
    final factor = _factor(from, defaultCurrency);
    if (factor == null || !factor.isFinite) return null;
    return (minor * factor).round();
  }

  double? _factor(Currency from, Currency to) {
    double? viaDzd(Currency currency) => switch (currency) {
      Currency.dzd => 1,
      Currency.usd => dzdPerUsd,
      Currency.eur => dzdPerEur,
    };

    // Direct EUR↔USD when fetched.
    if (from == Currency.eur && to == Currency.usd && usdPerEur != null) {
      return usdPerEur;
    }
    if (from == Currency.usd && to == Currency.eur && usdPerEur != null) {
      return 1 / usdPerEur!;
    }

    final fromDzd = viaDzd(from);
    final toDzd = viaDzd(to);
    if (fromDzd == null || toDzd == null) return null;
    return fromDzd / toDzd;
  }
}
