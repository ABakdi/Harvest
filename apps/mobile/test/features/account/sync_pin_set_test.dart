import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/platform/secret_store.dart';
import 'package:harvest/features/account/data/api_client.dart' show Me;
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/finances/data/finances_repository.dart';
import 'package:harvest/features/gallery/data/gallery_storage.dart';
import 'package:harvest/features/sync/domain/file_sync.dart';
import 'package:harvest/features/sync/domain/sync_cipher.dart';
import 'package:harvest/features/sync/domain/sync_service.dart';
import 'package:harvest/features/sync/presentation/sync_controller.dart';

import '../../support/fake_remote.dart';
import '../../support/temp_gallery_storage.dart';

class _Secrets implements SecretStore {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String? value) async =>
      value == null ? _values.remove(key) : _values[key] = value;
}

/// The file routes in memory: bytes kept under the name they came with.
class _Files implements FileRemote {
  final held = <String, ({Uint8List sealed, String iv})>{};

  @override
  Future<List<String>> missing(List<String> hashes) async =>
      hashes.where((hash) => !held.containsKey(hash)).toList();

  @override
  Future<void> upload(String sha256, Uint8List sealed, String iv) async =>
      held[sha256] = (sealed: sealed, iv: iv);

  @override
  Future<({Uint8List sealed, String iv})> download(String sha256) async =>
      held[sha256] ?? (throw StateError('no such file'));
}

class _Account extends AccountController {
  @override
  Future<AccountState> build() async => AccountState(
    serverUrl: 'https://harvest.example.com',
    me: Me(
      id: 'u1',
      email: 'maya@example.com',
      syncSalt: 'the-account-salt',
      verifiedAt: DateTime.utc(2026, 9, 2),
    ),
  );
}

/// Signed up here, verified from the email on another device since:
/// the server knows, this phone does not until it asks.
class _Unverified extends AccountController {
  int asked = 0;

  static Me me({required bool verified}) => Me(
    id: 'u1',
    email: 'maya@example.com',
    syncSalt: 'the-account-salt',
    verifiedAt: verified ? DateTime.utc(2026, 9, 2) : null,
  );

  @override
  Future<AccountState> build() async => AccountState(
    serverUrl: 'https://harvest.example.com',
    me: me(verified: false),
  );

  @override
  Future<void> refreshMe() async {
    asked++;
    state = AsyncData(
      AccountState(
        serverUrl: 'https://harvest.example.com',
        me: me(verified: true),
      ),
    );
  }
}

/// Setting the sync PIN opens the private tier at once ([[Accounts]]
/// AC7): what waited — money, and the pictures — goes up sealed on the
/// sync that follows, and a later device's PIN is checked against what
/// the first one sealed.
void main() {
  late FakeRemote remote;
  late _Files files;
  late List<HarvestDatabase> dbs;
  late List<Directory> dirs;

  setUp(() {
    remote = FakeRemote();
    files = _Files();
    dbs = [];
    dirs = [];
  });

  tearDown(() async {
    for (final db in dbs) {
      await db.close();
    }
    for (final dir in dirs) {
      await dir.delete(recursive: true);
    }
  });

  /// One phone: its database, its keystore, its pictures, and the real
  /// PIN and sync controllers over the fake server.
  Future<({HarvestDatabase db, ProviderContainer container, Directory dir})>
  phone({AccountController Function()? account}) async {
    final db = HarvestDatabase.forTesting(NativeDatabase.memory());
    final dir = await Directory.systemTemp.createTemp('harvest-pin');
    dbs.add(db);
    dirs.add(dir);
    final secrets = _Secrets();
    Future<SyncCipher?> cipher() async {
      final stored = await secrets.read(SyncPassphrase.keyName);
      return stored == null ? null : SyncCipher(base64Decode(stored));
    }

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secretStoreProvider.overrideWithValue(secrets),
        accountControllerProvider.overrideWith(account ?? _Account.new),
        galleryStorageProvider.overrideWithValue(TempGalleryStorage(dir)),
        // The real derivation, with fewer rounds.
        syncKeyMakerProvider.overrideWithValue(
          (secret, salt) =>
              SyncCipher.deriveKey(secret, salt, iterations: 1000),
        ),
        syncServiceProvider.overrideWith(
          (ref) => SyncService(db, remote, cipher: cipher),
        ),
        // As the app builds it: nothing until there is a key.
        fileSyncProvider.overrideWith((ref) async {
          final key = await cipher();
          return key == null ? null : FileSync(db, files, key);
        }),
      ],
    );
    addTearDown(container.dispose);
    return (db: db, container: container, dir: dir);
  }

  Future<String> logExpense(HarvestDatabase db) async {
    await FinancesRepository(db).log(
      amountMinor: 1250,
      category: 'food',
      note: 'bread',
      day: HarvestDay.today(),
    );
    return (await db.select(db.expenses).getSingle()).uuid;
  }

  Future<void> picture(HarvestDatabase db, Directory dir) async {
    await db
        .into(db.albums)
        .insertOnConflictUpdate(
          AlbumsCompanion.insert(uuid: 'album', name: 'Garden'),
        );
    await db
        .into(db.memories)
        .insertOnConflictUpdate(
          MemoriesCompanion.insert(
            uuid: 'm1',
            albumUuid: 'album',
            harvestDay: '2026-09-20',
            path: 'm1.jpg',
            fileHash: const Value(null),
          ),
        );
    await File(
      '${dir.path}/m1.jpg',
    ).writeAsBytes(List<int>.generate(4096, (i) => i % 251));
  }

  test('money and pictures wait for the PIN, and go up sealed the moment '
      'it is set', () async {
    final a = await phone();
    final uuid = await logExpense(a.db);
    await picture(a.db, a.dir);
    final sync = a.container.read(syncControllerProvider.notifier);

    await sync.syncNow();
    expect(remote.row('expenses', uuid), isNull);
    expect(files.held, isEmpty);
    expect(a.container.read(syncControllerProvider).last!.heldBack, 1);

    await a.container.read(syncPassphraseProvider.notifier).set('2468');
    await sync.syncNow();

    final stored = remote.row('expenses', uuid)!;
    expect(stored.containsKey('data'), isFalse);
    expect(stored['enc'], isA<Map<String, Object?>>());
    expect('${stored['enc']}', isNot(contains('bread')));
    expect(files.held, hasLength(1), reason: 'the picture went up');
  });

  test('a sync asks whether the account was verified since', () async {
    late _Unverified account;
    final a = await phone(account: () => account = _Unverified());
    final uuid = await logExpense(a.db);
    await a.container.read(syncPassphraseProvider.notifier).set('2468');

    await a.container.read(syncControllerProvider.notifier).syncNow();

    expect(account.asked, 1);
    expect(remote.row('expenses', uuid)?['enc'], isNotNull);
  });

  test('a PIN set while a sync runs still reaches the server', () async {
    final a = await phone();
    final uuid = await logExpense(a.db);
    final sync = a.container.read(syncControllerProvider.notifier);

    final running = sync.syncNow();
    await a.container.read(syncPassphraseProvider.notifier).set('2468');
    await sync.syncNow();
    await running;

    expect(remote.row('expenses', uuid)?['enc'], isNotNull);
  });

  test('a later device enters it once, and a wrong one is forgotten', () async {
    final a = await phone();
    await logExpense(a.db);
    await a.container.read(syncPassphraseProvider.notifier).set('2468');
    await a.container.read(syncControllerProvider.notifier).syncNow();

    final b = await phone();
    final sync = b.container.read(syncControllerProvider.notifier);
    final sealed = b.container.listen(syncSealedSeenProvider, (_, _) {});
    await sync.syncNow();
    await pumpEventQueue();
    // The server holds sealed rows: this device enters, not chooses.
    expect(sealed.read().value, isTrue);
    expect(await b.db.select(b.db.expenses).get(), isEmpty);

    final pin = b.container.read(syncPassphraseProvider.notifier);
    await pin.set('1357');
    await sync.syncNow();
    expect(await b.container.read(syncPassphraseProvider.future), isFalse);
    expect(b.container.read(syncControllerProvider).error, 'passphrase');

    await pin.set('2468');
    await sync.syncNow();
    expect(await b.container.read(syncPassphraseProvider.future), isTrue);
    final row = await b.db.select(b.db.expenses).getSingle();
    expect(row.note, 'bread');
  });
}
