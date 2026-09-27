import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/account/presentation/sync_pin_sheet.dart';
import 'package:harvest/features/gallery/data/memory_files.dart';
import 'package:harvest/features/gallery/domain/gallery.dart';
import 'package:harvest/features/gallery/presentation/memory_view.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:harvest/l10n/app_localizations_en.dart';

class _Pin extends SyncPassphrase {
  _Pin({required this.initial});

  final bool initial;

  @override
  Future<bool> build() async => initial;
}

/// The server's copy of a picture, fetched on demand; each fetch waits
/// on [answer] until the test says how it went.
class _Files implements MemoryFiles {
  final asked = <({String uuid, bool retry, bool again})>[];
  Completer<bool> answer = Completer();

  @override
  Future<bool> fetch(Memory memory, {bool retry = false, bool again = false}) {
    asked.add((uuid: memory.uuid, retry: retry, again: again));
    return answer.future;
  }
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

  Future<_Files> pump(
    WidgetTester tester,
    Memory memory, {
    bool pin = false,
    bool failed = false,
    double size = 240,
  }) async {
    final files = _Files();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncPassphraseProvider.overrideWith(() => _Pin(initial: pin)),
          memoryFilesProvider.overrideWithValue(files),
          syncKeyShareProvider.overrideWith(
            (ref) async => SyncKeyShare(
              salt: 'salt',
              keyShare: Uint8List(32),
              check: const {'v': 2, 'iv': '', 'ct': ''},
            ),
          ),
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
    await tester.pump();
    await tester.pump();
    return files;
  }

  testWidgets('not sent yet by the device that took it', (tester) async {
    await pump(tester, _memory());
    expect(find.text(l10n.galleryFileNotSent), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('on the server, but this phone has no PIN: asks for it', (
    tester,
  ) async {
    final files = await pump(tester, _memory(fileHash: 'ab' * 32));
    expect(find.text(l10n.galleryFileNeedsPin), findsOneWidget);
    expect(files.asked, isEmpty);
    await tester.tap(find.text(l10n.syncPinSetAction));
    await tester.pumpAndSettle();
    expect(find.byType(SyncPinSheet), findsOneWidget);
  });

  testWidgets('on the server, with the PIN: fetched now, on its own '
      '(Q5-26)', (tester) async {
    final files = await pump(tester, _memory(fileHash: 'ab' * 32), pin: true);
    expect(find.text(l10n.galleryFileDownloading), findsOneWidget);
    expect(files.asked, [(uuid: 'm1', retry: false, again: false)]);
    expect(find.text(l10n.galleryFileFailed), findsNothing);
  });

  testWidgets('one that does not come down: could not load, and Try again '
      'fetches that file again', (tester) async {
    final files = await pump(tester, _memory(fileHash: 'ab' * 32), pin: true);
    files.answer.complete(false);
    await tester.pump();
    expect(find.text(l10n.galleryFileFailed), findsOneWidget);

    files.answer = Completer();
    await tester.tap(find.text(l10n.galleryFileRetry));
    await tester.pump();
    expect(files.asked.last, (uuid: 'm1', retry: true, again: false));
    expect(find.text(l10n.galleryFileDownloading), findsOneWidget);
  });

  testWidgets('a file here that will not draw could not load either', (
    tester,
  ) async {
    await pump(tester, _memory(), failed: true);
    expect(find.text(l10n.galleryFileFailed), findsOneWidget);
  });

  testWidgets('one that will not draw, and is on the server, comes down '
      'again on Try again', (tester) async {
    final files = await pump(
      tester,
      _memory(fileHash: 'ab' * 32),
      pin: true,
      failed: true,
    );
    expect(files.asked, isEmpty);
    await tester.tap(find.text(l10n.galleryFileRetry));
    await tester.pump();
    expect(files.asked, [(uuid: 'm1', retry: true, again: true)]);
  });

  testWidgets('a thumbnail too small for words keeps them as its label', (
    tester,
  ) async {
    await pump(tester, _memory(), size: 48);
    expect(find.text(l10n.galleryFileNotSent), findsNothing);
    expect(find.bySemanticsLabel(l10n.galleryFileNotSent), findsOneWidget);
  });
}
