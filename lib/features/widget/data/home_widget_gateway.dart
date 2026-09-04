import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'home_widget_gateway.g.dart';

/// The platform edge for the home-screen widget, behind an interface
/// like every other one in this app — so the numbers that reach the
/// widget can be asserted without a launcher.
abstract interface class HomeWidgetGateway {
  Future<void> put(String key, Object value);

  /// Redraws every placed instance of the widget.
  Future<void> refresh();
}

/// The real thing: `home_widget`'s shared-preferences store plus a
/// broadcast that makes Android redraw the widget.
class HomeWidgetBridge implements HomeWidgetGateway {
  static const _provider = 'HarvestWidgetProvider';

  @override
  Future<void> put(String key, Object value) async {
    try {
      await HomeWidget.saveWidgetData(key, value);
    } on PlatformException catch (error) {
      _log(error);
    } on MissingPluginException catch (error) {
      _log(error);
    }
  }

  @override
  Future<void> refresh() async {
    try {
      await HomeWidget.updateWidget(androidName: _provider);
    } on PlatformException catch (error) {
      _log(error);
    } on MissingPluginException catch (error) {
      _log(error);
    }
  }

  /// A widget nobody placed, or a platform that has none, is not an
  /// error worth failing a check-in over.
  void _log(Object error) =>
      debugPrint('[widget] update skipped: ${error.runtimeType}');
}

@Riverpod(keepAlive: true)
HomeWidgetGateway homeWidgetGateway(Ref ref) => HomeWidgetBridge();
