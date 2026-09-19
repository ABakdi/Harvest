import {
  CloudAlertIcon,
  CloudCheckIcon,
  CloudOffIcon,
  LoaderIcon,
  LockIcon,
  MailWarningIcon,
  UserXIcon,
} from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { useHarvest, useSyncStatus } from '../context';
import { useRelativeTime } from './relative-time';

/** The sync status, always in view; clicking it syncs now. */
export function SyncIndicator({ compact = false }: { compact?: boolean }) {
  const { t } = useTranslation();
  const { engine } = useHarvest();
  const status = useSyncStatus();
  const ago = useRelativeTime(status.lastSyncedAt);

  const view = {
    idle: { icon: CloudCheckIcon, label: status.lastSyncedAt ? t('sync.syncedAgo', { ago }) : t('sync.notYet') },
    syncing: { icon: LoaderIcon, label: status.firstSync ? t('sync.firstSync') : t('sync.syncing') },
    offline: { icon: CloudOffIcon, label: t('sync.offline') },
    signedOut: { icon: UserXIcon, label: t('sync.signedOut') },
    unverified: { icon: MailWarningIcon, label: t('sync.unverified') },
    error: { icon: CloudAlertIcon, label: t('sync.error') },
  }[status.phase];
  const Icon = view.icon;
  const waiting = status.pending + status.locked;

  return (
    <Button
      variant="ghost"
      size="sm"
      onClick={() => void engine.sync()}
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
