import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/l10n_loader.dart';
import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/due.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
import 'package:harvest/features/finances/presentation/money.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/features/widget/data/home_widget_gateway.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'widget_service.g.dart';

/// Which sections the home-screen widget shows.
///
/// The streak is not on this list: it is the app, and a widget that can
/// be configured into showing nothing is a widget with a bug in it.
abstract final class WidgetKeys {
  /// Today's spend and the wallet balance.
  static const money = 'widget.money';

  /// The scrollable list of what is still due today.
  static const tasks = 'widget.tasks';

  /// The two buttons: log an expense, plant a seed.
  static const actions = 'widget.actions';

  /// Defaults for a widget nobody has configured yet.
  static const Map<String, bool> defaults = {
    money: true,
    tasks: true,
    actions: true,
  };
}

/// One line of the widget's task list.
typedef WidgetTask = ({String uuid, String title, bool done});

/// What the home-screen widget shows.
typedef WidgetSnapshot = ({
  int streak,
  int done,
  int due,
  int spentToday,
  int wallet,
  List<WidgetTask> tasks,
});

/// Keeps the home-screen widget honest.
///
/// It reads the database rather than any screen's providers, because it
/// has to be able to run when no screen exists — at the 3 AM reset, or
/// straight after a check-in that closed the app.
class WidgetService {
  WidgetService(this._db, this._widget)
    : _commitments = CommitmentsRepository(_db),
      _settings = SettingsRepository(_db);

  final HarvestDatabase _db;
  final HomeWidgetGateway _widget;
  final CommitmentsRepository _commitments;
  final SettingsRepository _settings;

  /// How many tasks the widget's list carries. It scrolls, so this is
  /// only a bound on how much is worth serialising.
  static const taskLimit = 20;

  /// Today's numbers, computed the same way the field computes them so
  /// the widget can never disagree with the screen behind it.
  Future<WidgetSnapshot> snapshot({HarvestDay? today}) async {
    final day = today ?? HarvestDay.today();
    var done = 0;
    final tasks = <WidgetTask>[];

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
      final logged = await _commitments.loggedOnOnce(commitment.uuid, day);
      final item = FieldItem(
        commitment: commitment,
        loggedToday: logged,
        totalLogged: total,
      );
      if (item.isDone) done++;
      tasks.add((
        uuid: commitment.uuid,
        title: commitment.title,
        done: item.isDone,
      ));
    }

    // Undone first: the widget's job is to say what is left, and the
    // list is short enough that scrolling past the done ones is a cost
    // with no benefit.
    tasks.sort((a, b) {
      if (a.done == b.done) return 0;
      return a.done ? 1 : -1;
    });

    final streak = await (_db.select(
      _db.streaks,
    )..where((s) => s.scope.equals('global'))).getSingleOrNull();
    return (
      streak: streak?.current ?? 0,
      done: done,
      due: tasks.length,
      spentToday: await _spentOn(day),
      wallet: await _walletBalance(),
      tasks: tasks.take(taskLimit).toList(),
    );
  }

  /// Writes today's numbers out and redraws the widget.
  Future<void> refresh({HarvestDay? today}) async {
    final data = await snapshot(today: today);
    final l10n = await localizationsFromSettings(_db);
    final currency = Currency.fromCode(
      await _settings.getString(FinanceKeys.defaultCurrency),
    );

    Future<bool> section(String key) async =>
        await _settings.getBool(key) ?? WidgetKeys.defaults[key]!;

    // Everything crosses as a string: the channel decides on its own
    // whether a Dart int arrives as an Integer or a Long, and guessing
    // wrong is a ClassCastException inside a broadcast receiver.
    await _widget.put('streak', '${data.streak}');
    await _widget.put('streakLabel', l10n.widgetStreakLabel);
    await _widget.put(
      'progress',
      data.due == 0
          ? l10n.widgetEmpty
          : '${data.done}/${data.due} ${l10n.widgetTasksLabel}',
    );
    await _widget.put(
      'spent',
      l10n.widgetSpentToday(formatAmount(data.spentToday, currency)),
    );
    await _widget.put(
      'wallet',
      l10n.widgetWallet(formatAmount(data.wallet, currency)),
    );

    await _widget.put('actionExpense', l10n.widgetActionExpense);
    await _widget.put('actionTask', l10n.widgetActionTask);
    await _widget.put('emptyTasks', l10n.widgetAllDone);

    await _widget.put('showMoney', await section(WidgetKeys.money));
    await _widget.put('showTasks', await section(WidgetKeys.tasks));
    await _widget.put('showActions', await section(WidgetKeys.actions));

    await _widget.put(
      'tasks',
      jsonEncode([
        for (final task in data.tasks)
          {'uuid': task.uuid, 'title': task.title, 'done': task.done},
      ]),
    );
    await _widget.refresh();
  }

  /// Everything spent on [day], converted into the default currency
  /// face-value-first, exactly as the Granary's own gauge does it.
  Future<int> _spentOn(HarvestDay day) async {
    final rates = await _rates();
    final rows =
        await (_db.select(_db.expenses)..where(
              (e) => e.harvestDay.equals(day.key) & e.deletedAt.isNull(),
            ))
            .get();
    var total = 0;
    for (final row in rows) {
      total += rates.toDefaultOrFace(
        row.amountMinor,
        Currency.fromCode(row.currency),
      );
    }
    return total;
  }

  Future<int> _walletBalance() async {
    final rates = await _rates();
    final rows =
        await (_db.select(_db.moneyTxns)..where(
              (t) => t.account.equals('wallet') & t.deletedAt.isNull(),
            ))
            .get();
    var total = 0;
    for (final row in rows) {
      total += rates.toDefaultOrFace(
        row.deltaMinor,
        Currency.fromCode(row.currency),
      );
    }
    return total;
  }

  Future<Rates> _rates() async {
    double? rate(String? raw) => double.tryParse(raw ?? '');
    return Rates(
      defaultCurrency: Currency.fromCode(
        await _settings.getString(FinanceKeys.defaultCurrency),
      ),
      dzdPerUsd: rate(await _settings.getString('rate.dzdPerUsd')),
      dzdPerEur: rate(await _settings.getString('rate.dzdPerEur')),
      usdPerEur: rate(await _settings.getString('rate.usdPerEur')),
    );
  }
}

@Riverpod(keepAlive: true)
WidgetService widgetService(Ref ref) => WidgetService(
  ref.watch(databaseProvider),
  ref.watch(homeWidgetGatewayProvider),
);
