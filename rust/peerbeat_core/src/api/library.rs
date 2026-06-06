//! FRB library API: open the database, scan folders, browse + search.
//!
//! Holds the process-wide [`Db`] behind a mutex. M1 surface; transport/audio
//! and network APIs are added in later milestones.

use crate::db::browse::{self, AlbumRow, ArtistRow, GenreRow, YearRow};
use crate::db::eq_presets::{self, EqPresetRow};
use crate::db::folders::{self, FolderRow};
use crate::db::history;
use crate::db::known_hosts;
use crate::db::playlists::{self, PlaylistRow};
use crate::db::shares::{self, ShareRow};
use crate::db::smart::{self, SmartPlaylistRow};
use crate::db::tracks::{self, TrackRow};
use crate::db::transfer_log::{self, TransferRow};
use crate::db::{settings, Db};
use crate::library::{self, metadata, playlist_io};
use std::path::{Path, PathBuf};
use std::sync::Mutex;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

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

/// Result of a folder scan (or a rescan-all).
pub struct ScanReport {
    pub added: u32,
    pub updated: u32,
    pub skipped: u32,
    pub errors: u32,
    /// Tracks pruned because their files no longer exist (rescan-all only).
    pub removed: u32,
}

/// Open (creating if needed) the library database at `db_path`.
pub fn library_open(db_path: String) -> Result<(), String> {
    let db = Db::open(&PathBuf::from(db_path)).map_err(|e| e.to_string())?;
    *DB.lock().map_err(|_| "db lock poisoned".to_string())? = Some(db);
    Ok(())
}

/// Recursively scan `path`, importing new/changed audio files, and remember it
/// as a library folder. Returns counts.
pub fn library_scan(path: String) -> Result<ScanReport, String> {
    let added_at = now_ms();
    let report = with_db(|db| -> anyhow::Result<ScanReport> {
        let root = PathBuf::from(&path);
        let s = library::scan_folder(db.conn(), &root, added_at, db.art_dir())?;
        folders::add(db.conn(), &path, added_at)?;
        Ok(ScanReport {
            added: s.added as u32,
            updated: s.updated as u32,
            skipped: s.skipped as u32,
            errors: s.errors as u32,
            removed: 0,
        })
    });
    restart_watcher(); // (re)start the watcher to include the new folder
    report
}

// ── Library folders (sources) ───────────────────────────────────────────────

/// The folders the user has scanned (library sources).
pub fn library_folders() -> Result<Vec<FolderRow>, String> {
    with_db(|db| folders::list(db.conn()))
}

/// Forget a library folder and remove the tracks under it.
pub fn library_remove_folder(folder_id: i64) -> Result<(), String> {
    let r = with_db(|db| folders::remove(db.conn(), folder_id));
    restart_watcher();
    r
}

/// Re-scan every known folder: import new/changed files and prune tracks whose
/// files have been deleted (skipping inaccessible/empty roots). Aggregate counts.
pub fn library_rescan_all() -> Result<ScanReport, String> {
    let now = now_ms();
    with_db(|db| -> anyhow::Result<ScanReport> {
        let mut rep = ScanReport {
            added: 0,
            updated: 0,
            skipped: 0,
            errors: 0,
            removed: 0,
        };
        for f in folders::list(db.conn())? {
            let root = PathBuf::from(&f.path);
            let s = library::scan_folder(db.conn(), &root, now, db.art_dir())?;
            let pruned = library::scan::prune_missing(db.conn(), &root)?;
            rep.added = rep.added.saturating_add(s.added as u32);
            rep.updated = rep.updated.saturating_add(s.updated as u32);
            rep.skipped = rep.skipped.saturating_add(s.skipped as u32);
            rep.errors = rep.errors.saturating_add(s.errors as u32);
            rep.removed = rep.removed.saturating_add(pruned as u32);
        }
        Ok(rep)
    })
}

// ── Watch-folders (auto-import on filesystem changes) ────────────────────────

struct FolderWatcher {
    // Dropping the watcher drops its event handler (and the channel sender),
    // which ends the debounce worker thread.
    _watcher: notify::RecommendedWatcher,
}

static WATCHER: Mutex<Option<FolderWatcher>> = Mutex::new(None);

/// Begin watching every library folder; filesystem changes trigger a debounced
/// incremental rescan + prune of the affected folder. Idempotent. A no-op (not
/// an error) when there are no folders yet.
pub fn library_start_watching() -> Result<(), String> {
    use notify::{RecursiveMode, Watcher};
    let mut guard = WATCHER
        .lock()
        .map_err(|_| "watcher lock poisoned".to_string())?;
    if guard.is_some() {
        return Ok(());
    }
    let roots: Vec<PathBuf> = with_db(|db| folders::list(db.conn()))?
        .into_iter()
        .map(|f| PathBuf::from(f.path))
        .collect();
    if roots.is_empty() {
        return Ok(());
    }

    let (tx, rx) = std::sync::mpsc::channel::<PathBuf>();
    let mut watcher = notify::recommended_watcher(move |res: notify::Result<notify::Event>| {
        if let Ok(ev) = res {
            for p in ev.paths {
                let _ = tx.send(p);
            }
        }
    })
    .map_err(|e| e.to_string())?;
    for root in &roots {
        let _ = watcher.watch(root, RecursiveMode::Recursive);
    }

    let worker_roots = roots.clone();
    std::thread::Builder::new()
        .name("peerbeat-watch".into())
        .spawn(move || watch_loop(rx, worker_roots))
        .map_err(|e| e.to_string())?;

    *guard = Some(FolderWatcher { _watcher: watcher });
    Ok(())
}

/// Drain filesystem events, debounce ~800 ms, then incrementally rescan+prune
/// each affected root. Exits when the watcher (and its sender) is dropped.
fn watch_loop(rx: std::sync::mpsc::Receiver<PathBuf>, roots: Vec<PathBuf>) {
    use std::collections::HashSet;
    use std::sync::mpsc::RecvTimeoutError;
    loop {
        let first = match rx.recv() {
            Ok(p) => p,
            Err(_) => return, // watcher dropped
        };
        let mut changed: HashSet<PathBuf> = HashSet::new();
        changed.insert(first);
        loop {
            match rx.recv_timeout(Duration::from_millis(800)) {
                Ok(p) => {
                    changed.insert(p);
                }
                Err(RecvTimeoutError::Timeout) => break,
                Err(RecvTimeoutError::Disconnected) => return,
            }
        }
        let now = now_ms();
        for root in roots
            .iter()
            .filter(|root| changed.iter().any(|p| p.starts_with(root)))
        {
            let _ = with_db(|db| -> anyhow::Result<()> {
                library::scan_folder(db.conn(), root, now, db.art_dir())?;
                library::scan::prune_missing(db.conn(), root)?;
                Ok(())
            });
        }
    }
}

/// Stop watching (best-effort).
pub fn library_stop_watching() {
    if let Ok(mut g) = WATCHER.lock() {
        *g = None;
    }
}

/// (Re)start the watcher so it reflects the current folder set. Watching is on by
/// default for all library folders, so this starts it even if it wasn't running.
fn restart_watcher() {
    library_stop_watching();
    let _ = library_start_watching();
}

// ── LAN sharing config (host side) ───────────────────────────────────────────

/// Every configured share (for the host's sharing screen).
pub fn share_list() -> Result<Vec<ShareRow>, String> {
    with_db(|db| shares::list(db.conn()))
}

/// Mark a scope shareable (create or update). `playlist_id == None` shares the
/// whole library. `permission`: "stream" | "stream_download"; `mode`: "open" |
/// "pin" | "approved". A `Some(pin)` (re)sets the PIN.
pub fn share_set(
    playlist_id: Option<i64>,
    permission: String,
    mode: String,
    pin: Option<String>,
    enabled: bool,
) -> Result<i64, String> {
    // Reject a too-weak PIN at the boundary (spec: 4–6 digits). An empty/None pin
    // on a "pin" share means "keep the existing one", so only validate a new value.
    if let Some(p) = pin.as_deref() {
        if !p.trim().is_empty() && !shares::pin_is_valid_format(p) {
            return Err("PIN must be 4–6 digits".to_string());
        }
    }
    with_db(|db| {
        shares::set_share(
            db.conn(),
            playlist_id,
            &permission,
            &mode,
            pin.as_deref(),
            enabled,
        )
    })
}

/// Enable/disable a share without losing its config.
pub fn share_set_enabled(playlist_id: Option<i64>, enabled: bool) -> Result<(), String> {
    with_db(|db| shares::set_enabled(db.conn(), playlist_id, enabled))
}

/// Stop sharing a scope entirely.
pub fn share_remove(playlist_id: Option<i64>) -> Result<(), String> {
    with_db(|db| shares::remove(db.conn(), playlist_id))
}

/// Recent stream/download activity by peers (for the host connections dashboard).
pub fn net_recent_transfers(limit: i64) -> Result<Vec<TransferRow>, String> {
    with_db(|db| transfer_log::recent(db.conn(), limit))
}

/// Clear the recorded peer-activity log.
pub fn net_clear_activity() -> Result<(), String> {
    with_db(|db| transfer_log::clear(db.conn()))
}

/// Browse all songs ordered by title, paginated.
pub fn library_browse_songs(limit: i64, offset: i64) -> Result<Vec<TrackRow>, String> {
    with_db(|db| tracks::browse_songs(db.conn(), limit, offset))
}

// ── Play tracking + auto-lists + favorites ───────────────────────────────────

/// Record that a track started playing (feeds Most/Recently-Played + smart rules).
pub fn library_mark_played(track_id: i64) -> Result<(), String> {
    let now = now_ms();
    with_db(|db| history::mark_played(db.conn(), track_id, now))
}

pub fn library_recently_played(limit: i64) -> Result<Vec<TrackRow>, String> {
    with_db(|db| history::recently_played(db.conn(), limit))
}

pub fn library_most_played(limit: i64) -> Result<Vec<TrackRow>, String> {
    with_db(|db| history::most_played(db.conn(), limit))
}

pub fn library_never_played(limit: i64) -> Result<Vec<TrackRow>, String> {
    with_db(|db| history::never_played(db.conn(), limit))
}

pub fn library_set_favorite(track_id: i64, on: bool) -> Result<(), String> {
    let now = now_ms();
    with_db(|db| history::set_favorite(db.conn(), track_id, on, now))
}

pub fn library_is_favorite(track_id: i64) -> Result<bool, String> {
    with_db(|db| history::is_favorite(db.conn(), track_id))
}

pub fn library_favorites(limit: i64) -> Result<Vec<TrackRow>, String> {
    with_db(|db| history::favorites(db.conn(), limit))
}

/// Fuzzy search across title/artist/album/genre.
pub fn library_search(query: String, limit: i64) -> Result<Vec<TrackRow>, String> {
    with_db(|db| tracks::search_tracks(db.conn(), &query, limit))
}

/// Fetch a single track by id (`None` if it no longer exists).
pub fn library_track_by_id(track_id: i64) -> Result<Option<TrackRow>, String> {
    with_db(|db| tracks::track_by_id(db.conn(), track_id))
}

/// Lyrics for a track — a sidecar `.lrc` or the embedded tag, or `None`.
pub fn library_track_lyrics(track_id: i64) -> Result<Option<String>, String> {
    with_db(|db| -> anyhow::Result<Option<String>> {
        let row = tracks::track_by_id(db.conn(), track_id)?;
        Ok(row.and_then(|t| metadata::read_lyrics(Path::new(&t.path))))
    })
}

/// All editable tag fields for a track (read fresh from the file, so the editor
/// can prefill every field and not clobber ones absent from [`TrackRow`]).
pub struct TrackTags {
    pub title: String,
    pub artist: String,
    pub album: String,
    pub album_artist: String,
    pub genre: String,
    pub year: Option<i64>,
    pub track_no: Option<i64>,
}

/// Read the current tag fields from a track's file (for the metadata editor).
pub fn library_track_tags(track_id: i64) -> Result<TrackTags, String> {
    with_db(|db| {
        let row = tracks::track_by_id(db.conn(), track_id)?
            .ok_or_else(|| anyhow::anyhow!("track not found"))?;
        let nt = metadata::read_tags(Path::new(&row.path), 0, 0, 0)?;
        Ok::<TrackTags, anyhow::Error>(TrackTags {
            title: nt.title,
            artist: nt.artists.join("; "),
            album: nt.album.unwrap_or_default(),
            album_artist: nt.album_artist.unwrap_or_default(),
            genre: nt.genres.join("; "),
            year: nt.year,
            track_no: nt.track_no,
        })
    })
}

/// Write edited tags back to the track's file, then re-read it into the
/// library. Returns the refreshed row. `artist`/`genre` accept `;`-separated
/// multi-values; empty strings clear the field.
#[allow(clippy::too_many_arguments)]
pub fn library_update_tags(
    track_id: i64,
    title: String,
    artist: String,
    album: String,
    album_artist: String,
    genre: String,
    year: Option<i64>,
    track_no: Option<i64>,
) -> Result<TrackRow, String> {
    with_db(|db| {
        let row = tracks::track_by_id(db.conn(), track_id)?
            .ok_or_else(|| anyhow::anyhow!("track not found"))?;
        let edit = metadata::TagEdit {
            title,
            artist,
            album,
            album_artist,
            genre,
            year,
            track_no,
        };
        metadata::write_tags(Path::new(&row.path), &edit)?;
        library::scan::rescan_file(db.conn(), Path::new(&row.path), db.art_dir(), now_ms())?;
        tracks::track_by_id(db.conn(), track_id)?
            .ok_or_else(|| anyhow::anyhow!("track vanished after edit"))
    })
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

// ── EQ presets ──────────────────────────────────────────────────────────────

pub fn eq_preset_list() -> Result<Vec<EqPresetRow>, String> {
    with_db(|db| eq_presets::list(db.conn()))
}

pub fn eq_preset_create(name: String, bands: Vec<f64>, preamp: f64) -> Result<i64, String> {
    let clean = name.trim().to_string();
    if clean.is_empty() {
        return Err("preset name cannot be empty".to_string());
    }
    with_db(|db| eq_presets::create(db.conn(), &clean, &bands, preamp))
}

pub fn eq_preset_update(
    preset_id: i64,
    name: String,
    bands: Vec<f64>,
    preamp: f64,
) -> Result<(), String> {
    let clean = name.trim().to_string();
    if clean.is_empty() {
        return Err("preset name cannot be empty".to_string());
    }
    with_db(|db| eq_presets::update(db.conn(), preset_id, &clean, &bands, preamp))
}

pub fn eq_preset_delete(preset_id: i64) -> Result<(), String> {
    with_db(|db| eq_presets::delete(db.conn(), preset_id))
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

// ── Playlist file import / export (M3U · M3U8 · PLS) ─────────────────────────

/// Outcome of importing a playlist file.
pub struct PlaylistImportReport {
    pub playlist_id: i64,
    /// Entries matched to a library track (and added to the new playlist).
    pub matched: u32,
    /// Total path entries found in the file.
    pub total: u32,
}

/// Import an `.m3u`/`.m3u8`/`.pls` file as a new playlist (named after the
/// file). Path entries are matched against the library by normalized path;
/// unmatched entries are skipped and reported.
pub fn playlist_import(file_path: String) -> Result<PlaylistImportReport, String> {
    with_db(|db| import_playlist_file(db, &file_path))
}

fn import_playlist_file(db: &Db, file_path: &str) -> anyhow::Result<PlaylistImportReport> {
    let path = PathBuf::from(file_path);
    let content = std::fs::read_to_string(&path)?;
    let base = path
        .parent()
        .map(Path::to_path_buf)
        .unwrap_or_else(|| PathBuf::from("."));
    let parsed = if playlist_io::is_pls(&path) {
        playlist_io::parse_pls(&content, &base)
    } else {
        playlist_io::parse_m3u(&content, &base)
    };
    let total = parsed.len() as u32;

    let mut ids = Vec::new();
    for p in &parsed {
        // Try the literal path, then a canonicalized form, normalized like scan.
        let mut candidates = vec![metadata::normalize_path(p)];
        if let Ok(canon) = std::fs::canonicalize(p) {
            candidates.push(metadata::normalize_path(&canon));
        }
        for c in candidates {
            if let Some(id) = tracks::id_by_path(db.conn(), &c)? {
                ids.push(id);
                break;
            }
        }
    }

    let name = path
        .file_stem()
        .and_then(|s| s.to_str())
        .filter(|s| !s.is_empty())
        .unwrap_or("Imported")
        .to_string();
    let playlist_id = playlists::create(db.conn(), &name, now_ms())?;
    if !ids.is_empty() {
        playlists::add_tracks(db.conn(), playlist_id, &ids, now_ms())?;
    }
    Ok(PlaylistImportReport {
        playlist_id,
        matched: ids.len() as u32,
        total,
    })
}

/// Export a playlist to `file_path`. Format is chosen by the file extension
/// (`.pls` → PLS, otherwise extended M3U).
pub fn playlist_export(playlist_id: i64, file_path: String) -> Result<(), String> {
    with_db(|db| export_playlist_file(db, playlist_id, &file_path))
}

// ── Smart playlists (JSON rule sets) ────────────────────────────────────────

pub fn smart_playlist_list() -> Result<Vec<SmartPlaylistRow>, String> {
    with_db(|db| smart::list(db.conn()))
}

/// Create a smart playlist after validating the rule JSON compiles.
pub fn smart_playlist_create(
    name: String,
    rule_json: String,
    limit_n: Option<i64>,
) -> Result<i64, String> {
    let clean = name.trim().to_string();
    if clean.is_empty() {
        return Err("playlist name cannot be empty".to_string());
    }
    smart::validate(&rule_json, now_ms())?;
    with_db(|db| smart::create(db.conn(), &clean, &rule_json, limit_n, now_ms()))
}

pub fn smart_playlist_update(
    smart_id: i64,
    name: String,
    rule_json: String,
    limit_n: Option<i64>,
) -> Result<(), String> {
    let clean = name.trim().to_string();
    if clean.is_empty() {
        return Err("playlist name cannot be empty".to_string());
    }
    smart::validate(&rule_json, now_ms())?;
    with_db(|db| smart::update(db.conn(), smart_id, &clean, &rule_json, limit_n, now_ms()))
}

pub fn smart_playlist_delete(smart_id: i64) -> Result<(), String> {
    with_db(|db| smart::delete(db.conn(), smart_id))
}

/// Resolve a saved smart playlist to its current matching tracks.
pub fn smart_playlist_tracks(smart_id: i64) -> Result<Vec<TrackRow>, String> {
    with_db(|db| {
        let sp = smart::get(db.conn(), smart_id)?
            .ok_or_else(|| anyhow::anyhow!("smart playlist not found"))?;
        smart::tracks_for_rules(db.conn(), &sp.rule_json, sp.limit_n, now_ms())
    })
}

/// Preview a rule set without saving it (for the rule builder UI).
pub fn smart_playlist_preview(
    rule_json: String,
    limit_n: Option<i64>,
) -> Result<Vec<TrackRow>, String> {
    with_db(|db| smart::tracks_for_rules(db.conn(), &rule_json, limit_n, now_ms()))
}

fn export_playlist_file(db: &Db, playlist_id: i64, file_path: &str) -> anyhow::Result<()> {
    let path = PathBuf::from(file_path);
    let rows = playlists::tracks(db.conn(), playlist_id)?;
    let entries: Vec<playlist_io::Entry> = rows
        .iter()
        .map(|t| playlist_io::Entry {
            path: t.path.clone(),
            title: t.title.clone(),
            duration_secs: t.duration_ms / 1000,
        })
        .collect();
    let text = if playlist_io::is_pls(&path) {
        playlist_io::to_pls(&entries)
    } else {
        playlist_io::to_m3u(&entries)
    };
    std::fs::write(&path, text)?;
    Ok(())
}

// ── LAN TOFU pins (remembered host certificate fingerprints) ────────────────

/// The pinned certificate fingerprint for `host_id`, or `None` if never seen.
pub fn net_known_host_fingerprint(host_id: String) -> Result<Option<String>, String> {
    with_db(|db| known_hosts::fingerprint(db.conn(), &host_id))
}

/// TOFU-remember a host's certificate fingerprint. First sight pins it; a
/// later, different fingerprint is rejected (possible MITM).
pub fn net_remember_host(host_id: String, name: String, fingerprint: String) -> Result<(), String> {
    with_db(|db| known_hosts::remember(db.conn(), &host_id, &name, &fingerprint, now_ms()))
}

/// Every pinned fingerprint — the streaming client (which only has a URL) uses
/// this to accept a self-signed cert that belongs to an already-trusted host.
pub fn net_known_fingerprints() -> Result<Vec<String>, String> {
    with_db(|db| known_hosts::all_fingerprints(db.conn()))
}

/// Forget a host's TOFU pin (so the next connection re-pins).
pub fn net_forget_host(host_id: String) -> Result<(), String> {
    with_db(|db| known_hosts::forget(db.conn(), &host_id))
}
