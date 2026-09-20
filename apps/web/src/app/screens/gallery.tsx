import { useLiveQuery } from 'dexie-react-hooks';
import { CameraIcon, ImageIcon, SmartphoneIcon, VideoIcon } from 'lucide-react';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { formatDay, formatNumber } from '@/lib/format';
import { cn } from '@/lib/utils';
import { EmptyState } from '../components/bits';
import { StreakChip } from '../components/bits';
import { useHarvest } from '../context';
import { RecordsTabs } from './records';

/**
 * The Gallery, as much of it as a browser can have.
 *
 * The rows sync; the files do not, until content-addressed file sync
 * lands ([[Phase-6-Sync-Accounts-and-Web]] M6.8). So this is the
 * album's shape — when it is due, how many pictures it holds, what
 * each one was captioned and when — with the pictures themselves still
 * on the phone. A grid of grey squares pretending to be photographs
 * would be worse than saying so.
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
                      {memory.kind === 'video' ? (
                        <VideoIcon className="size-4 text-muted-foreground" aria-hidden />
                      ) : (
                        <ImageIcon className="size-4 text-muted-foreground" aria-hidden />
                      )}
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
        <SmartphoneIcon className="size-4" aria-hidden />
        {t('gallery.filesOnPhone')}
      </p>
    </div>
  );
}
