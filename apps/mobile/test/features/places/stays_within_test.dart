import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/places/domain/place.dart';

/// `packages/core/fixtures/places.json` `staysWithin`: a stay across the
/// 3 AM line belongs to both days, each its own part ([[Audit-v3]] Q5-58).
void main() {
  final spec = jsonDecode(
    File('../../packages/core/fixtures/places.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  List<Map<String, dynamic>> list(Object? json) =>
      (json! as List<dynamic>).cast<Map<String, dynamic>>();

  for (final c in list(spec['staysWithin'])) {
    test(c['why'] as String, () {
      final stays = staysWithin(
        [
          for (final p in list(c['points']))
            Fix(
              latitude: (p['latitude'] as num).toDouble(),
              longitude: (p['longitude'] as num).toDouble(),
              at: DateTime.parse(p['at'] as String),
            ),
        ],
        start: DateTime.parse(c['dayStart'] as String),
        end: DateTime.parse(c['dayEnd'] as String),
      );
      expect(
        [
          for (final s in stays)
            {
              'from': s.from,
              'to': s.to,
              'minutes': s.length.inMinutes,
            },
        ],
        [
          for (final r in list(c['result']))
            {
              'from': DateTime.parse(r['from'] as String),
              'to': DateTime.parse(r['to'] as String),
              'minutes': r['minutes'],
            },
        ],
      );
    });
  }
}
