import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/account/presentation/sync_pin_sheet.dart';
import 'package:harvest/features/gallery/domain/gallery.dart';
import 'package:harvest/features/gallery/presentation/memory_view.dart';
import 'package:harvest/features/sync/presentation/sync_controller.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:harvest/l10n/app_localizations_en.dart';

class _Pin extends SyncPassphrase {
  _Pin({required this.initial});

  final bool initial;

  @override
  Future<bool> build() async => initial;
}

class _Sync extends SyncController {
  int syncs = 0;

  @override
  SyncStatus build() => const SyncStatus();

  @override
  Future<void> syncNow() async => syncs++;
}

Memory _memory({String? fileHash}) => Memory(
  uuid: 'm1',
  albumUuid: 'album',
  day: HarvestDay.parse('2026-09-20'),
  path: 'm1.jpg',
  capturedAt: DateTime(2026, 9, 20, 8),
  fileHash: fileHash,
);

/// A picture that has not reached this phone says why, in place of the
/// picture ([[Gallery]] G9) — never a blank frame.
void main() {
  final l10n = AppLocalizationsEn();

  Future<_Sync> pump(
    WidgetTester tester,
    Memory memory, {
    bool pin = false,
    bool failed = false,
    double size = 240,
  }) async {
    final sync = _Sync();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncPassphraseProvider.overrideWith(() => _Pin(initial: pin)),
          syncControllerProvider.overrideWith(() => sync),
          syncSealedSeenProvider.overrideWith((ref) => Stream.value(true)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox.square(
                dimension: size,
                child: MemoryAbsent(memory: memory, failed: failed),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return sync;
  }

  testWidgets('not sent yet by the device that took it', (tester) async {
    await pump(tester, _memory());
    expect(find.text(l10n.galleryFileNotSent), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('on the server, but this phone has no PIN: asks for it', (
    tester,
  ) async {
    await pump(tester, _memory(fileHash: 'ab' * 32));
    expect(find.text(l10n.galleryFileNeedsPin), findsOneWidget);
    await tester.tap(find.text(l10n.syncPinSetAction));
    await tester.pumpAndSettle();
    expect(find.byType(SyncPinSheet), findsOneWidget);
  });

  testWidgets('with the PIN and still missing: could not load, try again', (
    tester,
  ) async {
    final sync = await pump(tester, _memory(fileHash: 'ab' * 32), pin: true);
    expect(find.text(l10n.galleryFileFailed), findsOneWidget);
    await tester.tap(find.text(l10n.galleryFileRetry));
    await tester.pump();
    expect(sync.syncs, 1);
  });

  testWidgets('a file here that will not draw could not load either', (
    tester,
  ) async {
    await pump(tester, _memory(), failed: true);
    expect(find.text(l10n.galleryFileFailed), findsOneWidget);
  });

  testWidgets('a thumbnail too small for words keeps them as its label', (
    tester,
  ) async {
    await pump(tester, _memory(), size: 48);
    expect(find.text(l10n.galleryFileNotSent), findsNothing);
    expect(find.bySemanticsLabel(l10n.galleryFileNotSent), findsOneWidget);
  });
}
