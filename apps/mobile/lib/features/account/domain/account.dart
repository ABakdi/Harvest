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

  /// Done once the saved address has been read, or one was set.
  final loaded = Completer<void>();

  void set(String? url) {
    value = Uri.parse(
      url == null || url.trim().isEmpty ? defaultServerUrl : url.trim(),
    );
    if (!loaded.isCompleted) loaded.complete();
  }
}

@Riverpod(keepAlive: true)
ServerAddress serverAddress(Ref ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  final address = ServerAddress();
  unawaited(
    settings
        .getString(AccountKeys.serverUrl)
        .then(
          address.set,
          // Unreadable: the default, rather than every request waiting.
          onError: (Object _) => address.set(null),
        ),
  );
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
    ready: () => address.loaded.future,
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
    List<Map<String, Object?>> records, {
    int? keyEpoch,
  }) async {
    final json = await _api.post('/v1/sync/push', {
      'deviceId': deviceId,
      'keyEpoch': ?keyEpoch,
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
    int limit, {
    String? deviceId,
  }) async {
    final json = await _api.get(
      '/v1/sync/pull',
      query: {'after': '$after', 'limit': '$limit', 'deviceId': ?deviceId},
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
  Future<void> upload(
    String sha256,
    Uint8List sealed,
    String iv, {
    required int keyEpoch,
  }) => _api.putBytes(
    '/v1/files/$sha256',
    sealed,
    headers: {
      fileIvHeader: iv,
      // AES-GCM adds a 16-byte tag and nothing else.
      filePlainBytesHeader: '${sealed.length - 16}',
      fileKeyEpochHeader: '$keyEpoch',
    },
  );

  /// Tells the server no row names this file any more, so it can stop
  /// keeping it (`DELETE /v1/files/:sha256`).
  /// A 409 says a row on the server still names it: it stays, and that
  /// is not a failure.
  Future<void> forget(String sha256) async {
    try {
      await _api.delete('/v1/files/$sha256');
    } on ApiException catch (error) {
      if (error.status != 409) rethrow;
    }
  }

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

/// The key epoch a file was sealed under; the server refuses a stale one
/// (409 `key_changed`) and stores nothing.
const fileKeyEpochHeader = 'x-harvest-key-epoch';

/// Where the account's sync key stands, as `GET /v1/me/sync-key`
/// answers ([[Sync-API]], `contracts/sync-key.ts`): its salt, its key
/// epoch, and whether a PIN is set. While none is, the key share comes
/// with it; once one is, the share is only handed over for the PIN's
/// proof.
@immutable
class SyncKeyState {
  const SyncKeyState({
    required this.salt,
    required this.epoch,
    this.keyShare,
  });

  factory SyncKeyState.fromJson(Map<String, Object?> json) => SyncKeyState(
    salt: json['salt']! as String,
    epoch: (json['epoch']! as num).toInt(),
    keyShare: json['state'] == 'none'
        ? base64Decode(json['keyShare']! as String)
        : null,
  );

  final String salt;

  /// Names the key: it moves on with every start over.
  final int epoch;

  /// Only while no PIN is set: the first device chooses with it.
  final Uint8List? keyShare;

  /// No device has chosen a PIN yet: this one *chooses*, typed twice.
  /// Otherwise it *enters* the one the others use ([[Accounts]]).
  bool get choosing => keyShare != null;
}

/// What a right PIN proof is handed: the key share, the key check and
/// the epoch.
typedef SyncUnlock = ({
  Uint8List keyShare,
  Map<String, Object?> check,
  int epoch,
});

/// The key routes, as the phone needs them.
abstract interface class SyncKeyRemote {
  Future<SyncKeyState> fetch();

  /// Shows the PIN proof (base64). Throws [SyncPinRefused] on a wrong
  /// one, [SyncPinLimited] past the limit on tries, and [SyncPinChosen]
  /// when no PIN is set any more (choose instead).
  Future<SyncUnlock> unlock(String proof);

  /// Sets the account's PIN: the verifier and the key check. The epoch
  /// when it was stored; null when another device set one first.
  Future<int?> setPin(String verifier, Map<String, Object?> check);

  /// Starts the PIN over (`DELETE /v1/me/sync-key`, with the account's
  /// password): the verifier, the check, the key share, every private
  /// row and every file on the server go, and the epoch moves on.
  Future<void> startOver(String password);
}

class ApiSyncKeys implements SyncKeyRemote {
  ApiSyncKeys(this._api);

  final ApiClient _api;

  @override
  Future<SyncKeyState> fetch() async =>
      SyncKeyState.fromJson(await _api.get('/v1/me/sync-key'));

  @override
  Future<SyncUnlock> unlock(String proof) async {
    final Map<String, Object?> json;
    try {
      json = await _api.post('/v1/me/sync-key/unlock', {'proof': proof});
    } on ApiException catch (error) {
      if (error.code == 'wrong_pin') {
        final left =
            error.body?['triesLeft'] ??
            (error.details is Map
                ? (error.details! as Map)['triesLeft']
                : null);
        throw SyncPinRefused(triesLeft: left is num ? left.toInt() : null);
      }
      if (error.status == 429) {
        throw SyncPinLimited(retryAfter: error.retryAfter);
      }
      if (error.status == 409) throw const SyncPinChosen();
      rethrow;
    }
    return (
      keyShare: base64Decode(json['keyShare']! as String),
      check: json['check']! as Map<String, Object?>,
      epoch: (json['epoch']! as num).toInt(),
    );
  }

  @override
  Future<int?> setPin(String verifier, Map<String, Object?> check) async {
    try {
      final json = await _api.put('/v1/me/sync-key', {
        'verifier': verifier,
        'check': check,
      });
      return (json['epoch']! as num).toInt();
    } on ApiException catch (error) {
      if (error.status == 409) return null;
      rethrow;
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
Future<SyncKeyState> syncKeyState(Ref ref) =>
    ref.watch(syncKeyRemoteProvider).fetch();

/// The key kept in the keystore, with the epoch it belongs to.
Future<SyncCipher?> storedCipher(SecretStore secrets) async {
  final stored = await secrets.read(SyncPassphrase.keyName);
  if (stored == null) return null;
  try {
    final json = jsonDecode(stored) as Map<String, Object?>;
    return SyncCipher(
      base64Decode(json['key']! as String),
      epoch: (json['epoch']! as num).toInt(),
    );
  } on Object {
    return null;
  }
}

/// Files sync only once a passphrase is set: a picture is as personal
/// as an expense, and goes up sealed or not at all ([[Sync-API]]).
@Riverpod(keepAlive: true)
Future<FileSync?> fileSync(Ref ref) async {
  final cipher = await storedCipher(ref.read(secretStoreProvider));
  if (cipher == null) return null;
  return FileSync(
    ref.watch(databaseProvider),
    ApiFiles(ref.watch(apiClientProvider)),
    cipher,
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
    cipher: () => storedCipher(ref.read(secretStoreProvider)),
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

/// Makes the secret's base (PBKDF2, the slow part) from the sync secret
/// and the account's salt. Its own provider so the tests can make one
/// without 600,000 rounds.
typedef SyncKeyMaker = Future<Uint8List> Function(String secret, String salt);

@Riverpod(keepAlive: true)
SyncKeyMaker syncKeyMaker(Ref ref) =>
    (secret, salt) => compute(_derive, (passphrase: secret, salt: salt));

/// A PIN the account's check refused: not the account's PIN. Nothing was
/// kept, and nothing was sealed with it.
class SyncPinRefused implements Exception {
  const SyncPinRefused({this.chosenElsewhere = false, this.triesLeft});

  /// Another device chose the account's PIN while this one was choosing.
  final bool chosenElsewhere;

  /// How many wrong tries the server still allows today, when it said.
  final int? triesLeft;
}

/// Too many wrong PINs: the server takes no more for a while.
class SyncPinLimited implements Exception {
  const SyncPinLimited({this.retryAfter});

  /// How long, when the server said.
  final Duration? retryAfter;
}

/// The PIN was started over meanwhile: none is set, so this device
/// chooses one.
class SyncPinChosen implements Exception {
  const SyncPinChosen();
}

/// The sync PIN, or passphrase ([[Accounts]] AC7): set once, never sent.
/// Only the key derived from it is kept, in the keystore, with its epoch;
/// the secret itself is gone the moment the key exists.
@Riverpod(keepAlive: true)
class SyncPassphrase extends _$SyncPassphrase {
  /// `{key, epoch}`; keys kept under the older names are not ones this
  /// version can use, and the PIN is asked for again.
  static const keyName = 'sync.privateKey.v3';
  static const legacyKeyNames = ['sync.privateKey', 'sync.privateKey.v2'];

  @override
  Future<bool> build() async {
    final secrets = ref.read(secretStoreProvider);
    for (final name in legacyKeyNames) {
      if (await secrets.read(name) != null) await secrets.write(name, null);
    }
    return await secrets.read(keyName) != null;
  }

  /// Proves the secret to the server and keeps the key it opens.
  ///
  /// Entering: the PIN's proof is shown (`unlock`) and the key share
  /// comes back only when it is the account's; a wrong one is refused
  /// by the server, with a limit on tries, and nothing is kept. Choosing
  /// (no PIN set yet): the verifier and the key check go up first; when
  /// another device set a PIN meanwhile, this secret is tried against
  /// theirs. Either way, the history is pulled again so the rows that
  /// waited can be read, and this phone's own go up sealed.
  Future<void> set(String secret) async {
    final me = (await ref.read(accountControllerProvider.future)).me;
    if (me == null) return;
    final remote = ref.read(syncKeyRemoteProvider);
    final current = await remote.fetch();
    final base = await ref.read(syncKeyMakerProvider)(secret, current.salt);
    final proof = await SyncCipher.proofOf(base);
    Uint8List? key;
    var epoch = current.epoch;
    final share = current.keyShare;
    if (share != null) {
      key = await SyncCipher.keyOf(base, share);
      final stored = await remote.setPin(
        await SyncCipher.verifierOf(proof),
        await SyncCipher(key).sealCheck(),
      );
      if (stored != null) {
        epoch = stored;
      } else {
        key = null;
      }
    }
    if (key == null) {
      final SyncUnlock opened;
      try {
        opened = await remote.unlock(base64Encode(proof));
      } on SyncPinRefused catch (refused) {
        ref.invalidate(syncKeyStateProvider);
        throw share != null
            ? SyncPinRefused(
                chosenElsewhere: true,
                triesLeft: refused.triesLeft,
              )
            : refused;
      }
      key = await SyncCipher.keyOf(base, opened.keyShare);
      // Belt and braces: the key must open the account's check too.
      if (!await SyncCipher(key).opensCheck(opened.check)) {
        throw const SyncPinRefused();
      }
      epoch = opened.epoch;
    }
    // A run already going started without the key; it ends first, or
    // it would put back the cursor the re-pull needs at zero.
    final service = ref.read(syncServiceProvider);
    await service.idle();
    await ref
        .read(secretStoreProvider)
        .write(keyName, jsonEncode({'key': base64Encode(key), 'epoch': epoch}));
    await service.privateTierOpened();
    ref
      ..invalidate(fileSyncProvider)
      ..invalidate(syncKeyStateProvider);
    state = const AsyncData(true);
  }

  /// Starts the PIN over, with the account's password: everything
  /// private on the server goes, the key here is forgotten, and the
  /// next PIN is *chosen*. What this phone holds goes up again under it
  /// ([[Accounts]]: start over).
  Future<void> startOver(String password) async {
    await ref.read(syncKeyRemoteProvider).startOver(password);
    await forget();
    ref.invalidate(syncKeyStateProvider);
  }

  /// Whether the key kept here is still the account's: the account's
  /// epoch, one small request, is the key's. When it is not — the PIN was
  /// started over on another device — the key is forgotten and false is
  /// the answer; the PIN is asked for again, and what this phone holds
  /// goes up again under the new one. Null when there was no key, or no
  /// answer from the server.
  Future<bool?> stillTheAccounts() async {
    final cipher = await storedCipher(ref.read(secretStoreProvider));
    if (cipher == null) return null;
    final SyncKeyState current;
    try {
      current = await ref.read(syncKeyRemoteProvider).fetch();
    } on ApiException {
      return null;
    }
    if (!current.choosing && current.epoch == cipher.epoch) return true;
    await keyChanged();
    return false;
  }

  /// The server refused a sealed write for a stale epoch, or the epoch
  /// moved on: the key is the old one, and goes.
  Future<void> keyChanged() async {
    await forget();
    ref.invalidate(syncKeyStateProvider);
  }

  /// Forgets the key on this device; the private tier stays home again.
  Future<void> forget() async {
    await ref.read(secretStoreProvider).write(keyName, null);
    ref.invalidate(fileSyncProvider);
    state = const AsyncData(false);
  }
}

Future<Uint8List> _derive(({String passphrase, String salt}) input) =>
    SyncCipher.deriveBase(input.passphrase, input.salt);

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
    final service = ref.read(syncServiceProvider);
    await service.reset();
    // Data made here before signing in is not sent into an account that
    // has its own until I say so (U6-05). A new account has nothing to
    // meet it: what is here simply goes up.
    final joining = path == '/v1/auth/login';
    if (joining && await service.hasLocalData()) {
      await service.holdForJoin(hold: true);
    }
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
