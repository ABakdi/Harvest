import { MicIcon, PlusIcon, FilePlusIcon, FolderIcon, FolderPlusIcon, Trash2Icon } from 'lucide-react';
import { useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Link, useNavigate } from 'react-router';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { cn } from '@/lib/utils';
import { recordingFormat } from '../../components/notes/voice';
import { useHarvest } from '../../context';
import { AppBarActions } from '../../components/app-bar';
import { voiceNoteTitle } from '../../data/attachments';
import { notePreview, type NoteRow } from '../../data/notes';
import { background, runAction } from '@/lib/actions';
import type { Vault } from './vault';
import { parentOf, FolderDialog, FolderMenu } from './folders';

type Sort = 'edited' | 'created' | 'title';

export function Sidebar({
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
    background(navigate(`/app/records/${note.uuid}`));
  };

  // The three-second path: a note named by the minute, recording at once.
  const createVoice = async () => {
    const note = await notes.create({ title: voiceNoteTitle(new Date()), folder });
    background(navigate(`/app/records/${note.uuid}`, { state: { record: true } }));
  };

  const counts = new Map<string, number>();
  for (const note of vault.notes) counts.set(note.folder, (counts.get(note.folder) ?? 0) + 1);

  return (
    <aside className="flex flex-col gap-3" aria-label={t('notes.sidebar')}>
      {/* On a phone the microphone and the "+" sit in the app bar, as there. */}
      <AppBarActions>
        {recordingFormat() !== null && (
          <Button
            variant="ghost"
            size="icon"
            // At 200% on a phone the bar keeps room for the "+" (W6-06).
            className="@max-[14rem]/bar:hidden"
            aria-label={t('voice.newNote')}
            title={t('voice.newNote')}
            onClick={() => runAction(() => createVoice())}
          >
            <MicIcon />
          </Button>
        )}
        <Button variant="ghost" size="icon" aria-label={t('notes.new')} title={t('notes.new')} onClick={() => runAction(() => create())}>
          <PlusIcon />
        </Button>
      </AppBarActions>
      <div className="flex gap-2 max-md:justify-end">
        <Button className="flex-1 max-md:hidden" onClick={() => runAction(() => create())}>
          <FilePlusIcon />
          {t('notes.new')}
        </Button>
        {recordingFormat() !== null && (
          <Button
            variant="outline"
            size="icon"
            className="max-md:hidden"
            aria-label={t('voice.newNote')}
            title={t('voice.newNote')}
            onClick={() => runAction(() => createVoice())}
          >
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
                className="flex min-w-0 flex-1 items-center gap-2 rounded-md py-1.5 pe-2 text-start text-sm font-semibold outline-none hover:bg-accent focus-visible:ring-2 focus-visible:ring-ring max-md:min-h-11"
              >
                <FolderIcon className="size-4 shrink-0 text-muted-foreground" aria-hidden />
                <span className="truncate">{path ? path.split('/').at(-1) : t('notes.allNotes')}</span>
                {path && counts.get(path) ? <span className="ms-auto text-xs text-muted-foreground tabular">{counts.get(path)}</span> : null}
              </button>
              {path && (
                <FolderMenu
                  path={path}
                  onNewNote={() => runAction(() => create(path))}
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
          <SelectTrigger id="notes-sort" className="h-8 flex-1 text-xs max-md:h-11">
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
              <span dir="auto" className="truncate font-bold">{note.title || t('notes.untitled')}</span>
              <span dir="auto" className="truncate text-xs text-muted-foreground">{notePreview(note.body) || note.folder || ' '}</span>
            </Link>
          </li>
        ))}
        {shown.length === 0 && <li className="px-3 py-2 text-sm text-muted-foreground">{t('notes.noneHere')}</li>}
      </ul>
      <Link
        to="/app/records/trash"
        className="flex items-center gap-2 rounded-md px-2 py-1.5 text-sm font-semibold text-muted-foreground hover:bg-accent max-md:min-h-11"
      >
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
