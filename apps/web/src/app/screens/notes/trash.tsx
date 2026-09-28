import { ArrowLeftIcon, RotateCcwIcon, Trash2Icon } from 'lucide-react';
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
import { shortName } from '@/lib/format';
import { useHarvest } from '../../context';
import { notePreview } from '../../data/notes';
import { background, runAction } from '@/lib/actions';
import type { Vault } from './vault';

export function Trash({ vault }: { vault: Vault }) {
  const { t } = useTranslation();
  const { notes } = useHarvest();
  const navigate = useNavigate();
  return (
    <section className="flex flex-col gap-3" aria-labelledby="trash-heading">
      <div className="flex items-center gap-2">
        <Button asChild variant="ghost" size="icon" className="max-md:hidden" aria-label={t('notes.backToList')}>
          <Link to="/app/records">
            <ArrowLeftIcon className="rtl:rotate-180" />
          </Link>
        </Button>
        <h1 id="trash-heading" className="flex-1 text-xl font-extrabold">
          {t('notes.trashTitle')}
        </h1>
        {vault.trash.length > 0 && (
          <AlertDialog>
            <AlertDialogTrigger asChild>
              <Button variant="outline">{t('notes.emptyTrash')}</Button>
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
        )}
      </div>
      {vault.trash.length === 0 ? (
        <p className="text-muted-foreground">{t('notes.trashEmpty')}</p>
      ) : (
        <ul className="flex flex-col gap-2">
          {vault.trash.map((note) => (
            <li key={note.uuid} className="flex items-center gap-3 rounded-xl border bg-card p-3">
              <div className="flex min-w-0 flex-1 flex-col">
                <span dir="auto" className="truncate font-bold">{note.title || t('notes.untitled')}</span>
                <span dir="auto" className="truncate text-xs text-muted-foreground">{notePreview(note.body)}</span>
              </div>
              <Button
                variant="outline"
                size="sm"
                onClick={() =>
                  runAction(() => notes.restore(note.uuid).then(() =>
                    toast(t('notes.restoredToast', { title: shortName(note.title || t('notes.untitled')) }), {
                      action: { label: t('notes.openRestored'), onClick: () => background(navigate(`/app/records/${note.uuid}`)) },
                    }),
                  ))
                }
              >
                <RotateCcwIcon />
                {t('notes.restore')}
              </Button>
              <Button
                variant="ghost"
                size="icon-sm"
                aria-label={t('notes.deleteForever', { title: note.title })}
                onClick={() => runAction(() => notes.purge(note.uuid))}
              >
                <Trash2Icon />
              </Button>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
