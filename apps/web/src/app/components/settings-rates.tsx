import { useLiveQuery } from 'dexie-react-hooks';
import { CloudDownloadIcon, LoaderIcon } from 'lucide-react';
import { useId } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { formatDate } from '@/lib/format';
import { useHarvest } from '../context';
import { fetchEurUsd, parseRate, rateKeys, readSetting } from '../data/settings';
import { useBusy } from './use-busy';

/**
 * A moment as the phone writes `rate.usdPerEurAt`: Dart's
 * `toIso8601String()` of a local time, wall clock with no offset. The
 * phone reads it (and a UTC one) back with `toLocal()`.
 */
export function localIsoString(at: Date): string {
  const pad = (value: number, width = 2) => String(value).padStart(width, '0');
  return (
    `${pad(at.getFullYear(), 4)}-${pad(at.getMonth() + 1)}-${pad(at.getDate())}` +
    `T${pad(at.getHours())}:${pad(at.getMinutes())}:${pad(at.getSeconds())}.${pad(at.getMilliseconds(), 3)}`
  );
}

/**
 * One hand-typed leg, saved when it is left or entered with a changed
 * value, and said so (`RatesCard`). An empty field forgets the rate.
 */
function ManualRate({ settingKey, label, stored }: { settingKey: string; label: string; stored: string | null }) {
  const { t } = useTranslation();
  const { settings } = useHarvest();
  const id = useId();
  const save = async (raw: string) => {
    const text = raw.trim();
    if (text === (stored ?? '')) return;
    if (text === '') {
      await settings.remove(settingKey);
      toast(t('ratesWeb.cleared'));
      return;
    }
    const value = parseRate(text);
    if (value === null) {
      toast.error(t('ratesWeb.invalid'));
      return;
    }
    await settings.setString(settingKey, String(value));
    toast.success(t('ratesWeb.saved'));
  };
  return (
    <div className="flex flex-1 flex-col gap-2">
      <Label htmlFor={id}>{label}</Label>
      <Input
        id={id}
        key={stored ?? ''}
        inputMode="decimal"
        dir="ltr"
        className="tabular"
        defaultValue={stored ?? ''}
        onBlur={(event) => void save(event.target.value)}
        onKeyDown={(event) => {
          if (event.key === 'Enter') void save(event.currentTarget.value);
        }}
      />
    </div>
  );
}

/**
 * Exchange rates (checkpoint P5): the two DZD legs by hand, and EUR→USD
 * fetched from the ECB through `api.frankfurter.dev` — the one request
 * this page makes, and only when the button is pressed (Business
 * rule 13). What comes back is checked before it is stored.
 */
export function RatesCard() {
  const { t } = useTranslation();
  const { db, settings } = useHarvest();
  const [fetching, once] = useBusy();
  const values = useLiveQuery(
    async () => ({
      dzdPerUsd: await readSetting(db, rateKeys.dzdPerUsd),
      dzdPerEur: await readSetting(db, rateKeys.dzdPerEur),
      usdPerEur: await readSetting(db, rateKeys.usdPerEur),
      usdPerEurAt: await readSetting(db, rateKeys.usdPerEurAt),
    }),
    [db],
  );
  if (!values) return null;

  const fetchNow = async () => {
    const rate = await fetchEurUsd();
    if (rate !== null) {
      await settings.setMany({ [rateKeys.usdPerEur]: String(rate), [rateKeys.usdPerEurAt]: localIsoString(new Date()) });
    }
    if (rate === null) toast.error(t('ratesWeb.fetchFailed'));
    else toast.success(t('ratesWeb.saved'));
  };

  const fetchedAt = values.usdPerEurAt && !Number.isNaN(Date.parse(values.usdPerEurAt)) ? values.usdPerEurAt : null;
  return (
    <div className="flex flex-col gap-3">
      <p className="text-sm text-muted-foreground">{t('ratesWeb.explainer')}</p>
      <div className="flex flex-col gap-3 sm:flex-row">
        <ManualRate settingKey={rateKeys.dzdPerUsd} label={t('ratesWeb.dzdUsd')} stored={values.dzdPerUsd} />
        <ManualRate settingKey={rateKeys.dzdPerEur} label={t('ratesWeb.dzdEur')} stored={values.dzdPerEur} />
      </div>
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div className="flex flex-col">
          <span className="text-sm font-bold">
            {t('ratesWeb.eurUsd')}
            {values.usdPerEur !== null && (
              <>
                : <span className="tabular">{values.usdPerEur}</span>
              </>
            )}
          </span>
          {fetchedAt && (
            <span className="text-xs text-muted-foreground">
              {t('ratesWeb.updated', { when: formatDate(fetchedAt, { dateStyle: 'medium', timeStyle: 'short' }) })}
            </span>
          )}
          <span className="text-xs text-muted-foreground">{t('ratesWeb.fetchNote')}</span>
        </div>
        <Button variant="secondary" disabled={fetching} onClick={() => void once(fetchNow)}>
          {fetching ? <LoaderIcon className="animate-spin" aria-hidden /> : <CloudDownloadIcon aria-hidden />}
          {t('ratesWeb.fetch')}
        </Button>
      </div>
    </div>
  );
}
