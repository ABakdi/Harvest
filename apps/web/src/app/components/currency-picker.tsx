import { currenciesByName, currencyInfo, isCurrencyCode, type CurrencyInfo } from '@harvest/core';
import { CheckIcon, ChevronsUpDownIcon, SearchIcon } from 'lucide-react';
import { useId, useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { cn } from '@/lib/utils';
import { useDefaultCurrency } from '../hooks';

/** Folds case and accents, so `euro` finds Euro and `dirham` finds Dirham. */
function folded(text: string): string {
  return text.normalize('NFD').replace(/\p{M}/gu, '').toLocaleLowerCase();
}

/**
 * The currencies that match [query], by code, sign, or name in either
 * language; with none typed, [first] leads (the one chosen, the default)
 * and the rest follow by name in [language].
 */
export function matchingCurrencies(query: string, language: 'en' | 'ar', first: readonly string[] = []): CurrencyInfo[] {
  const all = currenciesByName(language);
  const wanted = folded(query.trim());
  if (wanted === '') {
    const lead = [...new Set(first)].filter(isCurrencyCode).map(currencyInfo);
    const led = new Set(lead.map((currency) => currency.code));
    return [...lead, ...all.filter((currency) => !led.has(currency.code))];
  }
  const hits = all.filter((currency) =>
    [currency.code, currency.symbol, currency.en, currency.ar].some((text) => folded(text).includes(wanted)),
  );
  // A code typed in full comes first.
  return hits.sort((a, b) => Number(folded(b.code) === wanted) - Number(folded(a.code) === wanted));
}

/**
 * Every currency, searchable ([[Finances]], Phase 7 M7.8): a button that
 * says the one chosen, opening a list to search by name (in the app's
 * language), code or sign. It stands where three toggles stood.
 */
export function CurrencyPicker({
  id,
  value,
  onChange,
  className,
  labelledBy,
}: {
  id?: string;
  value: string;
  onChange: (code: string) => void;
  className?: string;
  labelledBy?: string;
}) {
  const { t, i18n } = useTranslation();
  const language = i18n.language === 'ar' ? 'ar' : 'en';
  const fallback = useDefaultCurrency();
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');
  const listId = useId();
  const shown = useMemo(() => matchingCurrencies(query, language, [value, fallback]), [query, language, value, fallback]);
  const chosen = isCurrencyCode(value) ? currencyInfo(value) : null;

  const pick = (code: string) => {
    onChange(code);
    setOpen(false);
    setQuery('');
  };

  return (
    <>
      <Button
        id={id}
        type="button"
        variant="outline"
        className={cn('justify-between gap-2 font-semibold', className)}
        aria-haspopup="dialog"
        aria-labelledby={labelledBy === undefined ? undefined : `${labelledBy} ${id ?? ''}`.trim()}
        title={chosen ? chosen[language] : value}
        onClick={() => setOpen(true)}
      >
        <span className="truncate" dir="ltr">
          {chosen && chosen.symbol !== chosen.code ? `${chosen.symbol} ${value}` : value}
        </span>
        <ChevronsUpDownIcon className="size-4 shrink-0 opacity-60" aria-hidden />
      </Button>
      {open && (
        <Dialog open onOpenChange={(next) => !next && setOpen(false)}>
          <DialogContent className="flex max-h-[85dvh] flex-col gap-3">
            <DialogHeader>
              <DialogTitle>{t('currency.pick')}</DialogTitle>
              <DialogDescription className="sr-only">{t('currency.search')}</DialogDescription>
            </DialogHeader>
            <div className="relative">
              <SearchIcon className="pointer-events-none absolute start-2.5 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" aria-hidden />
              <Input
                autoFocus
                type="search"
                className="ps-8"
                aria-label={t('currency.search')}
                aria-controls={listId}
                placeholder={t('currency.search')}
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                onKeyDown={(event) => {
                  if (event.key === 'Enter' && shown[0]) {
                    event.preventDefault();
                    pick(shown[0].code);
                  }
                }}
              />
            </div>
            <ul id={listId} role="listbox" aria-label={t('currency.pick')} className="-mx-1 min-h-0 flex-1 overflow-y-auto">
              {shown.map((currency) => {
                const selected = currency.code === value;
                return (
                  <li
                    key={currency.code}
                    role="option"
                    aria-selected={selected}
                    tabIndex={0}
                    onClick={() => pick(currency.code)}
                    onKeyDown={(event) => {
                      if (event.key === 'Enter' || event.key === ' ') {
                        event.preventDefault();
                        pick(currency.code);
                      }
                    }}
                    className="flex cursor-pointer items-center gap-3 rounded-md px-2 py-2 text-sm outline-none hover:bg-accent focus-visible:bg-accent"
                  >
                    <span className="w-10 shrink-0 font-bold tabular" dir="ltr">
                      {currency.code}
                    </span>
                    <span className="flex-1 truncate">{currency[language]}</span>
                    <span className="shrink-0 text-muted-foreground" dir="ltr">
                      {currency.symbol !== currency.code ? currency.symbol : ''}
                    </span>
                    <CheckIcon className={cn('size-4 shrink-0', selected ? 'opacity-100' : 'opacity-0')} aria-hidden />
                  </li>
                );
              })}
              {shown.length === 0 && <li className="px-2 py-4 text-sm text-muted-foreground">{t('currency.none')}</li>}
            </ul>
          </DialogContent>
        </Dialog>
      )}
    </>
  );
}
