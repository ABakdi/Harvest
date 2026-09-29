import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/export/domain/archive_layout.dart';
import 'package:harvest/features/export/domain/workbook.dart';
import 'package:harvest/features/notes/domain/note.dart';

/// `packages/core/fixtures/file-names.json`: the names an archive gives
/// notes, folders and albums, and what a workbook cell holds, the same
/// on the phone as on the web ([[Audit-v3]] Q5-24, Q5-59).
void main() {
  final data = jsonDecode(
    File(
      '../../packages/core/fixtures/file-names.json',
    ).readAsStringSync(),
  ) as Map<String, dynamic>;
  List<Map<String, dynamic>> list(String key) =>
      (data[key] as List<dynamic>).cast<Map<String, dynamic>>();
  String label(Map<String, dynamic> c, String fallback) =>
      c['why'] == null ? fallback : '$fallback: ${c['why']}';

  group('safeFileName', () {
    for (final (i, c) in list('safeFileName').indexed) {
      test(label(c, 'case $i'), () {
        expect(safeFileName(c['title'] as String), c['name']);
      });
    }
  });

  group('cellText', () {
    for (final (i, c) in list('cellText').indexed) {
      test(label(c, 'case $i'), () {
        final input =
            c['text'] as String? ??
            (c['prefix'] as String? ?? '') +
                (c['repeat'] as String) * (c['times'] as int);
        final out = cellText(input);
        if (c['cell'] != null) expect(out, c['cell']);
        if (c['length'] != null) expect(out.length, c['length']);
      });
    }
  });

  group('sameFile', () {
    for (final c in list('sameFile')) {
      test('${c['a']} and ${c['b']}', () {
        expect(
          fileNameKey(c['a'] as String) == fileNameKey(c['b'] as String),
          c['same'],
        );
      });
    }
  });

  test('Ideas and ideas do not land on one file', () {
    final taken = <String>{};
    final first = notePath(title: 'Ideas', folder: '', taken: taken);
    final second = notePath(title: 'ideas', folder: '', taken: taken);
    expect(first, 'notes/Ideas.md');
    expect(second, 'notes/ideas (2).md');
  });

  test('a control character does not reach the workbook', () {
    final bytes = buildWorkbook([
      const ExportSheet(
        name: 'Notes',
        headers: ['Body'],
        rows: [
          ['a\u000bb'],
        ],
      ),
    ]);
    final xml = [
      for (final file in ZipDecoder().decodeBytes(bytes).files)
        if (file.name.endsWith('.xml')) utf8.decode(file.content as List<int>),
    ].join();
    expect(xml, contains('ab'));
    expect(xml.toLowerCase(), isNot(contains('&#xb;')));
  });
}
