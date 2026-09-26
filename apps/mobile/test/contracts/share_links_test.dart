import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/lists/domain/lists.dart';
import 'package:harvest/features/lists/domain/share_links.dart';

/// Where a shared link lands ([[Lists]]: Saving from anywhere), held to
/// the same `packages/core/fixtures/share-links.json` as the web's add
/// field, so a link pasted on the web and shared on the phone go to the
/// same list with the same type.
void main() {
  final data =
      jsonDecode(
            File(
              '../../packages/core/fixtures/share-links.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  List<Map<String, dynamic>> cases(String key) =>
      (data[key] as List<dynamic>).cast<Map<String, dynamic>>();

  String label(Map<String, dynamic> c, String fallback) {
    final why = c['why'] as String?;
    return why == null ? fallback : '$fallback: $why';
  }

  test('names the same video sites', () {
    expect(videoHosts, data['videoHosts']);
  });

  for (final c in cases('linkOf')) {
    test(label(c, 'linkOf(${c['text']}) is ${c['link']}'), () {
      expect(linkOf(c['text'] as String), c['link']);
    });
  }

  for (final c in cases('classify')) {
    test(label(c, '${c['url']} lands in ${c['list']}'), () {
      final link = classifyLink(c['url'] as String);
      expect(link.list, BuiltInList.ofKey(c['list'] as String));
      expect(link.mediaType, MediaType.values.byName(c['mediaType'] as String));
    });
  }
}
