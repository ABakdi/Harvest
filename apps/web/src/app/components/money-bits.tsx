import { evaluateAmountToMinor, isAmountExpression, toDefault, currencyOf, type Rates } from '@harvest/core';
import type { TFunction } from 'i18next';
import { useLiveQuery } from 'dexie-react-hooks';
import {
  BabyIcon,
  BusIcon,
  CarIcon,
  CoffeeIcon,
  DumbbellIcon,
  FilmIcon,
  Gamepad2Icon,
  GiftIcon,
  GraduationCapIcon,
  HeartIcon,
  HouseIcon,
  MusicIcon,
  PawPrintIcon,
  PlaneIcon,
  ReceiptIcon,
  ShapesIcon,
  ShoppingBagIcon,
  SmartphoneIcon,
  UtensilsIcon,
  WrenchIcon,
  type LucideIcon,
} from 'lucide-react';
import { createElement } from 'react';
import type * as React from 'react';
import { useTranslation } from 'react-i18next';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { currencySymbol, formatMoney } from '@/lib/format';
import { cn } from '@/lib/utils';
import { useHarvest } from '../context';
import { readCategories, type CategoryRow } from '../data/categories';
import { MoneyRuleError } from '../data/vault';

/** The phone's icon registry, drawn with the web's icon set. */
const icons: Record<string, LucideIcon> = {
  restaurant: UtensilsIcon,
  bus: BusIcon,
  receipt: ReceiptIcon,
  bag: ShoppingBagIcon,
  heart: HeartIcon,
  movie: FilmIcon,
  category: ShapesIcon,
  coffee: CoffeeIcon,
  home: HouseIcon,
  car: CarIcon,
  gift: GiftIcon,
  pets: PawPrintIcon,
  school: GraduationCapIcon,
  fitness: DumbbellIcon,
  phone: SmartphoneIcon,
  games: Gamepad2Icon,
  travel: PlaneIcon,
  baby: BabyIcon,
  tools: WrenchIcon,
  music: MusicIcon,
};

/** Each preset's icon key (`categoryIcon` on the phone). */
const presetIcons: Record<string, string> = {
  food: 'restaurant',
  transport: 'bus',
  bills: 'receipt',
  shopping: 'bag',
  health: 'heart',
  entertainment: 'movie',
  other: 'category',
};

export function iconFor(key: string): LucideIcon {
  return icons[key] ?? ShapesIcon;
}

/** Any category's icon: a preset's own, a custom one's chosen key, shapes otherwise. */
export function CategoryIcon({ category, customs, className }: { category: string; customs?: readonly CategoryRow[] | undefined; className?: string }) {
  const key = presetIcons[category] ?? customs?.find((row) => row.name === category)?.icon ?? 'category';
  return <IconGlyph icon={key} className={cn('size-4 shrink-0', className)} />;
}

/** One registry icon by its key, decorative. */
export function IconGlyph({ icon, className }: { icon: string; className?: string }) {
  return createElement(iconFor(icon), { className, 'aria-hidden': true });
}

/** The live custom categories, oldest first. */
export function useCustomCategories(): CategoryRow[] | undefined {
  const { db } = useHarvest();
  return useLiveQuery(() => readCategories(db), [db]);
}

/** The words for a refused money write, or the generic failure. */
export function moneyError(t: TFunction, error: unknown): string {
  return error instanceof MoneyRuleError ? t(`vault.refused.${error.rule}`) : t('common.saveFailed');
}

/** `≈DA1,080` beside an amount in another currency; nothing when it is the default or no rate is known. */
export function conversionCaption(rates: Rates, minor: number, currency: string): string | null {
  if (currency === rates.defaultCurrency) return null;
  const converted = toDefault(rates, minor, currencyOf(currency));
  return converted === null ? null : `≈${formatMoney(converted, rates.defaultCurrency)}`;
}

/** Every currency a pot holds, the default first, never added together. */
export function Balances({ balances, rates, className }: { balances: [string, number][]; rates: Rates; className?: string }) {
  const sorted = [...balances]
    .filter(([, minor]) => minor !== 0)
    .sort(([a], [b]) => Number(b === rates.defaultCurrency) - Number(a === rates.defaultCurrency));
  if (sorted.length === 0) {
    return (
      <span className={cn('text-3xl font-extrabold tabular', className)} dir="ltr">
        {formatMoney(0, rates.defaultCurrency)}
      </span>
    );
  }
  return (
    <span className={cn('flex flex-col gap-0.5', className)}>
      {sorted.map(([currency, minor], index) => {
        const caption = conversionCaption(rates, minor, currency);
        return (
          <span key={currency} className="flex flex-wrap items-baseline gap-x-2" dir="ltr">
            <span className={cn('font-extrabold tabular', index === 0 ? 'text-3xl' : 'text-xl')}>{formatMoney(minor, currency)}</span>
            {caption && <span className="text-sm font-bold text-muted-foreground tabular">{caption}</span>}
          </span>
        );
      })}
    </span>
  );
}

/**
 * The amount box: a number or a sum (`120+30`, `3×4`, `1,5+2`), with
 * what the sum comes to written under it as it is typed, so saving
 * never saves a surprise ([[Finances]] Quick-log).
 */
export function AmountField({
  id,
  label,
  value,
  onChange,
  currency,
  invalid,
  describedBy,
  autoFocus,
  className,
}: {
  id: string;
  label: string;
  value: string;
  onChange: (value: string) => void;
  currency: string;
  invalid?: boolean;
  describedBy?: string;
  autoFocus?: boolean;
  className?: string;
}) {
  const { t } = useTranslation();
  const minor = evaluateAmountToMinor(value);
  const sum = isAmountExpression(value);
  return (
    <div className={cn('flex flex-col gap-2', className)}>
      <Label htmlFor={id}>{label}</Label>
      <div className="relative">
        <span className="pointer-events-none absolute inset-y-0 start-3 flex items-center font-extrabold text-muted-foreground" aria-hidden>
          {currencySymbol(currency)}
        </span>
        <Input
          id={id}
          inputMode="decimal"
          autoComplete="off"
          autoFocus={autoFocus}
          dir="ltr"
          placeholder="0"
          className="ps-10 text-lg font-extrabold tabular"
          value={value}
          aria-invalid={invalid || undefined}
          aria-describedby={`${id}-sum${describedBy ? ` ${describedBy}` : ''}`}
          onChange={(event) => onChange(event.target.value)}
        />
      </div>
      <p id={`${id}-sum`} aria-live="polite" className={cn('text-sm font-extrabold tabular', minor === null ? 'text-muted-foreground' : 'text-primary')}>
        {sum ? (minor === null ? t('money.sumIncomplete') : t('money.sum', { amount: formatMoney(minor, currency) })) : null}
      </p>
    </div>
  );
}

/** A labelled switch row, the way the editors ask "from the wallet?". */
export function SwitchRow({ children }: { children: React.ReactNode }) {
  return <div className="flex items-center justify-between gap-3 rounded-lg bg-muted/60 p-3">{children}</div>;
}
