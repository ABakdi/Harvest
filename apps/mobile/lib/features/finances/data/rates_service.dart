import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:harvest/features/finances/domain/currency.dart';
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

  /// What one US dollar buys of every currency, as JSON (`{"EUR": 0.92,
  /// …}`), fetched ([[Finances]], Phase 7 M7.8).
  static const perUsd = 'rate.perUsd';

  /// When the source last updated [perUsd], as an ISO instant in UTC.
  static const perUsdAt = 'rate.perUsdAt';

  static const List<String> all = [
    dzdPerUsd,
    dzdPerEur,
    usdPerEur,
    usdPerEurAt,
    perUsd,
    perUsdAt,
  ];
}

/// A rate the app is willing to store: finite, positive, and not absurd.
bool isSaneRate(double value) => value.isFinite && value > 0 && value < 1e6;

/// The fetched rates of [raw] (`rate.perUsd`), keeping only currencies
/// Harvest knows and rates that are rates.
Map<String, double>? perUsdOf(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    return {
      for (final MapEntry(:key, :value) in decoded.entries)
        if (value is num &&
            value.isFinite &&
            value > 0 &&
            Currency.tryCode(key) != null)
          key: value.toDouble(),
    };
  } on FormatException {
    return null;
  }
}

/// The rates the settings hold, for [defaultCurrency]: the fetched ones
/// and the dinar's, typed by hand.
Rates ratesFrom(Map<String, String?> values, Currency defaultCurrency) {
  double? rate(String key) => double.tryParse(values[key] ?? '');
  return Rates(
    defaultCurrency: defaultCurrency,
    perUsd: perUsdOf(values[RateKeys.perUsd]),
    dzdPerUsd: rate(RateKeys.dzdPerUsd),
    dzdPerEur: rate(RateKeys.dzdPerEur),
    usdPerEur: rate(RateKeys.usdPerEur),
  );
}

/// Fetches what a US dollar buys of every currency from Exchange Rate
/// API's open endpoint (no key, updated daily) and stores it, with the
/// day it was updated. Purely optional network: everything else works
/// without it, and nothing the source says is trusted without a sanity
/// check. The dinar's market rate is not there to fetch: the official
/// one is, and the parallel one stays typed by hand.
class RatesService {
  RatesService(this._settings, {http.Client? client, DateTime Function()? now})
    : _client = client ?? http.Client(),
      _now = now ?? DateTime.now;

  final SettingsRepository _settings;
  final http.Client _client;
  final DateTime Function() _now;

  static final Uri endpoint = Uri.parse(
    'https://open.er-api.com/v6/latest/USD',
  );

  /// What a dollar buys of the euro has lived between these for decades;
  /// anything outside is a broken response, not a market move.
  static const double minEurPerUsd = 0.5;
  static const double maxEurPerUsd = 2;

  /// The response is a few kilobytes; refuse anything that isn't.
  static const int maxBodyBytes = 64 * 1024;

  /// The fetched rates, or null when the network, the payload or the
  /// values can't be trusted. Never throws.
  Future<Map<String, double>?> fetchRates() async {
    try {
      final response = await _client
          .get(endpoint)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      if (response.bodyBytes.length > maxBodyBytes) return null;
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return null;
      if (body['result'] != 'success' || body['base_code'] != 'USD') {
        return null;
      }
      final raw = body['rates'];
      if (raw is! Map<String, dynamic>) return null;
      final rates = <String, double>{
        for (final MapEntry(:key, :value) in raw.entries)
          if (value is num &&
              value.isFinite &&
              value > 0 &&
              Currency.tryCode(key) != null)
            key: value.toDouble(),
      };
      final eur = rates['EUR'];
      if (eur == null || eur < minEurPerUsd || eur > maxEurPerUsd) return null;
      final seconds = body['time_last_update_unix'];
      final at = seconds is int
          ? DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true)
          : _now().toUtc();
      await _settings.setString(RateKeys.perUsd, jsonEncode(rates));
      await _settings.setString(RateKeys.perUsdAt, at.toIso8601String());
      // What 3.1 read, kept for a device not updated yet.
      await _settings.setString(RateKeys.usdPerEur, '${1 / eur}');
      await _settings.setString(RateKeys.usdPerEurAt, at.toIso8601String());
      return rates;
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
