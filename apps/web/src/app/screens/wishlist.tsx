import { HarvestDay } from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import { ArrowDownIcon, ArrowUpIcon, EllipsisVerticalIcon, PencilIcon, PlusIcon, ShoppingBagIcon, StarIcon, Trash2Icon } from 'lucide-react';
import { useState } from 'react';
import type { TFunction } from 'i18next';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group';
import { formatDay, formatMoney } from '@/lib/format';
import { EmptyState } from '../components/bits';
import { useHarvest, useHarvestDay } from '../context';
import type { WishlistList, WishlistRow } from '../data/wishlist';
import { useDialogs } from '../dialogs';

/** Open items' estimates per currency, never added across (W2). */
function openTotals(items: WishlistRow[]): string {
  const sums = new Map<string, number>();
  for (const row of items) {
    if (row.priceMinor === null) continue;
    sums.set(row.currency, (sums.get(row.currency) ?? 0) + row.priceMinor);
  }
  return [...sums.entries()].map(([currency, minor]) => formatMoney(minor, currency)).join(' · ');
}

/** The target day (with days left) and the note, both when both are there, as the phone shows them. */
function rowSubtitle(row: WishlistRow, today: HarvestDay, t: TFunction): string | undefined {
  const parts: string[] = [];
  const target = HarvestDay.tryParse(row.targetDay);
  if (target) {
    const left = today.daysUntil(target);
    if (left < 0) parts.push(formatDay(target.key, { dateStyle: 'medium' }));
    else if (left === 0) parts.push(t('wishlist.today'));
    else parts.push(t('wishlist.inDays', { count: left }));
  }
  const note = row.note?.trim();
  if (note) parts.push(note);
  return parts.length > 0 ? parts.join(' · ') : undefined;
}

/**
 * The Wishlist tab of the Granary ([[Wishlist]]): the buy list and the
 * wishlist, one segment each, with the open items' estimated total per
 * currency and bought things folded below. A plain-tier table, so it
 * renders without the passphrase the money tabs ask for.
 */
export function WishlistPanel() {
  const { t } = useTranslation();
  const { db, wishlist } = useHarvest();
  const dialogs = useDialogs();
  const today = useHarvestDay();
  const [segment, setSegment] = useState<WishlistList>('buy');

  const rows = useLiveQuery(
    async () =>
      (await db.rows('wishlist_items').toArray())
        .filter((row) => row.deletedAt === null)
        .sort((a, b) => a.list.localeCompare(b.list) || a.position - b.position || a.createdAt.localeCompare(b.createdAt)),
    [db],
  );
  if (!rows) return null;

  const current = rows.filter((row) => row.list === segment);
  // Only the buy list folds bought things away (W7). A wish item that
  // arrives bought (an old import, another device) stays in view with
  // the rest of the wishlist, where it can still be moved or deleted.
  const folds = segment === 'buy';
  const open = current.filter((row) => !folds || row.boughtAt === null);
  const bought = current.filter((row) => folds && row.boughtAt !== null);

  const other = (row: WishlistRow): WishlistList => (row.list === 'buy' ? 'wish' : 'buy');

  const moveInList = (from: number, to: number) => {
    const order = open.map((row) => row.uuid);
    const [uuid] = order.splice(from, 1);
    order.splice(to, 0, uuid!);
    void wishlist.reorder(segment, order);
  };

  const remove = (row: WishlistRow) => {
    void wishlist.delete(row.uuid);
    toast(t('wishlist.removed'), {
      action: { label: t('common.undo'), onClick: () => void wishlist.restore(row.uuid) },
    });
  };

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <ToggleGroup
          type="single"
          value={segment}
          onValueChange={(value) => value && setSegment(value as WishlistList)}
          aria-label={t('wishlist.lists')}
        >
          <ToggleGroupItem value="buy">{t('wishlist.buyList')}</ToggleGroupItem>
          <ToggleGroupItem value="wish">{t('wishlist.wishlist')}</ToggleGroupItem>
        </ToggleGroup>
        <Button onClick={() => dialogs.addWishlistItem(segment)}>
          <PlusIcon />
          {t('wishlist.add')}
        </Button>
      </div>

      {open.length === 0 && bought.length === 0 ? (
        <EmptyState
          icon={segment === 'buy' ? <ShoppingBagIcon /> : <StarIcon />}
          title={segment === 'buy' ? t('wishlist.buyEmptyTitle') : t('wishlist.wishEmptyTitle')}
          body={segment === 'buy' ? t('wishlist.buyEmptyBody') : t('wishlist.wishEmptyBody')}
          action={
            <Button onClick={() => dialogs.addWishlistItem(segment)}>
              <PlusIcon />
              {t('wishlist.add')}
            </Button>
          }
        />
      ) : (
        <>
          <div className="flex items-baseline justify-between gap-2 px-1">
            <h2 className="text-sm font-extrabold text-muted-foreground">
              {t('wishlist.open')}
              {openTotals(open) && <span className="ms-2 tabular" dir="ltr">{openTotals(open)}</span>}
            </h2>
          </div>

          <ul className="flex flex-col divide-y rounded-xl border bg-card">
            {open.map((row, index) => (
              <li key={row.uuid} className="flex items-center gap-2 px-3 py-2.5">
                {segment === 'buy' ? (
                  <Checkbox
                    aria-label={t('wishlist.markBought', { title: row.title })}
                    onCheckedChange={() => void wishlist.setBought(row.uuid, true)}
                  />
                ) : (
                  <span className="w-4 text-muted-foreground" aria-hidden>
                    <StarIcon className="size-4" />
                  </span>
                )}
                <button
                  type="button"
                  onClick={() => dialogs.editWishlistItem(row)}
                  className="flex min-w-0 flex-1 flex-col text-start outline-none hover:underline focus-visible:ring-2 focus-visible:ring-ring"
                >
                  <span className="truncate font-bold">{row.title}</span>
                  {rowSubtitle(row, today, t) && (
                    <span className="truncate text-xs text-muted-foreground">{rowSubtitle(row, today, t)}</span>
                  )}
                </button>
                {/* An estimate, not money owed: plain ink, so it never reads like a debt. */}
                {row.priceMinor !== null && (
                  <span className="font-extrabold tabular text-foreground" dir="ltr">
                    {formatMoney(row.priceMinor, row.currency)}
                  </span>
                )}
                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <Button variant="ghost" size="icon-sm" aria-label={t('wishlist.options', { title: row.title })}>
                      <EllipsisVerticalIcon />
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end">
                    <DropdownMenuItem onSelect={() => dialogs.editWishlistItem(row)}>
                      <PencilIcon />
                      {t('common.edit')}
                    </DropdownMenuItem>
                    <DropdownMenuItem onSelect={() => void wishlist.move(row.uuid, other(row))}>
                      {row.list === 'buy' ? t('wishlist.moveToWish') : t('wishlist.moveToBuy')}
                    </DropdownMenuItem>
                    <DropdownMenuItem disabled={index === 0} onSelect={() => moveInList(index, index - 1)}>
                      <ArrowUpIcon />
                      {t('wishlist.up')}
                    </DropdownMenuItem>
                    <DropdownMenuItem disabled={index === open.length - 1} onSelect={() => moveInList(index, index + 1)}>
                      <ArrowDownIcon />
                      {t('wishlist.down')}
                    </DropdownMenuItem>
                    <DropdownMenuItem onSelect={() => remove(row)}>
                      <Trash2Icon />
                      {t('common.delete')}
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              </li>
            ))}
          </ul>

          {bought.length > 0 && (
            <details className="group">
              <summary className="flex cursor-pointer items-center gap-2 py-1 text-sm font-extrabold text-muted-foreground">
                <span className="transition-transform group-open:rotate-90" aria-hidden>
                  ▸
                </span>
                {t('wishlist.bought', { count: bought.length })}
              </summary>
              <ul className="mt-2 flex flex-col divide-y rounded-xl border bg-card">
                {bought.map((row) => (
                  <li key={row.uuid} className="flex items-center gap-2 px-3 py-2.5">
                    <Checkbox
                      aria-label={t('wishlist.unmarkBought', { title: row.title })}
                      checked
                      onCheckedChange={() => void wishlist.setBought(row.uuid, false)}
                    />
                    <span className="flex min-w-0 flex-1 flex-col">
                      <span className="truncate font-bold text-muted-foreground line-through">{row.title}</span>
                      {row.boughtAt && (
                        <span className="truncate text-xs text-muted-foreground">
                          {t('wishlist.boughtOn', { day: formatDay(HarvestDay.of(new Date(row.boughtAt)).key, { dateStyle: 'medium' }) })}
                        </span>
                      )}
                    </span>
                    {row.priceMinor !== null && (
                      <span className="font-bold tabular text-muted-foreground" dir="ltr">
                        {formatMoney(row.priceMinor, row.currency)}
                      </span>
                    )}
                  </li>
                ))}
              </ul>
            </details>
          )}
        </>
      )}
    </div>
  );
}