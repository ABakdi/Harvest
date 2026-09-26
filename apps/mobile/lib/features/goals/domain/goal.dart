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
    this.parentUuid,
    this.createdAt,
  });

  final String uuid;
  final String goalUuid;

  /// A subtask's is its parent's: a subtask of a task is a task.
  final GoalItemKind kind;
  final String body;
  final String? note;
  final DateTime? doneAt;
  final int position;

  /// The seed this was planted as, if it was.
  final String? commitmentUuid;

  /// For a subtask, the item it belongs to (GL8).
  final String? parentUuid;

  /// Breaks a tie in position, as the database does.
  final DateTime? createdAt;

  /// The stored tick. A parent's own is drawn from its subtasks; read
  /// [GoalView.isDone] for what the screen shows.
  bool get isDone => doneAt != null;
  bool get isPlanted => commitmentUuid != null;
}

/// A goal with everything under it, as the board and the goal screen
/// read it.
@immutable
class GoalView {
  GoalView({required this.goal, required this.items})
    : outline = GoalOutline(items);

  final Goal goal;

  /// Every live item, subtasks included, in no promised order.
  final List<GoalItem> items;

  /// The same items as a tree.
  final GoalOutline outline;

  /// Top-level requirements and tasks, each by position.
  List<GoalItem> get needs => outline.top(GoalItemKind.need);
  List<GoalItem> get steps => outline.top(GoalItemKind.step);

  List<GoalItem> subtasksOf(String uuid) => outline.subtasksOf(uuid);
  bool isDone(GoalItem item) => outline.isDone(item);

  /// Ticked over all (GL2). Null with nothing to count, so the board
  /// can say "add what it takes" rather than draw an empty ring.
  double? get progress => goalTally(items)?.ratio;

  /// The card's answer to "what now?".
  GoalItem? get next => outline.next;

  bool get complete => goalTally(items)?.complete ?? false;
}

/// How far along a goal is: what is ticked, out of what counts.
typedef GoalTally = ({int done, int total});

extension GoalTallyRatio on GoalTally {
  double get ratio => done / total;
  bool get complete => done == total;
}

/// Progress as the Goals spec, rule GL2, defines it: ticked over all,
/// requirements and tasks alike, with a parent's subtasks counted in
/// its place — a task with three subtasks weighs three. Null with
/// nothing to count. [live] are the goal's items that are not deleted;
/// a subtask whose parent is not among them counts on its own.
///
/// So an item counts exactly when no live item is its subtask, and it
/// counts as its own tick.
GoalTally? goalTally(Iterable<GoalItem> live) {
  final parents = {
    for (final item in live)
      if (item.parentUuid != null) item.parentUuid!,
  };
  var done = 0;
  var total = 0;
  for (final item in live) {
    if (parents.contains(item.uuid)) continue;
    total++;
    if (item.isDone) done++;
  }
  return total == 0 ? null : (done: done, total: total);
}

/// Progress as a fraction, for the ring.
double? goalProgress(Iterable<GoalItem> live) => goalTally(live)?.ratio;

/// A parent's tick, drawn from its live subtasks (GL8). With none, it
/// is not derived and the parent's own tick stands. Otherwise the
/// parent is done exactly when every subtask is, and its stored
/// `doneAt` is the latest of theirs; with any open, it is null. Every
/// device writes the same instant, so the export and the web agree.
({bool derived, DateTime? doneAt}) parentDoneAt(Iterable<GoalItem> subtasks) {
  if (subtasks.isEmpty) return (derived: false, doneAt: null);
  DateTime? latest;
  for (final item in subtasks) {
    final at = item.doneAt;
    if (at == null) return (derived: true, doneAt: null);
    if (latest == null || at.isAfter(latest)) latest = at;
  }
  return (derived: true, doneAt: latest);
}

/// A goal's live items as the screen draws them: top-level items by
/// kind, each with its subtasks, one level deep (GL8).
@immutable
class GoalOutline {
  factory GoalOutline(Iterable<GoalItem> live) {
    final byUuid = {for (final item in live) item.uuid: item};
    final top = <GoalItem>[];
    final children = <String, List<GoalItem>>{};
    for (final item in live) {
      final parent = item.parentUuid;
      // A subtask whose parent is gone reads as an item of its own.
      if (parent == null || !byUuid.containsKey(parent)) {
        top.add(item);
      } else {
        (children[parent] ??= []).add(item);
      }
    }
    top.sort(_byPosition);
    for (final list in children.values) {
      list.sort(_byPosition);
    }
    return GoalOutline._(top, children);
  }

  const GoalOutline._(this._top, this._children);

  final List<GoalItem> _top;
  final Map<String, List<GoalItem>> _children;

  List<GoalItem> top(GoalItemKind kind) =>
      [for (final item in _top) if (item.kind == kind) item];

  List<GoalItem> subtasksOf(String uuid) => _children[uuid] ?? const [];

  /// A parent is done when all its subtasks are; anything else by its
  /// own tick.
  bool isDone(GoalItem item) {
    final subtasks = subtasksOf(item.uuid);
    return subtasks.isEmpty
        ? item.isDone
        : subtasks.every((subtask) => subtask.isDone);
  }

  /// The first open task — its first open subtask when it has them —
  /// or, with every task done, the same over requirements.
  GoalItem? get next {
    for (final kind in const [GoalItemKind.step, GoalItemKind.need]) {
      for (final item in top(kind)) {
        if (isDone(item)) continue;
        return subtasksOf(item.uuid).where((s) => !s.isDone).firstOrNull ??
            item;
      }
    }
    return null;
  }

  static int _byPosition(GoalItem a, GoalItem b) {
    final byPosition = a.position.compareTo(b.position);
    if (byPosition != 0) return byPosition;
    final at = a.createdAt;
    final bt = b.createdAt;
    if (at == null || bt == null) return 0;
    return at.compareTo(bt);
  }
}
