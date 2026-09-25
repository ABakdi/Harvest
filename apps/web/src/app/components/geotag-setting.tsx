import { useId, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Switch } from '@/components/ui/switch';
import { useHarvest } from '../context';
import { placesFeatureKey, webGeotaggingKey } from '../data/geotags';
import { switchOn } from '../data/settings';
import { useSetting } from '../hooks';
import { SettingsRow, SettingsSection } from './settings-bits';

/**
 * Asks the browser for its location once, so the permission prompt
 * comes when I turn the switch on rather than in the middle of logging
 * an expense. Only a refusal counts against it: a fix that does not
 * come indoors is what `unavailable` is for (PL3).
 */
function askForLocation(): Promise<'granted' | 'refused' | 'unsupported'> {
  if (typeof navigator === 'undefined' || !('geolocation' in navigator)) return Promise.resolve('unsupported');
  return new Promise((resolve) => {
    navigator.geolocation.getCurrentPosition(
      () => resolve('granted'),
      (error) => resolve(error.code === error.PERMISSION_DENIED ? 'refused' : 'granted'),
      { timeout: 10_000, maximumAge: 10 * 60_000 },
    );
  });
}

/**
 * Geotagging what I do in this browser ([[Places]] PL2): off until I
 * turn it on here, whatever the phone does, because it asks this
 * browser for its location. The switch is this device's own and never
 * syncs; the place it finds is private-tier like every geotag (PL6).
 */
export function GeotagSetting() {
  const { t } = useTranslation();
  const { settings } = useHarvest();
  const id = useId();
  const mine = useSetting(webGeotaggingKey);
  const places = useSetting(placesFeatureKey);
  const [asking, setAsking] = useState(false);
  const placesOn = switchOn(places);

  const change = async (on: boolean) => {
    if (!on) {
      await settings.setBool(webGeotaggingKey, false);
      return;
    }
    setAsking(true);
    const answer = await askForLocation();
    setAsking(false);
    if (answer === 'granted') {
      await settings.setBool(webGeotaggingKey, true);
      return;
    }
    toast.error(answer === 'refused' ? t('places.geotagRefused') : t('places.geotagUnsupported'));
  };

  return (
    <SettingsSection title={t('places.geotagTitle')} id={`${id}-section`}>
      <SettingsRow
        label={t('places.geotagLabel')}
        hint={placesOn ? t('places.geotagHint') : t('places.geotagNeedsPlaces')}
        htmlFor={`${id}-switch`}
      >
        <Switch
          id={`${id}-switch`}
          checked={placesOn && switchOn(mine)}
          disabled={!placesOn || asking}
          onCheckedChange={(on) => void change(on)}
        />
      </SettingsRow>
    </SettingsSection>
  );
}
