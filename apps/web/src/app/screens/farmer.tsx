import { farmerRankForXp, farmerRanks, xpPerRank } from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import { ArchiveRestoreIcon, CoinsIcon, FlameIcon, SnowflakeIcon, TrophyIcon } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { Button } from '@/components/ui/button';
import { formatDate, formatNumber } from '@/lib/format';
import { StreakChip } from '../components/bits';
import { useHarvest, useHarvestDay } from '../context';
import { readStats, type HeatDay, type StatsView } from '../data/stats';

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
            <span className="text-lg font-extrabold tabular">{t('streak.freezes', { count: data.global?.freezesStored ?? 0, max: 2 })}</span>
            <span className="text-xs text-muted-foreground">{t('streak.freezeExplainer')}</span>
          </div>
        </div>
        <div className="flex items-center gap-3 rounded-xl border bg-card p-4">
          <CoinsIcon className="size-6 text-sun" aria-hidden />
          <span className="text-lg font-extrabold tabular">{t('farmer.coinCount', { count: data.coins, formatted: formatNumber(data.coins) })}</span>
        </div>
      </section>
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
  const shade = (actions: number) => {
    if (actions === 0) return 'bg-muted';
    const step = stats.busiest === 0 ? 1 : actions / stats.busiest;
    if (step > 0.66) return 'bg-primary';
    if (step > 0.33) return 'bg-primary/70';
    return 'bg-primary/40';
  };
  return (
    <div className="flex gap-1 overflow-x-auto pb-1" role="img" aria-label={t('stats.heatLabel', { count: stats.heat.length })}>
      {weeks.map((week) => (
        <div key={week[0]!.key} className="flex flex-col gap-1">
          {week.map((day) => (
            <span
              key={day.key}
              title={`${formatDate(day.day.toDate())} · ${t('stats.actions', { count: day.actions })}`}
              className={`size-3 rounded-[3px] ${shade(day.actions)}`}
            />
          ))}
        </div>
      ))}
    </div>
  );
}

/**
 * What the log adds up to: the run of days, the habits' own streaks,
 * and two lifetime numbers. The 3 AM judging happens on the phone, so
 * a streak here is the one the phone last wrote ([[Web]]).
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
      <Heat stats={stats} />
      <p className="text-xs text-muted-foreground tabular">
        {t('stats.lifetime', { checkIns: formatNumber(stats.checkIns), days: formatNumber(stats.activeDays) })}
      </p>
      {stats.seeds.length > 0 && (
        <ul className="flex flex-col divide-y rounded-xl border bg-card">
          {stats.seeds.map((seed) => (
            <li key={seed.uuid} className="flex items-center gap-3 px-4 py-2.5">
              <span className="min-w-0 flex-1 truncate font-bold">{seed.title}</span>
              <StreakChip count={seed.current} />
              <span className="text-xs text-muted-foreground tabular">{t('streak.best', { count: seed.best })}</span>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
