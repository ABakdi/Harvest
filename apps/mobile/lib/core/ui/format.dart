import 'package:flutter/widgets.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:intl/intl.dart';

/// The locale tag intl wants, from the widget tree.
String localeTag(BuildContext context) =>
    Localizations.localeOf(context).toString();

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
