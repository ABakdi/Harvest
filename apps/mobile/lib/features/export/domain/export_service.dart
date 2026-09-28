import 'package:flutter/foundation.dart';
import 'package:harvest/features/export/data/downloads_gateway.dart';
import 'package:harvest/features/export/data/export_repository.dart';
import 'package:harvest/features/export/domain/archive_service.dart';
import 'package:harvest/features/export/domain/harvest_workbook.dart';
import 'package:harvest/features/export/domain/workbook.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'export_service.g.dart';

/// The MIME type Android files an `.xlsx` under.
const xlsxMimeType =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// `harvest-2026-09-04-1830.xlsx` — sortable, and never two exports on
/// the same name unless they were a minute apart.
String exportFileName(DateTime at) {
  String two(int value) => value.toString().padLeft(2, '0');
  return 'harvest-${at.year}-${two(at.month)}-${two(at.day)}'
      '-${two(at.hour)}${two(at.minute)}.xlsx';
}

/// Reads the database, builds the archive, drops it in Downloads.
///
/// Since ADR-007 what lands there is a zip holding the workbook, the
/// notes as a vault and the gallery as folders of files. The workbook
/// alone is still built the same way, and still exactly as ADR-006
/// specified it — it is now one entry inside the archive.
/// Whether an export carries my location history ([[Places]] PL6). A
/// choice about this phone's exports, so it never leaves it.
const exportIncludesPlacesKey = 'export.includePlaces';

class ExportService {
  ExportService(this._repository, this._downloads, this._archive);

  final ExportRepository _repository;
  final DownloadsGateway _downloads;
  final ArchiveService _archive;

  /// The whole archive. Returns the path the file landed on.
  /// [onTooLarge] hears of each file left out for its size.
  Future<String> exportArchive({
    DateTime? now,
    void Function(ArchiveProgress)? onProgress,
    bool Function()? cancelled,
    bool includePlaces = true,
    void Function(String path)? onTooLarge,
    void Function(String path)? onNotHere,
  }) async {
    final at = now ?? DateTime.now();
    final bytes = await _archive.build(
      now: at,
      onProgress: onProgress,
      cancelled: cancelled,
      includePlaces: includePlaces,
      onTooLarge: onTooLarge,
      onNotHere: onNotHere,
    );
    return _downloads.save(
      fileName: archiveFileName(at),
      bytes: bytes,
      mimeType: zipMimeType,
    );
  }

  /// The workbook on its own, without the files.
  @visibleForTesting
  Future<String> exportWorkbook({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final data = await _repository.read(generatedAt: at);
    final bytes = buildWorkbook(harvestSheets(data));
    return _downloads.save(
      fileName: exportFileName(at),
      bytes: Uint8List.fromList(bytes),
      mimeType: xlsxMimeType,
    );
  }
}

@Riverpod(keepAlive: true)
ExportService exportService(Ref ref) => ExportService(
  ref.watch(exportRepositoryProvider),
  ref.watch(downloadsGatewayProvider),
  ref.watch(archiveServiceProvider),
);

/// Where the export got to, for the Settings card to show.
sealed class ExportStatus {
  const ExportStatus();
}

class ExportIdle extends ExportStatus {
  const ExportIdle();
}

class ExportRunning extends ExportStatus {
  const ExportRunning([this.progress]);

  /// Null until the first entry is written.
  final ArchiveProgress? progress;

  /// 0..1, or null while the total is not known yet.
  double? get fraction {
    final at = progress;
    if (at == null || at.total == 0) return null;
    return at.done / at.total;
  }
}

/// Stopped part-way, deliberately. Nothing was written.
class ExportCancelled extends ExportStatus {
  const ExportCancelled();
}

class ExportSaved extends ExportStatus {
  const ExportSaved(this.path, {this.leftOut = 0, this.notHere = 0});

  final String path;

  /// Files too large for an archive, left out of it.
  final int leftOut;

  /// Pictures only the server holds so far, not in the archive.
  final int notHere;
}

class ExportFailed extends ExportStatus {
  const ExportFailed(this.reason);

  /// A [DownloadFailure] reason, or null for anything else that broke.
  final String? reason;
}

/// Runs one export at a time and reports where it got to.
///
/// The archive is now slow enough to need both halves of this: a count
/// that moves, and a way to stop it. A cancelled export has written
/// nothing anywhere.
@riverpod
class ExportController extends _$ExportController {
  var _cancelled = false;

  @override
  ExportStatus build() => const ExportIdle();

  void cancel() {
    if (state is ExportRunning) _cancelled = true;
  }

  Future<void> run() async {
    if (state is ExportRunning) return;
    _cancelled = false;
    state = const ExportRunning();
    // An export running is kept, whoever still watches it: the zip is
    // built off the UI isolate, and its answer lands later.
    final keep = ref.keepAlive();
    try {
      final includePlaces =
          await ref
              .read(settingsRepositoryProvider)
              .getString(exportIncludesPlacesKey) !=
          'false';
      var leftOut = 0;
      var notHere = 0;
      final path = await ref
          .read(exportServiceProvider)
          .exportArchive(
            includePlaces: includePlaces,
            onTooLarge: (_) => leftOut++,
            onNotHere: (_) => notHere++,
            onProgress: (progress) {
              if (state is ExportRunning) state = ExportRunning(progress);
            },
            cancelled: () => _cancelled,
          );
      state = ExportSaved(path, leftOut: leftOut, notHere: notHere);
    } on ArchiveCancelled {
      state = const ExportCancelled();
    } on DownloadFailure catch (failure) {
      state = ExportFailed(failure.reason);
    } on Object {
      state = const ExportFailed(null);
    } finally {
      keep.close();
    }
  }
}
