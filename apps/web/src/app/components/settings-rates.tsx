import { useLiveQuery } from 'dexie-react-hooks';
import { CloudDownloadIcon, LoaderIcon } from 'lucide-react';
import { useId } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { formatDate, formatNumber } from '@/lib/format';
import { useHarvest } from '../context';
import { fetchPerUsd, parseRate, perUsdOf, rateKeys, rateSourceUrl, readSetting } from '../data/settings';
import { useDefaultCurrency } from '../hooks';
import { useBusy } from './use-busy';
import { runAction } from '@/lib/actions';

/**
 * One hand-typed leg, saved when it is left or entered with a changed
 * value, and said so (`RatesCard`). An empty field forgets the rate.
 */
function ManualRate({ settingKey, label, stored }: { settingKey: string; label: string; stored: string | null }) {
  const { t } = useTranslation();
  const { settings } = useHarvest();
  const id = useId();
  const save = async (field: HTMLInputElement) => {
    const text = field.value.trim();
    if (text === (stored ?? '')) return;
    // A failed write says so, and the field goes back to the rate in use (Q5-49).
    try {
      await write(field, text);
    } catch {
      field.value = stored ?? '';
      toast.error(t('common.saveFailed'));
    }
  };
  const write = async (field: HTMLInputElement, text: string) => {
    if (text === '') {
      await settings.remove(settingKey);
      toast(t('ratesWeb.cleared'));
      return;
    }
    const value = parseRate(text);
    if (value === null) {
      // What was typed is not a rate, so it does not stay looking like one:
      // the field goes back to the rate still in use.
      field.value = stored ?? '';
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
        onBlur={(event) => runAction(() => save(event.target))}
        onKeyDown={(event) => {
          if (event.key === 'Enter') runAction(() => save(event.currentTarget));
        }}
      />
    </div>
  );
}

/**
 * Exchange rates ([[Finances]], Phase 7 M7.8): what a US dollar buys of
 * every currency, fetched from Exchange Rate API's open endpoint — the
 * one request this page makes, and only when the button is pressed
 * (Business rule 13) — with the day the source last updated it and the
 * credit it asks for. What comes back is checked before it is stored.
 * The dinar's parallel-market legs, typed by hand, are there only for
 * whoever keeps their money in dinars.
 */
export function RatesCard() {
  const { t } = useTranslation();
  const { db, settings } = useHarvest();
  const currency = useDefaultCurrency();
  const [fetching, once] = useBusy();
  const values = useLiveQuery(
    async () => ({
      dzdPerUsd: await readSetting(db, rateKeys.dzdPerUsd),
      dzdPerEur: await readSetting(db, rateKeys.dzdPerEur),
      perUsd: perUsdOf(await readSetting(db, rateKeys.perUsd)),
      perUsdAt: await readSetting(db, rateKeys.perUsdAt),
    }),
    [db],
  );
  if (!values) return null;

  const fetchNow = async () => {
    const fetched = await fetchPerUsd();
    if (fetched === null) {
      toast.error(t('ratesWeb.fetchFailed'));
      return;
    }
    await settings.setMany({
      [rateKeys.perUsd]: JSON.stringify(fetched.rates),
      [rateKeys.perUsdAt]: fetched.at,
      // What 3.1 read, kept for a device not updated yet.
      [rateKeys.usdPerEur]: String(1 / fetched.rates.EUR!),
      [rateKeys.usdPerEurAt]: fetched.at,
    });
    toast.success(t('ratesWeb.saved'));
  };

  const fetchedAt = values.perUsdAt && !Number.isNaN(Date.parse(values.perUsdAt)) ? values.perUsdAt : null;
  // One line that says what the rates mean for me: a dollar in my
  // currency, or, when the dollar is mine, a euro in dollars.
  const base = currency === 'USD' ? 'EUR' : 'USD';
  const perUsd = values.perUsd;
  const rate = perUsd === null ? undefined : base === 'USD' ? perUsd[currency] : perUsd.EUR === undefined ? undefined : 1 / perUsd.EUR;
  return (
    <div className="flex flex-col gap-3">
      <p className="text-sm text-muted-foreground">{t('ratesWeb.explainer', { currency })}</p>
      {currency === 'DZD' && (
        <div className="flex flex-col gap-2">
          <p className="text-xs text-muted-foreground">{t('ratesWeb.byHand')}</p>
          <div className="flex flex-col gap-3 sm:flex-row">
            <ManualRate settingKey={rateKeys.dzdPerUsd} label={t('ratesWeb.dzdUsd')} stored={values.dzdPerUsd} />
            <ManualRate settingKey={rateKeys.dzdPerEur} label={t('ratesWeb.dzdEur')} stored={values.dzdPerEur} />
          </div>
        </div>
      )}
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div className="flex flex-col">
          <span className="text-sm font-bold" dir="ltr">
            {rate !== undefined
              ? t('ratesWeb.oneIs', { base, amount: formatNumber(rate, { maximumSignificantDigits: 6 }), currency })
              : t('ratesWeb.none')}
          </span>
          {fetchedAt && (
            <span className="text-xs text-muted-foreground">
              {t('ratesWeb.updated', { when: formatDate(fetchedAt, { dateStyle: 'medium' }) })}
            </span>
          )}
          <a href={rateSourceUrl} target="_blank" rel="noopener noreferrer" className="text-xs text-muted-foreground underline underline-offset-2">
            {t('ratesWeb.attribution')}
          </a>
          <span className="text-xs text-muted-foreground">{t('ratesWeb.fetchNote')}</span>
        </div>
        <Button variant="secondary" disabled={fetching} onClick={() => runAction(() => once(fetchNow))}>
          {fetching ? <LoaderIcon className="animate-spin" aria-hidden /> : <CloudDownloadIcon aria-hidden />}
          {t('ratesWeb.fetch')}
        </Button>
      </div>
    </div>
  );
}
