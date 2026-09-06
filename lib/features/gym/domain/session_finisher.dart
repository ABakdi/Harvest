import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/commitments/domain/check_in_service.dart';
import 'package:harvest/features/gym/data/programs_repository.dart';
import 'package:harvest/features/gym/data/sessions_repository.dart';
import 'package:harvest/features/gym/domain/program.dart';
import 'package:harvest/features/gym/domain/session.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_finisher.g.dart';

/// What finishing a session came to.
typedef FinishOutcome = ({
  /// The XP the check-in paid, or zero when there was nothing to check
  /// in — no habit bound, or the habit already checked in today.
  int xpEarned,

  /// The album to offer a picture for, if the program has one and asks
  /// for the picture at the end.
  String? albumUuid,
});

/// Ends a session and pays what it earned.
///
/// The rule this exists for ([[Gym]] rule Y4): **finishing** checks the
/// habit in. Starting checks nothing in, abandoning checks nothing in,
/// and finishing twice checks nothing in twice — that last one is free,
/// because a habit is once a day everywhere else in the app and this
/// goes through the same door.
class SessionFinisher {
  const SessionFinisher(
    this._sessions,
    this._programs,
    this._commitments,
    this._checkIns,
  );

  final SessionsRepository _sessions;
  final ProgramsRepository _programs;
  final CommitmentsRepository _commitments;
  final CheckInService _checkIns;

  Future<FinishOutcome> finish(WorkoutSession session) async {
    await _sessions.finish(session.uuid);

    final programUuid = session.programUuid;
    if (programUuid == null) return (xpEarned: 0, albumUuid: null);
    final program = await _programs.once(programUuid);
    if (program == null) return (xpEarned: 0, albumUuid: null);

    return (
      xpEarned: await _checkInFor(program, session),
      albumUuid: program.photoPrompt == PhotoPrompt.after
          ? program.albumUuid
          : null,
    );
  }

  Future<int> _checkInFor(Program program, WorkoutSession session) async {
    final commitmentUuid = program.commitmentUuid;
    if (commitmentUuid == null) return 0;
    final commitment = await _commitments.once(commitmentUuid);
    // A seed that was archived or deleted since the program was bound
    // to it is not an error: the workout happened either way.
    if (commitment == null || commitment.isArchived) return 0;

    // On the day the session belongs to, not the day it was finished —
    // a session logged past midnight but before 3 AM is still last
    // night's ([[Business-Rules]]).
    final result = await _checkIns.checkIn(commitment, day: session.day);
    return switch (result) {
      CheckInSuccess(:final xpEarned) => xpEarned,
      CheckInCapped(:final xpEarned) => xpEarned,
    };
  }
}

@riverpod
SessionFinisher sessionFinisher(Ref ref) => SessionFinisher(
  ref.watch(sessionsRepositoryProvider),
  ref.watch(programsRepositoryProvider),
  ref.watch(commitmentsRepositoryProvider),
  ref.watch(checkInServiceProvider),
);
