import { useLiveQuery } from 'dexie-react-hooks';
import { ArchiveIcon, ArchiveRestoreIcon, FlagIcon, NotebookTextIcon, RepeatIcon, Trash2Icon } from 'lucide-react';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Link } from 'react-router';
import { toast } from 'sonner';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog';
import { Button } from '@/components/ui/button';
import { formatDay } from '@/lib/format';
import { EmptyState } from '../components/bits';
import { useHarvest } from '../context';
import type { SeedRow } from '../data/seeds';
import { HarvestDay } from '@harvest/core';

const typeIcon = { habit: RepeatIcon, project: FlagIcon, todo: NotebookTextIcon } as const;

/**
 * Where finished and retired seeds live (`ArchiveScreen` on the phone):
 * each with the note that says why and the day it was put away, and the
 * two ways out — back to the field, or gone for good.
 */
export function ArchiveScreen() {
  const { t } = useTranslation();
  const { db, seeds } = useHarvest();
  const [deleting, setDeleting] = useState<SeedRow | null>(null);
  const archived = useLiveQuery(
    async () =>
      (await db.rows('commitments').toArray())
        .filter((seed) => seed.deletedAt === null && seed.archivedAt !== null)
        .sort((a, b) => (b.archivedAt ?? '').localeCompare(a.archivedAt ?? '')),
    [db],
  );
  if (!archived) return null;

  return (
    <div className="flex flex-col gap-3">
      <h1 className="text-2xl font-extrabold max-md:sr-only">{t('archive.title')}</h1>
      {archived.length === 0 ? (
        <EmptyState icon={<ArchiveIcon />} title={t('archive.empty')} body={t('archive.emptyBody')} />
      ) : (
        <ul className="flex flex-col gap-2">
          {archived.map((seed) => {
            const Icon = typeIcon[seed.type];
            return (
              <li key={seed.uuid} className="relative flex flex-col gap-2 rounded-2xl border bg-card p-4">
                <div className="flex items-start gap-3">
                  <span className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-muted text-muted-foreground" aria-hidden>
                    <Icon className="size-5" />
                  </span>
                  <div className="flex min-w-0 flex-1 flex-col">
                    {/* The whole card opens the seed's page, as on the phone. */}
                    <Link
                      to={`/app/field/seed/${seed.uuid}`}
                      className="truncate text-lg font-extrabold outline-none after:absolute after:inset-0 after:content-[''] hover:underline focus-visible:ring-2 focus-visible:ring-ring"
                    >
                      {seed.title}
                    </Link>
                    {seed.archivedAt && (
                      <span className="text-xs text-muted-foreground">
                        {t('archive.archivedOn', { day: formatDay(HarvestDay.of(new Date(seed.archivedAt)).key) })}
                      </span>
                    )}
                  </div>
                </div>
                {seed.archiveNote && (
                  <p className="rounded-xl bg-muted/60 p-2.5 text-sm" dir="auto">
                    {seed.archiveNote}
                  </p>
                )}
                <div className="relative z-10 flex justify-end gap-1">
                  <Button
                    variant="ghost"
                    size="sm"
                    className="text-primary"
                    onClick={() => void seeds.restore(seed.uuid).then(() => toast.success(t('farmer.restoredToField', { title: seed.title })))}
                  >
                    <ArchiveRestoreIcon />
                    {t('archive.restore')}
                  </Button>
                  <Button variant="ghost" size="sm" className="text-destructive" onClick={() => setDeleting(seed)}>
                    <Trash2Icon />
                    {t('archive.delete')}
                  </Button>
                </div>
              </li>
            );
          })}
        </ul>
      )}
      <AlertDialog open={deleting !== null} onOpenChange={(open) => !open && setDeleting(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>{t('archive.deleteTitle')}</AlertDialogTitle>
            <AlertDialogDescription>{t('archive.deleteBody', { title: deleting?.title ?? '' })}</AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>{t('common.cancel')}</AlertDialogCancel>
            <AlertDialogAction
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
              onClick={() => {
                const seed = deleting;
                if (!seed) return;
                void seeds.remove(seed.uuid).then(
                  () => toast(t('archive.deleted')),
                  () => toast.error(t('common.somethingWrong')),
                );
              }}
            >
              {t('archive.delete')}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
