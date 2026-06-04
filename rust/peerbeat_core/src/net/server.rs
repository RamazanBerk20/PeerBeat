//! LAN host HTTP server (axum). Serves library metadata + audio bytes to peers.
//!
//! Endpoints: public `/v1/info` and `/v1/shares` (so a peer can see what is
//! shareable and in which mode); `POST /v1/auth/session` issues a bearer token
//! for a chosen scope after the access mode is satisfied (open / PIN; approved
//! is gated on a remembered decision until the control channel lands). The
//! token-scoped routes `/v1/tracks`, `/v1/playlists`, `/v1/playlists/{id}`, and
//! `/v1/stream/{id}` (HTTP Range via `ServeFile`) then serve only what the
//! token's scope and permission allow. The listener is wrapped in TLS with a
//! per-host self-signed cert in [`crate::api::network`]; peers pin it via TOFU.
//!
//! Not yet built (roadmap, see `docs/STATUS.md`): download endpoints, the
//! transfer-log dashboard, and the WebSocket control / party channel.

use crate::db::{shares, tracks};
use axum::{
    extract::{FromRequestParts, Path, Request, State},
    http::{header::AUTHORIZATION, request::Parts, StatusCode},
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use rusqlite::Connection;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use tower::ServiceExt;
use tower_http::services::ServeFile;

/// Which shared scope a session token grants access to.
#[derive(Clone, Debug, PartialEq)]
pub enum Scope {
    Library,
    Playlist(i64),
}

/// An issued token's grant: the scope and whether downloads are permitted.
#[derive(Clone)]
pub struct Session {
    pub scope: Scope,
    pub can_download: bool,
    pub created_at_ms: i64,
}

/// Host-side token store (token → grant). Cleared by a host "revoke all".
pub type Sessions = Arc<Mutex<HashMap<String, Session>>>;

#[derive(Clone)]
pub struct ServerConfig {
    pub db_path: PathBuf,
    pub name: String,
    pub host_id: String,
    pub fingerprint: String,
    pub sessions: Sessions,
}

impl ServerConfig {
    pub fn new(db_path: PathBuf, name: String, host_id: String, fingerprint: String) -> Self {
        Self {
            db_path,
            name,
            host_id,
            fingerprint,
            sessions: Arc::new(Mutex::new(HashMap::new())),
        }
    }
}

fn now_ms() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

#[derive(Serialize)]
struct InfoResp {
    name: String,
    host_id: String,
    fingerprint: String,
    proto: u32,
}

#[derive(Serialize)]
struct TrackDto {
    id: i64,
    title: String,
    artist: String,
    album: String,
    duration_ms: i64,
}

fn track_dto(t: tracks::TrackRow) -> TrackDto {
    TrackDto {
        id: t.id,
        title: t.title,
        artist: t.artist,
        album: t.album,
        duration_ms: t.duration_ms,
    }
}

#[derive(Serialize)]
struct PlaylistDto {
    id: i64,
    name: String,
    track_count: i64,
}

#[derive(Serialize)]
struct ShareDto {
    /// `"library"` or `"playlist"`.
    scope: String,
    playlist_id: Option<i64>,
    label: String,
    mode: String,
    permission: String,
    requires_pin: bool,
}

pub fn router(cfg: ServerConfig) -> Router {
    Router::new()
        .route("/v1/info", get(info))
        .route("/v1/shares", get(list_shares))
        .route("/v1/auth/session", post(auth_session))
        .route("/v1/tracks", get(list_tracks))
        .route("/v1/playlists", get(list_playlists))
        .route("/v1/playlists/{id}", get(playlist_tracks))
        .route("/v1/stream/{id}", get(stream))
        .with_state(cfg)
}

/// Run a closure with a fresh connection on a blocking thread. Returns `None` on
/// any error (handlers fail closed).
async fn blocking_db<T, F>(db_path: PathBuf, f: F) -> Option<T>
where
    F: FnOnce(&Connection) -> rusqlite::Result<T> + Send + 'static,
    T: Send + 'static,
{
    tokio::task::spawn_blocking(move || {
        let conn = Connection::open(&db_path).ok()?;
        f(&conn).ok()
    })
    .await
    .ok()
    .flatten()
}

// ── Bearer-token auth extractor ──────────────────────────────────────────────

struct Auth(Session);

impl FromRequestParts<ServerConfig> for Auth {
    type Rejection = (StatusCode, &'static str);

    async fn from_request_parts(
        parts: &mut Parts,
        state: &ServerConfig,
    ) -> Result<Self, Self::Rejection> {
        // Prefer the Authorization header; fall back to a `?token=` query param so
        // a plain stream URL (which the audio engine fetches without custom
        // headers) can still carry its scoped token.
        let header_token = parts
            .headers
            .get(AUTHORIZATION)
            .and_then(|v| v.to_str().ok())
            .and_then(|s| s.strip_prefix("Bearer "))
            .map(str::to_owned);
        let token = header_token
            .or_else(|| {
                parts.uri.query().and_then(|q| {
                    q.split('&')
                        .find_map(|kv| kv.strip_prefix("token=").map(str::to_owned))
                })
            })
            .ok_or((StatusCode::UNAUTHORIZED, "missing bearer token"))?;
        state
            .sessions
            .lock()
            .ok()
            .and_then(|m| m.get(&token).cloned())
            .map(Auth)
            .ok_or((StatusCode::UNAUTHORIZED, "invalid or revoked token"))
    }
}

// ── Public endpoints ─────────────────────────────────────────────────────────

async fn info(State(cfg): State<ServerConfig>) -> impl IntoResponse {
    Json(InfoResp {
        name: cfg.name.clone(),
        host_id: cfg.host_id.clone(),
        fingerprint: cfg.fingerprint.clone(),
        proto: 1,
    })
}

/// The shareable scopes + their access mode, so a peer's UI can decide whether to
/// prompt for a PIN before authenticating. Reveals labels only — never tracks.
async fn list_shares(State(cfg): State<ServerConfig>) -> impl IntoResponse {
    let rows = blocking_db(cfg.db_path.clone(), shares::list)
        .await
        .unwrap_or_default();
    let dtos: Vec<ShareDto> = rows
        .into_iter()
        .filter(|s| s.enabled)
        .map(|s| ShareDto {
            scope: if s.playlist_id.is_none() {
                "library".into()
            } else {
                "playlist".into()
            },
            playlist_id: s.playlist_id,
            label: s.label,
            mode: s.mode.clone(),
            permission: s.permission,
            requires_pin: s.mode == "pin",
        })
        .collect();
    Json(dtos)
}

#[derive(Deserialize)]
struct AuthReq {
    #[serde(default)]
    scope: String, // "library" | "playlist"
    #[serde(default)]
    playlist_id: Option<i64>,
    #[serde(default)]
    pin: Option<String>,
}

#[derive(Serialize)]
struct AuthResp {
    token: String,
}

async fn auth_session(
    State(cfg): State<ServerConfig>,
    Json(req): Json<AuthReq>,
) -> impl IntoResponse {
    let pid = if req.scope == "playlist" {
        req.playlist_id
    } else {
        None
    };
    let access = blocking_db(cfg.db_path.clone(), move |c| match pid {
        None => shares::library_access(c),
        Some(id) => shares::playlist_access(c, id),
    })
    .await
    .flatten();
    let Some(access) = access else {
        return (StatusCode::FORBIDDEN, "that scope is not shared").into_response();
    };

    match access.mode.as_str() {
        "open" => {}
        "pin" => {
            let provided = req.pin.as_deref().map(shares::hash_pin);
            let ok = matches!((&access.pin_hash, &provided), (Some(w), Some(g)) if w == g);
            if !ok {
                return (StatusCode::UNAUTHORIZED, "incorrect PIN").into_response();
            }
        }
        "approved" => {
            return (
                StatusCode::FORBIDDEN,
                "host approval required (not yet available)",
            )
                .into_response();
        }
        _ => return (StatusCode::FORBIDDEN, "unsupported share mode").into_response(),
    }

    let scope = match pid {
        Some(id) => Scope::Playlist(id),
        None => Scope::Library,
    };
    let token = uuid::Uuid::new_v4().simple().to_string();
    if let Ok(mut m) = cfg.sessions.lock() {
        m.insert(
            token.clone(),
            Session {
                scope,
                can_download: access.allows_download(),
                created_at_ms: now_ms(),
            },
        );
    }
    Json(AuthResp { token }).into_response()
}

// ── Token-scoped endpoints ───────────────────────────────────────────────────

async fn list_tracks(State(cfg): State<ServerConfig>, auth: Auth) -> impl IntoResponse {
    let scope = auth.0.scope.clone();
    let rows = blocking_db(cfg.db_path.clone(), move |c| {
        let songs = match scope {
            Scope::Library => tracks::browse_songs(c, 100_000, 0)?,
            Scope::Playlist(id) => shares::shared_playlist_tracks(c, id)?,
        };
        Ok(songs.into_iter().map(track_dto).collect::<Vec<_>>())
    })
    .await
    .unwrap_or_default();
    Json(rows)
}

async fn list_playlists(State(cfg): State<ServerConfig>, auth: Auth) -> impl IntoResponse {
    let scope = auth.0.scope.clone();
    let rows = blocking_db(cfg.db_path.clone(), move |c| {
        let pls = shares::shared_playlists(c)?;
        let pls = match scope {
            Scope::Library => pls,
            Scope::Playlist(id) => pls.into_iter().filter(|p| p.id == id).collect(),
        };
        Ok(pls
            .into_iter()
            .map(|p| PlaylistDto {
                id: p.id,
                name: p.name,
                track_count: p.track_count,
            })
            .collect::<Vec<_>>())
    })
    .await
    .unwrap_or_default();
    Json(rows)
}

async fn playlist_tracks(
    State(cfg): State<ServerConfig>,
    Path(id): Path<i64>,
    auth: Auth,
) -> impl IntoResponse {
    if let Scope::Playlist(pid) = auth.0.scope {
        if pid != id {
            return (StatusCode::FORBIDDEN, "out of scope").into_response();
        }
    }
    let rows = blocking_db(cfg.db_path.clone(), move |c| {
        // The playlist must actually be shared (covers the library-scope case).
        if !shares::shared_playlists(c)?.iter().any(|p| p.id == id) {
            return Ok(None);
        }
        Ok(Some(
            shares::shared_playlist_tracks(c, id)?
                .into_iter()
                .map(track_dto)
                .collect::<Vec<_>>(),
        ))
    })
    .await
    .flatten();
    match rows {
        Some(t) => Json(t).into_response(),
        None => (StatusCode::NOT_FOUND, "no such shared playlist").into_response(),
    }
}

/// Stream a track's original bytes if the token's scope covers it. `ServeFile`
/// honors HTTP Range (206 for seeking) and streams in chunks. The path is
/// resolved from the DB by id (never the request), so there is no path traversal.
async fn stream(
    State(cfg): State<ServerConfig>,
    Path(id): Path<i64>,
    auth: Auth,
    request: Request,
) -> impl IntoResponse {
    let scope = auth.0.scope.clone();
    let allowed = blocking_db(cfg.db_path.clone(), move |c| {
        Ok(match scope {
            Scope::Library => shares::library_access(c)?.is_some(),
            Scope::Playlist(pid) => shares::track_in_playlist(c, pid, id)?,
        })
    })
    .await
    .unwrap_or(false);
    if !allowed {
        return (StatusCode::FORBIDDEN, "track not in your shared scope").into_response();
    }

    let file_path = blocking_db(cfg.db_path.clone(), move |c| {
        c.query_row("SELECT path FROM tracks WHERE id = ?1", [id], |r| {
            r.get::<_, String>(0)
        })
    })
    .await;
    let Some(file_path) = file_path else {
        return (StatusCode::NOT_FOUND, "no such track").into_response();
    };
    match ServeFile::new(&file_path).oneshot(request).await {
        Ok(resp) => resp.into_response(),
        Err(_) => (StatusCode::NOT_FOUND, "file missing").into_response(),
    }
}

/// Bind `0.0.0.0:0` and return a non-blocking std listener (for `axum_server`)
/// + the chosen port.
pub fn bind_std() -> std::io::Result<(std::net::TcpListener, u16)> {
    let listener = std::net::TcpListener::bind(("0.0.0.0", 0))?;
    let port = listener.local_addr()?.port();
    listener.set_nonblocking(true)?;
    Ok((listener, port))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::tracks::{upsert_track, NewTrack};
    use crate::db::{playlists, Db};
    use axum::body::{to_bytes, Body};
    use axum::http::Request as HttpRequest;

    /// A temp db file seeded with `n` tracks; returns (path, track_ids).
    fn seed_db(n: i64) -> (PathBuf, Vec<i64>) {
        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path = std::env::temp_dir().join(format!("peerbeat_srv_{nanos}.db"));
        let db = Db::open(&path).unwrap();
        let mut ids = Vec::new();
        for i in 0..n {
            // a real file so /v1/stream can 200 for in-scope tracks
            let f = std::env::temp_dir().join(format!("peerbeat_srv_{nanos}_{i}.bin"));
            std::fs::write(&f, b"audio-bytes").unwrap();
            ids.push(
                upsert_track(
                    db.conn(),
                    &NewTrack {
                        path: f.to_string_lossy().into_owned(),
                        normalized_path: f.to_string_lossy().into_owned(),
                        title: format!("Song {i}"),
                        added_at: 1,
                        ..Default::default()
                    },
                )
                .unwrap(),
            );
        }
        (path, ids)
    }

    fn run<F: std::future::Future>(f: F) -> F::Output {
        tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .unwrap()
            .block_on(f)
    }

    async fn status_of(cfg: &ServerConfig, req: HttpRequest<Body>) -> StatusCode {
        router(cfg.clone()).oneshot(req).await.unwrap().status()
    }

    async fn token_for(cfg: &ServerConfig, body: &str) -> Option<String> {
        let req = HttpRequest::post("/v1/auth/session")
            .header("content-type", "application/json")
            .body(Body::from(body.to_string()))
            .unwrap();
        let resp = router(cfg.clone()).oneshot(req).await.unwrap();
        if resp.status() != StatusCode::OK {
            return None;
        }
        let bytes = to_bytes(resp.into_body(), usize::MAX).await.unwrap();
        let v: serde_json::Value = serde_json::from_slice(&bytes).unwrap();
        v.get("token").and_then(|t| t.as_str()).map(str::to_owned)
    }

    #[test]
    fn open_library_share_requires_token_then_serves() {
        run(async {
            let (path, ids) = seed_db(2);
            let cfg = ServerConfig::new(path, "Host".into(), "h".into(), "fp".into());
            shares::set_share(
                &Connection::open(&cfg.db_path).unwrap(),
                None,
                "stream",
                "open",
                None,
                true,
            )
            .unwrap();

            // /v1/tracks without a token → 401
            let unauth = status_of(
                &cfg,
                HttpRequest::get("/v1/tracks").body(Body::empty()).unwrap(),
            )
            .await;
            assert_eq!(unauth, StatusCode::UNAUTHORIZED);

            // authenticate to the library scope (open → no pin)
            let token = token_for(&cfg, r#"{"scope":"library"}"#).await.unwrap();

            // /v1/tracks with the token → 200
            let ok = status_of(
                &cfg,
                HttpRequest::get("/v1/tracks")
                    .header("authorization", format!("Bearer {token}"))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await;
            assert_eq!(ok, StatusCode::OK);

            // an invalid token → 401
            let bad = status_of(
                &cfg,
                HttpRequest::get("/v1/tracks")
                    .header("authorization", "Bearer nope")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await;
            assert_eq!(bad, StatusCode::UNAUTHORIZED);

            // streaming an in-scope track succeeds (real temp file)
            let streamed = status_of(
                &cfg,
                HttpRequest::get(format!("/v1/stream/{}", ids[0]))
                    .header("authorization", format!("Bearer {token}"))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await;
            assert_eq!(streamed, StatusCode::OK);

            // streaming via a `?token=` query param (no auth header) also works
            let streamed_q = status_of(
                &cfg,
                HttpRequest::get(format!("/v1/stream/{}?token={token}", ids[1]))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await;
            assert_eq!(streamed_q, StatusCode::OK);
        });
    }

    #[test]
    fn pin_share_enforces_pin_and_playlist_scope() {
        run(async {
            let (path, ids) = seed_db(2);
            let cfg = ServerConfig::new(path, "Host".into(), "h".into(), "fp".into());
            let c = Connection::open(&cfg.db_path).unwrap();
            let p = playlists::create(&c, "Shared", 1).unwrap();
            playlists::add_tracks(&c, p, &[ids[0]], 2).unwrap(); // only track 0 is in the playlist
            shares::set_share(&c, Some(p), "stream", "pin", Some("4242"), true).unwrap();

            // wrong / missing pin → 401
            assert!(token_for(
                &cfg,
                &format!(r#"{{"scope":"playlist","playlist_id":{p}}}"#)
            )
            .await
            .is_none());
            assert!(token_for(
                &cfg,
                &format!(r#"{{"scope":"playlist","playlist_id":{p},"pin":"0000"}}"#)
            )
            .await
            .is_none());

            // correct pin → token scoped to the playlist
            let token = token_for(
                &cfg,
                &format!(r#"{{"scope":"playlist","playlist_id":{p},"pin":"4242"}}"#),
            )
            .await
            .unwrap();

            // in-playlist track streams; out-of-playlist track is 403
            let in_scope = status_of(
                &cfg,
                HttpRequest::get(format!("/v1/stream/{}", ids[0]))
                    .header("authorization", format!("Bearer {token}"))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await;
            assert_eq!(in_scope, StatusCode::OK);

            let out_scope = status_of(
                &cfg,
                HttpRequest::get(format!("/v1/stream/{}", ids[1]))
                    .header("authorization", format!("Bearer {token}"))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await;
            assert_eq!(out_scope, StatusCode::FORBIDDEN);
        });
    }
}
