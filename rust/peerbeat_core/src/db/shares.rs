//! Sharing config: which playlists (or the whole library) a host exposes on the
//! LAN, with an access **mode** (open / pin / approved) and a **permission**
//! level (stream / stream+download). One row per shared scope; a `NULL`
//! `playlist_id` means *the whole library*.
//!
//! This is the data layer only — the host server ([`crate::net`]) composes these
//! queries into per-request authorization, and the FRB API exposes the CRUD to
//! the host UI. PIN values are only ever stored hashed.

use crate::db::playlists::PlaylistRow;
use crate::db::tracks::{self, TrackRow};
use argon2::password_hash::{PasswordHash, PasswordHasher, PasswordVerifier, SaltString};
use argon2::Argon2;
use rusqlite::{params, Connection, OptionalExtension};
use serde::{Deserialize, Serialize};

/// A share as shown to the host UI. The `pin_hash` is never exposed; `has_pin`
/// only signals whether a PIN is set.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ShareRow {
    pub id: i64,
    /// `None` == the whole library.
    pub playlist_id: Option<i64>,
    /// Display label: the playlist name, or "Whole library" for the library share.
    pub label: String,
    /// `"stream"` | `"stream_download"`.
    pub permission: String,
    /// `"open"` | `"pin"` | `"approved"`.
    pub mode: String,
    pub has_pin: bool,
    pub enabled: bool,
}

/// What the server needs to authorize a request against one shared scope.
#[derive(Debug, Clone)]
pub struct ShareAccess {
    pub permission: String,
    pub mode: String,
    pub pin_hash: Option<String>,
}

impl ShareAccess {
    /// True if this share allows downloads (not just streaming).
    pub fn allows_download(&self) -> bool {
        self.permission == "stream_download"
    }
}

/// A share PIN must be 4–6 digits (spec). Enforced here and at the API/UI layer.
pub fn pin_is_valid_format(pin: &str) -> bool {
    let p = pin.trim();
    (4..=6).contains(&p.chars().count()) && p.chars().all(|c| c.is_ascii_digit())
}

/// Argon2id hash of a PIN as a self-contained PHC string (random per-PIN salt +
/// KDF params embedded). Short PINs are inherently weak, but a slow KDF with a
/// per-PIN salt removes cheap rainbow/precompute attacks against a stolen DB and
/// makes online guessing expensive (paired with auth rate-limiting). Stored in
/// `shares.pin_hash`. Returns an empty string only if hashing fails (never used).
pub fn hash_pin(pin: &str) -> String {
    // 16 random bytes from a v4 UUID make a fine Argon2 salt without pulling in a
    // separate RNG dependency (uuid is already a dep).
    let salt = match SaltString::encode_b64(uuid::Uuid::new_v4().as_bytes()) {
        Ok(s) => s,
        Err(_) => return String::new(),
    };
    Argon2::default()
        .hash_password(pin.trim().as_bytes(), &salt)
        .map(|h| h.to_string())
        .unwrap_or_default()
}

/// Verify a candidate PIN against a stored PHC hash. Pre-hardening SHA-256 hex
/// values fail to parse as PHC and therefore never verify — which intentionally
/// forces hosts to re-enter (re-save) their PIN once after upgrading.
pub fn verify_pin(stored_hash: &str, candidate: &str) -> bool {
    match PasswordHash::new(stored_hash) {
        Ok(parsed) => Argon2::default()
            .verify_password(candidate.trim().as_bytes(), &parsed)
            .is_ok(),
        Err(_) => false,
    }
}

fn normalize_permission(p: &str) -> &'static str {
    match p {
        "stream_download" => "stream_download",
        _ => "stream",
    }
}

fn normalize_mode(m: &str) -> &'static str {
    match m {
        "pin" => "pin",
        "approved" => "approved",
        _ => "open",
    }
}

/// Locate the existing share row id for a scope (`NULL`-aware on `playlist_id`).
fn find_id(conn: &Connection, playlist_id: Option<i64>) -> rusqlite::Result<Option<i64>> {
    match playlist_id {
        Some(pid) => conn
            .query_row("SELECT id FROM shares WHERE playlist_id = ?1", [pid], |r| {
                r.get(0)
            })
            .optional(),
        None => conn
            .query_row("SELECT id FROM shares WHERE playlist_id IS NULL", [], |r| {
                r.get(0)
            })
            .optional(),
    }
}

/// Create or update the share for a scope. A `pin` of `Some` (re)sets the PIN; a
/// `pin` of `None` keeps any existing PIN when `mode == "pin"`, and clears it
/// otherwise. Returns the share id.
pub fn set_share(
    conn: &Connection,
    playlist_id: Option<i64>,
    permission: &str,
    mode: &str,
    pin: Option<&str>,
    enabled: bool,
) -> rusqlite::Result<i64> {
    let permission = normalize_permission(permission);
    let mode = normalize_mode(mode);
    let existing = find_id(conn, playlist_id)?;

    // Resolve the pin_hash to store.
    let new_pin_hash: Option<String> = match (mode, pin) {
        (_, Some(p)) if !p.trim().is_empty() => Some(hash_pin(p)),
        ("pin", None) => match existing {
            // keep the current pin when re-saving a pin share without a new pin
            Some(id) => conn
                .query_row("SELECT pin_hash FROM shares WHERE id = ?1", [id], |r| {
                    r.get(0)
                })
                .optional()?
                .flatten(),
            None => None,
        },
        _ => None,
    };

    match existing {
        Some(id) => {
            conn.execute(
                "UPDATE shares SET permission = ?2, mode = ?3, pin_hash = ?4, enabled = ?5
                 WHERE id = ?1",
                params![id, permission, mode, new_pin_hash, enabled as i64],
            )?;
            Ok(id)
        }
        None => {
            conn.execute(
                "INSERT INTO shares(playlist_id, permission, mode, pin_hash, enabled)
                 VALUES (?1, ?2, ?3, ?4, ?5)",
                params![playlist_id, permission, mode, new_pin_hash, enabled as i64],
            )?;
            Ok(conn.last_insert_rowid())
        }
    }
}

/// Toggle a share on/off by scope (keeps its mode/permission/PIN).
pub fn set_enabled(
    conn: &Connection,
    playlist_id: Option<i64>,
    enabled: bool,
) -> rusqlite::Result<()> {
    match playlist_id {
        Some(pid) => conn.execute(
            "UPDATE shares SET enabled = ?2 WHERE playlist_id = ?1",
            params![pid, enabled as i64],
        ),
        None => conn.execute(
            "UPDATE shares SET enabled = ?1 WHERE playlist_id IS NULL",
            [enabled as i64],
        ),
    }?;
    Ok(())
}

/// Stop sharing a scope entirely (removes the row).
pub fn remove(conn: &Connection, playlist_id: Option<i64>) -> rusqlite::Result<()> {
    match playlist_id {
        Some(pid) => conn.execute("DELETE FROM shares WHERE playlist_id = ?1", [pid]),
        None => conn.execute("DELETE FROM shares WHERE playlist_id IS NULL", []),
    }?;
    Ok(())
}

/// Every configured share, with a display label, for the host UI.
pub fn list(conn: &Connection) -> rusqlite::Result<Vec<ShareRow>> {
    let mut stmt = conn.prepare(
        "SELECT s.id, s.playlist_id,
                COALESCE(p.name, 'Whole library') AS label,
                s.permission, s.mode, s.pin_hash IS NOT NULL, s.enabled
         FROM shares s
         LEFT JOIN playlists p ON p.id = s.playlist_id
         ORDER BY (s.playlist_id IS NOT NULL), label COLLATE NOCASE",
    )?;
    let rows = stmt.query_map([], |r| {
        Ok(ShareRow {
            id: r.get(0)?,
            playlist_id: r.get(1)?,
            label: r.get(2)?,
            permission: r.get(3)?,
            mode: r.get(4)?,
            has_pin: r.get::<_, i64>(5)? != 0,
            enabled: r.get::<_, i64>(6)? != 0,
        })
    })?;
    rows.collect()
}

/// The enabled whole-library share, if any.
pub fn library_access(conn: &Connection) -> rusqlite::Result<Option<ShareAccess>> {
    conn.query_row(
        "SELECT permission, mode, pin_hash FROM shares
         WHERE playlist_id IS NULL AND enabled = 1",
        [],
        |r| {
            Ok(ShareAccess {
                permission: r.get(0)?,
                mode: r.get(1)?,
                pin_hash: r.get(2)?,
            })
        },
    )
    .optional()
}

/// The enabled share for a specific playlist, if any.
pub fn playlist_access(
    conn: &Connection,
    playlist_id: i64,
) -> rusqlite::Result<Option<ShareAccess>> {
    conn.query_row(
        "SELECT permission, mode, pin_hash FROM shares
         WHERE playlist_id = ?1 AND enabled = 1",
        [playlist_id],
        |r| {
            Ok(ShareAccess {
                permission: r.get(0)?,
                mode: r.get(1)?,
                pin_hash: r.get(2)?,
            })
        },
    )
    .optional()
}

/// True if any share is enabled (i.e. hosting actually exposes something).
pub fn anything_shared(conn: &Connection) -> rusqlite::Result<bool> {
    let n: i64 = conn.query_row("SELECT count(*) FROM shares WHERE enabled = 1", [], |r| {
        r.get(0)
    })?;
    Ok(n > 0)
}

/// The playlists a peer may see/list: every playlist with an enabled share. If a
/// whole-library share is enabled, *all* playlists are listed.
pub fn shared_playlists(conn: &Connection) -> rusqlite::Result<Vec<PlaylistRow>> {
    let whole = library_access(conn)?.is_some();
    let sql = if whole {
        "SELECT p.id, p.name, count(pi.track_id) AS track_count,
                p.sort_order, p.created_at, p.updated_at
         FROM playlists p
         LEFT JOIN playlist_items pi ON pi.playlist_id = p.id
         GROUP BY p.id
         ORDER BY p.sort_order, p.name COLLATE NOCASE"
            .to_string()
    } else {
        "SELECT p.id, p.name, count(pi.track_id) AS track_count,
                p.sort_order, p.created_at, p.updated_at
         FROM playlists p
         JOIN shares s ON s.playlist_id = p.id AND s.enabled = 1
         LEFT JOIN playlist_items pi ON pi.playlist_id = p.id
         GROUP BY p.id
         ORDER BY p.sort_order, p.name COLLATE NOCASE"
            .to_string()
    };
    let mut stmt = conn.prepare(&sql)?;
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

/// Whether `track_id` is reachable by a peer, and at what permission. A
/// whole-library share covers every track; otherwise the track must sit in at
/// least one shared playlist. Returns the most permissive matching access.
pub fn track_access(conn: &Connection, track_id: i64) -> rusqlite::Result<Option<ShareAccess>> {
    if let Some(lib) = library_access(conn)? {
        // A library share already grants the widest reach; only a playlist share
        // with download could be more permissive, so check for that too.
        if lib.allows_download() {
            return Ok(Some(lib));
        }
        let dl = conn
            .query_row(
                "SELECT 1 FROM shares s
                 JOIN playlist_items pi ON pi.playlist_id = s.playlist_id
                 WHERE s.enabled = 1 AND s.permission = 'stream_download'
                   AND pi.track_id = ?1 LIMIT 1",
                [track_id],
                |_| Ok(()),
            )
            .optional()?;
        return Ok(Some(if dl.is_some() {
            ShareAccess {
                permission: "stream_download".into(),
                mode: lib.mode,
                pin_hash: lib.pin_hash,
            }
        } else {
            lib
        }));
    }
    // No library share: the track must be in some enabled playlist share. Prefer
    // a download-capable one.
    conn.query_row(
        "SELECT permission, mode, pin_hash FROM shares s
         JOIN playlist_items pi ON pi.playlist_id = s.playlist_id
         WHERE s.enabled = 1 AND pi.track_id = ?1
         ORDER BY (s.permission = 'stream_download') DESC
         LIMIT 1",
        [track_id],
        |r| {
            Ok(ShareAccess {
                permission: r.get(0)?,
                mode: r.get(1)?,
                pin_hash: r.get(2)?,
            })
        },
    )
    .optional()
}

/// Whether `track_id` is a member of `playlist_id` (scope check for a
/// playlist-scoped session token streaming a track).
pub fn track_in_playlist(
    conn: &Connection,
    playlist_id: i64,
    track_id: i64,
) -> rusqlite::Result<bool> {
    let n: i64 = conn.query_row(
        "SELECT count(*) FROM playlist_items WHERE playlist_id = ?1 AND track_id = ?2",
        params![playlist_id, track_id],
        |r| r.get(0),
    )?;
    Ok(n > 0)
}

/// Tracks of a shared playlist (used to serve `/v1/playlists/{id}` to peers).
pub fn shared_playlist_tracks(
    conn: &Connection,
    playlist_id: i64,
) -> rusqlite::Result<Vec<TrackRow>> {
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::playlists;
    use crate::db::tracks::{upsert_track, NewTrack};
    use crate::db::Db;

    fn add_track(conn: &Connection, id: i64) -> i64 {
        upsert_track(
            conn,
            &NewTrack {
                path: format!("/m/{id}.flac"),
                normalized_path: format!("/m/{id}.flac"),
                title: format!("Track {id}"),
                added_at: 1,
                ..Default::default()
            },
        )
        .unwrap()
    }

    #[test]
    fn set_update_and_toggle_a_playlist_share() {
        let db = Db::open_in_memory().unwrap();
        let c = db.conn();
        let p = playlists::create(c, "Road", 1).unwrap();

        // open, stream-only
        set_share(c, Some(p), "stream", "open", None, true).unwrap();
        let rows = list(c).unwrap();
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0].mode, "open");
        assert!(!rows[0].has_pin);
        assert!(rows[0].enabled);
        let acc = playlist_access(c, p).unwrap().unwrap();
        assert!(!acc.allows_download());

        // promote to pin + download; calling set_share again must UPDATE not insert
        set_share(c, Some(p), "stream_download", "pin", Some("1234"), true).unwrap();
        let rows = list(c).unwrap();
        assert_eq!(rows.len(), 1, "still one row (upsert)");
        assert!(rows[0].has_pin);
        let acc = playlist_access(c, p).unwrap().unwrap();
        assert!(acc.allows_download());
        // PIN is stored as an Argon2 PHC hash (random salt) — verify, don't compare.
        assert!(verify_pin(acc.pin_hash.as_deref().unwrap(), "1234"));
        assert!(!verify_pin(acc.pin_hash.as_deref().unwrap(), "9999"));

        // re-save without a pin keeps the existing one for a pin share
        set_share(c, Some(p), "stream_download", "pin", None, true).unwrap();
        assert!(verify_pin(
            playlist_access(c, p)
                .unwrap()
                .unwrap()
                .pin_hash
                .as_deref()
                .unwrap(),
            "1234"
        ));

        // disable hides it from access but keeps the row
        set_enabled(c, Some(p), false).unwrap();
        assert!(playlist_access(c, p).unwrap().is_none());
        assert_eq!(list(c).unwrap().len(), 1);
        assert!(!anything_shared(c).unwrap());
    }

    #[test]
    fn library_share_covers_all_tracks() {
        let db = Db::open_in_memory().unwrap();
        let c = db.conn();
        let t1 = add_track(c, 1);
        let t2 = add_track(c, 2);

        // no share → nothing reachable
        assert!(track_access(c, t1).unwrap().is_none());

        // whole-library stream share → every track streamable, none downloadable
        set_share(c, None, "stream", "open", None, true).unwrap();
        assert!(track_access(c, t1).unwrap().unwrap().permission == "stream");
        assert!(!track_access(c, t2).unwrap().unwrap().allows_download());
        assert_eq!(list(c).unwrap()[0].label, "Whole library");
    }

    #[test]
    fn playlist_share_scopes_tracks_and_download() {
        let db = Db::open_in_memory().unwrap();
        let c = db.conn();
        let t1 = add_track(c, 1);
        let t2 = add_track(c, 2);
        let p = playlists::create(c, "Shared", 1).unwrap();
        playlists::add_tracks(c, p, &[t1], 2).unwrap();

        // share only that playlist, stream+download
        set_share(c, Some(p), "stream_download", "open", None, true).unwrap();

        // t1 (in the playlist) is reachable + downloadable; t2 is not reachable
        let a1 = track_access(c, t1).unwrap().unwrap();
        assert!(a1.allows_download());
        assert!(track_access(c, t2).unwrap().is_none());

        // shared_playlists lists exactly the shared one
        let sp = shared_playlists(c).unwrap();
        assert_eq!(sp.len(), 1);
        assert_eq!(sp[0].id, p);
        assert_eq!(shared_playlist_tracks(c, p).unwrap().len(), 1);
    }

    #[test]
    fn remove_stops_sharing() {
        let db = Db::open_in_memory().unwrap();
        let c = db.conn();
        set_share(c, None, "stream", "open", None, true).unwrap();
        assert!(anything_shared(c).unwrap());
        remove(c, None).unwrap();
        assert!(!anything_shared(c).unwrap());
        assert!(library_access(c).unwrap().is_none());
    }

    #[test]
    fn pin_format_and_hash_roundtrip() {
        assert!(pin_is_valid_format("1234"));
        assert!(pin_is_valid_format("123456"));
        assert!(!pin_is_valid_format("123")); // too short
        assert!(!pin_is_valid_format("1234567")); // too long
        assert!(!pin_is_valid_format("12a4")); // non-digit
        assert!(!pin_is_valid_format("")); // empty

        let h = hash_pin("4242");
        assert!(h.starts_with("$argon2"));
        assert!(verify_pin(&h, "4242"));
        assert!(!verify_pin(&h, "0000"));
        // a legacy SHA-256 hex value never verifies (forces re-entry post-upgrade)
        assert!(!verify_pin("deadbeef", "4242"));
    }
}
