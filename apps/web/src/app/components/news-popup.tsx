import type { Announcement } from '@harvest/contracts';
import { ExternalLinkIcon } from 'lucide-react';
import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { api } from '@/lib/api';
import { markNewsSeen, useNewsPrefs } from '@/lib/news-prefs';
import { popupsToShow } from '../data/news';

export interface NewsSource {
  announcements(): Promise<{ announcements: Announcement[] }>;
}

/**
 * The news pop-ups ([[Admin]]): asked for once when the app opens, while
 * *News from Harvest* is on, and each live pop-up not shown here before
 * opens once, newest first, one at a time. Shown is remembered on this
 * browser, whatever the button pressed; nothing about it goes back.
 */
export function NewsPopup({ source = api }: { source?: NewsSource }) {
  const { t } = useTranslation();
  const { news } = useNewsPrefs();
  const [queue, setQueue] = useState<Announcement[]>([]);

  useEffect(() => {
    if (!news) return;
    let live = true;
    source
      .announcements()
      .then(({ announcements }) => {
        if (live) setQueue(popupsToShow(announcements));
      })
      .catch(() => {
        // No news this time: offline, or the server away. The next opening asks again.
      });
    return () => {
      live = false;
    };
  }, [news, source]);

  const current = queue[0];
  if (!current) return null;

  const done = () => {
    markNewsSeen(current.id);
    setQueue((rest) => rest.slice(1));
  };

  return (
    <Dialog open onOpenChange={(open) => !open && done()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{current.title}</DialogTitle>
          <DialogDescription className="whitespace-pre-line">{current.body}</DialogDescription>
        </DialogHeader>
        <DialogFooter>
          {current.link && (
            <Button asChild variant="outline">
              <a href={current.link} target="_blank" rel="noopener noreferrer" onClick={done}>
                <ExternalLinkIcon />
                {t('news.open')}
              </a>
            </Button>
          )}
          <Button onClick={done}>{t('news.gotIt')}</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
