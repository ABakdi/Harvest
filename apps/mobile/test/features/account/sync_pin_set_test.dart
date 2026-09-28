import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/platform/secret_store.dart';
import 'package:harvest/features/account/data/api_client.dart'
    show ApiException, Me;
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/finances/data/finances_repository.dart';
import 'package:harvest/features/gallery/data/gallery_storage.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/features/sync/domain/file_sync.dart';
import 'package:harvest/features/sync/domain/row_codec.dart' show privateTables;
import 'package:harvest/features/sync/domain/sync_cipher.dart';
import 'package:harvest/features/sync/domain/sync_service.dart';
import 'package:harvest/features/sync/presentation/sync_controller.dart';

import '../../support/fake_remote.dart';
import '../../support/temp_gallery_storage.dart';

class _Secrets implements SecretStore {
  final _values = <String, String>{};

  /// Set to make every read fail, as a Keystore that will not answer.
  bool failing = false;

  @override
  Future<String?> read(String key) async =>
      failing ? throw PlatformException(code: 'keystore') : _values[key];

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
  Future<void> upload(
    String sha256,
    Uint8List sealed,
    String iv, {
    required int keyEpoch,
  }) async => held[sha256] = (sealed: sealed, iv: iv);

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

/// Renamed on the server since this phone signed in: the phone learns
/// it once a run, not only at the next sign-in.
class _Renamed extends AccountController {
  int asked = 0;
  String? name = 'the old name';

  AccountState get _state => AccountState(
    serverUrl: 'https://harvest.example.com',
    me: Me(
      id: 'u1',
      email: 'maya@example.com',
      syncSalt: 'the-account-salt',
      verifiedAt: DateTime.utc(2026, 9, 2),
      displayName: name,
    ),
  );

  @override
  Future<AccountState> build() async => _state;

  @override
  Future<void> refreshMe() async {
    asked++;
    name = null;
    state = AsyncData(_state);
  }
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
  late FakeSyncKeys keys;
  late _Files files;
  late List<HarvestDatabase> dbs;
  late List<Directory> dirs;

  setUp(() {
    remote = FakeRemote();
    keys = FakeSyncKeys();
    remote.epoch = () => keys.epoch;
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
  phone({AccountController Function()? account, _Secrets? store}) async {
    final db = HarvestDatabase.forTesting(NativeDatabase.memory());
    final dir = await Directory.systemTemp.createTemp('harvest-pin');
    dbs.add(db);
    dirs.add(dir);
    final secrets = store ?? _Secrets();
    Future<SyncCipher?> cipher() => storedCipher(secrets);

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secretStoreProvider.overrideWithValue(secrets),
        accountControllerProvider.overrideWith(account ?? _Account.new),
        galleryStorageProvider.overrideWithValue(TempGalleryStorage(dir)),
        syncKeyRemoteProvider.overrideWithValue(keys),
        // The real derivation, with fewer rounds.
        syncKeyMakerProvider.overrideWithValue(
          (secret, salt) =>
              SyncCipher.deriveBase(secret, salt, iterations: 1000),
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

  test('a Keystore failing during the key check ends the run, and it is '
      'not left showing as syncing (Q6-11)', () async {
    final secrets = _Secrets();
    final a = await phone(store: secrets);
    await logExpense(a.db);
    secrets.failing = true;
    final sync = a.container.read(syncControllerProvider.notifier);
    await sync.syncNow();
    final state = a.container.read(syncControllerProvider);
    expect(state.running, isFalse);
    expect(state.error, 'internal');
  });

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

  test('a sync reads the account once a run, so a name changed on the '
      'server reaches the phone', () async {
    late _Renamed account;
    final a = await phone(account: () => account = _Renamed());
    final sync = a.container.read(syncControllerProvider.notifier);
    await sync.syncNow();
    await sync.syncNow();
    expect(account.asked, 1);
    final me = (await a.container.read(accountControllerProvider.future)).me;
    expect(me!.displayName, isNull);
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

  test(
    'the first device stores the verifier and the key check before it '
    'seals anything',
    () async {
      final a = await phone();
      expect(keys.check, isNull);
      await a.container.read(syncPassphraseProvider.notifier).set('2468');
      expect(keys.check, isNotNull);
      expect(keys.check!['v'], 2);
      expect(keys.verifier, matches(RegExp(r'^[0-9a-f]{64}$')));
      // Neither says anything of the PIN to the server.
      expect('${keys.check}${keys.verifier}', isNot(contains('2468')));
    },
  );

  test('the key share leaves the server only for the right PIN, and the '
      'tries are limited (S6-04)', () async {
    final a = await phone();
    await a.container.read(syncPassphraseProvider.notifier).set('2468');
    final b = await phone();
    final pin = b.container.read(syncPassphraseProvider.notifier);
    // Nothing the server hands out before a right proof opens anything.
    expect((await keys.fetch()).keyShare, isNull);
    for (var left = 4; left >= 0; left--) {
      await expectLater(
        pin.set('1357'),
        throwsA(isA<SyncPinRefused>().having((r) => r.triesLeft, 'left', left)),
      );
    }
    await expectLater(pin.set('2468'), throwsA(isA<SyncPinLimited>()));
    expect(await b.container.read(syncPassphraseProvider.future), isFalse);
    keys.wrong = 0;
    await pin.set('2468');
    expect(await b.container.read(syncPassphraseProvider.future), isTrue);
  });

  test('a later device enters it once, and a wrong one is refused on the '
      'spot', () async {
    final a = await phone();
    await logExpense(a.db);
    await a.container.read(syncPassphraseProvider.notifier).set('2468');
    await a.container.read(syncControllerProvider.notifier).syncNow();

    final b = await phone();
    final sync = b.container.read(syncControllerProvider.notifier);
    // The server has a check: this device enters, not chooses — decided
    // before any pull (Q5-55).
    final share = await b.container.read(syncKeyStateProvider.future);
    expect(share.choosing, isFalse);

    final pin = b.container.read(syncPassphraseProvider.notifier);
    await expectLater(pin.set('1357'), throwsA(isA<SyncPinRefused>()));
    expect(await b.container.read(syncPassphraseProvider.future), isFalse);
    await SettingsRepository(b.db).setString('themeMode', 'dark');
    await sync.syncNow();
    expect(await b.db.select(b.db.expenses).get(), isEmpty);
    expect(
      remote.row('kv_settings', 'themeMode'),
      isNotNull,
      reason: 'the plain tier syncs meanwhile',
    );

    await pin.set('2468');
    await sync.syncNow();
    expect(await b.container.read(syncPassphraseProvider.future), isTrue);
    final row = await b.db.select(b.db.expenses).getSingle();
    expect(row.note, 'bread');
  });

  test('two devices choosing at once: the second is checked against the '
      "first's", () async {
    final a = await phone();
    await a.container.read(syncPassphraseProvider.notifier).set('2468');
    final first = keys.check!;

    // B opened its sheet before A chose, so it offers to choose; A's
    // PIN is there by the time B's arrives.
    keys
      ..raced = (verifier: keys.verifier!, check: first)
      ..verifier = null
      ..check = null;
    final b = await phone();
    await expectLater(
      b.container.read(syncPassphraseProvider.notifier).set('9173'),
      throwsA(
        isA<SyncPinRefused>().having(
          (r) => r.chosenElsewhere,
          'chosen elsewhere',
          isTrue,
        ),
      ),
    );
    expect(await b.container.read(syncPassphraseProvider.future), isFalse);
    expect(keys.check, first);

    await b.container.read(syncPassphraseProvider.notifier).set('2468');
    expect(await b.container.read(syncPassphraseProvider.future), isTrue);
  });

  test('a row that will not open is locked, and never costs the key', () async {
    final a = await phone();
    await a.container.read(syncPassphraseProvider.notifier).set('2468');
    await logExpense(a.db);
    // A row no key of this account sealed: 3.0.0's, or one the server
    // made up.
    await remote.push('elsewhere', [
      {
        'table': 'expenses',
        'uuid': 'forged',
        'updatedAt': '2026-09-20T10:00:00.000Z',
        'deletedAt': null,
        'enc': {
          'v': 1,
          'iv': 'AAAAAAAAAAAAAAAA',
          'ct': 'AAAAAAAAAAAAAAAAAAAAAA==',
        },
      },
    ], keyEpoch: 1);
    await a.container.read(syncControllerProvider.notifier).syncNow();

    final status = a.container.read(syncControllerProvider);
    expect(status.error, isNull);
    expect(status.last!.locked, 1);
    expect(await a.container.read(syncPassphraseProvider.future), isTrue);
    expect(
      remote.row(
        'expenses',
        (await a.db.select(a.db.expenses).getSingle()).uuid,
      )?['enc'],
      isNotNull,
    );
  });

  test('a key kept under an older name is let go, and the PIN is asked '
      'again', () async {
    final a = await phone();
    final secrets = a.container.read(secretStoreProvider);
    for (final name in SyncPassphrase.legacyKeyNames) {
      await secrets.write(name, 'b2xk');
    }
    expect(await a.container.read(syncPassphraseProvider.future), isFalse);
    for (final name in SyncPassphrase.legacyKeyNames) {
      expect(await secrets.read(name), isNull);
    }
  });

  test('a sealed push refused for a stale key epoch forgets the key and '
      'asks again, and nothing is stored under it (S6-07)', () async {
    final a = await phone();
    await a.container.read(syncPassphraseProvider.notifier).set('2468');
    // Started over elsewhere, between this phone's check and its push.
    final uuid = await logExpense(a.db);
    final sync = a.container.read(syncControllerProvider.notifier);
    await sync.syncNow();
    remote.epoch = () => keys.epoch + 1;
    await FinancesRepository(a.db).log(
      amountMinor: 300,
      category: 'tea',
      day: HarvestDay.today(),
    );
    final service = a.container.read(syncServiceProvider);
    await expectLater(service.run(), throwsA(isA<SyncKeyChanged>()));
    expect(remote.row('expenses', uuid), isNotNull);
    final waiting = await a.db.select(a.db.outbox).get();
    expect(waiting.where((o) => o.targetTable == 'expenses'), isNotEmpty);
  });

  test('starting over asks for the password, drops what the server kept, '
      'and everything here goes up again under the new PIN', () async {
    keys.onStartOver = () {
      remote.dropTables(privateTables);
      files.held.clear();
    };
    final a = await phone();
    final uuid = await logExpense(a.db);
    await picture(a.db, a.dir);
    final pin = a.container.read(syncPassphraseProvider.notifier);
    final sync = a.container.read(syncControllerProvider.notifier);
    await pin.set('2468');
    await sync.syncNow();
    expect(files.held, hasLength(1));

    await expectLater(
      pin.startOver('not it'),
      throwsA(isA<ApiException>()),
    );
    expect(await a.container.read(syncPassphraseProvider.future), isTrue);

    await pin.startOver('the password');
    expect(await a.container.read(syncPassphraseProvider.future), isFalse);
    expect(remote.row('expenses', uuid), isNull);
    expect(files.held, isEmpty);
    expect(
      (await a.container.read(syncKeyStateProvider.future)).choosing,
      isTrue,
    );

    await pin.set('9731');
    await sync.syncNow();
    expect(remote.row('expenses', uuid)?['enc'], isNotNull);
    expect(files.held, hasLength(1), reason: 'the picture went up again');
  });

  test('a PIN started over on another device is asked for again here, and '
      "this phone's own rows go up under it", () async {
    keys.onStartOver = () => remote.dropTables(privateTables);
    final a = await phone();
    final b = await phone();
    await a.container.read(syncPassphraseProvider.notifier).set('2468');
    await b.container.read(syncPassphraseProvider.notifier).set('2468');
    final mine = await logExpense(b.db);
    final syncB = b.container.read(syncControllerProvider.notifier);
    await syncB.syncNow();
    expect(remote.row('expenses', mine), isNotNull);

    final pinA = a.container.read(syncPassphraseProvider.notifier);
    await pinA.startOver('the password');
    await pinA.set('9731');
    await a.container.read(syncControllerProvider.notifier).syncNow();
    expect(remote.row('expenses', mine), isNull);

    // B's next sync, with money of its own to send, meets rows sealed
    // under the new key, finds its own no longer fits, and says so.
    // What it sent meanwhile under the old one goes again under the new.
    await logExpense(a.db);
    await a.container.read(syncControllerProvider.notifier).syncNow();
    final later = await FinancesRepository(b.db).log(
      amountMinor: 300,
      category: 'tea',
      day: HarvestDay.today(),
    );
    await syncB.syncNow();
    expect(await b.container.read(syncPassphraseProvider.future), isFalse);
    expect(
      b.container.read(syncControllerProvider).error,
      SyncController.pinChanged,
    );

    await b.container.read(syncPassphraseProvider.notifier).set('9731');
    await syncB.syncNow();
    expect(remote.row('expenses', mine)?['enc'], isNotNull);
    expect(remote.row('expenses', later)?['enc'], isNotNull);
    await a.container.read(syncControllerProvider.notifier).syncNow();
    expect(
      (await a.db.select(a.db.expenses).get()).map((e) => e.uuid),
      containsAll([mine, later]),
    );
  });
}
