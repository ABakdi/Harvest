import { useLiveQuery } from 'dexie-react-hooks';
import { FileTextIcon, SproutIcon, TargetIcon } from 'lucide-react';
import { useMemo, useRef, useState, type KeyboardEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { useNavigate } from 'react-router';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { useHarvest } from '../context';
import { notePreview } from '../data/notes';

interface Hit {
  kind: 'seed' | 'goal' | 'note';
  id: string;
  title: string;
  detail: string;
  to: string;
}

const icons = { seed: SproutIcon, goal: TargetIcon, note: FileTextIcon } as const;

/**
 * `/` from anywhere: seeds, goals and notes by title, and notes by what
 * they say, matching as I type. Arrow keys move, Enter opens.
 */
export function SearchDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (open: boolean) => void }) {
  const { t } = useTranslation();
  const { db } = useHarvest();
  const navigate = useNavigate();
  const [query, setQuery] = useState('');
  const [active, setActive] = useState(0);
  const list = useRef<HTMLUListElement>(null);

  const everything = useLiveQuery(async () => {
    if (!open) return null;
    const [seeds, goals, notes] = await Promise.all([
      db.rows('commitments').toArray(),
      db.rows('goals').toArray(),
      db.rows('notes').toArray(),
    ]);
    return { seeds, goals, notes };
  }, [db, open]);

  const hits = useMemo<Hit[]>(() => {
    const needle = query.trim().toLowerCase();
    if (!needle || !everything) return [];
    const seeds: Hit[] = [];
    const goals: Hit[] = [];
    const notes: Hit[] = [];
    for (const seed of everything.seeds) {
      if (seed.deletedAt !== null || !seed.title.toLowerCase().includes(needle)) continue;
      seeds.push({
        kind: 'seed',
        id: seed.uuid,
        title: seed.title,
        detail: seed.archivedAt ? t('search.archivedSeed') : t(`seed.type.${seed.type}`),
        // Its own page, archived or not: the history is there either way.
        to: `/app/field/seed/${seed.uuid}`,
      });
    }
    for (const goal of everything.goals) {
      if (goal.deletedAt !== null || !goal.title.toLowerCase().includes(needle)) continue;
      goals.push({ kind: 'goal', id: goal.uuid, title: goal.title, detail: t('search.goal'), to: `/app/field/goals/${goal.uuid}` });
    }
    for (const note of everything.notes) {
      if (note.deletedAt !== null) continue;
      const inTitle = note.title.toLowerCase().includes(needle);
      if (!inTitle && !note.body.toLowerCase().includes(needle)) continue;
      notes.push({
        kind: 'note',
        id: note.uuid,
        title: note.title || t('notes.untitled'),
        detail: note.folder || notePreview(note.body),
        to: `/app/records/${note.uuid}`,
      });
    }
    return fairShare([seeds, goals, notes], 30);
  }, [everything, query, t]);

  function go(hit: Hit | undefined) {
    if (!hit) return;
    onOpenChange(false);
    setQuery('');
    void navigate(hit.to);
  }

  function onKeyDown(event: KeyboardEvent) {
    if (event.key === 'ArrowDown') {
      event.preventDefault();
      // Never below the first: with no results there is nothing to move to.
      setActive((index) => Math.max(0, Math.min(index + 1, hits.length - 1)));
    } else if (event.key === 'ArrowUp') {
      event.preventDefault();
      setActive((index) => Math.max(index - 1, 0));
    } else if (event.key === 'Enter') {
      event.preventDefault();
      go(hits[active]);
    }
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        onOpenChange(next);
        if (!next) setQuery('');
      }}
    >
      <DialogContent sheet={false} className="top-[15%] translate-y-0 gap-3 p-4">
        <DialogHeader>
          <DialogTitle className="sr-only">{t('app.search')}</DialogTitle>
          <DialogDescription className="sr-only">{t('search.lead')}</DialogDescription>
        </DialogHeader>
        <Input
          autoFocus
          role="combobox"
          aria-label={t('app.search')}
          aria-expanded={hits.length > 0}
          aria-controls="search-results"
          aria-activedescendant={hits[active] ? `hit-${hits[active].id}` : undefined}
          placeholder={t('search.placeholder')}
          value={query}
          onChange={(event) => {
            setQuery(event.target.value);
            setActive(0);
          }}
          onKeyDown={onKeyDown}
        />
        <ul id="search-results" role="listbox" ref={list} className="flex max-h-80 flex-col gap-1 overflow-y-auto">
          {hits.map((hit, index) => {
            const Icon = icons[hit.kind];
            return (
              <li
                key={`${hit.kind}-${hit.id}`}
                id={`hit-${hit.id}`}
                role="option"
                aria-selected={index === active}
                onMouseEnter={() => setActive(index)}
                onClick={() => go(hit)}
                className="flex cursor-pointer items-center gap-3 rounded-lg px-3 py-2 aria-selected:bg-accent"
              >
                <Icon className="size-4 shrink-0 text-muted-foreground" aria-hidden />
                <span className="flex min-w-0 flex-col">
                  <span className="truncate font-bold">{hit.title}</span>
                  <span className="truncate text-xs text-muted-foreground">{hit.detail}</span>
                </span>
              </li>
            );
          })}
          {query.trim() && hits.length === 0 && <li className="px-3 py-2 text-sm text-muted-foreground">{t('search.nothing')}</li>}
        </ul>
      </DialogContent>
    </Dialog>
  );
}

/**
 * At most [limit] hits, in their groups' order, with every group given
 * its share before any takes more: many matching seeds must not push
 * every note off the list ([[Audit-v3]] Q5-52).
 */
export function fairShare<T>(groups: readonly (readonly T[])[], limit: number): T[] {
  const taken = groups.map(() => 0);
  let left = limit;
  // Round by round, one more from each group that still has some.
  while (left > 0 && groups.some((group, i) => taken[i]! < group.length)) {
    for (let i = 0; i < groups.length && left > 0; i++) {
      if (taken[i]! < groups[i]!.length) {
        taken[i]!++;
        left--;
      }
    }
  }
  return groups.flatMap((group, i) => group.slice(0, taken[i]));
}
