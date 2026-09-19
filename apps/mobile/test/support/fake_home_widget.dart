import 'package:harvest/features/widget/data/home_widget_gateway.dart';

/// The home screen, faked: it keeps what was written instead of asking
/// Android to redraw, so the widget's numbers can be asserted without a
/// launcher.
class FakeHomeWidgetGateway implements HomeWidgetGateway {
  final Map<String, Object> data = <String, Object>{};
  int refreshes = 0;

  @override
  Future<void> put(String key, Object value) async => data[key] = value;

  @override
  Future<void> refresh() async => refreshes++;
}
