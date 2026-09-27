import 'dart:async';

import 'package:drift/drift.dart' show countAll;
import 'package:flutter/foundation.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/features/account/data/api_client.dart';
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/gallery/data/gallery_storage.dart';
import 'package:harvest/features/gallery/data/memory_files.dart';
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

  /// The server was not reached the last time it was tried.
  bool get offline => error == 'offline';

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

  /// How often the key is held against the account's key check, and
  /// how soon again at the most: the key routes allow an account 60
  /// requests in 15 minutes.
  static const checkEvery = Duration(minutes: 30);
  static const checkAtMost = Duration(minutes: 2);

  /// The error a sync ends with when the PIN was started over on
  /// another device and the key here no longer fits.
  static const pinChanged = 'pinChanged';

  DateTime? _checkedAt;
  var _lockedAtCheck = 0;

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

  Future<void>? _run;
  var _again = false;

  /// Syncs now, if there is a verified account to sync with. Quietly
  /// does nothing otherwise: an account is optional ([[Accounts]] AC1).
  ///
  /// Asked while a sync is running, it runs once more when that one
  /// ends, and answers when both are done: what was asked for — a PIN
  /// just set, a change just made — may have missed the running one.
  Future<void> syncNow() {
    final running = _run;
    if (running != null) {
      _again = true;
      return running;
    }
    return _run = _loop().whenComplete(() => _run = null);
  }

  Future<void> _loop() async {
    do {
      _again = false;
      await _once();
    } while (_again);
  }

  Future<void> _once() async {
    final account = await ref.read(accountControllerProvider.future);
    var me = account.me;
    if (me == null) return;
    if (!me.verified) {
      // The link was likely opened somewhere else since: ask again,
      // or this phone would wait for a restart that changes nothing.
      try {
        await ref.read(accountControllerProvider.notifier).refreshMe();
      } on ApiException {
        return;
      }
      me = (await ref.read(accountControllerProvider.future)).me;
      if (me == null || !me.verified) return;
    }
    state = state.copyWith(running: true);
    // The key is held against the account's check — another device may
    // have started the PIN over — now and then, and always before a
    // private row would go up sealed with it.
    final since = _checkedAt == null
        ? null
        : DateTime.now().difference(_checkedAt!);
    final service = ref.read(syncServiceProvider);
    if (since == null ||
        since > checkEvery ||
        (since > checkAtMost && await service.privatePending())) {
      if (await _pinChanged()) return;
    }
    try {
      final report = await service.run();
      // Rows that stopped opening say the same, sooner.
      if (report.locked > _lockedAtCheck && await _pinChanged()) return;
      _lockedAtCheck = report.locked;
      await _syncFiles();
      state = state.copyWith(running: false, last: report, clearError: true);
    } on ApiException catch (error) {
      state = state.copyWith(running: false, error: error.code);
    } on Object catch (error) {
      debugPrint('[sync] failed: ${error.runtimeType}');
      state = state.copyWith(running: false, error: 'internal');
    }
  }

  /// Whether the key here no longer opens the account's check; it is
  /// then forgotten, and the sync ends saying so ([[Accounts]]).
  Future<bool> _pinChanged() async {
    _checkedAt = DateTime.now();
    final pin = ref.read(syncPassphraseProvider.notifier);
    if (await pin.stillTheAccounts() != false) return false;
    _lockedAtCheck = 0;
    state = state.copyWith(running: false, error: pinChanged);
    return true;
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
      final report = await files.run(
        // A path from a row is still a path from somewhere else's
        // archive ([[Audit-v2-Beta]] S2-01): it is checked before it
        // becomes a file to write to.
        gallery: (relative) async => GalleryStorage.isSafeRelative(relative)
            ? await gallery.fileOf(relative)
            : null,
        attachments: (relative) async => GalleryStorage.isSafeRelative(relative)
            ? await attachments.fileOf(relative)
            : null,
      );
      if (report.downloaded > 0) {
        ref.read(fileArrivalsProvider.notifier).landed();
      }
    } on Object catch (error) {
      debugPrint('[sync] files: ${error.runtimeType}');
    }
  }
}
