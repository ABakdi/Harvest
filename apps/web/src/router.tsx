import { useTranslation } from 'react-i18next';
import { Link, Navigate, type RouteObject } from 'react-router';
import { RouteErrorScreen } from '@/components/error-screen';
import { Button } from '@/components/ui/button';
import { DownloadPage } from '@/pages/site/download';
import { HomePage } from '@/pages/site/home';
import { PrivacyPage } from '@/pages/site/privacy';
import { SiteLayout } from '@/pages/site/site-layout';
import { useDocumentTitle } from '@/lib/title';

function NotFound() {
  const { t } = useTranslation();
  useDocumentTitle(t('site.notFoundTitle'));
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
 * Nothing to show while a page's code arrives: the page is blank for
 * that moment, and the site's frame around it is already drawn.
 */
function Blank() {
  return null;
}

/**
 * Two faces in one app ([[ADR-012-Web-Client]]). The public pages are
 * in the first bundle and never touch the local store (W3); the account
 * pages and the app itself load on demand, so the home page stays light.
 */
export const routes: RouteObject[] = [
  {
    element: <SiteLayout />,
    errorElement: <RouteErrorScreen />,
    children: [
      { index: true, element: <HomePage /> },
      { path: 'download', element: <DownloadPage /> },
      { path: 'privacy', element: <PrivacyPage /> },
      { path: 'login', HydrateFallback: Blank, lazy: async () => ({ Component: (await import('@/pages/auth/login')).LoginPage }) },
      { path: 'register', HydrateFallback: Blank, lazy: async () => ({ Component: (await import('@/pages/auth/register')).RegisterPage }) },
      { path: 'forgot', HydrateFallback: Blank, lazy: async () => ({ Component: (await import('@/pages/auth/forgot')).ForgotPage }) },
      { path: 'reset/:token', HydrateFallback: Blank, lazy: async () => ({ Component: (await import('@/pages/auth/reset')).ResetPage }) },
      { path: 'verify/:token', HydrateFallback: Blank, lazy: async () => ({ Component: (await import('@/pages/auth/verify')).VerifyPage }) },
      // The admin panel lives inside the app, behind its session ([[Admin]]).
      { path: 'admin', element: <Navigate to="/app/admin" replace /> },
      { path: '*', element: <NotFound /> },
    ],
  },
  {
    path: '/app/*',
    errorElement: <RouteErrorScreen />,
    HydrateFallback: Blank,
    lazy: async () => ({ Component: (await import('@/app/app-root')).AppRoot }),
  },
];
