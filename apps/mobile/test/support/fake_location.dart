import 'package:harvest/features/places/data/location_gateway.dart';
import 'package:harvest/features/places/data/trail_service.dart';
import 'package:harvest/features/places/domain/place.dart';

/// A phone whose location says whatever the test tells it to.
class FakeLocationGateway implements LocationGateway {
  FakeLocationGateway({this.granted = LocationAccess.whileInUse, this.fix});

  LocationAccess granted;

  /// What the next "where am I?" answers; null is a timeout.
  Fix? fix;

  /// What asking for "all the time" ends up as.
  LocationAccess alwaysAnswer = LocationAccess.always;

  int fixRequests = 0;

  @override
  Future<LocationAccess> access() async => granted;

  @override
  Future<LocationAccess> requestWhileInUse() async {
    if (granted == LocationAccess.none) granted = LocationAccess.whileInUse;
    return granted;
  }

  @override
  Future<LocationAccess> requestAlways() async => granted = alwaysAnswer;

  @override
  Future<Fix?> currentFix({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    fixRequests++;
    return fix;
  }

  @override
  Future<void> openSettings() async {}
}

class FakeTrailService implements TrailService {
  bool running = false;
  int starts = 0;

  @override
  Future<bool> isRunning() async => running;

  @override
  Future<bool> start({required String title, required String text}) async {
    if (!running) starts++;
    return running = true;
  }

  @override
  Future<void> stop() async => running = false;
}
