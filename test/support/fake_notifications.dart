import 'package:harvest/core/platform/notifications.dart';

/// One scheduled reminder as the planner asked for it.
typedef ScheduledReminder = ({
  int id,
  String channelId,
  String title,
  String body,
  DateTime when,
  String? route,
  bool alarm,
});

/// Records what the planner schedules and cancels instead of talking to
/// the OS, so planner tests can assert exact (id, when, channel) tuples.
class FakeNotificationGateway implements NotificationGateway {
  final Map<int, ScheduledReminder> scheduled = {};
  final List<int> cancelled = [];

  @override
  List<(String, String)> snoozeLabels = const [];

  @override
  Map<String, String> channelNames = const {};

  @override
  Future<void> schedule({
    required int id,
    required String channelId,
    required String title,
    required String body,
    required DateTime when,
    String? route,
    bool alarm = true,
    List<(String, String)>? snoozeLabels,
  }) async {
    scheduled[id] = (
      id: id,
      channelId: channelId,
      title: title,
      body: body,
      when: when,
      route: route,
      alarm: alarm,
    );
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
  }

  /// Ids currently pending, sorted.
  List<int> get ids => scheduled.keys.toList()..sort();
}
