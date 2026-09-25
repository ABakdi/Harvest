import { useTranslation } from 'react-i18next';
import { NavLink } from 'react-router';
import { cn } from '@/lib/utils';
import { useFeaturesOrOff } from '../components/settings-bits';

/**
 * Notes, the Gallery and Places under one roof, as on the phone
 * ([[Notes]] N6): three views of what I wrote, took and walked. A view
 * whose feature is switched off is not offered.
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
