import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/l10n_loader.dart';
import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/due.dart';
import 'package:harvest/features/gamification/data/gamification_repository.dart';
import 'package:harvest/features/widget/data/home_widget_gateway.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'widget_service.g.dart';

/// What the home-screen widget shows.
typedef WidgetSnapshot = ({int streak, int done, int due, int xp});

/// Keeps the home-screen widget honest.
///
/// It reads the database rather than any screen's providers, because it
/// has to be able to run when no screen exists — at the 3 AM reset, or
/// straight after a check-in that closed the app.
class WidgetService {
  WidgetService(this._db, this._widget)
    : _commitments = CommitmentsRepository(_db);

  final HarvestDatabase _db;
  final HomeWidgetGateway _widget;
  final CommitmentsRepository _commitments;

  /// Today's numbers, computed the same way the field computes them so
  /// the widget can never disagree with the screen behind it.
  Future<WidgetSnapshot> snapshot({HarvestDay? today}) async {
    final day = today ?? HarvestDay.today();
    var done = 0;
    var due = 0;
    for (final commitment in await _commitments.activeOnce()) {
      final total = await _commitments.totalOnce(commitment.uuid);
      final isDue = isDueOn(
        commitment,
        day,
        doneDaysThisWeek: await _commitments.doneDaysInWeekOnce(
          commitment.uuid,
          day,
        ),
        totalLogged: total,
      );
      if (!isDue || commitment.isPaused) continue;
      due++;
      final logged = await _commitments.loggedOnOnce(commitment.uuid, day);
      final item = FieldItem(
        commitment: commitment,
        loggedToday: logged,
        totalLogged: total,
      );
      if (item.isDone) done++;
    }

    final streak = await (_db.select(
      _db.streaks,
    )..where((s) => s.scope.equals('global'))).getSingleOrNull();
    final sum = _db.ledger.delta.sum();
    final xpQuery = _db.selectOnly(_db.ledger)
      ..addColumns([sum])
      ..where(_db.ledger.kind.equals('xp'));
    final xp = (await xpQuery.getSingle()).read(sum) ?? 0;

    return (streak: streak?.current ?? 0, done: done, due: due, xp: xp);
  }

  /// Writes today's numbers out and redraws the widget.
  Future<void> refresh({HarvestDay? today}) async {
    final data = await snapshot(today: today);
    final l10n = await localizationsFromSettings(_db);
    // Everything crosses as a string: the channel decides on its own
    // whether a Dart int arrives as an Integer or a Long, and guessing
    // wrong is a ClassCastException inside a broadcast receiver.
    await _widget.put('streak', '${data.streak}');
    await _widget.put('streakLabel', l10n.widgetStreakLabel);
    await _widget.put(
      'tasks',
      data.due == 0
          ? l10n.widgetEmpty
          : '${data.done}/${data.due} ${l10n.widgetTasksLabel}',
    );
    await _widget.put('rank', rankLabel(l10n, FarmerRank.forXp(data.xp)));
    await _widget.refresh();
  }
}

/// The rank's name, in one place: the field, the stats screen and the
/// widget all say the same word for the same XP.
String rankLabel(AppLocalizations l10n, FarmerRank rank) => switch (rank) {
  FarmerRank.sprout => l10n.rankSprout,
  FarmerRank.seedling => l10n.rankSeedling,
  FarmerRank.gardener => l10n.rankGardener,
  FarmerRank.harvester => l10n.rankHarvester,
  FarmerRank.masterFarmer => l10n.rankMasterFarmer,
};

@Riverpod(keepAlive: true)
WidgetService widgetService(Ref ref) => WidgetService(
  ref.watch(databaseProvider),
  ref.watch(homeWidgetGatewayProvider),
);
