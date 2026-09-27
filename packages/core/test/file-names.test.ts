import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { cellText, fileNameKey, safeFileName } from '../src/index.js';

/** `fixtures/file-names.json`, which the phone's archive writer is held to as well. */
const data = JSON.parse(readFileSync(new URL('../fixtures/file-names.json', import.meta.url), 'utf8')) as {
  safeFileName: { title: string; name: string; why?: string }[];
  cellText: {
    why: string;
    text?: string;
    cell?: string;
    prefix?: string;
    repeat?: string;
    times?: number;
    length?: number;
  }[];
  sameFile: { a: string; b: string; same: boolean }[];
};

describe('file-names.json', () => {
  it.each(data.safeFileName)('safeFileName($title) is $name', ({ title, name }) => {
    expect(safeFileName(title)).toBe(name);
  });

  it.each(data.cellText)('cellText: $why', ({ text, cell, prefix, repeat, times, length }) => {
    const input = text ?? (prefix ?? '') + (repeat ?? '').repeat(times ?? 0);
    const out = cellText(input);
    if (cell !== undefined) expect(out).toBe(cell);
    if (length !== undefined) expect(out.length).toBe(length);
    // No lone half of a surrogate pair is left behind.
    expect(out).not.toMatch(/[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/);
  });

  it.each(data.sameFile)('$a and $b are the same file: $same', ({ a, b, same }) => {
    expect(fileNameKey(a) === fileNameKey(b)).toBe(same);
  });
});
