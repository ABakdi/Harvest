import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'widget_actions.g.dart';

/// The quick actions a widget button can ask for.
///
/// They travel as a `harvest://` URI on the launch intent, which is the
/// only channel a home-screen button has into a Flutter app.
enum WidgetAction {
  logExpense('expense'),
  plantSeed('task');

  const WidgetAction(this.host);

  final String host;

  static WidgetAction? fromUri(Uri? uri) {
    if (uri == null || uri.scheme != scheme) return null;
    return WidgetAction.values
        .where((action) => action.host == uri.host)
        .firstOrNull;
  }

  static const scheme = 'harvest';

  Uri get uri => Uri.parse('$scheme://$host');
}

/// The action a widget button asked for, waiting to be carried out.
///
/// The shell watches this and opens the sheet, because a home-screen
/// button cannot open a bottom sheet by itself: it can only start the
/// activity with a URI attached, and something inside the navigator has
/// to notice.
@Riverpod(keepAlive: true)
class PendingWidgetAction extends _$PendingWidgetAction {
  StreamSubscription<Uri?>? _clicks;

  @override
  WidgetAction? build() {
    ref.onDispose(() => _clicks?.cancel());
    return null;
  }

  /// The action waiting to be carried out.
  WidgetAction? get pending => state;

  set pending(WidgetAction? action) => state = action;

  /// Consumes the pending action; null when there is nothing to do.
  WidgetAction? take() {
    final action = state;
    if (action != null) state = null;
    return action;
  }

  /// Starts listening for widget taps, and picks up the one that
  /// launched the app if there was one.
  ///
  /// Android only, and checked here rather than in the caller: the
  /// event channel reaches for the services binding the moment it is
  /// listened to, which off a device is an error no `catch` in this
  /// method is positioned to see.
  Future<void> listen() async {
    if (!Platform.isAndroid) return;
    try {
      _clicks ??= HomeWidget.widgetClicked.listen(
        (uri) => pending = WidgetAction.fromUri(uri),
        onError: _log,
        cancelOnError: true,
      );
      final launch = await HomeWidget.initiallyLaunchedFromHomeWidget();
      final action = WidgetAction.fromUri(launch);
      if (action != null) pending = action;
    } on Object catch (error) {
      _log(error);
    }
  }

  void _log(Object error) =>
      debugPrint('[widget] launch actions unavailable: ${error.runtimeType}');
}
