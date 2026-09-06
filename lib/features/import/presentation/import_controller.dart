import 'package:harvest/features/import/data/archive_picker.dart';
import 'package:harvest/features/import/domain/archive_reader.dart';
import 'package:harvest/features/import/domain/import_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'import_controller.g.dart';

/// Where the import has got to.
sealed class ImportState {
  const ImportState();
}

class ImportIdle extends ImportState {
  const ImportIdle();
}

class ImportReading extends ImportState {
  const ImportReading();
}

/// Read, counted, and waiting for a yes. Nothing has been written.
class ImportReady extends ImportState {
  const ImportReady({
    required this.name,
    required this.bundle,
    required this.preview,
  });

  final String name;
  final ArchiveBundle bundle;
  final ImportPreview preview;
}

class ImportApplying extends ImportState {
  const ImportApplying();
}

class ImportDone extends ImportState {
  const ImportDone(this.preview);

  final ImportPreview preview;
}

class ImportFailed extends ImportState {
  const ImportFailed(this.problem);

  /// Null for anything that broke that was not the archive's fault.
  final ArchiveProblem? problem;
}

/// Picks an archive, reads it, shows what it would do, and — only if
/// asked again — does it.
///
/// The two steps are deliberately separate calls: an import that
/// started the moment a file was chosen would be a restore-over by
/// accident, and ADR-007 rule 6 says I get to see it first.
@riverpod
class ImportController extends _$ImportController {
  @override
  ImportState build() => const ImportIdle();

  void reset() => state = const ImportIdle();

  /// Choose a zip and count what it holds.
  Future<void> choose() async {
    if (state is ImportReading || state is ImportApplying) return;
    state = const ImportReading();
    try {
      final picked = await ref.read(archivePickerProvider).pickZip();
      if (picked == null) {
        state = const ImportIdle();
        return;
      }
      final bundle = readArchive(picked.bytes);
      final preview = await ref.read(importServiceProvider).preview(bundle);
      state = ImportReady(
        name: picked.name,
        bundle: bundle,
        preview: preview,
      );
    } on ArchiveInvalid catch (invalid) {
      state = ImportFailed(invalid.problem);
    } on Object {
      state = const ImportFailed(null);
    }
  }

  /// Carry out the merge that was previewed.
  Future<void> apply() async {
    if (state case ImportReady(:final bundle)) {
      state = const ImportApplying();
      try {
        final result = await ref.read(importServiceProvider).apply(bundle);
        state = ImportDone(result);
      } on Object {
        state = const ImportFailed(null);
      }
    }
  }
}
