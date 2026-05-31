//! 10-band EQ preset DAO.

use rusqlite::types::Type;
use rusqlite::{params, Connection};

#[derive(Debug, Clone)]
pub struct EqPresetRow {
    pub id: i64,
    pub name: String,
    pub bands: Vec<f64>,
    pub preamp: f64,
    pub builtin: bool,
}

fn parse_bands(json: String) -> rusqlite::Result<Vec<f64>> {
    let bands: Vec<f64> = serde_json::from_str(&json)
        .map_err(|e| rusqlite::Error::FromSqlConversionFailure(2, Type::Text, e.into()))?;
    if bands.len() != 10 {
        return Err(rusqlite::Error::InvalidQuery);
    }
    Ok(bands)
}

fn encode_bands(bands: &[f64]) -> rusqlite::Result<String> {
    if bands.len() != 10 {
        return Err(rusqlite::Error::InvalidQuery);
    }
    let clamped: Vec<f64> = bands.iter().map(|g| g.clamp(-12.0, 12.0)).collect();
    serde_json::to_string(&clamped).map_err(|e| rusqlite::Error::ToSqlConversionFailure(e.into()))
}

fn row(r: &rusqlite::Row<'_>) -> rusqlite::Result<EqPresetRow> {
    Ok(EqPresetRow {
        id: r.get(0)?,
        name: r.get(1)?,
        bands: parse_bands(r.get(2)?)?,
        preamp: r.get::<_, f64>(3)?.clamp(-15.0, 15.0),
        builtin: r.get::<_, i64>(4)? != 0,
    })
}

pub fn list(conn: &Connection) -> rusqlite::Result<Vec<EqPresetRow>> {
    let mut stmt = conn.prepare(
        "SELECT id, name, bands, preamp, builtin
         FROM eq_presets
         ORDER BY builtin DESC, lower(name)",
    )?;
    let rows = stmt.query_map([], row)?.collect();
    rows
}

pub fn create(conn: &Connection, name: &str, bands: &[f64], preamp: f64) -> rusqlite::Result<i64> {
    let bands = encode_bands(bands)?;
    conn.execute(
        "INSERT INTO eq_presets(name, bands, preamp, builtin)
         VALUES (?1, ?2, ?3, 0)",
        params![name.trim(), bands, preamp.clamp(-15.0, 15.0)],
    )?;
    Ok(conn.last_insert_rowid())
}

pub fn update(
    conn: &Connection,
    preset_id: i64,
    name: &str,
    bands: &[f64],
    preamp: f64,
) -> rusqlite::Result<()> {
    let bands = encode_bands(bands)?;
    conn.execute(
        "UPDATE eq_presets
         SET name = ?2, bands = ?3, preamp = ?4
         WHERE id = ?1 AND builtin = 0",
        params![preset_id, name.trim(), bands, preamp.clamp(-15.0, 15.0)],
    )?;
    Ok(())
}

pub fn delete(conn: &Connection, preset_id: i64) -> rusqlite::Result<()> {
    conn.execute(
        "DELETE FROM eq_presets WHERE id = ?1 AND builtin = 0",
        [preset_id],
    )?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::Db;

    #[test]
    fn preset_roundtrip_clamps_and_lists() {
        let db = Db::open_in_memory().unwrap();
        let c = db.conn();
        let id = create(c, "V", &[13.0; 10], 20.0).unwrap();
        let all = list(c).unwrap();
        assert_eq!(all.len(), 1);
        assert_eq!(all[0].id, id);
        assert_eq!(all[0].bands, vec![12.0; 10]);
        assert_eq!(all[0].preamp, 15.0);
        update(c, id, "Flat", &[0.0; 10], 0.0).unwrap();
        let all = list(c).unwrap();
        assert_eq!(all[0].name, "Flat");
        delete(c, id).unwrap();
        assert!(list(c).unwrap().is_empty());
    }

    #[test]
    fn rejects_wrong_band_count() {
        let db = Db::open_in_memory().unwrap();
        assert!(create(db.conn(), "bad", &[0.0; 9], 0.0).is_err());
    }
}
