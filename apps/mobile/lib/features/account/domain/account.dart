import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/platform/secret_store.dart';
import 'package:harvest/features/account/data/api_client.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
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

@Riverpod(keepAlive: true)
ApiClient apiClient(Ref ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  var base = Uri.parse(defaultServerUrl);
  // The URL is read on every call, so a change in Settings needs no
  // restart: the listener keeps a copy fresh.
  unawaited(
    settings.getString(AccountKeys.serverUrl).then((value) {
      if (value != null && value.isNotEmpty) base = Uri.parse(value);
    }),
  );
  final subscription = settings.watchAll([AccountKeys.serverUrl]).listen((
    values,
  ) {
    final value = values[AccountKeys.serverUrl];
    base = Uri.parse(value == null || value.isEmpty ? defaultServerUrl : value);
  });
  ref.onDispose(subscription.cancel);
  return ApiClient(
    baseUrl: () => base,
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

@Riverpod(keepAlive: true)
SyncService syncService(Ref ref) => SyncService(
  ref.watch(databaseProvider),
  ApiRemote(ref.watch(apiClientProvider)),
  cipher: () async {
    final stored = await ref
        .read(secretStoreProvider)
        .read(SyncPassphrase.keyName);
    return stored == null ? null : SyncCipher(base64Decode(stored));
  },
);

/// The sync passphrase ([[Accounts]]): set once, never sent. Only the key
/// derived from it is kept, in the keystore; the passphrase itself is
/// gone the moment the key exists.
@Riverpod(keepAlive: true)
class SyncPassphrase extends _$SyncPassphrase {
  static const keyName = 'sync.privateKey';

  @override
  Future<bool> build() async =>
      await ref.read(secretStoreProvider).read(keyName) != null;

  /// Derives the key (seconds of work, off the UI thread) and opens the
  /// private tier: the history is pulled again so the rows that waited
  /// for it can be read.
  Future<void> set(String passphrase) async {
    final me = (await ref.read(accountControllerProvider.future)).me;
    if (me == null) return;
    final key = await compute(
      _derive,
      (passphrase: passphrase, salt: me.syncSalt),
    );
    await ref.read(secretStoreProvider).write(keyName, base64Encode(key));
    await ref.read(syncServiceProvider).privateTierOpened();
    state = const AsyncData(true);
  }

  /// Forgets the key on this device; money and places stay home again.
  Future<void> forget() async {
    await ref.read(secretStoreProvider).write(keyName, null);
    state = const AsyncData(false);
  }
}

Future<Uint8List> _derive(({String passphrase, String salt}) input) =>
    SyncCipher.deriveKey(input.passphrase, input.salt);

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
