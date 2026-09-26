import { type AssistAction, assistPrompt } from '@harvest/core';
import { useQueryClient } from '@tanstack/react-query';
import { CopyIcon, SparklesIcon } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { AssistError, assistStream } from '../data/assist';
import { tooLongToTranscribe, transcribeAudio, transcribeLimitMb, transcribeMimeType } from '../data/transcribe';

export interface AssistTarget {
  action: AssistAction;
  /** The note, or the selection when the action takes one. */
  text: string;
  /** The note up to the caret, for Continue. */
  upToCaret: string;
  /** Whether [text] is a selection rather than the whole note. */
  fromSelection: boolean;
  /** The recording, for Transcribe: its file name and its file. */
  recording?: { name: string; blob: Blob };
}

/**
 * What an assist action sends, what it answered, and what to do with
 * the answer ([[ADR-013-Assist-Providers]]).
 *
 * Nothing is sent until the button is pressed, the dialog says what
 * will be sent and to whom, and the answer is a proposal: the note
 * changes when I choose, not before.
 */
export function AssistDialog({
  target,
  model,
  spent = false,
  onClose,
  onInsert,
  onReplace,
}: {
  target: AssistTarget | null;
  model: string;
  /** Whether the server says today's assist is used up. */
  spent?: boolean;
  onClose: () => void;
  onInsert: (text: string) => void;
  onReplace: (text: string) => void;
}) {
  if (!target) return null;
  // Keyed by the action (and the recording), so each one opens on a
  // blank answer rather than the last one's.
  return (
    <Asking
      key={`${target.action}:${target.recording?.name ?? ''}`}
      {...{ target, model, spent, onClose, onInsert, onReplace }}
    />
  );
}

function Asking({
  target,
  model,
  spent,
  onClose,
  onInsert,
  onReplace,
}: {
  target: AssistTarget;
  model: string;
  spent: boolean;
  onClose: () => void;
  onInsert: (text: string) => void;
  onReplace: (text: string) => void;
}) {
  const { t, i18n } = useTranslation();
  const queries = useQueryClient();
  const [question, setQuestion] = useState('');
  const [answer, setAnswer] = useState('');
  const [running, setRunning] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const abort = useRef<AbortController | null>(null);

  // Leaving mid-answer stops it: nothing is written down either side.
  useEffect(() => () => abort.current?.abort(), []);
  const asking = target.action === 'ask';
  const recording = target.action === 'transcribe' ? target.recording : undefined;
  const mimeType = recording ? transcribeMimeType(recording.blob, recording.name) : null;
  // Refused here, before anything goes: past the server's cap, or not
  // a kind of recording it takes (N10).
  const refusal =
    target.action !== 'transcribe'
      ? null
      : !recording || mimeType === null
        ? t('assist.transcribeUnknown')
        : tooLongToTranscribe(recording.blob)
          ? t('assist.transcribeTooLong', { limit: transcribeLimitMb })
          : null;

  const run = async () => {
    const controller = new AbortController();
    abort.current = controller;
    setRunning(true);
    setAnswer('');
    setFailure(null);
    const prompt = assistPrompt(target.action, {
      text: target.text,
      upToCaret: target.upToCaret,
      question,
      language: i18n.language,
    });
    try {
      const audio = prompt.wantsAudio && recording && mimeType ? await transcribeAudio(recording.blob, mimeType) : undefined;
      for await (const chunk of assistStream(
        { system: prompt.system, messages: prompt.messages, ...(audio ? { audio } : {}) },
        controller.signal,
      )) {
        setAnswer((text) => text + chunk);
      }
    } catch (error) {
      setFailure(error instanceof AssistError ? error.code : 'internal');
    } finally {
      setRunning(false);
      // Each ask is counted, so what is left today is asked again.
      void queries.invalidateQueries({ queryKey: ['assist-status'] });
    }
  };

  const sends =
    target.action === 'transcribe'
      ? t('assist.sendsRecording', { name: recording?.name ?? '' })
      : target.action === 'continueWriting'
        ? t('assist.sendsUpToCaret')
        : target.fromSelection
          ? t('assist.sendsSelection')
          : t('assist.sendsNote');

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-xl">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <SparklesIcon className="size-5 text-primary" aria-hidden />
            {t(`assist.actions.${target.action}`)}
          </DialogTitle>
          <DialogDescription>
            {t('assist.sends', { what: sends, model })}
          </DialogDescription>
        </DialogHeader>

        {asking && (
          <Input
            autoFocus
            value={question}
            placeholder={t('assist.questionHint')}
            onChange={(event) => setQuestion(event.target.value)}
            aria-label={t('assist.question')}
          />
        )}

        {answer && (
          <div dir="auto" className="max-h-64 overflow-y-auto whitespace-pre-wrap rounded-xl border bg-card p-3 text-sm">
            {answer}
          </div>
        )}
        {failure && <p className="text-sm text-destructive">{t(`assist.failures.${failure}`, t('assist.failures.other'))}</p>}
        {!answer && !failure && (refusal ?? (spent ? t('assist.failures.rate_limited') : null)) && (
          <p role="alert" className="text-sm text-destructive">
            {refusal ?? t('assist.failures.rate_limited')}
          </p>
        )}

        <DialogFooter className="flex-wrap gap-2">
          <Button variant="outline" onClick={onClose}>
            {t('common.close')}
          </Button>
          {answer && !running && (
            <>
              <Button
                variant="outline"
                onClick={() => {
                  void navigator.clipboard.writeText(answer).then(
                    () => toast.success(t('assist.copied')),
                    () => toast.error(t('common.somethingWrong')),
                  );
                }}
              >
                <CopyIcon />
                {t('assist.copy')}
              </Button>
              <Button variant="outline" onClick={() => onInsert(answer)}>
                {t('assist.insert')}
              </Button>
              {/* A transcript goes under its recording; it replaces nothing. */}
              {target.action !== 'transcribe' && <Button onClick={() => onReplace(answer)}>{t('assist.replace')}</Button>}
            </>
          )}
          {!answer && (
            <Button
              disabled={running || spent || refusal !== null || (asking && question.trim().length === 0)}
              onClick={() => void run()}
            >
              {running ? t('assist.thinking') : t('assist.send')}
            </Button>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
