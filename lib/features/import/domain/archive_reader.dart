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

  /// Bigger than this app will hold in memory — the whole archive,
  /// one entry, or what the entries add up to.
  tooLarge,
}

/// What an archive may weigh before it is refused.
///
/// The zip is decoded in memory, every entry copied out, and the app
/// is on a phone. These are generous for a real archive — five years
/// of daily pictures is a few hundred megabytes — and a hard stop for
/// one that was made to be large ([[Audit-v2-Beta]] S2-02).
abstract final class ArchiveLimits {
  /// The picked file itself.
  static const int archiveBytes = 768 * 1024 * 1024;

  /// Any one entry, uncompressed.
  static const int entryBytes = 64 * 1024 * 1024;

  /// Every entry, uncompressed, added up.
  static const int expandedBytes = 1024 * 1024 * 1024;

  /// The workbook on its own: a spreadsheet of rows, never pictures.
  static const int workbookBytes = 64 * 1024 * 1024;

  static const int entries = 100000;
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
  if (bytes.length > ArchiveLimits.archiveBytes) {
    throw const ArchiveInvalid(ArchiveProblem.tooLarge);
  }
  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(bytes);
  } on Object {
    throw const ArchiveInvalid(ArchiveProblem.unreadable);
  }

  // The sizes come from the zip's own directory, so they are checked
  // before a single entry is inflated: a bomb is refused by its label.
  if (zip.files.length > ArchiveLimits.entries) {
    throw const ArchiveInvalid(ArchiveProblem.tooLarge);
  }
  var expanded = 0;
  for (final entry in zip.files) {
    if (!entry.isFile) continue;
    final limit = entry.name == ArchivePaths.workbook
        ? ArchiveLimits.workbookBytes
        : ArchiveLimits.entryBytes;
    if (entry.size < 0 || entry.size > limit) {
      throw const ArchiveInvalid(ArchiveProblem.tooLarge);
    }
    expanded += entry.size;
    if (expanded > ArchiveLimits.expandedBytes) {
      throw const ArchiveInvalid(ArchiveProblem.tooLarge);
    }
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
  // The cell's own date, as ISO text the merge can read — not the
  // wrapper's `toString`, which read as "now" on every imported row a
  // spreadsheet had turned into a real date ([[Audit-v2-Beta]] Q2-07).
  DateTimeCellValue(
    :final year,
    :final month,
    :final day,
    :final hour,
    :final minute,
    :final second,
  ) =>
    DateTime(year, month, day, hour, minute, second).toIso8601String(),
  FormulaCellValue() => null,
  _ => value.toString().trim(),
};
