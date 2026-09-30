import { BellIcon, BellOffIcon } from 'lucide-react';
import { useEffect, useId, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Button } from '@/components/ui/button';
import { Label } from '@/components/ui/label';
import { Switch } from '@/components/ui/switch';
import { api } from '@/lib/api';
import { runAction } from '@/lib/actions';
import { setHeartbeatDay, setNewsPrefs, useNewsPrefs } from '@/lib/news-prefs';
import { disablePush, enablePush, pushStatus, type PushApi, type PushStatus } from '../data/news';
import { SettingsSection as Section } from './settings-bits';

/**
 * News from Harvest, Share my streak and notifications ([[Admin]]): all
 * this browser's own. The browser's permission prompt only ever follows
 * a tap on *Allow notifications*, never a page opening.
 */
export function NewsSection({ push = api }: { push?: PushApi }) {
  const { t } = useTranslation();
  const id = useId();
  const { news, shareStreak } = useNewsPrefs();
  const [status, setStatus] = useState<PushStatus | null>(null);

  useEffect(() => {
    let live = true;
    pushStatus()
      .then((next) => {
        if (live) setStatus(next);
      })
      .catch(() => {
        if (live) setStatus('unsupported');
      });
    return () => {
      live = false;
    };
  }, []);

  const setNews = (on: boolean) =>
    runAction(async () => {
      setNewsPrefs({ news: on });
      if (!on && status === 'on') {
        await disablePush(push);
        setStatus('off');
      }
    });

  return (
    <Section title={t('news.title')} id="settings-news" lead={t('news.lead')}>
      <SwitchRow
        id={`${id}-news`}
        label={t('news.fromHarvest')}
        hint={t('news.fromHarvestHint')}
        checked={news}
        onChange={setNews}
      />
      <SwitchRow
        id={`${id}-streak`}
        label={t('news.shareStreak')}
        hint={t('news.shareStreakHint')}
        checked={shareStreak}
        onChange={(on) => {
          setNewsPrefs({ shareStreak: on });
          // Said again today, with or without the streak, so the server
          // stops holding one I no longer share.
          setHeartbeatDay(null);
        }}
      />
      {news && status !== null && (
        <div className="flex flex-col gap-2 border-t pt-4 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex flex-col">
            <span className="text-sm font-semibold">{t('news.push')}</span>
            <span className="text-xs text-muted-foreground">
              {status === 'on'
                ? t('news.pushOn')
                : status === 'denied'
                  ? t('news.pushDenied')
                  : status === 'unsupported'
                    ? t('news.pushUnsupported')
                    : t('news.pushOffer')}
            </span>
          </div>
          {status === 'on' ? (
            <Button
              variant="outline"
              size="sm"
              onClick={() =>
                runAction(async () => {
                  await disablePush(push);
                  setStatus('off');
                })
              }
            >
              <BellOffIcon />
              {t('news.pushTurnOff')}
            </Button>
          ) : status === 'off' ? (
            <Button
              variant="outline"
              size="sm"
              onClick={() =>
                runAction(async () => {
                  setStatus(await enablePush(push));
                })
              }
            >
              <BellIcon />
              {t('news.pushAllow')}
            </Button>
          ) : null}
        </div>
      )}
    </Section>
  );
}

function SwitchRow({
  id,
  label,
  hint,
  checked,
  onChange,
}: {
  id: string;
  label: string;
  hint: string;
  checked: boolean;
  onChange: (on: boolean) => void;
}) {
  return (
    <div className="flex items-start gap-3">
      <div className="flex min-w-0 flex-1 flex-col">
        <Label htmlFor={id}>{label}</Label>
        <span id={`${id}-hint`} className="text-xs text-muted-foreground">
          {hint}
        </span>
      </div>
      <Switch id={id} checked={checked} aria-describedby={`${id}-hint`} onCheckedChange={onChange} />
    </div>
  );
}
