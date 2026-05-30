//! Embedded cover-art extraction.
//!
//! During a scan we pull the first embedded picture out of a track via `lofty`,
//! content-hash the image bytes (`xxh3`) so identical art is stored once, write
//! it into the DB's `art/` cache dir as `<hash>.<ext>`, and link the album to
//! it. Extraction runs once per album (the first track that carries art wins);
//! everything here is best-effort, so a malformed or art-less file just leaves
//! the album with a UI placeholder.

use lofty::file::TaggedFileExt;
use lofty::picture::MimeType;
use rusqlite::{params, Connection, OptionalExtension};
use std::path::Path;
use xxhash_rust::xxh3::xxh3_64;

/// Extract the first embedded cover image from `path`, returning its raw bytes
/// and a file extension (e.g. `"jpg"`). `None` if the file carries no picture.
pub fn extract_cover(path: &Path) -> Option<(Vec<u8>, &'static str)> {
    let tagged = lofty::read_from_path(path).ok()?;
    let tag = tagged.primary_tag().or_else(|| tagged.first_tag())?;
    let pic = tag.pictures().first()?;
    // Map to an owned `&'static str` so the result doesn't borrow `tagged`.
    let ext = match pic.mime_type() {
        Some(MimeType::Png) => "png",
        Some(MimeType::Jpeg) => "jpg",
        Some(MimeType::Gif) => "gif",
        Some(MimeType::Bmp) => "bmp",
        Some(MimeType::Tiff) => "tif",
        _ => "img",
    };
    Some((pic.data().to_vec(), ext))
}

/// Ensure the album of a just-scanned track has cover art, extracting and
/// caching it on first sight. Best-effort: a no-op when `art_dir` is empty
/// (in-memory DB), the track has no album, or the album already has art.
pub fn link_album_art(
    conn: &Connection,
    track_id: i64,
    src: &Path,
    art_dir: &Path,
) -> rusqlite::Result<()> {
    if art_dir.as_os_str().is_empty() {
        return Ok(());
    }
    let album_id: Option<i64> = conn
        .query_row(
            "SELECT album_id FROM tracks WHERE id = ?1",
            [track_id],
            |r| r.get(0),
        )
        .optional()?
        .flatten();
    let Some(album_id) = album_id else {
        return Ok(());
    };
    // Extract art only once per album.
    let has_art: Option<i64> = conn
        .query_row("SELECT art_id FROM albums WHERE id = ?1", [album_id], |r| {
            r.get(0)
        })
        .optional()?
        .flatten();
    if has_art.is_some() {
        return Ok(());
    }

    let Some((bytes, ext)) = extract_cover(src) else {
        return Ok(());
    };
    let hash = format!("{:016x}", xxh3_64(&bytes));
    let file_path = art_dir.join(format!("{hash}.{ext}"));
    if !file_path.exists() && std::fs::write(&file_path, &bytes).is_err() {
        return Ok(()); // can't cache the image; leave the album art-less
    }
    let fp = file_path.to_string_lossy().to_string();
    let mime = format!("image/{ext}");
    conn.execute(
        "INSERT INTO art_cache(image_hash, file_path, mime) VALUES (?1, ?2, ?3)
         ON CONFLICT(image_hash) DO UPDATE SET file_path = excluded.file_path",
        params![hash, fp, mime],
    )?;
    let art_id: i64 = conn.query_row(
        "SELECT id FROM art_cache WHERE image_hash = ?1",
        [&hash],
        |r| r.get(0),
    )?;
    conn.execute(
        "UPDATE albums SET art_id = ?2 WHERE id = ?1",
        params![album_id, art_id],
    )?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::tracks::{browse_songs, upsert_track, NewTrack};
    use crate::db::Db;

    fn tmp_dir(tag: &str) -> std::path::PathBuf {
        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let d = std::env::temp_dir().join(format!("peerbeat_art_{tag}_{nanos}"));
        std::fs::create_dir_all(&d).unwrap();
        d
    }

    #[test]
    fn no_embedded_cover_leaves_album_artless() {
        let dir = tmp_dir("nocover");
        let db = Db::open(&dir.join("lib.db")).unwrap();
        // A non-audio "source": extract_cover returns None, link is a clean no-op.
        let src = dir.join("song.mp3");
        std::fs::write(&src, b"not really audio").unwrap();
        let id = upsert_track(
            db.conn(),
            &NewTrack {
                path: src.to_string_lossy().to_string(),
                normalized_path: src.to_string_lossy().to_string(),
                title: "X".into(),
                album: Some("A".into()),
                album_artist: Some("Y".into()),
                added_at: 1,
                ..Default::default()
            },
        )
        .unwrap();

        link_album_art(db.conn(), id, &src, db.art_dir()).unwrap();

        // The art_path subquery in SELECT_ROW resolves to NULL.
        let rows = browse_songs(db.conn(), 10, 0).unwrap();
        assert_eq!(rows.len(), 1);
        assert!(rows[0].art_path.is_none());
        std::fs::remove_dir_all(&dir).ok();
    }
}
