import 'package:harvest/features/health/data/steps_source.dart';

/// A phone that counts steps however the test says it does.
class FakeStepsSource implements StepsSource {
  FakeStepsSource({
    this.backend = StepsBackend.healthConnect,
    this.granted = true,
    this.installable = false,
  });

  StepsBackend backend;
  bool granted;
  bool installable;

  /// Health Connect's answer per window, in order. Shorter than the
  /// windows asked for means zeros for the rest.
  List<int> perWindow = const [];

  /// The sensor's since-boot reading; null for a silent sensor.
  int? sinceBoot;

  /// What the next permission prompt will say.
  bool grantOnRequest = true;

  int permissionRequests = 0;
  List<StepsWindow>? lastWindows;

  @override
  Future<StepsStatus> status() async => StepsStatus(
    backend: backend,
    granted: backend == StepsBackend.sensor && granted,
    installable: installable,
  );

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return granted = grantOnRequest;
  }

  @override
  Future<StepsTotals> totals(List<StepsWindow> windows) async {
    lastWindows = windows;
    if (backend != StepsBackend.healthConnect || !granted) {
      return const StepsDenied();
    }
    return StepsCounted([
      for (var i = 0; i < windows.length; i++)
        if (i < perWindow.length) perWindow[i] else 0,
    ]);
  }

  @override
  Future<int?> counter() async =>
      backend == StepsBackend.sensor && granted ? sinceBoot : null;

  @override
  Future<void> openHealthConnect() async {}
}
