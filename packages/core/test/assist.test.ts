import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { actsOnSelection, assistActions, assistPrompt, type AssistAction, type AssistPrompt, type AssistPromptInput } from '../src/index.js';

/**
 * The prompts are a rule: the same button on the phone and on the web
 * must ask the same thing of the same model, or one screen quietly
 * answers differently from the other ([[ADR-013-Assist-Providers]]).
 * This is the fixture the Dart test reads too.
 */
const spec = JSON.parse(
  readFileSync(new URL('../fixtures/assist.json', import.meta.url), 'utf8'),
) as {
  cases: {
    why: string;
    action: AssistAction;
    input: AssistPromptInput;
    actsOnSelection: boolean;
    prompt: AssistPrompt;
  }[];
};

describe('the assist prompts', () => {
  it.each(spec.cases)('$why', ({ action, input, prompt, actsOnSelection: selection }) => {
    expect(assistPrompt(action, input)).toEqual(prompt);
    expect(actsOnSelection(action)).toBe(selection);
  });

  it('covers every action the app offers', () => {
    expect(spec.cases.map((one) => one.action)).toEqual([...assistActions]);
  });

  it('only the transcription wants the recording', () => {
    const wanting = spec.cases.filter((one) => one.prompt.wantsAudio).map((one) => one.action);
    expect(wanting).toEqual(['transcribe']);
  });
});
