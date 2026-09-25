import { describe, expect, it } from 'vitest';
import { parseBlocks } from '../src/lib/markdown';

describe('parseBlocks always moves on', () => {
  it('reads a heading holding a line separator', () => {
    const blocks = parseBlocks('# a b');
    expect(blocks).toEqual([{ kind: 'heading', level: 1, text: 'a b' }]);
  });

  it('reads a heading holding a paragraph separator', () => {
    const blocks = parseBlocks('## a b\nafter');
    expect(blocks[0]).toEqual({ kind: 'heading', level: 2, text: 'a b' });
    expect(blocks[1]).toEqual({ kind: 'paragraph', lines: ['after'] });
  });

  it('reads list and task items holding separators', () => {
    const blocks = parseBlocks('- one two\n- [x] done now');
    expect(blocks).toEqual([
      {
        kind: 'list',
        ordered: false,
        items: [
          { text: 'one two', task: null },
          { text: 'done now', task: true },
        ],
      },
    ]);
  });

  it('terminates on odd lines', () => {
    const pieces = ['#', '# ', '# ', ' ', ' ', ' ', '-', '- ', '1.', '1) ', '>', '|', '| - |', '---', '```', '[ ]', '[x]', '\t', 'a', '*', '_', '~', '​', '﻿', '#######', ' #', '   '];
    let seed = 7;
    const next = () => {
      seed = (seed * 1103515245 + 12345) % 2147483648;
      return seed;
    };
    for (let run = 0; run < 400; run++) {
      const lines: string[] = [];
      const count = 1 + (next() % 6);
      for (let l = 0; l < count; l++) {
        let line = '';
        const parts = 1 + (next() % 4);
        for (let p = 0; p < parts; p++) line += pieces[next() % pieces.length];
        lines.push(line);
      }
      const source = lines.join('\n');
      // A stalled parser never returns; returning at all is the assertion.
      expect(Array.isArray(parseBlocks(source))).toBe(true);
    }
    for (const piece of pieces) expect(Array.isArray(parseBlocks(piece))).toBe(true);
  });
});
