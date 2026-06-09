# PeerBeat — Data Model

All persistent state is local **SQLite** (one file per install), created and
migrated by `rust/peerbeat_core/src/db/schema.rs`. There are no remote
databases and no accounts. Times are Unix epoch **milliseconds** unless noted.

## Migrations

The schema is versioned with SQLite's `PRAGMA user_version`. `migrate()` applies
the `V1` batch on a fresh database and bumps the version; future changes append
`V2`, `V3`, … rather than mutating `V1`. Current `SCHEMA_VERSION = 1`.

## Library

| Table | Purpose / key columns |
|-------|----------------------|
| `artists` | `id`, `name` (unique), `sort_name`. |
| `genres` | `id`, `name` (unique). |
| `albums` | `id`, `title`, `album_artist_id → artists`, `year`, `art_id → art_cache`; unique `(title, album_artist_id)`. |
| `art_cache` | Deduplicated cover art by `image_hash` (unique); `file_path` on disk, plus `width/height/mime`. |
| `tracks` | The core row. `normalized_path` (unique) identifies a file; `content_hash` enables move-detection; audio facts (`duration_ms`, `codec`, `bitrate`, `sample_rate`, `channels`); `replaygain_track_db`/`replaygain_album_db`; user state (`rating`, `played_count`, `last_played_at`); `added_at`, `file_size`, `mtime_ns` (incremental scan); `has_lyrics`. |
| `track_artists` | Many-to-many `track ↔ artist` with a `role` (`main`, …). |
| `track_genres` | Many-to-many `track ↔ genre`. |

Indices on `tracks`: `album_id`, `content_hash`, `year`, `added_at`,
`played_count`, `last_played_at` — the columns the browse axes and smart-playlist
rules sort/filter on.

## Watch-folders + scan state

| Table | Purpose |
|-------|---------|
| `folders` | A library root: `path` (unique), `is_watched`, `added_at`. |
| `scan_state` | Per-folder `last_full_scan_at`, `last_incremental_at`, `file_count`. |

Scanning is incremental: a file is re-read only when its `mtime_ns`/`file_size`
changed. A filesystem watcher (the `notify` crate) debounces events ~800 ms and
rescans+prunes the affected root.

## Playlists, queue, history, favorites

| Table | Purpose |
|-------|---------|
| `playlists` | Manual playlists: `name`, `created_at`, `updated_at`, `sort_order`. |
| `playlist_items` | Ordered membership, PK `(playlist_id, position)`; cascades on track/playlist delete. |
| `smart_playlists` | Rule-based: `rule_json` (the rule tree), optional `sort_json`, `limit_n`. Rules compile to **parameterized** SQL against a field whitelist (`db/smart.rs`). |
| `queue` | Persisted play queue: `track_id`, `position`, `source` (`list`/`next`/…). |
| `favorites` | `track_id` (PK) + `added_at`. Drives the Favorites auto-list. |
| `play_history` | One row per play: `track_id`, `played_at`, `ms_played`. Drives Recently/Most/Never-Played. |
| `eq_presets` | Named 10-band EQ presets: `bands` (JSON of 10 dB gains), `preamp`, `builtin` flag. |
| `settings` | Key/value store for app preferences and the resume bookmark (last `track_id` + `position_ms`, volume, EQ, theme, etc.). |

## Search

`tracks_fts` is an **FTS5** virtual table (`title, artist, album, genre`) with a
**trigram** tokenizer, maintained programmatically by the track DAO
(`rowid == tracks.id`). Queries ≥3 chars use trigram + `bm25` ranking; shorter
queries fall back to a `LIKE` prefix match (with escaped patterns). It stores its
own copy of the join-derived artist/genre text for correctness.

## LAN / network

| Table | Purpose |
|-------|---------|
| `known_hosts` | TOFU trust store: `host_id` (unique), `display_name`, `color`, `spki_sha256` (the pinned certificate digest), `first_seen_at`, `last_seen_at`. |
| `remembered_peers` | Per-host approved-peer decisions: PK `(host_id, peer_id)`, `decision` (`allow`/`deny`), `decided_at`. |
| `shares` | What this host exposes: `playlist_id` (`NULL` = whole library), `permission` (`stream`/`stream_download`), `mode` (`open`/`pin`/`approved`), `pin_hash` (Argon2id PHC string, never the PIN), `enabled`. |
| `transfer_log` | Host visibility into activity: `peer_id`, `track_id`, `kind` (`stream`/`download`), `bytes`, `started_at`, `ended_at`, `state`. Powers the host's "who's streaming what" dashboard + revoke. |

## What is **not** stored

No cloud identifiers, no analytics/telemetry, no third-party service tokens, no
listener accounts. PINs are stored only as Argon2id hashes; LAN session bearer
tokens live in memory (as SHA-256 digests), never on disk. See
[`privacy.md`](privacy.md) for the full inventory.
