import { useLiveQuery } from 'dexie-react-hooks';
import {
  ArrowDownIcon,
  ArrowLeftIcon,
  ArrowUpIcon,
  EllipsisVerticalIcon,
  PencilIcon,
  PlusIcon,
  RotateCcwIcon,
  SproutIcon,
  Trash2Icon,
  TrophyIcon,
  XCircleIcon,
} from 'lucide-react';
import { useId, useState, type FormEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { Link, useNavigate, useParams } from 'react-router';
import { toast } from 'sonner';
import { Badge } from '@/components/ui/badge';
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
import { Textarea } from '@/components/ui/textarea';
import { formatDay } from '@/lib/format';
import { ProgressRing, StreakChip } from '../components/bits';
import { GoalEditor } from '../components/goal-editor';
import { useHarvest } from '../context';
import { loadGoals, type GoalView } from '../data/goal-views';
import type { GoalItemKind, GoalItemRow } from '../data/goals';
import { useDialogs } from '../dialogs';
import { useDaysLeft } from './goals-board';

function ItemRow({
  item,
  index,
  count,
  view,
  onMove,
}: {
  item: GoalItemRow;
  index: number;
  count: number;
  view: GoalView;
  onMove: (from: number, to: number) => void;
}) {
  const { t } = useTranslation();
  const { goals } = useHarvest();
  const dialogs = useDialogs();
  const [editing, setEditing] = useState(false);
  const [body, setBody] = useState(item.body);
  const [note, setNote] = useState(item.note ?? '');
  const planted = view.seeds.find((seed) => seed.uuid === item.commitmentUuid);
  const checkboxId = useId();

  if (editing) {
    return (
      <li className="rounded-lg bg-muted/60 p-3">
        <form
          className="flex flex-col gap-2"
          onSubmit={(event) => {
            event.preventDefault();
            if (!body.trim()) return;
            void goals.editItem(item.uuid, body, note).then(() => setEditing(false));
          }}
        >
          <Label htmlFor={`${checkboxId}-body`} className="sr-only">
            {t('goals.itemText')}
          </Label>
          <Input id={`${checkboxId}-body`} autoFocus value={body} onChange={(event) => setBody(event.target.value)} />
          <Label htmlFor={`${checkboxId}-note`} className="sr-only">
            {t('goals.itemNote')}
          </Label>
          <Input id={`${checkboxId}-note`} value={note} placeholder={t('goals.itemNote')} onChange={(event) => setNote(event.target.value)} />
          <div className="flex gap-2">
            <Button type="submit" size="sm">
              {t('common.save')}
            </Button>
            <Button size="sm" variant="outline" onClick={() => setEditing(false)}>
              {t('common.cancel')}
            </Button>
          </div>
        </form>
      </li>
    );
  }

  return (
    <li className="flex items-center gap-3 rounded-lg px-2 py-1.5 hover:bg-muted/50">
      <Checkbox
        id={checkboxId}
        checked={item.doneAt !== null}
        onCheckedChange={(checked) => void goals.setDone(item.uuid, checked === true)}
      />
      <label htmlFor={checkboxId} className="flex min-w-0 flex-1 cursor-pointer flex-col">
        <span className={item.doneAt ? 'text-muted-foreground line-through' : 'font-semibold'}>{item.body}</span>
        {item.note && <span className="text-xs text-muted-foreground">{item.note}</span>}
        {item.commitmentUuid && (
          <span className="flex items-center gap-1 text-xs text-muted-foreground">
            <SproutIcon className="size-3" aria-hidden />
            {planted ? (planted.archivedAt ? t('goals.plantedArchived', { title: planted.title }) : planted.title) : t('goals.plantedGone')}
            {planted?.type === 'habit' && <StreakChip count={view.streaks.get(planted.uuid) ?? 0} className="bg-transparent px-0" />}
          </span>
        )}
      </label>
      {!item.commitmentUuid && (
        <Button
          variant="outline"
          size="sm"
          onClick={() =>
            dialogs.plantSeed({ title: item.body, type: 'todo', goalUuid: view.goal.uuid, linkItem: item.uuid })
          }
        >
          <SproutIcon />
          <span className="hidden sm:inline">{t('goals.plant')}</span>
          <span className="sr-only sm:hidden">{t('goals.plantItem', { body: item.body })}</span>
        </Button>
      )}
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" size="icon-sm" aria-label={t('goals.itemOptions', { body: item.body })}>
            <EllipsisVerticalIcon />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem onSelect={() => setEditing(true)}>
            <PencilIcon />
            {t('common.edit')}
          </DropdownMenuItem>
          <DropdownMenuItem disabled={index === 0} onSelect={() => onMove(index, index - 1)}>
            <ArrowUpIcon />
            {t('goals.up')}
          </DropdownMenuItem>
          <DropdownMenuItem disabled={index === count - 1} onSelect={() => onMove(index, index + 1)}>
            <ArrowDownIcon />
            {t('goals.down')}
          </DropdownMenuItem>
          <DropdownMenuSeparator />
          <DropdownMenuItem
            destructive
            onSelect={() => {
              void goals.deleteItem(item.uuid).then(() =>
                toast(t('goals.itemRemoved'), {
                  action: { label: t('common.undo'), onClick: () => void goals.restoreItem(item.uuid) },
                }),
              );
            }}
          >
            <Trash2Icon />
            {t('common.remove')}
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </li>
  );
}

function Section({ view, kind, items }: { view: GoalView; kind: GoalItemKind; items: GoalItemRow[] }) {
  const { t } = useTranslation();
  const { goals } = useHarvest();
  const [text, setText] = useState('');
  const inputId = useId();

  const add = (event: FormEvent) => {
    event.preventDefault();
    if (!text.trim()) return;
    // Emptied at once, so a second Enter before the write lands adds
    // nothing; a write that fails gives the text back.
    const body = text;
    setText('');
    void goals.addItem(view.goal.uuid, body, kind).catch(() => {
      setText(body);
      toast.error(t('common.saveFailed'));
    });
  };
  const move = (from: number, to: number) => {
    const order = items.map((item) => item.uuid);
    const [moved] = order.splice(from, 1);
    order.splice(to, 0, moved!);
    void goals.reorderItems(order);
  };

  return (
    <section aria-labelledby={`${inputId}-heading`} className="flex flex-col gap-2 rounded-xl border bg-card p-4">
      <h2 id={`${inputId}-heading`} className="font-extrabold">
        {kind === 'need' ? t('goals.needs') : t('goals.steps')}
      </h2>
      {items.length > 0 && (
        <ul className="flex flex-col gap-1">
          {items.map((item, index) => (
            <ItemRow key={item.uuid} item={item} index={index} count={items.length} view={view} onMove={move} />
          ))}
        </ul>
      )}
      <form onSubmit={add} className="flex gap-2">
        <Label htmlFor={inputId} className="sr-only">
          {kind === 'need' ? t('goals.addNeed') : t('goals.addStep')}
        </Label>
        <Input
          id={inputId}
          value={text}
          placeholder={kind === 'need' ? t('goals.addNeed') : t('goals.addStep')}
          onChange={(event) => setText(event.target.value)}
        />
        <Button type="submit" variant="outline" size="icon" aria-label={kind === 'need' ? t('goals.addNeed') : t('goals.addStep')}>
          <PlusIcon />
        </Button>
      </form>
    </section>
  );
}

function DropDialog({ uuid, onClose }: { uuid: string; onClose: () => void }) {
  const { t } = useTranslation();
  const { goals } = useHarvest();
  const [note, setNote] = useState('');
  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>{t('goals.dropTitle')}</DialogTitle>
          <DialogDescription>{t('goals.dropBody')}</DialogDescription>
        </DialogHeader>
        <Label htmlFor="drop-note">{t('goals.dropNote')}</Label>
        <Textarea id="drop-note" rows={3} value={note} onChange={(event) => setNote(event.target.value)} />
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            {t('common.cancel')}
          </Button>
          <Button onClick={() => void goals.drop(uuid, note).then(onClose)}>{t('goals.drop')}</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

/** One goal, whole: the why, what it takes, the steps and the seeds ([[Goals]]). */
export function GoalScreen() {
  const { t } = useTranslation();
  const { uuid = '' } = useParams();
  const { db, goals } = useHarvest();
  const navigate = useNavigate();
  const view = useLiveQuery(async () => (await loadGoals(db)).find((v) => v.goal.uuid === uuid) ?? null, [db, uuid]);
  const [editing, setEditing] = useState(false);
  const [dropping, setDropping] = useState(false);
  const daysLeft = useDaysLeft(view?.goal.targetDay ?? null);

  if (view === undefined) return null;
  if (view === null) {
    return (
      <div className="flex flex-col items-start gap-3">
        <p>{t('goals.gone')}</p>
        <Button asChild variant="outline">
          <Link to="/app/field/goals">{t('goals.back')}</Link>
        </Button>
      </div>
    );
  }
  const { goal, progress } = view;

  const remove = () => {
    void goals.delete(goal.uuid).then(() => {
      void navigate('/app/field/goals');
      toast(t('goals.deleted', { title: goal.title }), {
        action: { label: t('common.undo'), onClick: () => void goals.restore(goal.uuid) },
      });
    });
  };

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center gap-2">
        <Button asChild variant="ghost" size="icon" aria-label={t('goals.back')}>
          <Link to="/app/field/goals">
            <ArrowLeftIcon className="rtl:rotate-180" />
          </Link>
        </Button>
        <h1 className="min-w-0 flex-1 truncate text-2xl font-extrabold">{goal.title}</h1>
        {goal.status !== 'active' && <Badge variant="secondary">{t(`goals.status.${goal.status}`)}</Badge>}
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon" aria-label={t('goals.options')}>
              <EllipsisVerticalIcon />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuItem onSelect={() => setEditing(true)}>
              <PencilIcon />
              {t('common.edit')}
            </DropdownMenuItem>
            {goal.status === 'active' ? (
              <>
                <DropdownMenuItem onSelect={() => void goals.achieve(goal.uuid)}>
                  <TrophyIcon />
                  {t('goals.markAchieved')}
                </DropdownMenuItem>
                <DropdownMenuItem onSelect={() => setDropping(true)}>
                  <XCircleIcon />
                  {t('goals.drop')}
                </DropdownMenuItem>
              </>
            ) : (
              <DropdownMenuItem onSelect={() => void goals.reopen(goal.uuid)}>
                <RotateCcwIcon />
                {goal.status === 'achieved' ? t('goals.reopen') : t('goals.pickUp')}
              </DropdownMenuItem>
            )}
            <DropdownMenuSeparator />
            <DropdownMenuItem destructive onSelect={remove}>
              <Trash2Icon />
              {t('common.delete')}
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>

      <section className="flex items-center gap-4 rounded-xl border bg-card p-4">
        {progress && <ProgressRing ratio={progress.ratio} size={64} label={t('goals.progress', { done: progress.done, total: progress.total })} />}
        <div className="flex min-w-0 flex-1 flex-col gap-1">
          {goal.why ? <p className="whitespace-pre-wrap">{goal.why}</p> : <p className="text-muted-foreground">{t('goals.noWhy')}</p>}
          <p className="text-sm text-muted-foreground">
            {[goal.targetDay ? formatDay(goal.targetDay, { dateStyle: 'long' }) : null, daysLeft].filter(Boolean).join(' · ') ||
              t('goals.noTarget')}
          </p>
          {progress && <p className="text-sm font-bold">{t('goals.progress', { done: progress.done, total: progress.total })}</p>}
        </div>
        {goal.status === 'active' && progress?.complete && (
          <Button variant="brand" onClick={() => void goals.achieve(goal.uuid)}>
            <TrophyIcon />
            {t('goals.markAchieved')}
          </Button>
        )}
      </section>
      {goal.status !== 'active' && goal.statusNote && <p className="rounded-lg bg-muted p-3 text-sm">{goal.statusNote}</p>}

      <div className="grid gap-4 lg:grid-cols-2">
        <Section view={view} kind="need" items={view.needs} />
        <Section view={view} kind="step" items={view.steps} />
      </div>

      <section className="flex flex-col gap-2 rounded-xl border bg-card p-4">
        <h2 className="font-extrabold">{t('goals.seeds')}</h2>
        {view.seeds.length === 0 ? (
          <p className="text-sm text-muted-foreground">{t('goals.noSeeds')}</p>
        ) : (
          <ul className="flex flex-col gap-1">
            {view.seeds.map((seed) => (
              <li key={seed.uuid} className="flex items-center gap-2 text-sm">
                <SproutIcon className="size-4 text-success" aria-hidden />
                <span className={seed.archivedAt ? 'text-muted-foreground line-through' : 'font-semibold'}>{seed.title}</span>
                <span className="text-xs text-muted-foreground">{t(`seed.type.${seed.type}`)}</span>
                {seed.type === 'habit' && <StreakChip count={view.streaks.get(seed.uuid) ?? 0} />}
                {seed.archivedAt && <Badge variant="muted">{t('goals.archivedSeed')}</Badge>}
              </li>
            ))}
          </ul>
        )}
      </section>

      {editing && <GoalEditor goal={goal} onClose={() => setEditing(false)} />}
      {dropping && <DropDialog uuid={goal.uuid} onClose={() => setDropping(false)} />}
    </div>
  );
}
