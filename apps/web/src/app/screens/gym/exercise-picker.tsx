import { filterExercises } from '@harvest/core';
import { InfoIcon, PlusIcon, SearchIcon } from 'lucide-react';
import { useDeferredValue, useId, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { formatNumber } from '@/lib/format';
import { useHarvest } from '../../context';
import { useAllExercises, useCatalogue, type Exercise } from '../../data/exercises';
import { useBusy } from '../../components/use-busy';
import { ExerciseDetailDialog } from './exercise-detail';

/** How many rows are drawn before the search has to narrow it. */
const shownAtOnce = 150;

function ChipRow({
  label,
  values,
  selected,
  onSelect,
}: {
  label: string;
  values: string[];
  selected: string | null;
  onSelect: (value: string | null) => void;
}) {
  return (
    // shrink-0: in a dialog capped at the screen's height a scrolling row
    // may otherwise be squeezed and cut its chips off at the bottom; the
    // padding keeps room for the focus ring.
    <div role="group" aria-label={label} className="-mx-1 flex shrink-0 gap-1.5 overflow-x-auto px-1 py-1">
      {values.map((value) => (
        <Button
          key={value}
          type="button"
          size="sm"
          variant={selected === value ? 'default' : 'outline'}
          aria-pressed={selected === value}
          className="shrink-0 rounded-full"
          onClick={() => onSelect(selected === value ? null : value)}
        >
          {value}
        </Button>
      ))}
    </div>
  );
}

/** Adding one the catalogue is missing; it behaves identically everywhere else. */
function MineForm({ initialName, onCreated, onCancel }: { initialName: string; onCreated: (exercise: Exercise) => void; onCancel: () => void }) {
  const { t } = useTranslation();
  const { exercises } = useHarvest();
  const id = useId();
  const [name, setName] = useState(initialName);
  const [bodyPart, setBodyPart] = useState('');
  const [equipment, setEquipment] = useState('');
  const [target, setTarget] = useState('');
  const [busy, once] = useBusy();
  return (
    <form
      aria-label={t('gym.mineTitle')}
      className="flex flex-col gap-3 rounded-xl border bg-muted/40 p-3"
      onSubmit={(event) => {
        event.preventDefault();
        if (!name.trim()) return;
        // One exercise per press, however fast the second one comes.
        void once(() => exercises.create({ name, bodyPart, equipment, target }).then(onCreated));
      }}
    >
      <p className="text-sm text-muted-foreground">{t('gym.mineBody')}</p>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`${id}-name`}>{t('gym.mineName')}</Label>
        <Input id={`${id}-name`} autoFocus value={name} onChange={(event) => setName(event.target.value)} />
      </div>
      <div className="grid gap-3 sm:grid-cols-3">
        <div className="flex flex-col gap-1.5">
          <Label htmlFor={`${id}-part`}>{t('gym.bodyPart')}</Label>
          <Input id={`${id}-part`} value={bodyPart} onChange={(event) => setBodyPart(event.target.value)} />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor={`${id}-kit`}>{t('gym.equipment')}</Label>
          <Input id={`${id}-kit`} value={equipment} placeholder={t('gym.equipmentHint')} onChange={(event) => setEquipment(event.target.value)} />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor={`${id}-target`}>{t('gym.muscle')}</Label>
          <Input id={`${id}-target`} value={target} onChange={(event) => setTarget(event.target.value)} />
        </div>
      </div>
      <div className="flex justify-end gap-2">
        <Button type="button" variant="outline" onClick={onCancel}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" disabled={busy || !name.trim()}>
          {t('gym.mineAdd')}
        </Button>
      </div>
    </form>
  );
}

/**
 * Choose an exercise (`exercise_picker.dart`): to build a day, and —
 * the case that matters — to swap one mid-session because the rack is
 * taken. Search reads the name, the body part, the kit and every
 * muscle, and every word has to match somewhere.
 *
 * Without [onPick] it is the catalogue to browse: a choice opens the
 * exercise rather than going anywhere.
 */
export function ExercisePicker({ title, onPick, onClose }: { title?: string; onPick?: (exercise: Exercise) => void; onClose: () => void }) {
  const { t } = useTranslation();
  const { db } = useHarvest();
  const searchId = useId();
  const book = useCatalogue();
  const all = useAllExercises(db);
  const [search, setSearch] = useState('');
  const deferred = useDeferredValue(search);
  const [bodyPart, setBodyPart] = useState<string | null>(null);
  const [equipment, setEquipment] = useState<string | null>(null);
  const [adding, setAdding] = useState(false);
  const [detail, setDetail] = useState<string | null>(null);

  const matches = all ? filterExercises(all, { search: deferred, bodyPart, equipment }) : [];
  const choose = (exercise: Exercise) => (onPick ? onPick(exercise) : setDetail(exercise.id));

  return (
    <>
      <Dialog open onOpenChange={(open) => !open && onClose()}>
        <DialogContent className="flex max-h-[90dvh] max-w-2xl flex-col gap-3">
          <DialogHeader>
            <DialogTitle>{title ?? t('gym.pickExercise')}</DialogTitle>
            <DialogDescription>{t('gym.catalogueHint')}</DialogDescription>
          </DialogHeader>
          <div className="relative">
            <SearchIcon className="pointer-events-none absolute start-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" aria-hidden />
            <Label htmlFor={searchId} className="sr-only">
              {t('gym.searchExercises')}
            </Label>
            <Input
              id={searchId}
              type="search"
              autoFocus
              className="ps-9"
              placeholder={t('gym.searchExercises')}
              value={search}
              onChange={(event) => setSearch(event.target.value)}
            />
          </div>
          {book && (
            <>
              <ChipRow label={t('gym.bodyPart')} values={book.bodyParts} selected={bodyPart} onSelect={setBodyPart} />
              <ChipRow label={t('gym.equipment')} values={book.equipment} selected={equipment} onSelect={setEquipment} />
            </>
          )}
          <div className="flex items-center justify-between gap-2 text-xs text-muted-foreground">
            <span aria-live="polite">{all ? t('gym.exerciseCount', { count: matches.length, replace: { count: formatNumber(matches.length) } }) : t('gym.catalogueLoading')}</span>
            {!adding && (
              <Button type="button" size="sm" variant="ghost" onClick={() => setAdding(true)}>
                <PlusIcon />
                {t('gym.mineTitle')}
              </Button>
            )}
          </div>
          {adding && (
            <MineForm
              initialName={search}
              onCancel={() => setAdding(false)}
              onCreated={(exercise) => {
                setAdding(false);
                if (onPick) onPick(exercise);
                else setSearch(exercise.name);
              }}
            />
          )}
          <div className="-mx-1 min-h-0 flex-1 overflow-y-auto px-1">
            {all && matches.length === 0 ? (
              <div className="flex flex-col items-center gap-1 py-8 text-center">
                <p className="font-bold">{t('gym.noExercise')}</p>
                <p className="text-sm text-muted-foreground">{t('gym.noExerciseBody')}</p>
              </div>
            ) : (
              <ul className="flex flex-col gap-1.5">
                {matches.slice(0, shownAtOnce).map((exercise) => (
                  <li key={exercise.id} className="flex items-center gap-1 rounded-lg border bg-card">
                    <button
                      type="button"
                      className="flex min-w-0 flex-1 flex-col items-start rounded-lg px-3 py-2 text-start outline-none hover:bg-accent focus-visible:ring-2 focus-visible:ring-ring"
                      onClick={() => choose(exercise)}
                    >
                      <span className="w-full truncate font-bold">{exercise.name}</span>
                      <span className="w-full truncate text-xs text-muted-foreground">
                        {[exercise.mine ? t('gym.mine') : null, exercise.equipment, exercise.target].filter(Boolean).join(' · ')}
                      </span>
                    </button>
                    {onPick && (
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon-sm"
                        className="me-1"
                        aria-label={t('gym.howToNamed', { name: exercise.name })}
                        onClick={() => setDetail(exercise.id)}
                      >
                        <InfoIcon />
                      </Button>
                    )}
                  </li>
                ))}
              </ul>
            )}
            {matches.length > shownAtOnce && (
              <p className="py-3 text-center text-xs text-muted-foreground">{t('gym.moreExercises', { count: matches.length - shownAtOnce, replace: { count: formatNumber(matches.length - shownAtOnce) } })}</p>
            )}
          </div>
        </DialogContent>
      </Dialog>
      {detail && <ExerciseDetailDialog exerciseId={detail} onClose={() => setDetail(null)} />}
    </>
  );
}

