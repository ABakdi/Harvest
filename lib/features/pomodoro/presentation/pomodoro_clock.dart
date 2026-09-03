import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pomodoro_clock.g.dart';

/// One shared second hand for every timer widget. Only widgets that
/// watch it rebuild, and they only watch it while a session runs.
@riverpod
Stream<DateTime> pomodoroClock(Ref ref) => Stream<DateTime>.periodic(
  const Duration(seconds: 1),
  (_) => DateTime.now(),
);
