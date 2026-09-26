import { wishListId, type ListKind } from '@harvest/contracts';
import { HarvestDay, classifyLink, linkOf } from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import {
  ArrowDownIcon,
  ArrowLeftIcon,
  ArrowRightIcon,
  ArrowUpIcon,
  CheckIcon,
  EllipsisVerticalIcon,
  ExternalLinkIcon,
  ListChecksIcon,
  NotebookPenIcon,
  PencilIcon,
  PlayIcon,
  PlusIcon,
  SlidersHorizontalIcon,
  SproutIcon,
  StarIcon,
  Trash2Icon,
  XIcon,
} from 'lucide-react';
import { useEffect, useId, useRef, useState, type ClipboardEvent, type FormEvent, type KeyboardEvent } from 'react';
import type { TFunction } from 'i18next';
import { useTranslation } from 'react-i18next';
import { Link, Navigate, useNavigate, useParams } from 'react-router';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Input } from '@/components/ui/input';
import { formatDay, formatMoney, formatNumber } from '@/lib/format';
import { cn } from '@/lib/utils';
import { EmptyState } from '../components/bits';
import { ListNameDialog, listName } from '../components/list-bits';
import { useFeaturesOrOff } from '../components/settings-bits';
import { useHarvest, useHarvestDay } from '../context';
import { builtInOf, listOfItem, type ListItemRow, type ListRow } from '../data/lists';
import { loadListsView, type ListsView, type SeedProgress } from '../data/list-views';
import { useDialogs } from '../dialogs';
import { RecordsTabs } from './records';

/** Open items' estimates per currency, never added across (L3). */
function openTotals(items: ListItemRow[]): string {
  const sums = new Map<string, number>();
  for (const row of items) {
    if (row.priceMinor === null) continue;
    sums.set(row.currency, (sums.get(row.currency) ?? 0) + row.priceMinor);
  }
  return [...sums.entries()].map(([currency, minor]) => formatMoney(minor, currency)).join(' · ');
}

/** What a row says under its title, by its list's kind. */
function rowSubtitle(row: ListItemRow, kind: ListKind, today: HarvestDay, t: TFunction): string | undefined {
  const parts: string[] = [];
  if (kind === 'shopping') {
    const target = HarvestDay.tryParse(row.targetDay);
    if (target) {
      const left = today.daysUntil(target);
      if (left < 0) parts.push(formatDay(target.key, { dateStyle: 'medium' }));
      else if (left === 0) parts.push(t('wishlist.today'));
      else parts.push(t('wishlist.inDays', { count: left }));
    }
  }
  if (kind === 'media') {
    if (row.mediaType) parts.push(t(`lists.mediaType.${row.mediaType}`));
    if (row.creator) parts.push(row.creator);
  }
  const note = row.note?.trim();
  if (note) parts.push(note);
  return parts.length > 0 ? parts.join(' · ') : undefined;
}

/** The day a done item was done, read on the Harvest Day it fell in. */
function doneDay(row: ListItemRow): string {
  return formatDay(HarvestDay.of(new Date(row.boughtAt!)).key, { dateStyle: 'medium' });
}

/**
 * Records → Lists ([[Lists]]): the lists as chips with their open
 * counts, the chosen list below with its open items in my order and
 * what is done folded underneath. Nothing on a list pays, costs or
 * moves money (L3, L4, L8); a list is a row, never a screen (L1).
 */
export function ListsScreen() {
  const { t } = useTranslation();
  const { db } = useHarvest();
  const { listUuid } = useParams();
  const view = useLiveQuery(() => loadListsView(db), [db]);
  const [naming, setNaming] = useState<{ list: ListRow | null } | null>(null);
  const navigate = useNavigate();

  if (!view) return null;
  const chosen = view.lists.find((list) => list.uuid === listUuid) ?? (listUuid ? undefined : view.lists[0]);
  // A list that is gone (deleted here or on another device): back to the first.
  if (!chosen && listUuid) return <Navigate to="/app/records/lists" replace />;

  return (
    <div className="flex flex-col gap-4">
      <RecordsTabs />
      <div className="flex items-center gap-2">
        <nav aria-label={t('lists.chips')} className="flex min-w-0 flex-1 gap-2 overflow-x-auto pb-1">
          {view.lists.map((list) => (
            <Link
              key={list.uuid}
              to={`/app/records/lists/${list.uuid}`}
              aria-current={list.uuid === chosen?.uuid ? 'page' : undefined}
              aria-label={t('lists.chipLabel', { name: listName(list, t), count: view.counts.get(list.uuid) ?? 0 })}
              className={cn(
                'flex shrink-0 items-center gap-1.5 rounded-full border px-3 py-1.5 text-sm font-extrabold outline-none focus-visible:ring-2 focus-visible:ring-ring',
                list.uuid === chosen?.uuid ? 'border-primary bg-primary text-primary-foreground' : 'bg-card hover:bg-accent',
              )}
            >
              <span>{listName(list, t)}</span>
              <span className="tabular opacity-80" aria-hidden>
                {formatNumber(view.counts.get(list.uuid) ?? 0)}
              </span>
            </Link>
          ))}
        </nav>
        <Button variant="outline" size="sm" aria-label={t('lists.newList')} onClick={() => setNaming({ list: null })}>
          <PlusIcon />
          <span className="hidden sm:inline" aria-hidden>
            {t('lists.newList')}
          </span>
        </Button>
      </div>

      {chosen ? (
        <ListPanel key={chosen.uuid} list={chosen} view={view} onRename={() => setNaming({ list: chosen })} />
      ) : (
        <EmptyState icon={<ListChecksIcon />} title={t('lists.noLists')} />
      )}

      {naming && (
        <ListNameDialog
          list={naming.list}
          onClose={() => setNaming(null)}
          onCreated={(list) => void navigate(`/app/records/lists/${list.uuid}`)}
        />
      )}
    </div>
  );
}

function ListPanel({ list, view, onRename }: { list: ListRow; view: ListsView; onRename: () => void }) {
  const { t } = useTranslation();
  const { lists } = useHarvest();
  const navigate = useNavigate();
  const headingId = useId();
  const [focus, setFocus] = useState<string | null>(null);
  const rows = useRef(new Map<string, HTMLButtonElement>());
  // A deleted list's menu has nowhere to hand the focus back to.
  const deleting = useRef(false);

  const name = listName(list, t);
  const index = view.lists.findIndex((row) => row.uuid === list.uuid);
  const items = view.items.filter((row) => listOfItem(row) === list.uuid);
  // The Wishlist folds nothing away: its items are not bought (L7), and
  // one that arrives bought (an old import) stays where it can be moved.
  const folds = list.uuid !== wishListId;
  const open = items.filter((row) => !folds || row.boughtAt === null);
  const done = items.filter((row) => folds && row.boughtAt !== null);

  // Keeps the keyboard on the row that just moved.
  useEffect(() => {
    if (focus === null) return;
    rows.current.get(focus)?.focus();
  });

  const moveList = (by: number) => {
    const order = view.lists.map((row) => row.uuid);
    const [uuid] = order.splice(index, 1);
    order.splice(index + by, 0, uuid!);
    void lists.reorderLists(order);
  };

  const deleteList = async () => {
    deleting.current = true;
    if (!(await lists.deleteList(list.uuid))) {
      deleting.current = false;
      return;
    }
    void navigate('/app/records/lists', { replace: true });
    toast(t('lists.listDeleted', { name }), {
      action: {
        label: t('common.undo'),
        onClick: () => void lists.restoreList(list.uuid).then(() => navigate(`/app/records/lists/${list.uuid}`)),
      },
    });
  };

  const moveItem = (from: number, to: number) => {
    if (to < 0 || to >= open.length) return;
    const order = open.map((row) => row.uuid);
    const [uuid] = order.splice(from, 1);
    order.splice(to, 0, uuid!);
    setFocus(uuid!);
    void lists.reorderItems(list.uuid, order);
  };

  return (
    <section aria-labelledby={headingId} className="flex flex-col gap-3">
      <div className="flex items-center justify-between gap-2">
        <h1 id={headingId} className="min-w-0 truncate text-2xl font-extrabold">
          {name}
        </h1>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon" aria-label={t('lists.listMenu', { name })}>
              <EllipsisVerticalIcon />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" onCloseAutoFocus={(event) => deleting.current && event.preventDefault()}>
            <DropdownMenuItem onSelect={onRename}>
              <PencilIcon />
              {t('lists.rename')}
            </DropdownMenuItem>
            <DropdownMenuItem disabled={index <= 0} onSelect={() => moveList(-1)}>
              <ArrowLeftIcon className="rtl:rotate-180" />
              {t('lists.moveEarlier')}
            </DropdownMenuItem>
            <DropdownMenuItem disabled={index >= view.lists.length - 1} onSelect={() => moveList(1)}>
              <ArrowRightIcon className="rtl:rotate-180" />
              {t('lists.moveLater')}
            </DropdownMenuItem>
            {/* The built-in lists stay (L10): emptied or renamed, never deleted. */}
            {!builtInOf(list) && (
              <DropdownMenuItem destructive onSelect={() => void deleteList()}>
                <Trash2Icon />
                {t('lists.deleteList')}
              </DropdownMenuItem>
            )}
          </DropdownMenuContent>
        </DropdownMenu>
      </div>

      <AddField list={list} name={name} />

      {open.length === 0 && done.length === 0 ? (
        <EmptyState icon={<ListChecksIcon />} title={t('lists.emptyTitle')} body={t(`lists.emptyBody.${list.kind}`)} />
      ) : (
        <>
          {list.kind === 'shopping' && openTotals(open) && (
            <p className="px-1 text-sm font-extrabold text-muted-foreground">
              {t('wishlist.open')}
              <span className="ms-2 tabular" dir="ltr">
                {openTotals(open)}
              </span>
            </p>
          )}
          {open.length > 0 && (
            <ul className="flex flex-col divide-y rounded-xl border bg-card">
              {open.map((row, at) => (
                <ItemRow
                  key={row.uuid}
                  row={row}
                  list={list}
                  view={view}
                  first={at === 0}
                  last={at === open.length - 1}
                  onMove={(by) => moveItem(at, at + by)}
                  titleRef={(node) => {
                    if (node) rows.current.set(row.uuid, node);
                    else rows.current.delete(row.uuid);
                  }}
                />
              ))}
            </ul>
          )}
          {done.length > 0 && (
            <details className="group">
              <summary className="flex cursor-pointer items-center gap-2 py-1 text-sm font-extrabold text-muted-foreground">
                <span className="transition-transform group-open:rotate-90 rtl:group-open:-rotate-90" aria-hidden>
                  ▸
                </span>
                {t(`lists.doneFold.${list.kind}`, { count: done.length })}
              </summary>
              <ul className="mt-2 flex flex-col divide-y rounded-xl border bg-card">
                {done.map((row) => (
                  <ItemRow key={row.uuid} row={row} list={list} view={view} />
                ))}
              </ul>
            </details>
          )}
        </>
      )}
    </section>
  );
}

/**
 * The add field. A bare link, pasted or typed, becomes the item's link
 * and stands in for its title until one is typed ([[Lists]]: Saving from
 * anywhere); on a media list its host picks the type, the same way the
 * phone's share sheet does. Nothing is fetched (L9).
 */
function AddField({ list, name }: { list: ListRow; name: string }) {
  const { t } = useTranslation();
  const { lists } = useHarvest();
  const dialogs = useDialogs();
  const id = useId();
  const [text, setText] = useState('');
  const [link, setLink] = useState<string | null>(null);
  const input = useRef<HTMLInputElement>(null);

  const reset = () => {
    setText('');
    setLink(null);
    input.current?.focus();
  };

  /** The link and title the field holds now: a bare link typed counts as pasted. */
  const read = () => {
    const typed = link === null ? linkOf(text) : null;
    const url = link ?? typed;
    const title = typed ? typed : text.trim() || url || '';
    return { url, title };
  };

  const paste = (event: ClipboardEvent<HTMLInputElement>) => {
    if (link !== null || text.trim() !== '') return;
    const pasted = linkOf(event.clipboardData.getData('text'));
    if (!pasted) return;
    event.preventDefault();
    setLink(pasted);
  };

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    const { url, title } = read();
    if (!title) return;
    const media = list.kind === 'media';
    try {
      await lists.addItem(list.uuid, {
        title,
        // Only a media item has a link (L2); elsewhere a link with a title of its own goes in the note.
        link: media ? url : null,
        mediaType: media && url ? classifyLink(url).mediaType : null,
        note: !media && url && url !== title ? url : null,
      });
    } catch {
      toast.error(t('common.saveFailed'));
      return;
    }
    reset();
  };

  const details = () => {
    const { url, title } = read();
    const media = list.kind === 'media';
    dialogs.addListItem(list.uuid, {
      title: media && title === url ? '' : title,
      link: media ? url : null,
      mediaType: media && url ? classifyLink(url).mediaType : null,
    });
    setText('');
    setLink(null);
  };

  return (
    <form onSubmit={(event) => void submit(event)} className="flex flex-col gap-2" noValidate>
      <div className="flex gap-2">
        <Input
          ref={input}
          id={`${id}-add`}
          value={text}
          maxLength={2000}
          aria-label={t('lists.addLabel', { name })}
          aria-describedby={link ? `${id}-link` : undefined}
          placeholder={link ?? t('lists.addHint')}
          onPaste={paste}
          onChange={(event) => setText(event.target.value)}
        />
        <Button type="submit" disabled={!text.trim() && link === null}>
          <PlusIcon />
          <span className="sr-only sm:not-sr-only">{t('lists.add')}</span>
        </Button>
        <Button type="button" variant="outline" size="icon" aria-label={t('lists.details')} title={t('lists.details')} onClick={details}>
          <SlidersHorizontalIcon />
        </Button>
      </div>
      {link && (
        <p id={`${id}-link`} className="flex min-w-0 items-center gap-2 text-xs text-muted-foreground">
          <span className="shrink-0 font-extrabold">{t('lists.linkLabel')}</span>
          <span className="min-w-0 truncate" dir="ltr">
            {link}
          </span>
          <span className="shrink-0">{t('lists.linkIsTitle')}</span>
          <Button type="button" variant="ghost" size="icon-sm" aria-label={t('lists.clearLink')} onClick={() => setLink(null)}>
            <XIcon />
          </Button>
        </p>
      )}
    </form>
  );
}

/** A 1–5 rating for a finished media item; the star pressed again takes it back. */
function Rating({ row }: { row: ListItemRow }) {
  const { t } = useTranslation();
  const { lists } = useHarvest();
  return (
    <div role="group" aria-label={t('lists.ratingOf', { title: row.title })} className="flex">
      {[1, 2, 3, 4, 5].map((stars) => (
        <button
          key={stars}
          type="button"
          aria-label={t('lists.rate', { count: stars })}
          aria-pressed={row.rating === stars}
          onClick={() => void lists.setRating(row.uuid, row.rating === stars ? null : stars)}
          className="rounded p-0.5 outline-none focus-visible:ring-2 focus-visible:ring-ring"
        >
          <StarIcon className={cn('size-4', row.rating !== null && stars <= row.rating ? 'fill-primary text-primary' : 'text-muted-foreground')} aria-hidden />
        </button>
      ))}
    </div>
  );
}

/** The seed an item was planted as, and how far it has come. */
function SeedLine({ progress, t }: { progress: SeedProgress; t: TFunction }) {
  const text =
    progress.total !== null
      ? t('lists.seedProject', { done: formatNumber(progress.done), total: formatNumber(progress.total) })
      : progress.complete
        ? t('lists.seedDone')
        : t('lists.seedPlanted');
  return (
    <Link to={`/app/field/seed/${progress.seed.uuid}`} className="inline-flex items-center gap-1 text-xs font-bold text-primary hover:underline">
      <SproutIcon className="size-3.5" aria-hidden />
      {text}
    </Link>
  );
}

function ItemRow({
  row,
  list,
  view,
  first,
  last,
  onMove,
  titleRef,
}: {
  row: ListItemRow;
  list: ListRow;
  view: ListsView;
  first?: boolean;
  last?: boolean;
  /** Only an open item moves: up (-1) or down (1). */
  onMove?: (by: number) => void;
  titleRef?: (node: HTMLButtonElement | null) => void;
}) {
  const { t } = useTranslation();
  const { db, lists, notes } = useHarvest();
  const dialogs = useDialogs();
  const navigate = useNavigate();
  const today = useHarvestDay();
  const on = useFeaturesOrOff();
  const kind = list.kind;
  const isDone = row.boughtAt !== null;
  // A wish is not bought (L7): it moves to *To buy* first.
  const buyable = list.uuid !== wishListId;
  const seed = row.seedUuid ? view.seeds.get(row.seedUuid) : undefined;
  const others = view.lists.filter((other) => other.kind === kind && other.uuid !== list.uuid);
  const subtitle = rowSubtitle(row, kind, today, t);
  const link = kind === 'media' && row.link ? linkOf(row.link) : null;

  const setDone = async (done: boolean) => {
    if (!(await lists.setDone(row.uuid, done))) return;
    // Bought offers the expense, prefilled; it never logs one (L4).
    if (done && kind === 'shopping') {
      dialogs.suggestExpense({ note: row.title, amountMinor: row.priceMinor, currency: row.currency });
    }
  };

  const remove = () => {
    void lists.deleteItem(row.uuid);
    toast(t('wishlist.removed'), {
      action: { label: t('common.undo'), onClick: () => void lists.restoreItem(row.uuid) },
    });
  };

  const move = async (to: ListRow) => {
    if (await lists.moveItem(row.uuid, to.uuid)) toast(t('lists.moved', { name: listName(to, t) }));
  };

  // Opens the note written about it, or starts one named after it.
  const writeAbout = async () => {
    const existing = row.noteUuid ? await db.rows('notes').get(row.noteUuid) : undefined;
    if (existing && existing.deletedAt === null) {
      void navigate(`/app/records/${existing.uuid}`);
      return;
    }
    try {
      const note = await notes.create({ title: row.title });
      await lists.linkNote(row.uuid, note.uuid);
      void navigate(`/app/records/${note.uuid}`);
    } catch {
      toast.error(t('common.saveFailed'));
    }
  };

  const keys = (event: KeyboardEvent<HTMLButtonElement>) => {
    if (!onMove || !event.altKey) return;
    if (event.key === 'ArrowUp' && !first) {
      event.preventDefault();
      onMove(-1);
    } else if (event.key === 'ArrowDown' && !last) {
      event.preventDefault();
      onMove(1);
    }
  };

  let control;
  if (kind === 'media' && !isDone) {
    control =
      row.startedAt === null ? (
        <Button variant="outline" size="icon-sm" aria-label={t('lists.start', { title: row.title })} title={t('lists.startShort')} onClick={() => void lists.setStarted(row.uuid, true)}>
          <PlayIcon />
        </Button>
      ) : (
        <Button variant="outline" size="icon-sm" aria-label={t('lists.finish', { title: row.title })} title={t('lists.finishShort')} onClick={() => void setDone(true)}>
          <CheckIcon />
        </Button>
      );
  } else if (kind === 'shopping' && !buyable) {
    control = (
      <span className="w-4 text-muted-foreground" aria-hidden>
        <StarIcon className="size-4" />
      </span>
    );
  } else {
    control = (
      <Checkbox
        aria-label={t(isDone ? `lists.unmark.${kind}` : `lists.mark.${kind}`, { title: row.title })}
        checked={isDone}
        onCheckedChange={() => void setDone(!isDone)}
      />
    );
  }

  return (
    <li className="flex flex-col gap-1 px-3 py-2.5">
      <div className="flex items-center gap-2">
        {control}
        <button
          ref={titleRef}
          type="button"
          onClick={() => dialogs.editListItem(row)}
          onKeyDown={keys}
          aria-keyshortcuts={onMove ? 'Alt+ArrowUp Alt+ArrowDown' : undefined}
          className="flex min-w-0 flex-1 flex-col text-start outline-none hover:underline focus-visible:ring-2 focus-visible:ring-ring"
        >
          <span className={cn('truncate font-bold', isDone && buyable && 'text-muted-foreground line-through')}>{row.title}</span>
          {subtitle && <span className="truncate text-xs text-muted-foreground">{subtitle}</span>}
          {isDone && buyable && (
            <span className="truncate text-xs text-muted-foreground">{t(`lists.doneOn.${kind}`, { day: doneDay(row) })}</span>
          )}
        </button>
        {kind === 'media' && !isDone && row.startedAt !== null && (
          <span className="shrink-0 rounded-full bg-muted px-2 py-0.5 text-xs font-extrabold">{t('lists.inProgress')}</span>
        )}
        {/* An estimate, not money owed: plain ink, so it never reads like a debt. */}
        {row.priceMinor !== null && kind === 'shopping' && (
          <span className={cn('font-extrabold tabular', isDone ? 'text-muted-foreground' : 'text-foreground')} dir="ltr">
            {formatMoney(row.priceMinor, row.currency)}
          </span>
        )}
        {link && (
          // Opened only by my click, in a new tab, telling the site nothing of where it came from (L9).
          <Button asChild variant="ghost" size="icon-sm">
            <a href={link} target="_blank" rel="noopener noreferrer" aria-label={t('lists.openLink', { title: row.title })} title={link}>
              <ExternalLinkIcon />
            </a>
          </Button>
        )}
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon-sm" aria-label={t('wishlist.options', { title: row.title })}>
              <EllipsisVerticalIcon />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuItem onSelect={() => dialogs.editListItem(row)}>
              <PencilIcon />
              {t('common.edit')}
            </DropdownMenuItem>
            {kind === 'media' && !isDone && row.startedAt === null && (
              <DropdownMenuItem onSelect={() => void setDone(true)}>
                <CheckIcon />
                {t('lists.finishShort')}
              </DropdownMenuItem>
            )}
            {kind === 'media' && !isDone && row.startedAt !== null && (
              <DropdownMenuItem onSelect={() => void lists.setStarted(row.uuid, false)}>{t('lists.notStarted')}</DropdownMenuItem>
            )}
            {onMove && (
              <>
                <DropdownMenuItem disabled={first === true} onSelect={() => onMove(-1)}>
                  <ArrowUpIcon />
                  {t('wishlist.up')}
                </DropdownMenuItem>
                <DropdownMenuItem disabled={last === true} onSelect={() => onMove(1)}>
                  <ArrowDownIcon />
                  {t('wishlist.down')}
                </DropdownMenuItem>
              </>
            )}
            {!seed && !isDone && (
              <DropdownMenuItem
                onSelect={() =>
                  dialogs.plantSeed({ title: row.title, type: row.mediaType === 'book' ? 'project' : 'todo', linkListItem: row.uuid })
                }
              >
                <SproutIcon />
                {t('lists.plant')}
              </DropdownMenuItem>
            )}
            {kind === 'media' && on.notes && (
              <DropdownMenuItem onSelect={() => void writeAbout()}>
                <NotebookPenIcon />
                {row.noteUuid ? t('lists.openNote') : t('lists.writeAbout')}
              </DropdownMenuItem>
            )}
            {/* Only to a list of the same kind (L2). */}
            {others.length > 0 && (
              <>
                <DropdownMenuSeparator />
                {others.map((other) => (
                  <DropdownMenuItem key={other.uuid} onSelect={() => void move(other)}>
                    {t('lists.moveTo', { name: listName(other, t) })}
                  </DropdownMenuItem>
                ))}
                <DropdownMenuSeparator />
              </>
            )}
            <DropdownMenuItem destructive onSelect={remove}>
              <Trash2Icon />
              {t('common.delete')}
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
      {(seed || (kind === 'media' && isDone)) && (
        <div className="flex flex-wrap items-center gap-x-3 gap-y-1 ps-6">
          {kind === 'media' && isDone && <Rating row={row} />}
          {seed && <SeedLine progress={seed} t={t} />}
          {/* The seed is done: offer to finish the item too, never do it for me. */}
          {seed?.complete && !isDone && (buyable || kind !== 'shopping') && (
            <Button variant="secondary" size="sm" onClick={() => void setDone(true)}>
              {t(`lists.finishToo.${kind}`)}
            </Button>
          )}
        </div>
      )}
    </li>
  );
}
