import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/gym/presentation/rest_timer.dart';

/// The rest has to outlive the screen: it is put down between sets,
/// which is exactly when the phone goes in a pocket ([[Audit-v2]]
/// P3-01).
class _Alerts implements RestAlerts {
  final List<DateTime> shown = <DateTime>[];
  int cleared = 0;

  @override
  Future<void> show(DateTime until) async => shown.add(until);

  @override
  Future<void> clear() async => cleared++;
}

void main() {
  test('starting shows the rest outside the app, stopping takes it back', () {
    final alerts = _Alerts();
    final rest = RestTimerController(alerts: alerts);

    // The asserts between the calls are the point of the test, and a
    // cascade would hide them.
    // ignore: cascade_invocations
    rest.start(90);
    expect(alerts.shown, hasLength(1));
    expect(
      alerts.shown.single.difference(DateTime.now()).inSeconds,
      closeTo(90, 2),
    );
    expect(alerts.cleared, isZero);

    // Another minute moves the end, and what the shade says with it.
    rest.extend(60);
    expect(alerts.shown, hasLength(2));
    expect(
      alerts.shown.last.difference(alerts.shown.first).inSeconds,
      closeTo(60, 1),
    );

    rest
      ..stop()
      ..dispose();
    expect(alerts.cleared, greaterThanOrEqualTo(1));
  });

  test('a rest that never started shows nothing', () {
    final alerts = _Alerts();
    RestTimerController(alerts: alerts)
      ..start(0)
      ..dispose();
    expect(alerts.shown, isEmpty);
  });
}
