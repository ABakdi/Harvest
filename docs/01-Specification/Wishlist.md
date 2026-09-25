# Wishlist

A fourth tab in the Granary, before the checkpoint ([Phase-6][]:
`v3.0.0`). Two lists for the things I am not buying *yet*: the **buy
list** for what comes out of the wallet soon, and the **wishlist** for
what I want someday. Each item may carry an estimated price, so the
plan has a number on it.

## Why it belongs here

The Granary tracks money that has already moved: expenses, the wallet,
savings, debts. None of it looks forward. *I want a winter coat*, *I
should replace the kettle*, *one day an espresso machine* — these are
plans, and until now they lived loose in my head, next to the
expenses that were supposed to be paying for them.

A wishlist is the forward edge of the Granary: the money I *will*
spend, written down while deciding. The buy list answers *what do I
pick up soon?*; the wishlist answers *what am I working toward?*;
between them the shopping is planned instead of improvised.

## What it is, and firmly is not

**Is:** two lists. Each item has a title, an optional estimated price
with a currency, an optional note (why I want it), and an optional
planned purchase day. Items can be moved between the lists, reordered,
edited, marked bought, and deleted with the same soft-delete the rest
of the app uses. Each list shows what its open items would roughly come
to, so the plan adds up.

**Is not:** money. An estimated price is a plan, not a ledger line: it
pays no XP, changes no wallet, and never appears in the ledger or the
Summary sheet's totals. Buying an item just marks it bought; turning
the purchase into an expense stays an expense, typed in Expenses like
any other. Nothing here has a streak, a schedule, or a reminder.

## The shape

One table, `wishlist_items`, because the two lists are the same thing
in two moods (the way goals and goals' items are one table each).

| Field | What it is |
| :--- | :--- |
| `uuid` | the row's id |
| `list` | which list it sits in, `buy` or `wish` |
| `title` | what I want — "Winter coat", "Kettle", "Espresso machine" |
| `priceMinor` | estimated price in minor units, **optional** — some things have no number yet |
| `currency` | the estimate's currency (`DZD` · `USD` · `EUR`) |
| `note` | free text, optional — size, model, colour, *why* |
| `targetDay` | planned purchase Harvest Day, optional — mostly on the buy list |
| `boughtAt` | set when I mark it bought; bought items fold below the open ones |
| `position` | my order within one list |
| `createdAt` · `updatedAt` · `deletedAt` | the usual stamps; deletion is soft |

No second table: an item is not linked to an expense, a goal, or a
seed. The wishlist plans purchases; the rest of the app records them
(N1-style one step at a time).

## The lists

**Buy list** — day to day. What I actually intend to buy soon. It
carries the shop-ready detail: estimated price, target day, note with
the size or model. When I mark an item bought it drops to the bottom,
folded under the open ones, and still counts in the export like any
other row.

**Wishlist** — future planning. What I want someday, with at most an
estimate in mind. When I commit to one — the coat becomes "this
season" — I move it to the buy list, and only then does it carry a
target day. The lists share one card design; the wishlist just shows
fewer fields.

## The screen

The Granary gains a **Wishlist** tab (Today · Vault · Insights ·
**Wishlist**), and keeps its own add action — the granary's floating
button stays on Today, as it is now, so the tab carries its own.

Inside, two segments, **To buy** and **Wishlist**, like the vault's
sections. Each shows:

- the open items in my order — title, note when there's one, the
  estimated price in the item's currency, and the target day with days
  left when it has one;
- a small line under the list header with what the open items come to,
  summed per currency — amounts in different currencies are never
  added together ([[Finances]]);
- on the buy list only, **Bought**, folded below the open items, where
  an item lands when I mark it, with the Harvest Day it was bought on
  (3 AM boundary, as everywhere). The wishlist has no fold: a wish
  item that arrives bought — by sync or an import — stays in the open
  list, without a check, where it can still be moved or deleted.

Each row reads the title, then the target day and the note together
(*In 5 days · size M*), then the estimate.

Item interactions:

- **Add** — title, then estimated price (optional, parsed like every
  amount in the app, minus the keypad), currency pills, note, target
  day, and *which list* — the tab you add from is preselected.
- **Tap** — edit any of those.
- **Move** — a button takes the item to the other list, where it joins
  the bottom; its price, note and target day come along.
- **Buy** — a check on the buy list's items marks `boughtAt`; uncheck
  brings it back if the purchase fell through. The wishlist has no
  buy button — being wanted isn't being bought — so a wish item is
  only *moved* to the buy list, then bought there.
- **Reorder / delete** — the app's usual handles: drag or order
  buttons on the phone, arrow buttons on the web; swipe/soft delete
  with undo.

## Sync

`wishlist_items` is a **plain** table ([[Sync-Strategy]]): it syncs in
the clear with the rest of the app's day-to-day data, so the phone and
the browser stay in step like goals and notes do. An estimated price
is a plan, not a record of spend or location — it names no account,
no debt, no third party — so it does not need the private tier's
envelope. Expenditure, once it happens, still earns its encryption in
expenses and the money movements.

**Why no W5-style privilege:** the buy list is not a shopping list
with permissions — it is my own plan, edited by me on my own two
devices, and the passphrase already protects the only rows that reveal
where the money went.

## Export and import

`wishlist_items` owns a **Wishlist** sheet in the workbook, like every
table (rule X7): every column, bought and deleted rows included, and
the archive restores it on import. The Summary counts it with the
other sheets; the estimated prices are never summed into the Totals
section, because they are not money that moved.

## Rules

<!-- The letter picks up after the finances spec. -->

- **W1. Two lists, one table.** An item belongs to exactly one list
  (`list = buy | wish`), and the lists are two views of the same rows.
- **W2. An estimate is a plan, not a ledger line.** `priceMinor` is
  optional, per-currency, and never sums into the wallet, the budget,
  the ledger, the Summary totals, or any XP. It is a number on a card,
  and the only arithmetic it does is the per-list "open items come to"
  line, per currency.
- **W3. Buying marks it bought.** `boughtAt` is a stamp, not a
  transaction. Nothing else changes: no money row is written, no streak
  is touched. Expense logging stays in Expenses, where it belongs.
- **W4. Moving is a mood, not a copy.** Moving an item between the
  lists changes `list`, and carries price, note and target day. A moved
  item stays the same row, so its history follows; it takes the last
  place in the list it joins. Moving to the list it is already on does
  nothing.
- **W5. The target day is a plan, not a commitment.** No streak, no
  schedule, no reminder is built from it — the same judgement-free rule
  goals live by (GL1). It says *about when*, and edits freely.
- **W6. Deletion is soft, and history is kept.** Rows are
  soft-deleted, carried in export and sync, and purge with the rest of
  the app's deleted rows.
- **W7. The buy list is where things get bought.** Only buy-list items
  can be marked bought; a wish item moves first. "Bought" on the wish
  list would make the future tense into a lie.

## Out of scope

- **Price alerts / falling prices.** The estimated price is what I
  think it costs, typed by me; nothing watches shops.
- **Converting to an expense in one tap.** The buy list is day-to-day,
  so it *feels* like an obvious next step — but a purchase has a
  category, a wallet movement and a Harvest Day, and guessing them for
  you is exactly the kind of magic the app avoids. Mark it bought, then
  log the expense as usual (a future release may prefill the sheet).
- **Shared / gift lists, permissions, links.** One account, two
  devices, me.
- **Gamification.** No XP for wishful thinking — the whole point is
  that wanting is not doing.

[Phase-6]: ../03-Planning/Phase-6-Sync-Accounts-and-Web.md