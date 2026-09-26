// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(tokenStore)
final tokenStoreProvider = TokenStoreProvider._();

final class TokenStoreProvider
    extends $FunctionalProvider<TokenStore, TokenStore, TokenStore>
    with $Provider<TokenStore> {
  TokenStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tokenStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tokenStoreHash();

  @$internal
  @override
  $ProviderElement<TokenStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TokenStore create(Ref ref) {
    return tokenStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TokenStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TokenStore>(value),
    );
  }
}

String _$tokenStoreHash() => r'14e198bdbd97ac84b018a8e32a5e894f2564e61a';

@ProviderFor(serverAddress)
final serverAddressProvider = ServerAddressProvider._();

final class ServerAddressProvider
    extends $FunctionalProvider<ServerAddress, ServerAddress, ServerAddress>
    with $Provider<ServerAddress> {
  ServerAddressProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serverAddressProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serverAddressHash();

  @$internal
  @override
  $ProviderElement<ServerAddress> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ServerAddress create(Ref ref) {
    return serverAddress(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ServerAddress value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ServerAddress>(value),
    );
  }
}

String _$serverAddressHash() => r'b19ae076ee68f3772d88d7d26efb845f609911ec';

@ProviderFor(apiClient)
final apiClientProvider = ApiClientProvider._();

final class ApiClientProvider
    extends $FunctionalProvider<ApiClient, ApiClient, ApiClient>
    with $Provider<ApiClient> {
  ApiClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'apiClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$apiClientHash();

  @$internal
  @override
  $ProviderElement<ApiClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ApiClient create(Ref ref) {
    return apiClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ApiClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ApiClient>(value),
    );
  }
}

String _$apiClientHash() => r'8e9a9bac28b70238ea27c5cd5cd9bb587d67bd76';

/// Files sync only once a passphrase is set: a picture is as personal
/// as an expense, and goes up sealed or not at all ([[Sync-API]]).

@ProviderFor(fileSync)
final fileSyncProvider = FileSyncProvider._();

/// Files sync only once a passphrase is set: a picture is as personal
/// as an expense, and goes up sealed or not at all ([[Sync-API]]).

final class FileSyncProvider
    extends
        $FunctionalProvider<
          AsyncValue<FileSync?>,
          FileSync?,
          FutureOr<FileSync?>
        >
    with $FutureModifier<FileSync?>, $FutureProvider<FileSync?> {
  /// Files sync only once a passphrase is set: a picture is as personal
  /// as an expense, and goes up sealed or not at all ([[Sync-API]]).
  FileSyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fileSyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fileSyncHash();

  @$internal
  @override
  $FutureProviderElement<FileSync?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<FileSync?> create(Ref ref) {
    return fileSync(ref);
  }
}

String _$fileSyncHash() => r'ab269243c6e3c1e829ccd837df197dba12cca8f3';

@ProviderFor(syncService)
final syncServiceProvider = SyncServiceProvider._();

final class SyncServiceProvider
    extends $FunctionalProvider<SyncService, SyncService, SyncService>
    with $Provider<SyncService> {
  SyncServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncServiceHash();

  @$internal
  @override
  $ProviderElement<SyncService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SyncService create(Ref ref) {
    return syncService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncService>(value),
    );
  }
}

String _$syncServiceHash() => r'2833ec746be5951149015c8bd6a862d7fbcfadd7';

@ProviderFor(syncKeyMaker)
final syncKeyMakerProvider = SyncKeyMakerProvider._();

final class SyncKeyMakerProvider
    extends $FunctionalProvider<SyncKeyMaker, SyncKeyMaker, SyncKeyMaker>
    with $Provider<SyncKeyMaker> {
  SyncKeyMakerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncKeyMakerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncKeyMakerHash();

  @$internal
  @override
  $ProviderElement<SyncKeyMaker> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SyncKeyMaker create(Ref ref) {
    return syncKeyMaker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncKeyMaker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncKeyMaker>(value),
    );
  }
}

String _$syncKeyMakerHash() => r'a28d3377fabac6a67a94579ff1def4dfc998ef87';

/// Whether another device has sealed rows on the server: what decides
/// between *choosing* a sync PIN and *entering* one ([[Accounts]]).

@ProviderFor(syncSealedSeen)
final syncSealedSeenProvider = SyncSealedSeenProvider._();

/// Whether another device has sealed rows on the server: what decides
/// between *choosing* a sync PIN and *entering* one ([[Accounts]]).

final class SyncSealedSeenProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// Whether another device has sealed rows on the server: what decides
  /// between *choosing* a sync PIN and *entering* one ([[Accounts]]).
  SyncSealedSeenProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncSealedSeenProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncSealedSeenHash();

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    return syncSealedSeen(ref);
  }
}

String _$syncSealedSeenHash() => r'697b951c3d96b42c918082e1b3c44698df638eab';

/// The sync PIN, or passphrase ([[Accounts]] AC7): set once, never sent.
/// Only the key derived from it is kept, in the keystore; the secret
/// itself is gone the moment the key exists.

@ProviderFor(SyncPassphrase)
final syncPassphraseProvider = SyncPassphraseProvider._();

/// The sync PIN, or passphrase ([[Accounts]] AC7): set once, never sent.
/// Only the key derived from it is kept, in the keystore; the secret
/// itself is gone the moment the key exists.
final class SyncPassphraseProvider
    extends $AsyncNotifierProvider<SyncPassphrase, bool> {
  /// The sync PIN, or passphrase ([[Accounts]] AC7): set once, never sent.
  /// Only the key derived from it is kept, in the keystore; the secret
  /// itself is gone the moment the key exists.
  SyncPassphraseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncPassphraseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncPassphraseHash();

  @$internal
  @override
  SyncPassphrase create() => SyncPassphrase();
}

String _$syncPassphraseHash() => r'640458f993057f2513fe9f6c18ae0480274f1998';

/// The sync PIN, or passphrase ([[Accounts]] AC7): set once, never sent.
/// Only the key derived from it is kept, in the keystore; the secret
/// itself is gone the moment the key exists.

abstract class _$SyncPassphrase extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Signing in, out and away ([[Accounts]]). An account is optional
/// forever (AC1): nothing here runs until I ask for it.

@ProviderFor(AccountController)
final accountControllerProvider = AccountControllerProvider._();

/// Signing in, out and away ([[Accounts]]). An account is optional
/// forever (AC1): nothing here runs until I ask for it.
final class AccountControllerProvider
    extends $AsyncNotifierProvider<AccountController, AccountState> {
  /// Signing in, out and away ([[Accounts]]). An account is optional
  /// forever (AC1): nothing here runs until I ask for it.
  AccountControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountControllerHash();

  @$internal
  @override
  AccountController create() => AccountController();
}

String _$accountControllerHash() => r'5cd945401bdce73372b79c60abf8b6cb199ec0d3';

/// Signing in, out and away ([[Accounts]]). An account is optional
/// forever (AC1): nothing here runs until I ask for it.

abstract class _$AccountController extends $AsyncNotifier<AccountState> {
  FutureOr<AccountState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<AccountState>, AccountState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AccountState>, AccountState>,
              AsyncValue<AccountState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
