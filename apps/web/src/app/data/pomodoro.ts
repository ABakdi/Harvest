import { HarvestDay, Xp } from '@harvest/core';
import type { HarvestDB, Row } from './db';
import { settingText } from './settings';
import type { Tx, Writer } from './writer';

export type PomodoroSessionRow = Row<'pomodoro_sessions'>;
export type PomodoroPhase = 'focus' | 'shortBreak' | 'longBreak';

/**
 * The timer lengths, under the phone's own keys (`PomodoroKeys`), so a
 * length set on either device is the length on both. `active` is the
 * running timer, which is this device's own and never syncs.
 */
export const pomodoroKeys = {
  focus: 'pomodoro.focusMinutes',
  shortBreak: 'pomodoro.shortBreakMinutes',
  longBreak: 'pomodoro.longBreakMinutes',
  blocksPerLong: 'pomodoro.blocksPerLongBreak',
  active: 'pomodoro.active',
} as const;

export interface PomodoroConfig {
  focusMinutes: number;
  shortBreakMinutes: number;
  longBreakMinutes: number;
  blocksPerLongBreak: number;
}

export const defaultPomodoroConfig: PomodoroConfig = {
  focusMinutes: 25,
  shortBreakMinutes: 5,
  longBreakMinutes: 15,
  blocksPerLongBreak: 4,
};

/** Dart's `int.tryParse`, with the phone's fallback when it says no. */
function parseMinutes(raw: string | null, fallback: number): number {
  if (raw === null || !/^[+-]?\d+$/.test(raw.trim())) return fallback;
  return Number.parseInt(raw, 10);
}

export async function readPomodoroConfig(db: HarvestDB): Promise<PomodoroConfig> {
  const rows = await db
    .rows('kv_settings')
    .bulkGet([pomodoroKeys.focus, pomodoroKeys.shortBreak, pomodoroKeys.longBreak, pomodoroKeys.blocksPerLong]);
  const [focus, short, long, perLong] = rows.map((row) => settingText(row?.valueJson));
  return {
    focusMinutes: parseMinutes(focus ?? null, defaultPomodoroConfig.focusMinutes),
    shortBreakMinutes: parseMinutes(short ?? null, defaultPomodoroConfig.shortBreakMinutes),
    longBreakMinutes: parseMinutes(long ?? null, defaultPomodoroConfig.longBreakMinutes),
    blocksPerLongBreak: parseMinutes(perLong ?? null, defaultPomodoroConfig.blocksPerLongBreak),
  };
}

/** A phase's length in milliseconds. */
export function phaseMs(config: PomodoroConfig, phase: PomodoroPhase): number {
  const minutes =
    phase === 'focus' ? config.focusMinutes : phase === 'shortBreak' ? config.shortBreakMinutes : config.longBreakMinutes;
  return minutes * 60_000;
}

/**
 * The timer, as the phone persists it (`PomodoroSnapshot`): time is
 * wall-clock instants, never a ticking counter, so a closed tab cannot
 * corrupt a session. Exactly one of [endsAt] (running) and
 * [pausedRemaining] (seconds left, waiting) is set.
 */
export interface PomodoroSnapshot {
  sessionUuid: string;
  phase: PomodoroPhase;
  blocksDone: number;
  commitmentUuid: string | null;
  endsAt: string | null;
  pausedRemaining: number | null;
  /** The farmer pressed pause, as opposed to a break running out. */
  userPaused: boolean;
}

export function isRunning(snapshot: PomodoroSnapshot): boolean {
  return snapshot.endsAt !== null;
}

/** Milliseconds left on the clock at [now]; negative once a running phase is over. */
export function remainingMs(snapshot: PomodoroSnapshot, now: Date): number {
  return snapshot.endsAt !== null ? Date.parse(snapshot.endsAt) - now.getTime() : (snapshot.pausedRemaining ?? 0) * 1000;
}

function parseSnapshot(valueJson: string | undefined): PomodoroSnapshot | null {
  if (!valueJson) return null;
  try {
    const value = JSON.parse(valueJson) as Partial<PomodoroSnapshot> | null;
    if (!value || typeof value.sessionUuid !== 'string') return null;
    const phase = value.phase === 'shortBreak' || value.phase === 'longBreak' ? value.phase : 'focus';
    const endsAt = typeof value.endsAt === 'string' ? value.endsAt : null;
    return {
      sessionUuid: value.sessionUuid,
      phase,
      blocksDone: typeof value.blocksDone === 'number' ? value.blocksDone : 0,
      commitmentUuid: typeof value.commitmentUuid === 'string' ? value.commitmentUuid : null,
      endsAt,
      pausedRemaining: endsAt === null ? (typeof value.pausedRemaining === 'number' ? value.pausedRemaining : 0) : null,
      userPaused: value.userPaused === true,
    };
  } catch {
    return null;
  }
}

export async function readActive(db: HarvestDB): Promise<PomodoroSnapshot | null> {
  return parseSnapshot((await db.rows('kv_settings').get(pomodoroKeys.active))?.valueJson);
}

/** What walking the clock forward did: the blocks it paid, and whether a break ran out. */
export interface Advance {
  next: PomodoroSnapshot;
  /** The moments focus blocks ended, each paid once. */
  blocks: Date[];
  breakOver: boolean;
}

/**
 * Walks [snapshot] forward over every phase boundary already behind
 * [now] (`_advance`): a focus block that ends is paid and its break
 * starts on its own; a break that ends waits, paused, for me to start
 * the next block.
 */
export function advance(snapshot: PomodoroSnapshot, config: PomodoroConfig, now: Date): Advance {
  let current = snapshot;
  const blocks: Date[] = [];
  let breakOver = false;
  while (current.endsAt !== null && Date.parse(current.endsAt) <= now.getTime()) {
    const boundary = new Date(current.endsAt);
    if (current.phase === 'focus') {
      blocks.push(boundary);
      const blocksDone = current.blocksDone + 1;
      const phase: PomodoroPhase = blocksDone % Math.max(config.blocksPerLongBreak, 1) === 0 ? 'longBreak' : 'shortBreak';
      current = {
        ...current,
        phase,
        blocksDone,
        endsAt: new Date(boundary.getTime() + phaseMs(config, phase)).toISOString(),
      };
    } else {
      breakOver = true;
      current = {
        ...current,
        phase: 'focus',
        endsAt: null,
        pausedRemaining: Math.round(phaseMs(config, 'focus') / 1000),
      };
    }
  }
  return { next: current, blocks, breakOver };
}

async function activeIn(tx: Tx): Promise<PomodoroSnapshot | null> {
  return parseSnapshot((await tx.get('kv_settings', pomodoroKeys.active))?.valueJson);
}

async function saveActive(tx: Tx, snapshot: PomodoroSnapshot | null): Promise<void> {
  // Not a portable key, so the writer keeps it on this device.
  await tx.put('kv_settings', { key: pomodoroKeys.active, valueJson: JSON.stringify(snapshot), updatedAt: tx.now() });
}

async function configIn(tx: Tx): Promise<PomodoroConfig> {
  const read = async (key: string, fallback: number) => parseMinutes(settingText((await tx.get('kv_settings', key))?.valueJson), fallback);
  return {
    focusMinutes: await read(pomodoroKeys.focus, defaultPomodoroConfig.focusMinutes),
    shortBreakMinutes: await read(pomodoroKeys.shortBreak, defaultPomodoroConfig.shortBreakMinutes),
    longBreakMinutes: await read(pomodoroKeys.longBreak, defaultPomodoroConfig.longBreakMinutes),
    blocksPerLongBreak: await read(pomodoroKeys.blocksPerLong, defaultPomodoroConfig.blocksPerLongBreak),
  };
}

async function endSession(tx: Tx, snapshot: PomodoroSnapshot): Promise<void> {
  await tx.patch('pomodoro_sessions', snapshot.sessionUuid, { endedAt: tx.now() });
  await saveActive(tx, null);
}

/**
 * Focus sessions, as the phone's PomodoroService and controller run
 * them: a `pomodoro_sessions` row per session, [Xp.pomodoroBlock] per
 * completed focus block through the ledger, and the running timer kept
 * as a snapshot. Every step reads the snapshot inside its own
 * transaction, so two tabs ticking at once cannot pay a block twice.
 */
export class PomodoroRepository {
  constructor(private readonly writer: Writer) {}

  /** Starts a session: the history row, and a first focus block running. */
  start(commitmentUuid: string | null): Promise<PomodoroSnapshot> {
    return this.writer.run(async (tx) => {
      const running = await activeIn(tx);
      if (running) return running;
      const config = await configIn(tx);
      const at = tx.clockNow();
      const snapshot: PomodoroSnapshot = {
        sessionUuid: crypto.randomUUID(),
        phase: 'focus',
        blocksDone: 0,
        commitmentUuid,
        endsAt: new Date(at.getTime() + phaseMs(config, 'focus')).toISOString(),
        pausedRemaining: null,
        userPaused: false,
      };
      await tx.put('pomodoro_sessions', {
        uuid: snapshot.sessionUuid,
        commitmentUuid,
        focusBlocks: 0,
        harvestDay: HarvestDay.of(at).key,
        startedAt: at.toISOString(),
        endedAt: null,
      });
      await saveActive(tx, snapshot);
      return snapshot;
    });
  }

  /**
   * Re-checks the clock: pays each focus block that has ended, on the
   * Harvest Day it ended on, and moves the timer on.
   */
  evaluate(): Promise<Advance | null> {
    return this.writer.run(async (tx) => {
      const snapshot = await activeIn(tx);
      if (!snapshot || snapshot.endsAt === null) return null;
      const step = advance(snapshot, await configIn(tx), tx.clockNow());
      if (step.blocks.length === 0 && !step.breakOver) return null;
      let blocks = snapshot.blocksDone;
      for (const boundary of step.blocks) {
        blocks += 1;
        await tx.patch('pomodoro_sessions', snapshot.sessionUuid, { focusBlocks: blocks });
        await tx.ledger({
          kind: 'xp',
          delta: Xp.pomodoroBlock,
          reason: `pomodoro:${snapshot.sessionUuid}`,
          harvestDay: HarvestDay.of(boundary).key,
        });
      }
      await saveActive(tx, step.next);
      return step;
    });
  }

  pause(): Promise<void> {
    return this.writer.run(async (tx) => {
      const snapshot = await activeIn(tx);
      if (!snapshot || snapshot.endsAt === null) return;
      const left = Math.max(Math.round(remainingMs(snapshot, tx.clockNow()) / 1000), 0);
      await saveActive(tx, { ...snapshot, endsAt: null, pausedRemaining: left, userPaused: true });
    });
  }

  /** Resumes a pause, or starts the next block after a break ran out. */
  resume(): Promise<void> {
    return this.writer.run(async (tx) => {
      const snapshot = await activeIn(tx);
      if (!snapshot || snapshot.endsAt !== null) return;
      const endsAt = new Date(tx.clockNow().getTime() + (snapshot.pausedRemaining ?? 0) * 1000).toISOString();
      await saveActive(tx, { ...snapshot, endsAt, pausedRemaining: null, userPaused: false });
    });
  }

  /**
   * Ends the session. Returns the seed to offer a check-in for when at
   * least one focus block was completed.
   */
  finish(): Promise<string | null> {
    return this.writer.run(async (tx) => {
      const snapshot = await activeIn(tx);
      if (!snapshot) return null;
      await endSession(tx, snapshot);
      return snapshot.blocksDone > 0 ? snapshot.commitmentUuid : null;
    });
  }

  /** Abandons mid-focus: no XP for the unfinished block, no guilt. */
  abandon(): Promise<void> {
    return this.writer.run(async (tx) => {
      const snapshot = await activeIn(tx);
      if (snapshot) await endSession(tx, snapshot);
    });
  }
}
