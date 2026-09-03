import 'dart:async';

import 'package:harvest/core/domain/harvest_day.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'current_day.g.dart';

/// The live Harvest Day. Everything keyed on "today" watches this
/// instead of calling [HarvestDay.today] once and freezing: it ticks
/// over by itself at the 3 AM boundary and can be nudged on resume.
@Riverpod(keepAlive: true)
class CurrentHarvestDay extends _$CurrentHarvestDay {
  Timer? _rollover;

  @override
  HarvestDay build() {
    ref.onDispose(() => _rollover?.cancel());
    final today = HarvestDay.today();
    _arm(today);
    return today;
  }

  /// Re-reads the clock (app resumed, time zone changed, test hook).
  void refresh() {
    final today = HarvestDay.today();
    if (today != state) state = today;
    _arm(today);
  }

  void _arm(HarvestDay today) {
    _rollover?.cancel();
    final wait = today.next.startsAt.difference(DateTime.now());
    _rollover = Timer(
      wait.isNegative
          ? const Duration(seconds: 1)
          : wait + const Duration(seconds: 1),
      refresh,
    );
  }
}
