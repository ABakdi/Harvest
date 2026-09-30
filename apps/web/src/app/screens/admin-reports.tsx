import { reportStatuses, type AdminReport } from '@harvest/contracts';
import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Trash2Icon } from 'lucide-react';
import { useEffect, useState } from 'react';
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
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogTitle } from '@/components/ui/dialog';
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group';
import { background } from '@/lib/actions';
import type { api } from '@/lib/api';
import { formatBytes, formatDate } from '@/lib/format';

/**
 * The reports people sent ([[Admin]], F12-5): newest first, each with its
 * words, its pictures and its recording, the platform and version it came
 * from, and nothing that says who sent it — there is nothing to say.
 */

export type ReportsApi = Pick<typeof api, 'adminReports' | 'setReportStatus' | 'deleteReport' | 'reportAttachment'>;

type Filter = AdminReport['status'] | 'all';

/** How many reports are still new, for the tab's badge. */
export function useUnreadReports(source: ReportsApi): number {
  const query = useQuery({ queryKey: ['admin', 'reports', 'unread'], queryFn: () => source.adminReports({ limit: 1 }), retry: 1 });
  return query.data?.unread ?? 0;
}

export function Reports({ source }: { source: ReportsApi }) {
  const { t } = useTranslation();
  const queryClient = useQueryClient();
  const [filter, setFilter] = useState<Filter>('all');
  const [deleting, setDeleting] = useState<AdminReport | null>(null);
  const reports = useInfiniteQuery({
    queryKey: ['admin', 'reports', filter],
    queryFn: ({ pageParam }) =>
      source.adminReports({ ...(filter === 'all' ? {} : { status: filter }), ...(pageParam ? { cursor: pageParam } : {}) }),
    initialPageParam: null as string | null,
    getNextPageParam: (last) => last.next,
    retry: 1,
  });
  const refresh = () => queryClient.invalidateQueries({ queryKey: ['admin', 'reports'] });
  const status = useMutation({
    mutationFn: ({ id, next }: { id: string; next: AdminReport['status'] }) => source.setReportStatus(id, next),
    onSuccess: () => background(refresh()),
    onError: () => toast.error(t('common.somethingWrong')),
  });
  const remove = useMutation({
    mutationFn: (id: string) => source.deleteReport(id),
    onSuccess: () => {
      toast.success(t('admin.reports.deleted'));
      background(refresh());
    },
    onError: () => toast.error(t('common.somethingWrong')),
  });

  const rows = reports.data?.pages.flatMap((page) => page.reports) ?? [];
  return (
    <div className="flex flex-col gap-3">
      <ToggleGroup
        type="single"
        value={filter}
        onValueChange={(value) => value && setFilter(value as Filter)}
        className="self-start"
        aria-label={t('admin.reports.filter')}
      >
        <ToggleGroupItem value="all">{t('admin.reports.status.all')}</ToggleGroupItem>
        {reportStatuses.map((value) => (
          <ToggleGroupItem key={value} value={value}>
            {t(`admin.reports.status.${value}`)}
          </ToggleGroupItem>
        ))}
      </ToggleGroup>
      {reports.isPending ? (
        <p className="text-sm text-muted-foreground">{t('common.loading')}</p>
      ) : reports.isError ? (
        <p className="text-sm text-muted-foreground">{t('admin.failed')}</p>
      ) : rows.length === 0 ? (
        <p className="text-sm text-muted-foreground">{t('admin.reports.none')}</p>
      ) : (
        <ul className="flex flex-col gap-3">
          {rows.map((report) => (
            <ReportCard
              key={report.id}
              report={report}
              source={source}
              onStatus={(next) => status.mutate({ id: report.id, next })}
              onDelete={() => setDeleting(report)}
            />
          ))}
        </ul>
      )}
      {reports.hasNextPage && (
        <Button variant="outline" className="self-start" disabled={reports.isFetchingNextPage} onClick={() => background(reports.fetchNextPage())}>
          {t('admin.more')}
        </Button>
      )}
      <AlertDialog open={deleting !== null} onOpenChange={(open) => !open && setDeleting(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>{t('admin.reports.deleteTitle')}</AlertDialogTitle>
            <AlertDialogDescription>{t('admin.reports.deleteBody')}</AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>{t('common.cancel')}</AlertDialogCancel>
            <AlertDialogAction
              destructive
              onClick={() => {
                if (deleting) remove.mutate(deleting.id);
                setDeleting(null);
              }}
            >
              {t('admin.reports.delete')}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}

function ReportCard({
  report,
  source,
  onStatus,
  onDelete,
}: {
  report: AdminReport;
  source: ReportsApi;
  onStatus: (next: AdminReport['status']) => void;
  onDelete: () => void;
}) {
  const { t } = useTranslation();
  const [open, setOpen] = useState(false);
  const toggle = () => {
    const next = !open;
    setOpen(next);
    // Opening a new one is reading it.
    if (next && report.status === 'new') onStatus('read');
  };
  return (
    <li className="flex flex-col gap-2 rounded-xl border bg-card p-3">
      <button type="button" className="flex flex-col gap-1 text-start" aria-expanded={open} onClick={toggle}>
        <span className="flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
          <Badge variant={report.status === 'new' ? 'default' : 'secondary'}>{t(`admin.reports.status.${report.status}`)}</Badge>
          <span>{formatDate(report.createdAt, { dateStyle: 'medium', timeStyle: 'short' })}</span>
          <span>
            {t(`admin.platform.${report.platform}`, { defaultValue: report.platform })} · {report.appVersion}
          </span>
          {report.attachments.length > 0 && <span>{t('admin.reports.files', { count: report.attachments.length })}</span>}
        </span>
        <span className={open ? 'whitespace-pre-wrap text-sm' : 'line-clamp-2 whitespace-pre-wrap text-sm'}>{report.text}</span>
      </button>
      {open && (
        <>
          {report.attachments.length > 0 && (
            <div className="flex flex-wrap items-start gap-2">
              {report.attachments.map((attachment) => (
                <Attachment key={attachment.id} report={report} attachment={attachment} source={source} />
              ))}
            </div>
          )}
          <div className="flex flex-wrap items-center justify-between gap-2">
            <span className="flex gap-1">
              {reportStatuses.map((value) => (
                <Button
                  key={value}
                  size="sm"
                  variant={report.status === value ? 'secondary' : 'ghost'}
                  aria-pressed={report.status === value}
                  onClick={() => onStatus(value)}
                >
                  {t(`admin.reports.mark.${value}`)}
                </Button>
              ))}
            </span>
            <Button size="sm" variant="ghost" className="text-destructive" onClick={onDelete}>
              <Trash2Icon />
              {t('admin.reports.delete')}
            </Button>
          </div>
        </>
      )}
    </li>
  );
}

/** One picture or recording, fetched with the admin's session and shown from an object URL. */
function Attachment({
  report,
  attachment,
  source,
}: {
  report: AdminReport;
  attachment: AdminReport['attachments'][number];
  source: ReportsApi;
}) {
  const { t } = useTranslation();
  const [url, setUrl] = useState<string | null>(null);
  const [failed, setFailed] = useState(false);
  const [large, setLarge] = useState(false);
  useEffect(() => {
    let live = true;
    let made: string | null = null;
    source
      .reportAttachment(report.id, attachment.id)
      .then((blob) => {
        if (!live) return;
        made = URL.createObjectURL(blob);
        setUrl(made);
      })
      .catch(() => {
        if (live) setFailed(true);
      });
    return () => {
      live = false;
      if (made) URL.revokeObjectURL(made);
    };
  }, [source, report.id, attachment.id]);

  if (failed) return <span className="text-xs text-muted-foreground">{t('admin.reports.fileFailed')}</span>;
  if (!url) return <span className="size-24 animate-pulse rounded-lg bg-muted" aria-label={t('common.loading')} />;
  if (attachment.kind === 'audio') {
    return (
      <span className="flex items-center gap-2">
        <audio controls src={url} className="h-9 max-w-full" aria-label={t('admin.reports.recording')} />
        <span className="text-xs text-muted-foreground tabular">{formatBytes(attachment.bytes)}</span>
      </span>
    );
  }
  return (
    <>
      <button type="button" onClick={() => setLarge(true)} aria-label={t('admin.reports.openPicture')}>
        <img src={url} alt={t('admin.reports.picture')} className="size-24 rounded-lg border object-cover" />
      </button>
      <Dialog open={large} onOpenChange={setLarge}>
        <DialogContent className="max-w-4xl">
          <DialogTitle className="sr-only">{t('admin.reports.picture')}</DialogTitle>
          <img src={url} alt={t('admin.reports.picture')} className="max-h-[80dvh] w-full object-contain" />
        </DialogContent>
      </Dialog>
    </>
  );
}
