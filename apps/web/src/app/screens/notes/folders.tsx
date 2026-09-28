import { EllipsisVerticalIcon, FolderPenIcon, FilePlusIcon, FolderPlusIcon, Trash2Icon } from 'lucide-react';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
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
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { useHarvest } from '../../context';
import { normalizeFolder } from '../../data/notes';
import { runAction } from '@/lib/actions';

/** The folder a path sits in, `''` at the top. */
export function parentOf(path: string): string {
  return path.includes('/') ? path.slice(0, path.lastIndexOf('/')) : '';
}

/**
 * Makes a folder inside [parent], or renames [renaming] in place: its
 * notes and its subfolders move with it (`renameFolder`).
 */
export function FolderDialog({
  parent,
  renaming,
  onClose,
}: {
  parent: string;
  renaming?: string;
  onClose: (renamedTo?: string) => void;
}) {
  const { t } = useTranslation();
  const { notes } = useHarvest();
  const [name, setName] = useState(renaming ? (renaming.split('/').at(-1) ?? '') : '');
  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-sm">
        <DialogHeader>
          <DialogTitle>{renaming ? t('notes.renameFolder') : t('notes.newFolder')}</DialogTitle>
          <DialogDescription>{parent ? t('notes.insideFolder', { folder: parent }) : t('notes.atRoot')}</DialogDescription>
        </DialogHeader>
        <form
          className="flex flex-col gap-3"
          onSubmit={(event) => {
            event.preventDefault();
            if (!name.trim()) return;
            const path = normalizeFolder(parent ? `${parent}/${name}` : name);
            if (!renaming) {
              runAction(() => notes.addFolder(path).then(() => onClose()));
            } else if (path === renaming || !path) {
              onClose();
            } else {
              runAction(() => notes.renameFolder(renaming, path).then(() => onClose(path)));
            }
          }}
        >
          <Label htmlFor="folder-name">{t('notes.folderName')}</Label>
          <Input id="folder-name" autoFocus value={name} placeholder={t('notes.folderNameHint')} onChange={(event) => setName(event.target.value)} />
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onClose()}>
              {t('common.cancel')}
            </Button>
            <Button type="submit">{renaming ? t('common.save') : t('common.create')}</Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

/**
 * What a folder offers from the sidebar, as the phone's folder sheet
 * does: a note or a folder inside it, a new name, or the trash — which
 * takes every note in it, so it asks first and can be undone.
 */
export function FolderMenu({
  path,
  onNewNote,
  onNewFolder,
  onRename,
  onDeleted,
}: {
  path: string;
  onNewNote: () => void;
  onNewFolder: () => void;
  onRename: () => void;
  onDeleted: () => void;
}) {
  const { t } = useTranslation();
  const { notes } = useHarvest();
  const [confirming, setConfirming] = useState(false);
  const name = path.split('/').at(-1) ?? path;

  const remove = async () => {
    setConfirming(false);
    const trashed = await notes.trashFolder(path);
    onDeleted();
    toast(t('notes.folderTrashed', { folder: name, count: trashed.length }), {
      action: { label: t('common.undo'), onClick: () => runAction(() => notes.restoreFolder(path, trashed)) },
    });
  };

  return (
    <>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" size="icon-sm" className="shrink-0" aria-label={t('notes.folderOptions', { folder: name })}>
            <EllipsisVerticalIcon />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem onSelect={onNewNote}>
            <FilePlusIcon />
            {t('notes.newNoteHere')}
          </DropdownMenuItem>
          <DropdownMenuItem onSelect={onNewFolder}>
            <FolderPlusIcon />
            {t('notes.newSubfolder')}
          </DropdownMenuItem>
          <DropdownMenuItem onSelect={onRename}>
            <FolderPenIcon />
            {t('notes.renameFolder')}
          </DropdownMenuItem>
          <DropdownMenuItem onSelect={() => setConfirming(true)}>
            <Trash2Icon />
            {t('notes.deleteFolder')}
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
      <AlertDialog open={confirming} onOpenChange={setConfirming}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>{t('notes.deleteFolderTitle', { folder: name })}</AlertDialogTitle>
            <AlertDialogDescription>{t('notes.deleteFolderBody', { folder: path })}</AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>{t('common.cancel')}</AlertDialogCancel>
            <AlertDialogAction destructive onClick={() => runAction(() => remove())}>
              {t('common.delete')}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
}
