import {
  barChoicesIn,
  barIn,
  loadFieldValue,
  parseScheduleJson,
  reorderedUuids,
  resolveTarget,
  roundLoad,
  usesBar,
  weightToGrams,
  type Schedule,
} from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import {
  ArrowDownIcon,
  ArrowLeftIcon,
  ArrowUpIcon,
  CameraIcon,
  ChevronRightIcon,
  CircleHelpIcon,
  EllipsisVerticalIcon,
  GaugeIcon,
  GripVerticalIcon,
  LeafIcon,
  PercentIcon,
  PlusIcon,
  InfinityIcon,
  Trash2Icon,
  UnlinkIcon,
  XIcon,
} from 'lucide-react';
import { useId, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Link, useNavigate, useParams } from 'react-router';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Switch } from '@/components/ui/switch';
import { cn } from '@/lib/utils';
import { EmptyState } from '../../components/bits';
import { useHarvest } from '../../context';
import { useExercise } from '../../data/exercises';
import {
  percentageExercises,
  readProgram,
  readTrainingMaxes,
  type DayTree,
  type ProgramTree,
  type SlotTree,
  type TargetSetRow,
} from '../../data/gym';
import { parseWeight } from '../../data/health';
import type { PhotoPrompt } from '../../data/programs';
import { ExercisePicker } from './exercise-picker';
import { useBusy } from '../../components/use-busy';
import { RestField, SetText, loadField, useAsker, useLoad, useSeededField, useTargetText, useUnit, useUnitKnown, type Asker } from './shared';

// ---------------------------------------------------------------- the seed

function useScheduleText(): (json: string | null) => string {
  const { t } = useTranslation();
  return (json) => {
    let schedule: Schedule | null;
    try {
      schedule = json ? parseScheduleJson(json) : null;
    } catch {
      schedule = null;
    }
    if (schedule?.type === 'timesPerWeek') return t('gym.timesPerWeek', { count: schedule.times });
    if (schedule?.type === 'daily') return t('gym.everyDay');
    return t('gym.plantedNoSchedule');
  };
}

/** Days a week — not which days — and the offer of an album, once. */
function PlantDialog({ tree, onClose }: { tree: ProgramTree; onClose: () => void }) {
  const { t } = useTranslation();
  const { programs } = useHarvest();
  const albumId = useId();
  const [times, setTimes] = useState<number | null>(null);
  const [album, setAlbum] = useState(false);
  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>{t('gym.howOften')}</DialogTitle>
          <DialogDescription>{t('gym.howOftenBody')}</DialogDescription>
        </DialogHeader>
        <div role="radiogroup" aria-label={t('gym.howOften')} className="flex flex-wrap gap-2">
          {[1, 2, 3, 4, 5, 6, 7].map((count) => (
            <Button
              key={count}
              type="button"
              role="radio"
              aria-checked={times === count}
              variant={times === count ? 'default' : 'outline'}
              size="sm"
              onClick={() => setTimes(count)}
            >
              {count === 7 ? t('gym.everyDay') : t('gym.timesPerWeek', { count })}
            </Button>
          ))}
        </div>
        <div className="flex items-start gap-3 rounded-lg bg-muted/50 p-3">
          <Checkbox id={albumId} checked={album} onCheckedChange={(checked) => setAlbum(checked === true)} className="mt-0.5" />
          <div className="flex flex-col gap-1">
            <Label htmlFor={albumId}>{t('gym.albumOffer')}</Label>
            <p className="text-xs text-muted-foreground">{t('gym.albumOfferBody')}</p>
          </div>
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            {t('common.cancel')}
          </Button>
          <Button
            disabled={times === null}
            onClick={() => {
              if (times === null) return;
              void programs.plant(tree.program.uuid, { title: tree.program.name, timesPerWeek: times, album }).then(() => {
                onClose();
                toast.success(t('gym.planted'));
              });
            }}
          >
            <LeafIcon />
            {t('gym.plant')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

/**
 * The program, on the field (`ProgramSeedCard`): bound to a habit it is
 * a seed like any other and Finish checks it in (Y4, Y12). Unbound it is
 * a document, which is a fine thing for a program to be — so this offers
 * and never nags.
 */
function SeedCard({ tree, asker }: { tree: ProgramTree; asker: Asker }) {
  const { t } = useTranslation();
  const { db, programs } = useHarvest();
  const scheduleText = useScheduleText();
  const [planting, setPlanting] = useState(false);
  const { program } = tree;
  const seed = useLiveQuery(async () => (program.commitmentUuid ? ((await db.rows('commitments').get(program.commitmentUuid)) ?? null) : null), [db, program.commitmentUuid]);
  const album = useLiveQuery(async () => (program.albumUuid ? ((await db.rows('albums').get(program.albumUuid)) ?? null) : null), [db, program.albumUuid]);

  if (!program.commitmentUuid) {
    return (
      <section className="flex flex-wrap items-center gap-3 rounded-2xl border bg-card p-4">
        <LeafIcon className="size-6 text-primary" aria-hidden />
        <div className="flex min-w-0 flex-1 flex-col">
          <h2 className="font-extrabold">{t('gym.plantProgram')}</h2>
          <p className="text-sm text-muted-foreground">{t('gym.plantProgramBody')}</p>
        </div>
        <Button onClick={() => setPlanting(true)}>{t('gym.plant')}</Button>
        {planting && <PlantDialog tree={tree} onClose={() => setPlanting(false)} />}
      </section>
    );
  }

  async function unplant() {
    const ok = await asker.confirm({ title: t('gym.unplant'), body: t('gym.unplantBody'), action: t('gym.unplant') });
    if (ok) await programs.unplant(program.uuid);
  }

  const prompts: PhotoPrompt[] = ['after', 'before', 'never'];
  return (
    <section className="flex flex-col gap-3 rounded-2xl border bg-card p-4">
      <div className="flex items-center gap-3">
        <LeafIcon className="size-6 text-primary" aria-hidden />
        <div className="flex min-w-0 flex-1 flex-col">
          <h2 className="truncate font-extrabold">{seed?.title ?? program.name}</h2>
          <p className="text-sm text-muted-foreground">{scheduleText(seed?.scheduleJson ?? null)}</p>
        </div>
        <Button variant="ghost" size="icon" aria-label={t('gym.unplant')} title={t('gym.unplant')} onClick={() => void unplant()}>
          <UnlinkIcon />
        </Button>
      </div>
      {album && (
        <div className="flex flex-wrap items-center gap-3 border-t pt-3">
          <CameraIcon className="size-5 text-muted-foreground" aria-hidden />
          <div className="flex min-w-0 flex-1 flex-col">
            <span className="font-bold">{album.name}</span>
            <span className="text-xs text-muted-foreground">{t('gym.photoPromptBody')}</span>
          </div>
          <div role="radiogroup" aria-label={t('gym.photoPrompt')} className="flex flex-wrap gap-1.5">
            {prompts.map((prompt) => (
              <Button
                key={prompt}
                size="sm"
                role="radio"
                aria-checked={program.photoPrompt === prompt}
                variant={program.photoPrompt === prompt ? 'default' : 'outline'}
                onClick={() => void programs.updateProgram(program.uuid, { photoPrompt: prompt })}
              >
                {t(`gym.prompt.${prompt}`)}
              </Button>
            ))}
          </div>
        </div>
      )}
    </section>
  );
}

// ------------------------------------------------------------- target sets

/**
 * Editing one target: a weight or a percentage, reps, and whether it is
 * open. Nothing is drawn until the unit is read — a weight seeded in
 * kilograms under a pound label is saved back as pounds.
 */
function EditSetDialog({ set, onClose }: { set: TargetSetRow; onClose: () => void }) {
  return useUnitKnown() ? <EditSetForm set={set} onClose={onClose} /> : null;
}

function EditSetForm({ set, onClose }: { set: TargetSetRow; onClose: () => void }) {
  const { t } = useTranslation();
  const { programs } = useHarvest();
  const unit = useUnit();
  const load = useLoad();
  const id = useId();
  const [percentage, setPercentage] = useState(set.percentTenths !== null);
  const [value, setValue] = useSeededField((shown) =>
    set.percentTenths !== null ? String(set.percentTenths / 10) : set.weightGrams !== null ? loadField(set.weightGrams, shown) : '',
  );
  const [reps, setReps] = useState(set.reps === null ? '' : String(set.reps));
  const [open, setOpen] = useState(set.openEnded);
  const [busy, once] = useBusy();
  const number = parseWeight(value);
  // What the typed load will be kept as, shown before it is saved rather
  // than changed behind my back: 61.3 kg is 61.25 kg on a bar (Y8).
  const rounded = !percentage && number !== null ? roundLoad(weightToGrams(unit, number), unit) : null;
  const roundedAway = rounded !== null && Number(loadFieldValue(rounded, unit)) !== number;
  // Rounded on leaving the field, the hint stays until the next keystroke:
  // were it to vanish, Save would jump up under the pointer mid-click.
  const [kept, setKept] = useState<number | null>(null);
  const hint = roundedAway ? rounded : kept;
  const repsNumber = reps.trim() === '' ? null : Number(reps);
  const validReps = repsNumber === null || (Number.isInteger(repsNumber) && repsNumber >= 0);

  return (
    <Dialog open onOpenChange={(next) => !next && onClose()}>
      <DialogContent className="max-w-sm">
        <DialogHeader>
          <DialogTitle>{t('gym.editSet')}</DialogTitle>
          <DialogDescription className="sr-only">{t('gym.setsSubtitle')}</DialogDescription>
        </DialogHeader>
        <form
          className="flex flex-col gap-4"
          onSubmit={(event) => {
            event.preventDefault();
            if (number === null || !validReps) return;
            // A load left as it was shown is the load it was: 60 kg read as
            // 132.25 lb and saved untouched stays 60 kg, not 59.99.
            const untouched = !percentage && set.percentTenths === null && set.weightGrams !== null && value === loadField(set.weightGrams, unit);
            void once(() =>
              programs.updateTargetSet(set.uuid, {
                reps: repsNumber,
                openEnded: open,
                percentTenths: percentage ? Math.round(number * 10) : null,
                weightGrams: percentage ? null : untouched ? set.weightGrams : roundLoad(weightToGrams(unit, number), unit),
              }),
            ).then(onClose);
          }}
        >
          <div role="radiogroup" aria-label={t('gym.loadKind')} className="grid grid-cols-2 gap-1 rounded-lg bg-muted p-1">
            {[false, true].map((kind) => (
              <button
                key={String(kind)}
                type="button"
                role="radio"
                aria-checked={percentage === kind}
                onClick={() => setPercentage(kind)}
                className={cn(
                  'rounded-md px-3 py-1.5 text-sm font-extrabold outline-none focus-visible:ring-2 focus-visible:ring-ring',
                  percentage === kind ? 'bg-card shadow-sm' : 'text-muted-foreground',
                )}
              >
                {kind ? t('gym.percentOfMax') : t(`body.unit.${unit}`)}
              </button>
            ))}
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor={`${id}-load`}>{percentage ? t('gym.percent') : t('gym.weight')}</Label>
              <Input
                id={`${id}-load`}
                inputMode="decimal"
                value={value}
                aria-describedby={hint !== null ? `${id}-rounded` : undefined}
                onChange={(event) => {
                  setKept(null);
                  setValue(event.target.value);
                }}
                onBlur={() => {
                  if (!roundedAway || rounded === null) return;
                  setKept(rounded);
                  setValue(loadFieldValue(rounded, unit));
                }}
              />
              {hint !== null && (
                <p id={`${id}-rounded`} className="text-xs font-bold text-muted-foreground" aria-live="polite">
                  {t('gymWeb.roundsTo', { load: load(hint) })}
                </p>
              )}
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor={`${id}-reps`}>{t('gym.reps')}</Label>
              <Input id={`${id}-reps`} inputMode="numeric" value={reps} onChange={(event) => setReps(event.target.value)} />
            </div>
          </div>
          <div className="flex items-start justify-between gap-3">
            <div className="flex flex-col gap-1">
              <Label htmlFor={`${id}-open`}>{t('gym.openSet')}</Label>
              <p className="text-xs text-muted-foreground">{t('gym.openSetHint')}</p>
            </div>
            <Switch id={`${id}-open`} checked={open} onCheckedChange={setOpen} />
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={onClose}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" disabled={busy || number === null || !validReps}>
              {t('common.save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

/** The mark for a set: its number, or `1+` on the open one — the program and the session call it one thing. */
export function SetBadge({ position, openEnded }: { position: number; openEnded: boolean }) {
  return (
    <span
      className={cn(
        'flex size-7 shrink-0 items-center justify-center rounded-full text-xs font-extrabold tabular',
        openEnded ? 'bg-primary text-primary-foreground' : 'bg-muted text-muted-foreground',
      )}
    >
      {openEnded ? '1+' : position + 1}
    </span>
  );
}

/** What one exercise in a day asks for: its sets, its rest, its bar (`target_set_sheet.dart`). */
function SlotDialog({ slotUuid, programUuid, onClose }: { slotUuid: string; programUuid: string; onClose: () => void }) {
  const { t } = useTranslation();
  const { db, programs } = useHarvest();
  const load = useLoad();
  const unit = useUnit();
  const targetText = useTargetText();
  // Read out of the live program, so the dialog redraws as sets are added.
  const tree = useLiveQuery(() => readProgram(db, programUuid), [db, programUuid]);
  const slot = tree?.days.flatMap((day) => day.slots).find((s) => s.row.uuid === slotUuid);
  const exercise = useExercise(db, slot?.row.exerciseId ?? null);
  const [editing, setEditing] = useState<TargetSetRow | null>(null);
  if (tree !== undefined && !slot) return null;

  // A new set starts as the last plain one, as on the phone (`nextTargetSet`):
  // the fifth set of five is rarely a different weight from the fourth.
  const add = (input: { reps: number; percentTenths: number | null; openEnded: boolean }) => {
    if (!slot) return;
    const last = [...slot.sets].reverse().find((set) => !set.openEnded && !input.openEnded);
    void programs.addTargetSet(
      slot.row.uuid,
      last ? { weightGrams: last.weightGrams, reps: last.reps, percentTenths: last.percentTenths, openEnded: false } : { weightGrams: null, ...input },
    );
  };

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-h-[90dvh] max-w-md overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{exercise?.name ?? t('gym.unknownExercise')}</DialogTitle>
          <DialogDescription>{t('gym.setsSubtitle')}</DialogDescription>
        </DialogHeader>
        {slot && (
          <>
            <ul className="flex flex-col gap-1">
              {slot.sets.map((set) => (
                <li key={set.uuid} className="flex items-center gap-2">
                  <SetBadge position={set.position} openEnded={set.openEnded} />
                  <button
                    type="button"
                    className="min-w-0 flex-1 rounded-md px-2 py-1.5 text-start outline-none hover:bg-accent focus-visible:ring-2 focus-visible:ring-ring"
                    aria-label={t('gym.editSetNamed', { set: targetText(set, set.weightGrams) })}
                    onClick={() => setEditing(set)}
                  >
                    <SetText>{targetText(set, set.weightGrams)}</SetText>
                  </button>
                  <Button variant="ghost" size="icon-sm" aria-label={t('gym.removeSetNamed', { set: targetText(set, set.weightGrams) })} onClick={() => void programs.removeTargetSet(set.uuid)}>
                    <XIcon />
                  </Button>
                </li>
              ))}
            </ul>
            <div className="flex flex-wrap gap-2">
              <Button size="sm" variant="outline" onClick={() => add({ reps: 5, percentTenths: null, openEnded: false })}>
                <PlusIcon />
                {t('gym.addSet')}
              </Button>
              <Button size="sm" variant="outline" onClick={() => add({ reps: 5, percentTenths: 750, openEnded: false })}>
                <PercentIcon />
                {t('gym.addPercentSet')}
              </Button>
              <Button size="sm" variant="outline" onClick={() => add({ reps: 1, percentTenths: 950, openEnded: true })}>
                <InfinityIcon />
                {t('gym.addOpenSet')}
              </Button>
            </div>
            {/* The bar only where there is one: a dumbbell asks no such question (Y9). */}
            {exercise && usesBar(exercise) && (
              <div className="flex flex-col gap-2 border-t pt-3">
                <div className="flex justify-between gap-2 text-sm">
                  <span className="font-bold">{t('gym.barWeight')}</span>
                  <span className="text-muted-foreground">{load(barIn(slot.row.barGrams, unit))}</span>
                </div>
                <div role="radiogroup" aria-label={t('gym.barWeight')} className="flex flex-wrap gap-1.5">
                  {/* Pounds get a pound gym's bars, not 20 kg read as 44.09 (Y8). */}
                  {barChoicesIn(unit).map((grams) => (
                    <Button
                      key={grams}
                      size="sm"
                      role="radio"
                      aria-checked={barIn(slot.row.barGrams, unit) === grams}
                      variant={barIn(slot.row.barGrams, unit) === grams ? 'default' : 'outline'}
                      onClick={() => void programs.updateSlot(slot.row.uuid, { barGrams: grams })}
                    >
                      {load(grams)}
                    </Button>
                  ))}
                </div>
              </div>
            )}
            <div className="flex flex-col gap-2 border-t pt-3">
              <div className="flex justify-between gap-2 text-sm">
                <span className="font-bold">{t('gym.rest')}</span>
                <span className="text-muted-foreground">
                  {slot.row.restSeconds === null ? t('gym.notSet') : t('gym.restSeconds', { count: slot.row.restSeconds })}
                </span>
              </div>
              <RestField seconds={slot.row.restSeconds} onChange={(seconds) => void programs.updateSlot(slot.row.uuid, { restSeconds: seconds })} />
            </div>
            <Button
              variant="ghost"
              className="self-start text-destructive"
              onClick={() => {
                onClose();
                void programs.removeSlot(slot.row.uuid);
              }}
            >
              <Trash2Icon />
              {t('gym.removeExercise')}
            </Button>
          </>
        )}
        {editing && <EditSetDialog set={editing} onClose={() => setEditing(null)} />}
      </DialogContent>
    </Dialog>
  );
}

// -------------------------------------------------------------------- days

function SlotRow({
  slot,
  index,
  count,
  trainingMaxGrams,
  onOpen,
  onMove,
  onDragStart,
  onDrop,
}: {
  slot: SlotTree;
  index: number;
  count: number;
  trainingMaxGrams: number | undefined;
  onOpen: () => void;
  onMove: (to: number) => void;
  onDragStart: () => void;
  onDrop: () => void;
}) {
  const { t } = useTranslation();
  const { db } = useHarvest();
  const unit = useUnit();
  const targetText = useTargetText();
  const exercise = useExercise(db, slot.row.exerciseId);
  const name = exercise?.name ?? t('gym.unknownExercise');
  return (
    <li
      className="flex items-center gap-1 rounded-lg hover:bg-accent/50"
      onDragOver={(event) => event.preventDefault()}
      onDrop={(event) => {
        event.preventDefault();
        onDrop();
      }}
    >
      <button
        type="button"
        onClick={onOpen}
        className="flex min-w-0 flex-1 flex-col items-start rounded-lg px-2 py-1.5 text-start outline-none focus-visible:ring-2 focus-visible:ring-ring"
      >
        <span className="w-full truncate font-bold">{name}</span>
        {slot.sets.length === 0 ? (
          <span className="text-xs text-muted-foreground">{t('gym.noSetsYet')}</span>
        ) : (
          <span className="flex flex-wrap gap-x-2 text-xs text-muted-foreground">
            {slot.sets.map((set) => (
              <SetText key={set.uuid} className={cn(set.openEnded && 'font-extrabold text-primary')}>
                {targetText(set, resolveTarget(set, trainingMaxGrams, unit))}
              </SetText>
            ))}
          </span>
        )}
      </button>
      <ChevronRightIcon className="size-4 shrink-0 text-muted-foreground rtl:rotate-180" aria-hidden />
      {/* The handle is the drag start; arrows move it from the keyboard. */}
      <button
        type="button"
        draggable
        onDragStart={(event) => {
          event.dataTransfer.effectAllowed = 'move';
          onDragStart();
        }}
        onKeyDown={(event) => {
          if (event.key === 'ArrowUp' && index > 0) {
            event.preventDefault();
            onMove(index - 1);
          } else if (event.key === 'ArrowDown' && index < count - 1) {
            event.preventDefault();
            onMove(index + 1);
          }
        }}
        aria-label={t('gym.reorderHandle', { name })}
        title={t('gym.reorderHint')}
        className="cursor-grab rounded-md p-2 text-muted-foreground outline-none hover:bg-accent focus-visible:ring-2 focus-visible:ring-ring active:cursor-grabbing"
      >
        <GripVerticalIcon className="size-4" aria-hidden />
      </button>
    </li>
  );
}

function DayCard({
  tree,
  day,
  index,
  maxes,
  asker,
}: {
  tree: ProgramTree;
  day: DayTree;
  index: number;
  maxes: Map<string, number>;
  asker: Asker;
}) {
  const { t } = useTranslation();
  const { programs } = useHarvest();
  const [adding, setAdding] = useState(false);
  const [open, setOpen] = useState<string | null>(null);
  const [dragging, setDragging] = useState<number | null>(null);
  const slotUuids = day.slots.map((slot) => slot.row.uuid);
  const dayUuids = tree.days.map((d) => d.row.uuid);

  const moveSlot = (from: number, to: number) => {
    const next = reorderedUuids(slotUuids, from, to);
    if (next.join() !== slotUuids.join()) void programs.reorderSlots(next);
  };

  async function rename() {
    const name = await asker.prompt({ title: t('gym.rename'), body: t('gymWeb.dayNameLead'), label: t('gym.dayName'), placeholder: t('gym.dayNameHint'), initial: day.row.name });
    if (name?.trim()) await programs.updateDay(day.row.uuid, { name });
  }

  async function accessories() {
    const text = await asker.prompt({
      title: t('gym.accessories'),
      label: t('gym.accessories'),
      initial: day.row.accessories ?? '',
      placeholder: t('gym.accessoriesHint'),
      allowEmpty: true,
    });
    if (text !== null) await programs.updateDay(day.row.uuid, { accessories: text });
  }

  async function duplicate() {
    await programs.duplicateDay(day, t('gym.dayCopy', { name: day.row.name }));
  }

  async function remove() {
    const ok = await asker.confirm({
      title: t('gym.deleteDay', { name: day.row.name }),
      body: t('gym.deleteDayBody'),
      action: t('common.delete'),
      destructive: true,
    });
    if (ok) await programs.removeDay(day.row.uuid);
  }

  return (
    <li className="flex flex-col gap-2 rounded-2xl border bg-card p-4">
      <div className="flex items-start gap-2">
        <div className="flex min-w-0 flex-1 flex-col">
          <h3 className="truncate text-lg font-extrabold">{day.row.name}</h3>
          <p className="text-xs text-muted-foreground">
            {t('gym.daySummary', { exercises: t('gym.exerciseCount', { count: day.slots.length }), sets: t('gym.setCount', { count: day.totalSets }) })}
          </p>
        </div>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon-sm" aria-label={t('gym.dayOptions', { name: day.row.name })}>
              <EllipsisVerticalIcon />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuItem onSelect={() => void duplicate()}>{t('gym.duplicateDay')}</DropdownMenuItem>
            <DropdownMenuItem onSelect={() => void accessories()}>{t('gym.accessories')}</DropdownMenuItem>
            <DropdownMenuItem onSelect={() => void rename()}>{t('gym.rename')}</DropdownMenuItem>
            <DropdownMenuItem disabled={index === 0} onSelect={() => void programs.reorderDays(reorderedUuids(dayUuids, index, index - 1))}>
              <ArrowUpIcon />
              {t('gym.moveUp')}
            </DropdownMenuItem>
            <DropdownMenuItem
              disabled={index === tree.days.length - 1}
              onSelect={() => void programs.reorderDays(reorderedUuids(dayUuids, index, index + 1))}
            >
              <ArrowDownIcon />
              {t('gym.moveDown')}
            </DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem onSelect={() => void remove()} className="text-destructive">
              {t('common.delete')}
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
      {day.row.accessories && <p className="text-sm text-muted-foreground">{t('gym.recommended', { what: day.row.accessories })}</p>}
      <ul className="flex flex-col border-t pt-2">
        {day.slots.map((slot, slotIndex) => (
          <SlotRow
            key={slot.row.uuid}
            slot={slot}
            index={slotIndex}
            count={day.slots.length}
            trainingMaxGrams={maxes.get(slot.row.exerciseId)}
            onOpen={() => setOpen(slot.row.uuid)}
            onMove={(to) => moveSlot(slotIndex, to)}
            onDragStart={() => setDragging(slotIndex)}
            onDrop={() => {
              if (dragging !== null) moveSlot(dragging, slotIndex);
              setDragging(null);
            }}
          />
        ))}
      </ul>
      <Button variant="ghost" size="sm" className="self-start" onClick={() => setAdding(true)}>
        <PlusIcon />
        {t('gym.addExercise')}
      </Button>
      {adding && (
        <ExercisePicker
          onClose={() => setAdding(false)}
          onPick={(exercise) => {
            setAdding(false);
            void programs.addSlot(day.row.uuid, exercise.id);
          }}
        />
      )}
      {open && <SlotDialog slotUuid={open} programUuid={tree.program.uuid} onClose={() => setOpen(null)} />}
    </li>
  );
}

// ---------------------------------------------------------- training maxes

function MaxRow({ programUuid, exerciseId, grams }: { programUuid: string; exerciseId: string; grams: number | undefined }) {
  const { t } = useTranslation();
  const { db, programs } = useHarvest();
  const unit = useUnit();
  const load = useLoad();
  const id = useId();
  const exercise = useExercise(db, exerciseId);
  const [text, setText] = useSeededField((shown) => (grams === undefined ? '' : loadField(grams, shown)));
  const typed = parseWeight(text);
  const rounded = typed === null ? null : roundLoad(weightToGrams(unit, typed), unit);
  const roundedAway = rounded !== null && Number(loadFieldValue(rounded, unit)) !== typed;
  // The hint outlives the rounding until the next keystroke, so the
  // dialog does not shift under a click on its way out.
  const [kept, setKept] = useState<number | null>(null);
  const hint = roundedAway ? rounded : kept;
  const save = () => {
    // Leaving the field as it was shown changes nothing: 60 kg read as
    // 132.25 lb is not re-saved as the 59.99 kg those pounds are.
    if (rounded === null || (grams !== undefined && text === loadField(grams, unit))) return;
    if (roundedAway) setKept(rounded);
    // The field shows what was kept, not what was typed — and, no longer
    // typing, it follows the unit again.
    setText(loadFieldValue(rounded, unit), false);
    if (rounded !== grams) void programs.setTrainingMax(programUuid, exerciseId, rounded);
  };
  return (
    <li className="flex flex-wrap items-center gap-3">
      <div className="flex min-w-0 flex-1 flex-col">
        <Label htmlFor={id} className="truncate">
          {exercise?.name ?? t('gym.unknownExercise')}
        </Label>
        <span className={cn('text-xs', grams === undefined ? 'text-destructive' : 'text-muted-foreground')}>
          {grams === undefined ? t('gym.noTrainingMax') : load(grams)}
        </span>
        {hint !== null && (
          <span id={`${id}-rounded`} className="text-xs font-bold text-muted-foreground" aria-live="polite">
            {t('gymWeb.roundsTo', { load: load(hint) })}
          </span>
        )}
      </div>
      <div className="flex items-center gap-2">
        <Input
          id={id}
          inputMode="decimal"
          className="w-24 text-center"
          aria-describedby={hint !== null ? `${id}-rounded` : undefined}
          value={text}
          onChange={(event) => {
            setKept(null);
            setText(event.target.value);
          }}
          onBlur={save}
          onKeyDown={(event) => {
            if (event.key === 'Enter') {
              event.preventDefault();
              save();
            }
          }}
        />
        <span className="text-sm text-muted-foreground">{t(`body.unit.${unit}`)}</span>
      </div>
    </li>
  );
}

/**
 * The numbers a program's percentages are percentages *of*, set and
 * bumped by hand: the app records training, it does not prescribe it.
 */
function TrainingMaxDialog({ tree, maxes, onClose }: { tree: ProgramTree; maxes: Map<string, number>; onClose: () => void }) {
  const { t } = useTranslation();
  const known = useUnitKnown();
  const needed = percentageExercises(tree);
  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>{t('gym.trainingMaxes')}</DialogTitle>
          <DialogDescription>{t('gym.trainingMaxesHint')}</DialogDescription>
        </DialogHeader>
        {needed.length === 0 ? (
          <p className="text-sm text-muted-foreground">{t('gym.noPercentSets')}</p>
        ) : (
          // The rows wait for the unit: a max seeded in kilograms under a pound label is saved as pounds.
          known && <ul className="flex flex-col gap-3">
            {needed.map((exerciseId) => (
              <MaxRow key={exerciseId} programUuid={tree.program.uuid} exerciseId={exerciseId} grams={maxes.get(exerciseId)} />
            ))}
          </ul>
        )}
        <DialogFooter>
          <Button onClick={onClose}>{t('common.close')}</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

// ------------------------------------------------------------------ screen

/**
 * Writing a program (`program_editor.dart`): days, the exercises in
 * them and what each asks. No generator, and never one — the app's job
 * is to make the list fast to fill, which is why a day duplicates in
 * one click.
 */
export function ProgramEditorScreen() {
  const { t } = useTranslation();
  const { uuid = '' } = useParams();
  const navigate = useNavigate();
  const { db, programs } = useHarvest();
  const tree = useLiveQuery(async () => (await readProgram(db, uuid)) ?? null, [db, uuid]);
  const maxes = useLiveQuery(() => readTrainingMaxes(db, uuid), [db, uuid]) ?? new Map<string, number>();
  const [asker, asking] = useAsker();
  const [showMaxes, setShowMaxes] = useState(false);

  if (tree === undefined) return null;
  const back = (
    <Button asChild variant="ghost" size="sm" className="self-start">
      <Link to="/app/body/gym">
        <ArrowLeftIcon className="rtl:rotate-180" />
        {t('gym.backToGym')}
      </Link>
    </Button>
  );
  if (tree === null) {
    return (
      <div className="flex flex-col gap-4">
        {back}
        <EmptyState icon={<GaugeIcon />} title={t('gym.programGone')} />
      </div>
    );
  }

  const needsMax = percentageExercises(tree).filter((id) => !maxes.has(id));

  async function rename() {
    const name = await asker.prompt({ title: t('gym.rename'), label: t('gym.programName'), initial: tree!.program.name });
    if (name?.trim()) await programs.updateProgram(uuid, { name });
  }

  async function remove() {
    const ok = await asker.confirm({
      title: t('gym.deleteProgram', { name: tree!.program.name }),
      body: t('gym.deleteProgramBody'),
      action: t('common.delete'),
      destructive: true,
    });
    if (!ok) return;
    await programs.deleteProgram(uuid);
    void navigate('/app/body/gym');
  }

  async function addDay() {
    const name = await asker.prompt({
      title: t('gym.addDay'),
      label: t('gym.dayName'),
      initial: t('gym.dayNumber', { n: tree!.days.length + 1 }),
      placeholder: t('gym.dayNameHint'),
      action: t('gym.addDay'),
    });
    if (name?.trim()) await programs.addDay(uuid, name);
  }

  return (
    <div className="flex flex-col gap-4">
      {back}
      <div className="flex flex-wrap items-center gap-2">
        <h1 className="min-w-0 flex-1 truncate text-2xl font-extrabold">{tree.program.name}</h1>
        <Button variant="outline" onClick={() => setShowMaxes(true)}>
          <GaugeIcon />
          {t('gym.trainingMaxes')}
        </Button>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon" aria-label={t('gym.programOptions')}>
              <EllipsisVerticalIcon />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuItem onSelect={() => void rename()}>{t('gym.rename')}</DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem onSelect={() => void remove()} className="text-destructive">
              {t('common.delete')}
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
      <SeedCard tree={tree} asker={asker} />
      {/* A percentage with no training max cannot become a weight: said here, not as a blank mid-session. */}
      {needsMax.length > 0 && (
        <button
          type="button"
          onClick={() => setShowMaxes(true)}
          className="flex items-start gap-3 rounded-2xl bg-secondary p-4 text-start text-secondary-foreground outline-none focus-visible:ring-2 focus-visible:ring-ring"
        >
          <CircleHelpIcon className="mt-0.5 size-5 shrink-0" aria-hidden />
          <span className="flex flex-col">
            <span className="font-extrabold">{t('gym.needsTrainingMax', { count: needsMax.length })}</span>
            <span className="text-sm">{t('gym.needsTrainingMaxBody')}</span>
          </span>
        </button>
      )}
      {tree.days.length === 0 ? (
        <EmptyState icon={<GaugeIcon />} title={t('gym.noDays')} body={t('gym.noDaysBody')} />
      ) : (
        <ul className="flex flex-col gap-3">
          {tree.days.map((day, index) => (
            <DayCard key={day.row.uuid} tree={tree} day={day} index={index} maxes={maxes} asker={asker} />
          ))}
        </ul>
      )}
      <Button className="self-start" onClick={() => void addDay()}>
        <PlusIcon />
        {t('gym.addDay')}
      </Button>
      {showMaxes && <TrainingMaxDialog tree={tree} maxes={maxes} onClose={() => setShowMaxes(false)} />}
      {asking}
    </div>
  );
}
