import { ImageIcon, PauseIcon, PlayIcon, VideoIcon } from 'lucide-react';
import { useEffect, useId, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogTitle } from '@/components/ui/dialog';
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group';
import { formatDay } from '@/lib/format';
import type { MemoryRow } from '../../data/gallery';
import { useMemoryUrls } from './memory-media';

/** Frames per second worth offering, as on the phone. */
export const timelapseSpeeds = [2, 4, 8, 12] as const;

/**
 * The album, played: one frame per memory, oldest first (the phone's
 * TimelapseScreen). No export, no rendering, no waiting — the frames
 * are resolved once, and playing them is a timer and an index. A clip,
 * or a picture not in this browser, shows as a mark rather than a
 * black frame that looks like the end of the album.
 */
export function TimelapseDialog({ title, memories, onClose }: { title: string; memories: MemoryRow[]; onClose: () => void }) {
  const { t } = useTranslation();
  const id = useId();
  const urls = useMemoryUrls(memories);
  const [index, setIndex] = useState(0);
  const [speed, setSpeed] = useState<number>(4);
  const [playing, setPlaying] = useState(true);

  useEffect(() => {
    if (!playing || !urls || memories.length === 0) return;
    const timer = setInterval(() => setIndex((at) => (at + 1 >= memories.length ? 0 : at + 1)), Math.round(1000 / speed));
    return () => clearInterval(timer);
  }, [playing, speed, urls, memories.length]);

  if (memories.length === 0) return null;
  const at = Math.min(index, memories.length - 1);
  const current = memories[at]!;
  const url = urls?.get(current.uuid);

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="flex h-[100dvh] max-h-none w-screen max-w-none flex-col gap-0 rounded-none border-0 bg-black p-0 pt-3 text-white sm:max-w-none">
        <DialogTitle className="truncate px-4 pe-12 text-lg text-white">{title}</DialogTitle>
        <DialogDescription className="sr-only">{t('gallery.playHint')}</DialogDescription>
        <div className="relative flex min-h-0 flex-1 items-center justify-center">
          {url ? (
            <img src={url} alt={current.note ?? formatDay(current.harvestDay)} className="size-full object-contain" />
          ) : current.kind === 'video' ? (
            <VideoIcon className="size-12 text-white/40" aria-label={t('gallery.video')} />
          ) : (
            <ImageIcon className="size-12 text-white/40" aria-label={t('gallery.onPhone')} />
          )}
          <span className="absolute bottom-3 start-3 rounded-md bg-black/55 px-2 py-1 text-sm font-bold" aria-live="off">
            {formatDay(current.harvestDay)}
          </span>
        </div>
        <div className="flex flex-col gap-2 p-3">
          <div className="flex items-center gap-2">
            <Button
              variant="ghost"
              size="icon"
              className="text-white hover:bg-white/10 hover:text-white"
              aria-label={playing ? t('gallery.pause') : t('gallery.play')}
              onClick={() => setPlaying(!playing)}
            >
              {playing ? <PauseIcon /> : <PlayIcon className="rtl:rotate-180" />}
            </Button>
            <label htmlFor={`${id}-frame`} className="sr-only">
              {t('gallery.frame')}
            </label>
            <input
              id={`${id}-frame`}
              type="range"
              min={0}
              max={memories.length - 1}
              value={at}
              aria-valuetext={`${at + 1}/${memories.length} · ${formatDay(current.harvestDay)}`}
              className="flex-1 accent-primary"
              onChange={(event) => {
                setPlaying(false);
                setIndex(Number(event.target.value));
              }}
            />
            <span className="text-xs text-white/70 tabular">
              {at + 1}/{memories.length}
            </span>
          </div>
          <div className="flex flex-wrap items-center justify-center gap-2">
            <span id={`${id}-speed`} className="text-xs text-white/70">
              {t('gallery.speed')}
            </span>
            <ToggleGroup
              type="single"
              value={String(speed)}
              aria-labelledby={`${id}-speed`}
              onValueChange={(value) => value && setSpeed(Number(value))}
            >
              {timelapseSpeeds.map((fps) => (
                <ToggleGroupItem key={fps} value={String(fps)} className="text-white data-[state=on]:text-foreground">
                  {t('gallery.fps', { count: fps })}
                </ToggleGroupItem>
              ))}
            </ToggleGroup>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
