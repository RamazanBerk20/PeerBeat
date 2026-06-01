//! TOFU (trust-on-first-use) pin store for remembered LAN hosts. A host is
//! keyed by its stable `host_id`; the first time we connect we pin its
//! certificate fingerprint, and any later connection presenting a different
//! fingerprint is rejected (possible MITM).

use rusqlite::{params, Connection, OptionalExtension};

/// The pinned fingerprint for `host_id`, or `None` if never seen.
pub fn fingerprint(conn: &Connection, host_id: &str) -> rusqlite::Result<Option<String>> {
    conn.query_row(
        "SELECT spki_sha256 FROM known_hosts WHERE host_id = ?1",
        [host_id],
        |r| r.get(0),
    )
    .optional()
}

/// Every pinned fingerprint (used to gate the stream-download client, which
/// only has a URL, not a host id).
pub fn all_fingerprints(conn: &Connection) -> rusqlite::Result<Vec<String>> {
    let mut stmt = conn.prepare("SELECT spki_sha256 FROM known_hosts")?;
    let rows = stmt.query_map([], |r| r.get::<_, String>(0))?;
    rows.collect()
}

/// TOFU upsert: the first sighting pins `fp`; a later sighting must match it
/// (else `Err`); a match just refreshes `last_seen`/name.
pub fn remember(
    conn: &Connection,
    host_id: &str,
    name: &str,
    fp: &str,
    now_ms: i64,
) -> Result<(), String> {
    match fingerprint(conn, host_id).map_err(|e| e.to_string())? {
        None => {
            conn.execute(
                "INSERT INTO known_hosts(host_id, display_name, spki_sha256, first_seen_at, last_seen_at)
                 VALUES (?1, ?2, ?3, ?4, ?4)",
                params![host_id, name, fp, now_ms],
            )
            .map_err(|e| e.to_string())?;
            Ok(())
        }
        Some(pinned) if pinned == fp => {
            conn.execute(
                "UPDATE known_hosts SET last_seen_at = ?2, display_name = ?3 WHERE host_id = ?1",
                params![host_id, now_ms, name],
            )
            .map_err(|e| e.to_string())?;
            Ok(())
        }
        Some(_) => Err(format!(
            "certificate changed for host '{name}' — refusing to connect \
             (possible man-in-the-middle on this network)"
        )),
    }
}

/// Forget a host (clears its TOFU pin so the next connect re-pins).
pub fn forget(conn: &Connection, host_id: &str) -> rusqlite::Result<()> {
    conn.execute("DELETE FROM known_hosts WHERE host_id = ?1", [host_id])?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::Db;

    #[test]
    fn tofu_pins_then_detects_change() {
        let db = Db::open_in_memory().unwrap();
        let c = db.conn();
        assert_eq!(fingerprint(c, "h1").unwrap(), None);

        // first use pins
        remember(c, "h1", "Laptop", "aa", 1).unwrap();
        assert_eq!(fingerprint(c, "h1").unwrap().as_deref(), Some("aa"));

        // same fingerprint is fine (refreshes)
        remember(c, "h1", "Laptop", "aa", 2).unwrap();

        // a changed fingerprint is rejected
        assert!(remember(c, "h1", "Laptop", "bb", 3).is_err());
        assert_eq!(fingerprint(c, "h1").unwrap().as_deref(), Some("aa"));

        assert_eq!(all_fingerprints(c).unwrap(), vec!["aa".to_string()]);
        forget(c, "h1").unwrap();
        assert_eq!(fingerprint(c, "h1").unwrap(), None);
    }
}
