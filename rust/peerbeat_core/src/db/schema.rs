//! Schema definition + linear migrations (keyed on SQLite `user_version`).

use rusqlite::Connection;

/// Current schema version. Bump + append a migration when the schema changes.
pub const SCHEMA_VERSION: i64 = 1;

/// v1 — the full schema: library, playlists, smart playlists, queue, history,
/// the FTS5 search index, and the LAN/network tables. See `docs/data-model.md`.
const V1: &str = r#"
-- ── Library ────────────────────────────────────────────────────────────────
CREATE TABLE artists (
    id        INTEGER PRIMARY KEY,
    name      TEXT NOT NULL,
    sort_name TEXT NOT NULL DEFAULT '',
    UNIQUE(name)
);

CREATE TABLE genres (
    id   INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE art_cache (
    id         INTEGER PRIMARY KEY,
    image_hash TEXT NOT NULL UNIQUE,
    file_path  TEXT NOT NULL,
    width      INTEGER,
    height     INTEGER,
    mime       TEXT
);

CREATE TABLE albums (
    id              INTEGER PRIMARY KEY,
    title           TEXT NOT NULL,
    album_artist_id INTEGER REFERENCES artists(id) ON DELETE SET NULL,
    year            INTEGER,
    art_id          INTEGER REFERENCES art_cache(id) ON DELETE SET NULL,
    sort_title      TEXT NOT NULL DEFAULT '',
    UNIQUE(title, album_artist_id)
);

CREATE TABLE tracks (
    id                   INTEGER PRIMARY KEY,
    path                 TEXT NOT NULL,
    normalized_path      TEXT NOT NULL UNIQUE,
    content_hash         TEXT,
    title                TEXT NOT NULL DEFAULT '',
    album_id             INTEGER REFERENCES albums(id) ON DELETE SET NULL,
    track_no             INTEGER,
    disc_no              INTEGER,
    year                 INTEGER,
    duration_ms          INTEGER NOT NULL DEFAULT 0,
    codec                TEXT NOT NULL DEFAULT '',
    bitrate              INTEGER,
    sample_rate          INTEGER,
    channels             INTEGER,
    replaygain_track_db  REAL,
    replaygain_album_db  REAL,
    rating               INTEGER NOT NULL DEFAULT 0,
    played_count         INTEGER NOT NULL DEFAULT 0,
    last_played_at       INTEGER,
    added_at             INTEGER NOT NULL,
    file_size            INTEGER NOT NULL DEFAULT 0,
    mtime_ns             INTEGER NOT NULL DEFAULT 0,
    has_lyrics           INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX idx_tracks_album   ON tracks(album_id);
CREATE INDEX idx_tracks_hash    ON tracks(content_hash);
CREATE INDEX idx_tracks_year    ON tracks(year);
CREATE INDEX idx_tracks_added   ON tracks(added_at);
CREATE INDEX idx_tracks_played  ON tracks(played_count);
CREATE INDEX idx_tracks_lastpl  ON tracks(last_played_at);

-- multi-value joins (a track may have several artists / genres)
CREATE TABLE track_artists (
    track_id  INTEGER NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
    artist_id INTEGER NOT NULL REFERENCES artists(id) ON DELETE CASCADE,
    role      TEXT NOT NULL DEFAULT 'main',
    PRIMARY KEY(track_id, artist_id, role)
);
CREATE INDEX idx_track_artists_artist ON track_artists(artist_id);

CREATE TABLE track_genres (
    track_id INTEGER NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
    genre_id INTEGER NOT NULL REFERENCES genres(id) ON DELETE CASCADE,
    PRIMARY KEY(track_id, genre_id)
);
CREATE INDEX idx_track_genres_genre ON track_genres(genre_id);

-- ── Watch-folders + scan state ─────────────────────────────────────────────
CREATE TABLE folders (
    id         INTEGER PRIMARY KEY,
    path       TEXT NOT NULL UNIQUE,
    is_watched INTEGER NOT NULL DEFAULT 1,
    added_at   INTEGER NOT NULL
);
CREATE TABLE scan_state (
    folder_id          INTEGER PRIMARY KEY REFERENCES folders(id) ON DELETE CASCADE,
    last_full_scan_at  INTEGER,
    last_incremental_at INTEGER,
    file_count         INTEGER NOT NULL DEFAULT 0
);

-- ── Playlists / queue / history / favorites ────────────────────────────────
CREATE TABLE playlists (
    id         INTEGER PRIMARY KEY,
    name       TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE playlist_items (
    playlist_id INTEGER NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
    track_id    INTEGER NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
    position    INTEGER NOT NULL,
    PRIMARY KEY(playlist_id, position)
);
CREATE INDEX idx_playlist_items_track ON playlist_items(track_id);

CREATE TABLE smart_playlists (
    id         INTEGER PRIMARY KEY,
    name       TEXT NOT NULL,
    rule_json  TEXT NOT NULL,
    sort_json  TEXT,
    limit_n    INTEGER,
    updated_at INTEGER NOT NULL
);

CREATE TABLE queue (
    id       INTEGER PRIMARY KEY,
    track_id INTEGER NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
    position INTEGER NOT NULL,
    source   TEXT NOT NULL DEFAULT 'list'
);

CREATE TABLE favorites (
    track_id INTEGER PRIMARY KEY REFERENCES tracks(id) ON DELETE CASCADE,
    added_at INTEGER NOT NULL
);

CREATE TABLE play_history (
    id        INTEGER PRIMARY KEY,
    track_id  INTEGER NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
    played_at INTEGER NOT NULL,
    ms_played INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX idx_play_history_track ON play_history(track_id);
CREATE INDEX idx_play_history_time  ON play_history(played_at);

CREATE TABLE eq_presets (
    id      INTEGER PRIMARY KEY,
    name    TEXT NOT NULL UNIQUE,
    bands   TEXT NOT NULL,          -- JSON array of 10 gains (dB)
    preamp  REAL NOT NULL DEFAULT 0,
    builtin INTEGER NOT NULL DEFAULT 0
);

-- ── Settings (key/value) ───────────────────────────────────────────────────
CREATE TABLE settings (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

-- ── Full-text search (trigram + bm25). Maintained programmatically by the
--    track DAO; rowid == tracks.id. Stores its own copy (simplest correctness
--    with join-derived artist/genre text). ──────────────────────────────────
CREATE VIRTUAL TABLE tracks_fts USING fts5(
    title, artist, album, genre,
    tokenize='trigram'
);

-- ── LAN / network ──────────────────────────────────────────────────────────
CREATE TABLE known_hosts (
    id            INTEGER PRIMARY KEY,
    host_id       TEXT NOT NULL UNIQUE,
    display_name  TEXT NOT NULL DEFAULT '',
    color         TEXT,
    spki_sha256   TEXT NOT NULL,        -- TOFU pin
    first_seen_at INTEGER NOT NULL,
    last_seen_at  INTEGER
);
CREATE TABLE remembered_peers (
    host_id    TEXT NOT NULL,
    peer_id    TEXT NOT NULL,
    decision   TEXT NOT NULL,           -- allow | deny
    decided_at INTEGER NOT NULL,
    PRIMARY KEY(host_id, peer_id)
);
CREATE TABLE shares (
    id          INTEGER PRIMARY KEY,
    playlist_id INTEGER REFERENCES playlists(id) ON DELETE CASCADE,
    permission  TEXT NOT NULL DEFAULT 'stream',   -- stream | stream_download
    mode        TEXT NOT NULL DEFAULT 'open',      -- open | pin | approved
    pin_hash    TEXT,
    enabled     INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE transfer_log (
    id         INTEGER PRIMARY KEY,
    peer_id    TEXT NOT NULL,
    track_id   INTEGER REFERENCES tracks(id) ON DELETE SET NULL,
    kind       TEXT NOT NULL,           -- stream | download
    bytes      INTEGER NOT NULL DEFAULT 0,
    started_at INTEGER NOT NULL,
    ended_at   INTEGER,
    state      TEXT NOT NULL DEFAULT 'active'
);
CREATE INDEX idx_transfer_log_peer ON transfer_log(peer_id);
"#;

/// Apply any outstanding migrations to bring `conn` up to [`SCHEMA_VERSION`].
pub fn migrate(conn: &Connection) -> rusqlite::Result<()> {
    let current: i64 = conn.query_row("PRAGMA user_version", [], |r| r.get(0))?;
    if current < 1 {
        conn.execute_batch(V1)?;
    }
    // Future: `if current < 2 { conn.execute_batch(V2)?; }` …
    if current != SCHEMA_VERSION {
        conn.pragma_update(None, "user_version", SCHEMA_VERSION)?;
    }
    Ok(())
}
