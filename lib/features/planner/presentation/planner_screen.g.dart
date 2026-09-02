// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'planner_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Commitments relevant to tomorrow: habits due, and planned to-dos.

@ProviderFor(tomorrowPlan)
final tomorrowPlanProvider = TomorrowPlanProvider._();

/// Commitments relevant to tomorrow: habits due, and planned to-dos.

final class TomorrowPlanProvider
    extends
        $FunctionalProvider<
          ({List<Commitment> habits, List<Commitment> todos}),
          ({List<Commitment> habits, List<Commitment> todos}),
          ({List<Commitment> habits, List<Commitment> todos})
        >
    with $Provider<({List<Commitment> habits, List<Commitment> todos})> {
  /// Commitments relevant to tomorrow: habits due, and planned to-dos.
  TomorrowPlanProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tomorrowPlanProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tomorrowPlanHash();

  @$internal
  @override
  $ProviderElement<({List<Commitment> habits, List<Commitment> todos})>
  $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  ({List<Commitment> habits, List<Commitment> todos}) create(Ref ref) {
    return tomorrowPlan(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(
    ({List<Commitment> habits, List<Commitment> todos}) value,
  ) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<
            ({List<Commitment> habits, List<Commitment> todos})
          >(value),
    );
  }
}

String _$tomorrowPlanHash() => r'8ab6a9a4fc0444c127fa59d192c9e96f41afacfe';
