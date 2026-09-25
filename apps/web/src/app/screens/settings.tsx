import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { KeyRoundIcon, LogOutIcon, MonitorSmartphoneIcon, RefreshCwIcon, ShieldCheckIcon, SmartphoneIcon, Trash2Icon } from 'lucide-react';
import { useId, useState } from 'react';
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
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { api, ApiError } from '@/lib/api';
import { currencies, formatDate } from '@/lib/format';
import { useLeave } from '../app-root';
import { GeotagSetting } from '../components/geotag-setting';
import { DataCard } from '../components/data-card';
import { PassphrasePrompt } from '../components/passphrase-prompt';
import { LanguageSelect, PresetPicker, ThemeModePicker } from '../components/prefs-pickers';
import { useRelativeTime } from '../components/relative-time';
import { useHarvest, useSyncStatus } from '../context';
import { SettingsRow as Row, SettingsSection as Section, Stepper, FeatureSwitchList, useFeaturesOrOff } from '../components/settings-bits';
import { DailyCycleCard, SleepNightsCard } from '../components/settings-cycle';
import { RatesCard } from '../components/settings-rates';
import { featureKeys, pomodoroSettings, settingKeys } from '../data/settings';
import { useDefaultCurrency, usePrivateKey, useSetting } from '../hooks';

function SyncSection() {
  const { t } = useTranslation();
  const { engine } = useHarvest();
  const status = useSyncStatus();
  const unlocked = usePrivateKey();
  const ago = useRelativeTime(status.lastSyncedAt);
  const [unlocking, setUnlocking] = useState(false);
  return (
    <Section title={t('settings.sync')} id="settings-sync">
      <Row label={t('settings.lastSynced')} hint={status.lastSyncedAt ? formatDate(status.lastSyncedAt, { dateStyle: 'medium', timeStyle: 'short' }) : undefined}>
        <div className="flex items-center gap-2">
          <span className="text-sm text-muted-foreground">{status.lastSyncedAt ? ago : t('sync.notYet')}</span>
          <Button variant="outline" size="sm" onClick={() => void engine.sync()} disabled={status.phase === 'syncing'}>
            <RefreshCwIcon className={status.phase === 'syncing' ? 'animate-spin' : undefined} />
            {t('sync.syncNow')}
          </Button>
        </div>
      </Row>
      <ul className="grid gap-2 text-sm sm:grid-cols-2">
        <li className="rounded-lg bg-muted/60 p-3">{t('settings.pending', { count: status.pending })}</li>
        <li className="rounded-lg bg-muted/60 p-3">{t('settings.invalid', { count: status.invalid })}</li>
        {status.sealed > 0 && <li className="rounded-lg bg-muted/60 p-3">{t('settings.sealed', { count: status.sealed })}</li>}
        {status.locked > 0 && <li className="rounded-lg bg-muted/60 p-3">{t('settings.locked', { count: status.locked })}</li>}
      </ul>
      {status.error && status.phase === 'error' && <p className="text-sm text-destructive">{status.error}</p>}
      <Row label={t('passphrase.title')} hint={t('settings.passphraseHint')}>
        {unlocked ? (
          <Badge variant="secondary" className="gap-1">
            <ShieldCheckIcon />
            {t('settings.passphraseSet')}
          </Badge>
        ) : (
          <Button variant="outline" size="sm" onClick={() => setUnlocking(true)}>
            <KeyRoundIcon />
            {t('settings.enterPassphrase')}
          </Button>
        )}
      </Row>
      {unlocking && (
        <Dialog open onOpenChange={(open) => !open && setUnlocking(false)}>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>{t('passphrase.title')}</DialogTitle>
              <DialogDescription className="sr-only">{t('passphrase.lead')}</DialogDescription>
            </DialogHeader>
            <PassphrasePrompt onUnlocked={() => setUnlocking(false)} />
          </DialogContent>
        </Dialog>
      )}
    </Section>
  );
}

function SessionsList() {
  const { t } = useTranslation();
  const client = useQueryClient();
  const sessions = useQuery({ queryKey: ['sessions'], queryFn: () => api.sessions(), retry: 1 });
  const revoke = useMutation({
    mutationFn: (id: string) => api.revokeSession(id),
    onSuccess: () => void client.invalidateQueries({ queryKey: ['sessions'] }),
    onError: () => toast.error(t('common.somethingWrong')),
  });
  if (sessions.isPending) return <p className="text-sm text-muted-foreground">{t('common.loading')}</p>;
  if (sessions.isError) return <p className="text-sm text-muted-foreground">{t('settings.sessionsOffline')}</p>;
  return (
    <ul className="flex flex-col gap-2">
      {sessions.data.sessions.map((session) => (
        <li key={session.id} className="flex items-center gap-3 rounded-lg bg-muted/60 p-3">
          <MonitorSmartphoneIcon className="size-5 shrink-0 text-muted-foreground" aria-hidden />
          <div className="flex min-w-0 flex-1 flex-col">
            <span className="truncate font-bold">
              {session.deviceName ?? t(`settings.client.${session.client}`)}
              {session.current && (
                <Badge variant="secondary" className="ms-2">
                  {t('settings.thisDevice')}
                </Badge>
              )}
            </span>
            <span className="text-xs text-muted-foreground">
              {t('settings.sessionSeen', {
                first: formatDate(session.createdAt),
                last: formatDate(session.lastSeenAt, { dateStyle: 'medium', timeStyle: 'short' }),
              })}
            </span>
          </div>
          {!session.current && (
            <Button
              variant="ghost"
              size="sm"
              disabled={revoke.isPending}
              onClick={() => revoke.mutate(session.id)}
              aria-label={t('settings.signOutDevice', { name: session.deviceName ?? t(`settings.client.${session.client}`) })}
            >
              {t('settings.signOut')}
            </Button>
          )}
        </li>
      ))}
    </ul>
  );
}

function DeleteAccountDialog({ onClose }: { onClose: () => void }) {
  const { t } = useTranslation();
  const leave = useLeave();
  const id = useId();
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('settings.deleteTitle')}</DialogTitle>
          <DialogDescription>{t('settings.deleteBody')}</DialogDescription>
        </DialogHeader>
        <form
          className="flex flex-col gap-3"
          onSubmit={(event) => {
            event.preventDefault();
            setBusy(true);
            setError(null);
            leave.deleteAccount(password).catch((failure: unknown) => {
              setBusy(false);
              setError(
                failure instanceof ApiError && failure.code === 'forbidden'
                  ? t('settings.wrongPassword')
                  : failure instanceof ApiError && failure.isNetwork
                    ? t('common.offline')
                    : t('common.somethingWrong'),
              );
            });
          }}
        >
          <Label htmlFor={`${id}-password`}>{t('auth.password')}</Label>
          <Input
            id={`${id}-password`}
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
          />
          {error && (
            <p role="alert" className="text-sm font-semibold text-destructive">
              {error}
            </p>
          )}
          <DialogFooter>
            <Button variant="outline" onClick={onClose}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" variant="destructive" disabled={busy || !password}>
              {t('settings.deleteConfirm')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

function AccountSection() {
  const { t } = useTranslation();
  const { user, engine } = useHarvest();
  const leave = useLeave();
  const [warning, setWarning] = useState<number | null>(null);
  const [deleting, setDeleting] = useState(false);

  // W5: a signed-out browser holds nothing, so anything not yet sent is
  // about to be lost; say so first.
  const signOut = async () => {
    await engine.refreshCounts();
    const waiting = engine.status.pending + engine.status.invalid + engine.status.locked;
    if (waiting > 0) setWarning(waiting);
    else leave.signOut();
  };

  return (
    <Section title={t('settings.account')} id="settings-account">
      <Row label={t('auth.email')} hint={user.verifiedAt ? t('settings.verified') : t('settings.unverified')}>
        <span className="font-bold" dir="ltr">
          {user.email}
        </span>
      </Row>
      <div className="flex flex-col gap-2">
        <h3 className="text-sm font-bold">{t('settings.devices')}</h3>
        <SessionsList />
      </div>
      <div className="flex flex-wrap gap-2">
        <Button variant="outline" onClick={() => void signOut()}>
          <LogOutIcon />
          {t('settings.signOutHere')}
        </Button>
        <Button variant="ghost" className="text-destructive" onClick={() => setDeleting(true)}>
          <Trash2Icon />
          {t('settings.deleteAccount')}
        </Button>
      </div>
      <AlertDialog open={warning !== null} onOpenChange={(open) => !open && setWarning(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>{t('settings.unsyncedTitle')}</AlertDialogTitle>
            <AlertDialogDescription>{t('settings.unsyncedBody', { count: warning ?? 0 })}</AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel onClick={() => void engine.sync()}>{t('settings.syncFirst')}</AlertDialogCancel>
            <AlertDialogAction destructive onClick={() => leave.signOut()}>
              {t('settings.signOutAnyway')}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
      {deleting && <DeleteAccountDialog onClose={() => setDeleting(false)} />}
    </Section>
  );
}

/**
 * The day: how many actions make it, its hours, and — with Health on —
 * the weekdays that are their own night (`SettingsSection.harvest`).
 * The alarm and the wind-down ring on the phone, so they are set there.
 */
export function HarvestSection() {
  const { t } = useTranslation();
  const { settings } = useHarvest();
  const goal = useSetting(settingKeys.dailyHarvestGoal);
  const { health } = useFeaturesOrOff();
  const id = useId();
  return (
    <Section title={t('settings.harvest')} id="settings-harvest">
      <Row label={t('settings.dailyGoal')} hint={t('settings.dailyGoalHint')} htmlFor={`${id}-goal`}>
        <Select value={goal ?? '3'} onValueChange={(value) => void settings.setString(settingKeys.dailyHarvestGoal, value)}>
          <SelectTrigger id={`${id}-goal`} className="w-full sm:w-40">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {Array.from({ length: 10 }, (_, i) => String(i + 1)).map((value) => (
              <SelectItem key={value} value={value}>
                {t('settings.actionsADay', { count: Number(value) })}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </Row>
      <div className="flex flex-col gap-3 border-t pt-4">
        <div className="flex flex-col">
          <h3 className="text-sm font-extrabold">{t('settingsWeb.cycle')}</h3>
          <span className="text-xs text-muted-foreground">{t('settingsWeb.cycleHint')}</span>
        </div>
        <DailyCycleCard />
      </div>
      {health && (
        <div className="flex flex-col gap-3 border-t pt-4">
          <div className="flex flex-col">
            <h3 className="text-sm font-extrabold">{t('settingsWeb.ownNights')}</h3>
            <span className="text-xs text-muted-foreground">{t('settingsWeb.ownNightsHint')}</span>
          </div>
          <SleepNightsCard />
        </div>
      )}
    </Section>
  );
}

/** The parts of the app that stay out of the way until asked for (`FeaturesCard`). */
export function ExtrasSection() {
  const { t } = useTranslation();
  const { settings } = useHarvest();
  const values = useFeaturesOrOff();
  return (
    <Section title={t('settingsWeb.extras')} id="settings-extras" lead={t('settingsWeb.extrasLead')}>
      <FeatureSwitchList values={values} onChange={(feature, on) => void settings.setBool(featureKeys[feature], on)} />
    </Section>
  );
}

/** The four numbers of the focus timer (`_PomodoroCard`). */
export function PomodoroSection() {
  const { t } = useTranslation();
  const { settings } = useHarvest();
  return (
    <Section title={t('settingsWeb.pomodoro')} id="settings-pomodoro">
      <ul className="flex flex-col divide-y">
        {pomodoroSettings.map((setting) => (
          <PomodoroRow
            key={setting.key}
            label={t(`settingsWeb.pomodoroLen.${setting.name}`)}
            setting={setting}
            onChange={(value) => void settings.setInt(setting.key, value)}
          />
        ))}
      </ul>
    </Section>
  );
}

function PomodoroRow({
  label,
  setting,
  onChange,
}: {
  label: string;
  setting: (typeof pomodoroSettings)[number];
  onChange: (value: number) => void;
}) {
  const { t } = useTranslation();
  const raw = useSetting(setting.key);
  const stored = Number.parseInt(raw ?? '', 10);
  const read = Number.isFinite(stored) ? stored : setting.fallback;
  // The last step taken, shown until the stored value catches up: two
  // quick presses step twice, rather than both stepping from the same
  // read.
  const [pending, setPending] = useState<number | null>(null);
  if (pending !== null && read === pending) setPending(null);
  const value = pending ?? read;
  return (
    <li className="flex items-center justify-between gap-3 py-2">
      <div className="flex flex-col">
        <span className="text-sm font-bold">{label}</span>
        <span className="text-sm text-muted-foreground tabular">
          {setting.name === 'blocks' ? value : t('settingsWeb.minutes', { count: value })}
        </span>
      </div>
      <Stepper
        value={value}
        min={setting.min}
        max={setting.max}
        step={setting.step}
        label={label}
        disabled={raw === undefined}
        onChange={(next) => {
          setPending(next);
          onChange(next);
        }}
      />
    </li>
  );
}

/** The currency amounts are shown in, and the rates between them (`SettingsSection.money`). */
export function MoneySection() {
  const { t } = useTranslation();
  const { settings } = useHarvest();
  const currency = useDefaultCurrency();
  const id = useId();
  return (
    <Section title={t('settingsWeb.money')} id="settings-money">
      <Row label={t('settings.defaultCurrency')} htmlFor={`${id}-currency`}>
        <Select value={currency} onValueChange={(value) => void settings.setString(settingKeys.defaultCurrency, value)}>
          <SelectTrigger id={`${id}-currency`} className="w-full sm:w-40">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {currencies.map((code) => (
              <SelectItem key={code} value={code}>
                {code}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </Row>
      <div className="border-t pt-4">
        <RatesCard />
      </div>
    </Section>
  );
}

/**
 * What only the phone can do, named rather than left out: the web has
 * no alarm, no lock of its own, no home screen and no archive to write
 * to a folder ([[Web]], phone-only by nature).
 */
export function PhoneOnlySection() {
  const { t } = useTranslation();
  return (
    <Section title={t('settingsWeb.onPhone')} id="settings-phone" lead={t('settingsWeb.onPhoneLead')}>
      <ul className="grid gap-2 text-sm sm:grid-cols-2">
        {(['reminders', 'sleepAlarm', 'appLock', 'widget', 'steps'] as const).map((item) => (
          <li key={item} className="flex items-start gap-2 rounded-lg bg-muted/60 p-3">
            <SmartphoneIcon className="mt-0.5 size-4 shrink-0 text-muted-foreground" aria-hidden />
            <span className="flex flex-col">
              <span className="font-bold">{t(`settingsWeb.phone.${item}`)}</span>
              <span className="text-xs text-muted-foreground">{t(`settingsWeb.phone.${item}Hint`)}</span>
            </span>
          </li>
        ))}
      </ul>
    </Section>
  );
}

const shortcutList: [string, string][] = [
  ['N', 'settings.keys.seed'],
  ['E', 'settings.keys.expense'],
  ['/', 'settings.keys.search'],
  ['G F', 'settings.keys.field'],
  ['G G', 'settings.keys.goals'],
  ['G B', 'settings.keys.body'],
  ['G R', 'settings.keys.records'],
  ['G M', 'settings.keys.granary'],
  ['G P', 'settings.keys.farmer'],
  ['G S', 'settings.keys.settings'],
  ['J / K', 'settings.keys.move'],
  ['Space', 'settings.keys.check'],
];

export function SettingsScreen() {
  const { t } = useTranslation();
  const id = useId();
  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-2xl font-extrabold">{t('nav.settings')}</h1>
      <HarvestSection />
      <ExtrasSection />
      <GeotagSetting />
      <PomodoroSection />
      <MoneySection />
      <Section title={t('settings.appearance')} id="settings-appearance">
        <Row label={t('prefs.language')} htmlFor={`${id}-language`}>
          <LanguageSelect id={`${id}-language`} />
        </Row>
        <div className="flex flex-col gap-2">
          <span className="text-sm font-bold">{t('prefs.theme')}</span>
          <ThemeModePicker />
        </div>
        <div className="flex flex-col gap-2">
          <span className="text-sm font-bold">{t('prefs.style')}</span>
          <PresetPicker />
        </div>
      </Section>
      <PhoneOnlySection />
      <SyncSection />
      <DataCard />
      <AccountSection />
      <Section title={t('settings.keyboard')} id="settings-keys">
        <dl className="grid gap-x-6 gap-y-2 text-sm sm:grid-cols-2">
          {shortcutList.map(([keys, label]) => (
            <div key={keys} className="flex items-center justify-between gap-3">
              <dt>{t(label)}</dt>
              <dd>
                <kbd className="rounded-md border bg-muted px-2 py-0.5 font-mono text-xs">{keys}</kbd>
              </dd>
            </div>
          ))}
        </dl>
      </Section>
    </div>
  );
}
