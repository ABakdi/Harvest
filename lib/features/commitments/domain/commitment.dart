import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:meta/meta.dart';

enum CommitmentType { habit, project, todo }

/// A seed in the field: a habit, a project, or a to-do.
@immutable
class Commitment {
  const Commitment({
    required this.uuid,
    required this.type,
    required this.title,
    required this.createdAt,
    this.schedule,
    this.totalTarget,
    this.dailyCommitment,
    this.dueDay,
    this.pausedAt,
    this.archivedAt,
  })  : assert(
          type != CommitmentType.habit || schedule != null,
          'habits need a schedule',
        ),
        assert(
          type != CommitmentType.project ||
              (totalTarget != null && dailyCommitment != null),
          'projects need totalTarget and dailyCommitment',
        );

  final String uuid;
  final CommitmentType type;
  final String title;
  final DateTime createdAt;

  /// Habits only.
  final Schedule? schedule;

  /// Projects only: total units and the daily commitment.
  final int? totalTarget;
  final int? dailyCommitment;

  /// To-dos only: the Harvest Day this is planned for.
  final HarvestDay? dueDay;

  /// Habits only: vacation mode. A paused habit is neither due nor
  /// judged, and its streak survives the break.
  final DateTime? pausedAt;

  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;
  bool get isPaused => pausedAt != null;

  /// Over-log cap (business rule #2): max units for a project in one day.
  int get maxUnitsPerDay =>
      type == CommitmentType.project ? 2 * (dailyCommitment ?? 0) : 1;

  Commitment copyWith({
    String? title,
    Schedule? schedule,
    int? totalTarget,
    int? dailyCommitment,
    HarvestDay? dueDay,
    DateTime? archivedAt,
  }) =>
      Commitment(
        uuid: uuid,
        type: type,
        title: title ?? this.title,
        createdAt: createdAt,
        schedule: schedule ?? this.schedule,
        totalTarget: totalTarget ?? this.totalTarget,
        dailyCommitment: dailyCommitment ?? this.dailyCommitment,
        dueDay: dueDay ?? this.dueDay,
        pausedAt: pausedAt,
        archivedAt: archivedAt ?? this.archivedAt,
      );
}

/// A commitment as it appears on today's field.
@immutable
class FieldItem {
  const FieldItem({
    required this.commitment,
    required this.loggedToday,
    required this.totalLogged,
  });

  final Commitment commitment;

  /// Units logged today (1 per check-in for habits/todos).
  final int loggedToday;

  /// Lifetime logged units (projects: progress toward [Commitment.totalTarget]).
  final int totalLogged;

  bool get isDone => switch (commitment.type) {
        CommitmentType.habit => loggedToday > 0,
        CommitmentType.todo => totalLogged > 0,
        CommitmentType.project =>
          loggedToday >= (commitment.dailyCommitment ?? 0) ||
              projectCompleted,
      };

  bool get projectCompleted =>
      commitment.type == CommitmentType.project &&
      totalLogged >= (commitment.totalTarget ?? 0);

  double get projectProgress => commitment.type == CommitmentType.project &&
          (commitment.totalTarget ?? 0) > 0
      ? (totalLogged / commitment.totalTarget!).clamp(0, 1).toDouble()
      : 0;
}
