//! Play tracking and the auto-generated lists — Recently Played, Most Played,
//! Never Played, and Favorites. `mark_played` is called when a track starts; the
//! list queries feed the library UI's "auto playlists" (and `played_count` /
//! `last_played_at` feed smart-playlist rules).

use crate::db::tracks::{self, TrackRow};
use rusqlite::{params, Connection};

/// Record a play: bump the track's counter + last-played time and append a
/// history row. Best-effort — callers ignore errors.
pub fn mark_played(conn: &Connection, track_id: i64, now_ms: i64) -> rusqlite::Result<()> {
    conn.execute(
        "UPDATE tracks SET played_count = played_count + 1, last_played_at = ?2 WHERE id = ?1",
        params![track_id, now_ms],
    )?;
    conn.execute(
        "INSERT INTO play_history(track_id, played_at, ms_played) VALUES (?1, ?2, 0)",
        params![track_id, now_ms],
    )?;
    Ok(())
}

/// Run a `SELECT_ROW` list query against `tracks t` with the given `WHERE/ORDER`
/// tail and a bound `LIMIT`.
fn list(conn: &Connection, tail: &str, limit: i64) -> rusqlite::Result<Vec<TrackRow>> {
    let sql = format!(
        "{} tracks t LEFT JOIN albums al ON al.id = t.album_id {tail} LIMIT ?1",
        tracks::SELECT_ROW
    );
    let mut stmt = conn.prepare(&sql)?;
    let rows = stmt.query_map([limit.max(1)], tracks::map_row)?;
    rows.collect()
}

/// Tracks most recently played (newest first).
pub fn recently_played(conn: &Connection, limit: i64) -> rusqlite::Result<Vec<TrackRow>> {
    list(
        conn,
        "WHERE t.last_played_at IS NOT NULL ORDER BY t.last_played_at DESC",
        limit,
    )
}

/// Most-played tracks (played at least once).
pub fn most_played(conn: &Connection, limit: i64) -> rusqlite::Result<Vec<TrackRow>> {
    list(
        conn,
        "WHERE t.played_count > 0 ORDER BY t.played_count DESC, t.last_played_at DESC",
        limit,
    )
}

/// Never-played tracks (added but not yet played), newest first.
pub fn never_played(conn: &Connection, limit: i64) -> rusqlite::Result<Vec<TrackRow>> {
    list(
        conn,
        "WHERE t.played_count = 0 ORDER BY t.added_at DESC",
        limit,
    )
}

// ── Favorites ────────────────────────────────────────────────────────────────

/// Add or remove a favorite.
pub fn set_favorite(
    conn: &Connection,
    track_id: i64,
    on: bool,
    now_ms: i64,
) -> rusqlite::Result<()> {
    if on {
        conn.execute(
            "INSERT OR IGNORE INTO favorites(track_id, added_at) VALUES (?1, ?2)",
            params![track_id, now_ms],
        )?;
    } else {
        conn.execute("DELETE FROM favorites WHERE track_id = ?1", [track_id])?;
    }
    Ok(())
}

pub fn is_favorite(conn: &Connection, track_id: i64) -> rusqlite::Result<bool> {
    let n: i64 = conn.query_row(
        "SELECT count(*) FROM favorites WHERE track_id = ?1",
        [track_id],
        |r| r.get(0),
    )?;
    Ok(n > 0)
}

/// Favorited tracks, most-recently-favorited first.
pub fn favorites(conn: &Connection, limit: i64) -> rusqlite::Result<Vec<TrackRow>> {
    let sql = format!(
        "{} favorites f JOIN tracks t ON t.id = f.track_id \
         LEFT JOIN albums al ON al.id = t.album_id ORDER BY f.added_at DESC LIMIT ?1",
        tracks::SELECT_ROW
    );
    let mut stmt = conn.prepare(&sql)?;
    let rows = stmt.query_map([limit.max(1)], tracks::map_row)?;
    rows.collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::tracks::{upsert_track, NewTrack};
    use crate::db::Db;

    fn track(conn: &Connection, id: i64) -> i64 {
        upsert_track(
            conn,
            &NewTrack {
                path: format!("/m/{id}.flac"),
                normalized_path: format!("/m/{id}.flac"),
                title: format!("T{id}"),
                added_at: id, // newer id == newer add
                ..Default::default()
            },
        )
        .unwrap()
    }

    #[test]
    fn plays_drive_recent_most_never() {
        let db = Db::open_in_memory().unwrap();
        let c = db.conn();
        let a = track(c, 1);
        let b = track(c, 2);
        let _never = track(c, 3);

        mark_played(c, a, 100).unwrap();
        mark_played(c, b, 200).unwrap();
        mark_played(c, b, 300).unwrap(); // b played twice, more recently

        let recent = recently_played(c, 10).unwrap();
        assert_eq!(recent.first().unwrap().title, "T2"); // b most recent
        let most = most_played(c, 10).unwrap();
        assert_eq!(most.first().unwrap().title, "T2"); // b has 2 plays
        let never = never_played(c, 10).unwrap();
        assert_eq!(never.len(), 1);
        assert_eq!(never[0].title, "T3");
    }

    #[test]
    fn favorites_toggle_and_list() {
        let db = Db::open_in_memory().unwrap();
        let c = db.conn();
        let a = track(c, 1);
        assert!(!is_favorite(c, a).unwrap());
        set_favorite(c, a, true, 10).unwrap();
        assert!(is_favorite(c, a).unwrap());
        set_favorite(c, a, true, 10).unwrap(); // idempotent
        assert_eq!(favorites(c, 10).unwrap().len(), 1);
        set_favorite(c, a, false, 10).unwrap();
        assert!(!is_favorite(c, a).unwrap());
        assert!(favorites(c, 10).unwrap().is_empty());
    }
}
