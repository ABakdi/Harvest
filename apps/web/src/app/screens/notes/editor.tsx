import { maxFileBytes } from '@harvest/contracts';
import { actsOnSelection, assistActions, type AssistAction } from '@harvest/core';
import { useQuery } from '@tanstack/react-query';
import {
  ArrowUpRightIcon,
  AudioLinesIcon,
  BookOpenIcon,
  CornerDownLeftIcon,
  EllipsisVerticalIcon,
  FolderInputIcon,
  MicIcon,
  MicVocalIcon,
  PaperclipIcon,
  PencilLineIcon,
  PlusIcon,
  PrinterIcon,
  SparklesIcon,
  TableIcon,
  Volume2Icon,
  BoldIcon,
  CodeIcon,
  FolderIcon,
  HeadingIcon,
  ItalicIcon,
  LinkIcon,
  ListChecksIcon,
  ListIcon,
  QuoteIcon,
  Trash2Icon,
} from 'lucide-react';
import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState, type PointerEvent, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { Link, useLocation, useNavigate } from 'react-router';
import { toast } from 'sonner';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { formatBytes, formatDate, formatNumber } from '@/lib/format';
import { Markdown, type MarkdownOptions } from '@/lib/markdown';
import { dropDraft, keepDraft } from '@/lib/note-drafts';
import { registerPendingEdit } from '@/lib/pending-edits';
import { cn } from '@/lib/utils';
import { AppBarActions, AppBarTitle } from '../../components/app-bar';
import { AssistDialog, type AssistTarget } from '../../components/assist-dialog';
import { keyboardUp } from '../../components/keyboard';
import { LocationNote } from '../../components/location-note';
import { addTableColumn, addTableRow, insertTable, tableAt, type Edit } from '../../components/notes/markdown-actions';
import { NotePrint } from '../../components/notes/note-print';
import { ReadAloudDialog } from '../../components/notes/read-aloud-dialog';
import { RecordingDialog } from '../../components/notes/recording-dialog';
import { Recordings } from '../../components/notes/recordings';
import { canSpeak, localDictation, recordingFormat, type Recognition } from '../../components/notes/voice';
import { useHarvest } from '../../context';
import { assistStatus } from '../../data/assist';
import { placeTranscript } from '../../data/transcribe';
import { attachmentFileName, audioEmbed, audioExtensionOf, voiceNoteTitle } from '../../data/attachments';
import { FileTooLargeError } from '../../data/files';
import { linksIn, maxNoteBody, notePreview, type NoteRow } from '../../data/notes';
import { background, runAction } from '@/lib/actions';
import { useDocumentTitle } from '@/lib/title';
import { MoveToFolderDialog } from './folders';
import type { VaultActions } from './sidebar';
import type { Vault } from './vault';

/** A note by the title a link names: exactly, then ignoring case. */
function byTitle(notes: NoteRow[], title: string): NoteRow | undefined {
  return notes.find((note) => note.title === title) ?? notes.find((note) => note.title.toLowerCase() === title.toLowerCase());
}

function useOpenTitle(notes: NoteRow[], replace: boolean) {
  const { t } = useTranslation();
  const { notes: repo } = useHarvest();
  const navigate = useNavigate();
  const [asking, setAsking] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const openTitle = useCallback(
    (title: string) => {
      const target = byTitle(notes, title);
      if (target) {
        background(navigate(`/app/records/${target.uuid}`, { replace }));
        return;
      }
      // A link to a note not written yet offers to write it, as the
      // phone does, rather than writing it on a click ([[Audit-v3]] G5-09).
      setAsking(title);
    },
    [notes, navigate, replace],
  );
  const create = async () => {
    if (asking === null || busy) return;
    // Held while it runs: a double click is one note, not two with one
    // title. At the top of the vault, where the phone puts it.
    setBusy(true);
    try {
      const existing = byTitle(notes, asking);
      const target = existing ?? (await repo.create({ title: asking, folder: '' }));
      setAsking(null);
      background(navigate(`/app/records/${target.uuid}`, { replace }));
    } catch {
      toast.error(t('common.saveFailed'));
    } finally {
      setBusy(false);
    }
  };
  const prompt = (
    <Dialog open={asking !== null} onOpenChange={(open) => !open && !busy && setAsking(null)}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('notes.createLinkTitle', { title: asking ?? '' })}</DialogTitle>
          <DialogDescription>{t('notes.createLinkBody')}</DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <Button variant="outline" onClick={() => setAsking(null)} disabled={busy}>
            {t('common.cancel')}
          </Button>
          <Button onClick={() => runAction(() => create())} disabled={busy}>
            {t('common.create')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
  return { openTitle, prompt };
}

/** Wraps the selection in [before]/[after], or starts each selected line with [prefix]. */
function applyFormat(area: HTMLTextAreaElement, format: { wrap?: [string, string]; prefix?: string }): string {
  const { selectionStart: start, selectionEnd: end, value } = area;
  if (format.wrap) {
    const [before, after] = format.wrap;
    return value.slice(0, start) + before + value.slice(start, end) + after + value.slice(end);
  }
  const lineStart = value.lastIndexOf('\n', start - 1) + 1;
  const block = value.slice(lineStart, end);
  const prefixed = block
    .split('\n')
    .map((line) => format.prefix! + line)
    .join('\n');
  return value.slice(0, lineStart) + prefixed + value.slice(end);
}

/** Where line [line] of [text] starts. */
export function offsetOfLine(text: string, line: number): number {
  let at = 0;
  for (let i = 0; i < line; i++) {
    const next = text.indexOf('\n', at);
    if (next < 0) return text.length;
    at = next + 1;
  }
  return at;
}

/** The `[[links]]` on the line the caret is on, so a phone can follow them from a chip (`_linksOnLine`). */
export function linksOnLine(text: string, caret: number): string[] {
  const start = text.lastIndexOf('\n', caret === 0 ? 0 : caret - 1) + 1;
  const next = text.indexOf('\n', caret);
  return [...new Set(linksIn(text.slice(start, next < 0 ? text.length : next)).map((link) => link.title))];
}

const fieldSizing = typeof CSS !== 'undefined' && typeof CSS.supports === 'function' && CSS.supports('field-sizing', 'content');

/**
 * The text area grows with the note, so the pane scrolls and not the
 * field. Browsers without `field-sizing` measure it; the pane keeps its
 * place while they do.
 */
function growField(field: HTMLTextAreaElement | null) {
  if (!field || fieldSizing) return;
  const pane = field.closest<HTMLElement>('[data-note-scroller]');
  const top = pane?.scrollTop ?? 0;
  field.style.height = '0px';
  field.style.height = `${field.scrollHeight}px`;
  if (pane) pane.scrollTop = top;
}

/** A button of the formatting bar; on a phone a tap keeps the caret in the field. */
function ToolButton({
  label,
  icon,
  phone,
  pressed,
  onClick,
}: {
  label: string;
  icon: ReactNode;
  phone: boolean;
  pressed?: boolean | undefined;
  onClick: () => void;
}) {
  return (
    <Button
      variant="ghost"
      size="icon-sm"
      className={phone ? 'size-11 shrink-0' : 'size-7 shrink-0 text-muted-foreground hover:text-foreground'}
      aria-label={label}
      title={label}
      aria-pressed={pressed}
      onClick={onClick}
      onPointerDown={phone ? (event: PointerEvent) => event.preventDefault() : undefined}
    >
      {icon}
    </Button>
  );
}

/**
 * How far down [field] the text before [at] reaches, measured on a copy
 * laid out as the field is: where the caret's line sits.
 */
function caretTop(field: HTMLTextAreaElement, at: number): number {
  const style = getComputedStyle(field);
  const mirror = document.createElement('div');
  for (const name of ['font', 'letterSpacing', 'lineHeight', 'padding', 'border', 'boxSizing', 'direction', 'tabSize', 'textIndent', 'wordSpacing'] as const) {
    mirror.style[name] = style[name];
  }
  Object.assign(mirror.style, { position: 'absolute', top: '0', left: '-9999px', visibility: 'hidden', whiteSpace: 'pre-wrap', overflowWrap: 'break-word', width: `${field.clientWidth}px` });
  mirror.textContent = field.value.slice(0, at);
  const marker = document.createElement('span');
  marker.textContent = '\u200b';
  mirror.append(marker);
  document.body.append(mirror);
  const top = marker.offsetTop;
  mirror.remove();
  return top;
}

/** How far the on-screen keyboard reaches up the window, so the toolbar can sit on it, as the phone's does. */
function useKeyboardInset(active: boolean): number {
  const [inset, setInset] = useState(0);
  useEffect(() => {
    const viewport = window.visualViewport;
    if (!active || !viewport) return;
    // Only a keyboard counts: a window a scrollbar or a bar shaves a
    // few pixels off is not one, and moving for it would move the
    // window again.
    const update = () =>
      setInset(
        keyboardUp(viewport.height, window.innerHeight, document.activeElement)
          ? Math.max(0, Math.round(window.innerHeight - viewport.height - viewport.offsetTop))
          : 0,
      );
    update();
    viewport.addEventListener('resize', update);
    viewport.addEventListener('scroll', update);
    return () => {
      viewport.removeEventListener('resize', update);
      viewport.removeEventListener('scroll', update);
      setInset(0);
    };
  }, [active]);
  return inset;
}

export function Editor({
  note,
  vault,
  phone,
  actions,
  onRemoved,
}: {
  note: NoteRow;
  vault: Vault;
  /** The phone's layout: the note in place, its actions up in the app bar. */
  phone: boolean;
  actions: VaultActions;
  /** The note went to the trash from here. */
  onRemoved: () => void;
}) {
  const { t, i18n } = useTranslation();
  const { notes, attachments, files, clock } = useHarvest();
  const location = useLocation();
  // The assist is the server's or nothing: a key pasted into a browser
  // is a key in everyone's browser ([[ADR-013-Assist-Providers]]).
  const assist = useQuery({ queryKey: ['assist-status'], queryFn: assistStatus, staleTime: 60_000 });
  const [asking, setAsking] = useState<AssistTarget | null>(null);
  const navigate = useNavigate();
  const [title, setTitle] = useState(note.title);
  useDocumentTitle(title || t('notes.untitled'));
  const [folder, setFolder] = useState(note.folder);
  const [body, setBody] = useState(note.body);
  // A wide window reads a written note and writes an empty one, with a
  // switch between; the phone writes where it reads (`editing`).
  const [mode, setMode] = useState<'write' | 'read'>(note.body ? 'read' : 'write');
  const [editing, setEditing] = useState(false);
  const area = useRef<HTMLTextAreaElement>(null);
  const toolbar = useRef<HTMLDivElement>(null);
  const paneRef = useRef<HTMLDivElement>(null);
  // Where the caret was when the field last had it: a recording, a
  // dictation or the assist lands there after the field has gone.
  const lastSelection = useRef<{ start: number; end: number } | null>(null);
  const [caretAt, setCaretAt] = useState<number | null>(null);
  const pending = useRef<{ title: string; folder: string; body: string; at: string } | null>(null);
  const warnedLong = useRef(false);
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const seen = useRef(note.updatedAt);
  const [inTable, setInTable] = useState(false);
  const [recording, setRecording] = useState<boolean>(() => Boolean((location.state as { record?: boolean } | null)?.record));
  const [reading, setReading] = useState(false);
  const [moving, setMoving] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [pickingAssist, setPickingAssist] = useState(false);
  // What is printed is taken when *Export PDF* is chosen, after the
  // pending save has landed: never a copy short of the last keystrokes
  // (Q5-53).
  const [printing, setPrinting] = useState<NoteRow | null>(null);
  const dictation = useRef<Recognition | null>(null);
  const [canDictate, setCanDictate] = useState(false);
  const [dictating, setDictating] = useState(false);
  const attachInput = useRef<HTMLInputElement>(null);
  const canRecord = recordingFormat() !== null;
  const writingHere = phone ? editing || !body.trim() : mode === 'write';
  useLayoutEffect(() => growField(area.current), [body, writingHere]);
  const keyboard = useKeyboardInset(phone && editing);

  const flush = useCallback(async () => {
    clearTimeout(timer.current);
    const changes = pending.current;
    pending.current = null;
    if (!changes) return;
    const { at, ...edit } = changes;
    await notes.update(note.uuid, edit);
    dropDraft(note.uuid, at);
    // A recording whose line was deleted goes to the trash with this save (N7).
    await attachments.reconcile(note.uuid, changes.body);
  }, [notes, attachments, note.uuid]);

  // Dictation only where the browser listens on this computer (N10).
  useEffect(() => {
    let live = true;
    runAction(() =>
      localDictation(i18n.language).then((found) => {
        if (!live) return;
        dictation.current = found;
        setCanDictate(found !== null);
      }),
    );
    return () => {
      live = false;
    };
  }, [i18n.language]);

  // Autosave, debounced: there is no Save button to miss ([[Notes]]).
  // Each keystroke is also kept at once where a reload cannot lose it
  // (W4-02): the debounce and a pagehide write both lose that race.
  const schedule = (next: { title: string; folder: string; body: string }) => {
    const at = clock().toISOString();
    pending.current = { ...next, at };
    keepDraft(note.uuid, { ...next, at });
    // What is past the limit is not kept: say so once, rather than let
    // the editor show text that will never be saved (Q5-60).
    if (next.body.length > maxNoteBody && !warnedLong.current) {
      warnedLong.current = true;
      toast.warning(t('notes.tooLong', { max: formatNumber(maxNoteBody) }));
    }
    clearTimeout(timer.current);
    timer.current = setTimeout(() => void flush().catch(() => toast.error(t('common.saveFailed'))), 600);
  };

  useEffect(() => {
    const off = registerPendingEdit(flush);
    return () => {
      off();
      runAction(() => flush());
    };
  }, [flush]);

  // A newer copy arrived from another device while nothing was typed
  // here: show it. With typing pending, mine is the later write anyway.
  useEffect(() => {
    if (note.updatedAt === seen.current) return;
    seen.current = note.updatedAt;
    if (pending.current) return;
    setTitle(note.title);
    setFolder(note.folder);
    setBody(note.body);
  }, [note]);

  const { openTitle, prompt: createLinkPrompt } = useOpenTitle(vault.notes, phone);
  const outgoing = useMemo(() => {
    const seenTitles = new Set<string>();
    return linksIn(body).filter((link) => {
      const key = link.title.toLowerCase();
      if (seenTitles.has(key)) return false;
      seenTitles.add(key);
      return true;
    });
  }, [body]);
  const backlinks = useMemo(
    () =>
      vault.notes.filter(
        (other) =>
          other.uuid !== note.uuid && linksIn(other.body).some((link) => link.title.toLowerCase() === note.title.toLowerCase()),
      ),
    [vault.notes, note.uuid, note.title],
  );

  /** The selection in the field, or where it was when the field last had it. */
  const selection = (): { start: number; end: number } => {
    const field = area.current;
    if (field) return { start: field.selectionStart, end: field.selectionEnd };
    const kept = lastSelection.current;
    return kept ? { start: Math.min(kept.start, body.length), end: Math.min(kept.end, body.length) } : { start: body.length, end: body.length };
  };

  const format = (spec: { wrap?: [string, string]; prefix?: string }) => {
    if (!area.current) return;
    const next = applyFormat(area.current, spec);
    setBody(next);
    schedule({ title, folder, body: next });
    area.current.focus();
  };

  const caret = (): Edit => {
    const { start, end } = selection();
    return { text: body, start, end };
  };

  /** Applies a toolbar edit and puts the selection where it says. */
  const applyEdit = (result: Edit | null) => {
    if (!result) return;
    setBody(result.text);
    schedule({ title, folder, body: result.text });
    if (phone) setEditing(true);
    requestAnimationFrame(() => {
      const field = area.current;
      if (!field) return;
      field.focus();
      field.setSelectionRange(result.start, result.end);
      setInTable(tableAt(result) !== null);
      setCaretAt(result.end);
    });
  };

  // The row and column buttons are there only while the caret is in a table.
  const trackCaret = () => {
    const field = area.current;
    if (!field) return;
    lastSelection.current = { start: field.selectionStart, end: field.selectionEnd };
    setInTable(tableAt({ text: field.value, start: field.selectionStart, end: field.selectionEnd }) !== null);
    setCaretAt(field.selectionEnd);
  };

  /** Types [text] at the caret, as a line of its own when asked (`_insertAtCaret`). */
  const insertAtCaret = (text: string, ownLine = false) => {
    const at = area.current || phone ? selection().end : body.length;
    const before = body.slice(0, at);
    const after = body.slice(at);
    const lead =
      ownLine && before && !before.endsWith('\n')
        ? '\n'
        : !ownLine && before && !before.endsWith(' ') && !before.endsWith('\n')
          ? ' '
          : '';
    const tail = ownLine && !after.startsWith('\n') ? '\n' : '';
    const inserted = `${lead}${text}${tail}`;
    applyEdit({ text: before + inserted + after, start: at + inserted.length, end: at + inserted.length });
  };

  // Words arrive after the render that started listening; they go in
  // with the body as it is then, not as it was.
  const insertLatest = useRef(insertAtCaret);
  useEffect(() => {
    insertLatest.current = insertAtCaret;
  });

  const dictate = () => {
    const listener = dictation.current;
    if (!listener) return;
    if (dictating) {
      listener.stop();
      return;
    }
    listener.onresult = (event) => {
      for (let i = event.resultIndex; i < event.results.length; i++) {
        const result = event.results[i]!;
        const words = result[0].transcript.trim();
        if (result.isFinal && words) insertLatest.current(words);
      }
    };
    listener.onend = () => setDictating(false);
    listener.onerror = () => setDictating(false);
    setMode('write');
    setDictating(true);
    listener.start();
  };

  /** An audio file from this computer, filed and embedded as a recording would be. */
  const attach = async (file: File) => {
    const extension = audioExtensionOf(file);
    if (!extension) {
      toast.error(t('voice.notAudio'));
      return;
    }
    const stem = file.name.replace(/\.[^.]*$/, '').replace(/[[\]\n|#^]/g, ' ').trim() || voiceNoteTitle(new Date());
    const name = attachmentFileName(stem, extension, await attachments.takenNames());
    try {
      await attachments.add({ noteUuid: note.uuid, blob: file, fileName: name, durationMs: null });
    } catch (error) {
      toast.error(
        error instanceof FileTooLargeError
          ? t('gallery.tooLarge', { size: formatBytes(error.bytes), max: formatBytes(maxFileBytes) })
          : t('common.saveFailed'),
      );
      return;
    }
    setMode('write');
    insertAtCaret(audioEmbed(name), true);
  };

  const remove = async () => {
    await flush();
    await notes.remove(note.uuid);
    onRemoved();
    toast(t('notes.movedToTrash'), { action: { label: t('common.undo'), onClick: () => runAction(() => notes.restore(note.uuid)) } });
  };

  const print = () => {
    const snapshot = { ...note, title, folder, body };
    runAction(() =>
      flush()
        .catch(() => toast.error(t('common.saveFailed')))
        .then(() => setPrinting(snapshot)),
    );
  };

  /** The assist on the selection, or on the whole note (N8). */
  const startAssist = (action: AssistAction) => {
    const { start, end } = selection();
    const selected = end > start ? body.slice(start, end) : '';
    const onSelection = actsOnSelection(action) && selected.length > 0;
    setAsking({ action, text: onSelection ? selected : body, upToCaret: body.slice(0, start), fromSelection: onSelection });
  };

  const tools: { label: string; icon: ReactNode; spec: { wrap?: [string, string]; prefix?: string } }[] = [
    { label: t('notes.tool.heading'), icon: <HeadingIcon />, spec: { prefix: '## ' } },
    { label: t('notes.tool.bold'), icon: <BoldIcon />, spec: { wrap: ['**', '**'] } },
    { label: t('notes.tool.italic'), icon: <ItalicIcon />, spec: { wrap: ['*', '*'] } },
    { label: t('notes.tool.code'), icon: <CodeIcon />, spec: { wrap: ['`', '`'] } },
    { label: t('notes.tool.list'), icon: <ListIcon />, spec: { prefix: '- ' } },
    { label: t('notes.tool.task'), icon: <ListChecksIcon />, spec: { prefix: '- [ ] ' } },
    { label: t('notes.tool.quote'), icon: <QuoteIcon />, spec: { prefix: '> ' } },
    { label: t('notes.tool.link'), icon: <LinkIcon />, spec: { wrap: ['[[', ']]'] } },
  ];
  const printDone = useCallback(() => setPrinting(null), []);

  // On a phone a tap keeps the caret in the field: the toolbar is part of writing.
  const keepFocus = phone ? { onPointerDown: (event: PointerEvent) => event.preventDefault() } : {};
  const formatting = (
    <>
      {tools.map((tool) => (
        <ToolButton key={tool.label} label={tool.label} icon={tool.icon} phone={phone} onClick={() => format(tool.spec)} />
      ))}
      <ToolButton label={t('notes.tool.table')} icon={<TableIcon />} phone={phone} onClick={() => applyEdit(insertTable(caret()))} />
      {inTable && (
        <>
          <Button
            variant="ghost"
            size="sm"
            className={cn('shrink-0 px-2', phone ? 'h-11' : 'h-7')}
            title={t('notes.tool.tableRow')}
            onClick={() => applyEdit(addTableRow(caret()))}
            {...keepFocus}
          >
            <PlusIcon />
            {t('notes.tool.rowShort')}
            <span className="sr-only">{t('notes.tool.tableRow')}</span>
          </Button>
          <Button
            variant="ghost"
            size="sm"
            className={cn('shrink-0 px-2', phone ? 'h-11' : 'h-7')}
            title={t('notes.tool.tableColumn')}
            onClick={() => applyEdit(addTableColumn(caret()))}
            {...keepFocus}
          >
            <PlusIcon />
            {t('notes.tool.columnShort')}
            <span className="sr-only">{t('notes.tool.tableColumn')}</span>
          </Button>
        </>
      )}
      {canRecord && <ToolButton label={t('voice.record')} icon={<MicIcon />} phone={phone} onClick={() => setRecording(true)} />}
      {canDictate && (
        <ToolButton
          label={dictating ? t('voice.listening') : t('voice.dictate')}
          icon={dictating ? <AudioLinesIcon className="text-destructive" /> : <MicVocalIcon />}
          phone={phone}
          pressed={dictating}
          onClick={dictate}
        />
      )}
    </>
  );

  const markdownOptions: MarkdownOptions = {
    renderEmbed: (name) => (
      <span className="inline-flex items-center gap-1 rounded-md bg-muted px-1.5 py-0.5 text-sm text-muted-foreground">
        <MicIcon className="size-3.5" aria-hidden />
        {name}
      </span>
    ),
    renderWikiLink: (linkTitle) => {
      const target = byTitle(vault.notes, linkTitle);
      return (
        <button
          type="button"
          onClick={() => openTitle(linkTitle)}
          className={cn('font-semibold underline-offset-4 hover:underline', target ? 'text-primary' : 'text-muted-foreground italic')}
          title={target ? undefined : t('notes.createLinked', { title: linkTitle })}
        >
          {linkTitle}
        </button>
      );
    },
  };

  const bodyField = (
    <>
      <Label htmlFor="note-body" className="sr-only">
        {t('notes.body')}
      </Label>
      <textarea
        id="note-body"
        ref={area}
        dir="auto"
        value={body}
        spellCheck
        placeholder={phone ? t('notes.bodyHintLive') : t('notes.bodyHint')}
        onChange={(event) => {
          setBody(event.target.value);
          schedule({ title, folder, body: event.target.value });
        }}
        onSelect={trackCaret}
        onFocus={phone ? () => setEditing(true) : undefined}
        onBlur={
          phone
            ? (event) => {
                trackCaret();
                if (toolbar.current?.contains(event.relatedTarget)) return;
                setEditing(false);
              }
            : undefined
        }
        className={cn('note-source', phone ? 'min-h-[24rem] leading-[1.6]' : 'min-h-[50vh]')}
      />
    </>
  );

  const titleField = (
    <>
      <Label htmlFor="note-title" className="sr-only">
        {t('notes.title')}
      </Label>
      <input
        id="note-title"
        value={title}
        placeholder={phone ? t('notes.title') : t('notes.untitled')}
        dir="auto"
        autoComplete="off"
        className={cn(
          'w-full min-w-0 bg-transparent font-extrabold outline-none placeholder:text-muted-foreground/60',
          phone ? 'text-2xl leading-tight' : 'text-[2rem] leading-tight tracking-tight',
        )}
        onChange={(event) => {
          setTitle(event.target.value);
          schedule({ title: event.target.value, folder, body });
        }}
        onKeyDown={(event) => {
          // Enter in the title goes on into the note, as Obsidian's does.
          if (event.key !== 'Enter' || event.nativeEvent.isComposing) return;
          event.preventDefault();
          if (phone) setEditing(true);
          else setMode('write');
          requestAnimationFrame(() => area.current?.focus());
        }}
      />
    </>
  );

  const moreItems = (
    <>
      {canRecord && (
        <DropdownMenuItem onSelect={() => setRecording(true)}>
          <MicIcon />
          {t('voice.record')}
        </DropdownMenuItem>
      )}
      <DropdownMenuItem onSelect={() => attachInput.current?.click()}>
        <PaperclipIcon />
        {t('voice.attach')}
      </DropdownMenuItem>
      {canSpeak() && (
        <DropdownMenuItem onSelect={() => setReading(true)}>
          <Volume2Icon />
          {t('voice.readAloud')}
        </DropdownMenuItem>
      )}
      <DropdownMenuItem onSelect={() => setMoving(true)}>
        <FolderInputIcon />
        {t('notes.moveToFolder')}
      </DropdownMenuItem>
      <DropdownMenuItem onSelect={print}>
        <PrinterIcon />
        {t('notes.exportPdf')}
      </DropdownMenuItem>
    </>
  );

  const hidden = (
    <>
      <input
        ref={attachInput}
        type="file"
        accept="audio/*"
        className="sr-only"
        tabIndex={-1}
        aria-hidden
        data-testid="attach-recording"
        onChange={(event) => {
          const file = event.target.files?.[0];
          event.target.value = '';
          if (file) runAction(() => attach(file));
        }}
      />
      <AssistDialog
        target={asking}
        model={assist.data?.model ?? ''}
        spent={assist.data ? assist.data.usedToday >= assist.data.dailyLimit : false}
        onClose={() => setAsking(null)}
        onInsert={(text) => {
          // A transcript goes under its recording, as a quote (N10).
          const next = asking?.recording
            ? placeTranscript(body, asking.recording.name, text)
            : `${body}${body.length === 0 || body.endsWith('\n') ? '' : '\n\n'}${text}`;
          setBody(next);
          schedule({ title, folder, body: next });
          setAsking(null);
        }}
        onReplace={(text) => {
          const { start, end } = selection();
          const next = asking?.fromSelection ? body.slice(0, start) + text + body.slice(end) : text;
          setBody(next);
          schedule({ title, folder, body: next });
          setAsking(null);
        }}
      />
      {recording && (
        <RecordingDialog
          noteUuid={note.uuid}
          onDone={(fileName) => {
            setRecording(false);
            // The request to record came with the note; it is spent.
            if (location.state) background(navigate(location.pathname, { replace: true, state: null }));
            if (fileName) {
              setMode('write');
              insertAtCaret(audioEmbed(fileName), true);
            }
          }}
        />
      )}
      {reading && <ReadAloudDialog markdown={body} onClose={() => setReading(false)} />}
      {printing && <NotePrint note={printing} onDone={printDone} />}
      {moving && (
        <MoveToFolderDialog
          current={folder}
          folders={vault.folders}
          onClose={() => setMoving(false)}
          onPick={(path) => {
            setMoving(false);
            setFolder(path);
            schedule({ title, folder: path, body });
          }}
        />
      )}
      {createLinkPrompt}
    </>
  );

  const recordings = (
    <Recordings
      noteUuid={note.uuid}
      body={body}
      onTranscribe={
        assist.data?.available === true
          ? (row) => {
              // The file is read now; nothing leaves until Send (N10).
              background(
                (async () => {
                  const hash = row.fileHash ?? (await files.localHash(row.uuid));
                  const blob = hash ? await files.get(hash) : null;
                  if (!blob) {
                    toast.error(t('voice.missing'));
                    return;
                  }
                  setAsking({ action: 'transcribe', text: '', upToCaret: '', fromSelection: false, recording: { name: row.fileName, blob } });
                })(),
              );
            }
          : undefined
      }
    />
  );

  const assistItems = assistActions.filter((action) => action !== 'transcribe');

  if (phone) {
    const caretLinks = editing && caretAt !== null ? linksOnLine(body, caretAt) : [];
    return (
      <article className="flex min-h-0 flex-1 flex-col" aria-label={title || t('notes.untitled')}>
        {/* The phone's app bar: the note's title, its folder under it, and its actions. */}
        <AppBarTitle>
          <div className="flex min-w-0 flex-col">
            <p dir="auto" className="truncate text-lg leading-tight font-extrabold">
              {title || t('notes.untitled')}
            </p>
            {folder && (
              <p dir="auto" className="truncate text-xs text-muted-foreground">
                {folder}
              </p>
            )}
          </div>
        </AppBarTitle>
        <AppBarActions>
          {canRecord && (
            <Button
              variant="ghost"
              size="icon"
              className="@max-[14rem]/bar:hidden"
              aria-label={t('voice.newNote')}
              title={t('voice.newNote')}
              onClick={() => runAction(() => actions.newVoiceNote(folder))}
            >
              <MicIcon />
            </Button>
          )}
          <Button variant="ghost" size="icon" aria-label={t('notes.new')} title={t('notes.new')} onClick={() => runAction(() => actions.newNote(folder))}>
            <PlusIcon />
          </Button>
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon" aria-label={t('notes.more')} title={t('notes.more')}>
                <EllipsisVerticalIcon />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="min-w-52">
              {assist.data?.available === true && (
                <DropdownMenuItem onSelect={() => setPickingAssist(true)}>
                  <SparklesIcon />
                  {t('assist.title')}
                </DropdownMenuItem>
              )}
              {moreItems}
              <DropdownMenuItem onSelect={() => setDeleting(true)}>
                <Trash2Icon />
                {t('common.delete')}
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </AppBarActions>

        <div className="min-h-0 flex-1 overflow-y-auto overscroll-contain" data-note-scroller>
          <div className="flex flex-col px-6 pt-2 pb-10">
            <LocationNote table="notes" uuid={note.uuid} className="mb-2" />
            {titleField}
            <hr className="my-3 border-border" />
            {writingHere ? (
              bodyField
            ) : (
              <div
                role="group"
                aria-label={t('notes.body')}
                tabIndex={0}
                data-testid="note-rendered"
                className="min-h-[24rem] cursor-text outline-none"
                dir="auto"
                onFocus={(event) => {
                  // Tabbed to from the keyboard: write. A tap focuses it too,
                  // and goes on to the click below, which knows where.
                  if (event.target === event.currentTarget && event.currentTarget.matches(':focus-visible')) setEditing(true);
                }}
                onClick={(event) => {
                  // A tap writes where it lands: the caret goes to the start
                  // of the block tapped, shown with its markdown.
                  const target = event.target as HTMLElement;
                  if (target.closest('button, a, audio, input')) return;
                  const block = target.closest<HTMLElement>('[data-line]');
                  const at = block ? offsetOfLine(body, Number(block.dataset.line)) : body.length;
                  const pane = event.currentTarget.closest<HTMLElement>('[data-note-scroller]');
                  // Where the tapped block stood in the pane: its line stays there once the markdown shows.
                  const stood = block && pane ? block.getBoundingClientRect().top - pane.getBoundingClientRect().top : null;
                  lastSelection.current = { start: at, end: at };
                  setEditing(true);
                  requestAnimationFrame(() => {
                    const field = area.current;
                    if (!field) return;
                    field.focus({ preventScroll: true });
                    field.setSelectionRange(at, at);
                    setCaretAt(at);
                    if (pane && stood !== null) {
                      const fieldTop = field.getBoundingClientRect().top - pane.getBoundingClientRect().top + pane.scrollTop;
                      pane.scrollTop = Math.max(0, fieldTop + caretTop(field, at) - stood);
                    }
                  });
                }}
              >
                <Markdown source={body} className="note-prose" options={markdownOptions} />
              </div>
            )}
            {caretLinks.length > 0 && (
              <div className="mt-3 flex flex-wrap gap-2">
                {caretLinks.map((linkTitle) => (
                  <Button
                    key={linkTitle}
                    variant="outline"
                    size="sm"
                    className="rounded-lg"
                    {...keepFocus}
                    onClick={() => openTitle(linkTitle)}
                  >
                    <ArrowUpRightIcon />
                    <span dir="auto">{linkTitle}</span>
                  </Button>
                ))}
              </div>
            )}
            <div className="mt-6 empty:hidden">{recordings}</div>
            {backlinks.length > 0 && (
              <section aria-labelledby="backlinks" className="mt-6 flex flex-col gap-2">
                <h2 id="backlinks" className="text-sm font-extrabold text-muted-foreground">
                  {t('notes.backlinks', { count: backlinks.length })}
                </h2>
                <div className="flex flex-wrap gap-2">
                  {backlinks.map((other) => (
                    <Button key={other.uuid} asChild variant="outline" size="sm" className="rounded-lg">
                      <Link to={`/app/records/${other.uuid}`} replace>
                        <CornerDownLeftIcon />
                        <span dir="auto">{other.title || t('notes.untitled')}</span>
                      </Link>
                    </Button>
                  ))}
                </div>
              </section>
            )}
          </div>
        </div>

        {/* The bar on the keyboard, while writing (`MarkdownToolbar`).
            Positioned, so the hidden labels in it stay inside it rather
            than widen the page. */}
        {editing && (
          <div
            ref={toolbar}
            role="toolbar"
            aria-label={t('notes.formatting')}
            className="no-scrollbar relative flex shrink-0 items-center overflow-x-auto bg-muted px-1"
            style={keyboard ? { transform: `translateY(-${keyboard}px)` } : undefined}
            onBlur={(event) => {
              const next = event.relatedTarget as Node | null;
              if (next !== area.current && !event.currentTarget.contains(next)) setEditing(false);
            }}
          >
            {formatting}
          </div>
        )}

        <Dialog open={pickingAssist} onOpenChange={setPickingAssist}>
          <DialogContent className="max-w-sm" aria-describedby={undefined}>
            <DialogHeader>
              <DialogTitle>{t('assist.title')}</DialogTitle>
            </DialogHeader>
            <ul className="-mx-2 flex flex-col">
              {assistItems.map((action) => (
                <li key={action}>
                  <button
                    type="button"
                    onClick={() => {
                      setPickingAssist(false);
                      startAssist(action);
                    }}
                    className="flex min-h-12 w-full items-center gap-3 rounded-lg px-2 text-start outline-none hover:bg-accent focus-visible:ring-2 focus-visible:ring-ring"
                  >
                    <SparklesIcon className="size-5 text-muted-foreground" aria-hidden />
                    {t(`assist.actions.${action}`)}
                  </button>
                </li>
              ))}
            </ul>
          </DialogContent>
        </Dialog>
        <AlertDialog open={deleting} onOpenChange={setDeleting}>
          <AlertDialogContent>
            <AlertDialogHeader>
              <AlertDialogTitle>{t('notes.deleteTitle')}</AlertDialogTitle>
              <AlertDialogDescription>{t('notes.deleteBody')}</AlertDialogDescription>
            </AlertDialogHeader>
            <AlertDialogFooter>
              <AlertDialogCancel>{t('common.cancel')}</AlertDialogCancel>
              <AlertDialogAction destructive onClick={() => runAction(() => remove())}>
                {t('common.delete')}
              </AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>
        {hidden}
      </article>
    );
  }

  /**
   * Read and Write keep my place, as Obsidian's switch does: the line at
   * the top of the pane is still at the top after it.
   */
  const switchMode = (next: 'write' | 'read') => {
    const pane = paneRef.current;
    const paneTop = pane?.getBoundingClientRect().top ?? 0;
    let anchor: { line: number; offset: number } | null = null;
    if (pane && next === 'write') {
      const block = [...pane.querySelectorAll<HTMLElement>('.note-prose > [data-line]')].find((el) => el.getBoundingClientRect().bottom > paneTop);
      if (block) anchor = { line: Number(block.dataset.line), offset: block.getBoundingClientRect().top - paneTop };
    } else if (pane && area.current) {
      const field = area.current;
      const fieldTop = field.getBoundingClientRect().top - paneTop;
      const lines = body.split('\n').length;
      // The first line whose top is at or below the pane's top.
      let low = 0;
      let high = lines - 1;
      while (low < high) {
        const mid = (low + high) >> 1;
        if (fieldTop + caretTop(field, offsetOfLine(body, mid)) < 0) low = mid + 1;
        else high = mid;
      }
      anchor = { line: low, offset: fieldTop + caretTop(field, offsetOfLine(body, low)) };
    }
    setMode(next);
    if (!pane || !anchor) return;
    const { line, offset } = anchor;
    requestAnimationFrame(() => {
      const top = pane.getBoundingClientRect().top;
      if (next === 'write') {
        const field = area.current;
        if (!field) return;
        const fieldTop = field.getBoundingClientRect().top - top + pane.scrollTop;
        pane.scrollTop = Math.max(0, fieldTop + caretTop(field, offsetOfLine(body, line)) - offset);
      } else {
        const blocks = [...pane.querySelectorAll<HTMLElement>('.note-prose > [data-line]')];
        const block = blocks.filter((el) => Number(el.dataset.line) <= line).at(-1) ?? blocks[0];
        if (block) pane.scrollTop = Math.max(0, block.getBoundingClientRect().top - top + pane.scrollTop - offset);
      }
    });
  };

  // A wide window: Obsidian's pane. A thin header with where the note
  // lives and its actions, the formatting while writing, and the note
  // in a readable column that scrolls on its own.
  const crumbs = folder ? folder.split('/') : [];
  return (
    <Tabs value={mode} onValueChange={(value) => switchMode(value as 'write' | 'read')} className="flex min-h-0 flex-1 flex-col gap-0" asChild>
      <article aria-label={title || t('notes.untitled')}>
        <header className="flex h-10 shrink-0 items-center gap-2 border-b ps-4 pe-2">
          <p className="flex min-w-0 flex-1 items-center gap-1 truncate text-[13px] text-muted-foreground" data-testid="note-path">
            {crumbs.map((part, index) => (
              <span key={index} className="flex shrink-0 items-center gap-1">
                {index === 0 && <FolderIcon className="size-3.5" aria-hidden />}
                <span dir="auto">{part}</span>
                <span aria-hidden className="opacity-60">
                  /
                </span>
              </span>
            ))}
            <span dir="auto" className="truncate font-semibold text-foreground">
              {title || t('notes.untitled')}
            </span>
          </p>
          <TabsList className="h-7 gap-0.5 rounded-md p-0.5">
            <TabsTrigger value="write" className="h-6 gap-1 rounded-[5px] px-2 text-xs" title={t('notes.write')}>
              <PencilLineIcon className="size-3.5" aria-hidden />
              {t('notes.write')}
            </TabsTrigger>
            <TabsTrigger value="read" className="h-6 gap-1 rounded-[5px] px-2 text-xs" title={t('notes.read')}>
              <BookOpenIcon className="size-3.5" aria-hidden />
              {t('notes.read')}
            </TabsTrigger>
          </TabsList>
          {assist.data?.available === true && (
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="ghost" size="sm" className="h-7 px-2 text-xs">
                  <SparklesIcon />
                  {t('assist.title')}
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end">
                {/* Transcribe works on one recording, from its
                    player below ([[Notes]] N10); it is not a
                    whole-note action. */}
                {assistItems.map((action) => (
                  <DropdownMenuItem key={action} onSelect={() => startAssist(action)}>
                    {t(`assist.actions.${action}`)}
                  </DropdownMenuItem>
                ))}
              </DropdownMenuContent>
            </DropdownMenu>
          )}
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon-sm" className="size-7 text-muted-foreground hover:text-foreground" aria-label={t('notes.more')} title={t('notes.more')}>
                <EllipsisVerticalIcon />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              {moreItems}
            </DropdownMenuContent>
          </DropdownMenu>
          <Button
            variant="ghost"
            size="icon-sm"
            className="size-7 text-muted-foreground hover:text-foreground"
            aria-label={t('notes.moveToTrash')}
            title={t('notes.moveToTrash')}
            onClick={() => runAction(() => remove())}
          >
            <Trash2Icon />
          </Button>
        </header>
        {mode === 'write' && (
          <div role="toolbar" aria-label={t('notes.formatting')} className="no-scrollbar relative flex h-9 shrink-0 items-center gap-0.5 overflow-x-auto border-b px-3">
            {formatting}
          </div>
        )}
        <div ref={paneRef} className="min-h-0 flex-1 overflow-y-auto overscroll-contain" data-note-scroller>
          <div className="mx-auto flex w-full max-w-[calc(700px+4rem)] flex-col px-8 pt-10 pb-32">
            {titleField}
            <div className="mt-2 mb-6 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-muted-foreground">
              <span className="flex items-center gap-1">
                <Label htmlFor="note-folder" className="flex items-center gap-1 text-xs font-semibold text-muted-foreground">
                  <FolderIcon className="size-3.5" aria-hidden />
                  <span className="sr-only">{t('notes.folder')}</span>
                </Label>
                <Input
                  id="note-folder"
                  list="note-folders"
                  value={folder}
                  placeholder={t('notes.rootFolder')}
                  className="h-7 w-44 rounded-md border-transparent bg-transparent px-1.5 text-xs shadow-none hover:bg-muted focus-visible:bg-muted"
                  onChange={(event) => {
                    setFolder(event.target.value);
                    schedule({ title, folder: event.target.value, body });
                  }}
                />
                <datalist id="note-folders">
                  {vault.folders.map((path) => (
                    <option key={path} value={path} />
                  ))}
                </datalist>
              </span>
              <span>{t('notes.edited', { when: formatDate(note.updatedAt, { dateStyle: 'medium', timeStyle: 'short' }) })}</span>
              <LocationNote table="notes" uuid={note.uuid} />
            </div>
            <TabsContent value="write" className="flex-none">
              {bodyField}
            </TabsContent>
            <TabsContent value="read" className="flex-none" dir="auto">
              {body.trim() ? (
                <Markdown source={body} className="note-prose" options={markdownOptions} />
              ) : (
                <p className="text-muted-foreground">{t('notes.empty')}</p>
              )}
            </TabsContent>
            <div className="mt-8 empty:hidden">{recordings}</div>

            {/* What this note links to, and what links here, at its foot as Obsidian keeps them. */}
            <div className="mt-14 grid gap-6 border-t pt-6 sm:grid-cols-2">
              <section aria-labelledby="outgoing">
                <h2 id="outgoing" className="mb-2 text-xs font-extrabold tracking-wide text-muted-foreground uppercase">
                  {t('notes.linksOut')}
                </h2>
                {outgoing.length === 0 ? (
                  <p className="text-xs text-muted-foreground">{t('notes.noLinks')}</p>
                ) : (
                  <ul className="flex flex-col gap-1">
                    {outgoing.map((link) => {
                      const target = byTitle(vault.notes, link.title);
                      return (
                        <li key={link.title}>
                          <button
                            type="button"
                            onClick={() => openTitle(link.title)}
                            className={cn('text-start text-sm font-semibold hover:underline', target ? 'text-primary' : 'text-muted-foreground italic')}
                          >
                            {link.title}
                            {!target && <span className="ms-1 text-xs">({t('notes.notWritten')})</span>}
                          </button>
                        </li>
                      );
                    })}
                  </ul>
                )}
              </section>
              <section aria-labelledby="backlinks">
                <h2 id="backlinks" className="mb-2 text-xs font-extrabold tracking-wide text-muted-foreground uppercase">
                  {t('notes.linksHere')}
                </h2>
                {backlinks.length === 0 ? (
                  <p className="text-xs text-muted-foreground">{t('notes.noBacklinks')}</p>
                ) : (
                  <ul className="flex flex-col gap-2">
                    {backlinks.map((other) => (
                      <li key={other.uuid}>
                        <Link dir="auto" to={`/app/records/${other.uuid}`} className="block rounded-md text-sm outline-none hover:underline focus-visible:ring-2 focus-visible:ring-ring">
                          <span className="font-semibold text-primary">{other.title || t('notes.untitled')}</span>
                          <span className="block truncate text-xs text-muted-foreground">{notePreview(other.body)}</span>
                        </Link>
                      </li>
                    ))}
                  </ul>
                )}
              </section>
            </div>
          </div>
        </div>
        {hidden}
      </article>
    </Tabs>
  );
}
