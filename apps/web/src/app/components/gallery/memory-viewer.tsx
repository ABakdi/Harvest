import { ChevronLeftIcon, ChevronRightIcon, DownloadIcon, StickyNoteIcon, Trash2Icon, XIcon } from 'lucide-react';
import { useEffect, useId, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Dialog, DialogClose, DialogContent, DialogDescription, DialogTitle } from '@/components/ui/dialog';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { formatDay } from '@/lib/format';
import { LocationNote } from '../location-note';
import { useHarvest } from '../../context';
import type { MemoryRow } from '../../data/gallery';
import { MemoryMedia, useRowFile } from './memory-media';

/** The file name a picture leaves as: the phone's own, from its path. */
function downloadName(memory: MemoryRow): string {
  return memory.path.split('/').at(-1) || `${memory.harvestDay}.jpg`;
}

/**
 * One memory, full size, with its note and the ways out (the phone's
 * MemoryViewer). The arrows and the arrow keys move along the album.
 *
 * Download is the web's Share: the gallery keeps its files to itself
 * (G2), and this is the one door out, opened by hand per picture.
 * Delete moves the picture to the trash, with an undo (G5).
 */
export function MemoryViewer({
  memories,
  index,
  onIndex,
  onClose,
}: {
  memories: MemoryRow[];
  index: number;
  onIndex: (index: number) => void;
  onClose: () => void;
}) {
  const { t, i18n } = useTranslation();
  const { gallery } = useHarvest();
  const id = useId();
  const at = Math.min(Math.max(index, 0), memories.length - 1);
  const memory = memories[at];
  const [editing, setEditing] = useState(false);
  const [note, setNote] = useState(memory?.note ?? '');
  const { url } = useRowFile(memory?.uuid ?? '', memory?.fileHash ?? null);
  const rtl = i18n.dir() === 'rtl';

  // A new picture starts with its own note, not the last one's.
  const [shown, setShown] = useState(memory?.uuid);
  if (memory && memory.uuid !== shown) {
    setShown(memory.uuid);
    setNote(memory.note ?? '');
    setEditing(false);
  }

  useEffect(() => {
    if (editing) return;
    const onKey = (event: KeyboardEvent) => {
      // In RTL the next picture is to the left.
      const forward = rtl ? 'ArrowLeft' : 'ArrowRight';
      const back = rtl ? 'ArrowRight' : 'ArrowLeft';
      if (event.key === forward && at < memories.length - 1) onIndex(at + 1);
      if (event.key === back && at > 0) onIndex(at - 1);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [at, memories.length, onIndex, editing, rtl]);

  if (!memory) return null;

  const saveNote = async () => {
    await gallery.setMemoryNote(memory.uuid, note);
    setEditing(false);
    toast.success(t('gallery.noteSaved'));
  };

  const remove = async () => {
    const uuid = memory.uuid;
    await gallery.removeMemory(uuid);
    onClose();
    toast(t('gallery.movedToTrash'), {
      action: { label: t('common.undo'), onClick: () => void gallery.restoreMemory(uuid) },
    });
  };

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent
        showCloseButton={false}
        className="flex h-[100dvh] max-h-none w-screen max-w-none flex-col gap-0 rounded-none border-0 bg-black p-0 text-white sm:max-w-none"
      >
        <div className="flex items-center gap-1 p-2">
          <DialogTitle className="flex-1 truncate px-2 text-lg text-white">
            {formatDay(memory.harvestDay, { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' })}
          </DialogTitle>
          <DialogDescription className="sr-only">
            {t('gallery.position', { at: at + 1, count: memories.length })}
          </DialogDescription>
          <span className="px-2 text-xs text-white/70 tabular" aria-hidden>
            {at + 1}/{memories.length}
          </span>
          <Button
            variant="ghost"
            size="icon"
            className="text-white hover:bg-white/10 hover:text-white"
            aria-label={t('gallery.memoryNote')}
            aria-pressed={editing}
            onClick={() => setEditing(!editing)}
          >
            <StickyNoteIcon />
          </Button>
          {url ? (
            <Button asChild variant="ghost" size="icon" className="text-white hover:bg-white/10 hover:text-white">
              <a href={url} download={downloadName(memory)} aria-label={t('gallery.download')}>
                <DownloadIcon />
              </a>
            </Button>
          ) : null}
          <Button
            variant="ghost"
            size="icon"
            className="text-white hover:bg-white/10 hover:text-white"
            aria-label={t('common.delete')}
            onClick={() => void remove()}
          >
            <Trash2Icon />
          </Button>
          <DialogClose asChild>
            <Button variant="ghost" size="icon" className="text-white hover:bg-white/10 hover:text-white" aria-label={t('common.close')}>
              <XIcon />
            </Button>
          </DialogClose>
        </div>

        <div className="relative flex min-h-0 flex-1 items-center justify-center">
          <MemoryMedia key={memory.uuid} memory={memory} fit="contain" controls className="size-full" />
          {at > 0 && (
            <Button
              variant="ghost"
              size="icon"
              className="absolute start-2 top-1/2 -translate-y-1/2 rounded-full bg-black/40 text-white hover:bg-black/60 hover:text-white"
              aria-label={t('gallery.previous')}
              onClick={() => onIndex(at - 1)}
            >
              <ChevronLeftIcon className="rtl:rotate-180" />
            </Button>
          )}
          {at < memories.length - 1 && (
            <Button
              variant="ghost"
              size="icon"
              className="absolute end-2 top-1/2 -translate-y-1/2 rounded-full bg-black/40 text-white hover:bg-black/60 hover:text-white"
              aria-label={t('gallery.next')}
              onClick={() => onIndex(at + 1)}
            >
              <ChevronRightIcon className="rtl:rotate-180" />
            </Button>
          )}
        </div>

        <div className="flex flex-col gap-2 p-3">
          {editing ? (
            <form
              className="flex flex-col gap-2"
              onSubmit={(event) => {
                event.preventDefault();
                void saveNote();
              }}
            >
              <Label htmlFor={`${id}-note`} className="text-white">
                {t('gallery.memoryNote')}
              </Label>
              <Textarea
                id={`${id}-note`}
                autoFocus
                rows={3}
                value={note}
                placeholder={t('gallery.memoryNoteHint')}
                className="bg-white/10 text-white placeholder:text-white/50"
                onChange={(event) => setNote(event.target.value)}
              />
              <div className="flex justify-end gap-2">
                <Button type="button" variant="ghost" className="text-white hover:bg-white/10 hover:text-white" onClick={() => setEditing(false)}>
                  {t('common.cancel')}
                </Button>
                <Button type="submit">{t('common.save')}</Button>
              </div>
            </form>
          ) : (
            memory.note && (
              <p className="text-sm text-white/80" dir="auto">
                {memory.note}
              </p>
            )
          )}
          <LocationNote table="memories" uuid={memory.uuid} className="text-white/70" />
        </div>
      </DialogContent>
    </Dialog>
  );
}
