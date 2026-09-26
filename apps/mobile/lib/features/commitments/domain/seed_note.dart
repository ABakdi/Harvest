import 'package:harvest/core/domain/harvest_day.dart';
import 'package:meta/meta.dart';

/// A note kept against a seed on one Harvest Day.
///
/// The point is the sequence, not the single entry: today starts blank,
/// and yesterday's note is right there to read first — the page I
/// stopped on, the weight I lifted, where to pick the thread back up.
@immutable
class SeedNote {
  const SeedNote({
    required this.uuid,
    required this.commitmentUuid,
    required this.day,
    required this.body,
    required this.loggedAt,
  });

  final String uuid;
  final String commitmentUuid;
  final HarvestDay day;
  final String body;
  final DateTime loggedAt;
}
