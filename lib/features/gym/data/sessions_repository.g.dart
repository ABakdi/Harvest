// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sessions_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sessionsRepository)
final sessionsRepositoryProvider = SessionsRepositoryProvider._();

final class SessionsRepositoryProvider
    extends
        $FunctionalProvider<
          SessionsRepository,
          SessionsRepository,
          SessionsRepository
        >
    with $Provider<SessionsRepository> {
  SessionsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionsRepositoryHash();

  @$internal
  @override
  $ProviderElement<SessionsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SessionsRepository create(Ref ref) {
    return sessionsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionsRepository>(value),
    );
  }
}

String _$sessionsRepositoryHash() =>
    r'a639f49002184d63de477bde22b7dc8864c75df3';

/// The session that is still running, if any. The gym screen offers to
/// resume it and the field knows a workout is in progress.

@ProviderFor(runningSession)
final runningSessionProvider = RunningSessionProvider._();

/// The session that is still running, if any. The gym screen offers to
/// resume it and the field knows a workout is in progress.

final class RunningSessionProvider
    extends
        $FunctionalProvider<
          AsyncValue<WorkoutSession?>,
          WorkoutSession?,
          Stream<WorkoutSession?>
        >
    with $FutureModifier<WorkoutSession?>, $StreamProvider<WorkoutSession?> {
  /// The session that is still running, if any. The gym screen offers to
  /// resume it and the field knows a workout is in progress.
  RunningSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'runningSessionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$runningSessionHash();

  @$internal
  @override
  $StreamProviderElement<WorkoutSession?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<WorkoutSession?> create(Ref ref) {
    return runningSession(ref);
  }
}

String _$runningSessionHash() => r'068e87a628457f4cf4abc8ef432e693aaa4d1404';

@ProviderFor(session)
final sessionProvider = SessionFamily._();

final class SessionProvider
    extends
        $FunctionalProvider<
          AsyncValue<WorkoutSession?>,
          WorkoutSession?,
          Stream<WorkoutSession?>
        >
    with $FutureModifier<WorkoutSession?>, $StreamProvider<WorkoutSession?> {
  SessionProvider._({
    required SessionFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'sessionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sessionHash();

  @override
  String toString() {
    return r'sessionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<WorkoutSession?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<WorkoutSession?> create(Ref ref) {
    final argument = this.argument as String;
    return session(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SessionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sessionHash() => r'53750e5e60f36ceef24dee93beeaac5d3b2f4a5a';

final class SessionFamily extends $Family
    with $FunctionalFamilyOverride<Stream<WorkoutSession?>, String> {
  SessionFamily._()
    : super(
        retry: null,
        name: r'sessionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SessionProvider call(String uuid) =>
      SessionProvider._(argument: uuid, from: this);

  @override
  String toString() => r'sessionProvider';
}

@ProviderFor(finishedSessions)
final finishedSessionsProvider = FinishedSessionsProvider._();

final class FinishedSessionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<WorkoutSession>>,
          List<WorkoutSession>,
          Stream<List<WorkoutSession>>
        >
    with
        $FutureModifier<List<WorkoutSession>>,
        $StreamProvider<List<WorkoutSession>> {
  FinishedSessionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'finishedSessionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$finishedSessionsHash();

  @$internal
  @override
  $StreamProviderElement<List<WorkoutSession>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<WorkoutSession>> create(Ref ref) {
    return finishedSessions(ref);
  }
}

String _$finishedSessionsHash() => r'702972bdc2e5d2589f60f0c55b647d3b94ff7b75';

@ProviderFor(exerciseRecords)
final exerciseRecordsProvider = ExerciseRecordsFamily._();

final class ExerciseRecordsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ExerciseRecords>,
          ExerciseRecords,
          FutureOr<ExerciseRecords>
        >
    with $FutureModifier<ExerciseRecords>, $FutureProvider<ExerciseRecords> {
  ExerciseRecordsProvider._({
    required ExerciseRecordsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'exerciseRecordsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$exerciseRecordsHash();

  @override
  String toString() {
    return r'exerciseRecordsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ExerciseRecords> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ExerciseRecords> create(Ref ref) {
    final argument = this.argument as String;
    return exerciseRecords(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ExerciseRecordsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$exerciseRecordsHash() => r'9f0d2b8d0b4f11f00c2b8d9ea91851e775aacd93';

final class ExerciseRecordsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ExerciseRecords>, String> {
  ExerciseRecordsFamily._()
    : super(
        retry: null,
        name: r'exerciseRecordsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ExerciseRecordsProvider call(String exerciseId) =>
      ExerciseRecordsProvider._(argument: exerciseId, from: this);

  @override
  String toString() => r'exerciseRecordsProvider';
}

@ProviderFor(lastTime)
final lastTimeProvider = LastTimeFamily._();

final class LastTimeProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<WorkoutSet>>,
          List<WorkoutSet>,
          FutureOr<List<WorkoutSet>>
        >
    with $FutureModifier<List<WorkoutSet>>, $FutureProvider<List<WorkoutSet>> {
  LastTimeProvider._({
    required LastTimeFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'lastTimeProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$lastTimeHash();

  @override
  String toString() {
    return r'lastTimeProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<WorkoutSet>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<WorkoutSet>> create(Ref ref) {
    final argument = this.argument as String;
    return lastTime(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LastTimeProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$lastTimeHash() => r'01f2fd44b53bae3f888590616c61ddde7086d65c';

final class LastTimeFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<WorkoutSet>>, String> {
  LastTimeFamily._()
    : super(
        retry: null,
        name: r'lastTimeProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  LastTimeProvider call(String exerciseId) =>
      LastTimeProvider._(argument: exerciseId, from: this);

  @override
  String toString() => r'lastTimeProvider';
}

@ProviderFor(exerciseHistory)
final exerciseHistoryProvider = ExerciseHistoryFamily._();

final class ExerciseHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ExerciseOuting>>,
          List<ExerciseOuting>,
          FutureOr<List<ExerciseOuting>>
        >
    with
        $FutureModifier<List<ExerciseOuting>>,
        $FutureProvider<List<ExerciseOuting>> {
  ExerciseHistoryProvider._({
    required ExerciseHistoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'exerciseHistoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$exerciseHistoryHash();

  @override
  String toString() {
    return r'exerciseHistoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<ExerciseOuting>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ExerciseOuting>> create(Ref ref) {
    final argument = this.argument as String;
    return exerciseHistory(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ExerciseHistoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$exerciseHistoryHash() => r'e964321a2c594cd7b23e8364d22f9a42f2c68ba6';

final class ExerciseHistoryFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ExerciseOuting>>, String> {
  ExerciseHistoryFamily._()
    : super(
        retry: null,
        name: r'exerciseHistoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ExerciseHistoryProvider call(String exerciseId) =>
      ExerciseHistoryProvider._(argument: exerciseId, from: this);

  @override
  String toString() => r'exerciseHistoryProvider';
}
