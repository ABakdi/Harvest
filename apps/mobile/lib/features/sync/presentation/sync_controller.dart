import 'dart:async';

import 'package:drift/drift.dart' show countAll;
import 'package:flutter/foundation.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/features/account/data/api_client.dart';
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/account/domain/heartbeat.dart';
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

  /// How often the key's epoch is held against the account's when
  /// nothing sealed waits; with sealed rows waiting it is held against it
  /// before every run (one small request).
  static const checkEvery = Duration(minutes: 30);

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
          _debounce?.cancel();
          // Emptied by the sync itself: nothing left to start one for
          // (P6-12).
          if (pending == 0) return;
          _debounce = Timer(debounce, () => unawaited(syncNow()));
        });
  }

  Future<void>? _run;
  var _again = false;

  /// Whether this run has read the account from the server yet.
  var _meRead = false;

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
    final signedIn = account.me;
    if (signedIn == null) return;
    var me = signedIn;
    if (!_meRead) {
      // The account as the server has it, once a run: a name or a
      // verification changed elsewhere would otherwise stay as it was at
      // sign-in for good.
      _meRead = true;
      try {
        await ref.read(accountControllerProvider.notifier).refreshMe();
        final fresh = (await ref.read(accountControllerProvider.future)).me;
        if (fresh == null) return;
        me = fresh;
      } on Object {
        // Offline, refused, or the keystore not answering: the copy from
        // sign-in does for now, and the run goes on to say what it can.
      }
    }
    // Once a day, this phone says it is in use ([[Admin]]); the first
    // run of a new day sends it, and it never holds the sync up.
    unawaited(ref.read(heartbeatProvider).beat());
    if (!me.verified) {
      // The link was likely opened somewhere else since: ask again,
      // or this phone would wait for a restart that changes nothing.
      try {
        await ref.read(accountControllerProvider.notifier).refreshMe();
      } on ApiException {
        return;
      }
      final again = (await ref.read(accountControllerProvider.future)).me;
      if (again == null || !again.verified) return;
    }
    final service = ref.read(syncServiceProvider);
    // Signed in on a phone with data of its own: nothing goes until I
    // have said where it goes (U6-05).
    if (await service.joinPending()) return;
    state = state.copyWith(running: true);
    // Everything after `running` is inside the try, the key check too: a
    // Keystore or database failure there ends the run rather than leave
    // it showing as syncing (Q6-11).
    try {
      // The key's epoch is held against the account's — another device
      // may have started the PIN over — now and then, and always before
      // a private row would go up sealed with it.
      final since = _checkedAt == null
          ? null
          : DateTime.now().difference(_checkedAt!);
      if (since == null ||
          since > checkEvery ||
          await service.privatePending()) {
        if (await _pinChanged()) return;
      }
      final report = await service.run();
      // Rows that stopped opening say the same, sooner.
      if (report.locked > _lockedAtCheck && await _pinChanged()) return;
      _lockedAtCheck = report.locked;
      await _syncFiles();
      state = state.copyWith(running: false, last: report, clearError: true);
    } on SyncKeyChanged {
      await _keyChanged();
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

  /// The server refused a sealed write for a stale key epoch (S6-07): the
  /// key goes, and the PIN is asked for again.
  Future<void> _keyChanged() async {
    await ref.read(syncPassphraseProvider.notifier).keyChanged();
    _lockedAtCheck = 0;
    state = state.copyWith(running: false, error: pinChanged);
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
    } on SyncKeyChanged {
      rethrow;
    } on Object catch (error) {
      debugPrint('[sync] files: ${error.runtimeType}');
    }
  }
}
