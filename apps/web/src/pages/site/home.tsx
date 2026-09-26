import {
  BookOpenIcon,
  CheckIcon,
  CoinsIcon,
  DumbbellIcon,
  FlameIcon,
  HourglassIcon,
  LockIcon,
  SmartphoneIcon,
  SproutIcon,
  WalletIcon,
  WifiOffIcon,
} from 'lucide-react';
import type { ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { Link } from 'react-router';
import { InstallButton } from '@/components/install-button';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';

/**
 * A still of the field, drawn with the app's own pieces rather than a
 * bitmap: it follows the theme, the language and the direction, and it
 * costs nothing to load.
 */
function FieldPreview() {
  const { t } = useTranslation();
  const seeds = [
    { title: t('home.preview.seed1'), meta: t('home.preview.seed1Meta'), done: true },
    { title: t('home.preview.seed2'), meta: t('home.preview.seed2Meta'), done: true },
    { title: t('home.preview.seed3'), meta: t('home.preview.seed3Meta'), done: false },
  ];
  return (
    <div aria-hidden className="w-full max-w-sm rounded-2xl border bg-card p-4 shadow-xl">
      <div className="flex items-center justify-between">
        <span className="text-sm font-extrabold">{t('home.preview.today')}</span>
        <span className="flex items-center gap-1 rounded-full bg-muted px-2 py-1 text-sm font-extrabold">
          <FlameIcon className="size-4 text-primary" />
          <span className="tabular">12</span>
        </span>
      </div>
      <div className="mt-3 h-2.5 overflow-hidden rounded-full bg-muted">
        <div className="bg-harvest-gradient h-full w-2/3 rounded-full" />
      </div>
      <ul className="mt-4 flex flex-col gap-2">
        {seeds.map((seed) => (
          <li key={seed.title} className="flex items-center gap-3 rounded-xl bg-background p-3">
            <span
              className={cn(
                'flex size-8 items-center justify-center rounded-full border-2',
                seed.done ? 'border-success bg-success text-white' : 'border-muted-foreground/40',
              )}
            >
              {seed.done && <CheckIcon className="size-4" strokeWidth={3} />}
            </span>
            <span className="flex flex-col">
              <span className={cn('text-sm font-bold', seed.done && 'text-muted-foreground line-through')}>{seed.title}</span>
              <span className="text-xs text-muted-foreground">{seed.meta}</span>
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
}

function Pillar({ icon, title, body }: { icon: ReactNode; title: string; body: string }) {
  return (
    <li className="flex flex-col gap-2 rounded-xl border bg-card p-4">
      <span className="flex size-10 items-center justify-center rounded-lg bg-secondary text-secondary-foreground [&_svg]:size-5">
        {icon}
      </span>
      <h3 className="font-extrabold">{title}</h3>
      <p className="text-sm text-muted-foreground">{body}</p>
    </li>
  );
}

function Feature({
  icon,
  title,
  body,
  points,
  flip = false,
}: {
  icon: ReactNode;
  title: string;
  body: string;
  points: string[];
  flip?: boolean;
}) {
  return (
    <section className={cn('grid items-center gap-6 md:grid-cols-2', flip && 'md:[&>*:first-child]:order-2')}>
      <div className="flex flex-col gap-3">
        <span className="flex size-12 items-center justify-center rounded-xl bg-harvest-gradient text-white [&_svg]:size-6">
          {icon}
        </span>
        <h2 className="text-2xl font-extrabold sm:text-3xl">{title}</h2>
        <p className="text-muted-foreground">{body}</p>
      </div>
      <ul className="flex flex-col gap-2 rounded-2xl border bg-card p-5">
        {points.map((point) => (
          <li key={point} className="flex items-start gap-2">
            <CheckIcon className="mt-0.5 size-4 shrink-0 text-success" strokeWidth={3} aria-hidden />
            <span className="text-sm">{point}</span>
          </li>
        ))}
      </ul>
    </section>
  );
}

export function HomePage() {
  const { t } = useTranslation();
  return (
    <div className="mx-auto flex max-w-6xl flex-col gap-16 px-4 py-10 sm:py-16">
      <section className="grid items-center gap-10 md:grid-cols-[1.2fr_1fr]">
        <div className="flex flex-col items-center gap-5 text-center md:items-start md:text-start">
          <span className="rounded-full bg-secondary px-3 py-1 text-xs font-extrabold text-secondary-foreground">
            {t('home.kicker')}
          </span>
          <h1 className="text-4xl font-extrabold leading-tight tracking-tight sm:text-5xl">{t('home.title')}</h1>
          <p className="max-w-xl text-lg text-muted-foreground">{t('home.lead')}</p>
          <div className="flex flex-col items-center gap-3 sm:flex-row sm:items-start">
            <Button asChild size="lg" variant="outline">
              <Link to="/download">
                <SmartphoneIcon />
                {t('site.getAndroid')}
              </Link>
            </Button>
            <InstallButton />
          </div>
          <p className="flex items-center gap-2 text-sm text-muted-foreground">
            <WifiOffIcon className="size-4" aria-hidden />
            {t('home.offline')}
          </p>
        </div>
        <div className="flex justify-center">
          <FieldPreview />
        </div>
      </section>

      <section aria-labelledby="what" className="flex flex-col gap-6">
        <div className="flex flex-col gap-2">
          <h2 id="what" className="text-2xl font-extrabold sm:text-3xl">
            {t('home.whatTitle')}
          </h2>
          <p className="max-w-3xl text-muted-foreground">{t('home.whatBody')}</p>
        </div>
        <ul className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Pillar icon={<SproutIcon />} title={t('home.pillar.productivity')} body={t('home.pillar.productivityBody')} />
          <Pillar icon={<WalletIcon />} title={t('home.pillar.finances')} body={t('home.pillar.financesBody')} />
          <Pillar icon={<DumbbellIcon />} title={t('home.pillar.health')} body={t('home.pillar.healthBody')} />
          <Pillar icon={<HourglassIcon />} title={t('home.pillar.focus')} body={t('home.pillar.focusBody')} />
        </ul>
      </section>

      <Feature
        icon={<FlameIcon />}
        title={t('home.feature.field.title')}
        body={t('home.feature.field.body')}
        points={[t('home.feature.field.p1'), t('home.feature.field.p2'), t('home.feature.field.p3')]}
      />
      <Feature
        flip
        icon={<BookOpenIcon />}
        title={t('home.feature.notes.title')}
        body={t('home.feature.notes.body')}
        points={[t('home.feature.notes.p1'), t('home.feature.notes.p2'), t('home.feature.notes.p3')]}
      />
      <Feature
        icon={<LockIcon />}
        title={t('home.feature.money.title')}
        body={t('home.feature.money.body')}
        points={[t('home.feature.money.p1'), t('home.feature.money.p2'), t('home.feature.money.p3')]}
      />

      <section className="flex flex-col items-center gap-4 rounded-2xl bg-card p-8 text-center">
        <CoinsIcon className="size-8 text-sun" aria-hidden />
        <h2 className="text-2xl font-extrabold">{t('home.ctaTitle')}</h2>
        <p className="max-w-xl text-muted-foreground">{t('home.ctaBody')}</p>
        <div className="flex flex-col items-center gap-3 sm:flex-row sm:items-start">
          <Button asChild size="lg" variant="outline">
            <Link to="/download">
              <SmartphoneIcon />
              {t('site.getAndroid')}
            </Link>
          </Button>
          <InstallButton />
        </div>
      </section>
    </div>
  );
}
