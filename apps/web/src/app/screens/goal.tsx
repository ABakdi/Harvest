import { useLiveQuery } from 'dexie-react-hooks';
import {
  ArrowDownIcon,
  ArrowLeftIcon,
  ArrowUpIcon,
  CornerDownRightIcon,
  CornerUpLeftIcon,
  EllipsisVerticalIcon,
  ListPlusIcon,
  PencilIcon,
  PlusIcon,
  RotateCcwIcon,
  SproutIcon,
  Trash2Icon,
  TrophyIcon,
  XCircleIcon,
} from 'lucide-react';
import { useEffect, useId, useRef, useState, type FormEvent, type KeyboardEvent, type ReactNode } from 'react';
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
import { isItemDone, loadGoals, type GoalView } from '../data/goal-views';
import type { GoalItemKind, GoalItemRow } from '../data/goals';
import { useDialogs } from '../dialogs';
import { useDaysLeft } from './goals-board';

/** Moves one uuid of [order] from [from] to [to]. */
function moved(order: string[], from: number, to: number): string[] {
  const next = [...order];
  const [uuid] = next.splice(from, 1);
  next.splice(to, 0, uuid!);
  return next;
}

interface RowProps {
  item: GoalItemRow;
  index: number;
  count: number;
  view: GoalView;
  onMove: (from: number, to: number) => void;
  /** Hands the tick box to the section, so a moved row keeps the keyboard. */
  tickRef: (node: HTMLButtonElement | null) => void;
  onAddSubtask?: () => void;
  onMoveUnder?: () => void;
  /** Drawn under a task; offers to be lifted to one of its own. */
  isSubtask?: boolean;
  children?: ReactNode;
}

/**
 * One item, or one subtask ([[Goals]] GL8). A parent's tick is drawn
 * from its subtasks and shows how many are done; ticking it ticks them
 * all. Alt+↑/↓ on the tick box moves it within its section or its task.
 */
function ItemRow({ item, index, count, view, onMove, tickRef, onAddSubtask, onMoveUnder, isSubtask = false, children }: RowProps) {
  const { t } = useTranslation();
  const { goals } = useHarvest();
  const dialogs = useDialogs();
  const [editing, setEditing] = useState(false);
  const [body, setBody] = useState(item.body);
  const [note, setNote] = useState(item.note ?? '');
  const planted = view.seeds.find((seed) => seed.uuid === item.commitmentUuid);
  const checkboxId = useId();
  const subtasks = view.subtasks.get(item.uuid) ?? [];
  const done = isItemDone(view, item);
  const doneCount = subtasks.filter((subtask) => subtask.doneAt !== null).length;
  // An entry that opens a field hands it the focus, which the menu would
  // otherwise take back to its button as it closes.
  const handOff = useRef(false);

  const keys = (event: KeyboardEvent<HTMLButtonElement>) => {
    if (!event.altKey) return;
    if (event.key === 'ArrowUp' && index > 0) {
      event.preventDefault();
      onMove(index, index - 1);
    } else if (event.key === 'ArrowDown' && index < count - 1) {
      event.preventDefault();
      onMove(index, index + 1);
    }
  };

  const remove = () => {
    const taken = subtasks.length;
    void goals.deleteItem(item.uuid).then(() =>
      toast(taken > 0 ? t('goals.itemRemovedWithSubtasks', { count: taken }) : t('goals.itemRemoved'), {
        action: { label: t('common.undo'), onClick: () => void goals.restoreItem(item.uuid) },
      }),
    );
  };

  const line = editing ? (
    <div className="rounded-lg bg-muted/60 p-3">
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
    </div>
  ) : (
    <div className="flex items-center gap-3 rounded-lg px-2 py-1.5 hover:bg-muted/50">
      <Checkbox
        ref={tickRef}
        id={checkboxId}
        checked={done}
        onCheckedChange={(checked) => void goals.setDone(item.uuid, checked === true)}
        onKeyDown={keys}
        aria-keyshortcuts="Alt+ArrowUp Alt+ArrowDown"
      />
      <label htmlFor={checkboxId} className="flex min-w-0 flex-1 cursor-pointer flex-col">
        <span className={done ? 'text-muted-foreground line-through' : isSubtask ? 'font-medium' : 'font-semibold'}>{item.body}</span>
        {item.note && <span className="text-xs text-muted-foreground">{item.note}</span>}
        {item.commitmentUuid && (
          <span className="flex items-center gap-1 text-xs text-muted-foreground">
            <SproutIcon className="size-3" aria-hidden />
            {planted ? (planted.archivedAt ? t('goals.plantedArchived', { title: planted.title }) : planted.title) : t('goals.plantedGone')}
            {planted?.type === 'habit' && <StreakChip count={view.streaks.get(planted.uuid) ?? 0} className="bg-transparent px-0" />}
          </span>
        )}
      </label>
      {subtasks.length > 0 && (
        <span
          className="shrink-0 rounded-full bg-muted px-2 py-0.5 text-xs font-bold tabular-nums text-muted-foreground"
          aria-label={t('goals.subtaskCountLabel', { done: doneCount, total: subtasks.length })}
        >
          {t('goals.subtaskCount', { done: doneCount, total: subtasks.length })}
        </span>
      )}
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
        <DropdownMenuContent
          align="end"
          onCloseAutoFocus={(event) => {
            if (!handOff.current) return;
            handOff.current = false;
            event.preventDefault();
          }}
        >
          <DropdownMenuItem
            onSelect={() => {
              handOff.current = true;
              setEditing(true);
            }}
          >
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
          {onAddSubtask && (
            <DropdownMenuItem
              onSelect={() => {
                handOff.current = true;
                onAddSubtask();
              }}
            >
              <ListPlusIcon />
              {t('goals.addSubtask')}
            </DropdownMenuItem>
          )}
          {onMoveUnder && subtasks.length === 0 && (
            <DropdownMenuItem onSelect={onMoveUnder}>
              <CornerDownRightIcon className="rtl:-scale-x-100" />
              {t('goals.moveUnder')}
            </DropdownMenuItem>
          )}
          {isSubtask && (
            <DropdownMenuItem onSelect={() => void goals.liftItem(item.uuid)}>
              <CornerUpLeftIcon className="rtl:-scale-x-100" />
              {item.kind === 'need' ? t('goals.liftNeed') : t('goals.liftTask')}
            </DropdownMenuItem>
          )}
          <DropdownMenuSeparator />
          <DropdownMenuItem destructive onSelect={remove}>
            <Trash2Icon />
            {t('common.remove')}
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  );

  return (
    <li className="flex flex-col gap-1">
      {line}
      {children}
    </li>
  );
}

/** The inline line that adds subtasks to [parent], one after another. */
function SubtaskAdder({ parent, onClose }: { parent: GoalItemRow; onClose: () => void }) {
  const { t } = useTranslation();
  const { goals } = useHarvest();
  const [text, setText] = useState('');
  const inputId = useId();
  const add = (event: FormEvent) => {
    event.preventDefault();
    // Enter on an empty line is done adding.
    if (!text.trim()) {
      onClose();
      return;
    }
    const body = text;
    setText('');
    void goals.addSubtask(parent.uuid, body).catch(() => {
      setText(body);
      toast.error(t('common.saveFailed'));
    });
  };
  return (
    <form onSubmit={add} className="flex gap-2 ps-2">
      <Label htmlFor={inputId} className="sr-only">
        {t('goals.addSubtaskTo', { body: parent.body })}
      </Label>
      <Input
        id={inputId}
        autoFocus
        value={text}
        placeholder={t('goals.addSubtask')}
        onChange={(event) => setText(event.target.value)}
        onKeyDown={(event) => {
          if (event.key === 'Escape') {
            event.preventDefault();
            onClose();
          }
        }}
      />
      <Button type="submit" variant="outline" size="icon" aria-label={t('goals.addSubtaskTo', { body: parent.body })}>
        <PlusIcon />
      </Button>
    </form>
  );
}

/** Picks the item a subtask-less item moves under (GL8). */
function MoveUnderDialog({ item, view, onClose }: { item: GoalItemRow; view: GoalView; onClose: () => void }) {
  const { t } = useTranslation();
  const { goals } = useHarvest();
  const targets = [...view.needs, ...view.steps].filter((other) => other.uuid !== item.uuid);
  const pick = (parent: GoalItemRow) =>
    void goals.nestItem(item.uuid, parent.uuid).then((ok) => {
      onClose();
      if (ok) toast(t('goals.movedUnder', { body: parent.body }));
    });
  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>{t('goals.moveUnderTitle', { body: item.body })}</DialogTitle>
          <DialogDescription>{t('goals.moveUnderBody')}</DialogDescription>
        </DialogHeader>
        {targets.length === 0 ? (
          <p className="text-sm text-muted-foreground">{t('goals.moveUnderNone')}</p>
        ) : (
          <ul className="flex max-h-80 flex-col gap-1 overflow-y-auto">
            {targets.map((target) => (
              <li key={target.uuid}>
                <Button variant="ghost" className="h-auto w-full justify-start whitespace-normal text-start" onClick={() => pick(target)}>
                  <span className="flex flex-col">
                    <span>{target.body}</span>
                    <span className="text-xs text-muted-foreground">{target.kind === 'need' ? t('goals.requirements') : t('goals.tasks')}</span>
                  </span>
                </Button>
              </li>
            ))}
          </ul>
        )}
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            {t('common.cancel')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function Section({ view, kind, items }: { view: GoalView; kind: GoalItemKind; items: GoalItemRow[] }) {
  const { t } = useTranslation();
  const { goals } = useHarvest();
  const [text, setText] = useState('');
  const [adding, setAdding] = useState<string | null>(null);
  const [moving, setMoving] = useState<GoalItemRow | null>(null);
  const focus = useRef<string | null>(null);
  const ticks = useRef(new Map<string, HTMLButtonElement>());
  const inputId = useId();
  const addLabel = kind === 'need' ? t('goals.addRequirement') : t('goals.addTask');

  // Keeps the keyboard on the row that just moved, once the new order
  // lands, and only then, so it never pulls focus from anywhere else.
  const order = items.flatMap((item) => [item.uuid, ...(view.subtasks.get(item.uuid) ?? []).map((sub) => sub.uuid)]).join();
  useEffect(() => {
    if (focus.current === null) return;
    ticks.current.get(focus.current)?.focus();
    focus.current = null;
  }, [order]);

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
  const reorder = (list: GoalItemRow[]) => (from: number, to: number) => {
    const order = moved(
      list.map((item) => item.uuid),
      from,
      to,
    );
    focus.current = list[from]!.uuid;
    void goals.reorderItems(order);
  };
  const tickRef = (uuid: string) => (node: HTMLButtonElement | null) => {
    if (node) ticks.current.set(uuid, node);
    else ticks.current.delete(uuid);
  };

  return (
    <section aria-labelledby={`${inputId}-heading`} className="flex flex-col gap-2 rounded-xl border bg-card p-4">
      <h2 id={`${inputId}-heading`} className="font-extrabold">
        {kind === 'need' ? t('goals.requirements') : t('goals.tasks')}
      </h2>
      {items.length > 0 && (
        <ul className="flex flex-col gap-1">
          {items.map((item, index) => {
            const subtasks = view.subtasks.get(item.uuid) ?? [];
            return (
              <ItemRow
                key={item.uuid}
                item={item}
                index={index}
                count={items.length}
                view={view}
                onMove={reorder(items)}
                tickRef={tickRef(item.uuid)}
                onAddSubtask={() => setAdding(item.uuid)}
                onMoveUnder={() => setMoving(item)}
              >
                {(subtasks.length > 0 || adding === item.uuid) && (
                  <div className="ms-8 flex flex-col gap-1 border-s ps-2">
                    {subtasks.length > 0 && (
                      <ul className="flex flex-col gap-1" aria-label={t('goals.subtasksOf', { body: item.body })}>
                        {subtasks.map((subtask, at) => (
                          <ItemRow
                            key={subtask.uuid}
                            item={subtask}
                            index={at}
                            count={subtasks.length}
                            view={view}
                            onMove={reorder(subtasks)}
                            tickRef={tickRef(subtask.uuid)}
                            isSubtask
                          />
                        ))}
                      </ul>
                    )}
                    {adding === item.uuid ? (
                      <SubtaskAdder parent={item} onClose={() => setAdding(null)} />
                    ) : (
                      <Button variant="ghost" size="sm" className="w-fit text-muted-foreground" onClick={() => setAdding(item.uuid)}>
                        <PlusIcon />
                        {t('goals.addSubtask')}
                        <span className="sr-only">{` — ${item.body}`}</span>
                      </Button>
                    )}
                  </div>
                )}
              </ItemRow>
            );
          })}
        </ul>
      )}
      <form onSubmit={add} className="flex gap-2">
        <Label htmlFor={inputId} className="sr-only">
          {addLabel}
        </Label>
        <Input id={inputId} value={text} placeholder={addLabel} onChange={(event) => setText(event.target.value)} />
        <Button type="submit" variant="outline" size="icon" aria-label={addLabel}>
          <PlusIcon />
        </Button>
      </form>
      {moving && <MoveUnderDialog item={moving} view={view} onClose={() => setMoving(null)} />}
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

/** One goal, whole: the why, its requirements, its tasks and subtasks, and the seeds ([[Goals]]). */
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
