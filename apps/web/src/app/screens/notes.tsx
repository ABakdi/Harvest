import { maxFileBytes } from '@harvest/contracts';
import { actsOnSelection, assistActions } from '@harvest/core';
import { useQuery } from '@tanstack/react-query';
import { useLiveQuery } from 'dexie-react-hooks';
import {
  ArrowLeftIcon,
  AudioLinesIcon,
  EllipsisVerticalIcon,
  FolderPenIcon,
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
  FilePlusIcon,
  FileTextIcon,
  FolderIcon,
  FolderPlusIcon,
  HeadingIcon,
  ItalicIcon,
  LinkIcon,
  ListChecksIcon,
  ListIcon,
  QuoteIcon,
  RotateCcwIcon,
  Trash2Icon,
} from 'lucide-react';
import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { Link, useLocation, useNavigate, useParams } from 'react-router';
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
  AlertDialogTrigger,
} from '@/components/ui/alert-dialog';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { formatBytes, formatDate } from '@/lib/format';
import { Markdown } from '@/lib/markdown';
import { dropDraft, keepDraft, leftDrafts } from '@/lib/note-drafts';
import { registerPendingEdit } from '@/lib/pending-edits';
import { cn } from '@/lib/utils';
import { AssistDialog, type AssistTarget } from '../components/assist-dialog';
import { EmptyState } from '../components/bits';
import { LocationNote } from '../components/location-note';
import { addTableColumn, addTableRow, insertTable, tableAt, type Edit } from '../components/notes/markdown-actions';
import { NotePrint } from '../components/notes/note-print';
import { ReadAloudDialog } from '../components/notes/read-aloud-dialog';
import { RecordingDialog } from '../components/notes/recording-dialog';
import { Recordings } from '../components/notes/recordings';
import { canSpeak, localDictation, recordingFormat, type Recognition } from '../components/notes/voice';
import { useHarvest } from '../context';
import { RecordsOff, RecordsTabs, useRecordsOff } from './records';
import { assistStatus } from '../data/assist';
import { placeTranscript } from '../data/transcribe';
import { attachmentFileName, audioEmbed, audioExtensionOf, voiceNoteTitle } from '../data/attachments';
import { FileTooLargeError } from '../data/files';
import type { HarvestDB } from '../data/db';
import { decodeFolders, folderTree, linksIn, normalizeFolder, notePreview, type NoteRow, type NotesRepository } from '../data/notes';
import { settingKeys, settingText } from '../data/settings';

type Sort = 'edited' | 'created' | 'title';

interface Vault {
  notes: NoteRow[];
  trash: NoteRow[];
  folders: string[];
}

async function loadVault(db: ReturnType<typeof useHarvest>['db']): Promise<Vault> {
  const [rows, declared] = await Promise.all([db.rows('notes').toArray(), db.rows('kv_settings').get(settingKeys.noteFolders)]);
  const notes = rows.filter((note) => note.deletedAt === null);
  return {
    notes,
    trash: rows.filter((note) => note.deletedAt !== null).sort((a, b) => (b.deletedAt ?? '').localeCompare(a.deletedAt ?? '')),
    folders: folderTree(
      notes.map((note) => note.folder),
      decodeFolders(settingText(declared?.valueJson)),
    ),
  };
}

/** A note by the title a link names: exactly, then ignoring case. */
function byTitle(notes: NoteRow[], title: string): NoteRow | undefined {
  return notes.find((note) => note.title === title) ?? notes.find((note) => note.title.toLowerCase() === title.toLowerCase());
}

function useOpenTitle(notes: NoteRow[], folder: string) {
  const { notes: repo } = useHarvest();
  const navigate = useNavigate();
  return useCallback(
    async (title: string) => {
      const target = byTitle(notes, title);
      if (target) {
        void navigate(`/app/records/${target.uuid}`);
        return;
      }
      // A link to a note not written yet offers to write it.
      const created = await repo.create({ title, folder });
      void navigate(`/app/records/${created.uuid}`);
    },
    [notes, folder, repo, navigate],
  );
}

// ------------------------------------------------------------- sidebar

/** The folder a path sits in, `''` at the top. */
function parentOf(path: string): string {
  return path.includes('/') ? path.slice(0, path.lastIndexOf('/')) : '';
}

/**
 * Makes a folder inside [parent], or renames [renaming] in place: its
 * notes and its subfolders move with it (`renameFolder`).
 */
function FolderDialog({
  parent,
  renaming,
  onClose,
}: {
  parent: string;
  renaming?: string;
  onClose: (renamedTo?: string) => void;
}) {
  const { t } = useTranslation();
  const { notes } = useHarvest();
  const [name, setName] = useState(renaming ? (renaming.split('/').at(-1) ?? '') : '');
  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-sm">
        <DialogHeader>
          <DialogTitle>{renaming ? t('notes.renameFolder') : t('notes.newFolder')}</DialogTitle>
          <DialogDescription>{parent ? t('notes.insideFolder', { folder: parent }) : t('notes.atRoot')}</DialogDescription>
        </DialogHeader>
        <form
          className="flex flex-col gap-3"
          onSubmit={(event) => {
            event.preventDefault();
            if (!name.trim()) return;
            const path = normalizeFolder(parent ? `${parent}/${name}` : name);
            if (!renaming) {
              void notes.addFolder(path).then(() => onClose());
            } else if (path === renaming || !path) {
              onClose();
            } else {
              void notes.renameFolder(renaming, path).then(() => onClose(path));
            }
          }}
        >
          <Label htmlFor="folder-name">{t('notes.folderName')}</Label>
          <Input id="folder-name" autoFocus value={name} placeholder={t('notes.folderNameHint')} onChange={(event) => setName(event.target.value)} />
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onClose()}>
              {t('common.cancel')}
            </Button>
            <Button type="submit">{renaming ? t('common.save') : t('common.create')}</Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

/**
 * What a folder offers from the sidebar, as the phone's folder sheet
 * does: a note or a folder inside it, a new name, or the trash — which
 * takes every note in it, so it asks first and can be undone.
 */
function FolderMenu({
  path,
  onNewNote,
  onNewFolder,
  onRename,
  onDeleted,
}: {
  path: string;
  onNewNote: () => void;
  onNewFolder: () => void;
  onRename: () => void;
  onDeleted: () => void;
}) {
  const { t } = useTranslation();
  const { notes } = useHarvest();
  const [confirming, setConfirming] = useState(false);
  const name = path.split('/').at(-1) ?? path;

  const remove = async () => {
    setConfirming(false);
    const trashed = await notes.trashFolder(path);
    onDeleted();
    toast(t('notes.folderTrashed', { folder: name, count: trashed.length }), {
      action: { label: t('common.undo'), onClick: () => void notes.restoreFolder(path, trashed) },
    });
  };

  return (
    <>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" size="icon-sm" className="shrink-0" aria-label={t('notes.folderOptions', { folder: name })}>
            <EllipsisVerticalIcon />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem onSelect={onNewNote}>
            <FilePlusIcon />
            {t('notes.newNoteHere')}
          </DropdownMenuItem>
          <DropdownMenuItem onSelect={onNewFolder}>
            <FolderPlusIcon />
            {t('notes.newSubfolder')}
          </DropdownMenuItem>
          <DropdownMenuItem onSelect={onRename}>
            <FolderPenIcon />
            {t('notes.renameFolder')}
          </DropdownMenuItem>
          <DropdownMenuItem onSelect={() => setConfirming(true)}>
            <Trash2Icon />
            {t('notes.deleteFolder')}
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
      <AlertDialog open={confirming} onOpenChange={setConfirming}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>{t('notes.deleteFolderTitle', { folder: name })}</AlertDialogTitle>
            <AlertDialogDescription>{t('notes.deleteFolderBody', { folder: path })}</AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>{t('common.cancel')}</AlertDialogCancel>
            <AlertDialogAction destructive onClick={() => void remove()}>
              {t('common.delete')}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
}

function Sidebar({
  vault,
  folder,
  setFolder,
  selected,
}: {
  vault: Vault;
  folder: string;
  setFolder: (folder: string) => void;
  selected: string | undefined;
}) {
  const { t } = useTranslation();
  const { notes } = useHarvest();
  const navigate = useNavigate();
  const [query, setQuery] = useState('');
  const [sort, setSort] = useState<Sort>('edited');
  const [folderDialog, setFolderDialog] = useState<{ parent: string; renaming?: string } | null>(null);

  const shown = useMemo(() => {
    const needle = query.trim().toLowerCase();
    const inFolder = (note: NoteRow) => !folder || note.folder === folder || note.folder.startsWith(`${folder}/`);
    const list = vault.notes.filter(
      (note) =>
        inFolder(note) && (!needle || note.title.toLowerCase().includes(needle) || note.body.toLowerCase().includes(needle)),
    );
    const compare: Record<Sort, (a: NoteRow, b: NoteRow) => number> = {
      edited: (a, b) => b.updatedAt.localeCompare(a.updatedAt),
      created: (a, b) => b.createdAt.localeCompare(a.createdAt),
      title: (a, b) => a.title.localeCompare(b.title),
    };
    return list.sort(compare[sort]);
  }, [vault.notes, folder, query, sort]);

  const create = async (where = folder) => {
    const note = await notes.create({ folder: where });
    void navigate(`/app/records/${note.uuid}`);
  };

  // The three-second path: a note named by the minute, recording at once.
  const createVoice = async () => {
    const note = await notes.create({ title: voiceNoteTitle(new Date()), folder });
    void navigate(`/app/records/${note.uuid}`, { state: { record: true } });
  };

  const counts = new Map<string, number>();
  for (const note of vault.notes) counts.set(note.folder, (counts.get(note.folder) ?? 0) + 1);

  return (
    <aside className="flex flex-col gap-3" aria-label={t('notes.sidebar')}>
      <div className="flex gap-2">
        <Button className="flex-1" onClick={() => void create()}>
          <FilePlusIcon />
          {t('notes.new')}
        </Button>
        {recordingFormat() !== null && (
          <Button variant="outline" size="icon" aria-label={t('voice.newNote')} title={t('voice.newNote')} onClick={() => void createVoice()}>
            <MicIcon />
          </Button>
        )}
        <Button variant="outline" size="icon" aria-label={t('notes.newFolder')} onClick={() => setFolderDialog({ parent: folder })}>
          <FolderPlusIcon />
        </Button>
      </div>
      <Label htmlFor="notes-search" className="sr-only">
        {t('notes.search')}
      </Label>
      <Input id="notes-search" type="search" placeholder={t('notes.search')} value={query} onChange={(event) => setQuery(event.target.value)} />
      <nav aria-label={t('notes.folders')} className="flex flex-col gap-0.5">
        {['', ...vault.folders].map((path) => {
          const depth = path ? path.split('/').length : 0;
          return (
            <div key={path || 'root'} className={cn('flex items-center rounded-md', folder === path && 'bg-accent text-accent-foreground')}>
              <button
                type="button"
                aria-current={folder === path ? 'true' : undefined}
                onClick={() => setFolder(path)}
                style={{ paddingInlineStart: `${0.5 + depth * 0.9}rem` }}
                className="flex min-w-0 flex-1 items-center gap-2 rounded-md py-1.5 pe-2 text-start text-sm font-semibold outline-none hover:bg-accent focus-visible:ring-2 focus-visible:ring-ring"
              >
                <FolderIcon className="size-4 shrink-0 text-muted-foreground" aria-hidden />
                <span className="truncate">{path ? path.split('/').at(-1) : t('notes.allNotes')}</span>
                {path && counts.get(path) ? <span className="ms-auto text-xs text-muted-foreground tabular">{counts.get(path)}</span> : null}
              </button>
              {path && (
                <FolderMenu
                  path={path}
                  onNewNote={() => void create(path)}
                  onNewFolder={() => setFolderDialog({ parent: path })}
                  onRename={() => setFolderDialog({ parent: parentOf(path), renaming: path })}
                  onDeleted={() => {
                    if (folder === path || folder.startsWith(`${path}/`)) setFolder('');
                  }}
                />
              )}
            </div>
          );
        })}
      </nav>
      <div className="flex items-center gap-2">
        <Label htmlFor="notes-sort" className="text-xs text-muted-foreground">
          {t('notes.sortBy')}
        </Label>
        <Select value={sort} onValueChange={(value) => setSort(value as Sort)}>
          <SelectTrigger id="notes-sort" className="h-8 flex-1 text-xs">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="edited">{t('notes.sort.edited')}</SelectItem>
            <SelectItem value="created">{t('notes.sort.created')}</SelectItem>
            <SelectItem value="title">{t('notes.sort.title')}</SelectItem>
          </SelectContent>
        </Select>
      </div>
      <ul className="flex flex-col gap-1" aria-label={t('notes.list')}>
        {shown.map((note) => (
          <li key={note.uuid}>
            <Link
              to={`/app/records/${note.uuid}`}
              aria-current={selected === note.uuid ? 'page' : undefined}
              className={cn(
                'flex flex-col rounded-lg px-3 py-2 outline-none hover:bg-accent focus-visible:ring-2 focus-visible:ring-ring',
                selected === note.uuid && 'bg-accent',
              )}
            >
              <span className="truncate font-bold">{note.title || t('notes.untitled')}</span>
              <span className="truncate text-xs text-muted-foreground">{notePreview(note.body) || note.folder || ' '}</span>
            </Link>
          </li>
        ))}
        {shown.length === 0 && <li className="px-3 py-2 text-sm text-muted-foreground">{t('notes.noneHere')}</li>}
      </ul>
      <Link to="/app/records/trash" className="flex items-center gap-2 rounded-md px-2 py-1.5 text-sm font-semibold text-muted-foreground hover:bg-accent">
        <Trash2Icon className="size-4" aria-hidden />
        {t('notes.trash', { count: vault.trash.length })}
      </Link>
      {folderDialog && (
        <FolderDialog
          parent={folderDialog.parent}
          {...(folderDialog.renaming ? { renaming: folderDialog.renaming } : {})}
          onClose={(renamedTo) => {
            const renaming = folderDialog.renaming;
            setFolderDialog(null);
            // The folder I was in moved: follow it.
            if (renaming && renamedTo && (folder === renaming || folder.startsWith(`${renaming}/`))) {
              setFolder(renamedTo + folder.slice(renaming.length));
            }
          }}
        />
      )}
    </aside>
  );
}

// -------------------------------------------------------------- editor

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

function Editor({ note, vault }: { note: NoteRow; vault: Vault }) {
  const { t, i18n } = useTranslation();
  const { notes, attachments, files, clock } = useHarvest();
  const location = useLocation();
  // The assist is the server's or nothing: a key pasted into a browser
  // is a key in everyone's browser ([[ADR-013-Assist-Providers]]).
  const assist = useQuery({ queryKey: ['assist-status'], queryFn: assistStatus, staleTime: 60_000 });
  const [asking, setAsking] = useState<AssistTarget | null>(null);
  const navigate = useNavigate();
  const [title, setTitle] = useState(note.title);
  const [folder, setFolder] = useState(note.folder);
  const [body, setBody] = useState(note.body);
  const [mode, setMode] = useState<'write' | 'read'>(note.body ? 'read' : 'write');
  const area = useRef<HTMLTextAreaElement>(null);
  const pending = useRef<{ title: string; folder: string; body: string; at: string } | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const seen = useRef(note.updatedAt);
  const [inTable, setInTable] = useState(false);
  const [recording, setRecording] = useState<boolean>(() => Boolean((location.state as { record?: boolean } | null)?.record));
  const [reading, setReading] = useState(false);
  const [printing, setPrinting] = useState(false);
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
    void localDictation(i18n.language).then((found) => {
      if (!live) return;
      dictation.current = found;
      setCanDictate(found !== null);
    });
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
    clearTimeout(timer.current);
    timer.current = setTimeout(() => void flush(), 600);
  };

  useEffect(() => {
    const off = registerPendingEdit(flush);
    return () => {
      off();
      void flush();
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

  const openTitle = useOpenTitle(vault.notes, note.folder);
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
    void navigate('/app/records');
    toast(t('notes.movedToTrash'), { action: { label: t('common.undo'), onClick: () => void notes.restore(note.uuid) } });
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
  const printDone = useCallback(() => setPrinting(false), []);

  return (
    <article className="flex min-w-0 flex-col gap-3">
      <div className="flex items-center gap-2">
        <Button asChild variant="ghost" size="icon" className="md:hidden" aria-label={t('notes.backToList')}>
          <Link to="/app/records">
            <ArrowLeftIcon className="rtl:rotate-180" />
          </Link>
        </Button>
        <Label htmlFor="note-title" className="sr-only">
          {t('notes.title')}
        </Label>
        <Input
          id="note-title"
          value={title}
          placeholder={t('notes.untitled')}
          className="h-12 bg-transparent px-0 text-2xl font-extrabold focus-visible:ring-0"
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
                void flush();
                setPrinting(true);
              }}
            >
              <PrinterIcon />
              {t('notes.exportPdf')}
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
        <Button variant="ghost" size="icon" aria-label={t('notes.moveToTrash')} onClick={() => void remove()}>
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
            if (file) void attach(file);
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
          className="h-8 w-48 text-xs"
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
            <div role="toolbar" aria-label={t('notes.formatting')} className="flex flex-wrap gap-0.5">
              {tools.map((tool) => (
                <Button key={tool.label} variant="ghost" size="icon-sm" aria-label={tool.label} title={tool.label} onClick={() => format(tool.spec)}>
                  {tool.icon}
                </Button>
              ))}
              <Button variant="ghost" size="icon-sm" aria-label={t('notes.tool.table')} title={t('notes.tool.table')} onClick={() => applyEdit(insertTable(caret()))}>
                <TableIcon />
              </Button>
              {inTable && (
                <>
                  <Button variant="ghost" size="sm" className="h-8 px-2" title={t('notes.tool.tableRow')} onClick={() => applyEdit(addTableRow(caret()))}>
                    <PlusIcon />
                    {t('notes.tool.rowShort')}
                    <span className="sr-only">{t('notes.tool.tableRow')}</span>
                  </Button>
                  <Button variant="ghost" size="sm" className="h-8 px-2" title={t('notes.tool.tableColumn')} onClick={() => applyEdit(addTableColumn(caret()))}>
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
                        onClick={() => void openTitle(linkTitle)}
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
                void (async () => {
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
                })();
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
            if (location.state) void navigate(location.pathname, { replace: true, state: null });
            if (fileName) {
              setMode('write');
              insertAtCaret(audioEmbed(fileName), true);
            }
          }}
        />
      )}
      {reading && <ReadAloudDialog markdown={body} onClose={() => setReading(false)} />}
      {printing && <NotePrint note={{ ...note, title, folder, body }} onDone={printDone} />}

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
                      onClick={() => void openTitle(link.title)}
                      className={cn('text-sm font-semibold hover:underline', target ? 'text-primary' : 'text-muted-foreground italic')}
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
                  <Link to={`/app/records/${other.uuid}`} className="text-sm font-semibold text-primary hover:underline">
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

function Trash({ vault }: { vault: Vault }) {
  const { t } = useTranslation();
  const { notes } = useHarvest();
  const navigate = useNavigate();
  return (
    <section className="flex flex-col gap-3" aria-labelledby="trash-heading">
      <div className="flex items-center gap-2">
        <Button asChild variant="ghost" size="icon" aria-label={t('notes.backToList')}>
          <Link to="/app/records">
            <ArrowLeftIcon className="rtl:rotate-180" />
          </Link>
        </Button>
        <h1 id="trash-heading" className="flex-1 text-xl font-extrabold">
          {t('notes.trashTitle')}
        </h1>
        {vault.trash.length > 0 && (
          <AlertDialog>
            <AlertDialogTrigger asChild>
              <Button variant="outline">{t('notes.emptyTrash')}</Button>
            </AlertDialogTrigger>
            <AlertDialogContent>
              <AlertDialogHeader>
                <AlertDialogTitle>{t('notes.emptyTrashTitle')}</AlertDialogTitle>
                <AlertDialogDescription>{t('notes.emptyTrashBody', { count: vault.trash.length })}</AlertDialogDescription>
              </AlertDialogHeader>
              <AlertDialogFooter>
                <AlertDialogCancel>{t('common.cancel')}</AlertDialogCancel>
                <AlertDialogAction destructive onClick={() => void notes.emptyTrash()}>
                  {t('notes.emptyTrash')}
                </AlertDialogAction>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialog>
        )}
      </div>
      {vault.trash.length === 0 ? (
        <p className="text-muted-foreground">{t('notes.trashEmpty')}</p>
      ) : (
        <ul className="flex flex-col gap-2">
          {vault.trash.map((note) => (
            <li key={note.uuid} className="flex items-center gap-3 rounded-xl border bg-card p-3">
              <div className="flex min-w-0 flex-1 flex-col">
                <span className="truncate font-bold">{note.title || t('notes.untitled')}</span>
                <span className="truncate text-xs text-muted-foreground">{notePreview(note.body)}</span>
              </div>
              <Button
                variant="outline"
                size="sm"
                onClick={() =>
                  void notes.restore(note.uuid).then(() =>
                    toast(t('notes.restoredToast', { title: note.title || t('notes.untitled') }), {
                      action: { label: t('notes.openRestored'), onClick: () => void navigate(`/app/records/${note.uuid}`) },
                    }),
                  )
                }
              >
                <RotateCcwIcon />
                {t('notes.restore')}
              </Button>
              <Button variant="ghost" size="icon-sm" aria-label={t('notes.deleteForever', { title: note.title })} onClick={() => void notes.purge(note.uuid)}>
                <Trash2Icon />
              </Button>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

/**
 * Puts drafts left in `localStorage` back into their notes: only one
 * typed after the note last changed — a newer save, here or from another
 * device, already holds it or overrules it. A draft for a note this
 * account does not have stays for the account that does.
 */
async function restoreDrafts(db: HarvestDB, notes: NotesRepository): Promise<void> {
  for (const [uuid, draft] of leftDrafts()) {
    const row = await db.rows('notes').get(uuid);
    if (!row) continue;
    if (row.deletedAt === null && draft.at > row.updatedAt) {
      await notes.update(uuid, { title: draft.title, folder: draft.folder, body: draft.body });
    }
    dropDraft(uuid, draft.at);
  }
}

/** Records: the notes vault, with the sidebar beside the note ([[Notes]]). */
export function NotesScreen({ trash = false }: { trash?: boolean }) {
  const { t } = useTranslation();
  const { db, notes } = useHarvest();
  const navigate = useNavigate();
  const { uuid } = useParams();
  const vault = useLiveQuery(() => loadVault(db), [db]);
  const [folder, setFolder] = useState('');
  const off = useRecordsOff();
  // Typing a reload cut off before it was saved goes back in first, so
  // no note opens without it — nor as an empty "Untitled" (W4-02).
  const [restored, setRestored] = useState(false);
  useEffect(() => {
    let live = true;
    void restoreDrafts(db, notes).finally(() => live && setRestored(true));
    return () => {
      live = false;
    };
  }, [db, notes]);
  if (!vault || off === undefined || !restored) return null;
  if (off) return <RecordsOff />;
  const note = uuid ? vault.notes.find((row) => row.uuid === uuid) : undefined;
  const detail = trash || uuid !== undefined;

  return (
    <div className="flex flex-col gap-4">
      <RecordsTabs />
      <div className="grid gap-6 md:grid-cols-[18rem_1fr]">
      <div className={cn(detail && 'hidden md:block')}>
        <Sidebar vault={vault} folder={folder} setFolder={setFolder} selected={uuid} />
      </div>
      <div className={cn('min-w-0', !detail && 'hidden md:block')}>
        {trash ? (
          <Trash vault={vault} />
        ) : note ? (
          <Editor key={note.uuid} note={note} vault={vault} />
        ) : uuid ? (
          <EmptyState icon={<FileTextIcon />} title={t('notes.gone')} />
        ) : (
          <EmptyState
            icon={<FileTextIcon />}
            title={vault.notes.length ? t('notes.pick') : t('notes.emptyTitle')}
            body={t('notes.emptyBody')}
            action={
              <Button
                onClick={() => {
                  void notes.create({ folder }).then((created) => navigate(`/app/records/${created.uuid}`));
                }}
              >
                <FilePlusIcon />
                {t('notes.new')}
              </Button>
            }
          />
        )}
        </div>
      </div>
    </div>
  );
}
