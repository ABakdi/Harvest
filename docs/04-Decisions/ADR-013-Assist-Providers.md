# ADR-013 — Writing assist behind one interface: my own key first, the server later

**Status:** Accepted · 2026-09-19 · [[Notes]] · [[Phase-5-Goals-Places-and-Voice]]

## Context

[[Notes]] gains an assist: summarise a note, rewrite a paragraph,
continue a thought, fix the grammar, translate between English and
Arabic, answer a question about what I wrote, and transcribe a voice
note. All of it needs a language model, and a model needs a provider.

Two routes will exist:
1. **My own API key**, pasted in Settings. The phone calls the
   provider directly, and it works without any Harvest server. This is
   how it will mostly be used, with Gemini.
2. **A server default.** The Harvest server holds a key and relays
   requests for signed-in accounts. It comes with
   [[Phase-6-Sync-Accounts-and-Web]].

## Decision

- **One interface, `AssistProvider`**, with one call: a list of
  messages plus optional inline audio, streamed back as text. Every
  action in the app is a prompt template over that call. No screen
  knows which provider answered.
- **The prompts are a rule, not a screen.** They live in
  `packages/core` and are pinned by `fixtures/assist.json`, which both
  the TypeScript and the Dart tests read: the same button must ask the
  same thing of the same model on either device.
- **Providers:**
  - `GeminiProvider`: `streamGenerateContent` on the Generative
    Language API, with the key sent in the `x-goog-api-key` header,
    never in the URL. The default model is `gemini-2.5-flash`, and
    the model is a setting. Gemini takes audio inline, which is what
    makes **Transcribe** possible without a second service.
  - `OpenAiCompatibleProvider`: any `/v1/chat/completions` endpoint
    (OpenAI, OpenRouter, a local Ollama). It is the same few lines, and
    it keeps the interface honest.
  - `HarvestServerProvider`: `POST /v1/assist` on the Harvest server,
    which lends its own key to a signed-in, verified account and counts
    the requests per account per UTC day. My own key still wins where
    it is set. On the **web** it is the only provider, because a key
    pasted into a browser is a key in everyone's browser.
- **The key** lives in Android Keystore-backed secure storage, never
  in `kv_settings`. It is never exported, never archived and never
  synced.
- **Nothing is sent without a tap.** Every action opens a sheet that
  says what will be sent (this note, this selection, this recording)
  and to whom (the provider's name). There is no background assist, no
  "smart" suggestion while I type, and no indexing of the vault.
- **Answers are proposals.** The sheet shows the result with
  *Insert*, *Replace* and *Copy*. Nothing in a note changes until I
  choose.

## Consequences

- With neither a key nor an account, the assist is simply absent: the
  menu entry explains what it needs and links to Settings. Nothing
  else in [[Notes]] changes.
- Provider errors (a bad key, a quota, no connection) are shown in the
  sheet in plain words. They never become an exception on the note.
- The note text leaves the phone when I ask it to. [[Notes]] N8 says
  so, and so does the privacy page.

Related: [[Notes]] · [[ADR-011-Backend]]
