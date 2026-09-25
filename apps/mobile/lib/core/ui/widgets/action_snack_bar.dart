import 'package:flutter/material.dart';

/// How long a snack bar with an action — Undo, nearly always — stays up.
const actionSnackBarDuration = Duration(seconds: 6);

/// A snack bar with one action that still goes away on its own.
///
/// A snack bar with an action stays up until it is dismissed unless it
/// says otherwise, and "Moved to the trash · Undo" sat over the Trash
/// entry and the Plant button for as long as I cared to watch, then
/// followed me to the next tab. Undo is an offer for a few seconds, not
/// a fixture. The one exception is a screen reader, which needs the
/// time to reach the action: there it waits, as the platform expects.
///
/// Takes the messenger it will be shown on, which outlives the screen
/// that asked — an undo is usually offered after the thing is gone.
SnackBar actionSnackBar(
  ScaffoldMessengerState messenger, {
  required Widget content,
  required SnackBarAction action,
  Duration duration = actionSnackBarDuration,
  Color? backgroundColor,
}) => SnackBar(
  content: content,
  action: action,
  duration: duration,
  backgroundColor: backgroundColor,
  persist: MediaQuery.accessibleNavigationOf(messenger.context),
);
