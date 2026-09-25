import { useLiveQuery } from 'dexie-react-hooks';
import {
  ChevronDownIcon,
  CircleCheckIcon,
  HandCoinsIcon,
  MinusIcon,
  PartyPopperIcon,
  PiggyBankIcon,
  PlusIcon,
  Trash2Icon,
  TriangleAlertIcon,
  WalletIcon,
} from 'lucide-react';
import { useEffect, useState, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog';
import { Button } from '@/components/ui/button';
import { formatDate, formatDay, formatMoney } from '@/lib/format';
import { cn } from '@/lib/utils';
import { EmptyState } from '../components/bits';
import { DebtDialog } from '../components/debt-dialog';
import { Balances, moneyError } from '../components/money-bits';
import { MoneyDialog } from '../components/money-dialog';
import { MoveFilterBar, MovesLedger } from '../components/money-ledger';
import { useHarvest, useHarvestDay } from '../context';
import { readSetting, settingKeys } from '../data/settings';
import {
  type Account,
  type DebtPaymentRow,
  type DebtView,
  type MoveFilter,
  type PotView,
  emptyFilter,
  matchesFilter,
  readVault,
} from '../data/vault';
import { useDefaultCurrency } from '../hooks';

type Section = Account | 'debts';

type Open =
  | { kind: 'walletAdd' | 'walletTake' | 'deposit' | 'withdraw' }
  | { kind: 'pay'; debt: DebtView }
  | { kind: 'debt' }
  | null;

/** A pot's balances as a map, zero balances dropped, for the dialogs' caps. */
function balanceMap(pot: PotView | undefined): Record<string, number> {
  return Object.fromEntries((pot?.balances ?? []).filter(([, minor]) => minor !== 0));
}

/** A section's hero: its title, its per-currency balances, its actions. */
function Hero({ icon, title, aside, tone, children, actions }: { icon: ReactNode; title: string; aside?: ReactNode; tone: string; children: ReactNode; actions: ReactNode }) {
  return (
    <section className={cn('flex flex-col gap-3 rounded-2xl border p-5', tone)} aria-label={title}>
      <div className="flex items-center gap-2 text-sm font-extrabold text-muted-foreground [&_svg]:size-5">
        {icon}
        <span className="flex-1">{title}</span>
        {aside}
      </div>
      {children}
      <div className="flex flex-wrap gap-2">{actions}</div>
    </section>
  );
}

function DebtCard({ view, onPay, onRemovePayment }: { view: DebtView; onPay: () => void; onRemovePayment: (payment: DebtPaymentRow) => void }) {
  const { t } = useTranslation();
  const [expanded, setExpanded] = useState(false);
  const { debt, paidMinor, leftMinor, payments } = view;
  const ratio = debt.amountMinor === 0 ? 1 : Math.min(paidMinor / debt.amountMinor, 1);
  const panel = `payments-${debt.uuid}`;
  return (
    <li className="flex flex-col gap-2 rounded-xl border bg-card p-4">
      <div className="flex items-start gap-3">
        <HandCoinsIcon className="mt-0.5 size-5 shrink-0 text-sun" aria-hidden />
        <div className="flex min-w-0 flex-1 flex-col">
          <span className="truncate font-extrabold">{debt.person}</span>
          {(debt.payOffBy || debt.note) && (
            <span className="truncate text-xs text-muted-foreground">
              {[debt.payOffBy ? t('vault.dueOn', { day: formatDay(debt.payOffBy) }) : null, debt.note].filter(Boolean).join(' · ')}
            </span>
          )}
        </div>
        <span className="text-lg font-extrabold tabular" dir="ltr">
          {formatMoney(leftMinor, debt.currency)}
        </span>
      </div>
      <div
        className="h-2 overflow-hidden rounded-full bg-muted"
        role="progressbar"
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={Math.round(ratio * 100)}
        aria-label={t('vault.paidOf', { paid: formatMoney(paidMinor, debt.currency), total: formatMoney(debt.amountMinor, debt.currency) })}
      >
        <div className="h-full rounded-full bg-success" style={{ width: `${ratio * 100}%` }} />
      </div>
      <div className="flex flex-wrap items-center gap-2">
        <span className="flex-1 text-xs font-bold text-muted-foreground tabular" dir="auto">
          {t('vault.paidOf', { paid: formatMoney(paidMinor, debt.currency), total: formatMoney(debt.amountMinor, debt.currency) })}
        </span>
        {payments.length > 0 && (
          <Button variant="ghost" size="sm" aria-expanded={expanded} aria-controls={panel} onClick={() => setExpanded(!expanded)}>
            <ChevronDownIcon className={cn('transition-transform', expanded && 'rotate-180')} />
            {t('vault.showPayments', { count: payments.length })}
          </Button>
        )}
        <Button variant="secondary" size="sm" onClick={onPay}>
          {t('vault.debtPay')}
        </Button>
      </div>
      {expanded && payments.length > 0 && <PaymentsList id={panel} payments={payments} currency={debt.currency} onRemove={onRemovePayment} />}
    </li>
  );
}

/**
 * A debt's payments, newest first, each one removable: a payment logged
 * by mistake goes, and a debt it had settled reopens ([[Audit-v2-Beta]]
 * N-01). The same list sits under an open debt and a settled one.
 */
function PaymentsList({ id, payments, currency, onRemove }: { id: string; payments: DebtPaymentRow[]; currency: string; onRemove: (payment: DebtPaymentRow) => void }) {
  const { t } = useTranslation();
  return (
    <ul id={id} className="flex flex-col divide-y border-t pt-1">
      {payments.map((payment) => (
        <li key={payment.uuid} className="flex items-center gap-3 py-1.5">
          <span className="flex min-w-0 flex-1 flex-col">
            <span className="text-sm font-bold">{formatDay(payment.harvestDay)}</span>
            <span className="text-xs text-muted-foreground">{formatDate(payment.loggedAt, { timeStyle: 'short' })}</span>
          </span>
          <span className="font-extrabold tabular" dir="ltr">
            −{formatMoney(payment.amountMinor, currency)}
          </span>
          <Button
            variant="ghost"
            size="icon-sm"
            aria-label={t('vault.removePayment', { amount: formatMoney(payment.amountMinor, currency) })}
            onClick={() => onRemove(payment)}
          >
            <Trash2Icon />
          </Button>
        </li>
      ))}
    </ul>
  );
}

/**
 * A settled debt, folded into the quiet list: what it was, and its
 * payments one tap away, so a mistaken last payment can still be taken
 * back. [cheer] plays the small celebration the moment it settles.
 */
function SettledDebt({ view, cheer, onRemovePayment }: { view: DebtView; cheer: boolean; onRemovePayment: (payment: DebtPaymentRow) => void }) {
  const { t } = useTranslation();
  const [expanded, setExpanded] = useState(false);
  const { debt, payments } = view;
  const panel = `payments-${debt.uuid}`;
  return (
    <li className="flex flex-col px-4 py-2.5">
      <div className="flex flex-wrap items-center gap-3">
        <span className="relative flex">
          {cheer && <span className="absolute inset-0 rounded-full bg-success/50 motion-safe:animate-ping" aria-hidden />}
          <CircleCheckIcon className="relative size-4 shrink-0 text-success" aria-hidden />
        </span>
        <span className="flex min-w-0 flex-1 flex-col">
          <span className="truncate font-bold">{debt.person}</span>
          <span className="text-xs text-muted-foreground">{t('vault.settled')}</span>
        </span>
        <span className="font-extrabold text-muted-foreground tabular" dir="ltr">
          {formatMoney(debt.amountMinor, debt.currency)}
        </span>
        {payments.length > 0 && (
          <Button variant="ghost" size="sm" aria-expanded={expanded} aria-controls={panel} onClick={() => setExpanded(!expanded)}>
            <ChevronDownIcon className={cn('transition-transform', expanded && 'rotate-180')} />
            {t('vault.showPayments', { count: payments.length })}
          </Button>
        )}
      </div>
      {expanded && payments.length > 0 && <PaymentsList id={panel} payments={payments} currency={debt.currency} onRemove={onRemovePayment} />}
    </li>
  );
}

/**
 * The Vault ([[Finances]] The Vault): three tiles — wallet, savings,
 * debts — each always showing its total in the default currency, and
 * under them the chosen section's balances, its actions and its own
 * ledger. Every movement is a row; balances are sums (W2), and money in
 * one currency is never added to money in another.
 */
export function VaultPanel() {
  const { t } = useTranslation();
  const { db, vault: repository } = useHarvest();
  const currency = useDefaultCurrency();
  const [section, setSection] = useState<Section>('wallet');
  // One filter for both pots: narrowing to food and switching pot
  // stays narrowed to food.
  const [filter, setFilter] = useState<MoveFilter>(emptyFilter);
  const [open, setOpen] = useState<Open>(null);
  const [removing, setRemoving] = useState<DebtPaymentRow | null>(null);
  // The debt that just settled, for the moment its check lights up.
  const [cheering, setCheering] = useState<string | null>(null);
  useEffect(() => {
    if (cheering === null) return;
    const timer = setTimeout(() => setCheering(null), 2000);
    return () => clearTimeout(timer);
  }, [cheering]);
  const today = useHarvestDay();
  const vault = useLiveQuery(() => readVault(db, today), [db, today.key]);
  const budget = useLiveQuery(async () => Number((await readSetting(db, settingKeys.monthlyBudget)) ?? 0), [db]);
  if (!vault) return null;

  const wallet = vault.pots.find((pot) => pot.account === 'wallet');
  const savings = vault.pots.find((pot) => pot.account === 'savings');
  const walletBalances = balanceMap(wallet);
  const savingsBalances = balanceMap(savings);
  // Savings below a tenth of the monthly budget turn the section red.
  const low = Object.keys(savingsBalances).length > 0 && (budget ?? 0) > 0 && (savings?.totalInDefault ?? 0) < Math.trunc((budget ?? 0) / 10);
  const openDebts = vault.debts.filter((view) => view.debt.settledAt === null);
  const settled = vault.debts.filter((view) => view.debt.settledAt !== null);
  const owed = new Map<string, number>();
  for (const view of openDebts) owed.set(view.debt.currency, (owed.get(view.debt.currency) ?? 0) + view.leftMinor);

  const tiles: { key: Section; icon: ReactNode; label: string; total: number }[] = [
    { key: 'wallet', icon: <WalletIcon />, label: t('vault.wallet'), total: wallet?.totalInDefault ?? 0 },
    { key: 'savings', icon: <PiggyBankIcon />, label: t('vault.savings'), total: savings?.totalInDefault ?? 0 },
    { key: 'debts', icon: <HandCoinsIcon />, label: t('vault.owed'), total: vault.owedInDefault },
  ];

  const pot = section === 'savings' ? savings : wallet;
  const moves = pot?.movements ?? [];
  const shown = moves.filter((row) => matchesFilter(filter, row));

  /** Money in or out of the wallet by hand, said so, with the way back ([[Finances]] The Vault). */
  async function moveWallet(deltaMinor: number, currency: string, note: string | null) {
    const uuid = await repository.moveWallet(deltaMinor, currency, note);
    const amount = formatMoney(Math.abs(deltaMinor), currency);
    const undo = () => repository.removeMove(uuid).catch((failure: unknown) => void toast.error(moneyError(t, failure)));
    toast.success(t(deltaMinor > 0 ? 'vaultWeb.walletAdded' : 'vaultWeb.walletTaken', { amount }), {
      action: { label: t('common.undo'), onClick: () => void undo() },
    });
  }

  /**
   * A payment, and when it is the last one the small celebration the
   * spec promises: the debt folds into Settled with its check lit.
   */
  async function pay(view: DebtView, minor: number, fromWallet: boolean, note: string | null) {
    await repository.payDebt(view.debt.uuid, minor, fromWallet, note);
    const amount = formatMoney(minor, view.debt.currency);
    if (minor >= view.leftMinor) {
      setCheering(view.debt.uuid);
      toast.success(t('vaultWeb.debtSettled', { person: view.debt.person }), {
        icon: <PartyPopperIcon className="size-4 text-sun" />,
        duration: 6000,
      });
    } else {
      toast.success(t('vaultWeb.debtPaid', { amount, person: view.debt.person }));
    }
  }

  async function removePayment(payment: DebtPaymentRow) {
    await repository.removePayment(payment.uuid);
    toast(t('vault.paymentRemoved'), {
      action: { label: t('common.undo'), onClick: () => void repository.restorePayment(payment.uuid) },
    });
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="grid grid-cols-3 gap-2" role="group" aria-label={t('vault.title')}>
        {tiles.map((tile) => (
          <button
            key={tile.key}
            type="button"
            aria-pressed={section === tile.key}
            onClick={() => setSection(tile.key)}
            className={cn(
              'flex min-w-0 flex-col gap-1 rounded-xl border p-3 text-start outline-none focus-visible:ring-2 focus-visible:ring-ring sm:p-4',
              section === tile.key ? 'border-primary bg-card' : 'bg-card/60 hover:bg-card',
              tile.key === 'savings' && low && 'border-destructive',
            )}
          >
            <span className="flex items-center gap-1.5 truncate text-xs font-bold text-muted-foreground sm:text-sm [&_svg]:size-4">
              {tile.icon}
              {tile.label}
            </span>
            <span className="truncate text-base font-extrabold tabular sm:text-xl" dir="ltr">
              {formatMoney(tile.total, currency)}
            </span>
          </button>
        ))}
      </div>

      {section === 'wallet' && (
        <Hero
          icon={<WalletIcon className="text-primary" />}
          title={t('vault.wallet')}
          tone="bg-primary/5"
          actions={
            <>
              <Button onClick={() => setOpen({ kind: 'walletAdd' })}>
                <PlusIcon />
                {t('vault.walletAdd')}
              </Button>
              <Button variant="outline" disabled={Object.keys(walletBalances).length === 0} onClick={() => setOpen({ kind: 'walletTake' })}>
                <MinusIcon />
                {t('vault.walletTake')}
              </Button>
            </>
          }
        >
          <Balances balances={wallet?.balances ?? []} rates={vault.rates} />
        </Hero>
      )}

      {section === 'savings' && (
        <Hero
          icon={<PiggyBankIcon className={low ? 'text-destructive' : 'text-success'} />}
          title={t('vault.savings')}
          tone={low ? 'border-destructive bg-destructive/5' : 'bg-success/5'}
          aside={
            low && (
              <span className="flex items-center gap-1 text-xs font-extrabold text-destructive">
                <TriangleAlertIcon className="size-4" aria-hidden />
                {t('vault.savingsLow')}
              </span>
            )
          }
          actions={
            <>
              <Button onClick={() => setOpen({ kind: 'deposit' })}>
                <PlusIcon />
                {t('vault.savingsDeposit')}
              </Button>
              <Button variant="outline" disabled={Object.keys(savingsBalances).length === 0} onClick={() => setOpen({ kind: 'withdraw' })}>
                <MinusIcon />
                {t('vault.savingsWithdraw')}
              </Button>
            </>
          }
        >
          <Balances balances={savings?.balances ?? []} rates={vault.rates} />
        </Hero>
      )}

      {section !== 'debts' && (
        <section className="flex flex-col gap-2" aria-labelledby="vault-moves">
          <h2 id="vault-moves" className="px-1 text-sm font-extrabold text-muted-foreground">
            {t('vault.moves')}
          </h2>
          <MoveFilterBar filter={filter} onChange={setFilter} matches={shown.length} total={moves.length} />
          <MovesLedger rows={shown} total={moves.length} rates={vault.rates} empty={t('vault.noMovements')} />
        </section>
      )}

      {section === 'debts' && (
        <>
          <Hero
            icon={<HandCoinsIcon className="text-sun" />}
            title={t('vault.owed')}
            tone="bg-sun/5"
            aside={<span className="text-xs font-extrabold">{t('vault.openDebts', { count: openDebts.length })}</span>}
            actions={
              <Button onClick={() => setOpen({ kind: 'debt' })}>
                <PlusIcon />
                {t('vault.addDebt')}
              </Button>
            }
          >
            <Balances balances={[...owed.entries()]} rates={vault.rates} />
          </Hero>
          {vault.debts.length === 0 && <EmptyState icon={<HandCoinsIcon />} title={t('vault.noDebts')} body={t('vault.noDebtsBody')} />}
          {openDebts.length > 0 && (
            <section className="flex flex-col gap-2" aria-labelledby="debts-open">
              <h2 id="debts-open" className="px-1 text-sm font-extrabold text-muted-foreground">
                {t('vault.debtOpen')}
              </h2>
              <ul className="flex flex-col gap-2">
                {openDebts.map((view) => (
                  <DebtCard key={view.debt.uuid} view={view} onPay={() => setOpen({ kind: 'pay', debt: view })} onRemovePayment={setRemoving} />
                ))}
              </ul>
            </section>
          )}
          {settled.length > 0 && (
            <section className="flex flex-col gap-2" aria-labelledby="debts-settled">
              <h2 id="debts-settled" className="px-1 text-sm font-extrabold text-muted-foreground">
                {t('vault.debtSettledSection')}
              </h2>
              <ul className="flex flex-col divide-y rounded-xl border bg-card">
                {settled.map((view) => (
                  <SettledDebt key={view.debt.uuid} view={view} cheer={view.debt.uuid === cheering} onRemovePayment={setRemoving} />
                ))}
              </ul>
            </section>
          )}
        </>
      )}

      {(open?.kind === 'walletAdd' || open?.kind === 'walletTake') && (
        <MoneyDialog
          title={t(open.kind === 'walletAdd' ? 'vault.walletAddTitle' : 'vault.walletTakeTitle')}
          initialCurrency={open.kind === 'walletTake' && !(currency in walletBalances) ? (Object.keys(walletBalances)[0] ?? currency) : currency}
          // Taking out more than the wallet holds is a typo, not a wish.
          maxMinor={open.kind === 'walletTake' ? walletBalances : undefined}
          description={t(open.kind === 'walletAdd' ? 'vaultWeb.walletAddLead' : 'vaultWeb.walletTakeLead')}
          onSubmit={(entry) => moveWallet(open.kind === 'walletAdd' ? entry.minor : -entry.minor, entry.currency, entry.note)}
          onClose={() => setOpen(null)}
        />
      )}
      {open?.kind === 'deposit' && (
        <MoneyDialog
          title={t('vault.savingsDeposit')}
          description={t('vaultWeb.depositLead')}
          initialCurrency={currency}
          walletBalances={walletBalances}
          onSubmit={async (entry) => {
            await repository.depositSavings(entry.minor, entry.currency, entry.fromWallet, entry.note);
            toast.success(t('vaultWeb.saved', { amount: formatMoney(entry.minor, entry.currency) }));
          }}
          onClose={() => setOpen(null)}
        />
      )}
      {open?.kind === 'withdraw' && (
        <MoneyDialog
          title={t('vault.savingsWithdraw')}
          description={t('vault.withdrawToWallet')}
          initialCurrency={currency in savingsBalances ? currency : (Object.keys(savingsBalances)[0] ?? currency)}
          lockCurrency={Object.keys(savingsBalances).length === 1}
          maxMinor={savingsBalances}
          onSubmit={async (entry) => {
            await repository.withdrawSavings(entry.minor, entry.currency, entry.note);
            toast.success(t('vaultWeb.withdrawn', { amount: formatMoney(entry.minor, entry.currency) }));
          }}
          onClose={() => setOpen(null)}
        />
      )}
      {open?.kind === 'pay' && (
        <MoneyDialog
          title={t('vault.debtPayTitle', { person: open.debt.debt.person })}
          initialCurrency={open.debt.debt.currency}
          lockCurrency
          initialMinor={open.debt.leftMinor}
          maxMinor={{ [open.debt.debt.currency]: open.debt.leftMinor }}
          walletBalances={walletBalances}
          description={t('vaultWeb.payLead', { amount: formatMoney(open.debt.leftMinor, open.debt.debt.currency) })}
          onSubmit={(entry) => pay(open.debt, entry.minor, entry.fromWallet, entry.note)}
          onClose={() => setOpen(null)}
        />
      )}
      {open?.kind === 'debt' && <DebtDialog onClose={() => setOpen(null)} />}

      <AlertDialog open={removing !== null} onOpenChange={(value) => !value && setRemoving(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>{t('vault.removePaymentTitle')}</AlertDialogTitle>
            <AlertDialogDescription>{t('vault.removePaymentBody')}</AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>{t('common.cancel')}</AlertDialogCancel>
            <AlertDialogAction
              onClick={() => {
                if (removing) void removePayment(removing);
              }}
            >
              {t('common.remove')}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
