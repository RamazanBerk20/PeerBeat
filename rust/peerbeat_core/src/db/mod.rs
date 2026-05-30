//! SQLite store (rusqlite, bundled) — the single source of truth.
//!
//! Owns the schema + migrations and the FTS5 (trigram + bm25) search index.
//! The scanner ([`crate::library`]) writes here and the LAN host server
//! ([`crate::net`]) reads here, both in-process, so there is no cross-FFI
//! chatter on the hot paths.
//!
//! See `docs/data-model.md` for the full table set and indexing strategy.

pub mod browse;
pub mod playlists;
mod schema;
pub mod tracks;

pub use schema::SCHEMA_VERSION;

use rusqlite::Connection;
use std::path::Path;

/// A handle to the PeerBeat database. Wraps a single rusqlite [`Connection`];
/// the FRB layer owns one of these on a dedicated worker thread.
pub struct Db {
    conn: Connection,
}

impl Db {
    /// Open (creating if absent) the database at `path`, applying migrations.
    pub fn open(path: &Path) -> rusqlite::Result<Self> {
        Self::init(Connection::open(path)?)
    }

    /// An in-memory database — used by tests and ephemeral tooling.
    pub fn open_in_memory() -> rusqlite::Result<Self> {
        Self::init(Connection::open_in_memory()?)
    }

    fn init(conn: Connection) -> rusqlite::Result<Self> {
        // execute_batch ignores the row PRAGMA journal_mode returns and is a
        // no-op for WAL on an in-memory db.
        conn.execute_batch(
            "PRAGMA journal_mode=WAL;
             PRAGMA foreign_keys=ON;
             PRAGMA synchronous=NORMAL;
             PRAGMA temp_store=MEMORY;",
        )?;
        schema::migrate(&conn)?;
        Ok(Self { conn })
    }

    /// Borrow the underlying connection (DAOs live in submodules).
    pub fn conn(&self) -> &Connection {
        &self.conn
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn migrates_to_current_version() {
        let db = Db::open_in_memory().unwrap();
        let v: i64 = db
            .conn()
            .query_row("PRAGMA user_version", [], |r| r.get(0))
            .unwrap();
        assert_eq!(v, SCHEMA_VERSION);
    }

    #[test]
    fn core_tables_exist() {
        let db = Db::open_in_memory().unwrap();
        for t in [
            "tracks",
            "albums",
            "artists",
            "genres",
            "track_artists",
            "playlists",
            "smart_playlists",
            "play_history",
            "known_hosts",
            "shares",
            "tracks_fts",
        ] {
            let n: i64 = db
                .conn()
                .query_row(
                    "SELECT count(*) FROM sqlite_master WHERE name=?1",
                    [t],
                    |r| r.get(0),
                )
                .unwrap();
            assert_eq!(n, 1, "missing table {t}");
        }
    }

    #[test]
    fn fts_trigram_substring_search_works() {
        let db = Db::open_in_memory().unwrap();
        let c = db.conn();
        c.execute(
            "INSERT INTO tracks(id, path, normalized_path, title, added_at) \
             VALUES (1, '/m/song.flac', '/m/song.flac', 'Midnight City', 100)",
            [],
        )
        .unwrap();
        c.execute(
            "INSERT INTO tracks_fts(rowid, title, artist, album, genre) \
             VALUES (1, 'Midnight City', 'M83', 'Hurry Up', 'Synthpop')",
            [],
        )
        .unwrap();

        // trigram supports substring matching (>= 3 chars)
        let id: i64 = c
            .query_row(
                "SELECT rowid FROM tracks_fts WHERE tracks_fts MATCH 'nigh' \
                 ORDER BY bm25(tracks_fts) LIMIT 1",
                [],
                |r| r.get(0),
            )
            .unwrap();
        assert_eq!(id, 1);
    }
}
