import { HarvestDay, type Schedule } from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import { MinusIcon, PlusIcon } from 'lucide-react';
import { useId, useState, type FormEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group';
import i18n from '@/i18n';
import { useHarvest, useHarvestDay } from '../../context';
import { albumIsGymBound, albumSchedule, type AlbumRow } from '../../data/gallery';
import { useBusy } from '../use-busy';

type Kind = 'none' | Schedule['type'];

/** Monday first, as the phone's weekday chips are. */
function weekdayNames(): string[] {
  const format = new Intl.DateTimeFormat(i18n.language, { weekday: 'short' });
  // 2024-01-01 was a Monday.
  return Array.from({ length: 7 }, (_, i) => format.format(new Date(2024, 0, 1 + i)));
}

function Stepper({
  id,
  label,
  value,
  min,
  max,
  onChange,
}: {
  id: string;
  label: string;
  value: number;
  min: number;
  max: number;
  onChange: (value: number) => void;
}) {
  const { t } = useTranslation();
  return (
    <div className="flex items-center gap-2" role="group" aria-labelledby={id}>
      <span id={id} className="flex-1 text-sm font-semibold">
        {label}
      </span>
      <Button
        type="button"
        variant="outline"
        size="icon-sm"
        aria-label={`${t('gallery.decrease')} · ${label}`}
        disabled={value <= min}
        onClick={() => onChange(value - 1)}
      >
        <MinusIcon />
      </Button>
      <Button
        type="button"
        variant="outline"
        size="icon-sm"
        aria-label={`${t('gallery.increase')} · ${label}`}
        disabled={value >= max}
        onClick={() => onChange(value + 1)}
      >
        <PlusIcon />
      </Button>
    </div>
  );
}

/**
 * Making or editing an album (the phone's album sheet).
 *
 * The schedule is the whole point: an album with one is a seed on the
 * field (G3), and an album without one is a shoebox. An album a gym
 * program owns takes its rhythm from the gym, so its schedule is not
 * offered at all.
 */
export function AlbumDialog({ album, onClose }: { album: AlbumRow | null; onClose: (created?: AlbumRow) => void }) {
  const { t } = useTranslation();
  const { db, gallery } = useHarvest();
  const today = useHarvestDay();
  const id = useId();
  const existing = album ? albumSchedule(album) : null;
  const gymBound = useLiveQuery(async () => (album ? albumIsGymBound(db, album.uuid) : false), [db, album]);

  const [name, setName] = useState(album?.name ?? '');
  const [note, setNote] = useState(album?.note ?? '');
  const [kind, setKind] = useState<Kind>(album ? (existing?.type ?? 'none') : 'daily');
  const [weekdays, setWeekdays] = useState<string[]>(
    existing?.type === 'weekly' ? [...existing.weekdays].map(String) : ['1', '3', '5'],
  );
  const [everyDays, setEveryDays] = useState(existing?.type === 'interval' ? existing.everyDays : 7);
  const [times, setTimes] = useState(existing?.type === 'timesPerWeek' ? existing.times : 3);
  const [remindAt, setRemindAt] = useState(album?.remindAt ?? '');
  const [error, setError] = useState<string | null>(null);
  const [saving, once] = useBusy();

  function schedule(): Schedule | null {
    switch (kind) {
      case 'none':
        return null;
      case 'daily':
        return { type: 'daily' };
      case 'weekly':
        return { type: 'weekly', weekdays: new Set(weekdays.map(Number)) };
      case 'interval':
        return {
          type: 'interval',
          everyDays,
          // An interval keeps counting from where it started.
          anchorDay:
            existing?.type === 'interval'
              ? existing.anchorDay
              : album
                ? HarvestDay.of(new Date(album.createdAt))
                : today,
        };
      case 'timesPerWeek':
        return { type: 'timesPerWeek', times };
    }
  }

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!name.trim()) {
      setError(t('form.error.required'));
      return;
    }
    if (kind === 'weekly' && weekdays.length === 0) {
      setError(t('gallery.error.weekdays'));
      return;
    }
    setError(null);
    // A gym-owned album keeps whatever schedule it had.
    const input = {
      name,
      schedule: gymBound ? existing : schedule(),
      remindAt: gymBound ? (album?.remindAt ?? null) : remindAt || null,
      note: note || null,
    };
    try {
      if (album) {
        await gallery.updateAlbum(album.uuid, input);
        toast.success(t('gallery.albumSaved'));
        onClose();
      } else {
        const created = await gallery.createAlbum(input);
        toast.success(t('gallery.albumCreated', { name: created.name }));
        onClose(created);
      }
    } catch {
      toast.error(t('common.saveFailed'));
    }
  }

  const field = (part: string) => `${id}-${part}`;
  const names = weekdayNames();

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-lg">
        <DialogHeader>
          <DialogTitle>{album ? t('gallery.editAlbum') : t('gallery.newAlbum')}</DialogTitle>
          <DialogDescription>{t('gallery.albumHint')}</DialogDescription>
        </DialogHeader>
        <form onSubmit={(event) => void once(() => submit(event))} className="flex flex-col gap-4" noValidate>
          <div className="flex flex-col gap-2">
            <Label htmlFor={field('name')}>{t('gallery.albumName')}</Label>
            <Input
              id={field('name')}
              value={name}
              autoFocus={!album}
              maxLength={200}
              placeholder={t('gallery.albumNameHint')}
              aria-invalid={error && !name.trim() ? true : undefined}
              onChange={(event) => setName(event.target.value)}
            />
          </div>

          {gymBound ? (
            <p className="text-sm text-muted-foreground">{t('gallery.gymBound')}</p>
          ) : (
            <fieldset className="flex flex-col gap-3">
              <legend className="mb-1 text-sm font-bold">{t('gallery.schedule')}</legend>
              <p className="text-xs text-muted-foreground">{t('gallery.seedHint')}</p>
              <ToggleGroup
                type="single"
                value={kind}
                onValueChange={(value) => value && setKind(value as Kind)}
                aria-label={t('gallery.schedule')}
                className="flex-wrap"
              >
                <ToggleGroupItem value="none">{t('gallery.scheduleNone')}</ToggleGroupItem>
                <ToggleGroupItem value="daily">{t('seed.scheduleKind.daily')}</ToggleGroupItem>
                <ToggleGroupItem value="weekly">{t('seed.scheduleKind.weekly')}</ToggleGroupItem>
                <ToggleGroupItem value="interval">{t('seed.scheduleKind.interval')}</ToggleGroupItem>
                <ToggleGroupItem value="timesPerWeek">{t('seed.scheduleKind.timesPerWeek')}</ToggleGroupItem>
              </ToggleGroup>
              {kind === 'weekly' && (
                <ToggleGroup
                  type="multiple"
                  value={weekdays}
                  onValueChange={setWeekdays}
                  aria-label={t('seed.weekdays')}
                  className="flex-wrap"
                >
                  {names.map((day, index) => (
                    <ToggleGroupItem key={day} value={String(index + 1)} className="min-w-11">
                      {day}
                    </ToggleGroupItem>
                  ))}
                </ToggleGroup>
              )}
              {kind === 'interval' && (
                <Stepper
                  id={field('every')}
                  label={t('gallery.everyDays', { count: everyDays })}
                  value={everyDays}
                  min={2}
                  max={60}
                  onChange={setEveryDays}
                />
              )}
              {kind === 'timesPerWeek' && (
                <Stepper
                  id={field('times')}
                  label={t('gallery.timesPerWeek', { count: times })}
                  value={times}
                  min={1}
                  max={6}
                  onChange={setTimes}
                />
              )}
              {kind !== 'none' && (
                <div className="flex flex-col gap-2">
                  <Label htmlFor={field('remind')}>{t('seed.remindAt')}</Label>
                  <Input
                    id={field('remind')}
                    type="time"
                    value={remindAt}
                    className="w-full sm:w-40"
                    onChange={(event) => setRemindAt(event.target.value)}
                  />
                </div>
              )}
            </fieldset>
          )}

          <div className="flex flex-col gap-2">
            <Label htmlFor={field('note')}>{t('seed.note')}</Label>
            <Textarea id={field('note')} value={note} rows={2} onChange={(event) => setNote(event.target.value)} />
          </div>

          {error && (
            <p role="alert" className="text-sm font-semibold text-destructive">
              {error}
            </p>
          )}

          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onClose()}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" disabled={saving}>
              {album ? t('common.save') : t('gallery.createAlbum')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
