import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/assist/domain/assist.dart';

void main() {
  test('a recording is sent as what its extension says it is', () {
    expect(AssistAudio.mimeTypeFor('Standup.m4a'), 'audio/mp4');
    expect(AssistAudio.mimeTypeFor('memo.MP3'), 'audio/mpeg');
    expect(AssistAudio.mimeTypeFor('voice.opus'), 'audio/ogg');
    expect(AssistAudio.mimeTypeFor('take.wav'), 'audio/wav');
    expect(AssistAudio.mimeTypeFor('notes.txt'), isNull);
    expect(AssistAudio.mimeTypeFor('no-extension'), isNull);
  });

  test('the cap is the one the server takes', () {
    expect(AssistAudio.maxBytes, 8 * 1024 * 1024);
  });
}
