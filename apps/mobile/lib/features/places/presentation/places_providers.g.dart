// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'places_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Keeps the trail, the geotags and the filler in step with the
/// settings ([[Places]]).
///
/// Everything here is idempotent and cheap to call again: it runs at
/// startup, on every resume, and after every switch.

@ProviderFor(PlacesController)
final placesControllerProvider = PlacesControllerProvider._();

/// Keeps the trail, the geotags and the filler in step with the
/// settings ([[Places]]).
///
/// Everything here is idempotent and cheap to call again: it runs at
/// startup, on every resume, and after every switch.
final class PlacesControllerProvider
    extends $AsyncNotifierProvider<PlacesController, TrailState> {
  /// Keeps the trail, the geotags and the filler in step with the
  /// settings ([[Places]]).
  ///
  /// Everything here is idempotent and cheap to call again: it runs at
  /// startup, on every resume, and after every switch.
  PlacesControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'placesControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$placesControllerHash();

  @$internal
  @override
  PlacesController create() => PlacesController();
}

String _$placesControllerHash() => r'0fca22bfce10e6feb14df085148319bab7221d07';

/// Keeps the trail, the geotags and the filler in step with the
/// settings ([[Places]]).
///
/// Everything here is idempotent and cheap to call again: it runs at
/// startup, on every resume, and after every switch.

abstract class _$PlacesController extends $AsyncNotifier<TrailState> {
  FutureOr<TrailState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<TrailState>, TrailState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<TrailState>, TrailState>,
              AsyncValue<TrailState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(trail)
final trailProvider = TrailFamily._();

final class TrailProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TrailPoint>>,
          List<TrailPoint>,
          Stream<List<TrailPoint>>
        >
    with $FutureModifier<List<TrailPoint>>, $StreamProvider<List<TrailPoint>> {
  TrailProvider._({
    required TrailFamily super.from,
    required PlacesSpan super.argument,
  }) : super(
         retry: null,
         name: r'trailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$trailHash();

  @override
  String toString() {
    return r'trailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<TrailPoint>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<TrailPoint>> create(Ref ref) {
    final argument = this.argument as PlacesSpan;
    return trail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TrailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$trailHash() => r'6802d75816754eda231cb172399fbfe7f83fc73d';

final class TrailFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<TrailPoint>>, PlacesSpan> {
  TrailFamily._()
    : super(
        retry: null,
        name: r'trailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TrailProvider call(PlacesSpan span) =>
      TrailProvider._(argument: span, from: this);

  @override
  String toString() => r'trailProvider';
}

@ProviderFor(geotags)
final geotagsProvider = GeotagsFamily._();

final class GeotagsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Geotag>>,
          List<Geotag>,
          Stream<List<Geotag>>
        >
    with $FutureModifier<List<Geotag>>, $StreamProvider<List<Geotag>> {
  GeotagsProvider._({
    required GeotagsFamily super.from,
    required PlacesSpan super.argument,
  }) : super(
         retry: null,
         name: r'geotagsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$geotagsHash();

  @override
  String toString() {
    return r'geotagsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Geotag>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Geotag>> create(Ref ref) {
    final argument = this.argument as PlacesSpan;
    return geotags(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GeotagsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$geotagsHash() => r'f907e89b31b0effbe8a5192d51052b8f30126210';

final class GeotagsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Geotag>>, PlacesSpan> {
  GeotagsFamily._()
    : super(
        retry: null,
        name: r'geotagsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GeotagsProvider call(PlacesSpan span) =>
      GeotagsProvider._(argument: span, from: this);

  @override
  String toString() => r'geotagsProvider';
}

@ProviderFor(savedPlaces)
final savedPlacesProvider = SavedPlacesProvider._();

final class SavedPlacesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SavedPlace>>,
          List<SavedPlace>,
          Stream<List<SavedPlace>>
        >
    with $FutureModifier<List<SavedPlace>>, $StreamProvider<List<SavedPlace>> {
  SavedPlacesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savedPlacesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedPlacesHash();

  @$internal
  @override
  $StreamProviderElement<List<SavedPlace>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<SavedPlace>> create(Ref ref) {
    return savedPlaces(ref);
  }
}

String _$savedPlacesHash() => r'1e4729637c06a1eef99699b5734511d01eff8e39';

@ProviderFor(pointsOn)
final pointsOnProvider = PointsOnFamily._();

final class PointsOnProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  PointsOnProvider._({
    required PointsOnFamily super.from,
    required HarvestDay super.argument,
  }) : super(
         retry: null,
         name: r'pointsOnProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pointsOnHash();

  @override
  String toString() {
    return r'pointsOnProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    final argument = this.argument as HarvestDay;
    return pointsOn(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PointsOnProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pointsOnHash() => r'93107d0a2652a26b3853c79d0b8143356a76d464';

final class PointsOnFamily extends $Family
    with $FunctionalFamilyOverride<Stream<int>, HarvestDay> {
  PointsOnFamily._()
    : super(
        retry: null,
        name: r'pointsOnProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PointsOnProvider call(HarvestDay day) =>
      PointsOnProvider._(argument: day, from: this);

  @override
  String toString() => r'pointsOnProvider';
}

/// The map style ([[ADR-010-Maps]]).

@ProviderFor(placesStyleUrl)
final placesStyleUrlProvider = PlacesStyleUrlProvider._();

/// The map style ([[ADR-010-Maps]]).

final class PlacesStyleUrlProvider
    extends $FunctionalProvider<AsyncValue<String>, String, Stream<String>>
    with $FutureModifier<String>, $StreamProvider<String> {
  /// The map style ([[ADR-010-Maps]]).
  PlacesStyleUrlProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'placesStyleUrlProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$placesStyleUrlHash();

  @$internal
  @override
  $StreamProviderElement<String> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<String> create(Ref ref) {
    return placesStyleUrl(ref);
  }
}

String _$placesStyleUrlHash() => r'e90d5458d97395e0c4e3636c32b2e03cd2925a39';

@ProviderFor(placesHighAccuracy)
final placesHighAccuracyProvider = PlacesHighAccuracyProvider._();

final class PlacesHighAccuracyProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  PlacesHighAccuracyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'placesHighAccuracyProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$placesHighAccuracyHash();

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    return placesHighAccuracy(ref);
  }
}

String _$placesHighAccuracyHash() =>
    r'b0a0f05147e1e55530f94d8c1bf0cd04332d8830';

/// A few words on what a pin is: a note's title, an expense's amount.

@ProviderFor(geotagDetail)
final geotagDetailProvider = GeotagDetailFamily._();

/// A few words on what a pin is: a note's title, an expense's amount.

final class GeotagDetailProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// A few words on what a pin is: a note's title, an expense's amount.
  GeotagDetailProvider._({
    required GeotagDetailFamily super.from,
    required ({String table, String uuid}) super.argument,
  }) : super(
         retry: null,
         name: r'geotagDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$geotagDetailHash();

  @override
  String toString() {
    return r'geotagDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    final argument = this.argument as ({String table, String uuid});
    return geotagDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GeotagDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$geotagDetailHash() => r'55815cc0c19b9e0f881562b1b68e98581c34a58e';

/// A few words on what a pin is: a note's title, an expense's amount.

final class GeotagDetailFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<String?>,
          ({String table, String uuid})
        > {
  GeotagDetailFamily._()
    : super(
        retry: null,
        name: r'geotagDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A few words on what a pin is: a note's title, an expense's amount.

  GeotagDetailProvider call(({String table, String uuid}) target) =>
      GeotagDetailProvider._(argument: target, from: this);

  @override
  String toString() => r'geotagDetailProvider';
}
