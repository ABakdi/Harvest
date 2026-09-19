import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/ui/widgets/paired_screen.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';

enum _Half { a, b, c }

class _Settings implements SettingsRepository {
  @override
  Future<String?> getString(String key) async => null;

  @override
  Future<void> setString(String key, String value) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records became three halves in phase 5 ([[Places]]): the tab row is
/// exactly the halves that are on, whatever their number.
void main() {
  Widget screen({required Set<_Half> on}) => ProviderScope(
    overrides: [settingsRepositoryProvider.overrideWithValue(_Settings())],
    child: MaterialApp(
      home: PairedScreen<_Half>(
        title: 'Records',
        halves: [
          for (final half in _Half.values)
            (
              value: half,
              icon: Icons.circle,
              label: half.name.toUpperCase(),
              on: on.contains(half),
            ),
        ],
        builder: (current, title, tabs) => Scaffold(
          appBar: AppBar(title: Text(title ?? 'alone'), bottom: tabs),
          body: Text('showing ${current.name}'),
        ),
      ),
    ),
  );

  testWidgets('a switched-off half has no tab', (tester) async {
    await tester.pumpWidget(screen(on: {_Half.a, _Half.c}));
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsNothing);
    expect(find.text('C'), findsOneWidget);

    await tester.tap(find.text('C'));
    await tester.pumpAndSettle();
    expect(find.text('showing c'), findsOneWidget);
  });

  testWidgets('switching a half on keeps me where I was', (tester) async {
    await tester.pumpWidget(screen(on: {_Half.a, _Half.c}));
    await tester.tap(find.text('C'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(screen(on: _Half.values.toSet()));
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
    expect(find.text('showing c'), findsOneWidget);
  });

  testWidgets('one half on stands alone, with no tabs', (tester) async {
    await tester.pumpWidget(screen(on: {_Half.b}));
    expect(find.text('alone'), findsOneWidget);
    expect(find.text('showing b'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
  });
}
