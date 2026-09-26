import { useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { useRegisterSW } from 'virtual:pwa-register/react';
import { flushPendingEdits } from '@/lib/pending-edits';

/**
 * A new version installs in the background and then waits: the toast
 * offers the reload, and the reload saves whatever is being typed first.
 * Nothing reloads the page on its own (W4).
 */
export function UpdatePrompt() {
  const { t } = useTranslation();
  const {
    needRefresh: [needRefresh],
    updateServiceWorker,
  } = useRegisterSW({
    onRegisteredSW(_url, registration) {
      // Look for a new version every hour while a tab stays open.
      if (registration) setInterval(() => void registration.update(), 60 * 60_000);
    },
  });

  useEffect(() => {
    if (!needRefresh) return;
    toast(t('pwa.updateReady'), {
      id: 'pwa-update',
      duration: Infinity,
      action: {
        label: t('pwa.reload'),
        onClick: () => {
          void flushPendingEdits().then(() => updateServiceWorker(true));
        },
      },
    });
  }, [needRefresh, t, updateServiceWorker]);

  return null;
}
