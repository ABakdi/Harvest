import { ArrowUpRightIcon } from 'lucide-react';
import { useTranslation } from 'react-i18next';

/**
 * What leaves the device, in plain words. The list is the one in
 * [[Business-Rules]] #13, item for item, plus what the web adds by
 * being a web page. If the rule's list grows, so does this one.
 */
const outbound = ['rates', 'exercise', 'tiles', 'assist', 'sync'] as const;
const webOnly = ['site', 'fonts'] as const;

export function PrivacyPage() {
  const { t } = useTranslation();
  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-8 px-4 py-10">
      <div className="flex flex-col gap-2">
        <h1 className="text-3xl font-extrabold">{t('privacy.title')}</h1>
        <p className="text-lg text-muted-foreground">{t('privacy.lead')}</p>
      </div>

      <section aria-labelledby="leaves" className="flex flex-col gap-3">
        <h2 id="leaves" className="text-xl font-extrabold">
          {t('privacy.leavesTitle')}
        </h2>
        <ul className="flex flex-col gap-3">
          {outbound.map((item) => (
            <li key={item} className="flex gap-3 rounded-xl border bg-card p-4">
              <ArrowUpRightIcon className="mt-0.5 size-5 shrink-0 text-primary" aria-hidden />
              <div className="flex flex-col gap-1">
                <h3 className="font-extrabold">{t(`privacy.item.${item}.title`)}</h3>
                <p className="text-sm text-muted-foreground">{t(`privacy.item.${item}.body`)}</p>
              </div>
            </li>
          ))}
        </ul>
        <p className="text-sm font-bold">{t('privacy.nothingElse')}</p>
      </section>

      <section aria-labelledby="web" className="flex flex-col gap-3">
        <h2 id="web" className="text-xl font-extrabold">
          {t('privacy.webTitle')}
        </h2>
        <ul className="flex flex-col gap-3">
          {webOnly.map((item) => (
            <li key={item} className="flex flex-col gap-1 rounded-xl border bg-card p-4">
              <h3 className="font-extrabold">{t(`privacy.item.${item}.title`)}</h3>
              <p className="text-sm text-muted-foreground">{t(`privacy.item.${item}.body`)}</p>
            </li>
          ))}
        </ul>
      </section>

      <section aria-labelledby="stays" className="flex flex-col gap-2">
        <h2 id="stays" className="text-xl font-extrabold">
          {t('privacy.staysTitle')}
        </h2>
        <p className="text-muted-foreground">{t('privacy.staysBody')}</p>
        <p className="text-muted-foreground">{t('privacy.signOutBody')}</p>
      </section>
    </div>
  );
}
