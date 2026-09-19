import 'package:harvest/core/domain/harvest_day.dart';
import 'package:meta/meta.dart';

/// What achieving a goal pays, once ([[Goals]] GL4).
const goalAchievedXp = 50;

enum GoalStatus { active, achieved, dropped }

/// A need is something to have or know; a step is something to do.
/// Both are ticked and both count; they are drawn apart because a list
/// that mixes "running shoes" with "run 10 km" reads as neither.
enum GoalItemKind { need, step }

/// Something I am working toward ([[Goals]]).
@immutable
class Goal {
  const Goal({
    required this.uuid,
    required this.title,
    required this.createdAt,
    this.why = '',
    this.targetDay,
    this.status = GoalStatus.active,
    this.statusNote,
    this.achievedAt,
    this.position = 0,
  });

  final String uuid;
  final String title;
  final String why;
  final HarvestDay? targetDay;
  final GoalStatus status;
  final String? statusNote;
  final DateTime? achievedAt;
  final int position;
  final DateTime createdAt;

  bool get isActive => status == GoalStatus.active;

  /// Days from [today] to the target; negative once it has passed.
  int? daysLeft(HarvestDay today) =>
      targetDay == null ? null : today.daysUntil(targetDay!);

  Goal copyWith({
    String? title,
    String? why,
    HarvestDay? targetDay,
    bool clearTargetDay = false,
  }) => Goal(
    uuid: uuid,
    title: title ?? this.title,
    why: why ?? this.why,
    targetDay: clearTargetDay ? null : targetDay ?? this.targetDay,
    status: status,
    statusNote: statusNote,
    achievedAt: achievedAt,
    position: position,
    createdAt: createdAt,
  );
}

/// One line of what a goal takes.
@immutable
class GoalItem {
  const GoalItem({
    required this.uuid,
    required this.goalUuid,
    required this.kind,
    required this.body,
    this.note,
    this.doneAt,
    this.position = 0,
    this.commitmentUuid,
  });

  final String uuid;
  final String goalUuid;
  final GoalItemKind kind;
  final String body;
  final String? note;
  final DateTime? doneAt;
  final int position;

  /// The seed this was planted as, if it was.
  final String? commitmentUuid;

  bool get isDone => doneAt != null;
  bool get isPlanted => commitmentUuid != null;
}

/// A goal with everything under it, as the board and the goal screen
/// read it.
@immutable
class GoalView {
  const GoalView({required this.goal, required this.items});

  final Goal goal;

  /// In board order: needs first, then steps, each by position.
  final List<GoalItem> items;

  Iterable<GoalItem> get needs =>
      items.where((item) => item.kind == GoalItemKind.need);
  Iterable<GoalItem> get steps =>
      items.where((item) => item.kind == GoalItemKind.step);

  /// Ticked over all, needs and steps alike (GL2). Null with nothing
  /// to count, so the board can say "add what it takes" rather than
  /// draw an empty ring.
  double? get progress => goalProgress(items);

  /// The first unticked step, or need if every step is done: the card's
  /// answer to "what now?".
  GoalItem? get next =>
      steps.where((item) => !item.isDone).firstOrNull ??
      needs.where((item) => !item.isDone).firstOrNull;

  bool get complete => items.isNotEmpty && items.every((item) => item.isDone);
}

/// Progress as the Goals spec, rule GL2, defines it.
double? goalProgress(Iterable<GoalItem> items) {
  final all = items.length;
  if (all == 0) return null;
  return items.where((item) => item.isDone).length / all;
}
