// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_finisher.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sessionFinisher)
final sessionFinisherProvider = SessionFinisherProvider._();

final class SessionFinisherProvider
    extends
        $FunctionalProvider<SessionFinisher, SessionFinisher, SessionFinisher>
    with $Provider<SessionFinisher> {
  SessionFinisherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionFinisherProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionFinisherHash();

  @$internal
  @override
  $ProviderElement<SessionFinisher> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SessionFinisher create(Ref ref) {
    return sessionFinisher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionFinisher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionFinisher>(value),
    );
  }
}

String _$sessionFinisherHash() => r'b273d5b7faf1a175221d2e9b1a1602dd65b54823';
