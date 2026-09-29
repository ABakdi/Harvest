import { useLiveQuery } from 'dexie-react-hooks';
import {
  CloudUploadIcon,
  ImageIcon,
  ImageOffIcon,
  KeyRoundIcon,
  LockIcon,
  RefreshCwIcon,
  SmartphoneIcon,
  VideoIcon,
} from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { useHarvest } from '../../context';
import type { FileMiss } from '../../data/files';
import type { MemoryRow } from '../../data/gallery';
import { useFileRetry, useFileView, useSeen, type FileView } from '../../hooks';
import { SyncPinDialog } from '../passphrase-prompt';
import { background } from '@/lib/actions';

/**
 * A row's file: by the hash the row carries, or, for one made in this
 * browser and not sent yet, by the hash it is waiting under. A row with
 * neither is still on the phone (G9). `local` says the file has not
 * left this browser.
 */
export function useRowFile(
  uuid: string,
  fileHash: string | null,
  enabled = true,
): { url: string | null | undefined; view: FileView; local: boolean } {
  const { files } = useHarvest();
  const waiting = useLiveQuery(
    async () => (fileHash === null ? files.localHash(uuid) : null),
    [files, uuid, fileHash],
  );
  const hash = fileHash ?? waiting ?? null;
  const found = useFileView(hash, enabled);
  const view: FileView = fileHash === null && waiting === undefined ? { state: 'loading' } : found;
  const url = view.state === 'loading' ? undefined : view.state === 'ready' ? view.url : null;
  return { url, view, local: fileHash === null && typeof waiting === 'string' };
}

/** How many files of a run are asked for at once. */
const runFetches = 4;

type Resolved = { url: string } | { miss: FileMiss };

/**
 * Every picture of a run, resolved once, for the timelapse and the
 * compare strips: a frame that had to find its own file twelve times a
 * second would show the placeholder more than the picture. A clip is
 * never fetched here and reads as `null`.
 */
export function useMemoryFiles(memories: MemoryRow[]): Map<string, FileView | null> | undefined {
  const { files } = useHarvest();
  const [resolved, setResolved] = useState<{ key: string; map: Map<string, Resolved | null> }>();
  const [asked, setAsked] = useState(0);
  // The key stands for the list: the same pictures, of the same kind, by
  // the same bytes, are the same URLs (Q6-18).
  const key = memories.map((memory) => `${memory.uuid}:${memory.kind}:${memory.fileHash ?? ''}`).join('|');
  const current = useRef(memories);
  useEffect(() => {
    current.current = memories;
  });
  // The URLs held now, by memory and the name of its bytes: kept across a
  // new list or a retry, so a shown frame never goes blank and a picture
  // already here is never fetched again.
  const held = useRef(new Map<string, { hash: string; got: Resolved }>());
  const waiting =
    resolved?.key === key &&
    memories.some((memory) => {
      const got = resolved.map.get(memory.uuid);
      return got !== undefined && got !== null && 'miss' in got;
    });
  // A picture missing while locked or offline is asked for again once that may have changed.
  const retry = useFileRetry(waiting);

  useEffect(() => {
    let live = true;
    const list = current.current;
    background((async () => {
      const local = await files.localHashes();
      const map = new Map<string, Resolved | null>();
      const next = new Map<string, { hash: string; got: Resolved }>();
      const resolve = async (memory: MemoryRow) => {
        if (memory.kind !== 'photo') return map.set(memory.uuid, null);
        const hash = memory.fileHash ?? local.get(memory.uuid) ?? null;
        if (hash === null) return map.set(memory.uuid, { miss: 'onPhone' });
        const had = held.current.get(memory.uuid);
        if (had && had.hash === hash && 'url' in had.got) {
          next.set(memory.uuid, had);
          return map.set(memory.uuid, had.got);
        }
        const got = await files.find(hash);
        if (typeof got === 'string') return map.set(memory.uuid, { miss: got });
        const resolvedUrl: Resolved = { url: URL.createObjectURL(got) };
        next.set(memory.uuid, { hash, got: resolvedUrl });
        return map.set(memory.uuid, resolvedUrl);
      };
      // A few at a time, each bounded by the fetch's own timeout.
      const queue = [...list];
      await Promise.all(
        Array.from({ length: Math.min(runFetches, queue.length) }, async () => {
          for (let item = queue.shift(); item && live; item = queue.shift()) await resolve(item);
        }),
      );
      if (!live) {
        // Only what this run made and no one kept.
        for (const [uuid, entry] of next) if (held.current.get(uuid) !== entry && 'url' in entry.got) URL.revokeObjectURL(entry.got.url);
        return;
      }
      // The old URLs go only once the new list has its own (Q6-18).
      for (const [uuid, entry] of held.current) {
        if (next.get(uuid) !== entry && 'url' in entry.got) URL.revokeObjectURL(entry.got.url);
      }
      held.current = next;
      setResolved({ key, map });
    })());
    return () => {
      live = false;
    };
  }, [files, key, retry, asked]);

  // Leaving: every URL goes.
  useEffect(
    () => () => {
      for (const entry of held.current.values()) if ('url' in entry.got) URL.revokeObjectURL(entry.got.url);
      held.current = new Map();
    },
    [files],
  );

  if (resolved?.key !== key) return undefined;
  const again = () => setAsked((n) => n + 1);
  return new Map(
    memories.map((memory) => {
      const got = resolved.map.get(memory.uuid) ?? null;
      const view: FileView | null =
        got === null ? null : 'url' in got ? { state: 'ready', url: got.url } : { state: got.miss, retry: again };
      return [memory.uuid, view];
    }),
  );
}

/** Every picture of a run as a URL, or null when it is not here. */
export function useMemoryUrls(memories: MemoryRow[]): Map<string, string | null> | undefined {
  const views = useMemoryFiles(memories);
  if (!views) return undefined;
  return new Map([...views].map(([uuid, view]) => [uuid, view?.state === 'ready' ? view.url : null]));
}

/**
 * Why a picture or a recording is not showing, in its place ([[Gallery]]
 * G9): still on the phone, the sync PIN to enter (with the button that
 * asks for it), or couldn't load with *Try again*. `compact` is a tile:
 * a mark with its reason as the label, since a tile is itself a button.
 */
export function FileMissing({
  view,
  kind = 'photo',
  compact = false,
  dark = false,
  className,
}: {
  view: FileView;
  kind?: 'photo' | 'video' | 'audio';
  compact?: boolean;
  /** On the black of the viewer, the compare and the timelapse. */
  dark?: boolean;
  className?: string | undefined;
}) {
  const { t } = useTranslation();
  const [unlocking, setUnlocking] = useState(false);
  if (view.state === 'ready') return null;
  const tone = dark ? 'bg-black text-white/75' : 'bg-muted text-muted-foreground';

  if (view.state === 'loading') {
    return (
      <span className={cn('block animate-pulse', dark ? 'bg-white/10' : 'bg-muted', className)} aria-busy />
    );
  }

  const label = { onPhone: t('fileState.onPhone'), locked: t('fileState.locked'), failed: t('fileState.failed') }[view.state];
  const Icon =
    view.state === 'locked' ? LockIcon : view.state === 'failed' ? ImageOffIcon : kind === 'video' ? VideoIcon : SmartphoneIcon;

  if (compact) {
    return (
      <span className={cn('flex items-center justify-center', tone, className)} title={label} role="img" aria-label={label}>
        <Icon className="size-5" aria-hidden />
      </span>
    );
  }

  return (
    <span className={cn('flex flex-col items-center justify-center gap-2 p-4 text-center', tone, className)}>
      <Icon className="size-8" aria-hidden />
      <span className="max-w-72 text-sm font-semibold" role="status">
        {label}
      </span>
      {view.state === 'locked' && (
        <Button size="sm" variant={dark ? 'secondary' : 'outline'} onClick={() => setUnlocking(true)}>
          <KeyRoundIcon />
          {t('fileState.enterPin')}
        </Button>
      )}
      {view.state === 'failed' && (
        <Button size="sm" variant={dark ? 'secondary' : 'outline'} onClick={view.retry}>
          <RefreshCwIcon />
          {t('common.tryAgain')}
        </Button>
      )}
      {unlocking && <SyncPinDialog onClose={() => setUnlocking(false)} />}
    </span>
  );
}

/**
 * One memory's picture or clip, once this browser has it.
 *
 * A file is fetched by the name of its own bytes, opened with the
 * private tier's key and kept ([[Sync-API]], files). Until it arrives
 * the frame says why rather than showing a broken image (G9); `explain`
 * spells that out with its button, where there is room for it.
 */
export function MemoryMedia({
  memory,
  fit = 'cover',
  controls = false,
  explain = false,
  className,
}: {
  memory: MemoryRow;
  fit?: 'cover' | 'contain';
  /** A clip plays in place in the viewer; elsewhere it is a still. */
  controls?: boolean;
  /** Say in words why the file is missing, with what to do about it. */
  explain?: boolean;
  className?: string;
}) {
  const { t } = useTranslation();
  // A tile fetches its file when it comes near the screen, not when the
  // grid is drawn (Q5-32).
  const frame = useRef<HTMLSpanElement>(null);
  const seen = useSeen(frame);
  const { view, local } = useRowFile(memory.uuid, memory.fileHash, seen);
  const alt = memory.note ?? t('gallery.untitled');
  const objectFit = fit === 'cover' ? 'object-cover' : 'object-contain';

  if (view.state !== 'ready') {
    return (
      <span ref={frame} className={cn('block', className)}>
        <FileMissing view={view} kind={memory.kind} compact={!explain} dark={explain} className="size-full" />
      </span>
    );
  }
  const url = view.url;
  return (
    <span ref={frame} className={cn('relative block overflow-hidden bg-black/5', className)}>
      {memory.kind === 'video' ? (
        <video
          src={url}
          controls={controls}
          muted={!controls}
          playsInline
          preload="metadata"
          aria-label={alt}
          className={cn('size-full', objectFit)}
        />
      ) : (
        <img src={url} alt={alt} loading="lazy" draggable={false} className={cn('size-full', objectFit)} />
      )}
      {memory.kind === 'video' && !controls && (
        <VideoIcon className="absolute end-1 top-1 size-4 text-white drop-shadow" aria-hidden />
      )}
      {local && (
        <span
          className="absolute start-1 top-1 rounded-full bg-black/50 p-0.5 text-white"
          title={t('gallery.onlyHere')}
        >
          <CloudUploadIcon className="size-3.5" aria-hidden />
          <span className="sr-only">{t('gallery.onlyHere')}</span>
        </span>
      )}
    </span>
  );
}

/** A quiet frame for an album with nothing in it yet. */
export function EmptyCover({ className }: { className?: string }) {
  const { t } = useTranslation();
  return (
    <span className={cn('flex flex-col items-center justify-center gap-1 bg-primary/10 text-primary', className)}>
      <ImageIcon className="size-7" aria-hidden />
      <span className="text-sm font-bold">{t('gallery.albumEmpty')}</span>
    </span>
  );
}
