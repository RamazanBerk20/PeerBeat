//! Smart playlists: a small JSON rule set compiled to a **parameterized**,
//! column/operator-whitelisted SQL `WHERE` clause. Unknown fields/operators are
//! rejected (never concatenated into SQL) and every value is bound as a
//! parameter, so rules can't inject SQL.
//!
//! Rule JSON shape:
//! ```json
//! { "match": "all",
//!   "rules": [ {"field":"artist","op":"contains","value":"M83"},
//!              {"field":"year","op":"gte","value":"2010"} ] }
//! ```

use crate::db::tracks::{self, TrackRow};
use rusqlite::types::Value;
use rusqlite::{params_from_iter, Connection, OptionalExtension};
use serde::{Deserialize, Serialize};

const DAY_MS: i64 = 86_400_000;

#[derive(Debug, Deserialize)]
pub struct SmartQuery {
    #[serde(rename = "match", default = "default_match")]
    pub match_mode: String,
    #[serde(default)]
    pub rules: Vec<Rule>,
}

#[derive(Debug, Deserialize)]
pub struct Rule {
    pub field: String,
    pub op: String,
    #[serde(default)]
    pub value: String,
}

fn default_match() -> String {
    "all".to_string()
}

#[derive(Clone, Copy)]
enum Kind {
    Text,
    Num,
}

/// Whitelist: map a rule field to its SQL scalar expression + value kind.
/// Anything not listed here is rejected.
fn field_expr(field: &str) -> Option<(&'static str, Kind)> {
    let e = match field {
        "title" => ("t.title", Kind::Text),
        "album" => ("COALESCE(al.title,'')", Kind::Text),
        "artist" => (
            "COALESCE((SELECT group_concat(a.name, ', ') FROM track_artists ta \
             JOIN artists a ON a.id = ta.artist_id WHERE ta.track_id = t.id),'')",
            Kind::Text,
        ),
        "genre" => (
            "COALESCE((SELECT group_concat(g.name, ', ') FROM track_genres tg \
             JOIN genres g ON g.id = tg.genre_id WHERE tg.track_id = t.id),'')",
            Kind::Text,
        ),
        "year" => ("COALESCE(t.year,0)", Kind::Num),
        "rating" => ("t.rating", Kind::Num),
        "played_count" => ("t.played_count", Kind::Num),
        "duration_ms" => ("t.duration_ms", Kind::Num),
        "added_at" => ("t.added_at", Kind::Num),
        _ => return None,
    };
    Some(e)
}

fn rule_sql(rule: &Rule, now_ms: i64) -> Result<(String, Value), String> {
    let (expr, kind) =
        field_expr(&rule.field).ok_or_else(|| format!("unknown field '{}'", rule.field))?;
    match kind {
        Kind::Text => {
            let v = Value::Text(rule.value.clone());
            let sql = match rule.op.as_str() {
                "is" => format!("lower({expr}) = lower(?)"),
                "isNot" => format!("lower({expr}) <> lower(?)"),
                "contains" => format!("lower({expr}) LIKE '%'||lower(?)||'%'"),
                "notContains" => format!("lower({expr}) NOT LIKE '%'||lower(?)||'%'"),
                "startsWith" => format!("lower({expr}) LIKE lower(?)||'%'"),
                "endsWith" => format!("lower({expr}) LIKE '%'||lower(?)"),
                other => return Err(format!("unknown text op '{other}'")),
            };
            Ok((sql, v))
        }
        Kind::Num => {
            if rule.op == "inLastDays" {
                let days: i64 = rule
                    .value
                    .trim()
                    .parse()
                    .map_err(|_| format!("'{}' is not a number", rule.value))?;
                let threshold = now_ms - days.saturating_mul(DAY_MS);
                return Ok((format!("{expr} >= ?"), Value::Integer(threshold)));
            }
            let n: i64 = rule
                .value
                .trim()
                .parse()
                .map_err(|_| format!("'{}' is not a number", rule.value))?;
            let op = match rule.op.as_str() {
                "eq" => "=",
                "neq" => "<>",
                "gt" => ">",
                "lt" => "<",
                "gte" => ">=",
                "lte" => "<=",
                other => return Err(format!("unknown numeric op '{other}'")),
            };
            Ok((format!("{expr} {op} ?"), Value::Integer(n)))
        }
    }
}

/// Compile a query to `(where_sql, params)`. Empty rule set matches everything.
pub fn compile(q: &SmartQuery, now_ms: i64) -> Result<(String, Vec<Value>), String> {
    if q.rules.is_empty() {
        return Ok(("1=1".to_string(), Vec::new()));
    }
    let join = if q.match_mode.eq_ignore_ascii_case("any") {
        " OR "
    } else {
        " AND "
    };
    let mut clauses = Vec::with_capacity(q.rules.len());
    let mut params = Vec::with_capacity(q.rules.len());
    for r in &q.rules {
        let (c, p) = rule_sql(r, now_ms)?;
        clauses.push(format!("({c})"));
        params.push(p);
    }
    Ok((clauses.join(join), params))
}

/// Run a rule set (JSON) against the library, returning matching tracks.
pub fn tracks_for_rules(
    conn: &Connection,
    rule_json: &str,
    limit: Option<i64>,
    now_ms: i64,
) -> anyhow::Result<Vec<TrackRow>> {
    let q: SmartQuery = serde_json::from_str(rule_json)?;
    let (where_sql, params) = compile(&q, now_ms).map_err(|e| anyhow::anyhow!(e))?;
    let limit_clause = match limit {
        Some(n) if n > 0 => format!(" LIMIT {n}"),
        _ => String::new(),
    };
    let sql = format!(
        "{} tracks t LEFT JOIN albums al ON al.id = t.album_id \
         WHERE {where_sql} ORDER BY t.title COLLATE NOCASE{limit_clause}",
        tracks::SELECT_ROW
    );
    let mut stmt = conn.prepare(&sql)?;
    let rows = stmt.query_map(params_from_iter(params.iter()), tracks::map_row)?;
    Ok(rows.collect::<rusqlite::Result<Vec<_>>>()?)
}

/// Validate a rule set compiles (used before persisting). Returns an error
/// message on the first bad field/operator/value.
pub fn validate(rule_json: &str, now_ms: i64) -> Result<(), String> {
    let q: SmartQuery = serde_json::from_str(rule_json).map_err(|e| e.to_string())?;
    compile(&q, now_ms).map(|_| ())
}

// ── CRUD on the smart_playlists table ───────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SmartPlaylistRow {
    pub id: i64,
    pub name: String,
    pub rule_json: String,
    pub limit_n: Option<i64>,
    pub updated_at: i64,
}

pub fn list(conn: &Connection) -> rusqlite::Result<Vec<SmartPlaylistRow>> {
    let mut stmt = conn.prepare(
        "SELECT id, name, rule_json, limit_n, updated_at \
         FROM smart_playlists ORDER BY name COLLATE NOCASE",
    )?;
    let rows = stmt.query_map([], |r| {
        Ok(SmartPlaylistRow {
            id: r.get(0)?,
            name: r.get(1)?,
            rule_json: r.get(2)?,
            limit_n: r.get(3)?,
            updated_at: r.get(4)?,
        })
    })?;
    rows.collect()
}

pub fn get(conn: &Connection, id: i64) -> rusqlite::Result<Option<SmartPlaylistRow>> {
    conn.query_row(
        "SELECT id, name, rule_json, limit_n, updated_at FROM smart_playlists WHERE id = ?1",
        [id],
        |r| {
            Ok(SmartPlaylistRow {
                id: r.get(0)?,
                name: r.get(1)?,
                rule_json: r.get(2)?,
                limit_n: r.get(3)?,
                updated_at: r.get(4)?,
            })
        },
    )
    .optional()
}

pub fn create(
    conn: &Connection,
    name: &str,
    rule_json: &str,
    limit_n: Option<i64>,
    now_ms: i64,
) -> rusqlite::Result<i64> {
    conn.execute(
        "INSERT INTO smart_playlists(name, rule_json, limit_n, updated_at) VALUES (?1,?2,?3,?4)",
        rusqlite::params![name, rule_json, limit_n, now_ms],
    )?;
    Ok(conn.last_insert_rowid())
}

pub fn update(
    conn: &Connection,
    id: i64,
    name: &str,
    rule_json: &str,
    limit_n: Option<i64>,
    now_ms: i64,
) -> rusqlite::Result<()> {
    conn.execute(
        "UPDATE smart_playlists SET name=?2, rule_json=?3, limit_n=?4, updated_at=?5 WHERE id=?1",
        rusqlite::params![id, name, rule_json, limit_n, now_ms],
    )?;
    Ok(())
}

pub fn delete(conn: &Connection, id: i64) -> rusqlite::Result<()> {
    conn.execute("DELETE FROM smart_playlists WHERE id = ?1", [id])?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::tracks::{upsert_track, NewTrack};
    use crate::db::Db;

    fn q(json: &str) -> SmartQuery {
        serde_json::from_str(json).unwrap()
    }

    #[test]
    fn compiles_all_and_any_with_params() {
        let query = q(r#"{"match":"all","rules":[
            {"field":"artist","op":"contains","value":"M83"},
            {"field":"year","op":"gte","value":"2010"}]}"#);
        let (sql, params) = compile(&query, 0).unwrap();
        assert!(sql.contains(" AND "));
        assert_eq!(params.len(), 2);
        assert!(matches!(&params[0], Value::Text(s) if s == "M83"));
        assert!(matches!(&params[1], Value::Integer(2010)));

        let any = q(r#"{"match":"any","rules":[
            {"field":"rating","op":"gte","value":"4"},
            {"field":"title","op":"is","value":"Outro"}]}"#);
        let (sql, _) = compile(&any, 0).unwrap();
        assert!(sql.contains(" OR "));
    }

    #[test]
    fn rejects_unknown_field_and_op() {
        let bad_field =
            q(r#"{"rules":[{"field":"t.title); DROP TABLE tracks;--","op":"is","value":"x"}]}"#);
        assert!(compile(&bad_field, 0).is_err());
        let bad_op = q(r#"{"rules":[{"field":"title","op":"regex","value":"x"}]}"#);
        assert!(compile(&bad_op, 0).is_err());
        let bad_num = q(r#"{"rules":[{"field":"year","op":"gte","value":"notanumber"}]}"#);
        assert!(compile(&bad_num, 0).is_err());
    }

    #[test]
    fn end_to_end_filters_library() {
        let db = Db::open_in_memory().unwrap();
        let c = db.conn();
        upsert_track(
            c,
            &NewTrack {
                path: "/m/1.flac".into(),
                normalized_path: "/m/1.flac".into(),
                title: "Midnight City".into(),
                artists: vec!["M83".into()],
                album: Some("Hurry Up".into()),
                album_artist: Some("M83".into()),
                year: Some(2011),
                added_at: 1,
                ..Default::default()
            },
        )
        .unwrap();
        // rating isn't part of NewTrack (set via tag editing later); seed it here
        c.execute(
            "UPDATE tracks SET rating = 5 WHERE title = 'Midnight City'",
            [],
        )
        .unwrap();
        upsert_track(
            c,
            &NewTrack {
                path: "/m/2.flac".into(),
                normalized_path: "/m/2.flac".into(),
                title: "Old Song".into(),
                artists: vec!["Someone".into()],
                album: Some("Old".into()),
                year: Some(1999),
                added_at: 1,
                ..Default::default()
            },
        )
        .unwrap();

        // value with an apostrophe must be treated literally (parameterized)
        let none = tracks_for_rules(
            c,
            r#"{"rules":[{"field":"artist","op":"is","value":"O'Brien"}]}"#,
            None,
            0,
        )
        .unwrap();
        assert!(none.is_empty());

        let hits = tracks_for_rules(
            c,
            r#"{"match":"all","rules":[
                {"field":"artist","op":"contains","value":"m83"},
                {"field":"year","op":"gte","value":"2010"},
                {"field":"rating","op":"gte","value":"4"}]}"#,
            None,
            0,
        )
        .unwrap();
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].title, "Midnight City");
    }
}
