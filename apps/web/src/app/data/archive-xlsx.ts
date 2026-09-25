import { strFromU8, strToU8, unzipSync, zipSync, type Zippable } from 'fflate';

/**
 * The workbook inside an archive, written and read as plain
 * SpreadsheetML ([[ADR-006-Export-Format]]).
 *
 * Small on purpose: the layout needs text, numbers, booleans, a bold
 * header row and live formulas, and reading needs the cells back as
 * text under their headers. A general spreadsheet library would be
 * most of the bundle for the few parts of the format used here.
 *
 * A port of the phone's `workbook.dart` (writing) and the sheet half
 * of `archive_reader.dart` (reading), so a workbook made by either one
 * opens in the other.
 */

/** A cell holding a live formula instead of a value (rule X3). */
export class Formula {
  constructor(readonly text: string) {}
}

export type CellValue = string | number | boolean | Formula | null;

/**
 * A column whose value is a formula over the row it sits in: `{row}` is
 * the 1-based spreadsheet row, `{Header}` the letter of that column on
 * the same sheet.
 */
export interface DerivedColumn {
  header: string;
  template: string;
}

/** One tab of the workbook, as the phone's `ExportSheet` describes it. */
export class ExportSheet {
  readonly name: string;
  readonly headers: readonly string[];
  readonly rows: CellValue[][];
  readonly derived: readonly DerivedColumn[];
  /** The Summary is a layout, not a table, and labels its own blocks. */
  readonly hasHeaderRow: boolean;

  constructor(options: {
    name: string;
    headers: readonly string[];
    rows: CellValue[][];
    derived?: readonly DerivedColumn[];
    hasHeaderRow?: boolean;
  }) {
    this.name = options.name;
    this.headers = options.headers;
    this.rows = options.rows;
    this.derived = options.derived ?? [];
    this.hasHeaderRow = options.hasHeaderRow ?? true;
  }

  get allHeaders(): string[] {
    return [...this.headers, ...this.derived.map((column) => column.header)];
  }

  /** The letter of [header] here; a formula pointing nowhere is a bug. */
  column(header: string): string {
    const index = this.allHeaders.indexOf(header);
    if (index < 0) throw new Error(`no such column on ${this.name}: ${header}`);
    return columnLetter(index);
  }

  /** The 1-based spreadsheet row of the last data row. */
  get lastRow(): number {
    return this.rows.length + (this.hasHeaderRow ? 1 : 0);
  }
}

/** Spreadsheet column letter for a 0-based index: 0 → A, 26 → AA. */
export function columnLetter(index: number): string {
  let remaining = index;
  let letters = '';
  do {
    letters = String.fromCharCode(65 + (remaining % 26)) + letters;
    remaining = Math.floor(remaining / 26) - 1;
  } while (remaining >= 0);
  return letters;
}

/** The 0-based column index of a letter run: A → 0, AA → 26. */
function columnIndex(letters: string): number {
  let index = 0;
  for (const letter of letters.toUpperCase()) index = index * 26 + (letter.charCodeAt(0) - 64);
  return index - 1;
}

/** Resolves `{Header}` against [sheet] and `{row}` against [row]. */
export function resolveTemplate(template: string, sheet: ExportSheet, row: number): string {
  return template.replace(/\{(\w+)\}/g, (_, name: string) => (name === 'row' ? String(row) : sheet.column(name)));
}

// ------------------------------------------------------------- writing

const xmlHeader = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';
const mainNs = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
const relNs = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const packageRelNs = 'http://schemas.openxmlformats.org/package/2006/relationships';

/**
 * Text as XML can carry it: escaped, and without the control characters
 * XML 1.0 cannot hold at all (or a lone half of a surrogate pair).
 */
function xmlText(text: string): string {
  let safe = '';
  // By code point, so a lone half of a pair shows up on its own.
  for (const char of text) {
    const code = char.codePointAt(0)!;
    const control = code < 0x20 && code !== 0x09 && code !== 0x0a && code !== 0x0d;
    if (control || code === 0xfffe || code === 0xffff || (code >= 0xd800 && code <= 0xdfff)) continue;
    safe += char;
  }
  return safe
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

class SharedStrings {
  private readonly index = new Map<string, number>();
  readonly list: string[] = [];
  count = 0;

  of(text: string): number {
    this.count++;
    const known = this.index.get(text);
    if (known !== undefined) return known;
    const next = this.list.length;
    this.index.set(text, next);
    this.list.push(text);
    return next;
  }

  xml(): string {
    const items = this.list.map((text) => `<si><t xml:space="preserve">${xmlText(text)}</t></si>`).join('');
    return `${xmlHeader}<sst xmlns="${mainNs}" count="${this.count}" uniqueCount="${this.list.length}">${items}</sst>`;
  }
}

function cellXml(ref: string, value: CellValue, strings: SharedStrings, sheet: ExportSheet, row: number, bold = false): string {
  if (value === null) return '';
  const style = bold ? ' s="1"' : '';
  if (value instanceof Formula) {
    // OOXML keeps a formula without its leading `=`; `fullCalcOnLoad`
    // has the spreadsheet compute every value when it opens the file.
    const formula = resolveTemplate(value.text, sheet, row).replace(/^=/, '');
    return `<c r="${ref}"${style}><f>${xmlText(formula)}</f></c>`;
  }
  if (typeof value === 'boolean') return `<c r="${ref}"${style} t="b"><v>${value ? 1 : 0}</v></c>`;
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) return '';
    return `<c r="${ref}"${style}><v>${String(value)}</v></c>`;
  }
  return `<c r="${ref}"${style} t="s"><v>${strings.of(value)}</v></c>`;
}

function sheetXml(sheet: ExportSheet, strings: SharedStrings): string {
  const rows: string[] = [];
  const headers = sheet.allHeaders;
  const offset = sheet.hasHeaderRow ? 1 : 0;
  if (sheet.hasHeaderRow) {
    const cells = headers.map((header, column) => cellXml(`${columnLetter(column)}1`, header, strings, sheet, 1, true));
    rows.push(`<row r="1">${cells.join('')}</row>`);
  }
  sheet.rows.forEach((values, index) => {
    const rowNumber = index + offset + 1;
    const cells: string[] = [];
    for (let column = 0; column < sheet.headers.length; column++) {
      cells.push(cellXml(`${columnLetter(column)}${rowNumber}`, values[column] ?? null, strings, sheet, rowNumber));
    }
    sheet.derived.forEach((derived, extra) => {
      const ref = `${columnLetter(sheet.headers.length + extra)}${rowNumber}`;
      cells.push(cellXml(ref, new Formula(derived.template), strings, sheet, rowNumber));
    });
    rows.push(`<row r="${rowNumber}">${cells.join('')}</row>`);
  });
  // A width per column from its header and a sample of its values, the
  // job the phone's `setColumnAutoFit` does.
  const widths = headers.map((header, column) => {
    let longest = header.length;
    for (const values of sheet.rows.slice(0, 200)) {
      const value = values[column];
      if (typeof value === 'string' || typeof value === 'number') longest = Math.max(longest, String(value).length);
    }
    return Math.min(Math.max(longest + 2, 8), 60);
  });
  const cols =
    widths.length === 0
      ? ''
      : `<cols>${widths.map((width, i) => `<col min="${i + 1}" max="${i + 1}" width="${width}" customWidth="1"/>`).join('')}</cols>`;
  return `${xmlHeader}<worksheet xmlns="${mainNs}" xmlns:r="${relNs}">${cols}<sheetData>${rows.join('')}</sheetData></worksheet>`;
}

const stylesXml =
  `${xmlHeader}<styleSheet xmlns="${mainNs}">` +
  '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>' +
  '<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>' +
  '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>' +
  '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>' +
  '<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>' +
  '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>' +
  '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>' +
  '</styleSheet>';

/**
 * Renders [sheets] into `.xlsx` bytes. Pure: rows in, bytes out, and
 * the same bytes for the same rows ([mtime] pins the zip's clock).
 */
export function buildWorkbook(sheets: ExportSheet[], mtime: Date = new Date('2026-01-01T00:00:00Z')): Uint8Array {
  if (sheets.length === 0) throw new Error('a workbook needs a sheet');
  const strings = new SharedStrings();
  const files: Zippable = {};
  sheets.forEach((sheet, i) => {
    files[`xl/worksheets/sheet${i + 1}.xml`] = strToU8(sheetXml(sheet, strings));
  });
  const sheetList = sheets
    .map((sheet, i) => `<sheet name="${xmlText(sheet.name)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>`)
    .join('');
  files['xl/workbook.xml'] = strToU8(
    `${xmlHeader}<workbook xmlns="${mainNs}" xmlns:r="${relNs}"><bookViews><workbookView activeTab="0"/></bookViews>` +
      `<sheets>${sheetList}</sheets><calcPr calcId="191029" fullCalcOnLoad="1"/></workbook>`,
  );
  const sheetRels = sheets
    .map(
      (_, i) =>
        `<Relationship Id="rId${i + 1}" Type="${relNs}/worksheet" Target="worksheets/sheet${i + 1}.xml"/>`,
    )
    .join('');
  files['xl/_rels/workbook.xml.rels'] = strToU8(
    `${xmlHeader}<Relationships xmlns="${packageRelNs}">${sheetRels}` +
      `<Relationship Id="rId${sheets.length + 1}" Type="${relNs}/styles" Target="styles.xml"/>` +
      `<Relationship Id="rId${sheets.length + 2}" Type="${relNs}/sharedStrings" Target="sharedStrings.xml"/>` +
      '</Relationships>',
  );
  files['xl/styles.xml'] = strToU8(stylesXml);
  files['xl/sharedStrings.xml'] = strToU8(strings.xml());
  files['_rels/.rels'] = strToU8(
    `${xmlHeader}<Relationships xmlns="${packageRelNs}">` +
      `<Relationship Id="rId1" Type="${relNs}/officeDocument" Target="xl/workbook.xml"/></Relationships>`,
  );
  const sheetTypes = sheets
    .map(
      (_, i) =>
        `<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>`,
    )
    .join('');
  files['[Content_Types].xml'] = strToU8(
    `${xmlHeader}<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">` +
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
      '<Default Extension="xml" ContentType="application/xml"/>' +
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
      sheetTypes +
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>' +
      '<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>' +
      '</Types>',
  );
  // The order a spreadsheet expects to meet the parts in.
  const ordered: Zippable = {};
  for (const name of ['[Content_Types].xml', '_rels/.rels', 'xl/workbook.xml', 'xl/_rels/workbook.xml.rels']) ordered[name] = files[name]!;
  for (const [name, data] of Object.entries(files)) if (!(name in ordered)) ordered[name] = data;
  return zipSync(ordered, { level: 6, mtime });
}

// ------------------------------------------------------------- reading

/**
 * One sheet, as a list of maps keyed by its header row: by header
 * rather than by position, so a column added by a later version moves
 * nothing. Empty cells are left out; formula cells are never read.
 */
export type SheetRows = Record<string, string>[];

function elements(parent: Document | Element, name: string): Element[] {
  return Array.from(parent.getElementsByTagNameNS('*', name));
}

function children(parent: Element, name: string): Element[] {
  return Array.from(parent.children).filter((child) => child.localName === name);
}

function parseXml(text: string): Document {
  const document = new DOMParser().parseFromString(text, 'application/xml');
  if (document.getElementsByTagName('parsererror').length > 0) throw new Error('not XML');
  return document;
}

/** Where a relationship's target sits in the package. */
function partPath(target: string): string {
  if (target.startsWith('/')) return target.slice(1);
  const parts: string[] = ['xl'];
  for (const segment of target.split('/')) {
    if (segment === '..') parts.pop();
    else if (segment !== '.' && segment !== '') parts.push(segment);
  }
  return parts.join('/');
}

/** Built-in number formats that are dates or times. */
const dateFormatIds = new Set([14, 15, 16, 17, 18, 19, 20, 21, 22, 45, 46, 47]);

function isDateFormat(code: string): boolean {
  // Quoted text and bracketed colours or conditions say nothing about dates.
  const bare = code.replace(/"[^"]*"/g, '').replace(/\[[^\]]*\]/g, '');
  return /[dmyhs]/i.test(bare) && !/^general$/i.test(bare.trim());
}

/**
 * A spreadsheet date serial as the wall-clock text a date cell means:
 * a person who opened the file and saved it may have turned an ISO
 * column into real dates, and those must read as their dates, not as
 * now ([[Audit-v2-Beta]] Q2-07).
 */
function serialToText(serial: number): string {
  const millis = Math.round((serial - 25569) * 86_400_000);
  return new Date(millis).toISOString().slice(0, 23);
}

/** One sheet as read: its header row, and the rows under it. */
export interface ReadSheet {
  headers: string[];
  rows: SheetRows;
}

/**
 * Reads every sheet of an `.xlsx` into rows keyed by header.
 * Throws when the bytes are not a workbook.
 */
export function readWorkbook(bytes: Uint8Array): Map<string, SheetRows> {
  return new Map([...parseWorkbook(bytes)].map(([name, sheet]) => [name, sheet.rows]));
}

/** [readWorkbook], with each sheet's header row kept in its order. */
export function parseWorkbook(bytes: Uint8Array): Map<string, ReadSheet> {
  const parts = unzipSync(bytes, { filter: (file) => file.name.startsWith('xl/') || file.name === '[Content_Types].xml' });
  const text = (name: string): string | null => {
    const part = parts[name];
    return part ? strFromU8(part) : null;
  };
  const workbookText = text('xl/workbook.xml');
  if (workbookText === null) throw new Error('no workbook part');
  const workbook = parseXml(workbookText);

  const targets = new Map<string, string>();
  let sharedTarget = 'xl/sharedStrings.xml';
  let stylesTarget = 'xl/styles.xml';
  const relsText = text('xl/_rels/workbook.xml.rels');
  if (relsText !== null) {
    for (const rel of elements(parseXml(relsText), 'Relationship')) {
      const id = rel.getAttribute('Id');
      const target = rel.getAttribute('Target');
      const type = rel.getAttribute('Type') ?? '';
      if (!target) continue;
      if (type.endsWith('/sharedStrings')) sharedTarget = partPath(target);
      else if (type.endsWith('/styles')) stylesTarget = partPath(target);
      else if (id) targets.set(id, partPath(target));
    }
  }

  const shared: string[] = [];
  const sharedText = text(sharedTarget);
  if (sharedText !== null) {
    for (const item of elements(parseXml(sharedText), 'si')) {
      // Rich runs are concatenated; phonetic guides are not the text.
      const runs = elements(item, 't').filter((t) => t.parentElement?.localName !== 'rPh');
      shared.push(runs.map((t) => t.textContent ?? '').join(''));
    }
  }

  const dateStyles = new Set<number>();
  const stylesText = text(stylesTarget);
  if (stylesText !== null) {
    const styles = parseXml(stylesText);
    const custom = new Map<number, string>();
    for (const format of elements(styles, 'numFmt')) {
      custom.set(Number(format.getAttribute('numFmtId')), format.getAttribute('formatCode') ?? '');
    }
    const cellXfs = elements(styles, 'cellXfs')[0];
    if (cellXfs) {
      children(cellXfs, 'xf').forEach((xf, index) => {
        const id = Number(xf.getAttribute('numFmtId') ?? '0');
        const code = custom.get(id);
        if (dateFormatIds.has(id) || (code !== undefined && isDateFormat(code))) dateStyles.add(index);
      });
    }
  }

  const sheets = new Map<string, ReadSheet>();
  for (const entry of elements(workbook, 'sheet')) {
    const name = entry.getAttribute('name');
    const id = entry.getAttributeNS(relNs, 'id') ?? entry.getAttribute('r:id');
    const path = id ? targets.get(id) : undefined;
    const sheetText = path ? text(path) : null;
    if (name === null || sheetText === null) continue;
    const grid = new Map<number, Map<number, string>>();
    for (const row of elements(parseXml(sheetText), 'row')) {
      const rowNumber = Number(row.getAttribute('r'));
      if (!Number.isInteger(rowNumber) || rowNumber < 1) continue;
      const cells = new Map<number, string>();
      let next = 0;
      for (const cell of children(row, 'c')) {
        const ref = /^([A-Z]+)\d*$/i.exec(cell.getAttribute('r') ?? '');
        const column = ref ? columnIndex(ref[1]!) : next;
        next = column + 1;
        const value = cellText(cell, shared, dateStyles);
        if (value !== null && value !== '') cells.set(column, value);
      }
      grid.set(rowNumber, cells);
    }
    if (grid.size === 0) continue;
    const headerCells = grid.get(1) ?? new Map<number, string>();
    const headers = new Map<number, string>(headerCells);
    const parsed: SheetRows = [];
    const numbers = [...grid.keys()].filter((n) => n > 1).sort((a, b) => a - b);
    for (const number of numbers) {
      const values: Record<string, string> = {};
      let any = false;
      for (const [column, value] of grid.get(number)!) {
        const header = headers.get(column);
        if (!header) continue;
        values[header] = value;
        any = true;
      }
      if (any) parsed.push(values);
    }
    const width = headers.size === 0 ? 0 : Math.max(...headers.keys()) + 1;
    sheets.set(name, { headers: Array.from({ length: width }, (_, i) => headers.get(i) ?? ''), rows: parsed });
  }
  return sheets;
}

/** A cell as text, whatever the spreadsheet stored it as; null for a formula. */
function cellText(cell: Element, shared: string[], dateStyles: Set<number>): string | null {
  const type = cell.getAttribute('t');
  const v = children(cell, 'v')[0]?.textContent ?? null;
  switch (type) {
    case 's':
      return v === null ? null : (shared[Number(v)] ?? '').trim();
    case 'b':
      return v === null ? null : v.trim() === '1' || v.trim().toLowerCase() === 'true' ? 'true' : 'false';
    case 'inlineStr':
      return elements(cell, 't')
        .map((t) => t.textContent ?? '')
        .join('')
        .trim();
    case 'str':
    case 'e':
      // A formula's cached result, or an error: never data.
      return null;
    default: {
      if (children(cell, 'f').length > 0) return null;
      if (v === null) return null;
      const trimmed = v.trim();
      const style = Number(cell.getAttribute('s') ?? '0');
      const number = Number(trimmed);
      if (dateStyles.has(style) && trimmed !== '' && Number.isFinite(number)) return serialToText(number);
      return trimmed;
    }
  }
}
