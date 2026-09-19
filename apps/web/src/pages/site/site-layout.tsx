import { useTranslation } from 'react-i18next';
import { Link, NavLink, Outlet } from 'react-router';
import { Wordmark } from '@/components/brand';
import { LanguageToggleButton, ThemeCycleButton } from '@/components/prefs-controls';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';

/**
 * The public face: light by rule (W3). Nothing under this layout opens
 * the local store or starts a sync.
 */
export function SiteLayout() {
  const { t } = useTranslation();
  const navClass = ({ isActive }: { isActive: boolean }) =>
    cn('rounded-md px-2 py-1 text-sm font-bold hover:text-primary', isActive && 'text-primary');
  return (
    <div className="flex min-h-dvh flex-col">
      <a href="#main" className="sr-only focus:not-sr-only focus:absolute focus:start-2 focus:top-2 focus:z-50 focus:rounded-md focus:bg-card focus:p-2">
        {t('common.skipToContent')}
      </a>
      <header className="sticky top-0 z-40 border-b bg-background/90 backdrop-blur">
        <div className="mx-auto flex h-16 max-w-6xl items-center gap-2 px-4 max-sm:px-3">
          <Link to="/" className="rounded-md outline-none focus-visible:ring-2 focus-visible:ring-ring" aria-label={t('site.homeLink')}>
            <Wordmark />
          </Link>
          <nav aria-label={t('site.nav')} className="ms-4 hidden items-center gap-2 sm:flex">
            <NavLink to="/download" className={navClass}>
              {t('site.download')}
            </NavLink>
            <NavLink to="/privacy" className={navClass}>
              {t('site.privacy')}
            </NavLink>
          </nav>
          <div className="ms-auto flex items-center gap-0.5 sm:gap-1">
            <LanguageToggleButton />
            <ThemeCycleButton />
            <Button asChild variant="outline" size="sm" className="ms-1">
              <Link to="/login">{t('auth.signIn')}</Link>
            </Button>
          </div>
        </div>
      </header>
      <main id="main" className="flex-1">
        <Outlet />
      </main>
      <footer className="border-t">
        <div className="mx-auto flex max-w-6xl flex-col gap-3 px-4 py-6 text-sm text-muted-foreground sm:flex-row sm:items-center">
          <span>{t('site.footerLine')}</span>
          <nav aria-label={t('site.footerNav')} className="flex gap-4 sm:ms-auto">
            <Link to="/download" className="hover:text-foreground">
              {t('site.download')}
            </Link>
            <Link to="/privacy" className="hover:text-foreground">
              {t('site.privacy')}
            </Link>
            <Link to="/app" className="hover:text-foreground">
              {t('site.openApp')}
            </Link>
          </nav>
        </div>
      </footer>
    </div>
  );
}
