import {
  farmerRankForXp,
  farmerRanks,
  freezeCost,
  globalStreakScope,
  maxFreezesStored,
  streakMilestoneCoins,
  xpPerRank,
} from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import {
  ArchiveRestoreIcon,
  ChevronRightIcon,
  CoinsIcon,
  FlameIcon,
  SnowflakeIcon,
  SparklesIcon,
  TrophyIcon,
} from 'lucide-react';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Link } from 'react-router';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { formatDate, formatNumber } from '@/lib/format';
import { cn } from '@/lib/utils';
import { StreakChip } from '../components/bits';
import { categoryLabel } from '../components/category';
import { useHarvest, useHarvestDay } from '../context';
import type { HarvestDB } from '../data/db';
import { readStats, type HeatDay, type StatsView } from '../data/stats';
import { buyFreeze } from '../data/streaks';

/** The global streak and the coin balance, the two things a freeze is bought with. */
async function readShed(db: HarvestDB) {
  const [global, coins] = await Promise.all([
    db.rows('streaks').get(globalStreakScope),
    db.rows('ledger').where('kind').equals('coin').toArray(),
  ]);
  return {
    current: global?.current ?? 0,
    best: global?.best ?? 0,
    freezes: global?.freezesStored ?? 0,
    coins: coins.reduce((sum, entry) => sum + entry.delta, 0),
  };
}

/**
 * Buying a freeze, as the phone's streak sheet does: a button that is
 * only live with coins enough and room in the shed, and a hint for
 * where coins come from when there are not enough. Spending one on a
 * missed day is the phone's 3 AM judging, never this.
 */
function FreezeShop({ coins, freezes }: { coins: number; freezes: number }) {
  const { t } = useTranslation();
  const { writer } = useHarvest();
  const today = useHarvestDay();
  const [buying, setBuying] = useState(false);
  const canBuy = freezes < maxFreezesStored && coins >= freezeCost && !buying;
  const first = Math.min(...Object.keys(streakMilestoneCoins).map(Number));

  async function buy() {
    setBuying(true);
    try {
      const bought = await buyFreeze(writer, today);
      if (bought) toast.success(t('streak.freezeBought'));
      else toast(t('streak.freezeUnavailable'));
    } finally {
      setBuying(false);
    }
  }

  return (
    <div className="flex flex-col gap-1">
      <Button disabled={!canBuy} onClick={() => void buy()}>
        <SnowflakeIcon />
        {t('streak.buyFreeze', { cost: formatNumber(freezeCost) })}
      </Button>
      {coins < freezeCost && (
        <p className="text-center text-xs text-muted-foreground">
          {t('streak.earnHint', { coins: formatNumber(streakMilestoneCoins[first] ?? 0), days: formatNumber(first) })}
        </p>
      )}
    </div>
  );
}

/** The streak up close: the run, the best, the freezes in the shed, and the shop. */
export function StreakDialog({ onClose }: { onClose: () => void }) {
  const { t } = useTranslation();
  const { db } = useHarvest();
  const shed = useLiveQuery(() => readShed(db), [db]);
  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-sm">
        <DialogHeader>
          <DialogTitle>{t('streak.sheetTitle')}</DialogTitle>
          <DialogDescription className="flex items-center gap-1 font-extrabold text-foreground">
            <CoinsIcon className="size-4 text-sun" aria-hidden />
            {t('farmer.coinCount', { count: shed?.coins ?? 0, formatted: formatNumber(shed?.coins ?? 0) })}
          </DialogDescription>
        </DialogHeader>
        {shed && (
          <div className="flex flex-col gap-4">
            <div className="flex items-center gap-3">
              <FlameIcon className={cn('size-12', shed.current > 0 ? 'text-primary' : 'text-muted-foreground')} aria-hidden />
              <div className="flex flex-col">
                <span className="text-2xl font-extrabold tabular">{t('streak.days', { count: shed.current })}</span>
                <span className="text-sm text-muted-foreground">{t('streak.best', { count: shed.best })}</span>
              </div>
            </div>
            <div className="flex flex-col gap-1">
              <span className="font-extrabold">{t('streak.freezes', { count: shed.freezes, max: maxFreezesStored })}</span>
              <span className="text-xs text-muted-foreground">{t('streak.freezeExplainer')}</span>
            </div>
            <FreezeShop coins={shed.coins} freezes={shed.freezes} />
            <p className="text-xs text-muted-foreground">{t('streak.phoneJudges')}</p>
          </div>
        )}
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            {t('common.close')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

/**
 * The farmer: rank, XP, coins and the streak, all sums over the ledger
 * and the stored streak rows, never a counter kept on the side (W2).
 * The archive lives here too, so a retired seed can come back.
 */
export function FarmerScreen() {
  const { t } = useTranslation();
  const { db, seeds, user } = useHarvest();
  const data = useLiveQuery(async () => {
    const [ledger, global, commitments] = await Promise.all([
      db.rows('ledger').toArray(),
      db.rows('streaks').get('global'),
      db.rows('commitments').toArray(),
    ]);
    let xp = 0;
    let coins = 0;
    for (const entry of ledger) {
      if (entry.kind === 'xp') xp += entry.delta;
      else coins += entry.delta;
    }
    const archived = commitments
      .filter((seed) => seed.deletedAt === null && seed.archivedAt !== null)
      .sort((a, b) => (b.archivedAt ?? '').localeCompare(a.archivedAt ?? ''));
    return { xp, coins, global, archived };
  }, [db]);
  if (!data) return null;

  const rank = farmerRankForXp(data.xp);
  const last = rank === farmerRanks[farmerRanks.length - 1];
  const intoRank = last ? xpPerRank : data.xp % xpPerRank;

  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-2xl font-extrabold">{user.displayName ?? t('nav.farmer')}</h1>
      <section className="flex flex-col gap-3 rounded-2xl border bg-card p-5">
        <div className="flex items-center gap-3">
          <TrophyIcon className="size-8 text-sun" aria-hidden />
          <div className="flex flex-col">
            <span className="text-xl font-extrabold">{t(`farmer.ranks.${rank}`)}</span>
            <span className="text-sm text-muted-foreground tabular">{t('farmer.lifetimeXp', { count: data.xp })}</span>
          </div>
        </div>
        <div
          className="h-3 overflow-hidden rounded-full bg-muted"
          role="progressbar"
          aria-valuemin={0}
          aria-valuemax={xpPerRank}
          aria-valuenow={intoRank}
          aria-label={t('farmer.toNextRank')}
        >
          <div className="bg-harvest-gradient h-full rounded-full" style={{ width: `${(intoRank / xpPerRank) * 100}%` }} />
        </div>
        {!last && (
          <span className="text-xs text-muted-foreground tabular">
            {t('farmer.xpToNext', { count: xpPerRank - intoRank })}
          </span>
        )}
      </section>

      <section className="grid gap-3 sm:grid-cols-3">
        <div className="flex items-center gap-3 rounded-xl border bg-card p-4">
          <FlameIcon className="size-6 text-primary" aria-hidden />
          <div className="flex flex-col">
            <span className="text-lg font-extrabold tabular">{t('streak.days', { count: data.global?.current ?? 0 })}</span>
            <span className="text-xs text-muted-foreground">{t('streak.best', { count: data.global?.best ?? 0 })}</span>
          </div>
        </div>
        <div className="flex items-center gap-3 rounded-xl border bg-card p-4">
          <SnowflakeIcon className="size-6 text-muted-foreground" aria-hidden />
          <div className="flex flex-col">
            <span className="text-lg font-extrabold tabular">
              {t('streak.freezes', { count: data.global?.freezesStored ?? 0, max: maxFreezesStored })}
            </span>
            <span className="text-xs text-muted-foreground">{t('streak.freezeExplainer')}</span>
          </div>
        </div>
        <div className="flex items-center gap-3 rounded-xl border bg-card p-4">
          <CoinsIcon className="size-6 text-sun" aria-hidden />
          <span className="text-lg font-extrabold tabular">{t('farmer.coinCount', { count: data.coins, formatted: formatNumber(data.coins) })}</span>
        </div>
      </section>
      <div className="max-w-sm">
        <FreezeShop coins={data.coins} freezes={data.global?.freezesStored ?? 0} />
      </div>
      <p className="text-xs text-muted-foreground">{t('streak.phoneJudges')}</p>

      <StatsSection />

      <section aria-labelledby="archive-heading" className="flex flex-col gap-2">
        <h2 id="archive-heading" className="text-lg font-extrabold">
          {t('farmer.archive')}
        </h2>
        {data.archived.length === 0 ? (
          <p className="text-sm text-muted-foreground">{t('farmer.archiveEmpty')}</p>
        ) : (
          <ul className="flex flex-col gap-2">
            {data.archived.map((seed) => (
              <li key={seed.uuid} className="flex items-center gap-3 rounded-xl border bg-card p-3">
                <div className="flex min-w-0 flex-1 flex-col">
                  <span className="truncate font-bold">{seed.title}</span>
                  <span className="text-xs text-muted-foreground">
                    {t('farmer.archivedOn', { date: formatDate(seed.archivedAt!) })}
                    {seed.archiveNote ? ` · ${seed.archiveNote}` : ''}
                  </span>
                </div>
                <Button variant="outline" size="sm" onClick={() => void seeds.restore(seed.uuid)}>
                  <ArchiveRestoreIcon />
                  {t('farmer.restore')}
                </Button>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}

/** A square per day, a column per week: the run of the last four months. */
function Heat({ stats }: { stats: StatsView }) {
  const { t } = useTranslation();
  const weeks: HeatDay[][] = [];
  for (let index = 0; index < stats.heat.length; index += 7) {
    weeks.push(stats.heat.slice(index, index + 7));
  }
  // Two things are said at once, so they are said differently, as on
  // the phone: a day of the current streak is simply on; any other
  // day is shaded by how much was done on it.
  const shade = (day: HeatDay) => {
    if (stats.streakDays.has(day.key)) return 'bg-success';
    if (day.actions === 0) return 'bg-muted';
    const step = stats.busiest === 0 ? 1 : day.actions / stats.busiest;
    if (step > 0.66) return 'bg-primary';
    if (step > 0.33) return 'bg-primary/70';
    return 'bg-primary/40';
  };
  return (
    <div className="flex flex-col gap-2">
      <div className="flex gap-1 overflow-x-auto pb-1" role="img" aria-label={t('stats.heatLabel', { count: stats.heat.length })}>
        {weeks.map((week) => (
          <div key={week[0]!.key} className="flex flex-col gap-1">
            {week.map((day) => (
              <span
                key={day.key}
                title={`${formatDate(day.day.toDate())} · ${t('stats.actions', { count: day.actions })}`}
                className={`size-3 rounded-[3px] ${shade(day)}`}
              />
            ))}
          </div>
        ))}
      </div>
      <ul className="flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted-foreground" aria-label={t('stats.legend')}>
        <li className="flex items-center gap-1.5">
          <span className="size-2.5 rounded-[3px] bg-success" aria-hidden />
          {t('stats.legendStreak')}
        </li>
        <li className="flex items-center gap-1.5">
          <span className="size-2.5 rounded-[3px] bg-primary/70" aria-hidden />
          {t('stats.legendActive')}
        </li>
        <li className="flex items-center gap-1.5">
          <span className="size-2.5 rounded-[3px] bg-muted" aria-hidden />
          {t('stats.legendQuiet')}
        </li>
      </ul>
    </div>
  );
}

/** The Weekly Harvest Report: XP, the best and the quietest day, top spending. */
function WeekCard({ stats }: { stats: StatsView }) {
  const { t, i18n } = useTranslation();
  const weekday = (key: string) =>
    new Intl.DateTimeFormat(i18n.language === 'ar' ? 'ar' : 'en', { weekday: 'long', timeZone: 'UTC' }).format(
      new Date(`${key}T00:00:00Z`),
    );
  const { week } = stats;
  return (
    <section aria-labelledby="week-heading" className="flex flex-col gap-2 rounded-xl border bg-card p-4">
      <h3 id="week-heading" className="text-sm font-extrabold text-muted-foreground">
        {t('stats.week')}
      </h3>
      <p className="flex items-center gap-2 text-xl font-extrabold tabular">
        <SparklesIcon className="size-5 text-sun" aria-hidden />
        {t('stats.weekXp', { count: week.xp, formatted: formatNumber(week.xp) })}
      </p>
      <p className="text-sm">{t('stats.bestDay', { day: weekday(week.best.key) })}</p>
      {week.worst && <p className="text-sm">{t('stats.quietestDay', { day: weekday(week.worst.key) })}</p>}
      {week.topCategory && <p className="text-sm">{t('stats.topSpending', { category: categoryLabel(t, week.topCategory) })}</p>}
    </section>
  );
}

/**
 * What the log adds up to: the week, the run of days, the projects'
 * progress, the habits' own streaks, and the lifetime numbers. The
 * 3 AM judging happens on the phone, so a streak here is the one the
 * phone last wrote ([[Web]]).
 */
function StatsSection() {
  const { t } = useTranslation();
  const { db } = useHarvest();
  const today = useHarvestDay();
  const stats = useLiveQuery(() => readStats(db, today), [db, today.key]);
  if (!stats) return null;
  return (
    <section aria-labelledby="stats-heading" className="flex flex-col gap-3">
      <h2 id="stats-heading" className="text-lg font-extrabold">
        {t('stats.title')}
      </h2>
      {stats.checkIns === 0 ? (
        <p className="text-sm text-muted-foreground">{t('stats.empty')}</p>
      ) : (
        <>
          <dl className="grid grid-cols-2 gap-3">
            <div className="flex flex-col rounded-xl border bg-card p-4">
              <dt className="text-xs text-muted-foreground">{t('stats.bestStreak')}</dt>
              <dd className="text-lg font-extrabold tabular">{formatNumber(stats.bestStreak)}</dd>
            </div>
            <div className="flex flex-col rounded-xl border bg-card p-4">
              <dt className="text-xs text-muted-foreground">{t('stats.checkIns')}</dt>
              <dd className="text-lg font-extrabold tabular">{formatNumber(stats.checkIns)}</dd>
            </div>
          </dl>
          <WeekCard stats={stats} />
        </>
      )}
      <p className="text-xs text-muted-foreground">{t('stats.streakSquares', { count: stats.currentStreak })}</p>
      <Heat stats={stats} />
      <p className="text-xs text-muted-foreground tabular">
        {t('stats.lifetime', { checkIns: formatNumber(stats.checkIns), days: formatNumber(stats.activeDays) })}
      </p>
      {stats.projects.length > 0 && (
        <section aria-labelledby="projects-heading" className="flex flex-col gap-2">
          <h3 id="projects-heading" className="text-sm font-extrabold text-muted-foreground">
            {t('stats.projects')}
          </h3>
          <ul className="flex flex-col gap-2">
            {stats.projects.map((project) => (
              <li key={project.uuid}>
                <Link
                  to={`/app/field/seed/${project.uuid}`}
                  className="flex flex-col gap-2 rounded-xl border bg-card p-4 outline-none hover:bg-accent focus-visible:ring-2 focus-visible:ring-ring"
                >
                  <span className="font-bold">{project.title}</span>
                  <span
                    className="h-2.5 overflow-hidden rounded-full bg-muted"
                    role="progressbar"
                    aria-label={project.title}
                    aria-valuemin={0}
                    aria-valuemax={Math.max(project.target, 1)}
                    aria-valuenow={Math.min(project.total, Math.max(project.target, 1))}
                  >
                    <span
                      className="block h-full rounded-full bg-success"
                      style={{ width: `${Math.min(project.total / Math.max(project.target, 1), 1) * 100}%` }}
                    />
                  </span>
                  <span className="text-xs text-muted-foreground tabular">
                    {t('stats.projectOf', { done: formatNumber(project.total), total: formatNumber(project.target) })}
                  </span>
                </Link>
              </li>
            ))}
          </ul>
        </section>
      )}
      {stats.seeds.length > 0 && (
        <section aria-labelledby="habits-heading" className="flex flex-col gap-2">
          <h3 id="habits-heading" className="text-sm font-extrabold text-muted-foreground">
            {t('stats.habitStreaks')}
          </h3>
          <ul className="flex flex-col divide-y rounded-xl border bg-card">
            {stats.seeds.map((seed) => (
              <li key={seed.uuid}>
                <Link
                  to={`/app/field/seed/${seed.uuid}`}
                  className="flex items-center gap-3 px-4 py-2.5 outline-none hover:bg-accent focus-visible:ring-2 focus-visible:ring-ring"
                >
                  <span className="min-w-0 flex-1 truncate font-bold">{seed.title}</span>
                  <StreakChip count={seed.current} />
                  <span className="text-xs text-muted-foreground tabular">{t('streak.best', { count: seed.best })}</span>
                  <ChevronRightIcon className="size-4 text-muted-foreground rtl:rotate-180" aria-hidden />
                </Link>
              </li>
            ))}
          </ul>
        </section>
      )}
    </section>
  );
}
