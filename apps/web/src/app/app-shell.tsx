import {
  ArchiveIcon,
  ArrowLeftIcon,
  BookOpenIcon,
  CalendarDaysIcon,
  EllipsisVerticalIcon,
  FlameIcon,
  HeartPulseIcon,
  KeyRoundIcon,
  MailWarningIcon,
  PlusIcon,
  SearchIcon,
  SettingsIcon,
  SproutIcon,
  TimerIcon,
  UserRoundIcon,
  WalletIcon,
  WifiOffIcon,
  type LucideIcon,
} from 'lucide-react';
import { useLiveQuery } from 'dexie-react-hooks';
import { Suspense, lazy, useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import type { TFunction } from 'i18next';
import { Link, Navigate, NavLink, Route, Routes, useLocation, useNavigate } from 'react-router';
import { toast } from 'sonner';
import { HarvestMark } from '@/components/brand';
import { ScreenErrorBoundary } from '@/components/error-screen';
import { Button } from '@/components/ui/button';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import { api } from '@/lib/api';
import { formatNumber } from '@/lib/format';
import { useDocumentTitle } from '@/lib/title';
import { cn } from '@/lib/utils';
import { AccountCircle } from './components/account-circle';
import { AppBarLeadingSlot, AppBarSlot, AppBarTitleSlot } from './components/app-bar';
import { useKeyboardMark } from './components/keyboard';
import { SyncPinDialog } from './components/passphrase-prompt';
import { usePinChosen } from './components/pin-state';
import { PomodoroChip } from './components/pomodoro-timer';
import { useFeaturesOrOff } from './components/settings-bits';
import { SyncIndicator } from './components/sync-indicator';
import { useHarvest, useSyncStatus } from './context';
import { usePrivateKey } from './hooks';
import { DialogsProvider, useDialogs } from './dialogs';
import { NewsPopup } from './components/news-popup';
import { FieldScreen } from './screens/field';
import { RecordsView } from './screens/records';
import { OnboardingGate } from './screens/onboarding-gate';
import { StreakDialog } from './components/streak-dialog';
import { useShortcuts } from './shortcuts';
import { background } from '@/lib/actions';

// Every screen but the Field loads when first opened, so the Field
// comes up with nothing else in its bundle ([[Audit-v3]] Q5-30, P6-10).
// The map is most of a megabyte of MapLibre, and most days nobody
// opens it: it arrives when Places does, not when the app does.
const BodyScreen = lazy(async () => ({ default: (await import('./screens/body')).BodyScreen }));
const GalleryScreen = lazy(async () => ({ default: (await import('./screens/gallery')).GalleryScreen }));
const GranaryScreen = lazy(async () => ({ default: (await import('./screens/granary')).GranaryScreen }));
const NotesScreen = lazy(async () => ({ default: (await import('./screens/notes')).NotesScreen }));
const ProgramEditorScreen = lazy(async () => ({ default: (await import('./screens/gym/program-editor')).ProgramEditorScreen }));
const SessionScreen = lazy(async () => ({ default: (await import('./screens/gym/session')).SessionScreen }));
const PlacesScreen = lazy(async () => ({ default: (await import('./screens/places')).PlacesScreen }));
const ArchiveScreen = lazy(async () => ({ default: (await import('./screens/archive')).ArchiveScreen }));
const CalendarScreen = lazy(async () => ({ default: (await import('./screens/calendar')).CalendarScreen }));
const FarmerScreen = lazy(async () => ({ default: (await import('./screens/farmer')).FarmerScreen }));
const GoalScreen = lazy(async () => ({ default: (await import('./screens/goal')).GoalScreen }));
const ListsScreen = lazy(async () => ({ default: (await import('./screens/lists')).ListsScreen }));
const OnboardingScreen = lazy(async () => ({ default: (await import('./screens/onboarding')).OnboardingScreen }));
const PomodoroScreen = lazy(async () => ({ default: (await import('./screens/pomodoro')).PomodoroScreen }));
const SeedScreen = lazy(async () => ({ default: (await import('./screens/seed')).SeedScreen }));
const SettingsScreen = lazy(async () => ({ default: (await import('./screens/settings')).SettingsScreen }));
const AdminScreen = lazy(async () => ({ default: (await import('./screens/admin')).AdminScreen }));

interface Tab {
  to: string;
  label: string;
  icon: LucideIcon;
  /** The second key after `g`. */
  key: string;
  /** The paths that light this tab up. */
  paths: string[];
}

/** One of the places the bottom bar and the rail lead to. */
export type TabId = 'field' | 'granary' | 'records' | 'body' | 'farmer';

type Switches = Record<'notes' | 'gallery' | 'places' | 'lists' | 'health' | 'gym', boolean>;

/**
 * The phone's bottom bar, in its order: Field, Granary, Records while
 * any of Notes, Lists, the Gallery or Places is on, the Body while
 * Health or the Gym is, and the Farmer, who holds Settings too. Three
 * with nothing extra, five with everything, never six ([[Web]]).
 */
export function barTabs(on: Switches): TabId[] {
  return [
    'field',
    'granary',
    ...(on.notes || on.gallery || on.places || on.lists ? (['records'] as const) : []),
    ...(on.health || on.gym ? (['body'] as const) : []),
    'farmer',
  ];
}

/** The rail on a wide window has the same places in the same order, so crossing 768 px moves nothing (W6-30). */
export function railTabs(on: Switches): TabId[] {
  return barTabs(on);
}

/**
 * What the app bar is called on a phone-width window: the phone's
 * titles. A tab holding two or more halves is named for the tab while
 * its tab row shows, and for the half when only one is on.
 */
export function barTitle(pathname: string, on: Switches, t: TFunction): string {
  const section = pathname.split('/')[2] ?? '';
  if (section === 'granary') return t('money.granary');
  if (section === 'records') {
    const halves = (['notes', 'lists', 'gallery', 'places'] as const).filter((half) => on[half]);
    if (halves.length !== 1) return t('nav.records');
    return { notes: t('nav.notes'), lists: t('lists.title'), gallery: t('gallery.title'), places: t('places.title') }[halves[0]!];
  }
  if (section === 'body') {
    if (on.health && !on.gym) return t('nav.health');
    if (on.gym && !on.health) return t('nav.gym');
    return t('nav.body');
  }
  if (section === 'farmer' || section === 'settings') return t('nav.farmer');
  if (section === 'welcome') return '';
  return t('nav.harvest');
}

/**
 * Where the back arrow leads from a screen the phone pushes over its
 * tab (a seed, a goal, the calendar, a note, a program…), or null on a
 * tab's own screen, which has the account circle there instead.
 */
export function pushedParent(pathname: string, search = ''): string | null {
  const parts = pathname.split('/').slice(2);
  const [section, second, third] = parts;
  if (section === 'field') {
    if (second === 'goals') return third ? '/app/field/goals' : null;
    return second ? '/app/field' : null;
  }
  if (section === 'body') return second === 'gym' && third ? '/app/body/gym' : null;
  if (section === 'records') {
    if (second === 'gallery') return new URLSearchParams(search).has('album') ? '/app/records/gallery' : null;
    // A note opens in place with its drawer, as on the phone; only the
    // trash is a screen pushed over Notes.
    return second === 'trash' ? '/app/records' : null;
  }
  return null;
}

/**
 * Whether a route is Notes, which fills the window as the phone's and
 * Obsidian's do: the list and the note each scroll on their own, and
 * the page never does.
 */
export function fillsViewport(pathname: string): boolean {
  const [section, second, ...rest] = pathname.split('/').slice(2).filter(Boolean);
  if (section !== 'records' || rest.length > 0) return false;
  return second === undefined || !['lists', 'gallery', 'places'].includes(second);
}

/** The title a pushed screen's app bar carries, when the screen does not carry its own. */
function pushedTitle(pathname: string, t: TFunction): string {
  if (pathname === '/app/field/calendar') return t('calendar.title');
  if (pathname === '/app/field/archive') return t('archive.title');
  if (pathname === '/app/field/focus') return t('focus.timer');
  if (pathname === '/app/records/trash') return t('notes.trashTitle');
  return '';
}

/** The tab's title for a route; a screen with a name of its own (a note, a seed) sets a better one. */
function routeTitle(pathname: string, on: Switches, t: TFunction): string {
  const pushed = pushedTitle(pathname, t);
  if (pushed) return pushed;
  if (pathname === '/app/field') return t('nav.field');
  if (pathname.startsWith('/app/field/goals')) return t('field.goals');
  if (pathname === '/app/settings') return t('nav.settings');
  return barTitle(pathname, on, t);
}

/** The farmer's streak in the Field's app bar: the flame and the days, opening the streak sheet. */
function FieldStreak() {
  const { t } = useTranslation();
  const { db } = useHarvest();
  const [open, setOpen] = useState(false);
  const current = useLiveQuery(async () => (await db.rows('streaks').get('global'))?.current ?? 0, [db]) ?? 0;
  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        aria-label={`${t('streak.sheetTitle')}: ${t('streak.days', { count: current })}`}
        title={t('streak.sheetTitle')}
        className="flex h-11 min-w-11 items-center justify-center gap-1 rounded-lg px-2 text-lg font-extrabold tabular outline-none hover:bg-accent focus-visible:ring-2 focus-visible:ring-ring"
      >
        <FlameIcon className={cn('size-6', current > 0 ? 'text-primary' : 'text-foreground/80')} aria-hidden />
        <span aria-hidden>{formatNumber(current)}</span>
      </button>
      {open && <StreakDialog onClose={() => setOpen(false)} />}
    </>
  );
}

function useTabs(): Record<TabId, Tab> {
  const { t } = useTranslation();
  const on = useFeaturesOrOff();
  return {
    field: { to: '/app/field', label: t('nav.field'), icon: SproutIcon, key: 'f', paths: ['/app/field'] },
    body: { to: '/app/body', label: t('nav.body'), icon: HeartPulseIcon, key: 'b', paths: ['/app/body'] },
    // Records opens on its first half that is on.
    records: {
      to: on.notes ? '/app/records' : on.lists ? '/app/records/lists' : on.gallery ? '/app/records/gallery' : '/app/records/places',
      label: t('nav.records'),
      icon: BookOpenIcon,
      key: 'r',
      paths: ['/app/records'],
    },
    granary: { to: '/app/granary', label: t('nav.granary'), icon: WalletIcon, key: 'm', paths: ['/app/granary'] },
    farmer: { to: '/app/farmer', label: t('nav.farmer'), icon: UserRoundIcon, key: 'p', paths: ['/app/farmer', '/app/settings'] },
  };
}

function isUnder(pathname: string, path: string): boolean {
  return pathname === path || pathname.startsWith(`${path}/`);
}

/** The rail on the left of a wide window: the five places, and Settings at the foot. */
function Rail() {
  const { t } = useTranslation();
  const byId = useTabs();
  const tabs = railTabs(useFeaturesOrOff()).map((id) => byId[id]);
  const item = ({ isActive }: { isActive: boolean }) =>
    cn(
      'flex flex-col items-center gap-1 rounded-lg px-1 py-2.5 text-[11px] font-extrabold outline-none transition-colors hover:bg-accent focus-visible:ring-2 focus-visible:ring-ring',
      isActive ? 'text-primary' : 'text-muted-foreground',
    );
  return (
    <nav aria-label={t('nav.main')} className="sticky top-0 hidden h-dvh w-24 shrink-0 flex-col gap-1 border-e px-2 py-4 md:flex">
      <Link to="/app/field" className="mb-3 flex justify-center" aria-label={t('nav.field')}>
        <HarvestMark className="size-10" />
      </Link>
      <div className="mb-3 flex justify-center">
        <AccountCircle />
      </div>
      {tabs.map((tab) => (
        <NavLink key={tab.to} to={tab.to} className={item} title={`${tab.label} (g ${tab.key})`}>
          <tab.icon className="size-5" aria-hidden />
          <span>{tab.label}</span>
        </NavLink>
      ))}
      <NavLink to="/app/settings" className={(state) => cn(item(state), 'mt-auto')}>
        <SettingsIcon className="size-5" aria-hidden />
        <span>{t('nav.settings')}</span>
      </NavLink>
    </nav>
  );
}

/**
 * The phone's navigation bar at the foot of a narrow window: the tabs
 * in the phone's order, the one on show with its pill behind the icon,
 * clear of the home indicator in an installed app.
 */
export function BottomBar() {
  const { t } = useTranslation();
  const { pathname } = useLocation();
  const byId = useTabs();
  const tabs = barTabs(useFeaturesOrOff()).map((id) => byId[id]);
  return (
    <nav
      aria-label={t('nav.main')}
      data-bottom-bar
      className="fixed inset-x-0 bottom-0 z-40 flex bg-muted pb-[env(safe-area-inset-bottom)] pl-[env(safe-area-inset-left)] pr-[env(safe-area-inset-right)] md:hidden"
    >
      {tabs.map((tab) => {
        const active = tab.paths.some((path) => isUnder(pathname, path));
        return (
          <Link
            key={tab.to}
            to={tab.to}
            aria-current={active ? 'page' : undefined}
            className="group flex h-20 min-w-0 flex-1 flex-col items-center justify-center gap-1 text-xs font-semibold text-muted-foreground outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ring aria-[current=page]:font-extrabold aria-[current=page]:text-foreground"
          >
            <span className="flex h-8 w-16 max-w-full items-center justify-center rounded-full transition-colors group-hover:bg-accent group-aria-[current=page]:bg-secondary">
              <tab.icon className="size-6" strokeWidth={1.75} aria-hidden />
            </span>
            <span data-bar-label className="max-w-full truncate px-1">
              {tab.label}
            </span>
          </Link>
        );
      })}
    </nav>
  );
}

function Banners({ startedOffline, className }: { startedOffline: boolean; className?: string | undefined }) {
  const { t } = useTranslation();
  const { user } = useHarvest();
  const status = useSyncStatus();
  const [sent, setSent] = useState(false);
  const unlocked = usePrivateKey();
  const offline = status.phase === 'offline' || (startedOffline && status.phase !== 'idle');
  return (
    <div className={cn('flex flex-col gap-2 empty:hidden', className)} aria-live="polite">
      {user.verifiedAt !== null && unlocked === false && <PinBanner />}
      {user.verifiedAt === null && (
        <div className="flex flex-wrap items-center gap-2 rounded-lg bg-secondary px-3 py-2 text-sm">
          <MailWarningIcon className="size-4" aria-hidden />
          <span className="flex-1">{t('app.verifyBanner', { email: user.email })}</span>
          <Button
            size="sm"
            variant="outline"
            disabled={sent}
            onClick={() => {
              void api.resendVerification(user.email).then(
                () => setSent(true),
                () => toast.error(t('common.somethingWrong')),
              );
            }}
          >
            {sent ? t('app.verifySent') : t('app.verifyResend')}
          </Button>
        </div>
      )}
      {offline && (
        <div className="flex items-center gap-2 rounded-lg bg-muted px-3 py-2 text-sm">
          <WifiOffIcon className="size-4" aria-hidden />
          <span>{t('app.offlineBanner')}</span>
        </div>
      )}
      {status.phase === 'syncing' && status.firstSync && (
        <div className="rounded-lg bg-muted px-3 py-2 text-sm">{t('app.firstSyncBanner')}</div>
      )}
    </div>
  );
}

/**
 * Since Phase 7 nothing leaves this browser unsealed, so without the
 * sync PIN nothing syncs at all: said here, on every screen, with the
 * way to enter it (or choose it, on the first device).
 */
function PinBanner() {
  const { t } = useTranslation();
  const chosen = usePinChosen();
  const [open, setOpen] = useState(false);
  return (
    <div className="flex flex-wrap items-center gap-2 rounded-lg bg-secondary px-3 py-2 text-sm">
      <KeyRoundIcon className="size-4" aria-hidden />
      <span className="flex-1">{t('app.pinBanner')}</span>
      <Button size="sm" variant="outline" onClick={() => setOpen(true)}>
        {chosen === false ? t('syncPin.chooseTitle') : t('syncPin.enter')}
      </Button>
      {open && <SyncPinDialog onClose={() => setOpen(false)} />}
    </div>
  );
}

function Shell({ startedOffline }: { startedOffline: boolean }) {
  const { t } = useTranslation();
  const { user } = useHarvest();
  const byId = useTabs();
  const on = useFeaturesOrOff();
  const { pathname } = useLocation();
  const navigate = useNavigate();
  const dialogs = useDialogs();
  const rail = railTabs(on).map((id) => byId[id]);
  const { search, key } = useLocation();
  const [slot, setSlot] = useState<HTMLDivElement | null>(null);
  const [leadingSlot, setLeadingSlot] = useState<HTMLDivElement | null>(null);
  const [titleSlot, setTitleSlot] = useState<HTMLDivElement | null>(null);
  const fills = fillsViewport(pathname);
  useKeyboardMark();
  // The Field's own two tabs carry its actions, as on the phone; a screen pushed over it does not.
  const onField = pathname === '/app/field' || pathname === '/app/field/goals';
  const back = pushedParent(pathname, search);
  useDocumentTitle(routeTitle(pathname, on, t), 0);
  const goBack = () => {
    // Back where I came from when I came from inside the app, else up to the tab.
    if (key !== 'default') background(navigate(-1));
    else if (back) background(navigate(back));
  };

  useShortcuts({
    n: () => dialogs.plantSeed(),
    e: () => dialogs.logExpense(),
    '/': () => dialogs.openSearch(),
    ...Object.fromEntries(rail.map((tab) => [`g ${tab.key}`, () => background(navigate(tab.to))])),
    'g s': () => background(navigate('/app/settings')),
    'g g': () => background(navigate('/app/field/goals')),
    'g c': () => background(navigate('/app/field/calendar')),
  });

  return (
    <div className={cn('flex min-h-dvh flex-col md:flex-row', fills && 'h-dvh overflow-hidden')}>
      <a
        href="#app-main"
        className="sr-only focus:not-sr-only focus:absolute focus:start-2 focus:top-2 focus:z-50 focus:rounded-md focus:bg-card focus:p-2"
      >
        {t('common.skipToContent')}
      </a>
      <Rail />
      <div className={cn('flex min-w-0 flex-1 flex-col', fills && 'min-h-0')}>
        {/* On a phone-width window this is the phone's app bar: the
            account circle at the start, the tab's title, and its
            actions at the end. */}
        <header className="@container/bar sticky top-0 z-30 flex h-[calc(3.5rem+env(safe-area-inset-top))] items-center gap-1 bg-background/95 pt-[env(safe-area-inset-top)] pr-[max(0.5rem,env(safe-area-inset-right))] pl-[max(0.5rem,env(safe-area-inset-left))] backdrop-blur md:border-b md:bg-background/90 md:px-6">
          {back ? (
            <Button variant="ghost" size="icon" className="md:hidden" aria-label={t('nav.back')} title={t('nav.back')} onClick={goBack}>
              <ArrowLeftIcon className="rtl:rotate-180" />
            </Button>
          ) : (
            <AccountCircle className="ms-1 md:hidden max-md:touch-target" />
          )}
          <div ref={setLeadingSlot} className="flex items-center empty:hidden md:hidden" />
          <div ref={setTitleSlot} className="peer min-w-0 flex-1 ps-2 empty:hidden md:hidden" />
          <p className="min-w-0 flex-1 truncate ps-2 text-lg font-extrabold md:hidden peer-[:not(:empty)]:hidden">
            {back ? pushedTitle(pathname, t) : barTitle(pathname, on, t)}
          </p>
          <div className="flex items-center gap-0.5 md:ms-auto md:gap-1">
            {onField && (
              <>
                <Button asChild variant="ghost" size="icon" className="md:hidden @max-[22rem]/bar:hidden" aria-label={t('calendar.title')} title={t('calendar.title')}>
                  <Link to="/app/field/calendar">
                    <CalendarDaysIcon />
                  </Link>
                </Button>
                <Button asChild variant="ghost" size="icon" className="@max-[22rem]/bar:hidden" aria-label={t('archive.open')} title={t('archive.title')}>
                  <Link to="/app/field/archive">
                    <ArchiveIcon />
                  </Link>
                </Button>
              </>
            )}
            <div ref={setSlot} className="flex items-center gap-0.5 empty:hidden md:hidden" />
            {/* On the timer's own screen the ring says it already (W6-38). */}
            {/* Notes on a phone has the phone's bar: its own actions and no more (the timer and search stay on a wide window). */}
            {pathname !== '/app/field/focus' && (
              <div className={cn('flex @max-[15rem]/bar:hidden', fills && 'max-md:hidden')}>
                <PomodoroChip />
              </div>
            )}
            {onField && (
              <div className="md:hidden">
                <FieldStreak />
              </div>
            )}
            <div className="max-md:hidden">
              <SyncIndicator />
            </div>
            <Button
              variant="ghost"
              size="icon"
              className={cn('@max-[22rem]/bar:hidden', fills && 'max-md:hidden')}
              aria-label={t('app.search')}
              title={`${t('app.search')} (/)`}
              onClick={dialogs.openSearch}
            >
              <SearchIcon />
            </Button>
            {/* With large text or zoom the bar has too little room: what does not fit folds into one menu (W6-06). */}
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="ghost" size="icon" className={cn('@min-[22rem]/bar:hidden md:hidden', fills && 'hidden')} aria-label={t('nav.more')}>
                  <EllipsisVerticalIcon />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end">
                {onField && (
                  <>
                    <DropdownMenuItem onSelect={() => background(navigate('/app/field/calendar'))}>
                      <CalendarDaysIcon />
                      {t('calendar.title')}
                    </DropdownMenuItem>
                    <DropdownMenuItem onSelect={() => background(navigate('/app/field/archive'))}>
                      <ArchiveIcon />
                      {t('archive.title')}
                    </DropdownMenuItem>
                  </>
                )}
                <DropdownMenuItem onSelect={() => background(navigate('/app/field/focus'))}>
                  <TimerIcon />
                  {t('focus.timer')}
                </DropdownMenuItem>
                <DropdownMenuItem onSelect={dialogs.openSearch}>
                  <SearchIcon />
                  {t('app.search')}
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
            <Button size="sm" className="max-md:hidden" onClick={() => dialogs.plantSeed()} title={`${t('seed.plant')} (n)`}>
              <PlusIcon />
              <span>{t('seed.plant')}</span>
            </Button>
          </div>
        </header>
        <main
          id="app-main"
          tabIndex={-1}
          data-fill={fills ? '' : undefined}
          className={
            fills
              ? // The whole window below the bar, and nothing past it: the
                // screen scrolls inside itself (above the bottom bar on a phone).
                'flex min-h-0 w-full flex-1 flex-col overflow-hidden pr-[env(safe-area-inset-right)] pb-[calc(5rem+env(safe-area-inset-bottom))] pl-[env(safe-area-inset-left)] outline-none md:pb-0'
              : 'mx-auto flex w-full max-w-6xl flex-1 flex-col gap-4 py-4 pr-[max(0.75rem,env(safe-area-inset-right))] pb-[calc(11rem+env(safe-area-inset-bottom))] pl-[max(0.75rem,env(safe-area-inset-left))] outline-none md:px-6 md:pb-4'
          }
        >
          <Banners startedOffline={startedOffline} className={fills ? 'mx-3 mt-3 md:mx-6' : undefined} />
          <OnboardingGate />
          <AppBarLeadingSlot.Provider value={leadingSlot}>
            <AppBarTitleSlot.Provider value={titleSlot}>
              <AppBarSlot.Provider value={slot}>
                {/* A screen that breaks, or whose code is gone after a deploy, shows so in place; the tabs stay. */}
                <ScreenErrorBoundary resetKey={pathname}>
                  <Suspense fallback={<div className="h-80 animate-pulse rounded-2xl bg-muted" aria-busy />}>
                    <Routes>
                      <Route index element={<Navigate to="field" replace />} />
                      <Route path="field" element={<FieldScreen tab="today" />} />
                      <Route path="field/calendar" element={<CalendarScreen />} />
                      <Route path="field/seed/:uuid" element={<SeedScreen />} />
                      <Route path="field/focus" element={<PomodoroScreen />} />
                      <Route path="field/archive" element={<ArchiveScreen />} />
                      <Route path="field/goals" element={<FieldScreen tab="goals" />} />
                      <Route path="field/goals/:uuid" element={<GoalScreen />} />
                      {/* Keyed apart: the two paths are two screens, so following a
                          link from one to the other opens on the tab it names. */}
                      <Route path="body" element={<BodyScreen key="health" />} />
                      <Route path="body/gym" element={<BodyScreen key="gym" tab="gym" />} />
                      <Route path="body/gym/programs/:uuid" element={<ProgramEditorScreen />} />
                      <Route path="body/gym/sessions/:uuid" element={<SessionScreen />} />
                      <Route path="records" element={<NotesScreen />} />
                      <Route
                        path="records/gallery"
                        element={
                          <RecordsView feature="gallery">
                            <GalleryScreen />
                          </RecordsView>
                        }
                      />
                      <Route
                        path="records/places"
                        element={
                          <RecordsView feature="places">
                            <Suspense fallback={<div className="h-80 animate-pulse rounded-2xl bg-muted" />}>
                              <PlacesScreen />
                            </Suspense>
                          </RecordsView>
                        }
                      />
                      <Route
                        path="records/lists/:listUuid?"
                        element={
                          <RecordsView feature="lists">
                            <ListsScreen />
                          </RecordsView>
                        }
                      />
                      <Route path="records/trash" element={<NotesScreen trash />} />
                      <Route path="records/:uuid" element={<NotesScreen />} />
                      <Route path="granary" element={<GranaryScreen />} />
                      <Route path="farmer" element={<FarmerScreen />} />
                      <Route path="settings" element={<SettingsScreen />} />
                      {/* Only for an account the server names an admin ([[Admin]]); anyone else lands on the field. */}
                      <Route path="admin" element={user.admin === true ? <AdminScreen /> : <Navigate to="/app/field" replace />} />
                      <Route path="welcome" element={<OnboardingScreen />} />
                      <Route path="*" element={<Navigate to="/app/field" replace />} />
                    </Routes>
                  </Suspense>
                </ScreenErrorBoundary>
              </AppBarSlot.Provider>
            </AppBarTitleSlot.Provider>
          </AppBarLeadingSlot.Provider>
        </main>
      </div>
      {/* The first run fills the phone's screen, with no bar under it. */}
      {pathname !== '/app/welcome' && <BottomBar />}
    </div>
  );
}

/** Pictures and recordings made here leave after each sync ([[Sync-API]], files). */
function FileUploads() {
  const { files, engine } = useHarvest();
  useEffect(() => files.follow(engine), [files, engine]);
  return null;
}

export function AppShell({ startedOffline }: { startedOffline: boolean }) {
  return (
    <DialogsProvider>
      <FileUploads />
      <NewsPopup />
      <Shell startedOffline={startedOffline} />
    </DialogsProvider>
  );
}
