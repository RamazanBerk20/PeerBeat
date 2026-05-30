# PeerBeat — Data Model

Storage engine: **SQLite** (bundled with `rusqlite`), one database file in the
app-private data directory, **WAL** journal mode. All persistent state lives here
except large binaries (album art, audio), which are referenced by path/hash.

> Privacy: every column below is stored **locally only**. Nothing here is uploaded
> anywhere; the only data that leaves the device is what a peer explicitly streams
> or downloads over the LAN. See [`privacy.md`](privacy.md).

## Conventions

- All ids are `INTEGER PRIMARY KEY` row-ids unless noted.
- Times are integer Unix epoch **milliseconds** (UTC).
- `content_hash` is `xxh3_64(first 64 KiB ‖ last 64 KiB ‖ file_size)` rendered
  hex — a stable, cheap identity used for dedup, move-detection, and as the
  **cross-peer track id** for LAN download/party matching.

## Core tables

### `tracks`
| column | type | notes |
|--------|------|-------|
| id | INTEGER PK | |
| path | TEXT | raw absolute path |
| normalized_path | TEXT UNIQUE | platform-folded (forward slashes; case-folded on Windows) |
| content_hash | TEXT | xxh3 identity; indexed |
| title | TEXT | |
| album_id | INTEGER FK→albums | nullable |
| track_no, disc_no | INTEGER | nullable |
| year | INTEGER | nullable; indexed |
| duration_ms | INTEGER | |
| codec | TEXT | `mp3`/`flac`/`wav`/`aac`/`ogg`/`m4a` |
| bitrate, sample_rate, channels | INTEGER | |
| replaygain_track_db, replaygain_album_db | REAL | nullable (from tags) |
| rating | INTEGER | 0–5, default 0 |
| played_count | INTEGER | default 0 |
| last_played_at | INTEGER | nullable |
| added_at | INTEGER | |
| file_size | INTEGER | |
| mtime_ns | INTEGER | for the `(size, mtime)` change gate |
| has_lyrics | INTEGER | 0/1 (embedded or sidecar `.lrc` found) |

Indexes: `content_hash`, `album_id`, `year`, `added_at`, `last_played_at`,
`played_count`.

### `albums`, `artists`, `genres`
`albums(id, title, album_artist_id, year, art_id FK→art_cache, sort_title)` ·
`artists(id, name, sort_name)` · `genres(id, name)`.

### Multi-value joins
Tracks can have several artists/genres ("feat."), so these are join tables, not
columns:
- `track_artists(track_id, artist_id, role)` — `role` ∈ {main, feat, composer, …}
- `track_genres(track_id, genre_id)`

This makes Artist/Genre browsing correct instead of guessing a single primary.

### `art_cache`
| column | type | notes |
|--------|------|-------|
| id | INTEGER PK | |
| image_hash | TEXT UNIQUE | content hash of the image bytes |
| file_path | TEXT | on-disk cached image (not stored in the DB) |
| width, height, mime | | |

Album art is **deduplicated by image hash** and stored on disk, never inline in
`tracks` — keeping row reads fast for 50k+ libraries. A generated placeholder /
palette swatch is used when absent.

### `folders` + `scan_state`
`folders(id, path, is_watched, added_at)` — the user's library roots.
`scan_state(folder_id, last_full_scan_at, last_incremental_at, file_count)`.

## Playlists & queue

- `playlists(id, name, created_at, updated_at, sort_order)`
- `playlist_items(playlist_id, track_id, position)` — ordered; reorder = update
  `position`.
- `queue(id, track_id, position, source)` — the live play queue; `source` marks
  Play-Next vs Add-to-Queue vs from-list.
- `smart_playlists(id, name, rule_json, sort_json, limit_n, updated_at)` — see
  below.
- `favorites(track_id, added_at)`; `play_history(id, track_id, played_at, ms_played)`.

`play_history` is an **event log** (not just a counter) so windowed smart rules
like "played in the last 30 days" and accurate Most/Recently-Played are possible.
`played_count` / `last_played_at` on `tracks` are denormalised roll-ups.

### Smart playlists

`rule_json` is a **versioned rule tree**, compiled to parameterised SQL by an
injection-safe compiler (whitelisted columns + operators; every value bound):

```json
{
  "version": 1,
  "match": "all",                       // all = AND, any = OR
  "rules": [
    { "field": "played_count", "op": ">",  "value": 10 },
    { "field": "rating",       "op": ">=", "value": 4 },
    { "match": "any", "rules": [
      { "field": "genre", "op": "is", "value": "Jazz" },
      { "field": "genre", "op": "is", "value": "Blues" }
    ]}
  ]
}
```

Allowed `field`s map to whitelisted columns/joins; allowed `op`s:
`is, is_not, contains, starts_with, >, >=, <, <=, between, in_last_days, is_true`.
Unknown fields/ops are rejected at parse time. The four **auto-lists** (Recently
Played, Most Played, Never Played, Favorites) are pre-baked rule trees, not
special-cased code.

## Network tables

- `known_hosts(id, host_id, display_name, color, spki_sha256, first_seen_at,
  last_seen_at)` — **TOFU pins**: the SHA-256 of the peer's certificate SPKI.
- `remembered_peers(host_id, peer_id, decision, decided_at)` — Approved-mode
  allow/deny memory.
- `shares(id, playlist_id, permission, mode, pin_hash, enabled)` — what *this*
  host shares; `permission` ∈ {stream, stream_download}; `mode` ∈ {open, pin,
  approved}.
- `transfer_log(id, peer_id, track_id, kind, bytes, started_at, ended_at,
  state)` — the host's safety/audit dashboard feed (`kind` ∈ {stream, download}).

## Full-text search

A contentless-external FTS5 virtual table indexes a denormalised search column
(title ‖ artists ‖ album ‖ album-artist ‖ genre ‖ year) using the **trigram**
tokenizer with **bm25** ranking — giving substring + typo-tolerant matching that
`unicode61` cannot. Triggers keep it in sync on insert/update/delete; all writes
go through the DAO layer so triggers always fire. Queries < 3 chars (trigram's
minimum) fall back to a folded-ASCII `LIKE` scan with `LIMIT`. A maintenance
command rebuilds the index (`INSERT INTO fts(fts) VALUES('rebuild')`).

## Performance (50k+ tracks < 2 s)

- DB on a dedicated worker thread; UI never blocks on SQL.
- **Two-pass scan**: pass 1 inserts path + basic tags (library browsable almost
  immediately); pass 2 extracts art + computes hashes lazily.
- Batched transactions (~500 rows); `(size, mtime)` gate skips unchanged files so
  rescans are near-instant.
- Browse/search queries are paginated and streamed to a virtualised list.

## Migrations

`user_version`-based linear migrations in `db/schema`. M1 ships v1 (core +
playlists + FTS); M2 adds the network tables and the smart-playlist columns.
