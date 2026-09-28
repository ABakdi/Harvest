import { ArchiveRestoreIcon, ArrowLeftIcon, FileTextIcon, RotateCcwIcon, Trash2Icon } from 'lucide-react';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Link, useNavigate } from 'react-router';
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
  AlertDialogTrigger,
} from '@/components/ui/alert-dialog';
import { Button } from '@/components/ui/button';
import { formatDate, shortName } from '@/lib/format';
import { useHarvest } from '../../context';
import { AppBarActions } from '../../components/app-bar';
import { EmptyState } from '../../components/bits';
import type { NoteRow } from '../../data/notes';
import { notePreview } from '../../data/notes';
import { background, runAction } from '@/lib/actions';
import type { Vault } from './vault';

/**
 * Deleted notes, and the two things I can do with them: put one back,
 * or let it go for good — which asks first, as emptying the whole
 * trash does. On a wide window it fills the note's pane; on a phone it
 * is a screen of its own, "Empty the trash" up in its bar.
 */
export function Trash({ vault, phone }: { vault: Vault; phone: boolean }) {
  const { t } = useTranslation();
  const { notes } = useHarvest();
  const navigate = useNavigate();
  const [purging, setPurging] = useState<NoteRow | null>(null);

  const restore = (note: NoteRow) =>
    runAction(() =>
      notes.restore(note.uuid).then(() =>
        toast(t('notes.restoredToast', { title: shortName(note.title || t('notes.untitled')) }), {
          action: { label: t('notes.openRestored'), onClick: () => background(navigate(`/app/records/${note.uuid}`)) },
        }),
      ),
    );

  const emptyAll = vault.trash.length > 0 && (
    <AlertDialog>
      <AlertDialogTrigger asChild>
        <Button variant={phone ? 'ghost' : 'outline'} size="sm" className={phone ? 'text-primary' : undefined}>
          {t('notes.emptyTrash')}
        </Button>
      </AlertDialogTrigger>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>{t('notes.emptyTrashTitle')}</AlertDialogTitle>
          <AlertDialogDescription>{t('notes.emptyTrashBody', { count: vault.trash.length })}</AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel>{t('common.cancel')}</AlertDialogCancel>
          <AlertDialogAction destructive onClick={() => runAction(() => notes.emptyTrash())}>
            {t('notes.emptyTrash')}
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );

  const list =
    vault.trash.length === 0 ? (
      <div className="flex flex-1 items-center justify-center py-10">
        <EmptyState icon={<Trash2Icon />} title={t('notes.trashEmptyTitle')} body={t('notes.trashEmptyBody')} />
      </div>
    ) : (
      <>
        <p className="text-sm text-muted-foreground">{t('notes.trashKeeps')}</p>
        <ul className="flex flex-col gap-2">
          {vault.trash.map((note) => (
            <li key={note.uuid} className="flex items-center gap-3 rounded-xl border bg-card p-3 ps-4">
              <FileTextIcon className="size-5 shrink-0 text-muted-foreground" aria-hidden />
              <div className="flex min-w-0 flex-1 flex-col">
                <span dir="auto" className="truncate font-bold">
                  {note.title || t('notes.untitled')}
                </span>
                <span dir="auto" className="truncate text-xs text-muted-foreground">
                  {phone ? formatDate(note.updatedAt, { dateStyle: 'medium' }) : notePreview(note.body) || formatDate(note.updatedAt, { dateStyle: 'medium' })}
                </span>
              </div>
              {phone ? (
                <Button variant="ghost" size="icon" aria-label={t('notes.restore')} title={t('notes.restore')} onClick={() => restore(note)}>
                  <ArchiveRestoreIcon />
                </Button>
              ) : (
                <Button variant="outline" size="sm" onClick={() => restore(note)}>
                  <RotateCcwIcon />
                  {t('notes.restore')}
                </Button>
              )}
              <Button
                variant="ghost"
                size={phone ? 'icon' : 'icon-sm'}
                aria-label={t('notes.deleteForever', { title: note.title })}
                title={t('notes.deleteForeverShort')}
                onClick={() => setPurging(note)}
              >
                <Trash2Icon />
              </Button>
            </li>
          ))}
        </ul>
      </>
    );

  return (
    <section className="flex min-h-0 flex-1 flex-col" aria-labelledby="trash-heading">
      {phone ? (
        <>
          <h1 id="trash-heading" className="sr-only">
            {t('notes.trashTitle')}
          </h1>
          <AppBarActions>{emptyAll}</AppBarActions>
        </>
      ) : (
        <div className="flex h-10 shrink-0 items-center gap-2 border-b px-3">
          <Button asChild variant="ghost" size="icon-sm" className="size-7" aria-label={t('notes.backToList')}>
            <Link to="/app/records">
              <ArrowLeftIcon className="rtl:rotate-180" />
            </Link>
          </Button>
          <h1 id="trash-heading" className="flex-1 truncate text-sm font-bold">
            {t('notes.trashTitle')}
          </h1>
          {emptyAll}
        </div>
      )}
      <div className="min-h-0 flex-1 overflow-y-auto overscroll-contain" data-note-scroller>
        <div className={phone ? 'flex min-h-full flex-col gap-3 p-4' : 'mx-auto flex min-h-full w-full max-w-[calc(700px+4rem)] flex-col gap-3 px-8 py-8'}>{list}</div>
      </div>
      <AlertDialog open={purging !== null} onOpenChange={(open) => !open && setPurging(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>{t('notes.deleteForeverTitle')}</AlertDialogTitle>
            <AlertDialogDescription>{t('notes.deleteForeverBody')}</AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>{t('common.cancel')}</AlertDialogCancel>
            <AlertDialogAction
              destructive
              onClick={() => {
                const note = purging;
                setPurging(null);
                if (note) runAction(() => notes.purge(note.uuid));
              }}
            >
              {t('notes.deleteForeverShort')}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </section>
  );
}
