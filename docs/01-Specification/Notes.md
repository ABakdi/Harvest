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

- A plain text field, monospace optional, no live preview. Markdown is
  rendered when **reading**, edited as text.
- Supported when rendering: headings, bold, italic, lists, task lists,
  quotes, code, links, and `[[wiki links]]`. Anything else passes
  through as text rather than being silently eaten.
- **Autosave.** A note is saved as it is typed, debounced, the way the
  day notes already are. Nothing in this app should ever have a Save
  button that can be missed.

## Finding things

- Search across titles and bodies, matching as I type.
- Filter by folder.
- Sort by edited, created, or title.

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

## Rules

| # | Rule |
| :-- | :--- |
| N1 | Notes are off until switched on, and switching them off never deletes a file. |
| N2 | The body is the truth. The link index is derived and may be rebuilt from the bodies at any time. |
| N3 | A note exports as a `.md` file at its folder path, with the title as the filename. What comes out opens in any editor. |
| N4 | No feature may require Harvest to read the note back. If it cannot survive being edited in a text editor, it does not belong. |

Related: [[Gallery]] · [[ADR-007-Archive-Format]] · [[Core-Entities]]
