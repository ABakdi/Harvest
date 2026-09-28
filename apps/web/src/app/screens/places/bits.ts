import { useTranslation } from 'react-i18next';
import { formatNumber } from '@/lib/format';

/*
 * What the Places screen, its map, its timeline and its cards share:
 * the pins' colours and the way a distance is said.
 */

export type MapBase = 'streets' | 'satellite';

/** A pin's colour, the same roles the phone draws ([[Places]]). */
export const actionColor: Record<string, string> = {
  expenses: '#DC2626',
  money_txns: '#DC2626',
  debts: '#DC2626',
  debt_payments: '#DC2626',
  memories: '#0D9488',
  albums: '#0D9488',
  notes: '#7C3AED',
  note_attachments: '#7C3AED',
  seed_notes: '#7C3AED',
  check_ins: '#1F8A46',
  workout_sessions: '#1F8A46',
};
export const defaultActionColor = '#1F8A46';
export const stayColor = '#0D9488';
export const savedColor = '#EA4335';

export function pinColor(table: string): string {
  return actionColor[table] ?? defaultActionColor;
}

/** `4.2 km`, or metres while it is still a walk across a car park. */
export function useDistance(): (metres: number) => string {
  const { t } = useTranslation();
  return (metres) =>
    metres >= 1000
      ? t('places.km', { value: formatNumber(metres / 1000, { maximumFractionDigits: 1 }) })
      : t('places.m', { value: formatNumber(Math.round(metres)) });
}
