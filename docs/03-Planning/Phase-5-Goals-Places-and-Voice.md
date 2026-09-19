# Phase 5 — Goals, Places & Voice

Specs: [[Goals]] · [[Places]] · [[Notes]] (voice, read aloud, assist) · [[ADR-010-Maps]] · [[ADR-013-Assist-Providers]]

The phone half of the round that began on 2026-09-19. Three features
that change what the app *remembers*, not only what it counts:
- **why** I do things: goals;
- **where** I did them: places;
- **what I said** when typing was too slow: voice.

They go before sync and the web ([[Phase-6-Sync-Accounts-and-Web]])
for one reason: their tables have to exist before the sync contract is
written, or the contract ships without them and is revised on day one.

```mermaid
flowchart LR
    A[M5.1 Schema v15 & the outbox] --> B[M5.2 Goals board]
    A --> C[M5.3 Places: trail & geotags]
    C --> D[M5.4 Places: the map]
    A --> E[M5.5 Voice notes & read aloud]
    E --> F[M5.6 Assist]
    B --> G[M5.7 Archive, docs & release]
    D --> G
    F --> G
```

## M5.1 — Schema v15, and an outbox that is really every write
- [ ] One migration, v14 → v15:
  - `goals`, `goal_items`, and `commitments.goal_uuid`;
  - `location_points`, `geotags` and `saved_places`;
  - `note_attachments`.
- [ ] Snapshot `drift_schemas/drift_schema_v15.json`; a generated
  migration test from every version.
- [ ] [[Audit-v2]] Q3-01 fixed first, because sync reads this table:
  - the ledger, `step_days`, `pomodoro_sessions`, `kv_settings`
    (allow-listed keys only) and the importer all call `logChange`;
  - the ADR's "pruned by a size cap" becomes true.
- [ ] `logChange` also writes a pending geotag for an insert into an
  action table while Places is on ([[Places]] PL2). The flag lives on
  the database object and is set by a provider from the setting.

## M5.2 — Goals board
- [ ] Repository: goals and items (create, edit, reorder, tick, soft
  delete with undo); achieve/reopen with +50 XP and its mirror row
  (GL4).
- [ ] The field gains **Today · Goals** tabs; the board with a progress
  ring, the next step and the seed chips.
- [ ] Goal screen: the *why*, **What it takes**, **Steps** and
  **Seeds**; drag to reorder; swipe to delete with undo.
- [ ] *Plant* an item → the seed editor, prefilled and linked. The seed
  editor gains **Serves: goal**.
- [ ] A planted to-do's check-in ticks its item, and undo un-ticks it
  (GL3), in the check-in service's own transaction.
- [ ] Tests: progress, achieve/reopen XP, the tick through check-in and
  undo, GL5 (archive a seed, the goal unchanged).

## M5.3 — Places: the trail and the geotags
- [ ] `geolocator` with the Android foreground-service configuration:
  - a permanent notification;
  - a 50 m distance filter, balanced power by default;
  - `FOREGROUND_SERVICE_LOCATION`, `ACCESS_BACKGROUND_LOCATION` and
    `RECEIVE_BOOT_COMPLETED` (resume after reboot).
- [ ] Permission flow in two steps (PL1), the feature switch, *pause*
  (1 h, until tomorrow, off).
- [ ] `TrailRecorder` writes points; `GeotagFiller` resolves pending
  geotags from the last point, then a fresh fix, else marks them
  unavailable (PL3).
- [ ] A `LocationGateway` interface with a fake, the same shape as
  `StepsSource`.
- [ ] Tests: the filler's three branches, the action-table list, a
  geotag written for each kind of insert, none when Places is off.

## M5.4 — Places: the map
- [ ] `maplibre_gl` with the OpenFreeMap style URL as a setting
  ([[ADR-010-Maps]]), and attribution always visible.
- [ ] Records gains **Places** as a third tab.
- [ ] Day view: the date strip, the trail line, pins per feature, and
  the timeline sheet (tap a row to fly to it, tap a pin to open it).
- [ ] Stays computed from points (PL5); naming a stay saves a place.
- [ ] Range view (week, month, custom), with clustering; filters by
  feature.
- [ ] *Delete this day's trail* (undo); *Delete all location history*
  (confirmed).
- [ ] Tests: stay detection, range queries, the pin list per day.

## M5.5 — Voice notes and read aloud
- [ ] `record` for AAC/m4a capture, `just_audio` for playback, and
  `note_attachments` rows.
- [ ] The editor's embed line `![[name.m4a]]` (N7) drawn as a player,
  still styled rather than rewritten (N5).
- [ ] *New voice note* on the Notes FAB; dictation with
  `speech_to_text` at the caret.
- [ ] Read aloud with `flutter_tts`: markdown stripped, the voice by
  script, the player sheet with speed.
- [ ] Export and archive: recordings beside their `.md`; the importer
  brings them back.
- [ ] Tests: the embed parse, the orphaned-recording sweep, the
  markdown-to-speech text.

## M5.6 — Assist
- [ ] The `AssistProvider` interface; `GeminiProvider` (streaming, key
  in a header); `OpenAiCompatibleProvider`.
- [ ] Settings → Assist: provider, key (secure storage), model, and
  *Test*.
- [ ] Note menu → Assist: the seven actions of [[Notes]], the sheet
  naming what is sent (N8), then Insert / Replace / Copy (N9).
- [ ] *Transcribe* on a recording, sending the audio inline to Gemini.
- [ ] Tests: the prompt templates, stream parsing for both providers
  against recorded responses, errors shown in plain words.

## M5.7 — Archive, docs, release
- [ ] Export sheets `Goals`, `GoalItems`, `LocationPoints`, `Geotags`,
  `SavedPlaces` and `NoteAttachments`; importer descriptors for each;
  [[ADR-006-Export-Format]] and [[ADR-007-Archive-Format]] updated.
- [ ] Onboarding's Extras page asks about Places, as it does for Notes
  and the Gym.
- [ ] Specs ticked, checkpoint written, `v2.1.0` tagged with an APK.

**Exit:** a week with the trail on, a goal planted into seeds, and a
voice note transcribed; `v2.1.0`.
