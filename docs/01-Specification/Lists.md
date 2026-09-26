# Lists

One place for every list I keep: what to buy, what I want someday,
what to read, what to watch, and whatever list I think of next. It
grew out of the [[Wishlist]], which was two lists in the Granary;
the moment I wanted a third — articles, books and shows to get to
later — it was clear the app should not grow a screen per list.
([[Phase-6-Sync-Accounts-and-Web]] M6.12.)

## Why it belongs here, and what it is not

The app already records what I *did*. Lists hold what I have not got
to yet: the kettle to replace, the book everyone mentions, the talk
someone sent me. Writing them down while I think of them is the whole
job, so saving has to take two seconds — including from another app.

**Is:** lists of items I tick off, each list of one *kind* that decides
which fields its items carry.

**Is not:** a to-do list. Something with a day, a streak or a reminder
is a seed, and the field is where seeds live. A list item can *become*
a seed (below), and then the seed carries the doing. Checklists inside
a note stay in the note: they are part of the writing.

## Kinds

A list is data, not code: I can make as many as I like, and a new list
is a row, not a screen.

| Kind | For | What an item carries | Done means |
| :--- | :--- | :--- | :--- |
| **Plain** | ideas, packing, someday | title, note | ticked |
| **Shopping** | to buy, wishlist | title, note, estimated price and currency, planned day | bought |
| **Media** | to read, to watch, to listen | title, type (book · article · show · film · video · podcast · other), link, author or creator, note | finished, with an optional rating |

A media item moves *want → in progress → finished*. Starting it stamps
when; finishing stamps when and may take a rating (1–5). A plain or
shopping item is open or done.

## The built-in lists

On first use, and on upgrade, four lists exist: **To buy** and
**Wishlist** (shopping) — the Wishlist's two lists, with their items —
and **To read** and **To watch** (media). They can be renamed,
reordered or emptied, not deleted; any list I make can be. The shopping
pair keeps every Wishlist rule below.

## Where it lives

**Records** gains a tab: *Notes · Lists · Gallery · Places* — Lists
second, beside the notes, because it is the one I open most after them.
Records already holds the things measurement does not reach, so no new
bottom tab. Lists has its feature switch like the other three.

Inside: the lists as a row of chips (each with its open count), the
chosen list below, its open items in my order, and what is done folded
underneath. A list's menu renames, reorders, or deletes it.

The Granary no longer has a Wishlist tab. It keeps one line on its
first tab — *Planned purchases · DA18,850* — that opens *To buy*; the
money stays in the Granary, the lists in one place. The line sums, per
currency, the open estimates of every shopping list except the
Wishlist: someday is not a purchase that is planned.

## Saving from anywhere

- **Share to Harvest** (Android). *Share* from a browser, YouTube or any
  app offers Harvest; a link lands in **To read** — or **To watch** for a
  video site — with the shared title, and a sheet lets me change the
  list or the title before it saves. A link inside a sentence is found,
  and the rest of the sentence is the title. Text without a link goes to
  the first plain list I made, or the sheet asks. A link saved to a list
  that keeps no link goes into the note. Saving from a share turns Lists
  on if it was off, so what I saved is never out of sight.
- **Which list a link belongs in** is one rule both clients share: only
  the host decides, and the video sites are YouTube, Vimeo, Dailymotion,
  Twitch and TikTok (`packages/core` `classifyLink`, pinned by
  `fixtures/share-links.json`).
- **The web**: pasting a link into a list's add field fills the link
  and uses what was pasted as the title until I type one.
- **No previews.** The title is what I typed or what the other app
  shared. Saving a link sends nothing anywhere ([[Business-Rules]] #13);
  opening it is a tap of mine.

## Tied into the rest of the app

- **Plant as a seed**, as a goal's items do ([[Goals]]): a book becomes a
  project ("300 pages, 10 a day"), anything else a to-do. The item and
  the seed stay linked; the item shows the seed's progress, and a seed
  that is done — a project at its total, a to-do ticked, or any seed
  archived — offers to mark the item finished.
- **Bought opens the expense sheet**, prefilled with the item's title as
  the note, its estimate as the amount and *Shopping* as the category —
  a suggestion, typed over or dismissed; nothing is logged without me
  ([[Finances]]).
- **Write about it**: a media item opens a note named after it, linked
  to it, for reading notes and quotes ([[Notes]]).

## Sync and export

`lists` and `wishlist_items` are **plain** tables ([[Sync-Strategy]]):
nothing in them is money that moved or a place I was. The item table
keeps its name, `wishlist_items`, so beta devices and archives already
out there keep working; the app calls it Lists everywhere. Its old
`list` column is still written — `buy` for *To buy*, `wish` for every
other list — so a beta client reading it files the item somewhere
sensible; the truth is `listUuid`. The built-in
lists have fixed ids, so two devices upgrading on their own do not make
two *To read*s. The archive carries a **Lists** sheet and the item
columns in the **Wishlist** sheet ([[ADR-007-Archive-Format]]).

## Rules

| # | Rule |
| :-- | :--- |
| L1 | One place for lists. A new list is a row in `lists`, never a new screen or table. |
| L2 | A list's kind decides its items' fields; an item belongs to exactly one list and moves between lists of the same kind as the same row. |
| L3 | An estimate is a plan, not a ledger line (was W2): it never sums into the wallet, the budget, the ledger, the Summary or XP; the *Planned purchases* line sums per currency. |
| L4 | Done is a stamp, not a transaction (W3): buying, finishing or ticking writes no money row and moves no streak. Bought *offers* an expense; it never logs one. |
| L5 | A planned day is a plan (W5): no streak, no schedule, no reminder is built from it. |
| L6 | Deletion is soft and history is kept (W6); a deleted list takes its items to the trash with it, and restoring it brings them back. |
| L7 | Only a shopping list's items are bought; a wish is moved to *To buy* first (W7). |
| L8 | Adding, finishing or rating pays nothing: wanting is not doing. A planted seed pays as any seed does. |
| L9 | Saving a link fetches nothing. |
| L10 | The built-in lists have fixed ids and cannot be deleted. |

Related: [[Wishlist]] · [[Finances]] · [[Goals]] · [[Notes]] · [[Web]]
