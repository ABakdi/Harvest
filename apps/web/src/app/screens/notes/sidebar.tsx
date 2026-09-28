import {
  ArrowUpDownIcon,
  CheckIcon,
  ChevronRightIcon,
  ChevronsDownUpIcon,
  ChevronsUpDownIcon,
  FileTextIcon,
  FolderIcon,
  FolderOpenIcon,
  FolderPlusIcon,
  MicIcon,
  PlusIcon,
  SearchIcon,
  SquarePenIcon,
  Trash2Icon,
  XIcon,
} from 'lucide-react';
import { Dialog as DialogPrimitive } from 'radix-ui';
import { useMemo, useRef, useState, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { Link } from 'react-router';
import { Button } from '@/components/ui/button';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { cn } from '@/lib/utils';
import { recordingFormat } from '../../components/notes/voice';
import { notePreview, type NoteRow } from '../../data/notes';
import { runAction } from '@/lib/actions';
import { childFolders, foldersAbove, searchNotes, sortNotes, type Sort, type Vault } from './vault';
import { parentOf, FolderDialog, FolderMenu } from './folders';

/** What the tree and its header can ask the screen to do. */
export interface VaultActions {
  /** Makes a note in [folder] and opens it. */
  newNote: (folder: string) => Promise<void>;
  /** A note named by the minute, recording at once. */
  newVoiceNote: (folder: string) => Promise<void>;
}

// --------------------------------------------------------------- the tree

/**
 * Which folders are open. A wide window remembers the ones I folded,
 * as Obsidian does, so a folder made since shows open; the phone's
 * drawer starts folded, with the way to the open note unfolded.
 */
function useFolding(variant: 'desktop' | 'phone', selectedFolder: string | undefined) {
  const key = 'harvest.notes.folded';
  const [folded, setFolded] = useState<Set<string>>(() => {
    if (variant === 'phone') return new Set();
    try {
      return new Set(JSON.parse(localStorage.getItem(key) ?? '[]') as string[]);
    } catch {
      return new Set();
    }
  });
  const [opened, setOpened] = useState<Set<string>>(() => new Set(foldersAbove(selectedFolder ?? '')));
  const save = (next: Set<string>) => {
    setFolded(next);
    try {
      localStorage.setItem(key, JSON.stringify([...next]));
    } catch {
      // Folding is only a convenience; a browser that keeps nothing starts unfolded.
    }
  };
  // The open note's folders unfold, so the note is in sight.
  const [revealed, setRevealed] = useState(selectedFolder);
  if (revealed !== selectedFolder) {
    setRevealed(selectedFolder);
    const above = foldersAbove(selectedFolder ?? '');
    if (above.length > 0) {
      if (variant === 'phone') setOpened(new Set([...opened, ...above]));
      else if (above.some((path) => folded.has(path))) setFolded(new Set([...folded].filter((path) => !above.includes(path))));
    }
  }
  const isOpen = (path: string) => (variant === 'phone' ? opened.has(path) : !folded.has(path));
  const toggle = (path: string) => {
    if (variant === 'phone') {
      const next = new Set(opened);
      if (!next.delete(path)) next.add(path);
      setOpened(next);
    } else {
      const next = new Set(folded);
      if (!next.delete(path)) next.add(path);
      save(next);
    }
  };
  const setAll = (open: boolean, folders: string[]) => {
    if (variant === 'phone') setOpened(new Set(open ? folders : []));
    else save(new Set(open ? [] : folders));
  };
  return { isOpen, toggle, setAll };
}

interface TreeProps {
  vault: Vault;
  sort: Sort;
  query: string;
  selected: string | undefined;
  variant: 'desktop' | 'phone';
  folding: ReturnType<typeof useFolding>;
  actions: VaultActions;
  /** The folder a new note or folder goes in, chosen by clicking one. */
  onFocusFolder: (folder: string) => void;
  onFolderDialog: (dialog: { parent: string; renaming?: string }) => void;
  onFolderGone: (path: string) => void;
  /** A note picked: the drawer closes on a phone. */
  onPicked?: (() => void) | undefined;
}

/** Folders first, then the notes, each level as Obsidian's file explorer lists it. */
function VaultTree(props: TreeProps) {
  const { t } = useTranslation();
  const { vault, sort, query, selected, variant, onPicked } = props;
  const phone = variant === 'phone';
  const counts = useMemo(() => {
    const byFolder = new Map<string, number>();
    for (const note of vault.notes) {
      for (const path of foldersAbove(note.folder)) byFolder.set(path, (byFolder.get(path) ?? 0) + 1);
    }
    return byFolder;
  }, [vault.notes]);

  if (query.trim()) {
    const found = searchNotes(vault.notes, query, sort);
    if (found.length === 0) {
      return <p className="px-4 py-6 text-center text-sm text-muted-foreground">{t('notes.noMatch')}</p>;
    }
    return (
      <ul className="flex flex-col" aria-label={t('notes.list')}>
        {found.map((note) => (
          <li key={note.uuid}>
            <NoteLink note={note} depth={0} selected={selected} phone={phone} onPicked={onPicked} preview />
          </li>
        ))}
      </ul>
    );
  }

  return (
    <ul className="flex flex-col" aria-label={t('notes.list')}>
      <Level {...props} parent="" depth={0} counts={counts} />
    </ul>
  );
}

function Level(props: TreeProps & { parent: string; depth: number; counts: Map<string, number> }) {
  const { t } = useTranslation();
  const { vault, sort, selected, variant, actions, parent, depth, onPicked } = props;
  const phone = variant === 'phone';
  const notes = sortNotes(
    vault.notes.filter((note) => note.folder === parent),
    sort,
  );
  return (
    <>
      {childFolders(vault.folders, parent).map((path) => (
        <FolderNode key={path} {...props} path={path} />
      ))}
      {notes.map((note) => (
        <li key={note.uuid}>
          <NoteLink note={note} depth={depth} selected={selected} phone={phone} onPicked={onPicked} />
        </li>
      ))}
      {/* The phone's "+ New note" under each open folder and at the foot. */}
      {phone && (
        <li>
          <button
            type="button"
            onClick={() => runAction(() => actions.newNote(parent))}
            style={{ paddingInlineStart: `${1 + depth * 0.875}rem` }}
            className="flex min-h-12 w-full items-center gap-2 pe-4 text-start text-sm font-bold text-primary outline-none hover:bg-accent focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ring"
          >
            <PlusIcon className="size-[17px]" aria-hidden />
            {t('notes.newHere')}
          </button>
        </li>
      )}
      {!phone && depth === 0 && vault.notes.length === 0 && vault.folders.length === 0 && (
        <li className="px-3 py-2 text-sm text-muted-foreground">{t('notes.noneHere')}</li>
      )}
    </>
  );
}

function FolderNode(props: TreeProps & { path: string; depth: number; counts: Map<string, number> }) {
  const { variant, folding, actions, path, depth, counts, onFocusFolder, onFolderDialog, onFolderGone } = props;
  const phone = variant === 'phone';
  const open = folding.isOpen(path);
  const name = path.split('/').at(-1) ?? path;
  const count = counts.get(path) ?? 0;
  const menu = (
    <FolderMenu
      path={path}
      className={phone ? 'size-11 text-muted-foreground' : 'size-6 rounded-sm text-muted-foreground opacity-0 group-hover:opacity-100 focus-visible:opacity-100 data-[state=open]:opacity-100 [&_svg]:size-3.5'}
      onNewNote={() => runAction(() => actions.newNote(path))}
      onNewFolder={() => onFolderDialog({ parent: path })}
      onRename={() => onFolderDialog({ parent: parentOf(path), renaming: path })}
      onDeleted={() => onFolderGone(path)}
    />
  );
  return (
    <li>
      <div className={cn('group flex items-center', phone ? 'min-h-12 pe-1 hover:bg-accent' : 'h-7 rounded-md pe-0.5 hover:bg-foreground/[0.06]')}>
        <button
          type="button"
          aria-expanded={open}
          onClick={() => {
            folding.toggle(path);
            onFocusFolder(path);
          }}
          style={{ paddingInlineStart: phone ? `${1 + depth * 0.875}rem` : `${0.25 + depth * 1.05}rem` }}
          className={cn(
            'flex h-full min-w-0 flex-1 items-center gap-1 text-start outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ring',
            phone ? 'min-h-12 gap-1 text-sm font-bold' : 'rounded-md text-[13.5px] font-semibold text-foreground/90',
          )}
        >
          <ChevronRightIcon
            className={cn('shrink-0 text-muted-foreground transition-transform', phone ? 'size-[18px]' : 'size-3.5', open ? 'rotate-90' : 'rtl:rotate-180')}
            aria-hidden
          />
          {phone &&
            (open ? <FolderOpenIcon className="size-[18px] shrink-0 text-sun" aria-hidden /> : <FolderIcon className="size-[18px] shrink-0 fill-sun/30 text-sun" aria-hidden />)}
          {/* Not stretched: a name in the other script keeps to the row's start. */}
          <span dir="auto" className={cn('min-w-0 truncate', phone && 'ms-1')}>
            {name}
          </span>
          {phone && count > 0 && (
            <span aria-hidden className="ms-auto ps-2 text-xs font-semibold text-muted-foreground tabular">
              {count}
            </span>
          )}
        </button>
        {menu}
      </div>
      {open && (
        <ul className={cn('flex flex-col', !phone && 'relative before:absolute before:inset-y-0 before:start-[var(--guide)] before:w-px before:bg-border')} style={phone ? undefined : { ['--guide' as string]: `${0.72 + depth * 1.05}rem` }}>
          <Level {...props} parent={path} depth={depth + 1} />
        </ul>
      )}
    </li>
  );
}

function NoteLink({
  note,
  depth,
  selected,
  phone,
  onPicked,
  preview = false,
}: {
  note: NoteRow;
  depth: number;
  selected: string | undefined;
  phone: boolean;
  onPicked?: (() => void) | undefined;
  preview?: boolean;
}) {
  const { t } = useTranslation();
  const active = selected === note.uuid;
  // An untitled note goes by its first line on a wide window, where the tree has room to tell them apart.
  const title = note.title || (!phone && notePreview(note.body)) || t('notes.untitled');
  return (
    <Link
      to={`/app/records/${note.uuid}`}
      // On a phone a note opens in place of the one on show, as there:
      // Back then closes it rather than stepping through every note.
      replace={phone && selected !== undefined}
      onClick={onPicked}
      aria-current={active ? 'page' : undefined}
      style={{ paddingInlineStart: phone ? `${1 + depth * 0.875}rem` : `${1.35 + depth * 1.05}rem` }}
      className={cn(
        'flex min-w-0 outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ring',
        phone
          ? cn('min-h-12 items-center gap-2 pe-4 text-sm', active ? 'bg-secondary/70 font-extrabold' : 'font-medium hover:bg-accent')
          : cn(
              'rounded-md pe-2 text-[13.5px]',
              preview ? 'flex-col py-1.5' : 'h-7 items-center',
              active ? 'bg-accent font-semibold text-accent-foreground' : 'text-foreground/80 hover:bg-foreground/[0.06] hover:text-foreground',
            ),
      )}
    >
      {phone && <FileTextIcon className={cn('size-[17px] shrink-0', active ? 'text-success' : 'text-muted-foreground')} aria-hidden />}
      <span dir="auto" className={cn('min-w-0 truncate', !note.title && 'text-muted-foreground italic')}>
        {title}
      </span>
      {preview && !phone && (
        <span dir="auto" className="min-w-0 truncate text-xs font-normal text-muted-foreground">
          {notePreview(note.body) || note.folder || ' '}
        </span>
      )}
    </Link>
  );
}

// ------------------------------------------------------------ the sort menu

function SortMenu({ sort, setSort, trigger }: { sort: Sort; setSort: (sort: Sort) => void; trigger: ReactNode }) {
  const { t } = useTranslation();
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>{trigger}</DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        {(['edited', 'created', 'title'] as const).map((value) => (
          <DropdownMenuItem key={value} onSelect={() => setSort(value)} aria-checked={sort === value} role="menuitemradio">
            <CheckIcon className={cn(sort !== value && 'invisible')} />
            {t(`notes.sort.${value}`)}
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}

function useSort(): [Sort, (sort: Sort) => void] {
  const key = 'harvest.notes.sort';
  const [sort, setSort] = useState<Sort>(() => {
    try {
      const stored = localStorage.getItem(key);
      return stored === 'created' || stored === 'title' ? stored : 'edited';
    } catch {
      return 'edited';
    }
  });
  return [
    sort,
    (next) => {
      setSort(next);
      try {
        localStorage.setItem(key, next);
      } catch {
        // The order is a convenience.
      }
    },
  ];
}

// ------------------------------------------------------------ wide window

const widthKey = 'harvest.notes.sidebarWidth';
const minWidth = 200;
const maxWidth = 480;

function storedWidth(): number {
  try {
    const value = Number(localStorage.getItem(widthKey));
    return value >= minWidth && value <= maxWidth ? value : 272;
  } catch {
    return 272;
  }
}

/**
 * The vault down the side of a wide window, as Obsidian's file explorer
 * draws it: a row of small actions, the tree of folders and notes, and
 * the trash at its foot. Its edge drags to make it wider.
 */
export function Sidebar({
  vault,
  folder,
  setFolder,
  selected,
  selectedFolder,
  actions,
}: {
  vault: Vault;
  /** The folder a new note or folder goes in. */
  folder: string;
  setFolder: (folder: string) => void;
  selected: string | undefined;
  selectedFolder: string | undefined;
  actions: VaultActions;
}) {
  const { t } = useTranslation();
  const [query, setQuery] = useState('');
  const [sort, setSort] = useSort();
  const [folderDialog, setFolderDialog] = useState<{ parent: string; renaming?: string } | null>(null);
  const folding = useFolding('desktop', selectedFolder);
  const [width, setWidth] = useState(storedWidth);
  const drag = useRef<{ x: number; width: number; rtl: boolean } | null>(null);
  const anyOpen = vault.folders.some((path) => folding.isOpen(path));

  const resize = (next: number) => {
    const clamped = Math.round(Math.min(maxWidth, Math.max(minWidth, next)));
    setWidth(clamped);
    try {
      localStorage.setItem(widthKey, String(clamped));
    } catch {
      // The width is a convenience.
    }
  };

  const tool = (label: string, icon: ReactNode, onClick?: () => void, extra?: object) => (
    <Button variant="ghost" size="icon-sm" className="size-7 text-muted-foreground hover:text-foreground" aria-label={label} title={label} onClick={onClick} {...extra}>
      {icon}
    </Button>
  );

  return (
    <aside
      className="relative flex min-h-0 shrink-0 flex-col border-e bg-muted/60"
      style={{ width }}
      aria-label={t('notes.sidebar')}
      data-testid="notes-sidebar"
    >
      <div className="flex h-10 shrink-0 items-center justify-center gap-0.5 border-b px-2">
        {tool(t('notes.new'), <SquarePenIcon />, () => runAction(() => actions.newNote(folder)))}
        {tool(t('notes.newFolder'), <FolderPlusIcon />, () => setFolderDialog({ parent: folder }))}
        {recordingFormat() !== null && tool(t('voice.newNote'), <MicIcon />, () => runAction(() => actions.newVoiceNote(folder)))}
        <SortMenu sort={sort} setSort={setSort} trigger={tool(t('notes.sortBy'), <ArrowUpDownIcon />)} />
        {tool(
          anyOpen ? t('notes.collapseAll') : t('notes.expandAll'),
          anyOpen ? <ChevronsDownUpIcon /> : <ChevronsUpDownIcon />,
          () => folding.setAll(!anyOpen, vault.folders),
        )}
      </div>
      <div className="shrink-0 px-2 pt-2 pb-1">
        <Label htmlFor="notes-search" className="sr-only">
          {t('notes.search')}
        </Label>
        <div className="relative">
          <SearchIcon className="pointer-events-none absolute start-2 top-1/2 size-3.5 -translate-y-1/2 text-muted-foreground" aria-hidden />
          <Input
            id="notes-search"
            type="search"
            placeholder={t('notes.search')}
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            className="h-8 rounded-md bg-background/70 ps-7 text-[13px]"
          />
        </div>
      </div>
      <nav aria-label={t('notes.folders')} className="min-h-0 flex-1 overflow-y-auto overscroll-contain px-1.5 pt-1 pb-6" data-notes-tree>
        <VaultTree
          vault={vault}
          sort={sort}
          query={query}
          selected={selected}
          variant="desktop"
          folding={folding}
          actions={actions}
          onFocusFolder={setFolder}
          onFolderDialog={setFolderDialog}
          onFolderGone={(path) => {
            if (folder === path || folder.startsWith(`${path}/`)) setFolder('');
          }}
        />
      </nav>
      <div className="shrink-0 border-t p-1.5">
        <Link
          to="/app/records/trash"
          className="flex h-8 items-center gap-2 rounded-md px-2 text-[13px] font-semibold text-muted-foreground outline-none hover:bg-foreground/[0.06] hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring"
        >
          <Trash2Icon className="size-4" aria-hidden />
          {t('notes.trash', { count: vault.trash.length })}
        </Link>
      </div>
      {/* The edge: dragged, or moved with the arrow keys, it sets the width. */}
      <div
        role="separator"
        aria-orientation="vertical"
        aria-label={t('notes.resizeSidebar')}
        aria-valuemin={minWidth}
        aria-valuemax={maxWidth}
        aria-valuenow={width}
        tabIndex={0}
        className="absolute inset-y-0 -end-1 z-10 w-2 cursor-col-resize touch-none outline-none after:absolute after:inset-y-0 after:start-1/2 after:w-0.5 after:-translate-x-1/2 after:bg-transparent after:transition-colors hover:after:bg-ring/60 focus-visible:after:bg-ring"
        onPointerDown={(event) => {
          event.currentTarget.setPointerCapture(event.pointerId);
          drag.current = { x: event.clientX, width, rtl: getComputedStyle(event.currentTarget).direction === 'rtl' };
        }}
        onPointerMove={(event) => {
          const current = drag.current;
          if (!current) return;
          const dx = event.clientX - current.x;
          resize(current.width + (current.rtl ? -dx : dx));
        }}
        onPointerUp={() => {
          drag.current = null;
        }}
        onKeyDown={(event) => {
          const rtl = getComputedStyle(event.currentTarget).direction === 'rtl';
          if (event.key === 'ArrowRight') resize(width + (rtl ? -16 : 16));
          else if (event.key === 'ArrowLeft') resize(width + (rtl ? 16 : -16));
          else return;
          event.preventDefault();
        }}
      />
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

// --------------------------------------------------------------- the phone

/**
 * The vault in the phone's drawer (`NotesSidebar`): "Notes" with a new
 * folder and the sort at its head, the search, the tree with a "+ New
 * note" in each open folder, and the trash at the foot.
 */
export function NotesDrawer({
  open,
  onOpenChange,
  vault,
  selected,
  selectedFolder,
  actions,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  vault: Vault;
  selected: string | undefined;
  selectedFolder: string | undefined;
  actions: VaultActions;
}) {
  const { t } = useTranslation();
  const [query, setQuery] = useState('');
  const [sort, setSort] = useSort();
  const [folderDialog, setFolderDialog] = useState<{ parent: string; renaming?: string } | null>(null);
  const folding = useFolding('phone', selectedFolder);
  const close = () => onOpenChange(false);
  const wrapped: VaultActions = {
    newNote: (folder) => {
      close();
      return actions.newNote(folder);
    },
    newVoiceNote: (folder) => {
      close();
      return actions.newVoiceNote(folder);
    },
  };

  return (
    <>
      <DialogPrimitive.Root open={open} onOpenChange={onOpenChange}>
        <DialogPrimitive.Portal>
          <DialogPrimitive.Overlay className="fixed inset-0 z-50 bg-black/45 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:animate-in data-[state=open]:fade-in-0" />
          <DialogPrimitive.Content
            aria-describedby={undefined}
            // The drawer itself takes the focus, as the phone's does, not
            // its first button.
            tabIndex={-1}
            onOpenAutoFocus={(event) => {
              event.preventDefault();
              (event.currentTarget as HTMLElement | null)?.focus();
            }}
            data-testid="notes-drawer"
            className="fixed inset-y-0 start-0 z-50 flex w-[min(20rem,85vw)] flex-col rounded-e-2xl bg-background pt-[env(safe-area-inset-top)] pb-[env(safe-area-inset-bottom)] shadow-xl outline-none duration-200 data-[state=closed]:animate-out data-[state=closed]:slide-out-to-start data-[state=open]:animate-in data-[state=open]:slide-in-from-start"
          >
            <div className="flex shrink-0 items-center gap-1 ps-4 pe-2 pt-4 pb-1">
              <DialogPrimitive.Title className="min-w-0 flex-1 truncate text-2xl font-extrabold">{t('notes.sidebar')}</DialogPrimitive.Title>
              <Button variant="ghost" size="icon" aria-label={t('notes.newFolder')} title={t('notes.newFolder')} onClick={() => setFolderDialog({ parent: '' })}>
                <FolderPlusIcon className="size-6" />
              </Button>
              <SortMenu
                sort={sort}
                setSort={setSort}
                trigger={
                  <Button variant="ghost" size="icon" aria-label={t('notes.sortBy')} title={t('notes.sortBy')}>
                    <ArrowUpDownIcon className="size-6" />
                  </Button>
                }
              />
            </div>
            <div className="shrink-0 px-4 pb-1">
              <Label htmlFor="notes-drawer-search" className="sr-only">
                {t('notes.search')}
              </Label>
              <div className="relative">
                <SearchIcon className="pointer-events-none absolute start-4 top-1/2 size-5 -translate-y-1/2 text-muted-foreground" aria-hidden />
                <Input
                  id="notes-drawer-search"
                  type="search"
                  placeholder={t('notes.search')}
                  value={query}
                  onChange={(event) => setQuery(event.target.value)}
                  className="h-12 rounded-2xl border-0 bg-secondary/60 ps-12 pe-11 text-base [&::-webkit-search-cancel-button]:hidden"
                />
                {query && (
                  <Button
                    variant="ghost"
                    size="icon"
                    className="absolute end-0.5 top-1/2 -translate-y-1/2"
                    aria-label={t('notes.clearSearch')}
                    onClick={() => setQuery('')}
                  >
                    <XIcon />
                  </Button>
                )}
              </div>
            </div>
            <nav aria-label={t('notes.folders')} className="min-h-0 flex-1 overflow-y-auto overscroll-contain pt-1 pb-4">
              <VaultTree
                vault={vault}
                sort={sort}
                query={query}
                selected={selected}
                variant="phone"
                folding={folding}
                actions={wrapped}
                onFocusFolder={() => undefined}
                onFolderDialog={setFolderDialog}
                onFolderGone={() => undefined}
                onPicked={close}
              />
            </nav>
            <Link
              to="/app/records/trash"
              onClick={close}
              className="flex min-h-12 shrink-0 items-center gap-6 border-t px-5 text-sm font-semibold outline-none hover:bg-accent focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ring"
            >
              <Trash2Icon className="size-6 text-muted-foreground" aria-hidden />
              <span className="flex-1">{t('notes.trashTitle')}</span>
              {vault.trash.length > 0 && <span className="text-xs text-muted-foreground tabular">{vault.trash.length}</span>}
            </Link>
          </DialogPrimitive.Content>
        </DialogPrimitive.Portal>
      </DialogPrimitive.Root>
      {folderDialog && (
        <FolderDialog
          parent={folderDialog.parent}
          {...(folderDialog.renaming ? { renaming: folderDialog.renaming } : {})}
          onClose={() => setFolderDialog(null)}
        />
      )}
    </>
  );
}
