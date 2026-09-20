import { useLiveQuery } from 'dexie-react-hooks';
import {
  ArrowLeftIcon,
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
import { Link, useNavigate, useParams } from 'react-router';
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
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { formatDate } from '@/lib/format';
import { Markdown } from '@/lib/markdown';
import { registerPendingEdit } from '@/lib/pending-edits';
import { cn } from '@/lib/utils';
import { EmptyState } from '../components/bits';
import { useHarvest } from '../context';
import { RecordsTabs } from './records';
import { decodeFolders, folderTree, linksIn, notePreview, type NoteRow } from '../data/notes';
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

function FolderDialog({ parent, onClose }: { parent: string; onClose: () => void }) {
  const { t } = useTranslation();
  const { notes } = useHarvest();
  const [name, setName] = useState('');
  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-sm">
        <DialogHeader>
          <DialogTitle>{t('notes.newFolder')}</DialogTitle>
          <DialogDescription>{parent ? t('notes.insideFolder', { folder: parent }) : t('notes.atRoot')}</DialogDescription>
        </DialogHeader>
        <form
          className="flex flex-col gap-3"
          onSubmit={(event) => {
            event.preventDefault();
            if (!name.trim()) return;
            void notes.addFolder(parent ? `${parent}/${name}` : name).then(onClose);
          }}
        >
          <Label htmlFor="folder-name">{t('notes.folderName')}</Label>
          <Input id="folder-name" autoFocus value={name} onChange={(event) => setName(event.target.value)} />
          <DialogFooter>
            <Button variant="outline" onClick={onClose}>
              {t('common.cancel')}
            </Button>
            <Button type="submit">{t('common.create')}</Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
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
  const [makingFolder, setMakingFolder] = useState(false);

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

  const create = async () => {
    const note = await notes.create({ folder });
    void navigate(`/app/records/${note.uuid}`);
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
        <Button variant="outline" size="icon" aria-label={t('notes.newFolder')} onClick={() => setMakingFolder(true)}>
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
            <button
              key={path || 'root'}
              type="button"
              aria-current={folder === path ? 'true' : undefined}
              onClick={() => setFolder(path)}
              style={{ paddingInlineStart: `${0.5 + depth * 0.9}rem` }}
              className={cn(
                'flex items-center gap-2 rounded-md py-1.5 pe-2 text-start text-sm font-semibold outline-none hover:bg-accent focus-visible:ring-2 focus-visible:ring-ring',
                folder === path && 'bg-accent text-accent-foreground',
              )}
            >
              <FolderIcon className="size-4 shrink-0 text-muted-foreground" aria-hidden />
              <span className="truncate">{path ? path.split('/').at(-1) : t('notes.allNotes')}</span>
              {path && counts.get(path) ? <span className="ms-auto text-xs text-muted-foreground tabular">{counts.get(path)}</span> : null}
            </button>
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
      {makingFolder && <FolderDialog parent={folder} onClose={() => setMakingFolder(false)} />}
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
  const { t } = useTranslation();
  const { notes } = useHarvest();
  const navigate = useNavigate();
  const [title, setTitle] = useState(note.title);
  const [folder, setFolder] = useState(note.folder);
  const [body, setBody] = useState(note.body);
  const [mode, setMode] = useState<'write' | 'read'>(note.body ? 'read' : 'write');
  const area = useRef<HTMLTextAreaElement>(null);
  const pending = useRef<{ title: string; folder: string; body: string } | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const seen = useRef(note.updatedAt);

  const flush = useCallback(async () => {
    clearTimeout(timer.current);
    const changes = pending.current;
    pending.current = null;
    if (changes) await notes.update(note.uuid, changes);
  }, [notes, note.uuid]);

  // Autosave, debounced: there is no Save button to miss ([[Notes]]).
  const schedule = (next: { title: string; folder: string; body: string }) => {
    pending.current = next;
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
        <Button variant="ghost" size="icon" aria-label={t('notes.moveToTrash')} onClick={() => void remove()}>
          <Trash2Icon />
        </Button>
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
      </div>

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
            </div>
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
            className="min-h-[55dvh] w-full resize-y rounded-xl border bg-card p-4 font-mono text-[15px] leading-relaxed outline-none focus-visible:ring-2 focus-visible:ring-ring"
          />
        </TabsContent>
        <TabsContent value="read">
          <div className="min-h-[55dvh] rounded-xl border bg-card p-4" dir="auto">
            {body.trim() ? (
              <Markdown
                source={body}
                options={{
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
              <Button variant="outline" size="sm" onClick={() => void notes.restore(note.uuid)}>
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

/** Records: the notes vault, with the sidebar beside the note ([[Notes]]). */
export function NotesScreen({ trash = false }: { trash?: boolean }) {
  const { t } = useTranslation();
  const { db, notes } = useHarvest();
  const navigate = useNavigate();
  const { uuid } = useParams();
  const vault = useLiveQuery(() => loadVault(db), [db]);
  const [folder, setFolder] = useState('');
  if (!vault) return null;
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
