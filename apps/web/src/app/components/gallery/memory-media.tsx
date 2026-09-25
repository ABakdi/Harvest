import { useLiveQuery } from 'dexie-react-hooks';
import { CloudUploadIcon, ImageIcon, SmartphoneIcon, VideoIcon } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { cn } from '@/lib/utils';
import { useHarvest } from '../../context';
import type { MemoryRow } from '../../data/gallery';
import { useFile, useFileRetry } from '../../hooks';

/**
 * A row's file as a URL: by the hash the row carries, or, for one made
 * in this browser and not sent yet, by the hash it is waiting under.
 * `local` says the file has not left this browser.
 */
export function useRowFile(uuid: string, fileHash: string | null): { url: string | null | undefined; local: boolean } {
  const { files } = useHarvest();
  const waiting = useLiveQuery(
    async () => (fileHash === null ? files.localHash(uuid) : null),
    [files, uuid, fileHash],
  );
  const hash = fileHash ?? waiting ?? null;
  const url = useFile(hash);
  if (fileHash === null && waiting === undefined) return { url: undefined, local: false };
  return { url, local: fileHash === null && typeof waiting === 'string' };
}

/**
 * Every picture of a run as a URL, resolved once, for the timelapse and
 * the compare strips: a frame that had to find its own file twelve
 * times a second would show the placeholder more than the picture.
 */
export function useMemoryUrls(memories: MemoryRow[]): Map<string, string | null> | undefined {
  const { files } = useHarvest();
  const [urls, setUrls] = useState<{ key: string; map: Map<string, string | null> }>();
  const key = memories.map((memory) => `${memory.uuid}:${memory.fileHash ?? ''}`).join('|');
  // The URLs this list holds, kept across a retry so a shown frame never goes blank.
  const held = useRef<{ key: string; map: Map<string, string | null> }>({ key: '', map: new Map() });
  const waiting =
    urls?.key === key && memories.some((memory) => memory.kind === 'photo' && urls.map.get(memory.uuid) === null);
  // A picture missing while locked or offline is asked for again once that may have changed.
  const retry = useFileRetry(waiting);

  useEffect(() => {
    let live = true;
    const made: string[] = [];
    const kept = held.current.key === key ? held.current.map : new Map<string, string | null>();
    void (async () => {
      const local = await files.localHashes();
      const map = new Map<string, string | null>();
      for (const memory of memories) {
        const had = kept.get(memory.uuid);
        if (had) {
          map.set(memory.uuid, had);
          continue;
        }
        const hash = memory.fileHash ?? local.get(memory.uuid) ?? null;
        const blob = memory.kind === 'photo' && hash ? await files.get(hash) : null;
        if (!live) break;
        if (blob) {
          const url = URL.createObjectURL(blob);
          made.push(url);
          map.set(memory.uuid, url);
        } else {
          map.set(memory.uuid, null);
        }
      }
      if (!live) {
        for (const url of made) URL.revokeObjectURL(url);
        return;
      }
      held.current = { key, map };
      setUrls({ key, map });
    })();
    return () => {
      live = false;
    };
    // The key stands for the list: same pictures, same URLs.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [files, key, retry]);

  // A new list, or leaving: the old URLs go.
  useEffect(
    () => () => {
      for (const url of held.current.map.values()) if (url !== null) URL.revokeObjectURL(url);
      held.current = { key: '', map: new Map() };
    },
    [files, key],
  );

  return urls?.key === key ? urls.map : undefined;
}

/**
 * One memory's picture or clip, once this browser has it.
 *
 * A file is fetched by the name of its own bytes, opened with the
 * private tier's key and kept ([[Sync-API]], files). Until it arrives
 * — no hash yet, no passphrase, or the phone has not uploaded it — the
 * frame says where the picture is rather than showing a broken image.
 */
export function MemoryMedia({
  memory,
  fit = 'cover',
  controls = false,
  className,
}: {
  memory: MemoryRow;
  fit?: 'cover' | 'contain';
  /** A clip plays in place in the viewer; elsewhere it is a still. */
  controls?: boolean;
  className?: string;
}) {
  const { t } = useTranslation();
  const { url, local } = useRowFile(memory.uuid, memory.fileHash);
  const alt = memory.note ?? t('gallery.untitled');
  const objectFit = fit === 'cover' ? 'object-cover' : 'object-contain';

  if (url === undefined) return <span className={cn('block animate-pulse bg-muted', className)} />;
  if (url === null) {
    return (
      <span
        className={cn('flex items-center justify-center bg-muted text-muted-foreground', className)}
        title={t('gallery.onPhone')}
        role="img"
        aria-label={t('gallery.onPhone')}
      >
        {memory.kind === 'video' ? <VideoIcon className="size-5" /> : <SmartphoneIcon className="size-5" />}
      </span>
    );
  }
  return (
    <span className={cn('relative block overflow-hidden bg-black/5', className)}>
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
