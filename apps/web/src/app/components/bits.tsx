import type * as React from 'react';
import { FlameIcon } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { formatNumber } from '@/lib/format';
import { cn } from '@/lib/utils';

/** A ring filled to [ratio], for goal progress and the day's harvest. */
export function ProgressRing({ ratio, size = 44, label }: { ratio: number; size?: number; label: string }) {
  const stroke = 5;
  const radius = (size - stroke) / 2;
  const circumference = 2 * Math.PI * radius;
  const clamped = Math.min(Math.max(ratio, 0), 1);
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} role="img" aria-label={label} className="shrink-0 -rotate-90">
      <circle cx={size / 2} cy={size / 2} r={radius} fill="none" strokeWidth={stroke} className="stroke-muted" />
      <circle
        cx={size / 2}
        cy={size / 2}
        r={radius}
        fill="none"
        strokeWidth={stroke}
        strokeLinecap="round"
        strokeDasharray={circumference}
        strokeDashoffset={circumference * (1 - clamped)}
        className="stroke-success transition-[stroke-dashoffset] duration-500"
      />
    </svg>
  );
}

export function StreakChip({ count, className }: { count: number; className?: string }) {
  const { t } = useTranslation();
  return (
    <span
      className={cn('inline-flex items-center gap-0.5 rounded-full bg-muted px-2 py-0.5 text-xs font-extrabold tabular', className)}
      aria-label={t('streak.semantics', { count })}
      title={t('streak.semantics', { count })}
    >
      <FlameIcon className={cn('size-3.5', count > 0 ? 'text-primary' : 'text-muted-foreground')} aria-hidden />
      {formatNumber(count)}
    </span>
  );
}

export function EmptyState({ icon, title, body, action }: { icon: React.ReactNode; title: string; body?: string; action?: React.ReactNode }) {
  return (
    <div className="flex flex-col items-center gap-3 rounded-xl border border-dashed p-8 text-center">
      <span className="text-muted-foreground [&_svg]:size-10">{icon}</span>
      <h2 className="text-lg font-extrabold">{title}</h2>
      {body && <p className="max-w-sm text-sm text-muted-foreground">{body}</p>}
      {action}
    </div>
  );
}
