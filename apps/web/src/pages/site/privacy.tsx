import { ArrowUpRightIcon } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { useDocumentTitle } from '@/lib/title';

/**
 * What happens to what I keep, in plain words ([[Data-Map]], Phase 7
 * M7.9). The outbound list is the one in [[Business-Rules]] #13, item
 * for item, plus what the web adds by being a web page. If the rule's
 * list grows, or the data map changes, so does this page.
 */
const outbound = ['rates', 'exercise', 'tiles', 'assist', 'sync', 'mail', 'news', 'push'] as const;
const webOnly = ['site', 'fonts'] as const;
const server = ['rows', 'files', 'account', 'password', 'activity', 'admin', 'logs', 'backups'] as const;
const devices = ['phone', 'browser', 'exports'] as const;
const kept = ['rows', 'sessions', 'counts', 'account'] as const;

export function PrivacyPage() {
  const { t } = useTranslation();
  useDocumentTitle(t('privacy.title'));
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

      <Cards id="server" title={t('privacy.serverTitle')} lead={t('privacy.serverLead')} items={server} group="server" />

      <section aria-labelledby="sees" className="flex flex-col gap-2">
        <h2 id="sees" className="text-xl font-extrabold">
          {t('privacy.seesTitle')}
        </h2>
        <p className="text-muted-foreground">{t('privacy.seesBody')}</p>
      </section>

      <Cards id="devices" title={t('privacy.devicesTitle')} items={devices} group="devices" />

      <section aria-labelledby="secret" className="flex flex-col gap-2">
        <h2 id="secret" className="text-xl font-extrabold">
          {t('privacy.secretTitle')}
        </h2>
        <p className="text-muted-foreground">{t('privacy.secretBody')}</p>
      </section>

      <Cards id="kept" title={t('privacy.keptTitle')} items={kept} group="kept" />

      <section aria-labelledby="yours" className="flex flex-col gap-2">
        <h2 id="yours" className="text-xl font-extrabold">
          {t('privacy.yoursTitle')}
        </h2>
        <p className="text-muted-foreground">{t('privacy.yoursBody')}</p>
        <p className="text-muted-foreground">{t('privacy.signOutBody')}</p>
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
    </div>
  );
}

/** A titled list of cards, each a heading and a paragraph from `privacy.<group>.<item>`. */
function Cards({
  id,
  title,
  lead,
  items,
  group,
}: {
  id: string;
  title: string;
  lead?: string;
  items: readonly string[];
  group: string;
}) {
  const { t } = useTranslation();
  return (
    <section aria-labelledby={id} className="flex flex-col gap-3">
      <h2 id={id} className="text-xl font-extrabold">
        {title}
      </h2>
      {lead && <p className="text-muted-foreground">{lead}</p>}
      <ul className="flex flex-col gap-3">
        {items.map((item) => (
          <li key={item} className="flex flex-col gap-1 rounded-xl border bg-card p-4">
            <h3 className="font-extrabold">{t(`privacy.${group}.${item}.title`)}</h3>
            <p className="text-sm text-muted-foreground">{t(`privacy.${group}.${item}.body`)}</p>
          </li>
        ))}
      </ul>
    </section>
  );
}
