import { useLiveQuery } from 'dexie-react-hooks';
import { HeartPulseIcon, SmartphoneIcon } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { useHarvest } from '../context';

/**
 * Body arrives in the next milestone (sleep, weight and steps as views).
 * The rows already sync, so this says how many are here and where they
 * are recorded: the steps source, the alarms and the gym sessions are
 * the phone's by nature ([[Web]]).
 */
export function BodyScreen() {
  const { t } = useTranslation();
  const { db } = useHarvest();
  const counts = useLiveQuery(
    async () => ({
      sleep: await db.rows('sleep_sessions').count(),
      weights: await db.rows('body_weights').count(),
      steps: await db.rows('step_days').count(),
      workouts: await db.rows('workout_sessions').count(),
    }),
    [db],
  );
  return (
    <div className="mx-auto flex w-full max-w-xl flex-col items-center gap-4 py-10 text-center">
      <HeartPulseIcon className="size-12 text-primary" aria-hidden />
      <h1 className="text-2xl font-extrabold">{t('body.title')}</h1>
      <p className="text-muted-foreground">{t('body.soon')}</p>
      {counts && (
        <ul className="grid w-full grid-cols-2 gap-2 text-sm">
          <li className="rounded-lg bg-card p-3">{t('body.sleep', { count: counts.sleep })}</li>
          <li className="rounded-lg bg-card p-3">{t('body.weights', { count: counts.weights })}</li>
          <li className="rounded-lg bg-card p-3">{t('body.steps', { count: counts.steps })}</li>
          <li className="rounded-lg bg-card p-3">{t('body.workouts', { count: counts.workouts })}</li>
        </ul>
      )}
      <p className="flex items-center gap-2 text-sm text-muted-foreground">
        <SmartphoneIcon className="size-4" aria-hidden />
        {t('body.phoneOnly')}
      </p>
    </div>
  );
}
