import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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

  static const List<String> all = [
    dzdPerUsd,
    dzdPerEur,
    usdPerEur,
    usdPerEurAt,
  ];
}

/// A rate the app is willing to store: finite, positive, and not absurd.
bool isSaneRate(double value) => value.isFinite && value > 0 && value < 1e6;

/// Fetches EUR→USD from the ECB (via the keyless Frankfurter API) and
/// stores it. Purely optional network: everything else works without it,
/// and nothing the server says is trusted without a sanity check.
class RatesService {
  RatesService(this._settings, {http.Client? client, DateTime Function()? now})
    : _client = client ?? http.Client(),
      _now = now ?? DateTime.now;

  final SettingsRepository _settings;
  final http.Client _client;
  final DateTime Function() _now;

  static final Uri endpoint = Uri.parse(
    'https://api.frankfurter.dev/v1/latest?base=EUR&symbols=USD',
  );

  /// EUR→USD has lived between these for decades; anything outside is a
  /// broken response, not a market move.
  static const double minEurUsd = 0.5;
  static const double maxEurUsd = 2;

  /// The response is a few hundred bytes; refuse anything that isn't.
  static const int maxBodyBytes = 64 * 1024;

  /// The fetched rate, or null when the network, the payload or the
  /// value itself can't be trusted. Never throws.
  Future<double?> fetchEurUsd() async {
    try {
      final response = await _client
          .get(endpoint)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      if (response.bodyBytes.length > maxBodyBytes) return null;
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return null;
      final rates = body['rates'];
      if (rates is! Map<String, dynamic>) return null;
      final raw = rates['USD'];
      if (raw is! num) return null;
      final rate = raw.toDouble();
      if (!isSaneRate(rate) || rate < minEurUsd || rate > maxEurUsd) {
        return null;
      }
      await _settings.setString(RateKeys.usdPerEur, '$rate');
      await _settings.setString(
        RateKeys.usdPerEurAt,
        _now().toIso8601String(),
      );
      return rate;
    } on SocketException {
      return null;
    } on TimeoutException {
      return null;
    } on FormatException {
      return null;
    } on http.ClientException {
      return null;
    } on Object catch (error) {
      debugPrint('[rates] fetch failed: ${error.runtimeType}');
      return null;
    }
  }
}

@Riverpod(keepAlive: true)
RatesService ratesService(Ref ref) =>
    RatesService(ref.watch(settingsRepositoryProvider));
