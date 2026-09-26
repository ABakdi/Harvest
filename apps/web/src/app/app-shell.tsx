import {
  BookOpenIcon,
  HeartPulseIcon,
  MailWarningIcon,
  PlusIcon,
  SearchIcon,
  SettingsIcon,
  SproutIcon,
  UserRoundIcon,
  WalletIcon,
  WifiOffIcon,
  type LucideIcon,
} from 'lucide-react';
import { Suspense, lazy, useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Link, Navigate, NavLink, Route, Routes, useNavigate } from 'react-router';
import { toast } from 'sonner';
import { HarvestMark } from '@/components/brand';
import { Button } from '@/components/ui/button';
import { api } from '@/lib/api';
import { cn } from '@/lib/utils';
import { PomodoroChip } from './components/pomodoro-timer';
import { useFeaturesOrOff } from './components/settings-bits';
import { SyncIndicator } from './components/sync-indicator';
import { useHarvest, useSyncStatus } from './context';
import { DialogsProvider, useDialogs } from './dialogs';
import { BodyScreen } from './screens/body';
import { CalendarScreen } from './screens/calendar';
import { FarmerScreen } from './screens/farmer';
import { FieldScreen } from './screens/field';
import { GalleryScreen } from './screens/gallery';
import { GoalScreen } from './screens/goal';
import { GranaryScreen } from './screens/granary';
import { ListsScreen } from './screens/lists';
import { ProgramEditorScreen } from './screens/gym/program-editor';
import { SessionScreen } from './screens/gym/session';
import { NotesScreen } from './screens/notes';
import { PomodoroScreen } from './screens/pomodoro';
import { RecordsView } from './screens/records';
import { SeedScreen } from './screens/seed';

// The map is most of a megabyte of MapLibre, and most days nobody
// opens it: it arrives when Places does, not when the app does.
const PlacesScreen = lazy(async () => ({ default: (await import('./screens/places')).PlacesScreen }));

import { OnboardingGate, OnboardingScreen } from './screens/onboarding';
import { SettingsScreen } from './screens/settings';
import { useShortcuts } from './shortcuts';

interface Tab {
  to: string;
  label: string;
  icon: LucideIcon;
  /** The second key after `g`. */
  key: string;
}

/**
 * The tabs, with the paired ones only while one of their halves is
 * switched on, as on the phone: Records for notes, pictures, places or lists,
 * Body for health or training. A tab switched off still opens by link.
 */
function useTabs(): Tab[] {
  const { t } = useTranslation();
  const on = useFeaturesOrOff();
  return [
    { to: '/app/field', label: t('nav.field'), icon: SproutIcon, key: 'f' },
    ...(on.health || on.gym ? [{ to: '/app/body', label: t('nav.body'), icon: HeartPulseIcon, key: 'b' }] : []),
    // Records opens on its first half that is on.
    ...(on.notes || on.gallery || on.places || on.lists
      ? [
          {
            to: on.notes ? '/app/records' : on.lists ? '/app/records/lists' : on.gallery ? '/app/records/gallery' : '/app/records/places',
            label: t('nav.records'),
            icon: BookOpenIcon,
            key: 'r',
          },
        ]
      : []),
    { to: '/app/granary', label: t('nav.granary'), icon: WalletIcon, key: 'm' },
    { to: '/app/farmer', label: t('nav.farmer'), icon: UserRoundIcon, key: 'p' },
  ];
}

/**
 * The rail on the left on a wide screen, and a bar at the bottom on a
 * phone: the same five places as the phone's tabs ([[Web]]).
 */
function Rail({ tabs }: { tabs: Tab[] }) {
  const { t } = useTranslation();
  const item = ({ isActive }: { isActive: boolean }) =>
    cn(
      'flex flex-1 flex-col items-center gap-1 rounded-lg px-1 py-2 text-[11px] font-extrabold outline-none transition-colors hover:bg-accent focus-visible:ring-2 focus-visible:ring-ring md:flex-none md:py-2.5',
      isActive ? 'text-primary' : 'text-muted-foreground',
    );
  return (
    <nav
      aria-label={t('nav.main')}
      className="fixed inset-x-0 bottom-0 z-40 flex border-t bg-background/95 px-1 pb-[env(safe-area-inset-bottom)] backdrop-blur md:sticky md:top-0 md:inset-auto md:h-dvh md:w-24 md:flex-col md:gap-1 md:border-t-0 md:border-e md:px-2 md:py-4"
    >
      <Link to="/app/field" className="mb-4 hidden justify-center md:flex" aria-label={t('nav.field')}>
        <HarvestMark className="size-10" />
      </Link>
      {tabs.map((tab) => (
        <NavLink key={tab.to} to={tab.to} className={item} title={`${tab.label} (g ${tab.key})`}>
          <tab.icon className="size-5" aria-hidden />
          <span>{tab.label}</span>
        </NavLink>
      ))}
      <NavLink to="/app/settings" className={(state) => cn(item(state), 'md:mt-auto')}>
        <SettingsIcon className="size-5" aria-hidden />
        <span>{t('nav.settings')}</span>
      </NavLink>
    </nav>
  );
}

function Banners({ startedOffline }: { startedOffline: boolean }) {
  const { t } = useTranslation();
  const { user } = useHarvest();
  const status = useSyncStatus();
  const [sent, setSent] = useState(false);
  const offline = status.phase === 'offline' || (startedOffline && status.phase !== 'idle');
  return (
    <div className="flex flex-col gap-2 empty:hidden" aria-live="polite">
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

function Shell({ startedOffline }: { startedOffline: boolean }) {
  const { t } = useTranslation();
  const tabs = useTabs();
  const navigate = useNavigate();
  const dialogs = useDialogs();

  useShortcuts({
    n: () => dialogs.plantSeed(),
    e: () => dialogs.logExpense(),
    '/': () => dialogs.openSearch(),
    ...Object.fromEntries(tabs.map((tab) => [`g ${tab.key}`, () => void navigate(tab.to)])),
    'g s': () => void navigate('/app/settings'),
    'g g': () => void navigate('/app/field/goals'),
    'g c': () => void navigate('/app/field/calendar'),
  });

  return (
    <div className="flex min-h-dvh flex-col md:flex-row">
      <a
        href="#app-main"
        className="sr-only focus:not-sr-only focus:absolute focus:start-2 focus:top-2 focus:z-50 focus:rounded-md focus:bg-card focus:p-2"
      >
        {t('common.skipToContent')}
      </a>
      <Rail tabs={tabs} />
      <div className="flex min-w-0 flex-1 flex-col pb-20 md:pb-0">
        <header className="sticky top-0 z-30 flex h-14 items-center gap-1 border-b bg-background/90 px-3 backdrop-blur md:px-6">
          <Link to="/app/field" className="md:hidden" aria-label={t('nav.field')}>
            <HarvestMark className="size-8" />
          </Link>
          <div className="ms-auto flex items-center gap-1">
            <PomodoroChip />
            <SyncIndicator />
            <Button variant="ghost" size="icon" aria-label={t('app.search')} title={`${t('app.search')} (/)`} onClick={dialogs.openSearch}>
              <SearchIcon />
            </Button>
            <Button size="sm" onClick={() => dialogs.plantSeed()} title={`${t('seed.plant')} (n)`}>
              <PlusIcon />
              <span className="hidden sm:inline">{t('seed.plant')}</span>
              <span className="sr-only sm:hidden">{t('seed.plant')}</span>
            </Button>
          </div>
        </header>
        <main id="app-main" tabIndex={-1} className="mx-auto flex w-full max-w-6xl flex-1 flex-col gap-4 px-3 py-4 outline-none md:px-6">
          <Banners startedOffline={startedOffline} />
          <OnboardingGate />
          <Routes>
            <Route index element={<Navigate to="field" replace />} />
            <Route path="field" element={<FieldScreen tab="today" />} />
            <Route path="field/calendar" element={<CalendarScreen />} />
            <Route path="field/seed/:uuid" element={<SeedScreen />} />
            <Route path="field/focus" element={<PomodoroScreen />} />
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
            <Route path="welcome" element={<OnboardingScreen />} />
            <Route path="*" element={<Navigate to="field" replace />} />
          </Routes>
        </main>
      </div>
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
      <Shell startedOffline={startedOffline} />
    </DialogsProvider>
  );
}
