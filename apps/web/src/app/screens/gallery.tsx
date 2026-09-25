import { useLiveQuery } from 'dexie-react-hooks';
import {
  ArrowLeftIcon,
  CameraIcon,
  CheckCircle2Icon,
  CloudOffIcon,
  EllipsisVerticalIcon,
  GitCompareArrowsIcon,
  ImageIcon,
  PlayIcon,
  PlusIcon,
  RepeatIcon,
  RotateCcwIcon,
  SearchIcon,
  StickyNoteIcon,
  Trash2Icon,
  XIcon,
} from 'lucide-react';
import { useState, useSyncExternalStore } from 'react';
import { useTranslation } from 'react-i18next';
import { useSearchParams } from 'react-router';
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
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { formatBytes, formatDay } from '@/lib/format';
import { cn } from '@/lib/utils';
import { EmptyState, StreakChip } from '../components/bits';
import { AlbumDialog } from '../components/gallery/album-dialog';
import { CaptureDialog } from '../components/gallery/capture-dialog';
import { CompareDialog } from '../components/gallery/compare-dialog';
import { EmptyCover, MemoryMedia } from '../components/gallery/memory-media';
import { MemoryViewer } from '../components/gallery/memory-viewer';
import { TimelapseDialog } from '../components/gallery/timelapse-dialog';
import { useHarvest, useHarvestDay, type Harvest } from '../context';
import type { AlbumRow, MemoryRow } from '../data/gallery';
import { RecordsTabs } from './records';

interface AlbumSummary {
  album: AlbumRow;
  /** Live memories, newest first: the grid's order. */
  memories: MemoryRow[];
  streak: number;
  doneToday: boolean;
  /** What this browser holds of the album's files. */
  bytes: number;
}

interface Gallery {
  albums: AlbumSummary[];
  trashedAlbums: AlbumRow[];
  trashedMemories: MemoryRow[];
  bytes: number;
}

async function loadGallery({ db, files }: Pick<Harvest, 'db' | 'files'>, todayKey: string): Promise<Gallery> {
  const [albums, memories, streaks, local] = await Promise.all([
    db.rows('albums').toArray(),
    db.rows('memories').toArray(),
    db.rows('streaks').toArray(),
    files.localHashes(),
  ]);
  const live = memories.filter((row) => row.deletedAt === null);
  const hashOf = (memory: MemoryRow) => memory.fileHash ?? local.get(memory.uuid) ?? null;
  const hashes = [...new Set(live.map(hashOf).filter((hash): hash is string => hash !== null))];
  const held = await db.files.bulkGet(hashes);
  const sizes = new Map(held.flatMap((file) => (file ? [[file.sha256, file.blob.size] as const] : [])));
  const streakBy = new Map(streaks.map((row) => [row.scope, row.current]));
  const newestFirst = (a: MemoryRow, b: MemoryRow) =>
    b.harvestDay.localeCompare(a.harvestDay) || b.capturedAt.localeCompare(a.capturedAt);

  const summaries = albums
    .filter((row) => row.deletedAt === null)
    .sort((a, b) => a.createdAt.localeCompare(b.createdAt))
    .map((album) => {
      const own = live.filter((row) => row.albumUuid === album.uuid).sort(newestFirst);
      return {
        album,
        memories: own,
        streak: streakBy.get(album.uuid) ?? 0,
        doneToday: own.some((row) => row.harvestDay === todayKey),
        bytes: own.reduce((sum, row) => sum + (sizes.get(hashOf(row) ?? '') ?? 0), 0),
      };
    });
  return {
    albums: summaries,
    trashedAlbums: albums
      .filter((row) => row.deletedAt !== null)
      .sort((a, b) => (b.deletedAt ?? '').localeCompare(a.deletedAt ?? '')),
    trashedMemories: memories
      .filter((row) => row.deletedAt !== null)
      .sort((a, b) => (b.deletedAt ?? '').localeCompare(a.deletedAt ?? '')),
    bytes: [...sizes.values()].reduce((sum, size) => sum + size, 0),
  };
}

/** A confirm for the steps that cannot be taken back. */
function Confirm({
  open,
  title,
  body,
  action,
  onConfirm,
  onCancel,
}: {
  open: boolean;
  title: string;
  body: string;
  action: string;
  onConfirm: () => void;
  onCancel: () => void;
}) {
  const { t } = useTranslation();
  return (
    <AlertDialog open={open} onOpenChange={(next) => !next && onCancel()}>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>{title}</AlertDialogTitle>
          <AlertDialogDescription>{body}</AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel>{t('common.cancel')}</AlertDialogCancel>
          <AlertDialogAction destructive onClick={onConfirm}>
            {action}
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}

/** Says out loud when the account has no room left for files. */
function UploadProblem() {
  const { t } = useTranslation();
  const { files } = useHarvest();
  const problem = useSyncExternalStore(
    (listener) => files.subscribe(listener),
    () => files.problem,
    () => files.problem,
  );
  if (problem !== 'quota') return null;
  return (
    <p role="alert" className="flex items-start gap-2 rounded-xl border border-destructive/40 bg-destructive/10 p-3 text-sm">
      <CloudOffIcon className="mt-0.5 size-4 shrink-0 text-destructive" aria-hidden />
      {t('gallery.quotaExceeded')}
    </p>
  );
}

// ------------------------------------------------------------- the list

function AlbumCard({ summary, onOpen }: { summary: AlbumSummary; onOpen: () => void }) {
  const { t } = useTranslation();
  const { album, memories, streak, doneToday, bytes } = summary;
  const latest = memories[0];
  const scheduled = album.scheduleJson !== null;
  return (
    <li className="overflow-hidden rounded-2xl border bg-card">
      <button
        type="button"
        onClick={onOpen}
        className="flex w-full flex-col text-start outline-none focus-visible:ring-2 focus-visible:ring-ring"
      >
        {/* The cover is the last picture, big enough to be the reason to open it. */}
        <span className="relative block aspect-video w-full">
          {latest ? <MemoryMedia memory={latest} className="size-full" /> : <EmptyCover className="size-full" />}
          {latest && scheduled && (
            <span className="absolute bottom-2 end-2 flex items-center gap-1 rounded-full bg-black/50 px-2 py-0.5 text-xs font-extrabold text-white">
              {doneToday ? <CheckCircle2Icon className="size-3.5 text-secondary" aria-hidden /> : <RepeatIcon className="size-3.5" aria-hidden />}
              {doneToday ? t('gallery.doneToday') : t('gallery.isSeed')}
            </span>
          )}
        </span>
        <span className="flex items-center gap-3 p-3">
          <span className="flex min-w-0 flex-1 flex-col">
            <span className="truncate font-extrabold">{album.name}</span>
            <span className="truncate text-xs text-muted-foreground">
              {t('gallery.count', { count: memories.length })}
              {scheduled ? ` · ${t('gallery.scheduled')}` : ''}
              {bytes > 0 ? ` · ${formatBytes(bytes)}` : ''}
              {latest ? ` · ${formatDay(latest.harvestDay)}` : ''}
            </span>
          </span>
          {scheduled && streak > 0 && <StreakChip count={streak} />}
        </span>
      </button>
    </li>
  );
}

function AlbumList({ gallery, onOpen, onTrash }: { gallery: Gallery; onOpen: (uuid: string) => void; onTrash: () => void }) {
  const { t } = useTranslation();
  const [making, setMaking] = useState(false);
  const trashCount = gallery.trashedAlbums.length + gallery.trashedMemories.length;
  return (
    <>
      <div className="flex flex-wrap items-center gap-2">
        <h1 className="flex-1 text-2xl font-extrabold">{t('gallery.title')}</h1>
        {gallery.bytes > 0 && (
          <span className="rounded-full bg-muted px-2.5 py-0.5 text-xs font-bold text-muted-foreground" title={t('gallery.storageHint')}>
            {formatBytes(gallery.bytes)}
          </span>
        )}
        <Button variant="ghost" size="sm" onClick={onTrash}>
          <Trash2Icon />
          {t('gallery.trash', { count: trashCount })}
        </Button>
        <Button onClick={() => setMaking(true)}>
          <PlusIcon />
          {t('gallery.newAlbum')}
        </Button>
      </div>
      <UploadProblem />
      {gallery.albums.length === 0 ? (
        <EmptyState icon={<CameraIcon />} title={t('gallery.emptyTitle')} body={t('gallery.emptyBody')} />
      ) : (
        <ul className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {gallery.albums.map((summary) => (
            <AlbumCard key={summary.album.uuid} summary={summary} onOpen={() => onOpen(summary.album.uuid)} />
          ))}
        </ul>
      )}
      {making && (
        <AlbumDialog
          album={null}
          onClose={(created) => {
            setMaking(false);
            if (created) onOpen(created.uuid);
          }}
        />
      )}
    </>
  );
}

// ------------------------------------------------------------ one album

type Overlay = { kind: 'viewer'; index: number } | { kind: 'compare' } | { kind: 'play' } | { kind: 'add' } | { kind: 'edit' } | { kind: 'delete' } | null;

function AlbumView({ summary, onBack }: { summary: AlbumSummary; onBack: () => void }) {
  const { t } = useTranslation();
  const { gallery } = useHarvest();
  const { album, memories: all } = summary;
  const [searching, setSearching] = useState(false);
  const [query, setQuery] = useState('');
  const [overlay, setOverlay] = useState<Overlay>(null);

  // Search reads the notes, so "the week I started creatine" is findable.
  const needle = query.trim().toLowerCase();
  const memories = needle ? all.filter((memory) => (memory.note ?? '').toLowerCase().includes(needle)) : all;

  const remove = async () => {
    setOverlay(null);
    await gallery.deleteAlbum(album.uuid);
    onBack();
    toast(t('gallery.albumTrashed', { name: album.name }), {
      action: { label: t('common.undo'), onClick: () => void gallery.restoreAlbum(album.uuid) },
    });
  };

  return (
    <>
      <div className="flex flex-wrap items-center gap-2">
        <Button variant="ghost" size="icon" aria-label={t('gallery.backToAlbums')} onClick={onBack}>
          <ArrowLeftIcon className="rtl:rotate-180" />
        </Button>
        {searching ? (
          <div className="flex min-w-0 flex-1 items-center gap-2">
            <Label htmlFor="gallery-search" className="sr-only">
              {t('gallery.searchNotes')}
            </Label>
            <Input
              id="gallery-search"
              type="search"
              autoFocus
              value={query}
              placeholder={t('gallery.searchHint')}
              onChange={(event) => setQuery(event.target.value)}
            />
          </div>
        ) : (
          <h1 className="min-w-0 flex-1 truncate text-2xl font-extrabold">{album.name}</h1>
        )}
        <Button
          variant="ghost"
          size="icon"
          aria-label={searching ? t('gallery.closeSearch') : t('gallery.searchNotes')}
          onClick={() => {
            setSearching(!searching);
            setQuery('');
          }}
        >
          {searching ? <XIcon /> : <SearchIcon />}
        </Button>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon" aria-label={t('gallery.albumMenu')}>
              <EllipsisVerticalIcon />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuItem onSelect={() => setOverlay({ kind: 'edit' })}>{t('common.edit')}</DropdownMenuItem>
            <DropdownMenuItem onSelect={() => setOverlay({ kind: 'delete' })}>{t('common.delete')}</DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
        <Button onClick={() => setOverlay({ kind: 'add' })}>
          <CameraIcon />
          {t('gallery.add')}
        </Button>
      </div>

      {album.note && <p className="text-sm text-muted-foreground" dir="auto">{album.note}</p>}

      {all.length >= 2 && (
        <div className="grid grid-cols-2 gap-2 sm:flex">
          <Button variant="secondary" onClick={() => setOverlay({ kind: 'play' })}>
            <PlayIcon className="rtl:rotate-180" />
            {t('gallery.play')}
          </Button>
          <Button variant="outline" onClick={() => setOverlay({ kind: 'compare' })}>
            <GitCompareArrowsIcon />
            {t('gallery.compare')}
          </Button>
        </div>
      )}

      <UploadProblem />

      {memories.length === 0 ? (
        <EmptyState
          icon={<ImageIcon />}
          title={all.length === 0 ? t('gallery.albumEmpty') : t('gallery.noMatch')}
          {...(all.length === 0 ? { body: t('gallery.albumEmptyBody') } : {})}
        />
      ) : (
        <ul className="grid grid-cols-3 gap-1.5 sm:grid-cols-4 lg:grid-cols-6" aria-label={t('gallery.pictures')}>
          {memories.map((memory, index) => (
            <li key={memory.uuid}>
              <button
                type="button"
                onClick={() => setOverlay({ kind: 'viewer', index })}
                aria-label={`${memory.kind === 'video' ? t('gallery.video') : t('gallery.photo')} · ${formatDay(memory.harvestDay)}`}
                className="relative block aspect-square w-full overflow-hidden rounded-lg outline-none focus-visible:ring-2 focus-visible:ring-ring"
              >
                <MemoryMedia memory={memory} className="size-full" />
                <span className="absolute inset-x-0 bottom-0 flex items-center gap-1 bg-gradient-to-t from-black/60 to-transparent px-1.5 py-1 text-[11px] font-bold text-white">
                  <span className="flex-1 truncate text-start">{formatDay(memory.harvestDay)}</span>
                  {memory.note && <StickyNoteIcon className="size-3" aria-hidden />}
                </span>
              </button>
            </li>
          ))}
        </ul>
      )}

      {overlay?.kind === 'viewer' && (
        <MemoryViewer
          memories={memories}
          index={overlay.index}
          onIndex={(index) => setOverlay({ kind: 'viewer', index })}
          onClose={() => setOverlay(null)}
        />
      )}
      {overlay?.kind === 'compare' && <CompareDialog title={album.name} memories={all} onClose={() => setOverlay(null)} />}
      {overlay?.kind === 'play' && (
        <TimelapseDialog title={album.name} memories={[...all].reverse()} onClose={() => setOverlay(null)} />
      )}
      {overlay?.kind === 'add' && <CaptureDialog album={album} onClose={() => setOverlay(null)} />}
      {overlay?.kind === 'edit' && <AlbumDialog album={album} onClose={() => setOverlay(null)} />}
      <Confirm
        open={overlay?.kind === 'delete'}
        title={t('gallery.deleteAlbumTitle', { name: album.name })}
        body={t('gallery.deleteAlbumBody')}
        action={t('common.delete')}
        onConfirm={() => void remove()}
        onCancel={() => setOverlay(null)}
      />
    </>
  );
}

// ------------------------------------------------------------ the trash

type Purge = { kind: 'memory'; memory: MemoryRow } | { kind: 'album'; album: AlbumRow } | { kind: 'all'; count: number } | null;

function TrashView({ gallery: data, onBack }: { gallery: Gallery; onBack: () => void }) {
  const { t } = useTranslation();
  const { gallery } = useHarvest();
  const [purge, setPurge] = useState<Purge>(null);
  const names = new Map([...data.albums.map((row) => [row.album.uuid, row.album.name] as const), ...data.trashedAlbums.map((row) => [row.uuid, row.name] as const)]);
  const count = data.trashedAlbums.length + data.trashedMemories.length;

  const confirmPurge = async () => {
    const target = purge;
    setPurge(null);
    if (!target) return;
    if (target.kind === 'memory') await gallery.purgeMemory(target.memory.uuid);
    else if (target.kind === 'album') await gallery.purgeAlbum(target.album.uuid);
    else await gallery.emptyTrash();
  };

  return (
    <section className="flex flex-col gap-3" aria-labelledby="gallery-trash">
      <div className="flex items-center gap-2">
        <Button variant="ghost" size="icon" aria-label={t('gallery.backToAlbums')} onClick={onBack}>
          <ArrowLeftIcon className="rtl:rotate-180" />
        </Button>
        <h1 id="gallery-trash" className="flex-1 text-2xl font-extrabold">
          {t('gallery.trashTitle')}
        </h1>
        {count > 0 && (
          <Button variant="outline" onClick={() => setPurge({ kind: 'all', count })}>
            {t('gallery.emptyTrash')}
          </Button>
        )}
      </div>
      {count === 0 ? (
        <EmptyState icon={<Trash2Icon />} title={t('gallery.trashEmptyTitle')} body={t('gallery.trashEmptyBody')} />
      ) : (
        <>
          <p className="text-sm text-muted-foreground">{t('gallery.trashKeepsFiles')}</p>
          <ul className="flex flex-col gap-2">
            {data.trashedAlbums.map((album) => (
              <li key={album.uuid} className="flex items-center gap-3 rounded-xl border bg-card p-3">
                <ImageIcon className="size-5 shrink-0 text-muted-foreground" aria-hidden />
                <div className="flex min-w-0 flex-1 flex-col">
                  <span className="truncate font-bold">{album.name}</span>
                  <span className="text-xs text-muted-foreground">{t('gallery.wholeAlbum')}</span>
                </div>
                <Button variant="outline" size="sm" onClick={() => void gallery.restoreAlbum(album.uuid)}>
                  <RotateCcwIcon />
                  {t('gallery.restore')}
                </Button>
                <Button variant="ghost" size="icon-sm" aria-label={t('gallery.deleteForeverNamed', { name: album.name })} onClick={() => setPurge({ kind: 'album', album })}>
                  <Trash2Icon />
                </Button>
              </li>
            ))}
            {data.trashedMemories.map((memory) => (
              <li key={memory.uuid} className="flex items-center gap-3 rounded-xl border bg-card p-3">
                <MemoryMedia memory={memory} className="size-12 shrink-0 rounded-md" />
                <div className="flex min-w-0 flex-1 flex-col">
                  <span className="truncate font-bold">{formatDay(memory.harvestDay)}</span>
                  <span className="truncate text-xs text-muted-foreground">
                    {[names.get(memory.albumUuid), memory.note].filter(Boolean).join(' · ')}
                  </span>
                </div>
                <Button variant="outline" size="sm" onClick={() => void gallery.restoreMemory(memory.uuid)}>
                  <RotateCcwIcon />
                  {t('gallery.restore')}
                </Button>
                <Button
                  variant="ghost"
                  size="icon-sm"
                  aria-label={t('gallery.deleteForeverNamed', { name: formatDay(memory.harvestDay) })}
                  onClick={() => setPurge({ kind: 'memory', memory })}
                >
                  <Trash2Icon />
                </Button>
              </li>
            ))}
          </ul>
        </>
      )}
      <Confirm
        open={purge !== null}
        title={
          purge?.kind === 'all'
            ? t('gallery.emptyTrashTitle', { count: purge.count })
            : purge?.kind === 'album'
              ? t('gallery.deleteAlbumTitle', { name: purge.album.name })
              : t('gallery.deleteForeverTitle')
        }
        body={purge?.kind === 'memory' ? t('gallery.deleteMemoryBody') : t('gallery.emptyTrashBody')}
        action={purge?.kind === 'all' ? t('gallery.emptyTrash') : t('gallery.deleteForever')}
        onConfirm={() => void confirmPurge()}
        onCancel={() => setPurge(null)}
      />
    </section>
  );
}

/**
 * The Gallery: albums, what each holds, and the pictures themselves
 * ([[Gallery]]). An album is made here as on the phone, and a picture
 * added here is kept in this browser and sent, sealed, with the next
 * sync. One album and the trash are views of this one screen, named in
 * the address so the back button walks out of them.
 */
export function GalleryScreen() {
  const { t } = useTranslation();
  const harvest = useHarvest();
  const today = useHarvestDay();
  const [params, setParams] = useSearchParams();
  const data = useLiveQuery(() => loadGallery(harvest, today.key), [harvest.db, harvest.files, today.key]);

  if (!data) return null;
  const albumUuid = params.get('album');
  const open = albumUuid ? data.albums.find((summary) => summary.album.uuid === albumUuid) : undefined;
  const toList = () => setParams({});

  return (
    <div className="flex flex-col gap-4">
      <RecordsTabs />
      {params.has('trash') ? (
        <TrashView gallery={data} onBack={toList} />
      ) : open ? (
        <AlbumView key={open.album.uuid} summary={open} onBack={toList} />
      ) : albumUuid ? (
        <EmptyState
          icon={<ImageIcon />}
          title={t('gallery.albumGone')}
          action={
            <Button variant="outline" onClick={toList}>
              {t('gallery.backToAlbums')}
            </Button>
          }
        />
      ) : (
        <AlbumList gallery={data} onOpen={(uuid) => setParams({ album: uuid })} onTrash={() => setParams({ trash: '1' })} />
      )}
      <p className={cn('flex items-center gap-2 text-xs text-muted-foreground')}>
        <ImageIcon className="size-4 shrink-0" aria-hidden />
        {t('gallery.filesSynced')}
      </p>
    </div>
  );
}
