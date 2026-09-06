import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harvest/app/router.dart';

/// The shell's branch numbers are positions in a list, and a list that
/// something else has to agree with by hand is a list that will
/// disagree eventually. It did: inserting the Body branch in the
/// middle silently moved Records, and the Body tab opened Notes.
///
/// So the numbers are asserted against the router itself rather than
/// against a comment.
void main() {
  test('every shell branch is where its constant says it is', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(routerProvider);

    final shell = router.configuration.routes
        .whereType<StatefulShellRoute>()
        .single;

    String pathOf(int branch) {
      final route = shell.branches[branch].routes.single as GoRoute;
      return route.path;
    }

    expect(pathOf(ShellBranch.field), AppRoutes.field);
    expect(pathOf(ShellBranch.finances), AppRoutes.finances);
    expect(pathOf(ShellBranch.stats), AppRoutes.stats);
    expect(pathOf(ShellBranch.settings), AppRoutes.settings);
    expect(pathOf(ShellBranch.body), AppRoutes.body);
    expect(pathOf(ShellBranch.records), AppRoutes.records);
  });

  test('the branch list has exactly the branches we name', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final shell = container
        .read(routerProvider)
        .configuration
        .routes
        .whereType<StatefulShellRoute>()
        .single;

    // A seventh branch added without a constant would slip past the
    // test above; this one notices.
    expect(shell.branches, hasLength(6));
  });
}
