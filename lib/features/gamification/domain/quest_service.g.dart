// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quest_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(questService)
final questServiceProvider = QuestServiceProvider._();

final class QuestServiceProvider
    extends $FunctionalProvider<QuestService, QuestService, QuestService>
    with $Provider<QuestService> {
  QuestServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'questServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$questServiceHash();

  @$internal
  @override
  $ProviderElement<QuestService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  QuestService create(Ref ref) {
    return questService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(QuestService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<QuestService>(value),
    );
  }
}

String _$questServiceHash() => r'88895b17720b31251468a758ad1d3082a2ca4a62';
