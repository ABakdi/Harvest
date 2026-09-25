/**
 * The table edits the toolbar performs, ported from the phone's
 * `markdown_actions.dart`: pure functions from (text, selection) to
 * (text, selection), so what a button does to a body is testable
 * without a textarea.
 */

/** A body and where the caret is in it. */
export interface Edit {
  text: string;
  start: number;
  end: number;
}

/** A three-column starter table, caret in the first header cell. */
export const starterTable = '| Column | Column | Column |\n| --- | --- | --- |\n|  |  |  |';

function lineAround(at: Edit): [number, number] {
  const from = at.text.lastIndexOf('\n', at.start === 0 ? 0 : at.start - 1) + 1;
  const next = at.text.indexOf('\n', at.end);
  return [at.start === 0 ? 0 : from, next < 0 ? at.text.length : next];
}

/** Inserts the starter table on a line of its own, "Column" selected. */
export function insertTable(at: Edit): Edit {
  const [from, to] = lineAround(at);
  const onBlankLine = at.text.slice(from, to).trim() === '';
  const lead = onBlankLine ? '' : '\n';
  const text = at.text.slice(0, at.start) + lead + starterTable + '\n' + at.text.slice(at.end);
  const start = at.start + lead.length + 2;
  return { text, start, end: start + 6 };
}

/**
 * The rows of the table the caret is in, or null when it is not in one.
 * A table is a run of lines that all start with `|`.
 */
export function tableAt(at: Edit): { start: number; end: number; rows: string[] } | null {
  const lines = at.text.split('\n');
  let offset = 0;
  let caretLine = -1;
  const bounds: [number, number][] = [];
  for (let i = 0; i < lines.length; i++) {
    const end = offset + lines[i]!.length;
    bounds.push([offset, end]);
    if (caretLine < 0 && at.start <= end) caretLine = i;
    offset = end + 1;
  }
  if (caretLine < 0) return null;
  const isRow = (i: number) => i >= 0 && i < lines.length && lines[i]!.trimStart().startsWith('|');
  if (!isRow(caretLine)) return null;
  let first = caretLine;
  while (isRow(first - 1)) first--;
  let last = caretLine;
  while (isRow(last + 1)) last++;
  return { start: bounds[first]![0], end: bounds[last]![1], rows: lines.slice(first, last + 1) };
}

function cellsOf(row: string): string[] {
  const trimmed = row.trim();
  return trimmed.slice(trimmed.startsWith('|') ? 1 : 0, trimmed.endsWith('|') ? trimmed.length - 1 : trimmed.length).split('|');
}

/**
 * The `| --- | --- |` line under a header. It has to hold a dash: an
 * empty row is not the divider, or adding a column would fill every
 * empty cell with dashes.
 */
function isDivider(row: string): boolean {
  return /^\s*\|[\s:|-]*-[\s:|-]*\|\s*$/.test(row);
}

/** Adds an empty row at the end of the table, caret in its first cell. */
export function addTableRow(at: Edit): Edit | null {
  const table = tableAt(at);
  if (!table) return null;
  const columns = cellsOf(table.rows[0]!).length;
  const row = `|${Array.from({ length: columns }, () => '  ').join('|')}|`;
  const rows = [...table.rows, row];
  const text = at.text.slice(0, table.start) + rows.join('\n') + at.text.slice(table.end);
  const caret = table.start + rows.slice(0, -1).reduce((sum, r) => sum + r.length + 1, 0) + 2;
  return { text, start: caret, end: caret };
}

/** Adds a column to every row, the divider included. */
export function addTableColumn(at: Edit): Edit | null {
  const table = tableAt(at);
  if (!table) return null;
  const rows = table.rows.map((row) => (isDivider(row) ? `${row.trimEnd()} --- |` : `${row.trimEnd()}   |`));
  const text = at.text.slice(0, table.start) + rows.join('\n') + at.text.slice(table.end);
  return { text, start: at.start, end: at.end };
}
