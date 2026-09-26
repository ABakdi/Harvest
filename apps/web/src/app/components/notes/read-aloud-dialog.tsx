import { PauseIcon, PlayIcon, SkipForwardIcon } from 'lucide-react';
import { useEffect, useId, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { formatNumber } from '@/lib/format';
import { localVoice, speechLanguageOf, speechParagraphs } from './voice';

/**
 * Reads a note aloud, a paragraph at a time (the phone's read-aloud
 * sheet, [[Notes]] N10): play, pause, next, and a speed from 0.75× to
 * 2×. Only a voice on this computer reads; a paragraph with no such
 * voice for its language is skipped with a word rather than sent to a
 * voice that lives on a server.
 */
export function ReadAloudDialog({ markdown, onClose }: { markdown: string; onClose: () => void }) {
  const { t, i18n } = useTranslation();
  const id = useId();
  const [paragraphs] = useState(() => speechParagraphs(markdown));
  const [index, setIndex] = useState(0);
  const [playing, setPlaying] = useState(false);
  const [rate, setRate] = useState(1);
  const [noVoice, setNoVoice] = useState(false);
  // Bumped on every stop, so a paragraph that ends after Pause does not start the next.
  const run = useRef(0);

  useEffect(
    () => () => {
      run.current++;
      speechSynthesis.cancel();
    },
    [],
  );

  const speakFrom = (start: number) => {
    const current = ++run.current;
    speechSynthesis.cancel();
    const say = (at: number) => {
      if (current !== run.current) return;
      if (at >= paragraphs.length) {
        setPlaying(false);
        setIndex(0);
        return;
      }
      setIndex(at);
      const text = paragraphs[at]!;
      const voice = localVoice(speechLanguageOf(text, i18n.language));
      if (!voice) {
        setNoVoice(true);
        say(at + 1);
        return;
      }
      const utterance = new SpeechSynthesisUtterance(text);
      utterance.voice = voice;
      utterance.lang = voice.lang;
      utterance.rate = rate;
      utterance.onend = () => say(at + 1);
      utterance.onerror = () => {
        if (current === run.current) setPlaying(false);
      };
      speechSynthesis.speak(utterance);
    };
    setPlaying(true);
    say(start);
  };

  const pause = () => {
    run.current++;
    speechSynthesis.cancel();
    setPlaying(false);
  };

  const next = () => {
    const at = Math.min(index + 1, paragraphs.length - 1);
    if (playing) speakFrom(at);
    else setIndex(at);
  };

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>{t('voice.readAloud')}</DialogTitle>
          <DialogDescription>
            {paragraphs.length === 0
              ? t('voice.readAloudEmpty')
              : t('voice.paragraph', { index: formatNumber(Math.min(index + 1, paragraphs.length)), count: paragraphs.length })}
          </DialogDescription>
        </DialogHeader>
        {paragraphs.length > 0 && (
          <>
            <p className="line-clamp-6 text-lg" dir="auto" aria-live="polite">
              {paragraphs[Math.min(index, paragraphs.length - 1)]}
            </p>
            {noVoice && (
              <p role="status" className="text-sm text-muted-foreground">
                {t('voice.noLocalVoice')}
              </p>
            )}
            <div className="flex items-center justify-center gap-3">
              <Button size="icon" className="size-12 rounded-full" aria-label={playing ? t('voice.pause') : t('voice.play')} onClick={() => (playing ? pause() : speakFrom(index))}>
                {playing ? <PauseIcon /> : <PlayIcon className="rtl:rotate-180" />}
              </Button>
              <Button variant="ghost" size="icon" aria-label={t('voice.next')} onClick={next}>
                <SkipForwardIcon className="rtl:rotate-180" />
              </Button>
            </div>
            <div className="flex flex-col gap-1">
              <label htmlFor={`${id}-rate`} className="text-sm font-semibold">
                {t('voice.speed')}
              </label>
              <input
                id={`${id}-rate`}
                type="range"
                min={0.75}
                max={2}
                step={0.25}
                value={rate}
                aria-valuetext={`${formatNumber(rate)}×`}
                className="accent-primary"
                onChange={(event) => setRate(Number(event.target.value))}
              />
            </div>
          </>
        )}
      </DialogContent>
    </Dialog>
  );
}
