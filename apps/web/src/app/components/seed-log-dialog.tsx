import { commitmentFromRow, maxUnitsPerDay } from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import { ArchiveIcon } from 'lucide-react';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { formatNumber } from '@/lib/format';
import { useHarvest, useHarvestDay } from '../context';
import type { HarvestDB } from '../data/db';
import type { SeedRow } from '../data/seeds';
import { useBusy } from './use-busy';

/** A project's units: logged today, ever, and the room left under today's cap. */
async function readUnits(db: HarvestDB, seed: SeedRow, dayKey: string) {
  const rows = await db.rows('check_ins').where('commitmentUuid').equals(seed.uuid).toArray();
  let today = 0;
  let total = 0;
  for (const row of rows) {
    if (row.deletedAt !== null) continue;
    total += row.quantity;
    if (row.harvestDay === dayKey) today += row.quantity;
  }
  let cap: number;
  try {
    cap = maxUnitsPerDay(commitmentFromRow(seed));
  } catch {
    cap = 0; // an unreadable seed takes nothing more
  }
  return { today, total, room: Math.max(cap - today, 0) };
}

/**
 * Logging progress on a project, and the 100% moment after it: when a
 * log carries the project to its target, a celebration says so and the
 * project is archived with its history intact, as on the phone
 * (`_celebrateCompletion`).
 */
export function SeedLogDialog({ seed, onClose }: { seed: SeedRow; onClose: () => void }) {
  const { t } = useTranslation();
  const { db, checkIns, seeds } = useHarvest();
  const day = useHarvestDay();
  const units = useLiveQuery(() => readUnits(db, seed, day.key), [db, seed, day.key]);
  const [quantity, setQuantity] = useState<string | null>(null);
  const [finished, setFinished] = useState<number | null>(null);
  const [busy, once] = useBusy();
  const room = units?.room ?? 0;
  const shown = quantity ?? String(Math.min(seed.dailyCommitment ?? 1, Math.max(room, 1)));
  const value = Number(shown);
  const valid = Number.isInteger(value) && value >= 1;

  // One log per press: a double click or a held Enter must not check
  // in twice.
  async function log() {
    if (!valid || !units) return;
    const plan = await checkIns.checkIn(seed, day, value);
    const total = units.total + plan.quantityLogged;
    if (plan.quantityLogged > 0 && total >= (seed.totalTarget ?? 0)) {
      setFinished(total);
      return;
    }
    onClose();
    if (plan.quantityLogged > 0) toast.success(t('field.xpEarned', { count: plan.xpEarned }));
    if (plan.capped) toast(t('field.capped'));
  }

  // The dialog closes however it closes; the project goes to the barn.
  function closeFinished() {
    void seeds.archive(seed.uuid, null);
    onClose();
  }

  if (finished !== null) {
    return (
      <Dialog open onOpenChange={(open) => !open && closeFinished()}>
        <DialogContent className="max-w-sm">
          <DialogHeader>
            <DialogTitle>{t('field.projectDoneTitle')}</DialogTitle>
            <DialogDescription>{t('field.projectDoneBody', { title: seed.title, total: formatNumber(finished) })}</DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button onClick={closeFinished}>
              <ArchiveIcon />
              {t('field.toTheBarn')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    );
  }

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-sm">
        <DialogHeader>
          <DialogTitle>{t('field.logProgressTitle')}</DialogTitle>
          <DialogDescription>{seed.title}</DialogDescription>
        </DialogHeader>
        <form
          className="flex flex-col gap-3"
          onSubmit={(event) => {
            event.preventDefault();
            void once(log);
          }}
        >
          <Label htmlFor="log-quantity">{t('field.howMuch')}</Label>
          <Input
            id="log-quantity"
            type="number"
            min={1}
            inputMode="numeric"
            autoFocus
            value={shown}
            onChange={(event) => setQuantity(event.target.value)}
          />
          <p className="text-sm text-muted-foreground">{t('field.remaining', { count: room })}</p>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={onClose}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" disabled={!valid || !units || room === 0 || busy}>
              {t('field.log')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
