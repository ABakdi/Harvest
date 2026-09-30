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

/// The server every request goes to: the built-in one, always.

@ProviderFor(serverAddress)
final serverAddressProvider = ServerAddressProvider._();

/// The server every request goes to: the built-in one, always.

final class ServerAddressProvider extends $FunctionalProvider<Uri, Uri, Uri>
    with $Provider<Uri> {
  /// The server every request goes to: the built-in one, always.
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
  $ProviderElement<Uri> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Uri create(Ref ref) {
    return serverAddress(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Uri value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Uri>(value),
    );
  }
}

String _$serverAddressHash() => r'c86e583895fb42f2a2ae9d1a745323fea8663112';

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

String _$apiClientHash() => r'91984f2d6f1850a20c13947e96c69e882a60a5cf';

@ProviderFor(syncKeyRemote)
final syncKeyRemoteProvider = SyncKeyRemoteProvider._();

final class SyncKeyRemoteProvider
    extends $FunctionalProvider<SyncKeyRemote, SyncKeyRemote, SyncKeyRemote>
    with $Provider<SyncKeyRemote> {
  SyncKeyRemoteProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncKeyRemoteProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncKeyRemoteHash();

  @$internal
  @override
  $ProviderElement<SyncKeyRemote> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SyncKeyRemote create(Ref ref) {
    return syncKeyRemote(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncKeyRemote value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncKeyRemote>(value),
    );
  }
}

String _$syncKeyRemoteHash() => r'5084e1f1ce5c40e5ab3f735827e3de3039e9f17b';

/// What the server says about the account's key right now: whether a
/// PIN is to be chosen or entered is its answer, never a guess from what
/// this phone happens to have pulled ([[Accounts]]).

@ProviderFor(syncKeyState)
final syncKeyStateProvider = SyncKeyStateProvider._();

/// What the server says about the account's key right now: whether a
/// PIN is to be chosen or entered is its answer, never a guess from what
/// this phone happens to have pulled ([[Accounts]]).

final class SyncKeyStateProvider
    extends
        $FunctionalProvider<
          AsyncValue<SyncKeyState>,
          SyncKeyState,
          FutureOr<SyncKeyState>
        >
    with $FutureModifier<SyncKeyState>, $FutureProvider<SyncKeyState> {
  /// What the server says about the account's key right now: whether a
  /// PIN is to be chosen or entered is its answer, never a guess from what
  /// this phone happens to have pulled ([[Accounts]]).
  SyncKeyStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncKeyStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncKeyStateHash();

  @$internal
  @override
  $FutureProviderElement<SyncKeyState> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SyncKeyState> create(Ref ref) {
    return syncKeyState(ref);
  }
}

String _$syncKeyStateHash() => r'e35bdec689a00ce9b94a8c3e3a7ebf5bee144d6d';

/// Files sync only once a sync PIN is set: like every row, a picture
/// goes up sealed or not at all ([[Sync-API]]).

@ProviderFor(fileSync)
final fileSyncProvider = FileSyncProvider._();

/// Files sync only once a sync PIN is set: like every row, a picture
/// goes up sealed or not at all ([[Sync-API]]).

final class FileSyncProvider
    extends
        $FunctionalProvider<
          AsyncValue<FileSync?>,
          FileSync?,
          FutureOr<FileSync?>
        >
    with $FutureModifier<FileSync?>, $FutureProvider<FileSync?> {
  /// Files sync only once a sync PIN is set: like every row, a picture
  /// goes up sealed or not at all ([[Sync-API]]).
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

String _$fileSyncHash() => r'423518cd8c9e91bc442f13ac3116bec1ba038335';

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

String _$syncServiceHash() => r'098c974ea3a6b866f69a0470474290b7eb392107';

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

/// The sync PIN, or passphrase ([[Accounts]] AC7): set once, never sent.
/// Only the key derived from it is kept, in the keystore, with its epoch;
/// the secret itself is gone the moment the key exists.

@ProviderFor(SyncPassphrase)
final syncPassphraseProvider = SyncPassphraseProvider._();

/// The sync PIN, or passphrase ([[Accounts]] AC7): set once, never sent.
/// Only the key derived from it is kept, in the keystore, with its epoch;
/// the secret itself is gone the moment the key exists.
final class SyncPassphraseProvider
    extends $AsyncNotifierProvider<SyncPassphrase, bool> {
  /// The sync PIN, or passphrase ([[Accounts]] AC7): set once, never sent.
  /// Only the key derived from it is kept, in the keystore, with its epoch;
  /// the secret itself is gone the moment the key exists.
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

String _$syncPassphraseHash() => r'377de52eb087d55a2e3e006ad08dd38b7d25054d';

/// The sync PIN, or passphrase ([[Accounts]] AC7): set once, never sent.
/// Only the key derived from it is kept, in the keystore, with its epoch;
/// the secret itself is gone the moment the key exists.

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

String _$accountControllerHash() => r'b3f6249ee6dbaeb0d9b694f03c2c91274eede564';

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
