import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:harvest/app/shell.dart';
import 'package:harvest/features/calendar/presentation/calendar_screen.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/presentation/archive_screen.dart';
import 'package:harvest/features/commitments/presentation/seed_detail_screen.dart';
import 'package:harvest/features/field/field_screen.dart';
import 'package:harvest/features/finances/presentation/granary_screen.dart';
import 'package:harvest/features/gallery/presentation/album_screen.dart';
import 'package:harvest/features/onboarding/presentation/onboarding_screen.dart';
import 'package:harvest/features/planner/presentation/planner_screen.dart';
import 'package:harvest/features/pomodoro/presentation/pomodoro_screen.dart';
import 'package:harvest/features/records/presentation/records_screen.dart';
import 'package:harvest/features/settings/presentation/settings_screen.dart';
import 'package:harvest/features/stats/stats_screen.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

abstract final class AppRoutes {
  static const onboarding = '/onboarding';
  static const field = '/field';
  static const pomodoro = '/field/pomodoro';
  static const planner = '/field/planner';
  static const calendar = '/field/calendar';
  static const archive = '/field/archive';

  /// The seed detail screen; append the seed's uuid.
  static const seed = '/field/seed';
  static const finances = '/finances';
  static const stats = '/stats';
  static const settings = '/settings';

  /// Notes and the Gallery, under one roof ([[Checkpoint-5]]). The
  /// branch always exists; the shell decides whether a tab points at
  /// it (rules N1 and G1: off until asked for, and switching one off
  /// hides it without deleting a thing).
  static const records = '/records';

  /// A single note, opened straight from a link or a reminder.
  static const notes = '/records/note';

  /// An album's own screen; append the album's uuid.
  static const gallery = '/records/album';
}

/// Which branch of the shell each tab is, in the order they are
/// declared below. The shell shows a subset of these.
abstract final class ShellBranch {
  static const field = 0;
  static const finances = 1;
  static const stats = 2;
  static const settings = 3;
  static const records = 4;
}

/// Re-runs the redirect whenever onboarding completes.
class _OnboardingRefresh extends ChangeNotifier {
  void bump() => notifyListeners();
}

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final refresh = _OnboardingRefresh();
  ref
    ..onDispose(refresh.dispose)
    ..listen(onboardingDoneProvider, (_, _) => refresh.bump());
  return GoRouter(
    initialLocation: AppRoutes.field,
    refreshListenable: refresh,
    // A location the router does not know is a bug somewhere else —
    // a stale deep link, a reminder payload from an older build. The
    // field is a better answer than a red error page.
    onException: (context, state, router) {
      debugPrint('[router] no route for ${state.uri}');
      router.go(AppRoutes.field);
    },
    redirect: (context, state) {
      final done = ref.read(onboardingDoneProvider);
      if (!done && state.matchedLocation != AppRoutes.onboarding) {
        return AppRoutes.onboarding;
      }
      if (done && state.matchedLocation == AppRoutes.onboarding) {
        return AppRoutes.field;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HarvestShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.field,
                builder: (context, state) => const FieldScreen(),
                routes: [
                  GoRoute(
                    path: 'pomodoro',
                    builder: (context, state) => PomodoroScreen(
                      commitment: state.extra as Commitment?,
                    ),
                  ),
                  GoRoute(
                    path: 'planner',
                    builder: (context, state) => const PlannerScreen(),
                  ),
                  GoRoute(
                    path: 'calendar',
                    builder: (context, state) => const CalendarScreen(),
                  ),
                  GoRoute(
                    path: 'archive',
                    builder: (context, state) => const ArchiveScreen(),
                  ),
                  GoRoute(
                    path: 'seed/:uuid',
                    builder: (context, state) => SeedDetailScreen(
                      uuid: state.pathParameters['uuid']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.finances,
                builder: (context, state) => const GranaryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.stats,
                builder: (context, state) => const StatsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.records,
                builder: (context, state) => const RecordsScreen(),
                routes: [
                  GoRoute(
                    path: 'note/:uuid',
                    builder: (context, state) => RecordsScreen(
                      initial: RecordsTab.notes,
                      noteUuid: state.pathParameters['uuid'],
                    ),
                  ),
                  GoRoute(
                    path: 'album/:uuid',
                    builder: (context, state) =>
                        AlbumScreen(uuid: state.pathParameters['uuid']!),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
