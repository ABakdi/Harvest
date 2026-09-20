import type { CurrencyCode, HarvestDay, Rates } from '@harvest/core';
import { budgetSnapshotFor, currencyOf, sumInDefault } from '@harvest/core';
import type { HarvestDB, Row } from './db';
import { readSetting, settingKeys } from './settings';

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

export async function readVault(db: HarvestDB, movementLimit = 30): Promise<VaultView> {
  const [txns, debts, payments, rates] = await Promise.all([
    db.rows('money_txns').toArray(),
    db.rows('debts').toArray(),
    db.rows('debt_payments').toArray(),
    readRates(db),
  ]);
  const live = txns
    .filter((row) => row.deletedAt === null)
    .sort((a, b) => b.loggedAt.localeCompare(a.loggedAt));

  const pots = accounts.map((account) => {
    const mine = live.filter((row) => row.account === account);
    const sums = new Map<CurrencyCode, number>();
    for (const row of mine) {
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
    .sort((a, b) => Number(a.settledAt !== null) - Number(b.settledAt !== null) || (a.payOffBy ?? '￿').localeCompare(b.payOffBy ?? '￿'))
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
    if (row.deletedAt !== null || !row.harvestDay.startsWith(month)) continue;
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
