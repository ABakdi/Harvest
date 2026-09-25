import { HarvestDay, parseScheduleJson, type Schedule } from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import { useId, useState, type FormEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Textarea } from '@/components/ui/textarea';
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group';
import i18n from '@/i18n';
import { useHarvest, useHarvestDay } from '../context';
import type { SeedInput, SeedRow, SeedType } from '../data/seeds';
import { useBusy } from './use-busy';

export interface SeedPrefill {
  title?: string;
  type?: SeedType;
  goalUuid?: string | null;
  /** The goal item this seed is planted from; linked on save. */
  linkItem?: string;
  dueDay?: string | null;
}

type ScheduleKind = Schedule['type'];

/** Monday first, whatever the language: weeks run Monday to Sunday everywhere. */
function weekdayNames(): string[] {
  const format = new Intl.DateTimeFormat(i18n.language, { weekday: 'short' });
  // 2024-01-01 was a Monday.
  return Array.from({ length: 7 }, (_, i) => format.format(new Date(2024, 0, 1 + i)));
}

function positiveInt(text: string): number | null {
  const value = Number(text);
  return Number.isInteger(value) && value >= 1 ? value : null;
}

function scheduleOf(row: SeedRow | null): Schedule | null {
  if (!row?.scheduleJson) return null;
  try {
    return parseScheduleJson(row.scheduleJson);
  } catch {
    return null;
  }
}

/**
 * Plant or edit a seed: a habit with its schedule, a project with its
 * target and daily commitment, or a to-do with its day. The advanced
 * options are the phone's: a note, a reminder time, a deadline, and the
 * goal it serves.
 */
export function SeedEditor({
  state,
  onClose,
}: {
  state: { mode: 'plant'; prefill: SeedPrefill } | { mode: 'edit'; seed: SeedRow };
  onClose: () => void;
}) {
  const { t } = useTranslation();
  const { db, seeds } = useHarvest();
  const today = useHarvestDay();
  const id = useId();
  const editing = state.mode === 'edit' ? state.seed : null;
  const prefill = state.mode === 'plant' ? state.prefill : {};
  const existingSchedule = scheduleOf(editing);

  const [type, setType] = useState<SeedType>(editing?.type ?? prefill.type ?? 'habit');
  const [title, setTitle] = useState(editing?.title ?? prefill.title ?? '');
  const [kind, setKind] = useState<ScheduleKind>(existingSchedule?.type ?? 'daily');
  const [weekdays, setWeekdays] = useState<string[]>(
    existingSchedule?.type === 'weekly' ? [...existingSchedule.weekdays].map(String) : ['1', '2', '3', '4', '5'],
  );
  const [everyDays, setEveryDays] = useState(existingSchedule?.type === 'interval' ? String(existingSchedule.everyDays) : '2');
  const [anchorDay] = useState(existingSchedule?.type === 'interval' ? existingSchedule.anchorDay.key : today.key);
  const [times, setTimes] = useState(existingSchedule?.type === 'timesPerWeek' ? String(existingSchedule.times) : '3');
  const [totalTarget, setTotalTarget] = useState(editing?.totalTarget?.toString() ?? '');
  const [dailyCommitment, setDailyCommitment] = useState(editing?.dailyCommitment?.toString() ?? '');
  const [dueDay, setDueDay] = useState(editing ? (editing.dueDay ?? '') : (prefill.dueDay ?? today.key));
  const [note, setNote] = useState(editing?.note ?? '');
  const [remindAt, setRemindAt] = useState(editing?.remindAt ?? '');
  const [deadline, setDeadline] = useState(editing?.deadline ?? '');
  const [goalUuid, setGoalUuid] = useState<string>(editing?.goalUuid ?? prefill.goalUuid ?? 'none');
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [saving, once] = useBusy();

  const goals = useLiveQuery(
    async () =>
      (await db.rows('goals').toArray())
        .filter((goal) => goal.deletedAt === null && (goal.status === 'active' || goal.uuid === goalUuid))
        .sort((a, b) => a.position - b.position),
    [db, goalUuid],
  );

  function buildSchedule(): Schedule | null {
    switch (kind) {
      case 'daily':
        return { type: 'daily' };
      case 'weekly':
        return weekdays.length ? { type: 'weekly', weekdays: new Set(weekdays.map(Number)) } : null;
      case 'interval': {
        const every = positiveInt(everyDays);
        return every ? { type: 'interval', everyDays: every, anchorDay: HarvestDay.parse(anchorDay) } : null;
      }
      case 'timesPerWeek': {
        const count = positiveInt(times);
        return count && count <= 7 ? { type: 'timesPerWeek', times: count } : null;
      }
    }
  }

  async function submit(event: FormEvent) {
    event.preventDefault();
    const found: Record<string, string> = {};
    if (!title.trim()) found.title = t('form.error.required');
    const schedule = type === 'habit' ? buildSchedule() : null;
    if (type === 'habit' && !schedule) found.schedule = t('seed.error.schedule');
    const total = positiveInt(totalTarget);
    const daily = positiveInt(dailyCommitment);
    if (type === 'project' && !total) found.totalTarget = t('seed.error.positive');
    if (type === 'project' && !daily) found.dailyCommitment = t('seed.error.positive');
    setErrors(found);
    if (Object.keys(found).length > 0) return;

    const input: SeedInput = {
      type,
      title,
      schedule,
      totalTarget: total,
      dailyCommitment: daily,
      dueDay: dueDay || null,
      note: note || null,
      remindAt: remindAt || null,
      deadline: deadline || null,
      goalUuid: goalUuid === 'none' ? null : goalUuid,
    };
    try {
      if (editing) {
        await seeds.edit(editing.uuid, input);
        toast.success(t('seed.saved'));
      } else {
        await seeds.plant(input, prefill.linkItem);
        toast.success(t('seed.planted', { title: title.trim() }));
      }
      onClose();
    } catch {
      toast.error(t('common.saveFailed'));
    }
  }

  const names = weekdayNames();
  const field = (name: string) => `${id}-${name}`;
  const errorFor = (name: string) =>
    errors[name] ? (
      <p id={`${field(name)}-error`} role="alert" className="text-sm font-semibold text-destructive">
        {errors[name]}
      </p>
    ) : null;

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-xl">
        <DialogHeader>
          <DialogTitle>{editing ? t('seed.editTitle') : t('seed.plant')}</DialogTitle>
          <DialogDescription>{t('seed.editorLead')}</DialogDescription>
        </DialogHeader>
        <form onSubmit={(event) => void once(() => submit(event))} className="flex flex-col gap-4" noValidate>
          <div className="flex flex-col gap-2">
            <Label id={field('type')}>{t('seed.typeLabel')}</Label>
            <ToggleGroup
              type="single"
              value={type}
              aria-labelledby={field('type')}
              onValueChange={(value) => value && setType(value as SeedType)}
              disabled={editing !== null}
            >
              <ToggleGroupItem value="habit">{t('seed.type.habit')}</ToggleGroupItem>
              <ToggleGroupItem value="project">{t('seed.type.project')}</ToggleGroupItem>
              <ToggleGroupItem value="todo">{t('seed.type.todo')}</ToggleGroupItem>
            </ToggleGroup>
          </div>

          <div className="flex flex-col gap-2">
            <Label htmlFor={field('title')}>{t('seed.title')}</Label>
            <Input
              id={field('title')}
              value={title}
              autoFocus
              maxLength={200}
              placeholder={t(`seed.titleHint.${type}`)}
              aria-invalid={errors.title ? true : undefined}
              aria-describedby={errors.title ? `${field('title')}-error` : undefined}
              onChange={(event) => setTitle(event.target.value)}
            />
            {errorFor('title')}
          </div>

          {type === 'habit' && (
            <fieldset className="flex flex-col gap-3">
              <legend className="mb-2 text-sm font-bold">{t('seed.schedule')}</legend>
              <ToggleGroup type="single" value={kind} onValueChange={(value) => value && setKind(value as ScheduleKind)} aria-label={t('seed.schedule')}>
                <ToggleGroupItem value="daily">{t('seed.scheduleKind.daily')}</ToggleGroupItem>
                <ToggleGroupItem value="weekly">{t('seed.scheduleKind.weekly')}</ToggleGroupItem>
                <ToggleGroupItem value="interval">{t('seed.scheduleKind.interval')}</ToggleGroupItem>
                <ToggleGroupItem value="timesPerWeek">{t('seed.scheduleKind.timesPerWeek')}</ToggleGroupItem>
              </ToggleGroup>
              {kind === 'weekly' && (
                <ToggleGroup type="multiple" value={weekdays} onValueChange={setWeekdays} aria-label={t('seed.weekdays')}>
                  {names.map((name, index) => (
                    <ToggleGroupItem key={name} value={String(index + 1)} className="min-w-11">
                      {name}
                    </ToggleGroupItem>
                  ))}
                </ToggleGroup>
              )}
              {kind === 'interval' && (
                <div className="flex items-center gap-2">
                  <Label htmlFor={field('every')}>{t('seed.everyLabel')}</Label>
                  <Input id={field('every')} type="number" min={1} inputMode="numeric" className="w-24" value={everyDays} onChange={(event) => setEveryDays(event.target.value)} />
                  <span className="text-sm text-muted-foreground">{t('seed.days')}</span>
                </div>
              )}
              {kind === 'timesPerWeek' && (
                <div className="flex items-center gap-2">
                  <Label htmlFor={field('times')}>{t('seed.timesLabel')}</Label>
                  <Input id={field('times')} type="number" min={1} max={7} inputMode="numeric" className="w-24" value={times} onChange={(event) => setTimes(event.target.value)} />
                  <span className="text-sm text-muted-foreground">{t('seed.perWeek')}</span>
                </div>
              )}
              {errorFor('schedule')}
            </fieldset>
          )}

          {type === 'project' && (
            <div className="grid gap-3 sm:grid-cols-2">
              <div className="flex flex-col gap-2">
                <Label htmlFor={field('total')}>{t('seed.totalTarget')}</Label>
                <Input id={field('total')} type="number" min={1} inputMode="numeric" value={totalTarget} aria-invalid={errors.totalTarget ? true : undefined} onChange={(event) => setTotalTarget(event.target.value)} />
                {errorFor('totalTarget')}
              </div>
              <div className="flex flex-col gap-2">
                <Label htmlFor={field('daily')}>{t('seed.dailyCommitment')}</Label>
                <Input id={field('daily')} type="number" min={1} inputMode="numeric" value={dailyCommitment} aria-invalid={errors.dailyCommitment ? true : undefined} onChange={(event) => setDailyCommitment(event.target.value)} />
                {errorFor('dailyCommitment')}
              </div>
            </div>
          )}

          {type === 'todo' && (
            <div className="flex flex-col gap-2">
              <Label htmlFor={field('due')}>{t('seed.plannedFor')}</Label>
              <Input id={field('due')} type="date" value={dueDay} onChange={(event) => setDueDay(event.target.value)} className="w-full sm:w-56" />
            </div>
          )}

          <details className="rounded-lg bg-muted/60 p-3" open={Boolean(editing?.note || editing?.remindAt || editing?.deadline || prefill.goalUuid)}>
            <summary className="cursor-pointer text-sm font-extrabold">{t('seed.advanced')}</summary>
            <div className="mt-3 flex flex-col gap-3">
              <div className="flex flex-col gap-2">
                <Label htmlFor={field('note')}>{t('seed.note')}</Label>
                <Textarea id={field('note')} value={note} rows={2} onChange={(event) => setNote(event.target.value)} />
              </div>
              <div className="grid gap-3 sm:grid-cols-2">
                <div className="flex flex-col gap-2">
                  <Label htmlFor={field('remind')}>{t('seed.remindAt')}</Label>
                  <Input id={field('remind')} type="time" value={remindAt} onChange={(event) => setRemindAt(event.target.value)} />
                </div>
                {type !== 'habit' && (
                  <div className="flex flex-col gap-2">
                    <Label htmlFor={field('deadline')}>{t('seed.deadline')}</Label>
                    <Input id={field('deadline')} type="date" value={deadline} onChange={(event) => setDeadline(event.target.value)} />
                  </div>
                )}
              </div>
              <div className="flex flex-col gap-2">
                <Label htmlFor={field('goal')}>{t('seed.serves')}</Label>
                <Select value={goalUuid} onValueChange={setGoalUuid}>
                  <SelectTrigger id={field('goal')}>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="none">{t('seed.servesNone')}</SelectItem>
                    {goals?.map((goal) => (
                      <SelectItem key={goal.uuid} value={goal.uuid}>
                        {goal.title}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>
          </details>

          <DialogFooter>
            <Button variant="outline" onClick={onClose}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" disabled={saving}>
              {editing ? t('common.save') : t('seed.plant')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
