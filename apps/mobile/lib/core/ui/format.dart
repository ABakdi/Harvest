import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:intl/intl.dart';

/// The locale tag intl wants, from the widget tree.
String localeTag(BuildContext context) =>
    Localizations.localeOf(context).toString();

/// Every date, time and number in Western digits, Arabic included: intl
/// writes Arabic dates in Arabic-Indic digits by default, which sat
/// "٦:٤٩ م" beside money's "DA5,000" on one screen. Money's digits are
/// Western ([[Finances]]); so is everything else. Called once, before
/// the first frame. (Numbers already are: intl's `ar` symbols count in
/// Western digits.)
void useWesternDigits() {
  for (final locale in const ['ar', 'ar_DZ', 'ar_EG']) {
    DateFormat.useNativeDigitsByDefaultFor(locale, false);
  }
}

/// "8:43 PM" in the current locale.
String formatTime(BuildContext context, DateTime moment) =>
    DateFormat.jm(localeTag(context)).format(moment);

/// "Sep 3" in the current locale (year added when it differs).
String formatDay(BuildContext context, HarvestDay day, {bool weekday = false}) {
  final locale = localeTag(context);
  final date = day.toDateTime();
  if (weekday) return DateFormat.MMMEd(locale).format(date);
  return day.year == HarvestDay.today().year
      ? DateFormat.MMMd(locale).format(date)
      : DateFormat.yMMMd(locale).format(date);
}

/// A measurement in the locale's own digits and separators, with
/// trailing zeros dropped: `82.5`, `1,240`, `100`.
///
/// Weights and distances used to be written with `toStringAsFixed`,
/// which groups nothing and keeps a trailing zero the scale never
/// showed ([[Audit-v2]] U3-18). Digits stay Western, as money's do
/// ([[Finances]]); what the locale decides is the separators.
String formatNumber(BuildContext context, num value, {int decimals = 1}) {
  final factor = math.pow(10, decimals);
  final rounded = (value * factor).round() / factor;
  var places = 0;
  for (var digits = decimals; digits > 0; digits--) {
    if ((rounded * math.pow(10, digits)).round() % 10 != 0) {
      places = digits;
      break;
    }
  }
  return NumberFormat.decimalPatternDigits(
    locale: localeTag(context),
    decimalDigits: places,
  ).format(rounded);
}
