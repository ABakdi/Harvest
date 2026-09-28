import { maxFileBytes } from '@harvest/contracts';
import { actsOnSelection, assistActions } from '@harvest/core';
import { useQuery } from '@tanstack/react-query';
import {
  AudioLinesIcon,
  EllipsisVerticalIcon,
  MicIcon,
  MicVocalIcon,
  PaperclipIcon,
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
import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { Link, useLocation, useNavigate } from 'react-router';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { formatBytes, formatDate, formatNumber } from '@/lib/format';
import { Markdown } from '@/lib/markdown';
import { dropDraft, keepDraft } from '@/lib/note-drafts';
import { registerPendingEdit } from '@/lib/pending-edits';
import { cn } from '@/lib/utils';
import { AssistDialog, type AssistTarget } from '../../components/assist-dialog';
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
import { linksIn, maxNoteBody, type NoteRow } from '../../data/notes';
import { background, runAction } from '@/lib/actions';
import { useDocumentTitle } from '@/lib/title';
import type { Vault } from './vault';

/** A note by the title a link names: exactly, then ignoring case. */
function byTitle(notes: NoteRow[], title: string): NoteRow | undefined {
  return notes.find((note) => note.title === title) ?? notes.find((note) => note.title.toLowerCase() === title.toLowerCase());
}

function useOpenTitle(notes: NoteRow[]) {
  const { t } = useTranslation();
  const { notes: repo } = useHarvest();
  const navigate = useNavigate();
  const [asking, setAsking] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const openTitle = useCallback(
    (title: string) => {
      const target = byTitle(notes, title);
      if (target) {
        background(navigate(`/app/records/${target.uuid}`));
        return;
      }
      // A link to a note not written yet offers to write it, as the
      // phone does, rather than writing it on a click ([[Audit-v3]] G5-09).
      setAsking(title);
    },
    [notes, navigate],
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
      background(navigate(`/app/records/${target.uuid}`));
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

export function Editor({ note, vault }: { note: NoteRow; vault: Vault }) {
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
  const [mode, setMode] = useState<'write' | 'read'>(note.body ? 'read' : 'write');
  const area = useRef<HTMLTextAreaElement>(null);
  const pending = useRef<{ title: string; folder: string; body: string; at: string } | null>(null);
  const warnedLong = useRef(false);
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const seen = useRef(note.updatedAt);
  const [inTable, setInTable] = useState(false);
  const [recording, setRecording] = useState<boolean>(() => Boolean((location.state as { record?: boolean } | null)?.record));
  const [reading, setReading] = useState(false);
  // What is printed is taken when *Export PDF* is chosen, after the
  // pending save has landed: never a copy short of the last keystrokes
  // (Q5-53).
  const [printing, setPrinting] = useState<NoteRow | null>(null);
  const dictation = useRef<Recognition | null>(null);
  const [canDictate, setCanDictate] = useState(false);
  const [dictating, setDictating] = useState(false);
  const attachInput = useRef<HTMLInputElement>(null);
  const canRecord = recordingFormat() !== null;

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
    runAction(() => localDictation(i18n.language).then((found) => {
      if (!live) return;
      dictation.current = found;
      setCanDictate(found !== null);
    }));
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

  const { openTitle, prompt: createLinkPrompt } = useOpenTitle(vault.notes);
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

  const format = (spec: { wrap?: [string, string]; prefix?: string }) => {
    if (!area.current) return;
    const next = applyFormat(area.current, spec);
    setBody(next);
    schedule({ title, folder, body: next });
    area.current.focus();
  };

  const caret = (): Edit => {
    const field = area.current;
    return field
      ? { text: body, start: field.selectionStart, end: field.selectionEnd }
      : { text: body, start: body.length, end: body.length };
  };

  /** Applies a toolbar edit and puts the selection where it says. */
  const applyEdit = (result: Edit | null) => {
    if (!result) return;
    setBody(result.text);
    schedule({ title, folder, body: result.text });
    requestAnimationFrame(() => {
      const field = area.current;
      if (!field) return;
      field.focus();
      field.setSelectionRange(result.start, result.end);
      setInTable(tableAt(result) !== null);
    });
  };

  // The row and column buttons are there only while the caret is in a table.
  const trackCaret = () => {
    const field = area.current;
    if (field) setInTable(tableAt({ text: field.value, start: field.selectionStart, end: field.selectionEnd }) !== null);
  };

  /** Types [text] at the caret, as a line of its own when asked (`_insertAtCaret`). */
  const insertAtCaret = (text: string, ownLine = false) => {
    const field = area.current;
    const at = mode === 'write' && field ? field.selectionEnd : body.length;
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
    background(navigate('/app/records'));
    toast(t('notes.movedToTrash'), { action: { label: t('common.undo'), onClick: () => runAction(() => notes.restore(note.uuid)) } });
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

  return (
    <article className="flex min-w-0 flex-col gap-3">
      <div className="flex items-center gap-2">
        <Label htmlFor="note-title" className="sr-only">
          {t('notes.title')}
        </Label>
        <Input
          id="note-title"
          value={title}
          placeholder={t('notes.untitled')}
          dir="auto"
          className="h-12 rounded-none border-b-2 border-transparent bg-transparent px-0 text-2xl font-extrabold focus-visible:border-primary focus-visible:ring-0"
          onChange={(event) => {
            setTitle(event.target.value);
            schedule({ title: event.target.value, folder, body });
          }}
        />
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon" aria-label={t('notes.more')}>
              <EllipsisVerticalIcon />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
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
            <DropdownMenuItem
              onSelect={() => {
                const snapshot = { ...note, title, folder, body };
                runAction(() => flush()
                  .catch(() => toast.error(t('common.saveFailed')))
                  .then(() => setPrinting(snapshot)));
              }}
            >
              <PrinterIcon />
              {t('notes.exportPdf')}
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
        <Button variant="ghost" size="icon" aria-label={t('notes.moveToTrash')} onClick={() => runAction(() => remove())}>
          <Trash2Icon />
        </Button>
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
      </div>
      <div className="flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
        <Label htmlFor="note-folder" className="flex items-center gap-1 text-xs font-semibold">
          <FolderIcon className="size-3.5" aria-hidden />
          {t('notes.folder')}
        </Label>
        <Input
          id="note-folder"
          list="note-folders"
          value={folder}
          placeholder={t('notes.rootFolder')}
          className="h-8 w-48 text-xs max-md:h-11"
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
        <span>{t('notes.edited', { when: formatDate(note.updatedAt, { dateStyle: 'medium', timeStyle: 'short' }) })}</span>
        <LocationNote table="notes" uuid={note.uuid} />
      </div>

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
          const field = area.current;
          const next =
            asking?.fromSelection && field
              ? body.slice(0, field.selectionStart) + text + body.slice(field.selectionEnd)
              : text;
          setBody(next);
          schedule({ title, folder, body: next });
          setAsking(null);
        }}
      />

      <Tabs value={mode} onValueChange={(value) => setMode(value as 'write' | 'read')}>
        <div className="flex flex-wrap items-center gap-2">
          <TabsList>
            <TabsTrigger value="write">{t('notes.write')}</TabsTrigger>
            <TabsTrigger value="read">{t('notes.read')}</TabsTrigger>
          </TabsList>
          {mode === 'write' && (
            <div role="toolbar" aria-label={t('notes.formatting')} className="flex flex-wrap gap-0.5 max-md:w-full max-md:flex-nowrap max-md:overflow-x-auto">
              {tools.map((tool) => (
                <Button key={tool.label} variant="ghost" size="icon-sm" aria-label={tool.label} title={tool.label} onClick={() => format(tool.spec)}>
                  {tool.icon}
                </Button>
              ))}
              <Button
                variant="ghost"
                size="icon-sm"
                aria-label={t('notes.tool.table')}
                title={t('notes.tool.table')}
                onClick={() => applyEdit(insertTable(caret()))}
              >
                <TableIcon />
              </Button>
              {inTable && (
                <>
                  <Button
                    variant="ghost"
                    size="sm"
                    className="h-8 px-2 max-md:h-11"
                    title={t('notes.tool.tableRow')}
                    onClick={() => applyEdit(addTableRow(caret()))}
                  >
                    <PlusIcon />
                    {t('notes.tool.rowShort')}
                    <span className="sr-only">{t('notes.tool.tableRow')}</span>
                  </Button>
                  <Button
                    variant="ghost"
                    size="sm"
                    className="h-8 px-2 max-md:h-11"
                    title={t('notes.tool.tableColumn')}
                    onClick={() => applyEdit(addTableColumn(caret()))}
                  >
                    <PlusIcon />
                    {t('notes.tool.columnShort')}
                    <span className="sr-only">{t('notes.tool.tableColumn')}</span>
                  </Button>
                </>
              )}
              {canRecord && (
                <Button variant="ghost" size="icon-sm" aria-label={t('voice.record')} title={t('voice.record')} onClick={() => setRecording(true)}>
                  <MicIcon />
                </Button>
              )}
              {canDictate && (
                <Button
                  variant="ghost"
                  size="icon-sm"
                  aria-label={dictating ? t('voice.listening') : t('voice.dictate')}
                  title={dictating ? t('voice.listening') : t('voice.dictate')}
                  aria-pressed={dictating}
                  onClick={dictate}
                >
                  {dictating ? <AudioLinesIcon className="text-destructive" /> : <MicVocalIcon />}
                </Button>
              )}
            </div>
          )}
          {assist.data?.available === true && (
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="ghost" size="sm" className="ms-auto">
                  <SparklesIcon />
                  {t('assist.title')}
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end">
                {/* Transcribe works on one recording, from its
                    player below ([[Notes]] N10); it is not a
                    whole-note action. */}
                {assistActions
                  .filter((action) => action !== 'transcribe')
                  .map((action) => (
                    <DropdownMenuItem
                      key={action}
                      onSelect={() => {
                        const field = area.current;
                        const selected =
                          field && field.selectionEnd > field.selectionStart
                            ? field.value.slice(field.selectionStart, field.selectionEnd)
                            : '';
                        const onSelection = actsOnSelection(action) && selected.length > 0;
                        setAsking({
                          action,
                          text: onSelection ? selected : body,
                          upToCaret: field ? field.value.slice(0, field.selectionStart) : body,
                          fromSelection: onSelection,
                        });
                      }}
                    >
                      {t(`assist.actions.${action}`)}
                    </DropdownMenuItem>
                  ))}
              </DropdownMenuContent>
            </DropdownMenu>
          )}
        </div>
        <TabsContent value="write">
          <Label htmlFor="note-body" className="sr-only">
            {t('notes.body')}
          </Label>
          <textarea
            id="note-body"
            ref={area}
            dir="auto"
            value={body}
            spellCheck
            placeholder={t('notes.bodyHint')}
            onChange={(event) => {
              setBody(event.target.value);
              schedule({ title, folder, body: event.target.value });
            }}
            onSelect={trackCaret}
            className="min-h-[55dvh] w-full resize-y rounded-xl border bg-card p-4 font-mono text-[15px] leading-relaxed outline-none focus-visible:ring-2 focus-visible:ring-ring"
          />
        </TabsContent>
        <TabsContent value="read">
          <div className="min-h-[55dvh] rounded-xl border bg-card p-4" dir="auto">
            {body.trim() ? (
              <Markdown
                source={body}
                options={{
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
                }}
              />
            ) : (
              <p className="text-muted-foreground">{t('notes.empty')}</p>
            )}
          </div>
        </TabsContent>
      </Tabs>

      <Recordings
        noteUuid={note.uuid}
        body={body}
        onTranscribe={
          assist.data?.available === true
            ? (recording) => {
                // The file is read now; nothing leaves until Send (N10).
                background((async () => {
                  const hash = recording.fileHash ?? (await files.localHash(recording.uuid));
                  const blob = hash ? await files.get(hash) : null;
                  if (!blob) {
                    toast.error(t('voice.missing'));
                    return;
                  }
                  setAsking({
                    action: 'transcribe',
                    text: '',
                    upToCaret: '',
                    fromSelection: false,
                    recording: { name: recording.fileName, blob },
                  });
                })());
              }
            : undefined
        }
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
      {createLinkPrompt}

      <div className="grid gap-3 sm:grid-cols-2">
        <section aria-labelledby="outgoing" className="rounded-xl border bg-card p-3">
          <h2 id="outgoing" className="mb-2 text-sm font-extrabold">
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
                      className={cn('text-start text-sm font-semibold hover:underline max-md:min-h-11', target ? 'text-primary' : 'text-muted-foreground italic')}
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
        <section aria-labelledby="backlinks" className="rounded-xl border bg-card p-3">
          <h2 id="backlinks" className="mb-2 text-sm font-extrabold">
            {t('notes.linksHere')}
          </h2>
          {backlinks.length === 0 ? (
            <p className="text-xs text-muted-foreground">{t('notes.noBacklinks')}</p>
          ) : (
            <ul className="flex flex-col gap-1">
              {backlinks.map((other) => (
                <li key={other.uuid}>
                  <Link
                    dir="auto"
                    to={`/app/records/${other.uuid}`}
                    className="text-sm font-semibold text-primary hover:underline max-md:inline-flex max-md:min-h-11 max-md:items-center"
                  >
                    {other.title || t('notes.untitled')}
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>
    </article>
  );
}
