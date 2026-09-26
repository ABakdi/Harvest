// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'goals_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every goal, board order.

@ProviderFor(goals)
final goalsProvider = GoalsProvider._();

/// Every goal, board order.

final class GoalsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<GoalView>>,
          List<GoalView>,
          Stream<List<GoalView>>
        >
    with $FutureModifier<List<GoalView>>, $StreamProvider<List<GoalView>> {
  /// Every goal, board order.
  GoalsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'goalsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$goalsHash();

  @$internal
  @override
  $StreamProviderElement<List<GoalView>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<GoalView>> create(Ref ref) {
    return goals(ref);
  }
}

String _$goalsHash() => r'ac21ffeb5bf10f6e43a98a8c6b59818b2ea0dec4';

/// One goal, live; null once deleted.

@ProviderFor(goal)
final goalProvider = GoalFamily._();

/// One goal, live; null once deleted.

final class GoalProvider
    extends
        $FunctionalProvider<AsyncValue<GoalView?>, GoalView?, Stream<GoalView?>>
    with $FutureModifier<GoalView?>, $StreamProvider<GoalView?> {
  /// One goal, live; null once deleted.
  GoalProvider._({
    required GoalFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'goalProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$goalHash();

  @override
  String toString() {
    return r'goalProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<GoalView?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<GoalView?> create(Ref ref) {
    final argument = this.argument as String;
    return goal(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GoalProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$goalHash() => r'0e37a02270b8da0621280374bfbfe498cc57f7a7';

/// One goal, live; null once deleted.

final class GoalFamily extends $Family
    with $FunctionalFamilyOverride<Stream<GoalView?>, String> {
  GoalFamily._()
    : super(
        retry: null,
        name: r'goalProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One goal, live; null once deleted.

  GoalProvider call(String uuid) => GoalProvider._(argument: uuid, from: this);

  @override
  String toString() => r'goalProvider';
}

/// The seeds a goal's card and screen show under Seeds.

@ProviderFor(goalSeeds)
final goalSeedsProvider = GoalSeedsFamily._();

/// The seeds a goal's card and screen show under Seeds.

final class GoalSeedsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Commitment>>,
          List<Commitment>,
          Stream<List<Commitment>>
        >
    with $FutureModifier<List<Commitment>>, $StreamProvider<List<Commitment>> {
  /// The seeds a goal's card and screen show under Seeds.
  GoalSeedsProvider._({
    required GoalSeedsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'goalSeedsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$goalSeedsHash();

  @override
  String toString() {
    return r'goalSeedsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Commitment>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Commitment>> create(Ref ref) {
    final argument = this.argument as String;
    return goalSeeds(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GoalSeedsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$goalSeedsHash() => r'c59092c9aaa3e1b95f0a0719cd4cdfa6f808f19f';

/// The seeds a goal's card and screen show under Seeds.

final class GoalSeedsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Commitment>>, String> {
  GoalSeedsFamily._()
    : super(
        retry: null,
        name: r'goalSeedsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The seeds a goal's card and screen show under Seeds.

  GoalSeedsProvider call(String goalUuid) =>
      GoalSeedsProvider._(argument: goalUuid, from: this);

  @override
  String toString() => r'goalSeedsProvider';
}
