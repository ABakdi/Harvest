import type { StoredTable } from '../db';
import { dayOf, intOf } from '../archive';
import { spec, uuidOf, text, at, updated, type Spec } from './sheet-spec';

/** The Granary: expenses, their categories, money and debts. */
export const moneySheets: Spec<StoredTable>[] = [
  spec({
    sheet: 'expenses',
    table: 'expenses',
    keyOf: uuidOf,
    stamp: updated,
    build: (row, { now }) => ({
      uuid: row.Uuid,
      harvestDay: dayOf(row.HarvestDay) ?? '',
      category: row.Category ?? '',
      currency: row.Currency ?? 'DZD',
      amountMinor: intOf(row.AmountMinor) ?? 0,
      note: text(row.Note),
      loggedAt: at(row.LoggedAt) ?? now,
      updatedAt: at(row.UpdatedAt) ?? at(row.LoggedAt) ?? now,
      deletedAt: at(row.DeletedAt),
    }),
  }),
  // The categories I made, so every key my expenses use has a name.
  spec({
    sheet: 'categories',
    table: 'expense_categories',
    keyOf: uuidOf,
    stamp: updated,
    build: (row, { now }) => ({
      uuid: row.Uuid,
      name: row.Name ?? '',
      icon: row.Icon ?? '',
      // Missing from an archive made before v21; the list then orders
      // it by UpdatedAt, as it always had.
      createdAt: at(row.CreatedAt),
      updatedAt: at(row.UpdatedAt) ?? now,
      deletedAt: at(row.DeletedAt),
    }),
  }),
  spec({
    sheet: 'money',
    table: 'money_txns',
    keyOf: uuidOf,
    stamp: updated,
    build: (row, { now }) => ({
      uuid: row.Uuid,
      harvestDay: dayOf(row.HarvestDay) ?? '',
      account: row.Account ?? '',
      kind: row.Kind ?? 'manual',
      reference: text(row.Reference),
      currency: row.Currency ?? 'DZD',
      deltaMinor: intOf(row.DeltaMinor) ?? 0,
      note: text(row.Note),
      linkUuid: text(row.LinkUuid),
      loggedAt: at(row.LoggedAt) ?? now,
      updatedAt: at(row.UpdatedAt) ?? at(row.LoggedAt) ?? now,
      deletedAt: at(row.DeletedAt),
    }),
  }),
  spec({
    sheet: 'debts',
    table: 'debts',
    keyOf: uuidOf,
    stamp: updated,
    build: (row, { now }) => ({
      uuid: row.Uuid,
      person: row.Person ?? '',
      currency: row.Currency ?? 'DZD',
      amountMinor: intOf(row.AmountMinor) ?? 0,
      payOffBy: text(row.PayOffBy),
      remindAt: text(row.RemindAt),
      note: text(row.Note),
      settledAt: at(row.SettledAt),
      createdAt: at(row.CreatedAt) ?? now,
      deletedAt: at(row.DeletedAt),
      updatedAt: at(row.UpdatedAt) ?? now,
    }),
  }),
  spec({
    sheet: 'debtPayments',
    table: 'debt_payments',
    keyOf: uuidOf,
    stamp: { sheet: 'LoggedAt', local: 'loggedAt' },
    build: (row, { now }) => ({
      uuid: row.Uuid,
      debtUuid: row.DebtUuid ?? '',
      harvestDay: dayOf(row.HarvestDay) ?? '',
      amountMinor: intOf(row.AmountMinor) ?? 0,
      loggedAt: at(row.LoggedAt) ?? now,
      deletedAt: at(row.DeletedAt),
    }),
  }),
];
