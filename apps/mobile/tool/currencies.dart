// Writes `lib/features/finances/domain/currency_data.g.dart` from
// `packages/core/fixtures/currencies.json` ([[Finances]], Phase 7 M7.8):
// every currency in circulation with its minor units, symbol and names,
// the currency of every country, and the country of every time zone. The
// web reads the same file through `packages/core`, so both apps know the
// same currencies and pick the same default.
//
// Run from apps/mobile: dart run tool/currencies.dart
import 'dart:convert';
import 'dart:io';

void main() {
  final source = File('../../packages/core/fixtures/currencies.json');
  final data = jsonDecode(source.readAsStringSync()) as Map<String, dynamic>;
  String quote(Object? value) => jsonEncode(value).replaceAll(r'$', r'\$');

  final out = StringBuffer()
    ..writeln('// Made by tool/currencies.dart from')
    ..writeln('// packages/core/fixtures/currencies.json; do not edit by hand.')
    ..writeln()
    ..writeln("import 'package:harvest/features/finances/domain/currency.dart';")
    ..writeln()
    ..writeln('/// Every currency in circulation, by code.')
    ..writeln('const currencyTable = <Currency>[');
  for (final raw in data['currencies'] as List<dynamic>) {
    final c = raw as Map<String, dynamic>;
    out.writeln(
      '  Currency(${quote(c['code'])}, ${c['minorUnits']}, '
      '${quote(c['symbol'])}, ${quote(c['en'])}, ${quote(c['ar'])}),',
    );
  }
  out
    ..writeln('];')
    ..writeln()
    ..writeln('/// ISO 3166-1 alpha-2 to the currency in everyday use there.')
    ..writeln('const countryCurrencies = <String, String>{');
  for (final entry in (data['byCountry'] as Map<String, dynamic>).entries) {
    out.writeln('  ${quote(entry.key)}: ${quote(entry.value)},');
  }
  out
    ..writeln('};')
    ..writeln()
    ..writeln('/// IANA time zone to the country it is in, from zone.tab.')
    ..writeln('const zoneCountries = <String, String>{');
  for (final entry in (data['zones'] as Map<String, dynamic>).entries) {
    out.writeln('  ${quote(entry.key)}: ${quote(entry.value)},');
  }
  out.writeln('};');
  File(
    'lib/features/finances/domain/currency_data.g.dart',
  ).writeAsStringSync(out.toString());
  stdout.writeln('wrote ${(data['currencies'] as List).length} currencies');
}
