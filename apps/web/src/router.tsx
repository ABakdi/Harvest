import { useTranslation } from 'react-i18next';
import { Link, type RouteObject } from 'react-router';
import { Button } from '@/components/ui/button';
import { DownloadPage } from '@/pages/site/download';
import { HomePage } from '@/pages/site/home';
import { PrivacyPage } from '@/pages/site/privacy';
import { SiteLayout } from '@/pages/site/site-layout';

function NotFound() {
  const { t } = useTranslation();
  return (
    <div className="mx-auto flex max-w-md flex-col items-center gap-4 px-4 py-20 text-center">
      <h1 className="text-3xl font-extrabold">{t('site.notFoundTitle')}</h1>
      <p className="text-muted-foreground">{t('site.notFoundBody')}</p>
      <Button asChild>
        <Link to="/">{t('site.homeLink')}</Link>
      </Button>
    </div>
  );
}

/**
 * Two faces in one app ([[ADR-012-Web-Client]]). The public pages are
 * in the first bundle and never touch the local store (W3); the account
 * pages and the app itself load on demand, so the home page stays light.
 */
export const routes: RouteObject[] = [
  {
    element: <SiteLayout />,
    children: [
      { index: true, element: <HomePage /> },
      { path: 'download', element: <DownloadPage /> },
      { path: 'privacy', element: <PrivacyPage /> },
      { path: 'login', lazy: async () => ({ Component: (await import('@/pages/auth/login')).LoginPage }) },
      { path: 'register', lazy: async () => ({ Component: (await import('@/pages/auth/register')).RegisterPage }) },
      { path: 'forgot', lazy: async () => ({ Component: (await import('@/pages/auth/forgot')).ForgotPage }) },
      { path: 'reset/:token', lazy: async () => ({ Component: (await import('@/pages/auth/reset')).ResetPage }) },
      { path: 'verify/:token', lazy: async () => ({ Component: (await import('@/pages/auth/verify')).VerifyPage }) },
      { path: '*', element: <NotFound /> },
    ],
  },
  {
    path: '/app/*',
    lazy: async () => ({ Component: (await import('@/app/app-root')).AppRoot }),
  },
];
