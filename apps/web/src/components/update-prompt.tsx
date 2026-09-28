import { useEffect, useRef } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { useRegisterSW } from 'virtual:pwa-register/react';
import { background, runAction } from '@/lib/actions';
import { flushPendingEdits } from '@/lib/pending-edits';
import { reloadSaved } from '@/lib/reload';

/**
 * A new version installs in the background and then waits: the toast
 * offers the reload, and the reload saves whatever is being typed first.
 * Nothing reloads the page on its own (W4) — not even another tab: when
 * the reload is asked for in one tab, every other tab saves its edits
 * and then reloads only if it is out of sight; a tab on screen asks.
 */
export function UpdatePrompt() {
  const { t } = useTranslation();
  // Whether this tab is the one that asked for the new version.
  const asked = useRef(false);
  const timer = useRef<number | null>(null);

  /** Saves, then reloads; when something did not save, says so and offers to reload anyway. */
  const reload = () =>
    runAction(() => reloadSaved(), {
      then: (reloaded) => {
        if (reloaded) return;
        toast.error(t('pwa.saveFirst'), {
          id: 'pwa-update',
          duration: Infinity,
          action: { label: t('pwa.reloadAnyway'), onClick: () => runAction(() => reloadSaved({ force: true })) },
        });
      },
    });

  const {
    needRefresh: [needRefresh],
    updateServiceWorker,
  } = useRegisterSW({
    onRegisteredSW(_url, registration) {
      // Look for a new version every hour while a tab stays open.
      if (registration && timer.current === null) timer.current = window.setInterval(() => background(registration.update()), 60 * 60_000);
    },
    // The new version has taken over: this tab asked for it, or another did.
    onNeedReload() {
      if (asked.current) {
        background(reloadSaved({ force: true }));
        return;
      }
      if (document.visibilityState === 'hidden') {
        // Out of sight: save, and reload only if everything saved.
        background(reloadSaved());
        return;
      }
      // In use: save what is typed, and ask.
      background(flushPendingEdits());
      toast(t('pwa.updatedElsewhere'), {
        id: 'pwa-update',
        duration: Infinity,
        action: { label: t('pwa.reload'), onClick: reload },
      });
    },
  });

  useEffect(
    () => () => {
      if (timer.current !== null) window.clearInterval(timer.current);
    },
    [],
  );

  useEffect(() => {
    if (!needRefresh) return;
    const update = () => {
      asked.current = true;
      background(updateServiceWorker(true));
    };
    toast(t('pwa.updateReady'), {
      id: 'pwa-update',
      duration: Infinity,
      action: {
        label: t('pwa.reload'),
        onClick: () =>
          runAction(() => flushPendingEdits(), {
            then: (saved) => {
              if (saved) {
                update();
                return;
              }
              toast.error(t('pwa.saveFirst'), {
                id: 'pwa-update',
                duration: Infinity,
                action: { label: t('pwa.reloadAnyway'), onClick: update },
              });
            },
          }),
      },
    });
  }, [needRefresh, t, updateServiceWorker]);

  return null;
}
