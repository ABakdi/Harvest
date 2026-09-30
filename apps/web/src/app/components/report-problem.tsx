import { reportImagesMax, reportTextMax, type ReportBody } from '@harvest/contracts';
import { ImagePlusIcon, LifeBuoyIcon, MicIcon, MusicIcon, SendIcon, SquareIcon, XIcon } from 'lucide-react';
import { useEffect, useId, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { background } from '@/lib/actions';
import { api, ApiError } from '@/lib/api';
import { formatBytes, formatNumber } from '@/lib/format';
import {
  audioTypeOf,
  encodeImage,
  recordingType,
  reportBodyOf,
  reportProblems,
  reportRecordingMaxMs,
  type ImageEncoder,
  type ReportFile,
  type ReportProblem,
} from '../data/report';
import { SettingsSection as Section } from './settings-bits';

/** Where a report goes: the server's by default, a test's own otherwise. */
export type ReportSend = (body: ReportBody) => Promise<unknown>;

/** *Report a problem* in Settings ([[Admin]], F12-5). */
export function ReportSection({ send, encode }: { send?: ReportSend; encode?: ImageEncoder }) {
  const { t } = useTranslation();
  const [open, setOpen] = useState(false);
  return (
    <Section title={t('report.title')} id="settings-report" lead={t('report.lead')}>
      <Button variant="outline" className="self-start" onClick={() => setOpen(true)}>
        <LifeBuoyIcon />
        {t('report.open')}
      </Button>
      <ReportProblemDialog open={open} onOpenChange={setOpen} {...(send ? { send } : {})} {...(encode ? { encode } : {})} />
    </Section>
  );
}

/**
 * The report itself: words, pictures and one recording. Each picture is
 * drawn again as a new JPEG the moment it is picked, so what is shown
 * and sent is that copy, never the file as it was taken (AD7).
 */
export function ReportProblemDialog({
  open,
  onOpenChange,
  send = api.report,
  encode = encodeImage,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  send?: ReportSend;
  encode?: ImageEncoder;
}) {
  const { t } = useTranslation();
  const id = useId();
  const [text, setText] = useState('');
  const [files, setFiles] = useState<ReportFile[]>([]);
  const [problems, setProblems] = useState<ReportProblem[]>([]);
  const [unreadable, setUnreadable] = useState(false);
  const [sending, setSending] = useState(false);
  const pictures = useRef<HTMLInputElement>(null);
  const sound = useRef<HTMLInputElement>(null);
  const filesRef = useRef<ReportFile[]>([]);
  useEffect(() => {
    filesRef.current = files;
  }, [files]);

  // Every preview goes with the dialog.
  useEffect(() => () => filesRef.current.forEach((file) => URL.revokeObjectURL(file.url)), []);

  const reset = () => {
    files.forEach((file) => URL.revokeObjectURL(file.url));
    setFiles([]);
    setText('');
    setProblems([]);
    setUnreadable(false);
  };

  const add = (file: Omit<ReportFile, 'url'>) =>
    setFiles((current) => [...current, { ...file, url: URL.createObjectURL(file.blob) }]);
  const remove = (target: ReportFile) => {
    URL.revokeObjectURL(target.url);
    setFiles((current) => current.filter((file) => file !== target));
  };

  const images = files.filter((file) => file.kind === 'image');
  const audio = files.find((file) => file.kind === 'audio') ?? null;

  const addPictures = async (list: FileList | null) => {
    if (!list) return;
    setUnreadable(false);
    const room = reportImagesMax - images.length;
    for (const picked of Array.from(list).slice(0, room)) {
      try {
        add({ kind: 'image', type: 'image/jpeg', blob: await encode(picked) });
      } catch {
        setUnreadable(true);
      }
    }
  };

  const addSound = (list: FileList | null) => {
    const picked = list?.[0];
    if (!picked) return;
    const type = audioTypeOf(picked.type);
    if (!type) {
      setProblems(['audio']);
      return;
    }
    add({ kind: 'audio', type, blob: picked });
  };

  const submit = async () => {
    const found = reportProblems(text, files);
    setProblems(found);
    if (found.length > 0) return;
    setSending(true);
    try {
      await send(await reportBodyOf(text, files));
      toast.success(t('report.sent'));
      reset();
      onOpenChange(false);
    } catch (error) {
      if (error instanceof ApiError && error.status === 429) {
        const minutes = Math.max(1, Math.ceil((error.retryAfter ?? 60) / 60));
        toast.error(t('report.tooMany', { count: minutes }));
      } else if (error instanceof ApiError && error.status === 413) {
        setProblems(['tooLarge']);
      } else if (error instanceof ApiError && error.isNetwork) {
        toast.error(t('report.offline'));
      } else {
        toast.error(t('report.failed'));
      }
    } finally {
      setSending(false);
    }
  };

  const problem = (key: ReportProblem) =>
    problems.includes(key) ? (
      <p role="alert" className="text-xs font-semibold text-destructive">
        {t(`report.problem.${key}`)}
      </p>
    ) : null;

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        if (!sending) onOpenChange(next);
      }}
    >
      <DialogContent className="max-h-[90dvh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{t('report.title')}</DialogTitle>
          <DialogDescription>{t('report.lead')}</DialogDescription>
        </DialogHeader>
        <div className="flex flex-col gap-4">
          <div className="flex flex-col gap-1.5">
            <Label htmlFor={`${id}-text`}>{t('report.what')}</Label>
            <Textarea
              id={`${id}-text`}
              rows={7}
              value={text}
              maxLength={reportTextMax}
              placeholder={t('report.placeholder')}
              onChange={(event) => setText(event.target.value)}
            />
            <span className="self-end text-xs text-muted-foreground tabular">
              {formatNumber(text.length)} / {formatNumber(reportTextMax)}
            </span>
            {problem('text')}
          </div>

          <div className="flex flex-col gap-2">
            <div className="flex flex-wrap items-center gap-2">
              <Button
                type="button"
                variant="outline"
                size="sm"
                disabled={images.length >= reportImagesMax}
                onClick={() => pictures.current?.click()}
              >
                <ImagePlusIcon />
                {t('report.addPicture', { count: images.length, max: reportImagesMax })}
              </Button>
              <input
                ref={pictures}
                type="file"
                accept="image/*"
                multiple
                hidden
                aria-label={t('report.addPictureLabel')}
                onChange={(event) => {
                  background(addPictures(event.target.files));
                  event.target.value = '';
                }}
              />
            </div>
            <p className="text-xs text-muted-foreground">{t('report.pictureHint')}</p>
            {unreadable && (
              <p role="alert" className="text-xs font-semibold text-destructive">
                {t('report.unreadable')}
              </p>
            )}
            {images.length > 0 && (
              <ul className="flex flex-wrap gap-2">
                {images.map((file, index) => (
                  <li key={file.url} className="relative">
                    <img src={file.url} alt={t('report.picture', { n: index + 1 })} className="size-20 rounded-lg border object-cover" />
                    <span className="absolute bottom-1 start-1 rounded bg-background/80 px-1 text-[10px] tabular">{formatBytes(file.blob.size)}</span>
                    <Button
                      type="button"
                      size="icon"
                      variant="secondary"
                      className="absolute -end-2 -top-2 size-6 rounded-full"
                      aria-label={t('report.removePicture', { n: index + 1 })}
                      onClick={() => remove(file)}
                    >
                      <XIcon />
                    </Button>
                  </li>
                ))}
              </ul>
            )}
            {problem('images')}
            {problem('imageTooLarge')}
          </div>

          <div className="flex flex-col gap-2">
            {audio ? (
              <div className="flex flex-wrap items-center gap-2">
                <audio controls src={audio.url} className="h-9 max-w-full" aria-label={t('report.recording')} />
                <span className="text-xs text-muted-foreground tabular">{formatBytes(audio.blob.size)}</span>
                <Button type="button" variant="ghost" size="sm" onClick={() => remove(audio)}>
                  <XIcon />
                  {t('report.removeRecording')}
                </Button>
              </div>
            ) : (
              <div className="flex flex-wrap items-center gap-2">
                <Recorder onDone={(blob, type) => add({ kind: 'audio', type, blob })} />
                <Button type="button" variant="ghost" size="sm" onClick={() => sound.current?.click()}>
                  <MusicIcon />
                  {t('report.attachSound')}
                </Button>
                <input
                  ref={sound}
                  type="file"
                  accept="audio/*"
                  hidden
                  aria-label={t('report.attachSound')}
                  onChange={(event) => {
                    addSound(event.target.files);
                    event.target.value = '';
                  }}
                />
              </div>
            )}
            {problem('audio')}
            {problem('audioTooLarge')}
            {problem('tooLarge')}
          </div>
        </div>
        <DialogFooter className="flex-col items-stretch gap-3 sm:flex-col sm:items-stretch">
          <p className="text-xs text-muted-foreground">{t('report.howItGoes')}</p>
          <Button onClick={() => background(submit())} disabled={sending}>
            <SendIcon />
            {sending ? t('report.sending') : t('report.send')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

/** One voice clip, made here, stopped by hand or at five minutes. */
function Recorder({ onDone }: { onDone: (blob: Blob, type: string) => void }) {
  const { t } = useTranslation();
  const [recording, setRecording] = useState<{ recorder: MediaRecorder; startedAt: number } | null>(null);
  const [elapsed, setElapsed] = useState(0);
  const [denied, setDenied] = useState(false);
  const type = recordingType();

  useEffect(() => {
    if (!recording) return;
    const tick = setInterval(() => {
      const ms = Date.now() - recording.startedAt;
      setElapsed(ms);
      if (ms >= reportRecordingMaxMs && recording.recorder.state === 'recording') recording.recorder.stop();
    }, 250);
    return () => clearInterval(tick);
  }, [recording]);

  useEffect(
    () => () => {
      if (recording?.recorder.state === 'recording') recording.recorder.stop();
    },
    [recording],
  );

  if (!type || typeof navigator === 'undefined' || !navigator.mediaDevices) return null;

  const start = async () => {
    setDenied(false);
    let stream: MediaStream;
    try {
      stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    } catch {
      setDenied(true);
      return;
    }
    const recorder = new MediaRecorder(stream, { mimeType: type });
    const chunks: Blob[] = [];
    recorder.addEventListener('dataavailable', (event) => {
      if (event.data.size > 0) chunks.push(event.data);
    });
    recorder.addEventListener('stop', () => {
      stream.getTracks().forEach((track) => track.stop());
      setRecording(null);
      setElapsed(0);
      const blob = new Blob(chunks, { type: recorder.mimeType || type });
      if (blob.size > 0) onDone(blob, blob.type);
    });
    recorder.start(1000);
    setRecording({ recorder, startedAt: Date.now() });
  };

  const seconds = Math.floor(elapsed / 1000);
  return (
    <>
      {recording ? (
        <Button type="button" variant="destructive" size="sm" onClick={() => recording.recorder.stop()}>
          <SquareIcon />
          {t('report.stop', { time: `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}` })}
        </Button>
      ) : (
        <Button type="button" variant="outline" size="sm" onClick={() => background(start())}>
          <MicIcon />
          {t('report.record')}
        </Button>
      )}
      {denied && (
        <p role="alert" className="w-full text-xs font-semibold text-destructive">
          {t('report.micDenied')}
        </p>
      )}
    </>
  );
}
