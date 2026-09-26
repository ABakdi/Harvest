import { SettingsIcon } from 'lucide-react';
import type { ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { Link, NavLink } from 'react-router';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { EmptyState } from '../components/bits';
import { useFeatures, useFeaturesOrOff } from '../components/settings-bits';
import type { FeatureSwitches } from '../data/settings';

/** Whether Notes, the Gallery, Places and Lists are all switched off; undefined until read. */
export function useRecordsOff(): boolean | undefined {
  const switches = useFeatures();
  return switches && allOff(switches);
}

function allOff(switches: FeatureSwitches): boolean {
  return !switches.notes && !switches.gallery && !switches.places && !switches.lists;
}

type RecordsFeature = 'gallery' | 'places' | 'lists';

/**
 * Records opened by link with all four views switched off: says so,
 * and where to switch one on, as the Body does with both halves off.
 * With [feature], just that view is off — opened by a link to it — and
 * the tabs still lead to the others.
 */
export function RecordsOff({ feature }: { feature?: RecordsFeature }) {
  const { t } = useTranslation();
  return (
    <div className="flex flex-col gap-4">
      {feature ? <RecordsTabs /> : <h1 className="text-2xl font-extrabold">{t('nav.records')}</h1>}
      <EmptyState
        icon={<SettingsIcon />}
        title={feature ? t(`recordsWeb.viewOff.${feature}`) : t('recordsWeb.offTitle')}
        body={feature ? t('recordsWeb.viewOffBody') : t('recordsWeb.offBody')}
        action={
          <Button asChild variant="outline">
            <Link to="/app/settings">{t('bodyWeb.offAction')}</Link>
          </Button>
        }
      />
    </div>
  );
}

/**
 * Notes, Lists, the Gallery and Places under one roof, in the phone's
 * order ([[Notes]] N6, [[Lists]]): what I wrote, what I have not got to
 * yet, and what I took and walked. A view whose feature is switched off
 * is not offered.
 */
export function RecordsTabs() {
  const { t } = useTranslation();
  const on = useFeaturesOrOff();
  const tab = ({ isActive }: { isActive: boolean }) =>
    cn(
      'rounded-md px-3 py-1.5 text-sm font-extrabold outline-none focus-visible:ring-2 focus-visible:ring-ring',
      isActive ? 'bg-card text-foreground shadow-sm' : 'text-muted-foreground hover:text-foreground',
    );
  return (
    <nav aria-label={t('records.tabs')} className="flex w-fit gap-1 rounded-lg bg-muted p-1">
      {on.notes && (
        <NavLink to="/app/records" end className={tab}>
          {t('nav.notes')}
        </NavLink>
      )}
      {on.lists && (
        <NavLink to="/app/records/lists" className={tab}>
          {t('lists.title')}
        </NavLink>
      )}
      {on.gallery && (
        <NavLink to="/app/records/gallery" className={tab}>
          {t('gallery.title')}
        </NavLink>
      )}
      {on.places && (
        <NavLink to="/app/records/places" className={tab}>
          {t('places.title')}
        </NavLink>
      )}
    </nav>
  );
}

/**
 * One view of Records, only while its switch is on: a direct link to
 * `/app/records/gallery` with the Gallery off says it is off, as
 * `/app/records` does, rather than open it anyway.
 */
export function RecordsView({ feature, children }: { feature: RecordsFeature; children: ReactNode }) {
  const switches = useFeatures();
  if (!switches) return null;
  if (allOff(switches)) return <RecordsOff />;
  return switches[feature] ? children : <RecordsOff feature={feature} />;
}
