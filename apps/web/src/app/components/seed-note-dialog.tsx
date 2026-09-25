import { useLiveQuery } from 'dexie-react-hooks';
import { HistoryIcon } from 'lucide-react';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { formatDay } from '@/lib/format';
import { useHarvest, useHarvestDay } from '../context';
import { notesFor, seedNoteMaxLength } from '../data/seed-notes';
import type { SeedRow } from '../data/seeds';
import { useBusy } from './use-busy';

/**
 * Today's note on a seed, with the last one I wrote quoted above it.
 *
 * This is the whole point of day-keyed notes: I open the book, the
 * dialog tells me I stopped on page 143, and I write down where I stop
 * today. Tomorrow it says 178, and today's is still in the timeline.
 */
export function SeedNoteDialog({ seed, onClose }: { seed: SeedRow; onClose: () => void }) {
  const { t } = useTranslation();
  const { db, seedNotes } = useHarvest();
  const day = useHarvestDay();
  const notes = useLiveQuery(() => notesFor(db, seed.uuid), [db, seed.uuid]);
  const [draft, setDraft] = useState<string | null>(null);
  const [saving, once] = useBusy();
  if (!notes) return null;

  const todays = notes.find((note) => note.harvestDay === day.key);
  const previous = notes.find((note) => note.harvestDay < day.key);
  const body = draft ?? todays?.body ?? '';

  async function save() {
    await seedNotes.write(seed.uuid, day, body);
    onClose();
  }

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>{t('seedDetail.notesTitle')}</DialogTitle>
          <DialogDescription>{seed.title}</DialogDescription>
        </DialogHeader>
        <form
          className="flex flex-col gap-3"
          onSubmit={(event) => {
            event.preventDefault();
            void once(save);
          }}
        >
          {previous && (
            <figure className="flex flex-col gap-1 rounded-xl bg-secondary/60 p-3">
              <figcaption className="flex items-center gap-1 text-xs font-extrabold text-muted-foreground">
                <HistoryIcon className="size-3.5" aria-hidden />
                {t('seedDetail.lastTime', { day: formatDay(previous.harvestDay) })}
              </figcaption>
              <blockquote className="text-sm whitespace-pre-wrap">{previous.body}</blockquote>
            </figure>
          )}
          <Label htmlFor="seed-note">{t('seedDetail.noteForDay', { day: formatDay(day.key) })}</Label>
          <Textarea
            id="seed-note"
            autoFocus
            rows={4}
            maxLength={seedNoteMaxLength}
            placeholder={t('seedDetail.noteHint')}
            value={body}
            onChange={(event) => setDraft(event.target.value)}
          />
          <p className="text-xs text-muted-foreground">{t('seedDetail.notesExplainer')}</p>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={onClose}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" disabled={saving}>
              {t('common.save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
