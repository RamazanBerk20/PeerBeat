//! Library source folders — the roots the user has scanned. Persisted so they
//! can be re-scanned (and, later, watched) and managed in the UI.

use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FolderRow {
    pub id: i64,
    pub path: String,
    pub is_watched: bool,
    pub added_at: i64,
}

/// Remember a scanned root (idempotent by path).
pub fn add(conn: &Connection, path: &str, now_ms: i64) -> rusqlite::Result<i64> {
    conn.execute(
        "INSERT INTO folders(path, added_at) VALUES (?1, ?2)
         ON CONFLICT(path) DO NOTHING",
        params![path, now_ms],
    )?;
    conn.query_row("SELECT id FROM folders WHERE path = ?1", [path], |r| {
        r.get(0)
    })
}

pub fn list(conn: &Connection) -> rusqlite::Result<Vec<FolderRow>> {
    let mut stmt = conn.prepare(
        "SELECT id, path, is_watched, added_at FROM folders ORDER BY path COLLATE NOCASE",
    )?;
    let rows = stmt.query_map([], |r| {
        Ok(FolderRow {
            id: r.get(0)?,
            path: r.get(1)?,
            is_watched: r.get::<_, i64>(2)? != 0,
            added_at: r.get(3)?,
        })
    })?;
    rows.collect()
}

/// Forget a folder and remove the tracks that live under it.
pub fn remove(conn: &Connection, id: i64) -> rusqlite::Result<()> {
    let path: Option<String> = conn
        .query_row("SELECT path FROM folders WHERE id = ?1", [id], |r| r.get(0))
        .ok();
    if let Some(p) = path {
        crate::library::scan::delete_under_root(conn, std::path::Path::new(&p))?;
    }
    conn.execute("DELETE FROM folders WHERE id = ?1", [id])?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::Db;

    #[test]
    fn add_is_idempotent_and_lists() {
        let db = Db::open_in_memory().unwrap();
        let c = db.conn();
        let a = add(c, "/music", 1).unwrap();
        let b = add(c, "/music", 2).unwrap();
        assert_eq!(a, b, "same path must not duplicate");
        add(c, "/other", 3).unwrap();
        let all = list(c).unwrap();
        assert_eq!(all.len(), 2);
        assert_eq!(all[0].path, "/music"); // alphabetical
        assert!(all[0].is_watched);

        remove(c, a).unwrap();
        assert_eq!(list(c).unwrap().len(), 1);
    }
}
