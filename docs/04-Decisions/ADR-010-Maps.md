# ADR-010 — Maps are MapLibre on OpenFreeMap, never Google

**Status:** Accepted · 2026-09-19 · [[Places]] · [[Phase-5-Goals-Places-and-Voice]]

## Context

[[Places]] draws where I have been on a map, and pins on it everything
I did there. That needs map tiles and a renderer, on Android and in
the browser.

The requirement is short: **free, open source, no Google, no API key
that can be revoked or billed.** A map of my own movements is the most
personal screen in the app. I do not want it to depend on an account
at an advertising company, or on a quota that ends with a bill.

## Options

| Option | Cost | Key | Open | Notes |
| :--- | :--- | :--- | :--- | :--- |
| Google Maps SDK | Free tier, then billed | Yes | No | Ruled out by the requirement |
| Mapbox | Free tier, then billed | Yes | Renderer is no longer open source (v2+) | Ruled out |
| `tile.openstreetmap.org` raster | Free | No | Yes | Its usage policy forbids heavy use by apps. It is a community server, not a CDN |
| **OpenFreeMap** vector tiles | **Free, no limits** | **No** | **Yes** (OSM data, open stack) | Run as a public service; self-hostable if it ever goes away |
| Self-hosted Protomaps | Hosting only | No | Yes | The fallback: one PMTiles file on any static host |

## Decision

- **Renderer: MapLibre.** `maplibre_gl` on Flutter and `maplibre-gl`
  on the web. It is the open-source fork of Mapbox GL, has the same
  style specification on both platforms, and draws vector tiles, so
  one style looks the same everywhere.
- **Tiles: OpenFreeMap**, the `liberty` style
  (`https://tiles.openfreemap.org/styles/liberty`). There is no key and
  no account, and the data is OpenStreetMap.
- **The style URL is one setting**, `places.styleUrl`, with that
  default. If OpenFreeMap ever changes its terms, I point it at a
  self-hosted Protomaps file and nothing else changes.
- **Attribution** to OpenStreetMap contributors and OpenFreeMap is
  always shown, as the licence requires.
- **No geocoding service in v1.** Places are shown as coordinates and
  as "stays" computed on the phone ([[Places]] PL5). Naming a place is
  something I do by hand. If I add reverse geocoding later, it will be
  an open service (Photon or Nominatim) called with care, never a
  background job that sends my whole trail away.

## Consequences

- Viewing the map needs a connection for tiles. The trail and the
  pins are local, so they are still listed without one.
- Tiles are fetched from a third party. They learn *which areas of the
  map I look at*, not my trail: the trail is drawn on the phone and
  never sent. That leak is the same one any map app has, and it is
  written down here so the privacy tier in [[Sync-Strategy]] stays
  honest.

Related: [[Places]] · [[ADR-012-Web-Client]]
