import { freezeCost, globalStreakScope, maxFreezesStored, streakMilestoneCoins } from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import { CoinsIcon, FlameIcon, SnowflakeIcon } from 'lucide-react';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { formatNumber } from '@/lib/format';
import { cn } from '@/lib/utils';
import { useHarvest, useHarvestDay } from '../context';
import type { HarvestDB } from '../data/db';
import { buyFreeze } from '../data/streaks';
import { runAction } from '@/lib/actions';

/** The global streak and the coin balance, the two things a freeze is bought with. */
async function readShed(db: HarvestDB) {
  const [global, coins] = await Promise.all([
    db.rows('streaks').get(globalStreakScope),
    db.rows('ledger').where('kind').equals('coin').toArray(),
  ]);
  return {
    current: global?.current ?? 0,
    best: global?.best ?? 0,
    freezes: global?.freezesStored ?? 0,
    coins: coins.reduce((sum, entry) => sum + entry.delta, 0),
  };
}

/**
 * Buying a freeze, as the phone's streak sheet does: a button that is
 * only live with coins enough and room in the shed, and a hint for
 * where coins come from when there are not enough. Spending one on a
 * missed day is the phone's 3 AM judging, never this.
 */
export function FreezeShop({ coins, freezes }: { coins: number; freezes: number }) {
  const { t } = useTranslation();
  const { writer } = useHarvest();
  const today = useHarvestDay();
  const [buying, setBuying] = useState(false);
  const canBuy = freezes < maxFreezesStored && coins >= freezeCost && !buying;
  const first = Math.min(...Object.keys(streakMilestoneCoins).map(Number));

  async function buy() {
    setBuying(true);
    try {
      const bought = await buyFreeze(writer, today);
      if (bought) toast.success(t('streak.freezeBought'));
      else toast(t('streak.freezeUnavailable'));
    } finally {
      setBuying(false);
    }
  }

  return (
    <div className="flex flex-col gap-1">
      <Button disabled={!canBuy} onClick={() => runAction(() => buy())}>
        <SnowflakeIcon />
        {t('streak.buyFreeze', { cost: formatNumber(freezeCost) })}
      </Button>
      {coins < freezeCost && (
        <p className="text-center text-xs text-muted-foreground">
          {t('streak.earnHint', { coins: formatNumber(streakMilestoneCoins[first] ?? 0), days: formatNumber(first) })}
        </p>
      )}
    </div>
  );
}

/** The streak up close: the run, the best, the freezes in the shed, and the shop. */
export function StreakDialog({ onClose }: { onClose: () => void }) {
  const { t } = useTranslation();
  const { db } = useHarvest();
  const shed = useLiveQuery(() => readShed(db), [db]);
  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-sm">
        <DialogHeader>
          <DialogTitle>{t('streak.sheetTitle')}</DialogTitle>
          <DialogDescription className="flex items-center gap-1 font-extrabold text-foreground">
            <CoinsIcon className="size-4 text-sun" aria-hidden />
            {t('farmer.coinCount', { count: shed?.coins ?? 0, formatted: formatNumber(shed?.coins ?? 0) })}
          </DialogDescription>
        </DialogHeader>
        {shed && (
          <div className="flex flex-col gap-4">
            <div className="flex items-center gap-3">
              <FlameIcon className={cn('size-12', shed.current > 0 ? 'text-primary' : 'text-muted-foreground')} aria-hidden />
              <div className="flex flex-col">
                <span className="text-2xl font-extrabold tabular">{t('streak.days', { count: shed.current })}</span>
                <span className="text-sm text-muted-foreground">{t('streak.best', { count: shed.best })}</span>
              </div>
            </div>
            <div className="flex flex-col gap-1">
              <span className="font-extrabold">{t('streak.freezes', { count: shed.freezes, max: maxFreezesStored })}</span>
              <span className="text-xs text-muted-foreground">{t('streak.freezeExplainer')}</span>
            </div>
            <FreezeShop coins={shed.coins} freezes={shed.freezes} />
            <p className="text-xs text-muted-foreground">{t('streak.phoneJudges')}</p>
          </div>
        )}
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            {t('common.close')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
