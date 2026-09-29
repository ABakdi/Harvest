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

/// A moment on the local clock: "8:43 PM" today, "Sep 3, 8:43 PM"
/// another day, with the year when it is not this one.
String formatMoment(BuildContext context, DateTime moment) {
  final local = moment.toLocal();
  final now = DateTime.now();
  final time = formatTime(context, local);
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return time;
  }
  final locale = localeTag(context);
  final day = local.year == now.year
      ? DateFormat.MMMd(locale).format(local)
      : DateFormat.yMMMd(locale).format(local);
  return '$day, $time';
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

/// A length of time as a clock: `4:05` under an hour, `1:04:05` past
/// it. The one duration formatter — the session clock, a recording and
/// the focus timer all read through it, so none of them prints
/// `100:05` for an hour and forty minutes. [padMinutes] writes `04:05`
/// under an hour, the timer's face. A negative duration reads as zero.
String formatDuration(Duration d, {bool padMinutes = false}) {
  String two(int n) => n.toString().padLeft(2, '0');
  final whole = d.isNegative ? 0 : d.inSeconds;
  final hours = whole ~/ 3600;
  final minutes = (whole % 3600) ~/ 60;
  final seconds = two(whole % 60);
  if (hours > 0) return '$hours:${two(minutes)}:$seconds';
  return '${padMinutes ? two(minutes) : minutes}:$seconds';
}
