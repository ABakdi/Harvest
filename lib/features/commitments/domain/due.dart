import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';

/// The one rule for "does this seed want attention on [day]?" — used by
/// the field, the calendar and the reminder planner so they never
/// disagree.
///
/// - Nothing is ever due before the day it was planted. A schedule
///   describes a rhythm, not a history: a habit created today starts
///   today and the calendar's past stays as empty as it really was.
/// - A habit is due when its schedule says so and it is not paused; a
///   times-per-week habit stops being due once the week's quota is met.
/// - A project is due every day until it reaches its target.
/// - A to-do is due on its planned day and every day after until done.
bool isDueOn(
  Commitment commitment,
  HarvestDay day, {
  int doneDaysThisWeek = 0,
  int totalLogged = 0,
}) {
  if (day.compareTo(commitment.startDay) < 0) return false;
  return switch (commitment.type) {
    CommitmentType.habit =>
      !commitment.isPaused &&
          (commitment.schedule ?? const DailySchedule()).isDueOn(
            day,
            doneDaysThisWeek: doneDaysThisWeek,
          ),
    CommitmentType.project => totalLogged < (commitment.totalTarget ?? 0),
    CommitmentType.todo =>
      totalLogged == 0 &&
          (commitment.dueDay == null || commitment.dueDay!.compareTo(day) <= 0),
  };
}

/// A to-do planned for a day that has passed and is still not done.
bool isOverdueOn(
  Commitment commitment,
  HarvestDay day, {
  int totalLogged = 0,
}) =>
    commitment.type == CommitmentType.todo &&
    totalLogged == 0 &&
    commitment.dueDay != null &&
    commitment.dueDay!.compareTo(day) < 0;
