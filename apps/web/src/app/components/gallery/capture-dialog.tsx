import { maxFileBytes } from '@harvest/contracts';
import { CameraIcon, ImagesIcon, LoaderIcon, VideoIcon, FilmIcon } from 'lucide-react';
import { useId, useRef, useState, type ChangeEvent, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { formatBytes } from '@/lib/format';
import { useHarvest } from '../../context';
import { FileTooLargeError } from '../../data/files';
import { downscaleImage, extensionOf, type AlbumRow } from '../../data/gallery';

/** Whether this is a touch device, where `capture` opens the camera itself. */
function hasCamera(): boolean {
  return typeof window !== 'undefined' && typeof window.matchMedia === 'function' && window.matchMedia('(pointer: coarse)').matches;
}

interface Source {
  key: string;
  label: string;
  icon: ReactNode;
  accept: string;
  capture: boolean;
  primary?: boolean;
}

/**
 * Adds a memory to [album]: a picture or a clip, from the files on this
 * computer or, on a phone's browser, from the camera — and a note to go
 * with it, written before the shutter because what I was trying is the
 * thing I forget by the time the picture is filed.
 *
 * A picture is downscaled as the phone does it (G4); a clip is kept as
 * it came, within the 25 MB a file may be ([[Sync-API]], files).
 */
export function CaptureDialog({ album, onClose }: { album: AlbumRow; onClose: () => void }) {
  const { t } = useTranslation();
  const { gallery } = useHarvest();
  const id = useId();
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const inputs = useRef(new Map<string, HTMLInputElement>());
  const camera = hasCamera();

  const sources: Source[] = [
    ...(camera
      ? [
          { key: 'photo', label: t('gallery.takePhoto'), icon: <CameraIcon />, accept: 'image/*', capture: true, primary: true },
          { key: 'video', label: t('gallery.takeVideo'), icon: <VideoIcon />, accept: 'video/*', capture: true },
        ]
      : []),
    { key: 'pickPhoto', label: t('gallery.pickPhoto'), icon: <ImagesIcon />, accept: 'image/*', capture: false, primary: !camera },
    { key: 'pickVideo', label: t('gallery.pickVideo'), icon: <FilmIcon />, accept: 'video/*', capture: false },
  ];

  async function take(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    event.target.value = '';
    if (!file) {
      toast(t('gallery.noCapture'));
      return;
    }
    const video = file.type.startsWith('video/');
    setBusy(true);
    try {
      const prepared = video ? { blob: file, converted: false } : await downscaleImage(file);
      const extension = prepared.converted ? '.jpg' : extensionOf(file.name, video);
      await gallery.addMemory(album, {
        blob: prepared.blob,
        kind: video ? 'video' : 'photo',
        extension,
        note: note.trim() || null,
      });
      toast.success(t('gallery.added', { name: album.name }));
      onClose();
    } catch (error) {
      toast.error(
        error instanceof FileTooLargeError
          ? t('gallery.tooLarge', { size: formatBytes(error.bytes), max: formatBytes(maxFileBytes) })
          : t('common.saveFailed'),
      );
      setBusy(false);
    }
  }

  return (
    <Dialog open onOpenChange={(open) => !open && !busy && onClose()}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>{t('gallery.addTo', { name: album.name })}</DialogTitle>
          {album.scheduleJson !== null ? (
            <DialogDescription>{t('gallery.checkInHint')}</DialogDescription>
          ) : (
            <DialogDescription className="sr-only">{t('gallery.addTo', { name: album.name })}</DialogDescription>
          )}
        </DialogHeader>
        <div className="flex flex-col gap-2">
          <Label htmlFor={`${id}-note`}>{t('gallery.memoryNote')}</Label>
          <Textarea
            id={`${id}-note`}
            rows={2}
            value={note}
            placeholder={t('gallery.memoryNoteHint')}
            onChange={(event) => setNote(event.target.value)}
          />
        </div>
        {busy ? (
          <div className="flex justify-center p-6" role="status">
            <LoaderIcon className="size-6 animate-spin text-muted-foreground" aria-hidden />
            <span className="sr-only">{t('common.loading')}</span>
          </div>
        ) : (
          <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
            {sources.map((source) => (
              <div key={source.key}>
                <input
                  ref={(element) => {
                    if (element) inputs.current.set(source.key, element);
                    else inputs.current.delete(source.key);
                  }}
                  type="file"
                  accept={source.accept}
                  {...(source.capture ? { capture: 'environment' as const } : {})}
                  className="sr-only"
                  tabIndex={-1}
                  aria-hidden
                  data-testid={`capture-${source.key}`}
                  onChange={(event) => void take(event)}
                />
                <Button
                  type="button"
                  className="w-full"
                  variant={source.primary ? 'default' : 'outline'}
                  onClick={() => inputs.current.get(source.key)?.click()}
                >
                  {source.icon}
                  {source.label}
                </Button>
              </div>
            ))}
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}
