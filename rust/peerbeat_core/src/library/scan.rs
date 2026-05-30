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
/// metadata-only edits and moves.
fn content_hash(path: &Path, size: u64) -> std::io::Result<String> {
    const CHUNK: u64 = 64 * 1024;
    let mut f = File::open(path)?;
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
        nt.content_hash = content_hash(path, size).ok();
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
}
