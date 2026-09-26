import { useLiveQuery } from 'dexie-react-hooks';
import { CheckIcon, PlayIcon } from 'lucide-react';
import { useState, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { useNavigate } from 'react-router';
import { toast } from 'sonner';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { useHarvest } from '../../context';
import { albumForPicture, nextDayOf, readPrograms, readRunning, readTrainingMaxes, type DayTree, type ProgramTree } from '../../data/gym';
import type { PictureState } from './picture-offer';
import { useUnit, useUnitKnown } from './shared';
import type { SeedRow } from '../../data/seeds';

/** `2 exercises · 9 sets`. */
export function useDaySummary(): (day: DayTree) => string {
  const { t } = useTranslation();
  return (day) =>
    t('gym.daySummary', { exercises: t('gym.exerciseCount', { count: day.slots.length }), sets: t('gym.setCount', { count: day.totalSets }) });
}

/**
 * Gets into a session. One rule lives here rather than in the screens
 * that call it: there is only ever one session running — begun here or
 * on the phone — so a running one is offered instead of a second.
 */
export function useStartSession(): (only?: ProgramTree) => Promise<'running' | 'pick' | 'none'> {
  const { db } = useHarvest();
  const navigate = useNavigate();
  return async (only) => {
    const running = await readRunning(db);
    if (running) {
      void navigate(`/app/body/gym/sessions/${running.session.uuid}`);
      return 'running';
    }
    const programs = await readPrograms(db);
    return programs.some((tree) => tree.days.length > 0 && (!only || tree.program.uuid === only.program.uuid)) ? 'pick' : 'none';
  };
}

/**
 * Which day (`session_start.dart`): every day of every program, with
 * the day that is up next leading each one, so the ordinary case is one
 * click and skipping a day is a deliberate second look (Y11). With
 * [only], a gym seed's own program and no other.
 */
export function StartDialog({ only, onClose }: { only?: ProgramTree; onClose: () => void }) {
  const { t } = useTranslation();
  const { db, sessions } = useHarvest();
  const navigate = useNavigate();
  const summary = useDaySummary();
  const unit = useUnit();
  const known = useUnitKnown();
  const [busy, setBusy] = useState(false);
  const choices = useLiveQuery(async () => {
    const programs = (await readPrograms(db)).filter(
      (tree) => tree.days.length > 0 && (!only || tree.program.uuid === only.program.uuid),
    );
    return Promise.all(programs.map(async (tree) => ({ tree, next: await nextDayOf(db, tree) })));
  }, [db, only?.program.uuid]);

  async function start(tree: ProgramTree, day: DayTree) {
    // A session started before the unit is read would label its sets in kilograms (Y8).
    if (busy || !known) return;
    // Several awaits sit between the click and the session; a second
    // click in that window waits for the first rather than racing it.
    setBusy(true);
    try {
      const { session, started } = await sessions.start({
        day,
        programUuid: tree.program.uuid,
        trainingMaxes: await readTrainingMaxes(db, tree.program.uuid),
        unit,
      });
      if (!started) toast(t('gym.alreadyRunning'));
      // The mirror on the way in, for whoever prefers it that way — only
      // for a session begun just now, not one picked back up.
      const album = started && tree.program.photoPrompt === 'before' ? await albumForPicture(db, tree.program.albumUuid) : null;
      onClose();
      void navigate(`/app/body/gym/sessions/${session.session.uuid}`, album ? { state: { gymPicture: album } satisfies PictureState } : undefined);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-h-[90dvh] max-w-md overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{t('gym.pickDay')}</DialogTitle>
          <DialogDescription>{t('gym.pickDayBody')}</DialogDescription>
        </DialogHeader>
        {choices?.length === 0 && <p className="text-sm text-muted-foreground">{t('gym.noProgramToStartBody')}</p>}
        {choices?.map(({ tree, next }) => (
          <section key={tree.program.uuid} aria-label={tree.program.name} className="flex flex-col gap-1.5">
            <h3 className="text-sm font-extrabold text-muted-foreground">{tree.program.name}</h3>
            {next && (
              <button
                type="button"
                disabled={busy || !known}
                onClick={() => void start(tree, next)}
                className="flex items-center gap-3 rounded-xl bg-secondary p-3 text-start text-secondary-foreground outline-none hover:brightness-95 focus-visible:ring-2 focus-visible:ring-ring disabled:opacity-60"
              >
                <PlayIcon className="size-6 shrink-0" aria-hidden />
                <span className="flex min-w-0 flex-col">
                  <span className="truncate font-extrabold">{next.row.name}</span>
                  <span className="text-xs">
                    {t('gym.upNext')} · {summary(next)}
                  </span>
                </span>
              </button>
            )}
            {tree.days.length > 1 && <p className="pt-1 text-xs text-muted-foreground">{t('gym.otherDays')}</p>}
            <ul className="flex flex-col">
              {tree.days
                .filter((day) => day.row.uuid !== next?.row.uuid)
                .map((day) => (
                  <li key={day.row.uuid}>
                    <button
                      type="button"
                      disabled={busy || !known}
                      onClick={() => void start(tree, day)}
                      className="flex w-full items-center gap-3 rounded-lg px-2 py-2 text-start outline-none hover:bg-accent focus-visible:ring-2 focus-visible:ring-ring disabled:opacity-60"
                    >
                      <span className="flex min-w-0 flex-1 flex-col">
                        <span className="truncate font-bold">{day.row.name}</span>
                        <span className="text-xs text-muted-foreground">{summary(day)}</span>
                      </span>
                      <PlayIcon className="size-4 text-muted-foreground" aria-hidden />
                    </button>
                  </li>
                ))}
            </ul>
          </section>
        ))}
      </DialogContent>
    </Dialog>
  );
}

/** The programs that are seeds, by the seed: the field asks before it ticks one. */
export function useGymSeeds(): Map<string, ProgramTree> | undefined {
  const { db } = useHarvest();
  return useLiveQuery(async () => {
    const map = new Map<string, ProgramTree>();
    for (const tree of await readPrograms(db)) if (tree.program.commitmentUuid) map.set(tree.program.commitmentUuid, tree);
    return map;
  }, [db]);
}

/**
 * The two honest ways to tick a gym seed (Y12): start the session, or
 * say I went and logged nothing — which is still a session, on the day
 * that was up next, finished on the spot, so the log and the streak
 * agree and *Next* moves on.
 */
export function GymSeedDialog({
  seed,
  program,
  onClose,
  onBare,
}: {
  seed: SeedRow;
  program: ProgramTree;
  onClose: () => void;
  /** Once "went, no numbers" has checked the seed in. */
  onBare?: () => void;
}) {
  const { t } = useTranslation();
  const { db, sessions } = useHarvest();
  const startSession = useStartSession();
  const [picking, setPicking] = useState(false);
  const [busy, setBusy] = useState(false);

  if (picking) return <StartDialog only={program} onClose={onClose} />;

  async function start() {
    const outcome = await startSession(program);
    if (outcome === 'pick') setPicking(true);
    else {
      if (outcome === 'none') toast(t('gym.noProgramToStartBody'));
      onClose();
    }
  }

  async function bare() {
    if (busy) return;
    setBusy(true);
    try {
      const next = await nextDayOf(db, program);
      const outcome = await sessions.bare({
        programUuid: program.program.uuid,
        dayUuid: next?.row.uuid ?? null,
        title: next?.row.name ?? t('gym.seedBare'),
      });
      onClose();
      onBare?.();
      if (outcome.xpEarned > 0) toast.success(t('field.xpEarned', { count: outcome.xpEarned }));
    } finally {
      setBusy(false);
    }
  }

  const option = 'flex w-full items-center gap-3 rounded-xl border p-3 text-start outline-none hover:bg-accent focus-visible:ring-2 focus-visible:ring-ring disabled:opacity-60';
  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-sm">
        <DialogHeader>
          <DialogTitle>{seed.title}</DialogTitle>
          <DialogDescription>{t('gym.seedQuestion')}</DialogDescription>
        </DialogHeader>
        <div className="flex flex-col gap-2">
          <button type="button" className={option} onClick={() => void start()}>
            <PlayIcon className="size-5 shrink-0 text-primary" aria-hidden />
            <span className="flex flex-col">
              <span className="font-extrabold">{t('gym.seedStart')}</span>
              <span className="text-xs text-muted-foreground">{t('gym.seedStartHint')}</span>
            </span>
          </button>
          <button type="button" className={option} disabled={busy} onClick={() => void bare()}>
            <CheckIcon className="size-5 shrink-0 text-muted-foreground" aria-hidden />
            <span className="flex flex-col">
              <span className="font-extrabold">{t('gym.seedBare')}</span>
              <span className="text-xs text-muted-foreground">{t('gym.seedBareHint')}</span>
            </span>
          </button>
        </div>
      </DialogContent>
    </Dialog>
  );
}

/**
 * The one door every check-in of a seed goes through before it ticks
 * one: [ask] opens the two-way choice for a gym seed and says so, and
 * says false for any other seed, which the caller then checks in as it
 * always has (Y12). The program is read at the moment of asking, so a
 * seed bound a second ago is asked about too.
 */
export function useGymSeedChoice({ onBare }: { onBare?: () => void } = {}): {
  ask: (seed: SeedRow) => Promise<boolean>;
  dialog: ReactNode;
} {
  const { db } = useHarvest();
  const [asking, setAsking] = useState<{ seed: SeedRow; program: ProgramTree } | null>(null);
  async function ask(seed: SeedRow): Promise<boolean> {
    const program = (await readPrograms(db)).find((tree) => tree.program.commitmentUuid === seed.uuid);
    if (!program) return false;
    setAsking({ seed, program });
    return true;
  }
  const dialog = asking && (
    <GymSeedDialog seed={asking.seed} program={asking.program} onClose={() => setAsking(null)} {...(onBare ? { onBare } : {})} />
  );
  return { ask, dialog };
}
