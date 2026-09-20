import type { CurrencyCode } from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import { ArrowLeftRightIcon, HandCoinsIcon, PiggyBankIcon, SmartphoneIcon, WalletIcon } from 'lucide-react';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { formatDay, formatMoney } from '@/lib/format';
import { EmptyState } from '../components/bits';
import { categoryLabel } from '../components/category';
import { useHarvest } from '../context';
import { type Account, type DebtView, type PotView, accounts, readVault } from '../data/vault';
import { useDefaultCurrency } from '../hooks';

/** Every currency the pot holds, never added together. */
function Balances({ balances, empty }: { balances: [CurrencyCode, number][]; empty: string }) {
  if (balances.length === 0) return <span className="text-muted-foreground">{empty}</span>;
  return (
    <span className="flex flex-wrap gap-x-3 tabular" dir="ltr">
      {balances.map(([currency, minor]) => (
        <span key={currency}>{formatMoney(minor, currency)}</span>
      ))}
    </span>
  );
}

function Movements({ pot }: { pot: PotView }) {
  const { t } = useTranslation();
  if (pot.movements.length === 0) {
    return <p className="px-1 text-sm text-muted-foreground">{t('vault.noMovements')}</p>;
  }
  return (
    <ul className="flex flex-col divide-y rounded-xl border bg-card">
      {pot.movements.map((row) => (
        <li key={row.uuid} className="flex items-center gap-3 px-4 py-2.5">
          <span className="flex min-w-0 flex-1 flex-col">
            <span className="font-bold">
              {row.kind === 'expense'
                ? categoryLabel(t, row.reference ?? 'other')
                : row.kind === 'debt'
                  ? t('vault.debtPayment', { person: row.reference ?? '' })
                  : row.kind === 'transfer'
                    ? t('vault.transfer', { account: t(`vault.${(row.reference ?? 'wallet') as Account}`) })
                    : t(row.deltaMinor >= 0 ? 'vault.deposit' : 'vault.withdrawal')}
            </span>
            <span className="truncate text-xs text-muted-foreground">
              {[formatDay(row.harvestDay), row.note].filter(Boolean).join(' · ')}
            </span>
          </span>
          <span
            className={row.deltaMinor >= 0 ? 'font-extrabold tabular text-success' : 'font-extrabold tabular'}
            dir="ltr"
          >
            {row.deltaMinor >= 0 ? '+' : ''}
            {formatMoney(row.deltaMinor, row.currency)}
          </span>
        </li>
      ))}
    </ul>
  );
}

function Debts({ debts }: { debts: DebtView[] }) {
  const { t } = useTranslation();
  if (debts.length === 0) {
    return <EmptyState icon={<HandCoinsIcon />} title={t('vault.noDebts')} body={t('vault.noDebtsBody')} />;
  }
  return (
    <ul className="flex flex-col gap-2">
      {debts.map(({ debt, paidMinor, leftMinor, payments }) => (
        <li key={debt.uuid} className="flex flex-col gap-1.5 rounded-xl border bg-card p-4">
          <div className="flex flex-wrap items-baseline justify-between gap-x-3">
            <span className="font-extrabold">{debt.person}</span>
            <span className="tabular" dir="ltr">
              {debt.settledAt === null ? formatMoney(leftMinor, debt.currency) : t('vault.settled')}
            </span>
          </div>
          {debt.settledAt === null && paidMinor > 0 && (
            <>
              <div className="h-1.5 overflow-hidden rounded-full bg-muted">
                <div
                  className="h-full rounded-full bg-success"
                  style={{ width: `${Math.min((paidMinor / debt.amountMinor) * 100, 100)}%` }}
                />
              </div>
              <span className="text-xs text-muted-foreground tabular" dir="ltr">
                {t('vault.paidOf', {
                  paid: formatMoney(paidMinor, debt.currency),
                  total: formatMoney(debt.amountMinor, debt.currency),
                })}
              </span>
            </>
          )}
          <span className="text-xs text-muted-foreground">
            {[
              debt.payOffBy ? t('vault.dueOn', { day: formatDay(debt.payOffBy) }) : null,
              payments.length > 0 ? t('vault.payments', { count: payments.length }) : null,
              debt.note,
            ]
              .filter(Boolean)
              .join(' · ')}
          </span>
        </li>
      ))}
    </ul>
  );
}

/**
 * The Vault: the wallet, savings and debts, each a sum of its own
 * movements rather than a stored balance (W2). Money is moved on the
 * phone — this is the ledger, read.
 */
export function VaultPanel() {
  const { t } = useTranslation();
  const { db } = useHarvest();
  const currency = useDefaultCurrency();
  const [open, setOpen] = useState<Account>('wallet');
  const vault = useLiveQuery(() => readVault(db), [db]);
  if (!vault) return null;

  const pot = vault.pots.find((one) => one.account === open) ?? vault.pots[0]!;
  const icon = { wallet: <WalletIcon />, savings: <PiggyBankIcon /> } as const;

  return (
    <div className="flex flex-col gap-4">
      <div className="grid gap-2 sm:grid-cols-3">
        {accounts.map((account) => {
          const each = vault.pots.find((one) => one.account === account)!;
          return (
            <button
              key={account}
              type="button"
              aria-pressed={open === account}
              onClick={() => setOpen(account)}
              className={`flex flex-col gap-1 rounded-xl border p-4 text-start outline-none focus-visible:ring-2 focus-visible:ring-ring ${
                open === account ? 'border-primary bg-card' : 'bg-card/60 hover:bg-card'
              }`}
            >
              <span className="flex items-center gap-2 text-sm font-bold text-muted-foreground [&_svg]:size-4">
                {icon[account]}
                {t(`vault.${account}`)}
              </span>
              <span className="text-xl font-extrabold">
                <Balances balances={each.balances} empty={t('vault.emptyPot')} />
              </span>
            </button>
          );
        })}
        <div className="flex flex-col gap-1 rounded-xl border bg-card/60 p-4">
          <span className="flex items-center gap-2 text-sm font-bold text-muted-foreground [&_svg]:size-4">
            <HandCoinsIcon />
            {t('vault.owed')}
          </span>
          <span className="text-xl font-extrabold tabular" dir="ltr">
            {formatMoney(vault.owedInDefault, currency)}
          </span>
        </div>
      </div>

      <section className="flex flex-col gap-2">
        <h2 className="flex items-center gap-2 px-1 text-sm font-extrabold text-muted-foreground">
          <ArrowLeftRightIcon className="size-4" aria-hidden />
          {t('vault.movements', { account: t(`vault.${pot.account}`) })}
        </h2>
        <Movements pot={pot} />
      </section>

      <section className="flex flex-col gap-2">
        <h2 className="px-1 text-sm font-extrabold text-muted-foreground">{t('vault.debts')}</h2>
        <Debts debts={vault.debts} />
      </section>

      <p className="flex items-center gap-2 text-xs text-muted-foreground">
        <SmartphoneIcon className="size-4" aria-hidden />
        {t('vault.phoneOnly')}
      </p>
    </div>
  );
}
