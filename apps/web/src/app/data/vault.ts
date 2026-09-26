import type { CurrencyCode, Rates } from '@harvest/core';
import { HarvestDay, budgetSnapshotFor, currencyOf, sumInDefault } from '@harvest/core';
import type { HarvestDB, Row } from './db';
import { readSetting, settingKeys } from './settings';
import type { Tx, Writer } from './writer';

export type TxnRow = Row<'money_txns'>;
export type DebtRow = Row<'debts'>;
export type DebtPaymentRow = Row<'debt_payments'>;

/** The two pots ([[Finances]]): the wallet is to spend, savings are to keep. */
export const accounts = ['wallet', 'savings'] as const;
export type Account = (typeof accounts)[number];

/** What the exchange card last knew, as the rules want it. */
export async function readRates(db: HarvestDB): Promise<Rates> {
  const [currency, usd, eur, usdPerEur] = await Promise.all([
    readSetting(db, settingKeys.defaultCurrency),
    readSetting(db, 'rate.dzdPerUsd'),
    readSetting(db, 'rate.dzdPerEur'),
    readSetting(db, 'rate.usdPerEur'),
  ]);
  const number = (raw: string | null) => {
    const value = Number(raw);
    return raw !== null && Number.isFinite(value) && value > 0 ? value : null;
  };
  return {
    defaultCurrency: currencyOf(currency),
    dzdPerUsd: number(usd),
    dzdPerEur: number(eur),
    usdPerEur: number(usdPerEur),
  };
}

/** One pot: what is in it, per currency, and the movements that put it there. */
export interface PotView {
  account: Account;
  balances: [CurrencyCode, number][];
  /** Everything converted, for the tile that has room for one number. */
  totalInDefault: number;
  movements: TxnRow[];
}

export interface DebtView {
  debt: DebtRow;
  paidMinor: number;
  leftMinor: number;
  payments: DebtPaymentRow[];
}

export interface VaultView {
  pots: PotView[];
  debts: DebtView[];
  /** Still owed, converted, so the tile can show one number. */
  owedInDefault: number;
  rates: Rates;
}

/**
 * Whether a movement is logged ahead: dated after [today], it counts on
 * its day, not before, so no pot's balance holds it yet ([[Finances]]).
 */
export function isUpcoming(row: Pick<TxnRow, 'harvestDay'>, today: HarvestDay | string): boolean {
  return row.harvestDay > (typeof today === 'string' ? today : today.key);
}

/**
 * Movements newest first by the day each counts on, then by when they
 * were logged: one logged ahead sits on top, under its own day
 * (`VaultRepository.watchTxns`).
 */
export function byDayNewestFirst(a: TxnRow, b: TxnRow): number {
  return b.harvestDay.localeCompare(a.harvestDay) || b.loggedAt.localeCompare(a.loggedAt);
}

/**
 * Every pot, its balances as of [today] (a movement logged ahead is left
 * out until its day, as `watchBalances(asOf:)` does) and its ledger.
 */
export async function readVault(db: HarvestDB, today: HarvestDay = HarvestDay.today(), movementLimit = 60): Promise<VaultView> {
  const [txns, debts, payments, rates] = await Promise.all([
    db.rows('money_txns').toArray(),
    db.rows('debts').toArray(),
    db.rows('debt_payments').toArray(),
    readRates(db),
  ]);
  const live = txns.filter((row) => row.deletedAt === null).sort(byDayNewestFirst);

  const pots = accounts.map((account) => {
    const mine = live.filter((row) => row.account === account);
    const sums = new Map<CurrencyCode, number>();
    for (const row of mine) {
      if (isUpcoming(row, today)) continue;
      const code = currencyOf(row.currency);
      sums.set(code, (sums.get(code) ?? 0) + row.deltaMinor);
    }
    const balances = [...sums.entries()].sort((a, b) => b[1] - a[1]);
    return {
      account,
      balances,
      totalInDefault: sumInDefault(rates, balances),
      movements: mine.slice(0, movementLimit),
    };
  });

  const livePayments = payments.filter((row) => row.deletedAt === null);
  const views = debts
    .filter((row) => row.deletedAt === null)
    // Open ones first, then oldest first, as the phone lists them.
    .sort((a, b) => (a.settledAt ?? '').localeCompare(b.settledAt ?? '') || a.createdAt.localeCompare(b.createdAt))
    .map((debt) => {
      const mine = livePayments
        .filter((row) => row.debtUuid === debt.uuid)
        .sort((a, b) => b.loggedAt.localeCompare(a.loggedAt));
      const paidMinor = mine.reduce((sum, row) => sum + row.amountMinor, 0);
      return { debt, payments: mine, paidMinor, leftMinor: Math.max(debt.amountMinor - paidMinor, 0) };
    });

  return {
    pots,
    debts: views,
    owedInDefault: sumInDefault(
      rates,
      views.filter((view) => view.debt.settledAt === null).map((view) => [currencyOf(view.debt.currency), view.leftMinor] as const),
    ),
    rates,
  };
}

/**
 * The month's budget, worked out the way the phone works it out: every
 * day's spending converted to the default currency, then
 * `budgetSnapshotFor` — the floating daily limit, what is left, and
 * whether that is under, close or over ([[Finances]]).
 */
export async function readBudget(db: HarvestDB, today: HarvestDay) {
  const [expenses, rates, budgetRaw] = await Promise.all([
    db.rows('expenses').toArray(),
    readRates(db),
    readSetting(db, settingKeys.monthlyBudget),
  ]);
  const monthlyBudget = Number(budgetRaw ?? 0);
  const month = today.key.slice(0, 7);
  const totals = new Map<string, number>();
  const byCategory = new Map<string, number>();
  for (const row of expenses) {
    // A day still to come has not been spent yet: the month counts up
    // to today, as the phone's snapshot does.
    if (row.deletedAt !== null || !row.harvestDay.startsWith(month) || row.harvestDay > today.key) continue;
    const minor = sumInDefault(rates, [[currencyOf(row.currency), row.amountMinor]]);
    totals.set(row.harvestDay, (totals.get(row.harvestDay) ?? 0) + minor);
    byCategory.set(row.category, (byCategory.get(row.category) ?? 0) + minor);
  }
  return {
    rates,
    monthlyBudget: Number.isFinite(monthlyBudget) && monthlyBudget > 0 ? monthlyBudget : 0,
    snapshot: budgetSnapshotFor([...totals.entries()], Number.isFinite(monthlyBudget) ? monthlyBudget : 0, today),
    byCategory: [...byCategory.entries()].sort((a, b) => b[1] - a[1]),
    spentThisMonth: [...totals.values()].reduce((sum, value) => sum + value, 0),
  };
}

// -------------------------------------------------------------- writes

/** Why a movement happened ([[Finances]] The Vault): the kinds the phone writes. */
export const txnKinds = ['manual', 'transfer', 'expense', 'debt'] as const;
export type TxnKind = (typeof txnKinds)[number];

/** A refused money write: an overdraw, an over-payment, a settled debt. */
export class MoneyRuleError extends Error {
  constructor(readonly rule: 'amount' | 'overdraw' | 'overpay' | 'settled' | 'missing') {
    super(`Money rule: ${rule}`);
    this.name = 'MoneyRuleError';
  }
}

export interface MoveInput {
  account: Account;
  deltaMinor: number;
  currency: string;
  kind?: TxnKind;
  reference?: string | null;
  linkUuid?: string | null;
  note?: string | null;
  /** The Harvest Day it lands on; today when left out. */
  day?: string;
}

/** Records one movement, as `VaultRepository.move` writes it. */
export async function writeMove(tx: Tx, input: MoveInput): Promise<string> {
  const uuid = crypto.randomUUID();
  const now = tx.now();
  await tx.put('money_txns', {
    uuid,
    account: input.account,
    deltaMinor: input.deltaMinor,
    currency: input.currency,
    note: input.note?.trim() || null,
    kind: input.kind ?? 'manual',
    reference: input.reference ?? null,
    linkUuid: input.linkUuid ?? null,
    harvestDay: input.day ?? HarvestDay.of(tx.clockNow()).key,
    loggedAt: now,
    deletedAt: null,
    updatedAt: now,
  });
  return uuid;
}

/** What one pot holds in one currency today, deleted rows and upcoming ones aside. */
async function balanceOf(tx: Tx, account: Account, currency: string): Promise<number> {
  const today = HarvestDay.of(tx.clockNow());
  const rows = await tx.rows('money_txns').where('account').equals(account).toArray();
  return rows
    .filter((row) => row.deletedAt === null && row.currency === currency && !isUpcoming(row, today))
    .reduce((sum, row) => sum + row.deltaMinor, 0);
}

/** What has been paid on one debt so far. */
async function paidOn(tx: Tx, debtUuid: string): Promise<number> {
  const rows = await tx.rows('debt_payments').where('debtUuid').equals(debtUuid).toArray();
  return rows.filter((row) => row.deletedAt === null).reduce((sum, row) => sum + row.amountMinor, 0);
}

/** Refuses a change of [deltaMinor] that would take a pot below zero. */
async function refuseBelowZero(tx: Tx, account: Account, currency: string, deltaMinor: number): Promise<void> {
  if (deltaMinor < 0 && (await balanceOf(tx, account, currency)) + deltaMinor < 0) throw new MoneyRuleError('overdraw');
}

function positive(amountMinor: number): void {
  if (!Number.isSafeInteger(amountMinor) || amountMinor <= 0) throw new MoneyRuleError('amount');
}

export interface DebtInput {
  person: string;
  amountMinor: number;
  currency: string;
  payOffBy: string | null;
  /** `H:mm`, the way the phone's sheet writes it; null for the default time. */
  remindAt: string | null;
  note: string | null;
}

/**
 * The Vault's writes, mirroring `VaultRepository` and `FinanceActions`
 * on the phone: every movement is a `money_txns` row with a kind, a
 * reference and, when another row owns it, a link; balances stay sums
 * ([[Finances]] The Vault).
 *
 * The phone's sheets cap a withdrawal at what the pot holds; here the
 * repository says so too, so a stale dialog cannot overdraw a pot that
 * another device emptied in the meantime.
 */
export class VaultRepository {
  constructor(private readonly writer: Writer) {}

  /** Adds to the wallet, or takes from it (a negative delta) — never past zero. */
  async moveWallet(deltaMinor: number, currency: string, note: string | null): Promise<string> {
    positive(Math.abs(deltaMinor));
    return this.writer.run(async (tx) => {
      if (deltaMinor < 0 && (await balanceOf(tx, 'wallet', currency)) < -deltaMinor) {
        throw new MoneyRuleError('overdraw');
      }
      return writeMove(tx, { account: 'wallet', deltaMinor, currency, note });
    });
  }

  /**
   * Puts money into savings: moved from the wallet (a transfer, two
   * linked-by-kind rows) or new money (`depositSavings`).
   */
  async depositSavings(amountMinor: number, currency: string, fromWallet: boolean, note: string | null): Promise<void> {
    positive(amountMinor);
    return this.writer.run(async (tx) => {
      if (fromWallet) {
        await transfer(tx, 'wallet', 'savings', amountMinor, currency, note);
      } else {
        await writeMove(tx, { account: 'savings', deltaMinor: amountMinor, currency, note });
      }
    });
  }

  /**
   * Takes money out of savings. It always lands in the wallet, and is
   * spent from there like any other money; it cannot exceed the pot.
   */
  async withdrawSavings(amountMinor: number, currency: string, note: string | null): Promise<void> {
    positive(amountMinor);
    return this.writer.run(async (tx) => {
      await transfer(tx, 'savings', 'wallet', amountMinor, currency, note);
    });
  }

  /**
   * Soft-deletes a hand-made movement; Undo is [restoreMove]. Only a
   * manual row goes this way: an expense's movement follows its expense
   * and a payment's follows its payment, and a transfer's two halves
   * are not tied to each other on the phone, so one half cannot be
   * taken without leaving the other behind.
   */
  removeMove(uuid: string): Promise<boolean> {
    return this.writer.run(async (tx) => {
      const row = await tx.get('money_txns', uuid);
      if (!row || row.deletedAt !== null || row.kind !== 'manual') return false;
      // Taking back money that has since been spent would leave the pot
      // below zero, the one thing a pot never is.
      // One still upcoming was never in the balance to take back.
      if (!isUpcoming(row, HarvestDay.of(tx.clockNow()))) await refuseBelowZero(tx, row.account as Account, row.currency, -row.deltaMinor);
      await tx.put('money_txns', { ...row, deletedAt: tx.now(), updatedAt: tx.now() });
      return true;
    });
  }

  /** The Undo for [removeMove]; a withdrawal cannot come back into a pot that no longer holds it. */
  restoreMove(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      const row = await tx.get('money_txns', uuid);
      if (!row || row.deletedAt === null) return;
      if (!isUpcoming(row, HarvestDay.of(tx.clockNow()))) await refuseBelowZero(tx, row.account as Account, row.currency, row.deltaMinor);
      await tx.put('money_txns', { ...row, deletedAt: null, updatedAt: tx.now() });
    });
  }

  async createDebt(input: DebtInput): Promise<string> {
    positive(input.amountMinor);
    const person = input.person.trim();
    if (!person) throw new MoneyRuleError('missing');
    return this.writer.run(async (tx) => {
      const uuid = crypto.randomUUID();
      const now = tx.now();
      await tx.put('debts', {
        uuid,
        person,
        amountMinor: input.amountMinor,
        currency: input.currency,
        payOffBy: input.payOffBy,
        remindAt: input.remindAt,
        note: input.note?.trim() || null,
        settledAt: null,
        createdAt: now,
        deletedAt: null,
        updatedAt: now,
      });
      return uuid;
    });
  }

  /**
   * Pays part or all of a debt, and settles it when fully paid. With
   * [fromWallet] the money leaves the wallet as a debt-kind row linked
   * to the payment. A non-positive amount, a payment past what is still
   * owed, or a debt settled or gone is refused (`payDebt`).
   */
  async payDebt(debtUuid: string, amountMinor: number, fromWallet: boolean, note: string | null): Promise<string> {
    positive(amountMinor);
    return this.writer.run(async (tx) => {
      const debt = await tx.get('debts', debtUuid);
      if (!debt || debt.deletedAt !== null) throw new MoneyRuleError('missing');
      if (debt.settledAt !== null) throw new MoneyRuleError('settled');
      if ((await paidOn(tx, debtUuid)) + amountMinor > debt.amountMinor) throw new MoneyRuleError('overpay');
      if (fromWallet && (await balanceOf(tx, 'wallet', debt.currency)) < amountMinor) {
        throw new MoneyRuleError('overdraw');
      }
      const day = HarvestDay.of(tx.clockNow()).key;
      const uuid = crypto.randomUUID();
      await tx.put('debt_payments', { uuid, debtUuid, amountMinor, harvestDay: day, loggedAt: tx.now(), deletedAt: null });
      if (fromWallet) {
        await writeMove(tx, {
          account: 'wallet',
          deltaMinor: -amountMinor,
          currency: debt.currency,
          kind: 'debt',
          reference: debt.person,
          linkUuid: uuid,
          note,
          day,
        });
      }
      await settleIfPaid(tx, debtUuid);
      return uuid;
    });
  }

  /**
   * Removes a payment logged by mistake: the payment, the wallet
   * movement it made, and the settlement it caused ([[Audit-v2-Beta]] N-01).
   */
  removePayment(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      const payment = await tx.get('debt_payments', uuid);
      if (!payment || payment.deletedAt !== null) return;
      await tx.put('debt_payments', { ...payment, deletedAt: tx.now() });
      const linked = await linkedMove(tx, uuid, false);
      if (linked) await tx.put('money_txns', { ...linked, deletedAt: tx.now(), updatedAt: tx.now() });
      await settleIfPaid(tx, payment.debtUuid);
    });
  }

  /** The Undo for [removePayment]: wallet movement and settlement too. */
  restorePayment(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      const payment = await tx.get('debt_payments', uuid);
      if (!payment) return;
      await tx.put('debt_payments', { ...payment, deletedAt: null });
      const linked = await linkedMove(tx, uuid, true);
      if (linked) await tx.put('money_txns', { ...linked, deletedAt: null, updatedAt: tx.now() });
      await settleIfPaid(tx, payment.debtUuid);
    });
  }
}

async function transfer(tx: Tx, from: Account, to: Account, amountMinor: number, currency: string, note: string | null) {
  if ((await balanceOf(tx, from, currency)) < amountMinor) throw new MoneyRuleError('overdraw');
  await writeMove(tx, { account: from, deltaMinor: -amountMinor, currency, kind: 'transfer', reference: to, note });
  await writeMove(tx, { account: to, deltaMinor: amountMinor, currency, kind: 'transfer', reference: from, note });
}

async function linkedMove(tx: Tx, linkUuid: string, includeDeleted: boolean) {
  const rows = await tx.rows('money_txns').where('linkUuid').equals(linkUuid).toArray();
  return rows.find((row) => includeDeleted || row.deletedAt === null);
}

/** Settles a debt its payments now cover, and reopens one they no longer do. */
async function settleIfPaid(tx: Tx, debtUuid: string): Promise<void> {
  const debt = await tx.get('debts', debtUuid);
  if (!debt) return;
  const settled = (await paidOn(tx, debtUuid)) >= debt.amountMinor;
  if (settled === (debt.settledAt !== null)) return;
  await tx.put('debts', { ...debt, settledAt: settled ? tx.now() : null, updatedAt: tx.now() });
}

// ------------------------------------------------------------ insights

/**
 * What to keep of a ledger (`MoveFilter`): forms of movement,
 * expense categories, and a word in the note or the reference. Empty
 * means everything — a filter nobody set never hides a row.
 */
export interface MoveFilter {
  kinds: readonly string[];
  categories: readonly string[];
  query: string;
}

export const emptyFilter: MoveFilter = { kinds: [], categories: [], query: '' };

export function activeFilters(filter: MoveFilter): number {
  return Number(filter.kinds.length > 0) + Number(filter.categories.length > 0) + Number(filter.query !== '');
}

export function matchesFilter(filter: MoveFilter, row: TxnRow): boolean {
  if (filter.kinds.length > 0 && !filter.kinds.includes(row.kind)) return false;
  // Only an expense carries a category, so choosing one narrows the
  // ledger to expenses by construction.
  if (filter.categories.length > 0 && (row.kind !== 'expense' || !filter.categories.includes(row.reference ?? ''))) {
    return false;
  }
  const needle = filter.query.trim().toLowerCase();
  if (!needle) return true;
  return (row.note ?? '').toLowerCase().includes(needle) || (row.reference ?? '').toLowerCase().includes(needle);
}

export type RangeKind = 'week' | 'month' | 'custom';

/** A closed span of Harvest Days, both ends included (`DayRange`). */
export interface DayRange {
  kind: RangeKind;
  from: HarvestDay;
  to: HarvestDay;
}

export function weekRange(today: HarvestDay): DayRange {
  return { kind: 'week', from: today.weekStart, to: today.weekStart.addDays(6) };
}

export function monthRange(today: HarvestDay): DayRange {
  const last = new Date(Date.UTC(today.year, today.month, 0)).getUTCDate();
  return { kind: 'month', from: HarvestDay.fromDate(today.year, today.month, 1), to: HarvestDay.fromDate(today.year, today.month, last) };
}

export function rangeDays(range: DayRange): HarvestDay[] {
  return Array.from({ length: range.from.daysUntil(range.to) + 1 }, (_, index) => range.from.addDays(index));
}

/**
 * How much of the span has happened: a month four days old divides by
 * four, not thirty-one ([[Finances]] Layout).
 */
export function elapsedDays(range: DayRange, today: HarvestDay): number {
  if (today.compareTo(range.from) < 0) return 0;
  return range.from.daysUntil(today.compareTo(range.to) < 0 ? today : range.to) + 1;
}

export interface InsightsView {
  rates: Rates;
  /** Spending per Harvest Day, in the default currency. */
  dayTotals: Map<string, number>;
  /** Spending per category, largest first, in the default currency. */
  byCategory: [string, number][];
  total: number;
  /** Every movement in the span, newest first. */
  moves: TxnRow[];
}

/**
 * The Insights page's one read: the span's expenses, converted (face
 * value where a rate is missing, as `totalsByDay` does), and its moves.
 */
export async function readInsights(db: HarvestDB, range: DayRange): Promise<InsightsView> {
  const [expenses, txns, rates] = await Promise.all([
    db.rows('expenses').where('harvestDay').between(range.from.key, range.to.key, true, true).toArray(),
    db.rows('money_txns').toArray(),
    readRates(db),
  ]);
  const dayTotals = new Map<string, number>();
  const byCategory = new Map<string, number>();
  let total = 0;
  for (const row of expenses) {
    if (row.deletedAt !== null) continue;
    const minor = sumInDefault(rates, [[currencyOf(row.currency), row.amountMinor]]);
    dayTotals.set(row.harvestDay, (dayTotals.get(row.harvestDay) ?? 0) + minor);
    byCategory.set(row.category, (byCategory.get(row.category) ?? 0) + minor);
    total += minor;
  }
  const moves = txns
    .filter((row) => row.deletedAt === null && row.harvestDay >= range.from.key && row.harvestDay <= range.to.key)
    .sort(byDayNewestFirst);
  return { rates, dayTotals, byCategory: [...byCategory.entries()].sort((a, b) => b[1] - a[1]), total, moves };
}
