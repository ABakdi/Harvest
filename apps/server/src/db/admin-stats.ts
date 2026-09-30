import { streakBandOf, streakBands, type AdminOverview, type DailyStats } from '@harvest/contracts';
import type { Collection } from 'mongodb';
import type { DailyStatsDoc, StoredUserDoc } from './types.js';

const dayMs = 24 * 60 * 60_000;

/** The UTC day of [at], `yyyy-MM-dd`. */
export function utcDay(at: Date): string {
  return at.toISOString().slice(0, 10);
}

/** Midnight UTC at the start of [at]'s day. */
export function startOfUtcDay(at: Date): Date {
  return new Date(`${utcDay(at)}T00:00:00.000Z`);
}

function median(values: readonly number[]): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 1 ? sorted[middle]! : (sorted[middle - 1]! + sorted[middle]!) / 2;
}

function mean(values: readonly number[]): number {
  if (values.length === 0) return 0;
  return Math.round((values.reduce((sum, value) => sum + value, 0) / values.length) * 10) / 10;
}

/**
 * The admin's numbers ([[Admin]]): counts over the accounts' own fields
 * and their latest heartbeat, and one row of totals a day. Nothing here
 * reads a row of anyone's data (AD1), and nothing keeps a history per
 * account (AD4).
 */
export class AdminStatsRepository {
  constructor(
    private readonly users: Collection<StoredUserDoc>,
    private readonly days: Collection<DailyStatsDoc>,
  ) {}

  /** The first heartbeat of an account on [at]'s day: counted once. */
  async countActive(at: Date): Promise<void> {
    await this.days.updateOne({ _id: utcDay(at) }, { $inc: { active: 1 } }, { upsert: true });
  }

  /** The current streaks the accounts share (AD3). */
  private async sharedStreaks(): Promise<number[]> {
    const docs = await this.users
      .find({ 'streak.current': { $type: 'number' } }, { projection: { 'streak.current': 1 } })
      .toArray();
    return docs.map((doc) => doc.streak!.current);
  }

  /** Everything the overview shows but the downloads, which come from GitHub. */
  async overview(now: Date): Promise<Omit<AdminOverview, 'downloads' | 'generatedAt'>> {
    const today = startOfUtcDay(now);
    const since = (days: number) => new Date(now.getTime() - days * dayMs);
    const count = (filter: object) => this.users.countDocuments(filter);
    const [total, verified, newToday, newWeek, newMonth, activeToday, activeWeek, activeMonth, streaks, platforms, versions] =
      await Promise.all([
        count({}),
        count({ verifiedAt: { $ne: null } }),
        count({ createdAt: { $gte: today } }),
        count({ createdAt: { $gte: since(7) } }),
        count({ createdAt: { $gte: since(30) } }),
        count({ lastActiveAt: { $gte: today } }),
        count({ lastActiveAt: { $gte: since(7) } }),
        count({ lastActiveAt: { $gte: since(30) } }),
        this.sharedStreaks(),
        this.users
          .aggregate<{ _id: string; n: number }>([
            { $match: { lastPlatform: { $type: 'string' } } },
            { $group: { _id: '$lastPlatform', n: { $sum: 1 } } },
            { $sort: { n: -1 } },
          ])
          .toArray(),
        this.users
          .aggregate<{ _id: string; n: number }>([
            { $match: { lastAppVersion: { $type: 'string' } } },
            { $group: { _id: '$lastAppVersion', n: { $sum: 1 } } },
            { $sort: { n: -1 } },
            { $limit: 20 },
          ])
          .toArray(),
      ]);
    const bands = new Map<string, number>(streakBands.map((band) => [band, 0]));
    for (const days of streaks) bands.set(streakBandOf(days), (bands.get(streakBandOf(days)) ?? 0) + 1);
    return {
      accounts: { total, verified, newToday, newWeek, newMonth },
      active: { today: activeToday, week: activeWeek, month: activeMonth },
      streaks: {
        sharing: streaks.length,
        median: median(streaks),
        mean: mean(streaks),
        longest: streaks.length === 0 ? 0 : Math.max(...streaks),
        bands: streakBands.map((band) => ({ band, accounts: bands.get(band) ?? 0 })),
      },
      platforms: platforms.map(({ _id, n }) => ({ platform: _id, accounts: n })),
      versions: versions.map(({ _id, n }) => ({ version: _id, accounts: n })),
    };
  }

  /**
   * Writes [now]'s day of totals, all but `active`, which the heartbeats
   * count as they come. Run every hour: the row of a day is final once
   * the day is over and the last run of it has been.
   */
  async snapshot(now: Date): Promise<void> {
    const today = startOfUtcDay(now);
    const since = (days: number) => new Date(now.getTime() - days * dayMs);
    const [accounts, verified, signups, active7, active30, streaks] = await Promise.all([
      this.users.countDocuments({}),
      this.users.countDocuments({ verifiedAt: { $ne: null } }),
      this.users.countDocuments({ createdAt: { $gte: today } }),
      this.users.countDocuments({ lastActiveAt: { $gte: since(7) } }),
      this.users.countDocuments({ lastActiveAt: { $gte: since(30) } }),
      this.sharedStreaks(),
    ]);
    await this.days.updateOne(
      { _id: utcDay(now) },
      {
        $set: {
          accounts,
          verified,
          signups,
          active7,
          active30,
          sharing: streaks.length,
          streakMedian: median(streaks),
          streakMean: mean(streaks),
        },
        $setOnInsert: { active: 0 },
      },
      { upsert: true },
    );
  }

  /**
   * The days of totals within the last [days], oldest first. A day with
   * no row — before the counting began, or while the server was down —
   * is left out rather than read as zeros, which would draw a drop that
   * never happened.
   */
  async history(days: number, now: Date): Promise<DailyStats[]> {
    const first = utcDay(new Date(startOfUtcDay(now).getTime() - (days - 1) * dayMs));
    const rows = await this.days.find({ _id: { $gte: first } }).sort({ _id: 1 }).toArray();
    return rows.map((row) => ({
      day: row._id,
      accounts: row.accounts ?? 0,
      verified: row.verified ?? 0,
      signups: row.signups ?? 0,
      active: row.active ?? 0,
      active7: row.active7 ?? 0,
      active30: row.active30 ?? 0,
      sharing: row.sharing ?? 0,
      streakMedian: row.streakMedian ?? 0,
      streakMean: row.streakMean ?? 0,
    }));
  }
}
