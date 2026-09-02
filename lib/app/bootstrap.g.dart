// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bootstrap.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Startup work: the lazy, idempotent day reconciliation that backs up
/// the 3 AM background job (business rule #1).

@ProviderFor(appBootstrap)
final appBootstrapProvider = AppBootstrapProvider._();

/// Startup work: the lazy, idempotent day reconciliation that backs up
/// the 3 AM background job (business rule #1).

final class AppBootstrapProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Startup work: the lazy, idempotent day reconciliation that backs up
  /// the 3 AM background job (business rule #1).
  AppBootstrapProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appBootstrapProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appBootstrapHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return appBootstrap(ref);
  }
}

String _$appBootstrapHash() => r'd8c3a73ce0a4996f539e6152b9338d263d6bee60';
