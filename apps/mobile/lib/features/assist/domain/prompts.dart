import 'package:harvest/features/assist/domain/assist.dart';

/// What the assist can do with a note ([[Notes]] — assist).
enum AssistAction {
  summarise,
  rewrite,
  continueWriting,
  fixGrammar,
  translate,
  ask,
  transcribe,
}

/// Whether an action works on the selection when there is one.
bool actsOnSelection(AssistAction action) => switch (action) {
  AssistAction.rewrite ||
  AssistAction.fixGrammar ||
  AssistAction.translate => true,
  _ => false,
};

const _base =
    'You help me with my own notes. Answer with the text only: no preamble, '
    'no closing remarks, no quotation marks around it. Keep the markdown '
    'the note already uses. Never add facts that are not in what I give you.';

/// The request for [action]: exactly what the sheet says will be sent.
///
/// [text] is the note, or the selection for the actions that take one;
/// [upToCaret] is the note up to the caret, for Continue; [question] is
/// mine, for Ask; [language] is the app's, for answers that are not
/// translations.
AssistRequest buildRequest(
  AssistAction action, {
  required String text,
  String upToCaret = '',
  String question = '',
  String language = 'en',
  AssistAudio? audio,
}) {
  final answerIn = language == 'ar' ? 'Arabic' : 'English';
  return switch (action) {
    AssistAction.summarise => AssistRequest(
      system:
          '$_base Summarise the note in a few sentences, in the language '
          'the note is written in.',
      messages: [AssistMessage.user(text)],
    ),
    AssistAction.rewrite => AssistRequest(
      system:
          '$_base Rewrite this more clearly and simply. Keep the meaning, '
          'the language and my voice.',
      messages: [AssistMessage.user(text)],
    ),
    AssistAction.continueWriting => AssistRequest(
      system:
          '$_base Continue writing from where the text stops, in the same '
          'language, voice and style. Write one paragraph, and do not '
          'repeat what is already there.',
      messages: [AssistMessage.user(upToCaret)],
    ),
    AssistAction.fixGrammar => AssistRequest(
      system:
          '$_base Correct spelling, grammar and punctuation. Change nothing '
          'else: not the words I chose, not the order, not the tone.',
      messages: [AssistMessage.user(text)],
    ),
    AssistAction.translate => AssistRequest(
      system:
          '$_base Translate between English and Arabic: English becomes '
          'Arabic, Arabic becomes English. Keep the markdown.',
      messages: [AssistMessage.user(text)],
    ),
    AssistAction.ask => AssistRequest(
      system:
          '$_base Answer my question using only the note below. If the note '
          'does not say, answer that it does not. Answer in $answerIn.',
      messages: [AssistMessage.user('Note:\n$text\n\nQuestion: $question')],
    ),
    AssistAction.transcribe => AssistRequest(
      system:
          '$_base Transcribe the recording word for word, in the language '
          'it is spoken in. Mark nothing you cannot hear; skip it.',
      messages: const [AssistMessage.user('Transcribe this recording.')],
      audio: audio,
    ),
  };
}
