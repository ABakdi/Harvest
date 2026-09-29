import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/features/commitments/domain/check_in_service.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/presentation/check_in_controller.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The logged amount a project log came to, and what the cap left out.
({int logged, int dropped}) projectLogOf(CheckInResult result) =>
    switch (result) {
      CheckInSuccess(:final quantityLogged) => (
        logged: quantityLogged,
        dropped: 0,
      ),
      CheckInCapped(:final quantityLogged, :final dropped) => (
        logged: quantityLogged,
        dropped: dropped,
      ),
    };

/// Whether a log of [logged] on top of [totalBefore] reaches the
/// project's target: the 100% moment.
bool projectReached(Commitment project, int totalBefore, int logged) =>
    logged > 0 && totalBefore + logged >= (project.totalTarget ?? 0);

/// The 100% moment, wherever the log came from: a celebration dialog,
/// then the crop is archived with its history intact. The focus timer
/// goes through here as the field does, so a project finished from a
/// focus block leaves the field too ([[Audit-v3]] Q5-28).
Future<void> celebrateProjectDone(
  WidgetRef ref,
  NavigatorState navigator, {
  required Commitment project,
  required int total,
  int logged = 0,
  int dropped = 0,
}) async {
  // Taken before the dialog: the screen may be gone by the time it
  // closes, and its `ref` with it.
  final editor = ref.read(commitmentEditorProvider.notifier);
  final context = navigator.context;
  if (!context.mounted) return;
  final l10n = AppLocalizations.of(context);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.projectDoneTitle),
      content: Text(
        projectDoneText(
          l10n,
          title: project.title,
          total: total,
          logged: logged,
          dropped: dropped,
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.toTheBarn),
        ),
      ],
    ),
  );
  await editor.archive(project.uuid);
}

/// What the completion dialog says: the project grown, and — when the
/// last log went past the target — how much of it was left out.
String projectDoneText(
  AppLocalizations l10n, {
  required String title,
  required int total,
  required int logged,
  required int dropped,
}) {
  final body = l10n.projectDoneBody(title, total);
  if (dropped <= 0) return body;
  return '$body\n\n${l10n.projectDoneCut(logged, dropped)}';
}
