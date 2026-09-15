// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sleep_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sleepRepository)
final sleepRepositoryProvider = SleepRepositoryProvider._();

final class SleepRepositoryProvider
    extends
        $FunctionalProvider<SleepRepository, SleepRepository, SleepRepository>
    with $Provider<SleepRepository> {
  SleepRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sleepRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sleepRepositoryHash();

  @$internal
  @override
  $ProviderElement<SleepRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SleepRepository create(Ref ref) {
    return sleepRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SleepRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SleepRepository>(value),
    );
  }
}

String _$sleepRepositoryHash() => r'67105bef3959f3c0848640e4fb3170de407cbbc1';
