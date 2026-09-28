import { useLiveQuery } from 'dexie-react-hooks';
import { FilePlusIcon, FileTextIcon } from 'lucide-react';
import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useNavigate, useParams } from 'react-router';
import { Button } from '@/components/ui/button';
import { dropDraft, leftDrafts } from '@/lib/note-drafts';
import { cn } from '@/lib/utils';
import { EmptyState } from '../components/bits';
import { useHarvest } from '../context';
import { useBusy } from '../components/use-busy';
import { RecordsOff, RecordsTabs, useRecordsOff } from './records';
import type { HarvestDB } from '../data/db';
import type { NotesRepository } from '../data/notes';
import { background, runAction } from '@/lib/actions';
import { loadVault } from './notes/vault';
import { Sidebar } from './notes/sidebar';
import { Editor } from './notes/editor';
import { Trash } from './notes/trash';

/**
 * Puts drafts left in `localStorage` back into their notes: only one
 * typed after the note last changed — a newer save, here or from another
 * device, already holds it or overrules it. A draft for a note this
 * account does not have stays for the account that does.
 */
async function restoreDrafts(db: HarvestDB, notes: NotesRepository): Promise<void> {
  for (const [uuid, draft] of leftDrafts()) {
    const row = await db.rows('notes').get(uuid);
    if (!row) continue;
    if (row.deletedAt === null && draft.at > row.updatedAt) {
      await notes.update(uuid, { title: draft.title, folder: draft.folder, body: draft.body });
    }
    dropDraft(uuid, draft.at);
  }
}

/** Records: the notes vault, with the sidebar beside the note ([[Notes]]). */
export function NotesScreen({ trash = false }: { trash?: boolean }) {
  const { t } = useTranslation();
  const { db, notes } = useHarvest();
  const navigate = useNavigate();
  const { uuid } = useParams();
  const vault = useLiveQuery(() => loadVault(db), [db]);
  const [folder, setFolder] = useState('');
  const [creating, once] = useBusy();
  const off = useRecordsOff();
  // Typing a reload cut off before it was saved goes back in first, so
  // no note opens without it — nor as an empty "Untitled" (W4-02).
  const [restored, setRestored] = useState(false);
  useEffect(() => {
    let live = true;
    background(restoreDrafts(db, notes).finally(() => live && setRestored(true)));
    return () => {
      live = false;
    };
  }, [db, notes]);
  if (!vault || off === undefined || !restored) return null;
  if (off) return <RecordsOff />;
  const note = uuid ? vault.notes.find((row) => row.uuid === uuid) : undefined;
  const detail = trash || uuid !== undefined;

  return (
    <div className="flex flex-col gap-4">
      {!trash && <h1 className="sr-only">{t('nav.notes')}</h1>}
      {/* A note or the trash is a screen of its own on a phone, with no tab row over it. */}
      <RecordsTabs className={detail ? 'max-md:hidden' : undefined} />
      <div className="grid grid-cols-1 gap-6 md:grid-cols-[18rem_1fr]">
      <div className={cn('min-w-0', detail && 'hidden md:block')}>
        <Sidebar vault={vault} folder={folder} setFolder={setFolder} selected={uuid} />
      </div>
      <div className={cn('min-w-0', !detail && 'hidden md:block')}>
        {trash ? (
          <Trash vault={vault} />
        ) : note ? (
          <Editor key={note.uuid} note={note} vault={vault} />
        ) : uuid ? (
          <EmptyState icon={<FileTextIcon />} title={t('notes.gone')} />
        ) : (
          <EmptyState
            icon={<FileTextIcon />}
            title={vault.notes.length ? t('notes.pick') : t('notes.emptyTitle')}
            body={t('notes.emptyBody')}
            action={
              <Button
                disabled={creating}
                onClick={() => {
                  runAction(() => once(() => notes.create({ folder }).then((created) => navigate(`/app/records/${created.uuid}`))));
                }}
              >
                <FilePlusIcon />
                {t('notes.new')}
              </Button>
            }
          />
        )}
        </div>
      </div>
    </div>
  );
}
