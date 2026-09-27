import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/commitments/presentation/project_done.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// A log that completes a project and was cut at its target says what
/// was left out in the completion dialog, which takes the snackbar's
/// place.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final ar = lookupAppLocalizations(const Locale('ar'));

  test('a cut log that completes the project names what was left out', () {
    final message = projectDoneText(
      en,
      title: 'Read 100 pages',
      total: 100,
      logged: 15,
      dropped: 3,
    );
    expect(message, contains('100 logged'));
    expect(message, endsWith('15 logged; 3 over the target left out.'));
    expect(
      projectDoneText(
        ar,
        title: 'قراءة',
        total: 100,
        logged: 15,
        dropped: 3,
      ),
      contains('15'),
    );
  });

  test('a log that fits says only that the project is done', () {
    expect(
      projectDoneText(en, title: 'Read', total: 100, logged: 15, dropped: 0),
      en.projectDoneBody('Read', 100),
    );
  });
}
