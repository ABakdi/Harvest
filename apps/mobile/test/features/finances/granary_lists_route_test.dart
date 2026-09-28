import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harvest/app/router.dart';

/// Planned purchases open the lists inside the Granary's own branch, so
/// Back comes home to the Granary and the bottom bar stays on it (U6-06).
void main() {
  test('the lists have a route under the Granary', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    final match = router.configuration.findMatch(
      Uri.parse('${AppRoutes.granaryLists}?list=buy'),
    );
    expect(match.isError, isFalse);
    final paths = [
      for (final route in match.routes)
        if (route is GoRoute) route.path,
    ];
    expect(paths, [AppRoutes.finances, 'lists']);
    expect(match.uri.queryParameters['list'], 'buy');
  });
}
