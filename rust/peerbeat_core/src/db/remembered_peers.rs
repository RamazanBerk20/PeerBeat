//! Remembered allow/deny decisions for the "approved peers" share mode.
//!
//! When a host approves (or denies) a peer and ticks "remember", the decision is
//! stored here keyed on `(host_id, peer_id)`. On the next connection the server
//! short-circuits the interactive prompt and honors the saved decision.

use rusqlite::{params, Connection, OptionalExtension};

/// The remembered decision for `(host_id, peer_id)`:
/// `Some(true)` = allow, `Some(false)` = deny, `None` = no record yet.
pub fn decision(conn: &Connection, host_id: &str, peer_id: &str) -> rusqlite::Result<Option<bool>> {
    let d: Option<String> = conn
        .query_row(
            "SELECT decision FROM remembered_peers WHERE host_id = ?1 AND peer_id = ?2",
            params![host_id, peer_id],
            |r| r.get(0),
        )
        .optional()?;
    Ok(d.map(|s| s == "allow"))
}

/// Persist (or replace) a decision for `(host_id, peer_id)`.
pub fn set(
    conn: &Connection,
    host_id: &str,
    peer_id: &str,
    allow: bool,
    now_ms: i64,
) -> rusqlite::Result<()> {
    conn.execute(
        "INSERT INTO remembered_peers(host_id, peer_id, decision, decided_at)
         VALUES (?1, ?2, ?3, ?4)
         ON CONFLICT(host_id, peer_id) DO UPDATE SET decision = ?3, decided_at = ?4",
        params![
            host_id,
            peer_id,
            if allow { "allow" } else { "deny" },
            now_ms
        ],
    )?;
    Ok(())
}

/// Forget a decision (so the peer is prompted again next time).
pub fn clear(conn: &Connection, host_id: &str, peer_id: &str) -> rusqlite::Result<()> {
    conn.execute(
        "DELETE FROM remembered_peers WHERE host_id = ?1 AND peer_id = ?2",
        params![host_id, peer_id],
    )?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::Db;

    #[test]
    fn remembers_allow_and_deny_and_clears() {
        let db = Db::open_in_memory().unwrap();
        let c = db.conn();
        assert_eq!(decision(c, "h1", "p1").unwrap(), None);

        set(c, "h1", "p1", true, 10).unwrap();
        assert_eq!(decision(c, "h1", "p1").unwrap(), Some(true));

        // upsert flips the decision in place
        set(c, "h1", "p1", false, 20).unwrap();
        assert_eq!(decision(c, "h1", "p1").unwrap(), Some(false));

        // scoping by host + peer is independent
        assert_eq!(decision(c, "h2", "p1").unwrap(), None);

        clear(c, "h1", "p1").unwrap();
        assert_eq!(decision(c, "h1", "p1").unwrap(), None);
    }
}
