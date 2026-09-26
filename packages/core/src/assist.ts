/**
 * What the assist can do with a note, and exactly what each action
 * asks for ([[ADR-013-Assist-Providers]], [[Notes]]).
 *
 * The prompts live here rather than in either client because they are
 * a rule, not a screen: the phone and the web must ask the same thing
 * of the same model, or the same button gives two different answers.
 * `fixtures/assist.json` pins them, and both sides are read against it.
 */
export const assistActions = [
  'summarise',
  'rewrite',
  'continueWriting',
  'fixGrammar',
  'translate',
  'ask',
  'transcribe',
] as const;
export type AssistAction = (typeof assistActions)[number];

/** Whether an action works on the selection when there is one. */
export function actsOnSelection(action: AssistAction): boolean {
  return action === 'rewrite' || action === 'fixGrammar' || action === 'translate';
}

export interface AssistPromptInput {
  /** The note, or the selection for the actions that take one. */
  text?: string;
  /** The note up to the caret, for Continue. */
  upToCaret?: string;
  /** Mine, for Ask. */
  question?: string;
  /** The app's language, for answers that are not translations. */
  language?: string;
}

export interface AssistPrompt {
  system: string;
  messages: { role: 'user' | 'model'; text: string }[];
  /** Whether this action sends the recording beside the words. */
  wantsAudio: boolean;
}

const base =
  'You help me with my own notes. Answer with the text only: no preamble, ' +
  'no closing remarks, no quotation marks around it. Keep the markdown ' +
  'the note already uses. Never add facts that are not in what I give you.';

/** The request for [action]: exactly what the sheet says will be sent. */
export function assistPrompt(action: AssistAction, input: AssistPromptInput = {}): AssistPrompt {
  const text = input.text ?? '';
  const upToCaret = input.upToCaret ?? '';
  const question = input.question ?? '';
  const answerIn = input.language === 'ar' ? 'Arabic' : 'English';
  const user = (value: string): AssistPrompt['messages'] => [{ role: 'user', text: value }];

  switch (action) {
    case 'summarise':
      return {
        system: `${base} Summarise the note in a few sentences, in the language the note is written in.`,
        messages: user(text),
        wantsAudio: false,
      };
    case 'rewrite':
      return {
        system: `${base} Rewrite this more clearly and simply. Keep the meaning, the language and my voice.`,
        messages: user(text),
        wantsAudio: false,
      };
    case 'continueWriting':
      return {
        system:
          `${base} Continue writing from where the text stops, in the same language, voice and style. ` +
          'Write one paragraph, and do not repeat what is already there.',
        messages: user(upToCaret),
        wantsAudio: false,
      };
    case 'fixGrammar':
      return {
        system:
          `${base} Correct spelling, grammar and punctuation. Change nothing else: ` +
          'not the words I chose, not the order, not the tone.',
        messages: user(text),
        wantsAudio: false,
      };
    case 'translate':
      return {
        system:
          `${base} Translate between English and Arabic: English becomes Arabic, ` +
          'Arabic becomes English. Keep the markdown.',
        messages: user(text),
        wantsAudio: false,
      };
    case 'ask':
      return {
        system:
          `${base} Answer my question using only the note below. ` +
          `If the note does not say, answer that it does not. Answer in ${answerIn}.`,
        messages: user(`Note:\n${text}\n\nQuestion: ${question}`),
        wantsAudio: false,
      };
    case 'transcribe':
      return {
        system:
          `${base} Transcribe the recording word for word, in the language it is spoken in. ` +
          'Mark nothing you cannot hear; skip it.',
        messages: user('Transcribe this recording.'),
        wantsAudio: true,
      };
  }
}
