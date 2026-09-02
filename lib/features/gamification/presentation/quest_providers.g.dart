// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quest_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(questRows)
final questRowsProvider = QuestRowsProvider._();

final class QuestRowsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<QuestState>>,
          List<QuestState>,
          Stream<List<QuestState>>
        >
    with $FutureModifier<List<QuestState>>, $StreamProvider<List<QuestState>> {
  QuestRowsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'questRowsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$questRowsHash();

  @$internal
  @override
  $StreamProviderElement<List<QuestState>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<QuestState>> create(Ref ref) {
    return questRows(ref);
  }
}

String _$questRowsHash() => r'081f12fc20d36cc16994549c4ebad331f3cf940f';

@ProviderFor(todayQuests)
final todayQuestsProvider = TodayQuestsProvider._();

final class TodayQuestsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<QuestView>>,
          List<QuestView>,
          FutureOr<List<QuestView>>
        >
    with $FutureModifier<List<QuestView>>, $FutureProvider<List<QuestView>> {
  TodayQuestsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'todayQuestsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$todayQuestsHash();

  @$internal
  @override
  $FutureProviderElement<List<QuestView>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<QuestView>> create(Ref ref) {
    return todayQuests(ref);
  }
}

String _$todayQuestsHash() => r'19cc890480f6a960dd245bb3d223c321280cd93e';
