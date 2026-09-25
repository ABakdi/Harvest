import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/features/finances/presentation/choice_sheet.dart';
import 'package:harvest/features/gym/data/sessions_repository.dart';
import 'package:harvest/features/gym/domain/program.dart';
import 'package:harvest/features/gym/domain/session_finisher.dart';
import 'package:harvest/features/gym/presentation/session_start.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The two honest ways to tick a gym seed: start the session, or say
/// I went and logged nothing — which is still a session, finished on
/// the spot, so history and the streak agree ([[Gym]] Y12,
/// [[Checkpoint-7]]). Every place that would check a gym seed in asks
/// this instead: the field, and the end of a focus block.
///
/// Returns the XP a bare session earned, or null when nothing was
/// written here (dismissed, or the session was started instead).
Future<int?> chooseGymSeed(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required Program program,
}) async {
  final l10n = AppLocalizations.of(context);
  final scheme = Theme.of(context).colorScheme;
  final start = await showChoiceSheet<bool>(
    context,
    title: title,
    options: [
      ChoiceOption(
        value: true,
        label: l10n.gymSeedStart,
        hint: l10n.gymSeedStartHint,
        icon: Icons.play_arrow_rounded,
      ),
      ChoiceOption(
        value: false,
        label: l10n.gymSeedBare,
        hint: l10n.gymSeedBareHint,
        icon: Icons.check_rounded,
        color: scheme.secondary,
      ),
    ],
  );
  if (start == null || !context.mounted) return null;
  if (start) {
    // This seed's program, not every program: a session of another one
    // would never check this seed in ([[Audit-v2]] B3-10).
    await startSession(context, ref, only: program);
    return null;
  }

  // The bare session is the day that was up next, so "Up next" moves
  // on as if I had logged it ([[Audit-v2]] B3-03).
  final sessions = ref.read(sessionsRepositoryProvider);
  final next = await sessions.nextDay(program);
  final session = await sessions.startFreeform(
    title: next?.name ?? l10n.gymSeedBare,
    programUuid: program.uuid,
    dayUuid: next?.uuid,
  );
  final outcome = await ref.read(sessionFinisherProvider).finish(session);
  unawaited(HarvestHaptics.thud());
  return outcome.xpEarned;
}
