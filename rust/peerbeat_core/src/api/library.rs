//! FRB library API: open the database, scan folders, browse + search.
//!
//! Holds the process-wide [`Db`] behind a mutex. M1 surface; transport/audio
//! and network APIs are added in later milestones.

use crate::db::browse::{self, AlbumRow, ArtistRow, GenreRow, YearRow};
use crate::db::playlists::{self, PlaylistRow};
use crate::db::tracks::{self, TrackRow};
use crate::db::{settings, Db};
use crate::library;
use std::path::PathBuf;
use std::sync::Mutex;
use std::time::{SystemTime, UNIX_EPOCH};

static DB: Mutex<Option<Db>> = Mutex::new(None);

fn now_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

fn with_db<T, E: std::fmt::Display>(f: impl FnOnce(&Db) -> Result<T, E>) -> Result<T, String> {
    let guard = DB.lock().map_err(|_| "db lock poisoned".to_string())?;
    let db = guard
        .as_ref()
        .ok_or_else(|| "library not open".to_string())?;
    f(db).map_err(|e| e.to_string())
}

/// Result of a folder scan.
pub struct ScanReport {
    pub added: u32,
    pub updated: u32,
    pub skipped: u32,
    pub errors: u32,
}

/// Open (creating if needed) the library database at `db_path`.
pub fn library_open(db_path: String) -> Result<(), String> {
    let db = Db::open(&PathBuf::from(db_path)).map_err(|e| e.to_string())?;
    *DB.lock().map_err(|_| "db lock poisoned".to_string())? = Some(db);
    Ok(())
}

/// Recursively scan `path`, importing new/changed audio files. Returns counts.
pub fn library_scan(path: String) -> Result<ScanReport, String> {
    let added_at = now_ms();
    with_db(|db| library::scan_folder(db.conn(), &PathBuf::from(&path), added_at, db.art_dir()))
        .map(|s| ScanReport {
            added: s.added as u32,
            updated: s.updated as u32,
            skipped: s.skipped as u32,
            errors: s.errors as u32,
        })
}

/// Browse all songs ordered by title, paginated.
pub fn library_browse_songs(limit: i64, offset: i64) -> Result<Vec<TrackRow>, String> {
    with_db(|db| tracks::browse_songs(db.conn(), limit, offset))
}

/// Fuzzy search across title/artist/album/genre.
pub fn library_search(query: String, limit: i64) -> Result<Vec<TrackRow>, String> {
    with_db(|db| tracks::search_tracks(db.conn(), &query, limit))
}

/// Fetch a single track by id (`None` if it no longer exists).
pub fn library_track_by_id(track_id: i64) -> Result<Option<TrackRow>, String> {
    with_db(|db| tracks::track_by_id(db.conn(), track_id))
}

// ── Settings (key/value) ────────────────────────────────────────────────────

/// Read a persisted setting, or `None` if unset.
pub fn settings_get(key: String) -> Result<Option<String>, String> {
    with_db(|db| settings::get(db.conn(), &key))
}

/// Write (upsert) a persisted setting.
pub fn settings_set(key: String, value: String) -> Result<(), String> {
    with_db(|db| settings::set(db.conn(), &key, &value))
}

/// Delete a persisted setting (no-op if absent).
pub fn settings_delete(key: String) -> Result<(), String> {
    with_db(|db| settings::delete(db.conn(), &key))
}

// ── Browse views ───────────────────────────────────────────────────────────

pub fn library_browse_albums(limit: i64, offset: i64) -> Result<Vec<AlbumRow>, String> {
    with_db(|db| browse::browse_albums(db.conn(), limit, offset))
}

pub fn library_browse_artists() -> Result<Vec<ArtistRow>, String> {
    with_db(|db| browse::browse_artists(db.conn()))
}

pub fn library_browse_genres() -> Result<Vec<GenreRow>, String> {
    with_db(|db| browse::browse_genres(db.conn()))
}

pub fn library_browse_years() -> Result<Vec<YearRow>, String> {
    with_db(|db| browse::browse_years(db.conn()))
}

pub fn library_album_tracks(album_id: i64) -> Result<Vec<TrackRow>, String> {
    with_db(|db| browse::album_tracks(db.conn(), album_id))
}

pub fn library_artist_tracks(artist_id: i64) -> Result<Vec<TrackRow>, String> {
    with_db(|db| browse::artist_tracks(db.conn(), artist_id))
}

pub fn library_genre_tracks(genre_id: i64) -> Result<Vec<TrackRow>, String> {
    with_db(|db| browse::genre_tracks(db.conn(), genre_id))
}

pub fn library_tracks_by_year(year: i64) -> Result<Vec<TrackRow>, String> {
    with_db(|db| browse::tracks_by_year(db.conn(), year))
}

pub fn library_recently_added(limit: i64) -> Result<Vec<TrackRow>, String> {
    with_db(|db| browse::recently_added(db.conn(), limit))
}

/// Total track count.
pub fn library_track_count() -> Result<i64, String> {
    with_db(|db| {
        db.conn()
            .query_row("SELECT count(*) FROM tracks", [], |r| r.get::<_, i64>(0))
    })
}

// ── Manual playlists ───────────────────────────────────────────────────────

pub fn playlist_list() -> Result<Vec<PlaylistRow>, String> {
    with_db(|db| playlists::list(db.conn()))
}

pub fn playlist_create(name: String) -> Result<i64, String> {
    let clean = name.trim().to_string();
    if clean.is_empty() {
        return Err("playlist name cannot be empty".to_string());
    }
    with_db(|db| playlists::create(db.conn(), &clean, now_ms()))
}

pub fn playlist_rename(playlist_id: i64, name: String) -> Result<(), String> {
    let clean = name.trim().to_string();
    if clean.is_empty() {
        return Err("playlist name cannot be empty".to_string());
    }
    with_db(|db| playlists::rename(db.conn(), playlist_id, &clean, now_ms()))
}

pub fn playlist_delete(playlist_id: i64) -> Result<(), String> {
    with_db(|db| playlists::delete(db.conn(), playlist_id))
}

pub fn playlist_duplicate(playlist_id: i64, name: String) -> Result<i64, String> {
    let clean = name.trim().to_string();
    if clean.is_empty() {
        return Err("playlist name cannot be empty".to_string());
    }
    with_db(|db| playlists::duplicate(db.conn(), playlist_id, &clean, now_ms()))
}

pub fn playlist_tracks(playlist_id: i64) -> Result<Vec<TrackRow>, String> {
    with_db(|db| playlists::tracks(db.conn(), playlist_id))
}

pub fn playlist_add_tracks(playlist_id: i64, track_ids: Vec<i64>) -> Result<(), String> {
    if track_ids.is_empty() {
        return Ok(());
    }
    with_db(|db| playlists::add_tracks(db.conn(), playlist_id, &track_ids, now_ms()))
}

pub fn playlist_remove_position(playlist_id: i64, position: i64) -> Result<(), String> {
    with_db(|db| playlists::remove_position(db.conn(), playlist_id, position, now_ms()))
}

pub fn playlist_reorder_tracks(playlist_id: i64, track_ids: Vec<i64>) -> Result<(), String> {
    with_db(|db| playlists::reorder_tracks(db.conn(), playlist_id, &track_ids, now_ms()))
}
