//! Filesystem scanning with incremental change detection.
//!
//! A cheap `(size, mtime)` fingerprint gates re-parsing: unchanged files are
//! skipped instantly. Changed/new files are tag-read ([`super::metadata`]),
//! content-hashed, and upserted. The `xxh3` content hash (head+tail+size) is the
//! stable cross-peer track identity used for downloads and party matching.

use super::metadata::{is_audio, normalize_path, read_tags};
use crate::db::tracks::upsert_track;
use rusqlite::{Connection, OptionalExtension};
use serde::{Deserialize, Serialize};
use std::fs::{File, Metadata};
use std::io::{Read, Seek, SeekFrom};
use std::path::Path;
use walkdir::WalkDir;
use xxhash_rust::xxh3::Xxh3;

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ScanStats {
    pub added: usize,
    pub updated: usize,
    pub skipped: usize,
    pub errors: usize,
}

fn mtime_ns(md: &Metadata) -> i64 {
    md.modified()
        .ok()
        .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
        .map(|d| d.as_nanos() as i64)
        .unwrap_or(0)
}

/// `xxh3_64` of `[first 64 KiB ‖ last 64 KiB ‖ size]`, hex. Cheap + robust to
/// metadata-only edits and moves. The size is re-read from the open handle (not
/// trusted from the caller) so a concurrent truncation in the window between the
/// caller's `stat` and here can't make `read_exact` overshoot and silently drop
/// the hash via `.ok()`.
fn content_hash(path: &Path) -> std::io::Result<String> {
    const CHUNK: u64 = 64 * 1024;
    let mut f = File::open(path)?;
    let size = f.metadata()?.len();
    let mut h = Xxh3::new();
    if size <= 2 * CHUNK {
        let mut buf = Vec::with_capacity(size as usize);
        f.read_to_end(&mut buf)?;
        h.update(&buf);
    } else {
        let mut head = vec![0u8; CHUNK as usize];
        f.read_exact(&mut head)?;
        h.update(&head);
        f.seek(SeekFrom::End(-(CHUNK as i64)))?;
        let mut tail = vec![0u8; CHUNK as usize];
        f.read_exact(&mut tail)?;
        h.update(&tail);
    }
    h.update(&size.to_le_bytes());
    Ok(format!("{:016x}", h.digest()))
}

/// Recursively scan `root`, upserting new/changed audio files. Idempotent:
/// re-scanning an unchanged tree only does cheap stat checks. Embedded cover
/// art is extracted into `art_dir` (once per album) as a side effect.
pub fn scan_folder(
    conn: &Connection,
    root: &Path,
    added_at: i64,
    art_dir: &Path,
) -> anyhow::Result<ScanStats> {
    let mut stats = ScanStats::default();
    for entry in WalkDir::new(root)
        .follow_links(true)
        .into_iter()
        .filter_map(Result::ok)
    {
        if !entry.file_type().is_file() || !is_audio(entry.path()) {
            continue;
        }
        let path = entry.path();
        let md = match entry.metadata() {
            Ok(m) => m,
            Err(_) => {
                stats.errors += 1;
                continue;
            }
        };
        let size = md.len();
        let mt = mtime_ns(&md);
        let norm = normalize_path(path);

        let existing: Option<(i64, i64)> = conn
            .query_row(
                "SELECT file_size, mtime_ns FROM tracks WHERE normalized_path = ?1",
                [&norm],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .optional()?;
        if let Some((s, m)) = existing {
            if s == size as i64 && m == mt {
                stats.skipped += 1;
                continue;
            }
        }

        let was_new = existing.is_none();
        let mut nt = match read_tags(path, size as i64, mt, added_at) {
            Ok(nt) => nt,
            Err(_) => {
                stats.errors += 1;
                continue;
            }
        };
        nt.content_hash = content_hash(path).ok();
        let id = upsert_track(conn, &nt)?;
        super::art::link_album_art(conn, id, path, art_dir)?;
        if was_new {
            stats.added += 1;
        } else {
            stats.updated += 1;
        }
    }
    Ok(stats)
}

/// A `LIKE` pattern (for use with `ESCAPE '\'`) matching exactly the tracks
/// whose files live under `root`. The root is LIKE-escaped so that `_`/`%` in
/// the path are literal — otherwise removing a folder `test_1` could also match
/// (and delete) tracks under a sibling `testX1`. The trailing `/` ensures
/// `/m/Music` doesn't also match `/m/MusicVideos`.
fn under_root_like(root: &Path) -> String {
    let norm = normalize_path(root);
    let escaped = crate::db::escape_like(norm.trim_end_matches('/'));
    format!("{escaped}/%")
}

fn delete_track(conn: &Connection, id: i64) -> rusqlite::Result<()> {
    conn.execute("DELETE FROM tracks WHERE id = ?1", [id])?;
    // tracks_fts stores its own copy (not external-content) → delete explicitly.
    conn.execute("DELETE FROM tracks_fts WHERE rowid = ?1", [id])?;
    Ok(())
}

/// Delete every track whose file lives under `root` (used when forgetting a
/// library folder). Track-artist/genre joins cascade via the schema.
pub fn delete_under_root(conn: &Connection, root: &Path) -> rusqlite::Result<usize> {
    let like = under_root_like(root);
    let ids: Vec<i64> = {
        let mut stmt =
            conn.prepare("SELECT id FROM tracks WHERE normalized_path LIKE ?1 ESCAPE '\\'")?;
        let rows = stmt.query_map([&like], |r| r.get(0))?;
        rows.collect::<rusqlite::Result<_>>()?
    };
    for id in &ids {
        delete_track(conn, *id)?;
    }
    Ok(ids.len())
}

/// Remove DB tracks under `root` whose files no longer exist on disk. Safe
/// against an inaccessible/unmounted root: if walking the tree finds **no**
/// audio files at all, nothing is pruned (we assume the volume is missing,
/// not that every track was deleted).
pub fn prune_missing(conn: &Connection, root: &Path) -> rusqlite::Result<usize> {
    let mut present = std::collections::HashSet::new();
    for entry in WalkDir::new(root)
        .follow_links(true)
        .into_iter()
        .filter_map(Result::ok)
    {
        if entry.file_type().is_file() && is_audio(entry.path()) {
            present.insert(normalize_path(entry.path()));
        }
    }
    if present.is_empty() {
        return Ok(0); // inaccessible / empty root — do not prune
    }
    let like = under_root_like(root);
    let candidates: Vec<(i64, String)> = {
        let mut stmt = conn.prepare(
            "SELECT id, normalized_path FROM tracks WHERE normalized_path LIKE ?1 ESCAPE '\\'",
        )?;
        let rows = stmt.query_map([&like], |r| Ok((r.get(0)?, r.get(1)?)))?;
        rows.collect::<rusqlite::Result<_>>()?
    };
    let mut removed = 0;
    for (id, np) in candidates {
        if !present.contains(&np) {
            delete_track(conn, id)?;
            removed += 1;
        }
    }
    Ok(removed)
}

/// Re-read a single file's tags + properties and upsert it, preserving the
/// existing `added_at` when the track is already known (else `now_ms`). Used
/// after a tag write-back and (later) by the folder watcher.
pub fn rescan_file(
    conn: &Connection,
    path: &Path,
    art_dir: &Path,
    now_ms: i64,
) -> anyhow::Result<()> {
    let md = std::fs::metadata(path)?;
    let size = md.len();
    let mt = mtime_ns(&md);
    let norm = normalize_path(path);
    let added_at: i64 = conn
        .query_row(
            "SELECT added_at FROM tracks WHERE normalized_path = ?1",
            [&norm],
            |r| r.get(0),
        )
        .optional()?
        .unwrap_or(now_ms);
    let mut nt = read_tags(path, size as i64, mt, added_at)?;
    nt.content_hash = content_hash(path).ok();
    let id = upsert_track(conn, &nt)?;
    super::art::link_album_art(conn, id, path, art_dir)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::{tracks::search_tracks, Db};
    use std::io::Write;

    /// Write a minimal valid 16-bit PCM mono WAV of `~secs` seconds.
    fn write_wav(path: &Path, secs: u32) {
        let sample_rate: u32 = 8000;
        let byte_rate = sample_rate * 2;
        let data_len = byte_rate * secs;
        let mut f = File::create(path).unwrap();
        f.write_all(b"RIFF").unwrap();
        f.write_all(&(36 + data_len).to_le_bytes()).unwrap();
        f.write_all(b"WAVE").unwrap();
        f.write_all(b"fmt ").unwrap();
        f.write_all(&16u32.to_le_bytes()).unwrap();
        f.write_all(&1u16.to_le_bytes()).unwrap(); // PCM
        f.write_all(&1u16.to_le_bytes()).unwrap(); // mono
        f.write_all(&sample_rate.to_le_bytes()).unwrap();
        f.write_all(&byte_rate.to_le_bytes()).unwrap();
        f.write_all(&2u16.to_le_bytes()).unwrap(); // block align
        f.write_all(&16u16.to_le_bytes()).unwrap(); // bits
        f.write_all(b"data").unwrap();
        f.write_all(&data_len.to_le_bytes()).unwrap();
        f.write_all(&vec![0u8; data_len as usize]).unwrap();
    }

    fn unique_tmp() -> std::path::PathBuf {
        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let d = std::env::temp_dir().join(format!("peerbeat_scan_{nanos}"));
        std::fs::create_dir_all(&d).unwrap();
        d
    }

    #[test]
    fn scan_imports_and_is_incremental() {
        let dir = unique_tmp();
        write_wav(&dir.join("track1.wav"), 1);
        write_wav(&dir.join("track2.wav"), 2);
        std::fs::write(dir.join("cover.jpg"), b"not audio").unwrap();

        let db = Db::open_in_memory().unwrap();
        let s1 = scan_folder(db.conn(), &dir, 1, db.art_dir()).unwrap();
        assert_eq!(s1.added, 2, "two wavs imported, jpg ignored");
        assert_eq!(s1.errors, 0);

        // re-scan: nothing changed -> all skipped
        let s2 = scan_folder(db.conn(), &dir, 2, db.art_dir()).unwrap();
        assert_eq!(s2.added, 0);
        assert_eq!(s2.skipped, 2);

        // duration parsed from the WAV header (~1s and ~2s)
        let dur: i64 = db
            .conn()
            .query_row(
                "SELECT duration_ms FROM tracks WHERE normalized_path LIKE '%track2.wav'",
                [],
                |r| r.get(0),
            )
            .unwrap();
        assert!((1900..=2100).contains(&dur), "duration_ms was {dur}");

        // searchable by filename-derived title
        let hits = search_tracks(db.conn(), "track", 10).unwrap();
        assert_eq!(hits.len(), 2);

        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn prune_missing_removes_deleted_but_guards_empty_root() {
        let dir = unique_tmp();
        write_wav(&dir.join("a.wav"), 1);
        write_wav(&dir.join("b.wav"), 1);
        let db = Db::open_in_memory().unwrap();
        scan_folder(db.conn(), &dir, 1, db.art_dir()).unwrap();
        assert_eq!(
            db.conn()
                .query_row("SELECT count(*) FROM tracks", [], |r| r.get::<_, i64>(0))
                .unwrap(),
            2
        );

        // delete one file on disk → prune removes exactly that track
        std::fs::remove_file(dir.join("b.wav")).unwrap();
        let removed = prune_missing(db.conn(), &dir).unwrap();
        assert_eq!(removed, 1);
        assert_eq!(
            db.conn()
                .query_row("SELECT count(*) FROM tracks", [], |r| r.get::<_, i64>(0))
                .unwrap(),
            1
        );

        // wipe the rest → empty root is treated as inaccessible (no prune)
        std::fs::remove_file(dir.join("a.wav")).unwrap();
        assert_eq!(prune_missing(db.conn(), &dir).unwrap(), 0);
        assert_eq!(
            db.conn()
                .query_row("SELECT count(*) FROM tracks", [], |r| r.get::<_, i64>(0))
                .unwrap(),
            1,
            "must not prune when the root yields no audio files"
        );
        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn prune_does_not_match_underscore_sibling() {
        // A folder named `test_1` must not LIKE-match a sibling `testX1`
        // (underscore is a wildcard unless escaped) — else pruning one folder
        // would delete another's tracks.
        let dir = unique_tmp();
        let a = dir.join("test_1");
        let b = dir.join("testX1");
        std::fs::create_dir_all(&a).unwrap();
        std::fs::create_dir_all(&b).unwrap();
        write_wav(&a.join("a.wav"), 1);
        write_wav(&a.join("b.wav"), 1);
        write_wav(&b.join("c.wav"), 1);

        let db = Db::open_in_memory().unwrap();
        scan_folder(db.conn(), &dir, 1, db.art_dir()).unwrap();

        std::fs::remove_file(a.join("b.wav")).unwrap();
        let removed = prune_missing(db.conn(), &a).unwrap();
        assert_eq!(removed, 1, "only test_1/b.wav should be pruned");

        let sibling: i64 = db
            .conn()
            .query_row(
                "SELECT count(*) FROM tracks WHERE normalized_path LIKE '%testX1/c.wav'",
                [],
                |r| r.get(0),
            )
            .unwrap();
        assert_eq!(sibling, 1, "sibling folder track must survive");
        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn tag_write_back_updates_library() {
        use crate::library::metadata::{write_tags, TagEdit};
        let dir = unique_tmp();
        let f = dir.join("song.wav");
        write_wav(&f, 1);

        let db = Db::open_in_memory().unwrap();
        scan_folder(db.conn(), &dir, 1, db.art_dir()).unwrap();

        write_tags(
            &f,
            &TagEdit {
                title: "Edited Title".into(),
                artist: "New Artist".into(),
                album: "New Album".into(),
                year: Some(2021),
                ..Default::default()
            },
        )
        .unwrap();
        rescan_file(db.conn(), &f, db.art_dir(), 2).unwrap();

        let title: String = db
            .conn()
            .query_row(
                "SELECT title FROM tracks WHERE normalized_path LIKE '%song.wav'",
                [],
                |r| r.get(0),
            )
            .unwrap();
        assert_eq!(title, "Edited Title");

        let artist: String = db
            .conn()
            .query_row(
                "SELECT a.name FROM track_artists ta \
                 JOIN artists a ON a.id = ta.artist_id \
                 JOIN tracks t ON t.id = ta.track_id \
                 WHERE t.normalized_path LIKE '%song.wav'",
                [],
                |r| r.get(0),
            )
            .unwrap();
        assert_eq!(artist, "New Artist");

        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn content_hash_handles_large_files() {
        // A file larger than 2*CHUNK (128 KiB) exercises the head+tail+seek path;
        // the hash must be a stable 16-char hex digest.
        let dir = unique_tmp();
        let f = dir.join("big.wav");
        write_wav(&f, 12); // ~192 KiB of PCM + header, well over 128 KiB
        assert!(std::fs::metadata(&f).unwrap().len() > 2 * 64 * 1024);
        let h1 = content_hash(&f).unwrap();
        let h2 = content_hash(&f).unwrap();
        assert_eq!(h1.len(), 16);
        assert_eq!(h1, h2);
        std::fs::remove_dir_all(&dir).ok();
    }
}
