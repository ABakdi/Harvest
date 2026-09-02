import 'dart:convert';

import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'rates_service.g.dart';

/// Settings keys for exchange rates.
abstract final class RateKeys {
  static const dzdPerUsd = 'rate.dzdPerUsd';
  static const dzdPerEur = 'rate.dzdPerEur';
  static const usdPerEur = 'rate.usdPerEur';
  static const usdPerEurAt = 'rate.usdPerEurAt';
}

/// Fetches EUR→USD from the ECB (via the keyless Frankfurter API) and
/// stores it. Purely optional network: everything else works without it.
class RatesService {
  RatesService(this._settings);

  final SettingsRepository _settings;

  Future<double?> fetchEurUsd() async {
    try {
      final response = await http
          .get(Uri.parse('https://api.frankfurter.dev/v1/latest?base=EUR&symbols=USD'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final rate = ((body['rates'] as Map<String, dynamic>)['USD'] as num)
          .toDouble();
      await _settings.setString(RateKeys.usdPerEur, '$rate');
      await _settings.setString(
        RateKeys.usdPerEurAt,
        DateTime.now().toIso8601String(),
      );
      return rate;
    } on Object {
      return null;
    }
  }
}

@Riverpod(keepAlive: true)
RatesService ratesService(Ref ref) =>
    RatesService(ref.watch(settingsRepositoryProvider));
