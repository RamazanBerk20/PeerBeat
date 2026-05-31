//! Track data-access: upsert from a scan, browse views, and fuzzy search.

use rusqlite::{params, Connection, OptionalExtension};
use serde::{Deserialize, Serialize};

/// A track as produced by the scanner ([`crate::library`]).
#[derive(Debug, Clone, Default)]
pub struct NewTrack {
    pub path: String,
    pub normalized_path: String,
    pub content_hash: Option<String>,
    pub title: String,
    pub artists: Vec<String>,
    pub album: Option<String>,
    pub album_artist: Option<String>,
    pub genres: Vec<String>,
    pub year: Option<i64>,
    pub track_no: Option<i64>,
    pub disc_no: Option<i64>,
    pub duration_ms: i64,
    pub codec: String,
    pub bitrate: Option<i64>,
    pub sample_rate: Option<i64>,
    pub channels: Option<i64>,
    pub replaygain_track_db: Option<f64>,
    pub replaygain_album_db: Option<f64>,
    pub file_size: i64,
    pub mtime_ns: i64,
    pub has_lyrics: bool,
    pub added_at: i64,
}

/// A track row shaped for display lists (artist/album flattened to text).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TrackRow {
    pub id: i64,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub album_id: Option<i64>,
    pub duration_ms: i64,
    pub year: Option<i64>,
    pub rating: i64,
    pub played_count: i64,
    pub path: String,
    /// On-disk path of the album's cached cover image, if any.
    pub art_path: Option<String>,
    /// ReplayGain track/album gain in dB (for volume normalization).
    pub replaygain_track_db: Option<f64>,
    pub replaygain_album_db: Option<f64>,
}

// The trailing `art_path` is a correlated subquery on the already-joined `al`
// alias, so every caller's FROM clause stays unchanged (no extra join needed).
pub(crate) const SELECT_ROW: &str = "
SELECT t.id, t.title,
  COALESCE((SELECT group_concat(a.name, ', ')
            FROM track_artists ta JOIN artists a ON a.id = ta.artist_id
            WHERE ta.track_id = t.id AND ta.role = 'main'), '') AS artist,
  COALESCE(al.title, '') AS album,
  t.album_id, t.duration_ms, t.year, t.rating, t.played_count, t.path,
  (SELECT ac.file_path FROM art_cache ac WHERE ac.id = al.art_id) AS art_path,
  t.replaygain_track_db, t.replaygain_album_db
FROM ";

pub(crate) fn map_row(r: &rusqlite::Row<'_>) -> rusqlite::Result<TrackRow> {
    Ok(TrackRow {
        id: r.get(0)?,
        title: r.get(1)?,
        artist: r.get(2)?,
        album: r.get(3)?,
        album_id: r.get(4)?,
        duration_ms: r.get(5)?,
        year: r.get(6)?,
        rating: r.get(7)?,
        played_count: r.get(8)?,
        path: r.get(9)?,
        art_path: r.get(10)?,
        replaygain_track_db: r.get(11)?,
        replaygain_album_db: r.get(12)?,
    })
}

fn get_or_create(
    conn: &Connection,
    sql_sel: &str,
    sql_ins: &str,
    key: &str,
) -> rusqlite::Result<i64> {
    if let Some(id) = conn
        .query_row(sql_sel, [key], |r| r.get::<_, i64>(0))
        .optional()?
    {
        return Ok(id);
    }
    conn.execute(sql_ins, [key])?;
    Ok(conn.last_insert_rowid())
}

fn artist_id(conn: &Connection, name: &str) -> rusqlite::Result<i64> {
    get_or_create(
        conn,
        "SELECT id FROM artists WHERE name = ?1",
        "INSERT INTO artists(name, sort_name) VALUES (?1, ?1)",
        name,
    )
}

fn genre_id(conn: &Connection, name: &str) -> rusqlite::Result<i64> {
    get_or_create(
        conn,
        "SELECT id FROM genres WHERE name = ?1",
        "INSERT INTO genres(name) VALUES (?1)",
        name,
    )
}

fn album_id(
    conn: &Connection,
    title: &str,
    album_artist: Option<i64>,
    year: Option<i64>,
) -> rusqlite::Result<i64> {
    if let Some(id) = conn
        .query_row(
            "SELECT id FROM albums WHERE title = ?1 AND album_artist_id IS ?2",
            params![title, album_artist],
            |r| r.get::<_, i64>(0),
        )
        .optional()?
    {
        return Ok(id);
    }
    conn.execute(
        "INSERT INTO albums(title, album_artist_id, year, sort_title) VALUES (?1, ?2, ?3, ?1)",
        params![title, album_artist, year],
    )?;
    Ok(conn.last_insert_rowid())
}

/// Insert or update a track (keyed by `normalized_path`) and refresh its
/// artist/genre joins, album link, and the FTS row. Returns the track id.
pub fn upsert_track(conn: &Connection, t: &NewTrack) -> rusqlite::Result<i64> {
    let album_artist_id = match &t.album_artist {
        Some(a) if !a.is_empty() => Some(artist_id(conn, a)?),
        _ => None,
    };
    let album = match &t.album {
        Some(a) if !a.is_empty() => Some(album_id(conn, a, album_artist_id, t.year)?),
        _ => None,
    };

    conn.execute(
        "INSERT INTO tracks
            (path, normalized_path, content_hash, title, album_id, track_no, disc_no,
             year, duration_ms, codec, bitrate, sample_rate, channels,
             replaygain_track_db, replaygain_album_db, file_size, mtime_ns, has_lyrics, added_at)
         VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11,?12,?13,?14,?15,?16,?17,?18,?19)
         ON CONFLICT(normalized_path) DO UPDATE SET
            path=excluded.path, content_hash=excluded.content_hash, title=excluded.title,
            album_id=excluded.album_id, track_no=excluded.track_no, disc_no=excluded.disc_no,
            year=excluded.year, duration_ms=excluded.duration_ms, codec=excluded.codec,
            bitrate=excluded.bitrate, sample_rate=excluded.sample_rate, channels=excluded.channels,
            replaygain_track_db=excluded.replaygain_track_db,
            replaygain_album_db=excluded.replaygain_album_db,
            file_size=excluded.file_size, mtime_ns=excluded.mtime_ns, has_lyrics=excluded.has_lyrics",
        params![
            t.path, t.normalized_path, t.content_hash, t.title, album, t.track_no, t.disc_no,
            t.year, t.duration_ms, t.codec, t.bitrate, t.sample_rate, t.channels,
            t.replaygain_track_db, t.replaygain_album_db, t.file_size, t.mtime_ns,
            t.has_lyrics as i64, t.added_at,
        ],
    )?;
    let id: i64 = conn.query_row(
        "SELECT id FROM tracks WHERE normalized_path = ?1",
        [&t.normalized_path],
        |r| r.get(0),
    )?;

    // refresh joins
    conn.execute("DELETE FROM track_artists WHERE track_id = ?1", [id])?;
    for name in t.artists.iter().filter(|s| !s.is_empty()) {
        let aid = artist_id(conn, name)?;
        conn.execute(
            "INSERT OR IGNORE INTO track_artists(track_id, artist_id, role) VALUES (?1, ?2, 'main')",
            params![id, aid],
        )?;
    }
    conn.execute("DELETE FROM track_genres WHERE track_id = ?1", [id])?;
    for name in t.genres.iter().filter(|s| !s.is_empty()) {
        let gid = genre_id(conn, name)?;
        conn.execute(
            "INSERT OR IGNORE INTO track_genres(track_id, genre_id) VALUES (?1, ?2)",
            params![id, gid],
        )?;
    }

    // refresh FTS (store-its-own-copy; rowid == track id)
    let artist_text = t.artists.join(", ");
    let genre_text = t.genres.join(", ");
    conn.execute("DELETE FROM tracks_fts WHERE rowid = ?1", [id])?;
    conn.execute(
        "INSERT INTO tracks_fts(rowid, title, artist, album, genre) VALUES (?1,?2,?3,?4,?5)",
        params![
            id,
            t.title,
            artist_text,
            t.album.clone().unwrap_or_default(),
            genre_text
        ],
    )?;

    Ok(id)
}

/// Look up a track id by its normalized path (for playlist-file matching).
pub fn id_by_path(conn: &Connection, normalized_path: &str) -> rusqlite::Result<Option<i64>> {
    conn.query_row(
        "SELECT id FROM tracks WHERE normalized_path = ?1",
        [normalized_path],
        |r| r.get(0),
    )
    .optional()
}

/// Fetch a single track by id (e.g. to restore the resume bookmark).
pub fn track_by_id(conn: &Connection, id: i64) -> rusqlite::Result<Option<TrackRow>> {
    let sql =
        format!("{SELECT_ROW} tracks t LEFT JOIN albums al ON al.id = t.album_id WHERE t.id = ?1");
    conn.query_row(&sql, params![id], map_row).optional()
}

/// Browse all songs, ordered by title, paginated.
pub fn browse_songs(conn: &Connection, limit: i64, offset: i64) -> rusqlite::Result<Vec<TrackRow>> {
    let sql = format!(
        "{SELECT_ROW} tracks t LEFT JOIN albums al ON al.id = t.album_id \
         ORDER BY t.title COLLATE NOCASE LIMIT ?1 OFFSET ?2"
    );
    let mut stmt = conn.prepare(&sql)?;
    let rows = stmt.query_map(params![limit, offset], map_row)?;
    rows.collect()
}

/// Build a trigram-safe FTS query: keep whitespace tokens of length >= 3, quote
/// each as a literal. Returns None if nothing usable (caller does LIKE fallback).
fn fts_query(input: &str) -> Option<String> {
    let parts: Vec<String> = input
        .split_whitespace()
        .filter(|t| t.chars().count() >= 3)
        .map(|t| format!("\"{}\"", t.replace('"', "\"\"")))
        .collect();
    if parts.is_empty() {
        None
    } else {
        Some(parts.join(" "))
    }
}

/// Fuzzy search across title/artist/album/genre. Uses FTS5 trigram + bm25 for
/// queries with a >= 3-char token; otherwise a folded LIKE scan.
pub fn search_tracks(
    conn: &Connection,
    query: &str,
    limit: i64,
) -> rusqlite::Result<Vec<TrackRow>> {
    match fts_query(query) {
        Some(q) => {
            let sql = format!(
                "{SELECT_ROW} tracks_fts \
                 JOIN tracks t ON t.id = tracks_fts.rowid \
                 LEFT JOIN albums al ON al.id = t.album_id \
                 WHERE tracks_fts MATCH ?1 ORDER BY bm25(tracks_fts) LIMIT ?2"
            );
            let mut stmt = conn.prepare(&sql)?;
            let rows = stmt.query_map(params![q, limit], map_row)?;
            rows.collect()
        }
        None => {
            let like = format!("%{}%", query.to_lowercase());
            let sql = format!(
                "{SELECT_ROW} tracks t LEFT JOIN albums al ON al.id = t.album_id \
                 WHERE lower(t.title) LIKE ?1 OR lower(COALESCE(al.title,'')) LIKE ?1 \
                 ORDER BY t.title COLLATE NOCASE LIMIT ?2"
            );
            let mut stmt = conn.prepare(&sql)?;
            let rows = stmt.query_map(params![like, limit], map_row)?;
            rows.collect()
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::Db;

    fn sample(path: &str, title: &str, artist: &str, album: &str) -> NewTrack {
        NewTrack {
            path: path.into(),
            normalized_path: path.into(),
            title: title.into(),
            artists: vec![artist.into()],
            album: Some(album.into()),
            album_artist: Some(artist.into()),
            genres: vec!["Electronic".into()],
            duration_ms: 200_000,
            codec: "flac".into(),
            added_at: 1,
            ..Default::default()
        }
    }

    #[test]
    fn upsert_is_idempotent_and_links_metadata() {
        let db = Db::open_in_memory().unwrap();
        let c = db.conn();
        let id1 = upsert_track(c, &sample("/m/a.flac", "Outro", "M83", "Hurry Up")).unwrap();
        let id2 = upsert_track(c, &sample("/m/a.flac", "Outro", "M83", "Hurry Up")).unwrap();
        assert_eq!(id1, id2, "same path must upsert, not duplicate");

        let n: i64 = c
            .query_row("SELECT count(*) FROM tracks", [], |r| r.get(0))
            .unwrap();
        assert_eq!(n, 1);
        let artist: String = c
            .query_row(
                "SELECT a.name FROM track_artists ta JOIN artists a ON a.id = ta.artist_id \
                 WHERE ta.track_id = ?1",
                [id1],
                |r| r.get(0),
            )
            .unwrap();
        assert_eq!(artist, "M83");
    }

    #[test]
    fn browse_and_search() {
        let db = Db::open_in_memory().unwrap();
        let c = db.conn();
        upsert_track(c, &sample("/m/1.flac", "Midnight City", "M83", "Hurry Up")).unwrap();
        upsert_track(c, &sample("/m/2.flac", "Reunion", "M83", "Hurry Up")).unwrap();

        let all = browse_songs(c, 50, 0).unwrap();
        assert_eq!(all.len(), 2);
        assert_eq!(all[0].title, "Midnight City"); // alphabetical
        assert_eq!(all[0].artist, "M83");

        // trigram substring
        let hits = search_tracks(c, "nigh", 10).unwrap();
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].title, "Midnight City");

        // <3-char query -> LIKE fallback (matches album 'Hurry Up' via title? no;
        // 'Re' matches 'Reunion' title)
        let short = search_tracks(c, "Re", 10).unwrap();
        assert!(short.iter().any(|r| r.title == "Reunion"));
    }
}
