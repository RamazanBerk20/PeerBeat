//! A lightweight record of what peers stream/download from this host, so the
//! host UI can show recent activity ("who streamed what") and revoke access.
//! One row per stream/download request; we don't track byte progress or an end
//! time (the server streams the body opaquely), so this is an activity log, not
//! a live transfer monitor.

use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};

/// A recent transfer, joined with the track title for display.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransferRow {
    pub peer: String,
    pub track_id: Option<i64>,
    pub title: String,
    /// `"stream"` | `"download"`.
    pub kind: String,
    pub at: i64,
}

/// Record one stream/download request. Best-effort: callers ignore errors.
pub fn record(
    conn: &Connection,
    peer: &str,
    track_id: i64,
    kind: &str,
    now_ms: i64,
) -> rusqlite::Result<()> {
    conn.execute(
        "INSERT INTO transfer_log(peer_id, track_id, kind, started_at, state)
         VALUES (?1, ?2, ?3, ?4, 'done')",
        params![peer, track_id, kind, now_ms],
    )?;
    Ok(())
}

/// The most recent `limit` transfers, newest first.
pub fn recent(conn: &Connection, limit: i64) -> rusqlite::Result<Vec<TransferRow>> {
    let mut stmt = conn.prepare(
        "SELECT tl.peer_id, tl.track_id, COALESCE(t.title, '(removed)'), tl.kind, tl.started_at
         FROM transfer_log tl
         LEFT JOIN tracks t ON t.id = tl.track_id
         ORDER BY tl.started_at DESC
         LIMIT ?1",
    )?;
    let rows = stmt.query_map([limit.max(1)], |r| {
        Ok(TransferRow {
            peer: r.get(0)?,
            track_id: r.get(1)?,
            title: r.get(2)?,
            kind: r.get(3)?,
            at: r.get(4)?,
        })
    })?;
    rows.collect()
}

/// Forget all recorded activity.
pub fn clear(conn: &Connection) -> rusqlite::Result<()> {
    conn.execute("DELETE FROM transfer_log", [])?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::tracks::{upsert_track, NewTrack};
    use crate::db::Db;

    #[test]
    fn records_and_lists_recent_newest_first() {
        let db = Db::open_in_memory().unwrap();
        let c = db.conn();
        let id = upsert_track(
            c,
            &NewTrack {
                path: "/m/1.flac".into(),
                normalized_path: "/m/1.flac".into(),
                title: "Song".into(),
                added_at: 1,
                ..Default::default()
            },
        )
        .unwrap();

        record(c, "10.0.0.5:5000", id, "stream", 100).unwrap();
        record(c, "10.0.0.6:6000", id, "download", 200).unwrap();
        let rows = recent(c, 10).unwrap();
        assert_eq!(rows.len(), 2);
        assert_eq!(rows[0].kind, "download"); // newest first
        assert_eq!(rows[0].title, "Song");
        assert_eq!(rows[1].peer, "10.0.0.5:5000");

        clear(c).unwrap();
        assert!(recent(c, 10).unwrap().is_empty());
    }
}
