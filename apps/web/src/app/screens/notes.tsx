import { useLiveQuery } from 'dexie-react-hooks';
import { FilePlusIcon, FileTextIcon, MenuIcon, MicIcon } from 'lucide-react';
import { useEffect, useRef, useState, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { NavigationType, useLocation, useNavigate, useNavigationType, useParams } from 'react-router';
import { Button } from '@/components/ui/button';
import { dropDraft, leftDrafts } from '@/lib/note-drafts';
import { EmptyState } from '../components/bits';
import { AppBarActions, AppBarLeading } from '../components/app-bar';
import { Fab, usePhoneWidth } from '../components/fab';
import { recordingFormat } from '../components/notes/voice';
import { useHarvest } from '../context';
import { useBusy } from '../components/use-busy';
import { RecordsOff, RecordsTabs, useRecordsOff } from './records';
import type { HarvestDB } from '../data/db';
import type { NotesRepository } from '../data/notes';
import { voiceNoteTitle } from '../data/attachments';
import { background, runAction } from '@/lib/actions';
import { loadVault, noteToReopen, rememberedNote, rememberNote } from './notes/vault';
import { NotesDrawer, Sidebar, type VaultActions } from './notes/sidebar';
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

/**
 * Records: the notes vault ([[Notes]]). A wide window is Obsidian's: the
 * vault's tree down the side and the note beside it, each scrolling on
 * its own. A phone-width one is the phone's: one note in place, the
 * vault in a drawer, the note's actions in the app bar.
 */
export function NotesScreen({ trash = false }: { trash?: boolean }) {
  const { t } = useTranslation();
  const { db, notes } = useHarvest();
  const navigate = useNavigate();
  const navigation = useNavigationType();
  const location = useLocation();
  const { uuid } = useParams();
  const phone = usePhoneWidth();
  const vault = useLiveQuery(() => loadVault(db), [db]);
  // The folder a new note goes in: the one I clicked in the tree, else
  // the open note's, as Obsidian puts a new note by default.
  const [picked, setPicked] = useState<{ folder: string; with: string | undefined }>({ folder: '', with: undefined });
  const [drawerState, setDrawerState] = useState<{ visit: number; open: boolean } | null>(null);
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

  // A note made here and not written in goes when I leave it, rather
  // than stay as an empty "Untitled" (U6-08).
  const fresh = useRef<string | null>(null);
  useEffect(() => {
    const made = fresh.current;
    if (made && made !== uuid) {
      fresh.current = null;
      background(notes.discardIfBlank(made));
    }
  }, [uuid, notes]);
  useEffect(
    () => () => {
      if (fresh.current) background(notes.discardIfBlank(fresh.current));
    },
    [notes],
  );

  const note = uuid && vault ? vault.notes.find((row) => row.uuid === uuid) : undefined;

  const folder = picked.with === uuid || !note ? picked.folder : note.folder;
  const setFolder = (path: string) => setPicked({ folder: path, with: uuid });

  // The phone remembers the note I am in, and opens on it again.
  const opened = note?.uuid;
  useEffect(() => {
    if (phone && opened) rememberNote(opened);
  }, [phone, opened]);

  // Each arrival here is a visit, with the note (if any) it came from:
  // a history entry's key cannot tell a first load from Back to it.
  const here = `${location.key} ${location.pathname}`;
  const [visit, setVisit] = useState({ here, n: 0, from: undefined as string | undefined, note: uuid });
  if (visit.here !== here) setVisit({ here, n: visit.n + 1, from: visit.note, note: uuid });

  // Back from a note closes it and shows the notes, as Back on the phone
  // does (U6-07): the drawer opens over the empty page.
  const backedOut = phone && !trash && !uuid && navigation === NavigationType.Pop && visit.from !== undefined;
  const drawer = drawerState?.visit === visit.n ? drawerState.open : backedOut && (vault?.notes.length ?? 0) > 0;
  const setDrawer = (open: boolean) => setDrawerState({ visit: visit.n, open });

  // Notes on a phone opens on the note I was last in (`_openLatest`).
  const handled = useRef<number | null>(null);
  useEffect(() => {
    if (!phone || trash || uuid || !vault || !restored || off !== false) return;
    if (handled.current === visit.n) return;
    handled.current = visit.n;
    if (backedOut) {
      // Coming back later opens on the list, not on the note I closed.
      rememberNote('');
      return;
    }
    const target = noteToReopen(vault.notes, rememberedNote());
    if (target) background(navigate(`/app/records/${target.uuid}`));
  }, [phone, trash, uuid, vault, restored, off, backedOut, visit.n, navigate]);

  const actions: VaultActions = {
    newNote: (where) =>
      once(async () => {
        const made = await notes.create({ folder: where });
        fresh.current = made.uuid;
        await navigate(`/app/records/${made.uuid}`, { replace: phone && uuid !== undefined });
      }),
    // The three-second path: a note named by the minute, recording at once.
    newVoiceNote: (where) =>
      once(async () => {
        const made = await notes.create({ title: voiceNoteTitle(new Date()), folder: where });
        await navigate(`/app/records/${made.uuid}`, { replace: phone && uuid !== undefined, state: { record: true } });
      }),
  };

  if (!vault || off === undefined || !restored) return null;
  if (off) {
    return (
      <div className="min-h-0 flex-1 overflow-y-auto p-3 md:p-6">
        <RecordsOff />
      </div>
    );
  }

  const onRemoved = () => {
    if (phone) {
      // The phone opens the latest note once one is deleted, found here
      // rather than from a list that may still hold the one just gone.
      const next = noteToReopen(
        vault.notes.filter((row) => row.uuid !== uuid),
        null,
      );
      rememberNote(next ? next.uuid : '');
      background(navigate(next ? `/app/records/${next.uuid}` : '/app/records', { replace: true }));
    } else {
      background(navigate('/app/records'));
    }
  };

  const newNoteButton = (
    <Button disabled={creating} onClick={() => runAction(() => actions.newNote(folder))}>
      <FilePlusIcon />
      {t('notes.new')}
    </Button>
  );

  const pane = trash ? (
    <Trash vault={vault} phone={phone} />
  ) : note ? (
    <Editor key={note.uuid} note={note} vault={vault} phone={phone} actions={actions} onRemoved={onRemoved} />
  ) : uuid ? (
    <Centered>
      <EmptyState icon={<FileTextIcon />} title={t('notes.gone')} body={t('notes.goneBody')} />
    </Centered>
  ) : phone ? (
    <Centered>
      <PhoneEmpty
        title={vault.notes.length ? t('notes.pick') : t('notes.emptyTitle')}
        body={vault.notes.length ? t('notes.pickBody') : t('notes.emptyBodyTap')}
        action={
          vault.notes.length > 0 && (
            <Button size="lg" onClick={() => setDrawer(true)}>
              <MenuIcon />
              {t('notes.showList')}
            </Button>
          )
        }
      />
      {/* The same floating button as every other tab, while no note is open (U6-32). */}
      <Fab label={t('notes.new')} wide={false} disabled={creating} onClick={() => runAction(() => actions.newNote(''))} />
    </Centered>
  ) : (
    <Centered>
      <EmptyState
        icon={<FileTextIcon />}
        title={vault.notes.length ? t('notes.pick') : t('notes.emptyTitle')}
        body={t('notes.emptyBody')}
        action={newNoteButton}
      />
    </Centered>
  );

  if (phone) {
    return (
      <div className="flex min-h-0 flex-1 flex-col">
        {!trash && <h1 className="sr-only">{t('nav.notes')}</h1>}
        {/* The Records tabs stay while a note is open, as on the phone
            ([[Checkpoint-8]]); the trash is a screen of its own. */}
        {!trash && <RecordsTabs className="shrink-0 max-md:static max-md:mx-0 max-md:mt-0" />}
        {!trash && (
          <>
            <AppBarLeading>
              <Button variant="ghost" size="icon" aria-label={t('notes.showList')} title={t('notes.showList')} onClick={() => setDrawer(true)}>
                <MenuIcon />
              </Button>
            </AppBarLeading>
            {!note && recordingFormat() !== null && (
              <AppBarActions>
                <Button variant="ghost" size="icon" aria-label={t('voice.newNote')} title={t('voice.newNote')} onClick={() => runAction(() => actions.newVoiceNote(''))}>
                  <MicIcon />
                </Button>
              </AppBarActions>
            )}
            <NotesDrawer
              open={drawer}
              onOpenChange={setDrawer}
              vault={vault}
              selected={uuid}
              selectedFolder={note?.folder}
              actions={actions}
            />
          </>
        )}
        {pane}
      </div>
    );
  }

  return (
    <div className="flex min-h-0 flex-1 flex-col">
      {!trash && <h1 className="sr-only">{t('nav.notes')}</h1>}
      <RecordsTabs className="mx-4 my-2 shrink-0" />
      <div className="flex min-h-0 flex-1 border-t">
        <Sidebar
          vault={vault}
          folder={folder}
          setFolder={setFolder}
          selected={uuid}
          selectedFolder={note?.folder}
          actions={actions}
        />
        <section className="flex min-w-0 flex-1 flex-col" aria-label={t('notes.pane')}>
          {pane}
        </section>
      </div>
    </div>
  );
}

function Centered({ children }: { children: ReactNode }) {
  return <div className="flex min-h-0 flex-1 flex-col items-center justify-center overflow-y-auto p-6">{children}</div>;
}

/** The phone's empty page: the icon on its tinted square, the words, and one way on (`EmptyState`). */
function PhoneEmpty({ title, body, action }: { title: string; body: string; action?: ReactNode }) {
  return (
    <div className="flex max-w-sm flex-col items-center gap-3 text-center">
      <span className="mb-2 flex size-24 items-center justify-center rounded-[28px] bg-sun/20 text-sun">
        <FileTextIcon className="size-10" aria-hidden />
      </span>
      <h2 className="text-2xl font-extrabold">{title}</h2>
      <p className="text-muted-foreground">{body}</p>
      {action && <div className="mt-3">{action}</div>}
    </div>
  );
}
