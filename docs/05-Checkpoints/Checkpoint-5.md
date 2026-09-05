# Checkpoint 5 — Records, and an editor worth writing in

Eight complaints after living with [[Phase-3-Notes-and-Gallery]] on the
phone for a day. Most of them are the same complaint twice: the two new
features were *built* but not *finished*, and the difference showed the
moment I tried to use them rather than test them.

## 1. Notes and the Gallery share one tab

**The complaint:** the bottom bar was crowded, and the two belong
together — one keeps a record in text, the other in pictures.

Both now live behind one **Records** tab, with the app's own segmented
button switching between them. The bar is back to five, and the switch
disappears entirely when only one of the two is turned on, because
there is then nothing to switch between.

The route `/records` replaces `/notes` and `/gallery`; a note still has
its own path (`/records/note/:uuid`) so a link or a reminder can open
one directly.

**The bar also hides itself while the keyboard is up.** That started as
a fix for the editor toolbar having nowhere to sit, and it is simply
better: nothing about navigation is useful while typing.

## 2. The sidebar

**The complaint:** folders and the note list were in the middle of the
screen. That space is for reading and writing.

Notes now open with a drawer holding the whole vault: search, sort, the
folder tree, a **New note** at every level, and the trash at the foot.
Folders can be made, renamed and deleted from it, and deleting one
moves its notes to the trash rather than destroying them.

A folder is still "a path, nothing more" ([[Notes]]) — the truth about
where a note lives is its own `folder` column. What the sidebar adds is
a memory of folders that have no note in them *yet*, kept in
`kv_settings` under `notes.folders`, which means it rides in the
archive for free and a folder is not worth a table.

## 3. One mode, not two

**The complaint:** Read and Edit were separate. I want what Obsidian
does — the rendered page, showing its syntax on the line the caret is
on.

The Read/Edit toggle is gone. `LiveMarkdownController` styles the body
in place: `**bold**` is drawn bold with the asterisks folded to a hair's
width, and the moment the caret lands on that line they come back to be
edited like the text they are.

**The rule that makes it work:** nothing is ever removed from the
string. Every marker is still a character at its own offset, drawn
invisibly. Selection, undo and the caret need no translation between
what is stored and what is shown — which is exactly where an editor
like this usually goes wrong, and where this one did:

- The first version dropped the **last line** of every note, because a
  loop appended a newline span between lines and then removed one span
  too many. The field rendered one string while editing another, so
  keystrokes vanished and the keyboard looked broken.
- The second version drew task checkboxes as a `WidgetSpan`, which
  costs one placeholder character. Same class of bug, subtler. The
  checkbox is now a tinted `[x]` and a struck-through line.

Both are now held down by a test that asserts, for every shape of line
and every caret position, that the drawn spans rebuild the body
exactly.

## 4. A bar on the keyboard

Heading (cycling H1→H2→H3→off), bold, italic, code, list, task, quote,
wiki link and table — and **+ Row** and **+ Col**, which appear only
when the caret is actually inside a table.

The edits are pure functions from `(text, selection)` to
`(text, selection)`, tested as such, because "make this bold" is fiddly
in ways a widget test would never catch.

Two bugs the phone found that the tests had not:
- The toolbar edits the body through the controller, and a controller
  set programmatically never calls `onChanged` — so every table and
  every bold the bar inserted was **lost on the way out**. Autosave now
  hangs off the controller, not the field.
- Adding a column filled the empty rows with dashes, because the
  "is this the divider line?" test matched `|  |  |`. A divider has to
  contain a dash.

## 5. A trash for notes

Delete moves a note to the trash with an undo. The trash lists what is
in it, restores one at a time, deletes one for good, or empties the
lot — and says, before it does, that there is nothing behind that.

## 6. Notes as PDF

The markdown is rendered rather than dumped: a PDF with the asterisks
still in it is a text file with a worse extension. It goes out through
the system share sheet, so print, mail and Drive all come free.

## 7. The gallery gets the same, and a way out

Deleting a picture or an album moves it to the trash; **emptying the
trash is what deletes the file**. Restoring a picture pays its day
again, exactly as removing it took the day back.

And one door out of the app: **share**, per picture, from the viewer.
The gallery still keeps its files to itself (rule G2) — this is a door
I have to open by hand, one picture at a time.

> **[[Gallery]] rule G5 is revised.** It said deleting a memory deletes
> the file "immediately and for good". The promise stands, but a photo
> deleted by a fat thumb was gone for good too. It now takes two
> deliberate steps to get there.

Schema v11 adds `memories.deleted_at`, and the archive carries it — an
import must not quietly resurrect what I threw away.

## 8. The look

The album list leads with the last picture at a size worth looking at,
because that *is* the album; the name is a label on it. The scrim sits
only under the text rather than over the whole photo. The viewer runs
full screen over the app's own bar, and its title is legible on black.
The Records switch is the app's segmented button rather than something
new, which is the whole of the brief: better, without becoming a
different app.

## What the phone caught that the tests did not

Four defects, all in the same family — **the widget tree changing shape
underneath a focused field**:

1. Hiding the navigation bar by returning a different widget instead of
   a `Scaffold` remounted the whole subtree; the field lost focus and
   the keyboard shut the instant it opened.
2. Same for the Records switch: it is now always in the tree, as an
   empty box when hidden, so the screen above it keeps its place.
3. `Scaffold` swallows the keyboard inset before the screen underneath
   can see it, so "is the keyboard up?" could not be asked from inside
   the editor at all. The toolbar now follows the body's **focus**,
   which is what it actually means.
4. Filling the controller during `build` notified a listener that
   called `setState` — a rebuild every frame, which starves the app
   quietly enough to look like a snack bar that never goes away.

And one that was not ours: a dialog's `TextEditingController` disposed
the moment `await showDialog` returned, while its route was still
animating out. `promptForText` now owns it.

## Rules touched

| Spec | Change |
| :--- | :--- |
| [[Gallery]] G5 | Deleting is a trash; emptying it is what deletes the file. |
| [[Notes]] | No Read/Edit modes: one live view. Folders may exist before they hold a note. |

Related: [[Checkpoint-4]] · [[Notes]] · [[Gallery]] · [[Phase-3-Notes-and-Gallery]]
