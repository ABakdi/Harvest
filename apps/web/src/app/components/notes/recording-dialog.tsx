import { maxFileBytes } from '@harvest/contracts';
import { SquareIcon, Trash2Icon } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { formatBytes } from '@/lib/format';
import { useHarvest } from '../../context';
import { voiceFileName } from '../../data/attachments';
import { FileTooLargeError } from '../../data/files';
import { formatClock } from './recordings';
import { recordingFormat } from './voice';

type Phase = 'starting' | 'recording' | 'refused' | 'saving';

/**
 * Records into a note (the phone's recording sheet, [[Notes]] N7):
 * a clock, a level, Stop and keep, or Discard. Mono at 64 kbps, as the
 * phone records: plenty for a voice, about half a megabyte a minute.
 * The take is filed as an attachment and its embed handed back for the
 * caret; a take that was discarded, or never started, leaves nothing.
 */
export function RecordingDialog({ noteUuid, onDone }: { noteUuid: string; onDone: (fileName: string | null) => void }) {
  const { t } = useTranslation();
  const { attachments } = useHarvest();
  const [phase, setPhase] = useState<Phase>('starting');
  const [elapsed, setElapsed] = useState(0);
  const [level, setLevel] = useState(0);
  const recorder = useRef<MediaRecorder | null>(null);
  const chunks = useRef<Blob[]>([]);
  const started = useRef(0);
  const keep = useRef(false);
  const format = useRef(recordingFormat());

  useEffect(() => {
    let live = true;
    let stream: MediaStream | null = null;
    let tick: ReturnType<typeof setInterval> | undefined;
    let audio: AudioContext | null = null;
    let frame = 0;

    void (async () => {
      const chosen = format.current;
      try {
        if (!chosen) throw new Error('No recorder');
        stream = await navigator.mediaDevices.getUserMedia({ audio: { channelCount: 1 } });
      } catch {
        if (live) setPhase('refused');
        return;
      }
      if (!live) {
        stream.getTracks().forEach((track) => track.stop());
        return;
      }
      const taking = new MediaRecorder(stream, { mimeType: chosen.mimeType, audioBitsPerSecond: 64_000 });
      taking.ondataavailable = (event) => {
        if (event.data.size > 0) chunks.current.push(event.data);
      };
      taking.start(1000);
      recorder.current = taking;
      started.current = Date.now();
      setPhase('recording');
      tick = setInterval(() => setElapsed(Date.now() - started.current), 250);
      // Loudness, for the bar: a take that shows nothing is a take of nothing.
      if (typeof AudioContext !== 'undefined') {
        audio = new AudioContext();
        const analyser = audio.createAnalyser();
        analyser.fftSize = 512;
        audio.createMediaStreamSource(stream).connect(analyser);
        const samples = new Uint8Array(analyser.fftSize);
        const measure = () => {
          analyser.getByteTimeDomainData(samples);
          let peak = 0;
          for (const sample of samples) peak = Math.max(peak, Math.abs(sample - 128));
          setLevel(Math.min(1, peak / 64));
          frame = requestAnimationFrame(measure);
        };
        frame = requestAnimationFrame(measure);
      }
    })();

    return () => {
      live = false;
      clearInterval(tick);
      cancelAnimationFrame(frame);
      void audio?.close();
      // Closed any other way than Stop and keep: nothing is kept.
      if (!keep.current && recorder.current?.state === 'recording') recorder.current.stop();
      stream?.getTracks().forEach((track) => track.stop());
    };
  }, []);

  const stop = async () => {
    const taking = recorder.current;
    const chosen = format.current;
    if (!taking || !chosen || phase !== 'recording') return;
    keep.current = true;
    setPhase('saving');
    const durationMs = Date.now() - started.current;
    const stopped = new Promise<void>((resolve) => {
      taking.onstop = () => resolve();
    });
    taking.stop();
    taking.stream.getTracks().forEach((track) => track.stop());
    await stopped;
    const blob = new Blob(chunks.current, { type: chosen.mimeType.split(';')[0] ?? chosen.mimeType });
    try {
      const fileName = voiceFileName(new Date(), await attachments.takenNames(), chosen.extension);
      await attachments.add({ noteUuid, blob, fileName, durationMs });
      onDone(fileName);
    } catch (error) {
      toast.error(
        error instanceof FileTooLargeError
          ? t('gallery.tooLarge', { size: formatBytes(error.bytes), max: formatBytes(maxFileBytes) })
          : t('common.saveFailed'),
      );
      onDone(null);
    }
  };

  return (
    <Dialog open onOpenChange={(open) => !open && phase !== 'saving' && onDone(null)}>
      <DialogContent className="max-w-sm">
        <DialogHeader>
          <DialogTitle>{phase === 'refused' ? t('voice.record') : t('voice.recording')}</DialogTitle>
          <DialogDescription>{phase === 'refused' ? t('voice.noMic') : t('voice.recordingHint')}</DialogDescription>
        </DialogHeader>
        {phase !== 'refused' && (
          <>
            <p className="text-center text-4xl font-extrabold tabular" role="timer" aria-live="off">
              {formatClock(elapsed)}
            </p>
            <div
              className="h-1.5 w-full overflow-hidden rounded-full bg-muted"
              role="meter"
              aria-label={t('voice.level')}
              aria-valuemin={0}
              aria-valuemax={100}
              aria-valuenow={Math.round(level * 100)}
            >
              <div className="h-full bg-destructive transition-[width]" style={{ width: `${Math.round(level * 100)}%` }} />
            </div>
            <div className="grid grid-cols-2 gap-2">
              <Button variant="outline" onClick={() => onDone(null)} disabled={phase === 'saving'}>
                <Trash2Icon />
                {t('voice.discard')}
              </Button>
              <Button onClick={() => void stop()} disabled={phase !== 'recording'}>
                <SquareIcon />
                {t('voice.stop')}
              </Button>
            </div>
          </>
        )}
      </DialogContent>
    </Dialog>
  );
}
