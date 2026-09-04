import 'dart:typed_data';

import 'package:harvest/features/export/data/downloads_gateway.dart';
import 'package:harvest/features/export/data/export_repository.dart';
import 'package:harvest/features/export/domain/harvest_workbook.dart';
import 'package:harvest/features/export/domain/workbook.dart';
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

/// Reads the database, builds the workbook, drops it in Downloads.
class ExportService {
  ExportService(this._repository, this._downloads);

  final ExportRepository _repository;
  final DownloadsGateway _downloads;

  /// Returns the path the file landed on.
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
);

/// Where the export got to, for the Settings card to show.
sealed class ExportStatus {
  const ExportStatus();
}

class ExportIdle extends ExportStatus {
  const ExportIdle();
}

class ExportRunning extends ExportStatus {
  const ExportRunning();
}

class ExportSaved extends ExportStatus {
  const ExportSaved(this.path);

  final String path;
}

class ExportFailed extends ExportStatus {
  const ExportFailed(this.reason);

  /// A [DownloadFailure] reason, or null for anything else that broke.
  final String? reason;
}

/// Runs one export at a time and reports where it got to.
@riverpod
class ExportController extends _$ExportController {
  @override
  ExportStatus build() => const ExportIdle();

  Future<void> run() async {
    if (state is ExportRunning) return;
    state = const ExportRunning();
    try {
      final path = await ref.read(exportServiceProvider).exportWorkbook();
      state = ExportSaved(path);
    } on DownloadFailure catch (failure) {
      state = ExportFailed(failure.reason);
    } on Object {
      state = const ExportFailed(null);
    }
  }
}
