import {
  announcementBodyMax,
  announcementBodySchema,
  announcementTitleMax,
  type AdminOverview,
  type Announcement,
  type AnnouncementBody,
  type DailyStats,
} from '@harvest/contracts';
import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { MegaphoneIcon, SearchIcon, Trash2Icon, UsersIcon, ChartColumnIcon } from 'lucide-react';
import { useId, useState, type ReactNode } from 'react';
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
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Switch } from '@/components/ui/switch';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Textarea } from '@/components/ui/textarea';
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group';
import { background } from '@/lib/actions';
import { api } from '@/lib/api';
import { formatDate, formatDay, formatNumber } from '@/lib/format';
import { useDocumentTitle } from '@/lib/title';
import { cn } from '@/lib/utils';

/**
 * The admin panel ([[Admin]]): how Harvest is used, from the server's
 * own counts and the heartbeats devices chose to send, and the news I
 * write. Only an account the server names an admin reaches it; the
 * server checks again on every call.
 */

export type AdminApi = Pick<
  typeof api,
  | 'adminOverview'
  | 'adminHistory'
  | 'adminUsers'
  | 'adminAnnouncements'
  | 'createAnnouncement'
  | 'endAnnouncement'
  | 'deleteAnnouncement'
>;

export function AdminScreen({ source = api }: { source?: AdminApi }) {
  const { t } = useTranslation();
  useDocumentTitle(t('admin.title'));
  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-2xl font-extrabold">{t('admin.title')}</h1>
      <Tabs defaultValue="overview">
        <TabsList>
          <TabsTrigger value="overview">
            <ChartColumnIcon />
            {t('admin.tab.overview')}
          </TabsTrigger>
          <TabsTrigger value="users">
            <UsersIcon />
            {t('admin.tab.users')}
          </TabsTrigger>
          <TabsTrigger value="news">
            <MegaphoneIcon />
            {t('admin.tab.news')}
          </TabsTrigger>
        </TabsList>
        <TabsContent value="overview">
          <Overview source={source} />
        </TabsContent>
        <TabsContent value="users">
          <Users source={source} />
        </TabsContent>
        <TabsContent value="news">
          <News source={source} />
        </TabsContent>
      </Tabs>
    </div>
  );
}

// ------------------------------------------------------------- overview

function Overview({ source }: { source: AdminApi }) {
  const { t } = useTranslation();
  const overview = useQuery({ queryKey: ['admin', 'overview'], queryFn: () => source.adminOverview(), retry: 1 });
  if (overview.isPending) return <Loading />;
  if (overview.isError) return <Failed />;
  const data = overview.data;
  return (
    <div className="flex flex-col gap-4">
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <Stat
          label={t('admin.accounts')}
          value={data.accounts.total}
          detail={t('admin.accountsDetail', {
            verified: formatNumber(data.accounts.verified),
            today: formatNumber(data.accounts.newToday),
            week: formatNumber(data.accounts.newWeek),
            month: formatNumber(data.accounts.newMonth),
          })}
        />
        <Stat
          label={t('admin.activeToday')}
          value={data.active.today}
          detail={t('admin.activeDetail', { week: formatNumber(data.active.week), month: formatNumber(data.active.month) })}
        />
        <Stat
          label={t('admin.streaks')}
          value={data.streaks.sharing}
          detail={t('admin.streaksDetail', {
            median: formatNumber(data.streaks.median, { maximumFractionDigits: 1 }),
            mean: formatNumber(data.streaks.mean, { maximumFractionDigits: 1 }),
            longest: formatNumber(data.streaks.longest),
          })}
        />
        <Stat
          label={t('admin.downloads')}
          value={data.downloads?.total ?? null}
          detail={data.downloads ? t('admin.downloadsDetail', { releases: formatNumber(data.downloads.releases.length) }) : t('admin.downloadsUnknown')}
        />
      </div>
      <History source={source} />
      <div className="grid gap-3 lg:grid-cols-2">
        <Panel title={t('admin.streakBands')}>
          <Bars rows={data.streaks.bands.map((band) => ({ label: t('admin.band', { band: band.band }), value: band.accounts }))} />
        </Panel>
        <Panel title={t('admin.platforms')}>
          <Bars rows={data.platforms.map((row) => ({ label: t(`admin.platform.${row.platform}`, { defaultValue: row.platform }), value: row.accounts }))} />
        </Panel>
        <Panel title={t('admin.versions')}>
          <Bars rows={data.versions.map((row) => ({ label: row.version, value: row.accounts }))} />
        </Panel>
        <Panel title={t('admin.releases')}>
          <Releases downloads={data.downloads} />
        </Panel>
      </div>
      <p className="text-xs text-muted-foreground">{t('admin.generated', { at: formatDate(data.generatedAt, { dateStyle: 'medium', timeStyle: 'short' }) })}</p>
    </div>
  );
}

function Stat({ label, value, detail }: { label: string; value: number | null; detail: string }) {
  return (
    <div className="flex flex-col gap-1 rounded-2xl border bg-card p-4">
      <span className="text-sm font-semibold text-muted-foreground">{label}</span>
      <span className="text-3xl font-extrabold tabular">{value === null ? '—' : formatNumber(value)}</span>
      <span className="text-xs text-muted-foreground">{detail}</span>
    </div>
  );
}

function Panel({ title, children, action }: { title: string; children: ReactNode; action?: ReactNode }) {
  return (
    <section className="flex flex-col gap-3 rounded-2xl border bg-card p-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h2 className="text-base font-extrabold">{title}</h2>
        {action}
      </div>
      {children}
    </section>
  );
}

/** Rows of a label and a bar as long as its share of the largest. */
function Bars({ rows }: { rows: { label: string; value: number }[] }) {
  const { t } = useTranslation();
  if (rows.length === 0) return <p className="text-sm text-muted-foreground">{t('admin.nothingYet')}</p>;
  const peak = Math.max(1, ...rows.map((row) => row.value));
  return (
    <ul className="flex flex-col gap-2">
      {rows.map((row) => (
        <li key={row.label} className="grid grid-cols-[minmax(0,8rem)_1fr_auto] items-center gap-2 text-sm">
          <span className="truncate" title={row.label}>
            {row.label}
          </span>
          <span className="h-2.5 overflow-hidden rounded-full bg-muted">
            <span className="block h-full rounded-full bg-primary" style={{ width: `${(row.value / peak) * 100}%` }} />
          </span>
          <span className="font-extrabold tabular">{formatNumber(row.value)}</span>
        </li>
      ))}
    </ul>
  );
}

function Releases({ downloads }: { downloads: AdminOverview['downloads'] }) {
  const { t } = useTranslation();
  if (!downloads) return <p className="text-sm text-muted-foreground">{t('admin.downloadsUnknown')}</p>;
  if (downloads.releases.length === 0) return <p className="text-sm text-muted-foreground">{t('admin.nothingYet')}</p>;
  return (
    <ul className="flex flex-col divide-y text-sm">
      {downloads.releases.map((release) => (
        <li key={release.tag} className="flex items-center justify-between gap-2 py-1.5">
          <span className="flex min-w-0 flex-col">
            <span className="truncate font-semibold">{release.name || release.tag}</span>
            <span className="text-xs text-muted-foreground">{formatDate(release.publishedAt)}</span>
          </span>
          <span className="font-extrabold tabular">{formatNumber(release.downloads)}</span>
        </li>
      ))}
    </ul>
  );
}

// --------------------------------------------------------------- history

const spans = [30, 90, 365] as const;

type Measure = 'accounts' | 'signups' | 'active' | 'active7' | 'active30' | 'streakMedian';
const measures: Measure[] = ['accounts', 'signups', 'active', 'active7', 'active30', 'streakMedian'];

function History({ source }: { source: AdminApi }) {
  const { t } = useTranslation();
  const [days, setDays] = useState<(typeof spans)[number]>(30);
  const history = useQuery({ queryKey: ['admin', 'history', days], queryFn: () => source.adminHistory(days), retry: 1 });
  return (
    <Panel
      title={t('admin.overTime')}
      action={
        <ToggleGroup
          type="single"
          value={String(days)}
          onValueChange={(value) => value && setDays(Number(value) as (typeof spans)[number])}
          aria-label={t('admin.span')}
        >
          {spans.map((span) => (
            <ToggleGroupItem key={span} value={String(span)}>
              {t('admin.days', { count: span })}
            </ToggleGroupItem>
          ))}
        </ToggleGroup>
      }
    >
      {history.isPending ? (
        <Loading />
      ) : history.isError ? (
        <Failed />
      ) : history.data.days.length === 0 ? (
        <p className="text-sm text-muted-foreground">{t('admin.nothingYet')}</p>
      ) : (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {measures.map((measure) => (
            <LineChart key={measure} label={t(`admin.measure.${measure}`)} days={history.data.days} measure={measure} />
          ))}
        </div>
      )}
    </Panel>
  );
}

/** One measure over the days, as a line; the first and last days under it, the last value beside its name. */
export function LineChart({ label, days, measure }: { label: string; days: DailyStats[]; measure: Measure }) {
  const { t } = useTranslation();
  const width = 300;
  const height = 90;
  const values = days.map((day) => day[measure]);
  const peak = Math.max(1, ...values);
  const step = values.length > 1 ? width / (values.length - 1) : 0;
  const points = values.map((value, index) => `${(index * step).toFixed(1)},${(height - (value / peak) * height).toFixed(1)}`).join(' ');
  const last = values.at(-1) ?? 0;
  const first = days[0]!;
  const end = days.at(-1)!;
  return (
    <figure className="flex flex-col gap-1">
      <figcaption className="flex items-baseline justify-between gap-2 text-sm">
        <span className="font-semibold">{label}</span>
        <span className="font-extrabold tabular">{formatNumber(last, { maximumFractionDigits: 1 })}</span>
      </figcaption>
      <svg
        viewBox={`0 0 ${width} ${height}`}
        preserveAspectRatio="none"
        className="h-24 w-full overflow-visible text-primary"
        role="img"
        aria-label={t('admin.chartLabel', {
          label,
          from: formatDay(first.day),
          to: formatDay(end.day),
          peak: formatNumber(peak, { maximumFractionDigits: 1 }),
          last: formatNumber(last, { maximumFractionDigits: 1 }),
        })}
      >
        <line x1="0" y1={height} x2={width} y2={height} className="stroke-border" strokeWidth="1" vectorEffect="non-scaling-stroke" />
        {values.length === 1 ? (
          <circle cx={width / 2} cy={height - (values[0]! / peak) * height} r="3" className="fill-current" />
        ) : (
          <polyline points={points} fill="none" stroke="currentColor" strokeWidth="2" vectorEffect="non-scaling-stroke" strokeLinejoin="round" />
        )}
      </svg>
      <div className="flex justify-between text-[10px] text-muted-foreground" dir="ltr">
        <span>{formatDay(first.day, { month: 'short', day: 'numeric' })}</span>
        <span>{formatDay(end.day, { month: 'short', day: 'numeric' })}</span>
      </div>
    </figure>
  );
}

// ----------------------------------------------------------------- users

function Users({ source }: { source: AdminApi }) {
  const { t } = useTranslation();
  const id = useId();
  const [typed, setTyped] = useState('');
  const [q, setQ] = useState('');
  const users = useInfiniteQuery({
    queryKey: ['admin', 'users', q],
    queryFn: ({ pageParam }) => source.adminUsers({ ...(q ? { q } : {}), ...(pageParam ? { cursor: pageParam } : {}), limit: 50 }),
    initialPageParam: null as string | null,
    getNextPageParam: (page) => page.next,
    retry: 1,
  });
  const rows = users.data?.pages.flatMap((page) => page.users) ?? [];
  return (
    <div className="flex flex-col gap-3">
      <form
        role="search"
        className="flex gap-2"
        onSubmit={(event) => {
          event.preventDefault();
          setQ(typed.trim());
        }}
      >
        <Label htmlFor={`${id}-q`} className="sr-only">
          {t('admin.searchUsers')}
        </Label>
        <Input
          id={`${id}-q`}
          type="search"
          dir="ltr"
          placeholder={t('admin.searchUsers')}
          value={typed}
          onChange={(event) => setTyped(event.target.value)}
          className="max-w-sm"
        />
        <Button type="submit" variant="outline">
          <SearchIcon />
          {t('admin.search')}
        </Button>
      </form>
      {users.isPending ? (
        <Loading />
      ) : users.isError ? (
        <Failed />
      ) : rows.length === 0 ? (
        <p className="text-sm text-muted-foreground">{q ? t('admin.noMatch') : t('admin.noUsers')}</p>
      ) : (
        <div className="overflow-x-auto rounded-2xl border bg-card">
          <table className="w-full min-w-[48rem] text-sm">
            <thead className="text-start text-xs text-muted-foreground">
              <tr className="border-b">
                <th className="p-3 text-start font-semibold">{t('admin.col.email')}</th>
                <th className="p-3 text-start font-semibold">{t('admin.col.created')}</th>
                <th className="p-3 text-start font-semibold">{t('admin.col.lastActive')}</th>
                <th className="p-3 text-start font-semibold">{t('admin.col.platform')}</th>
                <th className="p-3 text-end font-semibold">{t('admin.col.streak')}</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((user) => (
                <tr key={user.id} className="border-b last:border-0">
                  <td className="p-3">
                    <span className="flex flex-col">
                      <span className="font-semibold" dir="ltr">
                        {user.email}
                      </span>
                      <span className="text-xs text-muted-foreground">
                        {user.displayName ?? '—'}
                        {user.verifiedAt === null && (
                          <Badge variant="outline" className="ms-2">
                            {t('admin.unverified')}
                          </Badge>
                        )}
                      </span>
                    </span>
                  </td>
                  <td className="p-3">{formatDate(user.createdAt)}</td>
                  <td className="p-3">{user.lastActiveAt ? formatDate(user.lastActiveAt) : t('admin.never')}</td>
                  <td className="p-3">
                    {user.platform ? `${t(`admin.platform.${user.platform}`, { defaultValue: user.platform })} ${user.appVersion ?? ''}` : '—'}
                  </td>
                  <td className="p-3 text-end tabular">
                    {user.streak ? t('admin.streakCell', { current: formatNumber(user.streak.current), best: formatNumber(user.streak.best) }) : t('admin.notShared')}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {users.hasNextPage && (
        <Button variant="outline" className="self-start" disabled={users.isFetchingNextPage} onClick={() => background(users.fetchNextPage())}>
          {t('admin.more')}
        </Button>
      )}
    </div>
  );
}

// ------------------------------------------------------------------ news

type NewsState = 'live' | 'scheduled' | 'ended';

export function newsState(news: Pick<Announcement, 'startsAt' | 'endsAt'>, now: Date = new Date()): NewsState {
  const at = now.getTime();
  if (news.endsAt !== null && Date.parse(news.endsAt) <= at) return 'ended';
  return Date.parse(news.startsAt) > at ? 'scheduled' : 'live';
}

function News({ source }: { source: AdminApi }) {
  const { t } = useTranslation();
  const client = useQueryClient();
  const list = useQuery({ queryKey: ['admin', 'news'], queryFn: () => source.adminAnnouncements(), retry: 1 });
  const [deleting, setDeleting] = useState<Announcement | null>(null);
  const refresh = () => client.invalidateQueries({ queryKey: ['admin', 'news'] });
  const end = useMutation({
    mutationFn: (id: string) => source.endAnnouncement(id, new Date().toISOString()),
    onSuccess: () => {
      toast.success(t('admin.news.ended'));
      return refresh();
    },
    onError: () => toast.error(t('common.somethingWrong')),
  });
  const remove = useMutation({
    mutationFn: (id: string) => source.deleteAnnouncement(id),
    onSuccess: () => {
      toast.success(t('admin.news.deleted'));
      return refresh();
    },
    onError: () => toast.error(t('common.somethingWrong')),
  });
  return (
    <div className="grid gap-4 lg:grid-cols-[minmax(0,26rem)_1fr]">
      <Panel title={t('admin.news.write')}>
        <NewsForm source={source} onCreated={() => background(refresh())} />
      </Panel>
      <Panel title={t('admin.news.all')}>
        {list.isPending ? (
          <Loading />
        ) : list.isError ? (
          <Failed />
        ) : list.data.announcements.length === 0 ? (
          <p className="text-sm text-muted-foreground">{t('admin.news.none')}</p>
        ) : (
          <ul className="flex flex-col gap-3">
            {list.data.announcements.map((news) => {
              const state = newsState(news);
              return (
                <li key={news.id} className="flex flex-col gap-2 rounded-xl border p-3">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="font-extrabold">{news.title}</span>
                    <Badge variant={state === 'live' ? 'default' : 'secondary'}>{t(`admin.news.state.${state}`)}</Badge>
                    {news.push && <Badge variant="outline">{t('admin.news.pushBadge', { count: news.pushed })}</Badge>}
                    {news.popup && <Badge variant="outline">{t('admin.news.popupBadge')}</Badge>}
                    <Badge variant="outline">{t(`admin.news.audience.${news.audience}`)}</Badge>
                  </div>
                  <p className="whitespace-pre-line text-sm text-muted-foreground">{news.body}</p>
                  {news.link && (
                    <a href={news.link} target="_blank" rel="noopener noreferrer" className="truncate text-xs underline underline-offset-2" dir="ltr">
                      {news.link}
                    </a>
                  )}
                  <div className="flex flex-wrap items-center justify-between gap-2 text-xs text-muted-foreground">
                    <span>
                      {t('admin.news.when', {
                        from: formatDate(news.startsAt, { dateStyle: 'medium', timeStyle: 'short' }),
                        until: news.endsAt ? formatDate(news.endsAt, { dateStyle: 'medium', timeStyle: 'short' }) : t('admin.news.forever'),
                      })}
                    </span>
                    <span className="flex gap-1">
                      {state !== 'ended' && (
                        <Button size="sm" variant="outline" disabled={end.isPending} onClick={() => end.mutate(news.id)}>
                          {t('admin.news.endNow')}
                        </Button>
                      )}
                      <Button size="sm" variant="ghost" className="text-destructive" onClick={() => setDeleting(news)}>
                        <Trash2Icon />
                        {t('admin.news.delete')}
                      </Button>
                    </span>
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </Panel>
      <AlertDialog open={deleting !== null} onOpenChange={(open) => !open && setDeleting(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>{t('admin.news.deleteTitle')}</AlertDialogTitle>
            <AlertDialogDescription>{t('admin.news.deleteBody', { title: deleting?.title ?? '' })}</AlertDialogDescription>
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
              {t('admin.news.delete')}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}

interface Draft {
  title: string;
  body: string;
  link: string;
  push: boolean;
  popup: boolean;
  audience: 'everyone' | 'accounts';
  /** `datetime-local` values: this browser's own clock. */
  startsAt: string;
  endsAt: string;
}

const emptyDraft: Draft = { title: '', body: '', link: '', push: true, popup: false, audience: 'everyone', startsAt: '', endsAt: '' };

/** A `datetime-local` value as an instant, or null for none. */
function instantOf(local: string): string | null {
  if (!local) return null;
  const at = new Date(local);
  return Number.isNaN(at.getTime()) ? null : at.toISOString();
}

type Field = 'title' | 'body' | 'link' | 'push' | 'endsAt';

/** A draft as the server takes it, or what is wrong with it, by field. */
export function checkDraft(draft: Draft): { body: AnnouncementBody } | { problems: Partial<Record<Field, true>> } {
  const candidate = {
    title: draft.title,
    body: draft.body,
    link: draft.link.trim() ? draft.link.trim() : null,
    push: draft.push,
    popup: draft.popup,
    audience: draft.audience,
    startsAt: instantOf(draft.startsAt),
    endsAt: instantOf(draft.endsAt),
  };
  const parsed = announcementBodySchema.safeParse(candidate);
  if (parsed.success) return { body: candidate };
  const problems: Partial<Record<Field, true>> = {};
  for (const issue of parsed.error.issues) {
    const field = issue.path[0];
    if (field === 'title' || field === 'body' || field === 'link' || field === 'push' || field === 'endsAt') problems[field] = true;
  }
  return { problems };
}

function NewsForm({ source, onCreated }: { source: AdminApi; onCreated: () => void }) {
  const { t } = useTranslation();
  const id = useId();
  const [draft, setDraft] = useState<Draft>(emptyDraft);
  const [problems, setProblems] = useState<Partial<Record<Field, true>>>({});
  const create = useMutation({
    mutationFn: (body: AnnouncementBody) => source.createAnnouncement(body),
    onSuccess: () => {
      toast.success(t('admin.news.sent'));
      setDraft(emptyDraft);
      onCreated();
    },
    onError: () => toast.error(t('common.somethingWrong')),
  });
  const set = <K extends keyof Draft>(key: K, value: Draft[K]) => setDraft((current) => ({ ...current, [key]: value }));
  const problem = (field: Field) =>
    problems[field] ? (
      <p role="alert" className="text-xs font-semibold text-destructive">
        {t(`admin.news.problem.${field}`)}
      </p>
    ) : null;
  return (
    <form
      noValidate
      className="flex flex-col gap-3"
      onSubmit={(event) => {
        event.preventDefault();
        const checked = checkDraft(draft);
        if ('problems' in checked) {
          setProblems(checked.problems);
          return;
        }
        setProblems({});
        create.mutate(checked.body);
      }}
    >
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`${id}-title`}>{t('admin.news.title')}</Label>
        <Input id={`${id}-title`} value={draft.title} maxLength={announcementTitleMax} onChange={(event) => set('title', event.target.value)} />
        {problem('title')}
      </div>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`${id}-body`}>{t('admin.news.body')}</Label>
        <Textarea id={`${id}-body`} rows={5} value={draft.body} maxLength={announcementBodyMax} onChange={(event) => set('body', event.target.value)} />
        <span className="self-end text-xs text-muted-foreground tabular">
          {formatNumber(draft.body.length)} / {formatNumber(announcementBodyMax)}
        </span>
        {problem('body')}
      </div>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`${id}-link`}>{t('admin.news.link')}</Label>
        <Input id={`${id}-link`} type="url" dir="ltr" placeholder="https://" value={draft.link} onChange={(event) => set('link', event.target.value)} />
        {problem('link')}
      </div>
      <div className="flex flex-col gap-2 rounded-xl bg-muted/60 p-3">
        <label className="flex items-center justify-between gap-3 text-sm font-semibold" htmlFor={`${id}-push`}>
          {t('admin.news.push')}
          <Switch id={`${id}-push`} checked={draft.push} onCheckedChange={(on) => set('push', on)} />
        </label>
        <label className="flex items-center justify-between gap-3 text-sm font-semibold" htmlFor={`${id}-popup`}>
          {t('admin.news.popup')}
          <Switch id={`${id}-popup`} checked={draft.popup} onCheckedChange={(on) => set('popup', on)} />
        </label>
        {problem('push')}
      </div>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`${id}-audience`}>{t('admin.news.audienceLabel')}</Label>
        <Select value={draft.audience} onValueChange={(value) => set('audience', value as Draft['audience'])}>
          <SelectTrigger id={`${id}-audience`}>
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="everyone">{t('admin.news.audience.everyone')}</SelectItem>
            <SelectItem value="accounts">{t('admin.news.audience.accounts')}</SelectItem>
          </SelectContent>
        </Select>
      </div>
      <div className="grid gap-3 sm:grid-cols-2">
        <div className="flex flex-col gap-1.5">
          <Label htmlFor={`${id}-from`}>{t('admin.news.from')}</Label>
          <Input id={`${id}-from`} type="datetime-local" value={draft.startsAt} onChange={(event) => set('startsAt', event.target.value)} />
          <span className="text-xs text-muted-foreground">{t('admin.news.fromHint')}</span>
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor={`${id}-until`}>{t('admin.news.until')}</Label>
          <Input id={`${id}-until`} type="datetime-local" value={draft.endsAt} onChange={(event) => set('endsAt', event.target.value)} />
          <span className="text-xs text-muted-foreground">{t('admin.news.untilHint')}</span>
          {problem('endsAt')}
        </div>
      </div>
      <Button type="submit" disabled={create.isPending} className={cn('self-start')}>
        <MegaphoneIcon />
        {t('admin.news.send')}
      </Button>
    </form>
  );
}

function Loading() {
  const { t } = useTranslation();
  return <p className="text-sm text-muted-foreground">{t('common.loading')}</p>;
}

function Failed() {
  const { t } = useTranslation();
  return <p className="text-sm text-muted-foreground">{t('admin.failed')}</p>;
}
