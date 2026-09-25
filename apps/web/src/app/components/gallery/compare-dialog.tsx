import { ImageIcon, VideoIcon } from 'lucide-react';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Dialog, DialogContent, DialogDescription, DialogTitle } from '@/components/ui/dialog';
import { formatDay } from '@/lib/format';
import { cn } from '@/lib/utils';
import type { MemoryRow } from '../../data/gallery';
import { useMemoryUrls } from './memory-media';

function Frame({ memory, url }: { memory: MemoryRow; url: string | null | undefined }) {
  const { t } = useTranslation();
  return (
    <figure className="relative flex min-h-0 flex-1 items-center justify-center bg-black">
      {url ? (
        <img src={url} alt={memory.note ?? t('gallery.untitled')} className="size-full object-contain" />
      ) : memory.kind === 'video' ? (
        <VideoIcon className="size-10 text-white/40" aria-label={t('gallery.video')} />
      ) : (
        <ImageIcon className="size-10 text-white/40" aria-label={t('gallery.onPhone')} />
      )}
      <figcaption className="absolute inset-x-0 bottom-0 bg-black/50 py-1 text-center text-sm font-bold text-white">
        {formatDay(memory.harvestDay)}
      </figcaption>
    </figure>
  );
}

function Strip({
  label,
  memories,
  urls,
  selected,
  onPick,
}: {
  label: string;
  memories: MemoryRow[];
  urls: Map<string, string | null> | undefined;
  selected: number;
  onPick: (index: number) => void;
}) {
  return (
    <div className="flex flex-col gap-1">
      <span className="px-3 text-xs text-white/70">{label}</span>
      <div role="group" aria-label={label} className="flex gap-1 overflow-x-auto px-2 pb-1">
        {memories.map((memory, index) => {
          const url = urls?.get(memory.uuid);
          return (
            <button
              key={memory.uuid}
              type="button"
              aria-pressed={index === selected}
              aria-label={formatDay(memory.harvestDay)}
              onClick={() => onPick(index)}
              className={cn(
                'size-12 shrink-0 overflow-hidden rounded-md border-2 outline-none focus-visible:ring-2 focus-visible:ring-white',
                index === selected ? 'border-secondary' : 'border-transparent',
              )}
            >
              {url ? (
                <img src={url} alt="" className="size-full object-cover" />
              ) : (
                <span className="flex size-full items-center justify-center bg-white/10">
                  <ImageIcon className="size-4 text-white/50" aria-hidden />
                </span>
              )}
            </button>
          );
        })}
      </div>
    </div>
  );
}

/**
 * Two memories side by side (the phone's CompareScreen): the oldest
 * and the newest by default, because that is the question an album is
 * usually asking. Either side moves along the run with its strip.
 */
export function CompareDialog({ title, memories, onClose }: { title: string; memories: MemoryRow[]; onClose: () => void }) {
  const { t } = useTranslation();
  // Newest first, as the grid shows them.
  const [left, setLeft] = useState(memories.length - 1);
  const [right, setRight] = useState(0);
  const urls = useMemoryUrls(memories);
  if (memories.length < 2) return null;
  const a = memories[left]!;
  const b = memories[right]!;

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="flex h-[100dvh] max-h-none w-screen max-w-none flex-col gap-2 rounded-none border-0 bg-black p-0 pt-3 text-white sm:max-w-none">
        <DialogTitle className="px-4 text-lg text-white">
          {t('gallery.compare')} · {title}
        </DialogTitle>
        <DialogDescription className="sr-only">{t('gallery.compareHint')}</DialogDescription>
        <div className="flex min-h-0 flex-1 gap-0.5">
          <Frame memory={a} url={urls?.get(a.uuid)} />
          <Frame memory={b} url={urls?.get(b.uuid)} />
        </div>
        <Strip label={t('gallery.compareLeft')} memories={memories} urls={urls} selected={left} onPick={setLeft} />
        <Strip label={t('gallery.compareRight')} memories={memories} urls={urls} selected={right} onPick={setRight} />
      </DialogContent>
    </Dialog>
  );
}
