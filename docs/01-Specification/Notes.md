# Notes

Phase 3 module ([[Phase-3-Notes-and-Gallery]]). A small vault of
markdown files inside Harvest, with links between them.

## Why it belongs here

The app already knows what I did every day. It does not know what I
*thought* about any of it, and that is the half that turns a log into a
record worth keeping. Seeds already carry a note per Harvest Day
([[Productivity-Engine#Day notes Checkpoint-3|day notes]]); this is the
same instinct given room — pages that are mine to shape rather than
one line hung off a task.

## What it is, and firmly is not

**Is:** plain markdown files in folders, a link between any two of
them, and a search that reads the text.

**Is not:** Obsidian. No graph view, no canvas, no dataview, no
plugins, no live preview engine, no backlink panel with hover cards. If
a feature exists to make a note-taking app impressive rather than to
help me write a note, it is out.

The bar is: could I have written this in a text editor and lost
nothing? If yes, Harvest does not need to add it.

## Off by default

Notes are **not on** until I say so. Onboarding asks once — a plain
question with a plain default of no — and Settings has the switch
forever after ([[Onboarding]]). Someone who wants a streak tracker
should never have to walk past a notes tab to reach their field.

Turning it off hides the tab and stops the prompts. It does **not**
delete anything: the files stay, the export still carries them, and
turning it back on finds everything where it was.

## The shape

| Thing | What it is |
| :--- | :--- |
| **Note** | One markdown file: a title, a body, a folder, timestamps |
| **Folder** | A path, nothing more. Nested, created by naming one |
| **Link** | `[[Another note]]` in the body, resolved by title |
| **Backlink** | Which notes point here — a list, not a graph |

Links are stored as text in the body *and* indexed in a table, so
"what links here" is a query rather than a scan of every file. The text
stays the source of truth: edit the body, the index follows.

A link to a note that does not exist yet is **not an error**. It is a
note I have not written, shown differently, and tapping it offers to
create it. That is the one Obsidian behaviour worth copying outright,
because it is how notes actually get written.

## Writing

- **One mode.** The body renders as markdown and shows its syntax on
  whichever line the caret is on — the Obsidian behaviour, and the
  right one: a note with a Read button and an Edit button is two
  documents that happen to share a body ([[Checkpoint-5]]).
- Nothing is ever removed from the stored string to achieve that. Every
  marker stays a character at its own offset, drawn at a hair's width
  when folded, so the caret and the selection need no translation.
- A **bar above the keyboard** carries the syntax worth one tap:
  heading, bold, italic, code, list, task, quote, wiki link, table —
  and add-a-row and add-a-column while the caret is in a table.
- Supported when rendering: headings, bold, italic, lists, task lists,
  quotes, code, links, and `[[wiki links]]`. Anything else passes
  through as text rather than being silently eaten.
- **Autosave.** A note is saved as it is typed, debounced, the way the
  day notes already are. Nothing in this app should ever have a Save
  button that can be missed.

## Finding things

All of it in a **sidebar**, never in the middle of the screen — that
space is for one note ([[Checkpoint-5]]).

- Search across titles and bodies, matching as I type.
- A folder tree, with a new note at any level.
- Sort by edited, created, or title.
- The **trash**: deleting a note is undoable, and emptying the trash is
  the step that is not.

A folder may exist before it holds a note. The truth about where a note
lives is still the note's own path; the empty ones are remembered in
settings, which means they ride in the archive for free.

Nothing cleverer. When the vault is big enough to need more than that,
it is big enough to live in Obsidian.

## The Obsidian question

The export is a folder of `.md` files in the folder structure they
already have ([[ADR-007-Archive-Format]]), which means **the exported
notes are an Obsidian vault**. That is not a coincidence and not an
accident of format: the point is that this feature can never trap
anything.

A plugin that reads a Harvest export from inside an Obsidian vault is a
plausible future thing to build, and it needs nothing from this app
that the export does not already give it.

## Voice, reading aloud, and the assist

*Added for [[Phase-5-Goals-Places-and-Voice]].* Three things that
leave the page as plain markdown and the vault as plain files, so N4
still holds.

### Voice notes

Some thoughts come while walking, driving or holding something, when
typing is impossible or slow. So a note can hold **recordings**:
- **Record** is on the editor's toolbar, the microphone. A tap starts
  recording, the bar shows the time and a level, and a second tap
  stops.
- **What is written into the body** is an embed on its own line, in
  Obsidian's own syntax: `![[Voice 2026-09-19 14-32.m4a]]`. The editor
  draws it as a player (play/pause, a scrubber, the length). In any
  other editor it is a line of text naming a file that sits beside the
  note in the export.
- **The file** is AAC in an `.m4a` container, mono, 64 kbps: about
  half a megabyte a minute. It lives under the app's own storage and is
  a row in `note_attachments` (note, file name, kind, length, size).
- **A voice note from the FAB.** *New voice note* on the Notes list
  creates a note titled with the time, starts recording at once, and
  stops on a tap. It is the three-second path.
- **Dictation** is separate from recording. The toolbar's second mic
  mode turns speech into text at the caret, live, using the phone's own
  on-device recogniser. No audio is kept.
- **Transcribe**, on a recording's menu, sends the audio to the assist
  (below). The text is inserted under the player as a quote, and the
  audio stays.
- **Deleting the embed line never deletes the file.** A recording no
  body mentions any more goes to the trash with its note's next save,
  and is purged with the trash, like everything else.

### Read aloud

**Read aloud**, in the note's menu, reads the note with the phone's
text-to-speech engine:
- It reads the text as rendered: markdown syntax, link brackets and
  embeds are skipped.
- The voice follows the note's script: Arabic text is read in Arabic,
  and the rest in the app's language.
- A small player sheet has play/pause, stop, skip paragraph, and speed
  (0.75×–2×). It keeps reading with the screen off, and stops on a call.

### Assist

A language model can help with a note, **only when asked**
([[ADR-013-Assist-Providers]]):

| Action | Sends | Returns |
| :--- | :--- | :--- |
| Summarise | the note | a short summary, to insert at the top or copy |
| Rewrite clearer | the selection, or the note | the same meaning in plainer words |
| Continue | the text up to the caret | a paragraph in my own voice |
| Fix spelling and grammar | the selection, or the note | the text corrected, nothing else changed |
| Translate | the selection, or the note | English ↔ Arabic |
| Ask | the note, and my question | an answer drawn from the note only |
| Transcribe | one recording | its text |

Every action opens a sheet that names what will be sent and to which
provider. The answer streams into that sheet. **Insert**, **Replace**
and **Copy** are the only ways it reaches the note. Without a key or
an account, the assist entry says what it needs and links to Settings
→ Assist.

## Rules

| # | Rule |
| :-- | :--- |
| N1 | Notes are off until switched on, and switching them off never deletes a file. |
| N2 | The body is the truth. The link index is derived and may be rebuilt from the bodies at any time. |
| N3 | A note exports as a `.md` file at its folder path, with the title as the filename. What comes out opens in any editor. |
| N4 | No feature may require Harvest to read the note back. If it cannot survive being edited in a text editor, it does not belong. |
| N5 | The editor draws markdown by styling it, never by rewriting it. What is rendered and what is stored are the same string, character for character. |
| N6 | Under the Records tab the tab row stays whether a note is open or not; an open note shows its folder under the title ([[Checkpoint-8]]). |
| N7 | A recording is a file beside the note and an Obsidian embed line in its body, `![[name.m4a]]`. The export writes the file next to the `.md`, so the pair opens anywhere. |
| N8 | Nothing in a note is sent anywhere without a tap on an assist action that names what it sends and to whom. There is no background assist and no indexing. |
| N9 | The assist proposes; I dispose. Its answer changes a note only through Insert or Replace. |
| N10 | Read aloud and dictation use the phone's own engines. Only Transcribe and the assist actions ever send audio or text off the device. |

A note also goes out as a **PDF**, rendered rather than dumped, through
the system share sheet.

Related: [[Gallery]] · [[ADR-007-Archive-Format]] · [[Core-Entities]] · [[Checkpoint-5]]
