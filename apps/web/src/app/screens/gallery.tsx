import { useLiveQuery } from 'dexie-react-hooks';
import { CameraIcon, ImageIcon, SmartphoneIcon, VideoIcon } from 'lucide-react';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { formatDay, formatNumber } from '@/lib/format';
import { cn } from '@/lib/utils';
import { EmptyState } from '../components/bits';
import { StreakChip } from '../components/bits';
import { useHarvest } from '../context';
import type { Row } from '../data/db';
import { useFile } from '../hooks';
import { RecordsTabs } from './records';

/**
 * One memory's picture, once this browser has fetched it.
 *
 * A file is fetched by the name of its own bytes, opened with the
 * private tier's key and kept ([[Sync-API]], files). Until it arrives
 * — no hash yet, no passphrase, or the phone has not uploaded it — the
 * tile says where the picture is rather than showing a broken frame.
 */
function Thumbnail({ memory }: { memory: Row<'memories'> }) {
  const { t } = useTranslation();
  const url = useFile(memory.fileHash);
  if (url === undefined) return <span className="size-10 shrink-0 animate-pulse rounded bg-muted" />;
  if (url === null) {
    return (
      <span
        className="flex size-10 shrink-0 items-center justify-center rounded bg-muted text-muted-foreground"
        title={t('gallery.onPhone')}
      >
        {memory.kind === 'video' ? <VideoIcon className="size-4" /> : <SmartphoneIcon className="size-4" />}
      </span>
    );
  }
  if (memory.kind === 'video') {
    // A video is not played here; the frame is the phone's job.
    return (
      <a href={url} download className="flex size-10 shrink-0 items-center justify-center rounded bg-muted">
        <VideoIcon className="size-4 text-muted-foreground" aria-hidden />
        <span className="sr-only">{t('gallery.download')}</span>
      </a>
    );
  }
  return (
    <img
      src={url}
      alt={memory.note ?? t('gallery.untitled')}
      loading="lazy"
      className="size-10 shrink-0 rounded object-cover"
    />
  );
}

/**
 * The Gallery: the albums, what each holds, and the pictures
 * themselves once they have synced.
 *
 * An album is made on the phone, where the camera is. What a browser
 * does here is look.
 */
export function GalleryScreen() {
  const { t } = useTranslation();
  const { db } = useHarvest();
  const [open, setOpen] = useState<string | null>(null);

  const data = useLiveQuery(async () => {
    const [albums, memories, streaks] = await Promise.all([
      db.rows('albums').toArray(),
      db.rows('memories').toArray(),
      db.rows('streaks').toArray(),
    ]);
    const live = memories.filter((row) => row.deletedAt === null);
    const streakBy = new Map(streaks.map((row) => [row.scope, row]));
    return albums
      .filter((row) => row.deletedAt === null)
      .map((album) => ({
        album,
        streak: streakBy.get(album.uuid)?.current ?? 0,
        memories: live
          .filter((row) => row.albumUuid === album.uuid)
          .sort((a, b) => b.harvestDay.localeCompare(a.harvestDay) || b.capturedAt.localeCompare(a.capturedAt)),
      }))
      .sort((a, b) => b.memories.length - a.memories.length || a.album.name.localeCompare(b.album.name));
  }, [db]);

  if (!data) return null;

  return (
    <div className="flex flex-col gap-4">
      <RecordsTabs />
      <h1 className="text-2xl font-extrabold">{t('gallery.title')}</h1>
      {data.length === 0 ? (
        <EmptyState icon={<CameraIcon />} title={t('gallery.emptyTitle')} body={t('gallery.emptyBody')} />
      ) : (
        <ul className="flex flex-col gap-3">
          {data.map(({ album, memories, streak }) => (
            <li key={album.uuid} className="flex flex-col gap-2 rounded-2xl border bg-card p-4">
              <button
                type="button"
                aria-expanded={open === album.uuid}
                onClick={() => setOpen(open === album.uuid ? null : album.uuid)}
                className="flex items-center gap-3 text-start outline-none focus-visible:ring-2 focus-visible:ring-ring"
              >
                <CameraIcon className="size-5 text-primary" aria-hidden />
                <span className="flex min-w-0 flex-1 flex-col">
                  <span className="truncate font-extrabold">{album.name}</span>
                  <span className="text-xs text-muted-foreground">
                    {t('gallery.count', { count: memories.length })}
                    {album.scheduleJson !== null ? ` · ${t('gallery.scheduled')}` : ''}
                  </span>
                </span>
                {album.scheduleJson !== null && streak > 0 && <StreakChip count={streak} />}
              </button>
              {open === album.uuid && (
                <ul className={cn('flex flex-col divide-y rounded-lg border', memories.length === 0 && 'hidden')}>
                  {memories.slice(0, 40).map((memory) => (
                    <li key={memory.uuid} className="flex items-center gap-3 px-3 py-2">
                      <Thumbnail memory={memory} />
                      <span className="min-w-0 flex-1 truncate text-sm">{memory.note ?? t('gallery.untitled')}</span>
                      <span className="text-xs text-muted-foreground tabular">{formatDay(memory.harvestDay)}</span>
                    </li>
                  ))}
                  {memories.length > 40 && (
                    <li className="px-3 py-2 text-xs text-muted-foreground">
                      {t('gallery.andMore', { count: formatNumber(memories.length - 40) })}
                    </li>
                  )}
                </ul>
              )}
            </li>
          ))}
        </ul>
      )}
      <p className="flex items-center gap-2 text-xs text-muted-foreground">
        <ImageIcon className="size-4" aria-hidden />
        {t('gallery.filesSynced')}
      </p>
    </div>
  );
}
