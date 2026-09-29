import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/features/finances/domain/currency.dart';

/// Where the phone says it is: its SIM's and its network's country, and
/// its time zone. Read once, on the phone, and never sent anywhere.
typedef Whereabouts = ({List<String?> countries, String? zone});

/// Asks Android (`MainActivity`, `harvest/where`); nothing, anywhere else
/// or when it does not answer.
Future<Whereabouts> readWhereabouts() async {
  const channel = MethodChannel('harvest/where');
  try {
    final answer = await channel.invokeMapMethod<String, String?>('where');
    return (
      countries: [answer?['sim'], answer?['network']],
      zone: answer?['zone'],
    );
  } on Object {
    return (countries: const <String?>[], zone: null);
  }
}

/// The setting the default currency lives in (`FinanceKeys`).
const defaultCurrencyKey = 'finance.defaultCurrency';

/// The moment a guessed default is stamped with: older than any currency
/// I choose, on this phone or another, so a choice always wins over the
/// guess when the two meet in sync.
final guessedAt = DateTime.utc(2000);

/// On a phone with no default currency yet, sets the one where the phone
/// is ([defaultCurrencyFor]): the SIM's country, then the network's, the
/// time zone, and the languages set on the phone ([[Finances]], Phase 7
/// M7.8). Once there is one, it is never guessed again, and a phone that
/// has logged money already is never guessed for.
Future<Currency?> guessDefaultCurrency(
  HarvestDatabase db, {
  Future<Whereabouts> Function() where = readWhereabouts,
  List<String>? locales,
}) async {
  final existing = await (db.select(
    db.kvSettings,
  )..where((s) => s.key.equals(defaultCurrencyKey))).getSingleOrNull();
  if (existing != null) return null;
  // A phone from before, with money already logged, has been on the
  // dinar all along without saying so: its totals stay as they were
  // rather than turn into another currency on an update.
  final logged = await db
      .customSelect(
        'SELECT EXISTS (SELECT 1 FROM expenses) OR EXISTS (SELECT 1 FROM money_txns) '
        'OR EXISTS (SELECT 1 FROM debts) AS any_money',
        readsFrom: {db.expenses, db.moneyTxns, db.debts},
      )
      .getSingle();
  if (logged.read<bool>('any_money')) return null;
  final found = await where();
  final currency = defaultCurrencyFor(
    countries: found.countries,
    timeZone: found.zone,
    locales:
        locales ??
        [
          for (final locale in PlatformDispatcher.instance.locales)
            locale.toLanguageTag(),
        ],
  );
  // Not through the settings repository and not into the outbox: a
  // guess is not a change I made, and it must lose to one.
  await db
      .into(db.kvSettings)
      .insert(
        KvSettingsCompanion.insert(
          key: defaultCurrencyKey,
          valueJson: '"${currency.code}"',
          updatedAt: Value(guessedAt),
        ),
        mode: InsertMode.insertOrIgnore,
      );
  debugPrint('[finance] default currency guessed: ${currency.code}');
  return currency;
}
