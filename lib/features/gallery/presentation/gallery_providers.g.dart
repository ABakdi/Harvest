// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gallery_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(albums)
final albumsProvider = AlbumsProvider._();

final class AlbumsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Album>>,
          List<Album>,
          Stream<List<Album>>
        >
    with $FutureModifier<List<Album>>, $StreamProvider<List<Album>> {
  AlbumsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'albumsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$albumsHash();

  @$internal
  @override
  $StreamProviderElement<List<Album>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Album>> create(Ref ref) {
    return albums(ref);
  }
}

String _$albumsHash() => r'a3b2c1f3f2123a37f281d89dea30056fb628b2b7';

@ProviderFor(album)
final albumProvider = AlbumFamily._();

final class AlbumProvider
    extends $FunctionalProvider<AsyncValue<Album?>, Album?, Stream<Album?>>
    with $FutureModifier<Album?>, $StreamProvider<Album?> {
  AlbumProvider._({
    required AlbumFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'albumProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$albumHash();

  @override
  String toString() {
    return r'albumProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Album?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Album?> create(Ref ref) {
    final argument = this.argument as String;
    return album(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AlbumProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$albumHash() => r'3fc6cec82d6061fe1169d6cb54bf14cfc42764e7';

final class AlbumFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Album?>, String> {
  AlbumFamily._()
    : super(
        retry: null,
        name: r'albumProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AlbumProvider call(String uuid) =>
      AlbumProvider._(argument: uuid, from: this);

  @override
  String toString() => r'albumProvider';
}

@ProviderFor(albumMemories)
final albumMemoriesProvider = AlbumMemoriesFamily._();

final class AlbumMemoriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Memory>>,
          List<Memory>,
          Stream<List<Memory>>
        >
    with $FutureModifier<List<Memory>>, $StreamProvider<List<Memory>> {
  AlbumMemoriesProvider._({
    required AlbumMemoriesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'albumMemoriesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$albumMemoriesHash();

  @override
  String toString() {
    return r'albumMemoriesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Memory>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Memory>> create(Ref ref) {
    final argument = this.argument as String;
    return albumMemories(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AlbumMemoriesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$albumMemoriesHash() => r'7cfcab54e3fbf749f75c1e8f82c2e8c9e233baed';

final class AlbumMemoriesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Memory>>, String> {
  AlbumMemoriesFamily._()
    : super(
        retry: null,
        name: r'albumMemoriesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AlbumMemoriesProvider call(String uuid) =>
      AlbumMemoriesProvider._(argument: uuid, from: this);

  @override
  String toString() => r'albumMemoriesProvider';
}

@ProviderFor(albumSummaries)
final albumSummariesProvider = AlbumSummariesProvider._();

final class AlbumSummariesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AlbumSummary>>,
          List<AlbumSummary>,
          Stream<List<AlbumSummary>>
        >
    with
        $FutureModifier<List<AlbumSummary>>,
        $StreamProvider<List<AlbumSummary>> {
  AlbumSummariesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'albumSummariesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$albumSummariesHash();

  @$internal
  @override
  $StreamProviderElement<List<AlbumSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<AlbumSummary>> create(Ref ref) {
    return albumSummaries(ref);
  }
}

String _$albumSummariesHash() => r'cee530b2964147736d5057bebc6bf6fc218e15e6';

/// Memories added per album today — the field's version of "done".

@ProviderFor(albumCountsToday)
final albumCountsTodayProvider = AlbumCountsTodayProvider._();

/// Memories added per album today — the field's version of "done".

final class AlbumCountsTodayProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, int>>,
          Map<String, int>,
          Stream<Map<String, int>>
        >
    with $FutureModifier<Map<String, int>>, $StreamProvider<Map<String, int>> {
  /// Memories added per album today — the field's version of "done".
  AlbumCountsTodayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'albumCountsTodayProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$albumCountsTodayHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, int>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, int>> create(Ref ref) {
    return albumCountsToday(ref);
  }
}

String _$albumCountsTodayHash() => r'fdaa173a352bb34d1f02074fd4eb542e88217e81';

/// Distinct days per album this week, for times-per-week schedules.

@ProviderFor(albumDoneDaysThisWeek)
final albumDoneDaysThisWeekProvider = AlbumDoneDaysThisWeekProvider._();

/// Distinct days per album this week, for times-per-week schedules.

final class AlbumDoneDaysThisWeekProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, int>>,
          Map<String, int>,
          Stream<Map<String, int>>
        >
    with $FutureModifier<Map<String, int>>, $StreamProvider<Map<String, int>> {
  /// Distinct days per album this week, for times-per-week schedules.
  AlbumDoneDaysThisWeekProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'albumDoneDaysThisWeekProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$albumDoneDaysThisWeekHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, int>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, int>> create(Ref ref) {
    return albumDoneDaysThisWeek(ref);
  }
}

String _$albumDoneDaysThisWeekHash() =>
    r'0c560b09b64f3c93471187461fe8dc6f0f32b851';

/// The scheduled albums due today, with whether they have been fed.
///
/// This is what puts an album on the field: it is the album's answer to
/// `todayFieldProvider`, computed with the same rules.

@ProviderFor(albumsDueToday)
final albumsDueTodayProvider = AlbumsDueTodayProvider._();

/// The scheduled albums due today, with whether they have been fed.
///
/// This is what puts an album on the field: it is the album's answer to
/// `todayFieldProvider`, computed with the same rules.

final class AlbumsDueTodayProvider
    extends
        $FunctionalProvider<
          List<({Album album, bool done})>,
          List<({Album album, bool done})>,
          List<({Album album, bool done})>
        >
    with $Provider<List<({Album album, bool done})>> {
  /// The scheduled albums due today, with whether they have been fed.
  ///
  /// This is what puts an album on the field: it is the album's answer to
  /// `todayFieldProvider`, computed with the same rules.
  AlbumsDueTodayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'albumsDueTodayProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$albumsDueTodayHash();

  @$internal
  @override
  $ProviderElement<List<({Album album, bool done})>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<({Album album, bool done})> create(Ref ref) {
    return albumsDueToday(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<({Album album, bool done})> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<({Album album, bool done})>>(
        value,
      ),
    );
  }
}

String _$albumsDueTodayHash() => r'c978c2b25f936f972ef3be2dfa1edd2ae29f1046';
