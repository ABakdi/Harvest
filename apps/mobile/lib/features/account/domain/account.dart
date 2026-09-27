import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/platform/secret_store.dart';
import 'package:harvest/features/account/data/api_client.dart';
import 'package:harvest/features/gallery/data/gallery_storage.dart';
import 'package:harvest/features/notes/data/note_attachments.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/features/sync/domain/file_sync.dart';
import 'package:harvest/features/sync/domain/sync_cipher.dart';
import 'package:harvest/features/sync/domain/sync_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'account.g.dart';

/// Account bookkeeping in `kv_settings`: none of it is a preference,
/// so none of it syncs or exports.
abstract final class AccountKeys {
  static const serverUrl = 'account.serverUrl';
  static const me = 'account.me';
}

/// Where the Harvest server is, unless Settings says otherwise.
/// Filled at build time for a release; empty in development.
const defaultServerUrl = String.fromEnvironment('HARVEST_API_URL');

@immutable
class AccountState {
  const AccountState({required this.serverUrl, this.me});

  final String serverUrl;

  /// Null when signed out.
  final Me? me;

  bool get signedIn => me != null;
}

@Riverpod(keepAlive: true)
TokenStore tokenStore(Ref ref) => TokenStore(ref.watch(secretStoreProvider));

/// The server address as the client uses it, held in memory so a
/// sign-in straight after typing a new one goes there and not to the
/// old one (the setting itself is only read back asynchronously).
class ServerAddress {
  Uri value = Uri.parse(defaultServerUrl);

  void set(String? url) => value = Uri.parse(
    url == null || url.trim().isEmpty ? defaultServerUrl : url.trim(),
  );
}

@Riverpod(keepAlive: true)
ServerAddress serverAddress(Ref ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  final address = ServerAddress();
  unawaited(settings.getString(AccountKeys.serverUrl).then(address.set));
  final subscription = settings
      .watchAll([AccountKeys.serverUrl])
      .listen((values) => address.set(values[AccountKeys.serverUrl]));
  ref.onDispose(subscription.cancel);
  return address;
}

@Riverpod(keepAlive: true)
ApiClient apiClient(Ref ref) {
  final address = ref.watch(serverAddressProvider);
  return ApiClient(
    baseUrl: () => address.value,
    tokens: ref.watch(tokenStoreProvider),
    onSignedOut: () => unawaited(
      ref.read(accountControllerProvider.notifier).forget(),
    ),
  );
}

/// The server as sync sees it ([[Sync-API]]).
class ApiRemote implements SyncRemote {
  ApiRemote(this._api);

  final ApiClient _api;

  @override
  Future<({List<Map<String, Object?>> results, int cursor})> push(
    String deviceId,
    List<Map<String, Object?>> records,
  ) async {
    final json = await _api.post('/v1/sync/push', {
      'deviceId': deviceId,
      'records': records,
    });
    return (
      results: [
        for (final item in json['results']! as List<Object?>)
          item! as Map<String, Object?>,
      ],
      cursor: (json['cursor']! as num).toInt(),
    );
  }

  @override
  Future<({List<Map<String, Object?>> records, int cursor, bool more})> pull(
    int after,
    int limit,
  ) async {
    final json = await _api.get(
      '/v1/sync/pull',
      query: {'after': '$after', 'limit': '$limit'},
    );
    return (
      records: [
        for (final item in json['records']! as List<Object?>)
          item! as Map<String, Object?>,
      ],
      cursor: (json['cursor']! as num).toInt(),
      more: json['more'] == true,
    );
  }
}

/// The file routes, over the same client ([[Sync-API]]).
class ApiFiles implements FileRemote {
  ApiFiles(this._api);

  final ApiClient _api;

  @override
  Future<List<String>> missing(List<String> hashes) async {
    final json = await _api.post('/v1/files/missing', {'hashes': hashes});
    return [
      for (final item in json['missing']! as List<Object?>) item! as String,
    ];
  }

  @override
  Future<void> upload(String sha256, Uint8List sealed, String iv) =>
      _api.putBytes(
        '/v1/files/$sha256',
        sealed,
        headers: {
          fileIvHeader: iv,
          // AES-GCM adds a 16-byte tag and nothing else.
          filePlainBytesHeader: '${sealed.length - 16}',
        },
      );

  /// Tells the server no row names this file any more, so it can stop
  /// keeping it (`DELETE /v1/files/:sha256`).
  Future<void> forget(String sha256) => _api.delete('/v1/files/$sha256');

  @override
  Future<({Uint8List sealed, String iv})> download(String sha256) async {
    final answer = await _api.getBytes('/v1/files/$sha256');
    final iv = answer.headers[fileIvHeader];
    if (iv == null) throw const ApiException('internal', 500, 'No nonce');
    return (sealed: answer.bytes, iv: iv);
  }
}

/// The header the nonce travels in, as the contract names it
/// (`packages/contracts/src/files.ts`).
const fileIvHeader = 'x-harvest-iv';

/// The plaintext's length, for the server's accounting only.
const filePlainBytesHeader = 'x-harvest-plain-bytes';

/// The account's half of the private tier's key, and its key check, as
/// `GET /v1/me/sync-key` answers ([[Sync-API]], `contracts/sync-key.ts`).
@immutable
class SyncKeyShare {
  const SyncKeyShare({
    required this.salt,
    required this.keyShare,
    this.check,
  });

  factory SyncKeyShare.fromJson(Map<String, Object?> json) => SyncKeyShare(
    salt: json['salt']! as String,
    keyShare: base64Decode(json['keyShare']! as String),
    check: json['check'] as Map<String, Object?>?,
  );

  final String salt;

  /// 32 bytes only a signed-in session is given: without them the salt
  /// and a copy of the server's data are not enough to try PINs.
  final Uint8List keyShare;

  /// The account's key check, or null while no device has chosen a PIN.
  final Map<String, Object?>? check;

  /// No device has chosen a PIN yet: this one *chooses*, typed twice.
  /// Otherwise it *enters* the one the others use ([[Accounts]]).
  bool get choosing => check == null;
}

/// The key routes, as the phone needs them.
abstract interface class SyncKeyRemote {
  Future<SyncKeyShare> fetch();

  /// Stores [check] as the account's: null when it was stored, or the
  /// check another device stored first.
  Future<Map<String, Object?>?> putCheck(Map<String, Object?> check);

  /// Starts the PIN over (`DELETE /v1/me/sync-key`, with the account's
  /// password): the key check, the key share, every private row and
  /// every file on the server go.
  Future<void> startOver(String password);
}

class ApiSyncKeys implements SyncKeyRemote {
  ApiSyncKeys(this._api);

  final ApiClient _api;

  @override
  Future<SyncKeyShare> fetch() async =>
      SyncKeyShare.fromJson(await _api.get('/v1/me/sync-key'));

  @override
  Future<Map<String, Object?>?> putCheck(Map<String, Object?> check) async {
    try {
      await _api.put('/v1/me/sync-key/check', {'check': check});
      return null;
    } on ApiException catch (error) {
      if (error.status != 409) rethrow;
      final stored = error.body?['check'];
      if (stored is Map<String, Object?>) return stored;
      // The first device's check, asked for again.
      final share = await fetch();
      return share.check ?? (throw error);
    }
  }

  @override
  Future<void> startOver(String password) =>
      _api.delete('/v1/me/sync-key', {'password': password});
}

@Riverpod(keepAlive: true)
SyncKeyRemote syncKeyRemote(Ref ref) =>
    ApiSyncKeys(ref.watch(apiClientProvider));

/// What the server says about the account's key right now: whether a
/// PIN is to be chosen or entered is its answer, never a guess from what
/// this phone happens to have pulled ([[Accounts]]).
@riverpod
Future<SyncKeyShare> syncKeyShare(Ref ref) =>
    ref.watch(syncKeyRemoteProvider).fetch();

/// Files sync only once a passphrase is set: a picture is as personal
/// as an expense, and goes up sealed or not at all ([[Sync-API]]).
@Riverpod(keepAlive: true)
Future<FileSync?> fileSync(Ref ref) async {
  final stored = await ref
      .read(secretStoreProvider)
      .read(SyncPassphrase.keyName);
  if (stored == null) return null;
  return FileSync(
    ref.watch(databaseProvider),
    ApiFiles(ref.watch(apiClientProvider)),
    SyncCipher(base64Decode(stored)),
  );
}

@Riverpod(keepAlive: true)
SyncService syncService(Ref ref) {
  final db = ref.watch(databaseProvider);
  final gallery = ref.watch(galleryStorageProvider);
  final attachments = ref.watch(attachmentStorageProvider);
  return SyncService(
    db,
    ApiRemote(ref.watch(apiClientProvider)),
    cipher: () async {
      final stored = await ref
          .read(secretStoreProvider)
          .read(SyncPassphrase.keyName);
      return stored == null ? null : SyncCipher(base64Decode(stored));
    },
    // A purge that came from another device frees the file too
    // ([[Sync-API]]: tombstones).
    onPurged: PurgedFiles(
      db,
      gallery: gallery.delete,
      attachments: attachments.delete,
      forget: ApiFiles(ref.watch(apiClientProvider)).forget,
    ).release,
  );
}

/// Makes the private tier's key from the sync secret, the account's
/// salt and its key share. Its own provider so the tests can make one
/// without 600,000 rounds.
typedef SyncKeyMaker = Future<Uint8List> Function(
  String secret,
  String salt,
  Uint8List keyShare,
);

@Riverpod(keepAlive: true)
SyncKeyMaker syncKeyMaker(Ref ref) =>
    (secret, salt, keyShare) => compute(
      _derive,
      (passphrase: secret, salt: salt, keyShare: keyShare),
    );

/// A PIN the server's key check refused: not the account's PIN. Nothing
/// was kept, and nothing was sealed with it.
class SyncPinRefused implements Exception {
  const SyncPinRefused({this.chosenElsewhere = false});

  /// Another device chose the account's PIN while this one was choosing.
  final bool chosenElsewhere;
}

/// The sync PIN, or passphrase ([[Accounts]] AC7): set once, never sent.
/// Only the key derived from it is kept, in the keystore; the secret
/// itself is gone the moment the key exists.
@Riverpod(keepAlive: true)
class SyncPassphrase extends _$SyncPassphrase {
  /// Version 2 keys only: a key 3.0.0 kept under the old name is not
  /// one this version can use, and the PIN is asked for again.
  static const keyName = 'sync.privateKey.v2';
  static const legacyKeyName = 'sync.privateKey';

  @override
  Future<bool> build() async {
    final secrets = ref.read(secretStoreProvider);
    if (await secrets.read(legacyKeyName) != null) {
      await secrets.write(legacyKeyName, null);
    }
    return await secrets.read(keyName) != null;
  }

  /// Checks the secret against the account's key check and, only when
  /// it is the account's, keeps the key and opens the private tier: the
  /// history is pulled again so the rows that waited for it can be read,
  /// and this phone's own go up sealed.
  ///
  /// The first device to choose a PIN stores the check; the key is kept
  /// only once the server has it, and when another device got there
  /// first, only if it opens theirs. Throws [SyncPinRefused] when it is
  /// not the account's PIN, with nothing kept ([[Accounts]]).
  Future<void> set(String secret) async {
    final me = (await ref.read(accountControllerProvider.future)).me;
    if (me == null) return;
    final remote = ref.read(syncKeyRemoteProvider);
    final share = await remote.fetch();
    final key = await ref.read(syncKeyMakerProvider)(
      secret,
      share.salt,
      share.keyShare,
    );
    final cipher = SyncCipher(key);
    final stored = share.check;
    if (stored != null) {
      if (!await cipher.opensCheck(stored)) throw const SyncPinRefused();
    } else {
      final first = await remote.putCheck(await cipher.sealCheck());
      if (first != null && !await cipher.opensCheck(first)) {
        ref.invalidate(syncKeyShareProvider);
        throw const SyncPinRefused(chosenElsewhere: true);
      }
    }
    // A run already going started without the key; it ends first, or
    // it would put back the cursor the re-pull needs at zero.
    final service = ref.read(syncServiceProvider);
    await service.idle();
    await ref.read(secretStoreProvider).write(keyName, base64Encode(key));
    await service.privateTierOpened();
    ref
      ..invalidate(fileSyncProvider)
      ..invalidate(syncKeyShareProvider);
    state = const AsyncData(true);
  }

  /// Starts the PIN over, with the account's password: everything
  /// private on the server goes, the key here is forgotten, and the
  /// next PIN is *chosen*. What this phone holds goes up again under it
  /// ([[Accounts]]: start over).
  Future<void> startOver(String password) async {
    await ref.read(syncKeyRemoteProvider).startOver(password);
    await forget();
    ref.invalidate(syncKeyShareProvider);
  }

  /// Whether the key kept here still opens the account's key check.
  /// When it does not — the PIN was started over on another device —
  /// the key is forgotten and false is the answer; the PIN is asked for
  /// again, and what this phone holds goes up again under the new one.
  /// Null when there was no key, or no answer from the server.
  Future<bool?> stillTheAccounts() async {
    final stored = await ref.read(secretStoreProvider).read(keyName);
    if (stored == null) return null;
    final SyncKeyShare share;
    try {
      share = await ref.read(syncKeyRemoteProvider).fetch();
    } on ApiException {
      return null;
    }
    final check = share.check;
    if (check != null &&
        await SyncCipher(base64Decode(stored)).opensCheck(check)) {
      return true;
    }
    await forget();
    ref.invalidate(syncKeyShareProvider);
    return false;
  }

  /// Forgets the key on this device; the private tier stays home again.
  Future<void> forget() async {
    await ref.read(secretStoreProvider).write(keyName, null);
    ref.invalidate(fileSyncProvider);
    state = const AsyncData(false);
  }
}

Future<Uint8List> _derive(
  ({String passphrase, String salt, Uint8List keyShare}) input,
) => SyncCipher.deriveKey(input.passphrase, input.salt, input.keyShare);

/// Signing in, out and away ([[Accounts]]). An account is optional
/// forever (AC1): nothing here runs until I ask for it.
@Riverpod(keepAlive: true)
class AccountController extends _$AccountController {
  @override
  Future<AccountState> build() async {
    final settings = ref.watch(settingsRepositoryProvider);
    final url = await settings.getString(AccountKeys.serverUrl);
    final cached = await settings.getString(AccountKeys.me);
    Me? me;
    if (cached != null &&
        await ref.read(tokenStoreProvider).refresh() != null) {
      try {
        me = Me.fromJson(jsonDecode(cached) as Map<String, Object?>);
      } on Object {
        me = null;
      }
    }
    return AccountState(
      serverUrl: url == null || url.isEmpty ? defaultServerUrl : url,
      me: me,
    );
  }

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> setServerUrl(String url) async {
    ref.read(serverAddressProvider).set(url);
    await ref
        .read(settingsRepositoryProvider)
        .setString(AccountKeys.serverUrl, url.trim());
    ref.invalidateSelf();
    await future;
  }

  Future<void> register({
    required String email,
    required String password,
    String? displayName,
  }) => _signIn('/v1/auth/register', {
    'email': email,
    'password': password,
    if (displayName != null && displayName.trim().isNotEmpty)
      'displayName': displayName.trim(),
  });

  Future<void> login({required String email, required String password}) =>
      _signIn('/v1/auth/login', {'email': email, 'password': password});

  Future<void> _signIn(String path, Map<String, Object?> body) async {
    final auth = await _api.postAnonymous(path, {
      ...body,
      'client': 'mobile',
      'deviceName': 'Harvest on Android',
    });
    await _api.adopt(auth);
    // Another account may have synced here before: start from nothing.
    await ref.read(syncServiceProvider).reset();
    await _remember(Me.fromJson(auth['user']! as Map<String, Object?>));
  }

  /// Re-reads the account, for the verification state.
  Future<void> refreshMe() async {
    final json = await _api.get('/v1/me');
    await _remember(Me.fromJson(json));
  }

  Future<void> resendVerification() async {
    final me = state.value?.me;
    if (me == null) return;
    await _api.postAnonymous('/v1/auth/resend-verification', {
      'email': me.email,
    });
  }

  Future<List<Map<String, Object?>>> sessions() async {
    final json = await _api.get('/v1/me/sessions');
    return [
      for (final item in json['sessions']! as List<Object?>)
        item! as Map<String, Object?>,
    ];
  }

  Future<void> endSession(String id) => _api.delete('/v1/me/sessions/$id');

  Future<void> logout() async {
    final token = await ref.read(tokenStoreProvider).refresh();
    try {
      await _api.postAnonymous('/v1/auth/logout', {'refreshToken': ?token});
    } on ApiException catch (error) {
      // Signed out here either way; the server forgets on its own.
      debugPrint('[account] logout not confirmed: ${error.code}');
    }
    await forget();
  }

  /// Deletes the account and everything on the server (AC6). Nothing on
  /// this phone is touched.
  Future<void> deleteAccount(String password) async {
    await _api.delete('/v1/me', {'password': password});
    await forget();
  }

  /// Drops the session locally: the tokens, the cached account, and
  /// sync's place in the server's history.
  Future<void> forget() async {
    await ref.read(tokenStoreProvider).clear();
    await ref.read(syncPassphraseProvider.notifier).forget();
    await ref.read(settingsRepositoryProvider).remove(AccountKeys.me);
    await ref.read(syncServiceProvider).reset();
    ref.invalidateSelf();
  }

  Future<void> _remember(Me me) async {
    await ref
        .read(settingsRepositoryProvider)
        .setString(AccountKeys.me, jsonEncode(me.toJson()));
    ref.invalidateSelf();
    await future;
  }
}
