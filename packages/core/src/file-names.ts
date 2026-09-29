/**
 * Names and cells an archive can hold on any system ([[Notes]], ADR-007
 * rule 4). The phone's archive writer and the web's share these rules,
 * held to `fixtures/file-names.json`.
 */

/** Longest name before its extension, in code points and in UTF-8 bytes (a file system allows 255 bytes). */
export const maxFileNameCodePoints = 120;
export const maxFileNameBytes = 200;

/** The most characters an Excel cell holds. */
export const maxCellLength = 32767;

const reserved = /^(con|prn|aux|nul|com[0-9]|lpt[0-9])$/i;

function utf8Length(text: string): number {
  let bytes = 0;
  for (const char of text) {
    const code = char.codePointAt(0)!;
    bytes += code < 0x80 ? 1 : code < 0x800 ? 2 : code < 0x10000 ? 3 : 4;
  }
  return bytes;
}

/** A code point that cannot stand in a name: a control character, or a lone half of a surrogate pair. */
function unnamable(code: number): boolean {
  return code < 0x20 || (code >= 0x7f && code <= 0x9f) || (code >= 0xd800 && code <= 0xdfff);
}

function trimEnds(text: string): string {
  return text
    .trim()
    .replace(/^\.+/, '')
    .replace(/[. ]+$/, '')
    .trim();
}

/**
 * A file name that survives every platform: no `\ / : * ? " < > |`,
 * no control characters, no leading or trailing dots, not a name Windows
 * keeps for itself (`CON`, `LPT1`, …), and short enough in code points
 * and in bytes, cut between code points. Empty is `untitled`.
 */
export function safeFileName(title: string): string {
  let cleaned = '';
  for (const char of title.replace(/[\\/:*?"<>|]/g, '-').replace(/\s+/g, ' ')) {
    if (!unnamable(char.codePointAt(0)!)) cleaned += char;
  }
  let name = trimEnds(cleaned);
  const points = [...name];
  if (points.length > maxFileNameCodePoints) points.length = maxFileNameCodePoints;
  while (utf8Length(points.join('')) > maxFileNameBytes) points.pop();
  name = trimEnds(points.join(''));
  if (name === '') return 'untitled';
  const dot = name.indexOf('.');
  const base = dot < 0 ? name : name.slice(0, dot);
  return reserved.test(base) ? `${base}_${name.slice(base.length)}` : name;
}

/** Two paths that name one file on a system that ignores case (Windows, macOS) share this key. */
export function fileNameKey(path: string): string {
  return path.toLowerCase();
}

/**
 * Text a workbook cell can hold: without what XML 1.0 cannot carry
 * (control characters but tab and line breaks, U+FFFE, U+FFFF, a lone
 * half of a surrogate pair), and cut to [maxCellLength] without
 * splitting a pair. The full text of a note is in its `.md` file.
 */
export function cellText(text: string): string {
  let safe = '';
  for (const char of text) {
    const code = char.codePointAt(0)!;
    const control = code < 0x20 && code !== 0x09 && code !== 0x0a && code !== 0x0d;
    if (control || code === 0xfffe || code === 0xffff || (code >= 0xd800 && code <= 0xdfff)) continue;
    safe += char;
  }
  if (safe.length <= maxCellLength) return safe;
  const cut = safe.charCodeAt(maxCellLength - 1);
  return safe.slice(0, cut >= 0xd800 && cut <= 0xdbff ? maxCellLength - 1 : maxCellLength);
}
