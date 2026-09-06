import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:harvest/features/export/domain/archive_layout.dart';

/// One sheet, read back as a list of maps keyed by its header row.
///
/// By header rather than by position on purpose: a zip written by a
/// later version of the app may have gained a column, and an importer
/// that counts positions would then read every value one place to the
/// left. Unknown headers are carried and ignored; missing ones read as
/// null.
typedef SheetRows = List<Map<String, String>>;

/// A Harvest archive, opened.
class ArchiveBundle {
  ArchiveBundle({
    required this.sheets,
    required this.files,
  });

  /// Sheet name to its rows.
  final Map<String, SheetRows> sheets;

  /// Everything else in the zip, by its path inside it.
  final Map<String, Uint8List> files;

  SheetRows sheet(String name) => sheets[name] ?? const [];

  /// The note bodies as text, keyed by archive path.
  String? noteBody(String path) {
    final bytes = files[path];
    if (bytes == null) return null;
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return utf8.decode(bytes, allowMalformed: true);
    }
  }
}

/// Why an archive could not be opened.
enum ArchiveProblem {
  /// Not a zip at all, or a damaged one.
  unreadable,

  /// A zip, but not one of ours: no `harvest.xlsx` inside.
  notHarvest,

  /// The workbook is there but cannot be parsed.
  badWorkbook,
}

class ArchiveInvalid implements Exception {
  const ArchiveInvalid(this.problem);

  final ArchiveProblem problem;

  @override
  String toString() => 'ArchiveInvalid(${problem.name})';
}

/// Opens a Harvest zip and reads the workbook and the files out of it.
///
/// Nothing is written anywhere by this: reading is separated from
/// applying so the preview can be shown and refused (ADR-007 rule 6).
ArchiveBundle readArchive(Uint8List bytes) {
  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(bytes);
  } on Object {
    throw const ArchiveInvalid(ArchiveProblem.unreadable);
  }

  final files = <String, Uint8List>{};
  Uint8List? workbook;
  for (final entry in zip.files) {
    if (!entry.isFile) continue;
    final content = entry.content;
    if (content is! List<int>) continue;
    final data = Uint8List.fromList(content);
    if (entry.name == ArchivePaths.workbook) {
      workbook = data;
    } else {
      files[entry.name] = data;
    }
  }
  if (workbook == null) {
    throw const ArchiveInvalid(ArchiveProblem.notHarvest);
  }

  final Excel excel;
  try {
    excel = Excel.decodeBytes(workbook);
  } on Object {
    throw const ArchiveInvalid(ArchiveProblem.badWorkbook);
  }

  final sheets = <String, SheetRows>{};
  for (final entry in excel.tables.entries) {
    final rows = entry.value.rows;
    if (rows.isEmpty) continue;
    final headers = [
      for (final cell in rows.first) _text(cell?.value) ?? '',
    ];
    final parsed = <Map<String, String>>[];
    for (final row in rows.skip(1)) {
      final values = <String, String>{};
      for (var i = 0; i < headers.length && i < row.length; i++) {
        final header = headers[i];
        if (header.isEmpty) continue;
        final text = _text(row[i]?.value);
        if (text != null && text.isNotEmpty) values[header] = text;
      }
      if (values.isNotEmpty) parsed.add(values);
    }
    sheets[entry.key] = parsed;
  }

  return ArchiveBundle(sheets: sheets, files: files);
}

/// A cell as text, whatever the spreadsheet decided to store it as.
///
/// Derived columns come back as their computed value or as the formula
/// itself depending on who last saved the file; either way they are
/// ignored by the merge, which only reads stored columns.
String? _text(Object? value) => switch (value) {
  null => null,
  TextCellValue(:final value) => value.toString().trim(),
  IntCellValue(:final value) => '$value',
  DoubleCellValue(:final value) => '$value',
  BoolCellValue(:final value) => '$value',
  DateTimeCellValue() => value.toString(),
  FormulaCellValue() => null,
  _ => value.toString().trim(),
};
