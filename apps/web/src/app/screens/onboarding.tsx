import { type Schedule, dailySchedule, defaultDailyHarvestGoal } from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import { CheckIcon, MinusIcon, PlusIcon, SlidersHorizontalIcon, SmartphoneIcon, SproutIcon } from 'lucide-react';
import { useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Navigate, useLocation, useNavigate } from 'react-router';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { FeatureSwitchList } from '../components/settings-bits';
import { useHarvest, useSyncStatus } from '../context';
import type { HarvestDB } from '../data/db';
import { type SeedInput, plantSeed } from '../data/seeds';
import { type FeatureSwitches, featureKeys, features, settingKeys, writeSetting } from '../data/settings';

/**
 * Whether this account has never been set up: no `onboarding.done` on
 * record and not one seed, live or retired. Either is proof enough that
 * somebody already chose — on the phone or here.
 */
export async function needsOnboarding(db: HarvestDB): Promise<boolean> {
  const [done, seeds] = await Promise.all([db.rows('kv_settings').get(settingKeys.onboardingDone), db.rows('commitments').count()]);
  return done === undefined && seeds === 0;
}

/**
 * Whether to ask now. Never before the first sync has finished — an
 * empty browser is not an empty account, and the phone's seeds may be
 * on their way — unless the account cannot sync yet at all, which is
 * the one case where the server holds nothing either.
 */
export function useOnboardingDue(): boolean | undefined {
  const { db } = useHarvest();
  const status = useSyncStatus();
  const settled = status.lastSyncedAt !== null || status.phase === 'unverified';
  const empty = useLiveQuery(() => needsOnboarding(db), [db]);
  if (empty === undefined) return undefined;
  return settled && empty;
}

/**
 * The stores that have just answered the welcome. The answer is written
 * before the field opens, but the gate's own live query hears of it a
 * moment later; without this it would send the field straight back to
 * the welcome for a frame.
 */
const answered = new WeakSet<object>();

/** Sends a first-time account to the welcome, once. */
export function OnboardingGate() {
  const { db } = useHarvest();
  const due = useOnboardingDue();
  const location = useLocation();
  if (!due || answered.has(db) || location.pathname === '/app/welcome') return null;
  return <Navigate to="/app/welcome" replace />;
}

type TemplateId = 'read' | 'fit' | 'language' | 'meditate' | 'journal';

/** The quick-start seeds (`_templates`), exactly as the phone plants them. */
const templates: { id: TemplateId; seed: Omit<SeedInput, 'title'> }[] = [
  { id: 'read', seed: { type: 'project', totalTarget: 300, dailyCommitment: 10 } },
  { id: 'fit', seed: { type: 'habit', schedule: dailySchedule } },
  { id: 'language', seed: { type: 'habit', schedule: dailySchedule } },
  { id: 'meditate', seed: { type: 'habit', schedule: { type: 'timesPerWeek', times: 3 } satisfies Schedule } },
  { id: 'journal', seed: { type: 'habit', schedule: dailySchedule } },
];

const pages = 4;

/**
 * First run on the web (`OnboardingScreen`), for an account with nothing
 * in it: a welcome, a few seeds to start with, the Daily Harvest Goal,
 * and the parts of the app that stay hidden unless asked for. The
 * phone's reminders page is not here — reminders ring on the phone.
 *
 * Skipping plants nothing and switches nothing on; either way the
 * answer is written as `onboarding.done`, so neither the phone nor
 * another browser asks again.
 */
export function OnboardingScreen() {
  const { t } = useTranslation();
  const { db, settings, writer } = useHarvest();
  const navigate = useNavigate();
  const due = useOnboardingDue();
  const [page, setPage] = useState(0);
  const [picked, setPicked] = useState<Set<TemplateId>>(() => new Set(['read', 'fit']));
  const [goal, setGoal] = useState(defaultDailyHarvestGoal);
  const [switches, setSwitches] = useState<FeatureSwitches>({ notes: false, gallery: false, health: false, gym: false, places: false, lists: false });
  const [finishing, setFinishing] = useState(false);
  // Answers a second press at once, before the disabled buttons are drawn.
  const started = useRef(false);

  // Already set up (or set up elsewhere while this was open): nothing to ask.
  if (due === false && !finishing) return <Navigate to="/app/field" replace />;
  if (due === undefined) return null;

  const skip = async () => {
    if (started.current) return;
    started.current = true;
    setFinishing(true);
    try {
      await settings.setString(settingKeys.onboardingDone, 'true');
      answered.add(db);
      void navigate('/app/field', { replace: true });
    } catch {
      started.current = false;
      setFinishing(false);
      toast.error(t('common.saveFailed'));
    }
  };

  // The seeds, the goal, the switches and `onboarding.done` land as one
  // write or not at all: a failure halfway must not leave seeds planted
  // (which ends the asking) with the rest of the answer lost.
  const finish = async () => {
    if (started.current) return;
    started.current = true;
    setFinishing(true);
    try {
      await writer.run(async (tx) => {
        for (const template of templates) {
          if (!picked.has(template.id)) continue;
          await plantSeed(tx, { ...template.seed, title: t(`onboardingWeb.template.${template.id}`) });
        }
        // Every switch is written, on or off, so the answer is a decision
        // on record rather than an absent row.
        await writeSetting(tx, settingKeys.dailyHarvestGoal, String(goal));
        for (const feature of features) await writeSetting(tx, featureKeys[feature], String(switches[feature]));
        await writeSetting(tx, settingKeys.onboardingDone, 'true');
      });
      answered.add(db);
      void navigate('/app/field', { replace: true });
    } catch {
      started.current = false;
      setFinishing(false);
      toast.error(t('common.saveFailed'));
    }
  };

  const last = page === pages - 1;
  return (
    <div className="mx-auto flex w-full max-w-xl flex-col gap-6 py-4">
      <div className="flex justify-end">
        <Button variant="ghost" disabled={finishing} onClick={() => void skip()}>
          {t('onboardingWeb.skip')}
        </Button>
      </div>

      <section aria-live="polite" className="flex min-h-80 flex-col items-center gap-4 text-center">
        {page === 0 && (
          <>
            <SproutIcon className="size-24 text-primary" aria-hidden />
            <h1 className="text-3xl font-extrabold">{t('onboardingWeb.welcomeTitle')}</h1>
            <p className="whitespace-pre-line text-muted-foreground">{t('onboardingWeb.welcomeBody')}</p>
          </>
        )}
        {page === 1 && (
          <>
            <h1 className="text-3xl font-extrabold">{t('onboardingWeb.templatesTitle')}</h1>
            <p className="text-muted-foreground">{t('onboardingWeb.templatesBody')}</p>
            <div className="flex flex-wrap justify-center gap-2" role="group" aria-label={t('onboardingWeb.templatesTitle')}>
              {templates.map((template) => {
                const on = picked.has(template.id);
                return (
                  <Button
                    key={template.id}
                    variant={on ? 'default' : 'outline'}
                    aria-pressed={on}
                    onClick={() =>
                      setPicked((current) => {
                        const next = new Set(current);
                        if (!next.delete(template.id)) next.add(template.id);
                        return next;
                      })
                    }
                  >
                    {on && <CheckIcon aria-hidden />}
                    {t(`onboardingWeb.template.${template.id}`)}
                  </Button>
                );
              })}
            </div>
          </>
        )}
        {page === 2 && (
          <>
            <h1 className="text-3xl font-extrabold">{t('settings.dailyGoal')}</h1>
            <p className="text-muted-foreground">{t('settings.dailyGoalHint')}</p>
            <div className="flex items-center gap-6">
              <Button
                variant="secondary"
                size="icon"
                aria-label={t('settingsWeb.less', { what: t('settings.dailyGoal') })}
                disabled={goal <= 1}
                onClick={() => setGoal(goal - 1)}
              >
                <MinusIcon />
              </Button>
              <span className="text-6xl font-extrabold tabular" aria-hidden>
                {goal}
              </span>
              <Button
                variant="secondary"
                size="icon"
                aria-label={t('settingsWeb.more', { what: t('settings.dailyGoal') })}
                disabled={goal >= 10}
                onClick={() => setGoal(goal + 1)}
              >
                <PlusIcon />
              </Button>
            </div>
            <p className="text-lg font-bold">{t('settings.actionsADay', { count: goal })}</p>
          </>
        )}
        {page === 3 && (
          <>
            <SlidersHorizontalIcon className="size-16 text-primary" aria-hidden />
            <h1 className="text-3xl font-extrabold">{t('onboardingWeb.extrasTitle')}</h1>
            <p className="text-muted-foreground">{t('onboardingWeb.extrasBody')}</p>
            <div className="w-full rounded-2xl border bg-card p-4 text-start">
              <FeatureSwitchList values={switches} onChange={(feature, on) => setSwitches({ ...switches, [feature]: on })} />
            </div>
            <p className="flex items-center gap-2 text-xs text-muted-foreground">
              <SmartphoneIcon className="size-4 shrink-0" aria-hidden />
              {t('onboardingWeb.remindersOnPhone')}
            </p>
          </>
        )}
      </section>

      <div className="flex flex-col items-center gap-4">
        <div className="flex gap-2" aria-label={t('onboardingWeb.step', { page: page + 1, pages })} role="img">
          {Array.from({ length: pages }, (_, index) => (
            <span key={index} className={cn('size-2 rounded-full', index === page ? 'bg-primary' : 'bg-foreground/20')} />
          ))}
        </div>
        <div className="flex w-full gap-2">
          {page > 0 && (
            <Button variant="outline" size="lg" disabled={finishing} onClick={() => setPage(page - 1)}>
              {t('onboardingWeb.back')}
            </Button>
          )}
          <Button size="lg" className="flex-1" disabled={finishing} onClick={() => (last ? void finish() : setPage(page + 1))}>
            {last ? t('onboardingWeb.start') : t('onboardingWeb.next')}
          </Button>
        </div>
      </div>
    </div>
  );
}
