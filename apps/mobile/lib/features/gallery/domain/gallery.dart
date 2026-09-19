import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:meta/meta.dart';

/// What a memory is.
enum MemoryKind {
  photo,
  video;

  static MemoryKind fromName(String? name) => MemoryKind.values.firstWhere(
    (kind) => kind.name == name,
    orElse: () => MemoryKind.photo,
  );
}

/// A run of memories, optionally on a schedule.
///
/// A scheduled album **is a seed** (rule G3): it is due like a habit is
/// due, it is checked in by adding a picture rather than by tapping a
/// circle, and it feeds the same streak as everything else.
@immutable
class Album {
  const Album({
    required this.uuid,
    required this.name,
    required this.createdAt,
    this.schedule,
    this.remindAt,
    this.note,
  });

  final String uuid;
  final String name;
  final DateTime createdAt;

  /// Null for an album I add to when I feel like it. Non-null makes it
  /// a seed on the field.
  final Schedule? schedule;
  final String? remindAt;
  final String? note;

  bool get isScheduled => schedule != null;

  /// The first Harvest Day this album counts for. Nothing is ever due
  /// before it was made ([[Business-Rules]] #12).
  HarvestDay get startDay => HarvestDay.of(createdAt);

  /// Whether the album wants a picture on [day].
  bool isDueOn(HarvestDay day, {int doneDaysThisWeek = 0}) {
    if (schedule == null) return false;
    if (day.compareTo(startDay) < 0) return false;
    return schedule!.isDueOn(day, doneDaysThisWeek: doneDaysThisWeek);
  }

  Album copyWith({
    String? name,
    Schedule? schedule,
    String? remindAt,
    String? note,
    bool clearSchedule = false,
    bool clearRemindAt = false,
  }) => Album(
    uuid: uuid,
    name: name ?? this.name,
    createdAt: createdAt,
    schedule: clearSchedule ? null : schedule ?? this.schedule,
    remindAt: clearRemindAt ? null : remindAt ?? this.remindAt,
    note: note ?? this.note,
  );
}

/// One picture or clip, and what I wrote about it.
@immutable
class Memory {
  const Memory({
    required this.uuid,
    required this.albumUuid,
    required this.day,
    required this.path,
    required this.capturedAt,
    this.kind = MemoryKind.photo,
    this.note,
  });

  final String uuid;
  final String albumUuid;
  final HarvestDay day;

  /// Relative to the gallery directory, so the row survives the app's
  /// storage moving between installs.
  final String path;
  final MemoryKind kind;
  final String? note;
  final DateTime capturedAt;
}

/// An album with the numbers the list needs.
typedef AlbumSummary = ({
  Album album,
  int count,
  int bytes,
  Memory? latest,
  bool doneToday,
});

/// Bytes as something a person reads: "4.2 MB".
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return value >= 10
      ? '${value.round()} ${units[unit]}'
      : '${value.toStringAsFixed(1)} ${units[unit]}';
}
