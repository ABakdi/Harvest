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

String _$appBootstrapHash() => r'4b13fed3a85a644cdb4f3b054287d1c1f672e401';
