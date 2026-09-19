import { useEffect, useState } from 'react';
import i18n from '@/i18n';

function describe(iso: string | null, now: number): string {
  if (!iso) return '';
  const seconds = Math.round((new Date(iso).getTime() - now) / 1000);
  const format = new Intl.RelativeTimeFormat(i18n.language === 'ar' ? 'ar-u-nu-latn' : 'en', { numeric: 'auto' });
  const abs = Math.abs(seconds);
  if (abs < 45) return format.format(0, 'second');
  if (abs < 3600) return format.format(Math.round(seconds / 60), 'minute');
  if (abs < 86_400) return format.format(Math.round(seconds / 3600), 'hour');
  return format.format(Math.round(seconds / 86_400), 'day');
}

/** "2 minutes ago", kept current while it is on screen. */
export function useRelativeTime(iso: string | null): string {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), 30_000);
    return () => clearInterval(timer);
  }, []);
  return describe(iso, now);
}
