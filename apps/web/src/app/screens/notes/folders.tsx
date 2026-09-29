import { CheckIcon, EllipsisIcon, FolderIcon, FolderPenIcon, FilePlusIcon, FolderPlusIcon, InboxIcon, Trash2Icon } from 'lucide-react';
import { useState } from 'react';
import type * as React from 'react';
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
import { cn } from '@/lib/utils';

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
  className,
}: {
  path: string;
  onNewNote: () => void;
  onNewFolder: () => void;
  onRename: () => void;
  onDeleted: () => void;
  className?: string | undefined;
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
          <Button variant="ghost" size="icon-sm" className={cn('shrink-0', className)} aria-label={t('notes.folderOptions', { folder: name })}>
            <EllipsisIcon />
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

/**
 * Where a note lives, picked from the folders there are or a new one
 * named, as the phone's folder sheet offers it (`NoteFolderSheet`).
 */
export function MoveToFolderDialog({
  current,
  folders,
  onPick,
  onClose,
}: {
  current: string;
  folders: string[];
  onPick: (folder: string) => void;
  onClose: () => void;
}) {
  const { t } = useTranslation();
  const [naming, setNaming] = useState(false);
  const [name, setName] = useState('');
  const choice = (path: string, label: string, icon: React.ReactNode) => {
    const here = normalizeFolder(current) === path;
    return (
      <li key={path || 'root'}>
        <button
          type="button"
          aria-current={here ? 'true' : undefined}
          onClick={() => onPick(path)}
          className={cn(
            'flex min-h-12 w-full items-center gap-3 rounded-lg px-2 text-start outline-none hover:bg-accent focus-visible:ring-2 focus-visible:ring-ring',
            here && 'font-extrabold text-primary',
          )}
        >
          <span className="text-muted-foreground [&_svg]:size-5">{icon}</span>
          <span dir="auto" className="min-w-0 flex-1 truncate">
            {label}
          </span>
          {here && <CheckIcon className="size-5 text-success" aria-hidden />}
        </button>
      </li>
    );
  };
  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-sm" aria-describedby={undefined}>
        <DialogHeader>
          <DialogTitle>{t('notes.moveToFolder')}</DialogTitle>
        </DialogHeader>
        <ul className="-mx-2 flex flex-col">
          {choice('', t('notes.rootFolder'), <InboxIcon />)}
          {folders.map((path) => choice(path, path, <FolderIcon />))}
        </ul>
        <div className="border-t pt-3">
          {naming ? (
            <form
              className="flex flex-col gap-2"
              onSubmit={(event) => {
                event.preventDefault();
                if (name.trim()) onPick(normalizeFolder(name));
              }}
            >
              <Label htmlFor="move-folder-name">{t('notes.newFolder')}</Label>
              <Input id="move-folder-name" autoFocus value={name} placeholder={t('notes.folderNameHint')} onChange={(event) => setName(event.target.value)} />
              <p className="text-xs text-muted-foreground">{t('notes.folderHint')}</p>
              <DialogFooter>
                <Button type="submit" disabled={!name.trim()}>
                  {t('common.save')}
                </Button>
              </DialogFooter>
            </form>
          ) : (
            <button
              type="button"
              onClick={() => setNaming(true)}
              className="-mx-2 flex min-h-12 w-[calc(100%+1rem)] items-center gap-3 rounded-lg px-2 text-start outline-none hover:bg-accent focus-visible:ring-2 focus-visible:ring-ring"
            >
              <FolderPlusIcon className="size-5 text-muted-foreground" aria-hidden />
              {t('notes.newFolder')}
            </button>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
