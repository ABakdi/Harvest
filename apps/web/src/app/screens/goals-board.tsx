import { HarvestDay } from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import { ArrowDownIcon, ArrowUpIcon, ChevronDownIcon, PlusIcon, TargetIcon, TrophyIcon } from 'lucide-react';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Link, useNavigate } from 'react-router';
import { Button } from '@/components/ui/button';
import { formatDay } from '@/lib/format';
import { EmptyState, ProgressRing, StreakChip } from '../components/bits';
import { GoalEditor } from '../components/goal-editor';
import { useHarvest, useHarvestDay } from '../context';
import { loadGoals, type GoalView } from '../data/goal-views';

export function useDaysLeft(targetDay: string | null): string | null {
  const { t } = useTranslation();
  const today = useHarvestDay();
  const target = HarvestDay.tryParse(targetDay);
  if (!target) return null;
  const left = today.daysUntil(target);
  if (left === 0) return t('goals.dueToday');
  return left > 0 ? t('goals.daysLeft', { count: left }) : t('goals.daysPast', { count: -left });
}

function GoalCard({ view, index, count, onMove }: { view: GoalView; index: number; count: number; onMove: (from: number, to: number) => void }) {
  const { t } = useTranslation();
  const { goals } = useHarvest();
  const daysLeft = useDaysLeft(view.goal.targetDay);
  const { goal, progress } = view;
  return (
    <li className="flex flex-col gap-3 rounded-xl border bg-card p-4">
      <div className="flex items-start gap-3">
        {progress ? (
          <ProgressRing ratio={progress.ratio} label={t('goals.progress', { done: progress.done, total: progress.total })} />
        ) : (
          <span className="flex size-11 items-center justify-center rounded-full bg-muted" aria-hidden>
            <TargetIcon className="size-5 text-muted-foreground" />
          </span>
        )}
        <div className="flex min-w-0 flex-1 flex-col">
          <Link to={`/app/field/goals/${goal.uuid}`} className="truncate text-lg font-extrabold hover:underline">
            {goal.title}
          </Link>
          <span className="text-xs text-muted-foreground">
            {[goal.targetDay ? formatDay(goal.targetDay, { dateStyle: 'medium' }) : null, daysLeft].filter(Boolean).join(' · ') ||
              t('goals.noTarget')}
          </span>
        </div>
        {goal.status === 'active' && (
          <div className="flex flex-col">
            <Button variant="ghost" size="icon-sm" aria-label={t('goals.moveUp', { title: goal.title })} disabled={index === 0} onClick={() => onMove(index, index - 1)}>
              <ArrowUpIcon />
            </Button>
            <Button variant="ghost" size="icon-sm" aria-label={t('goals.moveDown', { title: goal.title })} disabled={index === count - 1} onClick={() => onMove(index, index + 1)}>
              <ArrowDownIcon />
            </Button>
          </div>
        )}
      </div>
      {!progress && goal.status === 'active' && <p className="text-sm text-muted-foreground">{t('goals.addWhatItTakes')}</p>}
      {view.next && goal.status === 'active' && (
        <p className="text-sm">
          <span className="font-bold text-muted-foreground">{t('goals.next')} </span>
          {view.next.body}
        </p>
      )}
      {view.seeds.length > 0 && (
        <ul className="flex flex-wrap gap-1.5" aria-label={t('goals.seeds')}>
          {view.seeds.map((seed) => (
            <li key={seed.uuid} className="flex items-center gap-1 rounded-full bg-muted px-2 py-0.5 text-xs font-bold">
              <span className={seed.archivedAt ? 'text-muted-foreground line-through' : undefined}>{seed.title}</span>
              {seed.type === 'habit' && <StreakChip count={view.streaks.get(seed.uuid) ?? 0} className="bg-transparent px-0" />}
            </li>
          ))}
        </ul>
      )}
      {goal.status === 'active' && progress?.complete && (
        <Button variant="brand" className="w-fit" onClick={() => void goals.achieve(goal.uuid)}>
          <TrophyIcon />
          {t('goals.markAchieved')}
        </Button>
      )}
      {goal.status !== 'active' && goal.statusNote && <p className="text-sm text-muted-foreground">{goal.statusNote}</p>}
    </li>
  );
}

/** The Goals tab of the field: my order, then the achieved and the dropped, folded. */
export function GoalsBoard() {
  const { t } = useTranslation();
  const { db, goals } = useHarvest();
  const navigate = useNavigate();
  const views = useLiveQuery(() => loadGoals(db), [db]);
  const [creating, setCreating] = useState(false);
  if (!views) return null;

  const active = views.filter((view) => view.goal.status === 'active');
  const achieved = views.filter((view) => view.goal.status === 'achieved');
  const dropped = views.filter((view) => view.goal.status === 'dropped');

  const move = (from: number, to: number) => {
    const order = active.map((view) => view.goal.uuid);
    const [moved] = order.splice(from, 1);
    order.splice(to, 0, moved!);
    void goals.reorder(order);
  };

  const folded = (label: string, list: GoalView[]) =>
    list.length > 0 && (
      <details className="group">
        <summary className="flex cursor-pointer items-center gap-2 py-1 text-sm font-extrabold text-muted-foreground">
          <ChevronDownIcon className="size-4 transition-transform group-open:rotate-180" aria-hidden />
          {label}
        </summary>
        <ul className="mt-2 grid gap-3 md:grid-cols-2">
          {list.map((view, index) => (
            <GoalCard key={view.goal.uuid} view={view} index={index} count={list.length} onMove={() => {}} />
          ))}
        </ul>
      </details>
    );

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between gap-2">
        <h1 className="text-xl font-extrabold">{t('goals.board')}</h1>
        <Button onClick={() => setCreating(true)}>
          <PlusIcon />
          {t('goals.new')}
        </Button>
      </div>
      {active.length === 0 ? (
        <EmptyState icon={<TargetIcon />} title={t('goals.emptyTitle')} body={t('goals.emptyBody')} />
      ) : (
        <ul className="grid gap-3 md:grid-cols-2">
          {active.map((view, index) => (
            <GoalCard key={view.goal.uuid} view={view} index={index} count={active.length} onMove={move} />
          ))}
        </ul>
      )}
      {folded(t('goals.achieved', { count: achieved.length }), achieved)}
      {folded(t('goals.dropped', { count: dropped.length }), dropped)}
      {creating && (
        <GoalEditor goal={null} onClose={() => setCreating(false)} onCreated={(uuid) => void navigate(`/app/field/goals/${uuid}`)} />
      )}
    </div>
  );
}
