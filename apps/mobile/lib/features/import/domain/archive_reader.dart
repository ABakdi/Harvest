import 'dart:convert';
import 'dart:io' as io;
import 'dart:math';
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
    this.skipped = 0,
  });

  /// Sheet name to its rows.
  final Map<String, SheetRows> sheets;

  /// Everything else in the zip, by its path inside it.
  final Map<String, Uint8List> files;

  /// Entries left out for being over [ArchiveLimits.entryBytes]: a
  /// long video costs its own file, never the whole archive (Q5-06).
  final int skipped;

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

  /// Any one entry, uncompressed. A file over it is left out, and the
  /// rest of the archive still comes in; only the workbook is required.
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

/// What the workbook's own parts may weigh: any one part, all of them,
/// and how many there are.
abstract final class WorkbookLimits {
  static const int partBytes = 64 * 1024 * 1024;
  static const int totalBytes = 256 * 1024 * 1024;
  static const int parts = 2000;
}

/// One zip entry's bytes, inflated with a hard stop at [limit]: past it,
/// [ArchiveProblem.tooLarge], with at most a few kilobytes more than the
/// limit ever held.
Uint8List inflateEntry(ArchiveFile entry, {required int limit}) {
  final raw = entry.rawContent?.toUint8List();
  if (raw == null) throw const ArchiveInvalid(ArchiveProblem.unreadable);
  switch (entry.compressionType) {
    case ArchiveFile.STORE:
      if (raw.length > limit) {
        throw const ArchiveInvalid(ArchiveProblem.tooLarge);
      }
      return raw;
    case ArchiveFile.DEFLATE:
      final out = _CappedSink(limit);
      final inflater = io.ZLibDecoder(
        raw: true,
      ).startChunkedConversion(ByteConversionSink.from(out));
      const chunk = 4096;
      try {
        for (var i = 0; i < raw.length; i += chunk) {
          inflater.add(
            Uint8List.sublistView(raw, i, min(i + chunk, raw.length)),
          );
        }
        inflater.close();
      } on ArchiveInvalid {
        rethrow;
      } on Object {
        throw const ArchiveInvalid(ArchiveProblem.unreadable);
      }
      return out.bytes;
    default:
      throw const ArchiveInvalid(ArchiveProblem.unreadable);
  }
}

class _CappedSink implements Sink<List<int>> {
  _CappedSink(this.limit);

  final int limit;
  final _builder = BytesBuilder(copy: false);

  Uint8List get bytes => _builder.takeBytes();

  @override
  void add(List<int> data) {
    if (_builder.length + data.length > limit) {
      throw const ArchiveInvalid(ArchiveProblem.tooLarge);
    }
    _builder.add(data);
  }

  @override
  void close() {}
}

/// Refuses a workbook whose own parts, inflated, would be too much: by
/// count, and by what each one and all of them actually weigh.
void checkWorkbookParts(Uint8List workbook) {
  final Archive parts;
  try {
    parts = ZipDecoder().decodeBytes(workbook);
  } on Object {
    throw const ArchiveInvalid(ArchiveProblem.badWorkbook);
  }
  if (parts.files.length > WorkbookLimits.parts) {
    throw const ArchiveInvalid(ArchiveProblem.tooLarge);
  }
  var total = 0;
  for (final part in parts.files) {
    if (!part.isFile) continue;
    total += inflateEntry(
      part,
      limit: min(WorkbookLimits.partBytes, WorkbookLimits.totalBytes - total),
    ).length;
  }
}

/// [readArchive] of the file at [path], read where this runs: on the
/// isolate that unzips it (P6-07).
ArchiveBundle readArchiveAt(String path) {
  final file = io.File(path);
  if (file.lengthSync() > ArchiveLimits.archiveBytes) {
    throw const ArchiveInvalid(ArchiveProblem.tooLarge);
  }
  return readArchive(file.readAsBytesSync());
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
  // The label is the archive's own word, though, and a crafted zip can
  // declare a kilobyte and inflate to gigabytes — so what comes out is
  // weighed again below ([[Audit-v2]] S3-01).
  if (zip.files.length > ArchiveLimits.entries) {
    throw const ArchiveInvalid(ArchiveProblem.tooLarge);
  }
  var expanded = 0;
  final oversized = <ArchiveFile>{};
  for (final entry in zip.files) {
    if (!entry.isFile) continue;
    final isWorkbook = entry.name == ArchivePaths.workbook;
    final limit = isWorkbook
        ? ArchiveLimits.workbookBytes
        : ArchiveLimits.entryBytes;
    if (entry.size < 0 || (isWorkbook && entry.size > limit)) {
      throw const ArchiveInvalid(ArchiveProblem.tooLarge);
    }
    if (entry.size > limit) {
      // Left out, never inflated, and counted for the preview.
      oversized.add(entry);
      continue;
    }
    expanded += entry.size;
    if (expanded > ArchiveLimits.expandedBytes) {
      throw const ArchiveInvalid(ArchiveProblem.tooLarge);
    }
  }

  final files = <String, Uint8List>{};
  Uint8List? workbook;
  var inflated = 0;
  for (final entry in zip.files) {
    if (!entry.isFile || oversized.contains(entry)) continue;
    final isWorkbook = entry.name == ArchivePaths.workbook;
    final limit = isWorkbook
        ? ArchiveLimits.workbookBytes
        : ArchiveLimits.entryBytes;
    // What the entry actually weighs, weighed while it inflates: a zip
    // that lied about its directory is refused the moment it proves it,
    // before the lie is in memory (S6-09).
    final data = inflateEntry(
      entry,
      limit: min(limit, ArchiveLimits.expandedBytes - inflated),
    );
    inflated += data.length;
    if (isWorkbook) {
      workbook = data;
    } else {
      files[entry.name] = data;
    }
  }
  if (workbook == null) {
    throw const ArchiveInvalid(ArchiveProblem.notHarvest);
  }
  // The workbook is a zip too: its own parts are weighed the same way
  // before the spreadsheet library expands them (S6-09).
  checkWorkbookParts(workbook);

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

  return ArchiveBundle(
    sheets: sheets,
    files: files,
    skipped: oversized.length,
  );
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
