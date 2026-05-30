//! Manual playlist data access.

use crate::db::tracks::{self, TrackRow};
use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlaylistRow {
    pub id: i64,
    pub name: String,
    pub track_count: i64,
    pub sort_order: i64,
    pub created_at: i64,
    pub updated_at: i64,
}

pub fn list(conn: &Connection) -> rusqlite::Result<Vec<PlaylistRow>> {
    let mut stmt = conn.prepare(
        "SELECT p.id, p.name, count(pi.track_id) AS track_count,
                p.sort_order, p.created_at, p.updated_at
         FROM playlists p
         LEFT JOIN playlist_items pi ON pi.playlist_id = p.id
         GROUP BY p.id
         ORDER BY p.sort_order, p.name COLLATE NOCASE",
    )?;
    let rows = stmt.query_map([], |r| {
        Ok(PlaylistRow {
            id: r.get(0)?,
            name: r.get(1)?,
            track_count: r.get(2)?,
            sort_order: r.get(3)?,
            created_at: r.get(4)?,
            updated_at: r.get(5)?,
        })
    })?;
    rows.collect()
}

pub fn create(conn: &Connection, name: &str, now_ms: i64) -> rusqlite::Result<i64> {
    let sort_order: i64 = conn.query_row(
        "SELECT COALESCE(max(sort_order), -1) + 1 FROM playlists",
        [],
        |r| r.get(0),
    )?;
    conn.execute(
        "INSERT INTO playlists(name, created_at, updated_at, sort_order)
         VALUES (?1, ?2, ?2, ?3)",
        params![name.trim(), now_ms, sort_order],
    )?;
    Ok(conn.last_insert_rowid())
}

pub fn rename(
    conn: &Connection,
    playlist_id: i64,
    name: &str,
    now_ms: i64,
) -> rusqlite::Result<()> {
    conn.execute(
        "UPDATE playlists SET name = ?2, updated_at = ?3 WHERE id = ?1",
        params![playlist_id, name.trim(), now_ms],
    )?;
    Ok(())
}

pub fn delete(conn: &Connection, playlist_id: i64) -> rusqlite::Result<()> {
    conn.execute("DELETE FROM playlists WHERE id = ?1", [playlist_id])?;
    Ok(())
}

pub fn duplicate(
    conn: &Connection,
    playlist_id: i64,
    name: &str,
    now_ms: i64,
) -> rusqlite::Result<i64> {
    let new_id = create(conn, name, now_ms)?;
    conn.execute(
        "INSERT INTO playlist_items(playlist_id, track_id, position)
         SELECT ?2, track_id, position
         FROM playlist_items
         WHERE playlist_id = ?1
         ORDER BY position",
        params![playlist_id, new_id],
    )?;
    Ok(new_id)
}

pub fn tracks(conn: &Connection, playlist_id: i64) -> rusqlite::Result<Vec<TrackRow>> {
    let sql = format!(
        "{} playlist_items pi
         JOIN tracks t ON t.id = pi.track_id
         LEFT JOIN albums al ON al.id = t.album_id
         WHERE pi.playlist_id = ?1
         ORDER BY pi.position",
        tracks::SELECT_ROW
    );
    let mut stmt = conn.prepare(&sql)?;
    let rows = stmt.query_map([playlist_id], tracks::map_row)?;
    rows.collect()
}

pub fn add_tracks(
    conn: &Connection,
    playlist_id: i64,
    track_ids: &[i64],
    now_ms: i64,
) -> rusqlite::Result<()> {
    let tx = conn.unchecked_transaction()?;
    let base: i64 = tx.query_row(
        "SELECT COALESCE(max(position), -1) + 1
         FROM playlist_items
         WHERE playlist_id = ?1",
        [playlist_id],
        |r| r.get(0),
    )?;
    {
        let mut stmt = tx.prepare(
            "INSERT INTO playlist_items(playlist_id, track_id, position) VALUES (?1, ?2, ?3)",
        )?;
        for (i, &track_id) in track_ids.iter().enumerate() {
            stmt.execute(params![playlist_id, track_id, base + i as i64])?;
        }
    }
    touch(&tx, playlist_id, now_ms)?;
    tx.commit()
}

pub fn remove_position(
    conn: &Connection,
    playlist_id: i64,
    position: i64,
    now_ms: i64,
) -> rusqlite::Result<()> {
    let tx = conn.unchecked_transaction()?;
    tx.execute(
        "DELETE FROM playlist_items WHERE playlist_id = ?1 AND position = ?2",
        params![playlist_id, position],
    )?;
    compact_positions(&tx, playlist_id)?;
    touch(&tx, playlist_id, now_ms)?;
    tx.commit()
}

pub fn reorder_tracks(
    conn: &Connection,
    playlist_id: i64,
    track_ids: &[i64],
    now_ms: i64,
) -> rusqlite::Result<()> {
    let tx = conn.unchecked_transaction()?;
    replace_items(&tx, playlist_id, track_ids)?;
    touch(&tx, playlist_id, now_ms)?;
    tx.commit()
}

/// Replace all items of a playlist with `track_ids` at compact positions `0..n`.
/// Must be called inside a transaction (does DELETE-all + re-INSERT).
fn replace_items(conn: &Connection, playlist_id: i64, track_ids: &[i64]) -> rusqlite::Result<()> {
    conn.execute(
        "DELETE FROM playlist_items WHERE playlist_id = ?1",
        [playlist_id],
    )?;
    let mut stmt = conn.prepare(
        "INSERT INTO playlist_items(playlist_id, track_id, position) VALUES (?1, ?2, ?3)",
    )?;
    for (position, &track_id) in track_ids.iter().enumerate() {
        stmt.execute(params![playlist_id, track_id, position as i64])?;
    }
    Ok(())
}

fn compact_positions(conn: &Connection, playlist_id: i64) -> rusqlite::Result<()> {
    let ids: Vec<i64> = {
        let mut stmt = conn.prepare(
            "SELECT track_id FROM playlist_items WHERE playlist_id = ?1 ORDER BY position",
        )?;
        let rows = stmt.query_map([playlist_id], |r| r.get(0))?;
        rows.collect::<rusqlite::Result<Vec<i64>>>()?
    };
    replace_items(conn, playlist_id, &ids)
}

fn touch(conn: &Connection, playlist_id: i64, now_ms: i64) -> rusqlite::Result<()> {
    conn.execute(
        "UPDATE playlists SET updated_at = ?2 WHERE id = ?1",
        params![playlist_id, now_ms],
    )?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::tracks::{upsert_track, NewTrack};
    use crate::db::Db;

    fn add_track(conn: &Connection, id: i64, title: &str) -> i64 {
        upsert_track(
            conn,
            &NewTrack {
                path: format!("/m/{id}.flac"),
                normalized_path: format!("/m/{id}.flac"),
                title: title.into(),
                added_at: 1,
                ..Default::default()
            },
        )
        .unwrap()
    }

    #[test]
    fn create_add_reorder_duplicate_delete() {
        let db = Db::open_in_memory().unwrap();
        let c = db.conn();
        let a = add_track(c, 1, "A");
        let b = add_track(c, 2, "B");
        let p = create(c, "Road", 10).unwrap();
        add_tracks(c, p, &[a, b], 11).unwrap();

        let rows = tracks(c, p).unwrap();
        assert_eq!(
            rows.iter().map(|t| t.title.as_str()).collect::<Vec<_>>(),
            ["A", "B"]
        );

        reorder_tracks(c, p, &[b, a], 12).unwrap();
        let rows = tracks(c, p).unwrap();
        assert_eq!(
            rows.iter().map(|t| t.title.as_str()).collect::<Vec<_>>(),
            ["B", "A"]
        );

        let copy = duplicate(c, p, "Road copy", 13).unwrap();
        assert_eq!(tracks(c, copy).unwrap().len(), 2);
        delete(c, p).unwrap();
        assert_eq!(list(c).unwrap().len(), 1);
    }
}
