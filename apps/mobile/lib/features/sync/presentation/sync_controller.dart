import 'dart:async';
import 'package:drift/drift.dart' show countAll;
import 'package:flutter/foundation.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/features/account/data/api_client.dart';
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/gallery/data/gallery_storage.dart';
import 'package:harvest/features/notes/data/note_attachments.dart';
import 'package:harvest/features/sync/domain/sync_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_controller.g.dart';

/// What the account screen says about sync.
@immutable
class SyncStatus {
  const SyncStatus({
    this.running = false,
    this.last,
    this.error,
    this.pending = 0,
  });

  final bool running;
  final SyncReport? last;

  /// The last failure's code (`offline`, `forbidden`, …), cleared by the
  /// next success.
  final String? error;

  /// Changes waiting in the outbox.
  final int pending;

  SyncStatus copyWith({
    bool? running,
    SyncReport? last,
    String? error,
    bool clearError = false,
    int? pending,
  }) => SyncStatus(
    running: running ?? this.running,
    last: last ?? this.last,
    error: clearError ? null : error ?? this.error,
    pending: pending ?? this.pending,
  );
}

/// When sync runs ([[Sync-API]]: order of a sync): on resume, two
/// seconds after the last local write, and every fifteen minutes while
/// the app is open — and never more than once at a time, which the
/// service itself guarantees.
@Riverpod(keepAlive: true)
class SyncController extends _$SyncController {
  Timer? _debounce;
  Timer? _periodic;
  StreamSubscription<int>? _outbox;

  static const debounce = Duration(seconds: 2);
  static const every = Duration(minutes: 15);

  @override
  SyncStatus build() {
    ref.onDispose(() {
      _debounce?.cancel();
      _periodic?.cancel();
      unawaited(_outbox?.cancel());
    });
    return const SyncStatus();
  }

  /// Starts the triggers. Cheap to call again.
  void start() {
    _periodic ??= Timer.periodic(every, (_) => unawaited(syncNow()));
    if (_outbox != null) return;
    final db = ref.read(databaseProvider);
    final count = countAll();
    _outbox = (db.selectOnly(db.outbox)..addColumns([count]))
        .map((row) => row.read(count) ?? 0)
        .watchSingle()
        .listen((pending) {
          state = state.copyWith(pending: pending);
          if (pending == 0) return;
          _debounce?.cancel();
          _debounce = Timer(debounce, () => unawaited(syncNow()));
        });
  }

  /// Syncs now, if there is a verified account to sync with. Quietly
  /// does nothing otherwise: an account is optional ([[Accounts]] AC1).
  Future<void> syncNow() async {
    final account = await ref.read(accountControllerProvider.future);
    final me = account.me;
    if (me == null || !me.verified || state.running) return;
    state = state.copyWith(running: true);
    try {
      final report = await ref.read(syncServiceProvider).run();
      await _syncFiles();
      state = state.copyWith(running: false, last: report, clearError: true);
    } on ApiException catch (error) {
      state = state.copyWith(running: false, error: error.code);
    } on SyncPassphraseMismatch {
      // The key cannot open what the other devices sealed: forget it,
      // and ask again, rather than sync around the rows it cannot read.
      await ref.read(syncPassphraseProvider.notifier).forget();
      state = state.copyWith(running: false, error: 'passphrase');
    } on Object catch (error) {
      debugPrint('[sync] failed: ${error.runtimeType}');
      state = state.copyWith(running: false, error: 'internal');
    }
  }

  /// Pictures and recordings, after the rows ([[Sync-API]]).
  ///
  /// A file failing is not a sync failing: the rows are already there,
  /// and the next run picks the file up again. Without a passphrase
  /// there is nothing to do, because files travel sealed or not at all.
  Future<void> _syncFiles() async {
    final files = await ref.read(fileSyncProvider.future);
    if (files == null) return;
    final gallery = ref.read(galleryStorageProvider);
    final attachments = ref.read(attachmentStorageProvider);
    try {
      await files.run(
        // A path from a row is still a path from somewhere else's
        // archive ([[Audit-v2-Beta]] S2-01): it is checked before it
        // becomes a file to write to.
        gallery: (relative) async => GalleryStorage.isSafeRelative(relative)
            ? await gallery.fileOf(relative)
            : null,
        attachments: (relative) async =>
            GalleryStorage.isSafeRelative(relative)
            ? await attachments.fileOf(relative)
            : null,
      );
    } on Object catch (error) {
      debugPrint('[sync] files: ${error.runtimeType}');
    }
  }
}
