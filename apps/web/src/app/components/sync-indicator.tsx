import {
  CloudAlertIcon,
  CloudCheckIcon,
  CloudOffIcon,
  LoaderIcon,
  KeyRoundIcon,
  LockIcon,
  MailWarningIcon,
  UserXIcon,
} from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { useHarvest, useSyncStatus } from '../context';
import { usePrivateKey } from '../hooks';
import { useOnline } from './pin-state';
import { useRelativeTime } from './relative-time';
import { runAction } from '@/lib/actions';

/** The sync status, always in view; clicking it syncs now. */
export function SyncIndicator({ compact = false }: { compact?: boolean }) {
  const { t } = useTranslation();
  const { engine } = useHarvest();
  const status = useSyncStatus();
  const ago = useRelativeTime(status.lastSyncedAt);
  // The browser's word that the network went counts at once (W6-02).
  const online = useOnline();
  const unlocked = usePrivateKey();
  // Without the sync PIN nothing syncs since Phase 7: it never says "synced".
  const phase = !online ? 'offline' : unlocked === false && status.phase === 'idle' ? 'waitingForPin' : status.phase;

  const view = {
    idle: { icon: CloudCheckIcon, label: status.lastSyncedAt ? t('sync.syncedAgo', { ago }) : t('sync.notYet') },
    waitingForPin: { icon: KeyRoundIcon, label: t('sync.waitingForPin') },
    syncing: { icon: LoaderIcon, label: status.firstSync ? t('sync.firstSync') : t('sync.syncing') },
    offline: { icon: CloudOffIcon, label: t('sync.offline') },
    signedOut: { icon: UserXIcon, label: t('sync.signedOut') },
    unverified: { icon: MailWarningIcon, label: t('sync.unverified') },
    error: { icon: CloudAlertIcon, label: t('sync.error') },
  }[phase];
  const Icon = view.icon;
  const waiting = status.pending + status.locked;

  return (
    <Button
      variant="ghost"
      size="sm"
      onClick={() => runAction(() => engine.sync())}
      aria-label={`${view.label}. ${waiting ? t('sync.waiting', { count: waiting }) : ''} ${t('sync.syncNow')}`}
      title={t('sync.syncNow')}
      className="gap-1.5 font-bold"
    >
      <Icon className={cn(status.phase === 'syncing' && 'animate-spin', status.phase === 'error' && 'text-destructive')} />
      {!compact && <span className="max-w-40 truncate text-xs">{view.label}</span>}
      {waiting > 0 && (
        <span className="rounded-full bg-muted px-1.5 text-xs tabular" aria-hidden>
          {status.locked > 0 && <LockIcon className="me-0.5 inline size-3" />}
          {waiting}
        </span>
      )}
    </Button>
  );
}
