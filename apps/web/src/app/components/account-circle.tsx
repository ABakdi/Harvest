import { ChartColumnIcon, KeyRoundIcon, LifeBuoyIcon, LogOutIcon, RefreshCwIcon, SettingsIcon, ShieldCheckIcon } from 'lucide-react';
import { useId, useState } from 'react';
import { ReportProblemDialog } from './report-problem';
import { useTranslation } from 'react-i18next';
import { Link } from 'react-router';
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
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Separator } from '@/components/ui/separator';
import { formatDate } from '@/lib/format';
import { cn } from '@/lib/utils';
import { useLeave } from '../app-root';
import { useHarvest, useSyncStatus } from '../context';
import { usePrivateKey } from '../hooks';
import type { SyncStatus } from '../sync/engine';
import { SessionsList } from './sessions-list';
import { StartOverDialog, SyncPinDialog } from './passphrase-prompt';
import { useOnline, usePinChosen } from './pin-state';
import { useRelativeTime } from './relative-time';
import { background, runAction } from '@/lib/actions';

/** The circle's status mark ([[Accounts]], the account circle). */
export type AccountMark = 'synced' | 'pending' | 'offline' | 'error';

/**
 * Green when everything has gone, amber while something waits, grey
 * offline, red when sync cannot go on (a failure, a session that ended,
 * an address not verified yet).
 */
export function accountMark(status: SyncStatus, online = true): AccountMark {
  // The browser's own word that the network went is taken at once, not after a sync fails (W6-02).
  if (status.phase === 'offline' || !online) return 'offline';
  if (status.phase === 'error' || status.phase === 'signedOut' || status.phase === 'unverified') return 'error';
  if (status.phase === 'syncing' || status.pending + status.locked > 0) return 'pending';
  return 'synced';
}

const markColour: Record<AccountMark, string> = {
  synced: 'bg-emerald-500',
  pending: 'bg-amber-500',
  offline: 'bg-zinc-400',
  error: 'bg-destructive',
};

/** The account's first letter, or nothing when it has none to give. */
function initialOf(name: string | null | undefined, email: string): string {
  const source = (name ?? '').trim() || email.trim();
  return Array.from(source)[0]?.toLocaleUpperCase() ?? '';
}

/**
 * The account circle ([[Accounts]], on the web): the account's initial
 * with the sync status on it, and a dot while this browser has no sync
 * PIN. It opens the account and sync sheet; the full account page stays
 * in Settings.
 */
export function AccountCircle({ className }: { className?: string }) {
  const { t } = useTranslation();
  const { user } = useHarvest();
  const status = useSyncStatus();
  const unlocked = usePrivateKey();
  const [open, setOpen] = useState(false);
  const id = useId();
  const online = useOnline();
  const mark = accountMark(status, online);
  const noPin = unlocked === false;
  const described = [t(`account.mark.${mark}`), noPin ? t('account.mark.noPin') : null].filter(Boolean).join('. ');

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        aria-label={t('account.label')}
        aria-describedby={`${id}-mark`}
        aria-haspopup="dialog"
        title={`${t('account.label')} · ${described}`}
        className={cn(
          'relative flex size-9 shrink-0 items-center justify-center rounded-full bg-primary/15 font-extrabold text-primary outline-none transition-colors hover:bg-primary/25 focus-visible:ring-2 focus-visible:ring-ring',
          className,
        )}
      >
        <span aria-hidden>{initialOf(user.displayName, user.email)}</span>
        <span id={`${id}-mark`} className="sr-only">
          {described}
        </span>
        <span
          data-mark={mark}
          aria-hidden
          className={cn('absolute -bottom-0.5 -end-0.5 size-3 rounded-full ring-2 ring-background', markColour[mark])}
        />
        {noPin && (
          <span data-no-pin aria-hidden className="absolute -end-0.5 -top-0.5 size-2.5 rounded-full bg-primary ring-2 ring-background" />
        )}
      </button>
      {open && <AccountSheet onClose={() => setOpen(false)} />}
    </>
  );
}

/** What the circle opens: the account, its sync, its PIN, its devices. */
function AccountSheet({ onClose }: { onClose: () => void }) {
  const { t } = useTranslation();
  const { user, engine, keyring } = useHarvest();
  const status = useSyncStatus();
  const unlocked = usePrivateKey();
  const leave = useLeave();
  const ago = useRelativeTime(status.lastSyncedAt);
  const [unlocking, setUnlocking] = useState(false);
  const [forgetting, setForgetting] = useState(false);
  const [changing, setChanging] = useState(false);
  const [reporting, setReporting] = useState(false);
  const [warning, setWarning] = useState<number | null>(null);
  const online = useOnline();
  const offline = status.phase === 'offline' || !online;
  const pinChosen = usePinChosen();

  // W5, as in Settings: signing out deletes what has not been sent, so it is said first.
  const signOut = async () => {
    await engine.refreshCounts();
    const waiting = engine.status.pending + engine.status.invalid + engine.status.locked;
    if (waiting > 0) setWarning(waiting);
    else leave.signOut();
  };

  const forget = async () => {
    await keyring.clear();
    await engine.refreshCounts();
    setForgetting(false);
    toast.success(t('syncPin.forgotten'));
  };

  return (
    <>
      <Dialog open onOpenChange={(next) => !next && onClose()}>
        <DialogContent className="max-h-[90dvh] overflow-y-auto sm:max-w-md">
          <DialogHeader>
            <DialogTitle>{t('account.label')}</DialogTitle>
            <DialogDescription className="flex flex-wrap items-center gap-x-2">
              <span className="font-bold text-foreground" dir="ltr">
                {user.email}
              </span>
              <span>{user.verifiedAt ? t('settings.verified') : t('settings.unverified')}</span>
            </DialogDescription>
          </DialogHeader>

          <section aria-label={t('settings.sync')} className="flex flex-col gap-2">
            <div className="flex flex-wrap items-center gap-2 text-sm">
              <Badge variant={offline ? 'outline' : 'secondary'} className="gap-1.5">
                <span aria-hidden className={cn('size-2 rounded-full', offline ? markColour.offline : markColour.synced)} />
                {offline ? t('account.offline') : t('account.online')}
              </Badge>
              <span className="text-muted-foreground">
                {t('settings.lastSynced')}:{' '}
                <span
                  title={
                    status.lastSyncedAt ? formatDate(status.lastSyncedAt, { dateStyle: 'medium', timeStyle: 'short' }) : undefined
                  }
                >
                  {status.lastSyncedAt ? ago : t('sync.notYet')}
                </span>
              </span>
            </div>
            <p className="text-sm">
              {status.pending + status.locked > 0
                ? t('settings.pending', { count: status.pending + status.locked })
                : t('account.allSent')}
            </p>
            {status.pinChanged ? (
              <p className="text-sm text-destructive">{t('syncPin.changedElsewhere')}</p>
            ) : (
              status.error && status.phase === 'error' && <p className="text-sm text-destructive">{status.error}</p>
            )}
            {status.refusedFor.includes('quota_exceeded') && <p className="text-sm">{t('sync.refusedQuota')}</p>}
            {status.refusedFor.some((code) => code === 'clock_ahead' || code === 'clock_too_far') && (
              <p className="text-sm">{t('sync.refusedClock')}</p>
            )}
            {status.unreadable > 0 && (
              <p className="text-sm text-destructive">{t('sync.unreadable', { count: status.unreadable })}</p>
            )}
            <Button
              variant="outline"
              size="sm"
              className="self-start"
              onClick={() => background(engine.sync())}
              disabled={status.phase === 'syncing' || offline}
              aria-describedby={offline ? 'account-offline-reason' : undefined}
            >
              <RefreshCwIcon className={status.phase === 'syncing' ? 'animate-spin' : undefined} />
              {t('sync.syncNow')}
            </Button>
            {offline && (
              <p id="account-offline-reason" className="text-xs text-muted-foreground">
                {t('account.syncWhenOnline')}
              </p>
            )}
          </section>

          <Separator />

          <section aria-labelledby="account-pin" className="flex flex-col gap-2">
            <h3 id="account-pin" className="text-sm font-bold">
              {t('syncPin.title')}
            </h3>
            {unlocked ? (
              <div className="flex flex-wrap items-center gap-2">
                <Badge variant="secondary" className="gap-1">
                  <ShieldCheckIcon />
                  {t('syncPin.setHere')}
                </Badge>
                <Button variant="link" size="sm" className="h-auto px-0" onClick={() => setChanging(true)}>
                  {t('syncPin.change')}
                </Button>
                <Button variant="link" size="sm" className="h-auto px-0" onClick={() => setForgetting(true)}>
                  {t('syncPin.forget')}
                </Button>
              </div>
            ) : (
              <>
                {/* None chosen yet on any device: choose one; else enter the one there is (W6-08). */}
                <p className="text-sm text-muted-foreground">{pinChosen === false ? t('syncPin.chooseWhy') : t('syncPin.waiting')}</p>
                <Button size="sm" className="self-start" onClick={() => setUnlocking(true)} disabled={unlocked === undefined}>
                  <KeyRoundIcon />
                  {pinChosen === false ? t('syncPin.chooseTitle') : t('syncPin.enter')}
                </Button>
              </>
            )}
          </section>

          <Separator />

          <section aria-labelledby="account-devices" className="flex flex-col gap-2">
            <h3 id="account-devices" className="text-sm font-bold">
              {t('settings.devices')}
            </h3>
            {offline ? <p className="text-sm text-muted-foreground">{t('account.devicesOffline')}</p> : <SessionsList />}
          </section>

          <div className="flex flex-wrap items-center justify-between gap-2">
            <Button variant="outline" onClick={() => runAction(signOut)}>
              <LogOutIcon />
              {t('settings.signOutHere')}
            </Button>
            <div className="flex flex-wrap items-center gap-1">
              {user.admin === true && (
                <Button asChild variant="link" size="sm">
                  <Link to="/app/admin" onClick={onClose}>
                    <ChartColumnIcon />
                    {t('admin.title')}
                  </Link>
                </Button>
              )}
              <Button variant="link" size="sm" onClick={() => setReporting(true)}>
                <LifeBuoyIcon />
                {t('report.open')}
              </Button>
              <Button asChild variant="link" size="sm">
                <Link to="/app/settings" onClick={onClose}>
                  <SettingsIcon />
                  {t('account.allSettings')}
                </Link>
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>

      {unlocking && <SyncPinDialog onClose={() => setUnlocking(false)} />}
      <ReportProblemDialog open={reporting} onOpenChange={setReporting} />
      {changing && (
        <StartOverDialog
          changing
          onClose={() => setChanging(false)}
          onDone={() => {
            // Changing is starting over while I still have it all: the
            // new PIN is chosen next, and what is here goes up under it.
            setChanging(false);
            setUnlocking(true);
          }}
        />
      )}

      <AlertDialog open={forgetting} onOpenChange={(next) => !next && setForgetting(false)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>{t('syncPin.forgetTitle')}</AlertDialogTitle>
            <AlertDialogDescription>{t('syncPin.forgetBody')}</AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>{t('common.cancel')}</AlertDialogCancel>
            <AlertDialogAction destructive onClick={() => runAction(forget)}>
              {t('syncPin.forget')}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      <AlertDialog open={warning !== null} onOpenChange={(next) => !next && setWarning(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>{t('settings.unsyncedTitle')}</AlertDialogTitle>
            <AlertDialogDescription>{t('settings.unsyncedBody', { count: warning ?? 0 })}</AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel onClick={() => background(engine.sync())}>{t('settings.syncFirst')}</AlertDialogCancel>
            <AlertDialogAction destructive onClick={() => leave.signOut()}>
              {t('settings.signOutAnyway')}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
}
