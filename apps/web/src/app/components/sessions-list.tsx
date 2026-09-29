import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { MonitorSmartphoneIcon } from 'lucide-react';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { api } from '@/lib/api';
import { formatDate } from '@/lib/format';
import { runAction } from '@/lib/actions';
import { useRelativeTime } from './relative-time';

/** When a sign-in was made, in words: "signed in 2 hours ago". */
function SignedIn({ at }: { at: string }) {
  const { t } = useTranslation();
  const ago = useRelativeTime(at);
  return <>{t('settings.signedInAgo', { ago })}</>;
}

/**
 * The account's signed-in devices: each by what it is and how long ago
 * it signed in, this one first, the newest three unless asked for all,
 * and one button for every other (W6-27).
 */
export function SessionsList() {
  const { t } = useTranslation();
  const client = useQueryClient();
  const [all, setAll] = useState(false);
  const sessions = useQuery({ queryKey: ['sessions'], queryFn: () => api.sessions(), retry: 1 });
  const refresh = () => runAction(() => client.invalidateQueries({ queryKey: ['sessions'] }));
  const revoke = useMutation({
    mutationFn: (id: string) => api.revokeSession(id),
    onSuccess: refresh,
    onError: () => toast.error(t('common.somethingWrong')),
  });
  const revokeOthers = useMutation({
    mutationFn: async (ids: string[]) => {
      for (const id of ids) await api.revokeSession(id);
    },
    onSuccess: () => {
      refresh();
      toast.success(t('settings.signedOutOthers'));
    },
    onError: () => {
      refresh();
      toast.error(t('common.somethingWrong'));
    },
  });
  if (sessions.isPending) return <p className="text-sm text-muted-foreground">{t('common.loading')}</p>;
  if (sessions.isError) return <p className="text-sm text-muted-foreground">{t('settings.sessionsOffline')}</p>;
  const sorted = [...sessions.data.sessions].sort(
    (a, b) => Number(b.current) - Number(a.current) || b.lastSeenAt.localeCompare(a.lastSeenAt),
  );
  const shown = all ? sorted : sorted.slice(0, 3);
  const others = sorted.filter((session) => !session.current).map((session) => session.id);
  const nameOf = (session: (typeof sorted)[number]) => session.deviceName ?? t(`settings.client.${session.client}`);
  return (
    <div className="flex flex-col gap-2">
      <ul className="flex flex-col gap-2">
        {shown.map((session) => (
          <li key={session.id} className="flex items-center gap-3 rounded-lg bg-muted/60 p-3">
            <MonitorSmartphoneIcon className="size-5 shrink-0 text-muted-foreground" aria-hidden />
            <div className="flex min-w-0 flex-1 flex-col">
              <span className="font-bold [overflow-wrap:anywhere]">
                {nameOf(session)}
                {session.current && (
                  <Badge variant="secondary" className="ms-2">
                    {t('settings.thisDevice')}
                  </Badge>
                )}
              </span>
              <span className="text-xs text-muted-foreground">
                <SignedIn at={session.createdAt} />
                {' · '}
                {t('settings.lastSeen', { last: formatDate(session.lastSeenAt, { dateStyle: 'medium', timeStyle: 'short' }) })}
              </span>
            </div>
            {!session.current && (
              <Button
                variant="ghost"
                size="sm"
                disabled={revoke.isPending || revokeOthers.isPending}
                onClick={() => revoke.mutate(session.id)}
                aria-label={t('settings.signOutDevice', { name: nameOf(session) })}
              >
                {t('settings.signOut')}
              </Button>
            )}
          </li>
        ))}
      </ul>
      <div className="flex flex-wrap gap-2">
        {sorted.length > 3 && (
          <Button variant="link" size="sm" className="h-auto px-0" onClick={() => setAll(!all)}>
            {all ? t('settings.fewerDevices') : t('settings.allDevices', { count: sorted.length })}
          </Button>
        )}
        {others.length > 1 && (
          <Button variant="outline" size="sm" disabled={revokeOthers.isPending} onClick={() => revokeOthers.mutate(others)}>
            {t('settings.signOutOthers')}
          </Button>
        )}
      </div>
    </div>
  );
}
