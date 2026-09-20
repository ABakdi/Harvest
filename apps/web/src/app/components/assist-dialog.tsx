import { type AssistAction, assistPrompt } from '@harvest/core';
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

export interface AssistTarget {
  action: AssistAction;
  /** The note, or the selection when the action takes one. */
  text: string;
  /** The note up to the caret, for Continue. */
  upToCaret: string;
  /** Whether [text] is a selection rather than the whole note. */
  fromSelection: boolean;
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
  onClose,
  onInsert,
  onReplace,
}: {
  target: AssistTarget | null;
  model: string;
  onClose: () => void;
  onInsert: (text: string) => void;
  onReplace: (text: string) => void;
}) {
  if (!target) return null;
  // Keyed by the action, so each one opens on a blank answer rather
  // than the last one's.
  return <Asking key={target.action} {...{ target, model, onClose, onInsert, onReplace }} />;
}

function Asking({
  target,
  model,
  onClose,
  onInsert,
  onReplace,
}: {
  target: AssistTarget;
  model: string;
  onClose: () => void;
  onInsert: (text: string) => void;
  onReplace: (text: string) => void;
}) {
  const { t, i18n } = useTranslation();
  const [question, setQuestion] = useState('');
  const [answer, setAnswer] = useState('');
  const [running, setRunning] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const abort = useRef<AbortController | null>(null);

  // Leaving mid-answer stops it: nothing is written down either side.
  useEffect(() => () => abort.current?.abort(), []);
  const asking = target.action === 'ask';

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
      for await (const chunk of assistStream(
        { system: prompt.system, messages: prompt.messages },
        controller.signal,
      )) {
        setAnswer((text) => text + chunk);
      }
    } catch (error) {
      setFailure(error instanceof AssistError ? error.code : 'internal');
    } finally {
      setRunning(false);
    }
  };

  const sends = target.fromSelection ? t('assist.sendsSelection') : t('assist.sendsNote');

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-xl">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <SparklesIcon className="size-5 text-primary" aria-hidden />
            {t(`assist.actions.${target.action}`)}
          </DialogTitle>
          <DialogDescription>
            {t('assist.sends', { what: target.action === 'continueWriting' ? t('assist.sendsUpToCaret') : sends, model })}
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
              <Button onClick={() => onReplace(answer)}>{t('assist.replace')}</Button>
            </>
          )}
          {!answer && (
            <Button disabled={running || (asking && question.trim().length === 0)} onClick={() => void run()}>
              {running ? t('assist.thinking') : t('assist.send')}
            </Button>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
