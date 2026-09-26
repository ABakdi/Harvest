import { HarvestDay, Xp } from '@harvest/core';
import type { HarvestDB, Row } from './db';
import type { Tx, Writer } from './writer';

export type ExpenseRow = Row<'expenses'>;
export type MoneyTxnRow = Row<'money_txns'>;

/** The preset categories, in display order; custom ones are stored by name. */
export const presetCategories = ['food', 'transport', 'bills', 'shopping', 'health', 'entertainment', 'other'] as const;

export interface ExpenseInput {
  amountMinor: number;
  currency: string;
  category: string;
  note: string | null;
  /** The Harvest Day it counts for. */
  day: string;
  /** Paid out of the wallet: a linked movement is written beside it. */
  fromWallet: boolean;
}

/**
 * Expenses, mirroring FinancesRepository and FinanceActions on the
 * phone: the first expense of a Harvest Day pays +10 XP
 * (`expenses:<day>`), and when the day's last expense goes, so does the
 * payment, with a mirror row (`expenses-undo:<day>`). An expense paid
 * from the wallet carries a linked movement that follows every edit.
 *
 * These are private-tier rows: they are stored here in the clear, like
 * the phone stores them, and sealed only on their way to the server.
 */
/** Day four of the same thing three days running ([[Finances]] Smart repeats). */
export interface RepeatSuggestion {
  amountMinor: number;
  currency: string;
  category: string;
  note: string | null;
}

/**
 * `repeatSuggestion`: an (amount, currency, category) logged on each of
 * the three days before [today], and not yet today, comes back as a
 * one-tap card. The note is whichever of those rows was read last, as
 * on the phone.
 */
export async function readRepeatSuggestion(db: HarvestDB, today: HarvestDay): Promise<RepeatSuggestion | null> {
  const days = [today.previous, today.previous.previous, today.previous.previous.previous].map((day) => day.key);
  const rows = (await db.rows('expenses').where('harvestDay').anyOf([today.key, ...days]).toArray()).filter(
    (row) => row.deletedAt === null,
  );
  const byDay = new Map<string, Set<string>>();
  const found = new Map<string, ExpenseRow>();
  for (const row of rows) {
    const key = JSON.stringify([row.amountMinor, row.currency, row.category]);
    if (!byDay.has(row.harvestDay)) byDay.set(row.harvestDay, new Set());
    byDay.get(row.harvestDay)!.add(key);
    found.set(key, row);
  }
  const todays = byDay.get(today.key) ?? new Set<string>();
  for (const key of byDay.get(days[0]!) ?? []) {
    if (days.every((day) => byDay.get(day)?.has(key)) && !todays.has(key)) {
      const row = found.get(key)!;
      return { amountMinor: row.amountMinor, currency: row.currency, category: row.category, note: row.note };
    }
  }
  return null;
}

export class MoneyRepository {
  constructor(private readonly writer: Writer) {}

  log(input: ExpenseInput): Promise<string> {
    return this.writer.run(async (tx) => {
      const now = tx.now();
      const uuid = crypto.randomUUID();
      await tx.put('expenses', {
        uuid,
        amountMinor: input.amountMinor,
        currency: input.currency,
        category: input.category,
        note: input.note?.trim() || null,
        harvestDay: input.day,
        loggedAt: now,
        deletedAt: null,
        updatedAt: now,
      });
      await payDayIfUnpaid(tx, input.day);
      if (input.fromWallet) await walletMove(tx, uuid, input);
      return uuid;
    });
  }

  /**
   * Edits an entry in place. A new day moves it, and the day's XP
   * follows: the old day gives its +10 back if this was its last
   * expense, the new day is paid if it had none.
   */
  update(uuid: string, input: ExpenseInput): Promise<void> {
    return this.writer.run(async (tx) => {
      const before = await tx.get('expenses', uuid);
      if (!before) return;
      const oldDay = HarvestDay.tryParse(before.harvestDay);
      const moved = oldDay !== null && oldDay.key !== input.day;
      const harvestDay = moved ? input.day : before.harvestDay;
      await tx.put('expenses', {
        ...before,
        amountMinor: input.amountMinor,
        currency: input.currency,
        category: input.category,
        note: input.note?.trim() || null,
        harvestDay,
        updatedAt: tx.now(),
      });
      if (moved) {
        if (!(await anyLiveOn(tx, oldDay.key))) await takeDayBack(tx, oldDay.key);
        await payDayIfUnpaid(tx, input.day);
      }
      const linked = await linkedTxn(tx, uuid, false);
      if (input.fromWallet) {
        // The switch turned back on brings the old movement back rather
        // than writing a second one beside it.
        const reuse = linked ?? (await linkedTxn(tx, uuid, true));
        if (reuse) {
          await tx.put('money_txns', {
            ...reuse,
            deletedAt: null,
            deltaMinor: -input.amountMinor,
            currency: input.currency,
            reference: input.category,
            note: input.note?.trim() || null,
            harvestDay,
            updatedAt: tx.now(),
          });
        } else {
          // The movement lives on the expense's day, which this edit
          // may just have changed ([[Audit-v2]] B3-05).
          await walletMove(tx, uuid, { ...input, day: harvestDay });
        }
      } else if (linked) {
        await tx.patch('money_txns', linked.uuid, { deletedAt: tx.now(), updatedAt: tx.now() });
      }
    });
  }

  /** Soft-deletes an entry, its wallet movement, and the day's XP if it was the last one. */
  remove(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      const row = await tx.get('expenses', uuid);
      if (!row) return;
      const now = tx.now();
      await tx.put('expenses', { ...row, deletedAt: now, updatedAt: now });
      if (!(await anyLiveOn(tx, row.harvestDay))) await takeDayBack(tx, row.harvestDay);
      const linked = await linkedTxn(tx, uuid, false);
      if (linked) await tx.put('money_txns', { ...linked, deletedAt: now, updatedAt: now });
    });
  }

  /** The Undo after a removal: the entry, its movement, and the day's XP come back. */
  restore(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      const row = await tx.get('expenses', uuid);
      if (!row) return;
      const now = tx.now();
      await tx.put('expenses', { ...row, deletedAt: null, updatedAt: now });
      await payDayIfUnpaid(tx, row.harvestDay);
      // Only the movement that went with it: [remove] stamps both with
      // the same moment, and a row an earlier edit dropped stays gone.
      const linked = await linkedTxn(tx, uuid, true);
      if (linked && linked.deletedAt === row.deletedAt) {
        await tx.put('money_txns', { ...linked, deletedAt: null, updatedAt: now });
      }
    });
  }
}

async function walletMove(tx: Tx, expenseUuid: string, input: ExpenseInput): Promise<void> {
  const now = tx.now();
  await tx.put('money_txns', {
    uuid: crypto.randomUUID(),
    account: 'wallet',
    deltaMinor: -input.amountMinor,
    currency: input.currency,
    note: input.note?.trim() || null,
    kind: 'expense',
    reference: input.category,
    linkUuid: expenseUuid,
    harvestDay: input.day,
    loggedAt: now,
    deletedAt: null,
    updatedAt: now,
  });
}

/**
 * The movement that belongs to an expense, or none. With
 * [includeDeleted] and no live one, the one deleted last: the one that
 * went with the expense, not an older row an earlier edit dropped.
 */
export async function linkedTxn(tx: Tx, linkUuid: string, includeDeleted: boolean): Promise<MoneyTxnRow | undefined> {
  const rows = await tx.rows('money_txns').where('linkUuid').equals(linkUuid).toArray();
  const live = rows.find((row) => row.deletedAt === null);
  if (live || !includeDeleted) return live;
  return rows.sort((a, b) => (b.deletedAt ?? '').localeCompare(a.deletedAt ?? ''))[0];
}

async function anyLiveOn(tx: Tx, dayKey: string): Promise<boolean> {
  const rows = await tx.rows('expenses').where('harvestDay').equals(dayKey).toArray();
  return rows.some((row) => row.deletedAt === null);
}

/** What the day's expense XP nets to; zero means unpaid, never or taken back. */
async function dayXpNet(tx: Tx, dayKey: string): Promise<number> {
  const rows = await tx.ledgerFor(`expenses:${dayKey}`, `expenses-undo:${dayKey}`);
  return rows.reduce((sum, row) => sum + row.delta, 0);
}

async function payDayIfUnpaid(tx: Tx, dayKey: string): Promise<void> {
  if ((await dayXpNet(tx, dayKey)) !== 0) return;
  await tx.ledger({ kind: 'xp', delta: Xp.expenseLog, reason: `expenses:${dayKey}`, harvestDay: dayKey });
}

async function takeDayBack(tx: Tx, dayKey: string): Promise<void> {
  const net = await dayXpNet(tx, dayKey);
  if (net <= 0) return;
  await tx.ledger({ kind: 'xp', delta: -net, reason: `expenses-undo:${dayKey}`, harvestDay: dayKey });
}
