// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(database)
final databaseProvider = DatabaseProvider._();

final class DatabaseProvider
    extends
        $FunctionalProvider<HarvestDatabase, HarvestDatabase, HarvestDatabase>
    with $Provider<HarvestDatabase> {
  DatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'databaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$databaseHash();

  @$internal
  @override
  $ProviderElement<HarvestDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HarvestDatabase create(Ref ref) {
    return database(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HarvestDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HarvestDatabase>(value),
    );
  }
}

String _$databaseHash() => r'7f9a05767ed2ef7d5f09244cf985597e2a843d12';
