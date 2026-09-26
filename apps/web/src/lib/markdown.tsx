import { Fragment, type ReactNode } from 'react';

/**
 * A small markdown renderer that builds React elements and never HTML
 * strings, so nothing in a note or a release body can inject markup.
 *
 * It covers what the Notes spec lists: headings, bold, italic, code,
 * lists, task lists, quotes, tables, links, `[[wiki links]]` and
 * Obsidian's `![[embeds]]`. Anything else passes through as text rather
 * than being silently eaten.
 */

export interface MarkdownOptions {
  /** How a `[[wiki link]]` renders; plain text when absent. */
  renderWikiLink?: (title: string, key: string) => ReactNode;
  /** How an `![[embed]]` renders, a recording say ([[Notes]] N7); its name when absent. */
  renderEmbed?: (name: string, key: string) => ReactNode;
}

const inlinePattern =
  /(`[^`\n]+`)|(\[\[[^[\]\n]+\]\])|(\[[^\]\n]+\]\([^)\s]+\))|(\*\*[^*\n]+\*\*|__[^_\n]+__)|(~~[^~\n]+~~)|(\*[^*\n]+\*|(?<![\w])_[^_\n]+_(?![\w]))|(!\[\[[^[\]\n]+\]\])/g;

function safeHref(url: string): string | null {
  return /^(https?:|mailto:)/i.test(url) ? url : null;
}

export function renderInline(text: string, options: MarkdownOptions = {}, keyPrefix = 'i'): ReactNode[] {
  const nodes: ReactNode[] = [];
  let last = 0;
  let index = 0;
  for (const match of text.matchAll(inlinePattern)) {
    const start = match.index;
    if (start > last) nodes.push(text.slice(last, start));
    const token = match[0];
    const key = `${keyPrefix}-${index++}`;
    if (match[1]) {
      nodes.push(
        <code key={key} className="rounded bg-muted px-1 py-0.5 font-mono text-[0.9em]">
          {token.slice(1, -1)}
        </code>,
      );
    } else if (match[2]) {
      const title = token.slice(2, -2).trim();
      nodes.push(
        options.renderWikiLink ? (
          <Fragment key={key}>{options.renderWikiLink(title, key)}</Fragment>
        ) : (
          <span key={key} className="font-semibold text-primary">
            {title}
          </span>
        ),
      );
    } else if (match[3]) {
      const split = token.indexOf('](');
      const label = token.slice(1, split);
      const href = safeHref(token.slice(split + 2, -1));
      nodes.push(
        href ? (
          <a key={key} href={href} target="_blank" rel="noreferrer noopener" className="text-primary underline">
            {renderInline(label, options, key)}
          </a>
        ) : (
          token
        ),
      );
    } else if (match[4]) {
      nodes.push(<strong key={key}>{renderInline(token.slice(2, -2), options, key)}</strong>);
    } else if (match[5]) {
      nodes.push(<s key={key}>{renderInline(token.slice(2, -2), options, key)}</s>);
    } else if (match[6]) {
      nodes.push(<em key={key}>{renderInline(token.slice(1, -1), options, key)}</em>);
    } else if (match[7]) {
      const name = token.slice(3, -2).trim();
      nodes.push(
        options.renderEmbed ? (
          <Fragment key={key}>{options.renderEmbed(name, key)}</Fragment>
        ) : (
          <span key={key} className="text-muted-foreground">
            {name}
          </span>
        ),
      );
    }
    last = start + token.length;
  }
  if (last < text.length) nodes.push(text.slice(last));
  return nodes;
}

type Block =
  | { kind: 'heading'; level: number; text: string }
  | { kind: 'code'; text: string }
  | { kind: 'quote'; lines: string[] }
  | { kind: 'list'; ordered: boolean; items: { text: string; task: boolean | null }[] }
  | { kind: 'rule' }
  | { kind: 'table'; head: string[]; rows: string[][] }
  | { kind: 'paragraph'; lines: string[] };

/**
 * Line bodies are `[^\n]*` and never `.*`: `.` stops at U+2028/U+2029, so
 * a heading or item holding one would fail here while the paragraph loop
 * still refused the line, and the parser would never move on.
 */
const listItem = /^\s{0,3}([-*+]|\d+[.)])\s+([^\n]*)$/;
const tableDivider = /^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$/;

/** A row's cells, the outer pipes dropped. */
function cellsOf(row: string): string[] {
  const trimmed = row.trim().replace(/^\|/, '').replace(/\|$/, '');
  return trimmed.split('|').map((cell) => cell.trim());
}

/** A table starts with a `|` row and has the `| --- |` divider under it. */
function tableAt(lines: string[], i: number): boolean {
  return /^\s*\|/.test(lines[i] ?? '') && tableDivider.test(lines[i + 1] ?? '') && (lines[i + 1] ?? '').includes('-');
}

export function parseBlocks(source: string): Block[] {
  const lines = source.replace(/\r\n?/g, '\n').split('\n');
  const blocks: Block[] = [];
  let i = 0;
  while (i < lines.length) {
    const line = lines[i]!;
    if (line.trim() === '') {
      i++;
      continue;
    }
    if (/^\s{0,3}```/.test(line)) {
      const body: string[] = [];
      i++;
      while (i < lines.length && !/^\s{0,3}```/.test(lines[i]!)) body.push(lines[i++]!);
      i++;
      blocks.push({ kind: 'code', text: body.join('\n') });
      continue;
    }
    const heading = /^\s{0,3}(#{1,6})\s+([^\n]*)$/.exec(line);
    if (heading) {
      blocks.push({ kind: 'heading', level: heading[1]!.length, text: heading[2]!.replace(/\s+#+\s*$/, '') });
      i++;
      continue;
    }
    if (/^\s{0,3}([-*_])(\s*\1){2,}\s*$/.test(line)) {
      blocks.push({ kind: 'rule' });
      i++;
      continue;
    }
    if (/^\s{0,3}>/.test(line)) {
      const quote: string[] = [];
      while (i < lines.length && /^\s{0,3}>/.test(lines[i]!)) quote.push(lines[i++]!.replace(/^\s{0,3}>\s?/, ''));
      blocks.push({ kind: 'quote', lines: quote });
      continue;
    }
    if (tableAt(lines, i)) {
      const head = cellsOf(line);
      const rows: string[][] = [];
      i += 2;
      while (i < lines.length && /^\s*\|/.test(lines[i]!)) rows.push(cellsOf(lines[i++]!));
      blocks.push({ kind: 'table', head, rows });
      continue;
    }
    const first = listItem.exec(line);
    if (first) {
      const ordered = /\d/.test(first[1]!);
      const items: { text: string; task: boolean | null }[] = [];
      while (i < lines.length) {
        const item = listItem.exec(lines[i]!);
        if (!item || /\d/.test(item[1]!) !== ordered) break;
        const task = /^\[([ xX])\]\s+([^\n]*)$/.exec(item[2]!);
        items.push(task ? { text: task[2]!, task: task[1] !== ' ' } : { text: item[2]!, task: null });
        i++;
      }
      blocks.push({ kind: 'list', ordered, items });
      continue;
    }
    const paragraph: string[] = [];
    while (
      i < lines.length &&
      lines[i]!.trim() !== '' &&
      !/^\s{0,3}(#{1,6}\s|```|>)/.test(lines[i]!) &&
      !listItem.test(lines[i]!) &&
      !tableAt(lines, i)
    ) {
      paragraph.push(lines[i++]!);
    }
    // Every branch above consumes at least one line; should a line slip past
    // them all and be refused here too, it is kept as text and passed, so
    // no input can stall the loop.
    if (paragraph.length === 0) paragraph.push(lines[i++]!);
    blocks.push({ kind: 'paragraph', lines: paragraph });
  }
  return blocks;
}

const headingClass: Record<number, string> = {
  1: 'text-2xl font-extrabold',
  2: 'text-xl font-extrabold',
  3: 'text-lg font-bold',
  4: 'text-base font-bold',
  5: 'text-sm font-bold',
  6: 'text-sm font-bold text-muted-foreground',
};

export function Markdown({ source, options = {}, className }: { source: string; options?: MarkdownOptions; className?: string }) {
  const blocks = parseBlocks(source);
  return (
    <div className={className ?? 'flex flex-col gap-3 leading-relaxed'}>
      {blocks.map((block, index) => {
        const key = `b${index}`;
        switch (block.kind) {
          case 'heading': {
            const Tag = `h${Math.min(block.level + 1, 6)}` as 'h2';
            return (
              <Tag key={key} className={headingClass[block.level]}>
                {renderInline(block.text, options, key)}
              </Tag>
            );
          }
          case 'code':
            return (
              <pre key={key} className="overflow-x-auto rounded-lg bg-muted p-3 font-mono text-sm">
                <code>{block.text}</code>
              </pre>
            );
          case 'quote':
            return (
              <blockquote key={key} className="border-s-4 border-success/60 ps-3 text-muted-foreground">
                {block.lines.map((line, n) => (
                  <p key={n}>{renderInline(line, options, `${key}-${n}`)}</p>
                ))}
              </blockquote>
            );
          case 'list': {
            const Tag = block.ordered ? 'ol' : 'ul';
            return (
              <Tag key={key} className={block.ordered ? 'list-decimal ps-6' : 'list-disc ps-6'}>
                {block.items.map((item, n) =>
                  item.task === null ? (
                    <li key={n}>{renderInline(item.text, options, `${key}-${n}`)}</li>
                  ) : (
                    <li key={n} className="list-none -ms-5 flex items-start gap-2">
                      <input type="checkbox" checked={item.task} readOnly disabled className="mt-1.5" aria-hidden />
                      <span className={item.task ? 'text-muted-foreground line-through' : undefined}>
                        {renderInline(item.text, options, `${key}-${n}`)}
                      </span>
                    </li>
                  ),
                )}
              </Tag>
            );
          }
          case 'rule':
            return <hr key={key} className="border-border" />;
          case 'table':
            return (
              <div key={key} className="overflow-x-auto">
                <table className="w-full border-collapse text-sm">
                  <thead>
                    <tr>
                      {block.head.map((cell, n) => (
                        <th key={n} className="border px-2 py-1 text-start font-bold">
                          {renderInline(cell, options, `${key}-h${n}`)}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {block.rows.map((row, r) => (
                      <tr key={r}>
                        {block.head.map((_, n) => (
                          <td key={n} className="border px-2 py-1 align-top">
                            {renderInline(row[n] ?? '', options, `${key}-${r}-${n}`)}
                          </td>
                        ))}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            );
          case 'paragraph':
            return (
              <p key={key} className="whitespace-pre-wrap">
                {renderInline(block.lines.join('\n'), options, key)}
              </p>
            );
        }
      })}
    </div>
  );
}
