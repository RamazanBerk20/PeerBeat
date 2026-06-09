//! Simple key/value settings store (the `settings` table). Used for
//! resume-from-position, EQ state, and user preferences.

use rusqlite::{params, Connection, OptionalExtension};

pub fn get(conn: &Connection, key: &str) -> rusqlite::Result<Option<String>> {
    conn.query_row("SELECT value FROM settings WHERE key = ?1", [key], |r| {
        r.get::<_, String>(0)
    })
    .optional()
}

pub fn set(conn: &Connection, key: &str, value: &str) -> rusqlite::Result<()> {
    conn.execute(
        "INSERT INTO settings(key, value) VALUES (?1, ?2)
         ON CONFLICT(key) DO UPDATE SET value = excluded.value",
        params![key, value],
    )?;
    // Mirror the UI language into the core so its own error messages localize
    // (the Flutter side persists the chosen locale under this key).
    if key == "ui.locale" {
        crate::i18n::set_locale(value);
    }
    Ok(())
}

/// Delete a setting (no-op if absent).
pub fn delete(conn: &Connection, key: &str) -> rusqlite::Result<()> {
    conn.execute("DELETE FROM settings WHERE key = ?1", [key])?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::Db;

    #[test]
    fn get_set_delete_roundtrip() {
        let db = Db::open_in_memory().unwrap();
        let c = db.conn();
        assert_eq!(get(c, "k").unwrap(), None);
        set(c, "k", "v1").unwrap();
        assert_eq!(get(c, "k").unwrap().as_deref(), Some("v1"));
        set(c, "k", "v2").unwrap();
        assert_eq!(get(c, "k").unwrap().as_deref(), Some("v2"));
        delete(c, "k").unwrap();
        assert_eq!(get(c, "k").unwrap(), None);
    }
}
