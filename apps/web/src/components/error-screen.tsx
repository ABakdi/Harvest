import { AlertTriangleIcon } from 'lucide-react';
import { Component, useEffect, type ErrorInfo, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { useRouteError } from 'react-router';
import { Button } from '@/components/ui/button';
import { isChunkLoadError, reloadForNewVersion, reloadSaved } from '@/lib/reload';
import { runAction } from '@/lib/actions';

/**
 * What a screen that broke shows instead of itself: a plain sentence in
 * the page's language, Reload and Back, and no stack trace. A missing
 * code chunk means a new version was deployed under this tab, so that
 * one reloads once on its own to pick it up.
 */
export function ErrorScreen({ error, onBack }: { error: unknown; onBack?: () => void }) {
  const { t } = useTranslation();
  const chunk = isChunkLoadError(error);
  useEffect(() => {
    // The console keeps the detail for whoever looks.
    console.error(error);
    if (chunk) reloadForNewVersion();
  }, [error, chunk]);

  return (
    <div role="alert" className="mx-auto flex max-w-md flex-col items-center gap-4 px-4 py-16 text-center">
      <AlertTriangleIcon className="size-10 text-primary" aria-hidden />
      <h1 className="text-2xl font-extrabold">{chunk ? t('errorScreen.newVersionTitle') : t('errorScreen.title')}</h1>
      <p className="text-muted-foreground">{chunk ? t('errorScreen.newVersionBody') : t('errorScreen.body')}</p>
      <div className="flex flex-wrap justify-center gap-2">
        <Button onClick={() => runAction(() => reloadSaved({ force: true }))}>{t('errorScreen.reload')}</Button>
        <Button
          variant="outline"
          onClick={() => {
            if (onBack) onBack();
            else window.history.back();
          }}
        >
          {t('errorScreen.back')}
        </Button>
      </div>
    </div>
  );
}

/** The route-level screen, for React Router's `errorElement`. */
export function RouteErrorScreen() {
  return <ErrorScreen error={useRouteError()} />;
}

/**
 * Keeps a broken screen from taking the shell with it: the tabs stay,
 * and moving to another screen ([resetKey]) tries again.
 */
export class ScreenErrorBoundary extends Component<{ resetKey: string; children: ReactNode }, { error: unknown; key: string }> {
  override state: { error: unknown; key: string } = { error: null, key: this.props.resetKey };

  static getDerivedStateFromError(error: unknown) {
    return { error };
  }

  static getDerivedStateFromProps(props: { resetKey: string }, state: { error: unknown; key: string }) {
    return props.resetKey === state.key ? null : { error: null, key: props.resetKey };
  }

  override componentDidCatch(error: unknown, info: ErrorInfo) {
    console.error(error, info.componentStack);
  }

  override render() {
    return this.state.error ? <ErrorScreen error={this.state.error} /> : this.props.children;
  }
}
