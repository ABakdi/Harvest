import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/notes/domain/voice.dart';

/// Phase 5, M5.5: recordings in notes, and notes read aloud.
void main() {
  group('embeds (N7)', () {
    test('finds the recordings a body embeds, and nothing else', () {
      const body = '''
Walked home.
![[Voice 2026-09-19 14-32.m4a]]
![[picture.png]]
and later ![[ Voice 2026-09-19 18-01.M4A ]] too''';
      expect(audioEmbedsIn(body), [
        'Voice 2026-09-19 14-32.m4a',
        'Voice 2026-09-19 18-01.M4A',
      ]);
    });

    test('names a recording by its minute, with a counter when taken', () {
      final at = DateTime(2026, 9, 19, 14, 32);
      expect(voiceFileName(at), 'Voice 2026-09-19 14-32.m4a');
      expect(
        voiceFileName(at, taken: {'Voice 2026-09-19 14-32.m4a'}),
        'Voice 2026-09-19 14-32 (2).m4a',
      );
      expect(voiceNoteTitle(at), 'Voice 2026-09-19 14-32');
    });
  });

  group('read aloud (N10)', () {
    test('drops the markdown and keeps the words, by paragraph', () {
      const note = '''
# Sleep

I went to **bed** at _eleven_, see [[Sleep log|the log]].
- [x] no coffee
- read [a book](https://example.org)

![[Voice 2026-09-19 14-32.m4a]]
```
code is not read
```
> Quiet.''';
      expect(speechParagraphs(note), [
        'Sleep',
        'I went to bed at eleven, see the log. no coffee read a book',
        'Quiet.',
      ]);
    });

    test('Arabic text is read in Arabic, the rest in the app language', () {
      expect(speechLanguageOf('ذهبت إلى النوم مبكرًا', fallback: 'en'), 'ar');
      expect(speechLanguageOf('Slept early', fallback: 'en'), 'en');
      expect(speechLanguageOf('123', fallback: 'fr'), 'fr');
    });
  });
}
